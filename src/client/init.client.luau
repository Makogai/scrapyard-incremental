--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Environment = require(ReplicatedStorage.Shared.Config.Environment)
local ScrapController = require(script.Controllers.ScrapController)
local AreaPromptController = require(script.Controllers.AreaPromptController)
local AudioController = require(script.Controllers.AudioController)
local MagnetRangeController = require(script.Controllers.MagnetRangeController)
local ReactUIController = require(script.Controllers.ReactUIController)
local SplashController = require(script.Controllers.SplashController)
local TopbarController = require(script.Controllers.TopbarController)
local PetFollowerController = require(script.Controllers.PetFollowerController)
local PlotSignController = require(script.Controllers.PlotSignController)
local TutorialArrowController = require(script.Controllers.TutorialArrowController)
local remotes = ReplicatedStorage:WaitForChild("Remotes")

assert(remotes:FindFirstChild("RequestInitialState"), "Initial-state remote is unavailable")
assert(remotes:FindFirstChild("StateChanged"), "State-change remote is unavailable")
assert(remotes:FindFirstChild("Notify"), "Notification remote is unavailable")

-- First, so it covers the rest of the bootstrap.
SplashController.Start()

ScrapController.Start()
AreaPromptController.Start()
--[[
	`AdminController` is no longer required or started. The authored `AdminUI` it drove has been
	replaced by `Screens/AdminScreen`, reached from a quiet unlabelled icon in the HUD. The file is
	still in the tree rather than deleted, so restoring the old panel is two lines if the new one turns
	out to be missing something.
]]
AudioController.Start()
MagnetRangeController.Start()

-- Replaces PackUIController. The authored PackGameplayUI is disabled at runtime
-- rather than deleted; see plan/UI_MIGRATION.md for the rollback.
ReactUIController.Start()
TopbarController.Start()

PetFollowerController.Start()
--[[
	After the React root: the plot signs render the same kit into world SurfaceGuis, and
	the plots have to have been assigned attributes by the server first.
]]
PlotSignController.Start()
--[[
	After ReactUIController: it reads the tutorial atoms, which only carry anything once the Bridge
	has pulled the first snapshot. Starting it earlier is harmless but pointless.
]]
TutorialArrowController.Start()

print(string.format("[%s] Client bootstrap ready", Environment.GameName))
