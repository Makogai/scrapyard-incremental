--!nonstrict
--[[
	TopbarController.luau
	Registers the game's TopbarPlus icons.

	TopbarPlus (`ReplicatedStorage.TopbarPlus.Icon`) is a Studio-authored package
	with a PackageLink, so it is not in the Rojo tree and not a Wally dependency --
	see `docs/STUDIO_SETUP.md`. That means it can legitimately be missing from a
	fresh sync, so every call here is guarded: no topbar is a missing convenience,
	not a broken client.

		far left   UPDATES     -> changelog window
		centre     SHOP        -> teleport to the shop
		centre     MY PLOT     -> teleport home
		centre     LEADERBOARD -> teleport to the board
		right      INDEX       -> collection window
		right      SETTINGS    -> settings window

	The window icons are deliberately *not* in the left-hand menu grid. A window
	reachable from two places gets two different selected states, and TopbarPlus
	owns its own, so the grid would fight it.

	TWO KINDS OF ICON, and they behave differently on purpose:

	  windows    toggle, and their lit state is driven from the `screen` atom rather than from the
	             click -- so the icon also lets go when the window is closed by its X or by another
	             icon
	  teleports  fire and let go. There is nothing for them to stay lit about: the player is somewhere
	             else a moment later, and an icon still glowing for a trip that finished reads as a
	             stuck button.

	The three teleports were a React row (`Parts.TeleportBar`) floating in the middle of the topbar
	strip, deliberately positioned to sit in the gap Roblox's own chrome leaves. That worked, but it
	meant hand-placed pixels competing for a strip TopbarPlus already owns and arranges -- and it only
	existed on the desktop HUD, so a phone player had no travel buttons at all. TopbarPlus centres and
	spaces them itself, on every device.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UI = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UI"))
local Atoms = UI.Atoms

local TopbarController = {}

--[[
	`screen` is the id `actions.openScreen` takes; `image` is looked up in
	`Assets.Icons` so the topbar wears the same art as the rest of the UI. Order
	rises left to right within an alignment.
]]
local ICONS = {
	{
		name = "Updates",
		label = "UPDATES",
		screen = "changelog",
		align = "Left",
		glyph = "note",
		order = 1,
		caption = "What's new",
	},
	{
		name = "Index",
		label = "INDEX",
		screen = "collection",
		align = "Right",
		glyph = "book",
		order = 1,
		caption = "Scrap index",
	},
	{
		-- Icon only: the flat cog reads on its own, and a label next to it just
		-- widens the topbar for no information.
		name = "Settings",
		screen = "settings",
		align = "Right",
		glyph = "sliders",
		order = 2,
		caption = "Settings",
	},
}

--[[
	The centre travel icons.

	`destination` is the id `TeleportService` accepts -- "MyPlot", not "Home", which it silently
	rejects. Same glyph names the React buttons used, so the topbar wears the art the rest of the UI
	already associates with these three places.

	LEADERBOARD has no image and that is not an oversight: `trophy` has no asset behind it, so
	`imageFor` returns nil and TopbarPlus renders it as a label, exactly like UPDATES does. The
	purpose-made `Assets.Icons.teleportBoard` art is a wide gradient button PLATE rather than an icon,
	so it cannot stand in.
]]
local TELEPORTS = {
	{ name = "TeleportShop", label = "SHOP", destination = "Shop", glyph = "basket", order = 1 },
	{ name = "TeleportPlot", label = "MY PLOT", destination = "MyPlot", glyph = "home", order = 2 },
	{
		name = "TeleportBoard",
		label = "LEADERBOARD",
		destination = "Leaderboards",
		glyph = "trophy",
		order = 3,
	},
}

local icons: { [string]: any } = {}
local teleportIcons: { any } = {}
local connection: RBXScriptConnection? = nil
local unsubscribe: (() -> ())? = nil

--- The art for an icon, or nil when nothing is mapped and TopbarPlus should keep
--- its own default image.
local function imageFor(entry): string?
	local art = UI.Assets.icon(entry.glyph)
	return if art then art.id else nil
end

function TopbarController.Start()
	local topbarPlus = ReplicatedStorage:FindFirstChild("TopbarPlus")
	local iconModule = topbarPlus and topbarPlus:FindFirstChild("Icon")
	if not iconModule then
		warn("[ScrapyardUI] TopbarPlus not found - topbar icons unavailable")
		return
	end

	local ok, Icon = pcall(require, iconModule)
	if not ok then
		warn("[ScrapyardUI] TopbarPlus failed to load: " .. tostring(Icon))
		return
	end

	-- Above our own ScreenGui (DisplayOrder 10) so captions and dropdowns are not
	-- painted over by the HUD.
	pcall(function()
		Icon.setDisplayOrder(20)
	end)

	for _, entry in ipairs(ICONS) do
		local built = Icon.new():setName(entry.name):align(entry.align)
		if entry.label then
			built:setLabel(entry.label)
		end

		local image = imageFor(entry)
		if image then
			built:setImage(image)
		end
		if entry.caption then
			built:setCaption(entry.caption)
		end
		built:setOrder(entry.order)

		--[[
			Toggle rather than open: pressing a selected icon closes its window.
			The atom write is all this does -- React re-renders off the atom, so the
			topbar never touches the UI tree.
		]]
		built:bindEvent("selected", function()
			Atoms.screen(entry.screen)
			Atoms.detail(nil)
		end)
		built:bindEvent("deselected", function()
			if Atoms.screen() == entry.screen then
				Atoms.screen(nil)
			end
		end)

		icons[entry.screen] = built
	end

	for _, entry in ipairs(TELEPORTS) do
		local built = Icon.new():setName(entry.name):align("Center")
		built:setLabel(entry.label)

		local image = imageFor(entry)
		if image then
			built:setImage(image)
		end
		built:setCaption(`Travel to {string.lower(entry.label)}`)
		built:setOrder(entry.order)

		--[[
			Fire and let go. `deselect` is deferred rather than called inline: it runs while TopbarPlus is
			still inside its own selection handler, and re-entering the state machine from within it is
			how you get an icon that ends up lit anyway.
		]]
		built:bindEvent("selected", function()
			UI.Bridge.requestTeleport(entry.destination)
			task.defer(function()
				pcall(function()
					built:deselect()
				end)
			end)
		end)

		table.insert(teleportIcons, built)
	end

	--[[
		Mirror the atom back onto the icons. Without this, closing a window with
		its X would leave the icon lit, and opening one from the menu grid would
		leave every icon dark.
	]]
	unsubscribe = Atoms.subscribe(Atoms.screen, function(screen)
		for screenId, icon in pairs(icons) do
			local shouldBeSelected = screenId == screen
			if shouldBeSelected ~= icon.isSelected then
				if shouldBeSelected then
					icon:select("Atom", icon)
				else
					icon:deselect("Atom", icon)
				end
			end
		end
	end)

	-- Icons live in TopbarPlus's own ScreenGui, which survives respawns; ours does
	-- too, so nothing needs rebuilding. Clean up only when the player leaves.
	connection = Players.PlayerRemoving:Connect(function(player)
		if player == Players.LocalPlayer then
			TopbarController.Stop()
		end
	end)
end

function TopbarController.Stop()
	if unsubscribe then
		unsubscribe()
		unsubscribe = nil
	end
	if connection then
		connection:Disconnect()
		connection = nil
	end
	for screenId, icon in pairs(icons) do
		pcall(function()
			icon:destroy()
		end)
		icons[screenId] = nil
	end
	for index, icon in ipairs(teleportIcons) do
		pcall(function()
			icon:destroy()
		end)
		teleportIcons[index] = nil
	end
end

return TopbarController
