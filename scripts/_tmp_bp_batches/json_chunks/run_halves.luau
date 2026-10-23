local folder = game.ReplicatedStorage._TmpBpSync
local code = folder:FindFirstChild("half_a.txt").Value .. folder:FindFirstChild("half_b.txt").Value
local fn, err = loadstring(code)
if not fn then return { err = err } end
local ok, res = pcall(fn)
folder:Destroy()
if not ok then return { err = res } end
return res
