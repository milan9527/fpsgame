# 运行与运维

## 启动和检查

```bash
./tools/setup.sh
docker compose ps
curl -f http://127.0.0.1:8000/health
docker compose logs --tail 50 api game game2
```

`setup.sh` 仅在 `.env` 不存在时生成三项随机密钥，并设置权限 0600。不覆盖已有凭据。容器自动重启策略为 `unless-stopped`。数据库、缓存和战绩队列均使用持久卷，日志按大小轮转。

```bash
# 重启服务，保留数据
docker compose restart
# 停止服务，保留卷
docker compose stop
# 再次启动
docker compose up -d
```

不要使用 `docker compose down -v`，除非明确要清空全部数据库与持久队列。

## 远程玩家接入

1. `.env` 的 `GAME_PUBLIC_HOST` 改为玩家能访问的域名或 IP。
2. 在宿主机前配置 HTTPS 反向代理，将 API 转发至 `127.0.0.1:8000`；客户端输入对应 HTTPS URL。当前不自动申请域名或证书。
3. 放行专用服务器 UDP 27015 和 27022，API 的 HTTPS 端口使用反向代理所设端口。
4. 运行 `docker compose up -d` 载入配置。

API 默认仅绑定环回地址；数据库与 Redis 不对外开放。开发用 HTTP 不应直接作为公网账号入口。若仅通过本机测试或 SSH 隧道连接，可使用默认地址。

## 备份

```bash
./tools/backup.sh
```

备份保存至 `artifacts/backups/`。PostgreSQL 使用一致性逻辑转储，另保存两个专服的战绩重试队列：`results.json` 与 `results-game2.json`。备份含账户哈希和游戏数据，目录权限为 0700、文件为 0600。新脚本先写唯一临时目录，全部命令成功且 JSON 队列可解析后才发布备份目录；`manifest.json` 记录格式版本、构建信息及各文件长度与 SHA-256。旧版无清单备份需要重新生成才能使用下面的自动演练。

运行以下命令对指定备份进行真实恢复演练：

```bash
python3 tools/restore_drill.py artifacts/backups/<备份目录名>
python3 tools/test_backup_integrity.py artifacts/backups/<备份目录名>
```

演练先验证清单与文件完整性，再启动独立 PostgreSQL 16 容器：无网络、无宿主端口、使用临时内存文件系统，不挂载正式数据库卷。它以单事务恢复转储，检查迁移版本、行数、约束、孤立/重复结果及统计值范围，并实际探测外键拒绝非法写入。成功或失败都会清理已创建的临时容器；报告只有在成功清理后才发布至 `artifacts/restore-drill.json`。报告不含账号名称、密码哈希或令牌。当前演练限定 512MiB 容器内存、2GiB 临时数据空间；更大的数据库需要单独规划恢复资源，超限应视为演练失败。

数据库转储使用一致性快照，两个战绩队列在转储后分别读取，**不是跨服务的一致时刻备份**。队列只检查哈希及 JSON 数组格式，演练不会重放队列；正式恢复需要核对队列涉及的用户与已结算 match_id，再通过原有幂等结算接口处理，不能直接认为队列与数据库必然匹配。Redis 中房间目录、占位与票据依赖短租约和进程实例，不应随旧备份恢复；恢复部署时使用干净缓存，由新专服重新注册。当前未实现跨主机恢复、自动备份调度或异地副本。

正式恢复应先停止账号写入和游戏服务，保留原卷及配置，在替代数据库完成上述演练和应用验证后再切换，并重新启动空缓存与专服。此工具不会自动覆盖现有生产库；当前演练也不宣称已验证应用切换、非空队列重放或完整灾备流程。备份仍位于本机，需另外保存至独立存储。

## 配置与容量

当前一个房间最多 16 名参战者，空缺用机器人补足。API 运行两个 worker；Godot 固定两个专用实例，使用房间目录匹配。已做有限的延迟和随机丢包验证；尚未完成 16 真人压力测试、长时间稳定性测试或自动扩容验证，不能据此宣称支持大规模生产运营。

Linux 客户端以 OpenGL Compatibility 渲染。开发主机通过软件 OpenGL 做实际渲染验证，所得性能不代表玩家 GPU 性能。Windows、macOS、移动端目前未打包验证。

## AI 任务

容器独立于编辑器和 Codex 前端运行。AI 自主开发的持续性取决于平台提供的 Goal 调度和会话生命周期，不由 Docker restart 保证。项目状态与下一步工作保存在 `docs/STATUS.md`，重新打开工作区可据此续接。

## 测试资源

骨骼蒙皮测试通过 Xvfb 使用实际 OpenGL 渲染，验证顶点变形与脚底位置；纯 headless 渲染器不能完成这项检查。联机测试账户凭据保存在忽略提交且权限为 0600 的 `artifacts/test-accounts.json`，不包含持久令牌。仅在重建测试数据库后删除此缓存以重新生成测试账户。

数据库升级已改用 Alembic，API 启动前自动运行事务迁移；`/health` 返回实际版本。升级策略和真实数据保留验证见 [数据库迁移](DATABASE_MIGRATIONS.md)。
