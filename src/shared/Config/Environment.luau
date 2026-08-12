--!strict

return table.freeze({
	GameName = "Scrapyard Incremental",
	IsDevelopment = false,
	EnableDebugLogging = false,
	UseDevelopmentDataStore = false,
	DataStoreName = "ScrapyardIncremental_PlayerData_v1.1",
	DevelopmentDataStoreName = "ScrapyardIncremental_Development_v1",
	AutoSaveIntervalSeconds = 120,
	AutoSaveJitterFraction = 0.15,
	DataStoreRetryCount = 4,
	DataStoreRetryBaseSeconds = 1,
	SessionLeaseSeconds = 300,
	MaximumPlayers = 6,
	MaximumMoney = 1e15,
	MaximumGears = 1000000,
	MaximumStoredWeight = 1e9,
	MaximumStoredValue = 1e12,
	MaximumUpgradeLevel = 1000000,
	MaximumActiveScrap = 700,
	--[[
		Raised with the yard density. Markers became pile anchors holding several pieces each, so a
		player standing in a pile now has many more pieces inside their magnet radius than the 32 this
		allowed -- and the ones past the limit were silently skipped, which reads as a magnet that
		refuses to pick up scrap you are standing on.
	]]
	MaximumScrapCandidatesPerQuery = 96,
	CollectionQueryIntervalSeconds = 0.15,
	MaximumRemoteRequestsPerWindow = 12,
	RemoteRateLimitWindowSeconds = 5,
})
