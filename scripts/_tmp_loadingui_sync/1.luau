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
