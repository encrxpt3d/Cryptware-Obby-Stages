local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Crypt = require(ReplicatedStorage.Cryptware.Crypt)

Crypt.Include(script.Parent.Systems)
Crypt.Utils(script.Parent.Utils)
Crypt.Start()

for _, component in script.Parent.Components:GetChildren() do
	require(component)
end