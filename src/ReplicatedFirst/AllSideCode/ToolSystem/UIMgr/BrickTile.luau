--[[
	Module: UIMgr/BrickTile
	Description: UIMgr 子模块 — UI 积木格子平铺图按父级底色/渐变自动上色（由 init 合并导出至 Utils.UIMgr）
	Author: 程莘
	Created: 2026-10-15
	Last Modified: 2026-10-15

	背景：
	- 积木格子图 BRICK_TILE_IMAGE 是不透明白底积木块（带灰色阴影），必须额外上色，
	  否则会盖住父级底色/渐变，显示成一层白砖
	- 约定积木图是父级 GuiObject 的直接子 ImageLabel / ImageButton（ScaleType = Tile），铺满父级

	功能：
	- BRICK_TILE_IMAGE：UI 积木格子图统一资源 ID，新 UI 一律用它
	- BindBrickTiles(root)：绑定 root 下现有及之后新增的积木图，持续跟随父级：
	  · 父级 BackgroundColor3 → 积木图 ImageColor3
	  · 父级 BackgroundTransparency → 积木图 ImageTransparency
	  · 父级 UIGradient（Color / Rotation / Offset / Transparency / Enabled）→ 积木图自有的 BrickTileGradient；
	    父级无渐变时删除 BrickTileGradient
	  · 父级运行时改色、换稀有度渐变、渐变循环动画都会同步
	- 积木图设属性 BrickTileFixed = true 时不跟随（美术单独定色，如加载界面 BgPattern）；该属性只在绑定时读取

	约束：
	- 积木图的 ImageColor3 / ImageTransparency / BrickTileGradient 只由本模块写；
	  业务要改色请改父级，或给积木图设 BrickTileFixed 后自管
	- 仅客户端调用；UIManager 启动时对 PlayerGui 调用一次。同一 root 重复调用为 no-op
	- 判定只看实例加入时的 Image；之后才改成积木图的实例不会自动绑定

	加载方式：
		local Utils = require(game.ReplicatedFirst.AllSideCode.UtilsSystem)
		local UIMgr = Utils.UIMgr

	示例：
		UIMgr.BindBrickTiles(playerGui)
		bricks.Image = UIMgr.BRICK_TILE_IMAGE
]]

local BrickTile = {}

BrickTile.BRICK_TILE_IMAGE = "rbxassetid://119367443786424"

local FIXED_ATTR = "BrickTileFixed"
local GRADIENT_NAME = "BrickTileGradient"

type BindState = {
	base: { RBXScriptConnection },
	gradient: { RBXScriptConnection },
}

local _bound: { [Instance]: BindState } = {}
local _boundRoots: { [Instance]: boolean } = {}

--[[
	是否为积木格子图实例
	@param inst Instance - 待检查实例
	@return boolean - ImageLabel / ImageButton 且 Image 为 BRICK_TILE_IMAGE 时 true
]]
local function _isBrickTile(inst: Instance): boolean
	if not (inst:IsA("ImageLabel") or inst:IsA("ImageButton")) then
		return false
	end
	return (inst :: ImageLabel).Image == BrickTile.BRICK_TILE_IMAGE
end

--[[
	断开并清空连接列表
	@param list { RBXScriptConnection } - 待断开的连接
	@return () - 无返回值
]]
local function _disconnectAll(list: { RBXScriptConnection })
	for _, connection in list do
		connection:Disconnect()
	end
	table.clear(list)
end

--[[
	把父级渐变属性复制到积木图自有渐变
	@param source UIGradient - 父级渐变
	@param target UIGradient - 积木图的 BrickTileGradient
	@return () - 无返回值
]]
local function _copyGradient(source: UIGradient, target: UIGradient)
	target.Color = source.Color
	target.Rotation = source.Rotation
	target.Offset = source.Offset
	target.Transparency = source.Transparency
	target.Enabled = source.Enabled
end

