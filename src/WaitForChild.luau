--!strict
--[[

Lazarus Resource Method that yields the running Behavior until a child is found,
or until the behavior is cleaned up. Will clean up the whole behavior if the
child is ever destroyed or reparented.

]]

local CreateResourceMethod = require(script.Parent.CreateResourceMethod)

local WaitForChild = CreateResourceMethod(function(
	parent: Instance,
	childName: string,
	childClass: string?,
	trackNameChanges: boolean?
)
	return {
		CheckConditionInitial = function(conditionMet)
			local matchingInitialChild: Instance? = nil
			do
				local firstChild = parent:FindFirstChild(childName)
				if firstChild then
					if childClass then
						if firstChild:IsA(childClass) then
							matchingInitialChild = firstChild
						else
							local children = parent:GetChildren()
							for i = 1, #children do
								if
									(children[i].Name == childName)
									and (children[i]:IsA(childClass))
								then
									matchingInitialChild = children[i]
									break
								end
							end
						end
					else
						matchingInitialChild = firstChild
					end
				end
			end

			if matchingInitialChild then
				conditionMet(matchingInitialChild)
			end
		end,
		TrackBeforeConditionMet = function(conditionMet)
			local childToNameTrack = {}
			local conn1 = parent.ChildAdded:Connect(function(child: Instance)
				local matchesClass
				if childClass then
					matchesClass = child:IsA(childClass)
				else
					matchesClass = true
				end
				if not matchesClass then
					return
				end
				
				local matchesName = child.Name == childName

				if matchesName then
					conditionMet(child)
				else
					if trackNameChanges then
						childToNameTrack[child] = child:GetPropertyChangedSignal("Name")
							:Connect(function()
								if child.Name == childName then
									if (not childClass) or child:IsA(childClass) then
										conditionMet(child)
									end
								end
							end)
					end
				end
			end)
			local conn2
			if trackNameChanges then
				conn2 = parent.ChildRemoved:Connect(function(child: Instance)
					local track = childToNameTrack[child]
					if track then
						childToNameTrack[child] = nil
						track:Disconnect()
					end
				end)
			end

			return function()
				conn1:Disconnect()
				if trackNameChanges then
					conn2:Disconnect()
					for _, conn in childToNameTrack do
						conn:Disconnect()
					end
				end
			end
		end,
		TrackAfterConditionMet = function(conditionUnmet, foundChild)
			local conn1 = foundChild.AncestryChanged:Connect(function(_, newParent)
				if newParent ~= parent then
					conditionUnmet()
				end
			end)
			local conn2 = foundChild.Destroying:Connect(conditionUnmet)
			local conn3: RBXScriptConnection? = nil
			if trackNameChanges then
				conn3 = foundChild:GetPropertyChangedSignal("Name"):Connect(function()
					if foundChild.Name ~= childName then
						conditionUnmet()
					end
				end)
			end

			return function()
				conn1:Disconnect()
				conn2:Disconnect()
				if conn3 then
					conn3:Disconnect()
				end
			end
		end
	}
end)

return WaitForChild