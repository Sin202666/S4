--[[
	Module: FallVfxConfig
	Description: 黑白漫画下落粒子；全部尺寸为 studs，时间为秒。贴图源文件在 art/vfx/fall。
	Author: 林奥宇
	Created: 2026-10-13
	Last Modified: 2026-10-13
]]
return table.freeze({
	revision = "V3-width-preserving-flipbook",
	ENABLE = true,
	minDownSpeed = 80,
	exitDownSpeed = 26,
	fullDownSpeed = 125,
	minDescendingSec = 0.50,
	minDropStuds = 16,
	attackSec = 0.025,
	releaseSec = 0.12,
	maxFrameSec = 0.25,
	teleportMinStuds = 45,
	maxFov = 0, -- 参考中没有可确认的额外 FOV，默认完全关闭
	texture = "rbxassetid://123981207090182", -- 4×4 等宽收缩序列，art/vfx/fall/fall-stroke-flipbook-v3.png
	rampSec = 0.07, -- 参考约2帧内铺开；之后持续补入，着地当帧停发
	emitterHeight = 1,
	emitterExtent = 3.6,
	emitterVerticalExtent = 8,
	particleSize = 1.9,
	particleSizeVariance = 0.20,
	lifetimeMin = 0.17,
	lifetimeMax = 0.24,
	particlesPerSecond = 90, -- 每色原生 Rate，约37粒同时存活，低帧率不再手动成簇补发
	upwardDrift = 42, -- 快速擦过，避免缓慢漂浮；不锁在角色上
})
