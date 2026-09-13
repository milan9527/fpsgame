# 断线重连开发记录

当前尚不支持断线后重新进入原对局。短时丢包恢复只覆盖 ENet 连接仍存活的情况，不是重连。正式版本断开 peer 后仍立即淘汰并删除角色，保留参与者结果和队伍身份以正确结算。

## 已完成的前置工作

源码现在区分服务端观察到的离开原因：`connection_lost`、`left`、`revoked`、`unauthenticated`。正常 `leave_operation` 为已登录会话标记主动离开；撤销优先于主动离开标记，因为客户端收到撤销通知后也可能发送离开请求。日志只记录 peer ID 与固定枚举，不包含账号或票据。该标记仅用于诊断，目前不延迟淘汰或改变准入规则。

`tests/duo_disconnect_rules.gd` 验证原因与优先级，并回归救援中断、队伍名次、淘汰归属与断线玩家结果保留。真实账号源码联网夹具中，驾驶员强制断线记录 `connection_lost`、撤销记录 `revoked`、乘客正常离开记录 `left`；制动、座位释放和乘员安全通过。日志 `artifacts/disconnect-reason-{rules,drop,revoke}.log`，详细服务器日志为 `artifacts/vehicle-login-duo-{drop,revoke}-server.log`。源码尚未发布。

## 当前实现中的约束

- `Game.peer_disconnected` 删除 session 并淘汰/移除 actor；最后一个 session 离开还会调用 `release_empty_room` 结算并更换 generation。要支持重连，需为意外连接丢失保留有界、仍可受伤的角色，并使房间回收识别保留状态。
- `Game.authenticate` 与 Redis 的房间票据消费均只接受 waiting/lobby。不能简单允许任意 live 票据；重连凭证须绑定同一 uid、session_version、room instance 和 generation，并且只能恢复属于该账号的角色。
- actor、participants、队伍成员、伤害/救援目标、投掷物归属、载具驾驶者以及输入历史均关联 peer ID。新连接会获得新 peer ID，需要明确稳定角色身份与连接身份的关系，不能只移动 actors 字典中的一项。
- 主动退出、账号撤销、超时、房间进程更换、回合结束和重复连接应分别处理；撤销不能被重连窗口绕过。新连接不能重放旧输入、旧座位 epoch 或重复结算。

后续实现须同时覆盖服务端状态保留、后端原子重连授权、客户端重新认证与完整快照恢复，以及到期/死亡/队伍救援/载具/最后连接离开的测试。这里列的是尚未实现的约束，不是功能完成声明。
