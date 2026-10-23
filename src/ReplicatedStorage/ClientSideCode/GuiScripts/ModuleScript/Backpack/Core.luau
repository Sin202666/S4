--[[
	Module: BackpackCore
	Description: Main.Backpack 仓库网格 + 快捷栏渲染（乐观 overlay；格子走 BagSlot.AwardStyle）
	Author: 林奥宇
	Created: 2026-09-04
	Last Modified: 2026-10-15

	功能：
	- init(main)：收集节点、建工具栏槽、藏仓库
	- 仓库层已停用：不监听 ToggleBackpackWarehouse，玩家无入口打开，Main.Backpack 只显示快捷栏
	- 页签 All / Potion / Material（BagCapacity.Tab）；译名搜索
	- 容量条：Window 占用 vs Capacity.Backpack（只展示）
	- 快捷栏：UI 1 号位固定哑铃（PinnedTool，数字键 1 切换手持）；UI 2~N+1 对应 Bag.equip 1~N（数字键只高亮）
	- 数字键选格与鼠标点格一致，播 SystemUISfx 点击音
	- 格子 Attribute：UiSlotIndex = UI 序号；EquipSlot = Bag.equip（固定格无此属性），拖拽只认 EquipSlot
	- overlay 与查询见 View；禁止改 PlayerData

	加载：
		local Core = require(script.Parent.Core)
		Core.init(main)
]]

local Utils = require(game.ReplicatedFirst.AllSideCode.UtilsSystem)
local AllUI = require(script.Parent.AllUI)
local Drag = require(script.Parent.Drag)
local Lock = require(script.Parent.Lock)
local PinnedTool = require(script.Parent.PinnedTool)
local View = require(script.Parent.View)

local AddListen = Utils.AddListen
local CollectionService = Utils.CollectionService
local EnumMgr = Utils.EnumMgr
local GetData = Utils.GetData
local LocalPlayer = Utils.LocalPlayer
local PlayerData = Utils.PlayerData
local StarterGui = Utils.StarterGui
local SystemInput = Utils.SystemInput
local SystemUISfx = Utils.SystemUISfx
local TranslationHelper = Utils.TranslationHelper
local UIMgr = Utils.UIMgr

local BackpackCore = {}

local BagView = GetData.BagView
local BagCapacity = GetData.BagCapacity
local BagSlot = UIMgr.BagSlot

-- ========================================
-- 常量定义
-- ========================================
local WAREHOUSE_CLONE_PREFIX = "Warehouse_"
local TOOLBAR_CLONE_PREFIX = "Slot"
local TAB_ALL = BagCapacity.Tab.All
local CODE_LOCALIZATION_TAG = "代码本地化"
local PINNED_SLOT_COUNT = 1
-- 数字键只绑到 Nine；超出的 Bag.equip 槽不在 UI 显示
local TOOLBAR_UI_MAX = 9
local ATTR_UI_SLOT = "UiSlotIndex"
local ATTR_EQUIP_SLOT = "EquipSlot"

-- ========================================
-- 私有变量
-- ========================================
local uiRefs: AllUI.BackpackUiRefs? = nil
local warehouseOpen = false
local currentTab: string = TAB_ALL
local searchText = ""
local selectedToolbarSlot = 1
local toolbarSlots: { GuiObject } = {}
local warehouseSlotsByOnlyId: { [number]: GuiObject } = {}
local warehouseCachedOnlyIds: { [number]: boolean } = {}
local toolbarCachedOnlyIds: { [number]: number } = {}
local _bound = false

-- ========================================
-- 私有函数
-- ========================================

--[[
	页签文案（Key 必须是调用处字面量）

	@param label TextLabel - 页签文字
	@param tabId string - BagCapacity.Tab 键（All / Potion / Material）
	@return nil
]]
local function _setTabLabel(label: TextLabel, tabId: string): ()
	local setters: { [string]: (TextLabel) -> () } = {
		[TAB_ALL] = function(lab: TextLabel)
			TranslationHelper.SetText(lab, "背包页签-全部")
		end,
		[BagCapacity.Tab.Potion] = function(lab: TextLabel)
			TranslationHelper.SetText(lab, "背包页签-药水")
		end,
		[BagCapacity.Tab.Material] = function(lab: TextLabel)
			TranslationHelper.SetText(lab, "背包页签-材料")
		end,
	}
	local setter = setters[tabId]
	if setter then
		setter(label)
	end
