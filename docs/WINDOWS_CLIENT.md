# Windows 客户端

下载站：<https://d3j1sc8stx5n1c.cloudfront.net>

2026-09-13 已发布 [Windows x64 ZIP](https://d3j1sc8stx5n1c.cloudfront.net/downloads/IronMeridian-Windows-x86_64.zip)，
约 33 MiB。公网下载摘要与测试包一致：
`d588cafa455f2a1175337809b7bf9314c25968f5eaec2488c84e7743dddc79d5`。

Windows 10/11 x64 便携版无需安装。右键 ZIP 选择“全部解压”，打开
`IronMeridian-Windows` 文件夹，双击 `IronMeridian.exe`。
不要直接从压缩包预览窗口运行。需要支持 OpenGL 3.3 的显卡驱动。

游戏内容已嵌入 EXE，不需要 Godot、Python、`play.sh` 或 SSH。
离线单人和双人机器人模式无需账号；联网时在游戏内创建账号或登录。
新客户端已预填 `https://d3j1sc8stx5n1c.cloudfront.net/api`。
玩家保存过的连接地址仍优先使用。

这是未签名的开发版，不包含商业代码签名证书，Windows 可能显示发布者未知。
校验值见下载页面和 `artifacts/windows-build/build.json`。
玩家数据保存在 `%APPDATA%\Godot\app_userdata\Iron Meridian`。

## 构建

`tools/package_windows.py` 默认从已部署版本
`484d98d958a0973d5dc630ce6474dcdcba950035` 提取独立源码，
加入默认 API 地址、记住登录和瞄准点修复，不打包当前分支尚未发布的玩法改动。
保持协议 17、内容 `ash-valley-18`，与现有 ECS 游戏服务器兼容。

需要 Godot 4.4.1、同版本官方 Windows x86_64 导出模板、Xvfb。
官方模板压缩包已用发行页的 `SHA512-SUMS.txt` 校验。
将 Windows 模板放入
`~/.local/share/godot/export_templates/4.4.1.stable/` 后运行：

```sh
.venv/bin/python tools/package_windows.py
docker build -t iron-meridian-windows-test -f infra/windows-test.Dockerfile .
.venv/bin/python tools/test_windows.py
.venv/bin/python tools/publish_windows.py
```

构建前需保留或移走已有的 `artifacts/windows-build/source` 和
`IronMeridian-Windows` 构建目录。导入资源时使用 OpenGL 渲染器和 Dummy
音频设备，避免无图形服务器的纹理导入与音频设备错误。
EXE、中文启动说明、玩家手册、许可证、构建清单一起打包。

## 验证与发布

验证实际 Windows PE 程序，包含菜单、预填地址、离线单人/双人运行、
用户目录读写，以及两个客户端通过公网 HTTPS 和 NLB UDP 加入两种对战模式。
发布前必须通过验证，且 ZIP 摘要必须匹配报告。
发布使用 boto3 更新现有私有 S3 下载桶并刷新 CloudFront，无 CloudFormation。
发布后再次下载并校验 ZIP，检查网页仍无登录表单。

测试环境是 Wine 8、软件 OpenGL；不能替代 Windows 实机、物理声卡、
麦克风及显卡驱动测试。截图、运行日志与验证报告位于
`artifacts/windows-verification/`。网络测试使用容器 host 网络，
并在两个 Wine 环境初始化完成后同步启动客户端。
本次菜单、离线两种模式、瞄准回归及联网两种模式共八项检查均已通过。

## 瞄准修复

开镜动画期间旧版会在瞄具尚未居中时隐藏屏幕准星，狙击枪的枪模后坐动画也会移动红点。新版使用屏幕中心的红色瞄准点，关闭枪模上会偏移的红点；不修改服务器伤害、散布或命中盒。瞄准回归覆盖三种武器、开镜过渡、后坐和左右侧身共 108 个组合，并检查中心射线命中目标。通过 Windows EXE 在 Wine 环境执行该检查，截图为 `artifacts/windows-verification/aim-alignment.png`。

请重新下载 ZIP 并完整解压，用新 EXE 启动。此版也加入登录成功后记住账号密码及 FORGET LOGIN 功能。
