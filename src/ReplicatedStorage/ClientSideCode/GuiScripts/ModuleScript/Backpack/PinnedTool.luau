--[[
	Module: BackpackPinnedTool
	Description: 快捷栏固定 Tool 格（UI 1 号位 = 扳手腕哑铃）：渲染 + 本地手持切换，不写 PlayerData / Bag.equip
	Author: 程莘
	Created: 2026-10-14
	Last Modified: 2026-10-15

	功能：
	- bind(onChanged)：追踪本地玩家 Backpack / Character 中的哑铃，持有或手持状态变化时回调
	- render(slotFrame)：在已由 Core 清空的格子上显示 ViewportFrame 模型与「已手持」
	- toggle()：未手持则 Humanoid:EquipTool（对局中 PlayerAttr.InBattle 为 true 时不装备），已手持则 UnequipTools
	- unequip()：切到其它快捷格时收起哑铃

	与相关模块：
	- Backpack.Core：建格与选槽；UI 1 号位交给本模块，2~N+1 映射 Bag.equip 1~N
	- 服务端 SystemArmWrestle.Look.EnsureDumbbell：唯一发放 Tool 的地方；本模块不克隆、不发放
	- 训练是否生效以服务端 Train 校验手持为准；本地装备只是表现与输入入口
	- CoreGui Backpack 已关闭，客户端只有本模块调用 EquipTool / UnequipTools；服务端仅 Battle 开局强制 UnequipTools

	加载：
		local PinnedTool = require(script.Parent.PinnedTool)
		PinnedTool.bind(function() refreshToolbar() end)
		PinnedTool.render(slotFrame)
]]

local Utils = require(game.ReplicatedFirst.AllSideCode.UtilsSystem)
local ArmWrestleConfig = Utils.ArmWrestleConfig
local ArmWrestleStyle = Utils.ArmWrestleStyle
local EnumMgr = Utils.EnumMgr
local LocalPlayer = Utils.LocalPlayer
local ViewportFrameModule = Utils.ViewportFrameModule

local BackpackPinnedTool = {}

-- ========================================
-- 常量定义
-- ========================================
local TOOL_NAME = ArmWrestleConfig.TOOL_NAME
local PlayerAttr = EnumMgr.PlayerAttr
local HIDE_NODE_NAMES = { "Icon", "Name" }
local HELD_NODE_NAME = "已手持"
local VIEWPORT_NODE_NAME = "ViewportFrame"

-- ========================================
-- 私有变量
-- ========================================
local _onChanged: (() -> ())? = nil
local _bound = false
local _playerConns: { RBXScriptConnection } = {}
local _containerConns: { RBXScriptConnection } = {}
local _viewportBuilt: { [GuiObject]: { tool: Tool, preview: any } } = {}

-- ========================================
-- 私有函数
-- ========================================

--[[
	在容器中查找哑铃 Tool
	@param container Instance? - Character 或 Backpack
	@return Tool? - 找到为 Tool，否则 nil
]]
local function _findToolIn(container: Instance?): Tool?
	if not container then
		return nil
	end
	local tool = container:FindFirstChild(TOOL_NAME)
	if tool and tool:IsA("Tool") then
		return tool
	end
	return nil
end

--[[
	当前哑铃 Tool 与是否手持
	@return Tool? - 哑铃；未发放为 nil
	@return boolean - 是否在 Character 中（手持）
]]
local function _getTool(): (Tool?, boolean)
	local held = _findToolIn(LocalPlayer.Character)
	if held then
		return held, true
	end
	return _findToolIn(LocalPlayer:FindFirstChildOfClass("Backpack")), false
end

--[[
	通知 Core 刷新
	@return nil
]]
local function _notify(): ()
	if _onChanged then
		_onChanged()
	end
end

--[[
	子节点增删时只对哑铃触发刷新
	@param child Instance - 增删的子节点
	@return nil
]]
local function _onContainerChild(child: Instance): ()
	if child.Name == TOOL_NAME then
		_notify()
	end
end

