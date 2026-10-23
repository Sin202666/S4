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
local v = sub:FindFirstChild("3")
if not v then
	v = Instance.new("StringValue")
	v.Name = "3"
	v.Parent = sub
end
v.Value = "tuWTkemTgyIsNCwiUmFyZSIsMjUwMDAsMTIwLDIxMCwyNTUsIkljZSIsMS4yNSwyMTAsMjQwLDI1NSwicmJ4YXNzZXRpZDovLzk0MzY2NTczMzgxODUzIn0sCglbN109eyLnv6Hnv6Dlk5Hpk4MiLDUuNSwiRXBpYyIsOTAwMDAsNDAsMjEwLDExMCwiR2xhc3MiLDEuMywzMCwxMjAsNzAsInJieGFzc2V0aWQ6Ly8xMTk1ODE4MjkzMzMwMzYifSwKCVs4XT17Iue0q+aZtuWTkemTgyIsNy41LCJFcGljIiwzNTAwMDAsMTcwLDgwLDI1NSwiR2xhc3MiLDEuMzUsOTAsNDAsMTQwLCJyYnhhc3NldGlkOi8vOTkzNjk3MDEyODM4NDQifSwKCVs5XT17IueGlOWyqeWTkemTgyIsMTAsIkVwaWMiLDEyMDAwMDAsMjU1LDEwMCwzMCwiQ3JhY2tlZExhdmEiLDEuNCw2MCw0MCw0MCwicmJ4YXNzZXRpZDovLzEwODc5NzY4MzQ2NjMxOSJ9LAoJWzEwXT17IumSu+efs+WTkemTgyIsMTQsIkVwaWMiLDUwMDAwMDAsMTIwLDI0MCwyNTUsIk5lb24iLDEuNSwyMzAsMjUwLDI1NSwicmJ4YXNzZXRpZDovLzEwNDM4NzUyNTQzOTE1NSJ9Cn0KCkNvbmZpZ0luc3RhbmNlLmF3bGV2ZWxDb25mPXsKCVsxXT17IumdkuiNieWFrOWbrSIsIkdyYXNzIiwwLCJHcmFzcyIsMTAwLDE3NSw3MCwiT2ZmZXIiLCLmnZDotKjmnKjnrrEiLDAseyJTYW5kIiwiV29vZCIsIkdyYXNzIn19LAoJWzJdPXsi5bKp55+z5bOh6LC3IiwiU3RvbmUiLDYwLCJTbGF0ZSIsMTIwLDEyNSwxNDAsIkdhY2hhIiwi5bKp55+z55+z566xIiw1MDAseyJXb29kIiwiR3Jhc3MiLCJTbm93IiwiUm9jayJ9fSwKCVszXT17IueCmeeDreaymea8oCIsIkRlc2VydCIsODAwLCJTYW5kIiwyMjUsMjAwLDE0MCwiR2FjaGEiLCLmspnmvKDlrp3nrrEiLDUwMDAseyJTbm93IiwiUm9jayIsIk1ldGFsIiwiV2F0ZXIifX0sCglbNF09eyLlhrDpm6rlsbHlnLAiLCJTbm93IiwxNTAwMCwiU25vdyIsMjM1LDI0MiwyNTAsIkdhY2hhIiwi5Yaw5pm25a6d566xIiw1MDAwMCx7Ik1ldGFsIiwiV2F0ZXIiLCJCcmljayIsIk1hZ21hIn19LAoJWzVdPXsi54aU5bKp54Gr5bGxIiwiTGF2YSIsMjUwMDAwLCJCYXNhbHQiLDU1LDQ1LDQ1LCJHYWNoYSIsIueGlOWyqeWuneeusSIsMjAwMDAwMCx7IkJyaWNrIiwiTWFnbWEiLCJOZW9uIiwiRGlhbW9uZCJ9fQp9CgpDb25maWdJbnN0YW5jZS5hd21hdGVyaWFsQ29uZj17CglbIlNhbmQiXT17IuaymeWtkCIsMS4yLCJDb21tb24iLDYwLCJTYW5kIiwyMjYsMjA1LDE0NSw0MCwiIiwicmJ4YXNzZXRpZDovLzEyMjE5MjAxMDQ3MDc2NSJ9LAoJWyJXb29kIl09eyLmnKjlpLQiLDEuNSwiQ29tbW9uIiw0OCwiV29vZCIsMTYwLDExMCw2MCw4MCwiIiwicmJ4YXNzZXRpZDovLzEyODEyNjcyNjY2MDc4NSJ9LAoJWyJHcmFzcyJdPXsi6I2J5ZywIiwyLCJVbmNvbW1vbiIsMzAsIkdyYXNzIiw5MCwxNzAsNjAsMTUwLCIiLCJyYnhhc3NldGlkOi8vMTI2ODQ1OTY0ODQ4NjI2In0sCglbIlNub3ciXT17IuWGsOmbqiIsMi41LCJVbmNvbW1vbiIsMjIsIlNub3ciLDIzNSwyNDUsMjU1LDAsIiIsInJieGFzc2V0aWQ6Ly8xMjIwMDUyMzYxMjk0MDkifSwKCVsiUm9jayJdPXsi5bKp55+zIiwzLjUsIlJhcmUiLDEyLCJTbGF0ZSIsMTEwLDExMCwxMjAsMCwiIiwicmJ4YXNzZXRpZDovLzEzMDc5NTQxMzMxNDY3NCJ9LAoJWyJNZXRhbCJdPXsi6YeR5bGeIiw1LCJSYXJlIiw4LCJEaWFtb25kUGxhdGUiLDE3MCwxNzUsMTg1LDAsIiIsInJieGFzc2V0aWQ6Ly8xMjYxMTE2MjIwNzUyNTIifSwKCVsiV2F0ZXIiXT17Iua1geawtCIsNywiRXBpYyIsNSwiR2xhc3MiLDYwLDE1MCwyNTUsMCwiIiwicmJ4YXNzZXRpZDovLzExNjg3MDUzODc5MDUw"
return #v.Value
