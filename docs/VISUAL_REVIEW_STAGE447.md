# Stage447：前臂结构与当前包验证

状态：本轮收尾，验证不完整，整体写实目标未完成。本阶段承接 stage446 道路/场地过渡修改，转入人物审阅；未用旧环境截图判定当前版本环境通过。

## 修改与预览

`tools/build_viewmodel.py` 将均匀管状前臂改为肘侧较丰满、腕侧收窄的连续截面，加入非对称肌肉轮廓，取消方形截面；保持腕部、武器锚点与动作骨架不变。已重新生成 `art/first_person.blend` 与 `client/assets/first_person.glb`。这次只解决部分轮廓问题，不代表握持与换弹动作完成。

本地启动：`artifacts/realism447-preview/Linux/launch.sh`。缺少 export-release 模板，改用成功导出的 PCK 加同版本 Godot 可执行文件；见 export.log、export-pack.log 和 provenance.json。当前 PCK SHA256：`511cba94d63d62d92fc12152ca33fbbff4952be4ceee0e76dfdcc4a2a69eafe7`。

## 实机审阅与边界

SG08 换弹中段实机截图 `contacts/weapon-1-reload-50.png` 已审阅：前臂有收放，但袖口仍显厚重，右掌与握把之间的空隙及手指朝向不自然仍明显。不能由前臂造型改善推断接触问题已解决。背景树冠重复、山体光滑的问题仍可见。

默认出生视角 `poses-full/default-spawn.png`：前臂肘侧到腕侧已有渐缩，但护木下方手掌与厚袖口仍像分离的团块。道路远景的横向硬色带不再主导画面，笔直宽路和重复尖峰山体仍使场景空旷、人工感强。相机位置 `(0, 1.6003644, 90)`，yaw/pitch 均为 0，1280×800；这不是入口近景或相同机位环境对照的替代证据。

源码交叉检查：`first_person.gd::bind_weapon` 按枪型设置瞄具和弹匣；右手目前没有对应每种武器的握把锚点约束。`place_reload_hand` 主要将左掌参考点约束到弹匣侧面，单个参考点误差不能验证手指包覆和腕部自然。这是下一阶段应处理的结构性问题，尚未在本阶段改变。

四姿势任务使用完整列表（未传 --pose），另有其他两种武器及第三人称站立/蹲伏换弹中段任务。最终覆盖以本目录测试结果和图片清单为准，不能将启动命令当成完成证据。

连续动作诊断使用 640×400 Compatibility、关闭阴影并裁剪远处细节，仅用于时序和接触排查，不能验收 Forward+ 画质。固定 60Hz 模拟、每 6 帧抓图，不覆盖真实输入、移动换弹、网络动作和采样间穿插。

## 当前包功能结果

- 三种武器瞄准无遮挡命中/遮挡不命中：6 个用例通过，`functions/aim-process.json`。
- 可进入建筑双向通行及墙体拦截：通过，`functions/building-process.json`。
- 道路边缘通行：通过，`functions/shoulder-retry-process.json`。
- 综合单机烟测重试通过：16 actors，reload/heal/damage/victory/raycast/cover/fire_interval/rig 检查通过，`functions/offline-retry.log` 和 `offline-retry-process.json`，退出码 0。首次四姿势及部分功能任务受到进程终止，保留原日志；原因未确认，不能将这些首次尝试记为通过。截图任务最终中断状态已落盘，均不得计为通过。
- 本轮尚未复测联网；环境相同机位对照、入口近景和宽幅地形属于 stage446 证据，未作为本轮验收。

## 下一步

先补齐本轮未完成的四姿势、其他武器和第三人称证据，再按实机缺陷建立各武器握把/护木接触锚点并调整腕部与肩肘链，审阅完整换弹取出、交换、插入和恢复握持过程。随后推进地形轮廓、树冠结构分布、建筑内部与光照；保持单机、联网、瞄准和碰撞验证目标。

## 本轮最终覆盖与复审

- 四姿势完整任务（无筛选）重试在 597.116 秒中断，exit -15，仅默认与 ADS 两张；首次中断也保留在 poses-interrupted。缺少 reload-middle/reload-complete，完整四姿势未通过。
- ADS 原图及 446/447 姿势对照已审阅：前臂渐缩变化有限，瞄具中心视野未被手臂遮挡，但袖口厚度与手掌团块仍明显；旧版本换弹图所在对照格不能替代当前缺失图。
- 其他武器/第三人称任务 827.129 秒中断，exit -15。SG08、SR5 中段两张已审阅，均存在右掌离开握把；SR5 枪托/瞄具轮廓膨大，左手手指挤团。第三人称站/蹲未捕获。
- 连续动作任务 946.37 秒中断，exit -15/KeyboardInterrupt。partial 文件实际 51 帧：AR30 23、SG08 28；SR5 与全部第三人称未覆盖。已审阅 AR30/SG08 各八帧联系表，见抬枪、弹匣下降与回插、恢复握持中的机械手形及接触空隙；未播放连续视频，不能证明连续动作自然。viewer.html 与 recovery-audit.json 明确保留 INCOMPLETE 状态。
- 上述终止原因未确认，无继续运行的本轮捕获包装器。没有将进程中断归因于游戏错误或声称测试通过。
- 汇总：artifacts/realism447-validation/evidence-index.json；缺失格标明 NOT CAPTURED，sheet-source-inventory.json 列出实际图片覆盖。
