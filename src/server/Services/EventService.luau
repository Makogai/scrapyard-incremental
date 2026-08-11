--!strict
--[[
	EventService.luau
	Watches the event schedule and tells everyone when it turns over.

	IT DOES NOT DECIDE ANYTHING. The schedule in `EventConfig` is a pure function of UTC time, so the
	multipliers are already live the instant a window opens -- `derivedStats` reads the same function
	on every recompute, with no service involved. That means this service cannot be the thing that
	"forgets" to start an event, and a server that somehow fails to run it still pays out correctly.

	What it does own is NOTICING, which is a different job:

		- Push a fresh snapshot to everyone when the window turns over, so the HUD banner changes at the
		  same moment the multipliers do.
		- Publish the live AND next event to `ReplicatedStorage.EventState`, which is what the world
		  billboard reads.
		- Announce it once, so a player already in-game sees it start rather than discovering it.

	Polling, not scheduling. A `task.delay` to the exact boundary sounds tighter but breaks in the two
	cases that matter: a server that starts mid-event, and a schedule edited during a live session. A
	cheap poll is correct in both and costs one comparison every few seconds.

	Nothing is needed on join: a joining player gets the event in their own initial snapshot, and their
	arrival does not change what is live -- so no `PushAll` here, which would re-broadcast to the whole
	server every time anyone walks in.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EventConfig = require(ReplicatedStorage.Shared.Config.EventConfig)
local PlayerStateService = require(script.Parent.PlayerStateService)
local RemoteService = require(script.Parent.RemoteService)

local EventService = {}

--- How often the schedule is checked. The banner may lag a window edge by at most this long.
local POLL_SECONDS = 5

--[[
	WHERE THE WORLD READS THE SCHEDULE FROM.

	The player's snapshot carries the live event, which is what the HUD strip needs. The world billboard
	needs something else: BOTH what is on now and what is next, because it is the surface that teaches
	the cadence while the HUD only announces the moment.

	Published as attributes on a folder in `ReplicatedStorage` rather than on the billboard model itself.
	Attributes replicate, any number of billboards can read them, and none of it breaks if the map is
	rearranged -- which a model-attached version would.
]]
local STATE_FOLDER = "EventState"

--- The id we last told clients about, so a turnover is detected rather than re-announced forever.
local lastEventId: string? = nil
local started = false

--- The live event, or nil. Anything server-side that wants the current event asks here.
function EventService.Current(): (EventConfig.EventDefinition?, number)
	return EventConfig.activeAt(os.time())
end

--- The published folder, created on first use so `Start` order cannot matter.
local function stateFolder(): Folder
	local existing = ReplicatedStorage:FindFirstChild(STATE_FOLDER)
	if existing and existing:IsA("Folder") then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = STATE_FOLDER
	folder.Parent = ReplicatedStorage
	return folder
end

--[[
	Publish both halves of the schedule.

	ABSOLUTE TIMESTAMPS, not remaining seconds. A "seconds left" attribute would need rewriting every
	second and would still be stale between writes; an end time is written once per window and every
	client can count down from it against the same server clock.
]]
local function publish()
	local now = os.time()
	local folder = stateFolder()
	local live, remaining = EventConfig.activeAt(now)
	local upcoming, wait = EventConfig.nextAt(now)
	folder:SetAttribute("LiveId", if live then live.Id else "")
	folder:SetAttribute("LiveEndsAt", if live then now + remaining else 0)
	folder:SetAttribute("NextId", if upcoming then upcoming.Id else "")
	folder:SetAttribute("NextStartsAt", if upcoming then now + wait else 0)
end

--[[
	Announce a turnover.

	`Notify` carries a PLAIN STRING by contract -- see AGENTS.md rule 13, which exists because a table
	on this remote once took down the entire UI. `Announce` is the one that takes a table.
]]
local function announce(definition: EventConfig.EventDefinition?)
	if definition == nil then
		return
	end
	local announceEvent = RemoteService.GetEvent("Announce")
	announceEvent:FireAllClients({
		Title = definition.Title,
		Body = definition.Detail,
		Glyph = definition.Glyph,
		Accent = definition.Accent,
	})
end

function EventService.Start()
	if started then
		return
	end
	started = true

	--[[
		The turnover check.

		On the FIRST pass this only records what is live -- it does not announce. A player joining
		mid-event should see the banner (which the snapshot gives them) without a popup claiming the
		event just started, and a server that boots during Scrap Rush would otherwise announce it to
		everyone who joins later too.
	]]
	local function poll(first: boolean)
		local definition = EventConfig.activeAt(os.time())
		local id = if definition then definition.Id else nil
		if id == lastEventId then
			return
		end
		lastEventId = id
		--- Snapshot first, popup second: the HUD should already be right when the popup names it.
		publish()
		PlayerStateService.PushAll()
		if not first then
			announce(definition)
		end
	end

	publish()
	poll(true)

	task.spawn(function()
		while true do
			task.wait(POLL_SECONDS)
			poll(false)
		end
	end)
end

return table.freeze(EventService)
