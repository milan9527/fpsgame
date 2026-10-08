# Stage74：掌部曲面与袖口收束（continue）

## 改动与实际结果

修改 `tools/build_viewmodel.py`，重建 `art/first_person.blend` 和 `client/assets/first_person.glb`。袖口径向收束并压低椭圆厚度；掌部使用圆形截面代替超椭圆，支撑手增加内收曲率，掌骨起伏由 1.3 mm 调整至 2.2 mm。保留指端接触锚点、骨骼和动作。本轮没有重做枪械或手指，不把这些列为成果。

实际检查独立包的五个姿态，并与 stage73 同机位截图并排审阅：

- `artifacts/realism74-validation/comparison-all-poses.jpg`：左 stage73，右 stage74；腰射、ADS、三个换弹时点。
- `artifacts/realism74-validation/comparison-hand-crop.png`：换弹中点手部 2 倍裁剪对照，不是原生高分辨率渲染。
- 原图在 `artifacts/realism74-validation/packaged-forward/weapon-0-*.png`。

正常视距下变化很弱，袖口缩窄可见；换弹中点掌部仍呈硬片状，未达到自然手部轮廓。ADS 红点保持可见，枪体和手臂没有新增明显遮挡，但机匣仍方正、材质与袖管仍欠真实。棕色仓库重复、草丛规律和地表过渡问题继续存在。本阶段不是第一人称画质验收通过，更不是整体目标完成。

## 验证

`artifacts/realism74-validation/stage-results.json` 汇总原始日志。Blender 构建、Godot 导入、导出和截图进程退出均为 0。导入仍报告 `ERROR: Parameter "t" is null.`，保留在 `import.log`，不宣称无错误。

源码和独立包各通过七项检查，共 14 项：手套材质/UV、108 个瞄准样本、183 个换弹接触样本、武器阻挡、视图模型骨骼/动作、武器外观快照、16 演员单机烟测。独立包使用 `/tmp` 为工作路径，避免误加载源项目。包内五张截图由 Forward+、Vulkan llvmpipe 软件设备生成，`capture.log` 为 PASS，退出 0。

快照规则测试不能证明真实联网可用。当前真实联网烟测脚本依赖认证服务及凭据，本轮未运行、未读取密钥；也未验证实体 GPU 或完整人工连续移动碰撞。截图固定姿态不能代替连续动作流畅度审阅。

## 当前预览及下一步

运行 `./artifacts/realism74-preview/Linux/IronMeridian --path /tmp`。同目录有 PCK、README、build.json 哈希和 verification.json。

下一阶段不要继续只微调掌部半径：应检查最终导出的掌部与拇指根连接、连续皮革区域及支撑手指根排布，重做造成硬片轮廓的结构；用正常视距换弹中点作形体验收，同时保持同相机腰射/ADS。之后仍需推进人物、建筑差异、地表植被和光照，并补齐真实联网及连续移动碰撞验证。
