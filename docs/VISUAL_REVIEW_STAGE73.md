# Stage73：手套手背结构调整与独立包复核

本轮状态：continue。正常游戏视距下收益较弱，第一人称写实目标尚未达标。

## 改动

`tools/build_viewmodel.py` 将手背独立椭圆护垫和外围椭圆线替换为掌部网格上的连续皮革材质区，加入约 1.3mm 的浅掌骨起伏，将手套织物法线强度由 0.19 降为 0.065；重建 `art/first_person.blend` 与 `client/assets/first_person.glb`。未改变手指接触锚点与动作骨架。保留原有未提交修改。

## 实际截图审阅

截图来自本轮导出的 Linux 独立包，Forward+ / Vulkan llvmpipe 软件渲染，1280×800。同一相机位置与朝向采集腰射、ADS、换弹 25% / 50% / 75%；ADS 保留游戏自身视场变化。前后对照沿用 stage72 相机。

- `artifacts/realism73-validation/carbine-before-after.png`：腰射与 ADS 前后对照。支撑手仍位于护木附近，ADS 红点可见且没有手臂遮挡；这些画面的视觉改善很有限。
- `artifacts/realism73-validation/glove-before-after.png`：换弹中段同区域 2 倍放大。前后仍十分接近，手背依然扁平、边缘偏硬，不能据生成器改动宣称手型已经写实。
- `artifacts/realism73-validation/all-poses-review.png`：五姿态总览。换弹两侧时点手臂没有明显脱离武器，但袖口宽厚，布料格纹偏强；静帧不证明整个动作无穿插。
- 原始截图：`artifacts/realism73-validation/packaged-forward/weapon-0-{hip,ads,reload-quarter,reload-half,reload-three-quarter}.png`。

枪身长矩形轮廓和枪托连接处亮环仍显机械拼装；重复橙色仓库、规则草簇、远处树木剪影和平滑山丘仍是明显缺陷。本轮未改善人物、建筑、地形或光照，不代表整体画质完成。

## 验证与预览

源码与独立包各运行七项测试，14 次均返回 0：手套材质/UV、三枪 ADS（108 样本）、换弹接触（183 样本）、武器阻挡、第一人称动作、武器视觉规则、16 actor 单机烟测。详情和各日志位于 `artifacts/realism73-validation/stage-results.json` 及同目录。截图程序五帧完成且无报告错误，导出返回 0。

导入仍输出 `ERROR: Parameter "t" is null.`，见 `import.log`，不能称为无错误导入。remote_snapshot 规则测试不是实际联网；本轮未运行依赖 `.env` 服务凭据的联网脚本，未读取密钥。实际联网、实体 GPU、完整人工移动/碰撞遍历仍未验证。

本地预览：`artifacts/realism73-preview/Linux/IronMeridian`，程序及 PCK 同目录。根目录运行：

```sh
./artifacts/realism73-preview/Linux/IronMeridian --path /tmp
```

目录内 `build.json` 提供哈希，`verification.json` 提供验证记录，`README.md` 提供操作说明。未上传或发布。

下一轮优先让第一人称正常视距下出现可辨认的形体改善：调整手掌横截面、指根过渡和袖口厚度，配合同相机腰射/ADS/换弹验证，避免继续仅靠微小表面参数变化累积进度。随后仍须处理环境重复、人物和实际联网验证。
