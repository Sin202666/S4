local folder = game.ReplicatedStorage:FindFirstChild("_TmpBpInject")
if not folder then
	folder = Instance.new("Folder")
	folder.Name = "_TmpBpInject"
	folder.Parent = game.ReplicatedStorage
end
local function set(i, s)
	local v = folder:FindFirstChild(tostring(i))
	if not v then v = Instance.new("StringValue") v.Name = tostring(i) v.Parent = folder end
	v.Value = s
	return #s
end
local lens = {}
lens[6] = set(6, [[bgoJCQlfc3RlcChzKQoJCWVuZAoJZW5kKQoJcy5Cb3VuZCA9IHRydWUKZW5kCgotLVtbCgnnu5PmnZ/vvJrov5jljp/oh4Lplb8gLyBDMSAvIFRyYW5zZm9ybQpdXQpmdW5jdGlvbiBCYXR0bGVQb3NlLlN0b3AoKQoJbG9jYWwgcyA9IF9zZXNzaW9uCglpZiBub3QgcyB0aGVuCgkJcmV0dXJuCgllbmQKCV9zZXNzaW9uID0gbmlsCglpZiBzLkJvdW5kIHRoZW4KCQlwY2FsbChmdW5jdGlvbigpCgkJCVJ1blNlcnZpY2U6VW5iaW5kRnJvbVJlbmRlclN0ZXAoQklORF9OQU1FKQoJCWVuZCkKCWVuZAoJX3Jlc3RvcmVBcm0ocy5QbGF5ZXIpCglfcmVzdG9yZUFybShzLk9wcG9uZW50KQplbmQKCi0tW1sKCeaYr+WQpuato+WcqOaRhuWvueWxgOiHguWnvwoJQHJldHVybiBib29sZWFuCl1dCmZ1bmN0aW9uIEJhdHRsZVBvc2UuSXNBY3RpdmUoKTogYm9vbGVhbgoJcmV0dXJuIF9zZXNzaW9uIH49IG5pbAplbmQKCnJldHVybiBCYXR0bGVQb3NlCg==]])
return lens
