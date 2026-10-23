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
local sub = folder:FindFirstChild("ArmWrestleConfig")
if not sub then
	sub = Instance.new("Folder")
	sub.Name = "ArmWrestleConfig"
	sub.Parent = folder
end
local v = sub:FindFirstChild("8")
if not v then
	v = Instance.new("StringValue")
	v.Name = "8"
	v.Parent = sub
end
v.Value = "IFRpZXIgPSAzLCBNdWx0ID0gOCB9LAoJU3RyZW5ndGhUaWVyNCA9IHsgSWQgPSAzNzE4Njc0NDA4LCBaaE5hbWUgPSAi5Yqb6YeP5YCN5pWwIiwgUm9idXggPSAxOTksIEtpbmQgPSAiU3RyZW5ndGhUaWVyIiwgVGllciA9IDQsIE11bHQgPSAxNiB9LAoJU3RyZW5ndGhUaWVyNSA9IHsgSWQgPSAzNzE4Njc0NDE2LCBaaE5hbWUgPSAi5Yqb6YeP5YCN5pWwIiwgUm9idXggPSAzOTksIEtpbmQgPSAiU3RyZW5ndGhUaWVyIiwgVGllciA9IDUsIE11bHQgPSAzMiB9LAoJU3RyZW5ndGhUaWVyNiA9IHsgSWQgPSAzNzE4Njc0NDIwLCBaaE5hbWUgPSAi5Yqb6YeP5YCN5pWwIiwgUm9idXggPSA3OTksIEtpbmQgPSAiU3RyZW5ndGhUaWVyIiwgVGllciA9IDYsIE11bHQgPSA2NCB9LAoJLS0g5Yqb6YeP5YyF77ya5q+P5qyh6K6t57uD5Yqb6YePIMOXIEFtb3VudO+8jOmaj+i/m+W6puWinumVvwoJU3RyZW5ndGhQYWNrMSA9IHsgSWQgPSAzNzE4Njc0NDIxLCBaaE5hbWUgPSAi5Yqb6YeP5YyFIiwgUm9idXggPSAxOSwgS2luZCA9ICJTdHJlbmd0aCIsIEFtb3VudCA9IDIwMCB9LAoJU3RyZW5ndGhQYWNrMiA9IHsgSWQgPSAzNzE4Njc0NDI0LCBaaE5hbWUgPSAi5Yqb6YeP5YyFIiwgUm9idXggPSA5OSwgS2luZCA9ICJTdHJlbmd0aCIsIEFtb3VudCA9IDIwMDAgfSwKCVN0cmVuZ3RoUGFjazMgPSB7IElkID0gMzcxODY3NDQyOSwgWmhOYW1lID0gIuWKm+mHj+WMhSIsIFJvYnV4ID0gMjk5LCBLaW5kID0gIlN0cmVuZ3RoIiwgQW1vdW50ID0gMjAwMDAgfSwKCS0tIOiNr+awtO+8muWPkei0p+WPquaKiiBfUE9USU9OU1tQb3Rpb25LZXldLkl0ZW1JZCDliqDov5vog4zljIXvvIzkvb/nlKjlj6botbAgVXNlUG90aW9u77yb6ZSu5LiOIF9QT1RJT05TIOS4gOiHtAoJU3RyZW5ndGhQb3Rpb24gPSB7IElkID0gMzcxODY3NDQzNiwgWmhOYW1lID0gIuWKm+mHj+iNr+awtCIsIFJvYnV4ID0gNDksIEtpbmQgPSAiUG90aW9uIiwgUG90aW9uS2V5ID0gIlN0cmVuZ3RoUG90aW9uIiwgQ291bnQgPSAxIH0sCglUcmFpblNwZWVkUG90aW9uID0geyBJZCA9IDM3MTg2NzQ0MzcsIFpoTmFtZSA9ICLorq3nu4PpgJ/luqboja/msLQiLCBSb2J1eCA9IDQ5LCBLaW5kID0gIlBvdGlvbiIsIFBvdGlvbktleSA9ICJUcmFpblNwZWVkUG90aW9uIiwgQ291bnQgPSAxIH0sCglDYXNoUG90aW9uID0geyBJZCA9IDM3MTg2NzQ0MzgsIFpoTmFtZSA9ICLph5HluIHoja/msLQiLCBSb2J1eCA9IDQ5LCBLaW5kID0gIlBvdGlvbiIsIFBvdGlvbktleSA9ICJDYXNoUG90aW9uIiwgQ291bnQgPSAxIH0sCn0KCi0tIOiNr+awtO+8mkVmZmVjdCDkuLrnlJ/mlYjnu7TluqbvvIhTdHJlbmd0aCDmr4/mrKHorq3nu4Plipvph48gLyBUcmFpblNwZWVkIOiuree7g+mikeeOhyAvIENhc2gg5a+55bGA6YeR5biB77yJ77yMRHVyYXRpb24g5Li65Y2V55O25Zyo57q/56eS5pWw77yMSWNvbiDkuLogQXJtV3Jlc3RsZVN0eWxlLkljb25zIOeahOmUrgotLSBJdGVtSWQg5Li66IOM5YyF54mp5ZOBIElk77yIaXRlbWRhdGFDb25m77yJ77yM6aG75LiO6KGo5LitIFVzZVNjcmlwdCA9IEFybVdyZXN0bGVQb3Rpb27jgIFwYXJtcyA9IOacrOmUriDnmoTooYzkuIDkuIDlr7nlupQKbG9jYWwgX1BPVElPTlMgPSB7CglTdHJlbmd0aFBvdGlvbiA9IHsgWmhOYW1lID0gIuWKm+mHj+iNr+awtCIsIFpoRGVzID0gIuWKm+mHj+iNr+awtOaPj+i/sCIsIEVmZmVjdCA9ICJTdHJlbmd0aCIsIE11bHQgPSAyLCBEdXJhdGlvbiA9IDkwMCwgUHJvZHVjdEtleSA9ICJTdHJlbmd0aFBvdGlvbiIsIEljb24gPSAicG90aW9uU3RyZW5ndGgiLCBJ"
return #v.Value
