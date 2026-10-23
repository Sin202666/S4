--[[
	Module: Common
	Description: ArmWrestleHUD 子模块共享上下文：静态 HUD 绑定、彩纸、玩家镜像读取、请求转发、弹窗开关
	Author: 程莘
	Created: 2026-10-14
	Last Modified: 2026-10-16

	只读服务端同步的 Attribute / PlayerData / 背包 NumberValue；服务端请求一律经客户端 SystemArmWrestle.Invoke。
	货币即背包金币（EnumMgr.ItemID.Coin），用 Common.Coin() 读，不再读 Cash Attribute。
	药水持有数同样是背包物品（ArmWrestleConfig.GetPotion().ItemId），用 Common.ItemCount / Common.OnItemChanged 读。
	文本提示统一走 TipsModule（渲染在 TipsGui.NewTipsFrame，位置由 TipsAnchor 贴在 Roblox 顶栏下方）；服务端失败码用 Common.ShowErrorTip 转成错误提示。

	静态 UI（Studio 中 StarterGui 下维护，代码只绑定不新建）：
	- ScreenGui.ArmWrestleHUD：全屏 HUD 容器；左下角 Cash 为现金；各分组 Frame 自带 UIScale（HUD 设计倍率），根缩放由 UISetMgr 写 ScreenGui.UIScale
	- ScreenGui.ArmWrestleShop：商店弹窗，经 UIManager（SHOW_LOCAL_UI）开关，UIScale 由 UISetMgr 适配
	- 文字左侧图标由 Attribute "Icon" 驱动，Bind 时 ArmWrestleStyle.BindIcons 统一接管（含运行时克隆的卡片）
]]

local Utils = require(game.ReplicatedFirst.AllSideCode.UtilsSystem)
local ContentProvider = Utils.ContentProvider
local LocalPlayer = Utils.LocalPlayer
local ArmWrestleConfig = Utils.ArmWrestleConfig
local ArmWrestleStyle = Utils.ArmWrestleStyle
local EnumMgr = Utils.EnumMgr
local GetData = Utils.GetData
local PlayerData = Utils.PlayerData
local TranslationHelper = Utils.TranslationHelper
local NetWork = Utils.NetWork
local NetMsg = Utils.NetMsg
local TipsModule = Utils.TipsModule
local SystemUISfx = Utils.SystemUISfx
local SystemBuyRoblox = Utils.SystemBuyRoblox
local Log = Utils.Log

local Style = ArmWrestleStyle
local BagData = GetData.Bag

local Common = {}

Common.COIN_ID = EnumMgr.ItemID.Coin

local SCREEN_GUI_NAME = "ScreenGui"
local SCREEN_GUI_FULL_NAME = "ScreenGui_Full"
local HUD_NAME = "ArmWrestleHUD"

Common.gui = nil :: Frame?
Common.screenGui = nil :: ScreenGui?
Common.screenGuiFull = nil :: ScreenGui?
Common.hud = {} :: { [string]: any }

local _rootScale: UIScale?
local _textCache: { [Instance]: string } = setmetatable({}, { __mode = "k" }) :: any
local _invoke: ((string, ...any) -> ...any)? = nil

--[[
	拼接文本缓存签名
	@param key string - 翻译键或原文
	@param args table? - 占位参数
	@return string - 签名
]]
local function _signature(key: string, args: { [any]: any }?): string
	if not args then
		return key
	end
	local parts = { key }
	for i, v in ipairs(args) do
		parts[i + 1] = if type(v) == "table" then "{" .. tostring(v[1]) .. "}" else tostring(v)
	end
	return table.concat(parts, "\0")
end

--[[
	后台预加载全部 HUD 图标：按需显示的按钮 / 弹窗卡片首次出现时贴图未下载会留空白
]]
local function _preloadIcons()
	local assets = {}
	for _, id in pairs(Style.Icons) do
		table.insert(assets, id)
	end
	task.spawn(function()
		local ok, err = pcall(ContentProvider.PreloadAsync, ContentProvider, assets)
		if not ok then
			Log.warn("ArmWrestleHUD 图标预加载失败", err)
		end
	end)
end

--[[
	注入请求函数（由 HUD.Init 传入客户端 SystemArmWrestle.Invoke）
	@param fn function - (action, ...) -> ok, result
]]
function Common.SetInvoker(fn: (string, ...any) -> ...any)
	_invoke = fn
