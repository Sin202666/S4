
local ConfigInstance ={}
ConfigInstance.key={
awarmConf={"ZhName","Mult","Xyd","Price","Robux","ProductKey","Limited","ColorR","ColorG","ColorB","Icon"},
awconstConf={"Value","Remark"},
awdumbbellConf={"ZhName","Mult","Xyd","Price","PlateR","PlateG","PlateB","PlateMat","PlateScale","HandleR","HandleG","HandleB","Icon"},
awenemyConf={"Level","ZhName","Model","Power","Reward","Scale"},
awlevelConf={"ZhName","Theme","Gate","GroundMat","GroundR","GroundG","GroundB","MachineMode","MachineZhName","Pool","PoolWeights","Icon"},
awmaterialConf={"ZhName","Mult","Xyd","Mat","ColorR","ColorG","ColorB","Price","ProductKey","Icon"},
awupgradeConf={"Kind","Level","Value","Price"},
buffdataConf={"isShow","ZhName","buffName","isOver","des","addPower","Icon"},
codeConf={"code","codeType","startTime","endTime","rewardId","rewardNum"},
dailyawardConf={"index","week","AwardID","CountID","BtnColor","BtnIcon"},
enemyConf={"model","","tp","des","ZhName","InjuredSound","animIdleName","animWalkName","animRunName","animHitName","animDieName","animStunName","Ai","boss","xyd","Lv","spMax","moveSkill","moveSkillCd","enablePreCastMove","skill","hpLimitSkill","skillCastMoveSpeedMul","cd","rgMin","rgMax","attackRange","rangerSafeDistance","chaseRunDistance","moveAway","at","atv","atInherit","proactiveDetectionAggro","stunImmune","detectionRange","patientRange","patientTime","idleTime","wanderTime","chaseRunSpeedMul","wanderRange","hitstunDisabled","outOfCombatRegenDelaySeconds","outOfCombatRegenMaxHealthPerSecond","despawnTime","changeSkill","isDeadMan","animWalkRefSpeed","animRunRefSpeed","isindex","World","deathPresentation","EventTp","Icon","eggInitHpRatio","eggRegenPerSec","eggMaxDamagePerHit","eggHatchIds","eggHatchWeights","rangerMaxMoveDistance"},
gamepassitemConf={"ZhName","OnlyTag","UnlockInf","hasCount","tp","Icon","xyd","ColorStr"},
itemdataConf={"ZhName","xyd","UnlockInf","isShow","isBag","hasCount","bagTp","tp","sort","ZhDes","UseNow","UseScript","parms","Icon","Model","init","newPlayerInit","ScriptTypeClient","ScriptTypeServer","ZhEffectDes","noToolbar"},
itemshopdataConf={"ZhName","ZhDes","OnlyTag","NeedBuy","NextBug","BuyLimitNum","gamePassItemID","cost","passID","GiftID","price","oriPrice","itemID","itemCount","Icon","ColorStr","Kind","Tier","Mult","Amount","ArmId","MatId"},
mountConf={"ZhName","LocomotionType","Model","SummonCd","CombatPolicy","Icon","xyd","SpeedMul","AttachName","CameraProfile","AnimSet","ExtJson"},
onlineawardConf={"AwardID","CountID","OnlinTime","Icon"},
petConf={"EggName","xyd","tp","SellItem","SellCount","ZhName","Model","PowerAdd"},
peteggConf={"DisName","ZhName","PoolOnlyTag","tp","pool","weight","cost","price","Model"},
settingConf={"ZhName","ShowName","SetType","TempType","set","range","isPecent","ZhDes","isShow","mobieFade"},
skillConf={"ZhName","ScriptName","","","Icon","Priority","Range","EffectTarget","needCheck","isBase","exp","","ElementTp","AttackEffectPos","CD","DamageRate","","buffs","","","","ForceHitAnimation","Size","Band","SummonBand"},
updatelogConf={"UpdateTime","ZhTagTitle","ZhUpdateText"},
}

