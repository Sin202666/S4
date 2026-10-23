--[[
	Module: ArmWrestleStyle
	Description: 扳手腕运行时 UI 样式（图标、描边、Label/Button 工厂、弹出动画、世界 GUI 重绘）
	Author: 程莘
	Created: 2026-10-14
	Last Modified: 2026-10-16

	功能：
	- Colors / Icons / Font：与原型 UIStyle 一致的配色、图标资源与字体
	- Label / Button：建带黑描边的文本；文案只走 TranslationHelper 翻译键，数字由调用方 SetRawText
	- SetIcon：按图标名（Icons 的键）在文字左侧画图标；文字为空时图标铺满
	- Pop：0.25s Back 回弹缩放
	- BuildShowModel / BuildDumbbellModel / ShowModelCamera：ViewportFrame 展示模型与机位（快捷栏哑铃格等 3D 预览；弹窗卡片改用配置 Icon 图片）
	- Confetti：全屏彩纸飘落（挂 ScreenGui 直属，高 ZIndex 盖过弹窗；纯表现，调用方须在服务端确认成功后再播）
	- BindIcons / StyleWorld：世界 Billboard/SurfaceGui 的图标与描边（客户端运行时）
	- BakeIcons：编辑态把图标写成 "Icon" ImageLabel 子节点（Studio 未运行也可见）；改了 Icon Attribute 后在命令栏重跑

	约束：
	- TranslationHelper.SetText 不处理 TextButton，所以 Button 内置名为 "Label" 的子 TextLabel 承载文字
	- 图标由 Attribute "Icon" 驱动，不解析 emoji，保证翻译键原样可用

	加载：
		local Utils = require(game.ReplicatedFirst.AllSideCode.UtilsSystem)
		local ArmWrestleStyle = Utils.ArmWrestleStyle
		local C = ArmWrestleStyle.Colors
		local lbl = ArmWrestleStyle.Label(parent, "手臂", UDim2.new(), UDim2.fromOffset(120, 30), C.White)
		ArmWrestleStyle.SetIcon(lbl, "strength")
		local btn, btnLabel = ArmWrestleStyle.Button(parent, "购买", UDim2.new(), UDim2.fromOffset(150, 52), C.Green)
		TranslationHelper.SetRawText(btnLabel, "X")
]]

local Utils = require(game.ReplicatedFirst.AllSideCode.UtilsSystem)
local RunService = Utils.RunService
local TweenService = Utils.TweenService
local TranslationHelper = Utils.TranslationHelper
local ArmWrestleConfig = Utils.ArmWrestleConfig

local ArmWrestleStyle = {}

-- 彩纸片的 Instance.Name；EdgeSlide 据此把它们排除在弹窗判定之外
ArmWrestleStyle.CONFETTI_NAME = "Confetti"

ArmWrestleStyle.Font = Font.new("rbxasset://fonts/families/ComicNeueAngular.json", Enum.FontWeight.Bold)

ArmWrestleStyle.Colors = {
	White = Color3.new(1, 1, 1),
	Black = Color3.new(0, 0, 0),
	Gold = Color3.fromRGB(255, 215, 0),
	Green = Color3.fromRGB(40, 220, 40),
	Red = Color3.fromRGB(255, 50, 50),
	Blue = Color3.fromRGB(60, 170, 255),
	Magenta = Color3.fromRGB(190, 0, 230),
	Panel = Color3.fromRGB(18, 18, 20),
	Card = Color3.fromRGB(40, 42, 48),
	Disabled = Color3.fromRGB(95, 95, 100),
	Equipped = Color3.fromRGB(120, 120, 130),
	Equip = Color3.fromRGB(60, 160, 255),
	Waiting = Color3.fromRGB(90, 90, 100),
	Desc = Color3.fromRGB(220, 220, 230),
}

