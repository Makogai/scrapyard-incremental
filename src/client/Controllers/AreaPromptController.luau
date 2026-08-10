--!strict

local Players = game:GetService("Players")

local AreaPromptController = {}

local function refreshPlot(plot: Model)
	local isOwner = (plot:GetAttribute("OwnerUserId") or 0) == Players.LocalPlayer.UserId
	for _, descendant in plot:GetDescendants() do
		if descendant:IsA("BillboardGui") and descendant.Name == "GateBillboard" then
			descendant.Enabled = descendant.Enabled and isOwner
		end
	end
end

function AreaPromptController.Start()
	local plots = workspace:WaitForChild("NewMap"):WaitForChild("Plots")
	for _, plot in plots:GetChildren() do
		if plot:IsA("Model") then
			refreshPlot(plot)
			plot:GetAttributeChangedSignal("OwnerUserId"):Connect(function()
				refreshPlot(plot)
			end)
		end
	end
end

return table.freeze(AreaPromptController)
