# Stage92：支撑手握持轮廓与三武器复查

本轮在 stage91 实际工作区基础上修改支撑手，而非重跑 stage29。总体目标继续，未达到写实 FPS 的完整验收标准。

## 改动

`tools/build_viewmodel.py` 将支撑手四指的整体伸展系数改为 0.94/1.00/0.91/0.73，并从指根开始逐渐展开，随之移动指节保护与缝线。此前只在末端缩短，容易产生四条平行管子的外观。拇指第二、三段外展并减小根部截面，保留运行时掌心接触锚点。重新生成 `art/first_person.blend` 和 `client/assets/first_person.glb`；沿用此前手套织物、皮革、法线材质，本轮没有新的材质重制。

## 复现与证据

使用未改动的 `tests/weapon_review_capture.gd`：位置 `(17,0.05,50)`、yaw `atan2(-18,16)`、pitch `-0.03`。三武器使用相同世界相机位置/角度；ADS 按游戏逻辑改变枪姿和视场。Compatibility 包含每武器腰射、ADS 和三个换弹时点，Forward+ 补充每武器腰射/ADS。截图为真实引擎输出，无图像生成或场景合成。

所有日志与截图在 `artifacts/realism92-validation/`。两种渲染器均为 llvmpipe 软件渲染，不作为显卡性能依据。Compatibility 的植被明显偏黑，不能与 stage91 Forward+ 混用作画质提升证据。最初连接旧显示会话失败，原始日志单独保留为 `display-attempt-failed.log`；随后使用独立 Xvfb。导入仍出现 `Parameter "t" is null`，需保留为未解决问题。

最终保存 42 张 PNG：源项目与包内 Compatibility 各 15 张，Forward+ 各 6 张，四次采集均退出 0 且输出对应帧数 PASS。`screenshot-index.json` 保存截图哈希，`verification.json` 汇总验证；四张总览为 `source-compatibility-contact.jpg`、`packaged-compatibility-contact.jpg`、`source-forward-pairs-contact.jpg`、`packaged-forward-pairs-contact.jpg`，均已实图审阅。

预览为 `artifacts/realism92-preview/Linux/IronMeridian` 与同名 PCK，启动方法见该预览目录 README，构建哈希见 build.json。

## 验证与画面判断

源项目和预览包各 10 项规则/冒烟检查均以退出码 0 通过，明细为 `artifacts/realism92-validation/test-results.json`。覆盖三武器 108 个瞄准采样、183 个换弹接触采样、枪口遮挡、模型与材质规则、16 人单机流程、入口与屋顶碰撞、网络状态生命周期。网络状态规则不代表实际双客户端联网，本轮没有新完成真实多人会话验证。Blender、导入、PCK 导出进程均退出 0；导入退出 0 不消除上述 null texture 错误。

实机审阅：Forward+ 步枪腰射可辨支撑手指长与拇指轮廓；三武器 ADS 的红点、机械照门、瞄准镜中心可见，手部没有挡住中央瞄准区。Compatibility 三武器五姿态总览中，换弹中段支撑手随弹匣离开枪体，回收阶段恢复握持，没有发现整手漂离或明显枪体穿掌；静态采样不能替代完整动画连续审阅。霰弹枪腰射仍突出手指如软管、手掌偏厚的问题，袖管的粗圆轮廓也没有解决。材质分层虽已有，但仍缺少可信的皮革受力、掌面褶皱和织物尺度。此轮是抓握轮廓调整，不构成第一人称整体写实验收通过。

远景仓库体块与排列重复，植被分布和地面仍偏程序化；人物、建筑、地形光照的总目标继续。下一轮优先重新塑造掌面/虎口与袖口截面，并校准手套材质尺度，以三武器同机位 Forward+ 腰射、ADS 和换弹近景复核；另需修复兼容模式黑植被与 null texture，补实际联网会话证据。
