--!strict
local CreateQueryFunction = require(script.Parent.CreateQueryFunction)

local WithChildren = CreateQueryFunction(function(parent: Instance)
	return function(add, remove, removeAll)
		for _, child in parent:GetChildren() do
			add(child)
		end
		local conn1 = parent.ChildAdded:Connect(add)
		local conn2 = parent.ChildRemoved:Connect(remove)
		local conn3 = parent.Destroying:Connect(removeAll)
		return function()
			conn1:Disconnect()
			conn2:Disconnect()
			conn3:Disconnect()
		end
	end
end)

return WithChildren