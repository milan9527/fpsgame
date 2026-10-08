# Stage33：霰弹枪、精确射手步枪形体与同机位瞄准审阅

本轮是开发过程中的截图自审，整体目标未完成。保留 stage32 的卡宾枪与手臂改动，本轮没有把既有袖口、迷彩改进计为新工作。

## 实际改动

- 霰弹枪和精确射手步枪的矩形上下机匣改为收窄的多段侧轮廓，增加抛壳窗凹槽、内侧枪栓、销钉与导轨细节。枪托及握把尚未重做。
- 霰弹枪厚鬼环改为薄环，脚座与支柱分开，降低 ADS 遮挡。
- 精确射手步枪直筒瞄具改为薄壁渐扩镜筒，减小固定座；初次截图发现旋钮侵入开口，随后把旋钮移至壳体外侧。包内截图又发现顶部连接处有空隙，补充高低与风偏调节旋钮连接颈后重新生成、导入和导出。仍使用贯通视野和游戏原有缩放，没有实现独立镜内光学渲染。
- 截图工具增加 `--review-aim-pairs`，可以拍摄三武器共六张腰射/ADS；默认仍保留 15 张姿态。最终包使用默认完整采样。

## 截图来源与验证范围

角色固定位置 `(17, 0.05, 50)`、yaw `atan2(-18,16)`、pitch `-0.03`，沿用 stage32 机位。各模式保留实际 FOV；截图冻结游戏逻辑，换弹采用 25%/50%/75% 三个进度采样，不等于连续动画全程无穿插证明。

`artifacts/realism33-before-turret-fix/` 是第一次工作区 15 张实图，记录旋钮修正前结果；`artifacts/realism33-capture.log` 对应这批图。最终资源以 `artifacts/realism33-preview/capture/` 的导出包实图为准。运行目录为 `/tmp`，隔离 XDG 用户数据，外部截图脚本通过 `res://` 加载包内游戏资源，没有设置工作区 `--path`。

`artifacts/realism33-before-neck-fix/` 保留补连接颈前的包内 15 张图及日志，便于复核截图发现与修正过程。

## 验证

修正旋钮后重新执行，以下命令退出 0：

- `artifacts/realism33-aim_alignment.log`：108 样本、3 武器、ADS 过渡、后坐力、侧倾、射线通过。
- `artifacts/realism33-weapon_visuals_rules.log`：本地与远端快照、挂点、瞄具对齐、缩放、骨骼挂接、网格范围通过；快照测试不等于真实联网。
- `artifacts/realism33-weapon_obstruction_rules.log`：权威射击与弹药、旋转掩体、长短武器、蹲姿、重叠、低持枪、恢复通过。
- `artifacts/realism33-preview-smoke.log`：最终导出包单机 16 角色，换弹、治疗、伤害、胜利、射线、掩体、射速、骨骼通过。

`realism33-build.log` 与 `realism33-export.log` 退出 0。最终 `realism33-import.log` 退出 0 但仍有一条 dummy renderer `Parameter "t" is null`，不能称无错误导入。Forward+ 使用 Vulkan llvmpipe 软件渲染，不能作为实体 GPU 性能证明。

本地运行：`./artifacts/realism33-preview/Linux/IronMeridian`，保持同目录 `.pck`。这是当前未提交工作区导出；没有上传或部署。运行说明与 SHA256 见预览目录 README 与 verification.json。

联网此前登录 HTTP 404 尚未解决，本轮没有重做 stage29 或宣称真实联网通过。后续应改善枪托、握指与换弹弹匣接触，再处理建筑/植被重复，并恢复真实联网主流程验证。

## 最终包实图自审结论

最终 `realism33-preview-capture.log` 返回 `WEAPON_REVIEW_CAPTURE_PASS frames=15`，进程退出 0。实际查看三张 `realism33-comparison/weapon-{0,1,2}-hip-ads.png` 对照、`final-reload-crops.png` 九格换弹图及最终 SR ADS 原图。

- SG 腰射机匣后部由方盒变为收窄斜面，ADS 环和基座明显减薄，准星可见；但后端仍是大面积空白平面，不能称写实枪械已完成。
- SR 镜筒开口扩大，旋钮位于外侧且连接颈无可见悬空；过薄的镜圈与缺少镜片、分划线让它仍像空金属环。下一轮应兼顾眼距、镜片与镜筒厚度，不能仅以开口更大作为质量指标。
- 卡宾枪与手臂沿用 stage32；迷彩、袖口细节保留，但枪托直管感、并排球状指节仍明显。三把武器换弹半程左手悬置，缺乏清楚的取弹/送弹接触，采样未证明动画全程无穿插。
- 地面重复草簇、大片裸土和建筑墙面材质仍显程序化，远景树片单薄。本轮未改善场景或人物，不以武器局部改善宣称整体完成。
