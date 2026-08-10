--!nonstrict
--[[
	ReactUIController.luau
	Mounts the React UI kit and replaces the authored PackGameplayUI.

	Everything this controller does is create one ScreenGui and one React root.
	All screen content, state and remote wiring lives in Shared/UI -- so this file
	should stay this small. If it starts growing, the logic belongs in a screen or
	in State/Bridge instead.

	Migration note: the authored `PackGameplayUI` and its 1338-line
	PackUIController are superseded by this. PackUIController is no longer
	started; the authored ScreenGui is disabled at runtime rather than deleted so
	a rollback is one line and no Studio work is lost.

	Non-strict because the kit's React components take open prop tables. The rest
	of the client remains strict.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ReactUIController = {}

local root: any = nil

--- Hides the authored pack UI without destroying it, so rollback is trivial.
local function retireAuthoredUI(playerGui: PlayerGui)
	local pack = playerGui:FindFirstChild("PackGameplayUI")
	if pack and pack:IsA("ScreenGui") then
		pack.Enabled = false
	end
end

function ReactUIController.Start()
	local packages = ReplicatedStorage:WaitForChild("Packages", 30)
	local shared = ReplicatedStorage:WaitForChild("Shared", 30)
	if not packages or not shared then
		warn("[ScrapyardUI] Packages/Shared never replicated - UI not mounted")
		return
	end

	local React = require(packages:WaitForChild("React"))
	local ReactRoblox = require(packages:WaitForChild("ReactRoblox"))
	local UI = require(shared:WaitForChild("UI"))

	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	retireAuthoredUI(playerGui)

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "ScrapyardReactUI"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.DisplayOrder = 10

	-- Newer than IgnoreGuiInset; assigning it on an older engine would throw and
	-- take the whole bootstrap down.
	pcall(function()
		screenGui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	end)

	screenGui.Parent = playerGui

	root = ReactRoblox.createRoot(screenGui)

	local ok, err = pcall(function()
		root:render(React.createElement(UI.Root, {
			dev = RunService:IsStudio(),
		}))
	end)

	if ok then
		print(
			"[ScrapyardUI] React UI mounted"
				.. (if RunService:IsStudio() then " (dev panel: F2)" else "")
		)
	else
		warn("[ScrapyardUI] React UI failed to mount: " .. tostring(err))
	end
end

function ReactUIController.Stop()
	if root then
		root:unmount()
		root = nil
	end
end

return ReactUIController
