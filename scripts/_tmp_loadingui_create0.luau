--[[
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
		if gradient then
			gradient.Color = ColorSequence.new(
				Color3.fromHex(cfg.Colors[1]),
				Color3.fromHex(cfg.Colors[2])
			)
		end
	end
end

--[[
	初始化 Logo 区：图标缩到 0 等待弹出
	@param preloadFrame Frame - 主内容 Frame
	@return nil - 无返回值
]]
local function _initLogoFrame(preloadFrame: Frame)
	local logoFrame = preloadFrame:FindFirstChild("Logo") :: Frame?
	if not logoFrame then
		return
	end

	local logoScale = logoFrame:FindFirstChildOfClass("UIScale")
	if logoScale then
		logoScale.Scale = 0
	end
end

--[[
	启动 Dots 下三点轮流缩放跳动
	@param dotsFrame Frame - 含 Dot1..Dot3（子级 Bounce UIScale）
	@return { Tween } - 循环 Tween 列表，关闭时需 Cancel；无 Dots 时为空表
]]
local function _playDotsBounce(dotsFrame: Frame?): { Tween }
	local loopTweens: { Tween } = {}
	if not dotsFrame then
		return loopTweens
	end

	dotsFrame.Visible = true
	for i = 1, 3 do
		local dot = dotsFrame:FindFirstChild("Dot" .. i) :: Frame?
		local bounce = dot and dot:FindFirstChild("Bounce") :: UIScale?
		if bounce then
			bounce.Scale = 1
			local tween = TweenService:Create(
				bounce,
				TweenInfo.new(
					DOT_BOUNCE_SEC,
					Enum.EasingStyle.Sine,
					Enum.EasingDirection.InOut,
					-1,
					true,
					(i - 1) * DOT_STAGGER_SEC
				),
				{ Scale = DOT_BOUNCE_SCALE }
			)
			tween:Play()
			table.insert(loopTweens, tween)
		end
	end
	return loopTweens
end

--[[
	图标弹出后启动循环摇摆与呼吸，并启动圆点跳动
	@param preloadFrame Frame - 主内容 Frame
	@return { Tween } - 循环 Tween 列表，关闭时需逐个 Cancel；无 Logo 时仅含圆点 Tween
]]
local function _playLogoIntro(preloadFrame: Frame): { Tween }
	local loopTweens: { Tween } = {}
	local logoFrame = preloadFrame:FindFirstChild("Logo") :: Frame?
	local logoScale = logoFrame and logoFrame:FindFirstChildOfClass("UIScale")
	if logoFrame and logoScale then
		local popTween = TweenService:Create(
			logoScale,
			TweenInfo.new(ICON_POP_SEC, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Scale = 1 }
		)
		popTween:Play()
		popTween.Completed:Wait()

		table.insert(
			loopTweens,
			TweenService:Create(
				logoScale,
				TweenInfo.new(ICON_PULSE_SEC, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
				{ Scale = ICON_PULSE_SCALE }
			)
		)

		for _, swayName in ICON_SWAY_TARGETS do
			local swayTarget = logoFrame:FindFirstChild(swayName) :: GuiObject?
			if swayTarget then
				swayTarget.Rotation = -ICON_SWAY_DEG
				table.insert(
					loopTweens,
					TweenService:Create(
						swayTarget,
						TweenInfo.new(ICON_SWAY_SEC, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
						{ Rotation = ICON_SWAY_DEG }
					)
				)
			end
		end

		for _, tween in loopTweens do
			tween:Play()
		end
	end

	for _, tween in _playDotsBounce(preloadFrame:FindFirstChild(DOTS_NAME) :: Frame?) do
		table.insert(loopTweens, tween)
	end

	return loopTweens
end

--[[
	背景积木纹理斜向循环滚动；位移恰为一个 TileSize，循环重置时无跳变
	@param canvasGroup CanvasGroup - PreloadGui.CanvasGroup
	@return Tween? - 循环滚动 Tween，关闭时需 Cancel；无 Bg.BgPattern 时为 nil
]]
\n--__LOADINGUI_MORE__\nreturn LoadingUI\n