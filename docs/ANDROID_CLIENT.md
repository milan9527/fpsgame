# Android 客户端

下载：https://d3j1sc8stx5n1c.cloudfront.net/downloads/IronMeridian-Android-0.52.7-20260925.apk

这是可直接安装的签名 APK（约 320 MiB），不是 Google Play 上架版本。安装时允许浏览器安装应用，完成后打开 Iron Meridian；无需 Godot、终端或启动脚本。支持 ARM64 / x86_64，要求 OpenGL ES 3.0。离线模式无需账号，联网在游戏内注册或登录，默认连接现有 AWS 服务。

## 触屏操作

左侧摇杆移动，右侧空白区域滑动转向；按住 FIRE 射击，也可在 FIRE 上拖动瞄准。屏幕按钮提供跳跃、冲刺、蹲伏、瞄准、侧身、换弹、拾取/交互、医疗、投掷物和武器切换。MAP / BAG 打开地图与背包，MENU 或 Android 返回键打开暂停菜单。联网打开菜单不会暂停服务器。语音默认关闭，开启时申请麦克风权限。

## 构建与发布

使用 Python 3.12、项目 `.venv`、Godot 4.4.1 Android 导出模板、Java 17、Android SDK platform/build-tools 34（签名验证用 build-tools 35）及 Xvfb。

```sh
export ANDROID_BUILD_DIR=artifacts/android-latest-20260925-r10
.venv/bin/python tools/package_android.py
.venv/bin/python tools/test_android_ui.py
.venv/bin/python tools/test_android_source_network.py
.venv/bin/python tools/test_android_devicefarm.py
.venv/bin/python tools/schedule_android_walkthrough.py
# 等待原生操作测试完成，采集并人工审阅截图，生成对应 APK 的审阅记录后发布。
.venv/bin/python tools/publish_android.py
```

当前 0.52.7-android.20260925 使用最新工作区源码快照，包含最新场景、武器、移动端加载优化，并修复 Android 场景导出时草丛实例及颜色数据丢失（Android 部分草丛仍偏暗），协议 17 / ash-valley-19，version code 20260929；构建和验证记录位于 artifacts/android-latest-20260925-r10。旧协议客户端与新版服务器不兼容。构建脚本默认参数可能指向历史版本，复现本版必须使用该目录 build.json 记录的源码快照及版本参数。

签名密钥保存在 `artifacts/android-signing/release.keystore`，密码文件同目录、权限 0600。后续升级必须保留同一密钥并递增 version code；不要把该目录放进公开下载桶或源码仓库。请将此目录纳入受控的加密备份。

发布脚本要求 APK 签名有效、当前触屏源码与构建哈希一致、触屏回归通过、源码在线单人/双人检查通过，以及 AWS Device Farm 原生 APK 测试通过。使用已有私有 S3 + CloudFront OAC 发布，核对公开下载哈希和无网页登录表单；不部署 CloudFormation，不修改 ECS 网络。

## 2026-09-25 验证

最新版包含场景、武器、触屏、陀螺仪和移动加载优化。Android 真机通过安装、启动、单机、开火和视角拖动；对应源码验证 AWS 单人/双人联网及登录记忆。原生 Android 联网、物理陀螺仪手感和帧率尚未完成实测。首次加载需要等待。Android 截图中部分路边草丛仍偏黑，桌面草色改善不代表 Android 画面已达到相同效果。

0.52.7 已发布，下载页面与二维码均指向新版；公网 APK 的 SHA-256 与测试包一致。单排、双排 ECS revision 5 使用当前协议资源，并调整 ENet throttle，避免延迟波动造成分片快照主动丢弃。两种模式各两客户端通过联网检查，四个客户端配置通过登录记忆检查。网站没有登录表单，账号操作仍在游戏内进行。

以下为历史版本验证记录。

## 验证范围

触屏多指、暂停、背包和失焦输入释放在桌面运行相同发行源码验证；单人/双人 AWS HTTPS + UDP 对战由相同源码的两客户端自动化验证。Device Farm 使用真实 Android 手机进行原生安装、启动及随机事件冒烟测试。随机事件测试不等价于真机完整通关或真机账号登录验证，语音和不同手机的帧率仍需实际设备体验。

本次 0.38.0-android.1 在 AWS Device Farm Google Pixel 3 / Android 10 上通过原生冒烟测试（3 项通过、0 项失败）。日志确认使用 Adreno 630 / OpenGL ES 3.2 启动，截图可见 Android 游戏主菜单；尚未完成真机完整对战及语音验证。

## 0.38.0-android.2：记住登录

登录或注册成功后自动保存账号和密码；下次启动或返回菜单会自动填入，不会自动发起登录。失败或取消的登录不更新已保存凭据。不同服务器分别保存，切换地址不会填入其他服务器的密码。FORGET LOGIN 清除当前服务器在本机保存的账号密码；成功退出所有设备也会清除本机记忆。

凭据使用 Godot 加密文件保存在应用数据目录；随机密钥也存于该应用私有目录，并非 Android Keystore。普通 settings.cfg 不保存密码。Android 可直接覆盖安装新版，包名和签名不变、version code 为 3802；下载链接和二维码不变。

本次更新验证：凭据加密保存/重新读取、不同服务器隔离、清除及桌面/触屏菜单恢复检查通过；同一发行源码完成 AWS 单人/双人对战，并在四个新的客户端进程中验证真实登录凭据恢复。APK 在 AWS Device Farm LG Stylo 6 上通过原生冒烟测试；真机尚未单独验证账号恢复流程。

## 0.38.0-android.3：瞄准点修复

与 Windows 同步修复开镜过渡和枪模后坐动画造成的红点偏移，改为屏幕中心瞄准点。服务器散布、伤害和命中盒不变。version code 为 3803，同签名覆盖安装，原下载地址和二维码有效。瞄准几何回归覆盖三种武器及侧身/后坐/开镜过渡 108 个组合。

## 0.38.0-android.4：陀螺仪瞄准

在主菜单或 FIELD MENU 中打开 **GYROSCOPE**。默认 OFF；选择 ADS ONLY（仅开镜）或 ALWAYS（游戏中始终开启）。灵敏度独立可调 0.1–4.0 倍，并支持水平、垂直反转；设置自动保存。陀螺仪与手指瞄准叠加，不改变联网协议或服务器判定。

需要手机硬件陀螺仪，不需要额外运行时权限。页面显示是否收到传感器读数；尚未收到读数时可移动手机检查，不能仅凭零读数判断硬件不存在。开菜单、失焦、切到后台、倒地、死亡、乘车时不使用陀螺仪转向；恢复时清除滤波历史，避免累计跳转。采用小幅噪声死区和角速度平滑。

Godot 4.4.1 Android 已将陀螺仪读数转为屏幕方向的弧度/秒，本实现直接将屏幕 Y/X 轴角速度积分为水平/垂直瞄准，不重复旋转横屏坐标。自动化测试用合成输入验证轴向、模式、30/60/120 FPS 一致性、反转、噪声过滤、后台/菜单抑制、触屏叠加和设置保存；这不替代实际手持手机转动的手感测试。version code 为 3804，同签名覆盖安装。

本次 APK 在 AWS Device Farm LG Stylo 6 上通过原生启动冒烟检查；实体手机转动与陀螺仪手感尚未实测。单人/双人 AWS 联网和账号恢复回归通过。
