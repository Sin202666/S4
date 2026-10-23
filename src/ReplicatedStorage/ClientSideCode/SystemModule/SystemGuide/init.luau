--[[
	Module: SystemGuide
	Description: 新手引导客户端：解析服务端发布的当前阶段，驱动界面箭头 / 引导线 / 场景高光，并向 HUD 提供阶段配置
	Author: 程莘
	Created: 2026-10-15
	Last Modified: 2026-10-16

	功能：
	- 监听本地玩家 Attribute GuideName（"引导键|阶段序号[|Pre]"，服务端 SystemGuide 唯一写入），从 GameConfig「引导」取阶段配置
	- 带 |Pre 时阶段前置未满足，表现改用阶段 Pre 内的 ZhText / line / worldHighlight / ui
	- 阶段 ui → UIGuide（按钮箭头）；line / worldHighlight → LineGuide（引导线 / 场景高光）
	- 弹窗打开（PopupOpen，HUD EdgeSlide 写）时箭头改用阶段 popupUi（如商店内购买按钮），未配则隐藏；对局中（SetSuppressed）箭头与引导线全部隐藏
	- GetStage：当前阶段表现深拷贝（ZhText，手机端优先 ZhText_Mobile）；主界面已无引导文案框

	约束：
	- 纯表现，不上报完成、不推进阶段：阶段完成只由服务端按结算判定（防止客户端伪造引导进度）
	- 本模块与服务端 SystemGuide 同名分端，Utils 在客户端解析到本模块

	与相关模块：
	- 服务端 SystemGuide：发布 GuideName；配置说明见 GameConfig「引导」
	- 客户端 SystemArmWrestle：对局开始 SetSuppressed(true)，交还控制 SetSuppressed(false)
	- 引导配置已清空，入服后 GuideName 为空，箭头与引导线不显示

	加载：
		local SystemGuide = Utils.SystemGuide
		SystemGuide.Init()                  -- GuideManager 调一次
		local stage = SystemGuide.GetStage() -- { ZhText = "...", ... } 或 nil
		SystemGuide.SetSuppressed(true)
]]

local Utils = require(game.ReplicatedFirst.AllSideCode.UtilsSystem)
local LocalPlayer = Utils.LocalPlayer
local EnumMgr = Utils.EnumMgr
local SystemGameConfig = Utils.SystemGameConfig
local Copy = Utils.Copy

local UIGuide = require(script.UIGuide)
local LineGuide = require(script.LineGuide)

local SystemGuide = {}

local GUIDE_NAME_ATTR = EnumMgr.PlayerAttr.GuideName
local POPUP_OPEN_ATTR = EnumMgr.PlayerAttr.PopupOpen
local NAME_SEPARATOR = "|"
local PRE_SUFFIX = "Pre"

local _inited = false
local _suppressed = false
local _stage: { [string]: any }? = nil
local _uiCfg: { [string]: any }? = nil
local _guideCfg: { [string]: any }? = nil

--[[
	引导配置表（首次读取后缓存，GameConfig 为只读深拷贝）
	@return table - GameConfig「引导」.Cfg；缺失为空表
]]
local function _getGuideCfg(): { [string]: any }
	if not _guideCfg then
		local cfg = SystemGameConfig.GetValue({ "引导", "Cfg" })
		_guideCfg = if type(cfg) == "table" then cfg else {}
	end
	return _guideCfg :: { [string]: any }
end

--[[
	解析 GuideName 对应的阶段表现配置
	@param value any - Attribute 值，形如 "新手扳手腕|3" 或 "新手扳手腕|5|Pre"；空串 / nil 表示无引导
	@return table? - 阶段表现 { ZhText, ZhText_Mobile?, line?, worldHighlight?, ui? }；Pre 变体取阶段 Pre 内的表现；无引导或配置缺失为 nil
]]
local function _resolveStage(value: any): { [string]: any }?
	if type(value) ~= "string" then
		return nil
	end
	local parts = string.split(value, NAME_SEPARATOR)
	local key, index = parts[1], tonumber(parts[2])
	if not key or key == "" or not index then
		return nil
	end
	local guide = _getGuideCfg()[key]
	local stages = type(guide) == "table" and guide.Stages
	local stage = type(stages) == "table" and stages[index]
	if type(stage) ~= "table" then
		return nil
	end
	local pre = stage.Pre
	if parts[3] == PRE_SUFFIX and type(pre) == "table" then
		return pre
	end
	return stage
end

--[[
	按对局抑制与弹窗状态选界面箭头配置并写各表现层显隐：弹窗打开时用阶段 popupUi（未配则不显示），否则用 ui
]]
local function _applyVisible()
	local stage = _stage
	local popupOpen = LocalPlayer:GetAttribute(POPUP_OPEN_ATTR) == true
	local uiCfg = if not stage then nil elseif popupOpen then stage.popupUi else stage.ui
	if uiCfg ~= _uiCfg then
		_uiCfg = uiCfg
		UIGuide.Apply(uiCfg)
	end
	UIGuide.SetVisible(not _suppressed)
	LineGuide.SetVisible(not _suppressed)
end

--[[
	GuideName 变化：切换到新阶段的全部表现
]]
local function _onGuideChanged()
	local stage = _resolveStage(LocalPlayer:GetAttribute(GUIDE_NAME_ATTR))
	_stage = stage
	_uiCfg = nil
	UIGuide.Apply(nil)
	LineGuide.Apply(stage and stage.line, stage and stage.worldHighlight)
	_applyVisible()
end

--[[
	当前引导阶段表现配置（深拷贝；前置未满足时为阶段 Pre 内的表现）
	@return table? - { ZhText: string, ZhText_Mobile: string?, ui: table?, popupUi: table?, line: table?, worldHighlight: table? }；无引导为 nil
]]
function SystemGuide.GetStage(): { [string]: any }?
	local stage = _stage
	if not stage then
		return nil
	end
	return Copy.deepCopy(stage)
end

--[[
	对局期间隐藏全部引导表现（客户端 SystemArmWrestle 在对局开始 / 交还控制时调用）
	@param suppressed boolean - true 隐藏；false 恢复
]]
function SystemGuide.SetSuppressed(suppressed: boolean)
	_suppressed = suppressed
	_applyVisible()
end

--[[
	启动：监听 GuideName 与弹窗状态（GuideManager 调一次；重复调用忽略）
]]
function SystemGuide.Init()
	if _inited then
		return
	end
	_inited = true
	LineGuide.Init()
	LocalPlayer:GetAttributeChangedSignal(GUIDE_NAME_ATTR):Connect(_onGuideChanged)
	LocalPlayer:GetAttributeChangedSignal(POPUP_OPEN_ATTR):Connect(_applyVisible)
	_onGuideChanged()
end

return SystemGuide