ArmWrestleStyle.Icons = {
	strength = "rbxassetid://89640220409172",
	cash = "rbxassetid://106939431581986",
	gift = "rbxassetid://85385834338146",
	pass = "rbxassetid://73731364078648",
	shop = "rbxassetid://88297653133859",
	brick = "rbxassetid://85702347387943",
	home = "rbxassetid://83054835202091",
	lock = "rbxassetid://133781534369836",
	mouse = "rbxassetid://139743508066521",
	moneybag = "rbxassetid://131291884716937",
	clover = "rbxassetid://97408042147277",
	star = "rbxassetid://86346378657280",
	chest = "rbxassetid://92604451320837",
	shake = "rbxassetid://110798915749713",
	potion = "rbxassetid://119967653102785",
	potionStrength = "rbxassetid://120013088141721",
	potionTrainSpeed = "rbxassetid://106581559588513",
	potionCash = "rbxassetid://73520282041364",
	fist = "rbxassetid://96637112157833",
	timer = "rbxassetid://79356458250943",
	fire = "rbxassetid://104735809992419",
	party = "rbxassetid://88133444710793",
	shoe = "rbxassetid://80167209502437",
	sleep = "rbxassetid://86188224464107",
	check = "rbxassetid://135821982743253",
	trophy = "rbxassetid://99326959667086",
	dice = "rbxassetid://123961328553066",
	sparkle = "rbxassetid://122304887891412",
	close = "rbxassetid://88973595248016",
	arrow = "rbxassetid://90036989440052",
	dumbbell = "rbxassetid://131249360802894",
	-- 蓝色漩涡传送门图标（圆形无星点透明底；直链偶发无权，改走缩略图）
	teleport = "rbxthumb://type=Asset&id=92475017169750&w=420&h=420",
	passStrength = "rbxassetid://83417455733652",
	passCash = "rbxassetid://111393052947676",
	passAutoClick = "rbxassetid://102720135882987",
	robux = "rbxasset://textures/ui/common/robux.png",
}

ArmWrestleStyle.PanelTransparency = 0.25
ArmWrestleStyle.CardTransparency = 0.15
ArmWrestleStyle.Border = 4
ArmWrestleStyle.TextStrokeThickness = 3

local ICON_ATTR = "Icon"
local ICON_CHILD = "Icon"
local POP_FROM = 1.2
local POP_TIME = 0.25
local CONFETTI_COUNT = 40
-- ScreenGui 为 Sibling 排序，弹窗根 ZIndex 为 2；彩纸须直挂 ScreenGui 且高于所有弹窗
local CONFETTI_Z_INDEX = 100
local SHOW_CAMERA_DIR = Vector3.new(0.35, 0.45, 1).Unit
local SHOW_CAMERA_DISTANCE_SCALE = 1.1

local _bound: { [Instance]: { [string]: any } } = setmetatable({}, { __mode = "k" }) :: any

--[[
	UDim 换算像素
	@param u UDim - 尺寸分量
	@param total number - 父轴像素
	@return number - 像素值
]]
local function _px(u: UDim, total: number): number
	return u.Scale * total + u.Offset
end

--[[
	按 Icon Attribute 摆放文字左侧图标；全部用 Scale 表示，避免 UIScale / Pop 时错位
	@param lbl TextLabel - 目标文本
	@param st table - 绑定状态 { icon: ImageLabel?, pad: UIPadding?, baseLeft: UDim? }
]]
local function _layoutIcon(lbl: TextLabel, st: { [string]: any })
	if not st.icon then
		local baked = lbl:FindFirstChild(ICON_CHILD)
		if baked and baked:IsA("ImageLabel") then
			st.icon = baked
		end
	end
	local img = ArmWrestleStyle.Icons[lbl:GetAttribute(ICON_ATTR) or ""]
	if not img then
		if st.icon then
			st.icon.Visible = false
		end
		if st.pad then
			st.pad.PaddingLeft = st.baseLeft
		end
		return
	end
	if not st.icon then
		local icon = Instance.new("ImageLabel")
		icon.Name = ICON_CHILD
		icon.BackgroundTransparency = 1
		icon.ScaleType = Enum.ScaleType.Fit
		icon.Parent = lbl
		st.icon = icon
	end
	local icon: ImageLabel = st.icon
	icon.Image = img
	icon.ZIndex = lbl.ZIndex
	icon.ImageTransparency = lbl.TextTransparency
	icon.Visible = true
	if lbl.Text == "" then
		if st.pad then
			st.pad.PaddingLeft = st.baseLeft
		end
		icon.AnchorPoint = Vector2.new(0.5, 0.5)
		icon.Position = UDim2.fromScale(0.5, 0.5)
		icon.Size = UDim2.fromScale(1, 1)
		return
	end
	if not st.pad then
		local pad = lbl:FindFirstChildOfClass("UIPadding") or Instance.new("UIPadding")
		st.baseLeft = pad.PaddingLeft
		pad.Parent = lbl
		st.pad = pad
	end
	local abs = lbl.AbsoluteSize
	if abs.X <= 0 or abs.Y <= 0 then
		return
	end
	local pad: UIPadding = st.pad
	local contentH = abs.Y - _px(pad.PaddingTop, abs.Y) - _px(pad.PaddingBottom, abs.Y)
	local s = if lbl.TextScaled then contentH * 0.95 else math.min(contentH, lbl.TextBounds.Y * 1.2)
	local gap = s * 0.12
	local left = _px(st.baseLeft, abs.X) + s + gap
	pad.PaddingLeft = UDim.new(left / abs.X, 0)
	local contentW = abs.X - left - _px(pad.PaddingRight, abs.X)
	if contentW <= 0 or contentH <= 0 then
		return
	end
	local tb = math.min(lbl.TextBounds.X, contentW)
	local start = (contentW - tb) / 2
	if lbl.TextXAlignment == Enum.TextXAlignment.Left then
		start = 0
	elseif lbl.TextXAlignment == Enum.TextXAlignment.Right then
		start = contentW - tb
	end
	icon.AnchorPoint = Vector2.new(0, 0.5)
	icon.Position = UDim2.new((start - gap - s) / contentW, 0, 0.5, 0)
	icon.Size = UDim2.new(s / contentW, 0, s / contentH, 0)
