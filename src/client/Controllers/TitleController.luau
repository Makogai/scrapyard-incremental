--!nonstrict
--[[
	TitleController.luau
	Shows the worn title in the two places other players look: over the head, and in front of chat.

	BOTH SURFACES READ A PLAYER ATTRIBUTE. `PlayerStateService` publishes `TitleTag` (already bracketed)
	and `TitleId` on the Player, so this controller draws OTHER people's titles with no remote, no
	request and no cache -- attributes replicate to every client and arrive with the Player instance, so
	someone who joined before you still shows up wearing theirs.

	THE NAMEPLATE REPLACES ROBLOX'S. `Humanoid.DisplayName` is drawn by the engine and cannot have a
	second line put under it, so the engine's version is switched off (`DisplayDistanceType = None`) and
	this draws both lines itself. That is the only way to get "title under name" rather than "title
	floating near name", and it means the two lines can never drift apart when the camera moves.

	The billboard is built here rather than authored in the place file, unlike the plot signs and the
	event board: it is attached to a character that does not exist until someone spawns, and respawning
	rebuilds it. There is nothing for a designer to position -- the head decides where it goes.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local Theme = require(ReplicatedStorage.Shared.UI.Theme)
local TitleConfig = require(ReplicatedStorage.Shared.Config.TitleConfig)

local TitleController = {}

local NAMEPLATE = "ScrapyardNameplate"
local started = false

--- The accent a rarity is drawn in, resolved through `Theme` here rather than in the shared config.
local function rarityColor(titleId: string?): Color3
	local definition = TitleConfig.resolve(titleId)
	if definition == nil then
		return Theme.Color.Gray
	end
	local accentName = TitleConfig.RarityAccent[definition.Rarity] or "Gray"
	return Theme.Color[accentName] or Theme.Color.Gray
end

--[[
	Build the two-line plate. Name on top, title under it.

	`AlwaysOnTop` is deliberately FALSE: a name that draws through walls turns a yard full of players
	into a wall of text, and the engine's own nameplates do not do it either.
]]
local function buildNameplate(character: Model, player: Player): BillboardGui?
	local head = character:FindFirstChild("Head")
	if head == nil then
		return nil
	end
	local existing = head:FindFirstChild(NAMEPLATE)
	if existing then
		existing:Destroy()
	end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = NAMEPLATE
	billboard.Size = UDim2.fromOffset(220, 58)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 2.6, 0)
	billboard.AlwaysOnTop = false
	billboard.MaxDistance = 90
	billboard.LightInfluence = 0
	billboard.ResetOnSpawn = false

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	layout.Padding = UDim.new(0, -2)
	layout.Parent = billboard

	local function line(name: string, size: number, colour: Color3, order: number): TextLabel
		local label = Instance.new("TextLabel")
		label.Name = name
		label.BackgroundTransparency = 1
		label.Size = UDim2.new(1, 0, 0, size + 6)
		label.Font = Enum.Font.FredokaOne
		label.TextSize = size
		label.TextColor3 = colour
		label.LayoutOrder = order
		label.Parent = billboard
		--- The heavy ink outline every glyph and label in this game carries; no plate behind it.
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = math.max(2, size * 0.14)
		stroke.Color = Theme.Color.Outline
		stroke.Parent = label
		return label
	end

	local titleLabel = line("Title", 15, rarityColor(player:GetAttribute("TitleId")), 1)
	titleLabel.Text = tostring(player:GetAttribute("TitleTag") or "")
	titleLabel.Visible = titleLabel.Text ~= ""

	local nameLabel = line("PlayerName", 20, Theme.Color.White, 2)
	nameLabel.Text = player.DisplayName

	billboard.Parent = head
	return billboard
end

local function refresh(player: Player)
	local character = player.Character
	if character == nil then
		return
	end
	local head = character:FindFirstChild("Head")
	local billboard = if head then head:FindFirstChild(NAMEPLATE) else nil
	if billboard == nil then
		return
	end
	local label = billboard:FindFirstChild("Title")
	if label and label:IsA("TextLabel") then
		local tag = tostring(player:GetAttribute("TitleTag") or "")
		label.Text = tag
		label.Visible = tag ~= ""
		label.TextColor3 = rarityColor(player:GetAttribute("TitleId"))
	end
end

local function bind(player: Player)
	local function onCharacter(character: Model)
		--[[
			The Head arrives with the character, but a humanoid's parts can still be assembling; polling
			briefly is the same fix the plot signs use for replicated models.
		]]
		task.spawn(function()
			local deadline = os.clock() + 10
			while os.clock() < deadline do
				if buildNameplate(character, player) then
					break
				end
				task.wait(0.25)
			end
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				--- Ours replaces the engine's, or the name would be drawn twice at two sizes.
				humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
			end
		end)
	end

	if player.Character then
		onCharacter(player.Character)
	end
	player.CharacterAdded:Connect(onCharacter)
	player:GetAttributeChangedSignal("TitleTag"):Connect(function()
		refresh(player)
	end)
end

function TitleController.Start()
	if started then
		return
	end
	started = true

	for _, player in Players:GetPlayers() do
		bind(player)
	end
	Players.PlayerAdded:Connect(bind)

	--[[
		CHAT PREFIX.

		`OnIncomingMessage` runs on every client for every message, and returning `FluffChatProperties`
		with a `PrefixText` puts the tag in front of the speaker's name -- which is the one place Roblox
		lets a game decorate chat without replacing the whole window.

		The speaker is resolved through `TextSource.UserId` rather than the message text, because a
		display name is not unique and the tag has to belong to the person who actually spoke.
	]]
	local function decorate(message: TextChatMessage)
		local source = message.TextSource
		if source == nil then
			return nil
		end
		local player = Players:GetPlayerByUserId(source.UserId)
		if player == nil then
			return nil
		end
		local tag = tostring(player:GetAttribute("TitleTag") or "")
		if tag == "" then
			return nil
		end
		local properties = Instance.new("TextChatMessageProperties")
		--[[
			The colour is baked in as rich text: `PrefixText` is one string, so the only way to tint the
			tag differently from the name is markup inside it.
		]]
		local colour = rarityColor(player:GetAttribute("TitleId"))
		properties.PrefixText =
			string.format('<font color="#%s">%s</font> %s', colour:ToHex(), tag, message.PrefixText)
		return properties
	end

	TextChatService.OnIncomingMessage = decorate
end

return TitleController
