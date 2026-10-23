--[[
	Module: CustomEUI
	Description: Custom 样式 ProximityPrompt 的 E 键 / 触屏 / 手柄外观与交互高亮
	Author: 程莘
	Created: 2026-10-16
	Last Modified: 2026-10-16

	资源依赖（Studio 资源，Git 不含 Instance）：
	- ReplicatedStorage.Assets.BillBoard.Default（BillboardGui 模板）
	- ReplicatedStorage.Assets.ModelRes.ProximityPromptHighLight（Highlight；兼容旧 RS.ModelRes）

	业务侧将 ProximityPrompt.Style 设为 Custom；本脚本监听 PromptShown 渲染 UI。
	缺 Default 模板时回退 Style=Default，避免 Custom 无外观导致「完全看不见 E」。

	本地化：
	- Action 文案须用 Prompt 的 Attribute `_key`（TranslationHelper.SetText 写入），勿用已翻译的 ActionText 当键
	- 无 `_key` 时用 ActionText 作键；键不在 Language 表则 SetRawText，避免「未本地化-」

	手柄：
	- PlayStation：显示与 TouchImg 同级的 PspImg
	- 其它手柄：显示 GamePadImg（原逻辑）

	显隐：
	- LocalPlayer「是否弹窗打开中」/ Scriptable 相机时用 MaxDistance 哨兵收起
	- 本脚本用 InsMgr 确保 BoolValue 存在；弹窗扫描刷新由 UIMgr 后续接入
	- PromptShown 时强制 CustomEUI ScreenGui.Enabled=true（防 HideAllBut / Loading 隔离后未恢复）
]]