end

--[[
	为文本绑定图标重排（幂等；文字/尺寸/Icon 变化时 defer 合并重排）
	@param lbl TextLabel - 目标文本
]]
local function _applyIcon(lbl: TextLabel)
	local st = _bound[lbl]
	if st then
		_layoutIcon(lbl, st)
		return
	end
	st = {}
	_bound[lbl] = st
	local queued = false
	local function relayout()
		if queued then
			return
		end
		queued = true
		task.defer(function()
			queued = false
			if lbl.Parent then
				_layoutIcon(lbl, st)
			end
		end)
	end
	for _, prop in ipairs({ "TextBounds", "AbsoluteSize", "Text", "TextXAlignment" }) do
		lbl:GetPropertyChangedSignal(prop):Connect(relayout)
	end
	lbl:GetAttributeChangedSignal(ICON_ATTR):Connect(relayout)
	lbl:GetPropertyChangedSignal("TextTransparency"):Connect(function()
		if st.icon then
			st.icon.ImageTransparency = lbl.TextTransparency
		end
	end)
	_layoutIcon(lbl, st)
end

--[[
	创建 Instance 并套属性/子节点
	@param className string - 类名
	@param props table? - 属性表；Parent 最后设置
	@param children {Instance}? - 子节点
	@return Instance - 新实例
]]
function ArmWrestleStyle.New(className: string, props: { [string]: any }?, children: { Instance }?): Instance
	local inst = Instance.new(className)
	local parent
	for key, value in pairs(props or {}) do
		if key == "Parent" then
			parent = value
		else
			(inst :: any)[key] = value
		end
	end
	for _, child in ipairs(children or {}) do
		child.Parent = inst
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

--[[
	边框描边（Name 固定为 "Border"，调用方可改 Color）
	@param thickness number? - 厚度，默认 Border(4)
	@param color Color3? - 颜色，默认黑
	@return UIStroke - 未挂父级的描边
]]
function ArmWrestleStyle.Stroke(thickness: number?, color: Color3?): UIStroke
	return ArmWrestleStyle.New("UIStroke", {
		Name = "Border",
		Thickness = thickness or ArmWrestleStyle.Border,
		Color = color or ArmWrestleStyle.Colors.Black,
		LineJoinMode = Enum.LineJoinMode.Miter,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}) :: UIStroke
end

--[[
	文字描边（Name 固定为 "TextStroke"）
	@param thickness number? - 厚度，默认 TextStrokeThickness(3)
	@return UIStroke - 未挂父级的描边
]]
function ArmWrestleStyle.TextStroke(thickness: number?): UIStroke
	return ArmWrestleStyle.New("UIStroke", {
		Name = "TextStroke",
		Thickness = thickness or ArmWrestleStyle.TextStrokeThickness,
		Color = ArmWrestleStyle.Colors.Black,
	}) :: UIStroke
end

