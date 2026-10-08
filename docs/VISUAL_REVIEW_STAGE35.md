# Stage35 — 枪托可见性、SG/SR轮廓与袖口材质

本轮以 stage34 实际文件为起点，落实 stage31 对第一人称武器/手臂的优先要求。整体目标仍未完成，不重复 stage29 验证。

## 改动

- 移除第一人称绑定时隐藏所有 `*Butt*` 节点的逻辑，恢复三武器枪托和肩垫；此前裸露缓冲管并不是完整枪托模型。外观规则新增枪托可见断言。
- SG/SR 枪托从长方体改成折线侧轮廓，增加肩垫、背带孔，SR增加贴腮板和侧面凹槽。保持静态部件合并及四网格结构，重新生成 Blender/GLB。
- 降低手腕绑带基础色，减轻近景袖口发白；不改变瞄准挂点和骨架动作。

## 同机位实图审阅

`artifacts/realism35-preview/capture/` 为最终包三武器各腰射、ADS和换弹25/50/75%共15张。机位及朝向沿用 stage34，ADS保留各武器正常倍率；由外部采集脚本固定动作采样。

对照 `artifacts/realism35-comparison/carbine-hip-ads.png`，汇总 `all-aim.jpg`、`all-reload.jpg`。已查看三武器六张瞄准姿态及九张换弹汇总：

- 卡宾枪后部不再只有裸管，袖口亮斑减弱；腰射武器轮廓更完整。
- 枪托未挡住ADS中心，但近相机的大面积平面十分明显；尤其换弹肩垫仍像矩形板。恢复真实部件可见性暴露了旧模型的体积/材质问题，不能把可见断言通过当作画质达标。
- SG/SR侧轮廓有所变化，但缺少圆角、高光层次和表面细节。SR镜内仍像空圈。
- 手指仍短粗，换弹中段左手没有可靠的弹匣取送接触；静态姿态不能证明连续动画流畅。
- 建筑和百叶窗重复、地表稀疏，远树/山体缺乏层次；本轮未改善人物、建筑或地形。

## 验证和预览

日志目录 `artifacts/realism35-validation/`：瞄准108样本、外观/远端快照/挂点、遮挡碰撞均通过。单机包烟测覆盖16角色、换弹、治疗、伤害、胜利、射线、掩体和射击间隔。快照测试不代表真实联网；此前真实登录HTTP404仍未解决，本轮未重测。

首次导入日志有 dummy texture null 错误；中间 `import-final.log` 无同类报错，但最后的 `import-cleanup.log` 退出0仍记录一条 texture null 错误，不能记为无错误导入。`export.log` 记录官方导出模板缺失导致 release 导出失败；随后成功 `--export-pack`，采用本机Godot可执行程序与同名PCK组成可运行预览，不冒称标准release模板导出成功。

运行 `./artifacts/realism35-preview/Linux/IronMeridian`，保留同目录PCK。最终包从 `/tmp`、隔离用户数据运行，使用 Forward+ Vulkan llvmpipe 采集，不代表实体GPU性能。最终采集日志 `capture-final-{0,1,2}.log`，烟测 `offline-smoke-final.log`，清单 `realism35-preview/verification.json`。

下一步先处理近景枪托/肩垫的厚度、圆角与粗糙度层次，并重做左手换弹接触；保持本轮同机位对照，避免继续累加小细节却保留大块平板。之后推进人物、建筑植被和真实联网验证。未推送或发布。
