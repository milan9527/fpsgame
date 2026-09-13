# 断线重连开发记录

当前尚不支持断线后重新进入原对局。短时丢包恢复只覆盖 ENet 连接仍存活的情况，不是重连。正式版本断开 peer 后仍立即淘汰并删除角色，保留参与者结果和队伍身份以正确结算。

## 开发中的保留窗口（默认关闭）

源码增加 `retained_sessions` 和 `reconnect_grace_seconds`，后者默认 0，未提供生产配置开关。仅测试显式启用时，live 中仍存活角色的 `connection_lost` 会保留其 actor、账号 session_version 和 generation，期限最多 30 秒。移除网络 session 后立即清除移动/射击/跳跃输入、取消治疗与正在执行的救援；驾驶员调用现有车辆控制重置。角色仍参与正常受伤与队伍规则，不获得免伤。

心跳把保留账号计入玩家与版本列表，后端报告撤销时立即清理；到期、回合结束或 generation 不一致时删除保留状态，按现有断线规则清理 actor。最后一个连接丢失时暂不回收仍有保留角色的房间，到期后再结算和回收。主动退出、已撤销及未启用的默认路径不保留角色；重复断开回调不会提前杀死已保留角色。

`tests/reconnect_retention.gd` 验证默认关闭、输入清理、正常护甲吸收下受伤、期限边界、主动退出/撤销排除、心跳撤销、最后连接到期后房间回收及重复回调。期限边界通过传入观察时间测试，没有等待真实 30 秒。心跳使用受控 HTTP 返回值，不是后端集成。日志 `artifacts/reconnect_retention-idempotent.log`；旧双人断线结算回归 `artifacts/duo_disconnect_rules-retention-final.log`。首次断言误将护甲吸收后的伤害全部视为生命损失，修正测试后通过。

这一阶段尚未实现重连票据、新 peer 与保留 actor 的绑定、客户端恢复，也尚未验证真实网络保留窗口中的驾驶、救援或中途回合结束。不得启用或发布为可用重连功能。

### 保留席位心跳契约

未发布源码的心跳增加 `reconnectable`，将保留账号 UUID 映射到剩余秒数（向上取整，1–30）。只有 live、同一 generation、尚未到期的保留状态才上报；正常连接的账号不在此表。后端要求这些账号同时存在于 players 与 session_versions，拒绝非整数、超范围时间及非 live 声明。旧心跳缺少此字段时默认空表，不自动授予重连资格。

`backend/tests/test_reconnect_contract.py` 的 16 项模型检查通过，覆盖序列化、时间类型与边界、对局阶段和账号绑定；源码在现有 API 镜像的隔离、无网络容器中执行，并未替换线上后端。`artifacts/reconnect-heartbeat-contract.log` 验证游戏侧声明、到期/旧 generation 排除及原有保留角色物理规则。这里还没有基于后端接收时间计算的授权截止时间或 Redis 原子重连票据；后续实现必须处理传输延迟与旧心跳，不能直接把剩余秒数当作永久有效的准入凭据。

### 保留驾驶员的物理验证

同一保留测试新增正常座位进入与实际驾驶：车速超过 10 m/s 后调用服务器断线处理，立即验证驾驶输入清空，再使用正常车辆物理完成制动。停车位移不超过初速度的物理制动距离加 0.5 m 容差，期间驾驶员与乘客均留在座位。对保留驾驶员施加伤害仍正常计入生命/护甲损失；到期清理后驾驶位与 driver_id 均释放，乘客生命和车体完整。日志 `artifacts/reconnect-retained-driver.log`，原有期限、撤销、最后连接回收等场景也一并通过。

测试直接调用断线与期限处理、使用真实物理帧；它补齐本地保留驾驶状态检查，不是 ENet 中断或重连恢复验证。功能仍默认关闭。

## 已完成的前置工作

源码现在区分服务端观察到的离开原因：`connection_lost`、`left`、`revoked`、`unauthenticated`。正常 `leave_operation` 为已登录会话标记主动离开；撤销优先于主动离开标记，因为客户端收到撤销通知后也可能发送离开请求。日志只记录 peer ID 与固定枚举，不包含账号或票据。该标记仅用于诊断，目前不延迟淘汰或改变准入规则。

`tests/duo_disconnect_rules.gd` 验证原因与优先级，并回归救援中断、队伍名次、淘汰归属与断线玩家结果保留。真实账号源码联网夹具中，驾驶员强制断线记录 `connection_lost`、撤销记录 `revoked`、乘客正常离开记录 `left`；制动、座位释放和乘员安全通过。日志 `artifacts/disconnect-reason-{rules,drop,revoke}.log`，详细服务器日志为 `artifacts/vehicle-login-duo-{drop,revoke}-server.log`。源码尚未发布。

## 当前实现中的约束

- `Game.peer_disconnected` 删除 session 并淘汰/移除 actor；最后一个 session 离开还会调用 `release_empty_room` 结算并更换 generation。要支持重连，需为意外连接丢失保留有界、仍可受伤的角色，并使房间回收识别保留状态。
- `Game.authenticate` 与 Redis 的房间票据消费均只接受 waiting/lobby。不能简单允许任意 live 票据；重连凭证须绑定同一 uid、session_version、room instance 和 generation，并且只能恢复属于该账号的角色。
- actor、participants、队伍成员、伤害/救援目标、投掷物归属、载具驾驶者以及输入历史均关联 peer ID。新连接会获得新 peer ID，需要明确稳定角色身份与连接身份的关系，不能只移动 actors 字典中的一项。
- 主动退出、账号撤销、超时、房间进程更换、回合结束和重复连接应分别处理；撤销不能被重连窗口绕过。新连接不能重放旧输入、旧座位 epoch 或重复结算。

后续实现须同时覆盖服务端状态保留、后端原子重连授权、客户端重新认证与完整快照恢复，以及到期/死亡/队伍救援/载具/最后连接离开的测试。这里列的是尚未实现的约束，不是功能完成声明。