ConfigInstance.awarmConf={
	[1]={"新手之臂",1,1,0,0,"",0,234,184,146,"rbxassetid://74809006284031"},
	[2]={"结实之臂",1.5,1,75,0,"",0,205,150,110,"rbxassetid://79060817271352"},
	[3]={"青铜之臂",2,2,250,0,"",0,205,127,50,"rbxassetid://78998063862787"},
	[4]={"钢铁之臂",3,2,600,0,"",0,160,165,175,"rbxassetid://125017192128258"},
	[5]={"冰晶之臂",4.5,3,1500,0,"",0,110,200,255,"rbxassetid://135758805551826"},
	[6]={"雷霆之臂",6.5,3,4000,0,"",0,255,230,60,"rbxassetid://98827391711336"},
	[7]={"翡翠之臂",9,4,10000,0,"",0,60,220,110,"rbxassetid://104373057742300"},
	[8]={"紫晶之臂",13,4,40000,0,"",0,170,80,255,"rbxassetid://116669000221342"},
	[9]={"烈焰之臂",18,4,150000,0,"",0,255,110,30,"rbxassetid://125285035215604"},
	[10]={"深渊之臂",25,4,600000,0,"",0,200,30,60,"rbxassetid://82645023916736"},
	[11]={"神圣之臂",40,5,0,249,"HolyArm",0,255,215,90,"rbxassetid://75627413068113"},
	[12]={"审判之臂",60,5,0,399,"JudgementArm",0,30,30,40,"rbxassetid://106638998049834"}
}

ConfigInstance.awconstConf={
	["EXIT_PUSH_STUDS"]={3,"出场时沿 EXIT 朝向外推的距离（studs）"},
	["WIN_CINEMATIC_SEC"]={4.6,"获胜演出总时长（秒）；服务端交还控制须大于它"},
	["WIN_RELEASE_DELAY_SEC"]={5.2,"获胜后服务端交还控制/出场延迟（秒）"},
	["LOSE_RELEASE_DELAY_SEC"]={2.6,"失败后服务端交还控制/出场延迟（秒）"},
	["LIMITED_ARM_ID"]={12,"限量手臂 Id（审判之臂）"},
	["LIMITED_SOLD_DEFAULT"]={96,"限量臂已售默认值（全服库存展示兜底）"},
	["NEAR_MACHINE_STUDS"]={25,"靠近材质箱的判定距离（studs）"},
	["TABLE_PROMPT_DISTANCE"]={18,"比赛桌扳手腕 E 交互距离（studs）"},
	["ROLL_ANIM_SEC"]={3.2,"材质箱抽取 3D 表演总秒数；冷却与之对齐"},
	["FRIEND_BOOST_PER"]={0.1,"同服每位好友现金加成（+10%）"},
	["FRIEND_BOOST_MAX"]={0.5,"好友现金加成封顶（+50%）"},
	["PREMIUM_BOOST"]={0.25,"Roblox 会员现金加成（+25%）"},
	["OFFLINE_RATE"]={0.1,"离线力量折算：在线挂机效率的 10%"},
	["OFFLINE_MIN_SEC"]={300,"离线最短门槛（秒）；线上 5 分钟，Studio 代码内改为 10 秒"},
	["OFFLINE_MAX_SEC"]={28800,"离线累计封顶（秒，8 小时）"},
	["MENU_GIFT_CASH_MULT"]={10,"菜单挽留礼物：已解锁关最强对手奖励 × 本倍数"},
	["ZoneLength"]={170,"单关世界区 X 向长度（studs）"},
	["ZoneWidth"]={130,"单关世界区 Z 向宽度（studs）"},
	["BattleTime"]={15,"扳手腕对局时长（秒）"},
	["TapPower"]={0.035,"单次点击对进度条贡献"},
	["OpponentDrift"]={0.13,"对手持续回推强度；需持续点击才能压住"},
	["MaxTapsPerSecond"]={14,"玩家点击速率上限（防脚本）"},
	["AutoTapsPerSecond"]={8,"自动点击通行证每秒点击次数"}
}

