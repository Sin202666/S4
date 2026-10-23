--[[
	Module: FallVfxVisual
	Description: 黑/白漫画线，4×4 序列控制线长，保持线身实度，着地只收尾。
	Author: 林奥宇
	Created: 2026-10-13
	Last Modified: 2026-10-13
	用法：create(config, parent)，update(origin, snapshot, followRoot)，clear/destroy。
	snapshot 为 FallVfxState 输出；emitting 开关连续发射，clear 是硬清理信号。
	只操作三个自有实例；NumberSequence 在创建时分配。载体跟随，已发出的粒子不再跟随角色。
]]
local Visual = {}

local function makeEmitter(cfg, name, color, carrier)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = name
	emitter.Texture = cfg.texture
	emitter.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
	emitter.FlipbookMode = Enum.ParticleFlipbookMode.OneShot
	emitter.FlipbookBlendFrames = true
	emitter.FlipbookStartRandom = false
	emitter.Color = ColorSequence.new(color)
	emitter.LightEmission, emitter.LightInfluence, emitter.Brightness = 0, 0, 1
	emitter.Orientation = Enum.ParticleOrientation.FacingCamera
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.Shape = Enum.ParticleEmitterShape.Box
	emitter.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	emitter.SpreadAngle = Vector2.zero
	-- 参考为画面竖线，面向镜头的竖向贴图避免透视汇聚或按横向速度倾斜。
	emitter.Rotation, emitter.RotSpeed = NumberRange.new(0), NumberRange.new(0)
	emitter.Squash = NumberSequence.new(0.6)
	emitter.LockedToPart, emitter.VelocityInheritance, emitter.Drag = false, 0, 0
	emitter.Lifetime = NumberRange.new(cfg.lifetimeMin, cfg.lifetimeMax)
	emitter.Speed = NumberRange.new(cfg.upwardDrift * 0.7, cfg.upwardDrift)
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.94, 0),
		NumberSequenceKeypoint.new(1, 1),
	})
	local size, variance = cfg.particleSize, cfg.particleSizeVariance
	-- 只由序列贴图缩短线长；不再用 Size 把线宽一同缩没，短划仍保持清楚的黑白线身。
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, size, size * variance),
		NumberSequenceKeypoint.new(1, size, size * variance),
	})
	-- 原生 Rate 在粒子模拟中连续补线；按 Heartbeat 批量 Emit 会在低帧率时形成一簇簇同龄线条。
	emitter.Enabled, emitter.Rate = false, cfg.particlesPerSecond
	emitter.Parent = carrier
	return emitter
end

function Visual.create(cfg, parent)
	local carrier = Instance.new("Part")
	carrier.Name = "FallParticles_Local"
	carrier:SetAttribute("FallVfxRevision", cfg.revision)
	carrier:SetAttribute("FallVfxTexture", cfg.texture)
	carrier.Size = Vector3.new(cfg.emitterExtent, cfg.emitterVerticalExtent, cfg.emitterExtent)
	carrier.Transparency, carrier.Anchored = 1, true
	carrier.CanCollide, carrier.CanTouch, carrier.CanQuery, carrier.CastShadow = false, false, false, false
	local emitters = {
		makeEmitter(cfg, "WhiteStreaks", Color3.new(1, 1, 1), carrier),
		makeEmitter(cfg, "InkStreaks", Color3.new(0, 0, 0), carrier),
	}
	carrier.Parent = parent
	local destroyed, hasParticles, wasEmitting = false, false, false

	local function clear()
		wasEmitting = false
		for _, emitter in ipairs(emitters) do emitter.Enabled = false end
		if not hasParticles then return end
		hasParticles = false
		for _, emitter in ipairs(emitters) do emitter:Clear() end
	end

	local function update(origin, snapshot, followRoot)
		if destroyed then return end
		if snapshot.clear then clear(); return end
		if followRoot then carrier.CFrame = CFrame.new(origin + Vector3.yAxis * cfg.emitterHeight) end
		for _, emitter in ipairs(emitters) do
			emitter.Enabled = snapshot.emitting
			if snapshot.emitting and not wasEmitting then emitter:Emit(1) end
		end
		if snapshot.emitting then hasParticles = true end
		wasEmitting = snapshot.emitting
	end

	return {
		update = update,
		clear = clear,
		destroy = function()
			if destroyed then return end
			destroyed = true
			carrier:Destroy()
		end,
	}
end

return Visual
