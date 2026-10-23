local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local lookup = {}
for i = 1, #alphabet do
	lookup[string.byte(alphabet, i)] = i - 1
end
local function b64decode(data)
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
local src = b64decode("bG9jYWwgbSA9IGdhbWUuUmVwbGljYXRlZEZpcnN0LkFsbFNpZGVDb2RlLlRvb2xTeXN0ZW0uQ2ZnRmluZAptLlNvdXJjZSAuLj0gWz1baW5lU2F2ZSkgfj0gInRhYmxlIiBvciBub3QgdGllcklkIHRoZW4KCQlyZXR1cm4gZmFsc2UKCWVuZAoJbG9jYWwgdGllckRhdGEgPSBvbmxpbmVTYXZlW3Rvc3RyaW5nKHRpZXJJZCldCglyZXR1cm4gdHlwZSh0aWVyRGF0YSkgPT0gInRhYmxlIiBhbmQgdG9udW1iZXIodGllckRhdGEuU3RhdGUpID09IE9OTElORV9TVEFURV9DTEFJTUVECmVuZAoKLS1bWwoJ5qGj5L2N5b2T5YmN5piv5ZCm5Y+v6aKG77yI5pyq6aKGIOS4lCDml7bplb/ovr7moIfmiJbor6XmoaMgVW5sb2NrPTHvvIkKCUBwYXJhbSBvbmxpbmVTYXZlIHRhYmxlPyAtIE9ubGluZUJveO+8mk9ubGluZVNlY29uZHMgLyBbdGllcklkXT17IFN0YXRlfFVubG9jayB9CglAcGFyYW0gY2ZnIHRhYmxlIC0gb25saW5lYXdhcmRDb25mIOihjO+8iOmhu+WQqyBpZCAvIE9ubGluVGltZe+8iQoJQHJldHVybiBib29sZWFuIC0g5Y+v6aKG5Li6IHRydWUKXV0KZnVuY3Rpb24gQ2ZnRmluZC5Jc09ubGluZVRpZXJDbGFpbWFibGUob25saW5lU2F2ZTogeyBbYW55XTogYW55IH0/LCBjZmc6IHsgW3N0cmluZ106IGFueSB9KTogYm9vbGVhbgoJaWYgdHlwZShvbmxpbmVTYXZlKSB+PSAidGFibGUiIG9yIHR5cGUoY2ZnKSB+PSAidGFibGUiIHRoZW4KCQlyZXR1cm4gZmFsc2UKCWVuZAoJbG9jYWwgdGllcklkID0gdG9udW1iZXIoY2ZnLmlkKQoJaWYgbm90IHRpZXJJZCBvciBDZmdGaW5kLklzT25saW5lVGllckNsYWltZWQob25saW5lU2F2ZSwgdGllcklkKSB0aGVuCgkJcmV0dXJuIGZhbHNlCgllbmQKCWxvY2FsIHRpZXJEYXRhID0gb25saW5lU2F2ZVt0b3N0cmluZyh0aWVySWQpXQoJaWYgdHlwZSh0aWVyRGF0YSkgPT0gInRhYmxlIiBhbmQgdG9udW1iZXIodGllckRhdGEuVW5sb2NrKSA9PSAxIHRoZW4KCQlyZXR1cm4gdHJ1ZQoJZW5kCglsb2NhbCBuZWVkID0gdG9udW1iZXIoY2ZnLk9ubGluVGltZSkgb3IgMAoJbG9jYWwgc2Vjb25kcyA9IHRvbnVtYmVyKG9ubGluZVNhdmUuT25saW5lU2Vjb25kcykgb3IgMAoJcmV0dXJuIHNlY29uZHMgPj0gbmVlZAplbmQKCi0tW1sKCeagueaNriBPbmxpbmVCb3gg5a2Y5qGj5Yik5pat5piv5ZCm5a2Y5Zyo5Y+v6aKG5Y+W5qGj5L2N77yI57qv5p+l6K+i77yM5Y+M56uv5Y+v55So77yJCglAcGFyYW0gb25saW5lU2F2ZSB0YWJsZT8gLSBPbmxpbmVCb3jvvJpPbmxpbmVTZWNvbmRzIC8gW3RpZXJJZF09eyBTdGF0ZXxVbmxvY2sgfQoJQHJldHVybiBib29sZWFuIC0g5pyJ5Y+v6aKG5qGj5L2N5Li6IHRydWUKXV0KZnVuY3Rpb24gQ2ZnRmluZC5IYXNDbGFpbWFibGVPbmxpbmVBd2FyZChvbmxpbmVTYXZlOiB7IFthbnldOiBhbnkgfT8pOiBib29sZWFuCglyZXR1cm4gQ2ZnRmluZC5Db3VudENsYWltYWJsZU9ubGluZUF3YXJkKG9ubGluZVNhdmUpID4gMAplbmQKCi0tW1sKCeagueaNriBPbmxpbmVCb3gg5a2Y5qGj57uf6K6h5Y+v6aKG5Y+W5qGj5L2N5pWw6YeP77yI57qv5p+l6K+i77yM5Y+M56uv5Y+v55So77yJCglAcGFyYW0gb25saW5lU2F2ZSB0YWJsZT8gLSBPbmxpbmVCb3jvvJpPbmxpbmVTZWNvbmRzIC8gW3RpZXJJZF09eyBTdGF0ZT0x5bey6aKGIHwgVW5sb2NrPTHku5jotLnlj6/pooYgfQoJQHJldHVybiBudW1iZXIgLSDlj6/poobmoaPkvY3mlbDvvIjiiaUw77yJCl1dCmZ1bmN0aW9uIENmZ0ZpbmQuQ291bnRDbGFpbWFibGVPbmxpbmVBd2FyZChvbmxpbmVTYXZlOiB7IFthbnldOiBhbnkgfT8pOiBudW1iZXIKCWlmIHR5cGUob25saW5lU2F2ZSkgfj0gInRhYmxlIiB0aGVuCgkJcmV0dXJuIDAKCWVuZAoJbG9jYWwgY291bnQgPSAwCglsb2NhbCBsaXN0ID0gQ2ZnRmluZC5HZXRPbmxpbmVBd2FyZExpc3QoKQoJZm9yIF8sIGNmZyBpbiBpcGFpcnMobGlzdCkgZG8KCQlpZiBDZmdGaW5kLklzT25saW5lVGllckNsYWltYWJsZShvbmxpbmVTYXZlLCBjZmcpIHRoZW4KCQkJY291bnQgKz0gMQoJCWVuZAoJZW5kCglyZXR1cm4gY291bnQKZW5kCgpyZXR1cm4gQ2ZnRmluZApdPV0KcmV0dXJuICNtLlNvdXJjZQo=")
local fn, err = load(src)
assert(fn, err)
return fn()
