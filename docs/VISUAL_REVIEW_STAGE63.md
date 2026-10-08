# Stage63 霰弹枪形体与材质自审

本轮为执行者实际截图自审，非独立审阅。按stage31要求复核同相机腰射与ADS；没有重复stage29验证。

霰弹枪机匣由圆鼓胶囊改为带倒角的机械切面，增加侧面嵌板和顶部窄条；枪托增加独立托腮与侧面凹槽、连接环。重建 `tools/build_weapon_variants.py` 对应Blender/GLB资源。共享手臂沿用stage62，本轮没有新的手臂形体改善。

## 实际画面

- `artifacts/realism63-validation/shotgun-before-after.png`：stage62/63相同机位腰射与ADS对照；圆鼓黑色机匣变为灰色机械切面，轮廓和材质分界更清楚，但ADS后肩及托腮仍宽大、平板感明显。
- `artifacts/realism63-validation/forward/`：三武器各腰射、ADS、换弹四分之一/二分之一/四分之三，共15张原始截图；`all-poses-review.png`全部缩略图自审。霰弹枪腰射、ADS、换弹一半原图另行查看。未见本次修改新增明显整体错位，瞄准中心保持；不能由静态图推出所有动态接触均无穿插。
- 换弹一半近景显示枪托仍偏大、手指和袖口僵硬；建筑仍为重复矩形仓库，草丛分布均匀，远山和树木欠自然。人物、整体光照和场景真实感未完成。

## 验证与限制

七项回归见 `artifacts/realism63-validation/tests.json`：108瞄准样本、183换弹接触、抵墙收枪、viewmodel、手套材质、武器资源、32入口雨棚/96射线均通过。15帧捕获PASS见 `capture-forward.log`。截图使用源码运行的Xvfb软件Vulkan Forward+，不是实体GPU性能或包体图形验证。

`artifacts/realism63-preview/Linux/` 已导出PCK并附运行文件、许可证、README、哈希、verification.json。在/tmp与独立用户数据目录执行包体单机烟测PASS（16演员，换弹、治疗、伤害、胜利、射线、掩体、射速、骨架），见 `packaged-smoke.log`。没有完整人工移动巡检。

`import.log`保留既有空纹理错误；stage62 Compatibility黑草本轮未解决或复测。`network-probe.json`记录本地8000端口health/protocol/openapi.json均404，真实双客户端联网未验证，未修改服务。

整体状态continue。下一阶段应实质推进仓库用途/体量差异、泥草边界并检验移动碰撞；后续继续宽大武器平面、自然握持、人物和光照，以及导入/兼容渲染与真实联网验证。
