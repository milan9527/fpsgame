# 通过 SSH 远程玩

普通 `ssh -L` 只转发 TCP。游戏 API 使用 TCP，但 Godot/ENet 对战使用 UDP 27015（单人混战）和 27022（双人队伍）。只转发 8000 端口会出现登录后不能进入对局的问题。

项目提供 `tools/ssh_game_tunnel.py`，用一条 SSH 连接转发 API，并通过 SSH 数据流双向转送游戏 UDP 报文。服务器继续向客户端返回 `127.0.0.1`，此时它指向玩家电脑上的 UDP 转发入口，无需修改专服地址或开放公网 API/游戏端口。

## 玩家电脑操作

需要本机 Python 3.9+、OpenSSH，以及原本可以登录服务器的 SSH 密钥或 SSH 配置。服务器上已有 Python 3。使用与你通常登录服务器相同的用户名、主机和密钥。

先将工具复制到玩家电脑，例如：

```sh
scp -i /path/to/key.pem ec2-user@54.172.49.143:/home/ec2-user/project/fpsgame/tools/ssh_game_tunnel.py .
```

然后在**玩家电脑**运行（不要在服务器终端内运行）：

```sh
python3 ssh_game_tunnel.py ec2-user@54.172.49.143 -i /path/to/key.pem --api-port 18000
```

Windows 安装 Python 后可将 `python3` 换成 `py`。如果已有 SSH Host 别名，也可用 `python3 ssh_game_tunnel.py 你的SSH别名 --api-port 18000`，它会使用本机 SSH 配置。

保持此终端开启，在游戏 API 地址栏填写：

```text
http://127.0.0.1:18000
```

注册/登录后选择单人或双人联机。脚本同时监听本机 UDP 27015/27022；无需另外运行 `ssh -L`。旧的 8000 转发可以关闭。退出游戏后 Ctrl+C 结束隧道。

## 排错与限制

- Python 报地址已占用：关闭本机占用 UDP 27015/27022 的专服或另一个隧道。API 端口冲突时可修改 `--api-port`，并同步修改游戏地址栏；普通客户端的 UDP 端口应保持默认。
- SSH 报密钥或主机校验失败：先用相同主机/密钥执行普通 SSH 登录，按正常流程确认服务器指纹。工具不关闭主机身份校验，也不会上传私钥。
- 浏览器访问 `http://127.0.0.1:18000/health` 应返回 `status: ok`。此检查只证明 API 转发；能否对战还取决于 UDP 转送与游戏版本匹配。
- SSH 使用 TCP，丢包时可能增加游戏延迟。本方式适合 SSH 远程试玩；不是原生 UDP 公网专服的性能保证。
- 一个隧道支持多个本地客户端，最多 64 个活跃 UDP 源地址；90 秒没有本机数据后回收映射。关闭隧道会断开对局，当前发行版不支持恢复到原对局。
- 脚本仅转送至服务器回环地址上的两个固定游戏端口，不提供任意 UDP 代理。

分帧测试覆盖短写、分段读取、报文边界及非法目标/长度拒绝。真实 SSH 对战测试使用临时、仅监听本机的 sshd，以及两个独立的 0.38 打包客户端，设置 `--max-fps 60`；不代表已经验证玩家所在网络。

初次不限制帧率的无图形测试进入了 live 对局，但未通过固定时刻的切枪/弹药断言。60 FPS 下切枪、各枪弹药、移动、姿态、手雷与远端同步均通过；未将这一观察解释为任意帧率/延迟都可靠。建议用 `./play.sh --max-fps 60` 启动游戏进行 SSH 试玩。

单人记录：`artifacts/ssh-tunnel-verification.json`、`artifacts/ssh-tunnel-integration.log`。双人端口记录：`artifacts/ssh-duo-tunnel-verification.json`、`artifacts/ssh-duo-tunnel-integration.log`。测试生成的临时 SSH 密钥及服务在结束后清理，不修改常驻 SSH 配置。

### 独立网络中的账号登录验证

`tools/test_remote_ssh_login.py` 进一步从独立 Docker bridge 网络运行测试客户端，通过真实 SSH 连接宿主机桥接地址。客户端不能直接访问宿主机的 API 8000 端口，但经 SSH 后，两个已有测试账号均登录成功并读取到各自资料；错误密码返回 401，未认证资料请求返回 403。两份已发布 Godot 客户端随后通过同一隧道进入 16 名参战者的对局，移动、射击、切枪、弹药、姿态、手雷及远端同步均通过。

报告：`artifacts/remote-ssh-login/verification.json`；游戏日志：同目录 `client-0.log`、`client-1.log`。测试密码仅放在临时受限文件，报告不包含密码或令牌。临时容器、SSH 服务及密钥在结束后清理。

此测试区别于两个本机回环客户端，但仍运行在同一台宿主机上，不证明玩家的家庭网络、防火墙或未来 ECS/ALB/NLB 公网入口可用。后者尚未部署。
