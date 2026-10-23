--[[
	Module: FallVfx
	Description: 下落表现编排：读取 Humanoid/速度/Gate → 状态机 → 贴图粒子。
	Author: 林奥宇
	Created: 2026-10-13
	Last Modified: 2026-10-13
	用法：Animate 创建一次，每次 Heartbeat update(dt)，清理时 destroy()。
	配置由 AnimateSetting.FallVfx 提供；FOV 只通过 getFov 交给 AnimateFov 合成。
	本地角色表现，不发 Remote；不改速度、重力、姿态、相机或落地反馈。
]]
local State = require(script.Parent.FallVfxState)
local Visual = require(script.Parent.FallVfxVisual)
local FallVfx = {}

function FallVfx.create(deps)
	local cfg = deps.setting.FallVfx
	local state = State.new()
	local hasTexture = type(cfg.texture) == "string" and cfg.texture:match("^rbxassetid://%d+$") ~= nil
	local visual = if cfg.ENABLE and hasTexture then Visual.create(cfg, workspace) else nil
	if cfg.ENABLE and not hasTexture then warn("FallVfx: 请先配置已上传的粒子贴图 FallVfxConfig.texture") end
	local lastPosition = deps.hrp.Position
	local destroyed = false

	local function reset()
		State.reset(state)
		if visual then visual.clear() end
	end

	local function update(dt)
		if destroyed or not visual then return end
		local root, humanoid = deps.hrp, deps.humanoid
		if not root.Parent or not deps.character.Parent then reset(); return end
		local position, velocity = root.Position, root.AssemblyLinearVelocity
		local distance = (position - lastPosition).Magnitude
		lastPosition = position
		local teleported = distance > math.max(cfg.teleportMinStuds, velocity.Magnitude * math.max(dt, 0) * 3 + 12)
		local blocked = humanoid.Health <= 0 or deps.isSuppressed() or teleported
			or deps.character:GetAttribute("FallVfxDisabled") == true
		local freefall = humanoid:GetState() == Enum.HumanoidStateType.Freefall
		local airborne = freefall and humanoid.FloorMaterial == Enum.Material.Air
		-- 游泳、攀爬、坐下、Physics 等退出不得保留地面收尾；Jumping 可自然淡出。
		local hs = humanoid:GetState()
		if not freefall and hs ~= Enum.HumanoidStateType.Running
			and hs ~= Enum.HumanoidStateType.Landed and hs ~= Enum.HumanoidStateType.Jumping then
			blocked = true
		end
		local grounded = humanoid.FloorMaterial ~= Enum.Material.Air
			and (hs == Enum.HumanoidStateType.Running or hs == Enum.HumanoidStateType.Landed)
		State.step(state, cfg, dt, -velocity.Y, airborne, blocked, grounded)
		-- 仅发射源跟随角色；世界空间余粒按自身 Size/Lifetime 收缩，着地不硬清除。
		visual.update(position, state, airborne and not blocked)
	end

	return {
		update = update,
		reset = reset,
		getFov = function()
			return state.intensity * cfg.maxFov
		end,
		destroy = function()
			if destroyed then return end
			destroyed = true
			reset()
			if visual then visual.destroy() end
		end,
	}
end

return FallVfx
