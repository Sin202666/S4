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
local v = sub:FindFirstChild("2")
if not v then
	v = Instance.new("StringValue")
	v.Name = "2"
	v.Parent = sub
end
v.Value = "PXsi57+h57+g5LmL6IeCIiw5LCJFcGljIiwxMDAwMCwwLCIiLDAsNjAsMjIwLDExMCwicmJ4YXNzZXRpZDovLzEwNDM3MzA1Nzc0MjMwMCJ9LAoJWzhdPXsi57Sr5pm25LmL6IeCIiwxMywiRXBpYyIsNDAwMDAsMCwiIiwwLDE3MCw4MCwyNTUsInJieGFzc2V0aWQ6Ly8xMTY2NjkwMDAyMjEzNDIifSwKCVs5XT17IueDiOeEsOS5i+iHgiIsMTgsIkVwaWMiLDE1MDAwMCwwLCIiLDAsMjU1LDExMCwzMCwicmJ4YXNzZXRpZDovLzEyNTI4NTAzNTIxNTYwNCJ9LAoJWzEwXT17Iua3sea4iuS5i+iHgiIsMjUsIkVwaWMiLDYwMDAwMCwwLCIiLDAsMjAwLDMwLDYwLCJyYnhhc3NldGlkOi8vODI2NDUwMjM5MTY3MzYifSwKCVsxMV09eyLnpZ7lnKPkuYvoh4IiLDQwLCJMZWdlbmRhcnkiLDAsMjQ5LCJIb2x5QXJtIiwwLDI1NSwyMTUsOTAsInJieGFzc2V0aWQ6Ly83NTYyNzQxMzA2ODExMyJ9LAoJWzEyXT17IuWuoeWIpOS5i+iHgiIsNjAsIkxlZ2VuZGFyeSIsMCwzOTksIkp1ZGdlbWVudEFybSIsMjUwLDMwLDMwLDQwLCJyYnhhc3NldGlkOi8vMTA2NjM4OTk4MDQ5ODM0In0KfQoKQ29uZmlnSW5zdGFuY2UuYXdjb25zdENvbmY9ewoJWyJFWElUX1BVU0hfU1RVRFMiXT17M30sCglbIldJTl9DSU5FTUFUSUNfU0VDIl09ezQuNn0sCglbIldJTl9SRUxFQVNFX0RFTEFZX1NFQyJdPXs1LjJ9LAoJWyJMT1NFX1JFTEVBU0VfREVMQVlfU0VDIl09ezIuNn0sCglbIkxJTUlURURfQVJNX0lEIl09ezEyfSwKCVsiTElNSVRFRF9TT0xEX0RFRkFVTFQiXT17OTZ9LAoJWyJORUFSX01BQ0hJTkVfU1RVRFMiXT17MjV9LAoJWyJUQUJMRV9QUk9NUFRfRElTVEFOQ0UiXT17MTh9LAoJWyJST0xMX0FOSU1fU0VDIl09ezMuMn0sCglbIkZSSUVORF9CT09TVF9QRVIiXT17MC4xfSwKCVsiRlJJRU5EX0JPT1NUX01BWCJdPXswLjV9LAoJWyJQUkVNSVVNX0JPT1NUIl09ezAuMjV9LAoJWyJPRkZMSU5FX1JBVEUiXT17MC4xfSwKCVsiT0ZGTElORV9NSU5fU0VDIl09ezMwMH0sCglbIk9GRkxJTkVfTUFYX1NFQyJdPXsyODgwMH0sCglbIk1FTlVfR0lGVF9DQVNIX01VTFQiXT17MTB9LAoJWyJab25lTGVuZ3RoIl09ezE3MH0sCglbIlpvbmVXaWR0aCJdPXsxMzB9LAoJWyJCYXR0bGVUaW1lIl09ezE1fSwKCVsiVGFwUG93ZXIiXT17MC4wMzV9LAoJWyJPcHBvbmVudERyaWZ0Il09ezAuMTN9LAoJWyJNYXhUYXBzUGVyU2Vjb25kIl09ezE0fSwKCVsiQXV0b1RhcHNQZXJTZWNvbmQiXT17OH0KfQoKQ29uZmlnSW5zdGFuY2UuYXdkdW1iYmVsbENvbmY9ewoJWzFdPXsi6K6t57uD5ZOR6ZODIiwxLCJDb21tb24iLDAsMzUsMzUsNDAsIk1ldGFsIiwxLDE5MCwxOTAsMjAwLCJyYnhhc3NldGlkOi8vNzkxNDkzOTc1NDA2NDkifSwKCVsyXT17IumTgeeJh+WTkemTgyIsMS4zLCJDb21tb24iLDE1MCwxMTAsMTEwLDEyMCwiRGlhbW9uZFBsYXRlIiwxLjA1LDE5MCwxOTAsMjAwLCJyYnhhc3NldGlkOi8vMTA4NjA4Mjk4MjI3NjcwIn0sCglbM109eyLpnZLpk5zlk5Hpk4MiLDEuNywiVW5jb21tb24iLDYwMCwyMDUsMTI3LDUwLCJNZXRhbCIsMS4xLDE1MCw5NSw0NSwicmJ4YXNzZXRpZDovLzkxNjM0ODYzMzA4NDg3In0sCglbNF09eyLnmb3pk7blk5Hpk4MiLDIuMiwiVW5jb21tb24iLDIwMDAsMjE1LDIyMCwyMzAsIk1ldGFsIiwxLjE1LDE2MCwxNjUsMTc1LCJyYnhhc3NldGlkOi8vODM0NDQ1NTQ0MjM5MDYifSwKCVs1XT17Ium7hOmHkeWTkemTgyIsMywiUmFyZSIsNzAwMCwyNTUsMjAwLDQwLCJNZXRhbCIsMS4yLDIwMCwxNTAsMzAsInJieGFzc2V0aWQ6Ly8xMzQyMjk1OTEwMDQxMzAifSwKCVs2XT17IuWGsOaZ"
return #v.Value
