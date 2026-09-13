# 写实场景本地预览

本轮将场景改为写实军事营地风格：使用 Poly Haven CC0 实拍地表、旧灰泥、沥青、波纹金属屋顶和天空照片；材质含颜色、法线和粗糙度贴图。建筑加入 Blender 制作的倒角金属百叶与边框。远山采用平滑高度网格，外围地表延伸以遮住地图边缘空洞，地面加入实例化草丛。第一人称袖子与人物服装换用原创迷彩织物贴图，降低服装反光。

原来的圆锥树冠替换为真实冷杉模型。针叶几何直接大幅减面会破坏轮廓，因此 25 米内保留约 50.5 万三角面的源模型，25–300 米采用 Blender 从同一模型渲染的透明贴片。近景共享网格；远景使用 alpha scissor、固定竖直轴的 billboard，不投影。切换尚存在轮廓跳变，近景模型也需要进一步优化后再发布到移动端。

继续使用 OpenGL Compatibility。4× MSAA 改善模型轮廓和细针叶的锯齿，普通 mipmap 纹理过滤避免远景闪烁；本机 llvmpipe 软件驱动下三平面纹理搭配各向异性过滤曾长时间卡顿，因此未启用各向异性过滤。天空用于背景、固定颜色补光，关闭天空反射；不依赖 SSAO、SSR、体积雾。

素材来源、许可与修改记录见 `client/assets/realism/LICENSE.md` 和 `SOURCES.json`。没有使用《和平精英》的专有资产。

## 重建与检查

提交的 GLB、贴图及导入设置可直接由 Godot 使用。重新获取源素材需要 Python 的 `httpx` 和 `Pillow`：

```sh
python tools/fetch_realism_assets.py
python tools/generate_uniform_texture.py
tools/blender-4.3.2-linux-x64/blender --background --threads 8 --python tools/build_realism_assets.py
tools/godot --headless --path client --editor --import
CAPTURE_ARTIFACT_DIR="$PWD/artifacts/realism-review" timeout 120 xvfb-run -a tools/godot --path client --audio-driver Dummy --script ../tests/world_visual_capture.gd
CAPTURE_ARTIFACT_DIR="$PWD/artifacts/realism-review" timeout 120 xvfb-run -a tools/godot --path client --audio-driver Dummy --script ../tests/visual_gameplay_capture.gd
tools/godot --headless --path client -- --smoke
```

截图是实际 Godot 运行画面。此次仅改变客户端表现；地图布局、门洞、道路、射击射线和碰撞规则保持原样。268 个碰撞体的快照逐项相同。16 人单机 smoke 通过（换弹、治疗、伤害、胜负、射线、掩体、射击间隔与骨骼）。验证结果记录在本地 `artifacts/realism-*.log`，碰撞快照为 `artifacts/realism-review/collision.json`。

## 当前边界

这是可运行的写实环境升级，尚未达到《和平精英》整体画面完成度。建筑主体仍是简化几何；第三人称人物几何与动作仍沿用原有资产（第一人称模型后续更新见第二轮），缺少精细服装模型、建筑室内陈设与完整场景美术。尚未测量真实 Android 或 Windows GPU 性能，也未重新测试 AWS 联网会话。

改动仅保存在本地，未推送 GitHub、未部署 AWS、未更新下载包。当前发行打包脚本使用固定基线及指定补丁，不会自动纳入这些视觉改动；发布前必须纳入发行源码，并完成手机与电脑实机检查。

## 第二轮：第一人称模型与建筑细节

步枪新增圆形枪管、枪管箍、机匣侧板、拉机柄、护木散热槽、护圈、瞄具调节旋钮与安装螺钉；金属和塑料采用更中性的深色与较高粗糙度。步枪为 7,944 个三角面，仍维持四个网格节点及原来的 SightAnchor / MuzzleAnchor。

