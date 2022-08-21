--!strict
local CreateQueryFunction = require(script.Parent.CreateQueryFunction)

local WithDescendants = CreateQueryFunction(function(parent: Instance)
	return function(add, remove, removeAll)
		for _, child in parent:GetDescendants() do
			add(child)
		end
		local conn1 = parent.DescendantAdded:Connect(add)
		local conn2 = parent.DescendantRemoving:Connect(remove)
		local conn3 = parent.Destroying:Connect(removeAll)
		return function()
			conn1:Disconnect()
			conn2:Disconnect()
			conn3:Disconnect()
		end
	end
end)

return WithDescendants