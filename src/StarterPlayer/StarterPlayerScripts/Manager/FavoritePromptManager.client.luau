--[[
	Module: FavoritePromptManager
	Description: 收藏提示管理器（客户端），玩家进入游戏一段时间后弹出 Roblox 原生「收藏本游戏」提示
	Author: 程莘
	Created: 2026-10-14
	Last Modified: 2026-10-15

	功能：
	- 进入游戏后等待 GameConfig.收藏提示.进入后延迟秒，调用 AvatarEditorService:PromptSetFavorite 弹出原生收藏框
	- 弹出前用 GetFavorite 查询，已收藏则跳过；查询失败会重试，多次仍失败则不弹（宁可漏弹也不打扰已收藏玩家）
	- 每会话最多弹一次；不落存档、不走 Remote

	加载方式：
	- 本文件是 StarterPlayerScripts LocalScript，客户端自动运行
	- 不是 Utils 模块，禁止 require；不要写 Utils.FavoritePromptManager

	配置（GameConfig.收藏提示）：
	- 启用：false 时不计时、不弹出
	- 进入后延迟秒：进入游戏后多少秒弹出；非法或 ≤0 时回落缺省 60 并 Log.warn

	约定：
	- 纯表现层提示，结果仅用于日志；不据此发奖（收藏结果来自客户端，不可信）
	- Studio 中 PromptSetFavorite 可能不弹框，以正式服为准
]]

-- ============================================================================
-- 服务引用
-- ============================================================================

local AvatarEditorService = game:GetService("AvatarEditorService")

-- ============================================================================
-- 模块引用
-- ============================================================================

local Utils = require(game.ReplicatedFirst.AllSideCode.UtilsSystem)

local Log = Utils.Log
local SystemGameConfig = Utils.SystemGameConfig

-- ============================================================================
-- 常量
-- ============================================================================

local DEFAULT_DELAY = 60
local QUERY_RETRY_COUNT = 3
local QUERY_RETRY_INTERVAL = 2
local CONFIG_PATH_ENABLED = table.freeze({ "收藏提示", "启用" })
local CONFIG_PATH_DELAY = table.freeze({ "收藏提示", "进入后延迟秒" })

-- ============================================================================
-- 私有函数
-- ============================================================================

--[[
	读取弹出延迟秒；非法或 ≤0 时回落缺省并打日志
	@return number - 有效延迟秒数，或 DEFAULT_DELAY
]]
local function _getDelay(): number
	local value = SystemGameConfig.GetValue(CONFIG_PATH_DELAY)
	if typeof(value) == "number" and value > 0 then
		return value
	end
	Log.warn("FavoritePromptManager: 配置非法，使用缺省", table.concat(CONFIG_PATH_DELAY, "."), value, DEFAULT_DELAY)
	return DEFAULT_DELAY
end

--[[
	查询本游戏是否已被当前玩家收藏，失败时按 QUERY_RETRY_COUNT 次重试
	@return boolean? - true=已收藏，false=未收藏，nil=多次查询均失败（状态未知）
]]
local function _queryFavorited(): boolean?
	for attempt = 1, QUERY_RETRY_COUNT do
		local ok, result = pcall(AvatarEditorService.GetFavorite, AvatarEditorService, game.PlaceId, Enum.AvatarItemType.Asset)
		if ok then
			return result == true
		end
		Log.warn("FavoritePromptManager: GetFavorite 失败", attempt, result)
		if attempt < QUERY_RETRY_COUNT then
			task.wait(QUERY_RETRY_INTERVAL)
		end
	end
	return nil
end

--[[
	延迟后弹出收藏提示；已收藏或收藏状态查询不到时均不弹
	@return nil - 无返回值
]]
local function _runPrompt()
	task.wait(_getDelay())
	if _queryFavorited() ~= false then
		return
	end
	local ok, err = pcall(AvatarEditorService.PromptSetFavorite, AvatarEditorService, game.PlaceId, Enum.AvatarItemType.Asset, true)
	if not ok then
		Log.warn("FavoritePromptManager: PromptSetFavorite 失败", err)
	end
end

--[[
	原生收藏框关闭回调，仅记录结果
	@param result Enum.AvatarPromptResult - Success=已收藏，PermissionDenied=玩家拒绝，Failed=失败
	@return nil - 无返回值
]]
local function _onPromptCompleted(result: Enum.AvatarPromptResult)
	Log.print("FavoritePromptManager: 收藏提示结果", result)
end

-- ============================================================================
-- 初始化
-- ============================================================================

if SystemGameConfig.GetValue(CONFIG_PATH_ENABLED) == true then
	AvatarEditorService.PromptSetFavoriteCompleted:Connect(_onPromptCompleted)
	task.spawn(_runPrompt)
end
