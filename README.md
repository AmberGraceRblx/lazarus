
# NOTE: THIS LIBRARY IS A WORK IN PROGRESS AND HAS NO STABLE RELEASES YET.
Currently, the Lazarus library is still being developed and tested. Stay tuned for a first (either beta or full) release.

# Lazarus
<p align="center">
<img width="400" height="400" src="Logo512.png" />
<br clear="left"/>
Scripted Behavior Library for Roblox
</p>

## Description

Lazarus is an Roblox library that makes it easy and safe to to write behavior code that brings instances to life in a way that is compatible with StreamingEnabled. Because StreamingEnabled often streams parts in and out incompletly, client-side code that relies on WaitForChild can often be unsafe, leak entire threads, break in edge cases, or causes memory leaks in edge cases that are hard to test.

Lazarus provides a simple array of tools that are easy to use and understand, while handling memory and event cleanups for you.

## Installation


## Example

Here is a sample "Car" behavior script written using Lazarus, with comments annotating highlights of Lazarus' features:
```lua 
local function Seat(seat)
    local fireParticles: Fire = Lazarus.WaitForChild(seat, "FireParticles")

    fireParticles.Enabled = true
    return function() -- Cleanup
        fireParticles.Enabled = false
    end
end

--[[
"Car" behavior: Lazarus will automatically yield and resume the Car
behavior until all required children are found, resetting back to the
beginning of the function if any of the required resources disappear
for any reason! Lazarus automatically manages events connections for
you, removing many sources of memory leaks!
]]
local function Car(car)
    local seats: Folder = Lazarus.WaitForChild(car, "Seats")
    local body: BasePart = Lazarus.WaitForChild(car, "Body")

    -- Lazarus lets you nest behaviors, making for cleaner and more
    -- Shallow code that is easy to read! When behaviors are run,
    -- they return a "cleanup" function which allows you to specify
    -- when these behaviors start and stop running.
    local cleanupSeats = Lazarus.WithChildren(seats):RunBehavior(Seat)

    print("We set up the car", car:GetFullName())

    return function() -- Cleanup
        cleanupSeats()

        print("We cleaned up the car", car:GetFullName())
    end
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