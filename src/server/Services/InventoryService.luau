--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Environment = require(ReplicatedStorage.Shared.Config.Environment)
local MagnetSkinBuilder = require(ReplicatedStorage.Shared.Utility.MagnetSkinBuilder)
local RateLimiter = require(ReplicatedStorage.Shared.Utility.RateLimiter)
local PlayerStateService = require(script.Parent.PlayerStateService)
local PlotThemeService = require(script.Parent.PlotThemeService)
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
	if hand == nil or not hand:IsA("BasePart") then
		return
	end
	--[[
		A worn skin replaces the held MODEL only. Strength and range still come from EquippedMagnet.
		Unknown or empty ActiveMagnetSkin falls through to MagnetModels the same way a missing
		Studio template used to: the player keeps a magnet in hand rather than nothing.
	]]
	local magnet: Instance? = nil
	local skinId = state.ActiveMagnetSkin
	if typeof(skinId) == "string" and skinId ~= "" then
		magnet = MagnetSkinBuilder.build(skinId)
	end
	if magnet == nil then
		local templates = ServerStorage:FindFirstChild("MagnetModels")
		local template = templates and templates:FindFirstChild(state.EquippedMagnet)
		if template == nil then
			return
		end
		magnet = template:Clone()
	end
	if magnet == nil then
		return
	end
	magnet.Name = "EquippedMagnet"
	magnet.Parent = character
	--[[
		Same pose for skins and real magnets. Skin models are built in AdvancedMagnet
		space (grip at origin, head in +X) so this rotation puts the grip in the palm.
	]]
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

function InventoryService.Refresh(player: Player)
	attach(player)
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
		elseif action == "UnequipMagnet" then
			success, message = PlayerStateService.TryUnequipMagnet(player, itemId)
		elseif action == "UseConsumable" then
			success, message = PlayerStateService.TryUseConsumable(player, itemId)
		elseif action == "SetPlotSkin" then
			--- `itemId` is a pass id, or "" to go back to the standard build.
			success, message = PlotThemeService.WearSkin(player, itemId)
		elseif action == "SetMagnetSkin" then
			--- `itemId` is a skin id, or "" for the equipped magnet's own look.
			success, message = PlayerStateService.TryWearMagnetSkin(player, itemId)
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
