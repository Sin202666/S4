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
local src = b64decode("bG9jYWwgbSA9IGdhbWUuUmVwbGljYXRlZEZpcnN0LkFsbFNpZGVDb2RlLlRvb2xCYXNpYy5Db25maWdJbnN0YW5jZQptLlNvdXJjZSAuLj0gWz1bZWN0TW9kZSIsNCwzLDAsezAsMX0sIiIseyLplIHlrprlvZPliY3nm67moIciLCLplIHlrprmnIDov5Hnm67moIcifSwxLCIifSwKCVsxM109eyLplb/mjInmlLvlh7siLCJIb2xkQXRrIiw0LDIsMSx7MCwxfSwiIix7IuWFs+mXrSIsIuW8gOWQryJ9LDEsIiJ9LAoJWzE0XT17IumakOiXj+WktOmDqOmlsOWTgSIsIkhpZGVTZWxmSGF0Iiw1LDIsMCx7MCwxfSwiIix7IuWFs+mXrSIsIuW8gOWQryJ9LDEsIiJ9LAoJWzE1XT17IumakOiXj+W3q+W4iOiijSIsIkhpZGVTZWxmUm9iZSIsNSwyLDAsezAsMX0sIiIseyLlhbPpl60iLCLlvIDlkK8ifSwxLCIifSwKCVsxNl09eyLpmpDol4/np43ml4/lpJbop4IiLCJIaWRlUmFjZSIsNSwyLDAsezAsMX0sIiIseyLlhbPpl60iLCLlvIDlkK8ifSwxLCIifSwKCVsxN109eyLop4bph47ojIPlm7QiLCJGaWVsZE9mVmlldyIsNSwxLDcwLHs1MCw5MH0sIiIse30sMCwiIn0sCglbMThdPXsi5o6J6JC954mp5qih5Z6LIiwiVGlwc0l0ZW0iLDUsMiwxLHswLDF9LCIiLHsi5YWz6ZetIiwi5byA5ZCvIn0sMSwiIn0sCglbMTldPXsi5pi+56S65LuW5Lq65L+h5oGvIiwiU2hvd090aGVyUGxySW5mbyIsNSwyLDEsezAsMX0sIiIseyLlhbPpl60iLCLlvIDlkK8ifSwxLCIifSwKCVsyMF09eyLnlKjmiLfnlYzpnaIiLCJIaWRlVUkiLDUsMiwxLHswLDF9LCIiLHsi5YWz6ZetIiwi5byA5ZCvIn0sMSwiIn0sCglbMjFdPXsi6Ieq5Yqo5Yqg54K5IiwiQXV0b0F0dHJQb2ludCIsNSwyLDEsezAsMX0sIiIseyLlhbPpl60iLCLlvIDlkK8ifSwwLCIifSwKCVsyMl09eyLorrDlv4blv6vpgJ/ngrzph5EiLCJBdXRvR2FtZTMiLDUsMiwwLHswLDF9LCIiLHt9LDAsIiJ9LAoJWzIzXT17IuWllOi3keaooeW8jyIsIlJ1bk1vZGUiLDQsMywwLHswLDF9LCIiLHsi5LiA6ZSu5YiH5o2iIiwi6ZW/5oyJ5aWU6LeRIn0sMSwiIn0KfQoKQ29uZmlnSW5zdGFuY2Uuc2tpbGxDb25mPXsKCVsxMDAwMDAwMl09eyLlhrLliLoiLCJOZXdSb2xsIiwiIiwi546p5a625Z+656GA5oqA6IO9IiwiIiwxLDAsMSwwLDAsMCwi5ZCR5YmN5Yay5Yi65LiA5q616Led56a7IiwwLDMsMix7MH0sIiIse30sIuWfuuehgOaKgOiDvSIsIiIsIiIsIiIsezF9LHsxLDF9LHt9fSwKCVsxMDAwMDAxMF09eyLmvJTnpLrmlr3ms5UiLCJTa2lsbERlbW9DYXN0IiwiIiwi5qGG5p625qC35L6LIiwiIiwxLDAsMSwwLDAsMCwi55+t5pa95rOV6ZSB56e75Yqo5qC35L6LIiwwLDMsMix7MH0sIiIse30sIuS4u+WKqOaKgOiDvSIsIiIsIiIsIiIsezF9LHsxLDF9LHt9fSwKCVsxMDAwMDAxMV09eyLpmajnn7PmnK8iLCJNZXRlb3IiLCIiLCLmoYbmnrbmoLfkvosiLCIiLDEsNTAsMSwwLDIsMTIwLCLlnKjnm67moIfkvY3nva7lj6zllKTkuIDmnprpmajnn7MiLDIsMywyLHsxfSwiIix7fSwi5Li75Yqo5oqA6IO9IiwiIiwiIiwiIix7MC42fSx7MSwyfSx7fX0sCglbMTAwMDAwMTJdPXsi56m66Ze05oqA6IO9IiwiU3BhY2VTa2lsbCIsIiIsIuahhuaetuagt+S+iyIsIiIsMSw4MCwxLDAsMiwwLCLnqbrpl7Too4LnvJ3lj4znkIPooajnjrDvvIjnuq/ooajnjrDpppbniYjvvIkiLDAsMywxMix7MH0sIiIse30sIuS4u+WKqOaKgOiDvSIsIiIsIiIsIiIsezF9LHsxLDF9LHt9fQp9CgpDb25maWdJbnN0YW5jZS51cGRhdGVsb2dDb25mPXsKCVsxXT17MTc3ODgzOTIwMCwi5pu05pawX+mhteetvuagh+mimF8xIix7IuabtOaWsF/lhoXlrrnmoIfpophfMSIsIuabtOaWsF/lhoXlrrlfMV8xIiwi5pu05pawX+WGheWuuV8xXzIiLCLmm7TmlrBf5YaF5a65XzFfMyJ9fQp9CnJldHVybiBDb25maWdJbnN0YW5jZQpdPV0KcmV0dXJuICNtLlNvdXJjZQo=")
local fn, err = load(src)
assert(fn, err)
return fn()
