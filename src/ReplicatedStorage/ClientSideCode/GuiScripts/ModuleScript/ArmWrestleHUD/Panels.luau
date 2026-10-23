--[[
	Module: Panels
	Description: ArmWrestleHUD 商城弹窗（委托 ShopPanel）
	Author: 程莘
	Created: 2026-10-14
	Last Modified: 2026-10-16

	静态 UI（Studio 维护于 StarterGui.ScreenGui，节点名为代码契约）：
	- ArmWrestleShop：Title / CloseButton / Scroll(四个分区)，渲染见 ShopPanel

	开关：
	- 一律经 Common.ShowPopup → UIManager（PopUp/PopBack 动画，UIScale 由 UISetMgr 按 PC_Scale/Mobie_Scale 适配）
	- UIManager 显示后调 GuiScripts 同名模块 openUi → ArmWrestleHUD.OnPanelOpened → OnOpened
]]

local Utils = require(game.ReplicatedFirst.AllSideCode.UtilsSystem)
local ArmWrestleStyle = Utils.ArmWrestleStyle

local Common = require(script.Parent.Common)
local ShopPanel = require(script.Parent.ShopPanel)

local Panels = {}

local SHOP_UI = "ArmWrestleShop"
local _shop: Frame? = nil

--[[
	绑定商城外框关闭按钮
	@param screenGui ScreenGui - PlayerGui.ScreenGui
	@return Frame - 商城面板
]]
local function _bindShop(screenGui: ScreenGui): Frame
	local panel = Common.Get(screenGui, SHOP_UI) :: Frame
	_shop = panel
	local close = Common.Get(panel, "CloseButton") :: TextButton
	close.MouseButton1Click:Connect(function()
		Common.ShowPopup(SHOP_UI, false)
	end)
	ArmWrestleStyle.BindIcons(panel)
	return panel
end

--[[
	打开/关闭商城
]]
function Panels.OpenShop()
	Common.ShowPopup(SHOP_UI, nil)
end

--[[
	弹窗已显示：渲染商城
	@param name string - Shop
]]
function Panels.OnOpened(name: string)
	if name == "Shop" then
		ShopPanel.OnOpened()
	end
end

--[[
	关闭商城
]]
function Panels.CloseAll()
	local panel = _shop
	if panel and panel.Visible then
		Common.ShowPopup(SHOP_UI, false)
	end
end

--[[
	渲染商城（面板不可见时跳过）
]]
function Panels.RenderShop()
	ShopPanel.Render()
end

--[[
	绑定商城（Common.Bind 之后调用一次）
	@param screenGui ScreenGui - PlayerGui.ScreenGui
]]
function Panels.Bind(screenGui: ScreenGui)
	ShopPanel.Bind(_bindShop(screenGui))
end

return Panels
