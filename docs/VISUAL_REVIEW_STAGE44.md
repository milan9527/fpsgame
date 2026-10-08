# Stage44：第一人称手套表面与指节形体

2026-09-13。本轮完成局部开发与验证，整体写实目标仍未完成。保留工作区已有修改，未推送或发布。

## 实际修改

- `tools/build_viewmodel.py` 为手套织物和皮革护片分别生成内嵌256×256切线空间法线贴图，保持非金属材质。
- 弯曲手指增加三道浅关节压褶和圆柱UV，手背单块椭圆护片拆为三片窄护片；保留既有骨骼和握持锚点。
- 验证发现袖口、球体和手指的UV层名称不同，合并网格后手指首UV通道为空；统一为 `UVMap` 后重建 `art/first_person.blend`、`client/assets/first_person.glb`，新增表面规则测试验证导入后的有效UV三角形覆盖率。初版失败后已修正，最终测试通过。

## 实机截图审阅

最终本地预览通过 Godot 4.4.1 Forward+ / Vulkan llvmpipe（LLVM15）生成15张1280×800原图。三把武器均使用位置 `(17, .05, 50)`、偏航 `atan2(-18,16)`、俯仰 `-.03`，分别拍摄腰射、ADS及换弹25%/50%/75%；ADS保留各武器自身缩放。

- 原图：`artifacts/realism44-preview/capture/`
- 六张腰射/ADS总览：`artifacts/realism44-validation/aim-contact-sheet.png`
- 九张换弹总览：`artifacts/realism44-validation/reload-contact-sheet.png`
- Stage43/44卡宾枪手部局部对照：`artifacts/realism44-validation/glove-comparison.png`

已查看上述总览、对照以及卡宾枪换弹中点和霰弹枪腰射原图。对照中手套织物纹理更清晰；正常视距下压褶与护片分区变化较小，不能称为手部写实问题已解决。三把武器腰射与ADS未见新增手部中心遮挡，卡宾枪红点、霰弹枪机械瞄具及精确步枪镜内目标可见。九个换弹时点保持既有动作轮廓；掌心接触测试通过不能证明逐指接触正确，SR拇指间隙仍待专门修正。

枪体大平面与部分手指仍显简化；仓库轮廓、白色封窗、草丛分布重复，地面和建筑缺少足够层次。此轮为局部材质/形体改进，没有达到整体画质目标。

## 最终包验证

七项规则及单机烟测均从临时外部工作目录、全新 `XDG_DATA_HOME` 运行最终引擎/PCK，退出码均为0。日志位于 `artifacts/realism44-validation/`：

| 日志 | 结果 |
| --- | --- |
| glove_surface_rules.log | 两种材质法线、非金属属性、有效UV覆盖通过；27072个有效UV三角形 |
| aim_alignment.log | 三武器108个瞄准样本，过渡/后坐力/侧倾/射线通过 |
| reload_contact_rules.log | 三武器183个掌心接触样本，释放/恢复通过 |
| viewmodel_rules.log | 骨架、瞄具、换弹时长、投掷、治疗、重置/死亡通过 |
| weapon_finish_rules.log | 三模型22个表面，材质覆盖及实例隔离通过 |
| weapon_obstruction_rules.log | 枪口遮挡、旋转、蹲姿、重叠、收枪与恢复通过 |
| weapon_visuals_rules.log | 本地/远端快照、锚点、瞄具、骨骼绑定、网格边界通过 |
| packaged-smoke.log | 16名角色，换弹、治疗、伤害、胜利、射线、掩体、射速通过 |

`capture-final.log` 为 `WEAPON_REVIEW_CAPTURE_PASS frames=15`，捕获退出0。Blender生成、导入、导出日志同时保留；导入退出0但记录既有 dummy renderer `Parameter "t" is null` 错误，不能称为全流程无错误。

## 本地预览与边界

运行 `artifacts/realism44-preview/Linux/IronMeridian`，保留相邻PCK。同目录 `README.txt`、`build.json`、`verification.json` 记录运行方式、代码/资产/包哈希、测试与截图索引。当前为引擎加PCK预览，release模板仍不可用。软件Vulkan截图不代表实体GPU性能。

本轮未做真实多人端到端测试，此前HTTP404尚未解决；远端快照测试不等同联网通过。本轮没有重新巡检全图碰撞，也没有重做Stage29验证。

下一阶段优先提升建筑入口/窗框纵深、草丛分布和地面过渡，补近景与移动截图；继续修复逐武器手指接触、诊断真实联网并验证主要通道碰撞。
