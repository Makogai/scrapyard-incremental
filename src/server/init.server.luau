--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Environment = require(ReplicatedStorage.Shared.Config.Environment)
local FoundationValidator = require(ReplicatedStorage.Shared.Utility.FoundationValidator)
local RemoteService = require(script.Services.RemoteService)
local InboxService = require(script.Services.InboxService)
local SocialRewardService = require(script.Services.SocialRewardService)
local LimitedStockService = require(script.Services.LimitedStockService)
local ServerRestartService = require(script.Services.ServerRestartService)
local PlayerStateService = require(script.Services.PlayerStateService)
local PlotService = require(script.Services.PlotService)
local ScrapService = require(script.Services.ScrapService)
local SellService = require(script.Services.SellService)
local UpgradeService = require(script.Services.UpgradeService)
local AreaService = require(script.Services.AreaService)
local AdminService = require(script.Services.AdminService)
local SettingsService = require(script.Services.SettingsService)
local PrestigeService = require(script.Services.PrestigeService)
local InventoryService = require(script.Services.InventoryService)
local CodeService = require(script.Services.CodeService)
local ShopService = require(script.Services.ShopService)
local MonetizationService = require(script.Services.MonetizationService)
local PetService = require(script.Services.PetService)
local LeaderboardService = require(script.Services.LeaderboardService)
local LeaderstatsService = require(script.Services.LeaderstatsService)
local GlobalChatService = require(script.Services.GlobalChatService)
local ArenaService = require(script.Services.ArenaService)
local TeleportService = require(script.Services.TeleportService)
local RichestPlayerService = require(script.Services.RichestPlayerService)
local PlotThemeService = require(script.Services.PlotThemeService)
local DailyRewardService = require(script.Services.DailyRewardService)
local PlaytimeRewardService = require(script.Services.PlaytimeRewardService)
local SpinService = require(script.Services.SpinService)
local FriendBoostService = require(script.Services.FriendBoostService)
local TutorialService = require(script.Services.TutorialService)
local EventService = require(script.Services.EventService)
local AchievementService = require(script.Services.AchievementService)

FoundationValidator.validate()
RemoteService.Start()
PlayerStateService.Start()
PlotService.Start()
ScrapService.Start()
SellService.Start()
UpgradeService.Start()
AreaService.Start()
AdminService.Start()
SettingsService.Start()
PrestigeService.Start()
InventoryService.Start()
CodeService.Start()
ShopService.Start()
MonetizationService.Start()
PetService.Start()
LeaderboardService.Start()
--[[
	After `PlayerStateService`: the columns are filled from the state push, so the folder exists before
	anything can change. It reads nothing back, so its position among the rest does not matter.
]]
LeaderstatsService.Start()
--- Owns the `Global` TextChannel and the MessagingService topic behind it.
GlobalChatService.Start()
--[[
	After `ScrapService`, which owns the public-scrap folder this registers, and after `EventService`, whose
	schedule it reads. It polls rather than being driven, so a late start only delays the first build.
]]
ArenaService.Start()
TeleportService.Start()
RichestPlayerService.Start()
--[[
	After PlotService: it subscribes to plot assignment so it can build each plot from the
	owner's saved theme. See docs/PLOT_UPGRADES.md.
]]
PlotThemeService.Start()
--[[
	Return-to-play systems. All five need PlayerStateService up, and nothing else -- they read and
	commit through it rather than touching data directly. See docs/GAME_AUDIT.md for why they exist.
]]
DailyRewardService.Start()
PlaytimeRewardService.Start()
SpinService.Start()
FriendBoostService.Start()
TutorialService.Start()
--[[
	Events last, and only for the announcement side: the multipliers are already live because
	`EventConfig` is a pure function of the clock, so a failure here costs a popup, not a payout.
]]
EventService.Start()
--[[
	Achievements last: they read every other system's numbers, so nothing here has to be running yet --
	the first poll is three seconds away and every service is up by then.
]]
AchievementService.Start()

--[[
	The mailbox, and the three services that feed or gate it.

	`InboxService` after `PlayerStateService` (it writes through it) and before `AdminService`, which routes
	gifts into it. `LimitedStockService` warms its DataStore cache on a slow timer, so it must be running
	before the first purchase can be processed.
]]
InboxService.Start()
SocialRewardService.Start()
LimitedStockService.Start()
ServerRestartService.Bind()
print(string.format("[%s] Server bootstrap ready", Environment.GameName))