手臂由简单圆锥改为 25 圈、32 分段的带褶皱袖子，重新展开布料 UV 并平滑法线，手套增加圆角并降低亮度；整体 7,272 个三角面。保留五根骨骼和 Hold / Reload / Throw / Heal 四段动作。迷彩改为连续的不规则色块，避免原先交叉多边形造成的碎三角图案。Blender 手臂源文件已打包布料纹理。

建筑增加门框、檐沟、排水管及固定卡箍，仍沿用现有门洞和碰撞布局。以上细节都是本项目制作，没有新增第三方素材。

重建本轮模型：

```sh
python tools/generate_uniform_texture.py
ASSET_ONLY=carbine tools/blender-4.3.2-linux-x64/blender --background --python tools/build_assets.py
tools/blender-4.3.2-linux-x64/blender --background --python tools/build_viewmodel.py
tools/godot --headless --path client --editor --import
```

本轮截图目录为 `artifacts/realism2-review/`，完整游戏画面为 `gameplay.png`；前后对比图为 `artifacts/realism2-comparison.png`。验证包括武器模型/锚点、108 组瞄准射线、手臂动作与单机 smoke；碰撞快照仍与原版 268 项一致。旧手臂测试对已停用的枪身准星点仍有显示断言，现改为检查 HUD 准星设计所要求的隐藏状态。截图工具也增加输出目录创建与保存结果检查，避免图片保存失败时错误报告通过。

第三人称人物几何、其他枪械和环境总体密度仍需要后续美术工作；本轮没有 Android/Windows 真机性能结论。改动仅在本地，尚未推送或发布客户端。

## 第三轮：植被、地形与可运行预览包

用 Blender 制作九片弯曲叶片的原创草簇，替换原先的尖刺草。草簇采用颜色渐变、确定性噪声控制疏密，并按 24 米网格分组实例化，75 米外停止绘制；道路和建筑周边仍留空。远山加入多层噪声山脊，减少重复圆顶轮廓。重建草簇：`tools/blender-4.3.2-linux-x64/blender --background --python tools/build_grass.py`。

实际画面保存在 `artifacts/realism3-review/`。源码与打包后的 Linux 程序均通过 16 人单机 smoke，环境截图通过，268 项碰撞快照与原版完全一致。

`artifacts/visual-preview/` 提供本地 Windows / Linux 预览包，包含前三轮美术改动。Windows 使用嵌入资源的 EXE，导出成功，但未在 Windows 系统上启动验证；Linux 因本机缺少专用 Linux 导出模板，使用本机 Godot 4.4.1 运行时和 PCK，并已从项目目录外启动验证。用户无需另装 Godot。预览包的默认 API 仍是 localhost，用于单机预览；没有验证它与线上服务器的协议兼容性。没有上传预览包、改动线上服务或推送 GitHub。

## 第四轮：人物、扫描道具与地表清晰度（目标仍在进行）

第三人称人物改用带褶皱的圆润四肢、头盔/护目镜、背心、肩带、弹匣袋、护膝、靴底和背包。保留 17 根骨骼及 15 段动作；布料纹理打包进 Blender 源文件。真实渲染检查通过站立、行走、奔跑、蹲伏、换弹、跳跃、死亡、倒地爬行和驾驶/乘车姿态。

原有散布掩体改用 Poly Haven CC0 木箱模型，最大外形归一化到原来的 2.5×1.5×2 米碰撞尺寸。外围岩石位于可行走地面之外，只作背景。两者的下载校验、来源和许可记录在 SOURCES.json / LICENSE.md。重建工具为 `tools/fetch_scenery_assets.py` 和 `tools/build_scenery_assets.py`，木箱 11,998 三角面，岩石 12,000 三角面。岩石先焊接重合顶点再减面，避免不连通的扫描网格无法达到预算。

地表和墙面改用 2K 原图，地面使用平面 UV 与各向异性过滤；三平面映射的墙壁/山体仍用普通 mipmap 过滤。本机软件渲染已验证平面 UV 不会触发先前三平面+各向异性组合的卡顿。远山网格提高到 65×65，降低噪声频率以减少尖锐折面。恢复补给类别颜色，防止通用墙面材质覆盖道具识别色。