--[[
	设置/清除文字左侧图标（仅客户端运行时生效）
	@param lbl TextLabel - 目标文本
	@param iconName string? - Icons 的键（strength / cash / gift ...）；nil 清除
]]
function ArmWrestleStyle.SetIcon(lbl: TextLabel, iconName: string?)
	if lbl:GetAttribute(ICON_ATTR) ~= iconName then
		lbl:SetAttribute(ICON_ATTR, iconName)
	end
	if not (RunService:IsRunning() and RunService:IsClient()) then
		return
	end
	-- 清除时也要走重排，否则 Studio 里预存的图标不会被隐藏
	if iconName or _bound[lbl] or lbl:FindFirstChild(ICON_CHILD) then
		_applyIcon(lbl)
	end
end

--[[
	编辑态把 Icon Attribute 对应的图标写成真实 ImageLabel 子节点，使 Studio 未运行时也能看到图标
	运行时 _layoutIcon 复用该子节点并按文字重排；不改 UIPadding，避免运行时 baseLeft 被污染
	用法（命令栏）：require(game.ReplicatedFirst.AllSideCode.ToolSystem.ArmWrestleStyle).BakeIcons(game.StarterGui)
	@param root Instance - 根（通常 StarterGui）；其下带 Icon Attribute 的 TextLabel 都会处理
	@return number - 写入/更新的图标数
]]
function ArmWrestleStyle.BakeIcons(root: Instance): number
	local count = 0
	for _, lbl in ipairs(root:GetDescendants()) do
		if not lbl:IsA("TextLabel") then
			continue
		end
		local existing = lbl:FindFirstChild(ICON_CHILD)
		local img = ArmWrestleStyle.Icons[lbl:GetAttribute(ICON_ATTR) or ""]
		if not img then
			if existing and existing:IsA("ImageLabel") then
				existing:Destroy()
			end
			continue
		end
		local icon: ImageLabel
		if existing and existing:IsA("ImageLabel") then
			icon = existing
		else
			icon = Instance.new("ImageLabel")
			icon.Name = ICON_CHILD
			icon.BackgroundTransparency = 1
			icon.ScaleType = Enum.ScaleType.Fit
			icon.Parent = lbl
		end
		icon.Image = img
		icon.ZIndex = lbl.ZIndex
		icon.ImageTransparency = lbl.TextTransparency
		icon.Visible = true
		icon.AnchorPoint = Vector2.new(0.5, 0.5)
		icon.Position = UDim2.fromScale(0.5, 0.5)
		icon.Size = UDim2.fromScale(1, 1)
		if lbl.Text ~= "" then
			local abs = lbl.AbsoluteSize
			local pad = lbl:FindFirstChildOfClass("UIPadding")
			local padL = if pad then _px(pad.PaddingLeft, abs.X) else 0
			local padR = if pad then _px(pad.PaddingRight, abs.X) else 0
			local padT = if pad then _px(pad.PaddingTop, abs.Y) else 0
			local padB = if pad then _px(pad.PaddingBottom, abs.Y) else 0
			local contentW = abs.X - padL - padR
			local contentH = abs.Y - padT - padB
			if contentW > 0 and contentH > 0 then
				local s = contentH * 0.95
				local tb = math.min(lbl.TextBounds.X, contentW)
				local start = (contentW - tb) / 2
				if lbl.TextXAlignment == Enum.TextXAlignment.Left then
					start = 0
				elseif lbl.TextXAlignment == Enum.TextXAlignment.Right then
					start = contentW - tb
				end
				icon.AnchorPoint = Vector2.new(1, 0.5)
				icon.Position = UDim2.new((start - s * 0.12) / contentW, 0, 0.5, 0)
				icon.Size = UDim2.new(s / contentW, 0, s / contentH, 0)
			end
		end
		count += 1
	end
	return count
end

