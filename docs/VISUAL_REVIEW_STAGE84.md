# Stage84：卡宾枪机匣截面与表面分区

本轮接续 stage83，落实 stage31 对第一人称形体/材质及同机位腰射、ADS 的要求。仅重建卡宾枪，保留已有手臂与其他武器修改；不重复 stage29 验证。整体状态 **continue**。

## 实际改动

- `tools/build_assets.py`：上机匣由12点改为16点截面，增加纵向过渡站点，收束侧壁并调整顶部肩线。导轨和瞄具锚点不变。
- 上下机匣侧面凹槽加圆角和深度，固定销缩小并贴合侧壁，减少突出的大颗粒零件。
- 降低机匣材质的大尺度色差、粗糙度扰动和凹凸强度，重新生成 `art/carbine.blend` 与 `client/assets/carbine.glb`。

## 截图审阅

固定角色位置 `(17, 0.05, 50)`、yaw `atan2(-18,16)`、pitch `-0.03`。1280×800，Godot 4.4.1 Forward+ Vulkan llvmpipe；ADS 使用游戏本身的变焦。源码与独立包各采集卡宾枪腰射、ADS、换弹25%/50%/75%共五帧。

- `artifacts/realism84-validation/receiver-before-after.png` 是 stage83/84 同机位腰射原图的相同区域2倍等比裁切。大块斑驳噪声减弱，机匣肩部过渡更平顺，固定销不再如此突出。不是整体画质大幅提升。
- 腰射中仍可辨认护木、机匣、握把和枪托，但机匣暗部偏平，枪身依然厚重，聚合物与金属区分不足。
- ADS 红点位于画面中央，机匣修改没有挡住瞄具开口；上机匣的对称宽肩仍明显。瞄准正确性另有自动测试，不能仅由截图证明。
- 三个换弹时刻中枪托、握把与握持手关系保持，未看到新增明显穿插。支撑手阶段性离枪属于既有动画。手套仍简化，袖子呈长管状，袖口与掌根缺乏真实布料和软组织过渡。本轮没有重塑手臂。
- 场景仍有重复仓库、均匀草簇、空旷地面和雾化山坡树列；人物、建筑、地形植被和光照的整体目标未完成。

原始截图与校验：`artifacts/realism84-validation/capture-status.json`；便于浏览的源码/包内 `*-aim-pairs.jpg` 和 `*-reload-poses.jpg` 均来自实际游戏截图。

## 验证与边界

构建、资源导入、PCK导出日志位于 `artifacts/realism84-validation/`。导入退出0，但仍记录 `servers/rendering/dummy/storage/texture_storage.h:107` 的 `Parameter "t" is null`，不能称为无错误导入。

源码与包内采集均退出0且 `WEAPON_REVIEW_CAPTURE_PASS frames=5`，共10帧；已人工审阅包内腰射/ADS及三个换弹时刻。源码/包内12项检查均退出0且PASS。功能结果保存在 `test-results.json`：源码与包内分别运行瞄准、换弹接触、近墙遮挡、视模规则、武器视觉规则和单机 smoke。近墙规则及射线/掩体检查不等于全地图碰撞验收；`remote_snapshot` 是进程内规则检查，不是真实联网。真实联网本轮未运行。

本地预览：`artifacts/realism84-preview/Linux/IronMeridian --path /tmp`，保留同目录 `IronMeridian.pck`。`build.json` 保存构建输入/产物SHA256，`verification.json` 索引验证。使用Godot可执行文件与PCK，标准Linux发布模板仍缺失。软件Vulkan截图不能证明硬件性能。

下一阶段应处理占屏面积较大的袖子轮廓、袖口与腕掌连接，在同机位腰射/ADS/换弹检查三把武器；随后继续重复建筑和地面布局，以及符合不读取密钥约束的真实联网验收。不得用持续添加机匣小细节替代整体画面改进。
