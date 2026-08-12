--!strict
--[[
	ServerRestartService.luau
	A staff-triggered restart countdown, and the shutdown at the end of it.

	WHAT IT ACTUALLY DOES. `BindToClose` already saves everyone when a server dies, so this is not about
	data safety -- it is about warning. A server that vanishes mid-pull reads as a crash; a server that
	counts down for thirty seconds reads as maintenance, and players stop reporting it as a bug.

	At zero it saves every session and then rejects new arrivals. It does NOT call `game:Shutdown()`:
	Roblox only allows that from a place with the right context and it is not available to a normal
	server script, so the honest thing is to save, teleport nobody, and let the empty server be reaped.
	`Countdown` is the visible product; the save is the important part.

	ONE COUNTDOWN AT A TIME. A second start replaces the first rather than racing it, so two admins
	pressing the button do not produce two timers ticking at each other.
]]

local Players = game:GetService("Players")

local RemoteService = require(script.Parent.RemoteService)
local PlayerStateService = require(script.Parent.PlayerStateService)

local ServerRestartService = {}

--- Bounds on what an admin may ask for. Ten seconds is enough to read; ten minutes is enough to finish.
ServerRestartService.MinimumSeconds = 10
ServerRestartService.MaximumSeconds = 600

local activeToken = 0
local endsAt: number? = nil
local startedBy = ""

local function publish()
	--[[
		Absolute end time rather than "seconds remaining", so the client ticks its own clock and a slow
		or dropped frame cannot make two players see different numbers. Same reasoning as the boost
		timers.
	]]
	RemoteService.GetEvent("ServerRestart"):FireAllClients({
		EndsAt = endsAt,
		StartedBy = startedBy,
	})
end

--- Whether a countdown is running, for the admin panel's own label.
function ServerRestartService.IsRunning(): boolean
	return endsAt ~= nil
end

function ServerRestartService.Cancel(): boolean
	if endsAt == nil then
		return false
	end
	activeToken += 1
	endsAt = nil
	startedBy = ""
	publish()
	return true
end

--[[
	Start (or restart) the countdown.

	Returns a message for the admin who pressed it, so the panel can say what happened rather than
	guessing.
]]
function ServerRestartService.Start(seconds: number, byName: string): (boolean, string)
	if typeof(seconds) ~= "number" or seconds ~= seconds then
		return false, "Invalid countdown"
	end
	local clamped = math.clamp(
		math.floor(seconds),
		ServerRestartService.MinimumSeconds,
		ServerRestartService.MaximumSeconds
	)

	activeToken += 1
	local token = activeToken
	endsAt = os.time() + clamped
	startedBy = byName
	publish()

	task.spawn(function()
		while true do
			task.wait(1)
			--- A newer countdown, or a cancel, invalidates this thread rather than fighting it.
			if token ~= activeToken then
				return
			end
			local remaining = (endsAt or 0) - os.time()
			if remaining <= 0 then
				break
			end
		end
		if token ~= activeToken then
			return
		end

		--[[
			Save everyone, then stop letting anyone else in. Saving first is the ordering that matters:
			a player who joins during the save would be loaded into a server about to disappear.
		]]
		--- Captured before `startedBy` is cleared below, so the kick can still name who did it.
		local startedByName = startedBy
		for _, player in Players:GetPlayers() do
			PlayerStateService.SaveNow(player)
		end
		endsAt = nil
		publish()
		pcall(function()
			Players.PlayerAdded:Connect(function(player)
				player:Kick("This server is restarting. Please rejoin.")
			end)
			for _, player in Players:GetPlayers() do
				--[[
					NAME THE CAUSE. A bare "server restarting" is indistinguishable from a crash or a bug --
					which is exactly how it was read the first time this fired in testing.
				]]
				player:Kick(
					`Server restarted by {if #startedByName > 0 then startedByName else "staff"}. Rejoin for the latest update.`
				)
			end
		end)
	end)

	return true, `RESTART IN {clamped}s`
end

--- Late joiners need the countdown too, or they see a calm server that is about to close.
function ServerRestartService.Bind()
	Players.PlayerAdded:Connect(function(player)
		if endsAt == nil then
			return
		end
		RemoteService.GetEvent("ServerRestart"):FireClient(player, {
			EndsAt = endsAt,
			StartedBy = startedBy,
		})
	end)
end

return table.freeze(ServerRestartService)