--[[
	建 TextLabel（TextScaled + 黑描边）
	@param parent Instance - 父级
	@param key string? - 翻译键（字面量或 cfg.Zh*）；nil 表示文字由调用方 SetRawText
	@param pos UDim2 - 位置
	@param size UDim2 - 尺寸
	@param color Color3? - 文字颜色，默认白
	@param props table? - 额外 Instance 属性
	@param args table? - 翻译占位参数（数字下标）
	@return TextLabel - 新文本
]]
function ArmWrestleStyle.Label(
	parent: Instance,
	key: string?,
	pos: UDim2,
	size: UDim2,
	color: Color3?,
	props: { [string]: any }?,
	args: { [any]: any }?
): TextLabel
	local label = ArmWrestleStyle.New("TextLabel", {
		BackgroundTransparency = 1,
		FontFace = ArmWrestleStyle.Font,
		Text = "",
		TextScaled = true,
		TextColor3 = color or ArmWrestleStyle.Colors.White,
		Position = pos,
		Size = size,
	}, { ArmWrestleStyle.TextStroke() }) :: TextLabel
	for k, v in pairs(props or {}) do
		(label :: any)[k] = v
	end
	label.Parent = parent
	if key then
		TranslationHelper.SetText(label, key, args)
	end
	return label
end

--[[
	建 TextButton（底色 + 黑边框），文字放在子 TextLabel "Label"
	@param parent Instance - 父级
	@param key string? - 翻译键；nil 表示文字由调用方写 label
	@param pos UDim2 - 位置
	@param size UDim2 - 尺寸
	@param color Color3? - 底色，默认绿
	@param props table? - 额外 Instance 属性（作用于按钮）
	@param args table? - 翻译占位参数
	@return TextButton - 按钮
	@return TextLabel - 按钮文字
]]
function ArmWrestleStyle.Button(
	parent: Instance,
	key: string?,
	pos: UDim2,
	size: UDim2,
	color: Color3?,
	props: { [string]: any }?,
	args: { [any]: any }?
): (TextButton, TextLabel)
	local button = ArmWrestleStyle.New("TextButton", {
		AutoButtonColor = true,
		BackgroundColor3 = color or ArmWrestleStyle.Colors.Green,
		Text = "",
		Position = pos,
		Size = size,
	}, { ArmWrestleStyle.Stroke() }) :: TextButton
	for k, v in pairs(props or {}) do
		(button :: any)[k] = v
	end
	local label = ArmWrestleStyle.Label(button, key, UDim2.new(), UDim2.fromScale(1, 1), ArmWrestleStyle.Colors.White, {
		Name = "Label",
		ZIndex = button.ZIndex,
	}, args)
	ArmWrestleStyle.New("UIPadding", {
		PaddingTop = UDim.new(0.12, 0),
		PaddingBottom = UDim.new(0.12, 0),
		PaddingLeft = UDim.new(0.06, 0),
		PaddingRight = UDim.new(0.06, 0),
		Parent = label,
	})
	button.Parent = parent
	return button, label
end

--[[
	用 Tool / 模型的 BasePart 拼出锚定展示模型（去掉焊接，不引用原件），供 ViewportFrame 展示
	@param source Instance - Tool 或 Model
	@return Model? - 展示模型，WorldPivot 为包围盒中心；无 BasePart 为 nil
]]
function ArmWrestleStyle.BuildShowModel(source: Instance): Model?
	local model = Instance.new("Model")
	model.Name = source.Name
	for _, descendant in source:GetDescendants() do
		if descendant:IsA("BasePart") then
			local part = descendant:Clone()
			for _, sub in part:GetChildren() do
				if sub:IsA("JointInstance") or sub:IsA("WeldConstraint") or sub:IsA("BasePart") then
					sub:Destroy()
				end
			end
			part.Anchored = true
			part.CFrame = descendant.CFrame
			part.Parent = model
		end
	end
	if #model:GetChildren() == 0 then
		model:Destroy()
		return nil
	end
	model.WorldPivot = model:GetBoundingBox()
	return model
end

--[[
	指定款式哑铃的展示模型（克隆 Tool 模板 → ApplyDumbbellLook → BuildShowModel）
	@param id number - 哑铃 Id
	@return Model? - 展示模型；模板缺失为 nil
]]
function ArmWrestleStyle.BuildDumbbellModel(id: number): Model?
	local template = ArmWrestleConfig.FindToolTemplate()
	if not template then
		return nil
	end
	local tool = template:Clone()
	ArmWrestleConfig.ApplyDumbbellLook(tool, id)
	local model = ArmWrestleStyle.BuildShowModel(tool)
	tool:Destroy()
	return model
end

