# Stage98：机匣截面、袖管与掌背形体

本轮状态 **continue**。第一人称形体有局部改善，仍未达到整体写实画面目标。

## 实施

- 收窄卡宾枪上机匣肩部截面，调整合金和边缘材质底色，使斜面更容易分辨；保持瞄准锚点、导轨和侧凹槽结构。
- 重塑袖管半径分布、压扁比例和弯曲轮廓，减弱直筒外形；压平掌背，保留腕部连接和现有手指绑定。
- 重建两个 Blender 源资产及对应 GLB。右手减面后出现一处重复三角形，新增导出前网格校验清理；最终保存资产再次校验通过。早期诊断保留在 mesh-diagnostic.log，修复后的构建与校验见 build-viewmodel.log、final-mesh-topology.log。

## 实际画面观察

采集脚本固定角色位置 (17, 0.05, 50)、朝向 atan2(-18, 16)、俯仰 -0.03，并冻结场景物理；腰射与 ADS 使用各自正常视场角。stage97-98-viewmodel-comparison.png 对比相同世界机位的原尺寸裁切。

卡宾枪 ADS 上机匣肩线变窄，灰蓝色金属斜面较容易辨认，但枪身仍显得大块、硬直。腰射改善较小；袖管略扁且弯曲更明显，依然缺少自然布料褶皱和袖口层次。换弹中段抽查未见明显腕部断开，但握持手指厚重、指腹接触粗糙，不能据此宣称完全没有穿插。

场景依旧存在相似仓库、屋顶附件重复、植被成簇和大片裸地。人物与更广泛地形、建筑、光照没有在本轮得到实质改善。下一轮应重构手指包握、虎口和袖口层次，避免继续仅调整颜色或小参数。

## 验证与本地预览

本轮记录位于 artifacts/realism98-validation/；最终通过数量及文件哈希以 verification.json、test-results.json、screenshot-index.json 为准。源码和预览包分别执行武器材质、手套表面、瞄准、换弹接触、枪口遮挡、第一人称绑定、武器显示、单机冒烟、入口碰撞、屋顶碰撞、网络状态规则检查。

最终源码与包内各11项功能检查通过，共22项；加导出及两次截图采集共25条成功记录。核对30张截图及11个构建文件哈希，git diff --check通过。已审阅源码与包内各15姿态总览，以及卡宾枪腰射、ADS和换弹中段原图；总览未见新增明显腕部断裂，其他两把枪仍保留粗重轮廓。首次驱动在包内采集中以143退出，保留driver.log；随后以--resume保留24条已通过记录，仅重跑未完成的包内采集，resume.log对应驱动退出0。

网络状态规则是本地逻辑测试，不能替代真实多人连接验证。导入退出 0 仍报告 dummy texture storage 的 `Parameter "t" is null`。实际截图使用 Forward+ / llvmpipe 软件 Vulkan，不能代表硬件 GPU 性能。

在图形会话中从项目根目录启动：

```sh
./artifacts/realism98-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus
```

保留同目录 IronMeridian.pck。这是 Godot 可执行文件加导出 PCK 的本地预览，运行方法及构建哈希见 artifacts/realism98-preview/README.md、build.json。未推送或发布；保留所有已有未提交修改。
