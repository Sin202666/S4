--[[
	Module: ShopPanel
	Description: 商城弹窗（ScreenGui.ArmWrestleShop）：通行证 / 力量 / 药水 / 兑换码 四个分区
	Author: 程莘
	Created: 2026-10-14
	Last Modified: 2026-10-16

	功能：
	- 通行证区：ArmWrestleConfig.ShopPassOrder（2 倍力量 / 2 倍金钱 / 自动点击），已拥有读 OwnedPasses 镜像
	- 力量区：ShopPackOrder 三档力量包，数值 = PerClick × Amount（与服务端 Economy.GrantProduct 同公式，仅展示）
	- 药水区：PotionOrder 三种药水；购买走 Common.Purchase，使用发 Action "UsePotion"，结果走 TipsModule 通用提示；
	  持有数读背包镜像（Common.ItemCount(药水 ItemId)）；剩余时长不在商城展示（见 PotionBuffBar）
	- 兑换码区：输入框 + 兑换按钮，走 NetMsg.REDEEM_CODE（服务端 SystemCode 校验与发奖）
	- 只展示与发请求；购买发货、药水计时、兑换结算全在服务端

	静态 UI（Studio 维护于 StarterGui.ScreenGui.ArmWrestleShop，本模块只绑定不新建，节点名为代码契约）：
	- Title / CloseButton（关闭由 Panels 绑定）
	- Scroll(ScrollingFrame，UIListLayout 纵向)
	  - PassTitle / PackTitle / PotionTitle / CodeTitle：分区标题 TextLabel
	  - PassRow / PackRow / PotionRow：横向卡片行，内含模板 PassTemp / PackTemp / PotionTemp（Visible=false，克隆为 "Card"）
	    - 公共：Name / Icon（Icon Attribute 驱动的图标）/ Button(Label)，底色由本模块按商品写入
	    - PassTemp：Desc；PackTemp：Amount；PotionTemp：Desc / Count / UseButton(Label)
	  - CodeRow：Art(插画 ImageLabel，可选) / Input(TextBox) / RedeemButton(Label) / Hint(社区提示)

	与相关模块：
	- Panels：绑定外框、开关与路由，显示后调 OnOpened
	- Cards：模板克隆与按钮取用

	加载：
		local ShopPanel = require(script.Parent.ShopPanel)
		ShopPanel.Bind(panel)   -- Panels.Bind 内调用一次
		ShopPanel.OnOpened()    -- 弹窗显示后
]]

local Utils = require(game.ReplicatedFirst.AllSideCode.UtilsSystem)
local LocalPlayer = Utils.LocalPlayer
local ArmWrestleConfig = Utils.ArmWrestleConfig
local ArmWrestleStyle = Utils.ArmWrestleStyle
local NetWork = Utils.NetWork
local NetMsg = Utils.NetMsg
local TipsModule = Utils.TipsModule
local SystemUISfx = Utils.SystemUISfx

local Common = require(script.Parent.Common)
local Cards = require(script.Parent.Cards)

local Style = ArmWrestleStyle
local C = Style.Colors
local FormatFixed = ArmWrestleConfig.FormatFixed

local ShopPanel = {}

