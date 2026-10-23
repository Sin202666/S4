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
local v = sub:FindFirstChild("1")
if not v then
	v = Instance.new("StringValue")
	v.Name = "1"
	v.Parent = sub
end
v.Value = "LCJVbmxvY2tJbmYiLCJoYXNDb3VudCIsInRwIiwiSWNvbiIsInh5ZCIsIkNvbG9yU3RyIn0sCml0ZW1kYXRhQ29uZj17IlpoTmFtZSIsInh5ZCIsIlVubG9ja0luZiIsImlzU2hvdyIsImlzQmFnIiwiaGFzQ291bnQiLCJiYWdUcCIsInRwIiwic29ydCIsIlpoRGVzIiwiVXNlTm93IiwiVXNlU2NyaXB0IiwicGFybXMiLCJJY29uIiwiTW9kZWwiLCJpbml0IiwibmV3UGxheWVySW5pdCIsIlNjcmlwdFR5cGVDbGllbnQiLCJTY3JpcHRUeXBlU2VydmVyIiwiWmhFZmZlY3REZXMiLCJub1Rvb2xiYXIifSwKaXRlbXNob3BkYXRhQ29uZj17IlpoTmFtZSIsIlpoRGVzIiwiT25seVRhZyIsIk5lZWRCdXkiLCJOZXh0QnVnIiwiQnV5TGltaXROdW0iLCJnYW1lUGFzc0l0ZW1JRCIsImNvc3QiLCJwYXNzSUQiLCJHaWZ0SUQiLCJwcmljZSIsIm9yaVByaWNlIiwiaXRlbUlEIiwiaXRlbUNvdW50IiwiSWNvbiIsIkNvbG9yU3RyIn0sCm1vdW50Q29uZj17IlpoTmFtZSIsIkxvY29tb3Rpb25UeXBlIiwiTW9kZWwiLCJTdW1tb25DZCIsIkNvbWJhdFBvbGljeSIsIkljb24iLCJ4eWQiLCJTcGVlZE11bCIsIkF0dGFjaE5hbWUiLCJDYW1lcmFQcm9maWxlIiwiQW5pbVNldCIsIkV4dEpzb24ifSwKb25saW5lYXdhcmRDb25mPXsiQXdhcmRJRCIsIkNvdW50SUQiLCJPbmxpblRpbWUiLCJJY29uIn0sCnBldENvbmY9eyJFZ2dOYW1lIiwieHlkIiwidHAiLCJTZWxsSXRlbSIsIlNlbGxDb3VudCIsIlpoTmFtZSIsIk1vZGVsIiwiUG93ZXJBZGQifSwKcGV0ZWdnQ29uZj17IkRpc05hbWUiLCJaaE5hbWUiLCJQb29sT25seVRhZyIsInRwIiwicG9vbCIsIndlaWdodCIsImNvc3QiLCJwcmljZSIsIk1vZGVsIn0sCnNldHRpbmdDb25mPXsiWmhOYW1lIiwiU2hvd05hbWUiLCJTZXRUeXBlIiwiVGVtcFR5cGUiLCJzZXQiLCJyYW5nZSIsImlzUGVjZW50IiwiWmhEZXMiLCJpc1Nob3ciLCJtb2JpZUZhZGUifSwKc2tpbGxDb25mPXsiWmhOYW1lIiwiU2NyaXB0TmFtZSIsIiIsIiIsIkljb24iLCJQcmlvcml0eSIsIlJhbmdlIiwiRWZmZWN0VGFyZ2V0IiwibmVlZENoZWNrIiwiaXNCYXNlIiwiZXhwIiwiIiwiRWxlbWVudFRwIiwiQXR0YWNrRWZmZWN0UG9zIiwiQ0QiLCJEYW1hZ2VSYXRlIiwiIiwiYnVmZnMiLCIiLCIiLCIiLCJGb3JjZUhpdEFuaW1hdGlvbiIsIlNpemUiLCJCYW5kIiwiU3VtbW9uQmFuZCJ9LAp1cGRhdGVsb2dDb25mPXsiVXBkYXRlVGltZSIsIlpoVGFnVGl0bGUiLCJaaFVwZGF0ZVRleHQifSwKfQoKQ29uZmlnSW5zdGFuY2UuYXdhcm1Db25mPXsKCVsxXT17IuaWsOaJi+S5i+iHgiIsMSwiQ29tbW9uIiwwLDAsIiIsMCwyMzQsMTg0LDE0NiwicmJ4YXNzZXRpZDovLzc0ODA5MDA2Mjg0MDMxIn0sCglbMl09eyLnu5Plrp7kuYvoh4IiLDEuNSwiQ29tbW9uIiw3NSwwLCIiLDAsMjA1LDE1MCwxMTAsInJieGFzc2V0aWQ6Ly83OTA2MDgxNzI3MTM1MiJ9LAoJWzNdPXsi6Z2S6ZOc5LmL6IeCIiwyLCJVbmNvbW1vbiIsMjUwLDAsIiIsMCwyMDUsMTI3LDUwLCJyYnhhc3NldGlkOi8vNzg5OTgwNjM4NjI3ODcifSwKCVs0XT17IumSoumTgeS5i+iHgiIsMywiVW5jb21tb24iLDYwMCwwLCIiLDAsMTYwLDE2NSwxNzUsInJieGFzc2V0aWQ6Ly8xMjUwMTcxOTIxMjgyNTgifSwKCVs1XT17IuWGsOaZtuS5i+iHgiIsNC41LCJSYXJlIiwxNTAwLDAsIiIsMCwxMTAsMjAwLDI1NSwicmJ4YXNzZXRpZDovLzEzNTc1ODgwNTU1MTgyNiJ9LAoJWzZdPXsi6Zu36ZyG5LmL6IeCIiw2LjUsIlJhcmUiLDQwMDAsMCwiIiwwLDI1NSwyMzAsNjAsInJieGFzc2V0aWQ6Ly85ODgyNzM5MTcxMTMzNiJ9LAoJWzdd"
return #v.Value