ConfigInstance.awdumbbellConf={
	[1]={"训练哑铃",1,1,0,35,35,40,"Metal",1,190,190,200,"rbxassetid://79149397540649"},
	[2]={"铁片哑铃",1.3,1,150,110,110,120,"DiamondPlate",1.05,190,190,200,"rbxassetid://108608298227670"},
	[3]={"青铜哑铃",1.7,2,600,205,127,50,"Metal",1.1,150,95,45,"rbxassetid://91634863308487"},
	[4]={"白银哑铃",2.2,2,2000,215,220,230,"Metal",1.15,160,165,175,"rbxassetid://83444554423906"},
	[5]={"黄金哑铃",3,3,7000,255,200,40,"Metal",1.2,200,150,30,"rbxassetid://134229591004130"},
	[6]={"冰晶哑铃",4,3,25000,120,210,255,"Ice",1.25,210,240,255,"rbxassetid://94366573381853"},
	[7]={"翡翠哑铃",5.5,4,90000,40,210,110,"Glass",1.3,30,120,70,"rbxassetid://119581829333036"},
	[8]={"紫晶哑铃",7.5,4,350000,170,80,255,"Glass",1.35,90,40,140,"rbxassetid://99369701283844"},
	[9]={"熔岩哑铃",10,4,1200000,255,100,30,"CrackedLava",1.4,60,40,40,"rbxassetid://108797683466319"},
	[10]={"钻石哑铃",14,4,5000000,120,240,255,"Neon",1.5,230,250,255,"rbxassetid://104387525439155"}
}

ConfigInstance.awenemyConf={
	["L1_1"]={1,"稻草人","Scarecrow",5,25,1},
	["L1_2"]={1,"木头人","Wooden",15,60,1.1},
	["L1_3"]={1,"树桩怪","Stump",40,150,1.25},
	["L2_1"]={2,"小石怪","Rock",120,400,0.9},
	["L2_2"]={2,"石头人","Rock",300,900,1.15},
	["L2_3"]={2,"岩石巨人","Rock",700,2000,1.45},
	["L3_1"]={3,"小仙人掌","Cactus",2000,5000,0.9},
	["L3_2"]={3,"仙人掌战士","Cactus",5000,12000,1.15},
	["L3_3"]={3,"仙人掌之王","CactusKing",12000,28000,1.4},
	["L4_1"]={4,"小雪人","Snowman",35000,60000,0.9},
	["L4_2"]={4,"大雪人","Snowman",90000,140000,1.2},
	["L4_3"]={4,"雪怪","Yeti",220000,320000,1.4},
	["L5_1"]={5,"熔岩小鬼","Lava",600000,700000,0.9},
	["L5_2"]={5,"熔岩巨人","Lava",1500000,1600000,1.2},
	["L5_3"]={5,"火山之王","LavaKing",4000000,4000000,1.5}
}

ConfigInstance.awlevelConf={
	[1]={"青草公园","Grass",0,"Grass",100,175,70,"Offer","材质木箱",{"Sand","Wood","Grass"},{60,48,30},"rbxassetid://118758086815883"},
	[2]={"岩石峡谷","Stone",60,"Slate",120,125,140,"Offer","岩石石箱",{"Wood","Grass","Snow","Rock"},{48,30,22,12},"rbxassetid://127921458019937"},
	[3]={"炙热沙漠","Desert",800,"Sand",225,200,140,"Offer","沙漠宝箱",{"Snow","Rock","Metal","Water"},{22,12,8,5},"rbxassetid://139210106756500"},
	[4]={"冰雪山地","Snow",15000,"Snow",235,242,250,"Offer","冰晶宝箱",{"Metal","Water","Brick","Magma"},{8,5,3,1.5},"rbxassetid://113424466396348"},
	[5]={"熔岩火山","Lava",250000,"Basalt",55,45,45,"Offer","熔岩宝箱",{"Brick","Magma","Neon","Diamond"},{3,1.5,0.8,0.4},"rbxassetid://139384037064283"}
}

