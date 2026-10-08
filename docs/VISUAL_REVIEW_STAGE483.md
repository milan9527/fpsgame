# Stage483 当前预览审阅

本阶段修复道路北侧 z26 横穿口被挡土石阻挡的问题。石墙北端逐层退让形成阶梯收口，保留其余石块的真实网格碰撞及随机序列。未改变测试路线或降低通过条件。整体画质目标未完成。

## 当前包与功能

- 本地启动：`artifacts/realism483-preview/Linux/launch.sh`。
- 来源与散列：`artifacts/realism483-preview/build-manifest.json`；PCK SHA256 `44a12fbd0ff21f1c41e793926a46a15991e90c5053d155ad0b6232503c0222de`。
- 当前包道路 24/24 路线通过，包括此前失败的 z26 右侧双向横穿：`artifacts/realism483-validation/road-traversal/graded-road-traversal.json`。
- 维修棚 7 路线及碰撞检查通过：`artifacts/realism483-validation/repair-traversal/repair-shelter-traversal.json`。
- 三枪开放命中/墙体阻挡 6 案例通过：`artifacts/realism483-validation/aim/aim-damage.json`。
- 当前包 `offline-smoke.log` 记录 OFFLINE_SMOKE_PASS，包含 16 角色、换弹、治疗、伤害、胜利、射线、遮挡、射速和骨架检查。
- 主要联网流程本轮未验证；上述单机断言不能证明联网行为。未读取认证信息，未更改服务或发布。

## 环境与视觉边界

新增同机位 `drainage-north-crossing`：相机 `(5.5,1.65,23)`，目标 `(10,0.5,28)`，yaw `-2.40877755180329`、pitch `-0.169320764409494`，1280×800。旧 stage482 冻结包与当前包使用相同捕获脚本。`terminal-comparison/camera-comparison.json` 验证相机数据一致。

已实际查看端头前后原图和拼图：石墙收口变化被前景树干与灌木部分遮挡，视觉收益有限，不能宣称显著画质提升。通行修复成立与视觉目标达成是两个独立结论。入口近景入口无遮挡，但地面仍有硬材质分区；树冠形状重复、远山光滑、整体材质与光照尚不足以达到目标。

## 人物审阅范围与后续

本轮人物资产未修改。已逐图审阅 `arms-four/` 的 default-spawn、ads、reload-middle、reload-complete 全四姿势。前臂仍显细长，肘部体积鼓起，袖口收束突兀；ADS 遮挡多数手臂，不能据此认定肩肘正常。换弹结束弹量恢复，左手回到护木附近，但单帧不能证明插匣与回握轨迹自然。

四姿势捕获 JSON 为 passed=true，日志有 `SLEEVE_POSE_REVIEW_PASS reload_refilled=true`；外层执行却返回 143，`process-result.json` 未收尾，终止原因不明。保留原始记录，不能将此次运行记为无异常退出。汇总明确区分捕获断言与执行器状态。

已逐图审阅 `other-third/` 的 SG-8、SR-5 换弹中段、第三人称站姿和蹲姿换弹中段；执行器 exit=0，`WEAPON_CONTACT_REVIEW_PASS`。两枪同样存在细长前臂和突兀腕部收束，SG-8 机匣与枪托仍显积木化。第三人称肩肘鼓起、面部简化，蹲姿手与护木、膝部相互遮挡，接触不可判定。蹲姿背景存在离地角色；隔离捕获场景不足以区分启动摆放与实际运行问题，留待连续单机验证。

验证汇总：`artifacts/realism483-validation/validation-summary.json`。环境四机位捕获正常退出，完整位置与朝向在 `environment/environment-camera-poses.json`；三标准机位前后对照在 `comparison/`，新增横穿口对照在 `terminal-comparison/`。均已查看，整体画面基本一致，没有将截图数量视作画质通过。

所有离散截图只能呈现特定时刻，不证明抽匣、插匣、回握、ADS 切换、奔跑落地及肩肘轨迹连续自然。下一阶段应依据当前图结构性修改上臂—肘—前臂体积、袖口过渡和蒙皮，补连续动作接触证据；不再以道路色值或小石块修改替代人物推进。建筑空间与材质、地形山体、树冠多样性、光照和当前版本联网验证继续保留。
