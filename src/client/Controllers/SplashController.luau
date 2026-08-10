--!nonstrict
--[[
	SplashController.luau
	Mounts the loading screen and decides when the game is ready.

	It owns its own ScreenGui rather than living inside the main UI tree, for two
	reasons: it must be up before the React app has mounted anything, and it must sit
	above it afterwards. Roblox's own loading screen is also removed here, so the
	player never sees the default one flash first.

	"Ready" is a list of real conditions, not a timer. The bar reports how many are
	met, so it finishes when the game finishes -- a bar that hits 100% and then waits
	is worse than no bar at all.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)

local SplashController = {}

local root: any = nil
local screenGui: ScreenGui? = nil

--[[
	The things worth waiting for, in the order a player would care about. Each
	returns true once it is satisfied; the bar is the fraction that are.

	Keep these cheap and non-yielding: they are polled.
]]
local function readinessSteps(): { { label: string, ready: () -> boolean } }
	return {
		{
			label = "Connecting...",
			ready = function()
				return ReplicatedStorage:FindFirstChild("Remotes") ~= nil
			end,
		},
		{
			label = "Loading your yard...",
			ready = function()
				local shared = ReplicatedStorage:FindFirstChild("Shared")
				return shared ~= nil and shared:FindFirstChild("UI") ~= nil
			end,
		},
		{
			label = "Loading pets...",
			ready = function()
				return ReplicatedStorage:FindFirstChild("PetModels") ~= nil
			end,
		},
		{
			label = "Waiting for your save...",
			ready = function()
				--[[
					The real gate. `Atoms.loaded` flips when the first authoritative
					snapshot lands, which is the moment the HUD would otherwise be
					showing zeroes as though they were real.
				]]
				local shared = ReplicatedStorage:FindFirstChild("Shared")
				local ui = shared and shared:FindFirstChild("UI")
				if ui == nil then
					return false
				end
				local ok, module = pcall(require, ui)
				return ok and module.Atoms.loaded() == true
			end,
		},
		{
			label = "Almost there...",
			ready = function()
				local character = Players.LocalPlayer.Character
				return character ~= nil and character.PrimaryPart ~= nil
			end,
		},
	}
end

--[[
	Start must not yield.

	It is called from the client bootstrap before every other controller, so any
	wait in here delays all of them -- the first version waited up to five seconds
	for `Shared`, which pushed `AdminController` past its own `WaitForChild` and
	logged an infinite-yield warning. Everything that can block now happens in the
	spawned task below.
]]
function SplashController.Start()
	local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if playerGui == nil then
		warn("[ScrapyardUI] no PlayerGui yet - splash skipped")
		return
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "ScrapyardSplash"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	-- Above the main UI's DisplayOrder (10) and TopbarPlus (20).
	gui.DisplayOrder = 100
	gui.Parent = playerGui
	screenGui = gui

	task.spawn(function()
		--[[
			Roblox's own chrome comes off for the duration. Guarded: this throws if the
			engine is not ready for it, and a failure here must not stop the splash.
		]]
		pcall(function()
			game:GetService("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.All, false)
		end)

		local shared = ReplicatedStorage:WaitForChild("Shared", 20)
		local uiFolder = shared and shared:WaitForChild("UI", 20)
		local ok, SplashScreen = pcall(function()
			return require(uiFolder.Screens.SplashScreen)
		end)
		if not ok then
			warn("[ScrapyardUI] splash screen failed to load: " .. tostring(SplashScreen))
			SplashController.Stop()
			return
		end

		root = ReactRoblox.createRoot(gui)

		local steps = readinessSteps()
		local function render(progress: number, status: string)
			root:render(React.createElement(SplashScreen, {
				progress = progress,
				status = status,
			}))
		end
		render(0, steps[1].label)
		print("[ScrapyardUI] splash shown")

		--[[
			Polled rather than event-driven: the conditions come from five unrelated
			systems, and a shared poll is far less code than five subscriptions that all
			have to be torn down. Twice a second is plenty for a progress bar.
		]]
		local deadline = os.clock() + 30
		while os.clock() < deadline do
			local done = 0
			local status = "Almost there..."
			for _, step in ipairs(steps) do
				if step.ready() then
					done += 1
				else
					status = step.label
					break
				end
			end

			render(done / #steps, status)
			if done == #steps then
				break
			end
			task.wait(0.4)
		end

		--[[
			Always leaves, even if something never reported ready. A splash screen that
			can trap a player is a far worse bug than one that lifts early, so the
			30-second deadline above is a hard exit rather than a retry.
		]]
		render(1, "Ready!")
		task.wait(0.35)
		print("[ScrapyardUI] splash lifted")
		SplashController.Stop()
	end)
end

function SplashController.Stop()
	pcall(function()
		game:GetService("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.All, true)
	end)
	if root then
		root:unmount()
		root = nil
	end
	if screenGui then
		screenGui:Destroy()
		screenGui = nil
	end
end

-- Studio's Play Solo restarts scripts without restarting the session; make sure a
-- reload cannot leave an orphaned splash behind.
if RunService:IsStudio() then
	local existing = Players.LocalPlayer:FindFirstChild("PlayerGui")
	local stale = existing and existing:FindFirstChild("ScrapyardSplash")
	if stale then
		stale:Destroy()
	end
end

return SplashController
