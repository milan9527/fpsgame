# Stage95：分节拇指形体与同机位审阅

## 本轮改动

`tools/build_viewmodel.py` 将拇指中心线改为分段插值，支撑拇指使用四个控制点，收窄近节中段、压平指腹并加入关节截面收折；手部体素合并后的平滑迭代由5次减至2次，避免抹平转折。重建 `art/first_person.blend` 与 `client/assets/first_person.glb`。这不是完整手部或枪械重制。

## 快速实机审阅

`artifacts/realism95-validation/quick-forward/weapon-0-hip.png` 与 `weapon-0-ads.png` 为本轮实际 Forward+ 游戏截图。同一测试相机位置与朝向，腰射和ADS各自使用游戏原生FOV。

支撑拇指比stage94连续圆弧管状轮廓更薄、有可辨转折；ADS中央瞄准区域仍清晰。但拇指仍偏细长，接近硬条，掌面仍厚，袖子仍是光滑筒状。枪身表面分区、磨损尺度及环境重复度的问题仍未解决，不能宣称整体写实目标完成。

## 验证范围

完整验证及包内截图结果见 `artifacts/realism95-validation/verification.json`、`test-results.json`。源码与包内各10项功能检查通过，另有导出及两次截图采集通过，共23条成功记录。截图脚本固定相机，覆盖三把武器的腰射、ADS和三个换弹采样姿态。静态采样不证明整个动画无穿插。

导入进程退出0，但仍记录 `Parameter "t" is null`，不视为无错误导入。网络状态规则不等于真实多人连接验证；入口与屋顶测试不覆盖全地图碰撞。Forward+ 使用llvmpipe软件Vulkan，不代表硬件帧率。

## 下一步

下一阶段应成组调整掌面、虎口、指腹接触面及袖子褶皱，让抓握整体合理，避免继续只微调拇指。还需实质改进枪械材质与结构、人物、建筑、地形植被和光照，并补真实联网及更广泛的碰撞检查。当前状态为continue。

## 原图补充观察

`stage94-95-hand-comparison.png` 使用两个阶段相同区域的原生像素裁切，未放大、未修图。对照显示本轮主要改变拇指截面与转折，枪械和场景外观基本沿用此前状态。

已查看源码步枪 `source-forward/weapon-0-reload-half.png` 全图：换弹中段左手持弹匣，右手握持枪械，厚掌面、袖子体积和偏平的枪身材质仍显人工生成感。姿态检查通过也不能代替解剖形态与材质质量审阅。

已查看源码与包内各15张截图的总览（`source-forward-contact.jpg`、`packaged-forward-contact.jpg`），三武器腰射、ADS及换弹采样均可见，瞄准中心未见手部遮挡。总览仍显示光滑筒状袖子、平板感枪身与重复草丛；总览检查不等于逐张原图的精细穿插检查。另保留2张快速原图，共32张原始截图，索引见 `screenshot-index.json`。

当前预览为 `artifacts/realism95-preview/Linux/IronMeridian` 与同目录PCK，运行方法见预览目录README；已校验 `build.json` 中全部六个文件哈希。功能规则通过、预览可运行，但真实联网及整体画质目标未完成。
