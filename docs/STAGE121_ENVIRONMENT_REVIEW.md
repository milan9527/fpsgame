# Stage121 环境地表审阅（2026-09-14）

本阶段修改道路和建筑周边地表，整体目标仍为 continue。建筑群体量与布局、植被边界和光照仍需继续改善；人物、手臂和武器完整目标保留。

## 实施

- `client/shaders/road_surface.gdshader` 新增世界坐标道路材质，使用细尺度骨料、低强度车道磨耗、不规则路肩和稀疏接缝。`client/scripts/world.gd` 将两条道路接入该材质；道路尺寸及现有碰撞未改变。
- `service_ground.gdshader` 与 `building_verge.gdshader` 降低土层橙黄偏色，混合灰褐石粒与不均匀沉积。此次没有新增建筑模型或修改太阳参数。
- `tests/environment_spawn_review_capture.gd` 补充审阅要求中的原始出生视角。截图来自两个独立导出包，非编辑器视图。

## 实图审阅与相机

原始出生机位脚点 `(17, 0.05, 50)`，yaw=`atan2(-18,16)`，pitch=`-0.03`，1280×800，武器0、非瞄准。前后图为 `artifacts/realism121-validation/{before,after}/environment-spawn.png`。维修棚外原来的橙黄土带明显减弱，与周边灰褐地表更加接近；草地斑块边缘、均匀草丛和空旷平地依旧明显。武器与袖子仍有简化感，本轮未验收连续动作。

其他固定机位由 `environment-camera-poses.json` 记录脚点和 yaw/pitch，包含西车间入口、东仓库入口和宽幅地形。原始出生相机单独保存在 `spawn-camera-pose.json`。对照生成脚本校验两个版本相机记录完全一致，并生成全分辨率并排图。

已逐张查看宽幅地形前后原图：道路从均匀暗色改为带灰色磨耗的表面，黄色路肩和棚前土带减弱，但道路仍呈宽阔平直色带，细骨料在该距离并不明显，不能声称已消除空旷感。远处低矮房屋重复与山峰轮廓人工感仍在。东仓入口前后近景没有明显变化，门洞内外可见连通空间；室内地面中央细黑竖线在两个版本中均存在，需后续定位，不能将其判为已修复。入口通行结论来自物理测试。

## 功能与预览

最终独立预览包完成13项功能检查：单机启动、瞄准对齐、武器遮挡、入口及屋顶碰撞、仓库/维修棚/水务区等实际角色通行，以及本地网络状态规则。结果和逐项日志位于 `artifacts/realism121-validation/functional-results.json` 及同目录。

远景检查首次在 headless 模式无法读取 MultiMesh，失败日志保留为 `background_scenery-headless-unsupported.log`；使用 Xvfb + Forward+ 重跑通过，18座山体、2545棵树，最大树根贴地误差0.000097米，见 `background_scenery.log`。没有将第一次失败视为通过。

预览：`artifacts/realism121-preview/Linux/IronMeridian`，相邻 `IronMeridian.pck` 必需。从项目根目录执行：

```sh
./artifacts/realism121-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus
```

README记录操作；build.json记录源码及二进制/PCK哈希。截图采用 llvmpipe 软件渲染，不代表硬件 GPU 性能。真实认证联网缺少授权 fixture，未测；本地规则不能替代真实联网。未推送或发布，保留所有未提交修改。

## 下一步

继续在正常出生及宽幅机位改善建筑间院落用途、建筑体量重复、植被与道路边缘衔接，并审阅阴影及棚顶受光；避免继续仅增加远景树木。随后补第三人称人物姿态及第一人称连续瞄准、射击、换弹手部审阅，合法联网测试条件具备后补真实联机验证。
