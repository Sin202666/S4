local m = game.ReplicatedStorage.ClientSideCode.SystemModule.SystemArmWrestle.BattlePose
m.Source = [===[--[[
	Module: BattlePose
	Description: 扳手腕对局臂姿：右手/左手对齐临时文件夹 Table_L1_1 参考手位；躯干仍跟 Anim scrub AW_Battle
	Author: 程莘
	Created: 2026-10-16
	Last Modified: 2026-10-16

	功能：
	- Begin / Stop：PreRender 写右肩参考形态 + 左肩扶桌（晚于 Animator，避免被冲掉）
	- 右手：尖端落在参考桌两人右手中点；座位偏远时 Transform 平移补臂长；扭转参考 Table_L1_1；P 微倾
	- 左手：Begin 时钉死在 Top 本地参考扶点（Player / Opponent 各自实测），整局尖端不挪；无座位时固定撑姿
	- 不禁用 Animate、不停 AnimationTrack（拉锯全身仍由 Anim）

	参考：
	- Workspace["临时文件夹"].Table_L1_1（Player + Opponent 已摆位姿）

	约束：
	- 纯本地表现；不写 HRP / 存档；镜头仍由 SystemArmWrestle

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
local RIGHT_ARM = "Right Arm"
local RIGHT_SHOULDER = "Right Shoulder"
local LEFT_ARM = "Left Arm"
local LEFT_SHOULDER = "Left Shoulder"
local UP = Vector3.yAxis
-- PreRender 在 Animator 写完 Transform 之后、出画之前，避免拉锯动画冲掉臂姿
local _preRenderConn: RBXScriptConnection? = nil

-- 临时文件夹 Table_L1_1.Opponent Right Shoulder（只取旋转作扭转参考）
local REF_RIGHT_C0 = CFrame.new(1, 0.5, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0)
local REF_RIGHT_C1 = CFrame.new(
	-0.5,
	0.9753023386,
	-0.5883182287,
	0,
	0,
	1,
	-0.8007820249,
	-0.5989558697,
	0,
	0.5989558697,
	-0.8007820249,
	0
)
local REF_RIGHT_ARM_LOCAL = REF_RIGHT_C0 * REF_RIGHT_C1:Inverse()
local MAX_TILT_DEG = 18
-- 相握手相对桌面抬高（无 Top 时）；C1 拉长上限（座位约 4.61，自然臂长不够）
local HAND_MEET_HEIGHT = 0.5
local RIGHT_REACH_MAX_SCALE = 1.9
-- 右手尖端 Top 本地目标（参考桌 Player/Opponent 右尖端中点）
local RIGHT_MEET_LOCAL = Vector3.new(-0.0541038364, 1.701965332, -0.0668640211)
-- 无座位时的左手固定撑姿（肩关节空间，前倾下压贴桌）
local LEFT_BRACE_TRANSFORM = CFrame.Angles(math.rad(55), math.rad(-15), math.rad(70))
-- 左手 Top 本地扶点（参考桌 Player / Opponent 左尖端实测）
local LEFT_REST_PLAYER_LOCAL = Vector3.new(-2.6057395935, 0.4963989258, -0.0160219558)
local LEFT_REST_OPP_LOCAL = Vector3.new(2.4975318909, 0.4963989258, -0.1177060828)
local LEFT_REACH_MAX_SCALE = 1.6

type ArmState = {
	Motor: Motor6D,
	Torso: BasePart,
	Arm: BasePart,
	OrigC0: CFrame,
	OrigC1: CFrame,
}

type Session = {
	Table: Model,
	Character: Model?,
	PlayerRight: ArmState?,
	OpponentRight: ArmState?,
	PlayerLeft: ArmState?,
	OpponentLeft: ArmState?,
	-- Begin 时按桌边算死，整局不变
	PlayerLeftRest: Vector3?,
	OpponentLeftRest: Vector3?,
	Bound: boolean,
}

local _session: Session? = nil

--[[
	取指定侧肩关节并记下原始 C0/C1
	@param model Model? - 角色或对手
	@param armName string - 手臂零件名
	@param shoulderName string - 肩关节名
	@return ArmState? - 状态
]]
local function _getArm(model: Model?, armName: string, shoulderName: string): ArmState?
	if not model or not model.Parent then
		return nil
	end
	local torso = model:FindFirstChild("Torso")
	local arm = model:FindFirstChild(armName)
	if not torso or not torso:IsA("BasePart") or not arm or not arm:IsA("BasePart") then
		return nil
	end
	local motor = torso:FindFirstChild(shoulderName)
	if not motor or not motor:IsA("Motor6D") then
		return nil
	end
	return {
		Motor = motor,
		Torso = torso,
		Arm = arm,
		OrigC0 = motor.C0,
		OrigC1 = motor.C1,
	}
end

--[[
	桌面顶面 Y
	@param tableModel Model - 桌子
	@return number - 世界 Y
]]
local function _getTableTopY(tableModel: Model): number
	local top = tableModel:FindFirstChild("Top")
	if top and top:IsA("BasePart") then
		return top.Position.Y + top.Size.Y * 0.5
	end
	local fist = tableModel:FindFirstChild("Fist")
	if fist and fist:IsA("BasePart") then
		return fist.Position.Y - 0.6
	end
	return tableModel:GetPivot().Position.Y
end

--[[
	还原肩关节
	@param state ArmState? - 手臂
]]
local function _restoreArm(state: ArmState?)
	if not state or not state.Motor.Parent then
		return
	end
	state.Motor.C0 = state.OrigC0
	state.Motor.C1 = state.OrigC1
	state.Motor.Transform = CFrame.identity
end

--[[
	两人右手相握点：优先 Top 本地参考中点；否则 Fist / 座位中点
	@param tableModel Model - 桌子
	@param topY number - 桌面顶面 Y
	@param seat any - 座位 CFrame 属性
	@param oppCf any - 对手枢轴 CFrame 属性
	@return Vector3 - 世界相握点
]]
local function _getHandMeet(tableModel: Model, topY: number, seat: any, oppCf: any): Vector3
	local top = tableModel:FindFirstChild("Top")
	if top and top:IsA("BasePart") then
		return top.CFrame:PointToWorldSpace(RIGHT_MEET_LOCAL)
	end
	local fist = tableModel:FindFirstChild("Fist")
	if fist and fist:IsA("BasePart") then
		return fist.Position + UP * (RIGHT_MEET_LOCAL.Y - 1.02)
	end
	if typeof(seat) == "CFrame" and typeof(oppCf) == "CFrame" then
		local mid = seat.Position:Lerp(oppCf.Position, 0.5)
		return Vector3.new(mid.X, topY + HAND_MEET_HEIGHT, mid.Z)
	end
	local pivot = tableModel:GetPivot().Position
	return Vector3.new(pivot.X, topY + HAND_MEET_HEIGHT, pivot.Z)
end

--[[
	右手：尖端落在相握点；扭转参考 Table_L1_1；P 微倾
	@param state ArmState - 右肩
	@param p number - 进度 0~1
	@param meet Vector3 - 相握点
]]
local function _applyRightRef(state: ArmState, p: number, meet: Vector3)
	local motor = state.Motor
	local arm = state.Arm
	if not motor.Parent or not arm.Parent then
		return
	end
	motor.C0 = state.OrigC0
	motor.C1 = state.OrigC1

	local half = arm.Size.Y * 0.5
	local tipLocal = Vector3.new(0, -half, 0)
	local shoulder = (state.Torso.CFrame * state.OrigC0).Position
	local toMeet = meet - shoulder
	local maxReach = (tipLocal - state.OrigC1.Position).Magnitude * RIGHT_REACH_MAX_SCALE
	local target = if toMeet.Magnitude > maxReach then shoulder + toMeet.Unit * maxReach else meet
	local dir = if (target - shoulder).Magnitude > 0.05 then (target - shoulder).Unit else -UP

	local refArmWorld = state.Torso.CFrame * REF_RIGHT_ARM_LOCAL
	local up = -dir
	local right = up:Cross(refArmWorld.LookVector)
	if right.Magnitude < 0.12 then
		right = up:Cross(refArmWorld.RightVector)
	end
	if right.Magnitude < 0.12 then
		right = up:Cross(Vector3.xAxis)
	end
	right = right.Unit
	local back = right:Cross(up)
	local rot = CFrame.fromMatrix(Vector3.zero, right, up, back)
	local armPos = target - rot:VectorToWorldSpace(tipLocal)
	local desiredArm = CFrame.new(armPos) * rot
	local full = state.OrigC0:Inverse() * state.Torso.CFrame:Inverse() * desiredArm * state.OrigC1
	local tilt = math.rad((p - 0.5) * 2 * MAX_TILT_DEG)
	motor.Transform = full * CFrame.Angles(tilt, 0, 0)
end

--[[
	左手扶桌：尖端钉在桌面扶点（保留 Transform 平移）
	@param state ArmState - 左肩
	@param rest Vector3 - 桌面扶点（已在 Top 上）
]]
local function _applyLeftRest(state: ArmState, rest: Vector3)
	local motor = state.Motor
	local arm = state.Arm
	if not motor.Parent or not arm.Parent then
		return
	end
	motor.C0 = state.OrigC0
	motor.C1 = state.OrigC1

	local half = arm.Size.Y * 0.5
	local tipLocal = Vector3.new(0, -half, 0)
	local shoulder = (state.Torso.CFrame * state.OrigC0).Position
	local toTip = rest - shoulder
	local maxReach = (tipLocal - state.OrigC1.Position).Magnitude * LEFT_REACH_MAX_SCALE
	local target = if toTip.Magnitude > maxReach then shoulder + toTip.Unit * maxReach else rest
	target = Vector3.new(target.X, rest.Y, target.Z)
	local dir = if (target - shoulder).Magnitude > 0.05 then (target - shoulder).Unit else -UP

	local up = -dir
	local right = up:Cross(UP)
	if right.Magnitude < 0.12 then
		right = up:Cross(Vector3.xAxis)
	end
	right = right.Unit
	local back = right:Cross(up)
	local rot = CFrame.fromMatrix(Vector3.zero, right, up, back)
	local armPos = target - rot:VectorToWorldSpace(tipLocal)
	local desiredArm = CFrame.new(armPos) * rot

	local full = state.OrigC0:Inverse() * state.Torso.CFrame:Inverse() * desiredArm * state.OrigC1
	motor.Transform = full
end

--[[
	左手固定撑姿（无座位时）
	@param state ArmState - 左肩
]]
local function _applyLeftBrace(state: ArmState)
	local motor = state.Motor
	if not motor.Parent then
		return
	end
	motor.C0 = state.OrigC0
	motor.C1 = state.OrigC1
	motor.Transform = LEFT_BRACE_TRANSFORM
end

--[[
	左手固定扶点：Top 本地参考点（玩家 / 对手各自实测）
	@param tableModel Model - 桌子
	@param isPlayer boolean - true 用玩家侧扶点
	@param topY number - 桌面 Y（无 Top 时回退）
	@return Vector3 - 扶点
]]
local function _leftRestPoint(tableModel: Model, isPlayer: boolean, topY: number): Vector3
	local localRest = if isPlayer then LEFT_REST_PLAYER_LOCAL else LEFT_REST_OPP_LOCAL
	local top = tableModel:FindFirstChild("Top")
	if not top or not top:IsA("BasePart") then
		local pivot = tableModel:GetPivot().Position
		return Vector3.new(pivot.X + localRest.X, topY + localRest.Y, pivot.Z + localRest.Z)
	end
	return top.CFrame:PointToWorldSpace(localRest)
end

--[[
	补解析双臂
	@param s Session - 会话
]]
local function _resolveArms(s: Session)
	if not s.PlayerRight or not s.PlayerRight.Motor.Parent then
		s.PlayerRight = _getArm(s.Character, RIGHT_ARM, RIGHT_SHOULDER)
	end
	if not s.OpponentRight or not s.OpponentRight.Motor.Parent then
		s.OpponentRight = _getArm(s.Table:FindFirstChild(OPPONENT_MODEL_NAME) :: Model?, RIGHT_ARM, RIGHT_SHOULDER)
	end
	if not s.PlayerLeft or not s.PlayerLeft.Motor.Parent then
		s.PlayerLeft = _getArm(s.Character, LEFT_ARM, LEFT_SHOULDER)
	end
	if not s.OpponentLeft or not s.OpponentLeft.Motor.Parent then
		s.OpponentLeft = _getArm(s.Table:FindFirstChild(OPPONENT_MODEL_NAME) :: Model?, LEFT_ARM, LEFT_SHOULDER)
	end
end

--[[
	一帧：右手参考形态 + 左手扶桌
	@param s Session - 会话
]]
local function _step(s: Session)
	local tableModel = s.Table
	if not tableModel.Parent then
		BattlePose.Stop()
		return
	end
	_resolveArms(s)

	local p = tableModel:GetAttribute("P")
	if typeof(p) ~= "number" then
		p = 0.5
	end
	local seat = tableModel:GetAttribute(SEAT_ATTR)
	local oppCf = tableModel:GetAttribute(OPP_PIVOT_ATTR)
	local topY = _getTableTopY(tableModel)
	local meet = _getHandMeet(tableModel, topY, seat, oppCf)

	if s.PlayerRight then
		_applyRightRef(s.PlayerRight, p, meet)
	end
	if s.OpponentRight then
		_applyRightRef(s.OpponentRight, 1 - p, meet)
	end

	if s.PlayerLeft then
		if s.PlayerLeftRest then
			_applyLeftRest(s.PlayerLeft, s.PlayerLeftRest)
		elseif typeof(seat) == "CFrame" then
			s.PlayerLeftRest = _leftRestPoint(tableModel, true, topY)
			_applyLeftRest(s.PlayerLeft, s.PlayerLeftRest)
		else
			_applyLeftBrace(s.PlayerLeft)
		end
	end
	if s.OpponentLeft then
		if s.OpponentLeftRest then
			_applyLeftRest(s.OpponentLeft, s.OpponentLeftRest)
		elseif typeof(oppCf) == "CFrame" then
			s.OpponentLeftRest = _leftRestPoint(tableModel, false, topY)
			_applyLeftRest(s.OpponentLeft, s.OpponentLeftRest)
		else
			_applyLeftBrace(s.OpponentLeft)
		end
	end
end

--[[
	对局开始：接管右臂参考形态 + 左手扶桌
	@param tableModel Model? - 桌子
	@param character Model? - 本地角色
]]
function BattlePose.Begin(tableModel: Model?, character: Model?)
	BattlePose.Stop()
	if not tableModel then
		return
	end
	local oppModel = tableModel:FindFirstChild(OPPONENT_MODEL_NAME) :: Model?
	local seat = tableModel:GetAttribute(SEAT_ATTR)
	local oppCf = tableModel:GetAttribute(OPP_PIVOT_ATTR)
	local topY = _getTableTopY(tableModel)
	local playerLeftRest: Vector3? = nil
	local opponentLeftRest: Vector3? = nil
	if typeof(seat) == "CFrame" then
		playerLeftRest = _leftRestPoint(tableModel, true, topY)
	end
	if typeof(oppCf) == "CFrame" then
		opponentLeftRest = _leftRestPoint(tableModel, false, topY)
	end
	local s: Session = {
		Table = tableModel,
		Character = character,
		PlayerRight = _getArm(character, RIGHT_ARM, RIGHT_SHOULDER),
		OpponentRight = _getArm(oppModel, RIGHT_ARM, RIGHT_SHOULDER),
		PlayerLeft = _getArm(character, LEFT_ARM, LEFT_SHOULDER),
		OpponentLeft = _getArm(oppModel, LEFT_ARM, LEFT_SHOULDER),
		PlayerLeftRest = playerLeftRest,
		OpponentLeftRest = opponentLeftRest,
		Bound = false,
	}
	_session = s
	if _preRenderConn then
		_preRenderConn:Disconnect()
		_preRenderConn = nil
	end
	_preRenderConn = RunService.PreRender:Connect(function()
		if _session == s then
			_step(s)
		end
	end)
	s.Bound = true
end

--[[
	结束：还原双臂肩关节
]]
function BattlePose.Stop()
	local s = _session
	if not s then
		return
	end
	_session = nil
	if _preRenderConn then
		_preRenderConn:Disconnect()
		_preRenderConn = nil
	end
	s.Bound = false
	_restoreArm(s.PlayerRight)
	_restoreArm(s.OpponentRight)
	_restoreArm(s.PlayerLeft)
	_restoreArm(s.OpponentLeft)
end

--[[
	是否正在接管对局臂姿
	@return boolean - true 表示接管中
]]
function BattlePose.IsActive(): boolean
	return _session ~= nil
end

return BattlePose
]===]
return { n = #m.Source, head = string.sub(m.Source, 1, 80) }