最新游戏/环境截图在 `artifacts/realism4-review/`，人物展示图为 `artifacts/realism4-characters.png`。当前只是检查点，尚未认定达到用户的整体画质要求。仍需提高补给物和建筑的完整度、场景自然层次，并完成最终客户端打包及平台性能验证；之前的 visual-preview ZIP 仍是第三轮版本，没有冒充包含本轮更新。

## 第五轮检查点：物资箱和建筑配件（目标仍在进行）

补给代理继续保留原来的 BoxMesh 尺寸、交互位置和材质状态，但不绘制代理几何；可见模型换成原创的倒角箱体、箱盖密封条、护角、锁扣与把手。模型箱体表面共享代理的类别/高亮材质，复用道具 ID 后也同步更新。类别漆面亮度降到原来的四分之一，避免普通道具呈霓虹色。供给规则、死亡掉落和握把规则测试已通过；测试额外验证了可见模型确实共享高亮材质及保持堆叠尺寸。

建筑加入 CC0 卷帘窗、空调外机和工业壁灯。下载包中的空调与窗户含并排变体，构建器只选第一款，避免将整组模型错误缩放到一个配件尺寸；墙面安装深度也已校正。配件使用 MultiMesh 批量绘制。来源与作者均记录在素材许可文件中。最新截图继续写入 `artifacts/realism5-review/`。

本节是开发检查点，不代表画质目标已经完成；本地已发布的第三轮预览 ZIP 也尚未包含这些后续资产。

### 桌面渲染路径

桌面默认改为 Forward+，启用天空补光/反射与 SSAO；移动端维持 GL Compatibility，并显式保留渲染设备初始化失败时的 OpenGL 回退。通过显式 `--rendering-method gl_compatibility` 可运行兼容模式。服务器新增 Mesa Vulkan 软件驱动以进行真实 Vulkan 渲染验证；本机没有物理 GPU，因此这不是 Windows/Android 显卡帧率报告。

Forward+ 游戏截图位于 `artifacts/realism5-lit/gameplay.png`，兼容路径位于 `artifacts/realism5-compat/gameplay.png`。两条路径均完成实际渲染，Forward+ 蒙皮动画验证和单机 smoke 通过。此配置仍需最终打包与真实设备验证，整体画质目标仍保持进行中。

## 第六轮：武器结构与瞄准镜

霰弹枪改为圆形护木与握持筋条，精确射手步枪增加圆形护木、通风孔、枪管台阶、圆形调节钮和拉机柄。两把枪增加机匣侧板、紧固件、扳机护圈与弹匣加强筋；加强筋合并进可动弹匣，保留每把武器四个网格的动画约定。

第一版实际截图暴露了镜筒通光孔过窄、内壁折面和粗圆环问题。修订版缩短镜筒，采用直通内孔、64 段圆周和平滑薄边环；不改变枪口与瞄准锚点。修订版网格为卡宾枪 7,944、霰弹枪 7,988、精确射手步枪 13,684 三角形。`ASSET_ONLY=weapons` 可单独重建武器，不必重建人物与手臂。

第一版三武器渲染与模型验证完成，修订后的 108 组瞄准射线验证也已通过（`artifacts/realism6-aim-revised.log`）。修订版截图检查结果另行记录，不能将模型规则测试通过视为整体画质达标。预览 ZIP 尚未更新。

后续修订扩大内孔后发现支架和调节钮穿入镜筒，已调整它们的位置。`artifacts/realism8-optic/marksman-aim.png` 实际检查确认内孔干净。六视图完整捕获在软件 OpenGL 下超过 180 秒，只生成部分图片，因此没有把该次运行记为通过；新增 `tests/optic_visual_capture.gd` 在数值上先稳定姿态，再仅渲染必要静帧，专门检查镜筒几何。

## 第七轮：山坡背景林带

