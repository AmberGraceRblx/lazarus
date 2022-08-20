--!strict
local CreateQueryFunction = require(script.Parent.CreateQueryFunction)

local WithTagged = CreateQueryFunction(function(tag: string)
	return function(add, remove)
		local CollectionService = game:GetService("CollectionService")
		for instance in CollectionService:GetTagged(tag) do
			add(instance)
		end
		local conn1 = CollectionService:GetInstanceAddedSignal(tag):Connect(add)
		local conn2 = CollectionService:GetInstanceRemovedSignal(tag):Connect(remove)
		return function()
			conn1:Disconnect()
			conn2:Disconnect()
		end
	end
end)

return WithTagged