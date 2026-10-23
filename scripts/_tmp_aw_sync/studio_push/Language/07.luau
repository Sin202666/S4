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
local src = b64decode("bG9jYWwgbSA9IGdhbWUuUmVwbGljYXRlZEZpcnN0LkFsbFNpZGVDb2RlLlRvb2xCYXNpYy5UcmFuc2xhdGlvbkhlbHBlci5MYW5ndWFnZQptLlNvdXJjZSAuLj0gWz1bcm0ifSwKCVsi6aKG5Y+W5oiQ5YqfIl09eyLpooblj5bmiJDlip8iLCJDbGFpbWVkIHN1Y2Nlc3NmdWxseSJ9LAoJWyJFZ2cxIl09eyLlrqDnianom4sxIiwiRWdnIDEifSwKCVsiRWdnMiJdPXsi5a6g54mp6JuLMiIsIkVnZyAyIn0sCglbIkVnZzMiXT17IuWuoOeJqeibizMiLCJFZ2cgMyJ9LAoJWyJHZW0iXT17IuWuneefsyIsIkdlbSJ9LAoJWyJ6dWFuc2hpIl09eyLpkrvnn7MiLCJHZW1zIn0KfQpyZXR1cm4gTGFuZ3VhZ2UKXT1dCnJldHVybiAjbS5Tb3VyY2UK")
local fn, err = load(src)
assert(fn, err)
return fn()
