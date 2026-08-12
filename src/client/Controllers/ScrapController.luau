--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local ClientPreferences = require(script.Parent.Parent.ClientPreferences)

local ScrapController = {}

local function pivot(instance: Instance): CFrame?
	if instance:IsA("Model") then
		return instance:GetPivot()
	elseif instance:IsA("BasePart") then
		return instance.CFrame
	end
	return nil
end

local function setPivot(instance: Instance, value: CFrame)
	if instance:IsA("Model") then
		instance:PivotTo(value)
	elseif instance:IsA("BasePart") then
		instance.CFrame = value
	end
end

--------------------------------------------------------------------------------
-- "You cannot pull that"
--------------------------------------------------------------------------------

--[[
	WHICH PIECE, SHOWN ON THE PIECE.

	The toast already says why -- too heavy, or storage full -- but it cannot say which, and standing in a
	pile of eight with one radiator in it, "magnet too weak" is a riddle. So the server points at the exact
	model (see `REJECTION_FLASH_SECONDS` in `ScrapService`) and this tints it and shakes it.

	TWO REASONS, TWO COLOURS, because they need different actions from the player:

		TooHeavy     red    -- upgrade your magnet, or come back later
		StorageFull  amber  -- go and sell; nothing is wrong with this piece

	Held slightly LONGER than the server's re-send interval, so a player who stands still sees one
	continuous tint rather than a strobe. Each fresh signal replaces the previous hold.
]]
local SCRAP_REJECT_SECONDS = 1.45

local REJECT_LOOKS = {
	TooHeavy = { fill = Color3.fromRGB(255, 68, 68), outline = Color3.fromRGB(255, 176, 176) },
	StorageFull = { fill = Color3.fromRGB(255, 168, 46), outline = Color3.fromRGB(255, 219, 150) },
}

--- Pieces currently shaking, so overlapping signals cannot stack two shakes on one model.
local jiggling: { [Instance]: boolean } = {}

--[[
	A short shake, restored exactly.

	Moving a server-replicated part from the client is safe HERE for the same reason the attraction
	animation does it: the piece is anchored and the server never touches its CFrame again after the
	spawn, so a client-side change is not fought over. It is still restored explicitly rather than left
	to replication -- nothing would put it back, and a piece left an inch out of place every time you
	walked past would accumulate all session.

	Rotation only, about the piece's own centre. A positional shake on a piece resting on the floor reads
	as it sinking into the ground on the down-beat.
]]
local function jiggle(instance: Instance)
	if jiggling[instance] then
		return
	end
	local origin = pivot(instance)
	if origin == nil then
		return
	end
	jiggling[instance] = true

	task.spawn(function()
		local DURATION = 0.34
		local SWINGS = 3
		local PEAK = math.rad(9)
		local startedAt = os.clock()
		while true do
			local alpha = (os.clock() - startedAt) / DURATION
			if alpha >= 1 or instance.Parent == nil then
				break
			end
			--- Decaying sine: biggest on the first swing, settling to nothing rather than stopping dead.
			local swing = math.sin(alpha * math.pi * SWINGS * 2) * (1 - alpha) * PEAK
			setPivot(
				instance,
				origin * CFrame.Angles(0, 0, swing) * CFrame.Angles(swing * 0.4, 0, 0)
			)
			task.wait()
		end
		if instance.Parent ~= nil then
			setPivot(instance, origin)
		end
		jiggling[instance] = nil
	end)
end

--- The red-or-amber wash, replacing any hold already on this piece.
local function flagRejected(instance: Instance, reason: string)
	local look = REJECT_LOOKS[reason]
	if look == nil then
		return
	end
	local existing = instance:FindFirstChild("RejectHighlight")
	if existing then
		existing:Destroy()
	end
	local highlight = Instance.new("Highlight")
	highlight.Name = "RejectHighlight"
	highlight.FillColor = look.fill
	highlight.OutlineColor = look.outline
	highlight.FillTransparency = 0.55
	highlight.OutlineTransparency = 0
	--[[
		THROUGH walls and other scrap. A piece you cannot pull is often the one buried at the back of a
		pile, which is exactly the case where an occluded outline tells you nothing.
	]]
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Adornee = instance
	highlight.Parent = instance
	Debris:AddItem(highlight, SCRAP_REJECT_SECONDS)
	--- The shake is the attention-getter and is not repeated while one is already running.
	jiggle(instance)
end

