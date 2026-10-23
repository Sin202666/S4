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
m.Source ..= b64decode("LSDphY3nva4KXV0KZnVuY3Rpb24gQXJtV3Jlc3RsZUNvbmZpZy5HZXRQcm9kdWN0KGtleTogc3RyaW5nKTogeyBbc3RyaW5nXTogYW55IH0/Cglsb2NhbCByb3cgPSBfUFJPRFVDVFNba2V5XQoJaWYgbm90IHJvdyB0aGVuCgkJcmV0dXJuIG5pbAoJZW5kCglyZXR1cm4gX2Nsb25lKHJvdykKZW5kCgotLVtbCgnmjIkgUm9ibG94IOW8gOWPkeiAheWVhuWTgSBJZCDmn6Xlj6/otbDmlLbmja7lj5HotKfnmoTllYblk4HplK7vvIhJZCDkuLogMCDnmoQgU3R1ZGlvIOWNoOS9jeS4jeWPguS4ju+8iQoJQHBhcmFtIHByb2R1Y3RJZCBudW1iZXIgLSDmlLbmja4gUHJvZHVjdElkCglAcmV0dXJuIHN0cmluZz8gLSDllYblk4HplK7vvJvpnZ7mnKznjqnms5XllYblk4HmiJbnp43nsbvkuI3mlK/mjIHmlLbmja7lj5HotKfml7bkuLogbmlsCl1dCmZ1bmN0aW9uIEFybVdyZXN0bGVDb25maWcuRmluZFJlY2VpcHRQcm9kdWN0S2V5KHByb2R1Y3RJZDogbnVtYmVyKTogc3RyaW5nPwoJaWYgdHlwZShwcm9kdWN0SWQpIH49ICJudW1iZXIiIG9yIHByb2R1Y3RJZCA8PSAwIHRoZW4KCQlyZXR1cm4gbmlsCgllbmQKCWZvciBrZXksIHJvdyBpbiBwYWlycyhfUFJPRFVDVFMpIGRvCgkJaWYgcm93LklkID09IHByb2R1Y3RJZCBhbmQgX1JFQ0VJUFRfS0lORFNbcm93LktpbmRdIHRoZW4KCQkJcmV0dXJuIGtleQoJCWVuZAoJZW5kCglyZXR1cm4gbmlsCmVuZAoKLS1bWwoJ5ZWG5ZOB6ZSu5piv5ZCm5YWB6K646LWw55yf5a6e5pS25o2u5Y+R6LSnCglAcGFyYW0ga2V5IHN0cmluZyAtIOWVhuWTgemUrgoJQHJldHVybiBib29sZWFuIC0gS2luZCDlsZ7kuo4gU3RyZW5ndGggLyBTdHJlbmd0aFRpZXIgLyBDYXNoIC8gUG90aW9uIOaXtuS4uiB0cnVlCl1dCmZ1bmN0aW9uIEFybVdyZXN0bGVDb25maWcuSXNSZWNlaXB0UHJvZHVjdChrZXk6IHN0cmluZyk6IGJvb2xlYW4KCWxvY2FsIHJvdyA9IF9QUk9EVUNUU1trZXldCglyZXR1cm4gcm93IH49IG5pbCBhbmQgX1JFQ0VJUFRfS0lORFNbcm93LktpbmRdID09IHRydWUKZW5kCgotLVtbCgnlipvph4/lgI3mlbDmnIDpq5jmoaMKCUByZXR1cm4gbnVtYmVyIC0g5qGj5pWw77yI5b2T5YmNIDbvvIzlr7nlupQgeDY077yJCl1dCmZ1bmN0aW9uIEFybVdyZXN0bGVDb25maWcuR2V0TWF4U3RyZW5ndGhUaWVyKCk6IG51bWJlcgoJcmV0dXJuICNfU1RSRU5HVEhfVElFUl9LRVlTCmVuZAoKLS1bWwoJ5oyJ5qGj5L2N5Y+W5Yqb6YeP5YCN5pWw5ZWG5ZOBCglAcGFyYW0gdGllciBudW1iZXIgLSAxLi5HZXRNYXhTdHJlbmd0aFRpZXIoKQoJQHJldHVybiBzdHJpbmc/IC0g5ZWG5ZOB6ZSu77yIU3RyZW5ndGhUaWVyMSDnrYnvvInvvJvotornlYzkuLogbmlsCglAcmV0dXJuIHRhYmxlPyAtIOWVhuWTgemFjee9rua3seaLt+i0nSB7IElkLCBaaE5hbWUsIFJvYnV4LCBLaW5kID0gIlN0cmVuZ3RoVGllciIsIFRpZXIsIE11bHQgfQpdXQpmdW5jdGlvbiBBcm1XcmVzdGxlQ29uZmlnLkdldFN0cmVuZ3RoVGllclByb2R1Y3QodGllcjogbnVtYmVyKTogKHN0cmluZz8sIHsgW3N0cmluZ106IGFueSB9PykKCWxvY2FsIGtleSA9IF9TVFJFTkdUSF9USUVSX0tFWVNbdGllcl0KCWlmIG5vdCBrZXkgdGhlbgoJCXJldHVybiBuaWwsIG5pbAoJZW5kCglyZXR1cm4ga2V5LCBfY2xvbmUoX1BST0RVQ1RTW2tleV0pCmVuZAoKLS1bWwoJ5bey6LSt5qGj5L2N5a+55bqU55qE5Yqb6YeP5oC75YCN5pWw77yI5pu/5o2i5byP77yM5LiN5LiO5L2O5qGj5Y+g5LmY77yJCglAcGFyYW0gdGllciBudW1iZXI/IC0g5a2Y5qGjIFN0cmVuZ3RoVGllcu+8m25pbCAvIDAgLyDpnZ7m")
return #m.Source
