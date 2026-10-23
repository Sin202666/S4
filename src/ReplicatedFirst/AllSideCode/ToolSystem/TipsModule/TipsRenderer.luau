--[[
	Module: TipsModule/TipsRenderer
	Description: 客户端提示 UI 渲染（TextTemp 直挂 NewTipsFrame、动画、回收）；同键合并并刷新时长
	Author: 程莘
	Created: 2026-07-02
	Last Modified: 2026-10-16

	合并策略：
	- 多段且末段为 x数字（奖励/合成等）：按前缀匹配，数量相加，展示仍为「前缀x合计」
	- 其余（普通单段等）：按全文匹配，出现次数≥2 时追加「 x次数」
	- 不对照扁平全文做 xN 启发式，避免与次数叠层格式串台

	注意：本模块含客户端副作用（操作 PlayerGui），仅客户端 require。
	小屏（ViewportDisplaySize.Small）提示字高与字号放大 50%；展示动画会把 TextScaled 打开，可视字号由标签高度决定。
]]

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")

local Utils = require(game.ReplicatedFirst.AllSideCode.UtilsSystem)
local TipsConfig = require(script.Parent.TipsConfig)
local TipsTemplateBuilder = require(script.Parent.TipsTemplateBuilder)

local InsMgr = Utils.InsMgr
local UIMgr = Utils.UIMgr
local ObjectPoolUtil = Utils.ObjectPoolUtil
local Players = Utils.Players

local TipsRenderer = {}

-- 小屏提示相对设计字号的放大倍数（展示时 TextScaled，同时放大行高才看得见）
local SMALL_SCREEN_TEXT_SCALE = 1.5
-- 提示条设计行高（与通用模板 TextSize 43 对齐）
local TIP_LINE_HEIGHT = 43

-- 合并模式：次数叠层 / 末段数量加总
local MERGE_MODE_STACK = "stack"
local MERGE_MODE_QUANTITY = "quantity"
-- 末段数量后缀（与 TipsTemplateBuilder._buildCountSegment 一致）
local COUNT_SEGMENT_PATTERN = "^x(%d+)$"

-- ========================================
-- 私有变量
-- ========================================
local _layoutIndex = 0
local _isClientReady = false
local _localPlayer: Player? = nil
local _hidingLabels: { [TextLabel]: boolean } = {}
local _tipCleanupThreads: { [TextLabel]: thread } = {}
-- 合并用（仅展示中）：匹配键 / 模式 / 累计值（stack=出现次数，quantity=物品数量）
local _tipMergeKeys: { [TextLabel]: string } = {}
local _tipMergeModes: { [TextLabel]: string } = {}
local _tipMergeAmounts: { [TextLabel]: number } = {}

-- ========================================
-- 客户端初始化
-- ========================================

--[[
	确保仅在客户端初始化运行时状态
	@return boolean - 客户端且初始化成功为 true；服务端调用为 false
]]
local function _ensureClientReady(): boolean
	if not RunService:IsClient() then
		warn("TipsRenderer 仅客户端可用")
		return false
	end

	if _isClientReady then
		return true
	end

	_localPlayer = Players.LocalPlayer
	_isClientReady = true
	return true
end

--[[
	获取 PlayerGui 下 Tips 条容器 Frame
	@return Frame? - TipsGui.NewTipsFrame；PlayerGui 或节点缺失时 nil
]]
local function _getTipsFrame(): Frame?
	if not _ensureClientReady() or not _localPlayer then
		return nil
	end

	local playerGui = _localPlayer:FindFirstChild("PlayerGui")
	if not playerGui then
		return nil
	end

	local tipGui = playerGui:FindFirstChild("TipsGui")
	if not tipGui then
		return nil
	end

	return tipGui:FindFirstChild("NewTipsFrame") :: Frame?
end

-- ========================================
-- 数据与队列
-- ========================================

--[[
	多段样式优先级：TextColor > 稀有度 xyd（数字）> 命名渐变（如「黄」）> 提示白/无
	避免「获得奖励」末段 x数量 的黄渐变盖住物品名的 xyd 渐变
	@param segment { [string]: any } - 单段配置
	@return number - 分数越高越优先保留为整句样式
]]
local function _segmentStyleScore(segment: { [string]: any }): number
	if typeof(segment.TextColor) == "Color3" then
		return 100
	end
	local gradientName = segment.UIGradientString
	if gradientName == nil or gradientName == "提示白" then
		return 0
	end
	-- 稀有度：number 或可 tonumber 的字符串（如 "4"）
	if type(gradientName) == "number" or tonumber(tostring(gradientName)) ~= nil then
		return 50
	end
	return 10
