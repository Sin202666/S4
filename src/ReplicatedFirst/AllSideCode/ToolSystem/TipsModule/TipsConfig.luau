--[[
	Module: TipsModule/TipsConfig
	Description: 提示系统常量、模板与资源引用
	Author: 程莘
	Created: 2026-07-02
	Last Modified: 2026-10-13

	模板：
	- 通用提示 / 通用警告：纯 TextColor
	- 彩虹提示：默认挂 AllGridients「彩虹Tips」；可被 uiGradientOverride（如稀有度 xyd）覆盖为对应 *-Text 渐变
	- 服务端模板「你已获得药水」：整句按 xyd 稀有度渐变
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Utils = require(game.ReplicatedFirst.AllSideCode.UtilsSystem)
local ResourceUtil = Utils.ResourceUtil

local TEMPLATE_NORMAL = "通用提示"
local TEMPLATE_ERROR = "通用警告"
local TEMPLATE_RAINBOW = "彩虹提示"

local TipsConfig = {
	MAX_SHOW_NUMBER = 3,
	DISPLAY_DURATION = 3,
	TEMPLATE_NORMAL = TEMPLATE_NORMAL,
	TEMPLATE_ERROR = TEMPLATE_ERROR,
	TEMPLATE_RAINBOW = TEMPLATE_RAINBOW,
	TWEEN_SHOW_DURATION = 0.5,
	TWEEN_TEXT_DURATION = 0.4,
	TEXT_BOUNDS = Vector2.new(1920, 1080),
	POOL_BG_TEMP = "Tips/BGTemp",
	POOL_TEXT_TEMP = "Tips/TextTemp",
	SERVER_TEMPLATE_VEHICLE_FUSE = "载具合成",
	SERVER_TEMPLATE_REWARD = "获得奖励",
	SERVER_TEMPLATE_POTION_OBTAIN = "你已获得药水",
	SOUND_ERROR = "音效-UI-通用消极点击",
	GRADIENT_RAINBOW = "彩虹Tips",
	-- 炼金标记配方相关提示（AllGridients 预设名；文字侧经 GradientCfg「提示黄-Text」映射）
	GRADIENT_TIP_YELLOW = "提示黄",
}

local _TIP_TEMPLATES: { [string]: { [string]: any } } = {
	[TEMPLATE_NORMAL] = {
		Text = "",
		TextSize = 43,
		Font = Enum.Font.MontserratBold,
		-- 直接用文本色（不再挂 UIGradient）
		TextColor = Color3.new(1, 1, 1),
		UIStorke = 3,
		UIStorkeTransparency = 0,
		UIStorkeColor = Color3.new(0, 0, 0),
	},
	[TEMPLATE_ERROR] = {
		Text = "",
		TextSize = 43,
		Font = Enum.Font.MontserratBold,
		TextColor = Color3.fromHex("#ff1919"),
		UIStorke = 3,
		UIStorkeTransparency = 0,
		UIStorkeColor = Color3.new(0, 0, 0),
	},
	-- 特殊怪刷新等：不设 TextColor，走 UIGradientString → AddGradientColor(..., true)
	[TEMPLATE_RAINBOW] = {
		Text = "",
		TextSize = 43,
		Font = Enum.Font.MontserratBold,
		UIGradientString = TipsConfig.GRADIENT_RAINBOW,
		UIStorke = 3,
		UIStorkeTransparency = 0,
		UIStorkeColor = Color3.new(0, 0, 0),
	},
}

local _assetCache: { [string]: Instance | false } = {}

--[[
	解析 Tips 资源模板（ResourceUtil 优先，迁移期回退 Assets）
	@param relativePath string - 资源相对路径，如 Tips/BGTemp、Tips/TextTemp
	@return Instance? - 模板实例；路径无效时 nil
]]
local function _resolveTemplate(relativePath: string): Instance?
	local template = ResourceUtil.GetTemplate(relativePath)
	if template then
		return template
	end

	local assets = ReplicatedStorage:FindFirstChild("Assets")
	if not assets then
		return nil
	end

	local current: Instance = assets
	for _, segment in string.split(relativePath, "/") do
		if segment == "" then
			continue
		end
		local child = current:FindFirstChild(segment)
		if not child then
			return nil
		end
		current = child
	end

	return current
end

--[[
	获取对象池模板（带缓存，避免重复 FindFirstChild）
	@param relativePath string - 资源相对路径，见 POOL_BG_TEMP / POOL_TEXT_TEMP
	@return Instance? - 可克隆的池模板；未找到时 nil 并缓存失败标记
]]
function TipsConfig.getPoolTemplate(relativePath: string): Instance?
	if _assetCache[relativePath] ~= nil then
		local cached = _assetCache[relativePath]
		if cached == false then
			return nil
		end
		return cached
	end

	local template = _resolveTemplate(relativePath)
	_assetCache[relativePath] = template or false
	return template
end

--[[
	复制提示样式模板，避免修改内部 _TIP_TEMPLATES
	@param templateName string - 模板名，如 TEMPLATE_NORMAL、TEMPLATE_ERROR、TEMPLATE_RAINBOW
	@return { [string]: any }? - 模板浅拷贝表；名称不存在时 nil
]]
function TipsConfig.copyTemplate(templateName: string): { [string]: any }?
	local template = _TIP_TEMPLATES[templateName]
	if not template then
		return nil
	end

	local copy = {}
	for key, value in pairs(template) do
		copy[key] = value
	end
	return copy
end

return TipsConfig
