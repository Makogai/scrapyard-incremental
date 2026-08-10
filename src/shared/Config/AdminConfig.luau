--!strict

local adminUserIds: { [number]: boolean } = {
	[1113999731] = true,
	[7862008029] = true,
}

local AdminConfig = {}
AdminConfig.MaximumGrantMoney = 1e12
AdminConfig.MaximumGrantGears = 100000

function AdminConfig.IsAdmin(userId: number): boolean
	return adminUserIds[userId] == true
end

return table.freeze(AdminConfig)
