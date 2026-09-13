# AWS 原生 API 部署

部署入口是 `tools/deploy_aws_direct.py`，使用 boto3 直接创建资源，不使用
CloudFormation、CDK 或 Terraform。区域为 `us-east-1`。

## 当前部署与验收

2026-09-13 已部署：

- 下载网站：<https://d3j1sc8stx5n1c.cloudfront.net>
- 游戏内 API：`https://d3j1sc8stx5n1c.cloudfront.net/api`
- ECS 集群：`im-09dd9eda`，服务为 `api`、`solo`、`duo`。
- 迁移成功：55 个账号、123 场比赛、219 条结果。

公网验收通过：两名迁移账号登录和读取个人资料均返回 200，错误密码返回 401；
从网站下载并校验原生安装包，单人和双人模式各运行两名客户端，均通过
移动、射击、手雷、远端动作、菜单继续同步和状态协调检查。
网站无表单，登录页面与文档路径返回 403/404，认证接口 GET 返回 JSON 405。
网络审计确认三个 ECS 任务均无公网 IP、内部 ALB 仅接受 CloudFront
VPC origin 服务安全组、S3 禁止公网直连。

首次单人测试有一名客户端触发菜单同步的 0.6 秒时序断言，随后继续更新并
完成测试；严格验收仍判该轮失败。未放宽断言，完整复测通过。首次日志保存在
`artifacts/aws-public-verification/first-attempt/`；这次验证不代表网络永远无抖动。
证据为同目录下的 `verification.json`、`network-audit.json` 和四份客户端日志。

## 连接方式

下载站点由 CloudFront 提供 HTTPS，源站为开启全部 Public Access Block 的
S3 REST endpoint，使用 OAC 签名访问。网站只提供下载与说明，没有登录表单。
Windows x64 ZIP 解压后双击 `IronMeridian.exe`，已预填 AWS API 地址。
Linux x86_64 客户端使用 `play.sh` 启动，将站点显示的 `/api` 地址填入游戏，
注册或登录。离线模式不需要账号；暂不提供 macOS 版。
Windows 的构建和测试范围见 [WINDOWS_CLIENT.md](WINDOWS_CLIENT.md)。

游戏客户端的 HTTPS JSON 请求经过 CloudFront VPC origin 到内部 ALB，
再到私有 ECS API 服务。CloudFront 只允许指定的公开 API 路径；
Swagger、ReDoc、OpenAPI 和内部服务接口不会通过该入口发布。
`POST /api/auth/login` 是客户端必需的公开认证接口，不是网页登录页面。

实时对战通过公网 NLB 的 UDP 27015（单人）和 27022（双人）进入。
三个 ECS 服务均位于私有子网，`assignPublicIp=DISABLED`，安全组仅允许对应
负载均衡器和必要的服务间通信。NLB 不发布游戏健康检查 HTTP 端口。
客户端无需 SSH 转发。

PostgreSQL RDS 和 Redis ElastiCache 位于隔离子网。数据库启用加密、
TLS、Multi-AZ、七天备份及删除保护；Redis 启用 TLS、AUTH 和静态加密。
游戏待提交结果使用 EFS 持久化。Secrets Manager 通过 ECS 注入运行时凭据。

## 执行和恢复

需要已配置 AWS 身份、Python 环境中的 boto3、Docker，以及本机经过验证的
0.38 API/游戏基础镜像、Linux 安装包，以及通过验证的 Windows ZIP 和对应报告。
脚本校验安装包 SHA-256，防止误发布。

```sh
.venv/bin/python -u tools/deploy_aws_direct.py > artifacts/aws-direct-deploy.log 2>&1
.venv/bin/python tools/test_aws_public.py
```

资源检查点位于 `artifacts/aws-direct/state.json`，生成的凭据位于同目录
`generated-secrets.json`，均为 0600。不要提交、打印、删除这些文件，
也不要同时启动多个部署进程。失败时先确认原进程已退出、检查 AWS 实际状态，
再恢复执行；脚本会复用已经记录的资源。
它是本项目的部署脚本，不是通用的配置差异协调器；后续配置修改需要明确更新
对应 AWS 资源或 ECS task definition，不能仅靠再次运行推断已完成更新。

完成后，非敏感连接信息写入 `infra/aws/deployment-outputs.json`。
验证报告写入 `artifacts/aws-public-verification/`，包括公网页面检查、
迁移账号登录、安装包校验和实际下载客户端的两种联网模式测试。
测试从现有 EC2 发起，不能替代玩家所在地网络的验证。

## 数据迁移和运维

`artifacts/aws-migration.json` 是现有数据库的一致性快照，包含敏感账号数据，
保持 0600，只上传至独立私有数据桶。导入 ECS 任务检查摘要、表结构、
目标表为空及导入后的逐表内容指纹，不覆盖已有数据。
源数据库、原 Docker 服务与原备份不受影响。快照之后写入旧服务器的记录
不会自动同步到 AWS。

CloudWatch 日志保留 30 天，日志组见部署输出。API、单人、双人服务各运行
一个 ECS task；单个房间更新时会短暂中断。当前配置服务于核心玩法，
不承诺商业级容量或无中断升级。NAT、负载均衡器、数据库等会持续计费。
删除部署需要按检查点逐项处理资源及依赖，数据库需明确解除删除保护；
不要删除账户里其他应用的共享资源。

### Android 下载发布

Android 签名 APK 通过同一个私有下载桶和 CloudFront OAC 分发，见 [Android 客户端](ANDROID_CLIENT.md)。运行 `tools/publish_android.py` 只更新 APK 和下载页，不改变 ECS 服务；网页不提供登录表单，账号操作在安装后的游戏内完成。
