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
local v = sub:FindFirstChild("0")
if not v then
	v = Instance.new("StringValue")
	v.Name = "0"
	v.Parent = sub
end
v.Value = "LS1bWwoJTW9kdWxlOiBBcm1XcmVzdGxlQ29uZmlnCglEZXNjcmlwdGlvbjog5omz5omL6IWV546p5rOV5YWx5Lqr6YWN572u77yI5YWz5Y2h44CB5omL6IeC44CB5p2Q6LSo44CB5ZOR6ZOD44CB5Y2H57qn44CB5ZWG5ZOB6KGo77yJCglBdXRob3I6IOeoi+iOmAoJQ3JlYXRlZDogMjAyNi0xMC0xNAoJTGFzdCBNb2RpZmllZDogMjAyNi0xMC0xNgoKCeWKn+iDve+8mgoJLSDmj5DkvpvlhbPljaEv5a+55omLL+aJi+iHgi/mnZDotKgv5ZOR6ZODL+iuree7g+S4juenu+mAn+mYtuOAgVN0dWRpbyDllYblk4HooagKCS0g5oiQ6ZW/5LiO5a+55bGA5pWw5YC85p2l6Ieq5a+86KGo77yaQVdDb25zdCAvIEFXTWF0ZXJpYWwgLyBBV0FybSAvIEFXRHVtYmJlbGwgLyBBV1VwZ3JhZGUgLyBBV0xldmVsIC8gQVdPcHBvbmVudAoJLSBBcHBseUR1bWJiZWxsTG9va++8muaMieWTkemTg+mFjee9rue7meaooeadv+WFi+mahuS9k+aUueiJsu+8iOacjeWKoeerr+WPkSBUb29s44CB5a6i5oi356uv5Y2h54mH6aKE6KeI5YWx55So77yJCgktIOaJi+iHgiAvIOadkOi0qCAvIOWTkemTg+adoeebrueahCBSYXJpdHkg5Z2H5oyH5ZCRIF9SQVJJVElFU++8iEdldFJhcml0ee+8ie+8jOS7heeUqOS6jiBVSSDlupXoibLjgIHmlofmoYjkuI7ooajnjrDmoaPkvY3vvIzkuI3lj4LkuI7nu5PnrpcKCS0g5omL6IeCIC8g5p2Q6LSoIC8g5ZOR6ZOD5p2h55uu55qEIEljb27vvJrlvLnnqpfljaHniYcgUHJldmlld++8iEltYWdlTGFiZWzvvInlsZXnpLrlm77vvIzluKbpu5Hmj4/ovrnnmoTpgI/mmI4gUE5H77yIcmJ4YXNzZXRpZO+8jOe+pOe7hOi1hOa6kO+8iQoJLSDmnZDotKjmir3lj5bmnYPph43or7vmnaHnm67oh6rouqsgV2VpZ2h077yI5LiO56iA5pyJ5bqm6Kej6ICm77yM5pS556iA5pyJ5bqm5LiN5pS55o6J546H77yJ77yb57y655yB5omN5Zue6YCAIF9SQVJJVElFUy5XZWlnaHTvvJtQb29sT2RkcyDku4XmjIkgV2VpZ2h0CgktIOafpeivoiBBUEkg5LiA5b6L6L+U5Zue5rex5ou36LSd77yM56aB5q2i5oqK5YaF5a2Y6KGo5rS75byV55So5Lqk57uZ6LCD55So5pa5CgktIOeOqeWutuWPr+ingeWQjeensOi1sCBaaE5hbWUgLyBaaERlc++8jOeUsSBUcmFuc2xhdGlvbkhlbHBlciDmjInlrZfpnaLph4/miJYgWmgqIOWtl+autee/u+ivkQoKCeS4juebuOWFs+aooeWdl++8mgoJLSBTeXN0ZW1Bcm1XcmVzdGxlIOivu+acrOihqOWBmuacjeWKoeerr+e7k+eul++8m+WuouaIt+err+WPquivu+WxleekugoJLSDkuI3lhpnlrZjmoaPjgIHkuI3lj5HlpZbjgIHkuI3nu5EgUmVtb3RlCgktIOeogOacieW6piAvIEdhbWVQYXNzIC8gRGV2ZWxvcGVyIFByb2R1Y3QgLyDoja/msLTku43mnKzmlofku7bluLjph4/ooajvvIjmnKrov5sgRXhjZWzvvIkKCS0g57q/5LiKIFJvYnV4IOWVhuWTgSBJZCDkuIDmnJ/lhajkuLogMO+8jOS7hSBTdHVkaW8gRGV2R3JhbnQg5Y+v55SoCgktIOWhq+WFpeecn+WuniBJZCDlkI7vvIxTdHJlbmd0aCAvIFN0cmVuZ3RoVGllciAvIENhc2ggLyBQb3Rpb24g56eN57G757uPIFN5c3RlbUJ1eVJvYmxveC5Qcm9jZXNzUmVjZWlwdCDluYLnrYnlj5HotKfvvIhGaW5kUmVjZWlwdFByb2R1Y3RLZXnvvIkKCS0g6YCa6KGM6K+B55yf5a6eIElkIOe7jyBGaW5kR2FtZVBhc3NLZXkg5Y+N5p+l77yb5oul5pyJ5p2D5LulIFJvYmxveCDkuLrlh4bvvIjov5vmnI0gVXNlck93bnNHYW1lUGFzc0FzeW5j77yJ77yM5LiN6JC95a2Y5qGjCgktIOWKm+mHj+WAjeaVsOahoyBTdHJlbmd0aFRpZXIxLi42IOS4uuabv+aNouW8j++8iHgyLi54NjTvvInvvIxHZXRTdHJlbmd0aFRpZXJN"
return #v.Value