local PASS_LOOK: { [string]: { Color: Color3, Icon: string } } = {
	DoubleStrength = { Color = Color3.fromRGB(40, 190, 60), Icon = "passStrength" },
	DoubleCash = { Color = Color3.fromRGB(245, 175, 20), Icon = "passCash" },
	AutoClicker = { Color = Color3.fromRGB(50, 170, 245), Icon = "passAutoClick" },
}
-- 力量包按 ShopPackOrder 下标取色
local PACK_COLORS = {
	Color3.fromRGB(50, 170, 245),
	Color3.fromRGB(170, 80, 245),
	Color3.fromRGB(245, 90, 60),
}
local POTION_COLORS: { [string]: Color3 } = {
	StrengthPotion = Color3.fromRGB(230, 70, 70),
	TrainSpeedPotion = Color3.fromRGB(60, 150, 255),
	CashPotion = Color3.fromRGB(245, 185, 30),
}
local DEFAULT_ICON = "star"
local PACK_ICON = "strength"
local POTION_ICON = "potion"
local BUY_COLOR = C.Green
local OWNED_COLOR = C.Disabled
local USE_COLOR = C.Equip
local PASS_KIND = "Pass"
local PRODUCT_KIND = "Product"
local ACTION_USE_POTION = "UsePotion"
local ERR_POTION_EMPTY = "empty"
local SECONDS_PER_MINUTE = 60
-- Roblox 私有区 Robux 字形（全项目统一用字形，不用 R$ 文本或图片）
local ROBUX_GLYPH = utf8.char(0xE002)
-- 与服务端 SystemCode 的 REDEEM_CODE_MAX_LEN 一致
local REDEEM_CODE_MAX_LEN = 50

type PotionView = { count: TextLabel, use: TextButton, useLabel: TextLabel, itemId: number }

local _panel: Frame?
local _scroll: ScrollingFrame?
local _passRow: Frame?
local _passTemp: Frame?
local _packRow: Frame?
local _packTemp: Frame?
local _potionRow: Frame?
local _potionTemp: Frame?
local _codeInput: TextBox?
local _redeemBusy = false
local _packAmounts: { { key: string, label: TextLabel } } = {}
local _potionViews: { [string]: PotionView } = {}

--[[
	写入 Robux 价签（字形 + 数字，数字不翻译）
	@param lbl TextLabel - 价签
	@param robux number - Robux 价格
]]
local function _setRobuxPrice(lbl: TextLabel, robux: number)
	Common.SetRaw(lbl, ROBUX_GLYPH .. " " .. tostring(robux))
end

--[[
	卡片公共部分：名称、图标
	@param card Frame - 克隆出的卡片
	@param nameKey string - 名称翻译键（配置 ZhName）
	@param icon string - ArmWrestleStyle.Icons 的键
]]
local function _cardHead(card: Frame, nameKey: string, icon: string)
	Common.SetText(Cards.Label(card, "Name"), nameKey)
	Style.SetIcon(Cards.Label(card, "Icon"), icon)
end

--[[
	渲染通行证区
]]
local function _renderPasses()
	local row, temp = _passRow, _passTemp
	if not row or not temp then
		return
	end
	Cards.Clear(row :: any)
	local owned = Common.KeySet("OwnedPasses")
	for i, key in ipairs(ArmWrestleConfig.ShopPassOrder) do
		local pass = ArmWrestleConfig.GetGamePass(key)
		if not pass then
			continue
		end
		local look = PASS_LOOK[key]
		local card = Cards.Clone(temp, row :: any, i, if look then look.Color else C.Card)
		_cardHead(card, pass.ZhName, if look then look.Icon else DEFAULT_ICON)
		Common.SetText(Cards.Label(card, "Desc"), pass.ZhDes)
		local has = owned[key] == true
		local btn, lbl = Cards.Button(card, if has then OWNED_COLOR else BUY_COLOR)
		if has then
			Common.SetText(lbl, "已拥有")
		else
			_setRobuxPrice(lbl, pass.Robux)
		end
		btn.MouseButton1Click:Connect(function()
			if not has then
				Common.Purchase(PASS_KIND, key)
			end
		end)
	end
end

--[[
	刷新力量包数值（随每次训练力量 PerClick 变化）
]]
local function _refreshPackAmounts()
	local perClick = Common.Attr("PerClick", 1)
	for _, pack in ipairs(_packAmounts) do
		local product = ArmWrestleConfig.GetProduct(pack.key)
		if product then
			Common.SetText(pack.label, "数值增加", { FormatFixed(perClick * (product.Amount or 0)) })
		end
	end
end

