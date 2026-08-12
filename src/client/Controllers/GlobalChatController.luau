--!nonstrict
--[[
	GlobalChatController.luau
	Draws the cross-server messages `GlobalChatService` sends into the Global chat tab.

	The server owns everything that matters -- who may speak, how often, and what each recipient is
	allowed to see -- so this only formats and displays. It never sends: typing goes through Roblox's own
	input bar into the Global channel, and the server picks it up from there.

	WHY `DisplaySystemMessage` RATHER THAN A REAL CHAT LINE. `TextChannel:SendAsync` is a client-to-server
	call; there is no server-to-client equivalent that makes a message look like it came from a person. So
	a global line is a system message whose text carries the speaker's name, which also means the whole
	line can be styled -- the title tag keeps its rarity colour, exactly as `TitleController` does for
	local chat.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local Theme = require(ReplicatedStorage.Shared.UI.Theme)
local TitleConfig = require(ReplicatedStorage.Shared.Config.TitleConfig)

local GlobalChatController = {}

local CHANNEL_NAME = "Global"

--- How long to wait for the server to create the channel before giving up.
local CHANNEL_WAIT_SECONDS = 20

local started = false

--[[
	Rarity colour for a title id, resolved the same way `TitleController` does it for local chat.

	`TitleConfig.accent` returns a Theme colour NAME rather than a `Color3`, which is why this goes
	through `Theme.Color` -- the config deliberately knows nothing about the palette.
]]
local function tagColour(titleId: string?): Color3
	local definition = TitleConfig.resolve(titleId)
	if definition == nil then
		return Theme.Color.Gray
	end
	return Theme.Color[TitleConfig.accent(definition)] or Theme.Color.Gray
end

local function escape(text: string): string
	--[[
		The line is drawn as rich text so the tag can be tinted, which means any angle bracket the player
		typed would be read as markup. `&` first, or it would double-escape the entities added after it.
	]]
	local escaped = string.gsub(text, "&", "&amp;")
	escaped = string.gsub(escaped, "<", "&lt;")
	escaped = string.gsub(escaped, ">", "&gt;")
	return escaped
end

local function format(payload: { [string]: any }): string
	local name = escape(tostring(payload.Name or "?"))
	local text = escape(tostring(payload.Text or ""))
	local tag = tostring(payload.Tag or "")

	--- GLOBAL first, so it is obvious the line reaches every server even if the tab is not in view.
	local prefix = '<font color="#7FD4FF">[GLOBAL]</font>'
	if tag ~= "" then
		local colour = tagColour(payload.TitleId)
		prefix = `{prefix} <font color="#{colour:ToHex()}">{escape(tag)}</font>`
	end
	return `{prefix} <b>{name}</b>: {text}`
end

function GlobalChatController.Start()
	if started then
		return
	end
	started = true

	local remote = ReplicatedStorage:WaitForChild("Remotes", 20)
	local globalChat = remote and remote:WaitForChild("GlobalChat", 20)
	if globalChat == nil then
		warn("[GlobalChatController] no GlobalChat remote -- global chat will not display")
		return
	end

	--[[
		The channel is made by the server, so it may not exist yet at the moment this starts. Waiting on
		the folder's child rather than polling: it arrives once and never goes away.
	]]
	local channels = TextChatService:WaitForChild("TextChannels", CHANNEL_WAIT_SECONDS)
	local channel = channels and channels:WaitForChild(CHANNEL_NAME, CHANNEL_WAIT_SECONDS)
	if channel == nil then
		warn(`[GlobalChatController] no {CHANNEL_NAME} channel -- global chat will not display`)
		return
	end

	globalChat.OnClientEvent:Connect(function(payload)
		if type(payload) ~= "table" then
			return
		end
		--[[
			A refusal from the server -- a cooldown or a busy topic -- rather than somebody's message. Shown
			in the same place the player was typing, because a message that silently vanishes reads as
			broken chat.
		]]
		if type(payload.System) == "string" then
			pcall(function()
				channel:DisplaySystemMessage(
					`<font color="#FFB454">{escape(payload.System)}</font>`
				)
			end)
			return
		end
		--- Nothing to clean up after: the connection dies with the client, and the channel is the server's.
		pcall(function()
			channel:DisplaySystemMessage(format(payload))
		end)
	end)
end

return table.freeze(GlobalChatController)