外围增加噪声分布的林带，以共享贴图、带实例颜色与缩放的 MultiMesh 绘制，避免为背景树分配高面数近景模型。全部树根位于可玩区域之外。首次截图发现山体遮住平地高度的树，因此提取山体高度函数用于树根落位；山体本身的网格生成公式保持一致。

`artifacts/realism7-hillside/street.png` 已实际检查，背景树木现在沿坡面分布。`overview.png` 提供整体布局检查。此次兼容渲染捕获完成；碰撞快照与基线完全相同，仍为 268 个形状及相同变换。当前仍有明显局限：单一稀疏树冠、平坦城区、重复的低层建筑，不能据此认定达到参考游戏的整体写实程度。需要进一步改善树种/树冠与建筑、地形层次，并更新可运行预览。

## 第八轮：建筑屋顶轮廓

Blender 原创双坡/单坡金属屋顶及接缝，分别应用到两种建筑样式，其余保留平顶。源文件 `art/roof_gable.blend`、`art/roof_shed.blend`，重建脚本 `tools/build_roofs.py`。共用世界构建代码同时为单机和专用服务器生成对应凸体碰撞，避免新增屋顶只是可穿透装饰。

屋顶射线测试 `tests/roof_collision.gd` 通过，覆盖 8 栋屋顶各三个坡面位置、挡弹和贯通门洞。新碰撞快照共 276 个形状，其中原有 268 个与基线逐项一致，另外 8 个为屋顶；凸体快照现在记录顶点而非不稳定的资源 ID。单机 smoke 通过。实际场景截图位于 `artifacts/realism8-review/`，专用瞄准镜截图位于 `artifacts/realism8-optic/`。这次没有验证旧线上服务与新客户端的跨版本匹配；本地预览包仍需更新，整体画质目标继续进行。

### 第八轮本地可运行预览

已更新 Windows/Linux ZIP，位置为 `artifacts/visual-preview/b3fdf590901d/`，包含截至第八轮的游戏内容。`verification.json` 记录构建提交、各平台 SHA-256 与检查结果。Linux 打包版本从独立临时目录自动加载旁边 PCK，单机 smoke 和屋顶碰撞测试通过；Windows 完成原生 EXE 导出，未在 Windows 系统执行验证。解压后启动 EXE 或 Linux `IronMeridian` 即可，不需要 play.sh 或另装 Godot。

构建脚本 `tools/package_visual_preview.py` 保留独立提交目录，附带许可/素材来源和运行说明，没有覆盖线上发布。原有顶层第三轮 ZIP 保留，不应作为新版链接使用。这些包供本地离线检查；新屋顶世界内容未部署到旧线上服务，不能据此声称与旧服务匹配。画质优化目标仍未完成。

## 第九轮：卡宾枪近景结构

机匣由单块倒角方盒改为有斜面过渡的截面挤出体，用布尔切割形成真实抛壳口凹槽及可见枪机；增加保险拨杆、加强筋和完整连续导轨。保持四个网格、原有枪口/瞄准锚点与独立弹匣，共 10,240 三角形。生成源仍为 `tools/build_assets.py`，可用 `ASSET_ONLY=carbine` 单独构建。

武器钢材与聚合物使用共享的细颗粒粗糙度贴图，按材质区分范围；缓存材质避免为每个远程玩家复制纹理。该效果只是细微的表面处理，并未将它描述成完整的写实武器贴图制作。没有使用曾导致软件驱动卡顿的各向异性三平面组合。

`artifacts/realism9-gameplay/gameplay.png` 为实际 Forward+ 游戏截图，已检查机匣和导轨轮廓。108 组瞄准、三武器模型/锚点、第一人称动作测试均通过（`realism9-aim.log`、`realism9-weapons.log`、`realism9-viewmodel.log`）。第八轮 `b3fdf590901d` ZIP 不包含本轮近景改动。整体场景、树冠和材质仍需继续改进，目标没有完成。

## 第十轮：背景树冠与墙面尺度

