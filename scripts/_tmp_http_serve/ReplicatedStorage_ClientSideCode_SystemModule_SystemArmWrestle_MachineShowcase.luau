--[[
	Module: MachineShowcase
	Description: 材质箱概率牌（宠物模拟器式奖池牌子）与箱子开盖抽取表演，纯客户端表现
	Author: 程莘
	Created: 2026-10-15
	Last Modified: 2026-10-16

	功能：
	- 概率牌：场景里每台 Machine_N 旁的立牌模型 OddsSign_N（Studio 摆放，编辑态可见），运行时在其 SignFace 正面贴 SurfaceGui：
	  顶部为单价（扭蛋模式），下面横排该关 Machine.Pool 的材质格子：稀有度色底 + 描边、材质名、手臂小图（ViewportFrame）、
	  抽中概率（ArmWrestleConfig.PoolOdds）；排版随牌面尺寸自适应
	- HUD 报价条打开期间（SetOfferOpen）隐藏该箱子的 Prompt，改由报价条的「换一个」接管 E 键
	- 已拥有的材质小图显示真实颜色与材质；未拥有为黑色剪影 + 白边
	- 抽取表演 PlayRoll：上一抽的手臂缩回箱内（开着的箱子不合盖，直接重抽）→ 开盖（已开则跳过）→ 黑色手臂从箱内升起，忽大忽小并逐渐减速，
	  描边在奖池各稀有度颜色间随机跳动 → 定格为抽中材质（稀有度色描边 + 粒子 + 名称 / 稀有度 / 力量倍率牌）
	- 定格后的手臂留在打开的箱子上方慢慢自转，直到该箱子下一次抽取或玩家在报价条点关闭放弃（DiscardShown：缩回 + 合盖）；
	  机器流出再流入时按本地状态恢复盖子开合
	- 表演期间本地禁用该机器 Prompt；抽中材质的格子在定格后才解锁，避免档案同步先于表演剧透
	- 表演音效（逐步滚动声 / 定格）经 RollSfx 本机播放

	约束：
	- 抽取结果以服务端 Economy.OnMachine / OfferNext 下发为准，本模块只做表现、不参与结算
	- 概率牌 SurfaceGui 挂在 PlayerGui（ResetOnSpawn = false）：挂在 Workspace 下的 SurfaceGui 不渲染 ViewportFrame；
	  经 Adornee 贴到 SignFace，牌面流出再流入时重新指向
	- 表演模型是本地实例，挂在 Workspace.ArmWrestleShowcase（不随 StreamingEnabled 流出而销毁）；其 CFrame / Size 只由本模块写
	- 场景约定：Machine_N 下 Main 为箱体（挂 Prompt），Lid 为盖子 Model，Pivot 在后上沿铰链处、绕本地 X 轴正向旋转为打开；
	  盖子的本地开合只由 _applyLid 写（服务端不动盖子，流入时读到的 Pivot 即合盖姿态）
	- 场景约定：立牌 OddsSign_N 为 Machine_N 所在 Zone 下的兄弟模型（不放进 Machine_N，以免改变箱子包围盒），
	  牌面部件名 SignFace，正面（Front）朝向玩家
	- Prompt.Enabled 只由 _refreshMachine 写（表演中 / 报价条打开两种状态合成）
	- Roblox 同屏 Highlight 有上限（31）：表演 / 定格手臂每台箱子至多 1 个

	用法（客户端 SystemArmWrestle）：
		local MachineShowcase = require(script.MachineShowcase)
		MachineShowcase.BindWorld(world)
		-- HUD 收到 Offer / Result 后先等表演定格，再弹报价条 / 飘字
		hud.SetRollFx(MachineShowcase.PlayRoll)
		-- 报价条显隐时通知，打开期间隐藏该箱子 Prompt
		hud.SetOfferFx(MachineShowcase.SetOfferOpen)
		-- 报价条点关闭 = 放弃：收回手臂并合盖
		hud.SetDiscardFx(MachineShowcase.DiscardShown)
]]

local Utils = require(game.ReplicatedFirst.AllSideCode.UtilsSystem)
local Workspace = game:GetService("Workspace")
local RunService = Utils.RunService
local TweenService = Utils.TweenService
local LocalPlayer = Utils.LocalPlayer
local ArmWrestleConfig = Utils.ArmWrestleConfig
local ArmWrestleStyle = Utils.ArmWrestleStyle
local PlayerData = Utils.PlayerData
local TranslationHelper = Utils.TranslationHelper
local RollSfx = require(script.Parent.RollSfx)

