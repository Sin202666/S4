local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local function b64decode(data: string): string
	data = string.gsub(data, "[^" .. alphabet .. "=]", "")
	local out = table.create(math.ceil(#data * 3 / 4))
	local n = 0
	for i = 1, #data, 4 do
		local a = string.find(alphabet, string.sub(data, i, i), 1, true) or 1
		local b = string.find(alphabet, string.sub(data, i + 1, i + 1), 1, true) or 1
		local c = string.find(alphabet, string.sub(data, i + 2, i + 2), 1, true) or 1
		local d = string.find(alphabet, string.sub(data, i + 3, i + 3), 1, true) or 1
		a, b, c, d = a - 1, b - 1, c - 1, d - 1
		local n1 = bit32.bor(bit32.lshift(a, 2), bit32.rshift(b, 4))
		n += 1
		out[n] = string.char(n1)
		if string.sub(data, i + 2, i + 2) ~= "=" then
			local n2 = bit32.band(bit32.bor(bit32.lshift(b, 4), bit32.rshift(c, 2)), 255)
			n += 1
			out[n] = string.char(n2)
		end
		if string.sub(data, i + 3, i + 3) ~= "=" then
			local n3 = bit32.band(bit32.bor(bit32.lshift(c, 6), d), 255)
			n += 1
			out[n] = string.char(n3)
		end
	end
	return table.concat(out)
end
local folder = game.ReplicatedStorage:FindFirstChild("_TmpAwSync")
if not folder then
	folder = Instance.new("Folder")
	folder.Name = "_TmpAwSync"
	folder.Parent = game.ReplicatedStorage
end
local sub = folder:FindFirstChild("ConfigInstance")
if not sub then
	sub = Instance.new("Folder")
	sub.Name = "ConfigInstance"
	sub.Parent = folder
end
local v = sub:FindFirstChild("6")
if not v then
	v = Instance.new("StringValue")
	v.Name = "6"
	v.Parent = sub
end
v.Value = "n+W6puiNr+awtCIsNCwxLDEsMCwxLDAsMSwyLCLorq3nu4PpgJ/luqboja/msLTmj4/ov7AiLDAsIkFybVdyZXN0bGVQb3Rpb24iLHsiVHJhaW5TcGVlZFBvdGlvbiJ9LDEwNjU4MTU1OTU4ODUxMywiIiwiMCIsIjAiLHt9LHt9LCIiLDF9LAoJWzIwM109eyLph5HluIHoja/msLQiLDQsMSwxLDAsMSwwLDEsMywi6YeR5biB6I2v5rC05o+P6L+wIiwwLCJBcm1XcmVzdGxlUG90aW9uIix7IkNhc2hQb3Rpb24ifSw3MzUyMDI4MjA0MTM2NCwiIiwiMCIsIjAiLHt9LHt9LCIiLDF9Cn0KCkNvbmZpZ0luc3RhbmNlLml0ZW1zaG9wZGF0YUNvbmY9ewoJWzFdPXsi5Y+M5YCN5bm46L+QIiwi5Y+M5YCN5bm46L+Q5o+P6L+wIiwiTHVja1gyIiwiIiwiIiwiIiwiIiwyLDE0ODkzMjkwNDEsIjM0MTI4NDg4NDkiLDE5OSwiIix7fSx7fSx7IjExOTM3NzQyOTg1OTExMSJ9LCIyIn0sCglbMl09eyLmnLrlmajnpLzljIUxIiwi5py65Zmo56S85YyFMeaPj+i/sCIsIk1hY2hpbmVQYWNrMSIsIiIsIiIsIiIsIiIsMSwzNDEyODMwODg3LCIzNDEyODM1MDEyIiw2OSwiIix7ODEwMDAwMyw4MjAwMDAyfSx7MX0seyIxMjgwNTMwMjkzNzc5NzgiLCIxMjcyODAxNjI5MzIwMzgifSwiMyJ9LAoJWzNdPXsi5LiA6ZSu6Kej6ZSB5Zyo57q/5aWW5YqxIiwiIiwiT25saW5lQXdhcmRDbGFpbUFsbCIsIiIsIiIsIiIsIiIsMSwzNjEyMDExNjI5LCIiLDc5LCIiLHt9LHt9LHt9LCIifQp9CgpDb25maWdJbnN0YW5jZS5tb3VudENvbmY9ewoJWzYwMDEwMDFdPXsi54us6KeS5YW9IiwiR3JvdW5kTW91bnQiLCLni6zop5Llhb0iLDMsIkZvcmNlRXhpdCIsIiIsMywxLjUsIk1vdW50U2FkZGxlIiwiTW91bnRHcm91bmQiLCJNb3VudFVuaWNvcm4iLCJ7XCJBY2NlbFNlY1wiOjAuOSxcIkRlY2VsU2VjXCI6MS4zNSxcIlR1cm5SYXRlRGVnXCI6MjIwLFwiVHVybkhpZ2hTcGVlZE11bFwiOjAuMzgsXCJUdXJuU3BlZWRQb3dcIjoxLjM1LFwiVHVybkFsaWduTWluXCI6MC42NSxcIlR1cm5BbGlnblBvd1wiOjEuMSxcIkFib3V0RmFjZURvdFwiOi0wLjc1LFwiQWJvdXRGYWNlQWxpZ25NaW5cIjowLFwiQWJvdXRGYWNlVHVybk11bFwiOjIuOSxcIkFib3V0RmFjZUJyYWtlXCI6MTYwLFwiQWJvdXRGYWNlQ29tcGxldGVEZWdcIjoxMixcIkFib3V0RmFjZVN0aWNrQmFja1wiOjAuOSxcIkFib3V0RmFjZUNvb2xkb3duU2VjXCI6MC4yLFwiQWlyVHVybk11bFwiOjAuODUsXCJBaXJGbGlwVHVybk11bFwiOjIuNixcIkRvdWJsZUp1bXBGbGlwV2luZG93U2VjXCI6MC40LFwiQWlyRmxpcFZlbEFsaWduXCI6OCxcIkRvdWJsZUp1bXBWZWxCbGVuZDBcIjowLjQ1LFwiRG91YmxlSnVtcFJlZGlyZWN0U2VjXCI6MC4yMixcIkp1bXBIZWlnaHRcIjoyMixcIkRvdWJsZUp1bXBTcGVlZFwiOjU1LFwiQWlyR3Jhdml0eVNjYWxlXCI6MC43MixcIkNhbkRvdWJsZUp1bXBcIjoxLFwiQWlyVGhyb3R0bGVNdWxcIjoxLFwiQWlyRmxpcFRocm90dGxlTXVsXCI6MSxcIkFpclNwZWVkTWFpbnRhaW5Tb2Z0XCI6MC45LFwiQWlyU3BlZWRMZWFuUmF0ZVwiOjgsXCJBaXJDb2FzdERlY2VsXCI6NixcIkZpcnN0SnVtcE1pbkZsYXRcIjoxNixcIkZpcnN0SnVtcFNuYXBGcmFjXCI6MC42LFwiRmlyc3RKdW1wUmFtcFNlY1wiOjAuMDYsXCJGaXJzdEp1bXBMb29rQWJzb3JiXCI6MC4wOCxcIkxlYXBQdXNoU2VjXCI6MC4yNCxcIkxlYXBQdXNoQWNjZWxcIjo1NSxcIkxlYXBQdXNoUG93XCI6MS4zNSxcIkxlYXBTdGFuZFB1c2hNdWxcIjoxLjIsXCJMZWFwR2FsbG9wUHVzaE11bFwiOjAuNDUsXCJEb3VibGVKdW1wUHVzaFNlY1wiOjAuMjIsXCJEb3VibGVK"
return #v.Value
