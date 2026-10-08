# Stage79：换弹朝向与握持可见性

本阶段继续处理stage78提出的枪托遮挡和弹匣握持构图。整体目标仍为 **continue**；本轮只改善动画姿态，没有重建人物、武器网格或材质，不代表写实画面已经达标。

## 实现

- `client/scripts/first_person.gd`：保持换弹平移与原有俯仰、滚转，增加峰值0.35弧度偏航，让机匣和枪托侧面进入视野；弹匣最大下移从0.32缩至0.22，减少持弹匣手在屏幕底部被裁切。
- `tests/viewmodel_rules.gd`：可见弹匣分离阈值相应从0.25改至0.18；详细抓握接触继续由未放宽的reload_contact_rules验证。腰射、ADS目标位姿未改。
- 曾尝试更大的前移和倾转，但实际截图露出袖子端面，已撤回。失败姿态的包、日志和截图归档在 `artifacts/realism79-validation/rejected-forward-pose/`，不得当作最终验证。

## 实际截图审阅

最终源码及预览包均以实际单机游戏、同一相机位置和卡宾枪生成腰射、ADS、四分之一、二分之一、四分之三换弹截图，每张1280×800。运行环境是Xvfb、Forward+、llvmpipe软件Vulkan，截图脚本冻结游戏进程并驱动姿态；不等同于人工连续游玩或实体GPU测试。

- 最终图片：`artifacts/realism79-validation/source-forward/` 与 `packaged-forward/`。
- stage78/79相同相机对比：`comparison-all-poses.jpg`；半程固定范围放大：`comparison-hand-crop.png`。源码五姿态另存 `source-all-poses.jpg`。
- 已查看两套五姿态拼图及包内半程原图。腰射和ADS未见新增遮挡或明显瞄准构图退化。换弹半程枪托由近乎正对镜头转为侧面，三角结构更清楚；持弹匣手较完整地留在画面内，最终姿态未见试验版本的袖子端面外露。
- 仍有明显不足：掌面像扁平硬壳，腕部与袖口过渡不自然；枪托、握把比例和聚合物表面较粗糙。弹匣仍被手遮挡较多，动作仍属程序驱动而非完整自然手部动画。建筑重复、地表空旷、草丛分布规则，远树和雾层缺乏自然层次；人物画质本轮未复核。

## 验证与预览边界

检查明细以 `artifacts/realism79-validation/test-results.json` 为准，覆盖源码和包内的手套材质/UV、108个瞄准样本、183个抓握接触样本、枪口遮挡、视图模型状态、三种武器视觉结构、32个雨棚/96条射线以及单机冒烟。remote_snapshot检查不等于真实联网。

源码截图写出五张且报告PASS后，工具会话返回143，终止原因未确定；不宣称源码截图正常退出。首次测试调度也返回143，已保留前11项完成结果，仅续跑剩余检查，日志在verify-resumed.log。包内最终截图报告五帧PASS且退出0。详情见capture-status.json。

本地启动：

```sh
./artifacts/realism79-preview/Linux/IronMeridian --path /tmp
```

环境缺少标准Linux release导出模板，标准导出失败记录在export.log；最终以仓库Godot可执行文件和export-pack的PCK组成预览，export-pack退出0。预览目录包含README、构建哈希与验证清单。本次export-pack日志未出现ERROR；历史导入空纹理参数错误未复测，不能视为已修复。

真实认证联网、实体GPU性能与完整人工移动碰撞仍未验证。本轮未读取认证密钥、未发布或推送。下一步应实质改进掌面/腕部形体，检查其他武器的实际画面，再推进建筑差异、植被光照及真实联网验收。
