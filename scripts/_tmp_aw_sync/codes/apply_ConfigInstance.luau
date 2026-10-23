local sub = game.ReplicatedStorage:FindFirstChild("_TmpAwSync") and game.ReplicatedStorage._TmpAwSync:FindFirstChild("ConfigInstance")
assert(sub, "missing chunks")
local parts = table.create(5)
for i = 0, 4 do
	local v = sub:FindFirstChild(tostring(i))
	assert(v and v:IsA("StringValue"), "missing " .. i)
	parts[i + 1] = v.Value
end
local src = table.concat(parts)
local mod = game.ReplicatedFirst.AllSideCode.ToolBasic.ConfigInstance
mod.Source = src
return #src
