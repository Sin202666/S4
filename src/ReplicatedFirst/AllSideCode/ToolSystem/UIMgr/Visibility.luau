--[[
	Module: UIMgr/Visibility
	Description: UIMgr 子模块 — 主界面显隐、ScreenGui 启停、模糊/景深、弹窗批量关闭、世界 UI 与弹窗态（由 init 合并导出至 Utils.UIMgr）
	Author: 林奥宇
	Created: 2026-08-18
	Last Modified: 2026-10-16

	功能：
	- SetMainUIVisible：主界面 / SystemGui 显隐（可按弹窗标记自动判断）
	- HideGui / ShowGui：宠物相关 UI
	- HideScreenGui / ShowScreenGui：整屏启停
	- UpdateBlurVisible / CloseBlur / VisibleDepth：Lighting 模糊与景深
	- HideOtherUI / HideAllBut / RecoverHideUI：弹窗批量关闭与恢复
	- RefreshPopShowState：扫描「是否是弹窗」刷新 LocalPlayer「是否弹窗打开中」，并 UpdateWorldUi
	- UpdateWorldUi：弹窗 / Scriptable 相机时收起 Tag=BillboardGui 与 ProximityPrompt
	- RefreshWorldUiAfterScriptableCamera：运镜交还后补刷世界 UI（等退出 Scriptable）

	与 init：业务只调 Utils.UIMgr，不要直接 require 本文件。
	与 CustomEUI：本模块写「是否弹窗打开中」；CustomEUI 监听该值收起 E 提示。

	加载方式：
		local Utils = require(game.ReplicatedFirst.AllSideCode.UtilsSystem)
		local UIMgr = Utils.UIMgr

	示例：
		UIMgr.SetMainUIVisible()
		UIMgr.UpdateBlurVisible()
		UIMgr.RefreshPopShowState()
		UIMgr.HideAllBut("ScreenGui")
		UIMgr.RecoverHideUI()
]]

local Utils = require(game.ReplicatedFirst.AllSideCode.UtilsSystem)
local Players = Utils.Players
local Lighting = Utils.Lighting
local Log = Utils.Log
local InsMgr = Utils.InsMgr
local CollectionService = Utils.CollectionService
local RunService = Utils.RunService
local ProximityPromptService = game:GetService("ProximityPromptService")

local Visibility = {}

local PET_UI_LIST = {
	"抽宠物弹窗",
}

local IGNORE_UI_NAMES = {
	["Mian"] = true,
	["Main"] = true,
	["详情"] = true,
	["UIAnima"] = true,
}

local BLUR_EFFECT_NAME = "UI模糊"
local DEPTH_EFFECT_NAME = "景深"
local SCREEN_GUI_NAME = "ScreenGui"
local SYSTEM_GUI_NAME = "SystemGui"
local REFRESH_UI_MODULE_NAME = "刷新UI"
local HIDE_ALL_BUT_ATTR = "UIMgrPrevEnabled"
local POP_MARKER_NAME = "是否是弹窗"
local POP_SHOW_STATE_VALUE_NAME = "是否弹窗打开中"
-- 与 CustomEUI / RP18 一致：弹窗时收起世界 Billboard 与 Prompt
local BILLBOARD_LISTEN_TAG = "BillboardGui"
local BILLBOARD_MAX_DIS_ATTR = "MaxDis"
local BILLBOARD_HIDDEN_MAX_DISTANCE = 0.001

local UI_ELEMENT_NAMES = {
	BACKGROUND_BLUR = "背景模糊",
	HIDE_MAIN_UI = "隐藏主界面",
	MAIN = "Main",
}

local _cameraTypeConn: RBXScriptConnection? = nil
local _currentCameraConn: RBXScriptConnection? = nil
local _worldUiListenersBound = false

--[[
	安全 require UI 模块并调用 closeUi（动态挂载的「刷新UI」ModuleScript，无法静态顶 require）
	@param refreshUI ModuleScript - Frame 下的刷新UI 脚本
	@return () - 无返回值
]]
local function _requireCloseUi(refreshUI: ModuleScript)
	local success, uiModel = pcall(require, refreshUI)
	if not success then
		Log.warn("[UIMgr] closeUi require 失败", refreshUI:GetFullName(), uiModel)
		return
	end
	if uiModel and type(uiModel.closeUi) == "function" then
		uiModel:closeUi()
	end
end

--[[
	获取本地玩家的 PlayerGui
	@return PlayerGui? - 本地玩家 GUI 容器，玩家未就绪时 nil
]]
local function _getLocalPlayerGui(): PlayerGui?
	local localPlayer = Players.LocalPlayer
	if not localPlayer then
		return nil
	end
	local playerGui = localPlayer:FindFirstChild("PlayerGui")
	if playerGui and playerGui:IsA("PlayerGui") then
		return playerGui
	end
	return nil
