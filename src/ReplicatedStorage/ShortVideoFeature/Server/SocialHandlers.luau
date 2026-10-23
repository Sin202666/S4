--[[
	Module: SocialHandlers
	Description: ShortVideo Remotes 处理（赞/评/已看/限流）；评论双 ODS 分页（hot/newest）；赞表惰性清理
	Author: 林奥宇
	Created: 2026-08-13
	Last Modified: 2026-10-12
]]

local HttpService = game:GetService("HttpService")

local Constants = require(script.Parent.Parent.Shared.Constants)
local Remotes = require(script.Parent.Parent.Shared.Remotes)
local ConfigListService = require(script.Parent.ConfigListService)
local SocialStore = require(script.Parent.SocialStore)
local TextFilter = require(script.Parent.TextFilter)

local SocialHandlers = {}

local _readHits = {}
local _watchHits = {}
local _watched = {}
local _initialized = false

local _postCd: { [number]: number } = {}
local _likeHits: { [number]: { number } } = {}
local _fetchHits: { [number]: { number } } = {}

--[[
	滑动窗口限流
	@param bucketByUser {[number]: {number}} - 用户命中时间戳表
	@param userId number - 玩家
	@param windowSec number - 窗口秒
	@param maxHits number - 窗口内最大次数
	@return boolean - 是否通过
]]
local function allowWindow(
	bucketByUser: { [number]: { number } },
	userId: number,
	windowSec: number,
	maxHits: number
): boolean
	local now = os.clock()
	local bucket = bucketByUser[userId]
	if not bucket then
		bucket = {}
		bucketByUser[userId] = bucket
	end
	local kept = {}
	for _, t in ipairs(bucket) do
		if now - t <= windowSec then
			table.insert(kept, t)
		end
	end
	if #kept >= maxHits then
		bucketByUser[userId] = kept
		return false
	end
	table.insert(kept, now)
	bucketByUser[userId] = kept
	return true
end

--[[
	点赞滑动窗口是否允许
	@param userId number - 玩家
	@return boolean - 是否通过
]]
local function allowLike(userId: number): boolean
	return allowWindow(_likeHits, userId, Constants.LIKE_WINDOW_SEC, Constants.LIKE_WINDOW_MAX)
end

--[[
	拉评滑动窗口是否允许
	@param userId number - 玩家
	@return boolean - 是否通过
]]
local function allowFetch(userId: number): boolean
	return allowWindow(
		_fetchHits,
		userId,
		Constants.FETCH_COMMENT_WINDOW_SEC,
		Constants.FETCH_COMMENT_WINDOW_MAX
	)
end

--[[
	发评 CD
	@param userId number - 玩家
	@return boolean - 是否通过
]]
local function allowPost(userId: number): boolean
	local now = os.clock()
	local last = _postCd[userId]
	if last and now - last < Constants.POST_COMMENT_CD_SEC then
		return false
	end
	_postCd[userId] = now
	return true
end

