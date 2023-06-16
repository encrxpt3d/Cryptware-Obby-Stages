-- CryptServer module
local CryptServer = {}

-- Stores the system definitions
local systems = {}

-- Stores the client system definitions
local clientSystems = {}

-- Represents the definition of a system
type SystemDef = {
	Name: string,
	[any]: any
}

-- Represents the definition of exposes for a client system
type ExposeDef = {
	RE: { [any]: string } | any,
	RF: { [any]: string } | any,
}

-- Represents a system instance
type System = {
	Name: string,
	Util: { [any]: any },
	[any]: any
}

local Players = game:GetService("Players")

-- Invalid expose names that cannot be used
local InvalidExposeName = { "_Comm", "Name" }

-- Utility functions
local Util = {}

-- Flags to track initialization and startup status
local initialized = false
local created = false
local started = false
local ready = false

-- Initializes the utility module cache
local function initUtil()
	for _, module in script.Parent.Parent:GetChildren() do
		if module:IsA("ModuleScript") and module.Name ~= "Crypt" then
			Util[module.Name] = require(module)
		end
	end
end

-- Validates an expose name to ensure it's not in the invalid list
local function validateExposeName(exposeName)
	if table.find(InvalidExposeName, exposeName) then
		return false
	end
	return true
end

-- Creates the CMiddleware remote function
local function createMiddleware()
	local mdw = Instance.new("RemoteFunction")
	mdw.Name = "CMiddleware"
	mdw.Parent = script.Parent
end

-- Creates the Systems folder if it doesn't exist
local function createSystemsFolder()
	if script.Parent:FindFirstChild("Systems") then
		return
	end

	local systemFolder = Instance.new("Folder")
	systemFolder.Name = "Systems"
	systemFolder.Parent = script.Parent
end

-- Creates a system folder for the given system name
local function createSystemFolder(systemName)
	local systemsFolder = script.Parent.Systems

	if systemsFolder:FindFirstChild(systemName) then
		return systemsFolder[systemName]
	else
		local systemFolder = Instance.new("Folder")
		systemFolder.Name = systemName
		systemFolder.Parent = systemsFolder
		return systemFolder
	end
end

-- Creates a signal (RemoteEvent or RemoteFunction) for a client system
local function createSignal(clientSystem, commName, instanceType)
	local signal = Instance.new(instanceType)
	signal.Name = commName
	signal.Parent = createSystemFolder(clientSystem.Name)
	if instanceType == "RemoteEvent" then
		clientSystem._Comm.RE[commName] = signal
	elseif instanceType == "RemoteFunction" then
		clientSystem._Comm.RF[commName] = signal
	end
	return signal
end

-- Initializes a signal for a client system
local function initSignal(clientSystem, commName, instanceType)
	assert(not clientSystem._Comm[commName], "Cannot have duplicate comm names")
	return createSignal(clientSystem, commName, instanceType)
end

-- Initializes all the signals for client systems
local function initSignals()
	script.Parent.CMiddleware.OnServerInvoke = function()
		if not ready then
			repeat task.wait() until ready
		end

		return clientSystems
	end
end

-- Finds the system with a name containing "Data"
local function findData()
	for _, system: System in systems do
		if system.Name:match("Data") then
			return system
		end
	end
	return nil
end

-- Initializes the data system and handles player-related events
local function initData()
	local ds = findData()
	local runMode = game:GetService("RunService"):IsRunMode() and #Players:GetPlayers() == 0
	
	if runMode then
		task.wait(3)

		if #Players:GetPlayers() > 0 then
			runMode = false
		end
	end

	if not ds then
		return
	end

	if ds.Init then
		ds:Init()
	end

	if ds.PlayerAdded and not runMode then
		for _, plr in Players:GetPlayers() do
			task.spawn(function()
				ds:PlayerAdded(plr)
				ds.Ready = true
			end)
		end
		Players.PlayerAdded:Connect(function(player)
			ds:PlayerAdded(player)
			repeat task.wait() until not player or ds.Profiles[player]

			if player then
				ds.Ready = true
			end
		end)
	end

	if not ds.Ready and not runMode then
		repeat task.wait() until ds.Ready
		ds.Ready = nil
	end

	if ds.Start then
		task.spawn(ds.Start, ds)
	end

	return ds
