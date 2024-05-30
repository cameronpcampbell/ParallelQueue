# ParallelQueue

Easily parallelise your Roblox code!


# Example Usage

```lua
--!strict

local ParallelQueue = require(game:GetService("ReplicatedStorage").ParallelQueue)

local MyQueue = ParallelQueue.new {
	Module = script.MyModule, -- The module to be run in parallel (must return a function).
	Workers = 100
}
local FinishedWork = MyQueue.FinishedWork

-- Waits for new finished work from the queue.
task.spawn(function()
	while task.wait(.0000000000001) do
		for idx, work in FinishedWork do
			FinishedWork[idx] = nil
			
			print(work)
		end
	end
end)

-- Waits for free worker then runs the `Module` (defined in the constructor above) in parallel.
-- Replace `...` with the args to pass to the Module.
MyQueue.Enqueue(...)
```
