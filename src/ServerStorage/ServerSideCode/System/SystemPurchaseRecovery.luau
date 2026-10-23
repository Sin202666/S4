--[[
	Module: SystemPurchaseRecovery
	Description: 服务端订单核对与人工审核后的幂等补发；不注册 Remote、不自动补发旧 true 收据
	Author: 林奥宇
	Created: 2026-10-12
	Last Modified: 2026-10-12
	使用：先 Preview(player, purchaseId) 查看证据；核对平台订单与历史存档后，
	仅由可信运营脚本调用 ApplyVerified(player, purchaseId, caseId, reason, frozenGrant)。
	caseId 与理由会持久化；同一订单只允许一份不可变补发方案。奖励与补发标记同档提交。
]]
local Utils = require(game.ReplicatedFirst.AllSideCode.UtilsSystem)
local Store, Save, Buy, Copy = Utils.SystemDataStore, Utils.SystemSave, Utils.SystemBuyRoblox, Utils.Copy
local SystemPurchaseRecovery = {}

--[[ 查询订单状态，不修改存档或订单。
	@param player Player - 订单所有者
	@param purchaseId string - 平台 PurchaseId
	@return table? , string? - {key,state,history} 或错误码；LegacyUnverified 必须人工核对
]]
function SystemPurchaseRecovery.Preview(player, purchaseId)
	if not player or type(purchaseId) ~= "string" or #purchaseId == 0 or #purchaseId > 100 then return nil, "INVALID_ORDER" end
	local key = tostring(player.UserId) .. "_" .. purchaseId
	local ok, history = Store.Get(Store.STORE.PurchaseHistory, key)
	if not ok then return nil, "ORDER_UNAVAILABLE" end
	return { key = key, state = if history == true then "LegacyUnverified" elseif type(history) == "table" then history.state else "Missing", history = Copy.deepCopy(if type(history) == "table" then history else {}) }
end

--[[ 执行已核对的历史漏单补发；只允许旧 true 收据，不从客户端接收参数。
	@param player Player - 在线订单所有者
	@param purchaseId string - 已核对的平台订单 ID
	@param caseId string - 运营工单 ID，重试必须相同
	@param reason string - 审核依据摘要，不含敏感凭证
	@param grant table - 服务端 CreateGrantSnapshot 生成并人工核对的奖励快照
	@return boolean, string? - 已确认补发或错误码；IO 失败可用相同参数重试
]]
function SystemPurchaseRecovery.ApplyVerified(player, purchaseId, caseId, reason, grant)
	if type(caseId) ~= "string" or #caseId == 0 or #caseId > 80 or type(reason) ~= "string" or #reason == 0 or #reason > 500 then return false, "AUDIT_REQUIRED" end
	if type(grant) ~= "table" or grant.version ~= 1 or not Store.ValidateValue(grant, 32768) then return false, "INVALID_GRANT" end
	local preview, err = SystemPurchaseRecovery.Preview(player, purchaseId)
	if not preview then return false, err end
	local accepted, row = Store.Update(Store.STORE.PurchaseHistory, preview.key, function(old)
		if old == true then
			return { state = "Delivered", legacy = true, recovery = { caseId = caseId, reason = reason, grant = Copy.deepCopy(grant), state = "Pending", createdAt = os.time() } }
		end
		return old
	end)
	if not accepted or type(row) ~= "table" or not row.legacy or not row.recovery then return false, "NOT_LEGACY_ORDER" end
	if row.recovery.caseId ~= caseId then return false, "RECOVERY_CASE_CONFLICT" end
	if row.recovery.state == "Delivered" then return true, "ALREADY_APPLIED" end
	local saved, saveErr = Save.Transact(player, "reconcile:" .. preview.key, function()
		return Buy.GrantSnapshot(player, row.recovery.grant)
	end)
	if not saved then return false, saveErr end
	local indexed = Store.Update(Store.STORE.PurchaseHistory, preview.key, function(old)
		if type(old) ~= "table" or not old.recovery or old.recovery.caseId ~= caseId then return nil end
		old.recovery.state, old.recovery.deliveredAt = "Delivered", os.time()
		return old
	end)
	return true, if indexed then nil else "INDEX_PENDING"
end

--[[ 只读查看某商品冻结的赠礼目标与状态。
	@param player Player - 赠送者
	@param productId number - Developer Product ID
	@return table? - 意图快照，未加载或无意图为 nil
]]
function SystemPurchaseRecovery.PreviewGift(player, productId)
	return Save.GetStatByKey(player, { "GiftIntents", tostring(productId) })
end

--[[ 运营核对所有未决订单后解除赠礼占用；禁止自动过期或客户端调用。
	@param player Player - 已加载的赠送者
	@param productId number - 商品 ID
	@param expected table - PreviewGift 返回的 target/createdAt 快照，防止审核期间意图变化
	@param caseId string - 审核工单号
	@param reason string - 已核实没有未路由订单的依据摘要
	@return boolean, string? - 已保存或冲突/失败
]]
function SystemPurchaseRecovery.ReleaseVerifiedGift(player, productId, expected, caseId, reason)
	if type(productId) ~= "number" or productId <= 0 or productId >= 2^53 or productId % 1 ~= 0
		or type(expected) ~= "table" or type(caseId) ~= "string" or #caseId == 0 or #caseId > 80
		or type(reason) ~= "string" or #reason == 0 or #reason > 500 then return false, "AUDIT_REQUIRED" end
	return Save.Transact(player, "gift-review:" .. tostring(productId) .. ":" .. caseId, function(data)
		local current = data.GiftIntents[tostring(productId)]
		if not current or current.target ~= expected.target or current.createdAt ~= expected.createdAt then return false, "GIFT_INTENT_CHANGED" end
		data._GiftReviews = data._GiftReviews or {}
		data._GiftReviews[caseId] = { product = productId, target = current.target, reason = reason, at = os.time() }
		data.GiftIntents[tostring(productId)] = nil
		return true
	end)
end

return SystemPurchaseRecovery
