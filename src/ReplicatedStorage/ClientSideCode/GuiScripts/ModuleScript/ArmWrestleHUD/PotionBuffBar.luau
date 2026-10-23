--[[
	Module: PotionBuffBar
	Description: 扳手腕主界面右下角药水 Buff 栏：生效中的药水显示图标、倍率与剩余时间，点击图标弹出药水详情
	Author: 程莘
	Created: 2026-10-15
	Last Modified: 2026-10-15

	功能：
	- 每种生效中的药水一个图标（ArmWrestleConfig.GetPotion().Icon → ArmWrestleStyle.Icons），左上角「xN」，底部 m:ss 倒计时
	- 点击图标弹出详情（名称 / 效果描述 / 剩余时间）；再点同一图标收起，点其它图标切换；该药水到期时详情自动收起
	- 对局中也显示（金币药水作用于对局），不加入 Common.hud 的对局隐藏分组
	- 只读服务端镜像 PotionEnd_<键>（服务器时间，workspace:GetServerTimeNow 口径）；计时与倍率结算全在服务端 SystemArmWrestle.Potion

	静态 UI（Studio 维护于 StarterGui.ScreenGui.ArmWrestleHUD，本模块只绑定不新建，节点名为代码契约）：
	- PotionBuff(UIScale，右下角、与 Boost 同一排且紧贴其左侧；Boost 宽度变化须同步调整 Position)
	  - List(UIListLayout 横向靠右)
	    - BuffTemp（ImageButton 模板，Visible=false，克隆为 "Buff"）/ Mult（「xN」）、Timer（倒计时）
	  - Detail（默认隐藏）/ Title、Band / Desc、Left

	与相关模块：
	- ShopPanel：商城药水卡片的购买 / 使用入口，与本栏读同一组镜像，倒计时口径一致
	- BoostBar：同在右下角的现金加成栏（本栏位于其左侧同一排）
	- ArmWrestleHUD.init：Bind 一次，Tick 由 HUD 4Hz 刷新转发

	加载：
		local PotionBuffBar = require(script.PotionBuffBar)
		PotionBuffBar.Bind(Common.gui)   -- ArmWrestleHUD 绑定静态界面时调一次
		PotionBuffBar.Tick()             -- 4Hz，刷新倒计时与到期
]]

local Utils = require(game.ReplicatedFirst.AllSideCode.UtilsSystem)
local Workspace = game:GetService("Workspace")
local LocalPlayer = Utils.LocalPlayer
local ArmWrestleConfig = Utils.ArmWrestleConfig
local ArmWrestleStyle = Utils.ArmWrestleStyle

local Common = require(script.Parent.Common)

local Style = ArmWrestleStyle

local PotionBuffBar = {}

local ATTR_END_PREFIX = "PotionEnd_"
local BUFF_NAME = "Buff"
local SECONDS_PER_MINUTE = 60
local DEFAULT_ICON = "potion"

type PotionInfo = { zhName: string, zhDes: string, mult: number, minutes: number, image: string }
type BuffView = { button: ImageButton, timer: TextLabel }

local _list: Frame?
local _temp: ImageButton?
local _detail: Frame?
local _detailTitle: TextLabel?
local _detailDesc: TextLabel?
local _detailLeft: TextLabel?
-- Bind 时缓存药水展示字段：GetPotion 每次深拷贝，4Hz 刷新不反复调用
local _potions: { [string]: PotionInfo } = {}
local _views: { [string]: BuffView } = {}
local _selected: string? = nil

--[[
	药水剩余秒数（读服务端镜像截止时间）
	@param key string - 药水键（ArmWrestleConfig.PotionOrder 中的键）
	@param serverNow number - 当前服务器时间（workspace:GetServerTimeNow）
	@return number - 剩余秒数；未生效为 0 或负数
]]
local function _left(key: string, serverNow: number): number
	return Common.Attr(ATTR_END_PREFIX .. key, 0) - serverNow
end

--[[
	收起详情气泡
]]
local function _hideDetail()
	_selected = nil
	if _detail then
		_detail.Visible = false
	end
end