end

--[[
	获取 ScreenGui 实例
	@return ScreenGui? - 主 ScreenGui，不存在时返回 nil
]]
local function _getScreenGui(): ScreenGui?
	local playerGui = _getLocalPlayerGui()
	if not playerGui then
		return nil
	end
	local screenGui = playerGui:FindFirstChild(SCREEN_GUI_NAME)
	if screenGui and screenGui:IsA("ScreenGui") then
		return screenGui
	end
	return nil
end

--[[
	设置宠物相关 UI 可见性
	@param visible boolean - 是否显示
	@return () - 无返回值
]]
local function _setPetUIVisible(visible: boolean): ()
	local screenGui = _getScreenGui()
	if not screenGui then
		return
	end
	for _, uiName in pairs(PET_UI_LIST) do
		local ui = screenGui:FindFirstChild(uiName)
		if ui and ui:IsA("Frame") then
			ui.Visible = visible
		end
	end
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
	当前是否应隐藏世界 BillboardGui / ProximityPrompt（弹窗打开或 Scriptable 相机）
	@return boolean - true 应隐藏
]]
local function _shouldHideWorldUi(): boolean
	local localPlayer = Players.LocalPlayer
	if localPlayer then
		local isPopShow = localPlayer:FindFirstChild(POP_SHOW_STATE_VALUE_NAME)
		if isPopShow and isPopShow:IsA("BoolValue") and isPopShow.Value == true then
			return true
		end
	end

	local currentCamera = workspace.CurrentCamera
	if currentCamera and currentCamera.CameraType == Enum.CameraType.Scriptable then
		return true
	end

	return false
end

--[[
	绑定 CurrentCamera.CameraType；相机实例替换时重绑（仅客户端）
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
		Visibility.UpdateWorldUi()
	end)
end

--[[
	确保世界 UI 相机监听已绑定（幂等；服务端早退）
	@return nil - 无返回值
]]
local function _ensureWorldUiListeners()
	if _worldUiListenersBound or RunService:IsServer() then
		return
	end
	_worldUiListenersBound = true
	_bindCameraTypeListener()
	_currentCameraConn = workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		_bindCameraTypeListener()
		Visibility.UpdateWorldUi()
	end)
end

--[[
	设置主界面可见性
	@param setVisible boolean? - 是否显示（可选，nil 时自动判断）
	@return () - 无返回值
]]
function Visibility.SetMainUIVisible(setVisible: boolean?): ()
	local ScreenGui = _getScreenGui()
	if not ScreenGui then
		return
	end

	local isShow = true
	if setVisible ~= nil then
		isShow = setVisible
	else
		-- 自动判断：检查是否有需要隐藏主界面的窗口
		for _, child in pairs(ScreenGui:GetChildren()) do
			local v: Frame? = child:IsA("Frame") and child :: Frame? or nil
			if v and v.Visible == true then
				local backgroundBlur = v:FindFirstChild(UI_ELEMENT_NAMES.BACKGROUND_BLUR)
				local hideMainUI = v:FindFirstChild(UI_ELEMENT_NAMES.HIDE_MAIN_UI)

				if (backgroundBlur and backgroundBlur:IsA("BoolValue") and backgroundBlur.Value == true) or
				   (hideMainUI and hideMainUI:IsA("BoolValue") and hideMainUI.Value == true) then
					isShow = false
					break
				end
			end
		end
	end

	-- 设置主界面可见性
	local Main: Frame? = ScreenGui:FindFirstChild(UI_ELEMENT_NAMES.MAIN) :: Frame?
	if Main then
		Main.Visible = isShow
	end

	-- 设置系统 GUI 启用状态
	local playerGui = _getLocalPlayerGui()
	if playerGui then
		local SystemGui: ScreenGui? = playerGui:FindFirstChild(SYSTEM_GUI_NAME) :: ScreenGui?
		if SystemGui then
			SystemGui.Enabled = isShow
		end
	end
end

--[[
	隐藏宠物相关 UI
	@return () - 无返回值
]]
function Visibility.HideGui(): ()
	_setPetUIVisible(false)
end

--[[
	显示宠物相关 UI
	@return () - 无返回值
]]
function Visibility.ShowGui(): ()
	_setPetUIVisible(true)
end

--[[
	禁用整个 ScreenGui
	@return () - 无返回值
]]
function Visibility.HideScreenGui(): ()
	local screenGui = _getScreenGui()
	if screenGui then
		screenGui.Enabled = false
	end
end

--[[
	启用整个 ScreenGui
	@return () - 无返回值
]]
function Visibility.ShowScreenGui(): ()
	local screenGui = _getScreenGui()
	if screenGui then
		screenGui.Enabled = true
	end
end

