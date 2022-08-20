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
		WithCondition: (
			self: Query,
			predicate: (instance: any) -> boolean
		) -> (),
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

return nil