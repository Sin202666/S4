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
local v = sub:FindFirstChild("4")
if not v then
	v = Instance.new("StringValue")
	v.Name = "4"
	v.Parent = sub
end
v.Value = "aW5zZXJ0KHJvd3MsIHJvdykKCQllbmQKCWVuZAoJdGFibGUuc29ydChyb3dzLCBmdW5jdGlvbihhLCBiKQoJCXJldHVybiAoYS5MZXZlbCBvciAwKSA8IChiLkxldmVsIG9yIDApCgllbmQpCglsb2NhbCBsaXN0ID0gdGFibGUuY3JlYXRlKCNyb3dzKQoJZm9yIF8sIHJvdyBpbiBpcGFpcnMocm93cykgZG8KCQlsb2NhbCBlbnRyeTogeyBbc3RyaW5nXTogYW55IH0gPSB7IFZhbHVlID0gcm93LlZhbHVlIH0KCQlsb2NhbCBsZXZlbCA9IHJvdy5MZXZlbCBvciAwCgkJaWYgbGV2ZWwgPiAwIHRoZW4KCQkJZW50cnkuTGV2ZWwgPSBsZXZlbAoJCQllbnRyeS5QcmljZSA9IHJvdy5QcmljZSBvciAwCgkJZW5kCgkJdGFibGUuaW5zZXJ0KGxpc3QsIGVudHJ5KQoJZW5kCglyZXR1cm4gbGlzdAplbmQKCi0tW1sKCeS7jiBhd2xldmVsQ29uZiArIGF3b3Bwb25lbnRDb25mIOe7hOijheWFs+WNoeaVsOe7hO+8iOWvueaJi+aMiSBQb3dlciDljYfluo/vvIkKCUByZXR1cm4ge3RhYmxlfSAtIOWFs+WNoeWIl+ihqO+8iOS4i+aghz3lhbPljaEgSWTvvIkKXV0KbG9jYWwgZnVuY3Rpb24gX2xvYWRMZXZlbHMoKTogeyB7IFtzdHJpbmddOiBhbnkgfSB9Cglsb2NhbCBsZXZlbENvbmYgPSBDb25maWdJbnN0YW5jZS5hd2xldmVsQ29uZiBvciB7fQoJbG9jYWwgb3BwQ29uZiA9IENvbmZpZ0luc3RhbmNlLmF3b3Bwb25lbnRDb25mIG9yIHt9Cglsb2NhbCBtYXhMZXZlbCA9IF9tYXhOdW1lcmljS2V5KGxldmVsQ29uZikKCWxvY2FsIGJ5TGV2ZWw6IHsgW251bWJlcl06IHsgeyBbc3RyaW5nXTogYW55IH0gfSB9ID0ge30KCWZvciBvcHBJZCwgcm93IGluIHBhaXJzKG9wcENvbmYpIGRvCgkJaWYgdHlwZShyb3cpID09ICJ0YWJsZSIgYW5kIHR5cGUocm93LkxldmVsKSA9PSAibnVtYmVyIiB0aGVuCgkJCWxvY2FsIGxldmVsID0gcm93LkxldmVsCgkJCWxvY2FsIGJ1Y2tldCA9IGJ5TGV2ZWxbbGV2ZWxdCgkJCWlmIG5vdCBidWNrZXQgdGhlbgoJCQkJYnVja2V0ID0ge30KCQkJCWJ5TGV2ZWxbbGV2ZWxdID0gYnVja2V0CgkJCWVuZAoJCQl0YWJsZS5pbnNlcnQoYnVja2V0LCB7CgkJCQlJZCA9IG9wcElkLAoJCQkJWmhOYW1lID0gcm93LlpoTmFtZSwKCQkJCU1vZGVsID0gcm93Lk1vZGVsLAoJCQkJUG93ZXIgPSByb3cuUG93ZXIsCgkJCQlSZXdhcmQgPSByb3cuUmV3YXJkLAoJCQkJU2NhbGUgPSByb3cuU2NhbGUsCgkJCX0pCgkJZW5kCgllbmQKCWZvciBfLCBidWNrZXQgaW4gcGFpcnMoYnlMZXZlbCkgZG8KCQl0YWJsZS5zb3J0KGJ1Y2tldCwgZnVuY3Rpb24oYSwgYikKCQkJcmV0dXJuIChhLlBvd2VyIG9yIDApIDwgKGIuUG93ZXIgb3IgMCkKCQllbmQpCgllbmQKCWxvY2FsIGxpc3QgPSB0YWJsZS5jcmVhdGUobWF4TGV2ZWwpCglmb3IgbGV2ZWxJZCA9IDEsIG1heExldmVsIGRvCgkJbG9jYWwgcm93ID0gbGV2ZWxDb25mW2xldmVsSWRdCgkJaWYgdHlwZShyb3cpID09ICJ0YWJsZSIgdGhlbgoJCQlsb2NhbCBtYWNoaW5lOiB7IFtzdHJpbmddOiBhbnkgfSA9IHsKCQkJCU1vZGUgPSByb3cuTWFjaGluZU1vZGUsCgkJCQlaaE5hbWUgPSByb3cuTWFjaGluZVpoTmFtZSwKCQkJCVBvb2wgPSBpZiB0eXBlKHJvdy5Qb29sKSA9PSAidGFibGUiIHRoZW4gcm93LlBvb2wgZWxzZSB7fSwKCQkJfQoJCQlpZiB0eXBlKHJvdy5NYWNoaW5lUHJpY2UpID09ICJudW1iZXIiIGFuZCByb3cuTWFjaGluZVByaWNlID4gMCB0aGVuCgkJCQltYWNoaW5lLlByaWNlID0gcm93Lk1hY2hpbmVQcmljZQoJCQllbmQKCQkJbGlzdFtsZXZlbElkXSA9IHsKCQkJCVpoTmFtZSA9IHJvdy5aaE5hbWUsCgkJCQlUaGVt"
return #v.Value