--[[
	根据 ScreenGui 状态与子 UI「背景模糊」标记更新 Lighting 模糊效果；
	结束后刷新弹窗态（是否弹窗打开中）与世界 UI，供 CustomEUI / Prompt 联动。
	@return () - 无返回值
]]
function Visibility.UpdateBlurVisible(): ()
	local uiBlurInstance = Lighting:FindFirstChild(BLUR_EFFECT_NAME)
	if not uiBlurInstance or not uiBlurInstance:IsA("BlurEffect") then
		uiBlurInstance = Instance.new("BlurEffect")
		uiBlurInstance.Name = BLUR_EFFECT_NAME
		uiBlurInstance.Parent = Lighting
	end
	local uiBlur = uiBlurInstance :: BlurEffect

	local screenGui = _getScreenGui()
	if not screenGui then
		Visibility.RefreshPopShowState()
		return
	end

	if not screenGui.Enabled then
		uiBlur.Enabled = false
		Visibility.RefreshPopShowState()
		return
	end

	local blurOn = false
	for _, child in pairs(screenGui:GetChildren()) do
		if child:IsA("Frame") and child.Visible then
			local blurValue = child:FindFirstChild(UI_ELEMENT_NAMES.BACKGROUND_BLUR)
			if blurValue and blurValue:IsA("BoolValue") and blurValue.Value then
				blurOn = true
				break
			end
		end
	end
	uiBlur.Enabled = blurOn
	Visibility.RefreshPopShowState()
end

--[[
	隐藏或恢复世界空间 BillboardGui（Tag=BillboardGui）与全部 ProximityPrompt。
	Billboard 用 MaxDistance 哨兵收起；Prompt 用 ProximityPromptService.Enabled。
	不得把 0.001 哨兵值写入 MaxDis，否则恢复后永久不可见。

	@return () - 无返回值
]]
function Visibility.UpdateWorldUi(): ()
	if RunService:IsServer() then
		return
	end
	_ensureWorldUiListeners()

	local shouldHide = _shouldHideWorldUi()

	for _, inst in CollectionService:GetTagged(BILLBOARD_LISTEN_TAG) do
		if inst:IsA("BillboardGui") then
			local billboard = inst :: BillboardGui
			if shouldHide then
				if billboard:GetAttribute(BILLBOARD_MAX_DIS_ATTR) == nil then
					local current = billboard.MaxDistance
					if not _isBillboardHiddenDistance(current) then
						billboard:SetAttribute(BILLBOARD_MAX_DIS_ATTR, current)
					end
				end
				billboard.MaxDistance = BILLBOARD_HIDDEN_MAX_DISTANCE
			else
				local maxDis = billboard:GetAttribute(BILLBOARD_MAX_DIS_ATTR)
				if typeof(maxDis) == "number" and not _isBillboardHiddenDistance(maxDis) then
					billboard.MaxDistance = maxDis
				elseif _isBillboardHiddenDistance(billboard.MaxDistance) then
					billboard:SetAttribute(BILLBOARD_MAX_DIS_ATTR, nil)
					billboard.MaxDistance = math.huge
				end
			end
		end
	end

	ProximityPromptService.Enabled = not shouldHide
end

--[[
	运镜交还后刷新世界 Billboard / Prompt。
	DisableCamera 后常有数帧 Scriptable handoff；仅 defer 一次可能把 Billboard 卡在哨兵 MaxDistance。

	@param maxWaitFrames number? - 最多等待非 Scriptable 的帧数；默认 12
	@return () - 无返回值
]]
function Visibility.RefreshWorldUiAfterScriptableCamera(maxWaitFrames: number?): ()
	if RunService:IsServer() then
		return
	end
	local waitFrames = math.max(1, math.floor(tonumber(maxWaitFrames) or 12))
	local function refresh()
		Visibility.UpdateWorldUi()
	end
	refresh()
	task.defer(refresh)
	task.spawn(function()
		local camera = workspace.CurrentCamera
		for _ = 1, waitFrames do
			RunService.Heartbeat:Wait()
			camera = workspace.CurrentCamera
			if camera and camera.CameraType ~= Enum.CameraType.Scriptable then
				refresh()
				RunService.Heartbeat:Wait()
				refresh()
				return
			end
		end
		refresh()
	end)
end

