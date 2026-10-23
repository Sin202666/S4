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
local v = sub:FindFirstChild("8")
if not v then
	v = Instance.new("StringValue")
	v.Name = "8"
	v.Parent = sub
end
v.Value = "LDUsezEsMn0sezEsMX0sIuWNmuWjq+eMtCIsIuWNmuWjq+eMtCIsNX0sCglbNTAwMTMwMV09eyLlrqDnianom4szIiwyLDUsezEsMn0sezEsMX0sIuWFlOWtkOWQkeWvvCIsIuWFlOWtkOWQkeWvvCIsNX0sCglbNTAwMTMwMl09eyLlrqDnianom4szIiwzLDUsezEsMn0sezEsMX0sIuaOoumZqeadvum8oCIsIuaOoumZqeadvum8oCIsNn0sCglbNTAwMTMwM109eyLlrqDnianom4szIiw0LDUsezEsMn0sezEsMX0sIuefv+W3peeMq+eMqyIsIuefv+W3peeMq+eMqyIsN30sCglbNTAwMTMwNF09eyLlrqDnianom4szIiw4MCw1LHsxLDJ9LHsxLDF9LCLlr7vlrp3osbkiLCLlr7vlrp3osbkiLDEwfQp9CgpDb25maWdJbnN0YW5jZS5wZXRlZ2dDb25mPXsKCVs3MDAwMDAxXT17IkVnZzEiLCJFZ2cxIiwiRWdnMSIsNyx7NTAwMTEwMSw1MDAxMTAyLDUwMDExMDN9LHs1MjQwMDAsMzAwMDAwLDExMDAwMH0sMSwyLCLlrqDnianom4sxIn0sCglbNzAwMDAwMl09eyJFZ2cyIiwiRWdnMiIsIkVnZzIiLDcsezUwMDEyMDEsNTAwMTIwMiw1MDAxMjAzLDUwMDEyMDR9LHs1MjQwMDAsMzAwMDAwLDExMDAwMCw1MDAwMH0sMSwzMDAsIuWuoOeJqeibizIifSwKCVs3MDAwMDAzXT17IkVnZzMiLCJFZ2czIiwiRWdnMyIsNyx7NTAwMTMwMSw1MDAxMzAyLDUwMDEzMDMsNTAwMTMwNH0sezUyNDAwMCwzMDAwMDAsMTEwMDAwLDUwMDAwfSwxLDIwMDAsIuWuoOeJqeibizMifQp9CgpDb25maWdJbnN0YW5jZS5zZXR0aW5nQ29uZj17CglbMV09eyLnp7Dlj7ciLCJFcXVpcFRpdGxlIiwxLDMsMCx7fSwiIix7fSwxLCIifSwKCVsyXT17IuWFkeaNoueggSIsIkNvZGUiLDEsNCwwLHt9LCIiLHsi6K+36L6T5YWl5YWR5o2i56CBIn0sMSwiIn0sCglbM109eyLog4zmma/pn7PkuZAiLCJCR00iLDIsMSwxMDAsezAsMTAwfSwiIix7fSwxLCIifSwKCVs0XT17Iua4uOaIj+mfs+aViCIsIkVGRkVDVCIsMiwxLDEwMCx7MCwxMDB9LCIiLHt9LDEsIiJ9LAoJWzVdPXsi5Lu75YqhIiwiVEFTSyIsNSwwLDAsezAsMX0sIiIseyLlhbPpl60iLCLlvIDlkK8ifSwwLCIifSwKCVs2XT17IuWbvuWDj+i0qOmHjyIsIkdyYXBoaWNzUXVhbGl0eSIsMywzLDEsezAsMX0sIiIseyLkvY4iLCLpq5gifSwxLCIifSwKCVs3XT17IueVjOmdouWwuuWvuCIsIlBvcFNjYWxlIiwzLDEsMTAwLHs3NSwxMDB9LCIiLHt9LDAsIiJ9LAoJWzhdPXsi5b+r5o235qCP5bC65a+4IiwiVG9vbFNjYWxlIiwzLDEsMTAwLHs1MCwxNTB9LCIiLHt9LDAsIiJ9LAoJWzldPXsi54mp55CG5pWI5p6cIiwiUHloc2ljIiwzLDIsMSx7MCwxfSwiIix7IuWFs+mXrSIsIuW8gOWQryJ9LDEsIiJ9LAoJWzEwXT17IuWxj+W5lemch+WKqCIsIlNoYWtlIiwzLDEsMTAwLHswLDEwMH0sIiIse30sMSwiIn0sCglbMTFdPXsi556E5YeG5qih5byPIiwiQUlMb2NrIiw0LDMsMSx7MCwxfSwiIix7Iui3n+maj+m8oOaghyIsIuaZuuiDvemUgeWumiJ9LDEsIjEifSwKCVsxMl09eyLoh6rliqjplIHmlYwiLCJUYXJnZXRTZWxlY3RNb2RlIiw0LDMsMCx7MCwxfSwiIix7IumUgeWumuW9k+WJjeebruaghyIsIumUgeWumuacgOi/keebruaghyJ9LDEsIiJ9LAoJWzEzXT17IumVv+aMieaUu+WHuyIsIkhvbGRBdGsiLDQsMiwxLHswLDF9LCIiLHsi5YWz6ZetIiwi5byA5ZCvIn0sMSwiIn0sCglbMTRdPXsi6ZqQ6JeP5aS06YOo6aWw5ZOBIiwiSGlkZVNlbGZIYXQiLDUsMiwwLHswLDF9LCIiLHsi5YWz6ZetIiwi5byA5ZCvIn0sMSwiIn0sCglbMTVdPXsi6ZqQ6JeP5ber5biI6KKNIiwiSGlkZVNlbGZSb2JlIiw1LDIsMCx7MCwxfSwiIix7IuWFs+mXrSIsIuW8gOWQryJ9LDEs"
return #v.Value