ConfigInstance.awmaterialConf={
	["Sand"]={"沙子",1.2,1,"Sand",226,205,145,40,"","rbxassetid://122192010470765"},
	["Wood"]={"木头",1.5,1,"Wood",160,110,60,80,"","rbxassetid://128126726660785"},
	["Grass"]={"草地",2,2,"Grass",90,170,60,150,"","rbxassetid://126845964848626"},
	["Snow"]={"冰雪",2.5,2,"Snow",235,245,255,500,"","rbxassetid://122005236129409"},
	["Rock"]={"岩石",3.5,3,"Slate",110,110,120,1500,"","rbxassetid://130795413314674"},
	["Metal"]={"金属",5,3,"DiamondPlate",170,175,185,5000,"","rbxassetid://126111622075252"},
	["Water"]={"流水",7,4,"Glass",60,150,255,15000,"","rbxassetid://116870538790500"},
	["Brick"]={"砖块",10,4,"Brick",170,70,50,50000,"","rbxassetid://124670707684711"},
	["Magma"]={"岩浆",15,4,"CrackedLava",255,100,30,200000,"","rbxassetid://104796958921544"},
	["Neon"]={"霓虹",25,4,"Neon",255,60,200,800000,"","rbxassetid://81720242495997"},
	["Diamond"]={"钻石",40,5,"Glass",120,240,255,2000000,"","rbxassetid://100212317246111"},
	["Arcane"]={"奥术",100,5,"ForceField",170,80,255,0,"ArcaneMaterial","rbxassetid://110621231829163"}
}

ConfigInstance.awupgradeConf={
	[1]={"TrainSpeed",0,1,0},
	[2]={"TrainSpeed",1,0.8,50},
	[3]={"TrainSpeed",2,0.6,500},
	[4]={"TrainSpeed",3,0.45,6000},
	[5]={"TrainSpeed",4,0.35,80000},
	[6]={"TrainSpeed",5,0.25,900000},
	[7]={"WalkSpeed",0,16,0},
	[8]={"WalkSpeed",1,20,150},
	[9]={"WalkSpeed",2,24,1500},
	[10]={"WalkSpeed",3,28,20000},
	[11]={"WalkSpeed",4,32,250000},
	[12]={"WalkSpeed",5,36,2000000}
}

ConfigInstance.buffdataConf={
}

ConfigInstance.codeConf={
	[1]={"NEWGAME",1,0,0,{202},{1}}
}

ConfigInstance.dailyawardConf={
	[1]={1,1,2,10,"2","86589195945629"},
	[2]={2,1,2,10,"3","86589195945629"},
	[3]={3,1,2,10,"4","86589195945629"},
	[4]={4,1,2,10,"4","86589195945629"},
	[5]={5,1,2,10,"4","86589195945629"},
	[6]={6,1,2,10,"5","86589195945629"},
	[7]={7,1,2,10,"4","86589195945629"},
	[8]={1,2,2,10,"3","86589195945629"},
	[9]={2,2,2,10,"3","86589195945629"},
	[10]={3,2,2,10,"4","86589195945629"},
	[11]={4,2,2,10,"4","86589195945629"},
	[12]={5,2,2,10,"4","86589195945629"},
	[13]={6,2,2,10,"5","86589195945629"},
	[14]={7,2,2,10,"5","86589195945629"},
	[15]={1,3,2,10,"4","86589195945629"},
	[16]={2,3,2,10,"4","86589195945629"},
	[17]={3,3,2,10,"5","86589195945629"},
	[18]={4,3,2,10,"5","86589195945629"},
	[19]={5,3,2,10,"4","86589195945629"},
	[20]={6,3,2,10,"5","86589195945629"},
	[21]={7,3,2,10,"5","86589195945629"}
}

