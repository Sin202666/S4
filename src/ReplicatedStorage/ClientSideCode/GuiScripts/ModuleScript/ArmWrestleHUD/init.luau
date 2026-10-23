--[[
	Module: ArmWrestleHUD
	Description: 扳手腕主界面：左下角现金、商店、加成、药水、离线与菜单礼物
	Author: 程莘
	Created: 2026-10-14
	Last Modified: 2026-10-19

	功能：
	- 左下角现金数值（ArmWrestleHUD.Cash，在工具栏上方），左侧商店；力量数值不再显示
	- 左侧只留商店；手臂、哑铃、传送、对局、材质抽取、新手引导文案，以及右侧力量倍数和力量包已从界面删除
	- 右下角加成栏：同服好友加成（点击邀请好友）、Roblox 会员加成（点击订阅会员），见 BoostBar
	- 右下角药水 Buff 栏（加成栏左侧同一排）：生效药水图标 + 倒计时，点击看详情，见 PotionBuffBar
	- 离线奖励窗与菜单离线横幅暂时关闭（OfflinePanel / MenuOfflineHint 的绑定已注释）
	- 打开 Roblox 菜单即弹出挽留礼物窗（每账号一次现金），点击领取由服务端结算，见 MenuGift
	- 子模块：Common、Panels（商城）、BoostBar、PotionBuffBar、OfflinePanel、MenuGift、MenuOfflineHint、EdgeSlide、TipsAnchor
	- 只展示与发请求；结算在服务端 SystemArmWrestle，请求经客户端 SystemArmWrestle.Invoke

	静态 UI（Studio 维护，本模块只绑定不新建，节点名为代码契约，改名须同步）：
	- ScreenGui.ArmWrestleHUD：Cash(Value) / Left(ShopButton) / Boost(见 BoostBar) / PotionBuff(见 PotionBuffBar) / OfflineReward(见 OfflinePanel)
	- ArmWrestleShop：弹窗，见 Panels
	- 挽留礼物弹窗在独立的 StarterGui.MenuGiftGui（高 DisplayOrder + 压暗遮罩），见 MenuGift
	- 菜单离线提示横幅在独立的 StarterGui.MenuHintGui（Top / Bottom），见 MenuOfflineHint

	与相关模块：
	- 客户端 SystemArmWrestle：Init 时传入 Invoke，并转发训练与每帧心跳
	- ArmWrestleShop：UIManager 弹窗模块，openUi 回调 OnPanelOpened

	加载：
		local HUD = require(ReplicatedStorage.ClientSideCode.GuiScripts.ModuleScript.ArmWrestleHUD)
		HUD.Init(SystemArmWrestle.Invoke)
		HUD.Heartbeat(dt)
]]

local Utils = require(game.ReplicatedFirst.AllSideCode.UtilsSystem)
local LocalPlayer = Utils.LocalPlayer
local ArmWrestleConfig = Utils.ArmWrestleConfig
local ArmWrestleStyle = Utils.ArmWrestleStyle
local GetData = Utils.GetData

local Common = require(script.Common)
local Panels = require(script.Panels)
local BoostBar = require(script.BoostBar)
local PotionBuffBar = require(script.PotionBuffBar)
-- 离线奖励暂时关闭
-- local OfflinePanel = require(script.OfflinePanel)
local MenuGift = require(script.MenuGift)
-- local MenuOfflineHint = require(script.MenuOfflineHint)
local EdgeSlide = require(script.EdgeSlide)
local TipsAnchor = require(script.TipsAnchor)

local Style = ArmWrestleStyle
local Format = ArmWrestleConfig.Format

local ArmWrestleHUD = {}

local REFRESH_INTERVAL = 0.25

local _initStarted = false
local _inited = false
local _acc = 0
local _cash: TextLabel?

--[[
	取按钮下承载文字的子 TextLabel "Label"（TranslationHelper 不处理 TextButton）
	@param btn Instance - 按钮
	@return TextLabel - 文字
]]
local function _label(btn: Instance): TextLabel
	return Common.Get(btn, "Label") :: TextLabel
end

