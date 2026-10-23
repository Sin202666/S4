--[[
	Module: BattlePose
	Description: 扳手腕对局 R6 右臂姿势：根部靠桌、前端斜 45° 朝握拳点，随桌子属性 P 倾斜
	Author: 程莘
	Created: 2026-10-16
	Last Modified: 2026-10-16

	功能：
	- Begin / Stop：对局开始接管、结束释放（Release / End / 重生）
	- 每帧 PreRender 在 Animator 之后写玩家与桌边 Opponent 的 Right Shoulder.Transform
	- 躯干仍由 Anim 的 AW_Battle 按 P 拉锯前倾；本模块只管右臂，不写 HRP / CFrame / 存档

	姿势：
	- 臂长轴从肩指向 Fist，抬升 ARM_RAISE_DEG；P=0.5 居中，P→1 压向对手侧，P→0 被压
	- 双方右臂共享同一世界倾斜（相握手），对手读 1 不单独镜像

	约束：
	- 纯本地表现：Transform 不复制；对局已隐藏其他玩家，对手为桌边 NPC
	- 对局期 Right Shoulder.Transform 唯一写口；Stop 时清零
	- 不写 CurrentCamera（镜头仍由 SystemArmWrestle._updateBattleCamera）

	加载（仅 SystemArmWrestle 内部）：
		local BattlePose = require(script.BattlePose)
		BattlePose.Begin(tableModel, LocalPlayer.Character)
		BattlePose.Stop()
]]

local Utils = require(game.ReplicatedFirst.AllSideCode.UtilsSystem)
local RunService = Utils.RunService
local ArmWrestleConfig = Utils.ArmWrestleConfig

local BattlePose = {}

local SEAT_ATTR = ArmWrestleConfig.SEAT_ATTR
local OPP_PIVOT_ATTR = "OppPivot"
local OPPONENT_MODEL_NAME = ArmWrestleConfig.OPPONENT_MODEL_NAME
local ARM_PART = "Right Arm"
local SHOULDER = "Right Shoulder"
local FLAT = Vector3.new(1, 0, 1)
local UP = Vector3.yAxis

-- 前端相对水平抬升；与「根部靠桌、拳朝前上方」一致
local ARM_RAISE_DEG = 45
-- |P-0.5| = 0.5 时的最大倾斜（压倒对手 / 被压倒）
local MAX_TILT_DEG = 52
-- R6 右臂半长（Size.Y/2），用于肩→臂心
local ARM_HALF = 1
local HAND_HEIGHT = 0.8

type ArmState = {
	Motor: Motor6D,
	Torso: BasePart,
}

type Session = {
	Table: Model,
	Player: ArmState?,
	Opponent: ArmState?,
	Conn: RBXScriptConnection?,
}

local _session: Session? = nil

--[[
	取 R6 右肩 Motor6D 与 Torso
	@param model Model? - 角色或对手
	@return ArmState? - 肩关节；缺件为 nil
]]
local function _getArm(model: Model?): ArmState?
	if not model then
		return nil
	end
	local torso = model:FindFirstChild("Torso")
	local arm = model:FindFirstChild(ARM_PART)
	if not torso or not torso:IsA("BasePart") or not arm or not arm:IsA("BasePart") then
		return nil
	end
	local motor = torso:FindFirstChild(SHOULDER)
	if not motor or not motor:IsA("Motor6D") then
		return nil
	end
	return { Motor = motor, Torso = torso }
end

--[[
	握拳世界坐标：优先 Fist 零件，否则 Pivot + 手高
	@param tableModel Model - 桌子
	@return Vector3 - 握拳点
]]
local function _getFistPos(tableModel: Model): Vector3
	local fist = tableModel:FindFirstChild("Fist")
	if fist and fist:IsA("BasePart") then
		return fist.Position
	end
	local pivot = tableModel:GetAttribute("Pivot")
	if typeof(pivot) == "Vector3" then
		return pivot + UP * HAND_HEIGHT
	end
	return tableModel:GetPivot().Position + UP * HAND_HEIGHT
end

--[[
	水平单位方向；接近零时退回 fallback
	@param v Vector3 - 任意向量
	@param fallback Vector3 - 备用单位向量
	@return Vector3 - 水平单位向量
]]
local function _flatUnit(v: Vector3, fallback: Vector3): Vector3
	local f = v * FLAT
	if f.Magnitude > 1e-3 then
		return f.Unit
	end
	local fb = fallback * FLAT
	return if fb.Magnitude > 1e-3 then fb.Unit else Vector3.zAxis
end

--[[
	绕轴旋转向量
	@param v Vector3 - 原向量
	@param axis Vector3 - 单位轴
	@param angle number - 弧度
	@return Vector3 - 旋转后
]]
local function _rotate(v: Vector3, axis: Vector3, angle: number): Vector3
	return CFrame.fromAxisAngle(axis, angle):VectorToWorldSpace(v)
end