ConfigInstance.enemyConf={
	[5011001]={"近战哥布林","1",5,"矮人描述","近战哥布林","受击-哥布林1","人型待机R6-2","人型行走R6-3","人型奔跑R6-2","人型受击R6-1","人型死亡R6","人型眩晕R6","Ranger","0",1,1,"","","","",{10300001},{},{1},{3},{0},{6},4,0,3,0,{1,5,9},{10,21,12},{},1,"",200,200,0,{},{},2,{},0,"0","1",3,3,0,16,24,1,1,"",0,"","","","",{},{},""}
}

ConfigInstance.gamepassitemConf={
	[3000003]={"自动点击","AutoClicker",1,1,3,0,3,"蓝"},
	[3000004]={"2 倍力量","DoubleStrength",1,1,3,0,3,"橙"},
	[3000005]={"2 倍金钱","DoubleCash",1,1,3,0,3,"绿"}
}

ConfigInstance.itemdataConf={
	[1]={"金钱",5,1,1,0,1,0,0,0,"Gem",0,"0",{"0"},90521258639290,"","0","10",{},{},"",0},
	[2]={"宝石",5,1,1,0,1,0,0,0,"zuanshi",0,"0",{"0"},103812808522717,"Gem","0","0",{},{},"",0},
	[201]={"力量药水",4,1,1,0,1,0,1,1,"力量药水描述",0,"ArmWrestlePotion",{"StrengthPotion"},120013088141721,"","0","0",{},{},"",1},
	[202]={"训练速度药水",4,1,1,0,1,0,1,2,"训练速度药水描述",0,"ArmWrestlePotion",{"TrainSpeedPotion"},106581559588513,"","0","0",{},{},"",1},
	[203]={"金币药水",4,1,1,0,1,0,1,3,"金币药水描述",0,"ArmWrestlePotion",{"CashPotion"},73520282041364,"","0","0",{},{},"",1}
}

