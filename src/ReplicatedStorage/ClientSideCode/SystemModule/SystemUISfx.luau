--[[
	Module: SystemUISfx
	Description: 客户端 UI 音效：全局按钮点击音、获得奖励音、购买 / 解锁 / 升级成功音
	Author: 程莘
	Created: 2026-10-15
	Last Modified: 2026-10-15

	功能：
	- Init(playerGui)：给 PlayerGui 下全部 GuiButton（含之后克隆 / 重生复制的）挂点击音；监听 Robux 购买弹窗成功时播成功音
	- PlayReward()：获得奖励音，短时间内多个来源（金币到账 + 奖励弹窗）只响一次
	- PlaySuccess()：购买 / 解锁关卡 / 升级移速 / 升级训练速度成功音，短时间内多个来源（Robux 回调 + 属性同步）只响一次
	- PlayClick()：手动补一次点击音（非 GuiButton 的点击入口用）

	按钮点击音规则（点击时判断，与绑定先后无关）：
	- Attribute ClickSound = "None"：静音；其它非空 string：改播该名模板
	- Attribute ClickSoundBound = true：已由 AddListen.AddMouseClick 自带点击音，跳过避免响两次

	约束：
	- 纯表现，只在本机 2D 播放，不发 Remote、不参与结算；奖励音 / 成功音只在服务端结果返回或同步后（背包数值增加 / 服务端推奖励弹窗 / Action 返回成功 / 属性增大 / 平台购买回调）触发
	- 直接经 SoundInstance 零渐入播放：SoundModule:PlaySoundLocal 固定 0.1s 渐入，会把短促 UI 音的起音削软
	- 模板按 Sound.Name 查找（即下方 SFX_* 常量）

	模板（SoundService 下 Sound.Name）：
	- 音效-UI-通用中度点击（UI 组）：按钮点击（与 AddListen 默认点击音一致）
	- 获得金币钻石（UI 组）：获得奖励
	- 购买（EFFECT 组）：购买 / 解锁 / 升级成功

	加载：
		local Utils = require(game.ReplicatedFirst.AllSideCode.UtilsSystem)
		local SystemUISfx = Utils.SystemUISfx
		SystemUISfx.Init(playerGui)        -- UIManager 启动时调一次
		SystemUISfx.PlayReward()           -- 获得奖励
		SystemUISfx.PlaySuccess()          -- 购买 / 解锁 / 升级成功
]]

local Utils = require(game.ReplicatedFirst.AllSideCode.UtilsSystem)
local MarketplaceService = Utils.MarketplaceService
local LocalPlayer = Utils.LocalPlayer
local SoundInstance = Utils.SoundInstance

local SystemUISfx = {}

local SFX_CLICK = "音效-UI-通用中度点击"
local SFX_REWARD = "获得金币钻石"
local SFX_SUCCESS = "购买"
local ATTR_CLICK_SOUND = "ClickSound"
local ATTR_CLICK_BOUND = "ClickSoundBound"
local CLICK_SOUND_NONE = "None"
local FADE_IN_SEC = 0
local REWARD_MIN_INTERVAL = 0.5
local SUCCESS_MIN_INTERVAL = 0.5

local _inited = false
local _lastReward = -math.huge
local _lastSuccess = -math.huge

--[[
	本机 2D 零渐入播放一个 UI 音效（非循环，播完自动销毁）
	@param name string - SoundService 下模板 Sound.Name
]]
local function _play(name: string)
	local sound = SoundInstance:new({ SoundName = name, Is2D = true })
	if sound then
		sound:playSound(FADE_IN_SEC)
	end
end

--[[
	按钮被点击：按 Attribute / Name 规则决定播哪个点击音或跳过
	@param btn GuiButton - 被点击的按钮
]]
local function _onButtonClick(btn: GuiButton)
	if btn:GetAttribute(ATTR_CLICK_BOUND) == true then
		return
	end
	local custom = btn:GetAttribute(ATTR_CLICK_SOUND)
	if custom == CLICK_SOUND_NONE then
		return
	end
	_play(if typeof(custom) == "string" and custom ~= "" then custom else SFX_CLICK)
end

--[[
	给单个实例挂点击音（非 GuiButton 忽略）；连接随按钮销毁释放
	@param inst Instance - PlayerGui 下的任意节点
]]
local function _bindButton(inst: Instance)
	if not inst:IsA("GuiButton") then
		return
	end
	local btn = inst :: GuiButton
	btn.MouseButton1Click:Connect(function()
		_onButtonClick(btn)
	end)
end

--[[
	Robux 开发者商品购买弹窗关闭：本人且成功购买时播成功音（发货以服务端收据为准，这里只做反馈）
	@param userId number - 购买者 UserId
	@param _productId number - 商品 Id（未使用）
	@param isPurchased boolean - 是否完成购买
]]
local function _onProductPurchaseFinished(userId: number, _productId: number, isPurchased: boolean)
	if isPurchased and userId == LocalPlayer.UserId then
		SystemUISfx.PlaySuccess()
	end
end

--[[
	通行证购买弹窗关闭：本人且成功购买时播成功音
	@param player Player - 购买者
	@param _passId number - 通行证 Id（未使用）
	@param wasPurchased boolean - 是否完成购买
]]
local function _onGamePassPurchaseFinished(player: Player, _passId: number, wasPurchased: boolean)
	if wasPurchased and player == LocalPlayer then
		SystemUISfx.PlaySuccess()
	end
end

--[[
	手动播一次按钮点击音（非 GuiButton 的点击入口用；GuiButton 已由 Init 自动挂上）
	@return nil
]]
function SystemUISfx.PlayClick()
	_play(SFX_CLICK)
end

--[[
	获得奖励音；REWARD_MIN_INTERVAL 秒内重复调用只响一次
	@return nil
]]
function SystemUISfx.PlayReward()
	local now = os.clock()
	if now - _lastReward < REWARD_MIN_INTERVAL then
		return
	end
	_lastReward = now
	_play(SFX_REWARD)
end

--[[
	购买 / 解锁关卡 / 升级移速 / 升级训练速度成功音；SUCCESS_MIN_INTERVAL 秒内重复调用只响一次
	只应在服务端已确认成功后调用（Action 返回 ok / 服务端同步属性增大 / 平台购买回调）
	@return nil
]]
function SystemUISfx.PlaySuccess()
	local now = os.clock()
	if now - _lastSuccess < SUCCESS_MIN_INTERVAL then
		return
	end
	_lastSuccess = now
	_play(SFX_SUCCESS)
end

--[[
	绑定全局按钮点击音与 Robux 购买成功音（UIManager 启动时调一次，重复调用忽略）
	@param playerGui PlayerGui - 本机 PlayerGui
	@return nil
]]
function SystemUISfx.Init(playerGui: PlayerGui)
	if _inited then
		return
	end
	_inited = true
	for _, inst in ipairs(playerGui:GetDescendants()) do
		_bindButton(inst)
	end
	playerGui.DescendantAdded:Connect(_bindButton)
	MarketplaceService.PromptProductPurchaseFinished:Connect(_onProductPurchaseFinished)
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(_onGamePassPurchaseFinished)
end

return SystemUISfx
