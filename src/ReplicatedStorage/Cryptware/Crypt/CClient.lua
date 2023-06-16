local CryptClient = {}

local handlers = {}
local systems = {}

-- Definition for a handler
type HandlerDef = {
	Name: string,
	[any]: any
}

-- Handler object
type Handler = {
	Name: string,
	[any]: any
}

-- System object
type System = {
	Name: string,
	[any]: any
}

-- Communication object
type Comm = {
	[any]: any
}

local started = false
local gotSystems = false

-- Retrieves the systems from the server
local function getSystems()
	local _systems = script.Parent.CMiddleware:InvokeServer("Systems")
	script.Parent.CMiddleware:Destroy()
	if _systems then
		systems = _systems
		gotSystems = true
	end
end

-- Initializes the signals for communication
local function initSignals()
	for _, system: System in systems do
		for commType, commData in system._Comm do
			if commType == "RE" then
				-- RemoteEvent communication type
				for commName, signal: RemoteEvent in commData do
					-- Connects a callback function to the remote event
					system[commName].Connect = function(_, callback)
						signal.OnClientEvent:Connect(callback)
					end
					-- Fires the remote event to the server
					system[commName].Fire = function(_, ...)
						signal:FireServer(...)
					end
				end
			elseif commType == "RF" then
				-- RemoteFunction communication type
				for commName, signal: RemoteFunction in commData do
					-- Defines a function that invokes the remote function on the server
					system[commName] = function(_, ...)
						return signal:InvokeServer(...)
					end
				end
			end
		end
	end
end

-- Adds utility modules from a specified path to all handlers
function CryptClient.Utils(path: Folder)
	local utils = {}
	for _, module in path:GetChildren() do
		utils[module.Name] = require(module)
	end
	for _, handler in handlers do
		if not handler.Util then
			handler.Util = utils
		else
			for utilName, util in utils do
				handler.Util[utilName] = util
			end
		end
	end
end

-- Registers a handler and its definitions
function CryptClient.Register(handlerDef: HandlerDef): Handler
	local handler = handlerDef
	handlers[handler.Name] = handler
	return handler
end

-- Includes all modules from a specified path
function CryptClient.Include(path: Folder)
	for _, module in path:GetChildren() do
		local s, e = pcall(require, module)
		if not s then warn(e) end
	end
end

-- Imports a registered handler or system by name
function CryptClient.Import(importDef: string)
	if handlers[importDef] then
		return handlers[importDef]
	else
		return systems[importDef]
	end
end

-- Starts the CryptClient
function CryptClient.Start()
	if started then return end
	started = true

	initSignals()

	-- Initialize and start all registered handlers
	for _, handler in handlers do
		if handler.Init then
			local s, e = pcall(handler.Init, handler)
			if not s then warn(e) end
		end
	end

	for _, handler in handlers do
		if handler.Start then
			local s, e = pcall(function()
				task.spawn(handler.Start, handler)
			end)
			if not s then warn(e) end
		end
	end
end

-- Retrieves systems if not already obtained
if not gotSystems then
	gotSystems = true
	getSystems()
end

return CryptClient