--[[
	刷新左下角现金
]]
local function _updateCash()
	if not _cash then
		return
	end
	Common.SetRaw(_cash, Format(math.floor(Common.Coin())))
end

--[[
	4Hz 刷新药水 Buff 倒计时
]]
local function _refresh()
	PotionBuffBar.Tick()
end

--[[
	绑定左下角现金与左侧商店
]]
local function _bindHud()
	local gui = Common.gui :: Frame
	_cash = Common.Get(gui, "Cash", "Value") :: TextLabel
	Common.SetRaw(_cash :: TextLabel, "0")

	local left = Common.Get(gui, "Left") :: Frame
	local shopBtn = Common.Get(left, "ShopButton") :: TextButton
	Common.SetText(_label(shopBtn), "商店")
	shopBtn.MouseButton1Click:Connect(function()
		Panels.OpenShop()
	end)

	Common.hud.left = left
	Common.hud.boost = BoostBar.Bind(gui)
	PotionBuffBar.Bind(gui)
	-- OfflinePanel.Bind(gui)
	MenuGift.Bind()
	-- MenuOfflineHint.Bind()
	Common.hud.backpack = Common.Get(Common.screenGui :: ScreenGui, "Main", "Backpack")
	EdgeSlide.Bind()
	TipsAnchor.Bind()
end

--[[
	绑定玩家镜像变化
]]
local function _bindAttributes()
	-- 金币 NumberValue 由背包镜像延迟创建，等待会阻塞 Init，故放后台线程
	task.spawn(function()
		local coinValue = GetData.WaitBagNumberValue(LocalPlayer, Common.COIN_ID)
		coinValue.Changed:Connect(function()
			_updateCash()
			if _cash then
				Style.Pop(_cash)
			end
		end)
		_updateCash()
	end)
end

--[[
	刷新现金（UIManager / 旧入口兼容）
]]
function ArmWrestleHUD.RefreshHud()
	if not _inited then
		return
	end
	_updateCash()
	_refresh()
end

--[[
	重绘商店面板（可见时）
]]
function ArmWrestleHUD.RenderShop()
	Panels.RenderShop()
end

--[[
	打开/切换面板（经 UIManager 播放弹出动画）
	@param name string - Shop
]]
function ArmWrestleHUD.OpenPanel(name: string)
	if name == "Shop" then
		Panels.OpenShop()
	end
end

--[[
	弹窗已由 UIManager 显示后的回调
	@param name string - Shop
]]
function ArmWrestleHUD.OnPanelOpened(name: string)
	Panels.OnOpened(name)
end

--[[
	每帧心跳：其余 4Hz
	@param dt number? - 帧间隔，缺省按 1/60
]]
function ArmWrestleHUD.Heartbeat(dt: number?)
	if not _inited then
		return
	end
	local step = dt or 1 / 60
	_acc += step
	if _acc < REFRESH_INTERVAL then
		return
	end
	_acc = 0
	_refresh()
end

--[[
	UIManager 兼容：显示主界面
]]
function ArmWrestleHUD:openUi()
	if Common.gui then
		Common.gui.Visible = true
	end
end

--[[
	UIManager 兼容：隐藏主界面
]]
function ArmWrestleHUD:closeUi()
	if Common.gui then
		Common.gui.Visible = false
	end
end

--[[
	UIManager 兼容：刷新
]]
function ArmWrestleHUD:updateUi()
	ArmWrestleHUD.RefreshHud()
end

--[[
	绑定静态界面（客户端 SystemArmWrestle.Init 调一次）；绑定完成前 Heartbeat 不生效
	@param invoke function? - (action, ...) -> ok, result；传客户端 SystemArmWrestle.Invoke
]]
function ArmWrestleHUD.Init(invoke: ((string, ...any) -> ...any)?)
	if _initStarted then
		return
	end
	_initStarted = true
	if invoke then
		Common.SetInvoker(invoke)
	end
	Common.Bind()
	_bindHud()
	Panels.Bind(Common.screenGui :: ScreenGui)
	_bindAttributes()
	_updateCash()
	_inited = true
end

return ArmWrestleHUD
