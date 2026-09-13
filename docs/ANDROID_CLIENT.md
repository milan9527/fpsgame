# Android 客户端

下载：https://d3j1sc8stx5n1c.cloudfront.net/downloads/IronMeridian-Android.apk

这是可直接安装的签名 APK（约 50 MiB），不是 Google Play 上架版本。安装时允许浏览器安装应用，完成后打开 Iron Meridian；无需 Godot、终端或启动脚本。支持 ARM64 / x86_64，要求 OpenGL ES 3.0。离线模式无需账号，联网在游戏内注册或登录，默认连接现有 AWS 服务。

## 触屏操作

左侧摇杆移动，右侧空白区域滑动转向；按住 FIRE 射击，也可在 FIRE 上拖动瞄准。屏幕按钮提供跳跃、冲刺、蹲伏、瞄准、侧身、换弹、拾取/交互、医疗、投掷物和武器切换。MAP / BAG 打开地图与背包，MENU 或 Android 返回键打开暂停菜单。联网打开菜单不会暂停服务器。语音默认关闭，开启时申请麦克风权限。

## 构建与发布

使用 Python 3.12、项目 `.venv`、Godot 4.4.1 Android 导出模板、Java 17、Android SDK platform/build-tools 34（签名验证用 build-tools 35）及 Xvfb。

```sh
.venv/bin/python tools/package_android.py
.venv/bin/python tools/test_android_source_network.py
.venv/bin/python tools/test_android_devicefarm.py
.venv/bin/python tools/publish_android.py
```

打包器从与线上服务器兼容的 Git 提交 `484d98d958a0973d5dc630ce6474dcdcba950035` 提取客户端，仅加入 Android 触屏界面、图标和默认 API 地址。重复构建前保存并移走 `artifacts/android-build/source`。APK、构建记录、测试证据在 `artifacts/`，不提交 Git。

签名密钥保存在 `artifacts/android-signing/release.keystore`，密码文件同目录、权限 0600。后续升级必须保留同一密钥并递增 version code；不要把该目录放进公开下载桶或源码仓库。请将此目录纳入受控的加密备份。

发布脚本要求 APK 签名有效、当前触屏源码与构建哈希一致、触屏回归通过、源码在线单人/双人检查通过，以及 AWS Device Farm 原生 APK 测试通过。使用已有私有 S3 + CloudFront OAC 发布，核对公开下载哈希和无网页登录表单；不部署 CloudFormation，不修改 ECS 网络。

## 验证范围

触屏多指、暂停、背包和失焦输入释放在桌面运行相同发行源码验证；单人/双人 AWS HTTPS + UDP 对战由相同源码的两客户端自动化验证。Device Farm 使用真实 Android 手机进行原生安装、启动及随机事件冒烟测试。随机事件测试不等价于真机完整通关或真机账号登录验证，语音和不同手机的帧率仍需实际设备体验。

本次 0.38.0-android.1 在 AWS Device Farm Google Pixel 3 / Android 10 上通过原生冒烟测试（3 项通过、0 项失败）。日志确认使用 Adreno 630 / OpenGL ES 3.2 启动，截图可见 Android 游戏主菜单；尚未完成真机完整对战及语音验证。
