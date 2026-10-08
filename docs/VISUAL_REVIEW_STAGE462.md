# Stage462：道路材质候选与验证失败记录

状态：continue。道路的明显改善尚未验收，人物审阅未完成。

当前本地导出：`artifacts/realism462-preview/Linux/launch.sh`。
PCK SHA256：`fbc859864f853c5cc04911f27cd2d3aad4a7e1e6a14724656944bcc9d993a93a`。
导入、导出退出0；当前包通过下述无界面功能检查，但图形首帧未验证成功，因此不能称为已验证可玩的新预览。

## 修改及实际证据

- `tools/build_asphalt_surface.py` 在生成 mipmap 前对沥青源图进行线性空间低频照明校正，生成 `client/assets/realism/asphalt_surface.png`。道路改用该纹理；shader 去掉运行时 LOD 照明相除，每个随机采样单元同时旋转 UV 和梯度，减少裂纹方向重复。不是道路几何改造，也没有修改人物。
- 纹理低频亮度标准差由 0.012812 降至 0.005560，见 `texture-diagnostic.json`。这只是源纹理诊断，不证明游戏里的横向矩形消失。
- 新增同机位对照工具 `tools/compare_environment_captures.py`，要求三机位元数据完全一致，记录来源哈希。新截图缺失，尚未运行生成对照，不能当作通过。
- `tools/test_online.py` 可明确选择导出包、日志位置及超时，避免联网测试无意使用源码或其他包。

所有本轮记录位于 `artifacts/realism462-validation/`。

## 当前包验证

`functions/connector-process.json`、`building-process.json`、`aim-process.json`、`offline-process.json` 均记录上述 PCK 哈希、退出0及对应 PASS 标志。接入通行双向各12/12路点；建筑通行与阻挡、三武器瞄准伤害、单机 smoke 通过。它们不能证明画质、连续动作或联网通过。

`after/process-result.json`：环境入口、宽幅地形、道路三机位完整请求；937.274秒后主动中断，退出-15，passed=false。软件 Vulkan/llvmpipe 停留在入口首个 process_frame，未生成任何 PNG。保存了入口相机位置 `[15.5,1.64999997615814,39]`、朝向 `[0,0.054087378,-0.998536229]` 及1280×800尺寸，见 `after/environment-camera-poses.json`。不能由单条相机记录推断三机位已采集。

最初并发运行多个图形采集造成明显内存、交换空间及 CPU 竞争；随后终止人物和动态采集，环境单独运行仍迟迟没有首帧。此次中断不是脚本超时，不是正常退出。尚未隔离是首次 shader 编译、渲染开销还是资源竞争后续影响，不把它断言为某个 shader 的已知缺陷。下一轮只串行运行图形采集，先定位首帧问题。

`full-four-poses/process-result.json`：无筛选完整四姿势已请求，中断退出-15，488.329秒，无截图，不通过。`other-weapons-third/process-result.json`：SG/SR换弹中点及第三人称站/蹲四图请求，中断退出-15，484.239秒，recorded为空，不通过。没有当前人物图可供审阅；不能沿用461的静态截图作为462通过证据。

`motion-diagnostic/process-result.json`：兼容渲染、关闭阴影及裁减远景的动态诊断，中断退出-15，363.562秒，samples=0。肩肘、腕旋转、袖口、护木、弹匣接触和回握的连续过程均未覆盖。

`online/process-result.json`：退出1，登录请求 `http://127.0.0.1:8000/auth/login` 返回404，尚未启动双客户端；联网未通过。没有修改认证或后台服务，不推断整个后台故障。

## 历史诊断的使用范围

本轮检查了461同机位基线，道路横向硬矩形、重复树冠、平滑山体和细长前臂仍是待解决问题。`diagnostic-no-bump/road-horizon.png` 实际使用461包（PCK `58f70c41092fad480809b4200c042f6e7c32571cc92a4126d049f76212eee1db`）；去掉道路法线扰动后色带仍可见，仅说明该因素不能单独解释旧包缺陷。它不是462修改后的截图，不构成前后对照。

## 下一步

先串行定位当前导出首帧的渲染/编译开销，必要时使用隔离诊断材质比较；恢复三个相同机位实机图和入口、宽幅地形对照后，才决定保留或修正这次道路候选。道路场地过渡的明显效果仍欠缺。随后运行完整四姿势、其他武器和第三人称补拍，按实际图像处理整臂比例与肩肘轨迹，补充连续换弹/回握接触证据。建筑多样性、山体、植被、光照、正常物理下人物表现和认证双客户端联网目标全部保留。未推送、未发布，保留已有未提交修改。
