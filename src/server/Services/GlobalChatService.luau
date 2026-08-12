--!strict
--[[
	GlobalChatService.luau
	A chat channel that reaches every server, not just this one.

	Roblox's own chat is already global WITHIN a server -- `RBXGeneral` delivers to everyone here, and
	that works. What it cannot do is cross the server boundary: two players in different servers of the
	same experience never see each other. `MessagingService` is the piece that does, so this is a
	`Global` channel whose traffic goes out over a topic and comes back in on every server.

	HOW A MESSAGE TRAVELS. One path, whether the sender is next to you or on another server:

	  1. the player types in the Global channel; `ShouldDeliverCallback` runs here, on the server
	  2. it returns FALSE -- nothing is delivered by the normal path, including to the sender
	  3. the text is published on the topic
	  4. every server, THIS ONE INCLUDED, receives it
	  5. each server filters the text once per local recipient and sends them the result
	  6. the client draws it into the Global channel

	Step 2 is what makes step 5 the only way a message is ever shown, so there is no second code path to
	drift and no chance of a message appearing twice on the sending server.

	TEXT FILTERING IS NOT OPTIONAL. What arrives over the topic is raw text typed by a player on a
	machine we know nothing about, and Roblox requires text shown to a user to have been filtered FOR
	that user -- the same words are allowed between adults and blocked for a child. So it is filtered per
	recipient, on the receiving server, and a filter that fails drops the message for that recipient
	rather than falling back to the raw string.

	WHY A SEPARATE TAB rather than making the normal chat global. Every message would cross the topic,
	which multiplies traffic by the number of servers and puts other people's conversations in the
	middle of yours. A tab keeps local talk local and makes "everyone can see this" a deliberate choice.

	IN STUDIO THIS ONLY EVER TALKS TO ITSELF. `MessagingService` delivers between live servers of a
	published place; a Studio session is one server, so a message published here comes back here and
	nowhere else. That is enough to prove the whole path except the hop itself.
]]

local MessagingService = game:GetService("MessagingService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")
local TextService = game:GetService("TextService")

local RemoteService = require(script.Parent.RemoteService)

local GlobalChatService = {}

--- The channel players type into, and the topic its traffic rides on.
local CHANNEL_NAME = "Global"
local TOPIC = "GlobalChat"

--[[
	Longest message that may cross a server.

	`MessagingService` caps a payload at 1 KB and the rest of the payload -- name, title tag, user id --
	is a couple of hundred bytes, so this leaves room to spare. It is also simply a reasonable length for
	something everyone in the game is going to read.
]]
local MAXIMUM_LENGTH = 200

--[[
	How often one player may speak globally.

	Deliberately slower than local chat. A global line is seen by every player in the experience, so the
	cost of spam is multiplied by the server count -- and `MessagingService` has a per-topic quota that a
	single determined spammer could otherwise eat on everyone's behalf.
]]
local PLAYER_COOLDOWN_SECONDS = 3

--[[
	A whole-server ceiling on top of the per-player one.

	The quota is roughly `150 + 60 * players` publishes a minute for a topic. Six players at one message
	every three seconds is 120 a minute, comfortably under -- but a bug elsewhere that called this in a
	loop would blow through it and get the topic throttled for everyone, so the budget is enforced here
	rather than trusted.
]]
local SERVER_BUDGET_PER_MINUTE = 90

--- How long to wait for Roblox to build `TextChannels`, which it does after server scripts run.
local CHANNEL_WAIT_SECONDS = 30

local channel: TextChannel? = nil
local globalChatRemote: RemoteEvent? = nil
local lastSpokeAt: { [number]: number } = {}
local publishTimes: { number } = {}
--[[
	Messages already published, keyed by id.

	`ShouldDeliverCallback` runs once per RECIPIENT, so a message sent with five people in the server
	arrives here five times. Without this it would be published five times and everyone would see it
	five times.
]]
local publishedMessages: { [string]: number } = {}

--- Drop ids older than this, so the guard table cannot grow for the life of the server.
local SEEN_MESSAGE_SECONDS = 30

local function forgetOldMessages()
	local now = os.clock()
	for messageId, seenAt in publishedMessages do
		if now - seenAt > SEEN_MESSAGE_SECONDS then
			publishedMessages[messageId] = nil
		end
	end
end

