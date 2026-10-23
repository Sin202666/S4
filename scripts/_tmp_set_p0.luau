local s = game.ServerStorage._LoadingUISrc['p0']
s.Value = [=[--[[
	Module: LoadingUI
	Description: FirstPreload 加载界面：居中裁切 Icon、跳动圆点、纯文字跳过与关闭过渡
	Author: 中台组
	Created: 2026-07-03
	Last Modified: 2026-10-16

	功能：
	- 挂载 PreloadGui 到 PlayerGui，传送场景下按 TeleportCfg 换肤
	- 加载期间隐藏其他 ScreenGui，关闭后按 Attribute 恢复
	- Logo.GameIcon 弹出后循环摇摆呼吸（透明 PNG 裁切图，无圆角框）
	- 图标下方 Dots 三点轮流跳动；满 5 秒显示纯文字「跳过」；手柄/按钮可跳过
	- 背景 CanvasGroup.Bg.BgPattern 积木平铺纹理斜向循环滚动
	- 图标/圆点/背景循环 Tween 在关闭时 Cancel；PreloadGui_Teleport 无 Logo / BgPattern 时跳过对应动画

	依赖：
	- Utils.RunService / TweenService / UserInputService / SoundService / Players
	- Utils.TranslationHelper

	示例：
	```lua
	local LoadingUI = require(script.LoadingUI)
	LoadingUI.Start({
		preloadGui = preloadGui,
		teleportCfg = teleportCfg,
		resTotal = resTotal,
		resLoaded = resLoaded,
		resLoadTime = resLoadTime,
		isCloseLoading = isCloseLoading,
		onFinished = function()
			script:Destroy()
		end,
	})
	```
]]

-- ============================================================================
-- 服务与依赖
-- ============================================================================

local Utils = require(game.ReplicatedFirst.AllSideCode.UtilsSystem)
local RunService = Utils.RunService
local TweenService = Utils.TweenService
local UserInputService = Utils.UserInputService
local SoundService = Utils.SoundService
local Players = Utils.Players
local TranslationHelper = Utils.TranslationHelper

-- ============================================================================
-- 模块定义
-- ============================================================================

local LoadingUI = {}

export type StartConfig = {
	preloadGui: ScreenGui,
	teleportCfg: any?,
	resTotal: NumberValue,
	resLoaded: NumberValue,
	resLoadTime: NumberValue,
	isCloseLoading: BoolValue,
	onFinished: (() -> ())?,
}

-- ============================================================================
-- 常量
-- ============================================================================

local PRELOAD_GUI_SHOW_NAME = "PreloadGuiNowShow"
local SKIP_SHOW_TIME_SEC = 5
local CLOSE_FADE_SEC = 0.5
local ICON_POP_SEC = 0.45
local ICON_SWAY_SEC = 1.6
local ICON_SWAY_DEG = 4
local ICON_PULSE_SEC = 0.8
local ICON_PULSE_SCALE = 1.04
local ICON_SWAY_TARGETS = { "GameIcon" }
local BG_PATTERN_NAME = "BgPattern"
local BG_SCROLL_SEC = 6
local DOTS_NAME = "Dots"
local DOT_BOUNCE_SEC = 0.35
local DOT_BOUNCE_SCALE = 1.35
local DOT_STAGGER_SEC = 0.18

-- ============================================================================
-- 私有函数
-- ============================================================================

--[[
	传送加载界面按配置设置背景、标题渐变与文案
	@param frame Frame - PreloadGui.CanvasGroup
	@param cfg table - TeleportService 传入的配置（BigZhName / Colors / TeleBG）
	@return nil - 无返回值
]]
local function _applyTeleportSkin(frame: Frame, cfg: any)
	local worldName = frame:FindFirstChild("WorldName")
	local bgImg = frame:FindFirstChild("BGImg")
	local nameBg = frame:FindFirstChild("NameBg")

	if worldName then
		worldName.Visible = false
		task.defer(function()
			worldName.Visible = true
			TranslationHelper.SetText(worldName, cfg.BigZhName)
		end)

		local gradient = worldName:FindFirstChild("UIGradient") :: UIGradient?
		if gradient and cfg.Colors then
			gradient.Color = ColorSequence.new(
				Color3.fromHex(cfg.Colors[1]),
				Color3.fromHex(cfg.Colors[2])
			)
		end
	end

	if bgImg and cfg.TeleBG then
		bgImg.Image = "rbxassetid://" .. cfg.TeleBG
	end

	if nameBg and cfg.Colors then
		local gradient = nameBg:FindFirstChild("UIGradient") :: UIGradient?
]=]
return #s.Value
