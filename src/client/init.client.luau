--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Environment = require(ReplicatedStorage.Shared.Config.Environment)
local UIController = require(script.Controllers.UIController)
local ScrapController = require(script.Controllers.ScrapController)
local AreaPromptController = require(script.Controllers.AreaPromptController)
local AdminController = require(script.Controllers.AdminController)
local AudioController = require(script.Controllers.AudioController)
local ShopController = require(script.Controllers.ShopController)
local MagnetRangeController = require(script.Controllers.MagnetRangeController)
local MonetizationController = require(script.Controllers.MonetizationController)
local remotes = ReplicatedStorage:WaitForChild("Remotes")

assert(remotes:FindFirstChild("RequestInitialState"), "Initial-state remote is unavailable")
assert(remotes:FindFirstChild("StateChanged"), "State-change remote is unavailable")
assert(remotes:FindFirstChild("Notify"), "Notification remote is unavailable")

ScrapController.Start()
AreaPromptController.Start()
AudioController.Start()
UIController.Start()
AdminController.Start()
ShopController.Start()
MagnetRangeController.Start()
MonetizationController.Start()

print(string.format("[%s] Client bootstrap ready", Environment.GameName))
