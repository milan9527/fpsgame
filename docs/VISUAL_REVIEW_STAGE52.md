# Stage52 第一人称袖管与袖口实拍审阅

日期：2026-09-13。结论：continue；完成局部资产与回归验证，整体写实目标未完成。

## 本轮改动

修改 `tools/build_viewmodel.py`，重建 `art/first_person.blend` 和 `client/assets/first_person.glb`。收紧袖管末端、增加腕部堆积与六条局部斜向褶皱，避免整圈等距环纹；袖口改用迷彩布料与柱面UV，增加贴合椭圆袖口的双层弧形调节搭片。骨架和武器接触锚点不变。本轮没有新增枪身材质或第三人称/场景改动。

## 实际截图审阅

当前导出包通过 `tests/weapon_review_capture.gd` 在 Xvfb、Godot4.4.1 Forward+、Vulkan llvmpipe 下生成15张1280×800原图，进程退出0且报告 `WEAPON_REVIEW_CAPTURE_PASS frames=15`。三武器各包含腰射、ADS及三个换弹采样；相同角色位置、朝向与俯仰，ADS保留游戏实际视场变化。属于受控实机场景，不等于人工游玩全过程。

- `artifacts/realism52-validation/carbine-before-after.jpg`：stage51/52同机位AR腰射、ADS、换弹末段对照。新袖管中段和腕部轮廓更有变化，腕部收束可见；迷彩遮盖了不少褶皱，收益有限，宽阔前臂仍显圆柱和扁平。
- `artifacts/realism52-validation/three-weapons-hip-ads.jpg`：已审阅三种武器腰射/ADS。红点、霰弹枪机械瞄具和精确射手镜内十字均可见，未见新增袖口遮挡瞄准视线。精确射手ADS几乎看不到袖管，不能以此判断布料效果。
- `artifacts/realism52-validation/reloads-three-weapons.jpg`：已审阅全部九个换弹采样。手臂在可见姿态中连续，袖口无明显破洞或脱离；搭片细节很小，不能宣称显著提升。离散截图不能排除姿态之间瞬时穿插。
- 枪身仍均匀偏暗、塑料与金属差异不足；院落空旷重复、泥草过渡和远山树木程序感仍明显。本轮没有解决这些问题，也没有新证据表明人物/光照整体达标。

## 验证与限制

`artifacts/realism52-validation/tests.json` 的7项均退出0：瞄准108样本、三武器换弹接触183样本、第一人称规则、武器视觉规则、抵墙碰撞规则、手套表面规则及16角色单机烟测。测试使用本轮导出包；remote_snapshot是模拟规则检查，不是真实联机。

Blender重建及导出成功。无头Godot导入退出0，但 `import.log` 保留一条既有 `texture_2d_get` 空纹理错误；截图及测试日志无对应运行错误。llvmpipe截图不支持硬件性能结论。

只读访问本机8000端口 health、protocol、openapi.json 均HTTP404，服务器为SimpleHTTP/0.6 Python/3.9.25，见 `network-probe.json`。真实双客户端验证仍受API不可用阻塞，未修改后台服务。

本地预览：`artifacts/realism52-preview/Linux/IronMeridian` 及相邻PCK；启动方式、哈希与验证索引见该目录README、build.json、verification.json。未推送或发布，保留全部既有未提交修改。

下一轮：优先让袖管布料明暗/粗糙度和机匣表面层次在实际画面可辨，继续同机位腰射/ADS对照；随后推进坡道道路泥草过渡、院落差异化及人物，API可用后补真实双客户端验证。
