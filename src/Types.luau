--!strict
--[[

Lazarus library types, both internal and external

]]

export type TablePack = {[number]: any, n: number}
export type Cleanup = () -> ()
export type QueryRunner<Args...> = (Args...) -> (
	add: (instance: Instance) -> (),
	remove: (instance: Instance) -> ()
) -> Cleanup
export type Query_Fields = {
	_runQuery: QueryRunner<...any>,
	_args: TablePack,
}
export type Query_Metatable = {
	__index: {
		-- Narrows down queries on a given condition
		WithCondition: (
			self: Query,
			predicate: (instance: any) -> boolean
		) -> Query,
		-- -- Uses an actor for parallel code execution? This is going to be hard
		-- -- to implement for client-side code, since the client cannot have
		-- -- actors. It may be better to simply use task.desynchronize within
		-- -- a behavior's main effect block.
		-- WithActor: (
		-- 	self: Query,
		-- 	actor: Actor
		-- ) -> Query,
		RunBehavior: (
			self: Query,
			behavior: Behavior
		) -> Cleanup,
	},
	__tostring: (self: Query) -> string,
}
export type Query = typeof(setmetatable(
	(nil :: any) :: Query_Fields,
	(nil :: any) :: Query_Metatable
))
export type QueryCreator<Args...> = (Args...) -> Query
export type Behavior = (instance: any) -> Cleanup
export type BehaviorYieldState = {
	_fromLazarusResourceMethod: true,
}
export type ConfigThrottleTriggers = {
    ExecutionTime: number?,
    ResourceCleanups: number?,
    EffectCleanups: number?,
    ResourceBlocks: number?,
    EffectBlocks: number?,
}
export type Config = {
    ClientThrottleTriggers: ConfigThrottleTriggers,
    ClientMaxRenderStepHeartbeatRatio: number?,
    ServerThrottleTriggers: ConfigThrottleTriggers,
}

return nil