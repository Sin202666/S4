local folder = game.ReplicatedStorage:FindFirstChild("_TmpAwSync")
if not folder then
	folder = Instance.new("Folder")
	folder.Name = "_TmpAwSync"
	folder.Parent = game.ReplicatedStorage
end
local sub = folder:FindFirstChild("ArmWrestleConfig")
if not sub then
	sub = Instance.new("Folder")
	sub.Name = "ArmWrestleConfig"
	sub.Parent = folder
end
local v = sub:FindFirstChild("2")
if not v then
	v = Instance.new("StringValue")
	v.Name = "2"
	v.Parent = sub
end
v.Value = [=[ow.Model,
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

-- 以下标量来自 AWConst.xlsx；Studio 离线门槛仍用 10 秒便于测试
ArmWrestleConfig.EXIT_PUSH_STUDS = _const("EXIT_PUSH_STUDS", 3)
ArmWrestleConfig.WIN_CINEMATIC_SEC = _const("WIN_CINEMATIC_SEC", 4.6)
ArmWrestleConfig.WIN_RELEASE_DELAY_SEC = _const("WIN_RELEASE_DELAY_SEC", 5.2)
ArmWrestleConfig.LOSE_RELEASE_DELAY_SEC = _const("LOSE_RELEASE_DELAY_SEC", 2.6)
ArmWrestleConfig.LIMITED_ARM_ID = _const("LIMITED_ARM_ID", 12)
ArmWrestleConfig.LIMITED_SOLD_DEFAULT = _const("LIMITED_SOLD_DEFAULT", 96)
ArmWrestleConfig.NEAR_MACHINE_STUDS = _const("NEAR_MACHINE_STUDS", 25)
ArmWrestleConfig.TABLE_PROMPT_DISTANCE = _const("TABLE_PROMPT_DISTANCE", 18)
ArmWrestleConfig.ROLL_ANIM_SEC = _const("ROLL_ANIM_SEC", 3.2)
ArmWrestleConfig.ROLL_COOLDOWN_SEC = ArmWrestleConfig.ROLL_ANIM_SEC
ArmWrestleConfig.FRIEND_BOOST_PER = _const("FRIEND_BOOST_PER", 0.1)
ArmWrestleConfig.FRIEND_BOOST_MAX = _const("FRIEND_BOOST_MAX", 0.5)
ArmWrestleConfig.PREMIUM_BOOST = _const("PREMIUM_BOOST", 0.25)
ArmWrestleConfig.OFFLINE_RATE = _const("OFFLINE_RATE", 0.1)
ArmWrestleConfig.OFFLINE_MIN_SEC = if RunService:IsStudio() then 10 else _const("OFFLINE_MIN_SEC", 300)
ArmWrestleConfig.OFFLINE_MAX_SEC = _const("OFFLINE_MAX_SEC", 28800)
ArmWrestleConfig.MENU_GIFT_CASH_MULT = _const("MENU_GIFT_CASH_MULT", 10)
ArmWrestleConfig.ZoneLength = _const("ZoneLength", 170)
ArmWrestleConfig.ZoneWidth = _const("ZoneWidth", 130)
ArmWrestleConfig.BattleTime = _const("BattleTime", 15)
ArmWrestleConfig.TapPower = _const("TapPower", 0.035)
ArmWrestleConfig.OpponentDrift = _const("OpponentDrift", 0.13)]=]
return #v.Value
