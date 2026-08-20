--!strict
--[[
	PassPadController.luau
	Stepping on a pass pad opens the Roblox purchase dialog.

	WHY THIS IS ON THE CLIENT. `MarketplaceService:PromptGamePassPurchase` only opens the dialog when it is
	called locally -- a server cannot open a purchase prompt for somebody, which is the same trap that left
	every buy button in the React UI silently dead until it was fixed. So the touch is detected here.

	Nothing here is authoritative and nothing needs to be. `PassPadService` destroys the pads a player
	already owns, so a pad that still exists is a pad that is still for sale; and Roblox itself refuses a
	second purchase of a pass. The worst a tampered client achieves is opening a dialog for something it
	could have opened from the shop anyway.

	ONE PROMPT AT A TIME, and a cooldown per pad. `Touched` fires many times a second while a character
	stands on a plate, and without the guard a player who parks on a pad gets the dialog reopened the
	instant they dismiss it.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MonetizationConfig = require(ReplicatedStorage.Shared.Config.MonetizationConfig)

local PassPadController = {}

--- Must match `PassPadService.PAD_PASSES`; the pad names are what Studio has.
local PAD_PASSES: { [string]: string } = {
	["2X Money"] = "DoubleCash",
	["Auto Sell"] = "AutoSell",
	["2X Movement Speed"] = "PermanentSpeed",
}

--[[
	Long enough that dismissing the dialog while still standing on the plate does not immediately reopen
	it, short enough that a deliberate second attempt works without waiting around.
]]
local PROMPT_COOLDOWN_SECONDS = 4

local lastPromptAt: { [string]: number } = {}

local function padPassId(part: BasePart): string?
	--[[
		Walk up from the touched part to find the pad model. The trigger is a `Touch` MeshPart inside the
		pad, so the name we care about is an ancestor's -- and stopping at the first Model ancestor is what
		keeps this from matching the plot itself.
	]]
	local current: Instance? = part
	while current ~= nil and current ~= workspace do
		if current:IsA("Model") then
			local passId = PAD_PASSES[current.Name]
			if passId ~= nil then
				return passId
			end
		end
		current = current.Parent
	end
	return nil
end

function PassPadController.Start()
	local player = Players.LocalPlayer

	local function onTouched(part: BasePart)
		local passId = padPassId(part)
		if passId == nil then
			return
		end

		local definition = MonetizationConfig.Passes[passId]
		if definition == nil or definition.MarketplaceId <= 0 then
			return
		end

		local now = os.clock()
		if now - (lastPromptAt[passId] or 0) < PROMPT_COOLDOWN_SECONDS then
			return
		end
		lastPromptAt[passId] = now

		--[[
			`pcall`, because a mistyped or unpublished marketplace id throws rather than returning a
			failure -- and a pad in the world should not be able to error a player's client.
		]]
		pcall(function()
			MarketplaceService:PromptGamePassPurchase(player, definition.MarketplaceId)
		end)
	end

	--[[
		Bound to the CHARACTER rather than to the pads.

		Pads come and go: `PlotThemeService` rebuilds the yard on a theme change or a rebirth, and
		`PassPadService` destroys a pad the moment its pass is bought. Listening on the character's own
		parts means there is nothing to rebind when the world changes underneath -- and it costs one
		connection per limb instead of one per pad per plot.
	]]
	local function bind(character: Model)
		for _, part in character:GetDescendants() do
			if part:IsA("BasePart") then
				part.Touched:Connect(onTouched)
			end
		end
		character.DescendantAdded:Connect(function(descendant)
			if descendant:IsA("BasePart") then
				descendant.Touched:Connect(onTouched)
			end
		end)
	end

	if player.Character ~= nil then
		bind(player.Character)
	end
	player.CharacterAdded:Connect(bind)
end

return table.freeze(PassPadController)