--[[
	重绑 Character / Backpack 的增删监听（重生后两者都会换新实例）
	@return nil
]]
local function _rebindContainers(): ()
	for _, conn in _containerConns do
		conn:Disconnect()
	end
	table.clear(_containerConns)
	for _, container in { LocalPlayer.Character, LocalPlayer:FindFirstChildOfClass("Backpack") } do
		if container then
			table.insert(_containerConns, container.ChildAdded:Connect(_onContainerChild))
			table.insert(_containerConns, container.ChildRemoved:Connect(_onContainerChild))
		end
	end
	_notify()
end

--[[
	在格子 ViewportFrame 里放哑铃模型；服务端换款会换新 Tool 实例，此时重建
	@param slotFrame GuiObject - 快捷栏格
	@param tool Tool - 哑铃
	@return nil
]]
local function _ensureViewport(slotFrame: GuiObject, tool: Tool): ()
	local viewport = slotFrame:FindFirstChild(VIEWPORT_NODE_NAME)
	if not viewport or not viewport:IsA("ViewportFrame") then
		return
	end
	viewport.Visible = true
	local built = _viewportBuilt[slotFrame]
	if built and built.tool == tool then
		return
	end
	local model = ArmWrestleStyle.BuildShowModel(tool)
	if not model then
		return
	end
	if built then
		built.preview:destroy()
	end
	local preview = ViewportFrameModule.new(viewport, model, ArmWrestleStyle.ShowModelCamera(model))
	if not preview then
		_viewportBuilt[slotFrame] = nil
		return
	end
	_viewportBuilt[slotFrame] = { tool = tool, preview = preview }
	if not built then
		slotFrame.Destroying:Once(function()
			local entry = _viewportBuilt[slotFrame]
			if entry then
				entry.preview:destroy()
			end
			_viewportBuilt[slotFrame] = nil
		end)
	end
end

-- ========================================
-- 公共函数
-- ========================================

--[[
	是否已发放哑铃（Backpack 或 Character 中存在）
	@return boolean - 存在为 true
]]
function BackpackPinnedTool.hasTool(): boolean
	local tool = _getTool()
	return tool ~= nil
end

--[[
	渲染固定格：隐藏 Icon / Name，显示哑铃模型与「已手持」；未发放时隐藏整格
	@param slotFrame GuiObject - 快捷栏格（Core 已调用 BagSlot.Clear 并写好 Number）
	@return nil
]]
function BackpackPinnedTool.render(slotFrame: GuiObject): ()
	local tool, held = _getTool()
	slotFrame.Visible = tool ~= nil
	if not tool then
		return
	end
	for _, nodeName in HIDE_NODE_NAMES do
		local node = slotFrame:FindFirstChild(nodeName)
		if node and node:IsA("GuiObject") then
			node.Visible = false
		end
	end
	local heldNode = slotFrame:FindFirstChild(HELD_NODE_NAME)
	if heldNode and heldNode:IsA("GuiObject") then
		heldNode.Visible = held
	end
	_ensureViewport(slotFrame, tool)
end

--[[
	切换手持：未手持则装备，已手持则收起；角色死亡、未发放或对局中（PlayerAttr.InBattle）不装备
	@return nil
]]
function BackpackPinnedTool.toggle(): ()
	local tool, held = _getTool()
	local character = LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not tool or not humanoid or humanoid.Health <= 0 then
		return
	end
	if held then
		humanoid:UnequipTools()
	elseif LocalPlayer:GetAttribute(PlayerAttr.InBattle) ~= true then
		humanoid:EquipTool(tool)
	end
end

--[[
	收起哑铃（仅当正手持时）
	@return nil
]]
function BackpackPinnedTool.unequip(): ()
	local _, held = _getTool()
	if not held then
		return
	end
	local character = LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid:UnequipTools()
	end
end

--[[
	开始追踪哑铃（幂等；Core.init 调用一次）
	@param onChanged () -> () - 持有 / 手持状态变化时回调，用于刷新快捷栏
	@return nil
]]
function BackpackPinnedTool.bind(onChanged: () -> ()): ()
	_onChanged = onChanged
	if _bound then
		return
	end
	_bound = true
	table.insert(_playerConns, LocalPlayer.CharacterAdded:Connect(_rebindContainers))
	table.insert(_playerConns, LocalPlayer.ChildAdded:Connect(function(child: Instance)
		if child:IsA("Backpack") then
			_rebindContainers()
		end
	end))
	_rebindContainers()
end

return BackpackPinnedTool
