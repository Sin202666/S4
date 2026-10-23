--[[
	Module: TipsModule/TipsTemplateBuilder
	Description: 服务端下发的模板类型 → 客户端提示数据构建
	Author: 程莘
	Created: 2026-07-02
	Last Modified: 2026-10-12
]]

local Utils = require(game.ReplicatedFirst.AllSideCode.UtilsSystem)
local TipsConfig = require(script.Parent.TipsConfig)

local TranslationHelper = Utils.TranslationHelper
local CfgFind = Utils.CfgFind

-- 与 TipsConfig 通用/彩虹模板、药水 Tips 一致；合并成单条后需启用描边
local DEFAULT_TIP_STROKE = 3

local TipsTemplateBuilder = {}

--[[
	构建「获得」类多段提示的公共前缀文本段
	@return table - 单段 textData 配置（已翻译「获得」文案）
]]
local function _buildObtainPrefixSegment()
	return {
		Text = TranslationHelper.TranslateByKey("获得"),
		TextSize = 35,
		Font = Enum.Font.MontserratBold,
		UIGradientString = "提示白",
		UIStorke = DEFAULT_TIP_STROKE,
		UIStorkeTransparency = 0,
		UIStorkeColor = Color3.new(0, 0, 0),
	}
end

--[[
	构建数量后缀文本段（x数量）
	@param count any - 展示数量，内部 tostring
	@return table - 单段 textData 配置
]]
local function _buildCountSegment(count: any)
	return {
		Text = "x" .. tostring(count),
		TextSize = 35,
		Font = Enum.Font.MontserratBold,
		UIGradientString = "黄",
		UIStorke = DEFAULT_TIP_STROKE,
		UIStorkeTransparency = 0,
		UIStorkeColor = Color3.new(0, 0, 0),
	}
end

--[[
	载具合成获得提示数据
	@param data { [string]: any } - 须含 Lv（number）、ZhName（string 翻译键）、Number（number）、Xyd（渐变色名或稀有度）
	@return {any}? - 三段 textData 数组；字段缺失时 nil
]]
local function _buildVehicleFuseTip(data: { [string]: any }): { any }?
	local lv = data.Lv
	local zhName = data.ZhName
	local number = data.Number
	local xyd = data.Xyd

	if lv == nil or zhName == nil or number == nil or xyd == nil then
		return nil
	end

	return {
		_buildObtainPrefixSegment(),
		{
			Text = " (Lv." .. tostring(lv) .. ") " .. TranslationHelper.TranslateByKey(zhName),
			TextSize = 40,
			Font = Enum.Font.MontserratBold,
			UIGradientString = xyd,
			UIStorke = DEFAULT_TIP_STROKE,
			UIStorkeTransparency = 0,
			UIStorkeColor = Color3.new(0, 0, 0),
		},
		_buildCountSegment(number),
	}
end

--[[
	你已获得药水提示数据（整句按 xyd 稀有度渐变）
	@param data { [string]: any } - 须含 ID（number 药水配置 ID）
	@return {any}? - 单段 textData 数组；配置不存在时 nil
]]
local function _buildPotionObtainTip(data: { [string]: any }): { any }?
	local itemId = tonumber(data.ID)
	if not itemId then
		return nil
	end

	local itemCfg = CfgFind.FindCfgByID(itemId)
	if not itemCfg then
		return nil
	end

	local xyd = itemCfg.xyd or 1
	local nameArg: any = if type(itemCfg.ZhName) == "string" and itemCfg.ZhName ~= ""
		then { itemCfg.ZhName }
		else tostring(itemId)
	local text = TranslationHelper.TranslateByKey("你已获得药水", { nameArg })

	return {
		{
			Text = text,
			TextSize = 43,
			Font = Enum.Font.MontserratBold,
			UIGradientString = xyd,
			UIStorke = DEFAULT_TIP_STROKE,
			UIStorkeTransparency = 0,
			UIStorkeColor = Color3.new(0, 0, 0),
		},
	}
end

--[[
	获得奖励提示数据
	@param data { [string]: any } - 须含 ID（number 物品配置 ID）、Count（number 数量）
	@return {any}? - 三段 textData 数组；配置不存在时 nil
]]
local function _buildRewardTip(data: { [string]: any }): { any }?
	local itemId = tonumber(data.ID)
	local count = data.Count
	if not itemId or count == nil then
		return nil
	end

	local itemCfg = CfgFind.FindCfgByID(itemId)
	if not itemCfg then
		return nil
	end

	-- 整句合并后按 xyd 挂文字 UIGradient（TipsRenderer 合并时优先保留数字稀有度）
	local xyd = math.floor(tonumber(itemCfg.xyd) or 1)

	return {
		_buildObtainPrefixSegment(),
		{
			Text = " " .. TranslationHelper.TranslateByKey(itemCfg.ZhName) .. " ",
			TextSize = 40,
			Font = Enum.Font.MontserratBold,
			UIGradientString = xyd,
			UIStorke = DEFAULT_TIP_STROKE,
			UIStorkeTransparency = 0,
			UIStorkeColor = Color3.new(0, 0, 0),
		},
		_buildCountSegment(count),
	}
end

local _TEMPLATE_BUILDERS: { [string]: (data: { [string]: any }) -> { any }? } = {
	[TipsConfig.SERVER_TEMPLATE_VEHICLE_FUSE] = _buildVehicleFuseTip,
	[TipsConfig.SERVER_TEMPLATE_REWARD] = _buildRewardTip,
	[TipsConfig.SERVER_TEMPLATE_POTION_OBTAIN] = _buildPotionObtainTip,
}

--[[
	根据服务端模板 Type 构建多段提示数据
	@param data { [string]: any } - 须含 Type（string）；载具合成须 Lv、ZhName、Number、Xyd；获得奖励须 ID、Count；你已获得药水须 ID
	@return {any}? - TipsRenderer.createTip 入参数组；Type 未知或字段无效时 nil
]]
function TipsTemplateBuilder.buildFromServerData(data: { [string]: any }): { any }?
	local typeName = data.Type
	if typeName == nil then
		return nil
	end

	local builder = _TEMPLATE_BUILDERS[typeName]
	if not builder then
		return nil
	end

	return builder(data)
end

return TipsTemplateBuilder
