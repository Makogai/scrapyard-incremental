--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ClientPreferences = require(script.Parent.Parent.ClientPreferences)

local MagnetRangeController = {}
local SEGMENTS = 36

function MagnetRangeController.Start()
	local player = Players.LocalPlayer
	local folder = Instance.new("Folder")
	folder.Name = "LocalMagnetRange"
	folder.Parent = workspace
	local rings: { { BasePart } } = {}
	local currentRange = 18
	local advanced = false
	local function makeRing(color: Color3): { BasePart }
		local ring = {}
		for index = 1, SEGMENTS do
			local segment = Instance.new("Part")
			segment.Name = `RangeSegment_{index}`
			segment.Anchored = true
			segment.CanCollide = false
			segment.CanTouch = false
			segment.CanQuery = false
			segment.CastShadow = false
			segment.Material = Enum.Material.Neon
			segment.Color = color
			segment.Transparency = 0.44
			segment.Parent = folder
			table.insert(ring, segment)
		end
		table.insert(rings, ring)
		return ring
	end
	makeRing(Color3.fromRGB(52, 225, 255))
	makeRing(Color3.fromRGB(155, 83, 255))
	local function applyState(state)
		currentRange = state.DerivedStats.MagnetRange
		advanced = state.EquippedMagnet ~= "MagnetBasic"
		ClientPreferences.Update(state.Settings)
	end
	ReplicatedStorage.Remotes.StateChanged.OnClientEvent:Connect(applyState)
	local initial = ReplicatedStorage.Remotes.RequestInitialState:InvokeServer()
	if initial then
		applyState(initial)
	end
	local startedAt = os.clock()
	RunService.RenderStepped:Connect(function()
		local character = player.Character
		local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
		local visible = root ~= nil and ClientPreferences.Get("ScreenEffectsEnabled")
		local time = os.clock() - startedAt
		for ringIndex, ring in rings do
			local ringVisible = visible and (ringIndex == 1 or advanced)
			local radius = currentRange
				+ (if ringIndex == 2 then 0.7 else 0)
				+ math.sin(time * (if advanced then 3.4 else 2.2) + ringIndex) * 0.28
			local rotation = time * (if ringIndex == 1 then 0.32 else -0.5)
			for index, segment in ring do
				segment.Transparency = if ringVisible
					then 0.4 + 0.13 * math.sin(time * 4 + index * 0.45)
					else 1
				if ringVisible and root and root:IsA("BasePart") then
					local angle = ((index - 1) / SEGMENTS) * math.pi * 2 + rotation
					local position = root.Position
						+ Vector3.new(math.cos(angle) * radius, -2.85, math.sin(angle) * radius)
					segment.Size = Vector3.new(
						math.max(1.2, radius * 0.16),
						0.12,
						if advanced then 0.42 else 0.28
					)
					segment.CFrame = CFrame.new(position) * CFrame.Angles(0, -angle, 0)
				end
			end
		end
	end)
end

return table.freeze(MagnetRangeController)
