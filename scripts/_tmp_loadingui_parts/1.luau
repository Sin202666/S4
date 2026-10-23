local function _playBgScroll(canvasGroup: CanvasGroup): Tween?
	local bg = canvasGroup:FindFirstChild("Bg")
	local pattern = bg and bg:FindFirstChild(BG_PATTERN_NAME) :: ImageLabel?
	if not pattern then
		return nil
	end

	local tileX = pattern.TileSize.X.Offset
	local tileY = pattern.TileSize.Y.Offset
	pattern.Position = UDim2.fromOffset(-tileX, -tileY)
	local scrollTween = TweenService:Create(
		pattern,
		TweenInfo.new(BG_SCROLL_SEC, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1),
		{ Position = UDim2.fromOffset(0, 0) }
	)
	scrollTween:Play()
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
