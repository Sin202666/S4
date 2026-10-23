--[[ Module: LikePolicy | Description: 同记录点赞状态/计数 CAS | Author: 林奥宇 ]]
local Policy = {}

-- expectedRevision 使回包丢失的重试及并发点击不会再次累计；legacyLiked 仅首次迁移使用。
function Policy.Apply(row, userKey, desired, expectedRevision, legacyLiked)
	row._votes = row._votes or {}
	local vote = row._votes[userKey]
	local revision = if vote then vote.revision else 0
	if revision ~= expectedRevision then return row end
	if not vote then
		local count = row._voterCount or 0
		-- 防止单键超过 4MB；超大内容应迁移分片后再开放更多首次点赞。
		if count >= 20000 then return nil end
		row._voterCount = count + 1
	end
	local previous = if vote then vote.liked else legacyLiked
	if previous ~= desired then
		row.likeCount = math.max(0, (row.likeCount or 0) + (if desired then 1 else -1))
	end
	row._votes[userKey] = { liked = desired, revision = revision + 1 }
	return row
end
return Policy
