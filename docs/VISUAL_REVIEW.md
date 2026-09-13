# 本地场景视觉预览

本轮采用暖色午后、低饱和工业营地风格，保持现有低多边形模型。新增渐变天空、远山轮廓、建筑饰面与检修板、分层树冠和低矮草丛。地面、混凝土、沥青和岩石使用四张原创程序生成的 256×256 无缝纹理，材质颜色按 sRGB 转线性处理。

装饰和附加树冠按材质实例化合批。草丛使用 MultiMesh，65 米外不绘制、不投影。沿用 OpenGL Compatibility 渲染；不依赖 SSAO、SSR、体积雾或桌面专用后处理。使用普通 mipmap 纹理过滤：本机 llvmpipe 软件驱动下，三平面映射搭配各向异性过滤曾出现长时间卡顿。天空仅作为背景，环境补光使用固定颜色，避免高成本天空反射预计算。

## 验证

固定镜位的修改前后截图位于本地 `artifacts/visual-before/` 和 `artifacts/visual-review/`。对比图为 `artifacts/visual-comparison.png`，含 HUD 和武器的游戏截图为 `artifacts/gameplay.png`。这些是本地运行截图，不是概念图。

268 个碰撞体的位置、尺寸与碰撞层逐项相同；没有改动地图随机序列、道路、门洞、掩体和导航碰撞。单机 smoke 检查通过，覆盖 16 名参战者、换弹、治疗、伤害、胜负、射线和掩体。软件 OpenGL 可以完成三个环境视角及游戏画面渲染；尚未完成手机 GPU 帧率测试。

## 本地重现

纹理生成器依赖 Pillow：`python tools/generate_surface_textures.py`。资源导入后可运行：

```sh
CAPTURE_ARTIFACT_DIR="$PWD/artifacts/visual-review" timeout 90 xvfb-run -a tools/godot --path client --audio-driver Dummy --script ../tests/world_visual_capture.gd
CAPTURE_ARTIFACT_DIR="$PWD/artifacts" timeout 90 xvfb-run -a tools/godot --path client --audio-driver Dummy --script ../tests/visual_gameplay_capture.gd
tools/godot --headless --path client -- --smoke
```

此改动仅在本地源码中。现有下载包使用固定发行源码，尚未包含本轮视觉变更。人物、枪械和拾取物仍为原有模型；后续进一步提高精细度需要单独更新这些资产并测试移动设备性能。
