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
local v = sub:FindFirstChild("12")
if not v then
	v = Instance.new("StringValue")
	v.Name = "12"
	v.Parent = sub
end
v.Value = "IH0/LCBudW1iZXI/KQoJaWYgdHlwZShpZCkgfj0gInN0cmluZyIgdGhlbgoJCXJldHVybiBuaWwsIG5pbAoJZW5kCglmb3IgbGV2ZWxJbmRleCwgbGV2ZWwgaW4gaXBhaXJzKF9MRVZFTFMpIGRvCgkJZm9yIF8sIG9wcG9uZW50IGluIGlwYWlycyhsZXZlbC5PcHBvbmVudHMpIGRvCgkJCWlmIG9wcG9uZW50LklkID09IGlkIHRoZW4KCQkJCXJldHVybiBfY2xvbmUob3Bwb25lbnQpLCBsZXZlbEluZGV4CgkJCWVuZAoJCWVuZAoJZW5kCglyZXR1cm4gbmlsLCBuaWwKZW5kCgotLVtbCgnpgJrooYzor4HooajvvIjmt7Hmi7fotJ3vvIkKCUByZXR1cm4gdGFibGUgLSBrZXkg4oaSIOmFjee9rgpdXQpmdW5jdGlvbiBBcm1XcmVzdGxlQ29uZmlnLkdldEdhbWVQYXNzZXMoKTogeyBbc3RyaW5nXTogYW55IH0KCXJldHVybiBfY2xvbmUoX0dBTUVfUEFTU0VTKQplbmQKCi0tW1sKCeWNleadoemAmuihjOivgQoJQHBhcmFtIGtleSBzdHJpbmcgLSBBdXRvQ2xpY2tlciDnrYkKCUByZXR1cm4gdGFibGU/IC0g6YWN572uCl1dCmZ1bmN0aW9uIEFybVdyZXN0bGVDb25maWcuR2V0R2FtZVBhc3Moa2V5OiBzdHJpbmcpOiB7IFtzdHJpbmddOiBhbnkgfT8KCWxvY2FsIHJvdyA9IF9HQU1FX1BBU1NFU1trZXldCglpZiBub3Qgcm93IHRoZW4KCQlyZXR1cm4gbmlsCgllbmQKCXJldHVybiBfY2xvbmUocm93KQplbmQKCi0tW1sKCeaMiSBSb2Jsb3ggR2FtZVBhc3MgSWQg5p+l6YCa6KGM6K+B6ZSu77yISWQg5Li6IDAg55qEIFN0dWRpbyDljaDkvY3kuI3lj4LkuI7vvIkKCUBwYXJhbSBwYXNzSWQgbnVtYmVyIC0gR2FtZVBhc3Mg6LWE5LqnIElkCglAcmV0dXJuIHN0cmluZz8gLSDpgJrooYzor4HplK7vvIhBdXRvQ2xpY2tlciDnrYnvvInvvJvpnZ7mnKznjqnms5XpgJrooYzor4HkuLogbmlsCl1dCmZ1bmN0aW9uIEFybVdyZXN0bGVDb25maWcuRmluZEdhbWVQYXNzS2V5KHBhc3NJZDogbnVtYmVyKTogc3RyaW5nPwoJaWYgdHlwZShwYXNzSWQpIH49ICJudW1iZXIiIG9yIHBhc3NJZCA8PSAwIHRoZW4KCQlyZXR1cm4gbmlsCgllbmQKCWZvciBrZXksIHJvdyBpbiBwYWlycyhfR0FNRV9QQVNTRVMpIGRvCgkJaWYgcm93LklkID09IHBhc3NJZCB0aGVuCgkJCXJldHVybiBrZXkKCQllbmQKCWVuZAoJcmV0dXJuIG5pbAplbmQKCi0tW1sKCeWNleadoeiNr+awtOmFjee9rgoJQHBhcmFtIGtleSBzdHJpbmcgLSBTdHJlbmd0aFBvdGlvbiAvIFRyYWluU3BlZWRQb3Rpb24gLyBDYXNoUG90aW9uCglAcmV0dXJuIHRhYmxlPyAtIHsgWmhOYW1lLCBaaERlcywgRWZmZWN0ID0gIlN0cmVuZ3RoIiB8ICJUcmFpblNwZWVkIiB8ICJDYXNoIiwgTXVsdCwgRHVyYXRpb24o56eSKSwgUHJvZHVjdEtleSwgSWNvbihBcm1XcmVzdGxlU3R5bGUuSWNvbnMg6ZSuKSwgSXRlbUlkKOiDjOWMheeJqeWTgSBJZCkgfe+8m+acquefpemUruS4uiBuaWwKXV0KZnVuY3Rpb24gQXJtV3Jlc3RsZUNvbmZpZy5HZXRQb3Rpb24oa2V5OiBzdHJpbmcpOiB7IFtzdHJpbmddOiBhbnkgfT8KCWxvY2FsIHJvdyA9IF9QT1RJT05TW2tleV0KCWlmIG5vdCByb3cgdGhlbgoJCXJldHVybiBuaWwKCWVuZAoJcmV0dXJuIF9jbG9uZShyb3cpCmVuZAoKLS1bWwoJ5byA5Y+R6ICF5ZWG5ZOB6KGoCglAcmV0dXJuIHRhYmxlIC0ga2V5IOKGkiDphY3nva4KXV0KZnVuY3Rpb24gQXJtV3Jlc3RsZUNvbmZpZy5HZXRQcm9kdWN0cygpOiB7IFtzdHJpbmddOiBhbnkgfQoJcmV0dXJuIF9jbG9uZShfUFJPRFVDVFMpCmVuZAoKLS1bWwoJ5Y2V5p2h5ZWG5ZOBCglAcGFyYW0ga2V5IHN0cmluZyAtIOWVhuWTgemUrgoJQHJldHVybiB0YWJsZT8g"
return #v.Value
