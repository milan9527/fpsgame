# Stage91：AR 护木连接与握把材质

本轮承接 stage90 的 AR 机匣、护木、握把任务。整体写实目标仍未完成，状态 continue。

## 实际修改

- 缩短上机匣伸入护木的部分，消除原本遮住后段散热开孔的内部重叠。
- 护木后端增加左右夹持件、螺钉及凹槽，机匣侧面增加装配接缝。
- 握把侧面沿原有曲面分配独立非金属橡胶材质，烘焙细颗粒法线、底色和粗糙度贴图；保留握把整体接触位置。
- 修改生成器 `tools/build_assets.py`，重建 `art/carbine.blend` 和 `client/assets/carbine.glb`，生成配套本地预览。

## 实机画面审阅

证据根目录：`artifacts/realism91-validation/`。

- `stage90-91-comparison.jpg`：stage90 与 stage91 同机位腰射和 ADS 对照。ADS 保持既有放大率，准星视野未见新遮挡。正常游戏尺寸下改善有限，不能据此宣称枪械整体写实已经达标。
- `source-contact.jpg`、`packaged-contact.jpg`：源码和独立 PCK 各五张实际 Forward+ 截图，包含腰射、ADS、三个换弹时刻，均已审阅。完整原图位于 `source-forward/`、`packaged-forward/`。
- 换弹侧视更容易看到开孔与握把材质区别。枪身仍有较大暗平面，新增小零件在腰射中可见度低。左掌仍呈连片手套形体，指节分离不足；前臂仍偏直筒。重复建筑、稀疏环境和偏平的光照仍然明显。
- 本轮没有重新采集另两把武器的画面，没有把接触规则通过当作掌指视觉自然的证明。

## 验证和预览

Blender 构建、Godot 导入、PCK 导出和两次五帧采集均退出 0；截图采集均输出 PASS。导入仍记录已有 `Parameter "t" is null`，没有将该日志隐去。源码与预览各十项检查共 20 项均退出 0 且输出 PASS，覆盖手套材质、三武器瞄准/换弹接触、遮挡、视图模型、武器视觉规则、单机冒烟、入口/屋顶碰撞及联网状态规则。

详细记录：`verification.json`、`test-results.json`、`capture-index.json` 及各项原始日志。真实多人会话尚未验收；入口与屋顶检查不等于全地图碰撞验收。截图使用 llvmpipe 软件 Vulkan，不能代表硬件帧率。

从仓库根目录运行：

```bash
./artifacts/realism91-preview/Linux/IronMeridian --path /tmp
```

必须保留同目录 `IronMeridian.pck`。这是 Godot 可执行文件加 PCK 的本地预览，非标准导出模板发行包。`artifacts/realism91-preview/README.md` 和 `build.json` 提供运行说明及文件哈希。

## 下一步

优先重塑换弹中连片的掌指、虎口与抓握轮廓，让同机位游戏截图出现主要形体改善，避免持续只增加枪身微细节。随后继续机匣大面材质、人物、建筑/植被与光照，并补真实联网和地图碰撞验收。
