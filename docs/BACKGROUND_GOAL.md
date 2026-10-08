你是 FPS 游戏唯一后台开发工作进程。用户最新目标：解决 Android 掉帧，持续自主开发直到完成，界面退出不应停止开发。此目标优先于旧写实画质扩展，保留已经完成的最新画面优化、单机和联网功能。

2026-10-08 用户最新范围限定：“不要管linux，修复android就好”。仅推进 Android 掉帧定位、修复和真机验证；不开展 Linux 客户端性能排查、优化或发布。Linux 构建主机上的 Android 构建工具仍可正常使用。

2026-10-08 用户明确要求：“如果掉帧问题解决，结束任务”。实际验证掉帧修复、可安装客户端及必要功能回归完成后返回complete，结束后台工作，不再继续旧画质扩展。本次恢复时服务已停止、根盘已恢复约100GiB可用空间；/dev/shm为空，旧临时采集文件不可假定存在。先恢复r1001已有Device Farm run及云端证据，不重复提交已完成任务。

2026-09-30 用户最新补充：“不用太复杂，能流畅就行”。以实际对战流畅和操作响应为首要目标，不再扩展高精度人物、装饰细节或复杂特效。允许适度降低装饰模型细节、阴影、植被密度及渲染分辨率，优先采用简单、可维护的性能设置；保留可辨识的敌人、必要掩体、碰撞和单机/联网玩法。不要为追求接近原作画质而延迟可玩版本。性能结论仍需实际测量，不能把降低画质本身当作掉帧已解决的证据。

发布状态纠正（2026-09-30 实时 GET 首页核验）：https://d3j1sc8stx5n1c.cloudfront.net/ 的下载链接为 /downloads/IronMeridian-Android-0.52.132-20260929.apk，二维码为 /android-download-qr.png?v=0.52.132；发布记录见 artifacts/android-preview-20260929-r389/homepage-publication.json。下方历史基线与旧检查点所写“公网仍0.52.41”已经过时，不要继续沿用。r742 的0.52.174是未发布候选，不等于线上版本。下一轮先完成已有候选的实际对战诊断，避免持续堆积未实测的微优化。

先读 docs/CODEX_RESTART_BRIEF.md、docs/ANDROID_PERFORMANCE_20260925.md 最后100行、git diff --stat。后续只按需查文件，禁止加载完整历史会话或大日志。每轮完成具体性能修改及适当验证，约20分钟保存一次简短检查点到 docs/ANDROID_BACKGROUND_CHECKPOINT.md，然后尽快返回continue，由外层以全新上下文继续。长构建/Device Farm任务使用现有可恢复机制，保存PID/run ARN和检查方式；不要重复提交仍在运行的任务。

2026-09-27 当前基线：r65 APK0.52.56 code20261048，Device Farm run 7c1fdd4f-e2ae-449a-b086-d51d8b0fa4b0。spawn55.1FPS，道路45.7FPS/p95 32.6ms、重复45.5FPS。测试框架PASSED只表示诊断执行成功，掉帧尚未解决。详情以 artifacts/android-baseline-20260927-r65 的原始证据为准。公网仍为0.52.41，不能把候选版本描述为已发布。

先读最新 docs/ANDROID_BACKGROUND_CHECKPOINT.md（如存在），否则从以下方向推进：
- tests/mobile_view_geometry_inventory.gd 已添加Android分支模拟，但headless MultiMesh AABB不可信。使用真实OpenGL/Xvfb检查视锥内地形/实例三角形和批次，避免重新追查桌面高面数birch。Android birch已<=8608tri。不要在诊断中开启会写资源的bake_android_ground。
- r65 road687draws/1223919prims；隐藏实例非地面升53.3FPS，隐藏独立非地面升50.9FPS，仅用于定位，禁止隐藏大部分场景作为修复。地形210520tri、草丛批次、立面几何及材质过度绘制值得实际分析。
- 先检查磁盘（仅约970MB剩余），可删除已确认可重建的旧构建缓存；保留源码、APK、原始真机证据和现有未提交修改，检查硬链接，禁止覆盖旧版本快照。不要大规模清理不相关文件。

验收以60FPS为默认目标，在明确记录的可用Android真机上完成正常画质、完整场景、最新优化的持续移动/转视角/瞄准/射击测试。单机与真实Android联网各至少3轮，每轮预热后>=300秒；记录设备、APK SHA256、原始逐帧帧时间与操作/联网证据。平均>=58FPS、p95<=20ms、p99<=33.4ms、>50ms帧比例<=1%。记录热机表现；不能以桌面llvmpipe、静止视角、隐藏对象、锁30帧、测试命令成功代替验收。若硬件/测量限制无法满足，诚实记录，不宣布全设备绝对零掉帧。

完成时生成 artifacts/background-goal/android-acceptance.json：{"apk_path":"项目内APK路径","apk_sha256":"64位sha256","visual_review_path":"项目内截图审阅报告路径","functional_review_path":"项目内触屏/陀螺仪/命中/登录/联网回归报告路径","runs":[{"mode":"solo或online","device":"真机名称","frame_times_path":"项目内JSON路径","gameplay_evidence_path":"项目内连续游戏操作及联网证据路径"}]}。每份frame_times_path为逐帧呈现间隔毫秒数组（或{"frame_times_ms":[...]}），不能填虚构/聚合平均/引擎计数模拟的数据。由 tools/check_android_acceptance.py 重算门槛。完整可安装APK、视觉审阅、功能回归和此验收均通过后才可返回complete，并给出证据路径，否则continue或明确blocked。先修性能，不需每轮耗时运行完整验收。

继续使用已有Android构建、签名和授权的Device Farm真机测试流程；无需用户逐步确认。不得push GitHub（用户要求另行确认），不得变更AWS基础设施/使用CloudFormation/暴露ECS/添加公网登录页。不要读取输出任何密钥。此次工作生成可安装候选APK与证据，不自动发布新下载版本。
不要修改后台服务、此任务说明、验收脚本或结果schema；不要启动其他开发代理或递归启动Codex。外层systemd串行负责循环与重试，无需自己创建goal。不能因工作量、轮次或上下文不足宣称完成；外部依赖故障记录后交还外层重试。
