--!strict
--[[
    A simple, composable task collector utility object. Similar to the
    commonly-used "maid" class, without the footguns and sexist undertones.

    Returns an object with a "Collect" and a "Cleanup" function. Collect marks
    an object to be cleaned up later, then returns that object for convenience.

    Example usage:

        local tasks = Lazarus.TaskCollector()
        local myPart = tasks.Collect(Instance.new("Part"))
        tasks.Collect(function()
            print(
                "This callback is run in its own thread when cleanup is called!"
            )
        end)
        -- . . .
        tasks.Cleanup() -- Cleans up all of the objects that were collected

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
        return cb
    end,
    ["table"] = function(tab: {[any]: any}): (() ->())?
        local destroy = tab.Destroy
        if destroy then
            local mt = getmetatable(tab :: any)
            if mt and mt.__call then
                return function()
                    (tab :: any)()
                end
            end
            return function()
                destroy(tab)
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
    
    return {
        Collect = collect,
        Cleanup = cleanup,
    }
end

return TaskCollector