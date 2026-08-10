--[[
	Assets.luau
	One table to swap the procedural artwork for real images.

	The kit ships with every icon drawn from Frames so it works with nothing
	uploaded. When you have art, you do not touch a single screen: fill in an id
	here and it appears everywhere that icon is used.

	ICONS -- replaces a glyph everywhere it appears:

		Assets.Icons.magnet = "rbxassetid://123456789"

	Every magnet icon in the game -- inventory cards, upgrade rows, the HUD, the
	details panel, the topbar -- becomes that image. Sizes, layouts and tints stay
	exactly as they are.

	ART -- per-entity artwork, keyed by kind and id:

		Assets.Art["area:vehicle_graveyard"] = "rbxassetid://123456789"
		Assets.Art["pet:scrap_pup"]          = "rbxassetid://987654321"

	Screens look these up by the entity's id, so a card shows real art the moment
	one exists and falls back to its glyph until then.

	Both accept either a plain id string or a table for finer control:

		Assets.Icons.coin = { id = "rbxassetid://1", scale = 0.8 }
		Assets.Icons.lock = { id = "rbxassetid://2", color = Color3.new(1, 1, 1) }

	PLATES -- background artwork for chrome (button slabs, pill backgrounds,
	window frames):

		Assets.Plates.navButton = "rbxassetid://123456789"

	A blank id keeps the drawn panel, so clearing one never breaks a layout.

	Everything below was harvested from the authored `PackGameplayUI` before it
	was retired, so the React UI wears the same art the game already shipped.

	Bulk-load from anywhere (a config module, a server payload):

		Assets.set({ Icons = { magnet = "rbxassetid://1" }, Art = { ["pet:x"] = "…" } })
]]

local Assets = {}

export type Entry = {
	id: string,
	scale: number?, -- fraction of the icon box, default 0.66 (or 1 when plain)
	color: Color3?, -- ImageColor3 tint
}

--------------------------------------------------------------------------------
-- Icons. Keys match the glyph names in Glyphs.byName; blank means "keep the
-- procedural drawing".
--------------------------------------------------------------------------------

Assets.Icons = {
	--[[
		THE GAME ICON / SPLASH LOGO GOES HERE.
		Paste it as "rbxassetid://0000000000". Until then the loading screen draws a
		plain lettered placeholder.
	]]
	gameLogo = "rbxassetid://132420480175685",

	-- marks
	check = "",
	cross = "",
	plus = "",
	minus = "",
	arrow = "rbxassetid://124942061563632",
	chevron = "",
	star = "",

	-- currencies and progression
	coin = "rbxassetid://104065626751462",
	gear = "rbxassetid://18209577633",
	robux = "rbxassetid://140667728219031",
	upgrade = "rbxassetid://132836771612353",
	recycle = "rbxassetid://92276565351925", -- rebirth
	trophy = "",
	medal = "",

	-- gameplay
	magnet = "rbxassetid://79829676084935",
	potion = "rbxassetid://82464105206823",
	scrap = "rbxassetid://18209575992",
	crate = "",
	bolt = "",
	clock = "",
	lock = "rbxassetid://76174231274376",
	paw = "rbxassetid://128999253503446",
	pin = "rbxassetid://83509002299617", -- areas
	home = "rbxassetid://130068439240504",
	basket = "rbxassetid://114042671041972", -- gift
	bag = "rbxassetid://125806058579575", -- inventory
	-- Friend boost. Blank keeps the drawn two-figure glyph; drop an id here to replace it.
	friends = "",

	-- plot and chrome
	ground = "",
	fence = "",
	sign = "",
	palette = "",
	calendar = "",
	-- The authored window headers used this for their "index" mark.
	book = "rbxassetid://125806058579575",
	-- No changelog art existed in the authored pack; the UPDATES topbar icon runs
	-- label-only until an id lands here.
	note = "",
	sliders = "rbxassetid://9405931578", -- flat cog, used by the topbar button
}

--------------------------------------------------------------------------------
-- Plates. Background artwork for chrome that is a picture rather than an icon:
-- button slabs, pill backgrounds, window frames. A blank id keeps the drawn
-- panel, so clearing one of these never breaks a layout.
--------------------------------------------------------------------------------

Assets.Plates = {
	navButton = "rbxassetid://78555104368507", -- left-hand menu tile
	shopButton = "rbxassetid://117587860672439", -- the wide, glowing SHOP slab
	statPill = "rbxassetid://82980653538406", -- gears / rebirth readout
	teleportPlot = "rbxassetid://119889969970139",
	teleportShop = "rbxassetid://100479747836624",
	teleportBoard = "rbxassetid://88624399260308",

	storage = "rbxassetid://126844774267555",
	storageTrack = "rbxassetid://139284504774422",
	storageFill = "rbxassetid://101777025203528",

	windowHeader = "rbxassetid://120357659596561",
	windowClose = "rbxassetid://109252276132515",
	card = "rbxassetid://119569266796281",
	equippedTick = "rbxassetid://106429591760124",

	upgradeRow = "rbxassetid://119337499768190",
	upgradeLogo = "rbxassetid://71448824599971",
	upgradeBuy = "rbxassetid://134194813634107",
	upgradeSecondary = "rbxassetid://73440589642489",

	shopBuy = "rbxassetid://99243851896343",
	shopGift = "rbxassetid://128879018619128",
}

