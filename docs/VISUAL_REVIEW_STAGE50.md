# Stage50 — 仓库入口纵深与雨棚（2026-09-13）

以 stage49 最新检查点为基础，承接其建筑入口优先项；stage31 要求的第一人称改造已在后续阶段推进，本轮补拍当前 AR 腰射/ADS 回归，不将其算作新武器改模。

## 实质变更

`tools/build_facades.py` 三种立面加入混凝土门洞侧壁、内收钢导轨及暗缝、倒角卷帘机罩、端盖、带滴水边与接缝的外挑雨棚、两侧斜撑；重建三份 Blender/GLB。三种资产三角形分别 17440/10744/17440。`world.gd` 为32处雨棚加入独立静态碰撞，避免将头顶构件加入地面障碍占地。既有坡道及院落保留。

## 实机截图审阅

Godot4.4.1，1280×800，Forward+ Vulkan / llvmpipe，运行导出的 PCK；截图包含真实游戏 HUD。新增 `tests/entrance_review_capture.gd` 对旧 stage49 包和当前包使用相同三组固定相机。原图：

- 旧包：`artifacts/realism50-validation/before/entrance-{oblique,close,inside}.png`
- 当前：`artifacts/realism50-preview/capture/entrance-{oblique,close,inside}.png`
- 三组对照：`artifacts/realism50-validation/entrance-{oblique,close,inside}-before-after.jpg`
- 当前同位置朝向 AR 腰射与ADS：`artifacts/realism50-preview/weapon-capture/weapon-0-{hip,ads}.png`；ADS按游戏设定收窄FOV，并非同FOV图。

逐张检查当前5张截图：斜向入口从平贴黑框变为可辨侧壁、卷帘机罩和外挑遮雨构件；近景门洞边缘具有厚度，室内向外仍保持通透。腰射袖口/枪体未发现新增遮挡，ADS红点中心可见。静态截图不能证明全程动画无穿插。

仍明显不足：门槛坡道光滑发亮，与混凝土不协调；道路纹理高频噪声明显；重复仓库与空旷院落依旧；AR机匣/镜座偏方正、表面层次少；人物、植被、远景山体和光照仍需持续提升。新增雨棚也偏干净，未达到商业级写实。

## 验证与限制

`artifacts/realism50-validation/test-results.json`：新增雨棚96条向上射线/32处命中；仓库角色双向穿越；屋顶碰撞；三武器108瞄准样本；武器抵墙规则；第一人称规则；正确入口单机烟测均通过。单机16角色、换弹、治疗、伤害、胜利、射线、掩体与射速通过。并非全图碰撞覆盖。

保留失败尝试：首次截图缺少DISPLAY，改用Xvfb后成功；首次烟测错误指向不存在的 `tests/smoke.gd`，改用主场景 `-- --smoke` 后退出0，详见 `offline-smoke-retry.log`。无头导入仍出现既有空纹理错误，不能声称无警告；导出、最终包截图均成功。三入口截图与两武器截图分别在 `after-capture.log`、`weapon-capture.log` 记录成功标记。

联网只做只读诊断：127.0.0.1:8000 的 /health、/protocol、/openapi.json 全部404，响应为 SimpleHTTP/0.6 Python/3.9.25；监听进程是python3文件服务器，不是项目预期API。见 `network-probe.json`。未改服务、认证或运行双客户端；真实多人仍未验证。需后续在允许范围内确定正确API入口或隔离测试环境。

本地预览：`artifacts/realism50-preview/Linux/IronMeridian` 与相邻 `IronMeridian.pck`，启动说明及哈希见该目录上级 README.md/build.json/verification.json。没有推送或发布；所有既有未提交修改保留。

状态 continue。下一阶段优先修复坡道/道路材质与泥草过渡，增加院落构图变化，并以同机位图与通行测试复核；继续人物、武器手臂与真实联网验证。