local MachineShowcase = {}

local C = ArmWrestleStyle.Colors
local MACHINE_PATTERN = "^Machine_(%d+)$"
local SIGN_PATTERN = "^OddsSign_(%d+)$"
local SIGN_FACE_NAME = "SignFace"
local SHOWCASE_FOLDER = "ArmWrestleShowcase"
local PROMPT_NAME = "Prompt"
local LID_NAME = "Lid"
-- R6 手臂外形
local ARM_SIZE = Vector3.new(1, 2, 1)
local ROLL_SCALE = 2
local LOCKED_COLOR = Color3.new(0, 0, 0)
local LOCKED_OUTLINE = Color3.new(1, 1, 1)
-- 概率牌面（studs）：单价行高、内边距
local PRICE_HEIGHT = 0.8
local SIGN_PAD = 0.3
local SIGN_PIXELS_PER_STUD = 50
local SIGN_MAX_DIST = 80
local TILE_PAD = 0.04
local TILE_DARKEN = 0.55
local TILE_STROKE = 3
-- 格子小图：远机位窄视角近似正交，白边剪影才均匀
local ICON_CAMERA_DIST = 20
local ICON_FOV = 8
local ICON_YAW = math.rad(30)
local ICON_OUTLINE_SCALE = 1.12
local ICON_OUTLINE_BACK = 0.3
local ICON_AMBIENT = Color3.fromRGB(190, 190, 190)
local SPIN_SPEED = math.rad(45)
local BOB_AMP = 0.25
local BOB_SPEED = 2
-- 镜头在此距离内的箱子才转定格手臂，远处不写 CFrame
local ANIM_RANGE = 120
-- 表演 / 定格手臂中心离箱子顶面的高度
local ROLL_HEIGHT = 2.4
local LID_OPEN_ANGLE = math.rad(110)
local LID_OPEN_SEC = 0.35
local LID_CLOSE_SEC = 0.25
local RETRACT_SEC = 0.3
local ROLL_APPEAR = 0.35
local ROLL_REVEAL_POP = 0.3
local ROLL_STEPS = 12
-- 第 i 步时长 ∝ 1 + i × ROLL_SLOWDOWN，越转越慢
local ROLL_SLOWDOWN = 0.25
-- 缩回 + 合盖占用后，忽大忽小阶段至少保留的秒数
local ROLL_MIN_STEPS_SEC = 1.2
local ROLL_MIN_SCALE = 0.55
local ROLL_MAX_SCALE = 1.25
local ROLL_TURN_DEG = 90
local ROLL_HIDDEN_SCALE = 0.05
local REVEAL_SCALE = 1.15
local REVEAL_INFO_SIZE = UDim2.fromScale(10, 3)
local REVEAL_INFO_OFFSET = 4.2
local REVEAL_INFO_MAX_DIST = 80
local BURST_COUNT = 40
local BURST_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"

type Tile = {
	id: string,
	mat: { [string]: any },
	arm: BasePart,
	outline: BasePart,
	chance: TextLabel,
	owned: boolean?,
}

type Showcase = {
	level: number,
	pool: { string },
	center: Vector3,
	innerCFrame: CFrame,
	rollCFrame: CFrame,
	gui: SurfaceGui,
	tiles: { Tile },
}

type ShownArm = {
	part: BasePart,
	base: CFrame,
	start: number,
}

local _folder: Folder? = nil
local _playerGui: Instance? = nil
local _showcases: { [number]: Showcase } = {}
local _machines: { [number]: Model } = {}
-- 场景立牌牌面（流入后才有；流出后实例失效，再流入时覆盖）
local _signFaces: { [number]: BasePart } = {}
local _holdId: string? = nil
local _rollToken = 0
local _rollPart: BasePart? = nil
local _rollingLevel: number? = nil
-- HUD 报价条正打开着的箱子
local _offerLevel: number? = nil
local _bound = false
-- 每台箱子上一抽定格后悬浮的手臂（直到该箱子下一次抽取）
local _shown: { [number]: ShownArm } = {}
local _lids: { [number]: Model } = {}
local _lidClosed: { [number]: CFrame } = {}
-- 盖子开合进度 0（合）~ 1（开），补间驱动、机器流入时据此恢复
local _lidAlpha: { [number]: NumberValue } = {}
local _lidTweens: { [number]: Tween } = {}

