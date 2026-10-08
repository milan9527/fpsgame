# Stage45 实机审阅：卡宾枪后机匣与拉机柄

日期：2026-09-13。整体目标未完成，状态 continue。

本轮以实际 stage44 资产为起点，结合 stage29/30/31 独立审阅对第一人称积木形体的反馈，集中改善卡宾枪后端。上机匣从两个截面改为六个渐缩截面，使后肩向缓冲管收拢；双侧拉机柄增加后掠轮廓和防滑齿，后段导轨与侧加强条缩短以贴合机匣。重建 `art/carbine.blend` 与 `client/assets/carbine.glb`，生成器为 `tools/build_assets.py`。沿用 stage44 手套材质；本轮未重新制作手臂，也未改变握持锚点或相机。

## 实际画面

最终本地 PCK 在 Godot 4.4.1 Forward+、Vulkan llvmpipe 软件渲染下生成三武器共15张截图，捕获退出0。相机位置与朝向固定，腰射和 ADS 使用各自正常视野；与 stage44 同姿态截图比较。

- 原图：`artifacts/realism45-preview/capture/`。
- 前后腰射对照：`artifacts/realism45-validation/carbine-hip-comparison.png`。
- 前后 ADS 对照：`artifacts/realism45-validation/carbine-ads-comparison.png`。
- 三武器腰射/ADS总览：`artifacts/realism45-validation/aim-contact-sheet.png`。
- 三武器25%/50%/75%换弹总览：`artifacts/realism45-validation/reload-contact-sheet.png`。

已查看上述对照与总览，并单独查看卡宾枪腰射、ADS和换弹中点原图。腰射后端原来的平直方墙变成较清晰的收肩连接，拉机柄形体更容易辨认；ADS中的拉机柄更宽且位置更靠下，没有新增准星中心遮挡。所查看视角未见新增悬空零件，换弹枪体保持连接。这是局部形体改善，枪身仍有大面积暗色平面，不能据此称为写实枪械完成。

## 验证与范围

最终包从外部工作目录、独立用户数据运行，以下六项规则及单机烟测退出码均为0：

- `aim_alignment.log`：108样本，三武器瞄准、转换、后坐、侧倾和射线。
- `reload_contact_rules.log`：183掌心接触样本；不等于逐指贴合验证。
- `viewmodel_rules.log`：骨架、瞄具、换弹、投掷、治疗、死亡与复位。
- `weapon_finish_rules.log`：三模型22表面材质规则。
- `weapon_obstruction_rules.log`：贴墙遮挡、蹲姿、低持枪、弹药与恢复。
- `weapon_visuals_rules.log`：本地/远端快照、锚点、附件与包围范围。
- `smoke.log`：16角色离线战斗、换弹、治疗、伤害、胜利、射线及掩体。

日志位于 `artifacts/realism45-validation/`，汇总 `test-results.json`。`capture.log` 记录15帧通过；构建与导出退出0。导入退出0但仍有既有 dummy renderer 空纹理错误，见 `import.log`。远端快照不是实际联网：此前真实联网HTTP404未解决，本轮未做多人端到端测试，亦未重跑全图通道碰撞。软件渲染不验证实体GPU性能。

## 本地预览与后续

启动 `artifacts/realism45-preview/Linux/IronMeridian`，保留相邻PCK。同目录 README、build.json、verification.json 提供来源哈希与验证范围。此为引擎加PCK的本地预览，发行导出模板仍不可用。保留所有未提交修改，未推送或发布。

下一轮应扩大场景收益：实质改善仓库窗框/入口纵深和草丛地面过渡，补近景与移动截图。手部解剖、SR拇指间隙、枪身大平面、重复建筑植被、地形光照和人物仍待继续；真实联网诊断与主要通道碰撞验证仍为整体完成的必要条件。
