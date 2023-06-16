local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Crypt = require(ReplicatedStorage.Cryptware.Crypt)

local Stages = Crypt.Register({ Name = "Stages" }).Expose({
	RE = {},
	RF = {}
})

function Stages:PlayerAdded(player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player
	
	local Stage = Instance.new("NumberValue")
	Stage.Name = "Stage"
	Stage.Parent = leaderstats
end

function Stages:Init()
	-- setup class variables and important things
end

function Stages:Start()
	-- runs simultaneously with all other systems
end

return Stages