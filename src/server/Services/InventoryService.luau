--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Environment = require(ReplicatedStorage.Shared.Config.Environment)
local RateLimiter = require(ReplicatedStorage.Shared.Utility.RateLimiter)
local PlayerStateService = require(script.Parent.PlayerStateService)
local RemoteService = require(script.Parent.RemoteService)

local InventoryService = {}
local limiter = RateLimiter.new(
	Environment.MaximumRemoteRequestsPerWindow,
	Environment.RemoteRateLimitWindowSeconds
)

local function clearHeld(character: Model)
	local existing = character:FindFirstChild("EquippedMagnet")
	if existing then
		existing:Destroy()
	end
end

local function attach(player: Player)
	local character = player.Character
	local state = PlayerStateService.GetPublicState(player)
	if character == nil or state == nil then
		return
	end
	clearHeld(character)
	local hand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
	local templates = ServerStorage:FindFirstChild("MagnetModels")
	local template = templates and templates:FindFirstChild(state.EquippedMagnet)
	if hand == nil or not hand:IsA("BasePart") or template == nil then
		return
	end
	local magnet = template:Clone()
	magnet.Name = "EquippedMagnet"
	magnet.Parent = character
	local target = hand.CFrame
		* CFrame.new(0, -0.85, -0.25)
		* CFrame.Angles(0, math.rad(90), math.rad(90))
	if magnet:IsA("Model") then
		magnet:PivotTo(target)
	elseif magnet:IsA("BasePart") then
		magnet.CFrame = target
	else
		magnet:Destroy()
		return
	end
	local parts = if magnet:IsA("BasePart") then { magnet } else {}
	if magnet:IsA("Model") then
		for _, descendant in magnet:GetDescendants() do
			if descendant:IsA("BasePart") then
				table.insert(parts, descendant)
			end
		end
	end
	for _, part in parts do
		part.Anchored = false
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.Massless = true
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = hand
		weld.Part1 = part
		weld.Parent = part
	end
end

local function attachWhenReady(player: Player)
	task.spawn(function()
		for _ = 1, 40 do
			if player.Parent ~= Players then
				return
			end
			if PlayerStateService.GetPublicState(player) ~= nil and player.Character ~= nil then
				attach(player)
				return
			end
			task.wait(0.25)
		end
	end)
end

function InventoryService.Start()
	local remote = RemoteService.GetEvent("InventoryAction")
	remote.OnServerEvent:Connect(function(player, action, itemId)
		if
			typeof(action) ~= "string"
			or typeof(itemId) ~= "string"
			or not limiter:Allow(tostring(player.UserId))
		then
			return
		end
		local success, message
		if action == "EquipMagnet" then
			success, message = PlayerStateService.TryEquipMagnet(player, itemId)
		elseif action == "UseConsumable" then
			success, message = PlayerStateService.TryUseConsumable(player, itemId)
		else
			return
		end
		RemoteService.GetEvent("Notify"):FireClient(player, message)
		if success then
			attach(player)
		end
	end)
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function()
			attachWhenReady(player)
		end)
	end)
	for _, player in Players:GetPlayers() do
		player.CharacterAdded:Connect(function()
			attachWhenReady(player)
		end)
		if player.Character then
			attachWhenReady(player)
		end
	end
	Players.PlayerRemoving:Connect(function(player)
		limiter:Remove(tostring(player.UserId))
	end)
end

return table.freeze(InventoryService)