local _stepWeightSum = 0
for i = 1, ROLL_STEPS do
	_stepWeightSum += 1 + i * ROLL_SLOWDOWN
end

--[[
	材质配置的 Mat 名转 Enum.Material
	@param mat table - 材质配置（读 Mat 字段，如 "Grass"）
	@return Enum.Material - 对应材质，缺省 SmoothPlastic
]]
local function _matEnum(mat: { [string]: any }): Enum.Material
	return (Enum.Material :: any)[mat.Mat] or Enum.Material.SmoothPlastic
end

--[[
	取稀有度颜色
	@param mat table - 材质配置（读 Rarity）
	@return Color3 - 稀有度颜色；未知稀有度为白
]]
local function _rarityColor(mat: { [string]: any }): Color3
	local rarity = ArmWrestleConfig.GetRarity(mat.Rarity)
	return if rarity then rarity.Color else C.White
end

--[[
	新建本地装饰 Part（锚定、无碰撞 / 射线 / 触碰）
	@param name string - 实例名
	@param size Vector3 - 尺寸
	@return Part - 未挂父级的 Part
]]
local function _newPart(name: string, size: Vector3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	return part
end

--[[
	本地玩家已拥有的材质表（只读快照）
	@return table - { [材质Id] = true }；档案未同步时为空表
]]
local function _ownedMats(): { [string]: boolean }
	local data = PlayerData.GetPlrDataByKey(LocalPlayer, "ArmWrestle")
	local mats = type(data) == "table" and data.Mats
	return if type(mats) == "table" then mats else {}
end

--[[
	切换一个概率格的拥有外观：已拥有显示真实材质，未拥有为黑色剪影 + 白边
	@param tile Tile - 概率格
	@param owned boolean - 是否已拥有
]]
local function _setTileOwned(tile: Tile, owned: boolean)
	tile.owned = owned
	tile.arm.Color = if owned then tile.mat.Color else LOCKED_COLOR
	tile.arm.Material = if owned then _matEnum(tile.mat) else Enum.Material.SmoothPlastic
	tile.outline.Transparency = if owned then 1 else 0
end

--[[
	按档案刷新全部概率格的拥有状态（正在表演的材质暂不解锁）
]]
local function _applyOwned()
	local owned = _ownedMats()
	for _, showcase in pairs(_showcases) do
		for _, tile in ipairs(showcase.tiles) do
			local has = owned[tile.id] == true and (tile.id ~= _holdId or tile.owned == true)
			if tile.owned ~= has then
				_setTileOwned(tile, has)
			end
		end
	end
end

--[[
	按 Weight 刷新全部概率格的概率文字
]]
local function _applyChances()
	for _, showcase in pairs(_showcases) do
		local odds = ArmWrestleConfig.PoolOdds(showcase.pool)
		for i, tile in ipairs(showcase.tiles) do
			local row = odds[i]
			TranslationHelper.SetRawText(tile.chance, string.format("%.1f%%", (row and row.Chance or 0) * 100))
		end
	end
end

--[[
	在格子里建手臂小图（手臂 + 身后略大的白色剪影边）
	@param parent GuiObject - 所属格子
	@return BasePart - 手臂
	@return BasePart - 白边
]]
local function _buildIcon(parent: GuiObject): (BasePart, BasePart)
	local viewport = Instance.new("ViewportFrame")
	viewport.Name = "Icon"
	viewport.BackgroundTransparency = 1
	viewport.Position = UDim2.fromScale(0.1, 0.2)
	viewport.Size = UDim2.fromScale(0.8, 0.5)
	viewport.Ambient = ICON_AMBIENT
	viewport.LightColor = C.White
	local camera = Instance.new("Camera")
	camera.FieldOfView = ICON_FOV
	camera.CFrame = CFrame.lookAt(Vector3.new(0, 0, ICON_CAMERA_DIST), Vector3.zero)
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	local rotation = CFrame.Angles(0, ICON_YAW, 0)
	local outline = _newPart("Outline", ARM_SIZE * ICON_OUTLINE_SCALE)
	outline.Color = LOCKED_OUTLINE
	outline.Material = Enum.Material.SmoothPlastic
	outline.CFrame = CFrame.new(0, 0, -ICON_OUTLINE_BACK) * rotation
	outline.Parent = viewport
	local arm = _newPart("Arm", ARM_SIZE)
	arm.CFrame = rotation
	arm.Parent = viewport
	viewport.Parent = parent
	return arm, outline
end

--[[
	建一个概率格（稀有度色底 + 描边、材质名、手臂小图、概率）
	@param row GuiObject - 概率牌的格子行
	@param index number - 第几格（1 起）
	@param count number - 总格数
	@param id string - 材质 Id
	@param mat table - 材质配置
	@return Tile - 概率格
]]
local function _buildTile(row: GuiObject, index: number, count: number, id: string, mat: { [string]: any }): Tile
	local color = _rarityColor(mat)
	local frame = Instance.new("Frame")
	frame.Name = id
	frame.BorderSizePixel = 0
	frame.BackgroundColor3 = color:Lerp(Color3.new(0, 0, 0), TILE_DARKEN)
	frame.Position = UDim2.fromScale((index - 1) / count + TILE_PAD / count, 0)
	frame.Size = UDim2.fromScale((1 - 2 * TILE_PAD) / count, 1)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.12, 0)
	corner.Parent = frame
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = TILE_STROKE
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = frame
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 90
	gradient.Color = ColorSequence.new(C.White, Color3.fromRGB(150, 150, 150))
	gradient.Parent = frame
	ArmWrestleStyle.Label(frame, mat.ZhName, UDim2.fromScale(0.04, 0.03), UDim2.fromScale(0.92, 0.17), C.White)
	local arm, outline = _buildIcon(frame)
	local chance = ArmWrestleStyle.Label(frame, nil, UDim2.fromScale(0.04, 0.72), UDim2.fromScale(0.92, 0.24), C.White)
	frame.Parent = row
	return { id = id, mat = mat, arm = arm, outline = outline, chance = chance }