--- Whether the server as a whole may publish again right now.
local function withinServerBudget(): boolean
	local now = os.clock()
	local kept = {}
	for _, at in publishTimes do
		if now - at < 60 then
			table.insert(kept, at)
		end
	end
	publishTimes = kept
	return #publishTimes < SERVER_BUDGET_PER_MINUTE
end

--[[
	Filter one message for one recipient.

	Two calls, both of which can throw: the first asks Roblox to analyse the text as coming from the
	sender, the second asks what THIS recipient is allowed to see of it. Returns nil when either fails,
	and nil means the recipient sees nothing -- never the unfiltered text.
]]
local function filterFor(text: string, fromUserId: number, toUserId: number): string?
	local ok, result = pcall(function()
		return TextService:FilterStringAsync(text, fromUserId, Enum.TextFilterContext.PublicChat)
	end)
	if not ok or result == nil then
		return nil
	end
	local shownOk, shown = pcall(function()
		return (result :: any):GetChatForUserAsync(toUserId)
	end)
	if not shownOk or type(shown) ~= "string" then
		return nil
	end

	--[[
		STUDIO ONLY, AND ONLY WHEN THE RESULT IS EMPTY.

		A live server returns the text with disallowed words replaced by `#`, so an EMPTY string means the
		filter never really ran -- which is what a local playtest does, because Studio is not connected to
		the filtering service. Measured: `GetChatForUserAsync` returns "" here for perfectly ordinary
		text, so without this branch global chat cannot be exercised in Studio at all and the feature
		looks broken rather than untested.

		`GetNonChatStringForBroadcastAsync` is the same text filtered for nobody in particular. That is NOT
		an acceptable substitute on a live server, which is exactly why the guard is `IsStudio` and not the
		empty string on its own.
	]]
	if shown == "" and RunService:IsStudio() then
		local broadcastOk, broadcast = pcall(function()
			return (result :: any):GetNonChatStringForBroadcastAsync()
		end)
		if broadcastOk and type(broadcast) == "string" then
			return broadcast
		end
	end
	return shown
end

--[[
	Hand a received global message to everyone on this server.

	The sender's own server runs this too, which is why they see their own line -- see the header.
]]
local function deliver(payload: { [string]: any })
	local remote = globalChatRemote
	if remote == nil then
		return
	end
	local text = payload.Text
	local fromUserId = tonumber(payload.UserId)
	if type(text) ~= "string" or text == "" or fromUserId == nil then
		return
	end

	for _, player in Players:GetPlayers() do
		--[[
			Filtered per recipient inside the loop, and deliberately not cached: the point of the call is
			that two players are allowed to see different things, so one result cannot serve both.
		]]
		local shown = filterFor(text, fromUserId, player.UserId)
		if shown ~= nil and shown ~= "" then
			remote:FireClient(player, {
				UserId = fromUserId,
				Name = tostring(payload.Name or "?"),
				Tag = tostring(payload.Tag or ""),
				TitleId = tostring(payload.TitleId or ""),
				Text = shown,
				--- So a client can mark messages from its own server differently if it ever wants to.
				Local = payload.JobId == game.JobId,
			})
		end
	end
end

--[[
	Publish what a player typed, and refuse to deliver it locally.

	ALWAYS returns false. The message is shown by `deliver` when it comes back off the topic, including
	on this server -- one path in, one path out.
]]
local function interceptAndPublish(message: TextChatMessage): boolean
	local source = message.TextSource
	if source == nil then
		return false
	end
	local player = Players:GetPlayerByUserId(source.UserId)
	if player == nil then
		return false
	end

	--- Once per message, not once per recipient.
	local messageId = message.MessageId
	if publishedMessages[messageId] ~= nil then
		return false
	end
	forgetOldMessages()
	publishedMessages[messageId] = os.clock()

	local text = string.sub(message.Text, 1, MAXIMUM_LENGTH)
	if text == "" then
		return false
	end

	local now = os.clock()
	local lastAt = lastSpokeAt[player.UserId]
	if lastAt ~= nil and now - lastAt < PLAYER_COOLDOWN_SECONDS then
		--[[
			Told, not silently swallowed. A global message that vanishes with no explanation reads as
			broken chat, and the player will simply type it again.
		]]
		local waited = math.ceil(PLAYER_COOLDOWN_SECONDS - (now - lastAt))
		local remote = globalChatRemote
		if remote then
			remote:FireClient(player, {
				System = `GLOBAL CHAT: wait {waited}s before sending again`,
			})
		end
		return false
	end

	if not withinServerBudget() then
		local remote = globalChatRemote
		if remote then
			remote:FireClient(
				player,
				{ System = "GLOBAL CHAT: too busy right now, try again shortly" }
			)
		end
		return false
	end

	lastSpokeAt[player.UserId] = now
	table.insert(publishTimes, now)

	local payload = {
		UserId = player.UserId,
		--- Display name, because that is what the rest of the game shows.
		Name = player.DisplayName,
		--- The worn title, read off the attribute `PlayerStateService.publishTitle` already sets.
		Tag = tostring(player:GetAttribute("TitleTag") or ""),
		TitleId = tostring(player:GetAttribute("TitleId") or ""),
		Text = text,
		JobId = game.JobId,
	}

	local ok, err = pcall(function()
		MessagingService:PublishAsync(TOPIC, payload)
	end)
	if not ok then
		--[[
			An unpublished place, an API outage, or a throttle. Deliver it locally so the message is not
			simply lost -- the sender's own server is still a real audience.
		]]
		warn(`[GlobalChatService] publish failed, delivering locally only: {tostring(err)}`)
		deliver(payload)
	end
	return false
