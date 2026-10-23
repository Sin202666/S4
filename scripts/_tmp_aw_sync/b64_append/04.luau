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
m.Source ..= b64decode("b3cgPSBjb25mW2lkXQoJCWlmIHR5cGUocm93KSA9PSAidGFibGUiIHRoZW4KCQkJbG9jYWwgZW50cnk6IHsgW3N0cmluZ106IGFueSB9ID0gewoJCQkJSWQgPSBpZCwKCQkJCVpoTmFtZSA9IHJvdy5aaE5hbWUsCgkJCQlNdWx0ID0gcm93Lk11bHQsCgkJCQlSYXJpdHkgPSByb3cuUmFyaXR5LAoJCQkJUHJpY2UgPSByb3cuUHJpY2Ugb3IgMCwKCQkJCUNvbG9yID0gX3JnYihyb3cuQ29sb3JSLCByb3cuQ29sb3JHLCByb3cuQ29sb3JCKSwKCQkJCUljb24gPSByb3cuSWNvbiwKCQkJfQoJCQlpZiB0eXBlKHJvdy5Sb2J1eCkgPT0gIm51bWJlciIgYW5kIHJvdy5Sb2J1eCA+IDAgdGhlbgoJCQkJZW50cnkuUm9idXggPSByb3cuUm9idXgKCQkJZW5kCgkJCWlmIHR5cGUocm93LlByb2R1Y3RLZXkpID09ICJzdHJpbmciIGFuZCByb3cuUHJvZHVjdEtleSB+PSAiIiB0aGVuCgkJCQllbnRyeS5Qcm9kdWN0S2V5ID0gcm93LlByb2R1Y3RLZXkKCQkJZW5kCgkJCWlmIHR5cGUocm93LkxpbWl0ZWQpID09ICJudW1iZXIiIGFuZCByb3cuTGltaXRlZCA+IDAgdGhlbgoJCQkJZW50cnkuTGltaXRlZCA9IHJvdy5MaW1pdGVkCgkJCWVuZAoJCQlsaXN0W2lkXSA9IGVudHJ5CgkJZW5kCgllbmQKCXJldHVybiBsaXN0CmVuZAoKLS1bWwoJ5LuOIGF3ZHVtYmJlbGxDb25mIOe7hOijheWTkemTg+eooOWvhuaVsOe7hAoJQHJldHVybiB7dGFibGV9IC0g5ZOR6ZOD5YiX6KGo77yI5LiL5qCHPUlk77yJCl1dCmxvY2FsIGZ1bmN0aW9uIF9sb2FkRHVtYmJlbGxzKCk6IHsgeyBbc3RyaW5nXTogYW55IH0gfQoJbG9jYWwgY29uZiA9IENvbmZpZ0luc3RhbmNlLmF3ZHVtYmJlbGxDb25mIG9yIHt9Cglsb2NhbCBtYXhJZCA9IF9tYXhOdW1lcmljS2V5KGNvbmYpCglsb2NhbCBsaXN0ID0gdGFibGUuY3JlYXRlKG1heElkKQoJZm9yIGlkID0gMSwgbWF4SWQgZG8KCQlsb2NhbCByb3cgPSBjb25mW2lkXQoJCWlmIHR5cGUocm93KSA9PSAidGFibGUiIHRoZW4KCQkJbGlzdFtpZF0gPSB7CgkJCQlJZCA9IGlkLAoJCQkJWmhOYW1lID0gcm93LlpoTmFtZSwKCQkJCU11bHQgPSByb3cuTXVsdCwKCQkJCVJhcml0eSA9IHJvdy5SYXJpdHksCgkJCQlQcmljZSA9IHJvdy5QcmljZSBvciAwLAoJCQkJUGxhdGVDb2xvciA9IF9yZ2Iocm93LlBsYXRlUiwgcm93LlBsYXRlRywgcm93LlBsYXRlQiksCgkJCQlQbGF0ZU1hdCA9IHJvdy5QbGF0ZU1hdCwKCQkJCVBsYXRlU2NhbGUgPSByb3cuUGxhdGVTY2FsZSwKCQkJCUhhbmRsZUNvbG9yID0gX3JnYihyb3cuSGFuZGxlUiwgcm93LkhhbmRsZUcsIHJvdy5IYW5kbGVCKSwKCQkJCUljb24gPSByb3cuSWNvbiwKCQkJfQoJCWVuZAoJZW5kCglyZXR1cm4gbGlzdAplbmQKCi0tW1sKCeS7jiBhd3VwZ3JhZGVDb25mIOaMiSBLaW5kIOe7hOijhemYtuaVsOe7hO+8m0xldmVsPTAg5Li65Z+656GA5qGj77yI5LiN5YaZIFByaWNlL0xldmVsIOWtl+aute+8jOS4juaXp+ihqOW9oueKtuS4gOiHtO+8iQoJQHBhcmFtIGtpbmQgc3RyaW5nIC0gVHJhaW5TcGVlZCAvIFdhbGtTcGVlZAoJQHJldHVybiB7dGFibGV9IC0g6Zi25YiX6KGo77yI5oyJIExldmVsIOWNh+W6j++8iQpdXQpsb2NhbCBmdW5jdGlvbiBfbG9hZFVwZ3JhZGVLaW5kKGtpbmQ6IHN0cmluZyk6IHsgeyBbc3RyaW5nXTogYW55IH0gfQoJbG9jYWwgY29uZiA9IENvbmZpZ0luc3RhbmNlLmF3dXBncmFkZUNvbmYgb3Ige30KCWxvY2FsIHJvd3MgPSB7fQoJZm9yIF8sIHJvdyBpbiBwYWlycyhjb25mKSBkbwoJCWlmIHR5cGUocm93KSA9PSAidGFibGUiIGFuZCByb3cuS2luZCA9PSBraW5kIHRoZW4KCQkJdGFibGUu")
return #m.Source
