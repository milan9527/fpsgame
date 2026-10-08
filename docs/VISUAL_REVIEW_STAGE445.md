# Stage445 当前预览审阅（总体未完成）

## 场地改动与视觉结论

`world_visuals.gd:service_yard` 将透明薄盒改为单一朝上的 PlaneMesh，避免盒底和侧面参与透明混合；保留地面和入口坡道的实际碰撞。**没有取得用户要求的明显道路过渡改善，横向色带仍在，不记为修复。** 后续不能继续用微调色值或噪声代替根因定位。

本轮正常 Forward+ 445 包捕获退出0，三张实机图均已审阅。`artifacts/realism445-validation/environment-after/` 保存当前图、相机及过程结果；`environment-before/` 为444原始证据的副本，不能算作445验证。三个 `*-before-after.png` 为左444右445，`camera-comparison.json` 确认完整相机记录相同。

|机位|位置|前向|
|---|---|---|
|service-approach|(17, 1.60010, 50)|(0, 0.0998334, -0.995004)|
|depot-entrance-close|(35, 1.65000, 44)|(0, 0.0249922, -0.999688)|
|terrain-wide|(17, 1.65000, 50)|(-0.409435, 0.0672644, -0.909856)|

分辨率1280×800。入口近景可见门洞未被招牌挡住，但地坪接缝、室内简单箱体和局部照明仍生硬。宽景道路和场地仍有大块浅色区；光滑尖锥山体、相似树冠及长管状前臂明显，未达到整体画质目标。

444包关闭太阳阴影的诊断捕获退出0：真实树影和棚影消失，横向色带仍在，不能将其简单归因于太阳阴影。证据 `diagnostic-no-shadow/`，它是根因诊断，不是445正常渲染验证。

445包另对 `service_access` 关闭导数凹凸，`access-normal-vs-no-bump.png` 左正常、右关闭凹凸。表面细纹减弱，但横向带状区域仍存在；单独去掉凹凸不能修复，下一步应隔离横穿路面的 trench / reinstatement ALBEDO 图案，再检查底层场地覆盖。此诊断包装进程退出143，子进程随后写出图片及捕获完成标记并结束，但无法取得其退出码；`diagnostic-access-no-bump/process-result.json` 明确保持 passed=false，不能算正常测试通过。

## 第一人称四姿势

`poses-full/` 本轮未传 `--pose`，完整捕获 default-spawn、ads、reload-middle、reload-complete，退出0，744.834秒，`SLEEVE_POSE_REVIEW_PASS reload_refilled=true`。四图均实际查看：默认及完成姿势前臂过于长直，腕部突然变细；ADS 的握持轮廓仍有棱角；换弹中段双臂均可见，但袖口膨大、腕部和手套衔接不自然，抓弹匣手指呈分节圆柱。护木支撑需要侧面及连续运动补证，不能凭这些角度判定无穿插。

这是四个离散时刻，不覆盖拔匣、插匣、回握的连续接触、速度及肩肘轨迹。后续应改肩—肘—腕的整体形体及运动链，而不是继续微调手指或机匣。

另两把武器的 `contacts/weapon-1-reload-50.png`、`weapon-2-reload-50.png` 已实际查看。SG-8 与 SR-5 的右手均显得贴在握把后方，SR-5 的掌心和握把之间可见明显空隙，不能记为持握接触通过；左手握弹匣呈粗分节轮廓，双前臂长直、袖口突变。这个问题需要各武器握把锚点与肩肘腕整体姿态共同修正，单独缩放手指无法解决。两图只覆盖换弹中点，不能证明拔匣、插匣、回握过程自然。

`contacts/` 完整四图捕获退出0，849.964秒，过程记录包含当前PCK与脚本哈希。第三人称站/蹲两张均已实际查看：站姿肩部衣料仍像硬块、肘部折面突兀、手套与枪械接触被胸挂部分遮挡；蹲姿膝盖、前臂、弹匣集中重叠，无法从这一角度排除穿插。蹲姿背景还出现离地角色，需追查对应对象和运动状态，不能直接认定为碰撞穿地。第三人称相机位置(2.8,1.50010,65)，欧拉旋转(-0.133233,2.390664,0)，完整记录见 contact-review.json。本轮没有覆盖连续动作、行走或联网同步。

## 当前包功能

`artifacts/realism445-validation/functions/`：建筑六条双向通行与两侧墙体阻挡、路肩通行、三武器瞄准伤害/掩体阻挡、单机smoke均退出0且有各自通过标记。每个 `*-process.json` 记录命令、当前PCK哈希和脚本哈希（内置smoke无外部脚本）。瞄准包装器初始错用了 `AIM_DAMAGE_REVIEW_PASS`；依据实际 `AIM_DAMAGE_PASS` 和六项结果修正记录，保留说明。

当前版本联网未验证；现有联网夹具依赖认证账户和服务凭据，本轮未读取凭据或运行该夹具。功能断言不代表视觉验收。

## 预览

本地启动：`artifacts/realism445-preview/Linux/launch.sh`。

PCK SHA256：`4ad40947351325a92be25459a18681aabbe7522bfc82eb0b4da587c9db624ba7`。来源记录：`artifacts/realism445-preview/provenance.json`；导出日志：`artifacts/realism445-validation/export.log`。保留全部未提交修改，未推送、发布或修改后台服务。

## 沟槽隔离诊断补充

`diagnostic-access-no-trench/` 使用445包，仅运行时删除 service_access 材质的维修沟槽颜色、切缝和对应高度影响，changed_nodes=1；退出0，实际标记 `ENVIRONMENT_REVIEW_CAPTURE_PASS frames=1`。包装器最初匹配了错误标记，已在 process-result.json 保留修正说明。`access-normal-vs-no-trench.png` 左为正式445、右为诊断，同一 service-approach 机位。实际审阅：画面近处横向色带明显减弱，纵向轮迹仍在，支持沟槽材质是主要来源之一；不能据此认定全部场地边界已解决。该诊断未写入生产源码或445预览。下一阶段优先替换突兀沟槽材质，再重新导出同机位验证，不继续用关闭阴影或删除法线代替修复。
