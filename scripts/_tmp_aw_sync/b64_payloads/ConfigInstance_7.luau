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
local v = sub:FindFirstChild("7")
if not v then
	v = Instance.new("StringValue")
	v.Name = "7"
	v.Parent = sub
end
v.Value = "dW1wUHVzaEFjY2VsXCI6NzAsXCJBYm91dEZhY2VUcmF2ZWxEb3RcIjotMC43NSxcIlR1cm5DcnVpc2VEb3RcIjowLjg1LFwiVHVyblBpdm90QmFja1N0dWRzXCI6My41LFwiRG91YmxlSnVtcE1pbkZsYXRcIjoxOCxcIkRyaXZlTW9kZVwiOlwiTW91bnRSb290XCIsXCJHcm91bmRDbGVhcmFuY2VcIjowLjA4LFwiV2Fsa1NwZWVkTXVsXCI6MC40MixcIkdhbGxvcEVudGVyVGhyb3R0bGVcIjowLjgyLFwiR2FsbG9wRW50ZXJIb2xkU2VjXCI6MC41NSxcIkdhbGxvcEV4aXRUaHJvdHRsZVwiOjAuMjgsXCJXYWxrQWNjZWxTZWNcIjowLjUsXCJHYWxsb3BBY2NlbFNlY1wiOjEuMDUsXCJTbGlwRGVjZWxTZWNcIjoxLjg1LFwiQnJha2VEZWNlbFNlY1wiOjAuNTUsXCJCcmFrZVNwZWVkMDFcIjowLjM2LFwiRG91YmxlSnVtcEFpckRlbGF5U2VjXCI6MC4xMn0ifSwKCVs2MDAyMDAxXT17Iua1i+ivleWQieaZriIsIldoZWVsZWRWZWhpY2xlIiwiTW91bnRfSmVlcF9UZXN0Iiw1LCJGb3JjZUV4aXQiLCIiLDIsMCwiIiwiTW91bnRWZWhpY2xlIiwiIiwie1wiTWF4U3BlZWRcIjo4MCxcIkFjY2VsZXJhdGlvblwiOjQwLFwiVHVyblJhZGl1c1wiOjEyfSJ9LAoJWzYwMDMwMDFdPXsi5rWL6K+V6aOe6b6ZIiwiRmx5aW5nQ3JlYXR1cmUiLCJNb3VudF9EcmFnb25fVGVzdCIsOCwiRm9yY2VFeGl0IiwiIiw0LDAsIk1vdW50RHJhZ29uIiwiTW91bnRGbHlpbmciLCJNb3VudERyYWdvbkJhc2ljIiwie1wiTWF4QWx0aXR1ZGVcIjoyMDAsXCJDbGltYlJhdGVcIjo0MCxcIkRlc2NlbmRSYXRlXCI6MzUsXCJIb3ZlckFsbG93ZWRcIjoxfSJ9LAoJWzYwMDQwMDFdPXsi5rWL6K+V55u05Y2H5py6IiwiQWlyY3JhZnQiLCJNb3VudF9IZWxpY29wdGVyX1Rlc3QiLDEwLCJGb3JjZUV4aXQiLCIiLDQsMCwiUGlsb3RTZWF0IiwiTW91bnRBaXJjcmFmdCIsIk1vdW50SGVsaUJhc2ljIiwie1wiQ29udHJvbFNjaGVtZVwiOlwiSGVsaWNvcHRlclwiLFwiTWF4U3BlZWRcIjo5MCxcIkhvdmVyVGhydXN0XCI6NTB9In0KfQoKQ29uZmlnSW5zdGFuY2Uub25saW5lYXdhcmRDb25mPXsKCVsxXT17MSwxMDAsMzAwLCIifSwKCVsyXT17MSwyMDAsNjAwLCIifSwKCVszXT17MSw0MDAsOTAwLCIifSwKCVs0XT17MSw4MDAsMTIwMCwiIn0sCglbNV09ezEsMTUwMCwxNTAwLCIifSwKCVs2XT17MSwzMDAwLDE4MDAsIiJ9LAoJWzddPXsxLDUwMDAsMjEwMCwiIn0sCglbOF09ezEsODAwMCwyNDAwLCIifSwKCVs5XT17MSwxMjAwMCwyNzAwLCIifSwKCVsxMF09ezEsMjAwMDAsMzAwMCwiIn0sCglbMTFdPXsxLDMwMDAwLDMzMDAsIiJ9LAoJWzEyXT17MSw1MDAwMCwzNjAwLCIifQp9CgpDb25maWdJbnN0YW5jZS5wZXRDb25mPXsKCVs1MDAxMTAxXT17IuWuoOeJqeibizEiLDIsNSx7MSwyfSx7MSwxfSwi5o6S55CD54uXIiwi5o6S55CD54uXIiwxLjJ9LAoJWzUwMDExMDJdPXsi5a6g54mp6JuLMSIsMyw1LHsxLDJ9LHsxLDF9LCLkuZLkuZPnkIPlhZQiLCLkuZLkuZPnkIPlhZQiLDEuNX0sCglbNTAwMTEwM109eyLlrqDnianom4sxIiw0LDUsezEsMn0sezEsMX0sIuevrueQg+eGiiIsIuevrueQg+eGiiIsMn0sCglbNTAwMTIwMV09eyLlrqDnianom4syIiwyLDUsezEsMn0sezEsMX0sIumTheeslOicgiIsIumTheeslOicgiIsMn0sCglbNTAwMTIwMl09eyLlrqDnianom4syIiwzLDUsezEsMn0sezEsMX0sIuS5puacrOeGiiIsIuS5puacrOeGiiIsM30sCglbNTAwMTIwM109eyLlrqDnianom4syIiw0LDUsezEsMn0sezEsMX0sIuWwuuWtkOixuSIsIuWwuuWtkOixuSIsNH0sCglbNTAwMTIwNF09eyLlrqDnianom4syIiw1"
return #v.Value
