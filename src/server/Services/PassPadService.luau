--!strict
--[[
	PassPadService.luau
	The three pass pads standing on every plot, and taking them away once they are bought.

	AUTHORED IN THE PLOT VARIANTS. `Workspace.PlotVariants.<Variant>Plot` each carry three pad Models,
	which `PlotThemeService` clones onto a player's plot along with the rest of the yard:

		2X Money             -> DoubleCash
		Auto Sell            -> AutoSell
		2X Movement Speed    -> PermanentSpeed

	A pad is a Model with a `Mesh` (the plate), a `Touch` part (the trigger) and two Parts carrying
	BillboardGuis -- one titled, one showing the price. The price label is written from
	`MonetizationConfig` rather than authored, so a price change in the config cannot leave a stale number
	standing in the world telling players the wrong thing.

	THE PROMPT IS NOT HERE. `MarketplaceService:PromptGamePassPurchase` only opens the Roblox dialog when
	called on the client, so the touch that opens it lives in `PassPadController`. This service owns the
	half that has to be authoritative: which pads a player is allowed to see at all.

	REMOVAL IS THE POINT. A pad for a pass you already own is worse than clutter -- it invites a second
	purchase of something you cannot buy twice. Owned pads are destroyed off the plot, on every path that
	can change the answer: the plot being built, the plot being rebuilt by a theme change or a rebirth, and
	the moment a purchase lands.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MonetizationConfig = require(ReplicatedStorage.Shared.Config.MonetizationConfig)
local Format = require(ReplicatedStorage.Shared.UI.Format)
local PlayerStateService = require(script.Parent.PlayerStateService)
local PlotService = require(script.Parent.PlotService)

local PassPadService = {}

--[[
	Pad model name -> pass id.

	The names are what the artist typed in Studio, spaces and capitals included, so they are matched
	exactly rather than normalised: a rename in Studio should break this loudly here rather than quietly
	stop removing a pad.
]]
local PAD_PASSES: { [string]: string } = {
	["2X Money"] = "DoubleCash",
	["Auto Sell"] = "AutoSell",
	["2X Movement Speed"] = "PermanentSpeed",
}

--[[
	Write the price onto a pad from the config.

	A pad carries two BillboardGui label parts, and they are told apart by HEIGHT: the title sits above the
	price. That is the only signal that holds -- child order is not stable, and the two labels are both
	named `Text` inside identically named `Part`s.

	AN EARLIER VERSION MATCHED ON CONTENT, treating any all-digits label as the price. It failed on the
	authored text, whose price carried a leading glyph before the number, so the digit pattern never
	matched and BOTH labels were treated as titles -- every pad in the game ended up captioned twice, with
	no price. Position cannot silently mean the wrong thing in that way.
]]
local function writePrice(pad: Model, price: number)
	local labelParts = {}
	for _, child in pad:GetChildren() do
		if child:IsA("BasePart") and child:FindFirstChildWhichIsA("BillboardGui") ~= nil then
			table.insert(labelParts, child)
		end
	end
	if #labelParts ~= 2 then
		--- Not the authored shape. Leave it alone rather than guess which label is which.
		return
	end

	table.sort(labelParts, function(a, b)
		return a.Position.Y > b.Position.Y
	end)

	local priceLabel = labelParts[2]:FindFirstChild("Text", true)
	if priceLabel ~= nil and priceLabel:IsA("TextLabel") then
		--[[
			WITH THE ROBUX GLYPH. An earlier version wrote the bare number, which stripped the mark off every
			pad in the game -- a price with no currency on it is just a number sitting on a plate.
		]]
		priceLabel.Text = Format.robuxSymbol(price)
	end
end

--[[
	Every pad on a plot, as (model, passId) pairs.

	`GetDescendants` rather than `GetChildren`: `PlotThemeService` nests the converted yard under a
	`RuntimeObjects` folder, so a pad is not a direct child of the plot.
]]
local function padsOn(plot: Model): { { Pad: Model, PassId: string } }
	local found = {}
	for _, descendant in plot:GetDescendants() do
		if descendant:IsA("Model") then
			local passId = PAD_PASSES[descendant.Name]
			if passId ~= nil then
				table.insert(found, { Pad = descendant, PassId = passId })
			end
		end
	end
	return found
end

--[[
	Bring one plot in line with what its owner owns.

	Prices are refreshed on the way past, because this runs on every rebuild and is therefore the cheapest
	honest moment to correct a stale label.
]]
function PassPadService.Refresh(player: Player, plot: Model)
	local state = PlayerStateService.GetPublicState(player)
	local entitlements = if state ~= nil then state.Entitlements else nil

	for _, entry in padsOn(plot) do
		local definition = MonetizationConfig.Passes[entry.PassId]
		if definition == nil then
			continue
		end
		if entitlements ~= nil and entitlements[entry.PassId] == true then
			--- Owned: the pad goes, so it cannot be touched or read as still for sale.
			entry.Pad:Destroy()
		else
			writePrice(entry.Pad, definition.DisplayPrice)
		end
	end
end

--- After a purchase, for the one player who bought it. Cheap enough to call on any entitlement change.
function PassPadService.RefreshPlayer(player: Player)
	local plot = PlotService.GetPlot(player)
	if plot ~= nil then
		PassPadService.Refresh(player, plot)
	end
end

function PassPadService.Start()
	--[[
		Every path that can change which pads belong on a plot:

		`OnAppearanceRefreshed` covers the plot being assigned, an area unlock, a theme conversion and a
		rebirth -- all of them already funnel through it. A purchase does not, so `MonetizationService`
		calls `RefreshPlayer` directly.
	]]
	PlotService.OnAppearanceRefreshed(function(player, plot)
		PassPadService.Refresh(player, plot)
	end)
end

return table.freeze(PassPadService)
