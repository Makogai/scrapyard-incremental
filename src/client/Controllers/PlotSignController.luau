--!nonstrict
--[[
	PlotSignController.luau
	Fills in each plot's owner card, and marks your own plot.

	THE CARD IS AUTHORED, NOT RENDERED. It lives in the place file as real instances:

		Plot0N.OwnerSign.Board
		  PlotSignSurface          SurfaceGui on the board's own front face
		    Card                   the artwork -- edit this in Studio, freely
		      AvatarWell.Avatar    ImageLabel, gets the owner's headshot
		      OwnerName            TextLabel
		      Stats                hidden on a free plot
		        Rebirths.Value     TextLabel
		        Cash.Value
		        Scrap.Value

	The marker over your own plot is authored the same way, as a `YourPlotMarker` BillboardGui
	on the plot's floor -- move it with `StudsOffsetWorldSpace`, restyle it freely; this only
	toggles who sees it and fills in the headshot. It has no background by design: the label
	carries a heavy outline instead of a panel.

	This controller only writes text and images into named children. Restyling either piece --
	colours, spacing, fonts, position, the lot -- is a Studio job and needs no code change.

	It used to render the UI kit into the surface with React, which looked the same in game
	but could not be seen or positioned in Edit, so it needed a separate stand-in preview.
	A stand-in always drifts from the thing it stands in for, so the authored card replaced
	both.

	The numbers come from attributes the server publishes on the `OwnerSign` (see
	`PlotBuildService`), so there is no remote and a late joiner gets current values with the
	plot.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.Shared.UI.Format)

local PlotSignController = {}

--- Attributes worth redrawing for. The server only writes when a value actually changed.
local WATCHED = { "Occupied", "OwnerUserId", "OwnerName", "Rebirths", "Money", "TotalScrap" }

--[[
	How long to keep looking for a sign's card before giving up.

	A rebuilt plot's `OwnerSign` arrives on the client as a Model whose descendants replicate over
	several frames, so a one-shot `FindFirstChild` right after the instance appears finds a bare
	Model and concludes the card is missing. That is exactly what happened: converting a plot left
	its sign reading AVAILABLE PLOT for the rest of the session, with
	"has no authored card" in the log, even though the card was there in the place file the whole
	time. Deferring one frame was not enough -- this has to actually wait.
]]
local CARD_WAIT_SECONDS = 10

--- Signs already bound, so a re-bind cannot stack a second set of connections on one instance.
local bound: { [Instance]: true } = {}

--[[
	Resolve `Card` under a sign, tolerating late replication. Yields, so call it from a task.

	The surface belongs on the board itself, which is flush by construction. An earlier version
	hung it on a thin plate floating in front, because the post used to stick out past the board's
	face; with the post moved back that is no longer needed. A plate is still tolerated if one is
	authored, so an older place file keeps working -- which is why this polls for either shape
	rather than using `WaitForChild` on one fixed path.
]]
local function waitForCard(sign: Instance): Instance?
	local deadline = os.clock() + CARD_WAIT_SECONDS
	repeat
		local board = sign:FindFirstChild("Board")
		if board then
			local surface = board:FindFirstChild("PlotSignSurface")
			if surface == nil then
				local plate = board:FindFirstChild("PlotSignPlate")
				surface = plate and plate:FindFirstChild("PlotSignSurface")
			end
			local card = surface and surface:FindFirstChild("Card")
			if card then
				return card
			end
		end
		task.wait(0.1)
	until os.clock() > deadline or sign.Parent == nil
	return nil
end

local function bindSign(sign: Instance)
	if bound[sign] then
		return
	end
	bound[sign] = true

	local card = waitForCard(sign)
	if card == nil then
		-- the sign was destroyed while we waited; a later one will bind in its place
		if sign.Parent == nil then
			bound[sign] = nil
			return
		end
		warn(
			`[PlotSignController] {sign:GetFullName()} has no authored card at `
				.. `Board/PlotSignSurface/Card after {CARD_WAIT_SECONDS}s -- nothing to fill in`
		)
		return
	end

	local name = card:FindFirstChild("OwnerName")
	local well = card:FindFirstChild("AvatarWell")
	local avatar = well and well:FindFirstChild("Avatar")
	local stats = card:FindFirstChild("Stats")

	local function valueOf(key: string): TextLabel?
		local group = stats and stats:FindFirstChild(key)
		local label = group and group:FindFirstChild("Value")
		return if label and label:IsA("TextLabel") then label else nil
	end

	local rebirths, cash, scrap = valueOf("Rebirths"), valueOf("Cash"), valueOf("Scrap")

	local function draw()
		local userId = sign:GetAttribute("OwnerUserId")
		local occupied = sign:GetAttribute("Occupied") == true
			and typeof(userId) == "number"
			and userId > 0

		if name and name:IsA("TextLabel") then
			name.Text = if occupied
				then string.upper(tostring(sign:GetAttribute("OwnerName"))) .. "'S YARD"
				else "AVAILABLE PLOT"
		end
		if avatar and avatar:IsA("ImageLabel") then
			--[[
				A thumbnail content URL rather than `GetUserThumbnailAsync`: no yield, no pcall,
				no retry, and Roblox caches it.
			]]
			avatar.Image = if occupied
				then `rbxthumb://type=AvatarHeadShot&id={userId}&w=150&h=150`
				else ""
		end
		--[[
			Hidden rather than zeroed on a free plot. Three zeroes read like a player who has
			achieved nothing, which is a worse thing to advertise than an empty sign.
		]]
		if stats then
			stats.Visible = occupied
		end
		if rebirths then
			rebirths.Text = Format.comma(sign:GetAttribute("Rebirths") or 0)
		end
		if cash then
			cash.Text = Format.money(sign:GetAttribute("Money") or 0)
		end
		if scrap then
			scrap.Text = Format.short(sign:GetAttribute("TotalScrap") or 0)
		end
	end

	draw()
	for _, attribute in WATCHED do
		sign:GetAttributeChangedSignal(attribute):Connect(draw)
	end
end

--[[
	The marker over your own plot.

	AUTHORED, like the sign card. Each plot carries a `PlotMarkerAnchor` part with a
	`YourPlotMarker` BillboardGui on it, so you can drag it to any height in Studio and
	restyle the chip, the label and the headshot well without touching code.

	This only decides who sees it and fills in the picture. A BillboardGui in the place file
	replicates to everyone, so the authored state is Enabled -- which is what makes it visible
	in Edit -- and every plot that is not yours gets switched off here.
]]
local function refreshMarker(plots: { Model }, isRetry: boolean?)
	local localPlayer = Players.LocalPlayer
	local missing: { Model } = {}
	for _, plot in plots do
		--[[
			Found recursively. The marker hangs off the plot's floor, and Plot04 keeps its
			`PlotFloor` nested under `Boundaries` rather than at the top level -- a direct-child
			lookup misses it, which is how every plot ended up showing a marker: the controller
			could not find any of them, so it never switched the other five off.
		]]
		local marker = plot:FindFirstChild("YourPlotMarker", true)
		if marker == nil or not marker:IsA("BillboardGui") then
			--[[
				Not a warning on the first look. A rebuilt plot's floor and marker replicate over
				several frames, so a marker that is simply not here yet is normal; the retry below
				catches it, and only a plot still missing one after that is worth reporting.
			]]
			table.insert(missing, plot)
			continue
		end

		local mine = plot:GetAttribute("OwnerUserId") == localPlayer.UserId
		marker.Enabled = mine

		local avatar = marker:FindFirstChild("Avatar", true)
		if avatar and avatar:IsA("ImageLabel") then
			avatar.Image = if mine
				then `rbxthumb://type=AvatarHeadShot&id={localPlayer.UserId}&w=150&h=150`
				else ""
		end
	end

	if #missing == 0 then
		return
	end
	if isRetry then
		for _, plot in missing do
			warn(`[PlotSignController] {plot.Name} has no YourPlotMarker to toggle`)
		end
		return
	end
	--[[
		One retry, once replication has had a moment. Only the plots that came up empty are
		re-checked, so a plot that genuinely has no marker authored still gets reported -- Plot04
		is currently one of those.
	]]
	task.delay(2, function()
		refreshMarker(missing, true)
	end)
end

function PlotSignController.Start()
	local map = workspace:FindFirstChild("NewMap")
	local root = if map then map:FindFirstChild("Plots") else nil
	if root == nil then
		warn("[PlotSignController] Workspace.NewMap.Plots missing -- no signs bound")
		return
	end

	local plots = {}
	for _, plot in root:GetChildren() do
		if plot:IsA("Model") and plot:GetAttribute("PlotId") ~= nil then
			table.insert(plots, plot)
			local sign = plot:FindFirstChild("OwnerSign")
			if sign then
				-- spawned: `bindSign` waits for the card to replicate
				task.spawn(bindSign, sign)
			end
		end
	end

	refreshMarker(plots)
	for _, plot in plots do
		plot:GetAttributeChangedSignal("OwnerUserId"):Connect(function()
			refreshMarker(plots)
		end)

		--[[
			Re-bind when the plot's geometry is replaced.

			Converting a plot to another theme clones in a whole new `OwnerSign` and a new
			`PlotFloor`, which leaves this controller holding references to destroyed instances --
			the symptom is a freshly converted plot whose sign reads AVAILABLE PLOT while the
			server has the owner's data on it.

			`bindSign` does the waiting now. An earlier version deferred a single frame and then
			read the card once, which is why this re-bind never actually fixed the defect: a
			Model's descendants replicate over several frames, so one frame later there was a bare
			`OwnerSign` with nothing under it yet, and the controller gave up for good.
		]]
		local pending = false
		plot.ChildAdded:Connect(function(child)
			if
				child.Name ~= "OwnerSign"
				and child.Name ~= "PlotFloor"
				and child.Name ~= "Boundaries"
			then
				return
			end
			if pending then
				return
			end
			pending = true
			task.defer(function()
				pending = false
				local sign = plot:FindFirstChild("OwnerSign")
				if sign then
					task.spawn(bindSign, sign)
				end
				refreshMarker(plots)
			end)
		end)
	end
end

return PlotSignController
