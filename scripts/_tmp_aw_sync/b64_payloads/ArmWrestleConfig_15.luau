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
local v = sub:FindFirstChild("15")
if not v then
	v = Instance.new("StringValue")
	v.Name = "15"
	v.Parent = sub
end
v.Value = "IGkgPCAjc3VmZml4ZXMgZG8KCQluIC89IDEwMDAKCQlpICs9IDEKCWVuZAoJaWYgaSA9PSAxIHRoZW4KCQlpZiBuID09IG1hdGguZmxvb3IobikgdGhlbgoJCQlyZXR1cm4gdG9zdHJpbmcobikKCQllbmQKCQlyZXR1cm4gc3RyaW5nLmZvcm1hdCgiJS4xZiIsIG4pCgllbmQKCWxvY2FsIHMgPSBzdHJpbmcuZm9ybWF0KCIlLjJmIiwgbik6Z3N1YigiJS4/MCskIiwgIiIpCglyZXR1cm4gcyAuLiBzdWZmaXhlc1tpXQplbmQKCi0tW1sKCeaVsOWtl+e8qeWGme+8jOS/neeVmeS4ieS9jeacieaViOaVsOWtl++8iDEuMDBUIC8gMTAuMEIgLyAxMDBC77yJ77yM55So5LqO5ZWG5ZOB5Lu3562+CglAcGFyYW0gbiBudW1iZXIgLSDljp/lgLwKCUByZXR1cm4gc3RyaW5nIC0g5bGV56S65Liy77yb5bCP5LqOIDEwMDAg5Y+W5pW0Cl1dCmZ1bmN0aW9uIEFybVdyZXN0bGVDb25maWcuRm9ybWF0Rml4ZWQobjogbnVtYmVyKTogc3RyaW5nCgluID0gbWF0aC5tYXgodG9udW1iZXIobikgb3IgMCwgMCkKCWxvY2FsIHN1ZmZpeGVzID0geyAiIiwgIksiLCAiTSIsICJCIiwgIlQiLCAiUWEiLCAiUWkiIH0KCWxvY2FsIGkgPSAxCgktLSA5OTkuNSDnuqfliKvlm5voiI3kupTlhaXlkI7kvJrlj5jmiJAgNCDkvY3mlbTmlbDvvIzmj5DliY3ov5vkvY3liLDkuIvkuIDkuKrljZXkvY0KCXdoaWxlIG4gPj0gOTk5LjUgYW5kIGkgPCAjc3VmZml4ZXMgZG8KCQluIC89IDEwMDAKCQlpICs9IDEKCWVuZAoJaWYgaSA9PSAxIHRoZW4KCQlyZXR1cm4gdG9zdHJpbmcobWF0aC5mbG9vcihuICsgMC41KSkKCWVuZAoJbG9jYWwgZm10ID0gaWYgbiA+PSA5OS45NSB0aGVuICIlLjBmIiBlbHNlaWYgbiA+PSA5Ljk5NSB0aGVuICIlLjFmIiBlbHNlICIlLjJmIgoJcmV0dXJuIHN0cmluZy5mb3JtYXQoZm10LCBuKSAuLiBzdWZmaXhlc1tpXQplbmQKCi0tW1sKCeWFs+WNoeWOn+eCuQoJQHBhcmFtIGxldmVsSW5kZXggbnVtYmVyIC0gMS1iYXNlZAoJQHJldHVybiBWZWN0b3IzIC0g5Y6f54K5Cl1dCmZ1bmN0aW9uIEFybVdyZXN0bGVDb25maWcuWm9uZU9yaWdpbihsZXZlbEluZGV4OiBudW1iZXIpOiBWZWN0b3IzCglyZXR1cm4gVmVjdG9yMy5uZXcoKGxldmVsSW5kZXggLSAxKSAqIEFybVdyZXN0bGVDb25maWcuWm9uZUxlbmd0aCwgMCwgMCkKZW5kCgotLVtbCgnlr7nlsYDnu5PmnZ/lh7rlnLrkvY3lp7/vvJpFWElUX0FUVFIg5rK/5YW25pyd5ZCR5aSW5o6oIEVYSVRfUFVTSF9TVFVEU++8jOWGjeawtOW5s+i9rOWQkeahjOWtkO+8jOaWueS+v+eOqeWutui9rOi6q+WwseiDveWGjeasoeS6pOS6kgoJ77yI5pyN5Yqh56uvIEJhdHRsZSDlh7rlnLrlhpkgSFJQ44CB5a6i5oi356uv5Lqk6L+Y6ZWc5aS05pe25pGG5py65L2N5YWx55So77yM5L+d6K+B5Lik5L6n5pyd5ZCR5LiA6Ie077yJCglAcGFyYW0gdGFibGVNb2RlbCBNb2RlbCAtIOavlOi1m+ahjO+8iOivuyBFWElUX0FUVFLvvIzmoYzpnaLkuK3lv4Por7sgUGl2b3Qg5bGe5oCn77yM57y655yB55So5qih5Z6LIFBpdm9077yJCglAcmV0dXJuIENGcmFtZT8gLSDlh7rlnLogSFJQIOS9jeWnv++8iOmdouacneahjOWtkO+8ie+8m+ahjOWtkOe8uuWwkSBFWElUX0FUVFIg5pe25Li6IG5pbApdXQpmdW5jdGlvbiBBcm1XcmVzdGxlQ29uZmlnLkdldEV4aXRDRnJhbWUodGFibGVNb2RlbDogTW9kZWwpOiBDRnJhbWU/Cglsb2NhbCBleGl0Q2YgPSB0YWJsZU1vZGVsOkdldEF0dHJpYnV0ZShBcm1XcmVzdGxlQ29uZmlnLkVYSVRfQVRUUikKCWlmIHR5cGVvZihleGl0Q2YpIH49ICJDRnJhbWUiIHRoZW4KCQlyZXR1cm4gbmlsCgllbmQKCWxvY2FsIHBvcyA9"
return #v.Value
