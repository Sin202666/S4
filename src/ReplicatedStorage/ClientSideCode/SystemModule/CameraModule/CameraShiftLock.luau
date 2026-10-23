--[[
	Module: CameraModule.CameraShiftLock
	Description: ShiftLock 属性同步（由 CameraModule/init 调用，业务勿直接 require）
	Author: 林奥宇
	Created: 2026-08-18
	Last Modified: 2026-10-14

	功能：
	- MouseBehavior.LockCenter → LocalPlayer.IsShiftLocked（仅值变化时写入）
	- 同步 CameraMode.SyncEngineShiftLock

	玩家锁镜头开关已关闭（StarterPlayer.EnableMouseLockOption = false），本模块不再重绑开关键；
	属性同步保留，供 Animate / 技能朝向等读取 IsShiftLocked。
]]

local CameraMode = require(script.Parent.CameraMode)
local Utils = require(game.ReplicatedFirst.AllSideCode.UtilsSystem)
local Players = Utils.Players
local UserInputService = Utils.UserInputService

local CameraShiftLock = {}

local SHIFT_LOCK_ATTRIBUTE = "IsShiftLocked"

local _shiftLockConn: RBXScriptConnection? = nil

--[[
	将当前鼠标锁定状态同步到 LocalPlayer.IsShiftLocked（仅值变化时写入）
	@return () - 无返回值
]]
local function _syncShiftLockAttribute()
	local localPlayer = Players.LocalPlayer
	if not localPlayer then
		return
	end
	local locked = UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter
	if localPlayer:GetAttribute(SHIFT_LOCK_ATTRIBUTE) ~= locked then
		localPlayer:SetAttribute(SHIFT_LOCK_ATTRIBUTE, locked)
	end
	CameraMode.SyncEngineShiftLock(locked)
end

--[[
	订阅 MouseBehavior 并同步一次属性（Init 调用）
	@return () - 无返回值
]]
function CameraShiftLock.bind()
	_syncShiftLockAttribute()
	_shiftLockConn = UserInputService:GetPropertyChangedSignal("MouseBehavior"):Connect(_syncShiftLockAttribute)
end

--[[
	断开 MouseBehavior 订阅
	@return () - 无返回值
]]
function CameraShiftLock.destroy()
	if _shiftLockConn then
		_shiftLockConn:Disconnect()
		_shiftLockConn = nil
	end
end

return CameraShiftLock