end

--[[
	去掉克隆树上残留的「代码本地化」，避免 Name 改写后被冲掉

	@param root Instance - 克隆根
	@return nil
]]
local function _stripCodeLocalizationTags(root: Instance): ()
	local function strip(inst: Instance)
		if CollectionService:HasTag(inst, CODE_LOCALIZATION_TAG) then
			CollectionService:RemoveTag(inst, CODE_LOCALIZATION_TAG)
		end
	end
	strip(root)
	for _, descendant in root:GetDescendants() do
		strip(descendant)
	end
end

--[[
	填格 + 可选已标记 / 选中 / 槽号

	@param slotFrame GuiObject - 格子
	@param entry table? - 条目
	@param uiSlotIndex number? - 工具栏槽号
	@return nil
]]
local function _bindSlot(slotFrame: GuiObject, entry: any?, uiSlotIndex: number?): ()
	if not slotFrame:IsA("Frame") and not slotFrame:IsA("GuiButton") then
		return
	end
	local frame = slotFrame :: Frame
	if entry then
		local vm = BagView.ToSlotVM(entry)
		BagSlot.Bind(frame, vm, BagSlot.AwardStyle)
	else
		BagSlot.Clear(frame, BagSlot.AwardStyle)
	end

	local mark = slotFrame:FindFirstChild("已标记") :: GuiObject?
	if mark then
		local locked = entry ~= nil and (entry.lock == EnumMgr.BagLock.Locked or entry.lock == true)
		mark.Visible = locked
	end

	local selected = slotFrame:FindFirstChild("选中") :: GuiObject?
	if selected then
		selected.Visible = uiSlotIndex ~= nil and uiSlotIndex == selectedToolbarSlot
	end

	local numberLabel = slotFrame:FindFirstChild("Number") :: TextLabel?
	if numberLabel then
		if uiSlotIndex then
			numberLabel.Visible = true
			TranslationHelper.SetRawText(numberLabel, tostring(uiSlotIndex))
		else
			numberLabel.Visible = false
		end
	end
end

--[[
	刷新容量条（只展示）

	@return nil
]]
local function _refreshCapacity(): ()
	if not uiRefs or not uiRefs.capacitySize then
		return
	end
	local occ = BagView.Occupancy(LocalPlayer, BagCapacity.Capacity.Backpack)
	local used = tonumber(occ.used) or 0
	local maxSlots = occ.max
	if type(maxSlots) == "number" then
		TranslationHelper.SetRawText(uiRefs.capacitySize, tostring(used) .. "/" .. tostring(maxSlots))
	else
		TranslationHelper.SetRawText(uiRefs.capacitySize, tostring(used))
	end
end

--[[
	UI 快捷栏总格数（固定格 + Bag.equip 槽，封顶 TOOLBAR_UI_MAX）

	@return number - UI 格数
]]
local function _getUiSlotCount(): number
	return math.min(BagCapacity.GetToolbarSlotCount() + PINNED_SLOT_COUNT, TOOLBAR_UI_MAX)
end

--[[
	UI 序号 → Bag.equip

	@param uiSlotIndex number - UI 序号 1~N
	@return number - Bag.equip；固定格为 0 或负数
]]
local function _toEquipSlot(uiSlotIndex: number): number
	return uiSlotIndex - PINNED_SLOT_COUNT
end

--[[
	刷新工具栏

	@return nil
]]
local function _refreshToolbar(): ()
	if not uiRefs then
		return
	end
	table.clear(toolbarCachedOnlyIds)
	local occupied: { [number]: any } = {}
	for _, entry in ipairs(View.queryWindowEffective()) do
		local eq = tonumber(entry.equip) or 0
		if BagCapacity.IsFilterType(BagCapacity.Filter.Toolbar, entry.tp) and BagCapacity.IsToolbarEquipSlot(eq) then
			occupied[eq] = entry
		end
	end
	for i, slotFrame in toolbarSlots do
		local equipSlot = _toEquipSlot(i)
		if equipSlot < 1 then
			_bindSlot(slotFrame, nil, i)
			PinnedTool.render(slotFrame)
		else
			local item = occupied[equipSlot]
			local show = warehouseOpen or item ~= nil
			slotFrame.Visible = show
			if show then
				_bindSlot(slotFrame, item, i)
			end
			if item then
				toolbarCachedOnlyIds[equipSlot] = tonumber(item.onlyID) or 0
			end
		end
	end
