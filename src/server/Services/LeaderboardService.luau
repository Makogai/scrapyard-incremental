--!strict
--[[
	LeaderboardService.luau
	The three hub boards: playtime, rebirths, Robux spent.

	WHAT THIS EXPECTS IN STUDIO

		A model or part named Leaderboard_TopPlaytime / Leaderboard_TopRebirths /
		Leaderboard_TopRobux, anywhere under Workspace (historically under
		NewMap/Decorations/StairsLeaderboard/Leaderboards). A child named Screen is
		used as the SurfaceGui host when it is a BasePart; otherwise the first part
		on the board.

	The old writer walked a fixed six-deep path and then looked for Row01..Row10
	with children named Rank / PlayerName / Value. If any name had drifted, the
	boards stayed blank forever and never even warned. This now finds the boards
	by name, reuses an authored ScrollingFrame when one exists, and builds a live
	gui on the Screen part when it does not.

	Names come from the player who is on this server first (always works), then
	Players:GetNameFromUserIdAsync. Empty OrderedDataStores -- Studio with API
	off, or a brand-new development store -- fall back to whoever is connected,
	so a Play session still shows your name instead of ten empty slots.
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Environment = require(ReplicatedStorage.Shared.Config.Environment)
local PlayerStateService = require(script.Parent.PlayerStateService)

local LeaderboardService = {}

local UPDATE_INTERVAL_SECONDS = 60
local FIRST_REFRESH_SECONDS = 2
local DISPLAY_COUNT = 10
local ROW_HEIGHT = 52
local CANVAS = Vector2.new(420, 720)

local sessionCheckpoints: { [Player]: number } = {}
local nameCache: { [number]: string } = {}
local missingWarned = false

local storeSuffix = if RunService:IsStudio() or Environment.UseDevelopmentDataStore
	then "Development"
	else "Production"
local playtimeStore = DataStoreService:GetOrderedDataStore(`Scrapyard_Playtime_{storeSuffix}_v1`)
local rebirthStore = DataStoreService:GetOrderedDataStore(`Scrapyard_Rebirths_{storeSuffix}_v1`)
local robuxStore = DataStoreService:GetOrderedDataStore(`Scrapyard_RobuxSpent_{storeSuffix}_v1`)

type BoardEntry = { key: string, value: number }

local BOARDS = {
	{
		name = "Leaderboard_TopPlaytime",
		title = "TOP PLAYTIME",
		store = playtimeStore,
		format = function(value: number): string
			local minutes = math.floor(math.max(0, value) / 60)
			local hours = math.floor(minutes / 60)
			local days = math.floor(hours / 24)
			if days > 0 then
				return string.format("%dd %02dh", days, hours % 24)
			elseif hours > 0 then
				return string.format("%dh %02dm", hours, minutes % 60)
			end
			return string.format("%dm", minutes)
		end,
	},
	{
		name = "Leaderboard_TopRebirths",
		title = "TOP REBIRTHS",
		store = rebirthStore,
		format = function(value: number): string
			return `{math.floor(value)} REBIRTHS`
		end,
	},
	{
		name = "Leaderboard_TopRobux",
		title = "TOP ROBUX",
		store = robuxStore,
		format = function(value: number): string
			return `{math.floor(value)} R$`
		end,
	},
}

local function findNamed(name: string): Instance?
	local map = workspace:FindFirstChild("NewMap")
	if map then
		local underMap = map:FindFirstChild(name, true)
		if underMap then
			return underMap
		end
	end
	return workspace:FindFirstChild(name, true)
end

local function boardHost(board: Instance): BasePart?
	local screen = board:FindFirstChild("Screen", true)
	if screen and screen:IsA("BasePart") then
		return screen
	end
	if board:IsA("BasePart") then
		return board
	end
	return board:FindFirstChildWhichIsA("BasePart", true)
end

local function styleText(label: TextLabel, size: number, color: Color3, bold: boolean)
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.Font = if bold then Enum.Font.GothamBlack else Enum.Font.GothamBold
	label.TextSize = size
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.4
	label.TextStrokeColor3 = Color3.fromRGB(20, 12, 32)
	label.TextTruncate = Enum.TextTruncate.AtEnd
end

local function ensureRow(list: ScrollingFrame, rank: number): GuiObject
	local name = string.format("Row%02d", rank)
	local existing = list:FindFirstChild(name)
	if existing and existing:IsA("GuiObject") then
		return existing
	end

	local row = Instance.new("Frame")
	row.Name = name
	row.BackgroundColor3 = if rank <= 3
		then Color3.fromRGB(48, 32, 72)
		else Color3.fromRGB(28, 22, 44)
	row.BackgroundTransparency = 0.15
	row.BorderSizePixel = 0
	row.Size = UDim2.new(1, -8, 0, ROW_HEIGHT - 4)
	row.LayoutOrder = rank
	row:SetAttribute("LiveRow", true)

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = row

	local rankLabel = Instance.new("TextLabel")
	rankLabel.Name = "Rank"
	rankLabel.Size = UDim2.new(0, 48, 1, 0)
	rankLabel.TextXAlignment = Enum.TextXAlignment.Center
	styleText(rankLabel, 22, Color3.fromRGB(255, 220, 90), true)
	rankLabel.Parent = row

	local avatar = Instance.new("ImageLabel")
	avatar.Name = "Avatar"
	avatar.BackgroundColor3 = Color3.fromRGB(20, 16, 32)
	avatar.BorderSizePixel = 0
	avatar.Size = UDim2.fromOffset(40, 40)
	avatar.Position = UDim2.new(0, 52, 0.5, 0)
	avatar.AnchorPoint = Vector2.new(0, 0.5)
	avatar.Parent = row
	local avatarCorner = Instance.new("UICorner")
	avatarCorner.CornerRadius = UDim.new(0, 6)
	avatarCorner.Parent = avatar

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "PlayerName"
	nameLabel.Size = UDim2.new(1, -220, 1, 0)
	nameLabel.Position = UDim2.fromOffset(100, 0)
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	styleText(nameLabel, 22, Color3.fromRGB(255, 255, 255), true)
	nameLabel.Parent = row

	local valueLabel = Instance.new("TextLabel")
	valueLabel.Name = "Value"
	valueLabel.Size = UDim2.new(0, 112, 1, -4)
	valueLabel.Position = UDim2.new(1, -8, 0.5, 0)
	valueLabel.AnchorPoint = Vector2.new(1, 0.5)
	valueLabel.TextXAlignment = Enum.TextXAlignment.Right
	styleText(valueLabel, 18, Color3.fromRGB(160, 255, 140), false)
	valueLabel.Parent = row

	row.Parent = list
	return row
end

local function ensureList(board: Instance, title: string): ScrollingFrame?
	local existingList = board:FindFirstChildWhichIsA("ScrollingFrame", true)
	if existingList then
		local surface = existingList:FindFirstAncestorOfClass("SurfaceGui")
		if surface then
			surface.LightInfluence = 0
		end
		local authoredRows = 0
		for _, child in existingList:GetChildren() do
			if child:IsA("GuiObject") and not child:IsA("UIBase") then
				authoredRows += 1
			end
		end
		if authoredRows == 0 then
			for rank = 1, DISPLAY_COUNT do
				ensureRow(existingList, rank)
			end
		end
		return existingList
	end

	local host = boardHost(board)
	if host == nil then
		return nil
	end
	--[[
		A fully invisible part does not draw its SurfaceGui. The richest-player
		plaques hit this; bump just enough to keep the canvas on screen without
		making a transparent Screen opaque.
	]]
	if host.Transparency >= 1 then
		host.Transparency = 0.05
	end

	local gui = host:FindFirstChild("LiveLeaderboard")
	if gui == nil or not gui:IsA("SurfaceGui") then
		local made = Instance.new("SurfaceGui")
		made.Name = "LiveLeaderboard"
		local other = host:FindFirstChildWhichIsA("SurfaceGui")
		made.Face = if other then other.Face else Enum.NormalId.Front
		made.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
		made.CanvasSize = CANVAS
		made.LightInfluence = 0
		made.AlwaysOnTop = false
		made.ZOffset = 0.05
		made.ClipsDescendants = true
		made.Parent = host
		gui = made
		for _, child in host:GetChildren() do
			if child:IsA("SurfaceGui") and child ~= made then
				child.Enabled = false
			end
		end
	else
		gui.LightInfluence = 0
	end
	if not gui:IsA("SurfaceGui") then
		return nil
	end

	local header = gui:FindFirstChild("Header")
	if header == nil or not header:IsA("TextLabel") then
		local made = Instance.new("TextLabel")
		made.Name = "Header"
		made.Size = UDim2.new(1, 0, 0, 64)
		made.Text = title
		made.TextXAlignment = Enum.TextXAlignment.Center
		styleText(made, 28, Color3.fromRGB(255, 244, 105), true)
		made.BackgroundColor3 = Color3.fromRGB(36, 22, 56)
		made.BackgroundTransparency = 0.1
		made.Parent = gui
		header = made
	else
		header.Text = title
	end

	local list = gui:FindFirstChild("Rows")
	if list == nil or not list:IsA("ScrollingFrame") then
		local made = Instance.new("ScrollingFrame")
		made.Name = "Rows"
		made.BackgroundTransparency = 1
		made.BorderSizePixel = 0
		made.Size = UDim2.new(1, -12, 1, -72)
		made.Position = UDim2.fromOffset(6, 68)
		made.AutomaticCanvasSize = Enum.AutomaticSize.Y
		made.CanvasSize = UDim2.new()
		made.ScrollBarThickness = 6
		made.ScrollBarImageColor3 = Color3.fromRGB(180, 170, 200)
		made.Parent = gui
		local layout = Instance.new("UIListLayout")
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Padding = UDim.new(0, 4)
		layout.Parent = made
		list = made
	end
	if not list:IsA("ScrollingFrame") then
		return nil
	end

	for rank = 1, DISPLAY_COUNT do
		ensureRow(list, rank)
	end
	return list
end

local function namedText(row: Instance, names: { string }): TextLabel?
	for _, name in names do
		local child = row:FindFirstChild(name, true)
		if child and child:IsA("TextLabel") then
			return child
		end
	end
	return nil
end

local function textsByX(row: Instance): { TextLabel }
	local labels = {}
	for _, child in row:GetDescendants() do
		if child:IsA("TextLabel") and child.Name ~= "Header" then
			table.insert(labels, child)
		end
	end
	table.sort(labels, function(a, b)
		local ax = a.Position.X.Scale * 1000 + a.Position.X.Offset
		local bx = b.Position.X.Scale * 1000 + b.Position.X.Offset
		return ax < bx
	end)
	return labels
end

local function displayName(userId: number): string
	local cached = nameCache[userId]
	if cached then
		return cached
	end
	local online = Players:GetPlayerByUserId(userId)
	if online then
		nameCache[userId] = online.Name
		return online.Name
	end
	local succeeded, playerName = pcall(Players.GetNameFromUserIdAsync, Players, userId)
	if succeeded and type(playerName) == "string" and playerName ~= "" then
		nameCache[userId] = playerName
		return playerName
	end
	return `Player {userId}`
end

local function setRow(row: GuiObject, rank: number, userId: number?, valueText: string?)
	local rankLabel = namedText(row, { "Rank", "RankLabel", "Place" })
	local nameLabel = namedText(row, { "PlayerName", "Player", "Username", "Name", "DisplayName" })
	local valueLabel = namedText(row, { "Value", "Score", "Amount", "Stat", "Points" })
	if nameLabel == nil or valueLabel == nil or rankLabel == nil then
		local ordered = textsByX(row)
		if rankLabel == nil then
			rankLabel = ordered[1]
		end
		if nameLabel == nil then
			nameLabel = ordered[2] or ordered[1]
		end
		if valueLabel == nil then
			valueLabel = ordered[3] or ordered[#ordered]
		end
	end
	local avatar = row:FindFirstChild("Avatar", true)
	if avatar == nil or not avatar:IsA("ImageLabel") then
		local icon = row:FindFirstChild("Headshot", true) or row:FindFirstChild("Icon", true)
		avatar = if icon and icon:IsA("ImageLabel") then icon else nil
	end

	if rankLabel then
		rankLabel.Text = `#{rank}`
	end
	if userId == nil then
		if nameLabel then
			nameLabel.Text = "—"
		end
		if valueLabel then
			valueLabel.Text = "—"
		end
		if avatar and avatar:IsA("ImageLabel") then
			avatar.Image = ""
		end
		return
	end
	if nameLabel then
		nameLabel.Text = displayName(userId)
	end
	if valueLabel then
		valueLabel.Text = valueText or "0"
	end
	if avatar and avatar:IsA("ImageLabel") then
		local imageSucceeded, image = pcall(function()
			return Players:GetUserThumbnailAsync(
				userId,
				Enum.ThumbnailType.HeadShot,
				Enum.ThumbnailSize.Size100x100
			)
		end)
		avatar.Image = if imageSucceeded then image else ""
	end
end

local function readStore(store: OrderedDataStore): { BoardEntry }
	local succeeded, pages = pcall(function()
		return store:GetSortedAsync(false, DISPLAY_COUNT)
	end)
	if not succeeded or typeof(pages) ~= "Instance" then
		return {}
	end
	local current = (pages :: DataStorePages):GetCurrentPage()
	local entries: { BoardEntry } = {}
	for _, entry in current do
		local key = tostring(entry.key)
		local value = tonumber(entry.value)
		if value then
			table.insert(entries, { key = key, value = value })
		end
	end
	return entries
end

local function sessionPlaytime(player: Player): number
	local checkpoint = sessionCheckpoints[player]
	if checkpoint == nil then
		return 0
	end
	return math.max(0, math.floor(os.clock() - checkpoint))
end

--[[
	When the ordered store is empty, rank whoever is on this server so the board
	is never a blank slab in Studio or on a fresh production key.
]]
local function withOnlineFallback(
	entries: { BoardEntry },
	metricOf: (Player) -> number
): { BoardEntry }
	if #entries > 0 then
		return entries
	end
	local fallback: { BoardEntry } = {}
	for _, player in Players:GetPlayers() do
		table.insert(fallback, {
			key = tostring(player.UserId),
			value = metricOf(player),
		})
	end
	table.sort(fallback, function(a, b)
		if a.value == b.value then
			return a.key < b.key
		end
		return a.value > b.value
	end)
	return fallback
end

local function refreshBoard(
	list: ScrollingFrame,
	entries: { BoardEntry },
	formatter: (number) -> string
)
	for rank = 1, DISPLAY_COUNT do
		local row = list:FindFirstChild(string.format("Row%02d", rank))
			or list:FindFirstChild("Row" .. rank)
		if row == nil then
			local frames = {}
			for _, child in list:GetChildren() do
				if child:IsA("GuiObject") and not child:IsA("UIListLayout") then
					table.insert(frames, child)
				end
			end
			table.sort(frames, function(a, b)
				return a.LayoutOrder < b.LayoutOrder
			end)
			row = frames[rank]
		end
		if row and row:IsA("GuiObject") then
			local entry = entries[rank]
			local userId = if entry then tonumber(entry.key) else nil
			setRow(row, rank, userId, if entry then formatter(entry.value) else nil)
		end
	end
end

local function publishPlayer(player: Player, includePlaytime: boolean)
	local state = PlayerStateService.GetPlotState(player)
	if state == nil then
		return
	end
	local key = tostring(player.UserId)
	pcall(function()
		rebirthStore:SetAsync(key, math.max(0, math.floor(state.PrestigeCount or 0)))
	end)
	if includePlaytime then
		local checkpoint = sessionCheckpoints[player] or os.clock()
		local elapsed = math.max(0, math.floor(os.clock() - checkpoint))
		if elapsed > 0 then
			local succeeded = pcall(function()
				playtimeStore:IncrementAsync(key, elapsed)
			end)
			if succeeded then
				sessionCheckpoints[player] = checkpoint + elapsed
			end
		end
	end
end

local function refreshAll()
	local foundAny = false
	for _, definition in BOARDS do
		local board = findNamed(definition.name)
		if board then
			local list = ensureList(board, definition.title)
			if list then
				foundAny = true
				local entries = readStore(definition.store)
				if definition.name == "Leaderboard_TopPlaytime" then
					entries = withOnlineFallback(entries, sessionPlaytime)
				elseif definition.name == "Leaderboard_TopRebirths" then
					entries = withOnlineFallback(entries, function(player)
						local state = PlayerStateService.GetPlotState(player)
						return if state
							then math.max(0, math.floor(state.PrestigeCount or 0))
							else 0
					end)
				else
					entries = withOnlineFallback(entries, function()
						return 0
					end)
				end
				refreshBoard(list, entries, definition.format)
			end
		end
	end
	if not foundAny and not missingWarned then
		missingWarned = true
		warn(
			"[LeaderboardService] No in-world boards found. Expected models named Leaderboard_TopPlaytime, Leaderboard_TopRebirths, and Leaderboard_TopRobux under Workspace (usually NewMap/Decorations/StairsLeaderboard/Leaderboards)."
		)
	end
end

function LeaderboardService.RecordRobuxSpent(player: Player, amount: number)
	local wholeAmount = math.max(0, math.floor(amount))
	if wholeAmount <= 0 then
		return
	end
	local succeeded, message = pcall(function()
		robuxStore:IncrementAsync(tostring(player.UserId), wholeAmount)
	end)
	if not succeeded then
		warn(`[LeaderboardService] Could not record Robux spend: {tostring(message)}`)
	end
end

function LeaderboardService.Start()
	for _, player in Players:GetPlayers() do
		sessionCheckpoints[player] = os.clock()
	end
	Players.PlayerAdded:Connect(function(player)
		sessionCheckpoints[player] = os.clock()
	end)
	Players.PlayerRemoving:Connect(function(player)
		publishPlayer(player, true)
		sessionCheckpoints[player] = nil
	end)
	task.spawn(function()
		local function tick()
			for _, player in Players:GetPlayers() do
				publishPlayer(player, true)
			end
			refreshAll()
		end
		task.wait(FIRST_REFRESH_SECONDS)
		tick()
		-- Data may still have been loading on the first pass; try once more shortly after.
		task.wait(6)
		tick()
		while true do
			task.wait(UPDATE_INTERVAL_SECONDS)
			tick()
		end
	end)
end

return table.freeze(LeaderboardService)