--[[
	渲染力量区
]]
local function _renderPacks()
	local row, temp = _packRow, _packTemp
	if not row or not temp then
		return
	end
	Cards.Clear(row :: any)
	table.clear(_packAmounts)
	for i, key in ipairs(ArmWrestleConfig.ShopPackOrder) do
		local product = ArmWrestleConfig.GetProduct(key)
		if not product then
			continue
		end
		local card = Cards.Clone(temp, row :: any, i, PACK_COLORS[i] or C.Card)
		_cardHead(card, product.ZhName, PACK_ICON)
		local amount = Cards.Label(card, "Amount")
		Style.SetIcon(amount, PACK_ICON)
		table.insert(_packAmounts, { key = key, label = amount })
		local btn, lbl = Cards.Button(card, BUY_COLOR)
		_setRobuxPrice(lbl, product.Robux)
		btn.MouseButton1Click:Connect(function()
			Common.Purchase(PRODUCT_KIND, key)
		end)
	end
	_refreshPackAmounts()
end

--[[
	刷新药水持有数与使用按钮状态（只改文字/颜色，不重建卡片）
]]
local function _refreshPotions()
	for _, view in pairs(_potionViews) do
		local count = Common.ItemCount(view.itemId)
		Common.SetText(view.count, "药水持有数量", { tostring(count) })
		view.use.BackgroundColor3 = if count > 0 then USE_COLOR else OWNED_COLOR
	end
end

--[[
	请求使用一瓶药水（库存与计时以服务端为准）
	@param key string - 药水键
]]
local function _usePotion(key: string)
	local potion = ArmWrestleConfig.GetPotion(key)
	if not potion then
		return
	end
	if Common.ItemCount(potion.ItemId) <= 0 then
		TipsModule.ErrorTips(LocalPlayer, "没有药水")
		return
	end
	local ok, err = Common.Invoke(ACTION_USE_POTION, key)
	if ok then
		TipsModule.NormalTips(LocalPlayer, "药水已生效", { { potion.ZhName } })
		SystemUISfx.PlayReward()
	elseif err == ERR_POTION_EMPTY then
		TipsModule.ErrorTips(LocalPlayer, "没有药水")
	else
		Common.ShowErrorTip(err)
	end
	_refreshPotions()
end