local ProximityPromptService = game:GetService("ProximityPromptService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Utils = require(game.ReplicatedFirst.AllSideCode.UtilsSystem)

local AddListen = Utils.AddListen
local AssetRegistry = Utils.AssetRegistry
local InsMgr = Utils.InsMgr
local Log = Utils.Log
local ResourceUtil = Utils.ResourceUtil
local TranslationHelper = Utils.TranslationHelper
local UIanima = Utils.UIanima
local LocalPlayer = Utils.LocalPlayer

local PlayerGui = LocalPlayer:WaitForChild("PlayerGui", math.huge)

-- 与 AddListen.CUSTOM_EUI_SCREEN_GUI_NAME 保持一致（勿用 script.Name，避免 Rojo 后缀差异）
local CUSTOM_EUI_SCREEN_GUI_NAME = "CustomEUI"
local PROMPT_BILLBOARD_CATALOG = "BillBoard"
local PROMPT_DEFAULT_TEMPLATE_NAME = "Default"
local PROMPT_DEFAULT_PATH = AssetRegistry.BuildCatalogPath(PROMPT_BILLBOARD_CATALOG, PROMPT_DEFAULT_TEMPLATE_NAME)
local HIGHLIGHT_PATH = AssetRegistry.BuildCatalogPath(AssetRegistry.Catalog.ModelRes, "ProximityPromptHighLight")
local MARK_ATTR = "MaxDis"
local BILLBOARD_HIDDEN_MAX_DISTANCE = 0.001

--[[
	解析 ProximityPrompt 高亮模板（优先 Assets/ModelRes，再兜底旧 RS.ModelRes）

	@return Highlight? - 高亮实例；缺失为 nil
]]
local function _resolveProximityPromptHighlight(): Highlight?
	local fromAssets = ResourceUtil.GetTemplate(HIGHLIGHT_PATH)
	if fromAssets and fromAssets:IsA("Highlight") then
		return fromAssets
	end
	local modelRes = game.ReplicatedStorage:FindFirstChild("ModelRes")
	if modelRes then
		local legacy = modelRes:FindFirstChild("ProximityPromptHighLight")
		if legacy and legacy:IsA("Highlight") then
			return legacy
		end
	end
	return nil
end

local ProximityPromptHighLight: Highlight? = _resolveProximityPromptHighlight()
if not ProximityPromptHighLight then
	Log.warn("[CustomEUI] 缺少 ModelRes.ProximityPromptHighLight，路径:", HIGHLIGHT_PATH)
end

local nowProximityPrompt: BillboardGui? = nil

local KeyboardButtonImage = {
	[Enum.KeyCode.Backspace] = "rbxasset://textures/ui/Controls/backspace.png",
	[Enum.KeyCode.Return] = "rbxasset://textures/ui/Controls/return.png",
	[Enum.KeyCode.LeftShift] = "rbxasset://textures/ui/Controls/shift.png",
	[Enum.KeyCode.RightShift] = "rbxasset://textures/ui/Controls/shift.png",
	[Enum.KeyCode.Tab] = "rbxasset://textures/ui/Controls/tab.png",
}

local KeyboardButtonIconMapping = {
	["'"] = "rbxasset://textures/ui/Controls/apostrophe.png",
	[","] = "rbxasset://textures/ui/Controls/comma.png",
	["`"] = "rbxasset://textures/ui/Controls/graveaccent.png",
	["."] = "rbxasset://textures/ui/Controls/period.png",
	[" "] = "rbxasset://textures/ui/Controls/spacebar.png",
}

local KeyCodeToTextMapping = {
	[Enum.KeyCode.LeftControl] = "Ctrl",
	[Enum.KeyCode.RightControl] = "Ctrl",
	[Enum.KeyCode.LeftAlt] = "Alt",
	[Enum.KeyCode.RightAlt] = "Alt",
	[Enum.KeyCode.F1] = "F1",
	[Enum.KeyCode.F2] = "F2",
	[Enum.KeyCode.F3] = "F3",
	[Enum.KeyCode.F4] = "F4",
	[Enum.KeyCode.F5] = "F5",
	[Enum.KeyCode.F6] = "F6",
	[Enum.KeyCode.F7] = "F7",
	[Enum.KeyCode.F8] = "F8",
	[Enum.KeyCode.F9] = "F9",
	[Enum.KeyCode.F10] = "F10",
	[Enum.KeyCode.F11] = "F11",
	[Enum.KeyCode.F12] = "F12",
}

local PSP_IMG_NAME = "PspImg"

--[[
	当前是否为 PlayStation 系手柄映射（对齐 GamePad.client）

	@return boolean - ButtonA 映射为 ButtonCross 时为 true
]]
local function _isPlayStationGamepad(): boolean
	local ok, mapped = pcall(function()
		return UserInputService:GetStringForKeyCode(Enum.KeyCode.ButtonA)
	end)
	if not ok or type(mapped) ~= "string" then
		return false
	end
	return mapped == "ButtonCross"
end

--[[
	从 Assets/BillBoard 解析 ProximityPrompt BillboardGui 模板

	@param templateName string? - 模板名；省略为 Default
	@return BillboardGui? - 模板实例；缺失为 nil
]]
local function _getPromptBillboardTemplate(templateName: string?): BillboardGui?
	local name = templateName or PROMPT_DEFAULT_TEMPLATE_NAME
	local relativePath = AssetRegistry.BuildCatalogPath(PROMPT_BILLBOARD_CATALOG, name)
	local template = ResourceUtil.GetTemplate(relativePath)
	if template and template:IsA("BillboardGui") then
		return template
	end
	return nil
end

--[[
	获取或创建 CustomEUI ScreenGui 容器；显示 Prompt 时强制 Enabled（防过场/加载隔离残留）

	@return ScreenGui - PlayerGui 下的 CustomEUI
]]
local function _getScreenGui(): ScreenGui
	local screenGui = PlayerGui:FindFirstChild(CUSTOM_EUI_SCREEN_GUI_NAME)
	if screenGui == nil then
		screenGui = Instance.new("ScreenGui")
		screenGui.Name = CUSTOM_EUI_SCREEN_GUI_NAME
		screenGui.ResetOnSpawn = false
		screenGui.Parent = PlayerGui
	end
	local gui = screenGui :: ScreenGui
	-- HideAllBut / LoadingUI 用 Attribute「Enabled」暂存；恢复失败时这里兜底打开
	if gui.Enabled ~= true then
		gui.Enabled = true
		gui:SetAttribute("Enabled", nil)
	end
	return gui
end

--[[
	判断是否为「收起世界 UI」用的哨兵 MaxDistance

	@param distance number - MaxDistance
	@return boolean - 是哨兵值则为 true
]]
local function _isBillboardHiddenDistance(distance: number): boolean
	return distance <= BILLBOARD_HIDDEN_MAX_DISTANCE + 0.0001
end

--[[
	设置交互高亮 Adornee

	@param adornee Instance? - 高亮目标；nil 为清除
	@return nil - 无返回值
]]
local function _setHighlightAdornee(adornee: Instance?)
	if not ProximityPromptHighLight then
		return
	end
	ProximityPromptHighLight.Adornee = adornee
	if adornee then
		ProximityPromptHighLight.Enabled = true
	end
end

--[[
	初始化圆形按住进度条

	@param bar Frame - 进度条根节点
	@return nil - 无返回值
]]
local function _setUpCircularProgressBar(bar: Frame)
	local leftImg: ImageLabel = bar.LeftGradient.ProgressBarImage
	local rightImg: ImageLabel = bar.RightGradient.ProgressBarImage
	local leftGradient: UIGradient = leftImg.UIGradient
	local rightGradient: UIGradient = rightImg.UIGradient

	leftImg.ImageTransparency = 0
	rightImg.ImageTransparency = 0
	leftImg.Visible = false
	rightImg.Visible = false

	local progress = bar.Progress
	progress.Changed:Connect(function(value)
		local angle = math.clamp(value * 360, 0, 360)
		leftGradient.Rotation = math.clamp(angle, 180, 360)
		rightGradient.Rotation = math.clamp(angle, 0, 180)

		leftImg.Visible = leftGradient.Rotation > 180
		rightImg.Visible = rightGradient.Rotation > 0
	end)
end

--[[
	从 Prompt 读取 TranslationHelper 写入的占位符参数（与 TranslationManager 一致）

	@param prompt ProximityPrompt - 交互提示
	@return { any }? - 参数表；无参数为 nil
]]
local function _getPromptLocalizationArgs(prompt: ProximityPrompt): { any }?
	local maxIndex = prompt:GetAttribute("_maxIndex")
	if typeof(maxIndex) ~= "number" or maxIndex <= 0 then
		return nil
	end

	local args: { any } = {}
	for i = 1, maxIndex do
		local tableArg = prompt:GetAttribute("_arg_table" .. i)
		if tableArg ~= nil then
			args[i] = { tableArg }
		else
			args[i] = prompt:GetAttribute("_arg" .. i)
		end
	end
	return args
end

--[[
	解析 Prompt 动作文案的翻译键：优先 `_key`，回退 ActionText（未走 SetText 的旧写法）

	@param prompt ProximityPrompt - 交互提示
	@return string - 翻译键或原文；无文案为空串
]]
local function _getPromptActionKey(prompt: ProximityPrompt): string
	local keyAttr = prompt:GetAttribute("_key")
	if typeof(keyAttr) == "string" and keyAttr ~= "" then
		return keyAttr
	end
	local actionText = prompt.ActionText
	if typeof(actionText) == "string" then
		return actionText
	end
	return ""
end

--[[
	为单个 Custom ProximityPrompt 创建 BillboardGui 并绑定动效

	@param prompt ProximityPrompt - 交互提示
	@param inputType Enum.ProximityPromptInputType - 输入设备类型
	@param gui ScreenGui - 挂载容器
	@return () -> () - PromptHidden 时调用的清理函数
]]
local function _createPrompt(prompt: ProximityPrompt, inputType: Enum.ProximityPromptInputType, gui: ScreenGui): () -> ()
	local tweensForButtonHoldBegin: { Tween } = {}
	local tweensForButtonHoldEnd: { Tween } = {}
	local tweensForFadeOut: { Tween } = {}
	local tweensForFadeIn: { Tween } = {}
	local tweenInfoInFullDuration = TweenInfo.new(prompt.HoldDuration, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
	local tweenInfoFast = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local tweenInfoQuick = TweenInfo.new(0.06, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
	local tweenInfoInstant = TweenInfo.new(0, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)

	local promptUI: BillboardGui? = nil
	local promptTheme = prompt:GetAttribute("Theme")
	if typeof(promptTheme) == "string" and promptTheme ~= "" then
		local themedTemplate = _getPromptBillboardTemplate(promptTheme)
		if themedTemplate then
			promptUI = themedTemplate:Clone()
		end
	end

	if promptUI == nil then
		local defaultTemplate = _getPromptBillboardTemplate(PROMPT_DEFAULT_TEMPLATE_NAME)
		if defaultTemplate then
			promptUI = defaultTemplate:Clone()
		else
			-- Custom 无模板 = 完全无外观；回退引擎默认 Prompt，避免玩家以为交互丢失
			Log.warn("[CustomEUI] 缺少 Assets.BillBoard.Default，路径:", PROMPT_DEFAULT_PATH, "；回退 Style=Default")
			prompt.Style = Enum.ProximityPromptStyle.Default
			return function()
			end
		end
	end

	promptUI.Enabled = true

	local frame = promptUI.PromptFrame
	local inputFrame = frame.InputFrame
	local promTextBg: ImageLabel = promptUI.PromTextBg
	local actionText = promTextBg.ButtonText

	-- 必须用 `_key`：ActionText 在语言切换后已是译文（如 Gift），不能再当翻译键
	local actionKey = _getPromptActionKey(prompt)
	if actionKey == "" then
		promTextBg.Visible = false
		frame.Position = UDim2.new(0.5, 0, 0.5, 0)
	else
		promTextBg.Visible = true
		frame.Position = UDim2.new(0.25, 0, 0.5, 0)
		if TranslationHelper.CheckTranslateByKey(actionKey) then
			TranslationHelper.SetText(actionText, actionKey, _getPromptLocalizationArgs(prompt))
		else
			TranslationHelper.SetRawText(actionText, actionKey)
		end
	end

	local backgroundTransparency = frame.BackgroundTransparency
	local imageTransparency = frame.ImageTransparency
	frame.BackgroundTransparency = 1
	frame.ImageTransparency = 1

	table.insert(tweensForFadeOut, TweenService:Create(frame, tweenInfoFast, { BackgroundTransparency = 1, ImageTransparency = 1 }))
	table.insert(
		tweensForFadeIn,
		TweenService:Create(frame, tweenInfoFast, { BackgroundTransparency = backgroundTransparency, ImageTransparency = imageTransparency })
	)

	local function setupUIStrokeTweens(uiStroke: UIStroke)
		local transparency = uiStroke.Transparency
		uiStroke.Transparency = 1
		table.insert(tweensForButtonHoldBegin, TweenService:Create(uiStroke, tweenInfoFast, { Transparency = 1 }))
		table.insert(tweensForButtonHoldEnd, TweenService:Create(uiStroke, tweenInfoFast, { Transparency = transparency }))
		table.insert(tweensForFadeOut, TweenService:Create(uiStroke, tweenInfoFast, { Transparency = 1 }))
		table.insert(tweensForFadeIn, TweenService:Create(uiStroke, tweenInfoFast, { Transparency = transparency }))
	end

	local function setupGUIObjectTweens(guiObject: GuiObject)
		local guiObjectBackgroundTransparency = guiObject.BackgroundTransparency
		guiObject.BackgroundTransparency = 1
		table.insert(tweensForButtonHoldBegin, TweenService:Create(guiObject, tweenInfoFast, { BackgroundTransparency = 1 }))
		table.insert(
			tweensForButtonHoldEnd,
			TweenService:Create(guiObject, tweenInfoFast, { BackgroundTransparency = guiObjectBackgroundTransparency })
		)
		table.insert(tweensForFadeOut, TweenService:Create(guiObject, tweenInfoFast, { BackgroundTransparency = 1 }))
		table.insert(
			tweensForFadeIn,
			TweenService:Create(guiObject, tweenInfoFast, { BackgroundTransparency = guiObjectBackgroundTransparency })
		)
	end

	local function setupTextLabelTweens(textLabel: TextLabel)
		local textTransparency = textLabel.TextTransparency
		local textStrokeTransparency = textLabel.TextStrokeTransparency
		textLabel.TextTransparency = 1
		textLabel.TextStrokeTransparency = 1
		table.insert(
			tweensForButtonHoldBegin,
			TweenService:Create(textLabel, tweenInfoFast, { TextTransparency = 1, TextStrokeTransparency = 1 })
		)
		table.insert(
			tweensForButtonHoldEnd,
			TweenService:Create(textLabel, tweenInfoFast, { TextTransparency = textTransparency, TextStrokeTransparency = textStrokeTransparency })
		)
		table.insert(
			tweensForFadeOut,
			TweenService:Create(textLabel, tweenInfoFast, { TextTransparency = 1, TextStrokeTransparency = 1 })
		)
		table.insert(
			tweensForFadeIn,
			TweenService:Create(textLabel, tweenInfoFast, { TextTransparency = textTransparency, TextStrokeTransparency = textStrokeTransparency })
		)
	end

	local function setupImageLabelTweens(imageLabel: ImageLabel)
		local imageTransparency = imageLabel.ImageTransparency
		imageLabel.ImageTransparency = 1
		table.insert(tweensForButtonHoldBegin, TweenService:Create(imageLabel, tweenInfoFast, { ImageTransparency = 1 }))
		table.insert(tweensForButtonHoldEnd, TweenService:Create(imageLabel, tweenInfoFast, { ImageTransparency = imageTransparency }))
		table.insert(tweensForFadeOut, TweenService:Create(imageLabel, tweenInfoFast, { ImageTransparency = 1 }))
		table.insert(tweensForFadeIn, TweenService:Create(imageLabel, tweenInfoFast, { ImageTransparency = imageTransparency }))
	end

	local function setupUnexpectedChildTweens(child: Instance)
		if child:IsA("UIStroke") then
			setupUIStrokeTweens(child)
		elseif child:IsA("GuiObject") then
			setupGUIObjectTweens(child)
			if child:IsA("TextLabel") then
				setupTextLabelTweens(child)
			elseif child:IsA("ImageLabel") then
				setupImageLabelTweens(child)
			end
		end
		for _, grandChild in child:GetChildren() do
			setupUnexpectedChildTweens(grandChild)
		end
	end

	local expectedFrameChildren = { [inputFrame] = false }
	for _, child in frame:GetChildren() do
		if expectedFrameChildren[child] == nil then
			setupUnexpectedChildTweens(child)
		elseif expectedFrameChildren[child] == true then
			for _, grandChild in child:GetChildren() do
				setupUnexpectedChildTweens(grandChild)
			end
		end
	end

	local resizeableInputFrame = inputFrame.Frame
	local inputFrameScaler = inputFrame.Parent.UIScale
	local inputFrameScaleFactor = if inputType == Enum.ProximityPromptInputType.Touch then 1.6 else 1.33
	table.insert(tweensForButtonHoldBegin, TweenService:Create(inputFrameScaler, tweenInfoFast, { Scale = inputFrameScaleFactor }))
	table.insert(tweensForButtonHoldEnd, TweenService:Create(inputFrameScaler, tweenInfoFast, { Scale = 1 }))

	local buttonText = resizeableInputFrame.ButtonText
	local buttonImage = resizeableInputFrame.ButtonImage
	local inputIconParent = buttonImage.Parent
	local gamePadImg = inputIconParent:FindFirstChild("GamePadImg") :: GuiObject?
	local touchImg = inputIconParent:FindFirstChild("TouchImg") :: GuiObject?
	local pspImg = inputIconParent:FindFirstChild(PSP_IMG_NAME) :: GuiObject?

	local function setupButtonTextTweens()
		local textTransparency = buttonText.TextTransparency
		local textStrokeTransparency = buttonText.TextStrokeTransparency
		local textBackgroundTransparency = buttonText.BackgroundTransparency
		buttonText.BackgroundTransparency = 1
		buttonText.TextStrokeTransparency = 1
		buttonText.TextTransparency = 1
		table.insert(
			tweensForFadeOut,
			TweenService:Create(buttonText, tweenInfoQuick, { TextTransparency = 1, TextStrokeTransparency = 1, BackgroundTransparency = 1 })
		)
		table.insert(
			tweensForFadeIn,
			TweenService:Create(buttonText, tweenInfoQuick, {
				TextTransparency = textTransparency,
				TextStrokeTransparency = textStrokeTransparency,
				BackgroundTransparency = textBackgroundTransparency,
			})
		)
		for _, child in buttonText:GetChildren() do
			if child:IsA("UIStroke") then
				local transparency = child.Transparency
				table.insert(tweensForFadeOut, TweenService:Create(child, tweenInfoQuick, { Transparency = 1 }))
				table.insert(tweensForFadeIn, TweenService:Create(child, tweenInfoQuick, { Transparency = transparency }))
			end
		end
	end

	if inputType == Enum.ProximityPromptInputType.Gamepad then
		buttonText.Visible = false
		buttonImage.Visible = false
		if touchImg then
			touchImg.Visible = false
		end
		local usePspImg = _isPlayStationGamepad() and pspImg ~= nil
		if gamePadImg then
			gamePadImg.Visible = not usePspImg
		end
		if pspImg then
			pspImg.Visible = usePspImg
		end
	elseif inputType == Enum.ProximityPromptInputType.Touch then
		promptUI.Size = UDim2.new(0, 280 * (5 / 7), 0, 70 * (5 / 7))
		if gamePadImg then
			gamePadImg.Visible = false
		end
		if pspImg then
			pspImg.Visible = false
		end
		if touchImg then
			touchImg.Visible = true
		end
		buttonText.Visible = false
		buttonImage.Visible = false
	else
		buttonImage.Visible = true
		if gamePadImg then
			gamePadImg.Visible = false
		end
		if pspImg then
			pspImg.Visible = false
		end

		local buttonTextString = UserInputService:GetStringForKeyCode(prompt.KeyboardKeyCode)
		local buttonTextImage = KeyboardButtonImage[prompt.KeyboardKeyCode]
		if buttonTextImage == nil then
			buttonTextImage = KeyboardButtonIconMapping[buttonTextString]
		end
		if buttonTextImage == nil then
			local keyCodeMappedText = KeyCodeToTextMapping[prompt.KeyboardKeyCode]
			if keyCodeMappedText then
				buttonTextString = keyCodeMappedText
			end
		end

		if buttonTextImage then
			buttonText.Visible = false
		elseif buttonTextString ~= nil and buttonTextString ~= "" then
			if string.len(buttonTextString) > 2 then
				buttonText.TextSize = math.round(buttonText.TextSize * 6 / 7)
			end
			setupButtonTextTweens()
			buttonText.Text = buttonTextString
			buttonText.Visible = true
		else
			Log.warn(
				"[CustomEUI] ProximityPrompt 不支持的键位:",
				prompt.Name,
				tostring(prompt.KeyboardKeyCode)
			)
		end
	end

	if inputType == Enum.ProximityPromptInputType.Touch or prompt.ClickablePrompt then
		local buttonDown = false

		--[[
			绑定可点击区域：按下/抬起等同触发 ProximityPrompt 的 InputHoldBegin/End
			@param button GuiButton - 可点击按钮（Default/TextButton 或 PromTextBg/TextButton）
		]]
		local function bindClickablePromptButton(button: GuiButton)
			button.InputBegan:Connect(function(input)
				if
					(input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1)
					and input.UserInputState ~= Enum.UserInputState.Change
				then
					prompt:InputHoldBegin()
					buttonDown = true
				end
			end)
			button.InputEnded:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
					if buttonDown then
						buttonDown = false
						prompt:InputHoldEnd()
					end
				end
			end)
		end

		bindClickablePromptButton(promptUI.TextButton)
		local promTextBgButton = promTextBg:FindFirstChild("TextButton")
		if promTextBgButton and promTextBgButton:IsA("GuiButton") then
			bindClickablePromptButton(promTextBgButton)
		end
		promptUI.Active = true
	end

	if prompt.HoldDuration > 0 then
		local circleBar = resizeableInputFrame.ProgressBar
		_setUpCircularProgressBar(circleBar)
		table.insert(tweensForButtonHoldBegin, TweenService:Create(circleBar.Progress, tweenInfoInFullDuration, { Value = 1 }))
		table.insert(tweensForButtonHoldEnd, TweenService:Create(circleBar.Progress, tweenInfoInstant, { Value = 0 }))
	end

	local holdBeganConnection: RBXScriptConnection? = nil
	local holdEndedConnection: RBXScriptConnection? = nil
	local triggeredConnection: RBXScriptConnection? = nil
	local triggerEndedConnection: RBXScriptConnection? = nil

	if prompt.HoldDuration > 0 then
		holdBeganConnection = prompt.PromptButtonHoldBegan:Connect(function()
			for _, tween in tweensForButtonHoldBegin do
				tween:Play()
			end
		end)
		holdEndedConnection = prompt.PromptButtonHoldEnded:Connect(function()
			for _, tween in tweensForButtonHoldEnd do
				tween:Play()
			end
		end)
	end

	triggeredConnection = AddListen.AddProximityPrompt(prompt, function()
		for _, tween in tweensForFadeOut do
			tween:Play()
		end
		local uiScale = frame:FindFirstChild("UIScale")
		if uiScale and uiScale:IsA("UIScale") then
			TweenService:Create(uiScale, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0 }):Play()
		end
	end)

	triggerEndedConnection = prompt.TriggerEnded:Connect(function()
		for _, tween in tweensForFadeIn do
			tween:Play()
		end
		if UIanima and UIanima.UIScaleOut then
			UIanima.UIScaleOut(frame, 0.18)
		end
	end)

	promptUI.Adornee = prompt.Parent
	local highlightTarget = if prompt.Parent then prompt.Parent.Parent else nil
	_setHighlightAdornee(highlightTarget)
	promptUI.Parent = gui

	for _, tween in tweensForFadeIn do
		tween:Play()
	end
	if UIanima and UIanima.UIScaleOut then
		UIanima.UIScaleOut(frame, 0.18)
	end

	nowProximityPrompt = promptUI

	return function()
		if holdBeganConnection then
			holdBeganConnection:Disconnect()
		end
		if holdEndedConnection then
			holdEndedConnection:Disconnect()
		end
		if triggeredConnection then
			triggeredConnection:Disconnect()
		end
		if triggerEndedConnection then
			triggerEndedConnection:Disconnect()
		end
		_setHighlightAdornee(nil)
		promptUI.Parent = nil
		promptUI:Destroy()
		nowProximityPrompt = nil
	end
end

local outlineTransparency = if ProximityPromptHighLight then ProximityPromptHighLight.OutlineTransparency else 1
local _cameraTypeConn: RBXScriptConnection? = nil

--[[
	弹窗 / 脚本相机时隐藏当前 E 提示（骑扫帚飞行不隐藏）

	@return nil - 无返回值
]]
local function _updatePromptVisibility()
	if not nowProximityPrompt then
		return
	end

	local isBlocked = false
	local isPopShow = LocalPlayer:FindFirstChild("是否弹窗打开中")
	if isPopShow and isPopShow:IsA("BoolValue") and isPopShow.Value then
		isBlocked = true
	end
	local currentCamera = workspace.CurrentCamera
	if currentCamera and currentCamera.CameraType == Enum.CameraType.Scriptable then
		isBlocked = true
	end

	if isBlocked then
		-- 不得把哨兵 0.001 写入 MaxDis，否则恢复后永久不可见（对齐 UIMgr.UpdateWorldUi）
		if nowProximityPrompt:GetAttribute(MARK_ATTR) == nil then
			local current = nowProximityPrompt.MaxDistance
			if not _isBillboardHiddenDistance(current) then
				nowProximityPrompt:SetAttribute(MARK_ATTR, current)
			end
		end
		nowProximityPrompt.MaxDistance = BILLBOARD_HIDDEN_MAX_DISTANCE
		if ProximityPromptHighLight then
			ProximityPromptHighLight.OutlineTransparency = 1
		end
	else
		local maxDistance = nowProximityPrompt:GetAttribute(MARK_ATTR)
		if typeof(maxDistance) == "number" and not _isBillboardHiddenDistance(maxDistance) then
			nowProximityPrompt.MaxDistance = maxDistance
		elseif _isBillboardHiddenDistance(nowProximityPrompt.MaxDistance) then
			nowProximityPrompt:SetAttribute(MARK_ATTR, nil)
			nowProximityPrompt.MaxDistance = math.huge
		end
		if ProximityPromptHighLight then
			ProximityPromptHighLight.OutlineTransparency = outlineTransparency
		end
	end
end

--[[
	绑定 CurrentCamera.CameraType；相机实例替换时重绑

	@return nil - 无返回值
]]
local function _bindCameraTypeListener()
	if _cameraTypeConn then
		_cameraTypeConn:Disconnect()
		_cameraTypeConn = nil
	end
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	_cameraTypeConn = cam:GetPropertyChangedSignal("CameraType"):Connect(function()
		_updatePromptVisibility()
	end)
end

ProximityPromptService.PromptShown:Connect(function(prompt: ProximityPrompt, inputType: Enum.ProximityPromptInputType)
	if prompt.Style == Enum.ProximityPromptStyle.Default then
		return
	end

	local gui = _getScreenGui()
	local cleanup = _createPrompt(prompt, inputType, gui)
	_updatePromptVisibility()
	prompt.PromptHidden:Wait()
	cleanup()
end)

local isPopShowValue = InsMgr.GetIns("是否弹窗打开中", "BoolValue", LocalPlayer) :: BoolValue

AddListen.NumValueAdd(isPopShowValue, function()
	_updatePromptVisibility()
	local touchGui = PlayerGui:FindFirstChild("TouchGui")
	if touchGui and touchGui:IsA("ScreenGui") then
		touchGui.Enabled = not isPopShowValue.Value
	end
end)

_bindCameraTypeListener()
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	_bindCameraTypeListener()
	_updatePromptVisibility()
end)
