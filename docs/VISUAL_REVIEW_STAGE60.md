# Stage60 第一人称腕掌形体与材质自审

本轮在stage59资产上改善手套腕部至掌部的连续形体，未将局部变化视作整体目标完成。本报告为当前开发进程自审，不是独立审阅。

## 实际修改

`tools/build_viewmodel.py` 将椭球掌部替换为连续截面网格：收窄腕部、扩展掌面、轻微非对称及腕部褶皱，保留骨骼和接触锚点。增加独立的织物粗糙度纹理，与皮革材质分离。已重建 `art/first_person.blend` 与 `client/assets/first_person.glb`，导出当前本地预览。武器本体沿用stage59修改。

## 实际截图审阅

- `artifacts/realism60-validation/after/`：三武器各腰射、ADS及换弹1/4、1/2、3/4，共15张1280×800实际游戏截图；捕获通过见 `capture-xvfb.log`。
- `artifacts/realism60-validation/all-poses-review.png`：全部15姿态裁切总览，已逐项查看。
- `artifacts/realism60-validation/carbine-before-after.png`：stage59左、stage60右，腰射、ADS、换弹中段同位置对比，已查看。
- 使用同一角色位置、朝向和俯仰；ADS按游戏逻辑改变视场。采用Forward+ / llvmpipe软件Vulkan及独立Xvfb。截图来自工作区运行，不是导出包图形运行截图。

换弹中段腕部到掌面的过渡更连续，所查姿态未见明显断腕。腰射和ADS改善较小；手指仍呈管状、拇指和掌面仍偏简化，袖口与握持姿态的机械感尚未消除。三武器ADS瞄具仍居中。不能由离散姿态推断全动画无穿模。环境仍有重复仓库、均匀稀疏草地和简陋远景植被；本轮没有完成第三人称人物、建筑、地形或光照质量提升。

## 验证与局限

`artifacts/realism60-validation/tests.json` 记录六项回归全部退出0：瞄准108样本、换弹接触183样本、抵墙/蹲姿/重叠/恢复、第一人称动作、手套材质及UV、三武器模型与远端快照规则。接触锚点测试不替代渲染表面穿插审阅；远端快照测试不等于真实联网测试。

`packaged-smoke.log`：导出包在独立用户数据目录运行，OFFLINE_SMOKE_PASS，16演员，射击间隔、换弹、治疗、受伤、胜利、射线、掩体和骨骼检查通过。并非本轮完整人工移动碰撞测试。

导入日志 `import.log` 仍有dummy渲染器空纹理错误（Parameter "t" is null），不能称日志无错误；导出成功。初次截图因旧DISPLAY不可用失败，保留 `capture.log`；改用独立Xvfb后15张捕获完成。软件渲染不证明实体GPU性能。

`network-probe.json`：本机8000端口的 `/health`、`/protocol`、`/openapi.json` 均404。未更改后台服务，真实双客户端联网主要功能尚未验证。

## 本地预览与下一步

启动：`./artifacts/realism60-preview/Linux/IronMeridian --path /tmp`，选择Solo。二进制与PCK需同目录；该包使用Godot4.4.1开发可执行文件加导出PCK，非正式发行模板。README、许可证、构建哈希位于同目录，验证索引为 `verification.json`。

状态continue。优先继续针对三种握把改善拇指/指节形体及袖口交叠，复核同相机腰射、ADS和换弹；随后推进建筑差异、泥草过渡、植被分布、人物和光照，并补人工移动碰撞与真实联网验证。