end

--[[
	多段提示合并为单条 TextLabel 配置（奖励类等）；单段原样返回
	@param tipData {any} - 有序文本段配置数组
	@return { [string]: any }? - 合并后的 textData；空数组时 nil
]]
local function _mergeTipSegments(tipData: { any }): { [string]: any }?
	if #tipData == 0 then
		return nil
	end
	if #tipData == 1 then
		return tipData[1]
	end

	local mergedText = ""
	local styleSource = tipData[1]
	local bestScore = _segmentStyleScore(styleSource)
	for _, segment in ipairs(tipData) do
		mergedText ..= segment.Text or ""
		local score = _segmentStyleScore(segment)
		-- 同分不覆盖，保留先出现的高优先级（如物品 xyd 不被后续「黄」替换）
		if score > bestScore then
			bestScore = score
			styleSource = segment
		end
	end

	local merged: { [string]: any } = {}
	for key, value in pairs(styleSource) do
		merged[key] = value
	end
	merged.Text = mergedText
	return merged
end

--[[
	收集 NewTipsFrame 下当前展示中的提示 TextLabel（不含 UIListLayout 等）
	@param tipsFrame Frame - NewTipsFrame 容器
	@return { TextLabel } - 按 LayoutOrder 排序前的列表
]]
local function _collectTipLabels(tipsFrame: Frame): { TextLabel }
	local tipList: { TextLabel } = {}
	for _, child in tipsFrame:GetChildren() do
		if child:IsA("TextLabel") then
			table.insert(tipList, child)
		end
	end
	return tipList
end

--[[
	清除提示标签上的合并元数据
	@param textLabel TextLabel - 目标提示标签
	@return nil
]]
local function _clearTipMergeMeta(textLabel: TextLabel)
	_tipMergeKeys[textLabel] = nil
	_tipMergeModes[textLabel] = nil
	_tipMergeAmounts[textLabel] = nil
end

--[[
	超员时立刻销毁最早提示（不播动画）
	@param textLabel TextLabel - 待移除的提示标签
	@return nil
]]
local function _removeTipImmediate(textLabel: TextLabel)
	local cleanupThread = _tipCleanupThreads[textLabel]
	if cleanupThread then
		task.cancel(cleanupThread)
		_tipCleanupThreads[textLabel] = nil
	end
	_hidingLabels[textLabel] = nil
	_clearTipMergeMeta(textLabel)
	ObjectPoolUtil.backToPool(textLabel)
end

--[[
	超出 MAX_SHOW_NUMBER 时按 LayoutOrder 立刻销毁最早提示
	@param tipsFrame Frame - NewTipsFrame 容器
	@return nil
]]
local function _enforceTipLimit(tipsFrame: Frame)
	local tipList = _collectTipLabels(tipsFrame)
	if #tipList <= TipsConfig.MAX_SHOW_NUMBER then
		return
	end

	table.sort(tipList, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)

	for i = 1, #tipList - TipsConfig.MAX_SHOW_NUMBER do
		_removeTipImmediate(tipList[i])
	end
end

-- ========================================
-- 动画
-- ========================================

--[[
	播放 TextLabel 展开动画（高度渐入）
	@param textLabel TextLabel - 已挂载到 NewTipsFrame 的提示标签
	@return nil
]]
local function _showTextTween(textLabel: TextLabel)
	textLabel.TextScaled = true
	local labelSize = textLabel.Size
	textLabel.Size = UDim2.new(labelSize.X.Scale, labelSize.X.Offset, 0, 0)

	local textTween = TweenService:Create(
		textLabel,
		TweenInfo.new(TipsConfig.TWEEN_TEXT_DURATION, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Size = labelSize }
	)
	textTween.Completed:Once(function()
		textTween:Destroy()
	end)
	textTween:Play()
end

