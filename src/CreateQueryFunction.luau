--!strict
--[[

CreateQueryFunction - builds a Lazarus query function. All built-in Queries are
designed using CreateQueryFunction internally.

]]

local Types = require(script.Parent.Types)
local ExecutionManager = require(script.Parent.ExecutionManager)
local BehaviorThreadState = require(script.Parent.BehaviorThreadState)

local QUERY_METATABLE: Types.Query_Metatable
QUERY_METATABLE = {
	__index = {
		RunBehavior = function(self, behavior)
			BehaviorThreadState.NotifyNonResourceMethodCall(coroutine.running())

			local instanceToCleanup: {[any]: Types.Cleanup} = {}
			
			local dead = false
			local cleanupQuery = self._runQuery(table.unpack(self._args))(
				function(instance) -- add
					if dead then
						return
					end
					if instanceToCleanup[instance] then
						return
					end
					
					instanceToCleanup[instance] = ExecutionManager.StartExecution(
						behavior,
						instance
					)
				end,
				function(instance) -- remove
					if dead then
						return
					end

					local cleanup = instanceToCleanup[instance]
					if cleanup then
						instanceToCleanup[instance] = nil
						cleanup()
					end
				end
			)

			return function()
				if dead then
					return
				end
				dead = true
				task.spawn(cleanupQuery) -- External code (unsafe)
				for _, cleanup in instanceToCleanup do
					cleanup()
				end
			end
		end,
		WithCondition = function(self, predicate): Types.Query
			BehaviorThreadState.NotifyNonResourceMethodCall(coroutine.running())

			local lastQuery = self._runQuery
			local nextQueryFields: Types.Query_Fields = {
				_runQuery = function(...)
					return function(add, remove)
						return lastQuery(table.unpack(self._args))(
							function(instance: any)
								if predicate(instance) then
									add(instance)
								end
							end,
							remove
						)
					end
				end,
				_args = self._args,
			}

			return setmetatable(nextQueryFields, QUERY_METATABLE)
		end,
		-- WithActor = function(self, actor): Types.Query

		-- end,
	},
	__tostring = function(self)
		return string.format(
			"Lazarus Query (Args: %s)",
			table.concat(self._args, ", ", 1, self._args.n)
		)
	end,
}

local function CreateQueryFunction<Args...>(
	runQuery: Types.QueryRunner<Args...>
): Types.QueryCreator<Args...>
	return function(...: Args...)
		BehaviorThreadState.NotifyNonResourceMethodCall(coroutine.running())

		local queryFields: Types.Query_Fields = {
			_runQuery = runQuery :: any,
			_args = table.pack(...),
		}

		return setmetatable(queryFields, QUERY_METATABLE)
	end
end

return CreateQueryFunction