end

--[[
	建概率牌面 SurfaceGui（单价行（扭蛋模式）+ 一行概率格）；按像素偏移排版，随牌面尺寸自适应
	@param parent Instance - 挂载父级（PlayerGui；经 Adornee 贴到场景牌面）
	@param name string - GUI 实例名（PlayerGui 下各箱子不重名）
	@param machineCfg table - 关卡 Machine 配置（读 Price）
	@param entries { { id: string, mat: table } } - 奖池里有效的材质
	@return SurfaceGui - 牌面 GUI（Adornee 未设置）
	@return { Tile } - 概率格（与 entries 同序）
]]
local function _buildOddsGui(
	parent: Instance,
	name: string,
	machineCfg: { [string]: any },
	entries: { { id: string, mat: { [string]: any } } }
): (SurfaceGui, { Tile })
	local count = #entries
	local hasPrice = type(machineCfg.Price) == "number"
	local pad = SIGN_PAD * SIGN_PIXELS_PER_STUD
	local head = if hasPrice then PRICE_HEIGHT * SIGN_PIXELS_PER_STUD else 0
	local gui = Instance.new("SurfaceGui")
	gui.Name = name
	gui.ResetOnSpawn = false
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = SIGN_PIXELS_PER_STUD
	gui.LightInfluence = 0
	gui.MaxDistance = SIGN_MAX_DIST
	if hasPrice then
		ArmWrestleStyle.Label(
			gui,
			"扭蛋单价",
			UDim2.fromOffset(0, pad),
			UDim2.new(1, 0, 0, head),
			C.Green,
			nil,
			{ ArmWrestleConfig.Format(machineCfg.Price) }
		)
	end
	local row = Instance.new("Frame")
	row.Name = "Tiles"
	row.BackgroundTransparency = 1
	row.Position = UDim2.fromOffset(pad, pad + head)
	row.Size = UDim2.new(1, -2 * pad, 1, -(2 * pad + head))
	row.Parent = gui
	local tiles = {}
	for i, entry in ipairs(entries) do
		local tile = _buildTile(row, i, count, entry.id, entry.mat)
		_setTileOwned(tile, false)
		table.insert(tiles, tile)
	end
	gui.Parent = parent
	return gui, tiles
end

