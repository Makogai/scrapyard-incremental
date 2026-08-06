--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Definitions = require(ReplicatedStorage.Shared.Remotes.Definitions)

local RemoteService = {}
local remoteFolder: Folder?

function RemoteService.Start()
	local folder = ReplicatedStorage:FindFirstChild("Remotes")
	if folder == nil then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = ReplicatedStorage
	end
	assert(folder:IsA("Folder"), "ReplicatedStorage.Remotes must be a Folder")
	remoteFolder = folder
	for _, definition in Definitions do
		local existing = folder:FindFirstChild(definition.Name)
		if existing then
			assert(
				existing.ClassName == definition.Kind,
				`Remote {definition.Name} has wrong class`
			)
		else
			local remote = Instance.new(definition.Kind)
			remote.Name = definition.Name
			remote.Parent = folder
		end
	end
end

function RemoteService.GetEvent(name: string): RemoteEvent
	local folder = assert(remoteFolder, "RemoteService has not started")
	local remote = folder:FindFirstChild(name)
	assert(remote ~= nil and remote:IsA("RemoteEvent"), `RemoteEvent {name} is unavailable`)
	return remote
end

function RemoteService.GetFunction(name: string): RemoteFunction
	local folder = assert(remoteFolder, "RemoteService has not started")
	local remote = folder:FindFirstChild(name)
	assert(remote ~= nil and remote:IsA("RemoteFunction"), `RemoteFunction {name} is unavailable`)
	return remote
end

return table.freeze(RemoteService)
