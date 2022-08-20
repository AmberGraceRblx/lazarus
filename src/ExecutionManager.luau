--!strict
--[[
	Execution Manager - Throttles execution and acts as a posting board for
	run/resume/cleanup states.

	All side effects begin after a queried instance behavior is flagged as
	"added", and in a deferred thread to allow entry point scripts to edit the
	Config.

	System design:

	Query add -> executionManager via ExecutionManager.StartExecution(behavior, instance)
		(immediately) -> ExecutionManager - queueContinue()

		Resource received -> ExecutionManager - queueContinue()
		Heartbeat continue (task.deferred) -> continue behavior code -> Check global
			execution limits
		On resource request: continue until full behavior code yield
			flag if resource request effect cleanup returned, then increment 
			xecution limit tracker
		On cleanup flagged: ExecutionManager - queueRestart()
		On query remove: ExecutionManager - queueFinish()

]]

local Config = require(script.Parent.Config)
local Types = require(script.Parent.Types)
local RunBehavior = require(script.Parent.RunBehavior)
local RunService = game:GetService("RunService")

-- local queuedRunBehaviorSet: any = {}
-- local queuedCleanupBehaviorSet: any = {}
-- local queuedRestartBehaviorSet: any = {}
-- local queuedResumeBehaviorSet: any = {}

