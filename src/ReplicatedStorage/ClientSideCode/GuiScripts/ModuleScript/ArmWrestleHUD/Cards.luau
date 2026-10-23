--[[
	Module: Cards
	Description: ArmWrestleHUD 弹窗网格卡片的通用工具：克隆模板、取按钮/文本、图标、清空网格
	Author: 程莘
	Created: 2026-10-14
	Last Modified: 2026-10-15

	约定：
	- 模板 Visible=false，Clone 后命名为 "Card"；Clear 只删 "Card"，模板保留
	- 卡片底部按钮名为 "Button"，文字在其子 TextLabel "Label"；左侧图标为 ImageLabel "Preview"
	- SetIcon 写入配置条目的 Icon（带黑描边的透明 PNG），不再建 3D 视口
	- ApplyRarity：手臂 / 材质 / 哑铃行按稀有度改 Fill 竖向渐变（底色须为白）与子文本 "Rarity" 颜色；
	  外框 Border 与全部文字描边固定黑色（不随稀有度/装备变化）；Bricks 积木图由 UIMgr.BindBrickTiles 跟随 Fill 上色，此处不写

	与相关模块：
	- Panels（手臂/材质/商店）、DumbbellPanel（哑铃）共用
	- Roll（报价卡 / 扭蛋卡 / 材质机牌子）用 ShowArm 在独立视口展示材质手臂，返回的 Part 可原地换色换材质

	加载：
		local Cards = require(script.Parent.Cards)
		Cards.Clear(grid)
		local card = Cards.Clone(template, grid, 1, C.Card)
		Cards.SetIcon(card, arm.Icon)
		local btn, lbl = Cards.Button(card, C.Green)
		local preview, arm = Cards.ShowArm(viewport, mat.Color, Enum.Material.Grass)
		Cards.ApplyRarity(card, mat.Xyd)
]]

local Utils = require(game.ReplicatedFirst.AllSideCode.UtilsSystem)
local ArmWrestleConfig = Utils.ArmWrestleConfig
local ArmWrestleStyle = Utils.ArmWrestleStyle
local ViewportFrameModule = Utils.ViewportFrameModule

local Common = require(script.Parent.Common)

local Cards = {}

local CARD_NAME = "Card"
local PREVIEW_NAME = "Preview"
-- 与 Panels 材质卡同款机位：R6 手臂斜放并略转向镜头
local ARM_SIZE = Vector3.new(1, 2, 1)
local ARM_CFRAME = CFrame.Angles(0, math.rad(30), math.rad(-35))
local ARM_CAMERA_CFRAME = CFrame.lookAt(Vector3.new(0, 0, 3.6), Vector3.zero)
local ARM_FOV = 40
local DEFAULT_XYD = 1
-- 竖向渐变（自上而下）：{ 位置, 明暗 }，明暗 >0 向白混合、<0 向黑混合；顶部略亮，底部一条暗边
local RARITY_FILL_ROTATION = 90
local RARITY_FILL_STOPS = {
	{ 0, 0.25 },
	{ 0.45, 0.08 },
	{ 0.86, 0 },
	{ 0.87, -0.22 },
	{ 1, -0.25 },
}
local RARITY_TEXT_TINT = 0.3

local C = ArmWrestleStyle.Colors
local BLACK = Color3.new(0, 0, 0)
local WHITE = Color3.new(1, 1, 1)

--[[
	按明暗系数调整颜色
	@param color Color3 - 原色
	@param k number - >0 向白混合，<0 向黑混合，取值 -1..1
	@return Color3 - 调整后的颜色
]]
local function _shift(color: Color3, k: number): Color3
	if k >= 0 then
		return color:Lerp(WHITE, k)
	end
	return color:Lerp(BLACK, -k)
end

--[[
	清空网格内已克隆的卡片（模板保留）
	@param grid ScrollingFrame - 网格
]]
function Cards.Clear(grid: ScrollingFrame)
	for _, child in ipairs(grid:GetChildren()) do
		if child.Name == CARD_NAME then
			child:Destroy()
		end
	end
end

--[[
	克隆卡片模板并挂入网格
	@param template Frame - 模板（Visible=false）
	@param grid ScrollingFrame - 网格
	@param order number - LayoutOrder
	@param bg Color3 - 底色
	@param strokeColor Color3? - 边框 "Border" 颜色，nil 为黑
	@return Frame - 卡片
]]
function Cards.Clone(template: Frame, grid: ScrollingFrame, order: number, bg: Color3, strokeColor: Color3?): Frame
	local card = template:Clone()
	card.Name = CARD_NAME
	card.LayoutOrder = order
	card.BackgroundColor3 = bg
	local border = card:FindFirstChild("Border") :: UIStroke?
	if border then
		border.Color = strokeColor or C.Black
	end
	card.Visible = true
	card.Parent = grid
	return card
