--!strict

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Environment = require(ReplicatedStorage.Shared.Config.Environment)
local PlayerStateService = require(script.Parent.PlayerStateService)

local LeaderboardService = {}

local UPDATE_INTERVAL_SECONDS = 60
local DISPLAY_COUNT = 10
local sessionCheckpoints: { [Player]: number } = {}

local storeSuffix = if RunService:IsStudio() or Environment.UseDevelopmentDataStore
	then "Development"
	else "Production"
local playtimeStore = DataStoreService:GetOrderedDataStore(`Scrapyard_Playtime_{storeSuffix}_v1`)
local rebirthStore = DataStoreService:GetOrderedDataStore(`Scrapyard_Rebirths_{storeSuffix}_v1`)
local robuxStore = DataStoreService:GetOrderedDataStore(`Scrapyard_RobuxSpent_{storeSuffix}_v1`)

local function formatPlaytime(totalSeconds: number): string
	local minutes = math.floor(math.max(0, totalSeconds) / 60)
	local hours = math.floor(minutes / 60)
	local days = math.floor(hours / 24)
	if days > 0 then
		return string.format("%dd %02dh", days, hours % 24)
	elseif hours > 0 then
		return string.format("%dh %02dm", hours, minutes % 60)
	end
	return string.format("%dm", minutes)
end

local function boardList(boardName: string): ScrollingFrame?
	local map = workspace:FindFirstChild("NewMap")
	local decorations = map and map:FindFirstChild("Decorations")
	local stairs = decorations and decorations:FindFirstChild("StairsLeaderboard")
	local boards = stairs and stairs:FindFirstChild("Leaderboards")
	local board = boards and boards:FindFirstChild(boardName)
	local screen = board and board:FindFirstChild("Screen")
	local surface = screen and screen:FindFirstChildOfClass("SurfaceGui")
	local frame = surface and surface:FindFirstChild("Frame")
	local list = frame and frame:FindFirstChild("Frame")
	return if list and list:IsA("ScrollingFrame") then list else nil
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

local function setRow(row: GuiObject, rank: number, userId: number?, valueText: string?)
	local rankLabel = row:FindFirstChild("Rank") :: TextLabel?
	local nameLabel = row:FindFirstChild("PlayerName") :: TextLabel?
	local valueLabel = row:FindFirstChild("Value") :: TextLabel?
	local avatar = row:FindFirstChild("Avatar") :: ImageLabel?
	if rankLabel then
		rankLabel.Text = `#{rank}`
	end
	if userId == nil then
		if nameLabel then
			nameLabel.Text = "Waiting for player..."
		end
		if valueLabel then
			valueLabel.Text = "—"
		end
		if avatar then
			avatar.Image = ""
		end
		return
	end
	local succeeded, playerName = pcall(Players.GetNameFromUserIdAsync, Players, userId)
	if nameLabel then
		nameLabel.Text = if succeeded then playerName else `Player {userId}`
	end
	if valueLabel then
		valueLabel.Text = valueText or "0"
	end
	if avatar then
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

local function refreshBoard(
	list: ScrollingFrame,
	store: OrderedDataStore,
	formatter: (number) -> string
)
	local succeeded, pages = pcall(function()
		return store:GetSortedAsync(false, DISPLAY_COUNT)
	end)
	local entries = if succeeded then pages:GetCurrentPage() else {}
	for rank = 1, DISPLAY_COUNT do
		local row = list:FindFirstChild(string.format("Row%02d", rank))
		if row and row:IsA("GuiObject") then
			local entry = entries[rank]
			local userId = if entry then tonumber(entry.key) else nil
			setRow(row, rank, userId, if entry then formatter(entry.value) else nil)
		end
	end
end

local function refreshAll()
	local playtimeList = boardList("Leaderboard_TopPlaytime")
	if playtimeList then
		refreshBoard(playtimeList, playtimeStore, formatPlaytime)
	end
	local rebirthList = boardList("Leaderboard_TopRebirths")
	if rebirthList then
		refreshBoard(rebirthList, rebirthStore, function(value)
			return `{math.floor(value)} REBIRTHS`
		end)
	end
	local robuxList = boardList("Leaderboard_TopRobux")
	if robuxList then
		refreshBoard(robuxList, robuxStore, function(value)
			return `{math.floor(value)} R$`
		end)
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
		while true do
			task.wait(UPDATE_INTERVAL_SECONDS)
			for _, player in Players:GetPlayers() do
				publishPlayer(player, true)
			end
			refreshAll()
		end
	end)
	task.delay(5, function()
		for _, player in Players:GetPlayers() do
			publishPlayer(player, true)
		end
		refreshAll()
	end)
end

return table.freeze(LeaderboardService)
