function LoadingUI.Start(config: StartConfig)
	local preloadGui = config.preloadGui
	local canvasGroup = preloadGui.CanvasGroup :: CanvasGroup
	local preloadFrame = canvasGroup.Frame :: Frame
	local buttonFrame = preloadFrame["跳过按钮"] :: Frame
	local blackBg = preloadGui["半透明屏蔽层"] :: ImageButton
	local localPlayer = Players.LocalPlayer :: Player

	local progressFrame = preloadFrame:FindFirstChild("进度条")
	if progressFrame and progressFrame:IsA("GuiObject") then
		progressFrame.Visible = false
	end

	local loadingLabel = preloadFrame:FindFirstChild("Loading")
	if loadingLabel and loadingLabel:IsA("GuiObject") then
		loadingLabel.Visible = false
	end

	preloadGui.Name = PRELOAD_GUI_SHOW_NAME
	buttonFrame.Visible = false
	canvasGroup.GroupTransparency = 0
	preloadGui.Enabled = true

	local playerGui = localPlayer:WaitForChild("PlayerGui") :: PlayerGui
	preloadGui.Parent = playerGui

	_initLogoFrame(preloadFrame)

	if config.teleportCfg then
		_applyTeleportSkin(canvasGroup, config.teleportCfg)
	end

	local skipLabel = _findSkipLabel(buttonFrame)
	task.defer(function()
		if skipLabel then
			TranslationHelper.SetText(skipLabel, "跳过")
		end
	end)

	local loadEndRef = { false }
	task.spawn(function()
		_runGuiIsolationLoop(localPlayer, loadEndRef)
	end)

	local progressConn: RBXScriptConnection? = nil
	local skipShowConn: RBXScriptConnection? = nil
	local skipInputConn: RBXScriptConnection? = nil
	local iconLoopTweens: { Tween } = {}
	local bgScrollTween = _playBgScroll(canvasGroup)
	local skipShown = false

	--[[
		预加载满 5 秒后显示纯文字跳过
		@return nil - 无返回值
	]]
	local function _onSkipThresholdReached()
		if skipShown or not preloadGui.Parent then
			return
		end
		skipShown = true

		if skipShowConn then
			skipShowConn:Disconnect()
			skipShowConn = nil
		end

		buttonFrame.Visible = true
		if skipLabel then
			skipLabel.TextTransparency = 1
			local stroke = skipLabel:FindFirstChildOfClass("UIStroke")
			local strokeTween: Tween? = nil
			if stroke then
				stroke.Transparency = 1
				strokeTween = TweenService:Create(stroke, TweenInfo.new(CLOSE_FADE_SEC), { Transparency = 0 })
			end
			local textTween = TweenService:Create(
				skipLabel,
				TweenInfo.new(CLOSE_FADE_SEC, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ TextTransparency = 0 }
			)
			textTween:Play()
			if strokeTween then
				strokeTween:Play()
			end
		end
	end

	--[[
		关闭加载界面：断开事件、淡出、恢复 GUI、标记 IsCloseLoading
		@return nil - 无返回值
	]]
	local function closeUI()
		if not progressConn then
			return
		end

		if skipInputConn then
			skipInputConn:Disconnect()
			skipInputConn = nil
		end
		if skipShowConn then
			skipShowConn:Disconnect()
			skipShowConn = nil
		end
		progressConn:Disconnect()
		progressConn = nil

		task.spawn(function()
			SoundService:WaitForChild("UI"):WaitForChild("loading加载完毕"):Play()
		end)

		local closeTween = TweenService:Create(canvasGroup, TweenInfo.new(CLOSE_FADE_SEC), {
			GroupTransparency = 1,
		})
		closeTween:Play()
		closeTween.Completed:Wait()

		loadEndRef[1] = true
		_restorePlayerGui(localPlayer)

		local blackBgTween = TweenService:Create(blackBg, TweenInfo.new(CLOSE_FADE_SEC), {
			BackgroundTransparency = 1,
		})
		blackBgTween:Play()
		blackBgTween.Completed:Wait()

		for _, tween in iconLoopTweens do
			tween:Cancel()
		end
		table.clear(iconLoopTweens)
		if bgScrollTween then
			bgScrollTween:Cancel()
			bgScrollTween = nil
		end

		preloadGui.Enabled = false
		preloadGui:Destroy()
		config.isCloseLoading.Value = true

		if config.onFinished then
			config.onFinished()
		end
	end

	local function playSkipSound()
		task.spawn(function()
			SoundService:WaitForChild("UI"):WaitForChild("UI_跳过加载点击"):Play()
		end)
	end

	skipInputConn = UserInputService.InputEnded:Connect(function(input: InputObject, gameProcessed: boolean)
		if gameProcessed then
			return
		end
		if input.KeyCode == Enum.KeyCode.ButtonX then
			closeUI()
			playSkipSound()
		end
	end)

	task.defer(function()
		iconLoopTweens = _playLogoIntro(preloadFrame)

		progressConn = RunService.Heartbeat:Connect(function()
			if config.resTotal.Value <= 0 then
				return
			end
			if config.resLoaded.Value >= config.resTotal.Value then
				closeUI()
			end
		end)

		local skipButton = buttonFrame:FindFirstChild("Button")
		if skipButton and skipButton:IsA("GuiButton") then
			skipButton.MouseButton1Click:Once(function()
				closeUI()
				playSkipSound()
			end)
		end
	end)

	skipShowConn = config.resLoadTime.Changed:Connect(function(elapsed: number)
		if elapsed > SKIP_SHOW_TIME_SEC then
			_onSkipThresholdReached()
		end
	end)

	if config.resLoadTime.Value > SKIP_SHOW_TIME_SEC then
		_onSkipThresholdReached()
	end
end