end

-- Includes all modules from a specified path
function CryptServer.Include(path: Folder)
	for _, module in path:GetChildren() do
		local s, e = pcall(require, module)
		if not s then warn(e) end
	end
end

-- Adds utility modules from a specified path to all systems
function CryptServer.Utils(path: Folder)
	local utils = {}
	for _, module in path:GetChildren() do
		utils[module.Name] = require(module)
	end
	for _, system in systems do
		for utilName, util in utils do
			system.Util[utilName] = util
		end
	end
end

-- Registers a system and its definitions
function CryptServer.Register(systemDef: SystemDef): System
	local system = systemDef
	system.Util = Util

	-- Defines the Expose function for exposing system methods to clients
	function system.Expose(exposeDef: ExposeDef)
		assert(not clientSystems[system.Name], "Cannot expose the system more than once")
		
		local clientSystem = {
			Name = system.Name,
			_Comm = {}
		}

		for exposeType: string, exposeData: { [any]: string } in exposeDef do
			for _, exposeName in exposeData do
				assert(validateExposeName(exposeName), "Invalid expose name: Cannot use names similar to core methods")
				assert(not clientSystem[exposeName], "Cannot duplicate comm name " .. exposeName)

				if exposeType == "RE" then
					clientSystem._Comm.RE = clientSystem._Comm.RE or {}
					clientSystem[exposeName] = {}

					local signal: RemoteEvent = initSignal(clientSystem, exposeName, "RemoteEvent")
					system[exposeName] = {}

					-- Connects a callback function to the remote event
					system[exposeName].Connect = function(_, callback)
						signal.OnServerEvent:Connect(callback)
					end

					-- Fires the remote event on a specific client
					system[exposeName].Fire = function(_, player: Player, ...)
						signal:FireClient(player, ...)
					end

					-- Fires the remote event on all clients
					system[exposeName].FireAll = function(_, ...)
						signal:FireAllClients(...)
					end

				elseif exposeType == "RF" then
					clientSystem._Comm.RF = clientSystem._Comm.RF or {}
					clientSystem[exposeName] = {}

					local signal: RemoteFunction = initSignal(clientSystem, exposeName, "RemoteFunction")

					-- Sets the server-side invoke function for the remote function
					signal.OnServerInvoke = function(...)
						return system[exposeName](system, ...)
					end
				end
			end
		end

		clientSystems[clientSystem.Name] = clientSystem
		system.Expose = nil
		return system
	end

	systems[system.Name] = system
	return system
end

-- Imports a registered system by name
function CryptServer.Import(system: string)
	return systems[system]
end

-- Starts the CryptServer
function CryptServer.Start()
	assert(not started, "Cannot start Crypt: Already started!")
	started = true

	createMiddleware()
	initSignals()
	
	local ds = initData()

	for _, system in systems do
		if ds and system.Name == ds.Name then
			continue
		end
		
		if system.Init then
			local s, e = pcall(system.Init, system)
			if not s then warn(e) end
		end
		
		if system.Start then
			local s, e = pcall(function()
				task.spawn(system.Start, system)
			end)
			if not s then warn(e) end
		end
		
		task.spawn(function()
			if system.PlayerAdded then
				for _, plr in Players:GetPlayers() do
					task.spawn(function()
						system:PlayerAdded(plr)
					end)
				end
				Players.PlayerAdded:Connect(function(player)
					system:PlayerAdded(player)
				end)
			end
			
			if system.PlayerRemoving then
				Players.PlayerRemoving:Connect(function(player)
					system:PlayerRemoving(player)
				end)
			end
		end)
	end

	ready = true
end

-- Initialization logic
if not initialized then
	initialized = true
	initUtil()
end

if not created then
	created = true
	createSystemsFolder()
end

-- Returns the CryptServer module
return CryptServer