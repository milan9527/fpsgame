# Stage437：前臂整体截面修改与当前包四姿势复验

整体目标未完成。本轮承接436道路/场地同机位审阅，转入人物前臂结构；没有把旧环境图计为437环境通过。

## 修改和实际观感

修改 `tools/build_viewmodel.py` 的整段前臂截面：降低中段鼓胀，延缓远端收窄，减小弯曲偏移，用圆角布料截面代替完全椭圆截面。肘端、袖口端尺寸和骨骼接触锚点保留。重建 `art/first_person.blend`、`client/assets/first_person.glb` 后导出当前包。工作区已有大量未提交修改，不能将整个 Git diff 都归于本轮。

实机四姿势前后图：`artifacts/realism437-validation/review.html`。左436、右437，相机元数据完全一致：角色 `(0, 0.0003644675, 90)`，相机 `(0, 1.6003644466, 90)`，yaw/pitch 为0；分辨率1280×800，Forward+。

- 默认持枪：袖管中段鼓胀减少、轮廓较直；长锥形前臂和厚重手套仍不自然。
- ADS：武器遮挡护木及手部接触，画面不能充分证明接触自然；下缘仍有宽大锥形袖管。
- 换弹中段：右前臂的圆鼓轮廓有所缓解，但仍显得过长、僵硬；左手持弹匣，手套与袖口连接偏厚。肩肘在镜头外，不能据此验收。
- 换弹结束：恢复持枪，弹数30/119；整体比例问题仍在，结束姿势不能证明连续插拔接触正确。

场景中仍可见空旷道路、重复裂纹、尖峰生硬和光滑远山、重复树冠、盒状建筑。本轮改善有限，不视为整体画质完成。

## 当前包验证

预览：`artifacts/realism437-preview/Linux/launch.sh`。
PCK SHA256：`408bc70c04111a2e280c2145df73e7a2ca94f8c6d449fabb6b17958299a1556b`。
来源和文件哈希见 `artifacts/realism437-validation/build-manifest.json`。

完整四姿势命令未使用 `--pose`，正常退出0，753.031秒，四张PNG均已审阅。见 `poses/process-result.json`、`evidence-audit.json` 及四组 `*-comparison.jpg`。

当前导出包八项检查正常退出0：

| 检查 | 证据与范围 |
| --- | --- |
| sleeve_reach_review | 606项肩肘/前臂测量 |
| reload_contact_rules | 三武器201项接触、594项前臂长度及中断/恢复规则 |
| aim_alignment | 三武器108样本，后坐、倾斜与射线 |
| entrance_collision | 32处入口遮棚、96条下方射线 |
| depot_traversal_review | 四条双向单机路径、两处护栏 |
| road_verge_traversal_review | 五处地面及路肩跨越 |
| aim_damage_review | 三武器各无遮挡/遮挡射击，六次伤害与弹数检查 |
| combat_rules | 蹲姿、低顶、掩体、后坐、散布及动作编码规则 |

退出码与耗时见 `functional-results.json`、`combat-results.json`，对应 `.log` 保留。初次缺少输出目录环境变量的检查被中断，单独记录在 `functional-initial-interrupted.json` 和 `*-initial.log`，不计通过。

Blender构建、Godot导入和导出退出0。Blender验证修复重复手部三角形后通过拓扑断言；无显示导入日志含 dummy texture 空参数信息，实际Forward+截图正常生成。不能因此声称所有渲染问题消失。

## 动作采样仍在运行：不能验收九段

截至2026-09-19 02:00 UTC，已有第一人称武器0的23帧、武器1的31帧，以及武器2的前2帧。已审阅前两武器采样表：手臂随武器倾转仍显僵硬；弹匣下降后回位，但部分手指、弹匣口和护木接触被遮挡或尺寸太小，不能据此判定自然。

运行命令：

```sh
python3 tools/run_weapon_motion_review.py \
  --preview /home/ec2-user/project/fpsgame/artifacts/realism437-preview/Linux/IronMeridian \
  --output artifacts/realism437-validation/motion \
  --compatibility-diagnostic --cull-distant-details --timeout 3000
```

此轮结束时保留采集进程继续执行，其包装器PID为2024998、游戏PID为2025195（PID仅供恢复时核查命令，不可盲目复用）。先检查 `motion/process-result.json` 和 `motion/capture.log`，不要并发重复启动。当前记录为running，并非通过；后续以终态记录为准。若超时，应保留失败和部分截图，不计完整动作通过。

动作模式为640×400兼容渲染、关闭阴影、裁剪远处细节，固定模拟步进每6帧采一图；播放器 `motion/viewer.html` 是10Hz采样回放。该证据不代表完整光照、实时交互性能或未采样间隙的连续运动。六段第三人称站姿/蹲姿尚无本轮审阅结论。采集结束后重新运行 `build_review.py` 和 `tools/build_motion_review_viewer.py` 更新图表，再审阅九段及接触关键原图。

## 下一阶段

先接续当前动作采集和第三人称肩肘、身体配合审阅，再选整体腕部/前臂比例或第三人称躯干参与换弹的结构修改；不要继续用接缝、手指或机匣微调替代人物整体改善。还缺其他武器ADS、移动中换弹、切枪/打断的实机连续证据。

437没有新增入口近景、宽幅地形同机位前后图，436环境结论仅作追查背景。本轮规则和单机自动路径不代表完整单机流程、真实联网或交互性能通过；未运行真实联网、未读取认证密钥。建筑空间、地形植被、光照及以上功能验证继续保留。未提交、推送或对外发布。
