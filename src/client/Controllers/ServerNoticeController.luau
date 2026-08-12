--!strict
--[[
	ServerNoticeController.luau
	Two server-wide notices, both landing in atoms the HUD renders:

		AdminBroadcast   a staff message everyone sees, with the sender's name and verified tick
		ServerRestart    a restart countdown, shown under the top bar

	NO UI IN HERE. Both write an atom and stop; `Hud/Parts` owns how they look, which keeps the one thing
	that has to be right -- the payload contract -- separate from the thing that gets restyled weekly.

	THE COUNTDOWN TICKS LOCALLY FROM AN ABSOLUTE END TIME. The server sends `EndsAt`, not "seconds left",
	so a dropped packet or a slow frame cannot leave two players seeing different numbers, and no
	per-second remote traffic is needed for a thing that is pure arithmetic once you know the deadline.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UI = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UI"))
local Atoms = UI.Atoms

local ServerNoticeController = {}

--[[
	How long a broadcast stays on screen.

	Long, because a staff message is rare and being missed is the failure mode. It is dismissible, so a
	player who has read it is not held hostage by the timer.
]]
local BROADCAST_SECONDS = 14

function ServerNoticeController.Start()
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local broadcast = remotes:WaitForChild("AdminBroadcast") :: RemoteEvent
	local restart = remotes:WaitForChild("ServerRestart") :: RemoteEvent

	--[[
		A token per broadcast, so a second message replaces the first instead of the first message's
		expiry wiping the second one off the screen a moment after it arrives.
	]]
	local broadcastToken = 0

	broadcast.OnClientEvent:Connect(function(payload)
		if typeof(payload) ~= "table" then
			return
		end
		local text = payload.Message
		if typeof(text) ~= "string" or #text == 0 then
			return
		end

		broadcastToken += 1
		local token = broadcastToken
		Atoms.broadcast({
			message = text,
			fromName = if typeof(payload.FromName) == "string" then payload.FromName else "STAFF",
			verified = payload.Verified == true,
			--- For the avatar and the rank badge. Both come from the server; neither is client-supplied.
			fromUserId = if typeof(payload.FromUserId) == "number" then payload.FromUserId else 0,
			role = if typeof(payload.Role) == "string" then payload.Role else "",
			--- "Gift" or nil. Decides whether this reads as a present or as somebody talking.
			kind = if typeof(payload.Kind) == "string" then payload.Kind else nil,
			receivedAt = os.clock(),
		})

		task.delay(BROADCAST_SECONDS, function()
			if token == broadcastToken then
				Atoms.broadcast(nil)
			end
		end)
	end)

	restart.OnClientEvent:Connect(function(payload)
		if typeof(payload) ~= "table" then
			Atoms.restart(nil)
			return
		end
		local endsAt = payload.EndsAt
		if typeof(endsAt) ~= "number" then
			--- A cancel arrives as a nil `EndsAt`, which is how the countdown is cleared.
			Atoms.restart(nil)
			return
		end
		Atoms.restart({
			endsAt = endsAt,
			startedBy = if typeof(payload.StartedBy) == "string" then payload.StartedBy else "",
		})
	end)

	--[[
		Clear the countdown once it has run out, so a server that survives the deadline -- a cancel that
		raced the timer, a shutdown that did not take -- does not leave "RESTARTING IN 0s" on screen
		forever.
	]]
	task.spawn(function()
		while true do
			task.wait(1)
			local current = Atoms.restart()
			if current ~= nil and os.time() >= current.endsAt then
				Atoms.restart(nil)
			end
		end
	end)
end

return table.freeze(ServerNoticeController)
