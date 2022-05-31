--!strict
--[[
    Centralized state store for currently-running behavior threads.
    
    Because certain Lazarus resource methods (e.g. WaitForChild) set up and
    clean up event handlers within the generator, there needs to be a global
    state tied to the currently-running thread.
    
    The built-in thread states ("dead" | "running" | "normal" | "suspended") and
    this global store together can be used to infer whether or not a resource
    method was called from an valid place, and help the user diagnose improper
    use of the Lazarus library.

    Because of the requirement of a centralized state module, it is important
    that a separate version of the Lazarus library doesn't somehow start running
    behaviors that use another copy of the Lazarus library, though this edge
    case seems pretty unlikely.
]]

local Types = require(script.Parent.Types)

local ERR_LEVEL: number? = nil

local BehaviorThreadState = {}

type InternalState = {
    resourceMethodsSanctioned: boolean,
    cleanedUp: boolean,
    cleanups: {Types.Cleanup},
    getTraceback: () -> string,
    lastSanctionedYieldState: Types.BehaviorYieldState?,
    userReturnsPacked: Types.TablePack?,
    userDefinedCleanup: Types.Cleanup?,
}
local threadToState: {[thread]: InternalState} = {}
setmetatable(threadToState, {__mode = "k"})

--[[
    Stops tracking a thread, closes it (i.e. frees its upvalues for garbage
    collection), and cleans up all resources tied to the behavior thread.
]]
local function closeBehaviorThread(thread: thread)
    if coroutine.status(thread) ~= "dead" then
        coroutine.close(thread)
    end
    
    local state = threadToState[thread]
    if state then
        if state.cleanedUp then
            return
        end
        state.cleanedUp = true
        local cleanups = state.cleanups
        for i = 1, #cleanups do
            cleanups[i]()
        end

        if state.userDefinedCleanup then
            task.spawn(state.userDefinedCleanup)
        end
    end
end

-- Acts as a generator call for a tracked thread.
local function stepResumption(thread: thread, state: InternalState, ...: any)
    -- If the status is "dead", an exception likely occurred. Clean up what
    -- we can; the user should have a more relevent error in their output
    -- already.
    if coroutine.status(thread) == "dead" then
        closeBehaviorThread(thread)
        return
    end

    -- Resumption does not need to be stepped. Emit a warning.
    if coroutine.status(thread) ~= "suspended" then
        warn(
            "A Lazarus Behavior function was somehow resumed in parallel with a"
            .. " its own main thread. This is most likely a bug and should be"
            .. " reported. Traceback: "
            .. state.getTraceback()
        )
        return
    end

    -- Begin user defined code up until next yield or return.
    local yieldState = coroutine.resume(thread, ...)

    -- If returns were encountered, validate them.
    if state.userReturnsPacked then
        if state.userReturnsPacked.n > 1 then
            warn(
                "A Lazarus Behavior function returned more than one value!"
                .. " Behavior functions should return a single cleanup function."
                .. " Traceback: "
                .. state.getTraceback()
            )
        end
        return
    end

    -- Check if we encountered a yield state, and had no external resumptions!
    if state.lastSanctionedYieldState == yieldState then
        state.lastSanctionedYieldState = nil
        return
    end
    
    -- Check the status again, if the thread died, or is not suspended,
    -- some issue occurred.
    if coroutine.status(thread) == "dead" then
        closeBehaviorThread(thread)
        return
    end
    if coroutine.status(thread) ~= "suspended" then
        warn(
            "A Lazarus Behavior function was somehow resumed in parallel with a"
            .. " its own main thread. This is most likely a bug and should be"
            .. " reported. Traceback: "
            .. state.getTraceback()
        )
        return
    end

    -- Else, there are two possibilities:
    -- 1) Some user code yielded the behavior where it was not supposed to
    -- 2) Some user code resumed the behavior where it was not supposed to

    -- We can diagnose this further.

    if state.lastSanctionedYieldState then
        -- A Lazarus yield was encountered, but improperly resumed!
        state.lastSanctionedYieldState = nil

        warn(
            "A Lazarus Behavior function was resumed outside of a resource method!"
            .. " Was your resource block placed at the top of the Behavior"
            .. " function, with no extra side effects in between resource method"
            .. " calls? Traceback: "
            .. state.getTraceback()
        )
    else
        warn(
            "A Lazarus Behavior function was yielded outside of a resource method!"
            .. " Behavior functions should only yield during the resource block"
            .. " at the top of the function, and should immediately return a"
            .. " cleanup function. Traceback: "
            .. state.getTraceback()
        )
    end