--[[
	为某台箱子建概率牌与表演定位（每关只建一次；机器流出后本地模型保留）
	@param level number - 关卡下标
	@param machine Model - Machine_N 模型（须已含 Main，盖子处于合盖姿态）
]]
local function _buildShowcase(level: number, machine: Model)
	local playerGui = _playerGui
	local levelCfg = ArmWrestleConfig.GetLevel(level)
	local machineCfg = levelCfg and levelCfg.Machine
	local pool = machineCfg and machineCfg.Pool
	local main = machine:FindFirstChild("Main")
	if _showcases[level] or not playerGui or type(pool) ~= "table" or not main or not main:IsA("BasePart") then
		return
	end
	local boxCFrame, boxSize = machine:GetBoundingBox()
	local floorY = boxCFrame.Position.Y - boxSize.Y / 2
	local topY = boxCFrame.Position.Y + boxSize.Y / 2
	local look = machine:GetPivot().LookVector * Vector3.new(1, 0, 1)
	local front = if look.Magnitude > 1e-3 then look.Unit else -Vector3.zAxis
	local center = Vector3.new(main.Position.X, floorY, main.Position.Z)
	local rotation = CFrame.lookAt(center, center + front).Rotation

	local entries = {}
	for _, id in ipairs(pool) do
		local mat = ArmWrestleConfig.GetMaterial(id)
		if mat then
			table.insert(entries, { id = id, mat = mat })
		end
	end
	local gui, tiles = _buildOddsGui(playerGui, machine.Name .. "Odds", machineCfg, entries)
	gui.Adornee = _signFaces[level]

	_showcases[level] = {
		level = level,
		pool = pool,
		center = center,
		innerCFrame = CFrame.new(main.Position) * rotation,
		rollCFrame = CFrame.new(main.Position.X, topY + ROLL_HEIGHT, main.Position.Z) * rotation,
		gui = gui,
		tiles = tiles,
	}
	_applyOwned()
	_applyChances()
end

--[[
	按开合进度摆放某台箱子的盖子（盖子的唯一写入点；机器未流入时忽略）
	@param level number - 关卡下标
]]
local function _applyLid(level: number)
	local lid = _lids[level]
	local closed = _lidClosed[level]
	local alpha = _lidAlpha[level]
	if not lid or not closed or not alpha or not lid.Parent then
		return
	end
	lid:PivotTo(closed * CFrame.Angles(LID_OPEN_ANGLE * alpha.Value, 0, 0))
end

--[[
	取某台箱子的开合进度值（首次访问时创建并绑定摆放）
	@param level number - 关卡下标
	@return NumberValue - 开合进度 0（合）~ 1（开）
]]
local function _lidValue(level: number): NumberValue
	local value = _lidAlpha[level]
	if not value then
		value = Instance.new("NumberValue")
		value.Changed:Connect(function()
			_applyLid(level)
		end)
		_lidAlpha[level] = value
	end
	return value :: NumberValue
end

