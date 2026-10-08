# Stage124：维修库外棚、草高过渡与局部照明

本阶段形成可在正常接近机位辨识的维修库外棚和作业物资，整体目标仍为 continue。新增倾斜金属棚顶、立缝、立柱/斜撑/檐沟及两处向下灯具；中央保留约5.6米通路。建筑周围约7米范围引入带噪声的草高恢复过渡，未增加全图植被密度。

## 实机审阅

证据根目录：`artifacts/realism124-validation/`。before 使用123包，after 使用124包，均从导出PCK加载单机世界，Godot4.4.1 Forward+ Vulkan llvmpipe，1280×800。两次捕获退出0，每次4帧。软件渲染冻结场景采样不能用于帧率验收。

- `west-workshop-approach-comparison.jpg`：屋前新增棚体、细柱与物资可辨认，矩形主体侧墙仍显单调，院落空旷未解决。
- `west-workshop-entrance-comparison.jpg`：棚顶形成真实遮阴，入口贯通；但棚下墙面和第一人称武器偏暗，新增局部灯具效果有限。
- `depot-entrance-close-comparison.jpg`：另一仓库入口保持通畅，地板与箱体仍有材质重复问题。
- `terrain-wide-comparison.jpg`：草高调整影响局部建筑边缘，宽景改善很小；道路过宽、远处建筑重复、山体及针叶树轮廓仍不够自然。不能据截图数量宣称画质达标。

两份 `environment-camera-poses.json` 逐项相等，见 `capture-evidence.json`，同时记录原图SHA256。眼高相对角色原点1.6米；以下角度单位弧度，完整浮点值在JSON中。

| 机位 | 角色原点 xyz | yaw | pitch |
| --- | --- | --- | --- |
| west-workshop-approach | -17, 0.05, 49 | 1.030377 | 0.073611 |
| west-workshop-entrance | -42, 0.05, 44 | 0 | 0.024995 |
| depot-entrance-close | 35, 0.05, 44 | 0 | 0.024995 |
| terrain-wide | 17, 0.05, 50 | 0.422854 | 0.067315 |

## 功能验证与失败记录

`functional-results.json` 记录7项最终通过及退出码0：维修库双向物理通行、原仓库双向通行、108样本三武器瞄准、武器遮挡规则、旧雨篷碰撞、屋顶碰撞、本地网络状态规则。新增测试保存 `west-workshop-traversal.json`：角色沿x=-42从z20/48双向穿过建筑和棚下，到达47.55/20.45；走向棚柱被阻挡；横向射线命中柱体，向上射线命中棚顶。

首次旧雨篷测试失败，断言后进程超时退出124，保留 `entrance_collision.log` 与 `test-results.json`。原因是新棚顶低于原雨篷，旧射线先击中新棚顶。测试起点改到旧雨篷紧邻下方后，32个雨篷、96条射线通过，见 `entrance_collision-corrected.log`。新增棚顶碰撞由独立测试覆盖，未移除碰撞以迁就断言。

本轮未重新执行完整战斗回合或第三人称连续动作；本地网络规则不代表真实认证联机通过。既有授权fixture缺失仍使真实联网验收未完成。

## 当前预览与后续

本地可运行包：`artifacts/realism124-preview/Linux/IronMeridian` 与同目录PCK；README提供启动命令，build.json记录包和本轮代码/测试哈希，已核对。包已用于上述实机截图。未推送或发布，保留所有未提交修改。

下一阶段优先改宽景可见的道路边缘用途、建筑差异及植被分布，并修正棚下曝光，保持相同机位和入口通行回归。结合无遮挡第三人称连续动作与第一人称近景继续处理袖子折面、霰弹枪装填、独立弹匣接触及蹲姿。人物、武器、全局环境和真实联网均仍有未完成项。
