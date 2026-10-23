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
local src = b64decode("bG9jYWwgbSA9IGdhbWUuU2VydmVyU3RvcmFnZS5TZXJ2ZXJTaWRlQ29kZS5TeXN0ZW0uU3lzdGVtQXJtV3Jlc3RsZQptLlNvdXJjZSAuLj0gWz1bW1sKCeemu+Wcuua4heeQhgoJQHBhcmFtIHBsciBQbGF5ZXIgLSDnjqnlrrYKXV0KZnVuY3Rpb24gU3lzdGVtQXJtV3Jlc3RsZS5PblBsYXllclJlbW92aW5nKHBscjogUGxheWVyKQoJQmF0dGxlLkZvcmNlRW5kKHBscikKCS0tIFBsYXllck1hbmFnZXIg5Zyo5pys5Ye95pWw5LmL5ZCO5omNIFBsYXllckxlYXZlU2F2Ze+8jOiNr+awtOWJqeS9meenkuaVsOS4jiBMYXN0T25saW5lIOmhu+WFiOWGmeWbnuaho+ahiAoJX3NhdmVQb3Rpb25MZWZ0KHBscikKCVBvdGlvbi5VbmxvYWQocGxyKQoJT2ZmbGluZS5VbmxvYWQocGxyKQoJTWVudUdpZnQuVW5sb2FkKHBscikKCVRyYWluLk9uUGxheWVyUmVtb3ZpbmcocGxyKQoJRWNvbm9teS5PblBsYXllclJlbW92aW5nKHBscikKCUJvb3N0Lk9uUGxheWVyUmVtb3ZpbmcocGxyKQplbmQKCnJldHVybiBTeXN0ZW1Bcm1XcmVzdGxlCl09XQpyZXR1cm4gI20uU291cmNlCg==")
local fn, err = load(src)
assert(fn, err)
return fn()
