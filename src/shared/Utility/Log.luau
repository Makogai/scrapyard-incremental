--!strict

local Environment = require(script.Parent.Parent.Config.Environment)

local Log = {}

function Log.info(scope: string, message: string)
	if Environment.EnableDebugLogging then
		print(string.format("[%s] %s", scope, message))
	end
end

function Log.warn(scope: string, message: string)
	warn(string.format("[%s] %s", scope, message))
end

return table.freeze(Log)
