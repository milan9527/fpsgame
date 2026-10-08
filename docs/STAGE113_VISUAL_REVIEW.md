# Stage113 — 分枝针叶树与远山树冠

状态：continue。完成一次环境植被资产替换和实机验证，不代表整体写实画面目标完成。

## 本轮实现

- 新增 `tools/build_branching_fir.py` 和可编辑 `art/branching_fir.blend`，用固定种子生成树干、交错主枝、下垂分枝及针叶。替换 `client/assets/realism/fir_full.glb`，同时从同一模型正交渲染 `fir_background.png`，使远近树冠形态对应。来源与许可记录已更新；本轮资产为本地原创生成。
- Blender 构建日志报告导出前 127178 polygons、395088 vertices；这不是 GPU 性能验收结果。
- 沿用前两阶段建筑墙体、装卸棚、地坪与照明；本轮没有修改建筑结构或光源。新增正常眼高的林地审阅机位，避免只凭远景判断树冠。

## 实机审阅结论

`artifacts/realism113-validation/` 内三个 `*-before-after.jpg` 为左侧112独立包、右侧113独立包。两侧运行同一采集脚本；源码113也另行采集，三份相机 JSON 完全一致。截图均为实际 Godot Forward+ 画面，保留武器及HUD。

- `terrain-wide-before-after.jpg`：远山原先细长、团簇状树影变为较宽的分层针叶树轮廓，能从正常游戏机位辨认；但统一树形重复，部分枝层像规则横排，远近颜色和细节密度仍有差异。
- `forest-eye-level-before-after.jpg`：近树横向枝干和针叶层次更明显，落地阴影可辨。针叶仍稀疏且细碎；新树干底部有明显棱角、缺少自然根部过渡，属于此次替换的不足，不能把轮廓变宽视为全部质量提升。
- `depot-entrance-close-before-after.jpg`：入口、墙裙、卷帘外壳、室内灯及通行区域可辨。此次没有针对该处改造；大箱子的材质拉伸、平滑地坪和细长第一人称手臂仍在。
- 宽幅画面仍存在道路过宽且空旷、低矮仓库重复、草丛密度与尺度单一、山体平滑的主要问题。需要继续改地被接地、院落布局与光照层次。

## 相机复现

分辨率1280×800；相机眼高为 actor_position + (0,1.6,0)。以下 yaw/pitch 单位为弧度；完整 target 数据见 `before-forward`、`source-forward`、`packaged-forward/environment-camera-poses.json`。

| 机位 | 角色位置 x,y,z | yaw / pitch |
| --- | --- | --- |
| depot-approach | 17.00000, 0.05000, 46.00000 | -0.862170 / 0.029819 |
| depot-canopy | 23.50000, 0.05000, 42.00000 | -0.135528 / 0.031516 |
| depot-entrance-close | 35.00000, 0.05000, 44.00000 | 0.000000 / 0.024995 |
| terrain-wide | 17.00000, 0.05000, 50.00000 | 0.422854 / 0.067315 |
| depot-interior-fixture | 35.00000, 0.05000, 38.00000 | 0.000000 / 0.502843 |
| depot-interior-floor | 35.00000, 0.05000, 38.00000 | 0.000000 / -0.221314 |
| forest-eye-level | -111.18713, 0.05000, -72.47517 | 0.000000 / 0.230812 |

## 验证与边界

功能结果见 `functional-results.json` 和对应日志：源码与独立包各运行瞄准、枪口遮挡、单机烟测、入口碰撞、屋顶碰撞、棚下净空、掩体碰撞、网络状态规则、仓库双向通行和装卸棚双向通行。仓库/棚下通行使用实际角色物理移动，起止点及通过结果在各 `*-forward/{traversal,depot-traversal}.json`，不是只测试射线。

单机烟测覆盖装弹逻辑、治疗、受伤、胜利、射线、掩体与射击间隔。网络状态规则仅覆盖本地状态逻辑，未运行真实双客户端联网，本轮不声称多人主流程已验收。静态武器姿态截图也不能代替连续换弹的时序与手部接触验收。

已审阅 `packaged-weapons-contact.jpg`：三枪腰射与瞄准构图均可辨，换弹抽样可见左手离开握持位置再回位；手臂仍细长、袖口过渡生硬，不能由静态帧确认全程手部接触或穿插。

环境三版各七机位；独立包另有三枪腰射、瞄准和三个静态换弹截图，日志与最终汇总见 `capture-results.json`、`verification.json`。使用 llvmpipe 软件 Vulkan，未验证硬件 GPU 帧率。

## 本地预览

项目根目录执行：

```sh
./artifacts/realism113-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus
```

保持 executable 与 PCK 相邻。`artifacts/realism113-preview/{README.md,build.json}` 保存操作说明、构建信息和哈希。未推送、未发布，保留此前所有未提交修改。

## 下一阶段

优先修复近树棱角树根、地被与泥土过渡，并用正常宽幅机位推进院落差异及光照层次。继续保留人物和武器目标：沿用112审阅发现的块状护具、背包、靴子、暗脸和蹲姿腿部压缩作为待修项；113没有重新验收第三人称。随后进行第一人称连续换弹及真实联网主流程测试，不能凭本阶段截图数量或局部树冠变化结束总体目标。