同一 CC0 杉树素材的 B 变体比现有 C 变体具有更完整的树冠。通过按范围下载提取源模型，在 Blender 中统一高度并渲染成 1024×1024 透明背景贴图，替换外围山坡林带的贴图。新增游戏资源约 900 KB，约 230 万三角形的源模型仅用于离线渲染，没有逐棵加入游戏。近景 C 树及其碰撞保持原样。105 MiB 的中间 Blend 位于 `artifacts/realism-sources/tree-b/background_fir.blend`，可通过已提交脚本重建；来源及范围校验值记录在 `SOURCES.json`。

粉刷墙面由现有扫描贴图生成较低对比度的变体，并缩小世界空间纹理尺度。首次捕获发现新贴图默认关闭 mipmap，产生高频噪点；现已为墙面和背景树贴图显式启用。最终实际 Forward+ 截图 `artifacts/realism10-final/gameplay.png` 已检查，墙面噪点消除、树冠轮廓更完整。这里只改材质/背景贴图，没有增加碰撞或改动战斗规则。

这仍是局部艺术改进。场景布局、建筑内部和人物细节距离整体写实目标仍有明显差距；第八轮预览包不包含第九、十轮更新。目标继续保持未完成。

## 第十一轮：仓库内部

室内地面采用 CC0 `concrete_floor_02` 的 2K 原始扫描材质，明确启用 mipmap，平面 UV 按约 4 米尺度映射；加入伸缩缝、内侧墙脚和中央顶灯。顶灯有可见灯具、暖色局部光、阴影及距离淡出。首版壁灯照不到主要掩体区域，实际检查后改为中央灯具。

原室内方块掩体隐藏显示，保留原碰撞，以实际木制货箱模型贴合可见尺寸。单机 smoke 通过，场景碰撞快照仍与第八轮 276 个形状/变换完全一致；没有改变门洞或导航障碍布局。`CAPTURE_INTERIOR=1` 可让现有游戏截图脚本进入室内，最终 Forward+ 截图为 `artifacts/realism11-lit/gameplay.png`。Compatibility 世界截图也完成。

当前只是仓库内部的第一轮完整材质/照明处理，尚缺更多自然布置和人物细节。未将它当作整体画质达标，也没有部署或推送。

第十一轮本地预览更新到 `artifacts/visual-preview/9648cb40b560/`，包含第九至十一轮改动。Windows/Linux 导出完成，打包后的 Linux 单机和屋顶碰撞检查通过，构建提交和归档 SHA-256 在该目录 `verification.json`。Windows 仍未进行实机运行测试；目录外旧 ZIP 不包含最新改动。

## 第十二轮：人物比例、蒙皮和迷彩 UV

头盔宽度从 0.35 米调整为 0.27 米，头部与护目镜相应缩小；用有厚度的曲面壳替代扁椭球头盔，补充颈部、面罩和束带，收窄靴子。衣料在关节附近混合相邻骨骼权重，减少原有完全刚性分段的硬折；褶皱改为集中在关节附近，减轻规则波纹。保留 17 根骨骼、15 个动作，模型约 25,856 三角形。

实际近景发现原来的四肢 UV 层名为 `Uniform UV`，与球体/方盒的 `UVMap` 不同，合并后迷彩材质读取的主 UV 在大量四肢面上退化为一点。统一层名后，按约 0.6 米重复尺度映射身体、四肢和口袋，避免图案被拉成长条。动画测试新增真实衣料三角形的主 UV 覆盖检查：旧资产触发断言，修复后的 12,804 / 12,876 个衣料三角形具有非退化 UV，剩余为球面极点等边界。

最终近景为 `artifacts/realism12-character-scaled.png`。`realism12-scaled-animation.log` 通过常规蒙皮、UV、走跑/下蹲/换弹/跳跃/死亡检查；`realism12-final-vehicle_animation.log` 和 `realism12-final-downed_animation.log` 验证了改动后的几何与权重在载具/倒地状态下的表现（随后只调整 UV 尺度）。展示脚本增加近景选项及图片保存失败检查。

