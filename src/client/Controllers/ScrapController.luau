--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
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

function ScrapController.Start()
	local effect = ReplicatedStorage.Remotes:WaitForChild("GameplayEffect") :: RemoteEvent
	effect.OnClientEvent:Connect(function(effectName: string, first: any, second: any)
		if effectName == "Sold" then
			if ClientPreferences.Get("ScreenEffectsEnabled") then
				for _, plot in workspace.Plots:GetChildren() do
					if plot:GetAttribute("OwnerUserId") == Players.LocalPlayer.UserId then
						local crusher = plot:FindFirstChild("StarterCrusher", true)
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
		if effectName == "Collected" then
			if not ClientPreferences.Get("ParticlesEnabled") then
				return
			end
			local character = Players.LocalPlayer.Character
			local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
			if root and root:IsA("BasePart") then
				local colors = {
					Normal = Color3.fromRGB(155, 165, 170),
					Silver = Color3.fromRGB(205, 220, 225),
					Gold = Color3.fromRGB(245, 190, 55),
					Rainbow = Color3.fromRGB(105, 225, 205),
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