--[[
	播放渐隐消失动画并回收到对象池（幂等，重复调用安全）
	@param textLabel TextLabel - 待回收的提示标签
	@return nil
]]
local function _hideTextTween(textLabel: TextLabel)
	if _hidingLabels[textLabel] then
		return
	end
	_hidingLabels[textLabel] = true

	local tweenInfo = TweenInfo.new(TipsConfig.TWEEN_TEXT_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local textTween = TweenService:Create(textLabel, tweenInfo, { TextTransparency = 1 })

	local uiStroke = textLabel:FindFirstChildOfClass("UIStroke")
	local strokeTween: Tween? = nil
	if uiStroke and uiStroke.Enabled then
		strokeTween = TweenService:Create(uiStroke, tweenInfo, { Transparency = 1 })
		strokeTween:Play()
	end

	textTween.Completed:Once(function()
		textTween:Destroy()
		if strokeTween then
			strokeTween:Destroy()
		end
		_hidingLabels[textLabel] = nil
		_tipCleanupThreads[textLabel] = nil
		_clearTipMergeMeta(textLabel)
		ObjectPoolUtil.backToPool(textLabel)
	end)
	textTween:Play()
end

-- ========================================
-- UI 创建
-- ========================================

--[[
	从对象池创建单个文本提示标签
	@param textData { [string]: any } - 文本段配置：Text、TextSize、Font、TextColor / UIGradientString、UIStorke 等
	@return TextLabel? - 文本标签实例；池模板缺失时 nil
]]
local function _createText(textData: { [string]: any }): TextLabel?
	local textTemplate = TipsConfig.getPoolTemplate(TipsConfig.POOL_TEXT_TEMP)
	if not textTemplate then
		return nil
	end

	local textLabel: TextLabel = ObjectPoolUtil.getObjectFromPool(textTemplate)
	if not textLabel then
		return nil
	end

	textLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	textLabel.Text = textData.Text or ""
	textLabel.Font = textData.Font or Enum.Font.MontserratBold
	textLabel.TextScaled = false
	textLabel.TextWrapped = false
	textLabel.AutomaticSize = Enum.AutomaticSize.None
	textLabel.BackgroundTransparency = 1
	textLabel.TextTransparency = 0
	-- 池复用须复位；含 <font> 时再开 RichText
	textLabel.RichText = false
	local tipText = textLabel.Text
	if string.find(tipText, "<font", 1, true) or string.find(tipText, "<Font", 1, true) then
		textLabel.RichText = true
	end

	local textSize = textData.TextSize or 20
	local lineHeight = TIP_LINE_HEIGHT
	local widthScale = 1
	local strokeScale = 1
	-- 小屏根 UIScale 会把提示缩得很小；字高与宽度一起放大，避免 TextScaled 后被裁切
	if GuiService.ViewportDisplaySize == Enum.DisplaySize.Small then
		textSize *= SMALL_SCREEN_TEXT_SCALE
		lineHeight *= SMALL_SCREEN_TEXT_SCALE
		widthScale = SMALL_SCREEN_TEXT_SCALE / 1.8
		strokeScale = SMALL_SCREEN_TEXT_SCALE
	end
	textLabel.TextSize = textSize
	textLabel.Size = UDim2.new(widthScale, 0, 0, lineHeight)

	local uiStroke: UIStroke = InsMgr.GetIns("UIStroke", "UIStroke", textLabel)
	if textData.UIStorke and textData.UIStorke > 0 then
		uiStroke.Thickness = (textData.UIStorke or 2) * strokeScale
		uiStroke.Transparency = textData.UIStorkeTransparency or 0
		uiStroke.Color = textData.UIStorkeColor or Color3.new(0, 0, 0)
		uiStroke.Enabled = true
	else
		uiStroke.Enabled = false
	end

	-- TextColor 优先：直接上色并关掉渐变；否则沿用 UIGradientString
	if typeof(textData.TextColor) == "Color3" then
		textLabel.TextColor3 = textData.TextColor
		local gradient = textLabel:FindFirstChildOfClass("UIGradient")
		if gradient then
			gradient.Enabled = false
		end
	elseif textData.UIGradientString then
		textLabel.TextColor3 = Color3.new(1, 1, 1)
		UIMgr.AddGradientColor(textData.UIGradientString, textLabel, true)
		local gradient = textLabel:FindFirstChildOfClass("UIGradient")
		if gradient then
			gradient.Enabled = true
		end
	else
		local gradient = textLabel:FindFirstChildOfClass("UIGradient")
		if gradient then
			gradient.Enabled = false
		end
	end

	return textLabel
end

--[[
	清理旧版 BGTemp 直挂 NewTipsFrame 的残留（迁移期执行一次）
	@param tipsFrame Frame - NewTipsFrame 容器
	@return nil
]]
local _legacyBgCleaned = false
local function _cleanupLegacyBgTips(tipsFrame: Frame)
	if _legacyBgCleaned then
		return
	end
	_legacyBgCleaned = true

	for _, child in tipsFrame:GetChildren() do
		if child:IsA("Frame") and child.Name == "BGTemp" then
			child:Destroy()
		end
	end
end

-- ========================================
-- 公共 API
-- ========================================

--[[
	解析展示时长：合法正数用调用方传入值，否则回退默认
	@param duration number? - 调用方指定的秒数
	@return number - 最终用于 task.delay 的秒数
]]
local function _resolveDisplayDuration(duration: number?): number
	local resolved = tonumber(duration)
	if resolved and resolved > 0 then
		return resolved
	end
	return TipsConfig.DISPLAY_DURATION
end

--[[
	从多段 tipData 解析合并模式（在扁平化之前，保留末段结构信息）
	多段且末段为 x数字 → quantity（前缀匹配、数量加总）；否则 → stack（全文匹配、次数叠层）
	@param tipData {any} - 有序文本段配置数组（非空）
	@return string - MERGE_MODE_QUANTITY 或 MERGE_MODE_STACK
	@return string - 匹配键（quantity 为除末段外拼接；stack 为全文拼接）
	@return number - 本次数量（quantity 为末段数字；stack 恒为 1）
]]
local function _resolveTipMergeInfo(tipData: { any }): (string, string, number)
	if #tipData >= 2 then
		local lastSegment = tipData[#tipData]
		local lastText = ""
		if lastSegment then
			lastText = lastSegment.Text or ""
		end
		local qtyStr = string.match(lastText, COUNT_SEGMENT_PATTERN)
		if qtyStr then
			local mergeKey = ""
			for i = 1, #tipData - 1 do
				mergeKey ..= tipData[i].Text or ""
			end
			return MERGE_MODE_QUANTITY, mergeKey, tonumber(qtyStr) :: number
		end
	end

	local fullText = ""
	for _, segment in ipairs(tipData) do
		fullText ..= segment.Text or ""
	end
	return MERGE_MODE_STACK, fullText, 1
end

--[[
	按累计出现次数拼展示文案（≥2 时追加 " xN"）
	@param mergeKey string - 不含次数后缀的原文案
	@param stackCount number - 累计展示次数
	@return string - 最终展示文案
]]
local function _formatStackedText(mergeKey: string, stackCount: number): string
	if stackCount <= 1 then
		return mergeKey
	end
	return mergeKey .. " x" .. tostring(stackCount)
end

--[[
	按累计物品数量拼展示文案（与 Builder 段拼接一致：前缀直接接 xN）
	@param mergeKey string - 除数量段外的前缀文案
	@param quantity number - 累计物品数量
	@return string - 最终展示文案
]]
local function _formatQuantityText(mergeKey: string, quantity: number): string
	return mergeKey .. "x" .. tostring(quantity)
end

--[[
	在容器中查找仍在展示、且合并键与模式相同的提示（不含正在渐隐的）
	@param tipsFrame Frame - NewTipsFrame 容器
	@param mergeKey string - 待匹配的合并键
	@param mode string - MERGE_MODE_QUANTITY 或 MERGE_MODE_STACK
	@return TextLabel? - 命中的标签；无则 nil
]]
local function _findVisibleTipByMergeKey(tipsFrame: Frame, mergeKey: string, mode: string): TextLabel?
	for _, child in tipsFrame:GetChildren() do
		if
			child:IsA("TextLabel")
			and not _hidingLabels[child]
			and _tipMergeKeys[child] == mergeKey
			and _tipMergeModes[child] == mode
		then
			return child
		end
	end
	return nil
end

--[[
	取消旧计时并按 duration 重新安排渐隐回收
	@param textLabel TextLabel - 目标提示标签
	@param duration number? - 展示秒数；nil 或非法时用 TipsConfig.DISPLAY_DURATION
	@return nil
]]
local function _restartTipCleanup(textLabel: TextLabel, duration: number?)
	local oldThread = _tipCleanupThreads[textLabel]
	if oldThread then
		task.cancel(oldThread)
		_tipCleanupThreads[textLabel] = nil
	end

	local cleanupThread = task.delay(_resolveDisplayDuration(duration), function()
		_tipCleanupThreads[textLabel] = nil
		if textLabel.Parent then
			_hideTextTween(textLabel)
		end
	end)
	_tipCleanupThreads[textLabel] = cleanupThread
end

--[[
	同键叠加：按模式累加数量或次数、改写展示文案、刷新显示时长
	@param textLabel TextLabel - 已存在的提示标签（须已登记合并元数据）
	@param incomingAmount number - 本次增量（quantity 为物品数；stack 为 1）
	@param duration number? - 本次触发的展示秒数
	@return boolean - 叠加成功为 true；元数据缺失时 false
]]
local function _stackOntoExistingTip(textLabel: TextLabel, incomingAmount: number, duration: number?): boolean
	local mergeKey = _tipMergeKeys[textLabel]
	local mode = _tipMergeModes[textLabel]
	if mergeKey == nil or mode == nil then
		return false
	end

	local nextAmount = (_tipMergeAmounts[textLabel] or 0) + incomingAmount
	_tipMergeAmounts[textLabel] = nextAmount

	if mode == MERGE_MODE_QUANTITY then
		textLabel.Text = _formatQuantityText(mergeKey, nextAmount)
	else
		textLabel.Text = _formatStackedText(mergeKey, nextAmount)
	end
	_restartTipCleanup(textLabel, duration)
	return true
end

--[[
	创建并展示提示（单条 TextTemp 直挂 NewTipsFrame）；同合并键则叠层并刷新时长
	@param tipData {any} - 有序文本段配置数组，多项时合并为单条 TextLabel
	@param duration number? - 展示秒数；nil 或非法时用 TipsConfig.DISPLAY_DURATION
	@return nil - PlayerGui 或池模板不可用时静默 return
]]
function TipsRenderer.createTip(tipData: { any }, duration: number?)
	local tipsFrame = _getTipsFrame()
	if not tipsFrame then
		return
	end

	_cleanupLegacyBgTips(tipsFrame)

	if type(tipData) ~= "table" or #tipData == 0 then
		return
	end

	local mergeMode, mergeKey, incomingAmount = _resolveTipMergeInfo(tipData)
	local existingTip = _findVisibleTipByMergeKey(tipsFrame, mergeKey, mergeMode)
	if existingTip and _stackOntoExistingTip(existingTip, incomingAmount, duration) then
		return
	end

	local textData = _mergeTipSegments(tipData)
	if not textData then
		return
	end

	-- 数量模式：展示用累计格式，与后续叠层一致（首条 amount 即末段数量）
	if mergeMode == MERGE_MODE_QUANTITY then
		textData.Text = _formatQuantityText(mergeKey, incomingAmount)
	end

	local textLabel = _createText(textData)
	if not textLabel then
		return
	end

	_layoutIndex += 1
	textLabel.LayoutOrder = _layoutIndex
	textLabel.Parent = tipsFrame
	_tipMergeKeys[textLabel] = mergeKey
	_tipMergeModes[textLabel] = mergeMode
	_tipMergeAmounts[textLabel] = incomingAmount

	_showTextTween(textLabel)
	_enforceTipLimit(tipsFrame)

	_restartTipCleanup(textLabel, duration)
end

--[[
	套用 TipsConfig 模板创建单句提示
	@param text string - 展示文案（通常已翻译）
	@param templateName string - TipsConfig 模板名，如 TEMPLATE_NORMAL、TEMPLATE_ERROR
	@param duration number? - 展示秒数；nil 时用 TipsConfig.DISPLAY_DURATION
	@param uiGradientOverride (string | number)? - 覆盖模板 UIGradientString（如稀有度 xyd）；nil 用模板原值
	@return nil - 模板名不存在时静默 return
]]
function TipsRenderer.templateTip(
	text: string,
	templateName: string,
	duration: number?,
	uiGradientOverride: (string | number)?
)
	local templateCopy = TipsConfig.copyTemplate(templateName)
	if not templateCopy then
		return
	end

	templateCopy.Text = text
	if uiGradientOverride ~= nil then
		-- 稀有度等：走文字渐变，勿保留模板 TextColor 以免盖住 UIGradient
		templateCopy.UIGradientString = uiGradientOverride
		templateCopy.TextColor = nil
	end
	TipsRenderer.createTip({ templateCopy }, duration)
end

--[[
	根据服务端下发的模板类型表构建并展示提示
	@param data { [string]: any } - 须含 Type；字段见 TipsTemplateBuilder.buildFromServerData
	@return nil - Type 未知或字段缺失时静默 return
]]
function TipsRenderer.showFromServerTemplate(data: { [string]: any })
	local tipData = TipsTemplateBuilder.buildFromServerData(data)
	if tipData then
		TipsRenderer.createTip(tipData)
	end
end

return TipsRenderer
