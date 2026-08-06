--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AdminConfig = require(ReplicatedStorage.Shared.Config.AdminConfig)

local AdminController = {}

function AdminController.Start()
	if not AdminConfig.IsAdmin(Players.LocalPlayer.UserId) then
		return
	end
	local gui = Players.LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("ScrapyardUI")
	local safeArea = gui:WaitForChild("SafeArea")
	local toggle = safeArea:WaitForChild("AdminToggle") :: GuiButton
	local panel = safeArea:WaitForChild("AdminPanel") :: GuiObject
	local close = panel:WaitForChild("CloseButton") :: GuiButton
	local target = panel:WaitForChild("TargetButton") :: TextButton
	local amount = panel:WaitForChild("AmountBox") :: TextBox
	local remote = ReplicatedStorage.Remotes:WaitForChild("AdminCommand") :: RemoteEvent
	local targetMode = "Self"

	toggle.Visible = true
	toggle.Activated:Connect(function()
		panel.Visible = not panel.Visible
	end)
	close.Activated:Connect(function()
		panel.Visible = false
	end)
	target.Activated:Connect(function()
		targetMode = if targetMode == "Self" then "All" else "Self"
		target.Text = `TARGET: {string.upper(targetMode)}`
	end)

	local commands = {
		AddMoneyButton = "AddMoney",
		AddGearsButton = "AddGears",
		UnlockAreasButton = "UnlockAllAreas",
		MaxUpgradesButton = "MaxUpgrades",
		ClearStorageButton = "ClearStorage",
		GrantTestItemsButton = "GrantTestItems",
	}
	for buttonName, command in commands do
		local button = panel:WaitForChild(buttonName) :: GuiButton
		button.Activated:Connect(function()
			remote:FireServer(command, tonumber(amount.Text), targetMode)
		end)
	end

	local reset = panel:WaitForChild("ResetTestProfileButton") :: TextButton
	reset.Activated:Connect(function()
		if reset:GetAttribute("ConfirmArmed") == true then
			reset:SetAttribute("ConfirmArmed", false)
			reset.Text = "RESET TEST PROFILE"
			remote:FireServer("ResetTestProfile", nil, "Self")
			return
		end
		reset:SetAttribute("ConfirmArmed", true)
		reset.Text = "CONFIRM FULL RESET"
		task.delay(5, function()
			if reset.Parent and reset:GetAttribute("ConfirmArmed") == true then
				reset:SetAttribute("ConfirmArmed", false)
				reset.Text = "RESET TEST PROFILE"
			end
		end)
	end)
end

return table.freeze(AdminController)
