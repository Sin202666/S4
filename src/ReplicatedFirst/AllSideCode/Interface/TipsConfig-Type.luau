local module = {}

module.MAX_SHOW_NUMBER = 3
module.DISPLAY_DURATION = 3
module.TEMPLATE_NORMAL = "通用提示"
module.TEMPLATE_ERROR = "通用警告"
module.TEMPLATE_RAINBOW = "彩虹提示"
module.TWEEN_SHOW_DURATION = 0.5
module.TWEEN_TEXT_DURATION = 0.4
module.TEXT_BOUNDS = Vector2.new(1920, 1080)
module.POOL_BG_TEMP = "Tips/BGTemp"
module.POOL_TEXT_TEMP = "Tips/TextTemp"
module.SERVER_TEMPLATE_VEHICLE_FUSE = "载具合成"
module.SERVER_TEMPLATE_REWARD = "获得奖励"
module.SERVER_TEMPLATE_POTION_OBTAIN = "你已获得药水"
module.SOUND_ERROR = "音效-UI-通用消极点击"
module.GRADIENT_RAINBOW = "彩虹Tips"
module.GRADIENT_TIP_YELLOW = "提示黄"

--[[
	获取对象池模板（带缓存）
	@param relativePath string - 资源相对路径，如 Tips/BGTemp
	@return Instance? - 池模板实例；未找到时 nil
]]
function module.getPoolTemplate(relativePath: string): Instance?
end

--[[
	复制提示样式模板
	@param templateName string - TipsConfig 模板名
	@return { [string]: any }? - 模板浅拷贝；名称不存在时 nil
]]
function module.copyTemplate(templateName: string): { [string]: any }?
end

return module