ConfigInstance.itemshopdataConf={
	[1]={"双倍幸运","双倍幸运描述","LuckX2","","","","",2,1489329041,"3412848849",199,"",{},{},{"119377429859111"},"2","",0,0,0,0,""},
	[2]={"机器礼包1","机器礼包1描述","MachinePack1","","","","",1,3412830887,"3412835012",69,"",{8100003,8200002},{1},{"128053029377978","127280162932038"},"3","",0,0,0,0,""},
	[3]={"一键解锁在线奖励","","OnlineAwardClaimAll","","","","",1,3612011629,"",79,"",{},{},{},"","",0,0,0,0,""},
	[4]={"自动点击","训练和扳手腕自动点击","AutoClicker","","","","3000003",2,2038076866,"",99,"",{},{},{},"","",0,0,0,0,""},
	[5]={"2 倍力量","永久获得双倍力量","DoubleStrength","","","","3000004",2,2037770817,"",149,"",{},{},{},"","",0,0,0,0,""},
	[6]={"2 倍金钱","永久获得双倍金钱","DoubleCash","","","","3000005",2,2036546863,"",129,"",{},{},{},"","",0,0,0,0,""},
	[7]={"力量倍数","力量倍数 x2","StrengthTier1","","","","",1,3718923863,"",19,"",{},{},{},"","StrengthTier",1,2,0,0,""},
	[8]={"力量倍数","力量倍数 x4","StrengthTier2","","","","",1,3718923869,"",49,"",{},{},{},"","StrengthTier",2,4,0,0,""},
	[9]={"力量倍数","力量倍数 x8","StrengthTier3","","","","",1,3718923875,"",99,"",{},{},{},"","StrengthTier",3,8,0,0,""},
	[10]={"力量倍数","力量倍数 x16","StrengthTier4","","","","",1,3718923881,"",199,"",{},{},{},"","StrengthTier",4,16,0,0,""},
	[11]={"力量倍数","力量倍数 x32","StrengthTier5","","","","",1,3718923891,"",399,"",{},{},{},"","StrengthTier",5,32,0,0,""},
	[12]={"力量倍数","力量倍数 x64","StrengthTier6","","","","",1,3718923897,"",799,"",{},{},{},"","StrengthTier",6,64,0,0,""},
	[13]={"力量包","力量包 200 次训练","StrengthPack1","","","","",1,3718923901,"",19,"",{},{},{},"","Strength",0,0,200,0,""},
	[14]={"力量包","力量包 2000 次训练","StrengthPack2","","","","",1,3718923908,"",99,"",{},{},{},"","Strength",0,0,2000,0,""},
	[15]={"力量包","力量包 20000 次训练","StrengthPack3","","","","",1,3718923917,"",299,"",{},{},{},"","Strength",0,0,20000,0,""},
	[16]={"力量药水","力量药水描述","StrengthPotion","","","","",1,3718923922,"",49,"",{201},{1},{},"","",0,0,0,0,""},
	[17]={"训练速度药水","训练速度药水描述","TrainSpeedPotion","","","","",1,3718923927,"",49,"",{202},{1},{},"","",0,0,0,0,""},
	[18]={"金币药水","金币药水描述","CashPotion","","","","",1,3718923937,"",49,"",{203},{1},{},"","",0,0,0,0,""},
	[19]={"神圣之臂","40 倍力量手臂","HolyArm","","","","",1,0,"",249,"",{},{},{},"","Arm",0,0,0,11,""},
	[20]={"审判之臂","60 倍力量手臂","JudgementArm","","","","",1,0,"",399,"",{},{},{},"","Arm",0,0,0,12,""},
	[21]={"奥术材质","100 倍力量材质","ArcaneMaterial","","","","",1,0,"",499,"",{},{},{},"","Material",0,0,0,0,"Arcane"}
}

ConfigInstance.mountConf={
	[6001001]={"独角兽","GroundMount","独角兽",3,"ForceExit","",3,1.5,"MountSaddle","MountGround","MountUnicorn","{\"AccelSec\":0.9,\"DecelSec\":1.35,\"TurnRateDeg\":220,\"TurnHighSpeedMul\":0.38,\"TurnSpeedPow\":1.35,\"TurnAlignMin\":0.65,\"TurnAlignPow\":1.1,\"AboutFaceDot\":-0.75,\"AboutFaceAlignMin\":0,\"AboutFaceTurnMul\":2.9,\"AboutFaceBrake\":160,\"AboutFaceCompleteDeg\":12,\"AboutFaceStickBack\":0.9,\"AboutFaceCooldownSec\":0.2,\"AirTurnMul\":0.85,\"AirFlipTurnMul\":2.6,\"DoubleJumpFlipWindowSec\":0.4,\"AirFlipVelAlign\":8,\"DoubleJumpVelBlend0\":0.45,\"DoubleJumpRedirectSec\":0.22,\"JumpHeight\":22,\"DoubleJumpSpeed\":55,\"AirGravityScale\":0.72,\"CanDoubleJump\":1,\"AirThrottleMul\":1,\"AirFlipThrottleMul\":1,\"AirSpeedMaintainSoft\":0.9,\"AirSpeedLeanRate\":8,\"AirCoastDecel\":6,\"FirstJumpMinFlat\":16,\"FirstJumpSnapFrac\":0.6,\"FirstJumpRampSec\":0.06,\"FirstJumpLookAbsorb\":0.08,\"LeapPushSec\":0.24,\"LeapPushAccel\":55,\"LeapPushPow\":1.35,\"LeapStandPushMul\":1.2,\"LeapGallopPushMul\":0.45,\"DoubleJumpPushSec\":0.22,\"DoubleJumpPushAccel\":70,\"AboutFaceTravelDot\":-0.75,\"TurnCruiseDot\":0.85,\"TurnPivotBackStuds\":3.5,\"DoubleJumpMinFlat\":18,\"DriveMode\":\"MountRoot\",\"GroundClearance\":0.08,\"WalkSpeedMul\":0.42,\"GallopEnterThrottle\":0.82,\"GallopEnterHoldSec\":0.55,\"GallopExitThrottle\":0.28,\"WalkAccelSec\":0.5,\"GallopAccelSec\":1.05,\"SlipDecelSec\":1.85,\"BrakeDecelSec\":0.55,\"BrakeSpeed01\":0.36,\"DoubleJumpAirDelaySec\":0.12}"},
	[6002001]={"测试吉普","WheeledVehicle","Mount_Jeep_Test",5,"ForceExit","",2,0,"","MountVehicle","","{\"MaxSpeed\":80,\"Acceleration\":40,\"TurnRadius\":12}"},
	[6003001]={"测试飞龙","FlyingCreature","Mount_Dragon_Test",8,"ForceExit","",4,0,"MountDragon","MountFlying","MountDragonBasic","{\"MaxAltitude\":200,\"ClimbRate\":40,\"DescendRate\":35,\"HoverAllowed\":1}"},
	[6004001]={"测试直升机","Aircraft","Mount_Helicopter_Test",10,"ForceExit","",4,0,"PilotSeat","MountAircraft","MountHeliBasic","{\"ControlScheme\":\"Helicopter\",\"MaxSpeed\":90,\"HoverThrust\":50}"}
}

