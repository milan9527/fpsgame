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