--[[
	由肩位与目标方向求右臂 Part CFrame（+Y 朝肩、−Y 朝拳）
	@param shoulder Vector3 - 肩关节世界坐标
	@param dir Vector3 - 肩→拳单位方向
	@return CFrame - Right Arm 世界位姿
]]
local function _armCFrame(shoulder: Vector3, dir: Vector3): CFrame
	local up = -dir
	local right = up:Cross(UP)
	if right.Magnitude < 0.12 then
		right = up:Cross(Vector3.xAxis)
	end
	right = right.Unit
	local back = right:Cross(up)
	local center = shoulder + dir * ARM_HALF
	return CFrame.fromMatrix(center, right, up, back)
end

--[[
	把 Motor6D.Transform 设到目标臂 Part CFrame
	@param state ArmState - 肩关节
	@param desiredArm CFrame - 目标 Right Arm 世界 CFrame
]]
local function _applyTransform(state: ArmState, desiredArm: CFrame)
	local motor = state.Motor
	motor.Transform = motor.C0:Inverse() * state.Torso.CFrame:Inverse() * desiredArm * motor.C1
end

--[[
	清零 Transform
	@param state ArmState? - 肩关节
]]
local function _clear(state: ArmState?)
	if state and state.Motor.Parent then
		state.Motor.Transform = CFrame.identity
	end
end

--[[
	算单侧肩→拳方向（45° 抬升后绕对局轴倾斜）
	@param shoulder Vector3 - 肩位
	@param fist Vector3 - 握拳点
	@param facing Vector3 - 角色朝向（水平）
	@param tiltAxis Vector3 - 倾斜轴（玩家→对手水平）
	@param tilt number - 倾斜弧度（P 驱动，双方同号）
	@return Vector3 - 单位方向
]]
local function _aimDir(shoulder: Vector3, fist: Vector3, facing: Vector3, tiltAxis: Vector3, tilt: number): Vector3
	local flat = _flatUnit(fist - shoulder, facing)
	local raise = math.rad(ARM_RAISE_DEG)
	local base = (flat * math.cos(raise) + UP * math.sin(raise)).Unit
	return _rotate(base, tiltAxis, tilt)
end

--[[
	一帧：按当前 Animator 后的躯干位姿写双臂
	@param s Session - 会话
]]
local function _step(s: Session)
	local tableModel = s.Table
	if not tableModel.Parent then
		BattlePose.Stop()
		return
	end
	local p = tableModel:GetAttribute("P")
	if typeof(p) ~= "number" then
		p = 0.5
	end
	local seat = tableModel:GetAttribute(SEAT_ATTR)
	local oppCf = tableModel:GetAttribute(OPP_PIVOT_ATTR)
	local facing = Vector3.zAxis
	local tiltAxis = Vector3.xAxis
	if typeof(seat) == "CFrame" then
		facing = _flatUnit(seat.LookVector, Vector3.zAxis)
	end
	if typeof(seat) == "CFrame" and typeof(oppCf) == "CFrame" then
		tiltAxis = _flatUnit(oppCf.Position - seat.Position, facing:Cross(UP))
	end
	-- P>0.5 压向对手：绕 tiltAxis 正转（与 WinCinematic 掰赢方向一致时手往玩家左压）
	local tilt = (p - 0.5) * 2 * math.rad(MAX_TILT_DEG)
	local fist = _getFistPos(tableModel)

	if s.Player then
		local shoulder = (s.Player.Torso.CFrame * s.Player.Motor.C0).Position
		local dir = _aimDir(shoulder, fist, facing, tiltAxis, tilt)
		_applyTransform(s.Player, _armCFrame(shoulder, dir))
	end
	if s.Opponent then
		local oppFacing = if typeof(oppCf) == "CFrame"
			then _flatUnit(oppCf.LookVector, -facing)
			else -facing
		local shoulder = (s.Opponent.Torso.CFrame * s.Opponent.Motor.C0).Position
		local dir = _aimDir(shoulder, fist, oppFacing, tiltAxis, tilt)
		_applyTransform(s.Opponent, _armCFrame(shoulder, dir))
	end
end

--[[
	对局开始：接管双方右臂；重复 Begin 会先 Stop
	@param tableModel Model? - 对局桌子
	@param character Model? - 本地玩家角色
]]
function BattlePose.Begin(tableModel: Model?, character: Model?)
	BattlePose.Stop()
	if not tableModel then
		return
	end
	local s: Session = {
		Table = tableModel,
		Player = _getArm(character),
		Opponent = _getArm(tableModel:FindFirstChild(OPPONENT_MODEL_NAME) :: Model?),
		Conn = nil,
	}
	_session = s
	s.Conn = RunService.PreRender:Connect(function()
		if _session == s then
			_step(s)
		end
	end)
end

--[[
	结束：清 Transform、断 PreRender；未在对局忽略
]]
function BattlePose.Stop()
	local s = _session
	if not s then
		return
	end
	_session = nil
	if s.Conn then
		s.Conn:Disconnect()
	end
	_clear(s.Player)
	_clear(s.Opponent)
end

--[[
	是否正在摆对局臂姿
	@return boolean - Begin 后到 Stop 前为 true
]]
function BattlePose.IsActive(): boolean
	return _session ~= nil
end

return BattlePose
