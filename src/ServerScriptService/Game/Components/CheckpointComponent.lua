local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Component = require(ReplicatedStorage.Cryptware.Component)
local CheckpointComponent = Component.new({ Tag = "Checkpoint" })

function CheckpointComponent:Construct()
	self.Instance.Touch.Touched:Connect(function(hit)
		local char = hit.Parent
		
		if Players:FindFirstChild(char.Name) then
			local player = Players[char.Name]
			local Stage = player:WaitForChild("leaderstats").Stage
			
			if Stage.Value < self.Instance.Stage.Value and self.Instance.Stage.Value - Stage.Value == 1 then
				Stage.Value += 1
				player.RespawnLocation = self.Instance
			end
		end
	end)
end

return CheckpointComponent