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

这是可运行的写实环境升级，尚未达到《和平精英》整体画面完成度。建筑主体仍是简化几何；人物和枪械几何与动作沿用原有资产，缺少精细服装模型、建筑室内陈设与完整场景美术。尚未测量真实 Android 或 Windows GPU 性能，也未重新测试 AWS 联网会话。

改动仅保存在本地，未推送 GitHub、未部署 AWS、未更新下载包。当前发行打包脚本使用固定基线及指定补丁，不会自动纳入这些视觉改动；发布前必须纳入发行源码，并完成手机与电脑实机检查。
