local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local lookup = {}
for i = 1, #alphabet do
	lookup[string.byte(alphabet, i)] = i - 1
end
local function b64decode(data: string): string
	data = string.gsub(data, "[^A-Za-z0-9+/=]", "")
	local out = table.create(math.ceil(#data * 3 / 4))
	local n = 0
	for i = 1, #data, 4 do
		local a = lookup[string.byte(data, i)] or 0
		local b = lookup[string.byte(data, i + 1)] or 0
		local c = lookup[string.byte(data, i + 2)] or 0
		local d = lookup[string.byte(data, i + 3)] or 0
		n += 1
		out[n] = string.char(bit32.bor(bit32.lshift(a, 2), bit32.rshift(b, 4)))
		if string.sub(data, i + 2, i + 2) ~= "=" then
			n += 1
			out[n] = string.char(bit32.band(bit32.bor(bit32.lshift(b, 4), bit32.rshift(c, 2)), 255))
		end
		if string.sub(data, i + 3, i + 3) ~= "=" then
			n += 1
			out[n] = string.char(bit32.band(bit32.bor(bit32.lshift(c, 6), d), 255))
		end
	end
	return table.concat(out)
end
local m = game.ReplicatedFirst.AllSideCode.ToolSystem.ArmWrestleConfig
m.Source ..= b64decode("IH0/LCBudW1iZXI/KQoJaWYgdHlwZShpZCkgfj0gInN0cmluZyIgdGhlbgoJCXJldHVybiBuaWwsIG5pbAoJZW5kCglmb3IgbGV2ZWxJbmRleCwgbGV2ZWwgaW4gaXBhaXJzKF9MRVZFTFMpIGRvCgkJZm9yIF8sIG9wcG9uZW50IGluIGlwYWlycyhsZXZlbC5PcHBvbmVudHMpIGRvCgkJCWlmIG9wcG9uZW50LklkID09IGlkIHRoZW4KCQkJCXJldHVybiBfY2xvbmUob3Bwb25lbnQpLCBsZXZlbEluZGV4CgkJCWVuZAoJCWVuZAoJZW5kCglyZXR1cm4gbmlsLCBuaWwKZW5kCgotLVtbCgnpgJrooYzor4HooajvvIjmt7Hmi7fotJ3vvIkKCUByZXR1cm4gdGFibGUgLSBrZXkg4oaSIOmFjee9rgpdXQpmdW5jdGlvbiBBcm1XcmVzdGxlQ29uZmlnLkdldEdhbWVQYXNzZXMoKTogeyBbc3RyaW5nXTogYW55IH0KCXJldHVybiBfY2xvbmUoX0dBTUVfUEFTU0VTKQplbmQKCi0tW1sKCeWNleadoemAmuihjOivgQoJQHBhcmFtIGtleSBzdHJpbmcgLSBBdXRvQ2xpY2tlciDnrYkKCUByZXR1cm4gdGFibGU/IC0g6YWN572uCl1dCmZ1bmN0aW9uIEFybVdyZXN0bGVDb25maWcuR2V0R2FtZVBhc3Moa2V5OiBzdHJpbmcpOiB7IFtzdHJpbmddOiBhbnkgfT8KCWxvY2FsIHJvdyA9IF9HQU1FX1BBU1NFU1trZXldCglpZiBub3Qgcm93IHRoZW4KCQlyZXR1cm4gbmlsCgllbmQKCXJldHVybiBfY2xvbmUocm93KQplbmQKCi0tW1sKCeaMiSBSb2Jsb3ggR2FtZVBhc3MgSWQg5p+l6YCa6KGM6K+B6ZSu77yISWQg5Li6IDAg55qEIFN0dWRpbyDljaDkvY3kuI3lj4LkuI7vvIkKCUBwYXJhbSBwYXNzSWQgbnVtYmVyIC0gR2FtZVBhc3Mg6LWE5LqnIElkCglAcmV0dXJuIHN0cmluZz8gLSDpgJrooYzor4HplK7vvIhBdXRvQ2xpY2tlciDnrYnvvInvvJvpnZ7mnKznjqnms5XpgJrooYzor4HkuLogbmlsCl1dCmZ1bmN0aW9uIEFybVdyZXN0bGVDb25maWcuRmluZEdhbWVQYXNzS2V5KHBhc3NJZDogbnVtYmVyKTogc3RyaW5nPwoJaWYgdHlwZShwYXNzSWQpIH49ICJudW1iZXIiIG9yIHBhc3NJZCA8PSAwIHRoZW4KCQlyZXR1cm4gbmlsCgllbmQKCWZvciBrZXksIHJvdyBpbiBwYWlycyhfR0FNRV9QQVNTRVMpIGRvCgkJaWYgcm93LklkID09IHBhc3NJZCB0aGVuCgkJCXJldHVybiBrZXkKCQllbmQKCWVuZAoJcmV0dXJuIG5pbAplbmQKCi0tW1sKCeWNleadoeiNr+awtOmFjee9rgoJQHBhcmFtIGtleSBzdHJpbmcgLSBTdHJlbmd0aFBvdGlvbiAvIFRyYWluU3BlZWRQb3Rpb24gLyBDYXNoUG90aW9uCglAcmV0dXJuIHRhYmxlPyAtIHsgWmhOYW1lLCBaaERlcywgRWZmZWN0ID0gIlN0cmVuZ3RoIiB8ICJUcmFpblNwZWVkIiB8ICJDYXNoIiwgTXVsdCwgRHVyYXRpb24o56eSKSwgUHJvZHVjdEtleSwgSWNvbihBcm1XcmVzdGxlU3R5bGUuSWNvbnMg6ZSuKSwgSXRlbUlkKOiDjOWMheeJqeWTgSBJZCkgfe+8m+acquefpemUruS4uiBuaWwKXV0KZnVuY3Rpb24gQXJtV3Jlc3RsZUNvbmZpZy5HZXRQb3Rpb24oa2V5OiBzdHJpbmcpOiB7IFtzdHJpbmddOiBhbnkgfT8KCWxvY2FsIHJvdyA9IF9QT1RJT05TW2tleV0KCWlmIG5vdCByb3cgdGhlbgoJCXJldHVybiBuaWwKCWVuZAoJcmV0dXJuIF9jbG9uZShyb3cpCmVuZAoKLS1bWwoJ5byA5Y+R6ICF5ZWG5ZOB6KGoCglAcmV0dXJuIHRhYmxlIC0ga2V5IOKGkiDphY3nva4KXV0KZnVuY3Rpb24gQXJtV3Jlc3RsZUNvbmZpZy5HZXRQcm9kdWN0cygpOiB7IFtzdHJpbmddOiBhbnkgfQoJcmV0dXJuIF9jbG9uZShfUFJPRFVDVFMpCmVuZAoKLS1bWwoJ5Y2V5p2h5ZWG5ZOBCglAcGFyYW0ga2V5IHN0cmluZyAtIOWVhuWTgemUrgoJQHJldHVybiB0YWJsZT8g")
return #m.Source
