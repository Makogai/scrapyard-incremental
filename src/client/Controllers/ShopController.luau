--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local InventoryConfig = require(ReplicatedStorage.Shared.Config.InventoryConfig)

local ShopController = {}

function ShopController.Start()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local safeArea = playerGui:WaitForChild("ScrapyardUI"):WaitForChild("SafeArea")
	local menus = safeArea:WaitForChild("Menus")
	local menu = menus:WaitForChild("MagnetShopMenu") :: GuiObject
	local adminToggle = safeArea:FindFirstChild("AdminToggle") :: GuiObject?
	local card = menu:WaitForChild("AdvancedMagnetCard")
	local buy = card:WaitForChild("BuyButton") :: TextButton
	local price = card:WaitForChild("Price") :: TextLabel
	local definition = InventoryConfig.Magnets.AdvancedMagnet
	local currentState: any = nil
	price.Text = `$ {definition.ShopPrice}`
	local function render(state)
		currentState = state
		local owned = state.OwnedMagnets.AdvancedMagnet == true
		buy.Text = if owned
			then "OWNED"
			elseif state.Money >= definition.ShopPrice then "BUY MAGNET"
			else "NEED MORE CASH"
		buy.Active = not owned
		buy.BackgroundColor3 = if owned
			then Color3.fromRGB(73, 177, 86)
			elseif state.Money >= definition.ShopPrice then Color3.fromRGB(255, 188, 47)
			else Color3.fromRGB(148, 157, 166)
	end
	ReplicatedStorage.Remotes.StateChanged.OnClientEvent:Connect(render)
	ReplicatedStorage.Remotes.OpenMagnetShop.OnClientEvent:Connect(function()
		for _, other in menus:GetChildren() do
			if other:IsA("GuiObject") then
				other.Visible = other == menu
			end
		end
		menu.Visible = true
		if adminToggle then
			adminToggle.Visible = false
		end
		local state = ReplicatedStorage.Remotes.RequestInitialState:InvokeServer()
		if state then
			render(state)
		end
	end)
	menu.CloseButton.Activated:Connect(function()
		menu.Visible = false
		if adminToggle then
			adminToggle.Visible = true
		end
	end)
	buy.Activated:Connect(function()
		if buy.Active and currentState then
			ReplicatedStorage.Remotes.ShopAction:FireServer("BuyMagnet", "AdvancedMagnet")
		end
	end)
end

return table.freeze(ShopController)
