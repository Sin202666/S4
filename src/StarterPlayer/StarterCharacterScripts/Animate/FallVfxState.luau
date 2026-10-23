--!strict
--[[
	Module: FallVfxState
	Description: 下落期间受控补线，落地停止；中断清理不在同次空中阶段重播。
	Author: 林奥宇
	Created: 2026-10-13
	Last Modified: 2026-10-13
	emitCount 为本轮每色理论预算，供状态回归与诊断；Visual 使用原生 Rate 连续发射。
]]
local State = {}

export type Config = {
	minDownSpeed: number, exitDownSpeed: number, fullDownSpeed: number,
	minDescendingSec: number, minDropStuds: number,
	attackSec: number, releaseSec: number, maxFrameSec: number,
	rampSec: number, lifetimeMax: number, particlesPerSecond: number,
}
export type Snapshot = {
	phase: string, descendingSec: number, dropStuds: number,
	intensity: number, emitting: boolean, fired: boolean,
	burstAge: number, emitCount: number, clear: boolean, emissionClosed: boolean,
}

function State.new(): Snapshot
	return { phase = "Idle", descendingSec = 0, dropStuds = 0, intensity = 0,
		emitting = false, fired = false, burstAge = 0, emitCount = 0, clear = false, emissionClosed = false }
end

function State.reset(s: Snapshot)
	s.phase, s.descendingSec, s.dropStuds, s.intensity = "Idle", 0, 0, 0
	s.emitting, s.fired, s.burstAge, s.emitCount, s.clear = false, false, 0, 0, true
	s.emissionClosed = false
end

-- grounded 是真实支撑状态；空中上升、攀爬或技能接管不应把已消耗爆发重新武装。
function State.step(s: Snapshot, cfg: Config, dt: number, downSpeed: number, airborne: boolean, blocked: boolean, grounded: boolean?)
	local onGround = if grounded == nil then not airborne else grounded
	s.clear = false
	if blocked or dt ~= dt or dt <= 0 or dt > cfg.maxFrameSec
		or downSpeed ~= downSpeed or math.abs(downSpeed) == math.huge then
		local consumed = s.fired and not onGround
		State.reset(s)
		s.fired = consumed
		if consumed then s.burstAge, s.phase, s.emissionClosed = math.huge, "Spent", true end
		return
	end
	if s.fired then s.burstAge += dt end
	local descending = airborne and downSpeed > 0
	if descending then
		s.descendingSec += dt
		s.dropStuds += downSpeed * dt
	else
		s.descendingSec, s.dropStuds = 0, 0
	end
	if onGround then
		s.fired, s.emitCount, s.emissionClosed = false, 0, false
	elseif not s.fired and descending and downSpeed >= cfg.minDownSpeed
		and s.descendingSec >= cfg.minDescendingSec and s.dropStuds >= cfg.minDropStuds then
		s.fired, s.burstAge, s.emitCount = true, 0, 1
	end
	if s.fired and (not descending or downSpeed < cfg.exitDownSpeed) then
		s.emissionClosed = true
	end
	s.emitting = s.fired and not s.emissionClosed and descending
	if s.emitting then
		s.emitCount = 1 + math.floor(s.burstAge * cfg.particlesPerSecond + 1e-6)
	end
	local target = 0
	if s.emitting then
		local speedAlpha = math.clamp((downSpeed - cfg.minDownSpeed) / (cfg.fullDownSpeed - cfg.minDownSpeed), 0, 1)
		target = 0.32 + 0.68 * speedAlpha
	end
	local response = if target > s.intensity then cfg.attackSec else cfg.releaseSec
	s.intensity += (target - s.intensity) * (1 - math.exp(-dt / math.max(response, 0.001)))
	if s.intensity < 0.005 then s.intensity = 0 end
	s.phase = if s.emitting then (if s.burstAge < cfg.rampSec then "Burst" else "Falling") elseif s.intensity > 0 then "Release"
		elseif s.fired then "Spent" elseif descending then "Armed" else "Idle"
end

return State
