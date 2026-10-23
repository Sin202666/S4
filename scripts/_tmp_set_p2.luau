local s = game.ServerStorage._LoadingUISrc['p2']
s.Value = [=[	scrollTween:Play()
	return scrollTween
end

--[[
	加载期间仅保留 PreloadGui，其他 ScreenGui 暂存 Enabled 到 Attribute
	@param localPlayer Player - 本地玩家
	@param loadEndRef { boolean } - 关闭标志引用，true 时退出循环
	@return nil - 无返回值
]]
local function _runGuiIsolationLoop(localPlayer: Player, loadEndRef: { boolean })
	local currentCamera = workspace.CurrentCamera

	while true do
		if loadEndRef[1] then
			currentCamera.CameraType = Enum.CameraType.Custom
			return
		end

		local playerGui = localPlayer:FindFirstChild("PlayerGui") :: PlayerGui?
		if playerGui then
			for _, child in playerGui:GetChildren() do
				if child:IsA("ScreenGui") then
					if child.Name == PRELOAD_GUI_SHOW_NAME and not child.Enabled then
						child:SetAttribute("Enabled", false)
						child.Enabled = true
					elseif child.Name ~= PRELOAD_GUI_SHOW_NAME and child.Enabled then
						child:SetAttribute("Enabled", true)
						child.Enabled = false
					end
				end
			end
		end

		if loadEndRef[1] then
			currentCamera.CameraType = Enum.CameraType.Custom
			return
		end

		task.wait()
	end
end

--[[
	恢复 PlayerGui 内被隔离的 ScreenGui Enabled 状态
	@param localPlayer Player - 本地玩家
	@return nil - 无返回值
]]
local function _restorePlayerGui(localPlayer: Player)
	local playerGui = localPlayer:FindFirstChild("PlayerGui") :: PlayerGui?
	if not playerGui then
		return
	end

	for _, child in playerGui:GetChildren() do
		if child:IsA("ScreenGui") then
			local enabled = child:GetAttribute("Enabled")
			if enabled ~= nil then
				child.Enabled = enabled
				child:SetAttribute("Enabled", nil)
			end
		end
	end
end

--[[
	解析跳过文案标签（兼容旧 Frame 嵌套与新扁平结构）
	@param buttonFrame Frame - 跳过按钮根
	@return TextLabel? - 文案节点
]]
local function _findSkipLabel(buttonFrame: Frame): TextLabel?
	local direct = buttonFrame:FindFirstChild("跳过")
	if direct and direct:IsA("TextLabel") then
		return direct
	end
	local nested = buttonFrame:FindFirstChild("Frame")
	local label = nested and nested:FindFirstChild("跳过")
	if label and label:IsA("TextLabel") then
		return label
	end
	return nil
end

-- ============================================================================
-- 公共 API
-- ============================================================================

--[[
	启动加载界面全流程（资源完成监听、圆点跳动、跳过、关闭动画）
	@param config StartConfig - 界面实例、计数器与完成回调
	@return nil - 无返回值
]]
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
]=]
return #s.Value
