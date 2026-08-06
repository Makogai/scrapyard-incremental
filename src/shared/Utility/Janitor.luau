--!strict

export type CleanupTask = RBXScriptConnection | Instance | (() -> ())
export type Janitor = {
	Add: (self: Janitor, task: CleanupTask) -> CleanupTask,
	Cleanup: (self: Janitor) -> (),
}

local Janitor = {}
Janitor.__index = Janitor

function Janitor.new(): Janitor
	return (setmetatable({ _tasks = {} }, Janitor) :: any) :: Janitor
end

function Janitor:Add(task: CleanupTask): CleanupTask
	table.insert(self._tasks, task)
	return task
end

function Janitor:Cleanup()
	for index = #self._tasks, 1, -1 do
		local task = self._tasks[index]
		if typeof(task) == "RBXScriptConnection" then
			task:Disconnect()
		elseif typeof(task) == "Instance" then
			task:Destroy()
		else
			task()
		end
	end
	table.clear(self._tasks)
end

return Janitor