end

local function addPlayer(player: Player)
	local target = channel
	if target == nil then
		return
	end
	local ok, err = pcall(function()
		target:AddUserAsync(player.UserId)
	end)
	if not ok then
		warn(`[GlobalChatService] could not add {player.Name} to {CHANNEL_NAME}: {tostring(err)}`)
	end
end

--[[
	Stand the channel up. Yields, so `Start` runs this on its own thread.

	Everything here is idempotent: a channel that already exists is adopted rather than replaced, so a
	second call cannot end up with two.
]]
local function build()
	local channels = TextChatService:WaitForChild("TextChannels", CHANNEL_WAIT_SECONDS)
	if channels == nil then
		warn("[GlobalChatService] no TextChannels folder -- global chat unavailable")
		return
	end

	local existing = channels:FindFirstChild(CHANNEL_NAME)
	if existing and existing:IsA("TextChannel") then
		channel = existing
	else
		local made = Instance.new("TextChannel")
		made.Name = CHANNEL_NAME
		made.Parent = channels
		channel = made
	end

	local target = channel
	if target == nil then
		return
	end
	target.ShouldDeliverCallback = interceptAndPublish

	--- Existing players first, then joiners. A player not in the channel cannot see or use the tab.
	for _, player in Players:GetPlayers() do
		addPlayer(player)
	end
	Players.PlayerAdded:Connect(addPlayer)

	local ok, err = pcall(function()
		MessagingService:SubscribeAsync(TOPIC, function(message: any)
			if type(message) == "table" and type(message.Data) == "table" then
				deliver(message.Data)
			end
		end)
	end)
	if not ok then
		--[[
			Subscribing is what makes this cross-server. Without it the channel still works as a second
			local channel, which is a degraded feature rather than a broken one -- so it warns and carries
			on rather than tearing the channel down.
		]]
		warn(`[GlobalChatService] could not subscribe to {TOPIC}, staying local: {tostring(err)}`)
	end
end

function GlobalChatService.Start()
	globalChatRemote = RemoteService.GetEvent("GlobalChat")

	--[[
		Channel tabs have to be on or a second channel is invisible: with tabs off the window shows one
		conversation and there is no way to switch. Set here rather than in Studio so the requirement
		travels with the code that depends on it.
	]]
	local tabs = TextChatService:FindFirstChild("ChannelTabsConfiguration")
	if tabs and tabs:IsA("ChannelTabsConfiguration") then
		tabs.Enabled = true
	else
		warn(
			"[GlobalChatService] no ChannelTabsConfiguration -- the Global tab will not be reachable"
		)
	end

	--- Cheap and non-yielding, so it stays on the bootstrap thread.
	Players.PlayerRemoving:Connect(function(player)
		lastSpokeAt[player.UserId] = nil
	end)

	--[[
		OFF THE BOOTSTRAP THREAD. `build` waits for a folder Roblox creates after server scripts run, and
		`init.server` starts the remaining services in sequence -- so waiting inline would hold up
		everything below this in that file for as long as the wait took.
	]]
	task.spawn(build)
end

return table.freeze(GlobalChatService)
