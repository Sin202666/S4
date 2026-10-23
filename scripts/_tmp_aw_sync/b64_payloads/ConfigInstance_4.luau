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
local v = sub:FindFirstChild("4")
if not v then
	v = Instance.new("StringValue")
	v.Name = "4"
	v.Parent = sub
end
v.Value = "MCJ9LAoJWyJCcmljayJdPXsi56CW5Z2XIiwxMCwiRXBpYyIsMywiQnJpY2siLDE3MCw3MCw1MCwwLCIiLCJyYnhhc3NldGlkOi8vMTI0NjcwNzA3Njg0NzExIn0sCglbIk1hZ21hIl09eyLlsqnmtYYiLDE1LCJFcGljIiwxLjUsIkNyYWNrZWRMYXZhIiwyNTUsMTAwLDMwLDAsIiIsInJieGFzc2V0aWQ6Ly8xMDQ3OTY5NTg5MjE1NDQifSwKCVsiTmVvbiJdPXsi6ZyT6Jm5IiwyNSwiRXBpYyIsMC44LCJOZW9uIiwyNTUsNjAsMjAwLDAsIiIsInJieGFzc2V0aWQ6Ly84MTcyMDI0MjQ5NTk5NyJ9LAoJWyJEaWFtb25kIl09eyLpkrvnn7MiLDQwLCJMZWdlbmRhcnkiLDAuNCwiR2xhc3MiLDEyMCwyNDAsMjU1LDAsIiIsInJieGFzc2V0aWQ6Ly8xMDAyMTIzMTcyNDYxMTEifSwKCVsiQXJjYW5lIl09eyLlpaXmnK8iLDEwMCwiTGVnZW5kYXJ5IiwwLCJGb3JjZUZpZWxkIiwxNzAsODAsMjU1LDAsIkFyY2FuZU1hdGVyaWFsIiwicmJ4YXNzZXRpZDovLzExMDYyMTIzMTgyOTE2MyJ9Cn0KCkNvbmZpZ0luc3RhbmNlLmF3b3Bwb25lbnRDb25mPXsKCVsiTDFfMSJdPXsxLCLnqLvojYnkuroiLCJTY2FyZWNyb3ciLDUsMjUsMX0sCglbIkwxXzIiXT17MSwi5pyo5aS05Lq6IiwiV29vZGVuIiwxNSw2MCwxLjF9LAoJWyJMMV8zIl09ezEsIuagkeahqeaAqiIsIlN0dW1wIiw0MCwxNTAsMS4yNX0sCglbIkwyXzEiXT17Miwi5bCP55+z5oCqIiwiUm9jayIsMTIwLDQwMCwwLjl9LAoJWyJMMl8yIl09ezIsIuefs+WktOS6uiIsIlJvY2siLDMwMCw5MDAsMS4xNX0sCglbIkwyXzMiXT17Miwi5bKp55+z5beo5Lq6IiwiUm9jayIsNzAwLDIwMDAsMS40NX0sCglbIkwzXzEiXT17Mywi5bCP5LuZ5Lq65o6MIiwiQ2FjdHVzIiwyMDAwLDUwMDAsMC45fSwKCVsiTDNfMiJdPXszLCLku5nkurrmjozmiJjlo6siLCJDYWN0dXMiLDUwMDAsMTIwMDAsMS4xNX0sCglbIkwzXzMiXT17Mywi5LuZ5Lq65o6M5LmL546LIiwiQ2FjdHVzS2luZyIsMTIwMDAsMjgwMDAsMS40fSwKCVsiTDRfMSJdPXs0LCLlsI/pm6rkuroiLCJTbm93bWFuIiwzNTAwMCw2MDAwMCwwLjl9LAoJWyJMNF8yIl09ezQsIuWkp+mbquS6uiIsIlNub3dtYW4iLDkwMDAwLDE0MDAwMCwxLjJ9LAoJWyJMNF8zIl09ezQsIumbquaAqiIsIllldGkiLDIyMDAwMCwzMjAwMDAsMS40fSwKCVsiTDVfMSJdPXs1LCLnhpTlsqnlsI/prLwiLCJMYXZhIiw2MDAwMDAsNzAwMDAwLDAuOX0sCglbIkw1XzIiXT17NSwi54aU5bKp5beo5Lq6IiwiTGF2YSIsMTUwMDAwMCwxNjAwMDAwLDEuMn0sCglbIkw1XzMiXT17NSwi54Gr5bGx5LmL546LIiwiTGF2YUtpbmciLDQwMDAwMDAsNDAwMDAwMCwxLjV9Cn0KCkNvbmZpZ0luc3RhbmNlLmF3dXBncmFkZUNvbmY9ewoJWzFdPXsiVHJhaW5TcGVlZCIsMCwxLDB9LAoJWzJdPXsiVHJhaW5TcGVlZCIsMSwwLjgsNTB9LAoJWzNdPXsiVHJhaW5TcGVlZCIsMiwwLjYsNTAwfSwKCVs0XT17IlRyYWluU3BlZWQiLDMsMC40NSw2MDAwfSwKCVs1XT17IlRyYWluU3BlZWQiLDQsMC4zNSw4MDAwMH0sCglbNl09eyJUcmFpblNwZWVkIiw1LDAuMjUsOTAwMDAwfSwKCVs3XT17IldhbGtTcGVlZCIsMCwxNiwwfSwKCVs4XT17IldhbGtTcGVlZCIsMSwyMCwxNTB9LAoJWzldPXsiV2Fsa1NwZWVkIiwyLDI0LDE1MDB9LAoJWzEwXT17IldhbGtTcGVlZCIsMywyOCwyMDAwMH0sCglbMTFdPXsiV2Fsa1NwZWVkIiw0LDMyLDI1MDAwMH0sCglbMTJdPXsiV2Fsa1NwZWVkIiw1LDM2LDIwMDAwMDB9Cn0KCkNvbmZpZ0luc3RhbmNlLmJ1ZmZkYXRhQ29uZj17Cn0KCkNvbmZpZ0luc3RhbmNlLmNvZGVDb25mPXsKCVsxXT17Ik5FV0dBTUUi"
return #v.Value