ConfigInstance.onlineawardConf={
	[1]={1,100,300,""},
	[2]={1,200,600,""},
	[3]={1,400,900,""},
	[4]={1,800,1200,""},
	[5]={1,1500,1500,""},
	[6]={1,3000,1800,""},
	[7]={1,5000,2100,""},
	[8]={1,8000,2400,""},
	[9]={1,12000,2700,""},
	[10]={1,20000,3000,""},
	[11]={1,30000,3300,""},
	[12]={1,50000,3600,""}
}

ConfigInstance.petConf={
	[5001101]={"宠物蛋1",2,5,{1,2},{1,1},"排球狗","排球狗",1.2},
	[5001102]={"宠物蛋1",3,5,{1,2},{1,1},"乒乓球兔","乒乓球兔",1.5},
	[5001103]={"宠物蛋1",4,5,{1,2},{1,1},"篮球熊","篮球熊",2},
	[5001201]={"宠物蛋2",2,5,{1,2},{1,1},"铅笔蜂","铅笔蜂",2},
	[5001202]={"宠物蛋2",3,5,{1,2},{1,1},"书本熊","书本熊",3},
	[5001203]={"宠物蛋2",4,5,{1,2},{1,1},"尺子豹","尺子豹",4},
	[5001204]={"宠物蛋2",5,5,{1,2},{1,1},"博士猴","博士猴",5},
	[5001301]={"宠物蛋3",2,5,{1,2},{1,1},"兔子向导","兔子向导",5},
	[5001302]={"宠物蛋3",3,5,{1,2},{1,1},"探险松鼠","探险松鼠",6},
	[5001303]={"宠物蛋3",4,5,{1,2},{1,1},"矿工猫猫","矿工猫猫",7},
	[5001304]={"宠物蛋3",80,5,{1,2},{1,1},"寻宝豹","寻宝豹",10}
}

ConfigInstance.peteggConf={
	[7000001]={"Egg1","Egg1","Egg1",7,{5001101,5001102,5001103},{524000,300000,110000},1,2,"宠物蛋1"},
	[7000002]={"Egg2","Egg2","Egg2",7,{5001201,5001202,5001203,5001204},{524000,300000,110000,50000},1,300,"宠物蛋2"},
	[7000003]={"Egg3","Egg3","Egg3",7,{5001301,5001302,5001303,5001304},{524000,300000,110000,50000},1,2000,"宠物蛋3"}
}

