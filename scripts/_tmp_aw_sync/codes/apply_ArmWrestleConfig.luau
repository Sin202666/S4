local sub = game.ReplicatedStorage:FindFirstChild("_TmpAwSync") and game.ReplicatedStorage._TmpAwSync:FindFirstChild("ArmWrestleConfig")
assert(sub, "missing chunks")
local parts = table.create(8)
for i = 0, 7 do
	local v = sub:FindFirstChild(tostring(i))
	assert(v and v:IsA("StringValue"), "missing " .. i)
	parts[i + 1] = v.Value
end
local src = table.concat(parts)
local mod = game.ReplicatedFirst.AllSideCode.ToolSystem.ArmWrestleConfig
mod.Source = src
return #src
