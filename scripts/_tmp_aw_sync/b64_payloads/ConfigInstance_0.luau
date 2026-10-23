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
local v = sub:FindFirstChild("0")
if not v then
	v = Instance.new("StringValue")
	v.Name = "0"
	v.Parent = sub
end
v.Value = "CmxvY2FsIENvbmZpZ0luc3RhbmNlID17fQpDb25maWdJbnN0YW5jZS5rZXk9ewphd2FybUNvbmY9eyJaaE5hbWUiLCJNdWx0IiwiUmFyaXR5IiwiUHJpY2UiLCJSb2J1eCIsIlByb2R1Y3RLZXkiLCJMaW1pdGVkIiwiQ29sb3JSIiwiQ29sb3JHIiwiQ29sb3JCIiwiSWNvbiJ9LAphd2NvbnN0Q29uZj17IlZhbHVlIn0sCmF3ZHVtYmJlbGxDb25mPXsiWmhOYW1lIiwiTXVsdCIsIlJhcml0eSIsIlByaWNlIiwiUGxhdGVSIiwiUGxhdGVHIiwiUGxhdGVCIiwiUGxhdGVNYXQiLCJQbGF0ZVNjYWxlIiwiSGFuZGxlUiIsIkhhbmRsZUciLCJIYW5kbGVCIiwiSWNvbiJ9LAphd2xldmVsQ29uZj17IlpoTmFtZSIsIlRoZW1lIiwiR2F0ZSIsIkdyb3VuZE1hdCIsIkdyb3VuZFIiLCJHcm91bmRHIiwiR3JvdW5kQiIsIk1hY2hpbmVNb2RlIiwiTWFjaGluZVpoTmFtZSIsIk1hY2hpbmVQcmljZSIsIlBvb2wifSwKYXdtYXRlcmlhbENvbmY9eyJaaE5hbWUiLCJNdWx0IiwiUmFyaXR5IiwiV2VpZ2h0IiwiTWF0IiwiQ29sb3JSIiwiQ29sb3JHIiwiQ29sb3JCIiwiT2ZmZXJQcmljZSIsIlByb2R1Y3RLZXkiLCJJY29uIn0sCmF3b3Bwb25lbnRDb25mPXsiTGV2ZWwiLCJaaE5hbWUiLCJNb2RlbCIsIlBvd2VyIiwiUmV3YXJkIiwiU2NhbGUifSwKYXd1cGdyYWRlQ29uZj17IktpbmQiLCJMZXZlbCIsIlZhbHVlIiwiUHJpY2UifSwKYnVmZmRhdGFDb25mPXsiaXNTaG93IiwiWmhOYW1lIiwiYnVmZk5hbWUiLCJpc092ZXIiLCJkZXMiLCJhZGRQb3dlciIsIkljb24ifSwKY29kZUNvbmY9eyJjb2RlIiwiY29kZVR5cGUiLCJzdGFydFRpbWUiLCJlbmRUaW1lIiwicmV3YXJkSWQiLCJyZXdhcmROdW0ifSwKZGFpbHlhd2FyZENvbmY9eyJpbmRleCIsIndlZWsiLCJBd2FyZElEIiwiQ291bnRJRCIsIkJ0bkNvbG9yIiwiQnRuSWNvbiJ9LAplbmVteUNvbmY9eyJtb2RlbCIsIiIsInRwIiwiZGVzIiwiWmhOYW1lIiwiSW5qdXJlZFNvdW5kIiwiYW5pbUlkbGVOYW1lIiwiYW5pbVdhbGtOYW1lIiwiYW5pbVJ1bk5hbWUiLCJhbmltSGl0TmFtZSIsImFuaW1EaWVOYW1lIiwiYW5pbVN0dW5OYW1lIiwiQWkiLCJib3NzIiwieHlkIiwiTHYiLCJzcE1heCIsIm1vdmVTa2lsbCIsIm1vdmVTa2lsbENkIiwiZW5hYmxlUHJlQ2FzdE1vdmUiLCJza2lsbCIsImhwTGltaXRTa2lsbCIsInNraWxsQ2FzdE1vdmVTcGVlZE11bCIsImNkIiwicmdNaW4iLCJyZ01heCIsImF0dGFja1JhbmdlIiwicmFuZ2VyU2FmZURpc3RhbmNlIiwiY2hhc2VSdW5EaXN0YW5jZSIsIm1vdmVBd2F5IiwiYXQiLCJhdHYiLCJhdEluaGVyaXQiLCJwcm9hY3RpdmVEZXRlY3Rpb25BZ2dybyIsInN0dW5JbW11bmUiLCJkZXRlY3Rpb25SYW5nZSIsInBhdGllbnRSYW5nZSIsInBhdGllbnRUaW1lIiwiaWRsZVRpbWUiLCJ3YW5kZXJUaW1lIiwiY2hhc2VSdW5TcGVlZE11bCIsIndhbmRlclJhbmdlIiwiaGl0c3R1bkRpc2FibGVkIiwib3V0T2ZDb21iYXRSZWdlbkRlbGF5U2Vjb25kcyIsIm91dE9mQ29tYmF0UmVnZW5NYXhIZWFsdGhQZXJTZWNvbmQiLCJkZXNwYXduVGltZSIsImNoYW5nZVNraWxsIiwiaXNEZWFkTWFuIiwiYW5pbVdhbGtSZWZTcGVlZCIsImFuaW1SdW5SZWZTcGVlZCIsImlzaW5kZXgiLCJXb3JsZCIsImRlYXRoUHJlc2VudGF0aW9uIiwiRXZlbnRUcCIsIkljb24iLCJlZ2dJbml0SHBSYXRpbyIsImVnZ1JlZ2VuUGVyU2VjIiwiZWdnTWF4RGFtYWdlUGVySGl0IiwiZWdnSGF0Y2hJZHMiLCJlZ2dIYXRjaFdlaWdodHMiLCJyYW5nZXJNYXhNb3ZlRGlzdGFuY2UifSwKZ2FtZXBhc3NpdGVtQ29uZj17IlpoTmFtZSIsIk9ubHlUYWci"
return #v.Value