end

--[[
	选中 UI 快捷格：固定格切换哑铃手持，其它格收起哑铃（锁定模式下不动手持）

	@param uiSlotIndex number - UI 序号 1~N
	@return nil
]]
local function _selectToolbarSlot(uiSlotIndex: number): ()
	selectedToolbarSlot = uiSlotIndex
	if not Lock.isActive() then
		if _toEquipSlot(uiSlotIndex) < 1 then
			PinnedTool.toggle()
		else
			PinnedTool.unequip()
		end
	end
	_refreshToolbar()
end

--[[
	绑定仓库格点击（锁定模式切 lock）

	@param onlyID number - onlyID
	@param slot GuiObject - 格
	@return nil
]]
local function _bindWarehouseClick(onlyID: number, slot: GuiObject): ()
	local btn = AllUI.findSlotButton(slot, "warehouseClick:" .. onlyID)
	if not btn then
		return
	end
	AddListen.AddMouseClick(btn, function()
		local entry = nil
		for _, row in ipairs(View.queryWindowEffective()) do
			if tonumber(row.onlyID) == onlyID then
				entry = row
				break
			end
		end
		Lock.tryHandleSlotClick(onlyID, entry)
	end, slot)
end

--[[
	刷新仓库网格（onlyID 差量复用）

	@return nil
]]
local function _refreshWarehouse(): ()
	if not uiRefs or not warehouseOpen then
		return
	end
	local list = View.queryWarehouseDisplay(currentTab, searchText)
	local temp = uiRefs.warehouseTemp
	temp.Visible = false

	local nextIds: { [number]: boolean } = {}
	local added: { number } = {}
	for index, entry in ipairs(list) do
		local onlyId = tonumber(entry.onlyID) or 0
		if onlyId > 0 then
			nextIds[onlyId] = true
			local slot = warehouseSlotsByOnlyId[onlyId]
			if not slot then
				slot = temp:Clone()
				_stripCodeLocalizationTags(slot)
				slot.Name = WAREHOUSE_CLONE_PREFIX .. tostring(onlyId)
				slot.Parent = uiRefs.warehouseScroll
				warehouseSlotsByOnlyId[onlyId] = slot
				table.insert(added, onlyId)
			end
			slot.Visible = true
			slot.LayoutOrder = index
			slot:SetAttribute("OnlyID", onlyId)
			_bindSlot(slot, entry, nil)
			if table.find(added, onlyId) then
				_bindWarehouseClick(onlyId, slot)
			end
		end
	end

	local removed: { number } = {}
	for onlyId, slot in warehouseSlotsByOnlyId do
		if not nextIds[onlyId] then
			slot:Destroy()
			warehouseSlotsByOnlyId[onlyId] = nil
			table.insert(removed, onlyId)
		end
	end

	table.clear(warehouseCachedOnlyIds)
	for onlyId in nextIds do
		warehouseCachedOnlyIds[onlyId] = true
	end

	_refreshCapacity()
	if #added > 0 or #removed > 0 then
		Drag.rebindWarehouseSlots(added, removed)
	end
	task.defer(function()
		if uiRefs and warehouseOpen then
			UIMgr.SetUIlistSize_New(uiRefs.warehouseScroll)
		end
	end)
end

--[[
	页签选中底

	@return nil
]]
local function _updateTabHighlight(): ()
	if not uiRefs then
		return
	end
	for tabId, tabFrame in uiRefs.tabFrames do
		local chooseBg = tabFrame:FindFirstChild("ChooseBg") :: GuiObject?
		local bg = tabFrame:FindFirstChild("Bg") :: GuiObject?
		local selected = tabId == currentTab
		if chooseBg then
			chooseBg.Visible = selected
		end
		if bg then
			bg.Visible = not selected
		end
	end
end