end

--[[
	发 Action 请求（服务端权威结算）
	@param action string - DevGrant / UsePotion / ClaimOffline / ClaimMenuGift
	@param ... any - 参数
	@return any - 服务端返回（ok, result）
]]
function Common.Invoke(action: string, ...: any): ...any
	if not _invoke then
		return false
	end
	local results = table.pack(pcall(_invoke, action, ...))
	if not results[1] then
		Log.warn("ArmWrestleHUD.Invoke 失败", action, results[2])
		return false
	end
	return table.unpack(results, 2, results.n)
end

--[[
	读玩家 Attribute
	@param name string - Attribute 名
	@param default any - 缺省值
	@return any - 值
]]
function Common.Attr(name: string, default: any): any
	local v = LocalPlayer:GetAttribute(name)
	if v == nil then
		return default
	end
	return v
end

--[[
	当前背包金币（读服务端同步的 Bag NumberValue，仅展示）
	@return number - 金币数；镜像未就绪为 0
]]
function Common.Coin(): number
	return BagData.GetItemCountByID(LocalPlayer, Common.COIN_ID)
end

--[[
	背包内某物品持有数（读服务端同步的 Bag NumberValue，仅展示）
	@param itemId number - 物品 Id（itemdataConf 键）
	@return number - 持有数；镜像未就绪为 0
]]
function Common.ItemCount(itemId: number): number
	return BagData.GetItemCountByID(LocalPlayer, itemId)
end

--[[
	监听背包内某物品数量变化（异步等待 Bag NumberValue 出现后连接，连接后立即回调一次）
	@param itemId number - 物品 Id（须为 isShow = 1 且可叠加的物品，否则服务端不建 NumberValue，永远等不到）
	@param callback () -> () - 数量变化回调
]]
function Common.OnItemChanged(itemId: number, callback: () -> ())
	task.spawn(function()
		local value = BagData.WaitBagNumberValue(LocalPlayer, itemId)
		value.Changed:Connect(callback)
		callback()
	end)
end

--[[
	档案只读（Arms / Mats 拥有表）
	@return table - ArmWrestle 子树
]]
function Common.Data(): { [string]: any }
	local data = PlayerData.GetPlrDataByKey(LocalPlayer, "ArmWrestle")
	return if type(data) == "table" then data else ArmWrestleConfig.GetDefaultProfile()
end

--[[
	解析逗号分隔的会话镜像（OwnedPasses）
	@param name string - Attribute 名
	@return table - { [key] = true }
]]
function Common.KeySet(name: string): { [string]: boolean }
	local set = {}
	local raw = LocalPlayer:GetAttribute(name)
	if type(raw) == "string" then
		for key in string.gmatch(raw, "[^,]+") do
			set[key] = true
		end
	end
	return set
end

--[[
	是否拥有通行证（仅展示）
	@param key string - AutoClicker / DoubleStrength / DoubleCash
	@return boolean
]]
function Common.HasPass(key: string): boolean
	return Common.KeySet("OwnedPasses")[key] == true
end