--[[
	取积木图自有渐变，没有则新建
	@param image GuiObject - 积木图
	@return UIGradient - 积木图的 BrickTileGradient
]]
local function _getOwnGradient(image: GuiObject): UIGradient
	local existing = image:FindFirstChild(GRADIENT_NAME)
	if existing and existing:IsA("UIGradient") then
		return existing
	end
	local gradient = Instance.new("UIGradient")
	gradient.Name = GRADIENT_NAME
	gradient.Parent = image
	return gradient
end

--[[
	按父级当前 UIGradient 重建渐变跟随（父级换渐变时重新调用）
	@param image GuiObject - 积木图
	@param parent GuiObject - 积木图父级
	@param state BindState - 该积木图的绑定状态；gradient 列表会被重置
	@return () - 无返回值
]]
local function _bindGradient(image: GuiObject, parent: GuiObject, state: BindState)
	_disconnectAll(state.gradient)
	local source = parent:FindFirstChildOfClass("UIGradient")
	if not source then
		local own = image:FindFirstChild(GRADIENT_NAME)
		if own then
			own:Destroy()
		end
		return
	end
	local own = _getOwnGradient(image)
	_copyGradient(source, own)
	table.insert(
		state.gradient,
		source.Changed:Connect(function()
			_copyGradient(source, own)
		end)
	)
end

--[[
	解除积木图的全部跟随连接
	@param image Instance - 积木图
	@return () - 无返回值
]]
local function _unbind(image: Instance)
	local state = _bound[image]
	if not state then
		return
	end
	_disconnectAll(state.base)
	_disconnectAll(state.gradient)
	_bound[image] = nil
end

--[[
	绑定积木图跟随父级底色、透明度与渐变；重复调用会先解绑再按当前父级重绑
	@param image GuiObject - 积木图（ImageLabel / ImageButton）
	@return () - 无返回值
]]
local function _bind(image: GuiObject)
	_unbind(image)
	if image:GetAttribute(FIXED_ATTR) == true then
		return
	end
	local parent = image.Parent
	if not parent or not parent:IsA("GuiObject") then
		return
	end
	local guiParent = parent :: GuiObject
	local imageObj = image :: ImageLabel
	local state: BindState = { base = {}, gradient = {} }
	_bound[image] = state

	local function syncBase()
		imageObj.ImageColor3 = guiParent.BackgroundColor3
		imageObj.ImageTransparency = guiParent.BackgroundTransparency
	end
	local function onParentChildChanged(child: Instance)
		if child:IsA("UIGradient") then
			_bindGradient(image, guiParent, state)
		end
	end

	syncBase()
	_bindGradient(image, guiParent, state)

	table.insert(state.base, guiParent:GetPropertyChangedSignal("BackgroundColor3"):Connect(syncBase))
	table.insert(state.base, guiParent:GetPropertyChangedSignal("BackgroundTransparency"):Connect(syncBase))
	table.insert(state.base, guiParent.ChildAdded:Connect(onParentChildChanged))
	table.insert(state.base, guiParent.ChildRemoved:Connect(onParentChildChanged))
	table.insert(
		state.base,
		image:GetPropertyChangedSignal("Parent"):Connect(function()
			if image.Parent then
				_bind(image)
			else
				_unbind(image)
			end
		end)
	)
	table.insert(
		state.base,
		image.Destroying:Connect(function()
			_unbind(image)
		end)
	)
end

--[[
	绑定 root 下现有及之后新增的积木格子图，使其持续跟随父级底色、透明度与 UIGradient。
	同一 root 只绑定一次；root 的 DescendantAdded 连接随 root 生命周期存在（PlayerGui 即会话期）。
	@param root Instance - 扫描根节点，通常为 LocalPlayer.PlayerGui
	@return () - 无返回值
]]
function BrickTile.BindBrickTiles(root: Instance): ()
	if _boundRoots[root] then
		return
	end
	_boundRoots[root] = true

	for _, descendant in root:GetDescendants() do
		if _isBrickTile(descendant) then
			_bind(descendant :: GuiObject)
		end
	end
	root.DescendantAdded:Connect(function(descendant: Instance)
		if _isBrickTile(descendant) then
			_bind(descendant :: GuiObject)
		end
	end)
end

return BrickTile
