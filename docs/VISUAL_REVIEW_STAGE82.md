# Stage82：卡宾枪护木形体与材质分区

状态：continue。护木获得可见的局部改善，尚未达到整体画质目标；本轮没有修改手臂，也没有完成真实联网验收。

## 实施

`tools/build_assets.py` 将护木截面由8面改为12面，加入顶部斜面、前端收缩、圆角侧面/底面通风孔和上部通风切口，增加底部聚合物护片厚度。护木使用低饱和铜褐色阳极金属分区，调整机匣与护木粗糙度。保持枪械挂点不变，重新生成 `art/carbine.blend`、`client/assets/carbine.glb` 并导入、打包。

## 实际截图审阅

来源是 Godot 4.4.1 Forward+、Vulkan llvmpipe 软件渲染。源码与预览包各保存卡宾枪腰射、ADS、25%/50%/75%换弹五张截图。使用同一固定机位和姿态脚本；与stage81源码对照，不重复stage29验证。

- `artifacts/realism82-validation/comparison-hip.png`：前端轮廓、通风孔与金属/聚合物分区更清楚，枪身整体仍有平板感。
- `artifacts/realism82-validation/comparison-ads.png`：护木大部分被遮挡，画面改善有限；红点居中，没有看到新增遮挡。
- `artifacts/realism82-validation/comparison-reload-half.png`、`comparison-reload-quarter.png`、`comparison-reload-three-quarter.png`：侧面更容易看到护木变化。机匣依然宽平，左拇指细长圆管形态和袖口偏软的轮廓仍需重塑。
- `artifacts/realism82-validation/packaged-hip-ads.png`、`packaged-contact-sheet.jpg`：包内实际截图；已查看腰射/ADS拼图及75%换弹原图，没有看到新增大范围脱手或缺失网格。源码与包内PNG并非逐字节相同，不以哈希相同作为验收结论。

场景仍有重复仓库、规则植被、空旷平坦地面、树木轮廓重复和墙面斑驳失真；人物细节及更自然的光照也未在本轮解决。局部护木修改不能视作整体完成。

## 验证与异常

`artifacts/realism82-validation/test-results.json`：源码与预览包各6项，共12项退出0且PASS。覆盖三武器瞄准108采样、换弹接触183采样、武器阻挡/低举/恢复、第一人称动作、武器模型及本地远端快照规则、16角色单机烟测（伤害、换弹、治疗、胜利、射线和掩体）。这些规则测试不等于全场景碰撞人工验收，也不等于真实联网。

`capture-status.json` 保存十张原图路径、SHA256与退出状态。源码截图保存5帧并输出PASS标记，但外层退出143，原因未确定；包内截图5帧且退出0。首次验证驱动外层同样143，恢复执行后退出0，全部12个测试子进程退出0。保留原日志。Godot导入退出0但仍记录dummy renderer纹理空参数错误，未声称修复。软件渲染不证明真实GPU性能。

本轮未运行读取认证密钥的联网脚本；未读取密钥、修改服务或认证。真实双客户端联机仍待符合约束的验收方法。

## 本地预览与下一步

运行 `artifacts/realism82-preview/Linux/IronMeridian --path /tmp`，保留同目录PCK。该包沿用Godot可执行文件加载PCK的本地预览方式，标准Linux导出模板依赖仍未解决；README、build.json、verification.json记录启动、构建校验及证据。实际包内渲染和规则测试已运行，没有推送或外部发布。

下一轮优先实质重塑机匣轮廓及左拇指关节/掌根过渡，避免继续只调表面参数；在同机位腰射、ADS、换弹复核，并扩大到三武器。随后继续人物、建筑差异、地形植被和光照，以及真实联网验收。
