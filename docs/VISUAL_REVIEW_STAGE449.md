# Stage449：右掌整体贴合修正与当前包复测

状态：continue，整体画质目标未完成。本轮没有修改环境；stage446 道路修复只作为检查点背景，不作为当前环境全项通过。

## 修改与预览

`tools/build_viewmodel.py` 调整右手整体掌指与手套的变换：目标轴向由 `z*.60+.049` 改为 `z*.40+.023`，沿既有权重向固定腕口过渡。重新生成 `art/first_person.blend`、`client/assets/first_person.glb`，重新导入并导出当前包。

预览：`artifacts/realism449-preview/Linux/launch.sh`。
PCK SHA256：`3b981900de80e81082913e8132f6477364c4584d987b5e1a537112e7425337ed`。
完整输入指纹见 `artifacts/realism449-preview/provenance.json` 和各测试的 `process-result.json`。

构建和导出退出 0。导入也退出 0，但 `import.log` 有 dummy renderer 的 `Parameter "t" is null / texture_2d_get` ERROR；不能称导入无错误。当前 Forward+ 实机截图可见枪械、衣物及地面纹理。

## 当前包已验证

- 完整四姿势运行未传 `--pose`：正常持枪、ADS、换弹中段、换弹完成全部生成并逐张审阅。`poses-full/process-result.json`：750.912 秒、退出 0、passed=true；换弹后 30/119。相机位置 `(0,1.60036444664001,90)`、朝向 `(0,0,0)`，1280×800。
- 其他武器及第三人称四张截图全部生成并逐张审阅：SG、SR 换弹中段与第三人称站立/蹲姿。`contacts/process-result.json`：878.696 秒、退出 0、passed=true。这是捕获完整性通过，不是人物画质或动作自然度通过。
- `functions/aim-process.json`：当前包退出 0，六项三武器命中/遮挡检查通过。
- `functions/building-process.json`：当前包退出 0，三个建筑通行路线双向共六项及两侧墙体射线阻挡检查通过。只覆盖测试列出的入口与墙段，未证明全地图碰撞。
- `functions/offline-process.json`：当前包退出 0，`OFFLINE_SMOKE_PASS`，16 actors，reload/heal/damage/victory/raycast/cover/fire_interval/rig 通过。

以上证据均在 `artifacts/realism449-validation/`。未运行需要认证的联网测试，不能把旧版本联网验证算作本包通过。

## 画面判断

`default-before-after.png` 的右手被枪托遮挡，不能证明贴合修复。`sg-before-after.png` 同机位裁切显示 SG-8 右掌与握把间隙缩小，但掌指仍呈钩片形，缺乏包握体积；仅局部贴合改善，手部形体问题未解决。

AR 换弹中段也可见右掌薄片和左手圆块式包握；袖口偏宽、前臂偏细。`ar-motion-contact-sheet.png` 展示 0、0.4、0.8、1.2、1.6、2.2 秒的取弹匣与回位。采样用于发现缺陷，不证明连续动作自然。

`sr-before-after.png` 显示右掌后方三角空隙变小，但钩片形及空隙仍存在。第三人称肩胸分段生硬、面部和靴子简化，蹲姿膝盖遮挡部分换弹接触；远处角色有悬空观感，单帧不能诊断碰撞原因。`contact-camera-comparison.json` 确认四张接触截图与448相机位置/朝向一致：第三人称位置 `(2.79999995231628,1.50010251998901,65)`、朝向 `(-.133232831954956,2.39066362380981,0)`。

动作任务未通过：`motion/process-result.json` 记录 KeyboardInterrupt、子进程退出 -15、734.343 秒；中断根因未确认，不记为超时或通过。保留56张：AR23张、SG31张、SR仅2张，六段第三人称动作均缺失。`motion/recovery-audit.json` 明确证据不完整；`motion/viewer.html` 可查看10Hz采样，但本轮未交互播放。`sg-motion-contact-sheet.png` 的0至3秒选帧仍见换弹时右掌空隙和细前臂。动作采样采用640×400、关闭阴影并裁去远景细节，仅用于接触诊断；缺少帧间连续运动、真实移动输入、站蹲过渡和网络动作证据。

四姿势背景仍有光滑尖锥山体、重复树冠、宽阔空旷道路及突兀场地边缘。当前相机没有显著横贯道路的硬矩形色块，但没有重新采集建筑入口近景、宽幅地形和环境前后对照，因此环境验收仍未完成。

## 下一阶段

不要连续微调握把、手指或色值。优先结构性修改山体轮廓与坡面，先分析重复尖锥和光滑坡面的成因，再保存相同相机的前后对照、建筑入口近景及宽幅地形截图，复测单机通行。保留人物肩肘/袖口/护木/换弹接触、第三人称动作、建筑室内光照、植被分布及联网功能目标。
