# Stage85 — 袖子体积、压褶与腕部过渡

本轮基于stage84，修改 `tools/build_viewmodel.py` 并重建 `art/first_person.blend`、`client/assets/first_person.glb`。提高前臂截面的厚度，减弱连续细折线，加入五组斜向宽压褶；袖口最后10%长度平滑收束到腕部。本轮没有修改材质贴图或手部接触变换。

## 实机画面

- `artifacts/realism85-validation/sleeve-before-after.jpg`：stage84/85同机位腰射及换弹四分之一时刻对比。
- `artifacts/realism85-validation/packaged-aim-pairs.jpg`：导出包腰射/ADS。
- `artifacts/realism85-validation/packaged-reload-poses.jpg`：导出包换弹25%、50%、75%。
- `artifacts/realism85-validation/source-forward/`、`packaged-forward/`：各5张1280×800原图；路径、SHA256、相机信息见 `capture-status.json`。

实际审阅以上画面：袖子比此前扁平长管更饱满，换弹时腕部压褶和收束可辨。ADS袖子处于画面下沿，未遮挡红点视野。三个换弹时刻未见明显袖口开裂；手套和腕掌交界仍显简化，不能据此认定接触外观完成。腰射/ADS使用相同世界位置、朝向，ADS保留游戏正常视场缩放。

布料仍有大块均匀橄榄色，压褶有些像软塑料，枪身偏暗且机匣厚重；背景仓库重复、草丛分布过均匀、远山平滑。本轮是局部形体改善，整体写实目标未完成。此次视觉采集仅卡宾枪，另外两种武器尚需在新袖子下补充实机审阅。

源码和包内采集均退出0且输出5帧PASS。对应帧平均绝对RGB差各通道约0.068—0.298（0—255），视觉布局一致但不是逐像素相同。渲染器为Forward+ Vulkan llvmpipe，不能证明实体显卡性能。

## 功能与预览

`artifacts/realism85-validation/test-results.json`记录源码及包内各6项、共12项退出0且PASS：瞄准（每次108样本/3武器）、换弹接触（每次183样本/3武器）、近墙遮挡、视模规则、武器视觉规则、单机烟雾测试。日志未出现FAIL/ERROR标记。remote_snapshot仅进程内检查，真实联网未运行；近墙规则和单机射线检查不等于全地图碰撞验收。

Blender生成、Godot导入、PCK导出均退出0，日志分别为本轮validation目录下 `build-viewmodel.log`、`import.log`、`export.log`。导入仍记录dummy/storage/texture_storage.h:107的Parameter t is null错误，未作为无错误导入报告。

本地Linux x86_64图形桌面预览：

```bash
cd /home/ec2-user/project/fpsgame/artifacts/realism85-preview/Linux
./IronMeridian --path /tmp
```

保留同目录PCK；README、build.json、verification.json提供运行说明、校验与证据。缺少标准导出模板，采用Godot 4.4.1可执行文件+PCK，包内实际截图及测试已完成。未push或发布。

下一步：补查另外两种武器的新袖子腰射/ADS/换弹，然后推进仓库入口与道路边缘的建筑变化、地表植被层次，多机位截图复核；继续人物、光照、真实联网与更广地图碰撞验收。状态continue。
