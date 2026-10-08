# Stage83：支撑手拇指与掌根重塑

本轮以 stage82 实际文件为基础，落实 stage31 关于第一人称形体及同机位腰射/ADS 的要求。状态为 **continue**，只完成一个局部建模与验证阶段，整体写实目标未完成。

## 改动

- `tools/build_viewmodel.py` 为拇指设置独立的两处关节压缩、皮革折线与沿长度变化的扁平截面；扩大拇指根部并调整弯曲控制点，使其接入掌肉，末端保留握持位置。
- 扩大掌根/虎口连接体积，重新生成 `art/first_person.blend`、`client/assets/first_person.glb`。本轮未修改武器本体、相机、瞄准或换弹逻辑。
- 三把武器共用这只支撑手，因此复核全部三把的腰射、ADS 和三个换弹时刻。

## 实机画面审阅

固定位置 `(17, 0.05, 50)`、偏航 `atan2(-18,16)`、俯仰 `-0.03`，1280×800，Godot 4.4.1 Forward+，Vulkan llvmpipe 软件渲染。腰射和 ADS 使用同一玩家机位，各武器保留正常 ADS 视场变化。

- `artifacts/realism83-validation/thumb-before-after.png`：stage82 与83的换弹半程同机位裁剪。原先细长圆管状的拇指根部变为较宽、连续的掌肉过渡，外轮廓改善可见；皮革表面仍偏软，指端和缝线不足，不可称为写实手部完成。
- `source-aim-pairs.jpg`：三武器腰射/ADS 成对审阅。腰射支撑手连接连续，未见新增明显脱手或瞄具遮挡；ADS 中手部可见面积小，改进有限。步枪镜内画面可见。
- `source-reload-poses.jpg`：三武器换弹四分之一、半程、四分之三审阅。未见新增明显悬空掌根；固定姿态画面和骨骼接触规则不能排除所有动态指部穿插。
- 袖子仍有管状感；卡宾枪机匣平板感、霰弹枪及精确射手步枪的大块聚合物结构仍明显。仓库重复、地面平坦空旷、草丛重复和远景树木简化均未解决。人物本轮未复核。

完整源码和包内截图、进程退出状态及校验见 `artifacts/realism83-validation/capture-status.json`；包内汇总图为 `packaged-aim-pairs.jpg` 和 `packaged-reload-poses.jpg`。

源码与包内各15帧、共30帧采集均退出0并有 PASS。已实际审阅包内三武器腰射/ADS及全部9个换弹姿态，与源码观察一致，未见新增明显脱手、瞄具遮挡或包内材质丢失。两次采集并非逐像素相同，逐帧RGB平均绝对差记录在索引中；静态截图仍不能证明整个动画无穿插。

## 验证范围与限制

`artifacts/realism83-validation/test-results.json` 保存源码与包内各6项、共12项测试，均退出0并有 PASS：

- 瞄准：每模式108样本、三武器、过渡/后坐力/侧倾/射线。
- 换弹：每模式183个骨骼接触样本、三武器接触/释放/复位。此测试不检查网格穿插。
- 近墙遮挡：不同方向、武器长度、蹲姿、重叠、低举枪及恢复。
- 第一人称与武器规则：骨骼、瞄具、换弹时长、投掷、治疗、死亡复位、装备状态与本地 remote_snapshot。
- 单机 smoke：16 actors、伤害、换弹、治疗、胜利、射线与掩体。不是完整地图碰撞遍历。

导入进程退出0，但仍有 `dummy/storage/texture_storage.h:107 Parameter "t" is null`，原日志为 `import.log`，不隐去此错误。实际 Forward+ 截图是单独的渲染验证，不代表实体 GPU 性能。

真实联网未运行：现有流程涉及读取认证密钥，与本轮约束不符；remote_snapshot 仅同进程规则检查，不能当作真实联网通过。未修改认证或后台服务。

## 本地预览和下一步

运行 `artifacts/realism83-preview/Linux/IronMeridian --path /tmp`，保留同目录 `IronMeridian.pck`。由于标准 Linux 发布模板不可用，使用 Godot 可执行文件和导出 PCK，构建校验见同目录 `build.json`，验证索引见 `verification.json`。未推送或外部发布。

下一轮应重塑卡宾枪机匣主要截面与部件连接、金属/聚合物材质分区，在同机位腰射、ADS及换弹中确认提升；随后扩大到人物、建筑与地形植被/光照的整体画面。仍需符合密钥约束的真实联网验证及更广的地图碰撞检查。
