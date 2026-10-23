--[[
	Module: SystemArmWrestle
	Description: 扳手腕客户端：清掉旧移速加成，并驱动 HUD
	Author: 程莘
	Created: 2026-10-14
	Last Modified: 2026-10-16

	不写存档，不写 WalkSpeed / CFrame。
	升级垫移速已下线：进角色时 pop 掉旧的 ArmWrestle:Walk，平面速度只留 CharacterMotion。
	哑铃训练已下线：不再自动上报训练，也不播举哑铃动作。
]]

local Utils = require(game.ReplicatedFirst.AllSideCode.UtilsSystem)
local RunService = Utils.RunService
local Workspace = game:GetService("Workspace")
local LocalPlayer = Utils.LocalPlayer
local ReplicatedStorage = Utils.ReplicatedStorage
local ArmWrestleConfig = Utils.ArmWrestleConfig
local ArmWrestleStyle = Utils.ArmWrestleStyle
local NetWork = Utils.NetWork
local NetMsg = Utils.NetMsg
local Log = Utils.Log

local SystemArmWrestle = {}

local WALK_MOD = ArmWrestleConfig.WALK_MODIFIER

local _inited = false
local _gui: any = nil

--[[
	取角色上的 CMS Bind
	@param character Model? - 角色
	@return any? - CharacterMoveSpeedBind
]]
local function _getMoveBind(character: Model?): any?
	if not character then
		return nil
	end
	local folder = character:FindFirstChild("CharacterScripts")
	local module = folder and folder:FindFirstChild("CharacterMoveSpeedBind")
	if module and module:IsA("ModuleScript") then
		return require(module)
	end
	return nil
end

--[[
	清掉升级垫留下的移速 modifier，避免热更后旧加成还在
	@param character Model? - 角色
]]
local function _clearWalkModifier(character: Model?)
	local bind = _getMoveBind(character)
	if bind and bind.popModifier then
		bind.popModifier(WALK_MOD)
	end
end

--[[
	角色生成：清移速 modifier
	@param character Model - 本地角色
]]
local function _onCharacter(character: Model)
	_clearWalkModifier(character)
end

--[[
	启动客户端
]]
function SystemArmWrestle.Init()
	if _inited then
		return
	end
	_inited = true

	local world = Workspace:WaitForChild(ArmWrestleConfig.WORLD_NAME, 15)
	if world then
		ArmWrestleStyle.BindIcons(world)
		ArmWrestleStyle.StyleWorld(world)
	end

	local ok, hud = pcall(function()
		return require(ReplicatedStorage.ClientSideCode.GuiScripts.ModuleScript.ArmWrestleHUD)
	end)
	if ok and hud and hud.Init then
		_gui = hud
		hud.Init(SystemArmWrestle.Invoke)
	else
		Log.warn("SystemArmWrestle 加载 HUD 失败", hud)
	end

	LocalPlayer.CharacterAdded:Connect(_onCharacter)
	if LocalPlayer.Character then
		_onCharacter(LocalPlayer.Character)
	end

	RunService.RenderStepped:Connect(function(dt: number)
		if _gui and _gui.Heartbeat then
			_gui.Heartbeat(dt)
		end
	end)
end

--[[
	Invoke 服务端 Action
	@param action string - 动作名
	@param ... any - 参数
	@return any
]]
function SystemArmWrestle.Invoke(action: string, ...: any): any
	return NetWork.InvokeServer(NetMsg.ARM_WRESTLE_ACTION, action, ...)
end

--[[
	是否对局中。比赛已下线，恒为 false
	@return boolean - 恒 false
]]
function SystemArmWrestle.IsInBattle(): boolean
	return false
end

return SystemArmWrestle
