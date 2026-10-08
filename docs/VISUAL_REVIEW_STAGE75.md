# Stage75：掌部拓扑修复与同机位复核

本轮状态 **continue**，形体验收未通过。修复了真实网格问题，但正常游戏视距改善很弱，不能据此宣称第一人称或整体写实目标完成。

## 修改与证据

`tools/build_viewmodel.py` 的掌部截面沿负 Z 排列，原侧面顶点顺序造成法线朝内。本轮反转两手共672个侧面的绕序，封闭四个端面并补端面UV；构建时逐面断言法线朝外。保留既有曲面与动画，重建 `art/first_person.blend`、`client/assets/first_person.glb`。

- [Blender构建日志](../artifacts/realism75-validation/blender.log)：两手各336面法线断言通过，骨骼及动画资产检查通过。
- [五姿势前后对照](../artifacts/realism75-validation/comparison-all-poses.jpg)：stage74在左、stage75在右。
- [换弹掌部放大对照](../artifacts/realism75-validation/comparison-hand-crop.png)。
- 包内原始截图：[腰射](../artifacts/realism75-validation/packaged-forward/weapon-0-hip.png)、[ADS](../artifacts/realism75-validation/packaged-forward/weapon-0-ads.png)、[换弹1/4](../artifacts/realism75-validation/packaged-forward/weapon-0-reload-quarter.png)、[换弹1/2](../artifacts/realism75-validation/packaged-forward/weapon-0-reload-half.png)、[换弹3/4](../artifacts/realism75-validation/packaged-forward/weapon-0-reload-three-quarter.png)。

1280×800实机截图来自独立包，Forward+ Vulkan、llvmpipe软件渲染；固定演员位置(17,0.05,50)、偏航atan2(-18,16)、俯仰-0.03。腰射与ADS采用相同相机位置/朝向，ADS保留设计中的视场变化，每姿势等待90帧。截图采集通过只表示文件生成成功。

## 实际画面判断

腰射和ADS与stage74几乎一致，未见新增瞄准遮挡，红点中心可辨认。换弹中段仍出现平板状掌面、浅色硬边和深色块状皮革区，修正法线没有充分改善轮廓。支撑手指仍像平行弯管，掌面、拇指根与指根连接不自然；袖口较厚，枪体拼装感仍明显。

环境仍存在重复仓库、规则草丛、平坦泥地和稀疏均匀树木。当前画面远未覆盖用户要求的人物、建筑、地形植被和光照整体提升。

## 功能验证与局限

[结果清单](../artifacts/realism75-validation/stage-results.json)列出源码和独立包各七项检查，共14项退出0及原始日志：手套材质、108样本瞄准、183样本换弹接触、抵墙阻挡、第一人称骨骼/动作、武器快照、16演员单机烟测。

武器远端快照检查不等于真实联网。本轮未验证双客户端真实联网、实体GPU或完整人工连续移动碰撞遍历。导入退出0但[导入日志](../artifacts/realism75-validation/import.log)仍有 `ERROR: Parameter "t" is null.`，不能称导入无错误。

本地运行：`./artifacts/realism75-preview/Linux/IronMeridian --path /tmp`。同目录PCK必须保留；[预览说明](../artifacts/realism75-preview/Linux/README.md)、`build.json`哈希与`verification.json`可复核。未发布，保留全部既有修改。

## 下一阶段

重做掌面、拇指根和指根连接结构，并调整连续材质过渡，以正常视距换弹轮廓显著改善为验收条件；不继续仅调半径或增加枪械小零件。保持同相机腰射/ADS/换弹复核及瞄准/阻挡回归。随后继续人物、建筑差异、地表植被、光照和真实联网验证。