--[[
	展示模型的斜上方视角相机（距离按包围盒对角线缩放；模型须已 Pivot 到原点）
	@param model Model - BuildShowModel 的结果
	@return CFrame - 视口相机 CFrame
]]
function ArmWrestleStyle.ShowModelCamera(model: Model): CFrame
	local distance = model:GetExtentsSize().Magnitude * SHOW_CAMERA_DISTANCE_SCALE
	return CFrame.lookAt(SHOW_CAMERA_DIR * distance, Vector3.zero)
end

--[[
	回弹缩放（挂 PopScale UIScale）
	@param obj GuiObject - 目标
]]
function ArmWrestleStyle.Pop(obj: GuiObject)
	local scale = obj:FindFirstChild("PopScale") :: UIScale?
	if not scale then
		scale = ArmWrestleStyle.New("UIScale", { Name = "PopScale", Parent = obj }) :: UIScale
	end
	local s = scale :: UIScale
	s.Scale = POP_FROM
	TweenService:Create(s, TweenInfo.new(POP_TIME, Enum.EasingStyle.Back), { Scale = 1 }):Play()
end

--[[
	彩纸从顶部飘落，结束自动销毁
	@param parent Instance - 挂载点；传 PlayerGui.ScreenGui 以盖过全部弹窗
]]
function ArmWrestleStyle.Confetti(parent: Instance)
	for _ = 1, CONFETTI_COUNT do
		local piece = ArmWrestleStyle.New("Frame", {
			Name = ArmWrestleStyle.CONFETTI_NAME,
			BackgroundColor3 = Color3.fromHSV(math.random(), 0.8, 1),
			BorderSizePixel = 0,
			Size = UDim2.fromOffset(math.random(8, 14), math.random(12, 20)),
			Position = UDim2.new(math.random(), 0, -0.05, 0),
			Rotation = math.random(0, 360),
			ZIndex = CONFETTI_Z_INDEX,
			Parent = parent,
		}) :: Frame
		local tween = TweenService:Create(
			piece,
			TweenInfo.new(math.random(15, 30) / 10, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{
				Position = UDim2.new(piece.Position.X.Scale + (math.random() - 0.5) * 0.3, 0, 1.1, 0),
				Rotation = piece.Rotation + math.random(-360, 360),
			}
		)
		tween:Play()
		tween.Completed:Connect(function()
			piece:Destroy()
		end)
	end
end

--[[
	给世界字绑图标（客户端运行时；Icon Attribute 可由服务端或建图时写入）
	@param root Instance - 根
]]
function ArmWrestleStyle.BindIcons(root: Instance)
	if not RunService:IsClient() then
		return
	end
	local function watch(desc: Instance)
		if not desc:IsA("TextLabel") then
			return
		end
		if desc:GetAttribute(ICON_ATTR) then
			_applyIcon(desc)
			return
		end
		local conn: RBXScriptConnection
		conn = desc:GetAttributeChangedSignal(ICON_ATTR):Connect(function()
			conn:Disconnect()
			_applyIcon(desc)
		end)
	end
	for _, desc in ipairs(root:GetDescendants()) do
		watch(desc)
	end
	root.DescendantAdded:Connect(watch)
end

--[[
	重绘世界 GUI 描边（幂等）
	@param root Instance - 世界根
]]
function ArmWrestleStyle.StyleWorld(root: Instance)
	for _, desc in ipairs(root:GetDescendants()) do
		local gui = desc:FindFirstAncestorWhichIsA("LayerCollector")
		if not gui then
			continue
		end
		if desc:IsA("UICorner") then
			desc:Destroy()
		elseif desc:IsA("TextLabel") then
			desc.FontFace = ArmWrestleStyle.Font
			desc.TextStrokeTransparency = 1
			local stroke = desc:FindFirstChildOfClass("UIStroke") or Instance.new("UIStroke")
			stroke.Color = ArmWrestleStyle.Colors.Black
			stroke.Thickness = 3
			stroke.Parent = desc
		elseif desc:IsA("Frame") and desc.BackgroundTransparency < 1 then
			local stroke = desc:FindFirstChildOfClass("UIStroke")
			if not stroke then
				stroke = Instance.new("UIStroke")
				stroke.Color = ArmWrestleStyle.Colors.Black
				stroke.Parent = desc
			end
			stroke.Thickness = ArmWrestleStyle.Border
			stroke.LineJoinMode = Enum.LineJoinMode.Miter
		end
	end
end

return ArmWrestleStyle