--[[
	秒数格式化 m:ss
	@param t number - 秒
	@return string - 展示串
]]
function Common.Mmss(t: number): string
	t = math.max(0, math.floor(t))
	return string.format("%d:%02d", t // 60, t % 60)
end

--[[
	仅在内容变化时写翻译文本（4Hz 刷新时避免反复写本地化 Attribute）
	@param lbl TextLabel - 目标
	@param key string - 翻译键
	@param args table? - 占位参数（数字下标，嵌套翻译用 {key}）
]]
function Common.SetText(lbl: TextLabel, key: string, args: { [any]: any }?)
	local sig = "K" .. _signature(key, args)
	if _textCache[lbl] == sig then
		return
	end
	_textCache[lbl] = sig
	TranslationHelper.SetText(lbl, key, args)
end

--[[
	仅在内容变化时写原文（数字、倒计时）
	@param lbl TextLabel - 目标
	@param text string - 原文
]]
function Common.SetRaw(lbl: TextLabel, text: string)
	local sig = "R" .. text
	if _textCache[lbl] == sig then
		return
	end
	_textCache[lbl] = sig
	TranslationHelper.SetRawText(lbl, text)
end

--[[
	彩纸飘落（盖过弹窗，见 ArmWrestleStyle.Confetti）
]]
function Common.Confetti()
	local screenGui = Common.screenGui
	if not screenGui then
		return
	end
	Style.Confetti(screenGui)
end

--[[
	购买入口：passID 为 0 / 缺失时走 Studio DevGrant；否则走商城表 OnlyTag → SystemBuyRoblox
	@param kind string - Pass / Product
	@param key string - ItemShopData.OnlyTag（与通行证/商品键一致）
]]
function Common.Purchase(kind: string, key: string)
	local entry = if kind == "Pass" then ArmWrestleConfig.GetGamePass(key) else ArmWrestleConfig.GetProduct(key)
	if not entry then
		return
	end
	if type(entry.Id) ~= "number" or entry.Id <= 0 then
		local ok = Common.Invoke("DevGrant", kind, key)
		if ok then
			TipsModule.NormalTips(LocalPlayer, "测试购买成功", { { entry.ZhName } })
			SystemUISfx.PlaySuccess()
		else
			TipsModule.ErrorTips(LocalPlayer, "购买失败")
		end
		return
	end
	if not SystemBuyRoblox.BuyRobloxByOnlyTag(LocalPlayer, key) then
		TipsModule.ErrorTips(LocalPlayer, "购买失败")
	end
end

--[[
	服务端失败码 → TipsModule 错误提示（未列出的失败码不提示）
	@param err any - 服务端返回的失败码："cash" / "owned" / "wait" / "battle"；其它值静默
]]
function Common.ShowErrorTip(err: any)
	if err == "cash" then
		TipsModule.ErrorTips(LocalPlayer, "现金不够")
	elseif err == "owned" then
		TipsModule.ErrorTips(LocalPlayer, "已拥有")
	elseif err == "wait" then
		TipsModule.ErrorTips(LocalPlayer, "未到时间")
	elseif err == "battle" then
		TipsModule.ErrorTips(LocalPlayer, "对局中无法操作")
	end
end

--[[
	按路径逐级等待子节点（静态 UI 随 ScreenGui 整体复制到 PlayerGui，正常立即命中；缺节点时 WaitForChild 会告警）
	@param root Instance - 起点
	@param ... string - 逐级子节点 Name
	@return Instance - 末级节点
]]
function Common.Get(root: Instance, ...: string): Instance
	local node = root
	for _, name in ipairs({ ... }) do
		node = node:WaitForChild(name)
	end
	return node
end

--[[
	经 UIManager 开关 ScreenGui 下的弹窗（播放 PopUp/PopBack，缩放由 UISetMgr 适配）
	@param uiName string - 弹窗 Frame 名，同 GuiScripts 模块名（ArmWrestleShop / OnlineAward 等）
	@param isShow boolean? - true 打开、false 关闭、nil 按当前显隐取反
]]
function Common.ShowPopup(uiName: string, isShow: boolean?)
	NetWork.FireBindable(NetMsg.SHOW_LOCAL_UI, uiName, nil, isShow, true)
end

--[[
	HUD 在屏幕上的实际像素倍率（ScreenGui 根 UIScale），供独立特效 ScreenGui 按像素换算尺寸
	@return number - 倍率；未绑定时为 1
]]
function Common.HudScale(): number
	return if _rootScale then _rootScale.Scale else 1
end

--[[
	绑定 Studio 中维护的静态 HUD（PlayerGui.ScreenGui.ArmWrestleHUD）：图标
	@return Frame - HUD 容器
]]
function Common.Bind(): Frame
	local playerGui = LocalPlayer:WaitForChild("PlayerGui")
	local screenGui = playerGui:WaitForChild(SCREEN_GUI_NAME) :: ScreenGui
	local screenGuiFull = playerGui:FindFirstChild(SCREEN_GUI_FULL_NAME)
	local gui = Common.Get(screenGui, HUD_NAME) :: Frame
	Common.screenGui = screenGui
	if screenGuiFull and screenGuiFull:IsA("ScreenGui") then
		Common.screenGuiFull = screenGuiFull
	end
	Common.gui = gui
	-- 特效像素倍率跟主 ScreenGui 根缩放（现金已不在 ScreenGui_Full）
	_rootScale = screenGui:FindFirstChildOfClass("UIScale")
	_preloadIcons()
	Style.BindIcons(gui)
	return gui
end

return Common
