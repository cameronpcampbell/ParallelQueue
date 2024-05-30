--!strict


--> Services ------------------------------------------------------------------------------------------
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterGui = game:GetService("StarterGui")
local SharedTableRegistry = game:GetService("SharedTableRegistry")
-------------------------------------------------------------------------------------------------------


--> Types ---------------------------------------------------------------------------------------------
type QueueProps = {
	Module: ModuleScript,
	Workers: number
}
-------------------------------------------------------------------------------------------------------


--> Variables -----------------------------------------------------------------------------------------
local GenerateGUID = HttpService.GenerateGUID

local IsClient = RunService:IsClient()
local FallbackQueuesRootFolder: Instance = IsClient and StarterGui or ServerScriptService

local QueueWorkerScript = script:FindFirstChild("QueueWorker")
-------------------------------------------------------------------------------------------------------


--> Private Functions ---------------------------------------------------------------------------------
local function ResolveInstanceFromPath(path: string): Instance?
	local splitPath = string.split(path, ".")
	local resolved: Instance = game
	
	for _,segment in splitPath do
		resolved = resolved:FindFirstChild(segment, false)
		if not resolved then return nil end
	end
	
	return resolved
end

local function CreateUniqueId(parent: Instance)
	local uniqueId: string
	repeat
		uniqueId = GenerateGUID(HttpService, false)
	until not parent:FindFirstChild(uniqueId, false)
	
	return uniqueId
end

local function CreateQueuesRootFolder(parent: Instance)
	local queuesRootFolder = Instance.new("Folder")
	queuesRootFolder.Name = "ParallelQueues"
	queuesRootFolder.Parent = parent
	
	return queuesRootFolder
end

local function InstantiateWorker(idx: number, queueId: string, module: ModuleScript, parent: Instance)
	local actor = Instance.new("Actor")
	actor.Name = `Worker:{idx}`
	actor:SetAttribute("QueueId", queueId)
	actor:SetAttribute("WorkerIdx", idx)
	
	module:Clone().Parent = actor
	
	local queueWorker = QueueWorkerScript:Clone()
	queueWorker.Parent = actor
	queueWorker.Enabled = true
	
	actor.Parent = parent
	
	return actor
end
-------------------------------------------------------------------------------------------------------


assert(QueueWorkerScript and QueueWorkerScript:IsA("Script"), `"{script:GetFullName()}.QueueWorker" is missing!`)

if IsClient then QueueWorkerScript.RunContext = Enum.RunContext.Client end

local function New(props: QueueProps)
	local module, workersCount = props.Module, props.Workers
	
	local queuesRootFolder = CreateQueuesRootFolder(
		ResolveInstanceFromPath(debug.info(2, "s")) or FallbackQueuesRootFolder
	)
	
	local queueId = CreateUniqueId(queuesRootFolder)
	
	local queueFolder = Instance.new("Folder")
	queueFolder.Name = `ParallelQueue:{queueId}`
	queueFolder.Parent = queuesRootFolder
	
	local workersStatus = SharedTable.new(table.create(workersCount, true))
	SharedTableRegistry:SetSharedTable(`ParallelQueue:{queueId}:WorkersStatus`, workersStatus)

	local finishedWork = SharedTable.new()
	SharedTableRegistry:SetSharedTable(`ParallelQueue:{queueId}:FinishedWork`, finishedWork)
	
	local workers = table.create(workersCount)
	for idx = 1, workersCount do
		workers[idx] = InstantiateWorker(idx, queueId, module, queueFolder)
	end
	
	local function getFreeWorker(): Actor?
		for idx, status in workersStatus do
			if not status then continue end
			
			-- Marks the actor as not free.
			SharedTable.update(workersStatus, idx, function() return false end)
			
			return workers[idx]
		end
		
		return nil
	end
	
	local freeIndexes = {}
	
	-- For some reason actors will fail to fire unless we wait here.
	task.wait(.125)
	
	return {
		Enqueue = function(...)
			coroutine.resume(coroutine.create(function(...)
				local freeWorker = getFreeWorker()

				if not freeWorker then
					repeat
						task.wait(.00001)
						freeWorker = getFreeWorker()
					until freeWorker
				end

				;(freeWorker :: Actor):SendMessage("DoWork", ...)
			end), ...)
		end,
		
		FinishedWork = finishedWork
	}
end



return {
	new = New
}