--[[
	注册全部 Remote 回调
]]
function SocialHandlers.Init()
	if _initialized then return end
	_initialized = true
	game:GetService("Players").PlayerRemoving:Connect(function(player)
		local id = player.UserId
		_postCd[id], _likeHits[id], _fetchHits[id], _readHits[id], _watchHits[id], _watched[id] = nil, nil, nil, nil, nil, nil
		SocialStore.RemovePlayer(id)
	end)
	local cleanupElapsed = 0
	game:GetService("RunService").Heartbeat:Connect(function(dt)
		cleanupElapsed += dt
		if cleanupElapsed >= 30 then cleanupElapsed = 0; SocialStore.CleanupCaches() end
	end)
	local requestList = Remotes.Get("RequestList") :: RemoteEvent
	local reportWatch = Remotes.Get("ReportWatchProgress") :: RemoteEvent
	local getVideoState = Remotes.Get("GetVideoState") :: RemoteFunction
	local fetchComments = Remotes.Get("FetchComments") :: RemoteFunction
	local toggleVideoLike = Remotes.Get("ToggleVideoLike") :: RemoteFunction
	local toggleCommentLike = Remotes.Get("ToggleCommentLike") :: RemoteFunction
	local postComment = Remotes.Get("PostComment") :: RemoteFunction

	requestList.OnServerEvent:Connect(function(player: Player)
		if not player or not player:IsDescendantOf(game) then
			return
		end
		if not allowWindow(_readHits, player.UserId, 5, 10) then return end
		ConfigListService.PushToPlayer(player)
	end)

	reportWatch.OnServerEvent:Connect(function(player: Player, videoId: any, playedSec: any, durationSec: any, ended: any)
		if not player or typeof(videoId) ~= "string" or not ConfigListService.HasId(videoId) then
			return
		end
		if not allowWindow(_watchHits, player.UserId, 5, 10) then return end
		_watched[player.UserId] = _watched[player.UserId] or {}
		if _watched[player.UserId][videoId] then return end
		local played = tonumber(playedSec) or 0
		local duration = tonumber(durationSec)
		if played ~= played or math.abs(played) == math.huge or (duration and (duration ~= duration or math.abs(duration) == math.huge)) then return end
		local isEnded = ended == true
		local pass = isEnded
		if not pass then
			if duration and duration > 0 then
				pass = played >= duration * 0.5
			else
				pass = played >= Constants.WATCH_FALLBACK_SEC
			end
		end
		if not pass then
			return
		end
		_watched[player.UserId][videoId] = true
		local saved = SocialStore.UpdatePlayer(player.UserId, function(old)
			old.watched[videoId] = true
			return old
		end)
		if not saved and _watched[player.UserId] then _watched[player.UserId][videoId] = nil end
	end)

	getVideoState.OnServerInvoke = function(player: Player, videoId: any)
		if not player or typeof(videoId) ~= "string" or not ConfigListService.HasId(videoId) then
			return { ok = false, err = Constants.ERROR.INVALID }
		end
		if not allowWindow(_readHits, player.UserId, 5, 10) then return { ok = false, err = Constants.ERROR.RATE_LIMIT } end
		local stats = SocialStore.GetStats(videoId)
		local plr = SocialStore.GetPlayer(player.UserId)
		return {
			ok = true,
			likeCount = stats.likeCount,
			commentCount = stats.commentCount,
			liked = SocialStore.IsLiked(player.UserId, videoId),
			watched = plr.watched[videoId] == true,
		}
	end

	fetchComments.OnServerInvoke = function(player: Player, videoId: any, cursor: any, pageSize: any, sortMode: any)
		if not player or typeof(videoId) ~= "string" or not ConfigListService.HasId(videoId) then
			return { ok = false, err = Constants.ERROR.INVALID }
		end
		if not allowFetch(player.UserId) then
			return { ok = false, err = Constants.ERROR.RATE_LIMIT }
		end
		if type(pageSize) == "number" and (pageSize ~= pageSize or math.abs(pageSize) == math.huge) then return { ok = false, err = Constants.ERROR.INVALID } end
		local size = math.clamp(tonumber(pageSize) or Constants.COMMENT_PAGE_SIZE, 1, Constants.COMMENT_PAGE_SIZE)
		local mode = SocialStore.NormalizeSortMode(sortMode)
		local ok, page, nextCursor = SocialStore.FetchCommentsPage(videoId, cursor, size, mode)
		if not ok then
			return { ok = false, err = Constants.ERROR.BUSY }
		end
		local plr = SocialStore.GetPlayer(player.UserId)
		local likedMap = {}
		for _, c in ipairs(page) do
			if c and c.cid and SocialStore.IsLiked(player.UserId, videoId, c.cid) then
				likedMap[c.cid] = true
			end
		end
		return {
			ok = true,
			comments = page,
			nextCursor = nextCursor,
			likedMap = likedMap,
			sortMode = mode,
		}
	end

	toggleVideoLike.OnServerInvoke = function(player: Player, videoId: any)
		if not player or typeof(videoId) ~= "string" or not ConfigListService.HasId(videoId) then
			return { ok = false, err = Constants.ERROR.INVALID }
		end
		if not allowLike(player.UserId) then
			return { ok = false, err = Constants.ERROR.RATE_LIMIT }
		end
		local ok, liked, count = SocialStore.ToggleLike(player.UserId, videoId)
		return { ok = ok, liked = liked, likeCount = count, err = if ok then nil else Constants.ERROR.BUSY }
	end

	toggleCommentLike.OnServerInvoke = function(player: Player, videoId: any, cid: any)
		if not player or typeof(videoId) ~= "string" or typeof(cid) ~= "string" or not ConfigListService.HasId(videoId) then
			return { ok = false, err = Constants.ERROR.INVALID }
		end
		if not allowLike(player.UserId) then
			return { ok = false, err = Constants.ERROR.RATE_LIMIT }
		end
		if #cid > 50 then return { ok = false, err = Constants.ERROR.INVALID } end
		local ok, liked, count = SocialStore.ToggleLike(player.UserId, videoId, cid)
		return { ok = ok, liked = liked, likeCount = count, err = if ok then nil else Constants.ERROR.BUSY }
	end

	postComment.OnServerInvoke = function(player: Player, videoId: any, text: any)
		if not player or typeof(videoId) ~= "string" or typeof(text) ~= "string" or not ConfigListService.HasId(videoId) then
			return { ok = false, err = Constants.ERROR.INVALID }
		end
		local trimmed = string.gsub(text, "^%s+", "")
		trimmed = string.gsub(trimmed, "%s+$", "")
		if trimmed == "" then
			return { ok = false, err = Constants.ERROR.INVALID }
		end
		-- 按 UTF-8 字节长度限制（与 COMMENT_MAX_LEN 一致）
		if #trimmed > Constants.COMMENT_MAX_LEN then
			return { ok = false, err = Constants.ERROR.TOO_LONG }
		end
		if not allowPost(player.UserId) then
			return { ok = false, err = Constants.ERROR.RATE_LIMIT }
		end
		local filtered = TextFilter.FilterForBroadcast(trimmed, player.UserId)
		-- 过滤失败或整段屏蔽：不入库
		if not filtered or SocialStore.IsBlockedText(filtered) then
			return { ok = false, err = Constants.ERROR.FILTER_FAIL }
		end
		local comment = {
			cid = string.format("%d_%d_%s", player.UserId, os.time(), string.sub(HttpService:GenerateGUID(false), 1, 8)),
			userId = player.UserId,
			name = player.DisplayName,
			text = filtered,
			likeCount = 0,
			createdAt = os.time(),
			videoId = videoId,
		}
		if #comment.cid > 50 then
			comment.cid = string.sub(comment.cid, 1, 50)
		end
		local okAdd, commentCount, pending = SocialStore.AddComment(videoId, comment)
		if not okAdd then
			return { ok = false, err = Constants.ERROR.BUSY }
		end
		return {
			ok = true,
			comment = {
				cid = comment.cid,
				userId = comment.userId,
				name = comment.name,
				text = comment.text,
				likeCount = comment.likeCount,
				createdAt = comment.createdAt,
			},
			commentCount = commentCount,
			pending = pending == true,
		}
	end
end

return SocialHandlers