--[[
	扫描 PlayerGui 下全部 ScreenGui，刷新 LocalPlayer「是否弹窗打开中」，并同步世界 Billboard / Prompt 显隐。
	标记名「是否是弹窗」：可挂在 ScreenGui 或直接子 Frame 上（BoolValue）。

	@return () - 无返回值
]]
function Visibility.RefreshPopShowState(): ()
	if RunService:IsServer() then
		return
	end

	local localPlayer = Players.LocalPlayer
	if not localPlayer then
		return
	end

	local playerGui = localPlayer:FindFirstChild("PlayerGui")
	if not playerGui or not playerGui:IsA("PlayerGui") then
		return
	end

	local isPopShowValue = InsMgr.GetIns(POP_SHOW_STATE_VALUE_NAME, "BoolValue", localPlayer) :: BoolValue
	local hasPopShow = false

	for _, child in pairs(playerGui:GetChildren()) do
		if child:IsA("ScreenGui") then
			local screenGui = child :: ScreenGui
			local isPopMarker = screenGui:FindFirstChild(POP_MARKER_NAME)
			if isPopMarker and isPopMarker:IsA("BoolValue") then
				if isPopMarker.Value == true and screenGui.Enabled == true then
					hasPopShow = true
					break
				end
			elseif screenGui.Enabled == true then
				for _, frameChild in pairs(screenGui:GetChildren()) do
					if frameChild:IsA("Frame") then
						local frame = frameChild :: Frame
						local isFramePopMarker = frame:FindFirstChild(POP_MARKER_NAME)
						if
							isFramePopMarker
							and isFramePopMarker:IsA("BoolValue")
							and isFramePopMarker.Value == true
							and frame.Visible == true
						then
							hasPopShow = true
							break
						end
					end
				end
				if hasPopShow then
					break
				end
			end
		end
	end

	isPopShowValue.Value = hasPopShow
	Visibility.UpdateWorldUi()
end

--[[
	强制关闭 Lighting UI 模糊效果（不扫描 ScreenGui；关闭弹窗后若需按 UI 状态恢复请调 UpdateBlurVisible）
	@return () - 无返回值
]]
function Visibility.CloseBlur(): ()
	local uiBlurInstance = Lighting:FindFirstChild(BLUR_EFFECT_NAME)
	if uiBlurInstance and uiBlurInstance:IsA("BlurEffect") then
		(uiBlurInstance :: BlurEffect).Enabled = false
	end
end

--[[
	设置景深效果可见性
	@param visible boolean - 是否启用景深
	@return () - 无返回值
]]
function Visibility.VisibleDepth(visible: boolean): ()
	local depthOfFieldInstance = Lighting:FindFirstChild(DEPTH_EFFECT_NAME)
	if not depthOfFieldInstance or not depthOfFieldInstance:IsA("DepthOfFieldEffect") then
		return
	end
	(depthOfFieldInstance :: DepthOfFieldEffect).Enabled = visible
end

--[[
	关闭除忽略列表外的其他可见弹窗（通过各 UI 的「刷新UI」模块 closeUi）
	@param player Player - 目标玩家
	@return () - 无返回值
]]
function Visibility.HideOtherUI(player: Player): ()
	local playerGui = player:FindFirstChild("PlayerGui")
	if not playerGui or not playerGui:IsA("PlayerGui") then
		return
	end

	local screenGui = playerGui:FindFirstChild(SCREEN_GUI_NAME)
	if not screenGui or not screenGui:IsA("ScreenGui") then
		return
	end

	for _, child in pairs(screenGui:GetChildren()) do
		if child:IsA("Frame") and child.Visible and not IGNORE_UI_NAMES[child.Name] then
			local refreshUI = child:FindFirstChild(REFRESH_UI_MODULE_NAME)
			if refreshUI and refreshUI:IsA("ModuleScript") then
				_requireCloseUi(refreshUI :: ModuleScript)
			end
		end
	end
end

--[[
	隐藏全部 ScreenGui 除了 _unHideUI
	@param _unHideUI string? - 保留显示的 ScreenGui 名称；nil 时隐藏全部
	@return () - 无返回值
]]
function Visibility.HideAllBut(_unHideUI: string?): ()
	local localPlayer = Players.LocalPlayer
	if not localPlayer then
		return
	end

	local playerGui = localPlayer:FindFirstChild("PlayerGui")
	if not playerGui or not playerGui:IsA("PlayerGui") then
		return
	end

	for _, v in playerGui:GetChildren() do
		if v:IsA("ScreenGui") and v.Name ~= _unHideUI and v.Enabled == true then
			v:SetAttribute(HIDE_ALL_BUT_ATTR, true)
			v.Enabled = false
		end
	end
end

--[[
	恢复 HideAllBut 之前隐藏的 ScreenGui
	@return () - 无返回值
]]
function Visibility.RecoverHideUI(): ()
	local localPlayer = Players.LocalPlayer
	if not localPlayer then
		return
	end

	local playerGui = localPlayer:FindFirstChild("PlayerGui")
	if not playerGui or not playerGui:IsA("PlayerGui") then
		return
	end

	for _, v in playerGui:GetChildren() do
		if v:IsA("ScreenGui") then
			local enabled: boolean? = v:GetAttribute(HIDE_ALL_BUT_ATTR)
			if enabled then
				v.Enabled = enabled
				v:SetAttribute(HIDE_ALL_BUT_ATTR, nil)
			end
		end
	end
end

return Visibility
