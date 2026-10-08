# Stage87：霰弹枪后部形体与材质映射

延续stage86检查点，按stage31反馈优先改善第一人称武器，并检查相同相机下腰射和ADS。整体目标仍为continue；未重复stage29验收。

## 改动与实际画面

`tools/build_weapon_variants.py`重新定义霰弹枪枪托截面：收窄颈部、下沉托底，降低并收窄独立贴腮垫，调整肩垫及背带座位置。枪托使用共享聚合物材质，贴腮垫使用橡胶材质，并为共享材质烘焙之后生成的霰弹枪变体网格补上按尺寸投影的UV。重新生成`art/shotgun.blend`和`client/assets/shotgun.glb`。本轮未改变手部骨架、握持锚点、瞄具位置或动作规则。

实际游戏截图前后对照：`../artifacts/realism87-validation/shotgun-before-after.jpg`。腰射右下角的大块斜面缩小，枪托与机匣之间的细颈更清楚；ADS底部宽楔形占屏减轻，准星仍居中。颈部表面可见粗糙度与颜色变化，但下方贴腮面依旧较平，金属机匣仍显方厚。这是可见的局部改进，不代表整把武器达到写实标准。

袖料沿用stage86，腕掌过渡和短圆手指仍需调整。本轮未修改手臂几何，不能将武器修改计作手部问题已解决。背景仓库重复、植被排列及远山材质仍偏简化，环境、第三人称人物与光照需要后续实质改进。

## 截图方法与验证边界

Godot 4.4.1 Forward+ Vulkan llvmpipe，1280×800，固定玩家位置(17,0.05,50)、yaw=atan2(-18,16)、pitch=-0.03。三武器各采集腰射、ADS、换弹25%/50%/75%五个姿态；ADS保留游戏自身视野变化。采集脚本冻结场景并设置动作时刻，属于实际游戏渲染姿态采样，不是手动连续游玩或硬件帧率验收。

Blender构建、Godot导入、PCK导出均退出0。导入仍记录已有`Parameter "t" is null`（dummy/storage/texture_storage.h:107），详见`../artifacts/realism87-validation/import.log`，本轮未修复。

真实联网未运行，进程内remote_snapshot检查不能替代联网验收。现有近墙遮挡、射线与掩体规则也不能替代全地图碰撞遍历。标准Linux发布模板不可用，预览采用Godot可执行文件与导出PCK。

## 验证结果与会话异常

源码和包内各执行瞄准对齐、换弹接触、近墙遮挡、视角模型规则、武器视觉规则及单机冒烟六项检查，12个测试子进程均退出0；两套分别覆盖108个瞄准样本、183个接触样本和16个单机角色。结果及各日志见`../artifacts/realism87-validation/test-results.json`。外层验证会话在结果全部落盘后返回143，原因未知，已单独记录`runner-status.json`，不能将外层会话报告为正常结束。

源码截图采集退出0并报告15帧。首次包内采集返回143，只保存14帧；随后完整重采第三把武器五个姿态，退出0并报告5帧。最终包内15张由首次前两把武器10张及补采5张组成，保留原始中断日志。30张截图的尺寸、哈希、采集日志及返回码见`../artifacts/realism87-validation/capture-status.json`。

已查看源码和包内的`source-aim-pairs.jpg`、`packaged-aim-pairs.jpg`、`source-reload-poses.jpg`与`packaged-reload-poses.jpg`（均在该验证目录）。同相机腰射/ADS形体一致，换弹采样未见明显整只手脱节，但腕部仍呈管状，手指偏圆，枪托肩垫仍较厚。对应截图的各RGB通道平均绝对差为0.113–0.626（0–255尺度）；画面接近，并非逐像素相同。这些静态采样不覆盖完整连续动作。

## 本地预览

仓库根目录运行：`artifacts/realism87-preview/Linux/IronMeridian --path /tmp`，保留同目录`IronMeridian.pck`。启动后在主菜单选择单机。说明、输入及产物哈希见预览目录`README.md`、`build.json`；七个哈希核对结果保存在`../artifacts/realism87-validation/build-hash-check.json`。

未push或发布，保留工作区原有修改。

## 下一阶段

优先改造手套腕掌过渡和指节形体，并继续检查三武器腰射、ADS与换弹；随后增加环境机位，处理仓库入口、道路边缘与植被分布。真实联网、人物、光照和更广地图碰撞仍是整体目标的未完成项。
