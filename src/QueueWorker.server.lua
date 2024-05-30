--!strict


--> Services ------------------------------------------------------------------------------------------
local SharedTableRegistry = game:GetService("SharedTableRegistry")
-------------------------------------------------------------------------------------------------------


local Actor: Actor = script.Parent
if typeof(Actor) ~= "Instance" and Actor.ClassName ~= "Actor" then script.Enabled = false end

local Module = Actor:FindFirstChildWhichIsA("ModuleScript") :: any
if not Module then script.Enabled = false end
local RequiredModule = require(Module) :: any

local WorkerIdx = Actor:GetAttribute("WorkerIdx")
if not WorkerIdx then script.Enabled = false end

local QueueId = Actor:GetAttribute("QueueId")
if not QueueId then script.Enabled = false end


--> Variables -----------------------------------------------------------------------------------------
local FinishedWork = SharedTableRegistry:GetSharedTable(`ParallelQueue:{QueueId}:FinishedWork`)
local WorkersStatus = SharedTableRegistry:GetSharedTable(`ParallelQueue:{QueueId}:WorkersStatus`)
-------------------------------------------------------------------------------------------------------


Actor:BindToMessageParallel("DoWork", function(...)
	local result = RequiredModule(...)
	
	SharedTable.update(WorkersStatus, WorkerIdx, function() return true end)
	
	Actor:SendMessage("PostWork", result)
end)


Actor:BindToMessage("PostWork", function(result)
	SharedTable.update(FinishedWork, SharedTable.size(FinishedWork) + 1, function() return result end)
end)



