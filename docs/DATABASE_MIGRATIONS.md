# 数据库版本与升级

数据库结构由 Alembic 迁移管理，不再在应用启动时对当前模型调用 `create_all`。

## 当前版本

- `0001`：冻结最初的 users / matches / results 结构。
- `0002`：账户统计、战绩数值的数据库 CHECK 约束，以及用户战绩查询索引。

API 容器先运行 `python -m app.migrate`，迁移成功才启动 worker。`/health` 返回实际 `schema_revision`。

迁移在一个 PostgreSQL 事务内执行，并先获取事务级 advisory lock，防止两个实例同时初始化或升级同一数据库。迁移失败时表变更和版本记录一起回滚；未知版本不会被强行覆盖。

## 旧开发数据库

没有 `alembic_version` 的已有库不会直接标记为最新版本。迁移器先比对基线的表集合、列类型/空值/default、索引、外键、主键和 CHECK 约束。只有兼容原始基线时才登记 `0001`，随后执行正常升级。发生漂移时停止，并保留原结构和数据，需要明确检查差异。

第一次运行升级已经完成，并在同一事务内锁住应用表，对全部应用行计算前后摘要，证明升级未改写账户、密码哈希、比赛和战绩数据。证据保存在 `artifacts/live-migration.log`；升级前备份位置记录在 `artifacts/pre-migration-backup.log`。

## 后续开发流程

1. 先运行 `tools/backup.sh`。
2. 添加新的迁移文件，不修改已经应用过的迁移；同步修改 `app/models.py`。
3. 在独立数据库验证空库创建、旧库保留数据升级、失败回滚和多实例并发。
4. 构建 API 镜像，部署后检查 `/health` 中的版本及服务日志。

当前迁移测试使用同一 PostgreSQL 实例内临时创建的随机命名数据库，结束后仅删除这些测试数据库，绝不清空游戏库。测试角色需要创建数据库权限；生产环境应进一步拆分运行角色与迁移角色。

```bash
docker compose build api
docker compose run --rm --no-deps \
  -v "$PWD/backend/tests:/app/tests:ro" \
  api python -m pytest -q -p no:cacheprovider tests/test_migrations.py
```

`0002` 的结构回退到 `0001` 已在测试数据库中验证，并保留应用行。删除基线表会毁掉玩家数据，因此 `0001` 不提供自动 downgrade 删除路径。正常代码回退优先保留兼容的数据库结构；涉及数据恢复时先在独立数据库演练备份恢复。

`tools/verify_live_migration.py` 是本次小型开发库升级的额外校验工具，需要在 API 容器环境中运行。它聚合全部应用行计算摘要，**不适用于大规模生产库**，常规启动也不会运行它。大库升级仍需分批数据迁移、锁等待预算与在线 DDL 策略，当前尚未实现。