比例和纹理缺陷已改善，但这仍是原创程序化人物的开发检查点，装备、面部和动作细节尚未达到完整写实标准。第十一轮预览 ZIP 不含这次人物改动；整个画质目标继续进行。

## 第十三轮：仓库场地与内容版本

部分仓库周围加入混凝土装卸场地和标线，内侧地块连接主路，避免给外侧地块铺设穿过内侧建筑的直线车道。场地采用实际尺寸的地面 UV，并从植被采样中排除。战术地图同步加入这些区域，绘制顺序保持建筑轮廓在场地上方。实际 Forward+ 截图为 `artifacts/realism13-yard/gameplay.png`，Compatibility 世界视图在 `realism13-world/`；276 个碰撞形状和变换与第十一轮完全一致。单机 smoke、战术地图规则检查通过。

检查发现第八轮新增屋顶碰撞后内容号仍为 `ash-valley-18`，不能可靠区分旧线上地图和新本地地图。本轮将内容号更新为 `ash-valley-19`，网络协议号仍为 17，未部署服务。`tests/world_content_revision.gd` 验证同内容号可匹配、旧内容号被拒绝，以及旧存档读取拒绝后仍保留原文件、新版本存档可正常读写。此处验证兼容判断，不冒充实际远程联机测试。旧存档没有自动迁移到新的碰撞世界。

本轮没有改变建筑排列或完成整体关卡美术；场景仍需更多建筑与地形层次。第十一轮 ZIP 仍为旧内容版本，不包含第十二、十三轮改动。

## 第十四轮：山体坡度材质

背景山体从单色改为世界空间岩土混合：缓坡使用原有地表扫描图，陡坡过渡到 CC0 `rock_face_03` 的 2K 色彩、法线和粗糙度贴图。三轴投影减少坡面拉伸，低频变化打散统一分界，启用 mipmap。没有修改山体几何或碰撞，内容号仍为 `ash-valley-19`。

Forward+ 与 Compatibility 实际单机截图均通过，分别在 `artifacts/realism14-forward/gameplay.png` 和 `artifacts/realism14-compat/gameplay.png`。人工检查 Forward+ 截图可见山体岩土层次，但远景雾削弱细节，地面草丛稀疏、建筑体块和排列仍然简单。这是局部材质改善，不代表达到参考游戏的整体写实画质。没有进行 GPU 实机性能验证。

第十四轮已更新本地 Windows/Linux 预览：`artifacts/visual-preview/0f2b9d5f721b/`，包含第十二至十四轮改动，内容号 19。两个平台导出和打包后 Linux 单机/屋顶碰撞检查通过，归档校验值在 `verification.json`；Windows 尚未实机验证。源码瞄准检查通过 108 个样本，覆盖三个武器、切换、后坐力、侧倾和射线。未推送或部署。

另从 `/tmp` 启动打包后的 Linux 程序完成 Forward+ 实际单机截图，证明相邻 PCK 及新材质可加载：`artifacts/visual-preview/0f2b9d5f721b/capture/gameplay.png`，日志 `artifacts/realism14-packaged-render.log` 通过。

## 第十五轮：低矮草地与疏密斑块

Blender 草丛从 9 片宽直叶改为 14 片更细低矮、带弯曲与枯绿差异的叶片，单簇 84 三角形。世界采样改为噪声控制的斑块密度，并变化垂直比例；首版 55,977 簇仍偏稀疏，实际查看后增至 169,031 簇，按 100 个 MultiMesh 单元、75 米距离裁剪。最终 Forward+ 实际游戏截图：`artifacts/realism15-dense/gameplay.png`。

