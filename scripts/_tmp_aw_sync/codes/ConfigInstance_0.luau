local folder = game.ReplicatedStorage:FindFirstChild("_TmpAwSync")
if not folder then
	folder = Instance.new("Folder")
	folder.Name = "_TmpAwSync"
	folder.Parent = game.ReplicatedStorage
end
local sub = folder:FindFirstChild("ConfigInstance")
if not sub then
	sub = Instance.new("Folder")
	sub.Name = "ConfigInstance"
	sub.Parent = folder
end
local v = sub:FindFirstChild("0")
if not v then
	v = Instance.new("StringValue")
	v.Name = "0"
	v.Parent = sub
end
v.Value = [=[
local ConfigInstance ={}
ConfigInstance.key={
awarmConf={"ZhName","Mult","Rarity","Price","Robux","ProductKey","Limited","ColorR","ColorG","ColorB","Icon"},
awconstConf={"Value"},
awdumbbellConf={"ZhName","Mult","Rarity","Price","PlateR","PlateG","PlateB","PlateMat","PlateScale","HandleR","HandleG","HandleB","Icon"},
awlevelConf={"ZhName","Theme","Gate","GroundMat","GroundR","GroundG","GroundB","MachineMode","MachineZhName","MachinePrice","Pool"},
awmaterialConf={"ZhName","Mult","Rarity","Weight","Mat","ColorR","ColorG","ColorB","OfferPrice","ProductKey","Icon"},
awopponentConf={"Level","ZhName","Model","Power","Reward","Scale"},
awupgradeConf={"Kind","Level","Value","Price"},
buffdataConf={"isShow","ZhName","buffName","isOver","des","addPower","Icon"},
codeConf={"code","codeType","startTime","endTime","rewardId","rewardNum"},
dailyawardConf={"index","week","AwardID","CountID","BtnColor","BtnIcon"},
enemyConf={"model","","tp","des","ZhName","InjuredSound","animIdleName","animWalkName","animRunName","animHitName","animDieName","animStunName","Ai","boss","xyd","Lv","spMax","moveSkill","moveSkillCd","enablePreCastMove","skill","hpLimitSkill","skillCastMoveSpeedMul","cd","rgMin","rgMax","attackRange","rangerSafeDistance","chaseRunDistance","moveAway","at","atv","atInherit","proactiveDetectionAggro","stunImmune","detectionRange","patientRange","patientTime","idleTime","wanderTime","chaseRunSpeedMul","wanderRange","hitstunDisabled","outOfCombatRegenDelaySeconds","outOfCombatRegenMaxHealthPerSecond","despawnTime","changeSkill","isDeadMan","animWalkRefSpeed","animRunRefSpeed","isindex","World","deathPresentation","EventTp","Icon","eggInitHpRatio","eggRegenPerSec","eggMaxDamagePerHit","eggHatchIds","eggHatchWeights","rangerMaxMoveDistance"},
gamepassitemConf={"ZhName","OnlyTag","UnlockInf","hasCount","tp","Icon","xyd","ColorStr"},
itemdataConf={"ZhName","xyd","UnlockInf","isShow","isBag","hasCount","bagTp","tp","sort","ZhDes","UseNow","UseScript","parms","Icon","Model","init","newPlayerInit","ScriptTypeClient","ScriptTypeServer","ZhEffectDes","noToolbar"},
itemshopdataConf={"ZhName","ZhDes","OnlyTag","NeedBuy","NextBug","BuyLimitNum","gamePassItemID","cost","passID","GiftID","price","oriPrice","itemID","itemCount","Icon","ColorStr"},
mountConf={"ZhName","LocomotionType","Model","SummonCd","CombatPolicy","Icon","xyd","SpeedMul","AttachName","CameraProfile","AnimSet","ExtJson"},
onlineawardConf={"AwardID","CountID","OnlinTime","Icon"},
petConf={"EggName","xyd","tp","SellItem","SellCount","ZhName","Model","PowerAdd"},
peteggConf={"DisName","ZhName","PoolOnlyTag","tp","pool","weight","cost","price","Model"},
settingConf={"ZhName","ShowName","SetType","TempType","set","range","isPecent","ZhDes","isShow","mobieFade"},
skillConf={"ZhName","ScriptName","","","Icon","Priority","Range","EffectTarget","needCheck","isBase","exp","","ElementTp","AttackEffectPos","CD","DamageRate","","buffs","","","","ForceHitAnimation","Size","Band","SummonBand"},
updatelogConf={"UpdateTime","ZhTagTitle","ZhUpdateText"},
}

ConfigInstance.awarmConf={
	[1]={"新手之臂",1,"Common",0,0,"",0,234,184,146,"rbxassetid://74809006284031"},
	[2]={"结实之臂",1.5,"Common",75,0,"",0,205,150,110,"rbxassetid://79060817271352"},
	[3]={"青铜之臂",2,"Uncommon",250,0,"",0,205,127,50,"rbxassetid://78998063862787"},
	[4]={"钢铁之臂",3,"Uncommon",600,0,"",0,160,165,175,"rbxassetid://125017192128258"},
	[5]={"冰晶之臂",4.5,"Rare",1500,0,"",0,110,200,255,"rbxassetid://135758805551826"},
	[6]={"雷霆之臂",6.5,"Rare",4000,0,]=]
return #v.Value
