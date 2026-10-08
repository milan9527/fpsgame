# 2026-09-16 服务器恢复记录

开发机游戏 API 无法启动：宿主机 8000 已被另一个项目的 Python 服务占用。单排和双排专服因 API 不可用反复重启。PostgreSQL、Redis 健康。

将本机 `.env` 的 `API_HOST_PORT` 设置为 8002，Compose 支持该变量，健康检查读取实际映射端口。API 仅绑定 `127.0.0.1:8002`，容器内部仍为 8000。保留已有 API 镜像恢复服务，再重启两个专服，没有清空数据库。

此次恢复使用以下镜像覆盖文件，避免重建正在开发的代码：

```sh
docker compose -f compose.yaml -f artifacts/server-repair-20260916/compose-image.yaml up -d --no-build --no-deps api
docker restart fpsgame-game-1 fpsgame-game2-1
```

SSH 隧道新增 `--remote-api-port` 参数，当前主机传入 8002；详见 `docs/SSH_PLAY.md`。该工具已通过 Python 编译和命令行检查，本次没有重新执行完整 SSH 链路测试。

验证结果见 `artifacts/server-repair-20260916/verification.json`：

- 本机与 AWS HTTPS API 健康检查均成功，协议 17、数据库版本 0004。
- 两个测试账号在两个环境登录、读取资料均成功。
- 已发布 Linux 原生客户端在每个环境分别运行单排、双排双客户端测试，共 8 次客户端执行，全部退出 0 并输出 `ONLINE_CLIENT_PASS`。
- 客户端测试覆盖进房、移动、射击、姿态、远端动画同步、手雷和爆炸等行为。
- API、数据库、缓存健康，两个专服恢复就绪。

AWS ECS 的 API、单排、双排服务各有一个运行任务。本次未修改 AWS 部署或下载地址，未推送 GitHub。验证从开发服务器运行，不能替代玩家 Android 真机启动测试。

画面优化后台进程仍运行，检查时最近完成第 255 轮；整体写实画质目标尚未完成。
