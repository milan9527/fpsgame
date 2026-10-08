# Stage493：地表开挖与当前预览审阅

本轮完成路沟基底与碰撞的结构性修改，但正常游戏机位的改善仍有限，**不认定道路/场地过渡已获得明显视觉修复，整体继续**。没有发布或推送，保留已有未提交修改。

## 实现与预览

- `world.gd` 的整块平面地面替换为 0.75m 采样的地表网格及同源 trimesh 碰撞；道路面随开挖地形衔接。
- `world_visuals.gd` 新增双轴道路开挖高度函数，交叉路口与建筑入口逐渐回到地面；路肩由高土堤改为浅沟，外缘接入开挖基底。
- 新增 `tests/road_excavation_review.gd`，在完整场景查询碰撞，避免旧平面碰撞掩盖新沟槽。
- 本轮独立差异：`artifacts/realism493-validation/road-structure.patch`；修改前源码保存在同目录 `source-before/`。
- 当前本地运行：`artifacts/realism493-preview/Linux/launch.sh`。export-pack 成功，复用已有 Godot 4.4.1 Linux 运行时，导出日志在预览目录 `export.log`。
- PCK SHA256：`cfa78b4fa5d3e148849f8dabd68775cbd8f00fb7add79f55e95dd364eebaa041`。
- 运行时 SHA256：`54215149d52efb1d653a3dec39d0993587bdf5daa2c56e787b5ee88417fb1339`。

## 环境实机对照

重新运行 stage492 基线与 stage493 当前包，均为 1280×800、Forward+ 软件 Vulkan 渲染。逐图审阅三组前后图，全部相机匹配。证据位于 `artifacts/realism493-validation/{before,after,comparison}/`，完整朝向、目标、图像哈希见 `comparison/camera-comparison.json`。

| 机位 | 相机位置 | forward |
| --- | --- | --- |
| repair-shelter-entrance | (15.5, 1.65, 39) | (0, 0.054087, -0.998536) |
| terrain-wide | (17, 1.65, 50) | (-0.409435, 0.067264, -0.909856) |
| road-horizon | (2, 1.65, 61) | (-0.013697, 0.010615, -0.999850) |

入口近景可见维修棚钢架、波纹板和通道，重复面板仍明显。宽幅地形图仍有大块浅色场地和平直绿褐分带。道路远景前后近似，浅沟在正常视角下不够明显，宽直色带、重复圆树冠、光滑/折面山体仍显眼。不能用新增沟槽、截图数量或像素差认定画质达标。后续需处理实际暴露面的交叠与场地边界布局，不能再只改色值、草簇和小起伏。

## 当前包功能与碰撞

`artifacts/realism493-validation/checks.json` 记录各命令、退出码和耗时，以下均退出 0：

- graded-road：24 条横穿路线。
- shelter：32 条维修棚入口/碰撞路线。
- road：路缘通行检查。
- aim：三武器、无遮挡/掩体共六项；无遮挡造成伤害，掩体阻挡伤害。
- offline：16 角色单机冒烟，换弹、治疗、伤害、胜利、射线、掩体、射击间隔及 rig 断言通过。

独立开挖测试 `excavation/excavation.json` 通过：z=49.2 入口两侧高度约 0 / 0.065m；z=85 两侧约 -0.278 / -0.193m。确认当前完整场景的碰撞能下凹，不能据此推断视觉自然。首次测试脚本类型推断错误修复后重跑通过。

当前联网未验证。现有网络测试会读取认证配置并启动认证 API，本轮没有运行，也没有读取密钥或更改后台服务。旧版本网络结果不计为本版通过；后续需使用隔离本地测试配置验证。

## 第一人称完整四姿势

`sleeve-full/process-result.json`：capture_filter 为空，完整运行通过，退出 0，710.657 秒。已逐图审阅 `default-spawn.png`、`ads.png`、`reload-middle.png`、`reload-complete.png`。

持枪与换弹完成时左手位于护木下方，但前臂袖管细长，腕部/掌根有圆盘式轮廓。ADS 中准星可见，手腕部分被武器遮住。换弹中段左手持分离弹匣，右手持握把；单帧未见明显大面积穿模，但握把接触被遮挡，不能证明接触全程正确。肩肘多数在视野外。本轮尚未修改人物结构。

这四个静态时点不能证明举枪、换弹抽出/插入、手返回护木以及移动混合的连续动作自然；连续过程仍未覆盖。

## 下一阶段的结构诊断

补充实机观察：`weapon-contact/weapon-1-reload-50.png` 与 `weapon-2-reload-50.png` 都显示左手持分离弹匣、右手握枪。两把武器同样存在细长袖管、圆盘掌根和钩状手指；枪托及机匣仍有大块基础形体。`third-stand-reload-middle.png` 中人物肩部与上臂衔接偏硬，肘部轮廓鼓起，持枪手被枪身及胸前装备遮挡，不能判断完整接触。这里只能确认抽样姿态，不能作为连续动作通过证据。

道路优先级仍未关闭。`client/shaders/meadow_surface.gdshaderinc` 的 `road_surface_distance` 使用固定轴线距离（两轴各减 6m，并合并入口线段）；`road_surface.gdshader` 继续用这份距离划分路面、路肩与草地。这与新几何的边界是否一致、以及多层表面谁实际可见，应通过逐层显示诊断验证。它是代码支持的待验证假设，不能直接认定为截图色带的唯一根因。下一轮应统一暴露面与边界布局，再用本轮相机复拍；不要继续叠加色值或零碎草簇。

人物结构入口为 `tools/build_viewmodel.py` 和 `client/scripts/character_animation.gd`。根据实机薄袖管、圆盘掌根的问题，后续应整体检查肩—肘—腕链、袖管截面与手掌体积/握持姿态，保留三武器接触验证；不能把修改单指或机匣细节当成人物阶段完成。建筑重复、山体轮廓与材质、植被层次、光照以及本版联网仍在总体待办中。

## 补齐第三人称蹲姿与阶段结论

`weapon-contact/process-result.json` 最终退出 0，passed=true，640.832 秒，other-weapons-and-third 四图均已逐图审阅。蹲姿 `third-crouch-reload-middle.png` 可见球状肘部，前臂、胸前装备和抬起膝部互相遮挡；接触不能仅凭此图判定。背景角色悬空需排除截图冻结物理的影响，尚未认定为正常运行缺陷。

本轮实现了真实下凹基底及碰撞，但道路视觉改善不足，人物结构也未修改。阶段状态 continue。当前包测试与证据索引见 `artifacts/realism493-validation/stage493-summary.json`；所有截图进程已结束，不能把采集成功解释为画质通过。
