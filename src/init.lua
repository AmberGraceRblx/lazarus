--!strict
--[[

Lazarus: Bring your instances to life with cleaner code, StreamingEnabled
support, and fewer memory leaks!

See the full documentation here: https://github.com/ambers-careware/lazarus

]]

local Types = require(script.Types)

-- Public types
export type Query = Types.Query
export type Cleanup = Types.Cleanup
export type Behavior = Types.Behavior
export type QueryRunner<Args...> = Types.QueryRunner<Args...>
export type QueryCreator<Args...> = Types.QueryCreator<Args...>

local Lazarus = {}

-- Query Methods

-- Resource Methods
Lazarus.WaitForChild = require(script.WaitForChild)

-- Custom Query/Resource Method Creators
Lazarus.CreateQueryMethod = require(script.CreateQueryFunction)
Lazarus.CreateResourceMethod = require(script.CreateResourceMethod)

-- Other utilities
local TaskCollector = require(script.TaskCollector)
Lazarus.TaskCollector = TaskCollector
export type CollectableTask = TaskCollector.CleanupTask

return Lazarus