--[[
	渲染药水区
]]
local function _renderPotions()
	local row, temp = _potionRow, _potionTemp
	if not row or not temp then
		return
	end
	Cards.Clear(row :: any)
	table.clear(_potionViews)
	for i, key in ipairs(ArmWrestleConfig.PotionOrder) do
		local potion = ArmWrestleConfig.GetPotion(key)
		local product = potion and ArmWrestleConfig.GetProduct(potion.ProductKey)
		if not potion or not product then
			continue
		end
		local card = Cards.Clone(temp, row :: any, i, POTION_COLORS[key] or C.Card)
		_cardHead(card, potion.ZhName, potion.Icon or POTION_ICON)
		Common.SetText(Cards.Label(card, "Desc"), potion.ZhDes, { tostring(potion.Duration // SECONDS_PER_MINUTE) })
		local btn, lbl = Cards.Button(card, BUY_COLOR)
		_setRobuxPrice(lbl, product.Robux)
		btn.MouseButton1Click:Connect(function()
			Common.Purchase(PRODUCT_KIND, potion.ProductKey)
		end)
		local use = card:FindFirstChild("UseButton") :: TextButton
		local useLabel = use:FindFirstChild("Label") :: TextLabel
		Common.SetText(useLabel, "使用")
		use.MouseButton1Click:Connect(function()
			_usePotion(key)
		end)
		_potionViews[key] = { count = Cards.Label(card, "Count"), use = use, useLabel = useLabel, itemId = potion.ItemId }
	end
	_refreshPotions()
end

--[[
	提交兑换码（防连点；结果只做提示，发奖在服务端 SystemCode）
]]
local function _redeem()
	local input = _codeInput
	if _redeemBusy or not input then
		return
	end
	local text = string.upper((string.gsub(input.Text, "^%s*(.-)%s*$", "%1")))
	if text == "" then
		TipsModule.ErrorTips(LocalPlayer, "兑换码不能为空")
		return
	end
	if string.len(text) >= REDEEM_CODE_MAX_LEN then
		TipsModule.ErrorTips(LocalPlayer, "兑换码错误")
		return
	end
	_redeemBusy = true
	local ok = NetWork.InvokeServer(NetMsg.REDEEM_CODE, text)
	_redeemBusy = false
	if ok then
		input.Text = ""
		TipsModule.NormalTips(LocalPlayer, "兑换码兑换成功")
		SystemUISfx.PlayReward()
	else
		TipsModule.ErrorTips(LocalPlayer, "兑换码错误")
	end
end

--[[
	重绘全部卡片分区（面板不可见时跳过）
]]
function ShopPanel.Render()
	local panel = _panel
	if not panel or not panel.Visible then
		return
	end
	_renderPasses()
	_renderPacks()
	_renderPotions()
end

--[[
	弹窗显示后：回到顶部并重绘
]]
function ShopPanel.OnOpened()
	if _scroll then
		_scroll.CanvasPosition = Vector2.zero
	end
	ShopPanel.Render()
end

--[[
	绑定商城静态节点与镜像监听（Panels.Bind 调一次）
	@param panel Frame - ScreenGui.ArmWrestleShop
]]
function ShopPanel.Bind(panel: Frame)
	_panel = panel
	Common.SetText(Common.Get(panel, "Title") :: TextLabel, "商店")
	local scroll = Common.Get(panel, "Scroll") :: ScrollingFrame
	_scroll = scroll
	Common.SetText(Common.Get(scroll, "PassTitle") :: TextLabel, "商城分区-通行证")
	Common.SetText(Common.Get(scroll, "PackTitle") :: TextLabel, "商城分区-力量")
	Common.SetText(Common.Get(scroll, "PotionTitle") :: TextLabel, "商城分区-药水")
	Common.SetText(Common.Get(scroll, "CodeTitle") :: TextLabel, "商城分区-兑换码")
	_passRow = Common.Get(scroll, "PassRow") :: Frame
	_passTemp = Common.Get(scroll, "PassRow", "PassTemp") :: Frame
	_packRow = Common.Get(scroll, "PackRow") :: Frame
	_packTemp = Common.Get(scroll, "PackRow", "PackTemp") :: Frame
	_potionRow = Common.Get(scroll, "PotionRow") :: Frame
	_potionTemp = Common.Get(scroll, "PotionRow", "PotionTemp") :: Frame

	local input = Common.Get(scroll, "CodeRow", "Input") :: TextBox
	_codeInput = input
	input.Text = ""
	Common.SetText(input :: any, "请输入兑换码")
	local redeemBtn = Common.Get(scroll, "CodeRow", "RedeemButton") :: TextButton
	Common.SetText(Common.Get(redeemBtn, "Label") :: TextLabel, "兑换")
	Common.SetText(Common.Get(scroll, "CodeRow", "Hint") :: TextLabel, "兑换码社区提示")
	redeemBtn.MouseButton1Click:Connect(_redeem)
	input.FocusLost:Connect(function(enterPressed: boolean)
		if enterPressed then
			_redeem()
		end
	end)

	LocalPlayer:GetAttributeChangedSignal("OwnedPasses"):Connect(function()
		if panel.Visible then
			_renderPasses()
		end
	end)
	LocalPlayer:GetAttributeChangedSignal("PerClick"):Connect(_refreshPackAmounts)
	for _, key in ipairs(ArmWrestleConfig.PotionOrder) do
		local potion = ArmWrestleConfig.GetPotion(key)
		if potion then
			Common.OnItemChanged(potion.ItemId, _refreshPotions)
		end
	end
end

return ShopPanel