-- local setAddMultiIndex = function(set: any, ...): ()
--     local indices = {...}
--     for i = 1, #indices - 1 do
--         local nextSet = set[indices[i]]
--         if not nextSet then
--             nextSet = {}
--             set[indices[i]] = nextSet
--         end
--         set = nextSet
--     end
--     set[indices[#indices]] = true
-- end
-- local setHasMultiIndex = function(set: any, ...): boolean
--     local indices = {...}
--     for i, index in indices do
--         local nextValue = set[index]
--         if not nextValue then
--             set = nil
--             break
--         end
--         set = nextValue
--     end

--     return set ~= nil
-- end
-- local setRemoveMultiIndex = function(set: any, ...): ()
--     local indices = {...}
--     local sets = table.create(#indices)
--     table.insert(sets, set)
--     for i = 2, #indices do
--         local nextSet = set[indices[i]]
--         if nextSet then
--             table.insert(sets, nextSet)
--             set = nextSet
--         else
--             return
--         end
--     end
--     for i = #sets, 1, -1 do
--         sets[i][indices[i]] = nil
--         if next(sets[i]) then
--             break
--         end
--     end
-- end

local ExecutionManager = {}

type Execution = {
	_behavior: Types.Behavior,
	_instance: Instance,
	_queuedDirective: ("continue" | "restart" | "finish")?,
	_state: "pending" | "executing" | "yielding" | "finished",
	_threadExecutionHandle: {
		ContinueExecution: () -> "yielding" | "finished",
		FinishExecution: () -> (boolean, boolean)
	}?,
}

local hasQueuedWorkSet: {[Execution]: true} = {}

local function queueContinue(execution: Execution)
	if execution._state == "pending" then
		if execution._queuedDirective == nil then
			execution._queuedDirective = "continue"
		end
		hasQueuedWorkSet[execution] = true
	elseif execution._state == "yielding" then
		if execution._queuedDirective == nil then
			execution._queuedDirective = "continue"
			hasQueuedWorkSet[execution] = true
		end
	end
end
local function queueRestart(execution: Execution)
	if execution._state == "yielding" or execution._state == "pending" then
		if
			(execution._queuedDirective == "finished")
			and (execution._queuedDirective == "restart")
		then
			execution._queuedDirective = "restart"
		end
		hasQueuedWorkSet[execution] = true
	end
end
local function queueFinish(execution: Execution)
	if execution._queuedDirective ~= "finish" then
		execution._queuedDirective = "finish"
		hasQueuedWorkSet[execution] = true
	end
end

function ExecutionManager.StartExecution(behavior: Types.Behavior, instance: Instance)
	local execution: Execution = {
		_behavior = behavior,
		_instance = instance,
		_state = "pending",
		_queuedDirective = "continue",
	}
	hasQueuedWorkSet[execution :: any] = true
	
	-- Return "finish execution" callback
	return function()
		queueFinish(execution)
	end
end

--[[

	Globally starts Lazarus behavior execution side effects

]]
local sideEffectsCleanup: (() -> ())? = nil
function ExecutionManager.StartSystems()
	if sideEffectsCleanup then
		return
	end

	local heartbeatCountSinceRender = 0
	local conn1 = RunService.Heartbeat:Connect(function()
		heartbeatCountSinceRender += 1

		task.defer(function()
			-- Read config once in deferred thread every Heartbeat
			local maxExecutionTime
			local maxEffectBlocks
			local maxEffectCleanups
			local maxResourceBlocks
			local maxResourceCleanups
			local maxFrameRatio
			do
				local isServer = RunService:IsServer()
				local throttleTriggersToUse = if isServer
					then Config.ServerThrottleTriggers
					else Config.ClientThrottleTriggers
				
				maxExecutionTime = throttleTriggersToUse.ExecutionTime or math.huge
				maxEffectBlocks = throttleTriggersToUse.EffectBlocks or math.huge
				maxEffectCleanups = throttleTriggersToUse.EffectCleanups or math.huge
				maxResourceBlocks = throttleTriggersToUse.ResourceBlocks or math.huge
				maxResourceCleanups = throttleTriggersToUse.ResourceCleanups or math.huge
				if isServer then
					maxFrameRatio = math.huge
				else
					maxFrameRatio = Config.ClientMaxRenderStepHeartbeatRatio or math.huge
				end
			end

			if heartbeatCountSinceRender > maxFrameRatio then
				return
			end
			
			local queuedWorkList = {}
			for task in hasQueuedWorkSet do
				table.insert(queuedWorkList, task)
			end

			hasQueuedWorkSet = {}

			local executionStart = os.clock()
			local resourceBlocks = 0
			local resourceCleanups = 0
			local effectBlocks = 0
			local effectCleanups = 0

			local handlePastINextFrame = #queuedWorkList + 1
			for i, execution in queuedWorkList do
				-- Initialize throttle trigger flags
				local resourceBlockFlagged = false
				local effectBlockFlagged = false
				local resourceCleanupFlagged = false
				local effectCleanupFlagged = false
				local shouldThrottle = false

				-- Resume behavior execution
				
				while execution._queuedDirective do
					local directive = execution._queuedDirective
					if directive then
						execution._queuedDirective = nil
						if directive == "continue" then
							local threadStateHandle = execution._threadExecutionHandle
							if threadStateHandle then
								execution._state = "executing"
								execution._state = (threadStateHandle :: any).ContinueExecution()
								resourceBlockFlagged = true
								if execution._state == "finished" then
									effectBlockFlagged = true
								end
							else
								-- Start running the behavior
								threadStateHandle = RunBehavior(
									execution._behavior,
									execution._instance,
									function() -- Continue execution request
										queueContinue(execution)
									end,
									function() -- Restart execution request
										queueRestart(execution)
									end
								)
								execution._threadExecutionHandle = threadStateHandle
								
								resourceBlockFlagged = true
								execution._state = "executing"
								execution._state = (threadStateHandle :: any).ContinueExecution()
								if execution._state == "finished" then
									effectBlockFlagged = true
								else
									resourceBlockFlagged = true
								end
							end
						elseif directive == "restart" then
							local threadStateHandle = execution._threadExecutionHandle
							if threadStateHandle then
								execution._state = "finished"
								execution._threadExecutionHandle = nil
								resourceCleanupFlagged, effectCleanupFlagged
									= threadStateHandle.FinishExecution()
								execution._state = "pending"
								queueContinue(execution)
							end
						else--if directive == "finish" then
							local threadStateHandle = execution._threadExecutionHandle
							if threadStateHandle then
								execution._state = "finished"
								resourceCleanupFlagged, effectCleanupFlagged
									= threadStateHandle.FinishExecution()
							end
						end
					end
					if (os.clock() - executionStart) >= maxExecutionTime then
						shouldThrottle = true
						break
					end
				end

				-- Uptick and compare throttle triggers
				if resourceBlockFlagged then
					resourceBlocks += 1
					if resourceBlocks >= maxResourceBlocks then
						shouldThrottle = true
					end
				end
				if effectBlockFlagged then
					effectBlocks += 1
					if effectBlocks >= maxEffectBlocks then
						shouldThrottle = true
					end
				end
				if resourceCleanupFlagged then
					resourceCleanups += 1
					if resourceCleanups >= maxResourceCleanups then
						shouldThrottle = true
					end
				end
				if effectCleanupFlagged then
					effectCleanups += 1
					if effectCleanups >= maxEffectCleanups then
						shouldThrottle = true
					end
				end

				if shouldThrottle then
					handlePastINextFrame = if execution._queuedDirective then i else i + 1
					break
				end
			end

			for i = handlePastINextFrame, #queuedWorkList do
				hasQueuedWorkSet[queuedWorkList[i]] = true
			end

			if resourceBlocks > 0 or effectBlocks > 0 or resourceCleanups > 0 or effectCleanups > 0 then
				print("Active frame:", resourceBlocks, effectBlocks, resourceCleanups, effectCleanups)
			end
		end)
	end)
	local conn2 = RunService.RenderStepped:Connect(function()
		heartbeatCountSinceRender = 0
	end)

	sideEffectsCleanup = function()
		conn1:Disconnect()
		conn2:Disconnect()
	end
end

--[[

	Globally stops Lazarus behavior execution side effects

]]
function ExecutionManager.StopSystems()
	if sideEffectsCleanup then
		sideEffectsCleanup()
		sideEffectsCleanup = nil
	end
end

return ExecutionManager