ConfigInstance.settingConf={
	[1]={"称号","EquipTitle",1,3,0,{},"",{},1,""},
	[2]={"兑换码","Code",1,4,0,{},"",{"请输入兑换码"},1,""},
	[3]={"背景音乐","BGM",2,1,100,{0,100},"",{},1,""},
	[4]={"游戏音效","EFFECT",2,1,100,{0,100},"",{},1,""},
	[5]={"任务","TASK",5,0,0,{0,1},"",{"关闭","开启"},0,""},
	[6]={"图像质量","GraphicsQuality",3,3,1,{0,1},"",{"低","高"},1,""},
	[7]={"界面尺寸","PopScale",3,1,100,{75,100},"",{},0,""},
	[8]={"快捷栏尺寸","ToolScale",3,1,100,{50,150},"",{},0,""},
	[9]={"物理效果","Pyhsic",3,2,1,{0,1},"",{"关闭","开启"},1,""},
	[10]={"屏幕震动","Shake",3,1,100,{0,100},"",{},1,""},
	[11]={"瞄准模式","AILock",4,3,1,{0,1},"",{"跟随鼠标","智能锁定"},1,"1"},
	[12]={"自动锁敌","TargetSelectMode",4,3,0,{0,1},"",{"锁定当前目标","锁定最近目标"},1,""},
	[13]={"长按攻击","HoldAtk",4,2,1,{0,1},"",{"关闭","开启"},1,""},
	[14]={"隐藏头部饰品","HideSelfHat",5,2,0,{0,1},"",{"关闭","开启"},1,""},
	[15]={"隐藏巫师袍","HideSelfRobe",5,2,0,{0,1},"",{"关闭","开启"},1,""},
	[16]={"隐藏种族外观","HideRace",5,2,0,{0,1},"",{"关闭","开启"},1,""},
	[17]={"视野范围","FieldOfView",5,1,70,{50,90},"",{},0,""},
	[18]={"掉落物模型","TipsItem",5,2,1,{0,1},"",{"关闭","开启"},1,""},
	[19]={"显示他人信息","ShowOtherPlrInfo",5,2,1,{0,1},"",{"关闭","开启"},1,""},
	[20]={"用户界面","HideUI",5,2,1,{0,1},"",{"关闭","开启"},1,""},
	[21]={"自动加点","AutoAttrPoint",5,2,1,{0,1},"",{"关闭","开启"},0,""},
	[22]={"记忆快速炼金","AutoGame3",5,2,0,{0,1},"",{},0,""},
	[23]={"奔跑模式","RunMode",4,3,0,{0,1},"",{"一键切换","长按奔跑"},1,""}
}

ConfigInstance.skillConf={
	[10000002]={"冲刺","NewRoll","","玩家基础技能","",1,0,1,0,0,0,"向前冲刺一段距离",0,3,2,{0},"",{},"基础技能","","","",{1},{1,1},{}},
	[10000010]={"演示施法","SkillDemoCast","","框架样例","",1,0,1,0,0,0,"短施法锁移动样例",0,3,2,{0},"",{},"主动技能","","","",{1},{1,1},{}},
	[10000011]={"陨石术","Meteor","","框架样例","",1,50,1,0,2,120,"在目标位置召唤一枚陨石",2,3,2,{1},"",{},"主动技能","","","",{0.6},{1,2},{}},
	[10000012]={"空间技能","SpaceSkill","","框架样例","",1,80,1,0,2,0,"空间裂缝双球表现（纯表现首版）",0,3,12,{0},"",{},"主动技能","","","",{1},{1,1},{}}
}

ConfigInstance.updatelogConf={
	[1]={1778839200,"更新_页签标题_1",{"更新_内容标题_1","更新_内容_1_1","更新_内容_1_2","更新_内容_1_3"}}
}
return ConfigInstance
