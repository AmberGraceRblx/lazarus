--!strict
--[[
	Runs a behavior generator on a given instance, returning a single cleanup
	function.

	Both RunBehavior and the returned cleanup should NOT directly error
	when called; instead they should spawn a task running the external
	code!
]]

local Types = require(script.Parent.Types)
local BehaviorThreadState = require(script.Parent.BehaviorThreadState)

local SOURCE_TRACING = false

local memo_behaviorToTracebackReference = {}
setmetatable(memo_behaviorToTracebackReference, {__mode = "k"})
local function memo_getTracebackReference(behavior: Types.Behavior): () -> string
	local existing = memo_behaviorToTracebackReference[behavior]
	if existing then
		return existing
	end

	local traceback = if SOURCE_TRACING
		then debug.traceback("Lazarus RunBehavior Call", 3)
		else "<behavior source tracing not enabled>"
	local reference = function()
		return traceback
	end
	memo_behaviorToTracebackReference[behavior] = reference
	return reference
end

local function RunBehavior(
	userDefinedBehavior: Types.Behavior,
	instance: Instance,
	onContinueExecutionRequest: () -> (),
	onRestartExecutionRequest: () -> ()
)
	local getTraceback = memo_getTracebackReference(userDefinedBehavior)
	-- Create a pseudo-"generator" by yielding/resuming a thread.
	local thread: thread
	task.spawn(function()
		thread = coroutine.running()
		
		-- Capture our thread in this scope before continuing the generator
		coroutine.yield()

		BehaviorThreadState.HandleFinalUserReturns(
			thread,
			userDefinedBehavior(instance)
		)
	end)
	-- "thread" variable should now be initialized in this scope.

	return BehaviorThreadState.Init(
		thread,
		getTraceback,
		onContinueExecutionRequest,
		onRestartExecutionRequest
	)
end

return RunBehavior