--[[
	刷新详情气泡的剩余时间；所选药水已到期则收起
	@param serverNow number - 当前服务器时间
]]
local function _refreshDetail(serverNow: number)
	local key = _selected
	local leftLabel = _detailLeft
	if not key or not leftLabel then
		return
	end
	local left = _left(key, serverNow)
	if left <= 0 then
		_hideDetail()
		return
	end
	Common.SetText(leftLabel, "药水剩余时间", { Common.Mmss(left) })
end

--[[
	点击图标：打开该药水详情；已打开同一药水则收起
	@param key string - 药水键
]]
local function _toggleDetail(key: string)
	local detail, title, desc = _detail, _detailTitle, _detailDesc
	local info = _potions[key]
	if not detail or not title or not desc or not info then
		return
	end
	if _selected == key then
		_hideDetail()
		return
	end
	_selected = key
	Common.SetText(title, info.zhName)
	Common.SetText(desc, info.zhDes, { tostring(info.minutes) })
	_refreshDetail(Workspace:GetServerTimeNow())
	if _selected ~= key then
		return
	end
	detail.Visible = true
	Style.Pop(detail)
end

--[[
	为生效中的药水克隆一个图标
	@param key string - 药水键
	@param order number - 在 PotionOrder 中的下标，作 LayoutOrder 保持固定排序
	@return BuffView? - 图标视图；模板未绑定或配置缺失为 nil
]]
local function _createView(key: string, order: number): BuffView?
	local list, temp = _list, _temp
	local info = _potions[key]
	if not list or not temp or not info then
		return nil
	end
	local button = temp:Clone()
	button.Name = BUFF_NAME
	button.LayoutOrder = order
	button.Image = info.image
	Common.SetRaw(Common.Get(button, "Mult") :: TextLabel, "x" .. tostring(info.mult))
	button.MouseButton1Click:Connect(function()
		_toggleDetail(key)
	end)
	button.Visible = true
	button.Parent = list
	Style.Pop(button)
	return { button = button, timer = Common.Get(button, "Timer") :: TextLabel }
end

--[[
	按镜像增删图标并刷新倒计时与详情（镜像变化与 4Hz 刷新共用）
]]
local function _sync()
	local serverNow = Workspace:GetServerTimeNow()
	for order, key in ipairs(ArmWrestleConfig.PotionOrder) do
		local left = _left(key, serverNow)
		local view = _views[key]
		if left > 0 then
			view = view or _createView(key, order)
			_views[key] = view
			if view then
				Common.SetRaw(view.timer, Common.Mmss(left))
			end
		elseif view then
			view.button:Destroy()
			_views[key] = nil
		end
	end
	_refreshDetail(serverNow)
end

--[[
	4Hz 刷新倒计时与到期（ArmWrestleHUD._refresh 转发）
]]
function PotionBuffBar.Tick()
	_sync()
end

--[[
	绑定右下角药水 Buff 栏静态节点与镜像监听（ArmWrestleHUD 绑定静态界面时调一次）
	@param gui Frame - ArmWrestleHUD 容器（Common.gui）
	@return Frame - PotionBuff 分组
]]
function PotionBuffBar.Bind(gui: Frame): Frame
	local bar = Common.Get(gui, "PotionBuff") :: Frame
	local list = Common.Get(bar, "List") :: Frame
	local temp = Common.Get(list, "BuffTemp") :: ImageButton
	temp.Visible = false
	_list = list
	_temp = temp

	local detail = Common.Get(bar, "Detail") :: Frame
	detail.Visible = false
	_detail = detail
	_detailTitle = Common.Get(detail, "Title") :: TextLabel
	_detailDesc = Common.Get(detail, "Band", "Desc") :: TextLabel
	_detailLeft = Common.Get(detail, "Left") :: TextLabel

	for _, key in ipairs(ArmWrestleConfig.PotionOrder) do
		local potion = ArmWrestleConfig.GetPotion(key)
		if potion then
			_potions[key] = {
				zhName = potion.ZhName,
				zhDes = potion.ZhDes,
				mult = potion.Mult,
				minutes = potion.Duration // SECONDS_PER_MINUTE,
				image = Style.Icons[potion.Icon] or Style.Icons[DEFAULT_ICON],
			}
		end
		LocalPlayer:GetAttributeChangedSignal(ATTR_END_PREFIX .. key):Connect(_sync)
	end
	_sync()
	return bar
end

return PotionBuffBar
