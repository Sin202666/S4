-- 直接加载生产状态机：下落补线速率、落地停发和中断语义。
local State = require("../src/StarterPlayer/StarterCharacterScripts/Animate/FallVfxState")
local Config = require("../src/StarterPlayer/StarterCharacterScripts/Animate/FallVfxConfig")
local passed = 0
local function check(name, run)
	run(); passed += 1; print("PASS " .. name)
end
local function advance(s, seconds, speed, airborne, blocked, fps, grounded)
	local rate = fps or 60
	for _ = 1, math.floor(seconds * rate + 0.5) do
		State.step(s, Config, 1/rate, speed, airborne, blocked == true, grounded)
	end
end
local function falling()
	local s = State.new()
	advance(s, 0.55, 100, true)
	assert(s.fired and s.emitting)
	return s
end

check("standing ascent and normal short hops remain silent", function()
	local s = State.new()
	advance(s, 1, 0, false)
	advance(s, 0.3, -65, true)
	advance(s, 0.3, 60, true)
	assert(not s.fired and s.intensity == 0)
end)
check("high velocity spike cannot bypass duration", function()
	local s = State.new()
	advance(s, 0.1, 170, true)
	assert(not s.fired)
end)
check("slow float cannot trigger by duration alone", function()
	local s = State.new()
	advance(s, 8, 30, true)
	assert(not s.fired)
end)
check("qualified fall builds quickly then replenishes", function()
	local s = falling()
	assert(s.phase == "Burst" and s.emitCount > 0)
	local initial = s.emitCount
	advance(s, 0.12, 100, true)
	assert(s.emitting and s.phase == "Falling" and s.emitCount > initial)
end)
check("long fall keeps a bounded per-second emission rate", function()
	local s = falling()
	local initial = s.emitCount
	advance(s, 10, 160, true)
	assert(s.phase == "Falling" and math.abs(s.emitCount-initial-10*Config.particlesPerSecond)<=1)
end)
check("landing stops additions without requesting a hard clear", function()
	local s = falling()
	State.step(s, Config, 1/60, 0, false, false, true)
	assert(not s.emitting and not s.clear and not s.fired and s.emitCount == 0)
	advance(s, 1, 0, false)
	assert(s.phase == "Idle" and s.intensity == 0)
end)
check("ground contact re-arms the next fall", function()
	local s = falling()
	advance(s, 1, 120, true)
	advance(s, 0.1, 0, false)
	advance(s, 0.55, 100, true)
	assert(s.fired and s.emitting and s.burstAge < Config.rampSec)
end)
check("midair ascent does not re-arm consumed burst", function()
	local s = falling()
	advance(s, 1, -80, false, false, 60, false)
	advance(s, 2, 120, true)
	assert(s.phase == "Spent" and not s.emitting)
end)
check("suppression hard clears and cannot replay during same fall", function()
	local s = falling()
	State.step(s, Config, 1/60, 100, true, true, false)
	assert(s.clear and s.intensity == 0 and s.fired and s.emitCount == 0)
	advance(s, 2, 120, true)
	assert(not s.emitting and s.emitCount == 0)
end)
check("interruption before trigger may arm after release", function()
	local s = State.new()
	advance(s, 0.3, 100, true, true)
	advance(s, 0.55, 100, true)
	assert(s.emitting)
end)
check("repeated short hops cannot accumulate fall distance", function()
	local s = State.new()
	for _ = 1, 20 do advance(s, 0.1, 100, true); advance(s, 0.1, 0, false) end
	assert(not s.fired and s.emitCount == 0)
end)
check("invalid inputs clear without catch-up bursts", function()
	for _, dt in ipairs({0, -1, 1, math.huge, 0/0}) do
		local s = falling(); State.step(s, Config, dt, 100, true, false)
		assert(s.clear and s.intensity == 0 and s.emitCount == 0)
	end
	for _, speed in ipairs({math.huge, -math.huge, 0/0}) do
		local s = falling(); State.step(s, Config, 1/60, speed, true, false)
		assert(s.clear and s.intensity == 0)
	end
end)
check("30 60 144 FPS produce identical counts per emission second", function()
	for _, fps in ipairs({30,60,144}) do
		local s, previous, count, triggers = State.new(), 0, 0, 0
		s.descendingSec, s.dropStuds = 1, 100
		for _ = 1, fps+1 do
			State.step(s, Config, 1/fps, 110, true, false)
			if s.emitCount > previous then
				count += s.emitCount-previous
				if previous==0 then triggers+=1 end
			end
			previous=s.emitCount
		end
		assert(count == 1+Config.particlesPerSecond and triggers == 1)
	end
end)
check("reference preset has no unsupported camera embellishment", function()
	assert(Config.maxFov == 0)
end)
print(string.format("Fall VFX: %d scenarios passed", passed))
