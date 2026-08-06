--!strict

local Players = game:GetService("Players")

local PlayerStateService = require(script.Parent.PlayerStateService)
local PlotService = require(script.Parent.PlotService)

local SellService = {}
local lastSell: { [Player]: number } = {}

function SellService.Start()
	local plotRoot = assert(workspace:FindFirstChild("Plots"), "Workspace.Plots required")
	for _, plot in plotRoot:GetChildren() do
		if plot:IsA("Model") then
			local zone = plot:FindFirstChild("CrusherSellZone")
			if zone and zone:IsA("BasePart") then
				zone.Touched:Connect(function(hit)
					local character = hit:FindFirstAncestorOfClass("Model")
					local player = if character
						then Players:GetPlayerFromCharacter(character)
						else nil
					if player == nil or not PlotService.IsOwner(player, plot) then
						return
					end
					local now = os.clock()
					if now - (lastSell[player] or 0) < 0.75 then
						return
					end
					lastSell[player] = now
					PlayerStateService.TrySell(player)
				end)
			end
		end
	end
	Players.PlayerRemoving:Connect(function(player)
		lastSell[player] = nil
	end)
end

return table.freeze(SellService)
