# Stage32：第一人称枪械与手臂

本轮按 stage31 独立反馈优先修改第一人称资源。本文件是开发过程中的截图审阅，不是独立审阅；整体画质目标尚未完成。

## 实际改动

- 卡宾枪后机匣收窄、下机匣和拉机柄减小，重新贴合侧板及销钉；厚实矩形瞄具改为薄八边框，增加分离的底座、调节件与固定细节，保留 SightAnchor/Muzzle。
- 手臂增加袖管轮廓与褶皱、袖口接缝、腕带、手背和指节皮革垫；手套边缘更圆。恢复可见的迷彩明度，腕带不再共用迷彩，材质添加细微法线变化。
- 保留五骨骼与 Hold/Reload/Throw/Heal 动画结构。截图工具增加仅拍卡宾枪腰射/ADS 的参数，供导出包复核。

## 同机位截图审阅

`artifacts/realism32-before/` 与 `artifacts/realism32-after/` 各 15 张实际 Forward+ 截图，覆盖三把武器各自腰射、ADS、换弹 25%/50%/75%。相同角色位置 `(17, 0.05, 50)`、yaw `atan2(-18,16)`、pitch `-0.03`；腰射和 ADS 保留各自实际 FOV，前后同姿态对比。

直接对照：`artifacts/realism32-comparison/carbine-hip-ads.png`。
姿态缩略图：`artifacts/realism32-comparison/all-poses-crops.png`。

实际观察：卡宾枪瞄具不再是一整块厚圆角盒，ADS 中框体更薄，底座与调节件可辨；袖口、迷彩、指节垫摆脱原先黑色管状外观。抽样姿态未见明显断腕，但不能据此保证全部动画没有穿插。

仍明显不足：卡宾枪枪托/缓冲管仍像直圆管，平行手指较僵硬，换弹时支撑手与弹匣接触不自然；另外两把枪后部仍有大块方盒。背景仓库重复、地面层次单一、远树轮廓简化。本轮尚不能认为已达到接近和平精英的整体观感。

## 验证和本地预览

以下日志命令均退出 0：

- `artifacts/realism32-aim_alignment.log`：108 个样本、三武器，ADS 过渡、后坐力、侧倾、射线通过。
- `artifacts/realism32-weapon_obstruction_rules.log`：旋转掩体、长短武器、蹲姿、重叠、低持枪、恢复及权威射击规则通过。
- `artifacts/realism32-weapon_visuals_rules.log`：本地/远端快照外观、挂点、瞄具对齐和网格约束通过；远端快照不是联网传输验证。
- `artifacts/realism32-viewmodel_rules.log`：骨骼、换弹时长、投掷、治疗、重置和死亡规则通过。headless 检查不能替代蒙皮截图。
- `artifacts/realism32-preview-smoke.log`：导出包在 `/tmp`、隔离用户数据运行，16 角色单机射击、换弹、治疗、伤害、胜利、掩体等烟测通过。
- `artifacts/realism32-after.log` / `realism32-preview-capture.log`：工作区 15 张、导出包 2 张截图完成，并实看包内腰射与 ADS。

`artifacts/realism32-import.log` 虽退出 0，但出现两条 dummy renderer `Parameter "t" is null`；不能称导入无错误。后续 Forward+ 截图和导出日志未出现该错误。软件 Vulkan llvmpipe 渲染，不作为实体 GPU 性能证明。

本地可运行文件：`artifacts/realism32-preview/Linux/IronMeridian`，同目录保留 `.pck`。运行说明、SHA256 清单位于 `artifacts/realism32-preview/README.md`、`verification.json`；截图在 `capture/weapon-0-hip.png` 和 `capture/weapon-0-ads.png`。包来自当前未提交工作区。

联网仍有此前记录的登录 HTTP 404 未解决，本轮未重复 stage29 验证，也未宣称联网通过。

下一阶段先改善枪托与握指/弹匣接触，并用相同机位完整换弹序列检查；随后处理其他武器大块结构及建筑/植被重复，单独恢复真实联网主流程验证。