end

--[[
    Initializes a thread as sanctioned for resource methods, and handles
    contined resumption of the thread until its status is "dead;" Should only be
    called from RunBehavior in general.
]]
function BehaviorThreadState.Init(thread: thread, getTraceback: () -> string)
    if threadToState[thread] then
        error("Attempt to run two behaviors within the same thread!")
    end
    local state: InternalState = {
        resourceMethodsSanctioned = true,
        cleanups = {},
        cleanedUp = false,
        getTraceback = getTraceback,
    }
    threadToState[thread] = state

    stepResumption(thread, state)

    return function()
        closeBehaviorThread(thread)
    end
end

function BehaviorThreadState.HandleFinalUserReturns(
    thread: thread,
    ...: any
)
    local state = threadToState[thread]
    if state then
        state.userReturnsPacked = table.pack(...)
    end

    -- Our thread should yield a final time, and the returns will be handled
    -- by the last stepResumption call.
    coroutine.yield(true)
end

--[[
    This function should be called every time a Lazarus library method is used
    that is not itself a resource method. This can be used to remove the
    sanction to continue using resource methods later in the scope, and help
    users diagnose improper use of the library.
]]
function BehaviorThreadState.NotifyNonResourceMethodCall(thread: thread)
    local state = threadToState[thread]
    if state then
        state.resourceMethodsSanctioned = false
    end
end

--[[
    Asserts whether a call to a Lazarus resource method was valid, and throws
    an error if the call was invalid. If you ended up here, you probably used a
    Lazarus method incorrectly! Check the output for more detailed information
    and suggestions.
]]
function BehaviorThreadState.AssertResourceMethodsAreSanctioned(thread: thread)
    local state = threadToState[thread]
    local errLevel: number? = nil
    if state then
        if not state.resourceMethodsSanctioned then
            error(
                "Attempt to call a Lazarus resource method outside of the Behavior's main"
                    .. " resource block! Resource methods should always be called at the top of the"
                    .. " Behavior function, and should have no extra functions or side effects"
                    .. " between calls!",
                ERR_LEVEL
            )
        end
    else
        error(
            "Attempt to call a Lazarus resource method outside of a Behavior's main thread!",
            ERR_LEVEL
        )
    end
end

--[[
    Yields the running thread, and returns resumed values. In general, should
    only be called from resource methods after
    AssertResourceMethodsAreSanctioned has also been called.
]]
function BehaviorThreadState.YieldForResource(yieldState: Types.BehaviorYieldState): ...any
    local thread = coroutine.running()
    local state = threadToState[thread]
    if state then
        state.lastSanctionedYieldState = yieldState
        return coroutine.yield(yieldState)
    end

    error(
        "Attempt to call a Lazarus resource method outside of a Behavior's main thread!",
        ERR_LEVEL
    )
end

--[[
    Adds a cleanup to the list of resource cleanups in a currently sanctioned
    thread. In general, should only be called from resource methods after
    AssertResourceMethodsAreSanctioned has also been called.
]]
function BehaviorThreadState.AddResourceCleanup(thread: thread, cleanup: Types.Cleanup)
    local state = threadToState[thread]
    if state then
        table.insert(state.cleanups, cleanup)
    else
        task.spawn(cleanup)
    end
end

--[[
    Resumes a yielding generator. This function should be called whenever a
    resource is found.
]]
function BehaviorThreadState.NotifyResourceFound(thread: thread, packedReturns: Types.TablePack)
    local state = threadToState[thread]
    if state then
        stepResumption(thread, state, table.unpack(packedReturns))
    end
end

--[[
    This function should be called everyime a resource function's condition is
    no longer met.
]]
function BehaviorThreadState.NotifyResourceRemoved(thread: thread)
    local state = threadToState[thread]
    if state then
        threadToState[thread] = nil
        closeBehaviorThread(thread)
    end
end

return BehaviorThreadState
