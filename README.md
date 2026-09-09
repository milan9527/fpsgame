# Iron Meridian / 铁境行动

Godot 4.4.1 + Blender 4.3.2 原创战术生存射击项目，包含单机、专用多人服务器、FastAPI、PostgreSQL 和 Redis。**目前是可运行的开发版本，不是已达到《和平精英》规模、品质和功能覆盖的商业成品。**

## 已实现的可玩流程

启动菜单 → 离线部署或注册/登录 → 联机大厅 → 16 人自由混战（空位机器人）→ 射击、换弹、拾取、治疗、缩圈 → 排名结算 → 在线自动开始下一局。

一张原创场景、可进入建筑、掩体、三种枪械规则、原创 Blender 枪械与角色模型、第一人称瞄准、真实蹲伏碰撞与低顶检查、服务器后坐力和散布、确认命中与受击方向提示、枪声与弹道、HUD 和小地图。服务端裁定移动、射击、碰撞、伤害、缩圈与排名，客户端不提交位置或伤害值。

## 最快运行

```bash
# 后端、数据库、缓存和专用服务器，Docker 需已启动
./tools/setup.sh

# 有桌面显示的 Linux 主机
./tools/godot --path client
```

离线游戏只需要第二条命令。在线默认 API 为 `http://127.0.0.1:8000`，UDP 端口为 `27015`。创建用户名和密码后联机。数据库与 Redis 不映射主机端口。

已打包的桌面版本位于 `artifacts/IronMeridian-Linux-x86_64.tar.gz`，解压执行 `play.sh`。图形服务器环境没有物理显示器；此处通过 Xvfb + Mesa 实际渲染截图验证。

## 目录

| 路径 | 内容 |
|---|---|
| `client/` | Godot 工程、客户端与服务器共用战斗规则 |
| `art/` | Blender 原始 `.blend` 文件 |
| `client/assets/` | Blender 导出的 glTF 二进制模型 |
| `backend/app/` | 账户、票据、战绩与排行榜 API |
| `backend/tests/` | 真实 PostgreSQL / Redis 集成测试 |
| `tools/` | 安装、资产生成、打包、在线测试与运维脚本 |
| `infra/` | 专用服务器容器 |
| `docs/` | 玩家指南、架构、运维与开发状态 |
| `artifacts/` | 运行日志、截图与桌面发行包 |

## 验证

```bash
python3.12 -m venv .venv
.venv/bin/pip install httpx==0.28.1 pytest==8.3.5
./tools/verify.sh
```

包含 Godot 单机规则验证、真实服务集成测试以及两份独立 Godot 客户端的联机操作测试。`tools/test_full_round.py` 另外启动独立的 20 倍速测试服务器，验证完整回合与战绩落库；这不是实时性能或稳定性测试。API 测试会创建带随机前缀的测试账户和战绩。在线测试建议对专用测试实例执行，要求开始时无正在进行的对局。

资源重建：

```bash
tools/blender-4.3.2-linux-x64/blender --background --python tools/build_assets.py
tools/godot --headless --path client --editor --import
./tools/package.sh
```

Blender 可以安装到其他位置再执行同一 Python 脚本。首个脚本会重建本项目的两份模型文件。更多操作见 [玩家指南](docs/PLAYER_GUIDE.md)、[架构](docs/ARCHITECTURE.md)、[运维](docs/OPERATIONS.md) 和 [真实开发状态](docs/STATUS.md)。

## 后台运行与持续开发边界

Docker 服务使用 `restart: unless-stopped`，退出终端或 Codex 界面不会主动停止这些容器；宿主机和 Docker 必须持续运行。**后台游戏服务不等于后台 AI 开发。Goal 已建立，但本项目不能保证 Codex 界面退出、会话终止或平台任务取消后 AI 仍持续写代码。** 持续开发需要平台保持任务调度，不能通过一个本地脚本承诺无限自主开发。
