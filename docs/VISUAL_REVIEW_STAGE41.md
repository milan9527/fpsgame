# Stage41 — 武器表面材质区分

本阶段继续，未达到整体写实目标。沿用stage40形体与目镜，在三武器运行时材质上区分涂层金属、拉丝零件、聚合物和橡胶；未修改手臂几何。`client/scripts/world_visuals.gd` 为材料创建缓存副本，按类别配置金属度、粗糙度纹理与微表面法线，并覆盖SG/SR composite及带Blender数字后缀的肩垫材料。共享源材质不直接改写。

## 实机审阅

使用本轮独立引擎+PCK，外部截图脚本 `tests/weapon_review_capture.gd`。三次独立Xvfb进程均退出0，各保存两帧，无ERROR。固定角色位置(17,0.05,50)、朝向与俯仰；同一武器各阶段腰射/ADS分别对照，ADS保留原有FOV变化。原图均为1280×800，路径 `artifacts/realism41-preview/capture/weapon-{0,1,2}-{hip,ads}.png`。六图已通过三张stage40/41同机位对照审阅，AR腰射另查看原图；对照位于 `artifacts/realism41-comparison/weapon-{0,1,2}-pairs.png`。

- AR：腰射时涂层机匣、较亮的小金属件与暗色枪托区分更清楚；ADS准星位置未见变化。长方机匣和平整大面仍显简化。
- SG：腰射的棕色复合枪托与灰色金属机匣更易区分；ADS环形照门保持位置。顶部仍偏光滑，微纹理在正常游戏距离不明显。
- SR：腰射枪机及ADS旋钮金属反光更明显，绿色枪托保持非金属观感；镜内分划位置未见变化。镜片边缘偏雾状，主体仍缺少真实结构细节。

手指仍没有真实包握，本轮未改善其形体；建筑重复、规则草丛、平滑山丘和平淡光照仍明显。程序微纹理不等于完整PBR贴图制作，也没有完成近似和平精英的整体画面。

## 验证与预览

日志目录 `artifacts/realism41-validation/`：

- `weapon_finish_rules.log`：3模型22表面，类别覆盖、非金属参数、源材质隔离及缓存通过。首次测试错误地要求肩垫材料名称完全一致，遇到Blender数字后缀断言失败；改为前缀检查后退出0。初次失败日志单独保留，未删除。
- `weapon_visuals_rules.log`：本地/远端快照外观、挂点、镜片对齐和缩放通过；不是实际联网测试。
- `aim_alignment.log`：108瞄准样本通过。
- `reload_contact_rules.log`：183换弹接触样本通过；本轮没有新增换弹截图。
- `weapon_obstruction_rules.log`：遮挡、弹药权威、低持枪、蹲姿及恢复规则通过。
- `packaged-smoke.log`：包内单机16角色、换弹治疗伤害胜利、射线掩体与射速通过。

以上最终测试均退出0；导入和PCK导出退出0。`capture-{0,1,2}.log`各有两帧PASS。截图使用Forward+ / llvmpipe软件渲染，不能证明实体GPU性能。真实联网此前HTTP404尚未解决，本轮未重测；没有重复stage29验证。

当前本地入口 `artifacts/realism41-preview/Linux/IronMeridian`，需相邻PCK。README、build.json、verification.json保存说明、文件哈希及截图清单。这是开发引擎+PCK预览，缺少release导出模板。保留全部未提交修改，未推送或外部发布。

下一阶段优先手指包握/拇指与护木接触的实际形体，同机位检查三武器腰射、ADS和换弹；之后继续人物、建筑地形植被光照，并补真实联网验证。
