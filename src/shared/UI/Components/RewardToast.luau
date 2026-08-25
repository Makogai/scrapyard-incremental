--!nonstrict
--[[
	RewardToast.luau
	"You got this" -- the banner that announces a single reward.

	Built for the spin wheel, which needed somewhere to say what you won once the COLLECT button was
	removed, but it is deliberately generic: anything that hands the player one thing can use it.
	Daily claims and playtime milestones are the obvious next callers.

	THE SHAPE. A wide pill with the accent gradient fading out to BOTH edges and a solid readable
	middle, an icon well on the left, and the reward in two lines: what it is, and what it does. The
	symmetrical fade is what makes it read as a banner rather than a card -- a card has edges, a banner
	arrives.

	The fade is two mirrored `UIGradient` transparency ramps rather than one: a single gradient can only
	go light-to-dark in one direction, so a symmetrical fall-off needs a pair. Both are horizontal, and
	neither rotates a frame, so nothing here can escape a clipping parent.

	WHY NOT A `Toast`. `Overlays.Toast` is the small stacking notification feed in the corner, capped at
	four and driven by the `Notify` remote. This is a single centred moment tied to an animation, and
	putting it in that queue would let a magnet warning push a jackpot off the screen.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)

local UI = script.Parent.Parent
local Assets = require(UI.Assets)
local FadeBanner = require(UI.Components.FadeBanner)
local InventoryConfig = require(ReplicatedStorage.Shared.Config.InventoryConfig)

local e = React.createElement

local RewardToast = {}

--[[
	Which glyph fronts a reward bundle.

	Money is the common case and gets the coin; spins get the wheel; anything with items gets the
	potion, because every consumable in the game is one. An explicit `glyph` always wins, so a caller
	with better information is never fighting this.
]]
--[[
	The IMAGE for a reward, when one exists, which beats any glyph.

	A reward that grants an item should show that item's own art -- `InventoryConfig` carries an
	`IconId` per consumable and magnet, and four different potions all drawing the generic `potion`
	glyph is four identical green flasks. Callers pass the result as `image`, which `Icon` prefers over
	`glyph`, so a missing id falls back to the glyph without any extra branching at the call site.

	Only for a SINGLE-item reward. A bundle has no one icon, so it keeps the generic glyph.
]]
function RewardToast.imageFor(reward: { [string]: any }): string?
	if reward.Items ~= nil then
		local onlyId: string? = nil
		for itemId in reward.Items do
			if onlyId ~= nil then
				onlyId = nil
				break
			end
			onlyId = itemId
		end
		if onlyId ~= nil then
			local definition = InventoryConfig.Consumables[onlyId]
				or InventoryConfig.Magnets[onlyId]
			local iconId = if definition then definition.IconId else nil
			if iconId ~= nil and iconId ~= "" then
				return iconId
			end
		end
	end

	--[[
		Money-only prizes (daily cash days, playtime rungs, wheel wedges) use the
		pack coin. The Pit shop cash crates set Glyph = "cash" themselves so they
		draw the bill stack instead.
	]]
	if reward.Money and reward.Items == nil and reward.Spins == nil then
		local entry = Assets.icon("coin")
		return if entry then entry.id else nil
	end

	return nil
end

function RewardToast.glyphFor(reward: { [string]: any }): string
	if reward.Glyph then
		return reward.Glyph
	end
	if reward.Spins then
		return "wheel"
	end
	if reward.Items then
		return "potion"
	end
	if reward.Gears then
		return "gear"
	end
	return "coin"
end

--[[
	The prize banner.

	Now a thin caller of `FadeBanner`, which is where the look lives. It was the first user of that
	treatment and for a while the only one, so the implementation sat here -- once the event strip and
	the notification feed wanted the same thing, keeping a second copy would have guaranteed they drift.

	props:
		title     "GOD POTION"        what you got
		detail    "+ $250,000"        optional second line
		glyph     icon name
		image     item art, which beats the glyph
		accent    Theme key, default Gold
		best      boolean?            adds the shine
		width     number?
]]
function RewardToast.Banner(props)
	return e(FadeBanner.Banner, {
		key = props.key or "RewardToast",
		title = props.title,
		detail = props.detail,
		--- Falls back to the coin: a reward banner with no art at all would read as a bug.
		glyph = props.glyph or (if props.image then nil else "coin"),
		image = props.image,
		accent = props.accent or "Gold",
		--[[
			HEAVIER THAN THE HUD SURFACES, deliberately.

			The default fade sits well back because the event strip and the toast feed are chrome that has
			to live over the game all day. This banner is a three-second moment announcing a prize -- it is
			the thing being looked at, not something to look past -- so it keeps very close to the solid
			centre it had before the treatment was shared.
		]]
		intensity = 0.1,
		shine = props.best == true,
		width = props.width,
		height = props.height,
		position = props.position,
		anchorPoint = props.anchorPoint,
		zIndex = props.zIndex,
	})
end

return RewardToast
