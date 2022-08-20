--!strict
--[[
	
	Global config for Lazarus, can be modified by a Script/LocalScript to tailor
	performance of Lazarus behaviors.

	By default, Lazarus will wait until the game is loaded / scripts start
	executing, and then defer a thread before running behaviors. This means
	that scripts copied / running at runtime should have an opportunity to
	modify the globals before behaviors are executed.

	The default configuration aims at maximizing performance and minimizing
	any render frame drops on the Client or heartbeat frame drops on the Server.
]]

local Types = require(script.Parent.Types)

local Config: Types.Config = {
	-- When a throttle is triggered, Lazarus will wait until the next frame's
	-- RenderStepped has stepped before any behavior code is run on the client.
	-- Cleanups will always be prioritized over new or resumed behaviors.
	ClientThrottleTriggers = {
		-- Triggers a throttle for this frame when the total execution time for
		-- all Lazarus behavior runs/resumptions/cleanups processed in
		-- this frame is greater than this value:
		ExecutionTime = 1 / 60,
		-- Triggers a throttle for this frame after the following max number of
		-- behaviors have cleaned up resources in this frame:
		ResourceCleanups = 100,
		-- Triggers a throttle for this frame after the following max number of
		-- behaviors have cleaned up effects in this frame:
		EffectCleanups = 50,
		-- Triggers a throttle for this frame after the following max number of
		-- behavior resource blocks have finished resuming this frame:
		ResourceBlocks = 100,
		-- Triggers a throttle for this frame after the following max number of
		-- behavior effect blocks have finished resuming this frame:
		EffectBlocks = 50,
	},
	-- Number of heartbeat frames at which Lazarus will automatically resume
	-- behaviors, even if RenderStepped did not fire.
	-- This can happen when the player loses focus on the Roblox app (mobile),
	-- or holds the "Close" / "Minimize" / "Fullscreen" buttons down on the
	-- Roblox window (Desktop):
	ClientMaxRenderStepHeartbeatRatio = 5,
	-- When a throttle is triggered, Lazarus will wait until the next frame's
	-- Heartbeat has stepped before any behavior code is run on the server.
	-- Cleanups will always be prioritized over new or resumed behaviors.
	ServerThrottleTriggers = {
		-- Triggers a throttle for this frame when the total execution time for
		-- all Lazarus behavior runs/resumptions/cleanups code processed in
		-- this frame is greater than this value:
		ExecutionTime = 1 / 30,
		-- Triggers a throttle for this frame after the following max number of
		-- behaviors have cleaned up resources in this frame:
		ResourceCleanups = 500,
		-- Triggers a throttle for this frame after the following max number of
		-- behaviors have cleaned up effects in this frame:
		EffectCleanups = 200,
		-- Triggers a throttle for this frame after the following max number of
		-- behavior resource blocks have finished resuming this frame:
		ResourceBlocks = 500,
		-- Triggers a throttle for this frame after the following max number of
		-- behavior effect blocks have finished resuming this frame:
		EffectBlocks = 200,
	},
}

return Config