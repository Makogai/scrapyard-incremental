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
local EventBillboardController = require(script.Controllers.EventBillboardController)
local EventSoundController = require(script.Controllers.EventSoundController)
local TitleController = require(script.Controllers.TitleController)
local GlobalChatController = require(script.Controllers.GlobalChatController)
local EggHologramController = require(script.Controllers.EggHologramController)
local ServerNoticeController = require(script.Controllers.ServerNoticeController)
local SecretPetVfxController = require(script.Controllers.SecretPetVfxController)
local PassPadController = require(script.Controllers.PassPadController)
local WreckHudController = require(script.Controllers.WreckHudController)
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
--[[
	The world event billboard. Independent of the React UI: it fills an authored SurfaceGui from
	attributes the server publishes, so it needs neither the store nor the Bridge.
]]
EventBillboardController.Start()
--[[
	Same EventState folder as the billboard. Independent of the React UI: a start sting is
	world audio, not a window, and it must still play if the HUD is closed.
]]
EventSoundController.Start()
--[[
	Titles over heads and in chat. Reads Player attributes, so it needs neither the store nor the
	Bridge -- and it draws OTHER players' titles, which is the whole point of them.
]]
TitleController.Start()

--[[
	After `TitleController`, which owns `TextChatService.OnIncomingMessage` for local chat. This one only
	displays into its own channel, so the two do not collide -- but starting it second keeps the reading
	order the same as the dependency order.
]]
GlobalChatController.Start()

--[[
	Purely cosmetic and self-contained: it reads authored map geometry and needs neither the store, the
	Bridge nor any remote. Started last because nothing waits on it, and a podium that is not authored yet
	only warns.
]]
EggHologramController.Start()

--[[
	Server-wide notices and the Secret-pull burst. Both are listeners that write atoms or spawn world
	effects, so they need nothing started before them beyond the remotes folder they wait on.
]]
ServerNoticeController.Start()
SecretPetVfxController.Start()
--- Stepping on a plot pad opens the purchase dialog; the prompt has to be client-side.
PassPadController.Start()
--[[
	Pit wreck HP on the HUD. Reads CollectionService tags / attributes, writes
	client-owned atoms. Screens never touch this module.
]]
WreckHudController.Start()

print(string.format("[%s] Client bootstrap ready", Environment.GameName))