--[[
	绑定页签

	@return nil
]]
local function _bindTabs(): ()
	if not uiRefs then
		return
	end
	for tabId, tabFrame in uiRefs.tabFrames do
		local clickBtn = AllUI.findSlotButton(tabFrame, "tab:" .. tabId)
		if clickBtn then
			AddListen.AddMouseClick(clickBtn, function()
				if Lock.isActive() then
					return
				end
				currentTab = tabId
				_updateTabHighlight()
				BackpackCore.refreshAll()
			end, tabFrame)
		end
		local label = tabFrame:FindFirstChildWhichIsA("TextLabel", true)
		if label then
			_setTabLabel(label, tabId)
		end
	end
	_updateTabHighlight()
end

--[[
	绑定搜索

	@return nil
]]
local function _bindSearch(): ()
	if not uiRefs or not uiRefs.searchBox then
		return
	end
	uiRefs.searchBox:GetPropertyChangedSignal("Text"):Connect(function()
		searchText = uiRefs.searchBox and uiRefs.searchBox.Text or ""
		BackpackCore.refreshAll()
	end)
end

--[[
	建工具栏 N 槽

	@return nil
]]
local function _buildToolbarSlots(): ()
	if not uiRefs then
		return
	end
	local temp = uiRefs.toolbarTemp
	temp.Visible = false
	for _, child in uiRefs.toolbar:GetChildren() do
		if child ~= temp and child:IsA("GuiObject") and string.sub(child.Name, 1, #TOOLBAR_CLONE_PREFIX) == TOOLBAR_CLONE_PREFIX then
			child:Destroy()
		end
	end
	table.clear(toolbarSlots)
	for i = 1, _getUiSlotCount() do
		local equipSlot = _toEquipSlot(i)
		local slot = temp:Clone()
		_stripCodeLocalizationTags(slot)
		slot.Name = TOOLBAR_CLONE_PREFIX .. tostring(i)
		slot.Visible = false
		slot.LayoutOrder = i
		slot:SetAttribute(ATTR_UI_SLOT, i)
		if equipSlot >= 1 then
			slot:SetAttribute(ATTR_EQUIP_SLOT, equipSlot)
		end
		slot.Parent = uiRefs.toolbar
		table.insert(toolbarSlots, slot)
		local btn = AllUI.findSlotButton(slot, "toolbarClick:" .. i)
		if btn then
			AddListen.AddMouseClick(btn, function()
				if equipSlot >= 1 and Lock.isActive() then
					local item = View.getToolbarItemAtSlot(equipSlot)
					if item then
						Lock.tryHandleSlotClick(tonumber(item.onlyID) or 0, item)
					end
				end
				_selectToolbarSlot(i)
			end, slot)
		end
	end
end

--[[
	绑定数字键：1 号切换哑铃手持，其余只高亮

	@return nil
]]
local function _bindToolbarHotkeys(): ()
	for i = 1, _getUiSlotCount() do
		SystemInput.OnAction(SystemInput.ToolbarSlotActionId(i), function(phase: string)
			if phase ~= SystemInput.Phase.Started then
				return
			end
			SystemUISfx.PlayClick()
			_selectToolbarSlot(i)
		end)
	end
end

--[[
	Bag 同步

	@return nil
]]
local function _bindBagDataWatch(): ()
	PlayerData.ListenClientSync(function(key: string | { string }?, value: any)
		local refreshToolbar = BagView.ShouldRefreshToolbarOnPlayerDataSync(key, value, LocalPlayer, toolbarCachedOnlyIds)
		local refreshWarehouse = BagView.ShouldRefreshWarehouseOnPlayerDataSync(
			key,
			value,
			LocalPlayer,
			toolbarCachedOnlyIds,
			warehouseCachedOnlyIds
		)
		if refreshToolbar or refreshWarehouse then
			View.clearOverlay()
			BackpackCore.refreshAll()
		end
	end)
end

-- ========================================
-- 公共函数
-- ========================================

--[[
	仓库是否打开

	@return boolean
]]
function BackpackCore.isWarehouseOpen(): boolean
	return warehouseOpen
end

--[[
	工具栏槽列表

	@return { GuiObject }
]]
function BackpackCore.getToolbarSlots(): { GuiObject }
	return toolbarSlots
end

--[[
	仓库格列表

	@return { GuiObject }
]]
function BackpackCore.getWarehouseSlotFrames(): { GuiObject }
	local list = {}
	for _, slot in warehouseSlotsByOnlyId do
		table.insert(list, slot)
	end
	return list
end

--[[
	按 onlyID 取仓库格

	@param onlyID number - onlyID
	@return GuiObject?
]]
function BackpackCore.getWarehouseSlotByOnlyId(onlyID: number): GuiObject?
	return warehouseSlotsByOnlyId[onlyID]
end

--[[
	快捷栏某槽当前展示物品（含 overlay）

	@param slotIndex number - 槽 1~N
	@return table? - 条目
]]
function BackpackCore.getToolbarItemAtSlot(slotIndex: number): any?
	return View.getToolbarItemAtSlot(slotIndex)
end

--[[
	乐观拖拽 overlay

	@param from table - 起点
	@param to table - 落点
	@return boolean - 已应用 overlay 为 true
]]
function BackpackCore.applyOptimisticDrag(
	from: { zone: string, equipSlot: number?, onlyID: number? },
	to: { zone: string, equipSlot: number?, onlyID: number? }
): boolean
	local applied = View.applyOptimisticDrag(from, to)
	if applied then
		BackpackCore.refreshAll()
	end
	return applied
end

--[[
	仓库 onlyID 是否允许上栏

	@param onlyID number - onlyID
	@return boolean
]]
function BackpackCore.canDropOnToolbar(onlyID: number): boolean
	return View.canDropOnToolbar(onlyID)
end

--[[
	切换仓库

	@return nil
]]
function BackpackCore.toggleWarehouse(): ()
	BackpackCore.setWarehouseOpen(not warehouseOpen)
end

--[[
	设置仓库显隐

	@param open boolean - 打开
	@return nil
]]
function BackpackCore.setWarehouseOpen(open: boolean): ()
	if not uiRefs then
		return
	end
	warehouseOpen = open
	uiRefs.warehouse.Visible = open
	if not open then
		Lock.onWarehouseClosed()
	end
	BackpackCore.refreshAll()
	if open then
		Drag.rebindWarehouseSlots()
	end
end

--[[
	刷新工具栏；开仓时刷网格

	@return nil
]]
function BackpackCore.refreshAll(): ()
	if not uiRefs then
		return
	end
	_refreshToolbar()
	if warehouseOpen then
		_refreshWarehouse()
	end
end

--[[
	初始化 Main.Backpack

	@param main Frame - ScreenGui.Main
	@return boolean - 成功为 true
]]
function BackpackCore.init(main: Frame): boolean
	if _bound then
		return uiRefs ~= nil
	end
	uiRefs = AllUI.collect(main)
	if not uiRefs then
		return false
	end
	_bound = true
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)

	uiRefs.root.Visible = true
	uiRefs.warehouse.Visible = false
	warehouseOpen = false

	View.setOnRollback(function()
		BackpackCore.refreshAll()
	end)

	_buildToolbarSlots()
	PinnedTool.bind(_refreshToolbar)
	_bindTabs()
	_bindSearch()
	_bindToolbarHotkeys()
	_bindBagDataWatch()

	Lock.bind(uiRefs, {
		onModeChanged = function()
			BackpackCore.refreshAll()
		end,
		onLockIntent = function(onlyID: number, wantLock: boolean)
			View.setLockOverlay(onlyID, if wantLock then EnumMgr.BagLock.Locked else EnumMgr.BagLock.Unlocked)
			BackpackCore.refreshAll()
		end,
		onLockAllIntent = function(wantLock: boolean)
			View.setLockAllOverlay(wantLock)
			BackpackCore.refreshAll()
		end,
	})

	Drag.bind({
		getToolbarSlots = BackpackCore.getToolbarSlots,
		getWarehouseSlotFrames = BackpackCore.getWarehouseSlotFrames,
		getWarehouseSlotByOnlyId = BackpackCore.getWarehouseSlotByOnlyId,
		getToolbarItemAtSlot = BackpackCore.getToolbarItemAtSlot,
		isWarehouseOpen = BackpackCore.isWarehouseOpen,
		isLockActive = Lock.isActive,
		applyOptimisticDrag = BackpackCore.applyOptimisticDrag,
		canDropOnToolbar = BackpackCore.canDropOnToolbar,
	})

	BackpackCore.refreshAll()
	return true
end

return BackpackCore
