# Dev-Framework

Roblox Luau 项目框架，使用 Rojo 同步代码。共享模块在 `ReplicatedFirst/AllSideCode`，权威业务在 `ServerStorage/ServerSideCode/System`，客户端表现位于 `ReplicatedStorage/ClientSideCode`。

## 构建与启动

1. 使用 `aftman.toml` 中的工具版本安装 Rojo，执行 `rojo build default.project.json -o build.rbxlx` 检查项目映射。
2. 在对应的 Studio 模板 Place 中连接 `rojo serve`。`servePlaceIds` 需要匹配实际开发 Place。
3. 启动前确认模板资源齐全：`ReplicatedFirst.PreloadGui`、`PreloadGui_Teleport`、`ReplicatedStorage.Assets` 中业务引用的资源、`StarterGui` 的业务 UI、`SoundService.UI` 音效和场景对象。仓库只包含部分资源，**单独 build 的文件不是完整可玩游戏**。
4. `default.project.json` 已包含框架的 Msg 管道和现有 ShortVideoScreen 资源。Assets 和 ScreenGui 保留 Studio 中未由代码管理的实例。加载屏缺失会在 15 秒后警告并解除加载标记，便于定位资源问题。
5. `GameConfig.CustomAppearance` 默认关闭；只有启用并提供自己的资源 ID 后才替换角色外观。测试刷怪脚本仅在 Studio 执行。

## 本地检查与 CI

