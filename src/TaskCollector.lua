--!strict
--[[
    A simple, composable task collector utility object. Acts equivalently to the
    commonly-used "maid" class, without the footguns and sexist undertones.

    The first function returned is a "collect" function. This collects tasks
    of varying type (RBXScriptConnection, callback, Instance, table) and handles
    convenient cleanup for the passed object depending on its type.

    The second function returned is a "cleanup" function. When it is called, it
    will idempotently clean up all the tasks that were collected.

    Task handlers: TaskCollector cleans up each task by its type
        RBXScriptConnection: Will call connection:Disconnect() when cleaned up
        Instance: Will call instance:Destroy() when cleaned up
        function (callback): Will be called in a new thread when cleaned up
        table: If a "Destroy" method is found, table:Destroy() will be called
            when cleaned up. If a "__call" metamethod is found, the __call
            metamethod will be called instead. If neither are found, an error is
            emitted when collected.
        nil: Will be silently ignored
]]

export type CleanupTask = (() -> ())
    | RBXScriptConnection
    | Instance
    | {Destroy: (self: any) -> ()}
    | typeof(setmetatable({}, {__call = function(self) end}))
    | nil

local TRANSFORM_BY_TYPE: {[string]: (taskObject: any) -> (() -> ())?} = {
    ["function"] = function(cb: () -> ())
        return function()
            task.spawn(cb)
        end
    end,
    ["table"] = function(tab: {[any]: any}): (() ->())?
        local destroy = tab.Destroy
        if destroy then
            local mt = getmetatable(tab :: any)
            if mt and mt.__call then
                return function()
                    task.spawn(function()
                        (tab :: any)()
                    end)
                end
            end
            return function()
                task.spawn(destroy, tab)
            end
        end
        error(
            "Attempt to collect invalid table (missing 'Destroy' field or"
            .. " '__call' metamethod)"
        )
    end,
    ["RBXScriptConnection"] = function(conn: RBXScriptConnection)
        return function()
            conn:Disconnect()
        end
    end,
    ["Instance"] = function(inst: Instance)
        return function()
            inst:Destroy()
        end
    end,
    ["nil"] = function()
        return nil
    end,
}

local TaskCollector = function()
    local tasks: {() -> ()} = {}
    local cleanedUp = false
    local function cleanup()
        if cleanedUp then
            return
        end
        cleanedUp = true

        for i = 1, #tasks do
            task.spawn(tasks[i])
        end
    end
    
    local function collect<T>(taskObject: T): T
        local transformedCallback: (() -> ())? = nil
        do
            local transformer = TRANSFORM_BY_TYPE[typeof(taskObject)]
            if transformer then
                transformedCallback = transformer(taskObject)
            else
                error(
                    "Attempt to collect object of invalid type '"
                    .. typeof(taskObject)
                    .. "'"
                )
            end
        end

        if cleanedUp then
            if transformedCallback then
                task.spawn(transformedCallback)
            end
        else
            if transformedCallback then
                table.insert(tasks, transformedCallback)
            end
        end

        return taskObject
    end
    
    return collect, cleanup
end

return TaskCollector