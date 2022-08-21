--!strict
local CreateQueryFunction = require(script.Parent.CreateQueryFunction)

local WithInstance = CreateQueryFunction(function(instance: Instance)
	return function(add, remove, removeAll)
		add(instance)
		local conn1 = instance.Destroying:Connect(function()
			remove(instance)
		end)
		return function()
			conn1:Disconnect()
		end
	end
end)

return WithInstance