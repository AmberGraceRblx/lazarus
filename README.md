
# NOTE: THIS LIBRARY IS A WORK IN PROGRESS AND HAS NO STABLE RELEASES YET.
Currently, the Lazarus library is still being developed and tested. Stay tuned for a first (either beta or full) release.

# Lazarus
<p align="center">
<img width="400" height="400" src="Logo512.png" />
<br clear="left"/>
Scripted Behavior Library for Roblox
</p>

## Description

Lazarus is an Roblox library that solves common problems with StreamingEnabled, or just instance replication in general.

Because StreamingEnabled often streams parts in and out incompletly, writing client code that relies on WaitForChild can often be unsafe, break in edge cases, or causes memory leaks that are hard to diagnose.

Lazarus provides a simple array of tools that allow you to define "behaviors", which are functions that take an instance as an argment, wait for resources (such the instance's children), run side effects, and will restart execution when a resource is lost. This model can save a lot of hassle when writing code for StreamingEnabled.

## Installation


A stable release has not yet been published. This repository is synced via Rojo while it's in development.


## Example

Here is a sample "Car" behavior script written using Lazarus, with comments annotating highlights of Lazarus' features:
```lua 
--[[
    "Seat" behavior: Behaviors are function generators that wait for resources,
    execute side effects, then return callback to clean up these side effects
]]
local function Seat(seat)
    -- Wait for resources
    local fireParticles: Fire = Lazarus.WaitForChild(seat, "FireParticles")

    -- Execute side effects
    fireParticles.Enabled = true

    -- Return callback to clean up side effects
    return function()
        fireParticles.Enabled = false
    end
end

--[[
    "Car" behavior: Waits for "Seats" folder and "Body" part, when executes
    a nested behavior and runs scripted effects on the car instance.
]]
local function Car(car)
    -- Resource block: Wait for resources using Lazarus methods
    local seats: Folder = Lazarus.WaitForChild(car, "Seats")
    local body: BasePart = Lazarus.WaitForChild(car, "Body")

    -- Effect block: Execute side effects.
    -- Lazarus provides a "TaskCollector" utility to better manage side
    -- effect cleanups
    local tasks = Lazarus.TaskCollector()

    -- Lazarus allows you to nest behaviors! We can use this to run a "Seat"
    -- behavior on any children of the "Seats" folder
    local cleanupSeats = Lazarus.WithChildren(seats):RunBehavior(Seat)

    -- Specify that we want to stop all nested Seat behaviors when
    -- Car behavior is cleaned up later
    tasks.Collect(cleanupSeats)

    print("We set up the car", car:GetFullName())

    -- Specify a callback to execute when the behavior is cleaned up
    tasks.Collect(function()
        print("We cleaned up the car", car:GetFullName())
    end)

    -- Cleanup callback: We can simple return the "Cleanup" function on our
    -- task collector object
    return tasks.Cleanup
end

-- Run our Car behavior every time an instance with the
-- CollectionService tag "Car" is encountered
Lazarus.WithTagged("Car"):RunBehavior(Car)
```

## Performance Considerations

Lazarus uses Roblox's well-optimized [task](https://create.roblox.com/docs/reference/engine/libraries/task) library to spawn and resume behavior threads. For execution of these, you can expect a very mininmal overhead, on the same order of magnitude of typical roblox API calls (WaitForChild, FindFirstChild, event:Connect(), etc.).

Lazarus also throttles behavior executions, allowing for a max execution time, framerate throttling, and behavior code execution throttling.
To customize these throttle triggers, change the global values in the [Config](/src/Config.luau) (documented within the Config module):

```lua
local Lazarus = require(path.to.Lazarus)

-- Sets the maximum global execution time for all Lazarus behaviors on the client
-- per heartbeat frame.
Lazarus.Config.ClientThrottleTriggers.ExecutionTime = 1 / 1000
```

Lazarus **is currently single-threaded**, and will not provide multithreading support for now, due to current limitations with roblox's multithreading API. While using an Actor for behavior-bound objects may be a well optimized way to support multithreading in the future, currently there is no multi-threading support for client code, or for scripts not directly descendant to an Actor.

If your game does not use StreamingEnabled, or more performance gains are needed than what Lazarus can provide, consider designing a custom systems for your experience that generates dynamically-scripted instances on the client rather than replicating these instances from the server.

## Documentation




## Contribution

Lazarus is an open-source and public domain project. Feature suggestions, bug reports, and contributions are very welcome!

To install the toolchain used for developing Lazarus, run `foreman install` in the repository's root directory using [Foreman](https://github.com/Roblox/foreman)

Next, build out the Lazarus project and sync files using [Rojo](https://rojo.space/docs):

```bash
rojo build -o "lazarus.rbxlx"
rojo serve
```

To run unit tests, copy the code inside the "RunLazarusTests" script in ReplicatedStorage. Make sure to run unit tests for both Deferred and Immediate signal behaviors (`workspace.SignalBehavior`)!