下载官方 [Luau 0.742 工具](https://github.com/luau-lang/luau/releases/tag/0.742)，解压后运行：

```powershell
python scripts/check_framework.py --luau-dir C:/Tools/luau
rojo build default.project.json -o build.rbxlx
```

检查脚本先编译全部 Luau 文件，再执行 `tests/framework.spec.luau`。测试直接加载生产源码，在模拟 DataStore/调度器中注入写前失败、写后回包丢失、租约被接管、事务异常和并发保存等情形。GitLab CI 执行同一入口和 Rojo 构建；工具版本与 SHA-256 固定在 CI 安装脚本中。新增纯算法模块同时执行 luau-analyze。无需连接正式 DataStore。

这不能替代 Studio 多客户端联调。发布前还应验证：慢加载时键位恢复、断线重连、跨服传送、在线/离线赠送、带真实资源的 UI 与角色初始化，以及测试环境中的 Marketplace 收据回调。

## 存档与奖励事务

- `SystemSave` 是玩家档唯一写口。加载通过 `UpdateAsync` 原子获取唯一会话租约，租约 120 秒；自动保存周期 30 秒。同一玩家的写入串行，批量保存最多四名玩家并行。旧服失去租约后不能覆盖新服。
- `ChangeStat` 保持旧签名并增量同步；`GetStatByKey` 只复制需要的字段。`Mutate(player, callback)` 用于整批内存修改。
- `Transact(player, transactionId, callback)` 把业务修改与去重账本一并持久化。回调必须同步、返回 `true` 或 `false, error`，不能 yield、直接写 Store 或触发外部副作用。嵌套 GamePass 事务加入外层收据事务。
- 仅提示、表现事件和可重建镜像使用 `AfterCommit`，关键统计与收益必须在事务内修改。回调失败或异常丢弃草稿；存储结果不确定时保留草稿和相同 WriteId，重试确认后才返回成功。不会通过撤销去重标记再次发奖。
- 离服保存失败保留会话，自动保存继续重试；关服最多等待 25 秒。平台持续不可用或进程被强制终止时，尚未确认的普通进度仍无法保证落盘。收据保持待处理，未确认邮件/CDK可按相同标识重试。
- 内部 `_Session`、`_WriteId`、`_Transactions`、`_SchemaVersion` 不下发客户端。不要清除交易账本来减小存档；任何归档方案必须同时保证历史事件不可重放。

## 兼容与行为变化

- `GameConfig.DataStoreScope = "auto"`：Studio 使用 `studio`，正式服使用原有 `global` scope，保留正式档的 Store 名与键名。已发布的开发 Place 必须显式配置 `dev` 等独立 scope。Studio 旧测试数据不会自动从正式 scope 迁入。
- 新收据先在 PurchaseHistory 保存 Pending 路由与奖励快照，再持久发货，最后更新完成索引。旧 PurchaseHistory 的 `true` 无法区分“占位成功”和“真实发货”，继续视为历史完成，历史漏单必须按订单对账补偿。
- 邮件以稳定 MailId 去重，先发奖落盘再确认邮箱。旧 `IsSynced=1` 的邮件保持终态，无法自动推断历史漏发。
- 新 CDK 预留永久绑定兑换玩家，发奖失败后输入同一码可重试；不会释放给另一位玩家。旧已兑记录不自动补发。普通码已支持配置中的 type 1（时间窗内、每人一次）；未定义类型仍明确拒绝。
- 赠送购买前必须保存 productId→recipient 意图，同一产品只允许一个待处理意图。收据第一次处理后冻结投递目标，收件人离线时进入幂等邮件。取消 UI 选择不会改写已经提交的购买目标；Roblox 的取消购买回调只记录取消状态，保留原目标；同目标可重开提示，重开后标记 reviewRequired，已交付也不自动解除。换目标须经运营核对并使用 ReleaseVerifiedGift 解除，避免把未路由的延迟收据投给另一人。
- 在线奖励当前轮次跨登录保留，直到全领完或 GM 显式重置，付费 Unlock 不再离服丢失。
- Setting 迁移通过独立 schema 只执行一次。没有 schema 的旧档中，数值 1 仍沿用旧比例迁移为 100；无法从旧值判断其原意是否为新制的 1%，这类历史数据需要产品侧确认。
- Developer Product 奖励整批入包。消耗品保留在背包，由既有 UseItem 入口消费；不再在收据回调中异步自动消耗，以免发货与消费各自失败形成不可恢复状态。

## 网络、调度与可选短视频

网络入口保留完整多返回值，检查全部参数中的非有限数、过深/过大载荷，未知路由静默拒绝。业务仍须校验目标、距离、技能权限和物品资格。限频用单调高精度时钟，瞄准采样允许每秒 30 次，为客户端 20 Hz 留出余量；超限日志与提示节流。

调度器每次交付完整累计 elapsed 后清零，同一任务不会重叠运行。键位加载在数据未就绪时重试；玩家事件先注册再处理已有玩家，技能消费者先初始化再发送绑定事件。模块加载的同协程循环依赖立即报错，跨协程等待有超时，不再递归 require 已加载中的模块。

短视频默认仍关闭。其 Store 访问已接入统一网关；请求列表、观看上报、状态查询加入限流；缓存定期驱逐并清理离服用户。点赞状态和计数在同一个对象记录内使用版本 CAS，玩家点赞表只是可重建索引。为避免单键超过存储容量，每条内容最多记录 20,000 位历史投票用户；达到上限会拒绝新的首次投票，扩大规模前需要分片。旧的重复计数不能自动推断并纠正，评论排序索引仍是最终一致，需要真实负载下验证。


## 第二轮可靠性优化

- 会话等待上限 20 秒；超时不会强行解开其他协程的锁。存储异常释放本地标记；失去所有权的旧会话立即隔离并退出缓存。平台 IO 本身不能安全取消，关服总等待仍为 25 秒。
- 嵌套 Mutate/Transact 失败会使整个外层草稿失效，即使业务忽略其返回值也不提交部分数据。不确定事务的草稿对普通查询隐藏；后续事务先确认旧写入，再处理新请求。
- 入包、扣除、锁定、快捷栏互换和交易扣除统一经过草稿；批量扣除先汇总重复 ID、跳过锁定行，再整批提交。UseItem 只扣指定 onlyID，不会误扣另一堆同类物品。新玩家初始奖励的 pending 状态与发放标记支持重进恢复。RemoveTradeItem 仍只是**单玩家扣除**，不是跨玩家原子交易协议。
- 商品目标、数量及 GamePass 解锁信息以版本化快照持久化。普通商品配置删除后，已冻结的订单仍可使用快照继续发货；物品自身配置仍须保留，否则拒绝发放并等待修复。
- 邮件在线轮询与投递串行化，失败退避 30～300 秒，每次最多处理 10 封。确认邮件精简为最近 100 个 MailId；更旧的重复投递由玩家永久事务账本拦截。赠礼快照可使用空的普通 RewardID 列表，普通 GM 邮件仍校验数量上限。
- 超过 512 条可归档交易标记后，自动保存每轮归档一个桶；64 桶使用玩家 Store 的 `Player{uid}:{bucket}` 键。只有归档写入被确认后才移除主档标记，读取失败拒绝发奖。每会话最多缓存四个 64 KB 小桶。receipt/mail/use/daily/online/code/cdk 等归档类型只能作为顶层事务；gamepass 等少量嵌套事务保留在主档。归档会分散增长，**不是无限容量保证**，达到单桶容量需要后续扩桶迁移。
- 存储网关按 [Roblox 请求预算](https://create.roblox.com/docs/cloud-services/data-stores/error-codes-and-limits) 有界等待，普通请求最多 4 个并发，关键保存最多 8 个并发，并优先于普通请求；重试使用带抖动的退避。序列化检查拒绝非法 UTF-8、混合/稀疏数组、循环和非有限数，按保守 JSON 字节上界为玩家档保留空间。小字段修改缓存根字段大小，避免每次遍历整包。
- 玩家初始化状态为 Loading/Ready/Failed/Leaving，Ready 后才设置 HasInit。连接和 AFK 恢复按 Player 实例隔离；角色事件先连接再检查当前角色，延迟回调核对角色身份。
- 网络新增跨路由令牌桶（120 请求/秒、突发 240）和每玩家 8 个并行业务槽；未知路由也占预算。HandlerOptions.validate 可声明参数结构，赠礼入口已接入。领域内的距离、冷却和资格判断仍由相应 System 执行。
- 短视频评论发布/删除先写持久待办，再完成正文、双索引和按 cid 幂等的计数；部分失败不会删除已确认正文。删除使用墓碑避免重试复活，迁移必须全部成功才记录完成，并保留旧数组备份。待办在访问和周期清理时重试；缓存增加字节上限。短视频仍默认关闭，20,000 位历史投票用户上限未改为分片模型。

### 消耗品脚本契约

仓库不包含项目实际使用的 ItemScript 实现。接入模板里的 UseScript 时，须明确声明 `Transactional = true`：

```lua
local Utils = require(game.ReplicatedFirst.AllSideCode.UtilsSystem)
local SystemSave = Utils.SystemSave
local Item = { Transactional = true }

function Item.Use(player, params, count)
    -- 只调用 SystemSave/PlayerData 修改持久字段，检查每个业务调用的返回值。
    -- 不能 yield、访问 DataStore 或在这里直接播放效果。
    -- 如需表现，在 SystemSave.AfterCommit(player, callback) 中处理。
    return true, { used = count }
end

return Item
```

声明只表示脚本承诺遵守契约；外部脚本仍须审查，运行时会拒绝 yield。UseItem 现在返回 `true, payload` / `false, error`；未迁移的旧脚本返回 `USE_SCRIPT_NOT_TRANSACTIONAL`，不会扣物品。开发者商品仍只入包，不自动使用；在线奖励仍跨登录保留，没有改变上一轮规则。

### 运营核对与回退

`Utils.SystemPurchaseRecovery` 不注册任何 Remote，供可信服务端运营脚本使用：

1. `Preview(player, purchaseId)` 只读查询。`LegacyUnverified` 不是已确认漏单，必须先核对平台订单和历史存档。
2. 核对后调用 `ApplyVerified(player, purchaseId, caseId, reason, frozenGrant)`。相同订单只接受一份补发计划；超时重试必须沿用相同订单和工单。完成索引更新失败返回 `INDEX_PENDING`，奖励仍由玩家账本去重。
3. `PreviewGift(player, productId)` 查看冻结意图；确认没有未路由订单后，以该快照调用 `ReleaseVerifiedGift(player, productId, expected, caseId, reason)`，解除与审核依据同档提交。不要按超时自动清除意图。

本轮未执行任何真实补发、赠礼解除或线上数据迁移。开始归档后，**不能直接回退到不识别 `_ArchiveBuckets` 的旧 SystemSave**；旧版本会丢失归档去重检查。需要回退业务时保留本轮存档、归档、邮件和收据兼容层，或先停服进行独立验证的数据迁移；不能删除归档桶。

### Studio 发布前验证

先在匹配 `default.project.json` 的模板编辑模式运行 `scripts/studio_preflight.luau`。它只读取基础资源与 Place ID；通过不代表全部业务资源齐全。随后在隔离 scope 验证：

| 场景 | 通过条件 |
|---|---|
| 双客户端同时领取、扣除及装备 | 数量正确、无部分修改、槽位不冲突 |
| 慢读档期间退出、重进、连续重生 | 初始化状态正确，无旧回调影响新角色 |
| 收据重试、赠礼离线领取、邮件确认失败 | 相同 ID 只发一次，待办最终完成 |
| 租约接管、关服保存、存储预算不足 | 旧服不能覆盖新档，失败可观察且不假报成功 |
| 消耗品脚本报错、返回失败、yield | 不扣物品、不保留部分收益，表现只在成功后执行 |
| 评论迁移、计数/索引失败、删除重试 | 保留正文/原始备份，计数不重复，墓碑不复活 |

仍需真实 Studio/测试服务器完成引擎、Marketplace、跨服和负载验证；模拟测试与 Rojo 构建不覆盖这些条件。CDK 全池扫描索引化、投票分片以及全部 Remote 的业务协议逐项审计仍属于后续扩展工作。