end

--[[
	取卡片底部按钮及其文字，并设底色
	@param card Frame - 卡片
	@param color Color3 - 底色
	@return TextButton - 按钮
	@return TextLabel - 文字
]]
function Cards.Button(card: Frame, color: Color3): (TextButton, TextLabel)
	local btn = card:FindFirstChild("Button") :: TextButton
	btn.BackgroundColor3 = color
	return btn, btn:FindFirstChild("Label") :: TextLabel
end

--[[
	取卡片子文本
	@param card Frame - 卡片
	@param name string - 子节点名（Mult / ItemName / Rarity / Header / Desc 等）
	@return TextLabel - 文本
]]
function Cards.Label(card: Frame, name: string): TextLabel
	return card:FindFirstChild(name) :: TextLabel
end

--[[
	按稀有度给行卡片上色：Fill 竖向渐变、"Rarity" 文本（文案与颜色，描边固定黑）
	卡片须以白底克隆（Cards.Clone bg = 白），否则渐变相乘后发暗；外框保持 Cards.Clone 的默认黑色
	@param card Frame - 已克隆的卡片（含 UIGradient "Fill"、TextLabel "Rarity"，缺失的节点跳过）
	@param xyd number? - 稀有度档 1..7（与条目 Xyd / ArmWrestleConfig.GetRarity 一致）；无效时按 1
]]
function Cards.ApplyRarity(card: Frame, xyd: number?)
	local rarity = ArmWrestleConfig.GetRarity(if typeof(xyd) == "number" then xyd else DEFAULT_XYD)
	if not rarity then
		return
	end
	local base: Color3 = rarity.Color
	local fill = card:FindFirstChild("Fill")
	if fill and fill:IsA("UIGradient") then
		local keys = table.create(#RARITY_FILL_STOPS)
		for i, stop in ipairs(RARITY_FILL_STOPS) do
			keys[i] = ColorSequenceKeypoint.new(stop[1], _shift(base, stop[2]))
		end
		fill.Color = ColorSequence.new(keys)
		fill.Rotation = RARITY_FILL_ROTATION
	end
	local label = card:FindFirstChild("Rarity")
	if label and label:IsA("TextLabel") then
		label.TextColor3 = _shift(base, RARITY_TEXT_TINT)
		local stroke = label:FindFirstChild("TextStroke")
		if stroke and stroke:IsA("UIStroke") then
			stroke.Color = BLACK
		end
		Common.SetText(label, rarity.ZhName)
	end
end

--[[
	在卡片 ImageLabel "Preview" 上显示条目图标；卡片无 Preview 或类型不符时跳过
	@param card Frame - 卡片
	@param image string? - 配置条目的 Icon 字段（rbxassetid://...）；nil 时清空图片
]]
function Cards.SetIcon(card: Frame, image: string?)
	local preview = card:FindFirstChild(PREVIEW_NAME)
	if preview and preview:IsA("ImageLabel") then
		preview.Image = image or ""
	end
end

--[[
	在独立视口里展示一条手臂（不登记网格，调用方持有并负责 destroy）
	@param viewport ViewportFrame - 目标视口
	@param color Color3 - 手臂颜色
	@param material Enum.Material - 手臂材质
	@return any? - ViewportFrameModule 实例；视口无效为 nil
	@return BasePart? - 手臂 Part，可直接改 Color / Material 切换展示，免重建模型
]]
function Cards.ShowArm(viewport: ViewportFrame, color: Color3, material: Enum.Material): (any?, BasePart?)
	local part = Instance.new("Part")
	part.Name = "Arm"
	part.Anchored = true
	part.Size = ARM_SIZE
	part.Color = color
	part.Material = material
	local model = Instance.new("Model")
	model.Name = "ArmPreview"
	part.Parent = model
	model.PrimaryPart = part
	local preview = ViewportFrameModule.new(viewport, model, ARM_CAMERA_CFRAME, ARM_CFRAME)
	if not preview then
		model:Destroy()
		return nil, nil
	end
	preview:SetViewportFrameCameraFOV(ARM_FOV)
	return preview, part
end

return Cards