Compatibility 图形环境检查所有实例均避开道路和装卸场地，日志 `realism15-dense-check.log`；检查中的构建与遍历共约 6.6 秒（软件渲染环境，不是帧率指标）。无图形渲染模式读取 MultiMesh 变换会得到无效结果，因此不能据此判断植被穿插。序列化后由 Python 比较的 276 个碰撞形状/变换与第十三轮完全相同。`realism15-smoke.log` 单机检查通过，包括换弹、治疗、伤害、胜利、射线和掩体。

地表覆盖改善，但远处细草仍有颗粒感；密度提高了渲染成本，尚需 LOD 和实机性能检查。建筑和角色仍未达到整体目标。现有 `0f2b9d5f721b` 桌面 ZIP 只到第十四轮，不含本轮草地；源码可直接运行。未推送或部署。

## 第十六轮：草地距离过渡与裁剪

草叶改用不透明双面着色器，24–48 米平滑缩回根部，加入轻微随高度变化的摆动。MultiMesh 单元由 24 米缩为 12 米，在 58 米处裁剪；该距离超过缩回距离加半格对角线，避免整格可见草地突然消失。保持全部 169,031 个实例的位置，不改变碰撞和玩法内容号。

Forward+ 实际截图 `artifacts/realism16-forward/gameplay.png` 和 Compatibility 截图 `realism16-compat/gameplay.png` 均通过。相同视角重建上轮的 24 米格/75 米裁剪/StandardMaterial 草地进行比较，`realism16-profile.log` 记录场景图元从 2,778,070 降至 1,748,314（约 37%），绘制调用从 516 增至 523；新旧实例总数相同。测量脚本在 `artifacts/realism16-grass-profile.gd`。这些是固定视角提交量，不是硬件帧率，也不能证明所有视角的性能。

截图中远处细草颗粒减少，但远地表仍简单，近处叶片还有锯齿；建筑体块、人物和整体环境仍有明显不足。后续重点应转向建筑轮廓、材质尺度和自然布局，不能只靠继续微调草地宣称写实目标完成。

第十六轮本地 Windows/Linux 预览位于 `artifacts/visual-preview/8de4240141a5/`，包含第十五、十六轮草地改动。导出、打包后 Linux 单机与屋顶碰撞检查通过。从 `/tmp` 启动打包程序的实际 Forward+ 截图也通过，图片位于该目录 `capture/gameplay.png`；归档哈希见 `verification.json`。Windows 尚未实机测试，未推送或部署。

## 第十七轮：仓库侧墙构造

通过 `tools/build_facades.py` 在 Blender 中制作三种原创侧墙组合：混凝土柱网与窄百叶、折边金属围护板、混凝土柱网与宽百叶。封闭百叶背后仍是原有实墙，没有伪装成可穿透窗洞。删除旧的单块侧墙装饰板。混凝土使用按米生成的 UV，金属围护板复用 CC0 波纹铁皮扫描贴图。三个模型分别为 9,144 / 2,448 / 9,144 三角形、3 / 2 / 3 个材质表面。

首轮背光近景暴露了平色金属板和百叶细节丢失的问题：增加围护板 UV/扫描材质，扩大百叶间隙，并禁用两个百叶组件的自动网格 LOD。扫描材质首版还被屋顶色乘数压得过暗，最终改为白色乘数保留扫描色值。最终金属板近景为 `artifacts/realism17-steel/facade_1.png`；其他两种墙面最终近景在 `realism17-facades-final/`。Forward+ 单机截图为 `realism17-final/gameplay.png`（随后仅调整样式1围护板的颜色乘数）。

`realism17-model-check-final.log` 检查三个导出模型 UV、材质面数及边界；`realism17-world.log` Compatibility 世界截图通过，276 个碰撞形状/变换经 JSON 比较与第十三轮完全一致。单机 smoke 通过。内容号仍为19，未部署或推送。现有 `8de4240141a5` 桌面预览仍到第十六轮，不包含本轮侧墙。

侧墙层次有所改善，但建筑主体轮廓和排列依然重复，整体环境与角色仍低于目标；本轮不代表整体画质完成。后续应改进建筑正面与屋顶轮廓、空间布局和更自然的地表层次。
