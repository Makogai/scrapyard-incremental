--!strict
--[[
	WreckHudController.luau
	Mirrors the Pit wreck's integrity onto Charm so the HUD can draw it.

	No remote. The server writes `WreckIntegrity` / `WreckIntegrityMax` /
	`WreckShielded` attributes on the tagged `PitWreck` model; this copies them
	into client-owned atoms. Screens still only read `{ state, actions }`.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Atoms = require(ReplicatedStorage.Shared.UI.State.Atoms)

local WreckHudController = {}

local TAG = "PitWreck"
local started = false
local bound: Model? = nil
local connections: { RBXScriptConnection } = {}

local function clearHud()
	Atoms.wreckIntegrity(0)
	Atoms.wreckIntegrityMax(0)
	Atoms.wreckShielded(false)
end

local function disconnect()
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
	bound = nil
end

local function sync(model: Model)
	local current = model:GetAttribute("WreckIntegrity")
	local maximum = model:GetAttribute("WreckIntegrityMax")
	local paused = model:GetAttribute("WreckShielded")
	Atoms.wreckIntegrity(if typeof(current) == "number" then current else 0)
	Atoms.wreckIntegrityMax(if typeof(maximum) == "number" then maximum else 0)
	Atoms.wreckShielded(paused == true)
end

local function bind(model: Instance)
	if not model:IsA("Model") then
		return
	end
	if bound == model then
		return
	end
	disconnect()
	bound = model
	sync(model)
	table.insert(
		connections,
		model:GetAttributeChangedSignal("WreckIntegrity"):Connect(function()
			sync(model)
		end)
	)
	table.insert(
		connections,
		model:GetAttributeChangedSignal("WreckIntegrityMax"):Connect(function()
			sync(model)
		end)
	)
	table.insert(
		connections,
		model:GetAttributeChangedSignal("WreckShielded"):Connect(function()
			sync(model)
		end)
	)
	table.insert(
		connections,
		model.Destroying:Connect(function()
			if bound == model then
				disconnect()
				clearHud()
			end
		end)
	)
end

function WreckHudController.Start()
	if started then
		return
	end
	started = true
	clearHud()
	for _, inst in CollectionService:GetTagged(TAG) do
		bind(inst)
	end
	CollectionService:GetInstanceAddedSignal(TAG):Connect(bind)
	CollectionService:GetInstanceRemovedSignal(TAG):Connect(function(inst)
		if bound == inst then
			disconnect()
			clearHud()
		end
	end)
end

return table.freeze(WreckHudController)