--------------------------------------------------------------------------------
-- Art, keyed "<kind>:<id>". Kinds used by the screens: magnet, skin, potion,
-- pet, area, shop, scrap, cosmetic.
--------------------------------------------------------------------------------

Assets.Art = {
	-- Upgrade rows. Keys are `UpgradeConfig.ById` ids.
	["upgrade:MagnetStrength"] = "rbxassetid://92124713803251",
	["upgrade:MagnetRange"] = "rbxassetid://121058962789707",
	["upgrade:StorageCapacity"] = "rbxassetid://93792537878170",
	["upgrade:MovementSpeed"] = "rbxassetid://122642391888202",
	["upgrade:ScrapValue"] = "rbxassetid://131695773496661",
	["upgrade:CollectionSpeed"] = "rbxassetid://133399223477204",
	["upgrade:ScrapFlow"] = "rbxassetid://73490734406899",
	["upgrade:Rarity"] = "rbxassetid://73490734406899", -- shared in the authored UI

	--[[
		Game pass icons, keyed by `MonetizationConfig.PassOrder` ids. Paste an id and
		it replaces that pass's glyph on its shop card; leave one blank and the glyph
		stays, so these can ship one at a time. The generation prompts, and the accent
		colour each icon has to sit against, are in `docs/ICON_PROMPTS.md`.
	]]
	["pass:DoubleCash"] = "rbxassetid://136753021470793",
	["pass:StoragePlus"] = "rbxassetid://70407724067119",
	["pass:FastCollector"] = "rbxassetid://79551795907555",
	["pass:QuantumMagnet"] = "",
	["pass:ExtraPetSlots"] = "rbxassetid://103179431409211",
	["pass:SingularityPet"] = "",
	["pass:DemonicGhostPet"] = "",
	["pass:SinisterLordPet"] = "",

	--[[
		Magnets and potions are deliberately absent: `InventoryConfig` already
		carries an `IconId` per item and `GameData` passes it straight through as
		`image`, which beats this table. Edit the config, not this file, for those.
	]]
} :: { [string]: string | Entry }

--------------------------------------------------------------------------------
-- Lookup
--------------------------------------------------------------------------------

local function resolve(value: (string | Entry)?): Entry?
	if value == nil then
		return nil
	end
	if type(value) == "string" then
		if value == "" then
			return nil
		end
		return { id = value }
	end
	if type(value) == "table" and value.id and value.id ~= "" then
		return value
	end
	return nil
end

--- Image entry for a glyph name, or nil to keep the procedural drawing.
function Assets.icon(name: string?): Entry?
	if not name then
		return nil
	end
	--[[
		Exact key first, then a lower-case fallback.

		This used to lower-case unconditionally, which worked only because every
		glyph name happened to be one lower-case word. The moment a camelCase key
		appeared -- `gameLogo` -- the lookup asked for `gamelogo`, found nothing, and
		the splash screen silently drew its placeholder over a perfectly good asset
		id. Exact-first means a key works under the name it was written with.
	]]
	local exact = Assets.Icons[name]
	if exact ~= nil then
		return resolve(exact)
	end
	return resolve(Assets.Icons[string.lower(name)])
end

--- Image id for a plate, or nil to keep the drawn panel.
function Assets.plate(name: string?): string?
	if not name then
		return nil
	end
	local entry = resolve(Assets.Plates[name])
	return if entry then entry.id else nil
end

--- Image entry for an entity, or nil when there is no art for it yet.
function Assets.art(kind: string, id: string?): Entry?
	if not id then
		return nil
	end
	return resolve(Assets.Art[kind .. ":" .. id])
end

--- Merges overrides in. Accepts `{ Icons = {...}, Art = {...} }`, or a flat
--- table of icon overrides.
function Assets.set(overrides: { [string]: any })
	local icons = overrides.Icons
	local art = overrides.Art
	local plates = overrides.Plates

	if not icons and not art and not plates then
		icons = overrides
	end

	if plates then
		for name, value in pairs(plates) do
			Assets.Plates[name] = value
		end
	end

	if icons then
		for name, value in pairs(icons) do
			-- Stored under the key it was given; `Assets.icon` matches exact-first.
			Assets.Icons[name] = value
		end
	end
	if art then
		for key, value in pairs(art) do
			Assets.Art[key] = value
		end
	end
end

--- Just the image id for an entity, or nil. This is what screens pass straight
--- into a card's `image` prop.
function Assets.imageId(kind: string, id: string?): string?
	local entry = Assets.art(kind, id)
	return if entry then entry.id else nil
end

--- True once any real art has been supplied. Handy for a startup log line.
function Assets.hasAny(): boolean
	for _, value in pairs(Assets.Icons) do
		if resolve(value) then
			return true
		end
	end
	for _, value in pairs(Assets.Plates) do
		if resolve(value) then
			return true
		end
	end
	for _, value in pairs(Assets.Art) do
		if resolve(value) then
			return true
		end
	end
	return false
end

return Assets
