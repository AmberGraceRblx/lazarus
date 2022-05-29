--!strict
--[[

CreateQueryFunction - builds a Lazarus resource method. All built-in Resource
methods are designed using CreateResourceMethod internally.

]]

local Types = require(script.Parent.Types)
local BehaviorThreadState = require(script.Parent.BehaviorThreadState)

local function CreateResourceMethod<Args..., Returns...>(
    resourceMethod: (Args...) -> {
        CheckConditionInitial: (conditionMet: (Returns...) -> ()) -> (),
        TrackBeforeConditionMet: (conditionMet: (Returns...) -> ()) -> Types.Cleanup,
        TrackAfterConditionMet: (conditionUnmet: () -> (), Returns...) -> Types.Cleanup,
    }
): (Args...) -> Returns...
    return function(...: Args...)
        local thread = coroutine.running()
        BehaviorThreadState.AssertResourceMethodsAreSanctioned(thread)

        local closure = resourceMethod(...)
        local finalReturns: Types.TablePack = nil
        closure.CheckConditionInitial(function(...)
            finalReturns = table.pack(...)
        end)

        local preConditionCleanup: Types.Cleanup? = nil
        local postConditionCleanup: Types.Cleanup? = nil

        -- This is made idempotent by de-referencing the prior cleanups.
        local finalCleanup = function()
            if preConditionCleanup then
                local tmp = preConditionCleanup :: Types.Cleanup
                preConditionCleanup = nil
                tmp()
            end
            if postConditionCleanup then
                local tmp = postConditionCleanup :: Types.Cleanup
                postConditionCleanup = nil
                tmp()
            end
        end

        BehaviorThreadState.AddResourceCleanup(thread, finalCleanup)

        local hasReturned = false
        if finalReturns then
            postConditionCleanup = closure.TrackAfterConditionMet(function()
                if hasReturned then
                    BehaviorThreadState.NotifyResourceRemoved(thread)
                else
                    -- In edge case where user-defined resource instantly cleans
                    -- up for some reason, we should defer the thread until
                    -- after we have continued processing.
                    task.defer(BehaviorThreadState.NotifyResourceRemoved, thread)
                end
            end)
        else
            local hasYielded = false
            preConditionCleanup = closure.TrackBeforeConditionMet(function(...)
                if hasYielded then
                    BehaviorThreadState.NotifyResourceFound(thread, table.pack(...))
                else
                    -- Instantly assign without yielding; we will continue
                    -- the function normally.
                    finalReturns = table.pack(...)
                end
            end)

            -- In some edge cases, the packed returns could instantly be found.
            -- Clean up connections immediately and don't yield the generator.
            if finalReturns then
                local tmp = preConditionCleanup :: Types.Cleanup
                preConditionCleanup = nil
                tmp()
            else
                hasYielded = true

                -- In all other branches, we should have returns. Else, we
                -- yield for them (the thread could close / upvalues GC'd in
                -- the case that they are never found).
                finalReturns = BehaviorThreadState.YieldForResource({
                    _fromLazarusResourceMethod = true,
                })
            end

            postConditionCleanup = closure.TrackAfterConditionMet(function()
                if hasReturned then
                    BehaviorThreadState.NotifyResourceRemoved(thread)
                else
                    -- In edge case where user-defined resource instantly cleans
                    -- up for some reason, we should defer the thread until
                    -- after we have continued processing.
                    task.defer(BehaviorThreadState.NotifyResourceRemoved, thread)
                end
            end)
        end

        hasReturned = true

        return table.unpack(finalReturns)
    end :: any
end

return CreateResourceMethod
