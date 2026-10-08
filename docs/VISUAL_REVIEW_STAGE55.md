# Stage55 — AR机匣材质分层与同机位实拍自审

日期：2026-09-13。此文为开发进程自审，不是独立审阅。整体目标未完成。

## 本轮变更

- AR上、下机匣改用独立阳极氧化铝材质，上机匣增大三段倒角并分配较亮的边缘材质；侧肩加厚，切出真实面板凹槽。
- 运行时为机匣及边缘分别设置金属度、底色和粗糙度范围，保留微法线与材质缓存隔离；补充材质覆盖断言。
- 重建 `art/carbine.blend`、`client/assets/carbine.glb` 并导出当前预览。本轮手臂沿用stage54，只复核姿态和材质，没有新增手臂形体修改。

## 实拍与结论

当前导出PCK配套Godot程序，在Xvfb、Vulkan Forward+、llvmpipe软件渲染下生成1280×800截图。三武器各含腰射、ADS、换弹25%/50%/75%共15张；相机位置及朝向固定，ADS保留游戏设计的FOV缩放。

- 原图：`artifacts/realism55-validation/after/weapon-{0,1,2}-{hip,ads,reload-quarter,reload-half,reload-three-quarter}.png`。
- 总览：`artifacts/realism55-validation/contact-sheet.jpg`。
- AR与stage54同机位腰射/ADS对照：`artifacts/realism55-validation/stage54-55-ar-comparison.jpg`。
- 已查看总览、AR对照及AR腰射、ADS、换弹中段原图。机匣顶面与侧面明暗更易区分，但仍是较宽、偏平的灰蓝色面；凹槽在正常游戏尺寸下改善有限，不能据模型细节宣称写实目标达成。
- ADS红点居中、光路清楚。抽查换弹姿态未发现新增明显大面积穿插，但不代表全部连续动作或逐指接触均经人工审阅。另两种武器仍明显简化。
- 袖管仍显粗直，迷彩及布料明暗生硬。重复仓库、空旷草地、平滑远山和单一树线仍明显；人物近景本轮没有重新审阅。
- `capture.log`记录15帧完成，`capture.exitcode`为0。stage54退出143本轮未复现，原始原因仍未确定。软件渲染截图不构成实体GPU性能验证。

## 验证和限制

`artifacts/realism55-validation/tests.json`记录当前包10项测试全部退出0且无记录错误：瞄准108样本、换弹接触183样本、第一人称规则、三武器视觉、抵墙碰撞、手套袖管表面、枪械材质、预测、可靠动作和16角色单机烟测。各项原始日志位于同目录。预测及可靠动作测试属于规则测试，不能代替真实联网。

Blender构建、导入和PCK导出日志分别为同目录的 `blender.log`、`import.log`、`export.log`。导入退出0但仍记录既有 `ERROR: Parameter "t" is null.`，未将其描述为无错误构建。

只读联网探测 `network-probe.json` 显示本地8000端口的 `/health`、`/protocol`、`/openapi.json` 均为HTTP404，响应来自SimpleHTTP文件服务器。未修改后台服务；真实双客户端联网仍未验证。

## 当前本地预览

从项目根目录运行：

```sh
./artifacts/realism55-preview/Linux/IronMeridian --path /tmp
```

保留相邻 `IronMeridian.pck`，进入SOLO无需账户。release导出模板不可用，当前为Godot 4.4.1程序配成功导出的PCK开发预览，实拍与测试使用此包。启动说明、文件SHA256及验证索引位于 `artifacts/realism55-preview/Linux/README.txt`、`build.json`、`verification.json`。未推送或发布。

## 下一阶段

优先推进院落建筑差异、道路泥草过渡和植被分布，通过地面移动视角及入口碰撞复核提升场景整体观感；补人物近景和光照审阅。保留第一人称同机位回归，继续改善袖管自然弯曲和枪身大平面。API可用后补真实双客户端验证。
