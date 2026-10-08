# Stage118 环境实机审阅（2026-09-14）

本轮完成一组建筑、树根地表和设施材质调整，并生成可运行本地包。整体目标仍为 continue：宽幅场景尚未摆脱重复仓库、平坦空地和孤立山峰，人物及连续第一人称动作也未完成验收。

## 实际改动与画面判断

- 仓库 (35,0,34) 新增带百叶、立柱和顶盖的屋脊通风楼，底座贴合屋面，具有实体碰撞。正常步行接近机位可以辨认新的建筑轮廓；这是封闭通风结构，没有新增室内天窗照明。入口近景保持中间通道，周围建筑体量重复仍明显。
- 树根增加不规则透明边缘的落叶土壤层，改善树干直接插进草地的接缝。森林机位确实可见土色过渡，圆形色斑仍偏明显，树干低模与草丛重复没有解决。
- 供水罐增加竖向流挂、底部污迹及沿圆柱排列的 WATER 04 字符。标字尺度和贴面感优于原悬浮招牌，但字边有破碎/可能的深度伪影，不能视为标字问题完全修复。
- 维修棚金属增加接缝抗锯齿、降低涂装亮度并调整背面遮蔽。同机位对照收益有限，内侧仍偏亮，后续需检查实际双面法线和受光，而非继续只改色值。

已实际查看仓库接近、入口、森林、宽幅地形、水罐及维修棚画面。宽幅地形几乎没有显著改善，不以截图数量推断整体画质。

## 同机位证据

目录：`artifacts/realism118-validation/`。`before/` 来自 stage117 包，`after/` 来自最终 stage118 包。六个完整截图批次退出0，见 `capture-results.json`。九个机位的所有记录字段相同，见 `camera-comparison.json`；其中 water-camera-poses.json 是单个对象，其余为数组。

关键机位（角色位置 → 视线目标，米；眼高偏移1.6米）：

| 机位 | 角色位置 | 目标 |
| --- | --- | --- |
| 仓库接近 | (17,0.05,46) | (31,2.2,34) |
| 入口近景 | (35,0.05,44) | (35,1.9,34) |
| 宽幅地形 | (17,0.05,50) | (-46,12,-90) |
| 森林 | (-111.1871,0.05,-72.4752) | (-111.1871,4,-82.4752) |
| 水罐 | (49,0.05,40) | (46,2.1,31) |
| 维修棚 | (15.5,0.05,40) | (15.5,2.6,29.5) |

完整位置、yaw/pitch弧度及1280×800视口记录在 before/after 下的 environment-camera-poses.json、water-camera-poses.json、service-camera-poses.json。截图使用实际单机场景与游戏摄像机，固定场景处理以便比较；通行另用实际角色移动测试。渲染为 Forward+ / llvmpipe，不能代表硬件GPU帧率。

对照文件：depot-approach-before-after.jpg、depot-entrance-close-before-after.jpg、terrain-wide-before-after.jpg、forest-eye-level-before-after.jpg、water-service-before-after.jpg、service-shelter-before-after.jpg。原始PNG保留在before/after。

## 功能、失败记录与预览

最终包13项检查通过，见 functional-results.json 和逐项日志：单机smoke、瞄准、武器遮挡规则、建筑入口/屋顶碰撞、院落净空/掩体、仓库/院落/维修棚/棚架/供水设施角色通行、网络状态规则。after/ 下的 traversal.json、depot-traversal.json、service-yard-traversal.json、shelter-frame-traversal.json、water-service-traversal.json 保留移动结果。水罐测试包含双向绕行及罐体、顶盖阻挡。

首次屋顶测试被新增通风楼拦住中央射线，原坡面断言失败；将取样移至通风楼外的原坡面，保留坡度误差要求，并新增三个顶盖射线检查。随后一次外部测试脚本类型推断错误已修复，单独重跑退出0。initial/ 保留失败日志和修正前结果，最终汇总明确标记 roof_collision 为重跑结果，没有覆盖失败历史。游戏包在最终截图和回归前已导出，之后只修正外部测试脚本。

本地预览：`artifacts/realism118-preview/Linux/IronMeridian`，同目录PCK。仓库根目录启动：

```bash
./artifacts/realism118-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus
```

选择单机；WASD移动、鼠标转向、左键开火、右键瞄准。README.md记录地点，build.json记录包和相关源文件SHA256；import.log/export.log记录构建。未推送或发布，保留所有未提交修改。

真实联网缺少可用授权认证fixture，本轮未读取密钥、未宣称联网通过；本地网络状态规则不能替代真实联机验收。

下一阶段优先改变可步行范围内建筑群体量/用途和院落布局，并做连续地面、路肩与植被过渡，在固定宽幅机位确认可见收益；随后修复棚顶受光、罐字边缘和树根圆斑。保留第三人称护具/蹲姿与第一人称连续瞄准、射击、换弹审阅，以及具备授权条件后的真实联网验证。
