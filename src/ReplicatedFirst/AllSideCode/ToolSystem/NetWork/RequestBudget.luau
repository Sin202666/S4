--[[
	Module: RequestBudget
	Description: 玩家级令牌桶与并发请求限制，跨路由共享；弱键随 Player 回收
	Author: 林奥宇
	Created: 2026-10-12
	Last Modified: 2026-10-12
]]
local RequestBudget = {}
local states = setmetatable({}, { __mode = "k" })
local RATE, BURST, MAX_IN_FLIGHT = 120, 240, 8

--[[ 全部入站请求（包括未知路由）消耗预算。
	@param player Player - 玩家实例
	@param now number - 单调时钟秒数
	@return boolean - 是否放行
]]
function RequestBudget.Take(player, now)
	local state = states[player]
	if not state then state = { tokens = BURST, at = now, active = 0 }; states[player] = state end
	state.tokens = math.min(BURST, state.tokens + math.max(0, now - state.at) * RATE)
	state.at = now
	if state.tokens < 1 then return false end
	state.tokens -= 1
	return true
end

--[[ 在进入可 yield 的业务前获取并发槽。
	@param player Player - 玩家实例
	@return boolean - 是否获得槽位
]]
function RequestBudget.Enter(player)
	local state = states[player]
	if not state or state.active >= MAX_IN_FLIGHT then return false end
	state.active += 1
	return true
end

--[[ handler 成功或异常都释放槽位。
	@param player Player - 玩家实例
	@return nil - 无返回值
]]
function RequestBudget.Leave(player)
	local state = states[player]
	if state then state.active = math.max(0, state.active - 1) end
end

return RequestBudget