function ScrapController.Start()
	local effect = ReplicatedStorage.Remotes:WaitForChild("GameplayEffect") :: RemoteEvent
	effect.OnClientEvent:Connect(function(effectName: string, first: any, second: any)
		if effectName == "NebulaSpawn" then
			if ClientPreferences.Get("ScreenEffectsEnabled") then
				local flash = Instance.new("ColorCorrectionEffect")
				flash.Name = "NebulaSpawnFlash"
				flash.Brightness = 0.18
				flash.Contrast = 0.08
				flash.Saturation = 0.35
				flash.TintColor = Color3.fromRGB(125, 255, 230)
				flash.Parent = Lighting
				TweenService:Create(
					flash,
					TweenInfo.new(1.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
					{
						Brightness = 0,
						Contrast = 0,
						Saturation = 0,
						TintColor = Color3.new(1, 1, 1),
					}
				):Play()
				Debris:AddItem(flash, 1.7)
			end
			return
		end
		if effectName == "Sold" then
			if ClientPreferences.Get("ScreenEffectsEnabled") then
				for _, plot in workspace.NewMap.Plots:GetChildren() do
					if plot:GetAttribute("OwnerUserId") == Players.LocalPlayer.UserId then
						local crusher = plot:FindFirstChild("Crusher", true)
						if crusher then
							local moving = { crusher:FindFirstChild("Top") }
							local teeth = crusher:FindFirstChild("Teeth")
							if teeth then
								for _, tooth in teeth:GetChildren() do
									table.insert(moving, tooth)
								end
							end
							for _, part in moving do
								if part and part:IsA("BasePart") then
									local original = part.CFrame
									local press = TweenService:Create(
										part,
										TweenInfo.new(
											0.12,
											Enum.EasingStyle.Quad,
											Enum.EasingDirection.In
										),
										{ CFrame = original * CFrame.new(0, -1.1, 0) }
									)
									press:Play()
									press.Completed:Once(function()
										TweenService:Create(
											part,
											TweenInfo.new(
												0.2,
												Enum.EasingStyle.Back,
												Enum.EasingDirection.Out
											),
											{ CFrame = original }
										):Play()
									end)
								end
							end
						end
						break
					end
				end
			end
			return
		end
		if effectName == "RejectScrap" then
			local instance = first :: Instance
			if typeof(instance) == "Instance" and instance:IsDescendantOf(workspace) then
				--[[
					Not gated on the particle or screen-effect preferences. This is not decoration: it is the
					only thing in the game that says WHICH piece is out of reach, and a player who turned
					effects down for performance still needs to be able to play.
				]]
				flagRejected(instance, tostring(second))
			end
			return
		end
		if effectName == "Collected" then
			if not ClientPreferences.Get("ParticlesEnabled") then
				return
			end
			local character = Players.LocalPlayer.Character
			local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
			if root and root:IsA("BasePart") then
				local colors = {
					Normal = Color3.fromRGB(155, 165, 170),
					Rare = Color3.fromRGB(73, 157, 255),
					Epic = Color3.fromRGB(185, 83, 255),
					Legendary = Color3.fromRGB(255, 188, 46),
					Nebula = Color3.fromRGB(90, 255, 225),
				}
				for index = 1, 6 do
					local spark = Instance.new("Part")
					spark.Name = "CollectionSpark"
					spark.Shape = Enum.PartType.Ball
					spark.Size = Vector3.new(0.34, 0.34, 0.34)
					spark.Material = Enum.Material.Neon
					spark.Color = colors[second] or colors.Normal
					spark.Anchored = true
					spark.CanCollide = false
					spark.CanQuery = false
					spark.CFrame = root.CFrame * CFrame.new(0, 0.5, -1)
					spark.Parent = workspace
					local angle = (index / 6) * math.pi * 2
					local target = spark.Position
						+ Vector3.new(
							math.cos(angle) * 2.4,
							1.5 + (index % 2),
							math.sin(angle) * 2.4
						)
					TweenService:Create(
						spark,
						TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
						{
							Position = target,
							Transparency = 1,
							Size = Vector3.new(0.08, 0.08, 0.08),
						}
					):Play()
					Debris:AddItem(spark, 0.55)
				end
			end
			return
		end
		local instance = first :: Instance
		local duration = second :: number
		if effectName ~= "AttractScrap" or not instance:IsDescendantOf(workspace) then
			return
		end
		local start = pivot(instance)
		if start == nil then
			return
		end
		if
			ClientPreferences.Get("ParticlesEnabled")
			and instance:GetAttribute("VariantId") ~= "Normal"
		then
			local highlight = Instance.new("Highlight")
			highlight.Name = "RareAttractionHighlight"
			highlight.FillColor = Color3.fromRGB(255, 235, 112)
			highlight.FillTransparency = 0.48
			highlight.OutlineTransparency = 0.15
			highlight.Adornee = instance
			highlight.Parent = instance
			Debris:AddItem(highlight, duration + 0.1)
		end
		local startedAt = os.clock()
		local connection: RBXScriptConnection?
		connection = RunService.RenderStepped:Connect(function()
			if not instance.Parent then
				if connection then
					connection:Disconnect()
				end
				return
			end
			local character = Players.LocalPlayer.Character
			local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
			if root == nil or not root:IsA("BasePart") then
				return
			end
			local alpha = math.clamp((os.clock() - startedAt) / duration, 0, 1)
			local eased = 1 - (1 - alpha) ^ 3
			local target = root.CFrame * CFrame.new(0, 0.5, -1)
			local arc = math.sin(alpha * math.pi) * 1.2
			setPivot(
				instance,
				start:Lerp(target, eased)
					* CFrame.new(0, arc, 0)
					* CFrame.Angles(0, alpha * math.pi * 2, math.sin(alpha * math.pi * 4) * 0.12)
			)
			if alpha >= 1 and connection then
				connection:Disconnect()
			end
		end)
	end)
end

return table.freeze(ScrapController)