--[[
	补间开 / 合某台箱子的盖子并阻塞到结束（同一箱子的新补间会取消旧补间）
	@param level number - 关卡下标
	@param open boolean - true 打开、false 合上
	@param duration number - 秒数
]]
local function _tweenLid(level: number, open: boolean, duration: number)
	local value = _lidValue(level)
	local old = _lidTweens[level]
	if old then
		old:Cancel()
	end
	local info = if open
		then TweenInfo.new(duration, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		else TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	local tween = TweenService:Create(value, info, { Value = if open then 1 else 0 })
	_lidTweens[level] = tween
	tween:Play()
	task.wait(duration)
end

--[[
	按「表演中 / 报价条打开」合成某台箱子 Prompt 的本地启用：两者任一成立即禁用（机器未流入时忽略）
	@param level number - 关卡下标
]]
local function _refreshMachine(level: number)
	local rolling = _rollingLevel == level
	local machine = _machines[level]
	local main = machine and machine:FindFirstChild("Main")
	local prompt = main and main:FindFirstChild(PROMPT_NAME)
	if prompt and prompt:IsA("ProximityPrompt") then
		prompt.Enabled = not rolling and _offerLevel ~= level
	end
end

--[[
	标记正在表演的机器（nil 表示表演结束），并刷新新旧机器的显隐
	@param level number? - 关卡下标
]]
local function _setRollingLevel(level: number?)
	local old = _rollingLevel
	_rollingLevel = level
	if old and old ~= level then
		_refreshMachine(old)
	end
	if level then
		_refreshMachine(level)
	end
end

--[[
	从 Machine_N 子孙节点解析出所属机器与关卡
	@param inst Instance - 机器下任意节点
	@return Model? - Machine_N 模型
	@return number? - 关卡下标（Level 属性，缺省取名字里的 N）
]]
local function _machineOf(inst: Instance): (Model?, number?)
	local node: Instance? = inst
	while node and node ~= Workspace do
		if node:IsA("Model") and string.match(node.Name, MACHINE_PATTERN) then
			local level = node:GetAttribute("Level")
			if type(level) ~= "number" then
				level = tonumber(string.match(node.Name, MACHINE_PATTERN))
			end
			return node, level
		end
		node = node.Parent
	end
	return nil, nil
end

--[[
	场景立牌牌面出现（初始扫描与流入）：记下并把对应关卡的概率牌 GUI 贴上去
	@param face Instance - 名为 SignFace 的节点（父级须为 OddsSign_N 模型）
]]
local function _onSignFace(face: Instance)
	local sign = face.Parent
	local level = sign and tonumber(string.match(sign.Name, SIGN_PATTERN))
	if not level or not face:IsA("BasePart") then
		return
	end
	_signFaces[level] = face
	local showcase = _showcases[level]
	if showcase then
		showcase.gui.Adornee = face
	end
end

--[[
	处理机器节点（初始扫描与流入）：Main 出现时建概率牌；Lid 出现时记下合盖姿态并按本地进度恢复；Prompt 出现时按本地状态设启用；
	立牌 SignFace 出现时贴概率牌 GUI
	@param inst Instance - World 下新出现的节点
]]
local function _onMachineNode(inst: Instance)
	local name = inst.Name
	if name == SIGN_FACE_NAME then
		_onSignFace(inst)
		return
	end
	if name ~= "Main" and name ~= LID_NAME and name ~= PROMPT_NAME then
		return
	end
	local machine, level = _machineOf(inst)
	if not machine or not level then
		return
	end
	_machines[level] = machine
	if name == "Main" and inst.Parent == machine then
		_buildShowcase(level, machine)
	elseif name == LID_NAME and inst:IsA("Model") and inst.Parent == machine and _lids[level] ~= inst then
		_lids[level] = inst
		_lidClosed[level] = inst:GetPivot()
		_applyLid(level)
	elseif name == PROMPT_NAME and inst:IsA("ProximityPrompt") then
		_refreshMachine(level)
	end
end

--[[
	箱子上方定格手臂的自转 + 浮动（仅镜头附近的箱子）
]]
local function _animateShown()
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local camPos = camera.CFrame.Position
	local t = os.clock()
	for level, shown in pairs(_shown) do
		local showcase = _showcases[level]
		if not showcase or (showcase.center - camPos).Magnitude > ANIM_RANGE then
			continue
		end
		local dt = t - shown.start
		shown.part.CFrame = shown.base * CFrame.new(0, math.sin(dt * BOB_SPEED) * BOB_AMP, 0) * CFrame.Angles(0, dt * SPIN_SPEED, 0)
	end
end

--[[
	奖池里出现的稀有度颜色（去重），表演时描边在其中随机跳动
	@param pool { string } - 材质 Id 列表
	@return { Color3 } - 颜色列表；至少含白色
]]
local function _poolColors(pool: { string }): { Color3 }
	local colors = {}
	local seen = {}
	for _, id in ipairs(pool) do
		local mat = ArmWrestleConfig.GetMaterial(id)
		if mat and not seen[mat.Rarity] then
			seen[mat.Rarity] = true
			table.insert(colors, _rarityColor(mat))
		end
	end
	if #colors == 0 then
		table.insert(colors, C.White)
	end
	return colors
end

--[[
	随机取一个与上一次不同的颜色（只有 1 种时允许重复）
	@param colors { Color3 } - 候选（非空）
	@param last Color3? - 上一次颜色
	@return Color3 - 颜色
]]
local function _pickColor(colors: { Color3 }, last: Color3?): Color3
	if #colors == 1 then
		return colors[1]
	end
	local color = colors[math.random(1, #colors)]
	while color == last do
		color = colors[math.random(1, #colors)]
	end
	return color
end

--[[
	中止未定格的表演：销毁表演手臂；被打断的若是别的箱子且其上没有定格手臂，则把盖子合上
	@param nextLevel number - 即将开始表演的关卡下标
]]
local function _abortRoll(nextLevel: number)
	if _rollPart then
		_rollPart:Destroy()
		_rollPart = nil
	end
	local level = _rollingLevel
	if level and level ~= nextLevel and not _shown[level] then
		task.spawn(_tweenLid, level, false, LID_CLOSE_SEC)
	end
end

--[[
	把某台箱子上方的定格手臂缩回箱内并销毁（阻塞到缩回结束）
	@param level number - 关卡下标
	@param showcase Showcase - 该箱子的展示数据（取箱内位置）
	@return boolean - 原本有定格手臂为 true
]]
local function _retractShown(level: number, showcase: Showcase): boolean
	local shown = _shown[level]
	if not shown then
		return false
	end
	_shown[level] = nil
	local part = shown.part
	local board = part:FindFirstChild("Info")
	if board and board:IsA("BillboardGui") then
		board.Enabled = false
	end
	TweenService:Create(part, TweenInfo.new(RETRACT_SEC, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		CFrame = showcase.innerCFrame,
		Size = part.Size * ROLL_HIDDEN_SCALE,
	}):Play()
	task.wait(RETRACT_SEC)
	part:Destroy()
	return true
end

--[[
	表演定格：换成抽中材质，描边定为稀有度色，弹大 + 粒子 + 名称 / 稀有度 / 力量倍率牌；不挂灯光
	@param part BasePart - 表演手臂
	@param highlight Highlight - 表演手臂的 Highlight
	@param mat table - 抽中材质配置
]]
local function _reveal(part: BasePart, highlight: Highlight, mat: { [string]: any })
	local color = _rarityColor(mat)
	part.Color = mat.Color
	part.Material = _matEnum(mat)
	highlight.OutlineColor = color
	RollSfx.PlayReveal(part.Position)
	TweenService:Create(highlight, TweenInfo.new(ROLL_REVEAL_POP), { FillTransparency = 1 }):Play()
	TweenService:Create(part, TweenInfo.new(ROLL_REVEAL_POP, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = ARM_SIZE * ROLL_SCALE * REVEAL_SCALE,
	}):Play()

	local burst = Instance.new("ParticleEmitter")
	burst.Texture = BURST_TEXTURE
	burst.Color = ColorSequence.new(color)
	burst.LightEmission = 1
	burst.Rate = 0
	burst.Lifetime = NumberRange.new(0.5, 1)
	burst.Speed = NumberRange.new(8, 14)
	burst.SpreadAngle = Vector2.new(180, 180)
	burst.Size = NumberSequence.new(0.5, 0)
	burst.Parent = part
	burst:Emit(BURST_COUNT)

	local board = Instance.new("BillboardGui")
	board.Name = "Info"
	board.Size = REVEAL_INFO_SIZE
	board.StudsOffsetWorldSpace = Vector3.new(0, REVEAL_INFO_OFFSET, 0)
	board.MaxDistance = REVEAL_INFO_MAX_DIST
	board.LightInfluence = 0
	local rarity = ArmWrestleConfig.GetRarity(mat.Rarity) or { ZhName = "普通", Color = C.White }
	ArmWrestleStyle.Label(board, mat.ZhName, UDim2.fromScale(0, 0), UDim2.fromScale(1, 0.42), C.White)
	ArmWrestleStyle.Label(board, rarity.ZhName, UDim2.fromScale(0, 0.42), UDim2.fromScale(1, 0.3), rarity.Color)
	ArmWrestleStyle.Label(board, "力量倍率", UDim2.fromScale(0, 0.72), UDim2.fromScale(1, 0.28), C.Gold, nil, { tostring(mat.Mult) })
	board.Parent = part
end

--[[
	在某台箱子上播放 3D 抽取表演，阻塞到定格（约 ArmWrestleConfig.ROLL_ANIM_SEC 秒）：
	上一抽的手臂缩回（若有，盖子保持打开）→ 开盖（已开着则跳过）→ 手臂升起并忽大忽小 → 定格；定格手臂留在箱子上方直到该箱子下一次抽取
	新表演会打断旧表演（旧调用返回 false）。箱子未流入过或材质无效时立即返回 false
	@param level number - 关卡下标（服务端载荷 Level）
	@param matId string - 抽中材质 Id（服务端载荷 Id）
	@return boolean - 播放到定格为 true；被打断或无法播放为 false
]]
function MachineShowcase.PlayRoll(level: number, matId: string): boolean
	local showcase = if type(level) == "number" then _showcases[level] else nil
	local mat = ArmWrestleConfig.GetMaterial(matId)
	local folder = _folder
	if not showcase or not mat or not folder then
		return false
	end
	_rollToken += 1
	local token = _rollToken
	_abortRoll(level)
	_holdId = matId
	_setRollingLevel(level)
	local started = os.clock()

	_retractShown(level, showcase)
	if token ~= _rollToken then
		return false
	end
	if _lidValue(level).Value < 1 then
		_tweenLid(level, true, LID_OPEN_SEC)
		if token ~= _rollToken then
			return false
		end
	end

	local full = ARM_SIZE * ROLL_SCALE
	local part = _newPart("RollArm", full * ROLL_HIDDEN_SCALE)
	part.Color = LOCKED_COLOR
	part.Material = Enum.Material.SmoothPlastic
	part.CFrame = showcase.innerCFrame
	local highlight = Instance.new("Highlight")
	highlight.FillColor = LOCKED_COLOR
	highlight.FillTransparency = 0
	highlight.OutlineTransparency = 0
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	local colors = _poolColors(showcase.pool)
	local lastColor = _pickColor(colors, nil)
	highlight.OutlineColor = lastColor
	highlight.Parent = part
	part.Parent = folder
	_rollPart = part

	TweenService:Create(part, TweenInfo.new(ROLL_APPEAR, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = full,
		CFrame = showcase.rollCFrame,
	}):Play()
	task.wait(ROLL_APPEAR)
	local remain = ArmWrestleConfig.ROLL_ANIM_SEC - ROLL_REVEAL_POP - (os.clock() - started)
	local unit = math.max(remain, ROLL_MIN_STEPS_SEC) / _stepWeightSum
	for step = 1, ROLL_STEPS do
		if token ~= _rollToken then
			return false
		end
		local duration = unit * (1 + step * ROLL_SLOWDOWN)
		local scale = if step % 2 == 1 then ROLL_MIN_SCALE else ROLL_MAX_SCALE
		lastColor = _pickColor(colors, lastColor)
		highlight.OutlineColor = lastColor
		RollSfx.PlayStep(step, ROLL_STEPS, showcase.rollCFrame.Position)
		TweenService:Create(part, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {
			Size = full * scale,
			CFrame = part.CFrame * CFrame.Angles(0, math.rad(ROLL_TURN_DEG), 0),
		}):Play()
		task.wait(duration)
	end
	if token ~= _rollToken then
		return false
	end
	_reveal(part, highlight, mat)
	task.wait(ROLL_REVEAL_POP)
	if token ~= _rollToken then
		return false
	end
	_rollPart = nil
	_shown[level] = { part = part, base = part.CFrame, start = os.clock() }
	_holdId = nil
	_applyOwned()
	_setRollingLevel(nil)
	return true
end

--[[
	收走某台箱子上方的定格手臂（报价条购买成功 / 点关闭）：手臂缩回箱内后合盖；该箱子正在表演或没有定格手臂时忽略。
	不阻塞；缩回期间该箱子开始新表演时不再合盖（新表演自己开盖）
	@param level number - 关卡下标
]]
function MachineShowcase.DiscardShown(level: number)
	local showcase = if type(level) == "number" then _showcases[level] else nil
	if not showcase or _rollingLevel == level or not _shown[level] then
		return
	end
	task.spawn(function()
		_retractShown(level, showcase)
		if _rollingLevel ~= level then
			_tweenLid(level, false, LID_CLOSE_SEC)
		end
	end)
end

--[[
	HUD 报价条显隐通知：打开期间禁用该箱子 Prompt（「换一个」接管 E 键），关闭后恢复
	@param level number? - 报价条所属关卡下标；nil 表示报价条已隐藏
]]
function MachineShowcase.SetOfferOpen(level: number?)
	local old = _offerLevel
	_offerLevel = if type(level) == "number" then level else nil
	if old and old ~= _offerLevel then
		_refreshMachine(old)
	end
	if _offerLevel then
		_refreshMachine(_offerLevel)
	end
end

--[[
	绑定世界：建本地根目录，为已流入 / 后续流入的材质箱建概率牌、恢复盖子，监听档案变化刷新拥有外观（只绑一次）
	@param world Instance - Workspace.World
]]
function MachineShowcase.BindWorld(world: Instance)
	if _bound then
		return
	end
	_bound = true
	local folder = Workspace:FindFirstChild(SHOWCASE_FOLDER)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = SHOWCASE_FOLDER
		folder.Parent = Workspace
	end
	_folder = folder :: Folder
	_playerGui = LocalPlayer:WaitForChild("PlayerGui")
	for _, inst in ipairs(world:GetDescendants()) do
		_onMachineNode(inst)
	end
	world.DescendantAdded:Connect(function(inst: Instance)
		-- 流入时 Main 的兄弟部件可能晚一帧挂上，推迟到本帧末再算包围盒
		task.defer(_onMachineNode, inst)
	end)
	PlayerData.ListenClientSync(function()
		_applyOwned()
	end)
	RunService.Heartbeat:Connect(_animateShown)
end

return MachineShowcase
