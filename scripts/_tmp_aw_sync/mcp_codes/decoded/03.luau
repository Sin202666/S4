local m = game.ReplicatedFirst.AllSideCode.ToolSystem.ArmWrestleConfig
m.Source ..= [=[b)
		return (a.Level or 0) < (b.Level or 0)
	end)
	local list = table.create(#rows)
	for _, row in ipairs(rows) do
		local entry: { [string]: any } = { Value = row.Value }
		local level = row.Level or 0
		if level > 0 then
			entry.Level = level
			entry.Price = row.Price or 0
		end
		table.insert(list, entry)
	end
	return list
end

--[[
	从 awlevelConf + awopponentConf 组装关卡数组（对手按 Power 升序）
	@return {table} - 关卡列表（下标=关卡 Id）
]]
local function _loadLevels(): { { [string]: any } }
	local levelConf = ConfigInstance.awlevelConf or {}
	local oppConf = ConfigInstance.awopponentConf or {}
	local maxLevel = _maxNumericKey(levelConf)
	local byLevel: { [number]: { { [string]: any } } } = {}
	for oppId, row in pairs(oppConf) do
		if type(row) == "table" and type(row.Level) == "number" then
			local level = row.Level
			local bucket = byLevel[level]
			if not bucket then
				bucket = {}
				byLevel[level] = bucket
			end
			table.insert(bucket, {
				Id = oppId,
				ZhName = row.ZhName,
				Model = row.Model,
				Power = row.Power,
				Reward = row.Reward,
				Scale = row.Scale,
			})
		end
	end
	for _, bucket in pairs(byLevel) do
		table.sort(bucket, function(a, b)
			return (a.Power or 0) < (b.Power or 0)
		end)
	end
	local list = table.create(maxLevel)
	for levelId = 1, maxLevel do
		local row = levelConf[levelId]
		if type(row) == "table" then
			local machine: { [string]: any } = {
				Mode = row.MachineMode,
				ZhName = row.MachineZhName,
				Pool = if type(row.Pool) == "table" then row.Pool else {},
			}
			if type(row.MachinePrice) == "number" and row.MachinePrice > 0 then
				machine.Price = row.MachinePrice
			end
			list[levelId] = {
				ZhName = row.ZhName,
				Theme = row.Theme,
				Gate = row.Gate,
				Ground = {
					Mat = row.GroundMat,
					Color = _rgb(row.GroundR, row.GroundG, row.GroundB),
				},
				Icon = row.Icon,
				Opponents = byLevel[levelId] or {},
				Machine = machine,
			}
		end
	end
	return list
end

ArmWrestleConfig.TOOL_NAME = "哑铃"
-- ReplicatedStorage 下的文件夹路径，末端子节点名为 TOOL_NAME
ArmWrestleConfig.TOOL_ASSET_PATH = { "Assets", "ModelRes", "Dumbbell" }
ArmWrestleConfig.WORLD_NAME = "World"
ArmWrestleConfig.BATTLE_OWNER = "ArmWrestle:Battle"
ArmWrestleConfig.WALK_MODIFIER = "ArmWrestle:Walk"
ArmWrestleConfig.STOCK_KEY = "ArmWrestleJudgementSold"
-- 桌子 Model 上由场景烘焙的 R6 玩家入座 HRP CFrame；对手 HRP 为 OppPivot
ArmWrestleConfig.SEAT_ATTR = "R6Seat"
-- 擂台四面有挡墙进不去，对局结束服务端把玩家送到此 HRP CFrame（擂台正面围栏外）
ArmWrestleConfig.EXIT_ATTR = "R6Exit"
ArmWrestleConfig.OPPONENT_MODEL_NAME = "Opponent"
-- AnimationModule/Animation.luau 中的逻辑名；对局拉锯片长 1 秒，TimePosition = P（对手 1-P）
ArmWrestleConfig.ANIM_TRAIN = "AW_Train"
ArmWrestleConfig.ANIM_BATTLE = "AW_Battle"
ArmWrestleConfig.ANIM_WIN = "AW_Win"
ArmWrestleConfig.ANIM_LOSE = "AW_Lose"
-- 桌边对手无人挑战时的循环待机（与玩家地面待机共用一片）
ArmWrestleConfig.ANIM_IDLE = "Idle"
-- ReplicatedStorage 下 KeyframeSequence 源文件夹；未上传前 Studio 内用其注册临时动画预览
ArmWrestleConfig.ANIM_SOURCE_PATH = { "Assets", "Animations", "ArmWrestle" }

-- 以下标量来自 AWConst]=]
return #m.Source
