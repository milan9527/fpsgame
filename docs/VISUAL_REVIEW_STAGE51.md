# Stage51 — AR 下机匣、镜座与手套分片（2026-09-13）

本轮响应 stage31 第一人称武器与手臂优先反馈，在 stage50 工作区上继续制作；未重复 stage29 验证。整体写实目标未完成。

## 实际改动

- `tools/build_assets.py`：以带斜面轮廓、侧面凹槽和销钉的下机匣替换盒体；镜座改为带横向减重开口的阶梯桥架，增加分离夹块、垫片和横栓。镜座及镜框采用喷砂铝材质，金属度0.72、粗糙度0.43。
- `tools/build_viewmodel.py`：双手原有三条长护垫拆成六块短皮革护垫，保留骨架、动画和握持定位。
- 已重建两份 Blender 源文件及 GLB，导入并打包当前 Linux 预览。没有修改服务或推送发布，保留原有未提交工作。

## 实机同机位审阅

旧 stage50 PCK 与新 stage51 PCK 均使用 `tests/weapon_review_capture.gd`：相同位置、朝向和机器人冻结状态，实拍腰射、ADS、换弹25%/50%/75%五个姿态。ADS采用游戏自身FOV。原图为1280×800，Godot4.4.1 Forward+、Xvfb Vulkan llvmpipe；不是硬件性能测试。

原图：`artifacts/realism51-preview/before/`、`after/`。
并排对照：`artifacts/realism51-validation/hip-before-after.jpg`、`ads-before-after.jpg`、`reload-quarter-before-after.jpg`、`reload-half-before-after.jpg`、`reload-three-quarter-before-after.jpg`；另有 `hip-detail-before-after.png`。

逐姿态审阅结果：

- 腰射：镜座侧轮廓和紧固件更明确，减少了单块支架观感。下机匣的变化受持枪角度限制，画面收益有限。
- ADS：红点仍居中，瞄具窗口未新增遮挡。镜座正后方仍显宽厚；不能从这个角度声称减重开口清晰可见。
- 换弹25%和50%：能看见更薄的桥架及轮廓转折。手仍处于合理握持区域；三张静态姿态不能替代连续动作中的逐指穿插验证。
- 换弹75%：支架侧形体更清楚，枪托仍占较大画幅；袖管仍有明显圆柱感。手套分片已改变资产，但在这些视角下被遮挡较多，视觉改善不显著。

仍有明显不足：机匣大面积暗色材质偏均匀，袖口与腕部缺少自然布料体积，院落重复空旷，草簇分布和远山树木仍显程序化。本轮只是局部资产改进，不能作为整体目标完成证据。

## 验证与运行

当前打包 PCK 通过6项检查，日志在 `artifacts/realism51-validation/`：

- `aim_alignment.log`：3武器108样本，过渡、后坐、侧倾及射线通过。
- `reload_contact_rules.log`：3武器183接触样本通过。
- `viewmodel_rules.log`、`weapon_visuals_rules.log`：骨架、动画、锚点、远端快照等规则通过；无头规则不替代图像审阅。
- `weapon_obstruction_rules.log`：抵墙、蹲姿、低持枪及恢复检查通过。
- `solo-smoke.log`：16角色、装填、治疗、伤害、胜利、射线和掩体检查通过。

两次截图日志均有 `WEAPON_REVIEW_CAPTURE_PASS frames=5`。最初失效 DISPLAY 的失败日志保留，随后使用临时 Xvfb 成功拍摄。`import.log` 保留两条既有无头 `texture_2d_get` 空纹理错误；当前图形截图可见材质，未将导入描述成零错误。

真实联网仍阻塞：`network-probe.json` 记录 localhost:8000 的 health、protocol、openapi.json 均HTTP404，服务标识为SimpleHTTP文件服务器。未修改服务，未执行真实双客户端验证；远端快照规则通过不代表联网通过。本轮也未重新进行全地图行走碰撞检查。

本地启动：`./artifacts/realism51-preview/Linux/IronMeridian --path /tmp`，保留相邻PCK并选择单机。README提供烟测命令；`build.json` 记录资产和包SHA256，`verification.json` 记录6项测试、10张原图和限制。

下一阶段优先改善腕部/袖口过渡、布料褶皱和机匣表面层次，用同机位腰射、ADS及换弹图判断画面收益；随后继续 stage50 未完成的坡道道路泥草过渡、院落差异化，并在API可用后完成真实联网验证。
