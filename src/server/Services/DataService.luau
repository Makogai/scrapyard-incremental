--!strict

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Environment = require(ReplicatedStorage.Shared.Config.Environment)
local PlayerDataSchema = require(ReplicatedStorage.Shared.Utility.PlayerDataSchema)

local DataService = {}
local store: GlobalDataStore?

local function getStore(): GlobalDataStore
	if store == nil then
		local useDevelopmentStore = RunService:IsStudio() or Environment.UseDevelopmentDataStore
		local storeName = if useDevelopmentStore
			then Environment.DevelopmentDataStoreName
			else Environment.DataStoreName
		store = DataStoreService:GetDataStore(storeName)
		print(
			`[DataService] Using {if useDevelopmentStore then "development" else "production"} store`
		)
	end
	return store :: GlobalDataStore
end

local function retry<T>(label: string, operation: () -> T): (boolean, T?)
	local lastError: any = nil
	for attempt = 1, Environment.DataStoreRetryCount do
		local succeeded, result = pcall(operation)
		if succeeded then
			return true, result
		end
		lastError = result
		warn(`[DataService] {label} attempt {attempt} failed: {tostring(result)}`)
		if attempt < Environment.DataStoreRetryCount then
			task.wait(Environment.DataStoreRetryBaseSeconds * (2 ^ (attempt - 1)))
		end
	end
	warn(`[DataService] {label} exhausted retries: {tostring(lastError)}`)
	return false, nil
end

local function playerKey(userId: number): string
	return `Player_{userId}`
end

function DataService.Load(userId: number): (boolean, { [string]: any }?, string?)
	local claimStatus = "unknown"
	local cleanData: { [string]: any }? = nil
	local nowTimestamp = os.time()
	local succeeded = retry("load", function()
		return getStore():UpdateAsync(playerKey(userId), function(storedValue)
			if typeof(storedValue) == "table" then
				local session = storedValue._Session
				if
					typeof(session) == "table"
					and session.JobId ~= game.JobId
					and typeof(session.ExpiresAt) == "number"
					and session.ExpiresAt > nowTimestamp
				then
					claimStatus = "locked"
					return nil
				end
			end

			local valid, validated, validationError =
				PlayerDataSchema.validate(storedValue, nowTimestamp)
			if not valid or validated == nil then
				claimStatus = `invalid: {validationError or "unknown validation error"}`
				return nil
			end
			validated.LastLoginTimestamp = nowTimestamp
			cleanData = validated
			local persisted = table.clone(validated)
			persisted._Session =
				{ JobId = game.JobId, ExpiresAt = nowTimestamp + Environment.SessionLeaseSeconds }
			claimStatus = "claimed"
			return persisted
		end)
	end)

	if not succeeded then
		return false, nil, "DataStore load failed"
	end
	if claimStatus ~= "claimed" or cleanData == nil then
		return false, nil, claimStatus
	end
	return true, cleanData, nil
end

function DataService.Save(
	userId: number,
	data: { [string]: any },
	releaseSession: boolean
): (boolean, string?)
	local nowTimestamp = os.time()
	local valid, clean, validationError = PlayerDataSchema.validate(data, nowTimestamp)
	if not valid or clean == nil then
		return false, validationError or "session data failed validation"
	end
	clean.LastSaveTimestamp = nowTimestamp

	local saveStatus = "unknown"
	local succeeded = retry("save", function()
		return getStore():UpdateAsync(playerKey(userId), function(storedValue)
			if typeof(storedValue) ~= "table" then
				saveStatus = "missing claimed record"
				return nil
			end
			local session = storedValue._Session
			if typeof(session) ~= "table" or session.JobId ~= game.JobId then
				saveStatus = "session ownership lost"
				return nil
			end

			local persisted = table.clone(clean)
			if not releaseSession then
				persisted._Session = {
					JobId = game.JobId,
					ExpiresAt = nowTimestamp + Environment.SessionLeaseSeconds,
				}
			end
			saveStatus = "saved"
			return persisted
		end)
	end)
	if not succeeded then
		return false, "DataStore save failed"
	end
	if saveStatus ~= "saved" then
		return false, saveStatus
	end
	data.LastSaveTimestamp = nowTimestamp
	return true, nil
end

return table.freeze(DataService)
