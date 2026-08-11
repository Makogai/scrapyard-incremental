--!nonstrict
--[[
	EventBillboardController.luau
	Fills in the world event billboard.

	THE CARD IS AUTHORED, NOT RENDERED -- the same arrangement as the plot `OwnerSign`. It lives in the
	place file as real instances:

		NewMap.EventBilboard ... Screen
		  SurfaceGui
		    Card               the artwork -- restyle this in Studio, freely
		      Heading          "NEXT EVENT" / "HAPPENING NOW"
		      Title            the event name
		      Detail           what it does
		      Timer            counts down
		      Footnote         when it runs, in words

	This controller writes text into those five labels and nothing else. Colours, fonts, spacing and
	position are a Studio job and need no code change.

	WHY THE BILLBOARD AND NOT THE HUD. The HUD strip is for what is true right now; it shows a live
	event and nothing otherwise. A permanent strip counting down to Saturday is the same furniture the
	old fake banner was -- always on screen, never actionable. Anticipation belongs somewhere a player
	walks past and chooses to read, which is what a billboard in the world is.

	Nothing here rebinds on respawn: the billboard is world geometry, not character-attached.

	IT READS SERVER TIMESTAMPS, not its own clock. `EventService` publishes `LiveEndsAt` and
	`NextStartsAt` on `ReplicatedStorage.EventState` as absolute times; this counts down to them. A
	client with a wrong system clock gets a wrong countdown either way, but it can never disagree with
	the server about WHICH event is on -- which is the part that would make the sign a liar.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local EventConfig = require(ReplicatedStorage.Shared.Config.EventConfig)
local Format = require(ReplicatedStorage.Shared.UI.Format)

local EventBillboardController = {}

--- Named children the card must have. A missing one is skipped, not fatal.
local LABELS = { "Heading", "Title", "Detail", "Timer", "Footnote" }

--- Once a second is plenty for a countdown, and a `Heartbeat` write per frame would be waste.
local TICK_SECONDS = 1

--- Model names that count as an event billboard. The place file spells it with one L.
local BILLBOARD_NAMES = { EventBilboard = true, EventBillboard = true }

local cards: { { [string]: TextLabel } } = {}
local state: Folder? = nil
local started = false

--[[
	When each event runs, in words.

	Derived from the schedule rather than written twice: a duration under a day reads as a window on one
	weekday, anything longer as a span. `EventConfig` is the only place the times live.
]]
local DAY_NAMES = { "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday" }

local function scheduleText(definition): string
	local day = DAY_NAMES[definition.StartDay] or "?"
	if definition.DurationHours >= 24 then
		local endDay =
			DAY_NAMES[(definition.StartDay - 1 + math.floor(definition.DurationHours / 24)) % 7 + 1]
		return `Every {day} to {endDay}, UTC`
	end
	return string.format(
		"Every %s at %02d:00 UTC, for %d hour%s",
		day,
		definition.StartHour,
		definition.DurationHours,
		if definition.DurationHours == 1 then "" else "s"
	)
end

local function definitionById(id: string?)
	if id == nil or id == "" then
		return nil
	end
	for _, definition in ipairs(EventConfig.Events) do
		if definition.Id == id then
			return definition
		end
	end
	return nil
end

--- Collect the labels off one authored card, or nil if the card is not there (or not there yet).
local function collect(model: Instance): { [string]: TextLabel }?
	local card = nil
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant.Name == "Card" and descendant:IsA("GuiObject") then
			card = descendant
			break
		end
	end
	if card == nil then
		return nil
	end
	local found = {}
	for _, name in LABELS do
		local label = card:FindFirstChild(name)
		if label and label:IsA("TextLabel") then
			found[name] = label
		end
	end
	return if next(found) then found else nil
end

local function write(card: { [string]: TextLabel }, heading, title, detail, timer, footnote)
	local values = {
		Heading = heading,
		Title = title,
		Detail = detail,
		Timer = timer,
		Footnote = footnote,
	}
	for name, label in card do
		local value = values[name]
		if value ~= nil and label.Text ~= value then
			label.Text = value
		end
	end
end

local function refresh()
	if #cards == 0 or state == nil then
		return
	end
	local now = os.time()
	local liveId = state:GetAttribute("LiveId")
	local live = definitionById(if typeof(liveId) == "string" then liveId else nil)

	local heading, title, detail, timer, footnote
	if live then
		local endsAt = state:GetAttribute("LiveEndsAt")
		local remaining = math.max(0, (if typeof(endsAt) == "number" then endsAt else now) - now)
		heading = "HAPPENING NOW"
		title = live.Title
		detail = live.Detail
		timer = Format.timer(remaining)
		footnote = "Ends in"
	else
		local nextId = state:GetAttribute("NextId")
		local upcoming = definitionById(if typeof(nextId) == "string" then nextId else nil)
		if upcoming == nil then
			--- No schedule at all. Say so rather than leaving last week's event on the sign.
			for _, card in cards do
				write(card, "EVENTS", "NONE SCHEDULED", "", "", "")
			end
			return
		end
		local startsAt = state:GetAttribute("NextStartsAt")
		local wait = math.max(0, (if typeof(startsAt) == "number" then startsAt else now) - now)
		heading = "NEXT EVENT"
		title = upcoming.Title
		detail = upcoming.Detail
		timer = Format.timer(wait)
		footnote = scheduleText(upcoming)
	end

	for _, card in cards do
		write(card, heading, title, detail, timer, footnote)
	end
end

--[[
	Find every billboard in the world and keep looking as the map streams in.

	A `Model`'s descendants arrive over several frames, so a one-shot `FindFirstChild` after `ChildAdded`
	is a race -- the same one the plot signs hit. Polling for a few seconds is the fix that does not
	need to know how the map is built.
]]
local function bind(model: Instance)
	task.spawn(function()
		local deadline = os.clock() + 10
		while os.clock() < deadline do
			local card = collect(model)
			if card then
				table.insert(cards, card)
				refresh()
				return
			end
			task.wait(0.5)
		end
		warn(`[EventBillboard] {model.Name} has no Card to fill -- see EventBillboardController`)
	end)
end

function EventBillboardController.Start()
	if started then
		return
	end
	started = true

	task.spawn(function()
		--[[
			`EventState` is created by `EventService` on the server, so on a fast client it may not have
			replicated yet. Waiting is correct; giving up would leave the sign showing its authored
			placeholder for the rest of the session.
		]]
		state = ReplicatedStorage:WaitForChild("EventState", 30) :: Folder?
		if state == nil then
			warn("[EventBillboard] EventState never replicated -- billboard will not update")
			return
		end
		for _, attribute in { "LiveId", "LiveEndsAt", "NextId", "NextStartsAt" } do
			state:GetAttributeChangedSignal(attribute):Connect(refresh)
		end
		refresh()
	end)

	local function scan(parent: Instance)
		for _, child in ipairs(parent:GetChildren()) do
			if BILLBOARD_NAMES[child.Name] then
				bind(child)
			end
		end
		parent.ChildAdded:Connect(function(child)
			if BILLBOARD_NAMES[child.Name] then
				bind(child)
			end
		end)
	end

	scan(workspace)
	local map = workspace:FindFirstChild("NewMap")
	if map then
		scan(map)
	end

	--- One write a second: the only thing that changes between turnovers is the countdown.
	local accumulator = 0
	RunService.Heartbeat:Connect(function(delta)
		accumulator += delta
		if accumulator >= TICK_SECONDS then
			accumulator -= TICK_SECONDS
			refresh()
		end
	end)
end

return EventBillboardController
