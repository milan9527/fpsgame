# Game handoff
Updated 2026-09-13; /home/ec2-user/project/fpsgame; feature/vehicles.

## Active goal
Autonomously improve Godot+Blender shooter realism toward Peace Elite: characters,
weapons/arms, buildings, terrain/vegetation/light. Inspect actual game images,
verify offline play and aiming/collision, provide runnable local previews.
NOT complete: environment/layout and characters remain visibly below reference.
NEVER push without confirmation. No AWS changes or publishing needed.
Do not claim execution survives UI exit. Keep tool outputs/images selective.

## Current source and evidence
Current source checkpointf3d332e adds stage20 ridges and grounded forest groves.
Stage19 source ba78dee adds fuller fir geometry (details below).
Previous checkpoint3406be7: stages17 side-wall frames/louvers/steel and18 roof covers,
plaster ends/flashing/gutters. Blender generators tools/build_facades.py and
build_roofs.py; corresponding .blend and .glb committed. Material scans CC0.
Main image artifacts/realism18-forward/gameplay.png; roof closeups realism18-roofs/.
Forward+ and Compatibility captures passed. Roof tests8 slopes/shots/doorways pass.
Stage17 collision snapshot matches all276 shapes from stage13. Content19 unchanged.
Stage17 model UV/bounds checked; see docs/VISUAL_REVIEW.md for detailed evidence.
Current Windows/Linux previews artifacts/visual-preview/f3d332eeb3f9/ include20.
verification.json: exports, packaged Linux offline/roof checks, ZIP hashes.
Packaged Forward+ street gameplay also passed from /tmp; capture/gameplay.png,
log artifacts/realism20-packaged-render.log.
Windows exported, not Windows-hardware tested. No live deployment changed.
Content19 cannot join old18 servers/checkpoints; old saves remain intact.

## Next substantial work
Stage20 complete locally: winding offset ridges within existing footprints,
slope-filtered groves,2314 trees including494 seedlings. Actual Forward+ forest
capture artifacts/realism20-final/gameplay.png; Compatibility realism20-world/
includes street/overview/forest.276 colliders match stage19; offline smoke passed.
tests/background_scenery.gd checks roots against temporary rendered-mesh triangle
colliders via raycasts; final pass2314trees,max error0.000101m. Run graphically
with xvfb and Compatibility, not headless. See realism20-scenery-final.log.
Next priority: major character/weapon/architecture assets rather than endless
distant-scenery polishing. Street capture shows repeated single-storey boxes.
tools/build_operator.py still builds separate sphere torso/joints and tubular
limbs, oval gloves; consider continuous garment topology and anatomical hands,
preserving the17-bone rig/15clips and validating crouch/reload/downed/vehicle poses.
Stage19 source: tools/prepare_fir_needles.py (NumPy/SciPy) converts all
432704 needles into area-compensated two-triangle kites; tools/build_fir_lod.py
reduces woody geometry and exports fir_full.glb (940024 triangles, ~72 MiB).
Runtime near trees and their distant billboards now use variant B. Auto mesh LOD
disabled for this asset to preserve needle coverage; distance cutoff still25m.
Forward+ forest image artifacts/realism19-final/gameplay.png passes; baseline
realism19-before/gameplay.png. Final smoke and roof tests pass; aim108samples pass.
Compatibility world capture realism19-world/ passed,276 colliders match stage13.
Tree crown improved but distant brightness/density/pop still need work.
Initial aggressive reduction, transparent cutout and autoLOD experiments did
not solve crown loss; do not use intermediate images/models as final evidence.
Address near/distant tree crown mismatch, empty repetitive layout and ground
material layers. Avoid substituting endless small trims for overall realism.
Old retained fir_near.glb is variantC (~505494 triangles); no longer used at runtime.
B source artifacts/realism-sources/tree-b/tree.gltf; packed authoring Blend is
background_fir.blend there. Source primitives: bark9582,trunk78776,twig2207296,
deadbranches4970 triangles. This is authoring input, too heavy to ship unchanged.
Continue matching near/distant lighting and lower-cost foliage representations.
tools/build_tree_impostor.py currently exports C near model unless FIR_VARIANT=B;
B branch only renders background billboard. Do not overwrite source/high-res Blend.
Keep collision trunk unchanged unless intentionally updating shared gameplay world.

## Environment
Godot tools/godot; Blender tools/blender-4.3.2-linux-x64/blender.
Software llvmpipe, no physical GPU. LP_NUM_THREADS=8; Forward+ uses
VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.x86_64.json and xvfb-run.
CAPTURE_ARTIFACT_DIR=<absolute> tools/godot --path client --audio-driver Dummy
--script ../tests/visual_gameplay_capture.gd. CAPTURE_INTERIOR=1 for indoors.
Add --rendering-method gl_compatibility for Compatibility. Use --headless for rules.
Avoid anisotropic triplanar sampling (driver stall); planar anisotropic is fine.
Enable mipmaps on new textures. Headless MultiMesh transform readback is invalid;
use graphics for placement diagnostics. Preserve shader UIDs/import metadata.
Package clean source with python3 tools/package_visual_preview.py; no publishing.
CLI /compact can summarize chat; this file itself cannot change context limits.
Input-length mitigation on 2026-09-13: user Codex config auto-compaction threshold
is currently 32000 (previously120000, then60000). Individual tool output history
is now capped with tool_output_token_limit = 4000. Timestamped config backups
are stored beside ~/.codex/config.toml.
Current running process may require restart to load it. If /compact fails, start
a fresh chat in this repository and read this handoff instead of pasting history.
This is a mitigation, not a verified change to the provider's input limit.

## Stage21 work in progress (2026-09-13)
Uncommitted changes: tools/build_operator.py, art/operator.blend,
client/assets/operator.glb; new tests/operator_pose_capture.gd. Preserve these.
Uniform torso/trousers and each sleeve are separately remeshed into continuous
surfaces with transferred normalized skin weights; limb endcaps are closed.
Build/import passed. Pose gallery: artifacts/realism21-poses-fixed.log
(OPERATOR_POSES_PASS: 15 clips, 75 skin samples). Images in
artifacts/realism21-poses/. Downed and aim checks passed in
artifacts/realism21-downed.log and artifacts/realism21-aim.log.
Still needed: remaining visual inspection, vehicle/offline checks, Forward+
gameplay capture, and preview packaging. Character vest/gloves/boots still need
more realistic shapes. Overall visual goal is NOT complete. No GitHub push
without explicit user confirmation; no publishing performed in this fix.

## Latest recovery checkpoint (2026-09-13)
This checkpoint supersedes the pending verification list above.
Stage21 gloves pose test passed (15 clips,75 skin samples), vehicle test passed,
and Forward+ gameplay capture passed; logs: artifacts/realism21-gloves-poses.log,
realism21-gloves-vehicle.log, realism21-gloves-gameplay.log.
Stage22 uncommitted tools/build_assets.py and regenerated art/carbine.blend,
client/assets/carbine.glb add shaped stock/grip, curved magazine and actual
handguard/muzzle openings. Build/import finished; realism22-aim.log records
AIM_ALIGNMENT_PASS samples=108 weapons=3. realism22-weapons.log currently has
only startup output: do not claim weapon visual checks passed; inspect process,
capture files and final log before resuming or rerunning.
Next: inspect weapon screenshots, refine assets, validate and package a local
preview. Overall realism goal remains incomplete. Preserve uncommitted work.
Latest user request is to resolve Codex "Input is too long". Existing recovery
script syntax and config values were rechecked; upstream resolution is not
proven. Start a fresh chat using tools/restart_codex_clean.sh if compact fails.

## Recovery handoff update (2026-09-13, stage28)
Supersedes the stage22 next-step checkpoint above. Verified directly from logs:
artifacts/realism28-facades.log has FACADE_ASSET_PASS for all three styles;
artifacts/realism28-roof.log has ROOF_COLLISION_PASS (8 roofs, slopes, shots,
doorways); artifacts/realism28-forward.log has VISUAL_GAMEPLAY_CAPTURE_PASS.
Stage28 adds gutters and downpipes. Latest capture:
artifacts/realism28-forward/gameplay.png. Overall realism remains incomplete.
Continue visual evaluation and improvements from current dirty assets, then
validate and create a current local preview. Do not push without confirmation.
The latest user request again concerns Input is too long. Recovery script
passes bash syntax validation; local configuration already limits tool output
to 4000 tokens and sets auto compaction to 32000. These settings alone do not
prove the upstream error resolved or reset the current UI chat. If compaction
fails, start a fresh conversation with docs/CODEX_RESTART_BRIEF.md only.


### Stage29 verification — 2026-09-13
Verified the pending Blender grass rebuild (22 curved/folded blades, 264 triangles)
and reviewed actual Forward+ gameplay against stage28. New regression
`tests/grass_visual_check.gd` checks imported upright geometry, 388 cells /
169031 tufts, grounded roots and clear roads/buildings/paved areas.
Evidence: artifacts/realism29-grass-build.log, realism29-forward.log and
realism29-forward/gameplay.png; packaged close view:
artifacts/realism29-preview/capture/grass-close.png with grass-visual.log.
Import exited 0 but realism29-import.log contains dummy renderer texture
ERROR (Parameter t is null); graphical rendering succeeded. Initial test
miscounted auto-renamed nodes; now identifies grass by shader resource.
Aim: realism29-aim.log PASS (108 samples, 3 weapons, recoil/lean/raycast);
offline: realism29-offline.log PASS; roof: realism29-roof.log PASS (8 roofs).
Networking blocked before two-client connection: realism29-online.log reports
HTTP 404 at 127.0.0.1:8000/auth/login. No service/auth changes; not a pass.
Current local preview: artifacts/realism29-preview/Linux/IronMeridian
(adjacent PCK required; run directly, or --rendering-method gl_compatibility).
Exported current dirty workspace without committing or pushing. Preview
verification.json records binary/PCK hashes, isolated-profile offline and roof
passes; packaged graphical grass test also passed outside source cwd.
Visual limits: repeating grass silhouettes, blurred uniform ground, pointed
mountains, repeated buildings, plastic-looking weapon and simple arms remain.
Screenshots use llvmpipe; no physical-GPU performance claim. Overall incomplete.
Next: improve mountain silhouettes and ground material/vegetation variation,
compare actual gameplay views, then continue weapon/character realism.
Repeat network regression once the local auth route is restored by its owner.

### Stage30 — 远山轮廓与独立预览验证

- 将远山尖锥改为更宽、圆润且带鞍部的山脊，保留原位置/半径。实际对比stage29与 `artifacts/realism30-forward/gameplay.png`，左侧尖峰明显改善。审阅：`docs/VISUAL_REVIEW_STAGE30.md`。
- 新增 `tests/ridge_visual_check.gd`：实际网格18山体、2566棵树贴地检查通过，最大误差0.000005m，均位于竞技区外（`artifacts/realism30-ridges.log`）。安全区100种子/600中心实际碰撞和导航通过（`artifacts/realism30-terrain.log`）。
- 当前本地预览：运行 `artifacts/realism30-preview/Linux/IronMeridian`（同目录PCK），进入离线SOLO/DUO。独立临时目录运行包内单机测试通过；截图已实际审阅：`artifacts/realism30-preview/capture/gameplay.png`；日志 `offline.log`、`capture.log`，哈希及范围 `verification.json`。Forward+使用llvmpipe，不代表硬件GPU性能。
- 未重复stage29瞄准/屋顶验证；联网沿用stage29本地登录HTTP404阻塞，本轮未重测、未修改服务。保留全部未提交修改，未发布。
- 整体目标未完成：草地重复、土壤模糊、建筑雷同、树片单薄、武器手臂材质平，人物和光照仍需更多视角审阅。下一步优先地表纹理尺度和植被变化，再做武器/手臂形体材质；登录接口恢复后完成联网主要功能验证。

### Stage31 — 草丛群落、地表尺度与独立预览

- 地表纹理重复尺度由约6米缩至2米，提高碎石辨识度；草丛增加疏密群落、枯绿和高宽变化及根部暗化。实际审阅包内 `artifacts/realism31-preview/capture/grass-close.png`、`capture/gameplay.png`，裸土与密草分布更明确，仍有重复叶片和泥斑。详见 `docs/VISUAL_REVIEW_STAGE31.md`。
- 独立临时目录、隔离用户数据运行当前导出包：`offline.log` 单机16角色、换弹/治疗/伤害/胜利/射线/掩体等通过；`grass.log` 检查385草格、124056草簇贴地且道路/硬质地面净空，高度0.186–2.222、枯绿数据0–1；`capture.log` 游戏截图通过。源端日志 `artifacts/realism31-grass.log`；包哈希与范围记录于 `verification.json`。
- 当前本地预览 `artifacts/realism31-preview/Linux/IronMeridian`（须保留相邻PCK），进入离线SOLO/DUO。截图采用Forward+ llvmpipe，不代表实体GPU性能。保留未提交修改，未推送或发布。
- 未重复stage29瞄准/屋顶测试；联网仍是此前本地登录HTTP404未解决记录，本轮未重测。整体目标未完成。
- 下一步：处理沥青与裸土的生硬多边形边界，再改善机匣、手套/前臂材质分层和形体；继续建筑、人物和光照多视角实机审阅。登录接口恢复后验证联网主要功能。

### Stage32 — 第一人称枪械/手臂实质改形与导出复核
- 卡宾枪机匣/拉机柄收窄，薄八边瞄具取代厚盒；袖管增加褶皱、接缝和袖口，手套增加皮革指节垫并调整迷彩/材质层次。保留已有未提交修改。
- 同机位三武器共 15 姿态前后截图：`artifacts/realism32-before/`、`realism32-after/`；腰射/ADS 对照 `artifacts/realism32-comparison/carbine-hip-ads.png`。审阅详情 `docs/VISUAL_REVIEW_STAGE32.md`。
- 瞄准 108 样本、武器外观、手臂规则与遮挡碰撞测试通过（`artifacts/realism32-*.log`）。导入有两条 dummy renderer texture null 错误；后续 Forward+ 截图与导出通过，不能称导入无错误。
- 可运行预览 `artifacts/realism32-preview/Linux/IronMeridian` + 同目录 pck；在项目目录外隔离数据单机烟测通过，导出包腰射/ADS 截图已实看（`realism32-preview/capture/`），附 README 和 SHA256 清单。llvmpipe 不代表实体 GPU 性能。
- 尚未完成整体目标：枪托直管感、手指与换弹接触、其他枪械方块感和场景重复仍明显。真实联网此前登录 HTTP 404 尚未解决，本轮未重跑 stage29；远端快照不算联网通过。下一步优先枪托/握持与换弹序列，再推进场景和真实联网验证。

### Stage33 — SG/SR 机匣与瞄具改形、最终包15姿态复核
- SG/SR 方盒机匣改为收窄多段轮廓并增加抛壳窗/枪栓/销钉；SG 薄鬼环、SR 渐扩薄壁镜筒减少遮挡。实图发现旋钮侵入和悬空后两次修正，保留修正前证据；本轮未新增手臂改动。
- 最终导出包从项目外隔离数据运行，三武器同机位腰射/ADS及换弹25/50/75%共15张通过：`artifacts/realism33-preview/capture/`、`realism33-preview-capture.log`；已实看对照 `realism33-comparison/`。详见 `docs/VISUAL_REVIEW_STAGE33.md`。
- 瞄准108样本、外观快照与挂点、遮挡碰撞及包内单机16角色烟测通过（`artifacts/realism33-*.log`）。导入退出0仍有一条 dummy renderer texture null 错误；llvmpipe不证明实体GPU性能。未重复stage29验证，快照不等于真实联网。
- 当前本地预览 `artifacts/realism33-preview/Linux/IronMeridian` + 同目录PCK，附README和SHA256清单；保留未提交修改，未推送发布。
- 整体继续：SR仍像空镜圈，枪托/握指和换弹接触、场景重复需实质改善；此前登录HTTP404未解决且本轮未重测。下一轮优先枪托与手指握持/换弹接触、镜内光学，再推进建筑植被和真实联网验证。

### Stage34 — 手套连续掌背、弯指形体与包内复核
- 重建第一人称手部：椭圆掌体、连续皮革掌背、拇指根部及渐细弯指，替换方掌/直指/珠状指节；更新 Blender 与 GLB，保留此前未提交修改。材质参数与骨架动作沿用，未宣称材质写实完成。
- 包内同机位三武器腰射/ADS和换弹共15张：`artifacts/realism34-preview/capture/`。首次采集13张后退出143且原因未知；新增单武器采集参数，第三把补采5张退出0。原日志和补采日志保留在 `artifacts/realism34-validation/`，没有把首次采集记为通过。
- 瞄准108样本、武器外观快照/挂点、遮挡碰撞和独立包单机16角色烟测通过；导入退出0仍报 dummy texture null。已实看腰射/ADS对照和九张换弹接触裁图，审阅 `docs/VISUAL_REVIEW_STAGE34.md`，对照 `artifacts/realism34-comparison/`。
- 本地预览 `artifacts/realism34-preview/Linux/IronMeridian` + 同目录PCK，从项目外隔离数据验证，附README及SHA256清单。使用llvmpipe，不代表实体GPU性能；未推送发布。
- 整体未完成：手指仍短粗、袖口亮、枪托直管，三武器换弹中段左手悬空且没有取送弹接触；下一阶段优先动作接触/手指比例与枪托材质，再推进人物蒙皮、建筑植被。真实联网此前HTTP404仍未解决，本轮未重测，未重复stage29。

### Stage35 — 恢复完整枪托、SG/SR侧轮廓与袖口降亮
- 移除第一人称绑定时隐藏枪托/肩垫的逻辑；SG/SR盒状枪托改为折线侧轮廓并增加背带孔，SR增加贴腮板/凹槽；降低手腕绑带基础色。重新生成资产，外观测试新增枪托可见断言，保留此前未提交修改。
- 三武器同机位腰射/ADS和换弹共15张包内截图位于 `artifacts/realism35-preview/capture/`；已实看六张瞄准姿态及九张换弹汇总，对照 `artifacts/realism35-comparison/`，审阅 `docs/VISUAL_REVIEW_STAGE35.md`。枪托更完整，但近景枪托/肩垫仍呈大块平板，不能把部件可见当作画质完成。
- 瞄准108样本、外观快照/挂点、遮挡碰撞和包内单机16角色烟测通过，日志 `artifacts/realism35-validation/`。末次资源导入退出0仍有一条texture null；标准release导出因缺少模板失败，改用成功导出的PCK配本机Godot程序。
- 本地预览 `artifacts/realism35-preview/Linux/IronMeridian` + 同目录PCK，项目外隔离数据运行，附README和哈希清单；Forward+ llvmpipe截图不证明实体GPU性能。未推送发布、未重复stage29；此前真实联网HTTP404仍未解决，本轮未重测。
- 整体继续：下一阶段优先枪托/肩垫厚度、圆角和粗糙度层次、左手换弹取送接触；手指比例与SR镜内光学仍需改善，再推进人物、建筑植被和真实联网验证。

### Stage36 — 圆角橡胶肩垫与仓库门槛碰撞修复
- AR/SG/SR肩垫改为四圈收边轮廓、深色高粗糙度橡胶和11道防滑肋，重建Blender/GLB；保留未提交修改。本轮未修改手臂，换弹左手接触仍需整改。
- 仓库双门加入实体混凝土斜坡衔接20cm地板；源项目与独立包真实Actor双向穿行通过，地板未禁用。证据 `artifacts/realism36-validation/packaged-traversal/traversal.json`。
- 最终包三武器同机位腰射/ADS与换弹共15张已实看：`artifacts/realism36-preview/capture/`、`realism36-comparison/all-hip-ads.jpg`、`all-reload.jpg`；前后肩垫对照及审阅见 `docs/VISUAL_REVIEW_STAGE36.md`。
- 瞄准108样本、外观挂点/快照、遮挡碰撞及项目外隔离数据的包内单机16角色烟测通过，日志 `artifacts/realism36-validation/`。导入退出0仍有三条dummy texture-null；llvmpipe不代表实体GPU性能。真实联网此前HTTP404未解决且本轮未重测，未重复stage29。
- 本地预览 `artifacts/realism36-preview/Linux/IronMeridian` + 同目录PCK，附README与 `verification.json` 哈希清单。未推送或发布。
- 整体继续：下一轮优先手指比例与左手取送弹接触；枪托平板感、SR空镜圈、人物与重复场景仍需实质改善，随后推进建筑植被光照及真实联网验证。

### Stage37 — 手指轮廓与手套材质重建
- 收窄掌体、镜像指序、渐细弯曲手指、错列指节护垫和低亮缝线，加入嵌入式皮革粗糙度图；重建Blender/GLB，保留5骨4动作与此前未提交修改。
- 最终包三武器固定相机腰射/ADS与换弹15张截图全部成功并实看；手部前后对照及汇总在 `artifacts/realism37-comparison/`，原图在 `artifacts/realism37-preview/capture/`，审阅 `docs/VISUAL_REVIEW_STAGE37.md`。指节轮廓改善，但通常被袖口/枪体遮挡，材质变化有限，换弹中段左手接触仍不可信。
- 瞄准108样本、三武器外观挂点/快照、遮挡规则与项目外隔离数据的包内单机16角色烟测通过，日志 `artifacts/realism37-validation/`。导入退出0有一条dummy texture-null；Forward+ llvmpipe不代表实体GPU性能。未重跑stage29；真实联网此前HTTP404未解决，本轮未重测。
- 本地预览 `artifacts/realism37-preview/Linux/IronMeridian` + 相邻PCK，附README与 `verification.json`。采用本机引擎+PCK，release模板缺失仍未解决。未推送发布。
- 整体继续：下一阶段优先左手换弹轨迹及弹匣取送接触，以三武器25/50/75%和腰射/ADS验证；继续改善枪托平板、SR空镜圈、人物及重复建筑植被光照，完成真实联网验证后再判断总体完成。

### Stage38 — 换弹取送接触与持枪恢复
- 左手跟随弹匣侧面，前臂对齐手腕；抽插限制20%–80%，伸手/收手弹匣归座，每帧清除骨骼覆盖。三武器183个实际骨骼接触样本与持枪恢复通过；本轮未重建几何/材质。
- 本地包三武器同机位腰射/ADS和25/50/75%换弹共15张已保存并实看，`artifacts/realism38-preview/capture/`；对照/汇总 `artifacts/realism38-captures/`，审阅 `docs/VISUAL_REVIEW_STAGE38.md`。中段脱离减轻，但手指仍未包握、前臂伸缩不等于完整IK。
- 瞄准108样本、外观快照挂点、遮挡碰撞、项目外隔离数据包内单机16角色烟测通过，日志 `artifacts/realism38-validation/`。首次武器0截图后X11退出1和shader缓存错误保留，隔离数据单独重跑退出0、五帧PASS且无ERROR，日志另存；武器1鼠标抓取报错但退出0，武器2退出0。llvmpipe不证明实体GPU性能。
- 本地入口 `artifacts/realism38-preview/Linux/IronMeridian` + 相邻PCK，附README、build.json及已核验15张截图/包哈希的verification.json；仍为引擎+PCK开发预览。未推送发布，保留全部未提交修改；实际联网HTTP404未解决，本轮未复验。
- 整体继续：优先枪托形体/材质、SR镜内光学和手指包握，再推进人物、重复建筑植被与光照及真实联网验证；本轮不代表整体目标完成。

### Stage39 — 曲面枪托与托腮板
- 三武器枪托由平板挤出改为32点圆角截面放样，SR托腮板改圆顶；重建三组Blender/GLB，保留挂点、肩垫和此前全部修改。本轮未改手臂/材质。
- 独立包同相机腰射、ADS及25/50/75%换弹15张已保存并实看，三进程退出0、各五帧PASS无ERROR。原图 `artifacts/realism39-preview/capture/`，前后对照 `artifacts/realism39-comparison/`，审阅 `docs/VISUAL_REVIEW_STAGE39.md`。枪托平板感减轻，但SR空镜圈、单调材质、简化手指和重复场景仍明显。
- 瞄准108样本、换弹接触183样本、外观挂点快照、遮挡规则与项目外隔离数据包内单机16角色烟测通过，日志 `artifacts/realism39-validation/`。导入退出0仍有三条dummy texture-null；llvmpipe截图不证明实体GPU性能。未重复stage29；真实联网此前HTTP404未解决，本轮未重测。
- 本地可运行入口 `artifacts/realism39-preview/Linux/IronMeridian` + 相邻PCK；README、build.json、verification.json保存包哈希与15张原图清单。仍为引擎+PCK开发预览，release模板缺失。未推送发布。
- 整体继续：下一轮优先SR镜内视觉及枪体材质，同机位复查腰射/ADS和换弹；继续手指包握、人物、建筑地形植被光照与真实联网验证，不把枪托改善当成整体完成。

### Stage40 — SR目镜表面与分划
- 增加透明圆形镀膜、边缘遮光及细分划，中心留空，目镜随武器运动/隐藏且换枪清理。本轮未改手臂几何；仍用整屏FOV，刻度未标定弹道，镜片边缘偏雾状。
- 独立包三武器同相机腰射/ADS六图及SR换弹三图已保存实看；前后对照 `artifacts/realism40-comparison/`，审阅 `docs/VISUAL_REVIEW_STAGE40.md`。空镜圈改善，但材质单调、手指包握及重复建筑植被仍需工作。
- 瞄准108样本、换弹接触183样本、外观/目镜生命周期、遮挡碰撞及包内单机16角色烟测通过，日志 `artifacts/realism40-validation/`。并行截图武器0退出1清理报错、武器1鼠标捕获报错，独立显示器重跑均退出0且无ERROR；原日志保留。外观测试初次遗漏render更新，修正后通过，失败记录保留。
- 当前本地入口 `artifacts/realism40-preview/Linux/IronMeridian` + 相邻PCK；build.json/verification.json核验包哈希、九张1280×800截图及八份PASS日志。仍为引擎+PCK开发预览，llvmpipe不证明实体GPU性能。未推送发布，全部未提交修改保留；真实联网此前HTTP404未解决，本轮未重测。
- 整体continue：下一轮优先枪体金属/聚合物/橡胶材质区分和手指包握，同机位复查腰射/ADS；继续人物、建筑地形植被光照与真实联网验证。本轮不代表整体目标完成。

### Stage41 — 武器金属/聚合物/橡胶表面区分
- 三武器运行时材质增加分类型金属度、粗糙度微纹理和法线，补齐SG/SR复合枪托及肩垫后缀名称覆盖，复制缓存保证源材质隔离。本轮未改手臂几何。
- 独立包三武器同机位腰射/ADS六图已保存实看，三次独立显示器进程均退出0、两帧PASS无ERROR；原图 `artifacts/realism41-preview/capture/`，对照 `artifacts/realism41-comparison/`，审阅 `docs/VISUAL_REVIEW_STAGE41.md`。材质区分改善，但机匣大面仍光滑、手指未包握、场景重复。
- 材质3模型22表面、瞄准108样本、换弹接触183样本、外观挂点快照、遮挡碰撞及包内单机16角色烟测通过，日志 `artifacts/realism41-validation/`。材质测试初次忽略Blender名称数字后缀，修正断言后通过，失败日志保留。本轮没有新增换弹截图，未重复stage29。
- 当前本地入口 `artifacts/realism41-preview/Linux/IronMeridian` + 相邻PCK，README/build.json/verification.json含说明及哈希、六图和九份PASS日志；仍为开发预览，缺release模板，llvmpipe不证明实体GPU性能。真实联网此前HTTP404仍未解决，本轮未重测。全部未提交修改保留，未推送发布。
- 整体continue：下一轮优先手指包握和拇指/护木接触形体，复查三武器腰射/ADS及换弹；继续人物、建筑地形植被光照与真实联网验证，不把材质小阶段视为整体完成。

## Stage42 — 支撑手包握形体与换弹朝向（2026-09-13）

- 重建左手横向四指、对握拇指与鱼际细节，生成 Blender/GLB；实机发现旧换弹90度旋转令手指竖起，已修正并保留失败图。腰射轮廓改善，ADS 未新增中心遮挡；SR 换弹中点仍有拇指间隙，逐指接触尚未完成。
- 三把武器同机位腰射/ADS及三个换弹时点共15张已审阅：`artifacts/realism42-preview/capture/`；前后对照及九格换弹图：`artifacts/realism42-comparison/`；审阅：`docs/VISUAL_REVIEW_STAGE42.md`。
- 外观、瞄准108样本、换弹掌心183样本、武器遮挡规则和最终PCK离线战斗烟测通过，日志在 `artifacts/realism42-validation/`。导入退出0但记录 dummy 空纹理错误；真实联网此前HTTP404未解决，本轮未作多人端到端测试。
- 本地运行：`artifacts/realism42-preview/Linux/IronMeridian`（相邻PCK）；README/build.json/verification.json记录来源、哈希及限制。软件Vulkan截图，不代表实体GPU性能。保留未提交修改，无推送发布。
- 下一步：优先扩大场景画面收益，改善建筑入口/窗框纵深和草丛分布并补近景/移动截图；继续逐武器接触、人物、地形光照及真实联网诊断/主要通道碰撞。整体目标未完成，状态continue。

### Stage43 — 第一人称导轨与袖口形体（2026-09-13）
- 卡宾枪宽方块导轨改为21.2mm燕尾截面细齿，袖口改为开放锥形椭圆布料网格；重建 Blender/GLB，保留武器锚点和骨骼。
- 最终独立预览固定相机生成三武器15张腰射/ADS/换弹截图并审阅；导轨积木感减轻，袖口改善较细微。六项规则测试和打包单机 smoke 通过。证据：`docs/VISUAL_REVIEW_STAGE43.md`、`artifacts/realism43-comparison/`、`artifacts/realism43-validation/`。
- 本地启动：`artifacts/realism43-preview/Linux/IronMeridian`；同目录 `build.json` / `verification.json` 记录哈希与验证。导入退出0但有 dummy renderer 空纹理错误；截图采用软件 Vulkan，不代表真实GPU性能。
- 整体目标未完成：手套与SR指尖接触、重复建筑植被仍明显；真实联网HTTP404未解决，本轮未做联网端到端及全图碰撞巡检。下一步提升建筑入口/窗框纵深与植被地面过渡，补近景移动截图，继续手部修正并诊断联网。

### Stage44 — 手套材质、指节压褶与导出UV修正（2026-09-13）
- 增加手套织物/皮革法线、指节浅压褶及分片手背护垫；修复网格合并时UV层名称不一致导致手指首UV通道为空的问题，重建 Blender/GLB，新增导入后表面规则验证。
- 最终本地包三武器同相机15张腰射/ADS/换弹截图已审阅；手套近景纹理改善，正常视距形体变化较小，枪体/手部仍简化。证据：`docs/VISUAL_REVIEW_STAGE44.md`、`artifacts/realism44-preview/capture/`、`artifacts/realism44-validation/` 的对照与总览。
- 七项规则与单机烟测通过：瞄准108样本、掌心接触183样本、UV有效三角形27072；捕获退出0。真实联网此前HTTP404未解决，本轮未测多人端到端或全图碰撞；导入退出0仍记录既有dummy空纹理错误。
- 本地运行：`artifacts/realism44-preview/Linux/IronMeridian`（相邻PCK）；同目录README/build.json/verification.json记录限制、哈希与验证。软件Vulkan截图，引擎加PCK预览；保留未提交修改，无推送发布。
- 整体目标未完成，状态continue。下一步实质改善建筑入口/窗框纵深、草地过渡并补近景移动截图，继续SR逐指接触、真实联网诊断及主要通道碰撞验证。

### Stage45 — 卡宾枪后机匣收肩与拉机柄（2026-09-13）
- 上机匣改为六截面后端渐缩形体，重做后掠双侧拉机柄与防滑齿，调整导轨及加强条贴合；重建 Blender/GLB。沿用stage44手臂材质和握持锚点。
- 最终本地包同相机三武器15张腰射/ADS/换弹截图已审阅，后端方墙感减轻、ADS中心无新增遮挡；枪身平面及手部简化仍明显。证据：`docs/VISUAL_REVIEW_STAGE45.md`、`artifacts/realism45-preview/capture/`、`artifacts/realism45-validation/` 内腰射/ADS前后对照及总览。
- 六项规则和单机烟测通过，含瞄准108、掌心接触183样本及武器贴墙遮挡。真实联网此前HTTP404未解决，本轮未做多人端到端或全图碰撞；导入退出0仍记录dummy空纹理错误。
- 本地启动：`artifacts/realism45-preview/Linux/IronMeridian`（相邻PCK）；同目录README/build.json/verification.json记录哈希和验证范围。软件Vulkan截图，不代表实体GPU性能。保留未提交修改，无推送发布。
- 整体目标未完成，状态continue。下一步扩大建筑入口/窗框纵深与草地过渡改善，补近景移动截图；继续SR逐指接触、人物/地形光照、联网诊断及主要通道碰撞。

### Stage46 — 前臂截面与局部布料褶皱（2026-09-13）
- 袖子改为变化椭圆截面与局部斜向压褶，加入ripstop织物法线；重建Blender/GLB和本地包。枪体保留stage45，握持锚点未改。
- 最终包同相机三武器15张腰射/ADS/换弹截图已审阅。圆管感减轻、ADS无新增中心遮挡；正常视距改善有限，迷彩与手部仍简化。证据：`docs/VISUAL_REVIEW_STAGE46.md`、`artifacts/realism46-validation/` 对照及总览、`artifacts/realism46-preview/capture/` 原图。
- 七项规则和单机烟测通过，含瞄准108、掌心接触183样本；截图退出0。真实联网此前HTTP404未解决，本轮未测多人端到端、全图碰撞或连续动画。导入退出0仍有既有dummy空纹理错误。
- 本地启动：`artifacts/realism46-preview/Linux/IronMeridian`（相邻PCK），同目录README/build.json/verification.json记录哈希、验证与限制。软件Vulkan截图不代表实体GPU性能。保留所有未提交修改，无推送发布。
- 整体目标未完成，状态continue。下一步集中建筑入口/窗框纵深和院落路面-草地过渡，补移动近景截图；继续人物/光照、SR逐指接触、真实联网诊断和主要通道碰撞。

### Stage47 — SG-8 圆弧机匣与复合材质（2026-09-13）
- SG机匣改为渐缩圆弧截面，护木改为椭圆渐缩与浅防滑带，握把增加掌心鼓起；复合材质改为深灰绿。单独重建SG Blender/GLB，沿用stage46手臂和握持锚点。
- 最终包同机位三武器15张腰射/ADS/换弹截图已审阅；SG亮灰后端平板感减轻，ADS中心无新增遮挡。证据：`docs/VISUAL_REVIEW_STAGE47.md`、`artifacts/realism47-validation/sg-hip-ads-before-after.png`、同目录总览与 `artifacts/realism47-preview/capture/` 原图。
- 七项规则和单机烟测通过，含瞄准108、掌心接触183样本和贴墙遮挡；截图退出0。真实联网此前HTTP404未解决，本轮未验证多人端到端、全图碰撞或连续动画。无头导入仍有既有dummy空纹理错误，实际Vulkan截图成功。
- 本地启动：`artifacts/realism47-preview/Linux/IronMeridian`（相邻PCK）；README/build.json/verification.json包含说明、已复核哈希与验证范围。软件渲染不代表实体GPU性能。保留未提交修改，无推送发布。
- 状态continue：枪体与手部仍简化，建筑重复、植被规律、光照不足。下一步实质改善建筑入口/窗框纵深和院落地表过渡，补移动近景及主要通道碰撞；继续人物、光照、手指接触与联网诊断。

### Stage48 — SR-5 曲面机匣、握把与真实通风护木（2026-09-13）
- SR机匣和握把改为渐变曲面，护木重建为空腔渐缩壳体及五组贯通槽，复合材质改深灰绿；重建Blender/GLB与本地包，沿用现有手臂锚点。
- 最终包同机位SR腰射/ADS/三换弹共5张图已审阅，平板感减轻，ADS无新增中心遮挡；开孔近景改善有限，枪体仍偏光滑。证据：`docs/VISUAL_REVIEW_STAGE48.md`、`artifacts/realism48-validation/sr-hip-ads-before-after.png`、`sr-reload-overview.png`、`artifacts/realism48-preview/capture/`。
- 八项规则/单机测试通过，瞄准108与掌心接触183样本，截图退出0。真实联网此前HTTP404未解决，本轮未测多人端到端、全图碰撞或连续动画；无头导入仍有既有空纹理错误，软件Vulkan截图成功。
- 本地启动：`artifacts/realism48-preview/Linux/IronMeridian`（相邻PCK），附README/build.json/verification.json与已复核哈希。未推送发布，保留全部未提交修改。
- 状态continue。下一阶段集中建筑入口/窗框纵深、院落地表过渡及移动近景/主要通道碰撞；继续人物、光照、逐指接触与真实联网诊断。

## Stage49 — SR 镜筒形体与同机位复核（2026-09-13）
- 重建分段镜筒、防滑调节环及旋钮端盖，分离壳体/调节环/内壁材质，保留光路与瞄准锚点。手臂沿用已有版本，本轮只复核接触。
- 最终包 Forward+ 软件 Vulkan 生成并审阅腰射、ADS、三个换弹姿态共5张图；镜筒机械轮廓更明确，ADS中心清晰，但镜体仍厚重、侧旋钮高光生硬。证据：`docs/VISUAL_REVIEW_STAGE49.md`、`artifacts/realism49-validation/sr-hip-ads-before-after.png`、`sr-reload-contact.png`。
- 打包版本8项规则/单机测试通过：瞄准108、接触183样本；日志 `artifacts/realism49-validation/test-results.json` 与 `capture.log`。既有无头导入空纹理错误仍在；真实多人HTTP404、全地图碰撞和连续手指动作本轮未验证。
- 本地预览 `artifacts/realism49-preview/Linux/IronMeridian`（相邻PCK），附README/build.json/verification.json与复核哈希。未推送发布，保留未提交修改。
- 状态continue，整体目标未完成。下一轮优先建筑门窗/入口纵深、院落道路泥草过渡的实质改善及同机位截图、入口碰撞；另需修复联网HTTP404并做真实双客户端验证，继续人物、植被与光照。

## Stage50 — 仓库门洞厚度、卷帘机罩与雨棚（2026-09-13）
- 三种立面重建门洞侧壁、导轨暗缝、卷帘机罩与带斜撑滴水边雨棚；32处雨棚增加独立碰撞，保留既有坡道和全部未提交修改。
- 最新包实拍三入口视角及AR同机位腰射/ADS并审阅；旧stage49包同相机三图作对照。入口纵深改善，但坡道光滑发亮、地表噪声、重复空院落和简化枪械仍明显。详见 `docs/VISUAL_REVIEW_STAGE50.md`、`artifacts/realism50-validation/entrance-oblique-before-after.jpg`。
- 雨棚96射线/32处、仓库双向穿越、屋顶碰撞、瞄准108样本、抵墙、第一人称与单机烟测通过。保留首次缺DISPLAY及误用不存在烟测脚本的失败日志，修正入口后成功；无头导入既有空纹理错误仍在。
- 联网只读诊断：8000端口实际为SimpleHTTP文件服务器，三个API路径404；未改服务，未验证真实多人。证据 `artifacts/realism50-validation/network-probe.json`、`test-results.json`。
- 本地预览 `artifacts/realism50-preview/Linux/IronMeridian`（相邻PCK），附README与哈希记录。状态continue，未推送发布，整体目标未完成。
- 下一轮优先门槛坡道/道路材质及泥草过渡、院落差异化，继续同机位截图与移动碰撞复核；随后补人物、武器手臂、光照及可用API下真实双客户端验证。

## Stage51 — AR 下机匣、镜座与手套分片（2026-09-13）
- 按stage31反馈优先第一人称：重塑下机匣斜面/凹槽、桥架镜座与独立紧固件，调整喷砂铝材质，双手护垫改为短分片；重建Blender/GLB并打包，保留全部既有修改。
- stage50旧包与本轮包同机位腰射、ADS和三个换弹姿态共10张实拍已审阅。镜座侧形体改善，ADS无遮挡；手套改善受遮挡限制，袖管圆柱感、机匣均匀暗色及重复院落仍明显。详见 `docs/VISUAL_REVIEW_STAGE51.md` 与 `artifacts/realism51-validation/*-before-after.jpg`。
- 当前包6项检查通过：瞄准108样本、换弹接触183样本、第一人称规则、武器视觉规则、抵墙和单机烟测。日志及截图哈希见 `artifacts/realism51-preview/verification.json`。首次DISPLAY失败和既有两条无头导入空纹理错误均保留记录；Xvfb截图成功。
- 联网API仍HTTP404（SimpleHTTP文件服务器），未改服务、未验证真实多人；证据 `artifacts/realism51-validation/network-probe.json`。
- 本地预览 `artifacts/realism51-preview/Linux/IronMeridian`（相邻PCK），附README/build.json。状态continue，整体目标未完成，未推送发布。
- 下一轮优先袖口腕部形体/布料褶皱与机匣表面层次，并用同机位图复核；继续坡道道路泥草过渡、院落差异化和可用API下真实双客户端验证。

## Stage52 — 袖管斜向褶皱与迷彩袖口（2026-09-13）
- 重塑第一人称袖管腕部收束、局部斜向褶皱和堆积，袖口增加布料UV及弧形搭片；重建Blender/GLB并导出当前包，保留全部既有修改。
- 三武器同机位腰射/ADS与三个换弹姿态共15张实拍成功并审阅；stage51/52 AR对照显示轮廓局部改善，但布料仍平、枪身材质均匀偏暗、院落重复。详见 `docs/VISUAL_REVIEW_STAGE52.md` 与 `artifacts/realism52-validation/*jpg`。
- 当前包7项规则/单机检查全部通过，覆盖瞄准108样本、换弹接触183样本及抵墙碰撞；见 `artifacts/realism52-validation/tests.json`。无头导入保留一条既有空纹理错误，图形截图退出0。
- 联网只读探测三个API仍HTTP404（SimpleHTTP服务器）；未改服务，未验证真实多人。预览 `artifacts/realism52-preview/Linux/IronMeridian`（相邻PCK），附README与哈希/验证索引。
- 状态continue，整体目标未完成，未推送发布。下一轮优先实际可见的布料明暗与机匣材质层次，继续道路泥草过渡、院落和人物；API可用后补真实双客户端验证。

## Stage53 — 袖管加固布片、织纹与枪身哑光材质（2026-09-13）
- 加入贴合袖管的加固片和中尺度织物法线；调整涂层金属/聚合物并补齐瞄具材质覆盖，重建Blender/GLB及本地包。
- 导出包三武器腰射/ADS/换弹15张实拍退出0，已审阅总览和AR同机位对照；织纹可见、蓝灰反光减弱，但袖管仍直、机匣仍平，加固片正常视角不醒目。详见 `docs/VISUAL_REVIEW_STAGE53.md`。
- 当前包10项检查通过：瞄准108样本、换弹接触183样本、抵墙碰撞、材质/UV、预测、可靠动作、单机等；日志 `artifacts/realism53-validation/tests.json`。导入仍有一条既有空纹理错误。
- API探测仍三项HTTP404，真实多人未验证，未改服务。预览 `artifacts/realism53-preview/Linux/IronMeridian`（相邻PCK），附README和哈希/验证索引。
- 状态continue，整体目标未完成，未推送发布。下一轮优先正常画面可辨认的袖管弯曲及机匣倒角/零件层次；继续人物、院落、道路泥草与光照，API可用后补真实双客户端验证。

## Stage54 — 袖管弯曲与机匣轮廓分层（2026-09-13）
- 重塑肘腕粗细、袖管弯曲中心线及局部褶皱；AR机匣加入肩线、检修面板和销钉，重建Blender/GLB及本地包，保留所有既有修改。
- 三武器同机位腰射/ADS/换弹15张原图完整并已自审；stage53/54对照可见袖管变化，机匣改善较小、仍偏平暗。见 `docs/VISUAL_REVIEW_STAGE54.md` 与 `artifacts/realism54-validation/contact-sheet.jpg`。捕获日志有15帧PASS，但进程退出143，原因未确定，未记正常退出。
- 当前包10项规则及单机检查全部退出0：瞄准108样本、换弹接触183样本、抵墙碰撞等，见 `artifacts/realism54-validation/tests.json`。导入仍有既有空纹理错误；release模板缺失，改用成功导出PCK配套Godot程序。
- 本地预览 `artifacts/realism54-preview/Linux/IronMeridian --path /tmp`（保留相邻PCK），附README、build.json和verification.json。API三项仍HTTP404，真实多人未验证，未修改服务或推送发布。
- 状态continue，整体目标未完成。下一轮推进院落建筑差异、道路泥草和植被分布，复核人物近景与光照，并保留第一人称姿态回归；复核图形进程退出异常，API可用后补真实双客户端验证。

## Stage55 — AR机匣材质与凹槽实拍复核（2026-09-13）
- AR机匣分离阳极氧化铝及倒角材质，加厚侧肩并切出面板凹槽，重建Blender/GLB及预览；手臂沿用stage54并复核，没有新增手臂形体修改。
- 当前包三武器同机位腰射/ADS/换弹15张实拍正常退出0，已自审总览、AR对照及原图；机匣明暗层次改善，但宽平面、粗直袖管、重复建筑和空院落仍明显。见 `docs/VISUAL_REVIEW_STAGE55.md`、`artifacts/realism55-validation/contact-sheet.jpg`、`stage54-55-ar-comparison.jpg`。stage54退出143未复现，原因仍未知。
- 当前包10项规则及单机检查全部通过，含瞄准108样本、换弹接触183样本与抵墙碰撞，见 `artifacts/realism55-validation/tests.json`。既有导入空纹理错误仍保留记录；软件Vulkan截图不代表实体GPU性能。
- 本地预览 `artifacts/realism55-preview/Linux/IronMeridian --path /tmp`（相邻PCK），该目录附README/build.json/verification.json。API三项仍404，真实多人未验证，未修改服务或推送发布，保留既有未提交修改。
- 状态continue，整体目标未完成。下一轮优先院落建筑差异、道路泥草和植被分布及移动/入口碰撞，补人物近景与光照；保留第一人称回归，API可用后补真实双客户端验证。

## Stage56 — 袖管非圆截面与布料压褶（2026-09-13）
- 收窄前臂袖管，增加纵向张力起伏及斜向压褶，重建Blender/GLB与本地包；沿用已有枪械/织物材质，保留全部既有修改。
- 三武器同机位腰射/ADS/换弹15张实拍正常退出0并完成自审；换弹袖管轮廓有所改善，但正常腰射收益有限，大块迷彩、宽平枪身及重复院落仍明显。见 `docs/VISUAL_REVIEW_STAGE56.md`、`artifacts/realism56-validation/contact-sheet.jpg` 与 `stage55-56-ar-comparison.jpg`。
- 10项检查全部通过，含瞄准108样本、换弹接触183样本、抵墙、预测/可靠动作规则与单机。见 `artifacts/realism56-validation/tests.json`；导出包烟测也退出0。既有导入空纹理错误保留，软件Vulkan截图不代表实体GPU性能。
- 预览启动 `./artifacts/realism56-preview/Linux/IronMeridian --path /tmp`（相邻PCK；README/build.json/verification.json记录限制与哈希）。API三项仍404，真实多人未验证，未改服务、未推送发布。
- 状态continue，整体目标未完成。下一轮应推进院落差异、道路泥草过渡和植被分布，实拍并验证入口/移动碰撞；继续人物与光照，保留第一人称回归，API可用后补真实双客户端验证。

## Stage57 — 护木截面与袖料迷彩尺度（2026-09-13）
- AR护木改为收窄八边形壳体及斜面，袖料UV重复率增加2.6倍，重建Blender/GLB。较细迷彩的改善明确；护木被手部遮挡，正常视角收益有限，枪身大平面、偏直袖管和细钩状手指仍需改善。
- 同机位三武器腰射/ADS/换弹15张截图完成并自审，进程退出0；见 `docs/VISUAL_REVIEW_STAGE57.md`、`artifacts/realism57-validation/carbine-comparison.jpg`、`contact-sheet.jpg`。仍有重复建筑、空院落与离散草丛，整体目标未完成。
- 10项回归全部通过，含108瞄准样本、183换弹接触样本、抵墙、预测/可靠动作与单机；导出包烟测通过。证据 `artifacts/realism57-validation/tests.json`、`preview-smoke.log`；导入仍有两条空纹理错误，软件Vulkan不代表实体GPU性能。
- 本地预览 `./artifacts/realism57-preview/Linux/IronMeridian --path /tmp`，相邻README/build.json/verification.json附限制与哈希。API三项仍404，真实多人未验证；未改服务、未推送发布，保留所有既有修改。
- 状态continue。下一轮优先院落建筑差异、道路泥草过渡与植被分布，实拍并验证入口/移动碰撞；继续机匣、手臂、人物近景与光照，API可用后补真实双客户端。

## Stage58 — 手套指腹与固定机位复核（2026-09-13）
- 两手末节从尖点改为有厚度的指腹与浅圆顶，保留指尖端点、骨架和接触锚点，重建Blender/GLB。换弹可见局部改善，腰射/ADS收益很小，未新增材质改善，不代表第一人称或整体目标完成。
- 三武器腰射/ADS/换弹15张实拍退出0并自审；见 `docs/VISUAL_REVIEW_STAGE58.md`、`artifacts/realism58-validation/all-poses.jpg`、`carbine-comparison.jpg`。宽平机匣、光滑枪托、重复仓库和失真植被仍明显。
- 8项回归全部通过，含108瞄准样本、183换弹接触样本、抵墙、预测/可靠动作及16人单机；导出包独立烟测退出0。见 `artifacts/realism58-validation/tests.json`、`preview-smoke.log`。导入仍有一条空纹理错误；软件Vulkan截图不能代表实体GPU性能。
- 当前本地预览 `./artifacts/realism58-preview/Linux/IronMeridian --path /tmp`，相邻build.json/verification.json记录哈希与限制。API三项仍404，真实多人未验证；未改服务、未推送发布，保留既有修改。
- 状态continue。下一轮应推进正常腰射可见机匣/枪托/瞄具形体及材质分离，避免继续只改被遮挡细节；随后建筑差异、泥草过渡、植被/人物/光照及移动碰撞，API可用后补真实双客户端。

## Stage59 — 卡宾枪薄框瞄具、贴腮面与导出材质（2026-09-13）
- 瞄具深度40→30mm、内外半径比0.82→0.90，枪托增加贴腮肩线；机匣/聚合物加入颜色与粗糙度贴图。修正运行时重复乘暗及材质缓存隔离，重建Blender/GLB。
- 首轮三武器15张用于诊断；修复乘暗后重拍卡宾枪五姿态。完整腰射/ADS及换弹自审：瞄具开口改善明确，枪托表面更有层次，机匣仍宽平、手臂仍机械。最终图 `artifacts/realism59-validation/final-carbine/`，前后对比 `comparison-hip.jpg` / `comparison-ads.jpg`，详见 `docs/VISUAL_REVIEW_STAGE59.md`。
- 8项回归通过，含108瞄准、183接触样本及抵墙；独立导出包16演员单机烟测PASS。证据 `tests.json`、`packaged-smoke.log`。导入仍有空纹理错误；软件Vulkan不代表实体GPU性能。
- 本地启动 `./artifacts/realism59-preview/Linux/IronMeridian --path /tmp`，附许可证、README、哈希和验证记录。API三项仍404，真实多人未验证；未改服务、未推送发布，保留既有修改。
- 状态continue，整体画质未完成。下一轮实质改善正常视角手臂/腕部形体和材质，推进建筑差异、泥草过渡与植被分布，复核移动碰撞、人物及光照；接口可用后补真实双客户端。

### Stage60（2026-09-13）腕掌连续形体与粗糙度
- 将椭球掌部改为连续腕掌网格，增加织物独立粗糙度；重建Blender/GLB并导出。换弹腕掌过渡改善，腰射/ADS变化较小，指节及袖口机械感仍在。
- 三武器同相机15张已自审：`artifacts/realism60-validation/after/`、`all-poses-review.png`，stage59/60对比 `carbine-before-after.png`；详见 `docs/VISUAL_REVIEW_STAGE60.md`。
- 六项回归通过（108瞄准、183接触样本及抵墙等），导出包16演员单机烟测PASS；证据 `tests.json`、`packaged-smoke.log`。截图使用Xvfb软件Vulkan；导入空纹理错误仍保留，非实体GPU性能验证。
- 当前启动 `./artifacts/realism60-preview/Linux/IronMeridian --path /tmp`；附README、哈希、verification.json及许可证。三个API探测仍404，真实联网未验证，未修改服务或推送发布。
- 状态continue，整体目标未完成。下一步细化三握把下拇指/指节和袖口交叠，复核腰射/ADS/换弹，再推进建筑差异、泥草植被、人物光照；补人工移动碰撞和真实双客户端验证。

### Stage61（2026-09-13）指腹截面与拇指根部
- 手指改为扁平圆角截面、连续截面方向及关节皮革分区，收薄双手拇指根部；重建Blender/GLB。换弹近景圆管感减轻，腰射/ADS改善很小，整体第一人称仍未达标。
- 三武器同相机15张已自审：`artifacts/realism61-validation/after/`、`all-poses-review.png`；stage60/61对照 `carbine-before-after.png`，详见 `docs/VISUAL_REVIEW_STAGE61.md`。
- 六项回归通过（108瞄准、183接触及抵墙等），独立导出包16演员单机烟测PASS；证据 `tests.json`、`packaged-smoke.log`。导入仍有空纹理错误；截图为软件Vulkan，不代表实体GPU性能或完整人工移动巡检。
- 当前启动 `./artifacts/realism61-preview/Linux/IronMeridian --path /tmp`，附README、许可证、build.json哈希及verification.json。API三项仍404，真实联网未验证；未改服务、未推送发布，保留既有修改。
- 状态continue。下一阶段推进正常视角占比更大的仓库外部用途/尺度差异和泥草边界，复核移动碰撞；继续机匣曲面、袖口及整体握持，再推进人物、植被、光照和真实双客户端，避免持续只改遮挡细节。

### Stage62（2026-09-13）机匣、托腮与袖管大形体
- 卡宾枪加入肩部浅槽与材质层次，收窄降低托腮、区分尼龙外壳和橡胶接触垫；收薄共享袖管肘腕鼓包并重建资源。正常腰射/ADS可辨枪托变化，机匣平直与握持生硬仍未解决。
- Forward+三武器15张已自审：`artifacts/realism62-validation/forward/`、`all-poses-review.png`；stage61/62同机位对照 `carbine-before-after.png`，详见 `docs/VISUAL_REVIEW_STAGE62.md`。
- 七项回归通过：108瞄准、183换弹接触、抵墙收枪及32雨棚/96射线入口碰撞等；独立包16演员单机烟测PASS。证据 `tests.json`、`packaged-smoke.log`、`capture-forward.log`。
- 当前启动 `./artifacts/realism62-preview/Linux/IronMeridian --path /tmp`，附README、许可证、哈希与verification.json。截图为软件Vulkan；导入空纹理错误仍在，初次Compatibility截图草丛发黑。默认API三项404，真实联网未验证；未修改服务或发布。
- 状态continue，整体目标未完成。下一阶段优先实质改善仓库用途/体量差异与泥草边界，复核截图和移动碰撞；继续武器大面、自然握持、人物光照，处理导入与兼容渲染问题并补真实双客户端验证。

### Stage63（2026-09-13）霰弹枪机械切面与托腮分区
- 重建霰弹枪机匣为倒角机械切面，加入侧面嵌板、托腮与连接分区；同机位腰射/ADS圆鼓感减轻，但宽大平面与枪托、僵硬握持仍明显，手臂沿用stage62。
- 三武器15张源码Forward+截图自审：`artifacts/realism63-validation/forward/`、`all-poses-review.png`；stage62/63对照 `shotgun-before-after.png`，审阅 `docs/VISUAL_REVIEW_STAGE63.md`。
- 七项回归通过（108瞄准、183换弹接触、抵墙与32雨棚96射线等）；独立包16演员单机烟测PASS，见 `tests.json`、`packaged-smoke.log`。软件Vulkan截图不代表实体GPU性能或完整人工移动验证。
- 当前启动 `./artifacts/realism63-preview/Linux/IronMeridian --path /tmp`，附README、许可证、哈希与verification.json。导入空纹理错误仍在；Compatibility黑草未复测，API三项仍404，真实联网未验证。未修改服务或发布。
- 状态continue，整体目标未完成。下一阶段推进仓库用途/体量差异和泥草边界，复核移动碰撞；继续武器平面、自然握持、人物光照，并补兼容渲染和真实双客户端验证。

### Stage64（2026-09-13）袖管布料与卡宾枪加强筋
- 重建共享袖管：低反差橄榄布料、弱织纹法线、扩大斜向几何褶皱，修复运行时 uniform.png 覆盖源材质；卡宾枪加深侧槽、增加斜筋和钢嵌板。袖子噪声降低，仍偏软，握持和枪械大平面未解决。
- 三武器同机位15张源码Forward+截图已自审：`artifacts/realism64-validation/forward/`、`all-poses-review.png`，stage63/64对照 `carbine-before-after.png`；见 `docs/VISUAL_REVIEW_STAGE64.md`。软件Vulkan，capture.log打印15帧PASS，但启动进程最终退出143，未当作正常退出。
- 七项回归通过（108瞄准、183换弹接触、抵墙、32雨棚96射线等），独立包16演员单机烟测PASS并退出0；证据 `tests.json`、`packaged-smoke.log`。
- 当前本地启动 `./artifacts/realism64-preview/Linux/IronMeridian --path /tmp`，附README、许可证、哈希和verification.json。未做包内图形截图、实体GPU或完整人工移动验证。导入两次空纹理错误、Compatibility黑草仍待解决；默认API三项404，真实联网未验证。未修改服务或发布。
- 状态continue，整体目标未完成。下一步实质改善仓库用途/体量差异和泥草边界并复核移动碰撞；继续武器大面、自然握持、人物光照及兼容渲染，补真实双客户端验证。

### Stage65（2026-09-13）镂空枪托、袖肘形体与包内截图
- 卡宾枪实心枪托改为贯通空腔与斜撑结构，收窄托腮；共享袖管收窄肘部、重塑折叠凹槽。腰射改善受画面裁切限制，ADS仍有大平面，袖管和握持不够自然。
- 从本地PCK、以 /tmp 为运行路径完成三武器15张同机位腰射/ADS/换弹截图，PASS且退出0。已自审 `artifacts/realism65-validation/packaged-forward/`、`all-poses-review.png`、`carbine-before-after.png`，详见 `docs/VISUAL_REVIEW_STAGE65.md`。
- 六项回归全过（108瞄准、183换弹接触、抵墙等），包内16演员单机烟测PASS并退出0；见 `tests.json`、`packaged-smoke.log`、`stage-results.json`。软件Vulkan不代表实体GPU或完整人工移动验证。
- 预览：`./artifacts/realism65-preview/Linux/IronMeridian --path /tmp`，附README、许可证、哈希和verification.json。导入两次空纹理错误仍在，Compatibility黑草未复测，默认API三项404，真实双客户端联网未验证；未修改服务或发布。
- 状态continue。下一步实质改变重复仓库体量/用途和空旷泥草边界、复核新增碰撞与包内画面；继续枪械大面、袖管塑料感、人物光照及联网验证，不将本轮局部改善当作整体完成。

### Stage66（2026-09-13）机匣肩面、袖管压褶与包内验证
- 卡宾枪机匣改为十二点截面、收窄侧壁并细分肩面；共享袖管降低鼓包、收紧压褶，增加贴合补强片的骨骼缝边。实际同机位改善有限，拉机柄偏粗、布料塑料感仍在，整体目标未完成。
- 包内三武器15张腰射/ADS/换弹截图已自审，PASS且退出0：`artifacts/realism66-validation/packaged-forward/`、`all-poses-review.png`、`carbine-before-after.png`；详见 `docs/VISUAL_REVIEW_STAGE66.md`。
- 六项回归全过（108瞄准、183接触、抵墙等）；包内16演员单机烟测PASS且退出0。见 `tests.json`、`packaged-smoke.log`、`stage-results.json`。软件Vulkan，未验证实体GPU或完整人工移动。
- 本地预览：`./artifacts/realism66-preview/Linux/IronMeridian --path /tmp`，附README、哈希及verification.json。导入两次空纹理错误、Compatibility黑草仍待处理；本机API三项404，真实联网未验证。保留已有修改，未发布或修改服务。
- 状态continue。下一步实质改善重复仓库体量/用途和泥草边界，复核移动碰撞与包内画面；继续拉机柄比例、袖管布料、人物光照，并补真实双客户端验证。

### Stage67（2026-09-13）弯钩拉机柄、袖口与包内验证
- 卡宾枪拉机柄改为薄颈、不对称弯钩拨片和暗色细纹；共享袖口减薄、增加不均匀收褶，袖料导出高粗糙度纹理。腰射粗杆感减少，ADS仍有横条感，布料依旧偏软，整体目标未完成。
- 包内三武器同机位15张腰射/ADS/换弹截图PASS且退出0，已自审：`artifacts/realism67-validation/packaged-forward/`、`all-poses-review.png`、`carbine-before-after.png`；见 `docs/VISUAL_REVIEW_STAGE67.md`。
- 六项包内规则测试全过（108瞄准、183接触、抵墙等），16演员单机烟测PASS且退出0；证据 `tests.json`、`smoke.log`、`stage-results.json`。软件Vulkan，完整人工移动和实体GPU未验证。
- 本地启动 `./artifacts/realism67-preview/Linux/IronMeridian --path /tmp`，附README、哈希和verification.json。导入一次空纹理错误仍在，Compatibility黑草未复测；本机API三项404，真实联网未验证。未修改服务或发布，保留已有修改。
- 状态continue。下一步实质改善仓库体量/用途差异和道路泥草边界，补移动碰撞与场景截图；继续布料形体、握持和人物光照，后端可用时补真实双客户端验证。

### Stage68（2026-09-13）袖肘收褶、补强斜纹与UV修复
- 共享袖管收窄肘部、降低鼓包并增加定向褶皱，压暗布色；补强片分离深色斜纹材质。扩展表面规则后发现薄边UV退化，改用独立缝边材质修复，保留失败日志且未放宽阈值。
- 包内三武器15张同机位腰射/ADS/换弹截图PASS且退出0，已查看总览及stage67/68对照：`artifacts/realism68-validation/all-poses-review.png`、`carbine-before-after.png`、`packaged-forward/`；审阅见 `docs/VISUAL_REVIEW_STAGE68.md`。
- 六项包内规则测试通过（108瞄准、183接触、4材质94064三角形等），16演员单机烟测PASS且退出0，见 `stage-results.json` 及各日志。
- 本地启动 `./artifacts/realism68-preview/Linux/IronMeridian --path /tmp`，附哈希、README和验证汇总。软件Vulkan；真实联网、完整人工移动及实体GPU未验证。导入一次空纹理错误仍在，Compatibility和此前API问题未复测；未发布或修改服务，保留既有修改。
- 状态continue。袖管仍偏软管、枪身大面与握持仍不足，仓库重复/空地/扇片草明显。下一步实质改变仓库体量用途和道路泥草边界并补移动碰撞截图，继续人物与手臂画质及真实联网验证。

### Stage69（2026-09-13）前臂可见侧非对称布褶
- 共享袖管从两道圆滑隆起改为六组非对称折面，覆盖相机可见下侧，重建 Blender/GLB。腰射和 ADS 同机位对照可见斜向收褶；手臂仍厚、褶皱偏软，枪械与环境未在本轮重做，整体目标未完成。
- 导出包三武器15张腰射/ADS/换弹截图PASS且退出0，已审阅总览、对照与霰弹枪换弹/狙击ADS原图：`artifacts/realism69-validation/all-poses-review.png`、`carbine-before-after.png`、`packaged-forward/`；详见 `docs/VISUAL_REVIEW_STAGE69.md`。
- 七项包内验证通过：108瞄准样本、183换弹接触样本、遮挡规则、骨骼、材质UV、武器快照和16演员单机烟测。证据 `artifacts/realism69-validation/stage-results.json` 与各测试日志。
- 本地启动 `./artifacts/realism69-preview/Linux/IronMeridian --path /tmp`，附README、哈希和verification.json。软件Vulkan截图；真实联网、完整人工移动、实体GPU未验证。导入仍有一次空纹理错误，未复测Compatibility或此前API问题；未发布或修改后台服务，保留所有已有修改。
- 状态continue。下一阶段应实质改善枪械机匣/瞄具轮廓及材质、握持接触，复核同相机腰射/ADS；再推进仓库体量用途和泥草过渡、人物光照，补连续移动碰撞与真实双客户端验证，避免只继续微调袖管。

### Stage70（2026-09-13）卡宾枪瞄具薄壁与镂空支架
- 重建卡宾枪圆角薄框、双柱镂空底座、夹爪及分层调节旋钮，区分阳极金属/边缘/橡胶材质；保留瞄准中心与挂点。手臂沿用stage69，机匣和枪托仍厚重。
- 本轮预览包五张固定机位腰射/ADS/换弹截图PASS、退出0；已审阅原图和stage69/70对照：`artifacts/realism70-validation/carbine-before-after.png`、`optic-before-after-detail.png`、`packaged-forward/`。详见 `docs/VISUAL_REVIEW_STAGE70.md`。
- 六项包内测试通过：108瞄准、183换弹接触、贴墙规则、骨骼、武器快照及16演员单机烟测，证据 `artifacts/realism70-validation/stage-results.json`。未重跑材质UV专项；远端快照不代表真实联网。
- 本地启动 `./artifacts/realism70-preview/Linux/IronMeridian --path /tmp`，附README、哈希和verification.json。软件Vulkan；导入仍有一次空纹理参数错误。真实联网、实体GPU及完整人工移动未验证，未发布或修改服务，保留已有修改。
- 状态continue。下一步重塑机匣/枪托及握持关系，再推进仓库体量用途、道路泥草边界、人物光照，补连续移动碰撞和真实双客户端验证；不可将此次瞄具改善视为整体完成。


### Stage71（2026-09-13）卡宾枪枪托收窄及材质分层
- 重塑贴腮支承与橡胶垫渐变轮廓，去掉顶部深横槽，增加调节拨片/转轴/背带孔及尼龙、橡胶颗粒材质；重建Blender/GLB。手臂未改，机匣仍方正，整体目标未完成。
- 本轮预览包五张固定机位腰射/ADS/换弹截图PASS、退出0，已查看原图和stage70/71对照：`artifacts/realism71-validation/carbine-before-after.png`、`all-poses-review.png`、`packaged-forward/`；审阅 `docs/VISUAL_REVIEW_STAGE71.md`。
- 源项目与包内六项测试均通过：108瞄准、183换弹接触、抵墙规则、骨骼、武器快照和16演员单机烟测。证据 `artifacts/realism71-validation/stage-results.json` 及各日志。真实双客户端联网未验证，快照不代替联网。
- 本地启动 `./artifacts/realism71-preview/Linux/IronMeridian --path /tmp`，附README、哈希及verification.json。软件Vulkan；导入空纹理参数错误仍未解决，保留import.log；实体GPU和完整人工移动未验证。未发布或修改服务，保留已有修改。
- 状态continue。下一步集中改善机匣/握持连接与袖管体积，复核同相机腰射/ADS；随后推进建筑差异、道路泥草过渡、人物光照，补连续移动碰撞与真实联网，避免只继续添加枪托小零件。

### Stage72（2026-09-13）机匣凹槽、曲面握把与袖子下垂
- 移除机匣厚斜筋/叠加面板，切实体凹槽并降低亮边；握把改为七层椭圆截面，修正面朝向；袖子调整扁平截面与底部下垂，重建Blender/GLB。腰射改善可见但有限，机匣仍方正、袖手仍欠真实，整体目标未完成。
- 本轮包内五张固定机位腰射/ADS/换弹截图PASS、退出0；审阅 `artifacts/realism72-validation/carbine-before-after.png`、`all-poses-review.png` 和原图，详见 `docs/VISUAL_REVIEW_STAGE72.md`。
- 源项目和包内各六项检查通过：108瞄准、183换弹接触、抵墙规则、骨骼、武器快照及16演员单机烟测。证据 `artifacts/realism72-validation/stage-results.json` 和原始日志。真实双客户端联网、实体GPU和完整人工连续移动未验证；导入空纹理参数错误仍在 `import.log`。
- 本地预览 `./artifacts/realism72-preview/Linux/IronMeridian --path /tmp`，附README、哈希和verification.json。软件Vulkan实机截图；保留已有修改，未发布、未改后台服务。
- 状态continue。下一阶段优先建筑用途/体量差异及道路泥草边界，并补连续移动碰撞与真实联网；第一人称整体轮廓/手部解剖、人物和光照仍待改进，不应继续只堆枪械小零件。

### Stage73（2026-09-13）：手背网格与独立包复核，continue
- 手背浮动椭圆护垫改为连续皮革材质区，加入浅掌骨起伏、减弱手套织物法线；重建第一人称 Blender/GLB，保留全部既有修改。
- 源码和独立包各七项测试通过（ADS 108、换弹接触 183 样本及阻挡/单机等）；独立包 Forward+ 软件 Vulkan 采集同相机腰射、ADS、三个换弹时点。
- 证据：artifacts/realism73-validation/stage-results.json、carbine-before-after.png、glove-before-after.png、all-poses-review.png；审阅 docs/VISUAL_REVIEW_STAGE73.md。正常视距变化很弱，手背仍扁平，袖口厚重、枪身拼装感及重复环境未解决，整体未完成。
- 当前预览：artifacts/realism73-preview/Linux/IronMeridian（同目录 PCK、README、哈希与验证记录）。导入仍有 Parameter t is null；实际联网、实体 GPU、完整人工碰撞遍历未验证。本轮未读取联网凭据或发布。
- 下一步：优先重塑手掌横截面/指根过渡和袖口厚度，以正常视距可见的形体改善为验收，复核同相机腰射/ADS/换弹；后续继续人物、场景差异和真实联网验证。

### Stage74（2026-09-13）：掌部曲面与袖口收束，continue
- 收束袖口、掌部改为圆截面并加入支撑手内收曲率，重建第一人称 Blender/GLB。实际对照显示正常视距改善有限，换弹掌部仍硬片状，未达到形体验收；没有将微调视为整体完成。
- 源码和独立包各七项测试通过，共14项，包含108瞄准/183换弹接触样本、武器阻挡与16演员单机烟测；包内同机位五张 Forward+ 软件 Vulkan 截图退出0。证据 `artifacts/realism74-validation/stage-results.json`、`comparison-all-poses.jpg`、`comparison-hand-crop.png`；审阅 `docs/VISUAL_REVIEW_STAGE74.md`。
- 预览：`./artifacts/realism74-preview/Linux/IronMeridian --path /tmp`，同目录README、PCK、哈希及验证记录。导入空纹理参数错误仍在；真实联网、实体GPU及完整人工移动碰撞未验证，未读取认证密钥、未发布、保留既有修改。
- 下一步：重做掌部/拇指根/支撑手指根连接造成的硬片轮廓，不继续只调半径；以正常视距换弹、腰射和ADS对照验收。人物、建筑差异、地表植被、光照及真实联网仍需继续。

### Stage75（2026-09-13）：掌部朝内法线修复，continue
- 修复两手672个掌部侧面绕序、封闭四端并补UV，加入逐面朝外断言；重建 Blender/GLB 与独立包。实际同机位对照显示腰射/ADS无明显新增遮挡，但换弹掌面硬片感仍在，正常视距改善很弱，形体验收未通过。
- 源码/包内各七项测试通过，共14项（108瞄准、183换弹接触及阻挡/单机等）。五张包内 Forward+ 软件 Vulkan 截图、前后对照、日志见 `artifacts/realism75-validation/stage-results.json`、`comparison-all-poses.jpg`、`comparison-hand-crop.png`；审阅 `docs/VISUAL_REVIEW_STAGE75.md`。
- 本地预览：`./artifacts/realism75-preview/Linux/IronMeridian --path /tmp`，附PCK、README、哈希及验证记录。导入空纹理参数错误仍在；真实联网、实体GPU和完整人工移动碰撞未验证。保留既有修改，未发布。
- 下一步：实质重做掌面/拇指根/指根连接与连续材质过渡，避免只修法线或微调半径，以正常视距形体改善验收；继续人物、建筑差异、地表植被、光照与真实联网，整体目标未完成。

### Stage76（2026-09-13）：手套连续曲面重建，continue
- 将左右手各15个零件体素融合、平滑连接、重做UV及材质转移，重建Blender/GLB；拓扑审计右手单主体、左手主体加80顶点小岛，两手无非流形边。实际同机位腰射/ADS无明显退步，但换弹掌面仍硬片状，正常视距改善有限，形体验收未通过。
- 源码/独立包各七项回归共14项通过（108瞄准、183换弹接触、阻挡及单机等）。五张包内Forward+软件Vulkan截图已保存且有捕获PASS标记，但进程退出143，不能称正常退出。证据 `artifacts/realism76-validation/stage-results.json`、`comparison-all-poses.jpg`、`comparison-hand-crop.png`；审阅 `docs/VISUAL_REVIEW_STAGE76.md`。
- 预览：`./artifacts/realism76-preview/Linux/IronMeridian --path /tmp`，附PCK、README、哈希及验证记录。导入空纹理参数错误仍在；真实联网、实体GPU、完整人工移动碰撞与性能未验证。保留既有修改，未发布。
- 下一步：直接重塑可见掌面与护垫分区，消除硬片边条并审视枪托/握把/机匣比例；检查截图退出异常和网格成本。继续人物、建筑差异、地表植被、光照及真实联网，整体目标未完成。

### Stage77 — 手掌细分修复、网格预算与弹匣诊断
- 应用手掌细分后融合、调整掌部织物/皮革，并按材质边界简化；检查三角形183546→85836。重建第一人称资产，14项源码/包内回归通过。
- 同机位腰射、ADS和三段换弹5张截图完成，Forward+软件Vulkan捕获退出0；画面改善有限。橙红材质标记实证确认半程换弹尖角深色块是Magazine，不是手掌。
- 证据：docs/VISUAL_REVIEW_STAGE77.md、artifacts/realism77-validation/（截图、诊断、test-results.json）；可运行包 artifacts/realism77-preview/Linux/IronMeridian（--path /tmp）。导入空纹理参数错误仍在，真实联网/实体GPU/人工全场碰撞未验证，整体continue。
- 下一步：优先改 tools/build_assets.py carbine Magazine 轮廓曲面、倒角及结构细节，保持抓握接触；重拍相同相机腰射/ADS/换弹，勿再把弹匣误判为手掌。再推进建筑植被光照及真实联网验证。

### Stage78 — 曲面弹匣与五姿态复核（continue）
- 重建卡宾枪弹匣弯曲圆角壳体、筋条、底板和注塑材质，保留运行时Magazine节点；生成Blender/GLB与独立预览包。同相机半程裁切尖角暗面减弱，但弹匣仍被掌面遮挡，手腕和枪托构图仍生硬，正常视距整体改善有限。
- 源码/包内各8项共16项PASS，包括108瞄准、183接触样本、雨棚射线与单机冒烟。五张包内Forward+软件Vulkan截图捕获PASS、退出0。
- 证据：`docs/VISUAL_REVIEW_STAGE78.md`、`artifacts/realism78-validation/test-results.json`、`comparison-all-poses.jpg`、`comparison-hand-crop.png`。预览：`./artifacts/realism78-preview/Linux/IronMeridian --path /tmp`，附PCK、哈希及验证记录。
- 导入空纹理参数错误仍在；真实联网、实体GPU性能、全场人工移动碰撞未验证。保留未提交修改，未发布，整体目标未完成。
- 下一步：调整换弹枪托朝向和弹匣握持可见性，继续掌面/腕部形体；固定机位复核后推进建筑差异、植被光照及真实联网验证。

### Stage79 — 换弹侧面展示与持弹匣手可见性（continue）
- 换弹新增峰值0.35弧度偏航，弹匣下移0.32→0.22；同机位截图显示枪托侧面更清楚、持弹匣手较完整，腰射与ADS保持稳定。未重建网格/材质，掌面、腕部仍生硬，整体写实目标未完成。
- 源码/包内16项检查全部PASS。源码五帧截图报告PASS但会话退出143；测试调度中断后仅续跑剩余5项并退出0。最终包内五帧Forward+软件Vulkan截图PASS且退出0，异常如实保留。
- 证据：`docs/VISUAL_REVIEW_STAGE79.md`、`artifacts/realism79-validation/comparison-all-poses.jpg`、`test-results.json`、`capture-status.json`。失败前移姿态单独归档，不作最终证据。
- 预览：`./artifacts/realism79-preview/Linux/IronMeridian --path /tmp`，附PCK、build.json与verification.json。标准release模板缺失，使用仓库Godot+export-pack；未发布。历史导入错误未复测；真实联网、实体GPU、全场人工碰撞仍未验证。
- 下一步：实质改进掌面/腕部形体并拍摄其他武器，再推进建筑差异、植被光照和真实联网验收；不要把本轮姿态改善当作整体完成。

### Stage80 — 手套表面补片、同机位三武器复核
- 为左右手各增加两块贴合表面的薄皮革补片，降低手套/皮革微法线并提高皮革粗糙度；重建Blender与GLB。首次宽补片投射失败已缩窄修正，保留失败日志；Godot导入仍有dummy纹理空参数错误，未声称修复。
- 实际Forward+/llvmpipe截图：源码5张、包内3武器15张；同机位stage79/80腰射、ADS及换弹对照见`artifacts/realism80-validation/comparison-hip-ads.jpg`、`comparison-reload.jpg`和`packaged-contact-sheet.jpg`。改善细微，手指/袖口、枪身平板感与重复场景仍明显。
- 源码/包内各8项检查全部PASS，见`artifacts/realism80-validation/test-results.json`；截图索引`capture-status.json`。真实联网未运行：现有脚本读取认证密钥，不符合本轮约束；未修改认证/服务。
- 本地可运行预览：`artifacts/realism80-preview/Linux/IronMeridian --path /tmp`，同目录有PCK、README和构建/验证索引；审阅`docs/VISUAL_REVIEW_STAGE80.md`。状态continue。
- 下一步：实质重塑掌根、指关节和袖口过渡，改善枪身材质分区，再以同相机三武器腰射/ADS/换弹复核；继续人物、建筑、植被、光照及合规的真实联网验收。

### Stage81 — 第一人称袖口与手背形体、包内同机位验收
- 袖口改为25圈连续收缩曲面，9排搭扣贴合布料；调整左右手手背朝向与厚度，重建 Blender/GLB。换弹硬环感减弱，腰射/ADS整体改善有限；本轮没有改武器本体。
- 保存源码5张、包内三武器15张实际 Forward+ 截图并审阅：`artifacts/realism81-validation/comparison-hip-ads.jpg`、`comparison-reload.jpg`、`packaged-contact-sheet.jpg`；完整结论 `docs/VISUAL_REVIEW_STAGE81.md`。
- 源码/包内各8项检查全部子进程退出0且PASS（单机、瞄准、换弹、阻挡与碰撞等），见 `test-results.json`。外层验证进程最终143，原因未确定，已保留异常；导入dummy renderer错误仍在。软件渲染截图不证明硬件性能，remote_snapshot不代表真实联网，本轮未读取认证密钥或运行依赖密钥的联网脚本。
- 本地预览：`artifacts/realism81-preview/Linux/IronMeridian --path /tmp`；同目录保留PCK，`build.json`、`verification.json`提供校验与证据。未push或外部发布。
- 下一步优先实质改进机匣/护木轮廓及金属/聚合物分区，并修正换弹左拇指细长弯管形体；继续同相机三武器验收。人物、重复建筑、平坦地形与植被、光照和真实联网仍未完成。状态continue，不以局部袖口修正宣称总体完成。

### Stage82 — 卡宾枪护木轮廓、金属分区与包内验收
- 护木改12面截面、收缩前端及圆角通风孔，增加上部切口和聚合物护片厚度，调整金属分区/粗糙度；重建Blender/GLB。本轮手臂未改，腰射可见改善、ADS改善有限，机匣平板与拇指圆管问题仍在。
- 同机位源码5帧、包内5帧实机截图：`artifacts/realism82-validation/comparison-hip.png`、`comparison-ads.png`、`packaged-contact-sheet.jpg`；审阅 `docs/VISUAL_REVIEW_STAGE82.md`。建筑、植被、光照及人物整体目标未完成。
- 源码/包内各6项共12项测试退出0且PASS，见 `artifacts/realism82-validation/test-results.json`。源码截图和首次验证外层143原因未明；源码5帧与PASS标记已保存，恢复验证退出0，包内截图退出0；`capture-status.json`记录截图与状态。导入dummy纹理错误仍在。真实联网未运行，remote_snapshot仅本地规则检查。
- 本地预览 `artifacts/realism82-preview/Linux/IronMeridian --path /tmp`，同目录PCK、README、build.json、verification.json；未push或发布。状态continue。
- 下一步：实质重塑机匣与左拇指关节/掌根，同机位三武器腰射/ADS/换弹复核；继续人物、重复建筑、地形植被、光照和符合密钥约束的真实联网验收。

### Stage83 — 支撑手拇指与掌根重塑、三武器包内复核
- 拇指改独立两处关节压缩与渐变扁平截面，扩大掌根/虎口、调整弯曲控制点，重建Blender/GLB。换弹近景中细弯管感减弱；手套仍简化，袖子管状与枪身块状问题未解决。
- 同机位源码/包内各15张、共30张Forward+软件渲染截图，两个采集进程均退出0且PASS；实际审阅三武器腰射/ADS和换弹三时刻。证据：`artifacts/realism83-validation/thumb-before-after.png`、`packaged-aim-pairs.jpg`、`packaged-reload-poses.jpg`、`capture-status.json`；完整审阅 `docs/VISUAL_REVIEW_STAGE83.md`。
- 源码/包内各6项共12项功能检查均退出0且PASS，见 `artifacts/realism83-validation/test-results.json`，涵盖单机、瞄准、换弹接触、近墙遮挡及视模规则。导入退出0但dummy纹理错误仍在；真实联网未运行，remote_snapshot不等于联网通过，地图碰撞也未全面遍历。
- 本地预览：`artifacts/realism83-preview/Linux/IronMeridian --path /tmp`，保留同目录PCK；README、build.json、verification.json记录运行方法和校验。标准发布模板缺失，采用Godot可执行文件+PCK。未push或外部发布，保留既有修改。状态continue。
- 下一步：重塑卡宾枪机匣主要截面和部件连接，改善金属/聚合物分区并同机位验收；继续人物、重复建筑、地形植被、光照，以及符合密钥约束的真实联网和更广碰撞验证。不得以本轮局部手形改善认定整体完成。

### Stage84 — 卡宾枪机匣截面与表面改善、独立预览复核
- 上机匣改16点截面与8个纵向站点，收束侧壁、平顺肩线，调整圆角凹槽及固定销；降低金属斑驳/凹凸噪声，重建Blender/GLB。机匣仍厚重偏暗，金属/聚合物区别不足；本轮手臂沿用stage83。
- 源码/包内各5张同机位Forward+截图，两个采集进程均退出0且PASS，已审阅腰射、ADS及三个换弹时刻。证据：`artifacts/realism84-validation/receiver-before-after.png`、`packaged-aim-pairs.jpg`、`packaged-reload-poses.jpg`、`capture-status.json`；完整审阅 `docs/VISUAL_REVIEW_STAGE84.md`。
- 源码/包内各6项共12项功能检查退出0且PASS，涵盖瞄准、换弹接触、近墙遮挡、视模及单机流程，见 `artifacts/realism84-validation/test-results.json`。导入退出0但dummy纹理错误仍在；真实联网未运行，remote_snapshot仅进程内规则；全地图碰撞未验收。
- 本地可运行预览：`artifacts/realism84-preview/Linux/IronMeridian --path /tmp`，保留同目录PCK；README、build.json、verification.json保存说明与校验。标准发布模板缺失，继续使用Godot可执行文件+PCK。未push或发布，保留既有修改；状态continue。
- 下一步：实质改善长管状袖子、袖口及腕掌过渡，同机位检查三武器腰射/ADS/换弹；随后推进重复建筑、空旷地面、人物与光照，并完成符合密钥约束的真实联网及更广碰撞验证。整体画质目标未完成。

### Stage85 — 袖子体积、斜向压褶与袖口收束
- 增厚袖子截面，减弱连续细折线并增加宽压褶，平滑袖口到腕部的过渡；重建Blender/GLB。换弹袖子更饱满，但布料仍偏均匀、软塑料感未消除，枪身与场景整体写实目标未完成。
- 源码/包内各5张卡宾枪同机位腰射、ADS及三个换弹时刻，采集均退出0且PASS。已审阅 `artifacts/realism85-validation/sleeve-before-after.jpg`、`packaged-aim-pairs.jpg`、`packaged-reload-poses.jpg`；索引 `capture-status.json`，审阅 `docs/VISUAL_REVIEW_STAGE85.md`。另外两种武器本轮未做新袖子实机截图。
- 源码/包内各6项共12项功能检查退出0且PASS，含三武器瞄准、换弹接触、近墙遮挡、视模及单机流程，见 `artifacts/realism85-validation/test-results.json`。导入退出0但dummy纹理错误仍在；软件Vulkan不代表硬件性能，真实联网及全地图碰撞未验收。
- 本地预览 `artifacts/realism85-preview/Linux/IronMeridian --path /tmp`，保留同目录PCK；README、build.json、verification.json记录运行与校验。标准导出模板缺失，使用Godot可执行文件+PCK；未push或发布，保留既有修改。状态continue。
- 下一步：补查另外两种武器新袖子的腰射/ADS/换弹，推进仓库入口及道路边缘的建筑变化与地表植被层次并多机位复核；继续人物、光照、符合密钥约束的真实联网和更广地图碰撞验收。

### Stage86 — 袖料织纹与三武器同机位复核
- 增加可平铺的多尺度染色、细纱、防撕裂线及加强部位斜纹，调整袖料颜色和微法线，重建Blender/GLB；本轮形体沿用stage85。布料层次改善，但褶皱规则、腕掌简化和武器厚重问题仍在，整体目标未完成。
- 源码/包内各15张三武器腰射、ADS及三个换弹时刻，两个采集进程退出0且PASS，均已审阅。证据：`artifacts/realism86-validation/sleeve-before-after.jpg`、`packaged-aim-pairs.jpg`、`packaged-reload-poses.jpg`、`capture-status.json`；审阅 `docs/VISUAL_REVIEW_STAGE86.md`。
- 源码/包内各6项共12项功能检查退出0且PASS，涵盖瞄准、换弹接触、近墙遮挡、视模及单机，见 `artifacts/realism86-validation/test-results.json`。六个构建哈希校验一致。导入退出0但已有dummy纹理错误仍在；软件Vulkan截图不代表硬件性能，真实联网及全地图碰撞未验收。
- 本地可运行预览：`artifacts/realism86-preview/Linux/IronMeridian --path /tmp`，保留同目录PCK；README、build.json、verification.json记录运行与验证。标准导出模板缺失，使用Godot可执行文件+PCK；未push或发布，保留既有修改。状态continue。
- 下一步：优先修整霰弹枪宽厚后部与枪托材质、手套腕掌过渡，同机位复查；随后改善仓库入口、道路边缘和植被并增加机位，继续人物、光照、真实联网及更广地图碰撞验证。

### Stage87 — 霰弹枪枪托轮廓与材质映射
- 收窄枪托颈部、降低贴腮垫并下沉托底，调整肩垫/背带座，补充变体网格按尺寸投影的UV，重建Blender/GLB。腰射与ADS宽楔形占屏减轻，但机匣仍方厚、手腕仍呈管状；整体目标未完成。
- 已审阅源码/包内三武器各15张腰射、ADS、换弹截图；证据 `artifacts/realism87-validation/shotgun-before-after.jpg`、`packaged-aim-pairs.jpg`、`packaged-reload-poses.jpg`、`capture-status.json`；详见 `docs/VISUAL_REVIEW_STAGE87.md`。包内首次会话143中断，第三把武器五姿态补采退出0，其余10张保留，未隐去中断记录。
- 源码/包内共12个功能测试子进程退出0且PASS，覆盖瞄准、接触、遮挡、视模和单机；外层验证会话结果落盘后返回143，原因未知，见 `test-results.json`、`runner-status.json`。构建/导入/导出退出0，七个产物哈希一致；已有dummy纹理导入错误仍在，真实联网、全地图碰撞未验收。
- 本地预览：`artifacts/realism87-preview/Linux/IronMeridian --path /tmp`，保留同目录PCK；README、build.json、verification.json记录运行及验证。未push或发布，保留原有修改。状态continue。
- 下一步：实质调整手套腕掌过渡及指节，复核三武器同机位腰射/ADS/换弹；随后推进仓库入口、道路边缘、植被多机位审阅，并继续人物、光照、真实联网和更广地图碰撞验证。

### Stage88 — 手套腕掌过渡与掌背形体
- 增加掌部截面、收窄腕部并调整掌背指节及压褶，重建Blender/GLB；本轮沿用原材质。半程换弹右腕更收束，但腰射变化较小、左掌仍偏平、袖筒仍粗，整体目标未完成。
- 源码/预览包各15张三武器同机位腰射、ADS及换弹截图，两个采集进程退出0且PASS；已审阅对照图。证据 `artifacts/realism88-validation/wrist-before-after.jpg`、`packaged-aim-pairs.jpg`、`packaged-reload.jpg`、`capture-index.json`；详见 `docs/VISUAL_REVIEW_STAGE88.md`。
- 源码/包内共14项检查及验证主进程退出0，覆盖材质规则、瞄准、接触、遮挡、视模和单机；结果见 `artifacts/realism88-validation/test-results.json`、`verification.json`。构建/导入/导出退出0，已有dummy纹理导入错误仍在；软件Vulkan不代表硬件性能，真实联网和全地图碰撞未验收。
- 本地可运行预览：`artifacts/realism88-preview/Linux/IronMeridian --path /tmp`，保留同目录PCK；README及build.json记录启动与哈希。未push或发布，保留既有修改。状态continue。
- 下一步：优先重塑左掌弧度、虎口及手指轮廓，消除可见平板掌面，再处理袖口厚度和纹理尺度；随后继续建筑、道路植被、人物、光照及实际多人和地图碰撞验证。

### Stage89 — 支撑掌弧度与虎口调整、固定机位复核
- 增加左掌横向弧度、收束虎口并调整指根，重建Blender/GLB及本地预览；沿用材质。实机腰射改变较小，换弹掌面仍偏平、袖筒仍粗，未达到整体画质目标。
- 源码/包内14项检查均退出0，覆盖单机、瞄准、换弹接触和近墙遮挡；真实联网、全地图碰撞未验收。构建/导入/导出退出0，既有dummy纹理错误仍在；软件Vulkan不代表硬件性能。
- 保存并审阅源码/包内各15张三武器同机位腰射、ADS、换弹截图。首次源码采集退出143（15张及PASS），包内首次退出143（14张无PASS）；包内第三武器补采退出0且PASS。证据：`artifacts/realism89-validation/verification.json`、`capture-index.json`、`wrist-before-after.jpg`、`packaged-aim-pairs.jpg`、`packaged-reload.jpg`；审阅见 `docs/VISUAL_REVIEW_STAGE89.md`。
- 本地预览：`artifacts/realism89-preview/Linux/IronMeridian --path /tmp`，同目录PCK配套；README与build.json记录运行和哈希。保留未提交修改，未push或发布。状态continue。
- 下一步：改变掌指、虎口和袖口的主要轮廓，避免继续只有毫米级微调；改善枪身与手套材质层次并同机位复核，再推进建筑植被、人物光照、真实联网和地图碰撞验证。

### Stage90 — 前臂袖子与袖口收形、独立预览复核
- 收紧前臂末端与袖口、减弱腕部鼓包和褶皱位移，重建 Blender/GLB。stage89→90 同机位对照显示换弹右腕改善，掌面仍连片、前臂仍管状、枪身材质仍简单，整体目标未完成。
- 源码和包内各7项检查全部退出0（共14项），覆盖单机、瞄准、换弹接触、近墙遮挡等；真实联网与全地图碰撞尚未验证。构建/导入/导出退出0，导入仍有已有 Parameter "t" is null 日志；llvmpipe截图不代表硬件性能。
- 两次完整截图采集均退出0且PASS，各15张三武器同机位腰射、ADS及换弹截图，已审阅源码/包内拼图。证据：`artifacts/realism90-validation/verification.json`、`capture-index.json`、`wrist-before-after.jpg`、`packaged-aim-pairs.jpg`、`packaged-reload.jpg`；审阅见 `docs/VISUAL_REVIEW_STAGE90.md`。
- 当前本地预览：`artifacts/realism90-preview/Linux/IronMeridian --path /tmp`，保留同目录PCK；README和build.json记录运行方法及哈希。保留全部既有修改，未push或发布。状态continue。
- 下一步：停止仅调袖子参数，实质完善AR机匣/护木/握把的倒角、零件接缝与金属/聚合物材质分层，并处理换弹连片掌指；同机位腰射/ADS/换弹复核后继续人物、建筑植被光照、真实联网及地图碰撞。

### Stage91 — AR护木重叠修复与握把材质分层
- 修复上机匣遮挡护木开孔，增加后端夹持件、螺钉和装配接缝，握把侧面增加独立橡胶贴图材质；重建Blender/GLB和本地预览。腰射/ADS改观有限，掌指连片、管状前臂和重复场景仍明显，整体目标未完成。
- 源码/包内各10项检查共20项PASS，覆盖三武器瞄准/接触、单机、入口/屋顶碰撞和联网状态规则；真实多人和全地图碰撞仍未验收。构建/导入/导出退出0，导入仍有已有 Parameter "t" is null。
- 源码与包内AR各5张同机位腰射、ADS、换弹实机截图已审阅，两次采集退出0且PASS。证据：`artifacts/realism91-validation/verification.json`、`test-results.json`、`capture-index.json`、`stage90-91-comparison.jpg`、`packaged-contact.jpg`；审阅见 `docs/VISUAL_REVIEW_STAGE91.md`。llvmpipe不代表硬件性能。
- 本地预览：`artifacts/realism91-preview/Linux/IronMeridian --path /tmp`，同目录PCK配套；README/build.json记录运行及哈希。保留未提交修改，未push或发布。状态continue。
- 下一步：优先实质重塑换弹掌指、虎口和抓握轮廓，避免仅增加枪身微细节；继续人物、建筑植被光照及真实联网/地图碰撞验证。

### Stage92 — 支撑手轮廓调整与三武器同机位复核
- 调整四指长度、展开与弯曲轮廓，减小拇指根部截面，重建 Blender/GLB；沿用既有材质。手指仍偏管状，掌面和袖口偏厚，本轮调整未达到第一人称整体写实验收。
- 源码/包内各10项检查共20项PASS，覆盖三武器瞄准、换弹接触、遮挡、单机、入口/屋顶碰撞和网络状态规则；未新增真实多人验证。构建/导入/导出退出0，导入仍有 Parameter "t" is null。
- 保存并审阅42张实机截图：源码/包内Compatibility各15张、Forward+腰射/ADS各6张，四次采集退出0且PASS。三武器中央瞄准区可见；Compatibility植被偏黑，llvmpipe不代表硬件性能。证据：`artifacts/realism92-validation/verification.json`、`test-results.json`、`screenshot-index.json`及四张contact总览；详见 `docs/VISUAL_REVIEW_STAGE92.md`。
- 当前本地预览：`artifacts/realism92-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，保留同目录PCK；README/build.json记录启动和哈希。保留全部未提交修改，未push或发布。状态continue。
- 下一步：重塑掌面、虎口和袖口截面并校准材质尺度，补三武器同机位Forward+换弹近景；修复黑植被/null错误，继续人物、重复建筑、地形光照及真实联网验证。

### Stage93 — 手套截面、袖口与纹理尺度
- 收紧袖口、缩小虎口并压薄掌指，按实际表面积统一手套 UV 岛纹理尺度，重建 Blender/GLB。同机位截图显示有限改善，但拇指与袖子仍偏管状，整体目标未完成。
- 源码与预览包各10项检查通过，共20项，覆盖瞄准、换弹接触、遮挡、单机、入口/屋顶碰撞及网络状态规则；未验证真实多人。导入退出0仍报 `Parameter "t" is null`。驱动退出143原因未明，恢复完成剩余检查并保留中断记录。
- 已保存并审阅30张Forward+实机截图（三武器各腰射/ADS/三个换弹姿态，源码与包内各15张）。证据：`artifacts/realism93-validation/verification.json`、`test-results.json`、`screenshot-index.json`、`source-forward-contact.jpg`、`packaged-forward-contact.jpg`；审阅见 `docs/VISUAL_REVIEW_STAGE93.md`。llvmpipe不代表硬件性能。
- 当前本地预览：`artifacts/realism93-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，保留同目录PCK；README/build.json记录运行方法及哈希。保留全部未提交修改，未push或发布。状态continue。
- 下一步：实质重塑拇指指节、虎口与抓握轮廓及袖子褶皱，避免只微调尺寸；继续枪身材质分区、人物与重复环境改造，修复导入null并补无需读取密钥的真实联网验证。

### Stage94 — 拇指关节截面与同机位复核
- 支撑拇指改为六点中心线，收窄中段、压平指腹并增加关节隆起；右拇指补用专用截面，重建 Blender/GLB。同机位腰射/ADS对比表明改善很小，仍有连续管状感，换弹抓握掌面偏厚；不能作为第一人称整体写实改善完成。
- 源码与包内各10项功能检查通过，共20项；导出及两次截图采集也通过，驱动正常退出0。保存并审阅30张Forward+实机截图（三武器各腰射/ADS/三个换弹姿态）。未验证真实多人；导入退出0仍报 `Parameter "t" is null`，llvmpipe不代表硬件性能。
- 证据：`artifacts/realism94-validation/verification.json`、`test-results.json`、`screenshot-index.json`、两张forward-contact总览及 `stage93-94-hand-comparison.png`；审阅见 `docs/VISUAL_REVIEW_STAGE94.md`。
- 当前本地预览：`./artifacts/realism94-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，保留同目录PCK；预览目录README/build.json记录运行方法与哈希。保留全部未提交修改，未push或发布。状态continue。
- 下一步：用明确的近节/远节体块和指腹接触面替换连续管状抓握形体，先审阅同机位腰射/ADS确认可见改善，再扩大验证；继续枪械材质、袖子、人物、重复建筑与植被及光照，修复导入null并补真实联网验证。

### Stage95 — 分节拇指与源码/包内同机位复核
- 拇指改为分段中心线、压平指腹及收窄近节，减少体素平滑，重建Blender/GLB。同机位腰射/ADS原生像素对照显示轮廓更有转折，但仍偏细长硬条，掌面厚、袖子筒状；整体画质目标未完成。
- 源码与包内各10项功能检查通过，共20项；加导出与两次采集共23条成功记录，驱动退出0。保存30张完整采集截图与2张快速截图，查看两组总览及关键原图。未验证真实多人；导入退出0仍报 `Parameter "t" is null`，软件Vulkan不代表硬件性能。
- 证据：`artifacts/realism95-validation/verification.json`、`test-results.json`、`screenshot-index.json`、`stage94-95-hand-comparison.png`、两张forward-contact总览；审阅见 `docs/VISUAL_REVIEW_STAGE95.md`。
- 本地预览：`./artifacts/realism95-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，保留同目录PCK；README记录运行方法，build.json六个文件哈希已核对。保留全部未提交修改，未push或发布。状态continue。
- 下一步：成组重塑掌面、虎口、指腹接触面与袖子褶皱，避免继续孤立微调拇指；实质改进武器材质与结构，再推进人物、建筑、地形植被和光照。修复导入null，并补真实联网与更广泛碰撞检查。

### Stage96 — 连续袖褶与固定机位预览复核
- 将堆叠鼓包袖褶替换为连续布面、斜向窄压褶与纵向收束，缩小支撑虎口并调整拇指中间关节，重建Blender/GLB。同机位腰射袖褶更明确，ADS改善较小；袖子仍筒状、拇指接触生硬、掌面偏厚，本轮未改善枪械材质，整体目标未完成。
- 源码与包内各10项检查通过，含单机、瞄准、换弹接触、遮挡及门口/屋顶碰撞；加导出与两次采集共23条成功记录，驱动退出0。保存30张Forward+截图，审阅两组总览和关键原图，核对30个截图及6个构建文件哈希。真实多人未验证；导入退出0仍报 `Parameter "t" is null`；llvmpipe不代表硬件性能。
- 证据：`artifacts/realism96-validation/verification.json`、`test-results.json`、`screenshot-index.json`、`stage95-96-hand-comparison.png`、两张forward-contact总览；审阅见 `docs/VISUAL_REVIEW_STAGE96.md`。
- 本地预览：`./artifacts/realism96-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，保留同目录PCK；README/build.json记录运行方法和哈希。保留全部未提交修改，未push或发布。状态continue。
- 下一步：成组改进枪械机匣/护木材质与握持手形，先检查同机位腰射/ADS，避免继续孤立微调拇指；推进人物、建筑差异、地形植被与光照，排查导入null并补真实联网及更广泛碰撞验证。

### Stage97 — 机匣凹面与运行时法线保留
- 将卡宾枪浅矩形槽改为带斜端的布尔凹面，重建Blender/GLB并加入金属微表面法线；修复运行时材质覆盖资产法线的问题，新增两个实际烘焙法线材质的保留检查。本轮未重塑手臂。
- 同机位腰射/ADS对照显示局部切口感减轻，但ADS变化很小，枪身仍大块、手掌厚且袖子筒状；人物、重复建筑和稀疏植被仍待改善，整体目标未完成。
- 源码和包内各11项功能检查通过，共22项；加导出与两次采集共25条成功记录，驱动退出0。保存30张Forward+截图，审阅两组总览和关键原图，核对30个截图及11个构建文件哈希，git diff --check通过。真实多人未验证；导入退出0仍报 Parameter "t" is null；llvmpipe不代表硬件性能。
- 证据：artifacts/realism97-validation/verification.json、test-results.json、screenshot-index.json、stage96-97-receiver-comparison.png及两张forward-contact总览；审阅见 docs/VISUAL_REVIEW_STAGE97.md。保留早期断言失败日志，最终全套复验通过。
- 本地预览：`./artifacts/realism97-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，保留同目录PCK；README/build.json记录方法和哈希。保留全部未提交修改，未push或发布。状态continue。
- 下一步：成组重塑机匣轮廓与掌面/虎口/指腹接触关系，同机位检查腰射、ADS和换弹，避免继续仅微调凹槽；推进人物、建筑差异、地形植被与光照，修复导入null并补真实联网和更广泛碰撞验证。

### Stage98 — 机匣肩线与袖管掌背形体
- 收窄卡宾枪上机匣肩部并调整金属底色，重塑袖管截面和弯曲轮廓、压平掌背；重建Blender/GLB，修复右手减面后的重复三角形并复核保存网格。
- 同机位腰射/ADS及源码、包内两组15姿态截图已审阅：ADS斜面更清楚，袖子略扁，但改善有限，枪身仍厚重、手指生硬、袖口缺层次；重复建筑和稀疏植被仍明显，整体目标未完成。
- 22项功能检查通过，共25条成功记录，30张截图及11个构建文件哈希核对通过。首次驱动包内采集时退出143，保留日志；resume仅补未完成采集并退出0。真实多人未验证；导入退出0仍报Parameter "t" is null；截图使用llvmpipe。
- 证据：artifacts/realism98-validation/verification.json、test-results.json、final-mesh-topology.log、stage97-98-viewmodel-comparison.png及两张forward-contact总览；审阅见docs/VISUAL_REVIEW_STAGE98.md。
- 本地预览：`./artifacts/realism98-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，保留相邻PCK；README/build.json记录运行方法和哈希。保留未提交修改，未push或发布。状态continue。
- 下一步：实质重构手指包握、虎口与袖口层次并核查腰射/ADS/换弹接触；继续人物、建筑差异、地形植被与光照，排查导入null并补真实联网及更广泛碰撞验证。

### Stage99 — 拇指连续曲面、瞄具肩线与动画导出修复
- 调整拇指中心线和椭圆截面、收窄瞄具上部肩线，重建Blender/GLB。发现完整资产构建残留第三人称动作，使第一人称导出19个动作；清除残留后完整重建，确认仅Heal/Hold/Reload/Throw四个动作，保存网格校验通过。
- 已审阅同机位腰射/ADS、换弹原图及源码/包内姿态总览。拇指转折与瞄具轮廓有局部改善，但细长拇指、僵硬握持、厚重枪身和单调袖管仍明显；本轮没有实质改善人物、建筑、地形植被和光照，整体目标未完成。
- 最终驱动退出0：22项功能检查、导出和两次截图采集共25条成功记录；30张截图及11个构建文件哈希核验，git diff --check检查。保留首次动画断言失败日志。真实多人未验证；导入退出0仍报Parameter "t" is null；截图使用llvmpipe。
- 证据：artifacts/realism99-validation/test-results.json、verification.json、final-mesh-topology.log、stage98-99-viewmodel-comparison.png和两张forward-contact总览；审阅见docs/VISUAL_REVIEW_STAGE99.md。
- 本地预览：`./artifacts/realism99-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，保留相邻PCK；README/build.json记录运行方法和哈希。保留全部未提交修改，未push或发布。状态continue。
- 下一步：成组重构掌面、虎口、指腹与枪械接触及袖口比例，避免继续孤立微调；同机位复核腰射/ADS/换弹，同时推进场景差异、人物与光照，排查导入null并补真实联网和更广泛碰撞验证。

### Stage100 — 支撑手虎口与袖口局部修正、预览复核
- 降低支撑手拇指弧线、加宽虎口连接并收束袖口，重建Blender/GLB；网格检查及四个第一人称动画导出检查通过。实际改善有限，管状手指、厚重枪体和材质区分不足仍明显，未达到stage31要求的实质形体/材质改善，整体目标未完成。
- 已审阅同机位腰射/ADS、换弹原图与源码/包内三枪五姿态总览；卡宾枪红点居中，未发现新增瞄具遮挡。22项功能检查通过，含单机、瞄准、换弹接触、枪口遮挡及入口/屋顶碰撞；连同导出、两次采集共25条成功记录，30张截图和11个构建文件哈希核验通过。
- 首次驱动退出143原因不明，已保留driver-interruption.json；resume补完后退出0。导入退出0仍报Parameter "t" is null；使用llvmpipe，真实多人及硬件GPU性能未验证。
- 证据：artifacts/realism100-validation/verification.json、test-results.json、topology.log、stage99-100-grip-comparison.png及两张forward-contact总览；审阅见docs/VISUAL_REVIEW_STAGE100.md。
- 本地预览：`./artifacts/realism100-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，保留相邻PCK；README/build.json记录运行方法和哈希。保留全部未提交修改，未push或发布。状态continue。
- 下一步：完整重构掌面、虎口、四指包握与袖口并明确金属/聚合物/织物材质差异，停止孤立控制点微调；继续人物、建筑差异、地形植被、光照，排查导入null并补真实联网及更广泛碰撞验证。

### Stage101 — 托枪掌骨与四指联动，源码/打包截图验证
- 调整 `tools/build_viewmodel.py` 左手掌骨宽度、指根衔接、四指长度差与屈曲细节，重建 Blender/GLB；腰射掌面稍更饱满，但手指仍有管状感。武器本体/材质本轮未改，整体目标未完成。
- 源码与打包版各 11 项检查通过（单机、瞄准、换弹、遮挡、入口/屋顶碰撞等），三枪腰射/ADS/三个换弹时点共 30 张截图；25 条任务记录成功，截图与 11 个构建文件哈希已核对。证据：`artifacts/realism101-validation/verification.json`、`test-results.json`、`stage100-101-grip-comparison.png`、`packaged-forward-contact.jpg`。
- 实际审阅：ADS 无新增遮挡；右手包握不足、握把/枪体偏大、材质区分不足和重复植被建筑仍突出，见 `docs/VISUAL_REVIEW_STAGE101.md`。导入仍有 dummy texture storage 的 t-null 错误；仅软件 Vulkan，真实联网与硬件 GPU 未验证，未读取密钥。
- 本地预览：`artifacts/realism101-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，说明见同目录上级 `README.md`；未发布。
- 下一步：联合修正枪体厚度/握把比例、右手包握与手指关节，实质改善手套/金属/聚合物材质，再做固定机位腰射/ADS/换弹对照。状态 continue，不将微小调整当作整体完成。

### Stage102 — 握把比例与右手形体联动，完成本地预览验证
- 卡宾枪握把由约 152 mm 缩到 115 mm、收窄截面并调整防滑区域；右手四指改为竖向排列、向袖口平滑过渡，重建 Blender/GLB。实际同机位腰射/ADS/换弹对照显示露出握把缩短，但掌位偏低、拇指环状、三枪包握不完整仍突出；本轮未完成材质改造。
- 源码及包内各 11 项功能检查通过，含单机、瞄准、换弹、遮挡、入口/屋顶碰撞和网络状态规则；含导出、两次截图采集共 25 条成功记录，30 张截图及 11 个构建文件哈希核验通过。网格与四个动画片段导出检查通过，不等同于解剖或穿模检查。
- 证据：`artifacts/realism102-validation/verification.json`、`test-results.json`、`topology.log`、`stage101-102-carbine-comparison.jpg`、源码/包内 `forward-contact.jpg` 总览；审阅见 `docs/VISUAL_REVIEW_STAGE102.md`。
- 首次驱动退出 143 原因不明，恢复后完成验证；导入退出 0 仍有 t-null 错误。截图使用 llvmpipe，真实认证多人及硬件 GPU 未验证。保留未提交修改，未发布或读取密钥。
- 本地预览：`./artifacts/realism102-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，保留相邻 PCK；同目录上级 README.md 和 build.json 提供说明与哈希。
- 下一步：按三枪握把接触面重构掌骨、虎口和逐指关节，修复低掌位与环状拇指，明确织物/聚合物/金属材质差异；继续人物、建筑、植被、光照及真实联网和更广泛碰撞验证。状态 continue，整体写实目标未完成。

### Stage103 — 右掌位置与手套织物/皮革区分，源码和预览截图验证
- 修改 `tools/build_viewmodel.py`，右掌上移约 23 mm、内移 4 mm，调整指列与拇指形体，增加橄榄色编织底色并降低接触皮革粗糙度；重建 Blender/GLB。固定机位腰射/ADS/换弹对照显示掌位和材质区别改善，但虎口空隙、四指包握不自然仍明显，枪体本轮未改。
- 源码及包内各 11 项检查通过，覆盖单机、瞄准、换弹、遮挡、入口/屋顶碰撞及网络状态规则；加导出和截图采集共 25 条成功记录，30 张截图及 11 个构建文件哈希核对通过。直接审阅三枪五姿态总览，ADS 无手臂遮挡。
- 证据：`artifacts/realism103-validation/verification.json`、`test-results.json`、`topology.log`、`stage102-103-carbine-comparison.jpg`、源码/包内 `forward-contact.jpg`；详见 `docs/VISUAL_REVIEW_STAGE103.md`。
- Blender 中间重复面诊断经构建器清理，最终拓扑检查通过；Godot 导入退出 0 仍有 t-null 诊断。仅 llvmpipe 软件 Vulkan，真实认证多人及硬件 GPU 未验证；未发布，保留未提交修改。
- 本地预览：`./artifacts/realism103-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，保留相邻 PCK；上级 `README.md`、`build.json` 提供说明和哈希。
- 下一步：按三枪握把接触面重建虎口和逐指弯曲，避免继续只平移整掌；联合改善枪体截面及金属/聚合物响应。人物、建筑差异、地形植被、光照、真实联网和更广泛碰撞仍待推进。状态 continue，不将局部改善视为整体完成。

### Stage104 — 收窄卡宾枪机匣，源码与包内同机位画面验证
- 修改 `tools/build_assets.py`，上机匣横向缩至 78%、下机匣由 67 mm 收至 54 mm，同步调整抛壳口、枪机、侧槽、销钉和保险等接合件，略降金属粗糙度；重建 `art/carbine.blend` 与 `client/assets/carbine.glb`。手臂本轮未重建。
- 已直接审阅源码/包内三枪五姿态总览，以及卡宾枪腰射、ADS 全分辨率截图和前后对照。肩部收窄可见但整体改善有限；红点居中、视窗无遮挡，虎口空隙、手指包握、粗壮拉机柄及大平面仍待修复。
- 源码与包内各 11 项功能检查通过，覆盖单机、瞄准、换弹、遮挡、入口/屋顶碰撞与网络状态规则；加导出及截图采集共 25 条成功记录，30 张截图与 11 个构建文件哈希核对通过，最终拓扑检查通过。
- 证据：`artifacts/realism104-validation/verification.json`、`test-results.json`、`topology.log`、`stage103-104-carbine-comparison.jpg`、源码/包内 `forward-contact.jpg`；审阅见 `docs/VISUAL_REVIEW_STAGE104.md`。导入退出 0 仍有 t-null 诊断；使用 llvmpipe 软件 Vulkan，真实认证多人及硬件 GPU 未验证。
- 本地预览：`./artifacts/realism104-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，保留相邻 PCK；上级 `README.md`、`build.json` 提供说明与哈希。未发布，保留所有未提交修改。
- 下一步：按握把接触面重建虎口、拇指与逐指弯曲，改善袖子结构，并验证三枪同机位腰射/ADS/换弹，避免仅平移整掌。人物、建筑差异、地形植被、光照、真实联网与更广泛碰撞仍需推进。状态 continue，整体目标未完成。

### Stage105 — 仓库装卸区、屋顶差异与不规则低草带
- 按环境优先反馈，主仓库改为绿色坡屋顶、后仓库采用另一屋顶形式；新增西侧装卸棚、立柱斜撑、两只货箱与接触阴影，并降低草高、增加不规则草带。正常腰射与 ADS 同机位对照中建筑轮廓变化明确；本轮未修改武器资产或全局光照。
- 已审阅源码/包内环境原图、三枪五姿态总览、卡宾枪腰射/ADS 原图和 stage104–105 对照。硬直地坪边缘、规则树列、平滑山体、其他方盒建筑以及手臂/换弹接触仍限制画质。
- 共 27 条成功记录（20 功能、6 截图采集、1 导出），40 张 1280×800 截图。源码和包内均通过装卸棚真实角色双向通行、顶棚/立柱射线、六根旋转斜撑实际变换采样、两只货箱侧面及模型/代理边界检查；另覆盖单机、108 样本瞄准、武器遮挡、入口/屋顶碰撞及网络状态规则。
- 证据：`artifacts/realism105-validation/verification.json`、`test-results.json`、`environment-results.json`、`depot-results.json`、`stage104-105-environment-comparison.jpg`、`source-weapon-contact-sheet.jpg`、`packaged-weapon-contact-sheet.jpg`；审阅见 `docs/VISUAL_REVIEW_STAGE105.md`。最终验证日志未检出 ERROR/WARNING；静态截图与实际角色物理测试分开执行。
- 本地预览已运行：`./artifacts/realism105-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，保留相邻 PCK；README 与 build.json 提供说明和哈希。使用 llvmpipe 软件 Vulkan，真实认证多人及硬件 GPU 性能仍未验证；未发布，保留未提交修改。
- 下一步：优先改善地坪/道路硬边、树丛疏密、地形材质与光照层次，使正常游戏机位环境更自然；继续推进人物、武器手臂、真实联网和更广范围碰撞验证。状态 continue，不将本阶段环境改善视作整体目标完成。

### Stage106 — 装卸棚地表过渡、钢架可读性与远景林带
- 增加棚边泥土碎石过渡和柱脚底座，调整钢架表面、背景树木疏密/尺寸及 Forward+ 天空补光；正常游戏机位可见棚架和地表变化。钢架仍偏石质、泥土带偏宽且有直线接缝，近草重复、大片空地、平滑山体及入口坡板高光仍明显，整体画质未达标。
- 保存 stage105→106 四个相同位置/朝向的环境对照，覆盖建筑入口近景及宽幅地形；另保存原出生机位腰射/ADS 对照和三枪换弹实机截图。相机数据在各截图目录 `environment-camera-poses.json` 及 `original-spawn-camera.json`。
- 28 条最终验证记录通过，覆盖源码/导出包单机流程、108 样本瞄准、遮挡、入口/屋顶/棚架碰撞及仓库与装卸棚真实角色双向通行；网络仅验证状态规则。最终日志未检出 ERROR/WARNING；截图采集中断 143 和验证器标记修正均保留记录，补跑通过。
- 证据：`artifacts/realism106-validation/verification.json`、`test-results.json`、`environment-before-after.jpg`、`packaged-forward/`、`packaged-weapon-contact-sheet.jpg`；详细审阅 `docs/VISUAL_REVIEW_STAGE106.md`。48 张原始截图用于核对采集完整性，不作为画质达标依据。
- 本地预览已验证：`./artifacts/realism106-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，需保留相邻 PCK；README 与 build.json 记录运行说明和哈希。使用 llvmpipe 软件 Vulkan，硬件 GPU 性能和真实多人联机未验证；未发布，保留所有未提交修改。
- 下一步：继续改善棚边接缝、钢架材质、坡板高光、近草与宽幅地块/山体层次；结合第三人称人物和第一人称腕部/换弹接触审阅推进剩余缺陷，并补齐真实联网及更广泛碰撞。状态 continue。

### Stage107 — 钢架漆面与棚边碎石沉积修正
- 去除钢架误用的岩石纹理，改为灰绿色漆面；地坪碎石带增加宽度变化、间断和通行缺口，减弱连续黄色矩形边框。正常接近机位可见改善，但入口坡道强反光、硬接缝、重复草型、空旷院区及圆滑山体仍明显，整体目标未完成。
- 保存 stage106→107 四个固定机位前后对照、入口近景及宽幅地形实机截图，相机位置和朝向见各 `*-forward/environment-camera-poses.json`；另保存出生机位腰射/ADS 对照与三枪动作回归截图。已实际审阅环境对照、入口/地形原图及打包武器联系表。
- 最终 28 条记录通过，覆盖源码/打包版本单机、瞄准、武器遮挡、入口/屋顶/棚架碰撞和仓库及棚下真实角色双向通行；联网仅验证状态规则。最终日志无 ERROR/WARNING；三次退出 143 后恢复验证，未将中断作为通过。48 张截图仅反映采集完整性。
- 证据：`artifacts/realism107-validation/verification.json`、`test-results.json`、`environment-before-after.jpg`、`packaged-forward/`、`packaged-weapon-contact-sheet.jpg`；详细审阅 `docs/VISUAL_REVIEW_STAGE107.md`。
- 本地预览已验证：`./artifacts/realism107-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，保留相邻 PCK；README 与 build.json 提供运行说明和哈希。使用 llvmpipe 软件 Vulkan，硬件 GPU 性能及真实认证多人未验证；未发布，保留未提交修改。
- 下一步：成组改善坡道反光、普通机位植被形态/分布、院区空间和光照层次；继续第三人称人物、第一人称腕部与换弹接触审阅，并补齐真实联网及更广范围碰撞。状态 continue。

### Stage108 — 院区混合地表、磨损停车线与入口坡道材质
- 新增院区混合材质，融合混凝土、碎石与泥土，增加不规则边缘、车辙和断续旧漆停车线；坡道采用世界坐标纹理并降低镜面反射。普通接近和入口机位变化明确，碰撞几何保持原形。本轮未新增植被模型或调整全局光照。
- 已实际审阅 stage107→108 同机位环境/入口对照、宽幅地形原图和打包三枪五姿态截图。地坪仍偏褐且布局笔直；坡道暗色条纹近似木纹，货箱模糊拉伸、草型重复、圆滑山体与空旷院区仍明显，整体画质未达标。
- 最终 29 条验证记录通过，包括源码/包内单机、108 样本瞄准、遮挡、入口/屋顶/棚架碰撞和仓库/棚下真实角色双向通行；网络仅验证状态规则。51 张截图及两组相机位置/朝向记录核对完整，最终日志无 ERROR/WARNING。一次截图采集退出 143 后恢复补跑，未将中断计为通过。
- 证据：`artifacts/realism108-validation/verification.json`、`test-results.json`、`environment-before-after.jpg`、`entrance-before-after.jpg`、`packaged-forward/`、`packaged-weapon-contact-sheet.jpg`；相机数据见各 `*-forward/*-camera-poses.json` 和 `original-spawn-camera.json`，详细审阅见 `docs/VISUAL_REVIEW_STAGE108.md`。
- 本地预览已验证：`./artifacts/realism108-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，保留相邻 PCK；README 与 build.json 提供运行说明和哈希。使用 llvmpipe 软件 Vulkan，硬件 GPU 性能及真实认证多人未验证；未发布，保留所有未提交修改。
- 下一步：优先制作低草、细茎杂草和阔叶地被的成片分布，修正货箱纹理尺度与坡道材质，继续改善环境受光层次；补充第三人称人物和第一人称腕部/换弹接触审阅，继续真实联网与更广泛碰撞验证。状态 continue，整体目标未完成。

### Stage109 — 雨棚结构、院区围栏、远山轮廓与室内顶灯
- 增加雨棚梁翼缘、连接板和螺栓；新增有实体碰撞的院区铁丝围栏并保留五米通道；远山增加支脊、鞍部及峰高变化，室内顶灯改向下聚光消除天花强白斑。本轮未新增植被模型。
- 已审阅108→109同机位环境、入口和正常出生机位对照，以及打包版地形、入口与三枪姿态。围栏和山形在正常机位可辨；重复草丛、简化建筑、围栏锯齿、模糊货箱及木纹状坡板仍明显，换弹手腕和手指也不自然，整体画质未达标。
- 最终29条验证记录通过，日志无 ERROR/WARNING，覆盖源码/打包单机、瞄准、遮挡、入口/屋顶/围栏碰撞，仓库及围栏缺口真实角色双向通行。联网仅检查状态规则。修正环境采集俯仰符号后重新采集旧版及新版，五个环境及三个入口机位的位置与朝向完全一致；54张截图仅代表采集完整性。
- 证据：`artifacts/realism109-validation/verification.json`、`test-results.json`、`environment-before-after.jpg`、`entrance-before-after.jpg`、`original-spawn-before-after.jpg`、`packaged-forward/`；相机记录见各 `*-forward/*-camera-poses.json` 与 `original-spawn-camera.json`。详细审阅：`docs/VISUAL_REVIEW_STAGE109.md`。
- 本地预览已生成并验证：`./artifacts/realism109-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，保留相邻 PCK；README 与 build.json 提供运行说明及哈希。使用 llvmpipe 软件 Vulkan，硬件性能及真实认证多人未验证；未发布，保留所有未提交修改。
- 下一步：优先落地混合低草、细茎杂草和阔叶地被成片分布，减少树木重复，处理围栏过滤及货箱/坡道材质；继续第三人称人物、第一人称连续换弹与真实联网及更广泛碰撞验证。状态 continue。


### Stage110 — 环境：混合草型、仓库钢梁及吊灯（2026-09-14）
- Blender生成低草/细长草/阔叶三种网格，按覆盖噪声混合合批；仓库新增工字梁、檩条、连接件、吊杆并降低灯具及向下照明。保持墙地及入口碰撞。
- 保存109→110相同机位环境/入口前后对照、宽幅地形及室内实机原图；相机位置与朝向JSON一致。实审可辨识钢梁和草型变化，但草地接地弱、货箱模糊、坡道木纹感、院区空旷重复仍明显。审阅：`docs/VISUAL_REVIEW_STAGE110.md`。
- 最终29项导出/采集/检查通过：源码与打包版单机、瞄准、遮挡、入口/屋顶/掩体碰撞、仓库和棚下双向真实角色物理通行；网络仅状态规则，未完成真实多人验收。日志及哈希：`artifacts/realism110-validation/{test-results,verification}.json`。保留实现期间的导入错误、相对路径导出失败及退出143诊断，已修正并完成最终验证。
- 图像：`artifacts/realism110-validation/environment-before-after.jpg`、`entrance-before-after.jpg`及`packaged-forward/`原图/相机JSON。本地预览：`artifacts/realism110-preview/Linux/IronMeridian`（同目录PCK；启动说明见该预览目录README.md）。软件Vulkan实机采集不代表硬件GPU性能。未推送/发布，保留未提交修改。
- 下一阶段：优先货箱/坡道材质尺度及地被接地感，继续减少空旷重复；保留第三人称人体、第一人称细腕与握持、连续换弹和真实联网的完整验收目标。整体目标未完成，状态continue。

### Stage111 — 仓库入口设施与混凝土地坪
- 新增入口两侧排水格栅、配电柜及走线；室内地坪和坡道改用同一世界坐标混凝土材质，保留现有碰撞。沿用110植被和照明，本轮未新增植被或调整光源。
- 已审阅110→111同机位环境、入口、正常出生机位对照及打包实机。格栅/柜体可辨，坡道原粗粒木纹感减弱，但新地坪偏白、过于均匀，不能视作材质最终达标；宽幅场景仍空旷重复、树冠薄、草簇接地弱。
- 最终29条导出/测试/采集记录通过，最终日志无 ERROR/WARNING。源码与打包版验证单机、瞄准、遮挡、入口/屋顶/掩体碰撞、仓库及棚下双向真实角色物理通行。联网仅状态规则；三枪静态姿态仍有细腕和握持接触缺陷，未完成第三人称、连续换弹及真实多人验收。
- 证据：`artifacts/realism111-validation/{test-results,verification}.json`、`environment-before-after.jpg`、`entrance-before-after.jpg`、`original-spawn-before-after.jpg`、`packaged-forward/`和`packaged-weapon-contact-sheet.jpg`。各版本相机JSON记录位置/朝向且一致。详细审阅：`docs/VISUAL_REVIEW_STAGE111.md`。
- 本地预览：`./artifacts/realism111-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，保留相邻PCK；README/build.json提供说明与构建记录。使用软件Vulkan采集，未验证硬件GPU性能。未推送/发布，保留所有未提交修改。
- 下一阶段优先宽幅树冠体积、地被与泥土接触、重复院区及货箱/地坪材质尺度，结合第三人称与第一人称换弹实机审阅安排人物缺陷。整体目标未完成，状态continue。

### Stage112 — 仓库墙体分层与装卸地坪
- 仓内增加墙裙、护条和高位线槽；装卸棚粗大石块地坪改用混凝土，降低混凝土底色亮度并增加积尘/色差，缩小碎石泥土纹理尺度。本轮未调整植被布局或光源，环境整体目标未完成。
- 保存111→112同机位环境、入口近景、原出生点对照及宽幅实机原图。入口采集俯仰符号已修正，并从111独立包重新采集入口基线；三版相机位置/朝向JSON一致。墙体分层与灰色地坪可辨，但地坪仍平滑、木箱拉伸、树冠薄、道路空旷和建筑重复仍明显。
- 最终27项功能/采集检查通过：源码与打包版单机、瞄准、遮挡、入口/屋顶/掩体碰撞及仓库/棚下双向真实角色物理通行。网络仅状态规则，真实多人仍未验收。三枪静态姿态及第三人称四姿态三角度已实审，手臂细长、握持、块状护具与蹲姿腿部压缩仍需修复。
- 证据：`artifacts/realism112-validation/verification.json`、`environment-before-after.jpg`、`entrance-before-after.jpg`、`packaged-forward/`及相机JSON、`packaged-weapon-contact-sheet.jpg`、`operator-contact-sheet.jpg`；详细审阅 `docs/STAGE112_VISUAL_REVIEW.md`。首次烟测路径错误及人物采集超时日志保留，正确调用/顺序重试通过。
- 当前预览：`./artifacts/realism112-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`（保留同目录PCK；README/build.json提供说明与哈希）。软件Vulkan实机验证不代表硬件GPU性能。未推送/发布，保留未提交修改。
- 下一阶段优先宽幅机位树冠体积、地被接地、院落布局变化与光照层次，不能继续仅微调地坪；随后结合上述人物/手部缺陷安排动态换弹和真实多人验证。状态continue。


### Stage113 — 分枝针叶树替换与独立包验收（2026-09-14）
- 用可复现 Blender 脚本生成分枝、侧梢与针叶树，替换近景 GLB 和匹配远景图，保存原创来源及工程。正常宽幅机位中树冠从细长团簇变成较宽分层轮廓；但树根棱角、针叶稀疏和规则枝层仍明显，本轮没有完成建筑及光照提升。
- 旧112包、113源码、113独立包各采集七个完全相同机位，保存相机位置/朝向、宽幅地形、入口近景和近树对照。审阅三枪腰射、ADS、静态换弹图，细长手臂及袖口过渡仍待改；静态图不代表连续换弹验收。
- 源码及独立包各10项检查全部通过，含瞄准、遮挡、单机烟测、入口/屋顶/棚下/掩体碰撞及仓库和棚下实际双向物理行走。网络状态规则通过仅代表本地逻辑，真实双客户端联网未验收；第三人称本轮未重新审阅。Forward+ 使用 llvmpipe，未验证硬件GPU帧率。
- 证据：`artifacts/realism113-validation/verification.json`、`functional-results.json`、`capture-results.json`、三个 `*-before-after.jpg`、`packaged-weapons-contact.jpg`；详见 `docs/STAGE113_VISUAL_REVIEW.md`。本地预览 `artifacts/realism113-preview/Linux/IronMeridian`（同目录PCK，启动加 `--path /tmp --rendering-method forward_plus`），哈希已核对。未推送或发布，保留未提交修改。
- 下一步：先修近树根部/地被泥土过渡，继续院落差异与光照层次；随后推进人物块状护具与蹲姿缺陷、第一人称连续换弹和真实联网主流程。总体目标未完成，状态 continue。


### Stage114 — 棚体细节、地被尺度及补光验证（2026-09-14）
- 增加装卸棚接缝、排水与 LOADING 标识，降低阔叶尺寸及黄绿偏色、形成路肩不连续植被，减弱天空补光。正常机位可见局部变化，但仓库群重复、空旷地形及山坡折面仍未解决，不能算环境整体完成。
- 复用已归档113独立包作为前图，与114独立包七个相机位置/朝向完全一致；保存建筑入口、内部、宽幅地形、林地前后对照。源码和独立包各10项功能回归全部通过，含仓库与棚下实际双向物理通行。两个截图脚本通过；三枪腰射/ADS/静态换弹已审阅，细长手臂及连续动作问题保留。
- 真实联网未验收：现有runner需要服务密钥/认证fixture，本任务禁止读取密钥，未执行。状态规则仅本地逻辑。第三人称未重拍，llvmpipe不代表硬件GPU性能。
- 证据：`artifacts/realism114-validation/verification.json`、`functional-results.json`、`capture-results.json`、`environment-before-after.jpg`、`entrance-before-after.jpg`、`forest-before-after.jpg`、`packaged-weapons-contact.jpg`；详见 `docs/STAGE114_VISUAL_REVIEW.md`。本地预览 `artifacts/realism114-preview/Linux/IronMeridian`（同目录PCK，启动加 `--path /tmp --rendering-method forward_plus`）；README及build.json记录启动与哈希。未推送发布，保留未提交修改。
- 下一步：优先做宽幅视角明显可辨的仓库群体量/院落用途差异和地面过渡，处理树根与泥土针叶衔接，不再整轮局限单个棚子。之后继续第三人称块状护具/靴子/蹲姿、第一人称连续换弹、真实联网主流程。总体状态 continue。


### Stage115 — 弧顶维修院落与实际穿行验证（2026-09-14）
- 增加可穿行弧顶维修棚、结构肋及工作台，加入院落碎石/车辙、路肩泥土过渡并排除硬化场地植被；正常宽幅机位能辨认新的建筑轮廓。未改全局光照或植物几何，平地空旷、山体折面和仓库重复仍明显，新棚内表面偏亮及金属条纹失真仍需修复。
- 新增真实角色双向穿棚与墙顶碰撞测试；初测发现随机箱堵住通路，已修改生成排除范围。最终独立包11项功能检查全部通过，含瞄准、单机与三处建筑实际通行；网络状态检查仅本地逻辑，真实联网、第三人称重拍和连续换弹仍未验收。
- 保存114/115完全一致的七个环境机位及一个维修棚机位、入口近景和宽幅地形对照。最终环境截图进程在PNG/相机JSON落盘后中断，未收集退出码，不宣称该脚本通过；维修棚截图单独补跑成功。Forward+使用llvmpipe。
- 证据：`artifacts/realism115-validation/verification.json`、`final-functional-results.json`、`final-capture-results.json`、`camera-comparison.json`、三个`*-before-after.jpg`；详见`docs/STAGE115_VISUAL_REVIEW.md`。最终本地预览`artifacts/realism115-preview/Linux/IronMeridian`（同目录PCK，启动加`--path /tmp --rendering-method forward_plus`），build.json记录哈希。保留早期失败诊断及全部未提交修改，未推送发布。
- 下一步：先消除新棚条纹失真及偏亮，推进宽幅地形起伏、植被分布/树根地表衔接与建筑群用途差异；继续人物护具/蹲姿、第一人称连续动作与具备合法测试条件后的真实联网验收。总体目标未完成，状态continue。

### Stage116 — 棚架尺度、圆缓山脊与路肩草带（2026-09-14）
- 维修棚改为四道可见实体承重拱架，屋面增加条纹过滤和双面受光修正；圆缓远山轮廓、向路肩扩展草带。宽幅实机对照可辨认结构及轮廓变化，但棚内顶面偏亮、场地过平空旷和仓库重复仍明显，未完成整体画质目标。
- 115/116七个环境机位及维修棚机位元数据完全相同，保存入口近景、宽幅地形和棚内对照；两个最终截图脚本均退出0。独立包11项功能回归通过；新增四条双向角色穿棚路线及立柱/墙/顶碰撞通过。背景贴地初测发现测试把小成树误判幼树，修正分类并保持容差后1177棵树检查通过，最大误差0.000102米，保留首次失败日志。
- 证据：`artifacts/realism116-validation/verification.json`、`functional-results.json`、`capture-results.json`、`camera-comparison.json`、三个`*-before-after.jpg`；详见`docs/STAGE116_VISUAL_REVIEW.md`。本地预览`artifacts/realism116-preview/Linux/IronMeridian`（同目录PCK，启动加`--path /tmp --rendering-method forward_plus`），README/build.json记录操作与哈希。未推送发布，保留未提交修改。
- 真实联网缺少可用认证fixture，未访问密钥；网络状态仅本地规则通过。第三人称与第一人称连续动作仍待验收，llvmpipe不代表硬件GPU性能。下一步优先建筑群用途/体量及院落地面过渡、棚顶受光和树根地表衔接，再继续人物和武器连续动作审阅。状态continue。


### Stage117 — 供水设施、入口排水与山脚光照（2026-09-14）
- 仓库侧面新增带抱箍、弧顶和管路的供水罐，入口院落加入排水格栅；拓宽山脚并保持树木贴地，适度降低环境光与日光。正常步行机位可辨认设施及地面变化，但罐身偏素、标字贴合感不足，宽幅平地空旷、重复仓库、孤立山峰及棚顶过亮仍未解决。
- 116/117共九个机位位置与朝向完全一致，保存入口近景、宽幅地形、维修棚和供水设施对照。最终四个截图批次均退出0；最终本地包13项功能检查全部通过，含单机、瞄准、建筑通行以及水罐双向绕行、罐体和顶盖碰撞。首次绕行路线越界失败及一次退出143的中断批次保留在initial/interrupted，完整重跑通过。
- 证据：`artifacts/realism117-validation/verification.json`、`functional-results.json`、`capture-results.json`、`camera-comparison.json`及五张`*-before-after.jpg`；详见`docs/STAGE117_VISUAL_REVIEW.md`。预览：`artifacts/realism117-preview/Linux/IronMeridian`（同目录PCK，启动加`--path /tmp --rendering-method forward_plus`），README/build.json记录操作和已复核哈希。未推送发布，保留所有未提交修改。
- 真实联网缺少可用授权认证fixture，未读取密钥；网络状态规则通过不代表真实联网通过。第三人称及第一人称连续动作尚未验收，截图使用llvmpipe。下一步优先修复棚顶局部受光、仓库群重复和地面植被过渡，补足设施表面细节，再继续人物护具/蹲姿、第一人称连续动作及具备合法测试条件后的真实联网。整体状态continue。

### Stage118 — 仓库通风楼、树根土层与设施表面（2026-09-14）
- 新增带碰撞的仓库屋脊通风楼，树根加入落叶土壤过渡，供水罐增加流挂及沿圆柱排字，调整棚顶材质接缝过滤与背面遮蔽。正常游戏机位可辨建筑轮廓与树根变化；棚顶改善有限、罐字边缘破碎、树根圆斑仍待修，宽幅平地及重复建筑未解决。整体continue。
- 117/118九个机位位置朝向完全相同，六个完整截图批次退出0，保存入口、宽幅、森林、水罐及棚内对照。最终包13项功能检查通过，含单机、瞄准、建筑碰撞和多条实际角色通行路线；原屋顶射线被新增结构截获后改为外露坡面取样并增加顶盖检查，保留原失败及一次测试类型推断错误，修正后的独立重跑通过。
- 证据：`artifacts/realism118-validation/verification.json`、`functional-results.json`、`capture-results.json`、`camera-comparison.json`及六张`*-before-after.jpg`；详见`docs/STAGE118_VISUAL_REVIEW.md`。本地预览`artifacts/realism118-preview/Linux/IronMeridian`，同目录PCK，启动加`--path /tmp --rendering-method forward_plus`；README/build.json记录操作和哈希。未推送发布，保留所有未提交修改。
- 实际联网仍缺授权认证fixture，仅本地网络状态规则通过；第三人称及第一人称连续动作未验收，llvmpipe不代表硬件GPU性能。下一步优先可步行建筑群体量/用途、院落布局与连续地面植被过渡，要求固定宽幅机位可见收益，再修棚顶受光/标字/树根斑并继续人物、手部连续动作和合法条件下真实联网验证。

### stage119（2026-09-14）— 西侧坡顶车间与沿墙植被实机验证
- 西侧指定建筑切换坡顶/单坡顶，(-42,0,34) 加通风天窗；侧院土壤过渡和沿墙草带，草淡出42–80m，阴影覆盖170m。正常机位屋顶轮廓变化可见，光照整体改善尚未证实。
- stage118/119 相同9机位导出包截图、入口近景和宽幅前后对照已保存：`artifacts/realism119-validation/`；相机脚点、yaw/pitch、原图及日志齐全，`verification.json` 确认机位一致和8项构建哈希匹配。
- 13项检查通过；东西车间实际物理角色双向穿越四条路线均通过，地板保持启用；屋顶11处及两处天窗碰撞通过。联网仅本地状态规则，真实联网未测；第三人称、手部连续动作及GPU性能未验收。
- 预览：`artifacts/realism119-preview/Linux/IronMeridian`（同目录PCK；README含启动命令）。审阅：`docs/STAGE119_VISUAL_REVIEW.md`。未推送/发布，整体目标未完成。
- 下一步：按宽景固定机位处理远山棱面、空旷中景与植被组团，复测通行及阴影；继续人物/手部连续动作和真实联网验证，不回到仅微调武器的一轮。

### Stage120（2026-09-14）：山坡受光与林带连续性，整体 continue
- 接续119建筑阶段，修改 world_visuals.gd：山体128格采样与连续高度场法线，树根高度插值同步；扩展远山林带和不规则草丛覆盖。建筑入口及太阳/雾参数沿用119。
- 独立119/120包完成同机位前后截图，包含入口近景、宽幅地形及林地；camera JSON完全一致，对照与源码/包哈希验证通过：artifacts/realism120-validation/verification.json。已实际审阅宽景、西车间接近、东仓入口与林地实图。主要改善是远山受光及林带；宽阔空路、重复房屋、地表色块、树冠规律枝层仍明显，草丛变化较小。
- 13项功能检查退出0通过，覆盖瞄准、武器遮挡、单机、入口/屋顶碰撞、仓库与设施通行及本地网络规则；初次进程143中断后，缺失完整结果的3项补跑成功。独立远景射线检查18山体/2545树，最大树根误差0.000097米。日志与 functional-results.json 位于同验证目录。
- 本地可运行包 artifacts/realism120-preview/Linux/IronMeridian（相邻PCK必需），运行说明见该预览目录README.md；审阅见 docs/STAGE120_VISUAL_REVIEW.md。软件渲染不代表GPU性能，真实认证联网缺授权fixture；第三人称及连续手部动作尚待审阅。未推送或发布。
- 下一步：优先改宽景中景的道路边缘、建筑用途与布局、地表过渡，保留实际通行；随后结合第三人称和第一人称连续动作审阅推进人物/手臂/武器，具备合法测试条件后补真实联网。不要继续仅增加远景树木数量，不以本轮局部提升宣布整体完成。

### Stage121（2026-09-14）：道路材质与建筑周边土色，整体 continue
- 新增世界坐标道路材质，包含骨料、轻微磨耗和不规则路肩；维修地表及建筑边带降低橙黄偏色。正常出生及宽景实图可辨认土带色偏减弱，道路磨耗可见；道路仍宽直空旷、房屋重复和植被边界仍明显。本轮没有新增建筑模型或修改太阳参数。
- 独立120/121包10组同机位截图及相机位置/yaw/pitch核对通过，包含原始出生、建筑入口近景、宽幅地形；源码和包哈希核对通过。证据：`artifacts/realism121-validation/verification.json`、`environment-spawn-before-after.jpg`、`terrain-wide-before-after.jpg`、`depot-entrance-close-before-after.jpg`。已实际查看出生、宽景和入口前后原图。
- 13项包内功能检查通过，覆盖单机、瞄准、遮挡、入口/屋顶碰撞及设施物理通行和本地网络规则，见同目录 `functional-results.json`。远景 headless 首次失败日志保留；Xvfb Forward+重跑通过，18山体/2545树、最大树根误差0.000097米。真实认证联机缺授权fixture，仍未测；第三人称和连续手部动作未验收。
- 本地预览：`artifacts/realism121-preview/Linux/IronMeridian`，相邻PCK必需；README含运行命令。审阅：`docs/STAGE121_ENVIRONMENT_REVIEW.md`。llvmpipe不代表硬件GPU性能；未推送/发布，保留未提交修改。
- 下一步优先建筑院落用途与体量差异、路边植被衔接及棚顶受光，解决宽景重复空旷；入口室内中央细黑竖线在120/121均存在，需定位。随后推进第三人称人物及第一人称连续瞄准/射击/换弹实图，具备授权条件后补真实联机。不以本轮地表局部改善宣告整体完成。

### stage122 — 地面黑线定位修复与连续动作实机审阅
- 121包同机位隐藏80条薄盒地缝确认黑线来源；122移除装饰盒，改地板专用过滤接缝，减轻模糊白斑。保存入口/室内/宽景三组前后对照和相机记录；实际走入仓库120步通过，碰撞未改。室外重复、空旷道路、草地硬边与路标光照未改善，整体continue。
- 三武器瞄准/射击/换弹连续采样完成；原第三人称蹲行脚本未保持输入，已修正补录39帧/390步，状态通过。动作截图存在缓冲延迟，约5Hz采样不代表性能。实图仍见前臂袖子硬折面、霰弹枪装填不清、第三人称装备块状/脸暗/蹲姿不自然，第三人称换弹手与弹匣动作不明显。
- 证据：`docs/STAGE122_ENVIRONMENT_REVIEW.md`；`artifacts/realism122-validation/` 内三张 comparison.jpg、motion/、actions/review.html、actions-third-corrected/review.html、action-verification.json、functional-results.json（11项PASS，前6项无子进程退出码，详情见报告）。真实认证联网仍缺授权fixture，不能称联机通过。
- 当前可运行包：`artifacts/realism122-preview/Linux/IronMeridian` + `.pck`，README及build.json保留启动命令/哈希；Godot Forward+ llvmpipe实机采样，非GPU性能验收。未推送，未发布，保留所有未提交修改。
- 下一步：先按相同连续动作修复第一人称手臂/袖子与霰弹枪装填、第三人称持枪/蹲行/换弹；随后继续建筑差异、路边植被和光照辨识度，不再整轮只调地板。保留单机、瞄准、碰撞回归及真实联网待验证项。

### stage123 — 第三人称换弹轨迹与包内环境回归，整体 continue
- 接续122动作缺陷，重建人物换弹左手分段轨迹，实图可辨认离开护木、下探腰侧和返回；仍没有独立弹匣动作，霰弹枪共用装填、人物块状装备/暗脸、第一人称袖子折面仍待解决。本轮未改环境。
- 前后各39帧/390模拟步，相同相机与动作状态核对通过；已查看八时刻换弹对照及新包Forward+入口、室内、宽景三张原图。证据：`artifacts/realism123-validation/reload-comparison.jpg`、`review.html`、`action-verification.json`、`packaged-environment/`（含相机位置/朝向）。软件渲染采样不作性能证据。
- 八项检查退出0，含三武器站/蹲换弹轨迹、瞄准/遮挡、入口/屋顶、仓库双向物理通行、蒙皮及本地网络状态规则，见functional-results.json。旧四材质断言首次失败保留日志，更新为既有五材质后通过；构建仍有plate pocket网格警告。真实认证联机缺授权fixture，未验收。
- 当前本地包：`artifacts/realism123-preview/Linux/IronMeridian`及相邻PCK，README/build.json记录启动和哈希；已从包实机加载。审阅：`docs/STAGE123_CHARACTER_REVIEW.md`。保留未提交修改，未推送发布。
- 下一步回到环境组合改进：建筑院落用途/体量差异、路边植被过渡及棚顶光照，做正常机位前后对照和入口/宽景截图、复测通行。随后继续第一人称袖子/霰弹枪与第三人称弹匣接触/蹲姿；不要连续整轮仅做手部微调，不宣告整体完成。

### stage124 — 维修库外棚及植被/局部照明，整体 continue
- 新增有碰撞的倾斜金属外棚、棚柱/斜撑/檐沟、侧边物资和向下灯具，中央保留通路；库周草高按约7米带噪声过渡恢复。正常接近机位棚体可辨认，入口阴影增强但墙面/武器偏暗；宽景重复与空旷基本未解决。
- 123/124包实机相同四机位前后截图、入口近景与宽景均保存；相机位置/朝向逐项相等。证据 `artifacts/realism124-validation/` 的四张comparison.jpg、before/after原图、capture-evidence.json；审阅 `docs/STAGE124_ENVIRONMENT_REVIEW.md`。Forward+ llvmpipe采样不代表性能验收。
- 七项最终退出0：维修库/原仓库双向物理通行、棚柱阻挡/棚顶射线、瞄准/遮挡、雨篷/屋顶和本地网络规则。旧雨篷射线首次被新增低棚截获，失败及超时日志保留；改从原雨篷紧邻下方检测后96条通过，新增棚顶独立验证。见functional-results.json及west-workshop-traversal.json；未重新验证完整战斗回合，真实认证联机仍缺授权fixture。
- 当前包 `artifacts/realism124-preview/Linux/IronMeridian` 和相邻PCK已实际加载，README/build.json记录启动和核对哈希。保留未提交修改，未推送发布。
- 下一步：改宽景可见的道路边缘用途、建筑差异/植被分布和棚下曝光；继续入口通行及瞄准回归，并结合第三人称连续动作/第一人称近景修复袖子、霰弹枪装填、弹匣接触与蹲姿。整体未完成。

### stage125：环境树带、库房调色与实机对照
- 增加9棵有树干碰撞的路边树并延长网格可视距离，扩展路肩草带；微调仓库色温、维修库编号牌及天空环境光。首版墙面过暗已减轻调色复拍。
- 保存124→125四组相同相机实机对照，含两处入口近景和宽幅地形；相机位置/朝向及截图哈希见 `artifacts/realism125-validation/capture-evidence.json`。最终采集子进程PASS；外层会话143已如实记录。
- 8项本地回归通过：道路/两库实际通行、树干与入口/屋顶碰撞、108样本瞄准、武器遮挡、本地网络规则。真实认证联机未验证，不能以规则测试替代。
- 本地预览 `artifacts/realism125-preview/Linux/IronMeridian`，包及源码哈希见build.json；审阅 `docs/STAGE125_ENVIRONMENT_REVIEW.md`。树带有可见改善，入口光照变化有限，整体目标仍continue。
- 下一步：优先改变空院落用途、重复建筑体量及规则地形；继续第一人称袖子/手部和第三人称动作实机审阅，补单机战斗、真实联网。不得把本轮局部改善视为整体完成。

### stage126：维修侧棚、硬化地面与边缘草带
- 维修库东侧增加可进入的维修棚、柱撑/檐沟、工作台、分缝硬化地面与两盏暖色灯，草带沿硬化边缘恢复。接近机位能明确看到建筑轮廓扩展；宽景重复小屋、尖锥远山和空地仍明显，整体未完成。
- 125→126四组相同机位前后实机截图已审阅，含两处入口和宽景；位置/朝向逐项相同，证据见 `artifacts/realism126-validation/capture-evidence.json` 与四张comparison.jpg。最终日志四帧PASS且图片齐全，但外层退出143，原因未定，不记为正常退出。
- 九项回归及单机战斗冒烟退出0：侧棚实际进出、柱/墙/棚顶碰撞，原有道路与建筑通行、入口/屋顶、108样本瞄准、武器遮挡、本地网络规则；16角色换弹/治疗/伤害/胜利/掩体脚本验证通过。见functional-results.json和offline-smoke.log；真实认证联网仍未验证。
- 当前本地预览 `artifacts/realism126-preview/Linux/IronMeridian` 与相邻PCK已实际运行；README给出启动方式，build.json哈希复核通过。详细审阅 `docs/STAGE126_ENVIRONMENT_REVIEW.md`；未推送发布，保留未提交修改。
- 下一步：继续环境大尺度改造，优先消除重复小屋与规则远山，避免继续只叠加小附件；安排第三人称人物及第一人称连续动作审阅，修复袖子折面、霰弹枪装填、蹲姿和弹匣接触，并持续功能回归及真实联网验证。

### stage127：连续远山、背景林带与屋顶变化
- 18块孤立高丘改为更宽缓、衔接的外围山脊，背景林带扩大；三栋中景房屋采用不同坡顶和对应碰撞。孤峰感降低，但宽景地平线偏低、纵深不足，普通小屋仍盒状；本轮未改灯光，室内地面和光照仍待改善，整体continue。
- 126→127四组同机位对照含工坊/仓库入口、宽景，已实机审阅；基线复用126最终图，127采集正常退出0。位置/朝向与哈希见 `artifacts/realism127-validation/capture-evidence.json`，对照为同目录comparison.jpg。
- 九项回归及16角色单机冒烟最终全部退出0/PASS，覆盖实际通行、入口/屋顶碰撞、108样本瞄准、武器遮挡与本地网络规则。首次批次143中断记录单独保留，补跑通过；真实认证联机尚未验证。证据见functional-results.json与offline-smoke.log。
- 当前可运行预览 `artifacts/realism127-preview/Linux/IronMeridian`，相邻PCK/README/build.json；详细审阅 `docs/STAGE127_ENVIRONMENT_REVIEW.md`。保留未提交修改，未推送发布。
- 下一步：恢复不规则分层远山纵深，改变重复小屋体量/入口用途，改善室内地面光照；继续第三人称与第一人称连续动作审阅、袖子折面/霰弹枪装填/蹲姿弹匣接触修复，并验证真实联网。

### stage128：建筑雨棚烟囱、山脊纵深与日照
- 既有建筑 (-42,0,-35) 增加有碰撞的外挑雨棚、立柱和分层烟囱，补入口暖光；提高不规则山脊并调整太阳方向，增加局部草斑。实机入口轮廓和宽景山体改善可辨识，但草斑改善不明显，建筑盒状感、平地及重复植被仍在，整体 continue。
- 保存并审阅 127→128 同机位入口、宽幅地形及普通出生对照；新增入口基线重新运行127采集。位置、朝向、哈希、退出码及软件渲染/冻结截图限制见 `artifacts/realism128-validation/capture-evidence.json`，审阅见 `docs/STAGE128_ENVIRONMENT_REVIEW.md`。
- 十项回归及16角色单机冒烟全部退出0/PASS，覆盖五处建筑通行、入口/屋顶、108样本瞄准、武器遮挡、本地网络状态规则；另通过新增立柱阻挡和雨棚向上射线测试。证据：同目录 `functional-results.json`、`offline-smoke.log`、`utility-station-collision.log`、`utility-station-traversal.json`。真实认证联机尚未验收。
- 当前预览 `artifacts/realism128-preview/Linux/IronMeridian`，相邻PCK为本轮导出，README含启动方法，build.json哈希已核对。保留未提交修改，未推送或发布。
- 下一步：继续改善正常机位可见的近中景建筑体量、地表材质尺度与植被重复；结合第三人称人物及第一人称连续动作实机审阅，修复袖子折面、霰弹枪装填、蹲姿及弹匣接触，并补齐真实联网验证。

### stage129：车间砖墙裙、路边草带和雾光调整
- 西侧车间增加砖墙裙、压顶、斜撑，路边草丛增加覆盖与高度，降低雾密度和Forward+环境光。入口墙裙、宽景草带变化明确；出生点和另一仓库改善很小，盒状建筑、地形及植被重复仍在，整体continue。
- 128基线本轮重新实机采集；保存并审阅四组环境与普通出生同机位对照。位置/朝向、哈希及退出码见 `artifacts/realism129-validation/capture-evidence.json`，详细判断见 `docs/STAGE129_ENVIRONMENT_REVIEW.md`。初版墙裙遮挡经截图和射线发现后已修正，原始失败证据保留。
- 最终包车间双向实际通行、柱/棚顶/砖墙碰撞、32雨棚96射线、16角色单机冒烟和本地网络规则退出0；其他通行、屋顶、108样本瞄准、武器遮挡在局部几何修正前通过。初始批次143及脚本/射线失败、瞄准Dummy渲染警告均记录在 `verification-summary.json`；真实联机未验收。
- 本地预览 `artifacts/realism129-preview/Linux/IronMeridian` 已实际运行；相邻最终PCK、README、build.json可复核。保留未提交修改，未推送发布。
- 下一步：第三人称行走/奔跑/蹲姿/换弹与三把第一人称武器完整连续动作实机审阅，安排手部、袖子及弹匣接触修复；继续建筑体量、院落用途、地形植被改进，并补齐真实联网主要流程。

### stage130：连续动作审阅与门洞命中验证
- 按 stage129 下一步补足动作证据；修正第三人称采集路线及遮挡失败退出，加入蹲起采样。中央道路起点 `(0,0.3,68)` 的步枪第三人称重跑退出0：438 tick，41张人物帧均有四条无遮挡射线；相机位置/朝向见 `artifacts/realism130-validation/third-actions/action-timeline.json`。
- 三枪第一人称图片已审阅，但首次联合运行因第三人称矮墙遮挡失败，未生成完整元数据；保留失败日志，不记为三枪完整验收。`review.html` 本地逐帧页明确区分这些图片与成功重跑数据。
- 新增真实 shoot 路径测试：三枪门洞伤害23/73.2181/78，邻墙后伤害均0；建筑双向通行及本地网络状态规则通过。日志与JSON在 `artifacts/realism130-validation/`；真实联网仍未验收。
- 实图确认手掌偏方、腕袖生硬、弹匣缺乏明确交换，人物正面过暗、蹲姿膝部拥挤和靴子偏大；建筑及树木重复仍明显。详见 `docs/STAGE130_ACTION_REVIEW.md`。本轮改进验证工具，未修改画面资产，不计作画质提升，整体continue。
- 当前本地可运行预览仍为 `artifacts/realism129-preview/Linux/IronMeridian`，本轮实际启动该包，哈希见130目录 `build-evidence.json`。保留全部未提交修改，未推送发布。
- 下一步：实现可辨识的第一人称弹匣交换，修正第三人称蹲姿与腕肘并保留本轮机位对照，重跑三枪完整连续序列；持续改善建筑体量、地表植被和光照，并补齐真实联网主要功能。

### stage131：弹匣交换实现与最终包回归（环境优先事项仍欠缺）
- 第一人称三枪加入旧匣下探、替换匣抬起/入位，支撑手跟随当前弹匣，完成与切枪恢复。未改建筑、植被或光照；本轮偏离当前环境优先要求，不算环境阶段完成，整体继续。
- 修正截图延迟变换同步后，129基线/131最终包各31个关键帧采集退出0；相机、朝向、角色位置和tick逐帧匹配。每侧7个人物帧、28条无遮挡射线通过。`artifacts/realism131-validation/review.html`、两侧 `action-timeline.json` 和 `comparison-checks.json` 可复核；旧未同步尝试排除。
- 最终包单机冒烟、三枪183样本换弹接触及6相位切枪中断、108样本瞄准、三枪门洞命中/墙体遮挡、仓库双向通行和网络状态规则通过，日志见同目录 `verification-summary.json`。真实认证联网未验证，需要授权测试会话/夹具；稀疏抓图不代表完整对局、全部中间动作或FPS测试。
- 实图仍见方形手掌、生硬腕袖、过暗人物、拥挤蹲姿及重复空旷环境。详见 `docs/STAGE131_ACTION_REVIEW.md`。本地预览 `artifacts/realism131-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus` 已运行，附PCK、README、build.json。保留未提交修改，未推送发布。
- 下一步必须执行环境改进组：正常机位可辨识的建筑体量/入口与院落用途、近景地表草灌分布、光照阴影层次；保存相同机位前后、入口近景和宽幅地形实机图及相机元数据，验证建筑碰撞与单机通行。随后继续人物、手部缺陷和真实联网主要流程，不能再次整轮仅限武器微调。

### stage132：工坊入口、路边石草与太阳方向调整
- 工坊增加高窗带和金属入口构件；四处路边增加12块有碰撞岩石、152株草，调整太阳角度。已导出并实际运行 `artifacts/realism132-preview/Linux/IronMeridian`，启动参数 `--path /tmp --rendering-method forward_plus`，附PCK、README与哈希。
- 保存工坊接近/入口、仓库入口、宽幅地形和出生点同机位前后实图；位置与朝向见 `artifacts/realism132-validation/comparison-checks.json`，画廊 `review.html`。after及出生点采集外层退出143，虽有PASS、完整PNG及元数据，仍记录异常，见 `capture-process-audit.json`。
- 最终包11项功能检查通过：五组单机通行、入口/屋顶碰撞、瞄准、武器遮挡、本地网络状态规则、单机冒烟；新增岩石角色碰撞检查通过。见 `functional-results.json`、`verge-outcrop-collision.json`。真实联网仍未验证。
- 实图审阅：入口差异明显，但金属罩叠层冗余、高窗被雨棚遮挡；宽幅改善小，院落空旷、树木与地表重复仍明显。详见同目录 `visual-review.md`。整体continue，不以局部变化或截图数量判定完成。
- 下一步：整合入口资产并改善正常机位可见的建筑体量、院落用途与连续草灌裸土分布，继续同机位对照；随后修复人物与手部剩余缺陷并补齐真实联网主要流程。保留所有未提交修改，未推送发布。

### stage133：工坊入口整合、管材院落与局部草石地表
- 移除工坊冗余叠层金属罩，保留原入口构件；两处院落增加中空混凝土管堆、木垫块、碎石和宽叶植被，调整环境光与SSAO。管口分离端面/内外壁法线，修正初版橡胶圆环感。东侧堆料由 (23,0,17) 移至 (17,0,17)，修复实测仓库通行阻塞。
- 最终包四个必需机位与132基线采集均退出0，1280×800，角色位置/眼高/yaw/pitch完全一致；涵盖工坊接近、工坊入口、仓库入口及宽幅地形。证据 `artifacts/realism133-validation/review.html`、`comparison-checks.json`、`accepted/`。额外出生点首次480秒超时124，重试未产图后主动中止143，保留 `accepted-spawn/` 日志，不计通过，也不以中间版本替代。
- 最终包12项检查通过：新增管堆空心射线、管壁及角色阻挡/绕行，五组单机通行、入口/屋顶碰撞、108样本瞄准、武器遮挡、本地网络状态规则及单机冒烟；详见 `verified/functional-results.json`、`verification-summary.json`。保留初次围栏起点、堆料阻路及导出期间资源读取失败记录，最终验证在稳定导出后执行。真实联网主要流程仍未验证。
- 实图审阅：管材院落与入口变化可辨识，但部分堆料位于画面边缘、管口过齐；宽幅改善有限，地面平坦、树形重复、建筑方盒轮廓和室内灰平地面仍明显。详见 `visual-review.md`。整体继续，不宣称整体画质显著提升或目标完成。
- 当前本地可运行预览 `artifacts/realism133-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus` 已实际启动，附PCK、README和更新哈希。保留所有未提交修改；未推送、发布或修改后台服务。
- 下一步：优先改善正常机位中景建筑体量、连续草灌/裸土过渡与可通行地形起伏，避免仅追加边缘道具；继续同机位实图审阅与入口通行回归。随后结合第三人称蹲姿、腕袖、第一人称方形手掌与连续动作审阅修复缺陷，并补齐真实联网主要流程。

### stage134：工业筒仓、可通行草坡与明暗分区
- 厂区新增两座不同高度的金属筒仓、锥顶、加强环及装饰梯，带碰撞并保留筒间通路；三段局部草坡增加曲面碰撞并同步草丛高度，环境填充光由0.43降至0.38。正常道路机位工业轮廓明显变化，宽幅改变仍有限。
- 保存133基线与最终134包六组完全相同机位实图，含工坊接近、两处入口、宽幅地形、筒仓与草坡近景；四次采集均退出0。相机位置、朝向及哈希见 `artifacts/realism134-validation/comparison-checks.json` 和各截图目录元数据，画廊 `review.html`，审阅 `visual-review.md`。采用Forward+软件渲染固定战局截图，不代表连续操作帧率。
- 最终包13项子测试退出0且均有PASS：两条草坡通行最高约0.724米、筒仓阻挡与间隙通行、既有院落/建筑通行、入口/屋顶碰撞、108样本瞄准、武器遮挡、本地网络状态规则、单机冒烟。第三段草坡未独立步行验证。测试包装进程最终退出143，原因未确定，单独保留异常，不声称包装进程正常退出；见 `verified/functional-results.json`、逐项日志及 `verification-summary.json`。
- 当前预览 `artifacts/realism134-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus` 已实际运行，附PCK、README与build.json；已核对源码、测试和导出包哈希。未推送或发布，保留全部未提交修改。
- 画质限制：筒仓金属偏暗且缺少风化，场地仍平坦空旷、草树与屋顶重复，室内地坪均匀灰白；第一人称阴影手套偏暗。整体continue，真实联网、第三人称及连续手部动作仍未完成验收。
- 下一步：扩大正常机位可见的连续地形、草灌裸土过渡并改善筒仓材质层次，补第三段草坡通行；继续入口及宽幅同机位审阅，结合第三人称和连续手部动作安排剩余修复，并补齐真实联网主要流程。

### stage135：筒仓镀锌层次与连续草坡覆盖
- 筒仓增加镀锌漫反射、波纹法线、板缝与底部氧化，改善此前暗且光滑的金属外观；三段草坡增加连续高草覆盖，并保留西侧低草通行带。此次调整材质受光表现，未改变全局光照参数。
- 保存134原始实图基线与135最终包六组同机位对照，包含正常道路机位、两处建筑入口、宽幅地形和筒仓/草坡近景；基线为复制已有实图，非本轮重拍。相机位置和朝向见 `artifacts/realism135-validation/comparison-checks.json`，画廊 `review.html`，实图审阅 `visual-review.md`。
- 最终包13项回归全部退出0并有PASS：三段草坡步行最高约0.724/0.724/0.728米，筒仓阻挡与间隙通行、院落及建筑通行、入口与屋顶碰撞、108样本瞄准、武器遮挡、网络状态规则、单机冒烟。导入、导出、两次截图采集及验证包装进程均退出0，日志扫描无ERROR/WARNING，构建哈希核对通过；见 `verification-summary.json`、`verified/functional-results.json` 和逐项日志。网络状态规则并非真实多人联机验收。
- 当前可运行预览：`artifacts/realism135-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，附PCK、README与build.json；该包已实际运行并用于本轮截图。固定战局的软件渲染截图不代表连续操作帧率。保留全部未提交修改，未推送、发布或修改后台服务。
- 审阅结论：筒仓材质与草坡近景有可辨识改善，建筑入口基本不变，宽幅改善有限；大面积空地、平直道路、重复山树与屋顶、均匀灰白室内地坪仍明显，锈迹与草丛存在规则重复。本轮只完成局部阶段，整体继续。
- 下一步：优先处理正常游戏宽幅机位中的大面积地表过渡和建筑地坪/体量、光照层次，继续同机位入口与地形实图及通行验证；随后结合第三人称、第一人称手部连续动作审阅修复，补齐真实联网主要流程，不能以截图数量或本次局部改善判断整体完成。

### stage136：地表枯草过渡、建筑作业地坪与室内光照
- 平地、外圈地面与可步行草坡共用世界坐标土壤/枯草混合材质；建筑地坪增加磨损黄色通道线、轮迹及局部油渍，室内聚光灯能量2.4→1.35、角度72°→58°。正常入口机位能辨识标线与收窄的亮区，草丛间裸土增加枯草底色；未更改碰撞体。
- 保存六组同机位前后对照，含车间外观、车间/仓库入口、宽幅地形及筒仓/草坡近景。before为复制stage135已有实图，after由136最终包实际运行生成；来源、位置与朝向见 `artifacts/realism136-validation/baseline-origin.json`、`comparison-checks.json` 和after目录的 `environment-camera-poses.json`。画廊 `review.html`，逐图判断 `visual-review.md`；像素差不作画质分数。
- 最终包13项回归全部退出0且有PASS：草坡与筒仓、院落及建筑通行、入口和屋顶碰撞、108样本瞄准、武器遮挡、网络状态规则、单机冒烟（换弹/治疗/伤害/胜利等）。导入、导出、两次实机截图及验证包装进程退出0，日志扫描无ERROR/WARNING，构建哈希核对通过；见 `artifacts/realism136-validation/verification-summary.json`、`verified/functional-results.json` 及逐项日志。网络规则测试不等于真实多人验收。
- 当前本地预览：`./artifacts/realism136-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，同目录保留PCK，附README和build.json。该包已用于本轮实机截图与回归；Xvfb/llvmpipe固定战局截图不代表连续操作帧率。保留已有未提交修改，未推送、发布或改动后台服务。
- 画质局限：新增地表斑块偏黄且程序感明显，缺少贴地碎叶/砾石，远山、道路与建筑布局仍重复空旷；室内地坪仍平滑，油渍不够显眼。人物及手部连续动作、真实联网主要流程尚未验收，整体目标未完成。
- 下一步：降低地表黄斑饱和度，增加自然碎石/枯叶和植被群落过渡，打破正常宽幅机位的空旷与重复；保持入口和地形同机位实图、建筑碰撞与单机通行验证，再结合第三人称人物与第一人称手腕动作修复，并补齐真实联网验收。

### stage137：草地扫描偏色修正与贴地碎石枯叶
- 降低扫描土壤黄绿色饱和度并调整枯草底色，加入按地形高度与独立随机种子生成的成簇碎石/枯叶；避开道路、建筑和硬化区域，按小区块批量绘制。本轮沿用已有建筑和光照，不将其计作新增成果。
- 已人工查看宽幅地形、筒仓、草坡、车间接近及两处入口实机截图。大面积黄斑明显收敛，碎石正常机位可辨识；但碎石阳光下偏白、枯叶效果较弱，场地仍空旷重复，人物前臂形态仍有缺陷，整体目标未完成。
- 六组同机位对照：before复制stage136实图，after来自137最终包Forward+实际运行；来源、位置与朝向见 `artifacts/realism137-validation/baseline-origin.json`、`comparison-checks.json` 和after两目录的 `environment-camera-poses.json`。查看 `review.html` 与 `visual-review.md`；入口近景及宽幅地形均已保存。
- 最终包13项回归均退出0且有PASS，覆盖坡地/建筑双向通行、门柱/入口/屋顶碰撞、108样本瞄准、武器阻挡、网络状态规则及单机冒烟。导入、导出、两次截图和验证包装进程退出0，日志扫描无ERROR/WARNING，构建哈希一致；见 `artifacts/realism137-validation/verification-summary.json`、`verified/functional-results.json` 与逐项日志。网络规则测试不等于真实联机；固定战局软件渲染截图不证明连续交互帧率。
- 本地可运行预览：`./artifacts/realism137-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`；保留同目录PCK，附README和build.json。保留所有原有未提交修改，未推送、发布或修改后台服务。
- 下一步：在正常宽幅机位改善一处完整建筑周边作业区，结合外部设施、土路磨损、成簇灌木与檐下接触阴影打破空旷布局，避免继续整轮只微调碎石/草色。继续保存入口与地形同机位对照及通行验证，再结合第三人称、手部动态审阅补齐角色缺陷、真实双客户端联网和连续运行性能验收。

### stage138：车间储罐作业区、入口土路与边缘植被
- 新增横向储罐、支座箍带、管道柜、护栏和投影作业灯；土路连接道路与车间入口，清除通路草丛并补植设施边缘阔叶草。正常持枪接近及草坡机位可明确辨识新体量；日照下灯光贡献不突出，不宣称整体光照改善完成。
- 已人工审阅六组实机机位，包括两处入口近景和宽幅地形。before来自stage137，after由138最终包Forward+运行生成；对照、来源及位置朝向见 `artifacts/realism138-validation/review.html`、`baseline-origin.json`、`comparison-checks.json` 和after两目录的 `environment-camera-poses.json`。详细判断见 `visual-review.md`。
- 首次护栏与灯杆阻挡原有x=-26草坡路线，失败日志保留在 `artifacts/realism138-validation/attempt1/verified/`；向东调整后重新导出，原阈值测试通过。新增真实角色土路通行、储罐阻挡和壳体射线测试，见 `tests/workyard_traversal_review.gd`。
- 最终包14项回归退出0且有PASS，覆盖建筑/地形通行、入口/屋顶碰撞、108样本瞄准、武器遮挡、网络状态规则及单机冒烟。导入、导出、两次截图和验证包装进程退出0，日志扫描无ERROR/WARNING，构建哈希一致；见 `artifacts/realism138-validation/verification-summary.json` 与 `verified/functional-results.json`。网络规则检查不等于真实双客户端验收，固定软件渲染截图不证明交互帧率。
- 当前本地预览：`./artifacts/realism138-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，保留同目录PCK，附README与build.json。保留所有已有未提交修改，未推送或发布。
- 局限与下一步：宽幅机位新增设施仅在最左边缘，主体道路、院地和远山树林仍空旷重复；储罐端面简单、土路纹理偏糊，前臂仍细长有折面。下一阶段须直接改善宽幅主体区域的建筑周边布局和地表过渡，继续入口碰撞与同机位取证；随后结合第三人称及手部动态审阅修复角色，补齐真实联网与连续运行性能。整体目标未完成。

### stage139：主体维修棚山墙、入口地坪与边缘植被
- 为宽幅主体区域绿色维修棚补齐后山墙、保留2.6米宽门洞，增加混凝土作业地坪、排水槽、左侧木料及两侧草簇和局部作业灯。入口近景与宽幅均能辨认变化；灯光贡献有限，地坪矩形边缘、植被重复和远山棱角仍明显，整体目标未完成。
- 七组实际Forward+同机位前后对照已人工审阅，包含维修棚、车间及仓库入口、宽幅地形、筒仓和草坡。六张基线沿用138原始截图，维修棚由138运行包补拍；相机位置与朝向、来源及对照见 `artifacts/realism139-validation/review.html`、`baseline-origin.json`、`comparison-checks.json` 和各截图目录 `environment-camera-poses.json`。判断及局限见 `visual-review.md`。
- 新增 `tests/repair_shelter_traversal_review.gd` 验证真实角色双向穿行、木料阻挡、门洞净空及山墙双侧射线碰撞。首次山墙绕序错误已修复并重新导出，失败证据保存在 `artifacts/realism139-validation/attempt1/`。
- 最终包15项回归退出0并输出PASS，含建筑/地形通行、入口/屋顶碰撞、108样本瞄准、武器遮挡、网络状态规则和单机冒烟。最终导入、导出、有效截图及测试日志扫描无ERROR/WARNING；见 `verification-summary.json`、`verified/functional-results.json` 和逐项日志。网络规则测试不等于真实双客户端联机；冻结战局的软件渲染截图不证明连续交互性能。
- 额外出生点基线补拍约八分钟没有输出截图，停止本轮自建补拍进程，未计入有效证据；见 `spawn-process-audit.json` 与 `before-spawn/capture.log`，原因未定位。未修改后台服务。
- 当前本地可运行预览：`./artifacts/realism139-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，保留同目录PCK；附README及源码/运行包哈希 `build.json`。保留已有未提交修改，未推送或发布。
- 下一步：改善主体地坪与泥地过渡、建筑周边生活痕迹及远景重复；排查出生点补拍异常。结合第三人称人物与第一人称手部动态实机审阅修复折面和比例，补齐真实双客户端联网与连续运行性能，不能将本轮环境增量视为整体完成。

### stage140：维修棚入口结构、地坪表面与混合草带
- 为宽幅主体维修棚增加部分开启的两侧推拉门、门楣、五金和入口作业灯；地坪增加接缝、局部油污及边缘尘土，原先重复的大叶草带改为不规则细草与少量阔叶混合。入口及宽幅正常机位能辨认门板和草带变化；污迹与日间灯光贡献较弱，地坪边缘仍生硬，门板仍平整，整体目标未完成。
- 保存并实际审阅七组139→140同机位Forward+前后对照，含维修棚近景、车间及仓库入口、宽幅地形、筒仓和草坡；位置与朝向严格匹配。见 `artifacts/realism140-validation/review.html`、`comparison-checks.json`、`baseline-origin.json`、各截图目录 `environment-camera-poses.json` 及 `visual-review.md`。远山棱角、重复树林、空旷中景和前臂折面仍明显，不能以截图数量判定画质。
- 维修棚角色双向穿行、木料阻挡、后门净空及山墙双面碰撞通过；新增前门两侧射线命中 z=33.18，中心通道畅通。最终运行包15项回归全部退出0并有PASS，含入口/屋顶碰撞、108样本瞄准、武器遮挡、网络状态规则和单机冒烟。导入、导出及三次截图进程成功，日志无ERROR/WARNING，构建哈希匹配；见 `artifacts/realism140-validation/verification-summary.json`、`verified/functional-results.json` 与逐项日志。
- 当前本地预览：`./artifacts/realism140-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，保留同目录PCK；附README和build.json。保留所有已有未提交修改，未推送或发布，未操作后台服务。
- 下一步：优先改善中景地形、植被分布和地坪向泥地过渡；排查139原始出生朝向补拍超时（140没有补齐该机位）。继续第三人称人物及第一人称手部动态审阅，补齐真实双客户端联网和连续运行性能；本轮网络规则与软件渲染固定截图不构成这些验收。

### stage141：作业区泥地过渡、棚侧幼树及碰撞回归
- 维修棚侧墙应用现有金属表面材质；作业区泥地边界改为带噪声的圆角过渡；装卸棚南侧新增四棵不同尺度与朝向的幼树及104株混合地被，树木参与投影并有树干碰撞，未调整太阳或灯具参数。
- 保存并实际审阅七组140→141同机位实机对照，含维修棚入口近景及宽幅地形；基线沿用140原始截图，位置与朝向严格匹配。见 `artifacts/realism141-validation/review.html`、`visual-review.md`、`comparison-checks.json`、各截图目录的 `environment-camera-poses.json`。首版树冠穿插雨棚，已移位修复并保留 `attempt1-canopy-overlap/` 失败证据；新增四棵树实际网格包围盒与屋顶不相交检查。
- 诚实审阅：泥地边缘有轻微改善，侧墙差异较小；最终幼树主要位于宽幅画面右缘，主体构图提升有限。其他入口、筒仓和草坡画面仅作回归证据。中景空旷、远山棱角、重复树林、平整门板及前臂折面仍明显，本轮有限增量不代表整体目标完成。
- 最终预览包15项回归全部退出0并有PASS，覆盖建筑双向通行、棚侧通行、树干/入口/屋顶碰撞、108组瞄准样本、武器遮挡、网络状态规则及单机冒烟。三次截图进程成功；最终导入、导出、截图和测试日志无ERROR/WARNING，构建哈希匹配。见 `artifacts/realism141-validation/verification-summary.json` 与 `verified/functional-results.json`。网络规则未替代真实双客户端验收，llvmpipe固定截图未验证连续操作性能。
- 当前本地预览：`./artifacts/realism141-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，保留同目录PCK；附README和build.json。标准导出模板缺失，已用现有Godot可执行文件配合export-pack生成并验证预览，首次导出失败日志保留。保留已有未提交修改，未推送、发布或操作后台服务。
- 下一步：优先改善宽幅正常机位中央可见的地形、植被和建筑周边空间，避免继续把边缘植被或微小材质调整作为主要成果；排查139出生朝向补拍超时。保留第三人称人物、第一人称手部动态、武器完整验证及真实双客户端联机、连续运行性能的剩余目标。

### stage142：维修棚入口雨棚、路旁树组及实际通行验证
- 维修棚新增斜坡金属雨棚、立柱、边梁和排水槽，入口近景可明显辨识屋面及投影；新增三棵不同尺度的路旁针叶树、132株混合地被及三块岩石。几何参与阴影与相应碰撞，未调整太阳或曝光参数。
- 保存并实际审阅七组141→142同机位对照，含建筑入口近景和宽幅地形；基线沿用141原始截图。见 `artifacts/realism142-validation/review.html`、`visual-review.md`、`comparison-checks.json` 及截图目录内相机位置/朝向JSON。诚实结论：雨棚改善明显，宽幅新树组大部分被建筑遮挡，整体地形植被构图尚未达到目标；重复建筑、远山棱角、地面材质和手臂折面仍需改进。
- 最终预览15项回归通过，包括棚内双向通行、路旁通行、七棵树干及雨棚立柱/屋顶碰撞、建筑入口与屋顶、108组瞄准样本、武器遮挡、网络状态规则及单机冒烟；三次实机截图进程成功，七组机位一致，最终日志无ERROR/WARNING，构建哈希匹配。新增测试首次因GDScript类型推断失败，显式声明Dictionary后实际重跑通过，失败及重试证据保留于 `attempt1-test-parse/`、`repair-test-retry.json`。汇总：`artifacts/realism142-validation/verification-summary.json`。
- 本地预览：`./artifacts/realism142-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，保留相邻PCK，附README与build.json。使用现有Godot可执行文件及export-pack；未推送或发布，保留已有修改。
- 下一步：安排连续第一/第三人称实机动作、移动目标射击及真实双客户端同步验证，结合人物与手部截图处理缺陷；宽幅植被应按实际投影位置改善，不能继续用边缘或遮挡树组代替整体构图。139出生朝向补拍超时仍待排查；当前固定截图、强制状态单机冒烟和网络规则测试不能替代完整单机对局、实际联网或连续运行性能验收，整体目标未完成。

### stage143：第一/第三人称动作关键帧及移动目标射击验证
- 扩展 `tests/action_timeline_capture.gd` 的动作中间帧采样；新增 `tests/moving_target_fire.gd`，实际地面移动目标覆盖三类武器17次有效射击、约140.31米移动，检查弹药、伤害、射线与贴地状态。固定种子及增大目标生命值的单机夹具不替代真实联机或完整对局。
- 使用142本地预览实际生成57个动作采样（1266模拟步），保存相机位置/朝向及动作状态；审阅两张接触表和跑动、蹲行、换弹原图。证据：`artifacts/realism143-validation/review.html`、`visual-review.md`、`actions/action-timeline.json`。人物胸前弹袋与护膝方块化、前臂折面、重复树林、棱角山体和平整路面仍明显。本轮无运行时画面改动，不计为画质提升，也没有新环境前后对照。
- 动作采样、移动目标测试及四项回归全部退出0，最终日志无ERROR/WARNING；回归覆盖108组瞄准、武器遮挡、维修棚通行碰撞和建筑入口。初版移动射击夹具间隔/容量失败和退出警告日志保留，修正后实际重跑。见 `artifacts/realism143-validation/verification-summary.json`、`functional-results.json`。duo仅健康接口200，真实双客户端未执行（现有脚本依赖登录凭据且可能自动注册）；未读取凭据或改变认证。
- 当前可运行预览仍为 `./artifacts/realism142-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，保留相邻PCK；142构建清单文件哈希全部匹配。未推送、发布或修改后台服务，保留原有未提交修改。
- 下一步：恢复正常宽幅机位中央可见的环境实质改善，重点树林分布、地面层次、建筑周边及光照，保存同机位前后、入口与宽幅对照并复核通行碰撞；结合本轮动作审阅修正人物装备和手臂。完整单机、真实双客户端、连续操作性能、139出生朝向补拍仍待完成；固定采样及冻结其他人物不替代这些验收，整体目标未完成。

### stage144：正常宽幅可见的西侧树群与维修棚门板
- 西侧空隙新增五棵不同尺度针叶树及混合地被，宽幅地形和车间接近机位可辨识新增树群；树干具有实体碰撞，保留道路与管材区通行。维修棚门板改为纵向压筋与底部污渍材质。天空环境光由0.38调整至0.32，但入口截图变化极小，不计为明显光照改善。
- 实际生成并审阅七组142→144同机位对照，包含维修棚、车间、仓库入口及宽幅地形；前图沿用142原始截图，未重新拍摄。相机位置、朝向和1280×800尺寸全部匹配。见 `artifacts/realism144-validation/review.html`、`visual-review.md`、`comparison-checks.json` 和各截图目录的 `environment-camera-poses.json`。地表平整、草丛排列规律、远山棱角、远林重复、箱体UV拉伸及前臂折面仍明显，整体写实目标未完成。
- 最终预览16项检查全部退出0并出现PASS，覆盖新增五棵树干碰撞、建筑双向通行、入口和屋顶碰撞、108组瞄准、武器遮挡、网络状态规则及单机冒烟。扫描21份最终日志无ERROR/WARNING，14项构建哈希匹配。原验证调度进程退出143，原因未知；保留已完成11项证据并重跑剩余五项成功，记录 `runner-interruption.json`，未隐去中断。汇总：`artifacts/realism144-validation/verification-summary.json`。
- 当前本地预览：`./artifacts/realism144-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，保留相邻PCK；附README与build.json。本轮未推送、发布、部署或改动后台服务，保留所有已有修改。
- 下一步：继续改善正常机位的地表材质、植被分布和建筑周边层次，光照需以可见效果复核；结合143动作截图处理第三人称装备方块化及第一人称前臂折面。真实双客户端联网、完整单机对局、连续操作性能及139出生朝向补拍超时仍待处理；固定截图、网络状态规则和单机冒烟不替代这些验收。

### stage145：维修棚上部立面、弯曲车辙与路缘草带
- 维修棚新增弧形压筋钢板山墙和高窗条带，正常宽景与入口近景均可辨识；高窗为不透明玻璃近似，不具备真实透光。新增双面实体碰撞，中央入口保留2.9米净高。地面磨损、双车辙与植被避让共用弯曲路径，草带集中至两侧；太阳角直径调至0.65，但截图未证实明显柔影改善。
- 已审阅七组144→145同机位实机对照，涵盖维修棚、车间、仓库入口、地表植被和宽幅地形；前图沿用144原始截图。相机位置、朝向与1280×800尺寸一致，记录在各目录environment-camera-poses.json和comparison-checks.json；入口新立面与宽景路径变化明显，但裸地增多、车辙仍像平面色带，箱体UV拉伸、规律草丛、重复树林、棱角远山及前臂折面尚存。证据：artifacts/realism145-validation/review.html、visual-review.md。不以像素变化或截图数量判断画质达标。
- 最终16项检查全部退出0并出现PASS，包含实际CharacterBody3D建筑双向通行、新山墙双面射线、树干/入口/屋顶碰撞、三种武器108组瞄准、武器遮挡、网络状态规则及单机冒烟。维修棚双向通过z38→24.25及z24→37.75，新山墙两方向命中z32.98。21份最终日志无ERROR/WARNING，15项源码/构建哈希匹配；见artifacts/realism145-validation/verification-summary.json及verified/functional-results.json。首次调度进程退出143，原因未知，保留成功证据后续跑完成，记录runner-interruption.json。
- 当前本地预览：./artifacts/realism145-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus，保持相邻PCK；附README.md与build.json。本轮实际使用Forward+ Vulkan llvmpipe生成截图，未作硬件帧率结论。未推送、发布、部署或修改后台服务，保留所有已有未提交修改。
- 下一步：优先修正当前宽景地面平涂感和路径边缘细节，继续改善植被重复与远山轮廓，光照以可见效果验收；结合143动作截图处理第三人称胸前弹袋/护膝方块化与第一人称前臂折面。真实双客户端、完整单机对局、连续操作性能及139出生朝向补拍超时仍未完成；网络规则、单机冒烟及受控机位不能替代这些验收，整体目标继续。

### stage146：地表碎石细节与草土边界
- 草地道路混合泥土、碎石纹理及微表面法线，打散路缘和车道中央植被恢复区，减弱棚前深色车辙，调整西侧草簇避让。宽幅实机对照显示浅色连续路缘和深色条带减弱、地面颗粒更清楚；入口变化较小，地面仍偏平。本轮未新增建筑几何或改变全局光源，法线不产生真实车辙深度，不能算整体画质达标。
- 保存七组145→146同机位对照，前图沿用145原始截图，来源见baseline-origin.json；逐项核对位置、朝向及1280×800尺寸。人工审阅宽景、棚入口、草坡前后图及车间/仓库入口当前图，记录artifacts/realism146-validation/visual-review.md，对照入口review.html。宽景角色位置(17,0.05,50)，目标(-46,12,-90)，yaw=0.422854、pitch=0.067315、眼高偏移1.6；完整机位见after/environment-camera-poses.json及comparison-checks.json。
- 导出预览16项功能检查均退出0并出现PASS，覆盖建筑通行、树干/入口/屋顶碰撞、三种武器108组瞄准、武器遮挡、网络状态规则和单机冒烟；21份日志无ERROR/WARNING，17项文件哈希一致。证据artifacts/realism146-validation/verification-summary.json及verified/functional-results.json。实际截图采用Forward+ / llvmpipe，不据此判断硬件性能。
- 当前本地预览：./artifacts/realism146-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus，保持同目录PCK；README.md记录启动方式，build.json记录哈希。未推送、发布、部署或修改后台服务，保留已有修改。
- 下一步：改善正常机位的重复草簇、远山棱面和建筑落地接触层次，复核入口通行，光照变化需实机可辨；结合143动作审阅处理人物胸挂/护膝和第一人称手臂折面。真实双客户端鉴权/注册依赖、完整单机对局、连续操作性能及139出生机位超时仍待处理；本轮规则检查与冒烟不能替代这些验收，返回continue。

### stage147：山脊轮廓与背景林带
- 山脊周期尖齿改为世界坐标噪声起伏、减弱鞍部切口；背景林增加采样，按高度收疏树线并引入片状冠色变化。正常机位可见宽景右侧山肩更连续、维修棚后尖峰减少、筒仓左侧林带更连贯；西车间后方仍像堆叠土丘，近景草簇重复、灰色空地、建筑墙脚与室内光照偏平仍未解决。本轮没有新增建筑几何、全局光照或人物手臂改进，不能算整体达标。
- 保存七组146→147同机位对照，前图为146原始截图副本；来源baseline-origin.json，完整机位及尺寸核对comparison-checks.json。实际审阅宽景前后、棚入口前后、筒仓、草坡及车间/仓库入口，见artifacts/realism147-validation/visual-review.md与review.html。宽景角色(17,0.05,50)、目标(-46,12,-90)、yaw=0.422854、pitch=0.067315、眼高1.6；完整记录见after/environment-camera-poses.json及其余截图目录。
- 导出包16项检查全部退出0并出现PASS，覆盖实际角色建筑双向通行、树干/入口/屋顶碰撞、三种武器108组瞄准、武器遮挡、网络状态规则及单机冒烟。仓库双向通行z44→18.42486和z18→43.57514；21份日志无ERROR/WARNING，17项文件哈希一致。证据artifacts/realism147-validation/verification-summary.json及verified/functional-results.json；Forward+ / llvmpipe实机截图不作为硬件性能结论。
- 当前本地预览：./artifacts/realism147-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus，保持相邻PCK；README.md与build.json记录启动及构建。未推送、发布、部署或修改后台服务，保留所有未提交修改。
- 下一步：建筑墙脚接触与入口明暗、近地草土重复仍需实机可辨的改进；结合143连续动作检查点处理第三人称胸挂/护膝与第一人称前臂，避免无限延后人物问题。真实双客户端鉴权/注册依赖、完整单机对局、连续操作性能及139出生机位超时仍待处理；规则测试和冒烟不替代这些验收，返回continue。

### stage148：车间墙脚风化与入口室内光照
- workshop_masonry增加不规则潮湿/盐渍、压暗砂浆并按屏幕导数过滤细纹；建筑室内聚光灯扩大光锥并增强暖色照明。正常眼高入口前后可辨认亮砖缝减弱、墙脚污渍及通道光照增强；砖块仍规则、污渍略斑块化，远机位变化很小。宽幅地形、裸地及重复草簇没有明显改善，本轮不能算环境或整体目标完成。
- 保存147→148七组同机位实机对照，前图为147原始截图副本，来源baseline-origin.json；review.html、visual-review.md、comparison-checks.json均在artifacts/realism148-validation。车间入口角色(-42,0.05,44)、目标(-42,1.9,34)、yaw=0、pitch=0.024995；宽景角色(17,0.05,50)、目标(-46,12,-90)、yaw=0.422854、pitch=0.067315，眼高1.6，完整记录见after/environment-camera-poses.json。
- 导出包16项检查全部退出0且PASS，包括真实角色建筑双向通行、入口/屋顶/树干碰撞、三种武器108组瞄准、遮挡规则、网络状态规则和单机冒烟。三次截图进程均退出0；21份日志未检出ERROR/WARNING，18项源码与包散列一致。证据：verification-summary.json与verified/functional-results.json。Forward+ / llvmpipe截图不能证明硬件帧率；状态规则不能证明真实双客户端，通行及冒烟不能证明完整单机对局。
- 当前本地预览：./artifacts/realism148-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus（保持相邻PCK，需图形显示/Vulkan）；README.md记录启动，build.json记录构建。截图和检查使用此导出包。未推送、发布、部署或修改后台服务，保留所有未提交修改。
- 下一步：正常机位裸地、草丛分布与土壤过渡需要一组明显改进；随后结合143动作检查点处理第三人称胸挂/护膝及第一人称前臂，不无限延后人物。真实双客户端鉴权/注册依赖、完整单机对局、连续操作性能及139出生机位超时仍待处理。返回continue。

### stage149：低草覆盖与草土过渡
- 地被分布和地面材质共享覆盖图，提高低草占比、降低高度并扩宽草簇，增加草下暗绿腐殖土过渡及旋转土壤采样。正常草坡机位和宽景路肩可辨认覆盖更连续、灰土间隙减少；建筑及光照保留148成果。本轮未修改人物或武器，地面方向条纹、重复叶簇、筒仓条纹及尖角远山仍明显，整体目标未完成。
- 保存148原始截图→149导出包七组同机位实机对照，包含建筑入口近景及宽幅地形；artifacts/realism149-validation/review.html、visual-review.md、comparison-checks.json记录审阅、局限及精确相机一致性。草坡角色(-26,0.05,63)、目标(-26,0.6,50)、yaw=0、pitch=-0.080594274；宽景角色(17,0.05,50)、目标(-46,12,-90)、yaw=0.422854、pitch=0.067315，眼高1.6。完整位姿见各after目录environment-camera-poses.json，前图来源见baseline-origin.json。
- 导出包16项功能检查全部退出0且PASS，涵盖建筑通行、入口/屋顶/树干碰撞、三种武器108组瞄准、武器遮挡、网络状态规则与单机冒烟；三次截图进程退出0。verification-summary.json汇总21份日志无ERROR/WARNING、18项构建散列一致，逐项结果见verified/functional-results.json。两次启动进程返回143，原因未确定，恢复后完成剩余检查，记录于runner-interruption.json。软件Vulkan截图不证明硬件帧率，网络规则不证明真实双客户端，受控通行和冒烟不证明完整单机对局。
- 当前本地预览：./artifacts/realism149-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus（需图形显示/Vulkan及相邻PCK）；README.md与build.json记录启动和构建。未推送、发布、部署或修改后台服务，保留未提交修改。
- 下一步：结合143动作检查点实机审阅并修正第三人称胸挂/护膝及第一人称前臂，保留环境地面条纹、重复植被和筒仓材质缺陷清单；继续处理真实双客户端注册/鉴权依赖、完整单机对局、连续操作性能及139出生机位超时。返回continue。


### stage150：人物软包、护膝与第一人称袖褶实机复核
- 按149检查点，将胸挂盒体改为收底圆角软包、护膝改为圆角凸面，并降低前臂折痕深度、扩宽谷底。走路/蹲行实机对照可辨轮廓改善，袖褶改善有限；人物装备颜色、迷彩、脸部阴影及手掌仍简化。本轮环境保留145–149成果作回归，不声称新增环境改善或整体达标。
- 保存149预览重新采集→150预览共57组同动作同机位对照，覆盖三武器持枪/瞄准/射击/换弹及第三人称走跑蹲行动作；完整位姿、动作与相机一致性见artifacts/realism150-validation/action-comparison-checks.json，图集action-review.html。保留七组环境同机位对照、入口近景和宽幅地形，review.html及各after目录environment-camera-poses.json记录相机。宽景角色(17,0.05,50)、目标(-46,12,-90)，yaw=0.422854、pitch=0.067315；车间入口角色(-42,0.05,44)、目标(-42,1.9,34)，yaw=0、pitch=0.024995，眼高1.6。
- 导出包16项功能检查通过，含建筑角色双向通行、入口/屋顶/树干碰撞、三武器108项瞄准、遮挡、网络状态规则和单机冒烟；另6项静止目标实弹检查确认入口造成伤害、隔墙伤害为零。24项构建散列一致。verification-summary.json保留两项未解决诊断：无界面导入空纹理ERROR、实弹测试退出对象泄漏WARNING；相关进程退出0，不能说日志无异常。动作基线曾仅移除本轮超时监督进程，监督进程退出137非游戏退出码，最终57样本及PASS完整；当前动作进程退出0，见action-process-note.json。
- 当前本地预览：./artifacts/realism150-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus（需桌面/Vulkan及相邻PCK）；README.md、build.json记录运行及构建。实际审阅和局限见artifacts/realism150-validation/visual-review.md。未推送、发布、部署或修改后台服务，保留全部未提交修改。
- 下一步：回到正常机位地面方向条纹、重复草簇与规则树冠，实施可辨识的环境改进；追查上述导入/退出诊断。仍需运动目标和真实双客户端注册/鉴权及伤害同步、完整单机对局、连续操作性能与139出生机位超时验收。软件Vulkan固定步长截图不证明连续硬件帧率，规则与冒烟不替代完整功能，返回continue。


### stage151 — 草地采样、草叶弯曲与受光；环境实机回归（2026-09-14）
- 按环境优先级推进：`meadow_ground.gdshader` 混合三组旋转地表采样并同步旋转法线，降低草地法线强度；`grass.gdshader` 增加根部稳定的草叶弯曲并调整天空法线混合，使正常机位草丛轮廓与方向受光更明确。本轮没有修改建筑或全局灯光，不能将入口回归截图视作这些项目的改进。
- 保存 stage150→151 七组相同位置、朝向的实机对照，含草坡、宽幅地形、维修棚、工坊和仓库入口；before 明确来自 stage150 存档，after 使用本轮导出包。相机坐标、朝向与图像哈希见 `artifacts/realism151-validation/comparison-checks.json`，对照页 `review.html`，人工审阅 `visual-review.md`。风动画时间未锁定，像素差异不代表质量评分。
- 16 项功能测试通过：建筑/场地通行、入口与屋顶碰撞、108 项瞄准采样、武器遮挡、网络状态规则和单机烟测。仓库双向实际 actor 通行通过。`verified/functional-results.json` 与原始日志可复核；当前导入、导出、3 组截图和16项测试共21份日志未发现 ERROR/WARNING，25项构建哈希核对一致，见 `verification-summary.json`。网络规则测试不等于真实联网；未验证完整单局、移动目标命中或硬件帧率。
- 当前本地预览：`artifacts/realism151-preview/Linux/IronMeridian`（相邻 PCK 已从当前工作树重新导出）；启动 `./artifacts/realism151-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，需图形桌面与 Vulkan。说明和构建记录为该目录的 `README.md`、`build.json`。未推送或发布，保留所有未提交修改。
- 画质结论：本轮改善有限，不能判定整体目标完成。草坡仍有平行条纹，草木重复、山体光滑、室内地面和墙面偏平及灯光锥边界仍明显。下一轮先处理草地 litter 的单方向 `texture(soil, p * 0.73)` 调制，再实施正常入口机位能辨认的建筑地坪/墙脚材质与室内照明改进；随后结合第三人称人物与第一人称手部实机审阅继续修正，并补真实联网同步伤害、移动靶和完整单机流程。stage150 退出泄漏警告本轮未重测，不宣称修复；整体保持 continue。

### stage152 — 入口混凝土地坪与工坊照明；环境实机验证（2026-09-14）
- `warehouse_concrete.gdshader` 增加随距离衰减的骨料颜色/法线细节及地坪墙脚接触污渍；`world_visuals.gd` 调整西侧工坊灯光范围、能量与衰减。工坊与维修棚正常入口机位可辨认地坪变化，中央亮斑略弱；墙脚变化细微，室内仍空、材质颗粒略均匀。本轮未修改建筑几何或碰撞。
- `meadow_ground.gdshader` 用已有旋转混合 luminance 替代 litter 的单向 soil 采样调制。实机前后差异很小，草坡平行波纹仍明显，不宣称修复。已确认 `TraversableGrassBank` 使用 meadow_surface，后续排查此 shader 的法线与半米网格生成，而非直接归因远山 terrain_slopes。
- 保存 stage151 存档→152 导出包七组相同机位对照，覆盖入口近景、草坡和宽幅地形；`artifacts/realism152-validation/review.html`、`visual-review.md` 为对照和逐景审阅，`comparison-checks.json` 及各 after 目录的 `environment-camera-poses.json` 记录位置、朝向与哈希。入口角色(-42,0.05,44)、目标(-42,1.9,34)、yaw=0、pitch=0.024995；宽景角色(17,0.05,50)、目标(-46,12,-90)、yaw=0.422854、pitch=0.067315，眼高1.6。风动画未锁定，图像差异不是质量评分。
- 16项导出包功能检查通过，含建筑实际角色双向通行、入口/屋顶/树干碰撞、三武器108项瞄准、武器遮挡、网络状态规则及单机冒烟；`verified/functional-results.json` 保留日志路径。`verification-summary.json` 核验25项构建哈希，当前21份导入/导出/截图/测试日志未发现 ERROR/WARNING。规则测试不证明真实联机，冒烟不证明完整单局，软件 Vulkan 不证明硬件帧率；stage150实弹退出泄漏未重测。
- 当前本地预览：`./artifacts/realism152-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`（需桌面/Vulkan及相邻PCK）；该目录 `README.md`、`build.json` 保存说明与构建依据。未推送、发布或改动后台服务，保留全部未提交修改。
- 下一步：定位草坡条纹，减少正常机位草簇/树冠重复，继续建筑室内层次和地表改善；结合第三人称人物与第一人称手部动态实机审阅修正剩余缺陷，并补移动靶伤害、真实双客户端注册/鉴权和伤害同步、完整单机流程及连续性能验证。宽景改善有限，整体目标未完成，保持 continue。

### stage153 — 工坊配件货架、工作灯与草坡细纹过滤；环境实机验证（2026-09-14）
- `world_visuals.gd` 为西侧工坊后墙右侧加入三层货架、零件箱及暖色工作灯，正常第一人称入口可辨识，中央通道保持畅通；草坡改为高度函数差分顶点法线，`meadow_ground.gdshader` 对细颗粒与法线扰动做距离过滤。实际审阅：货架改善空白室内，地面细颗粒略减弱，但草坡长波纹仍明显，宽幅地形变化很小；本轮未调整植被布局，不宣称环境整体达标。
- `artifacts/realism153-validation/review.html` 保存 stage152 原始存档→153 七组同机位实机对照；`visual-review.md` 保存逐景结论，`comparison-checks.json` 保存完整位置、朝向和哈希。车间入口角色(-42,0.05,44)、yaw=0、pitch=0.024994794；宽景(17,0.05,50)、yaw=0.422853926、pitch=0.067315195，眼高1.6。baseline-origin.json 明确旧截图来源；风动画未锁定，像素差不作质量评分。
- 新增货架角色阻挡与射线断言通过：角色停止z=29.63044，射线命中前沿z=29.25；工坊、仓库及其他建筑双向通行和碰撞通过。16项导出包检查全部通过，含三武器108项瞄准、遮挡、网络状态规则、单机冒烟（16角色及换弹/治疗/伤害/胜利等断言）。`verified/functional-results.json`、`verified/west-workshop-traversal.json` 保存结果；`verification-summary.json` 核验26项构建哈希、七组相机一致，25份本轮日志未发现 ERROR/WARNING/FAIL/Error。
- 当前预览：`./artifacts/realism153-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，需桌面/Vulkan及相邻PCK；README.md 和 build.json 保存说明及构建依据。保留全部未提交修改，未推送、发布或调整后台服务。
- 下一步先隔离草坡长条纹来源（贴图/法线/网格或覆盖关系），用草坡和宽幅原机位验证，再改善重复树冠分布和远山轮廓。继续人物、第一人称手部与武器动态审阅，补真实双客户端鉴权/同步伤害、移动靶、完整单局和连续性能；本轮网络规则不代表真实联网，单机冒烟不代表完整比赛，软件 Vulkan 不证明硬件帧率，stage150退出泄漏未重测。整体目标未完成，保持 continue。


### stage154 — 车间立面设施、局部补光与草坡材质；环境实机验证（2026-09-14）
- 西侧车间增加带碰撞的电箱、门板/通风槽/把手、落水管和卡箍，补充室内暖光；初次实机发现旧电箱重叠，移除该入口旧件后重新导出、重拍并补跑车间通行。草地 shader 降低颗粒频率和法线扰动。入口附件可辨识，草坡条纹对比降低，但残留带纹、细噪点与人工顶棚亮斑仍需处理；未改植被布局，宽路空旷、重复树冠和棱角远山基本未改善，不视为整体目标达标。
- 保存 stage153 原始存档→154 七组同机位实机对照，包含入口与宽幅地形。`artifacts/realism154-validation/review.html`、`visual-review.md` 为对照与人工审阅；`baseline-origin.json` 明确旧图来源，`comparison-checks.json` 及各 after 目录 `environment-camera-poses.json` 记录完整位姿。入口(-42,0.05,44)、yaw=0、pitch=0.024994794；宽景(17,0.05,50)、yaw=0.422853926、pitch=0.067315195，眼高1.6。风动时间未锁定，像素差不作质量评分。
- `diagnostic/` 及相应截图目录保留草坡隔离实验：关闭太阳阴影、移除法线、分别固定纹理或噪声仍有条纹；固定整体地表输出后消失，但未确定单一根因，需继续检查混合权重和映射。
- 16项导出包功能检查通过，含建筑角色双向通行、电箱/货架/立柱/入口/屋顶/树干碰撞、三武器108项瞄准、遮挡、网络状态规则与单机冒烟。最后电箱修正后车间检查再次通过。`verified/functional-results.json`、`verified/west-workshop-traversal.json` 保存结果；`verification-summary.json` 核验26项构建哈希与七组相机一致，29份本轮日志无 ERROR/WARNING/FAIL/Error。网络规则不代表真实双客户端，冒烟不代表完整单局，软件 Vulkan 不证明硬件帧率；stage150退出泄漏未重测。
- 当前本地预览：`./artifacts/realism154-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，需桌面/Vulkan及相邻PCK；README.md、build.json 记录说明与构建。保留全部未提交修改，未推送、发布或调整后台服务。
- 下一步优先做宽幅正常机位可辨识的植被群落、道路边缘和远山轮廓改善，继续定位草坡条纹，避免只加车间小附件；再结合第三人称与第一人称手部动态审阅处理人物/武器缺陷。仍须真实双客户端鉴权与同步伤害、移动靶、完整单局、连续性能和139出生机位超时验证。整体保持 continue。

### stage155 — 西侧林缘、路肩与远山轮廓；环境实机复核（2026-09-14）
- 西侧树群由5株扩展至9株，成年树冠加宽并增加林下覆盖，同步树干碰撞；远山加入峰宽、侧峰和鞍部差异，路肩加入可变宽度与碎石色彩过渡。实机宽景和工坊接近机位中林缘更丰满，远山轮廓变化可辨；路肩收益较弱，草坡平行暗带、材质重复、建筑方块感及偏平光照仍明显，不视为整体达标。本轮建筑沿用已有改进并复核入口，不计作新建模成果。
- `artifacts/realism155-validation/review.html` 保存 stage154 原始存档→155 七组同机位对照，`baseline-origin.json` 说明基线来源，`visual-review.md` 保存实际审阅。各 after 目录的 `environment-camera-poses.json` 与 `comparison-checks.json` 记录位置、朝向及哈希；工坊入口(-42,0.05,44)、yaw=0、pitch=0.024994794，宽景(17,0.05,50)、yaw=0.422853926、pitch=0.067315195，眼高1.6。风动时间未同步，像素差不作画质评分。
- 16项导出包功能检查全部通过：九株树干角色阻挡、建筑通行、入口/屋顶碰撞、三武器108项瞄准、武器遮挡、网络状态规则及16角色单机冒烟。`verified/functional-results.json`、`verified/western-grove-collision.json` 保存结果；`verification-summary.json` 核验26项构建哈希、七组相机一致与三组截图进程成功，26份本轮日志无 ERROR/WARNING/FAIL/Error。网络规则不等于真实双客户端，冒烟不等于完整比赛；软件 Vulkan 不证明硬件性能，历史出生超时和退出泄漏未重测。
- 当前本地预览：`./artifacts/realism155-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，需图形桌面/Vulkan及相邻PCK；README.md、build.json 保存说明与构建依据。截图及功能验证均使用此导出包。保留全部未提交修改，未推送、发布或调整后台服务。
- 下一步优先定位草坡混合输出的平行暗带、改善材质尺度与车间顶棚亮斑，以正常机位复核；随后结合第三人称人物和第一人称手部动态实机审阅安排剩余缺陷。保留真实双客户端移动/伤害权威、完整单局、移动靶及持续性能验证。整体目标未完成，保持 continue。

### stage156 — 草坡底色与车间实体照明；最终包环境复核（2026-09-14）
- `client/shaders/meadow_ground.gdshader` 改用非正弦哈希与扰动噪声分配草坡覆盖底色；`client/scripts/world_visuals.gd` 将车间额外全向补光替换为四组有吊杆、灯壳的向下聚光灯。正常入口机位天花板亮斑减弱、光源可辨，草坡平行色带减少；细密网纹、重复草簇、方块道具和远山平淡仍明显，宽景收益有限，整体未达标。
- `artifacts/realism156-validation/review.html`、`visual-review.md` 保存七组同机位对照及实际审阅；基线为stage155存档，来源见 `baseline-origin.json`，风动时间未同步。`comparison-checks.json` 与各截图目录 `environment-camera-poses.json` 保存位置朝向；入口(-42,0.05,44)、yaw=0、pitch=0.024994794；宽景(17,0.05,50)、yaw=0.422853926、pitch=0.067315195，眼高1.6。包含入口、宽幅地形、眼平草坡与车间外侧实机图。
- 最终导出包16项检查通过，含建筑角色双向穿行、树干/货架/柱子/入口/屋顶碰撞、三武器108项瞄准、遮挡规则、网络状态规则及16角色单机冒烟。`verification-summary.json` 核验26项构建哈希、七组相机一致、三组截图进程成功，27份本轮日志无 ERROR/WARNING/FAIL/Error。首轮验证进程曾收到终止信号，原因未确定，保留原日志并补跑剩余项目；最终吊杆修正前启动的检查及截图已重跑。
- 本地预览：`./artifacts/realism156-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，需桌面/Vulkan及相邻PCK；README.md、build.json 保存说明与构建依据。保留所有未提交修改，未推送、发布或调整后台服务。
- 下一步处理近景地表细纹、植被重复和室外道具材质，继续正常机位实机复核；随后补第三人称人物、第一人称手部/换弹动态审阅。真实双客户端移动/伤害同步、完整单局、移动靶与持续性能仍待验证；网络规则和冒烟不代替这些测试，历史超时与退出泄漏尚未全面排除。整体保持 continue。

### stage157 — 储罐曲面与草丛斑块；通行回归修复（2026-09-14）
- `world_visuals.gd` 为服务储罐增加有碰撞的曲面封头和焊缝，并调整草地种类/高度的斑块分布；`workyard_tank.gdshader` 用噪声替换规则染色。正常工坊接近机位可辨认封头变化，草坡疏密略有改善；漆面仍偏白、地表细网纹、重复植被和建筑方块感仍明显。本轮未新增建筑主体或光照改动，不视为整体环境达标。
- `artifacts/realism157-validation/review.html`、`main-comparison.jpg`、`visual-review.md` 保存同机位前后对照及实际审阅；基线为stage156原始存档，风动时间未同步。七组相机位置/朝向见 `comparison-checks.json` 和各目录 `environment-camera-poses.json`。入口(-42,0.05,44)、yaw=0、pitch=0.024994794；宽景(17,0.05,50)、yaw=0.422853926、pitch=0.067315195，眼高1.6米；包含入口近景和宽幅地形实机图。
- 初版封头阻挡原x=-26草坡路线，失败证据保存在 `artifacts/realism157-initial-attempt/`。缩短罐体至4.6米、封头中心改为±2.3米后重新导出并复测；未放宽原草坡通行条件，另增加储罐两端曲面射线碰撞断言。
- 最终导出包16项功能检查全部通过，含建筑通行、草坡通行、储罐/树干/入口/屋顶碰撞、三武器108项瞄准、武器遮挡、网络状态规则及16角色单机冒烟。`artifacts/realism157-validation/verification-summary.json` 核验26项构建哈希、七组相机一致、三组截图进程成功；25份最终验证日志无 ERROR/WARNING/FAIL/Error。初版失败单独保留，不计入最终通过结果。
- 当前本地预览：`./artifacts/realism157-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，需桌面/Vulkan及相邻PCK；README.md与build.json保存说明和构建依据。全部未提交修改保留，未推送、发布或调整后台服务。
- 下一步优先解决地表细网纹、建筑入口大平面/方块感及正常机位光照层次，避免连续仅改小道具；再补第三人称人物、第一人称手部/换弹动态审阅。真实双客户端同步与伤害、完整单局、移动靶、持续性能、历史出生超时与退出泄漏仍待验证；网络规则和单机冒烟不能替代这些检查，整体保持 continue。

### stage158 — 车间窗框、草坡土壤覆盖与局部照明（2026-09-14）
- `world_visuals.gd` 增加车间窗带钢框，配合新增 `workshop_glass.gdshader` 积灰玻璃近似；降低雨棚自发光与雨棚/维修棚局部灯能量。`meadow_ground.gdshader` 将扫描土壤明度和不规则裸露区混入坡面覆盖，`project.godot` 尝试高质量全分辨率 SSAO。草坡由均匀橄榄绿变为更多灰褐土壤斑块，但细网纹仍在，窗带反射偏白，整体改善有限，不视为环境或整体目标达标。
- `artifacts/realism158-validation/review.html` 和 `visual-review.md` 保存七组正常机位前后对照与人工审阅，含建筑入口近景及宽幅地形。基线为stage157原始存档，风动时刻未同步。`comparison-checks.json` 和各目录 `environment-camera-poses.json` 记录相机；工坊入口(-42,0.05,44)，yaw=0、pitch=0.024994794；宽景(17,0.05,50)，yaw=0.422853926、pitch=0.067315195；眼高1.6米。
- 当前本地预览：`./artifacts/realism158-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，需图形桌面/Vulkan与相邻PCK；README.md、build.json 保存说明及源码/包哈希。全部未提交修改保留，未推送、发布或调整后台服务。
- 下一步校正窗带过亮并受控分离地表纹理、阴影、SSAO噪声来源，处理建筑轮廓与近景植被重复；再结合第三人称人物、第一人称手部/换弹实机审阅安排缺陷。真实双客户端同步/伤害、完整单局、移动靶与持续性能仍待验证，高质量SSAO成本也未评估；网络规则和单机冒烟不能替代实际联机及完整对局。整体保持 continue。
- 最终验证：导出包16项功能检查通过，含建筑双向通行、入口/屋顶碰撞、三武器108项瞄准、遮挡、网络状态规则及16角色单机冒烟；七组相机一致，三批实机截图成功，28项构建哈希匹配，29份本轮日志扫描无错误标记，见 `artifacts/realism158-validation/verification-summary.json`。两次验证进程退出143，原因未确定，原日志及 `interruption.json` 已保留；仅补跑未完成检查，最终全部通过，未将中断当作成功。


### Stage159（2026-09-14）：院区材质、植被与阴影；实际仓库穿门验证
- 降低横置储罐偏白漆面/金属反射并修正噪声和接缝坐标，减弱周期性波浪暗纹；厂房高窗改为更暗的玻璃，调整砾土纹理/法线尺度，罐旁以细草混少量宽叶提高密度，太阳 shadow_normal_bias 调整为 1.5。实机可见罐座与地面交界更清楚，但筒仓强条纹、规整树群/远山、盒状棚柱、重复货箱及手指体块仍未解决。
- 七组 stage158→159 同机位对照已人工审阅，含建筑入口近景、工作院、地表、敞棚和宽幅地形；位置/朝向、图片哈希见 `artifacts/realism159-validation/comparison-checks.json`，并排页 `review.html`，局限见 `visual-review.md`。Forward+ / 1280×800 / llvmpipe，非硬件 GPU 性能验证；before 为原有 stage158 截图，来源见 baseline-origin.json。
- 17 项独立功能进程退出 0 且有 PASS：原有 16 项场区通行/碰撞、瞄准、遮挡、联网规则和离线 smoke，加新增 `tests/warehouse_door_traversal_review.gd`。新增实际角色沿截图门洞 x=35，从 z=48 到 20.4532、z=20 到 47.54725 双向穿越；原 depot 的 x=23.5 路线不能替代此检查。证据在 `verified/functional-results.json` 和 `verified/warehouse-door-traversal.json`。规则测试不是双客户端实战，smoke 不是完整单机回合，瞄准射线不是移动射击伤害验证。
- 默认出生机位额外补拍失败：stage158 基线达到 420 秒超时（124），无图片，stage159 对应补拍未执行。保留 `spawn-capture-audit.json`、`spawn-run.log`、`before-spawn/capture.log`；不得声称出生朝向已验证或渲染问题已修复。22 份导出/捕获/功能日志无 ERROR/WARNING/FAIL/leak/orphan 文本，但不抵消此超时。汇总见 `verification-summary.json`。
- 当前本地预览：`artifacts/realism159-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`（需图形会话）；PCK 本轮重新导出，可执行文件沿用158；29 项文件哈希核对通过，见 preview/build.json 与 README.md。未推送、发布或改变服务，保留未提交修改。
- 下一步：先定位默认出生朝向采集超时；恢复三枪腰射/ADS/开火/完整换弹/切枪、第三人称走跑蹲/换弹的连续实机审阅并修正手臂握持，继续改善环境远景与明显模型缺陷；补真实联网、完整单机、移动瞄准和硬件性能验证。整体目标未完成，状态 continue。


### Stage160（2026-09-14）：远景地形、远林分布与筒仓材质过滤
- `world_visuals.gd` 调整山脊峰谷/沟槽与远林多尺度密度，维修棚拱架立柱增加钢腹板、翼缘与底板；`silo_galvanized.gdshader` 按屏幕导数过滤高频波纹，仓顶/加强圈取消错误波纹。照明沿用159，本轮未新增光照改善。筒仓细密条纹减弱，远山轮廓明显变化，但部分山峰过尖、近景主体基本未变；拱架细节常被门板遮挡，不能认为显眼的方块雨棚柱已解决。
- 七组 stage159→160 同机位实机对照已审阅：`artifacts/realism160-validation/review.html`、`visual-review.md`、`comparison-checks.json`，含建筑入口、草坡、筒仓和宽幅地形。before 复用159原始截图，风动时刻不同；各目录 `environment-camera-poses.json` 保存位置/朝向。宽景角色位置(17,0.05,50)、眼高1.6m、yaw=0.422853926、pitch=0.067315195；仓库入口(35,0.05,44)、yaw=0、pitch=0.024994794。截图为 Forward+ / 1280×800 / llvmpipe，不能证明硬件性能。
- 导出包17项功能进程全部退出0且有PASS，包括多建筑实际通行、入口/屋顶碰撞、三武器108项瞄准、遮挡、网络状态规则及16角色离线冒烟。仓库正门实际角色沿x=35从z=48到20.4532、z=20到47.54725双向通过；维修棚从z=38到24.24992、z=24到37.75008通过。见 `verified/functional-results.json`、`verified/warehouse-door-traversal.json` 及维修棚日志。规则检查不能替代真实联网，冒烟不能替代完整单局。
- `verification-summary.json` 核实3批捕获成功、7组相机一致、31项构建哈希一致，21份已完成日志无 ERROR/WARNING/FAIL/leak/orphan 文本。首次验证进程退出143、原因未确定，保留 `interrupted-run/audit.json` 和日志，补跑缺失检查后全部通过。默认出生朝向的159基线补拍仍在240秒超时(124)，未产生图片、未执行160对应补拍；见 `spawn-capture-audit.json`，不得声称已修复。
- 当前本地预览：`./artifacts/realism160-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，需图形会话及相邻PCK；包从当前源码导出，说明/哈希见 preview/README.md、build.json。保留所有未提交修改，未推送、发布或改变后台服务。
- 下一步：校正过尖远山，优先处理正常机位显眼的雨棚方柱、白亮窗带与重复近景植被，并定位默认出生机位采集超时；恢复第三人称走跑蹲及三枪腰射/ADS/开火/换弹/切枪连续实机审阅，修正手臂握持；补真实联网、完整单机、移动靶伤害与硬件性能验证。整体写实目标尚未完成，状态 continue。


### Stage161（2026-09-14）：车间入口构件、山脊平滑与草色照明
- 西车间增加黄黑防撞护角、导轨连接板/螺栓和门头泛水，入口近景能辨识；降低山脊高频尖峰与沟槽幅度，宽景轮廓明显缓和。草尖加入枯黄渐变、调整根部明暗，车间棚灯略提亮；后两项效果轻微，未改变植被布局，室内仍暗，不能视为整体画质完成。
- 七组 stage160→161 同机位实机对照已审阅，见 `artifacts/realism161-validation/review.html`、`visual-review.md`、`comparison-checks.json`。before 复用160原图并记录来源；入口近景和宽幅地形均有对照，各目录 `environment-camera-poses.json` 保存位置/朝向。宽景(17,0.05,50)、眼高1.6、yaw=0.422853926、pitch=0.067315195；车间入口(-42,0.05,44)、yaw=0、pitch=0.024994794。重复草簇、大片空地、维修棚方块结构及僵硬手臂仍突出，截图数量不代表画质达标。
- 当前导出包17项功能测试全部退出0且有PASS：多建筑实际角色通行、入口/屋顶碰撞、三枪108项瞄准对齐、武器遮挡、网络状态规则和16角色离线冒烟。仓库正门实际角色沿x=35从z=48到20.4532、从20到47.54725双向通过，西车间与维修棚通行亦通过；见 `verified/functional-results.json` 和对应日志。规则/冒烟不能替代真实联机、完整单局与移动靶伤害验证。
- `verification-summary.json` 核实3批捕获成功、7组相机一致、32项构建哈希一致，21份已完成日志无 ERROR/WARNING/FAIL/leak/orphan 文本。默认出生机位160基线诊断240秒超时(124)，停在27716ms首次 process_frame 等待开始，未到 force_draw/get_image/save_png；无PNG，原因未确定，未完成161出生机位补拍。证据见 `spawn-capture-audit.json`、`before-spawn/capture.log`，不宣称修复。
- 本地预览：`./artifacts/realism161-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，需图形会话及相邻PCK；说明和哈希见 preview/README.md、build.json。实机截图使用Forward+ / llvmpipe，不代表硬件GPU性能。保留未提交修改，未推送、发布或改变后台服务。
- 下一步：恢复当前包三枪腰射/ADS/开火/完整换弹/切枪及第三人称走跑蹲连续实机审阅，继续处理近景植被布局、维修棚结构与空地；定位出生帧等待，补真实联网、完整单机、移动靶伤害与硬件性能。整体目标未完成，状态 continue。

### Stage162（2026-09-14）：工区储罐检修设施与路缘植被
- `world_visuals.gd` 为西车间工区储罐增加圆形人孔、检修梯、管路法兰/阀轮及支座底板，调整附近柜体位置；三个圆形草岛改为起伏、有缺口的路缘草带。正常接近机位能辨识梯子和罐顶构件，管路部分被遮挡；本轮未修改建筑主体或照明，不将继承的入口与光照效果算作新增改善。
- 七组 stage161→162 同机位实机对照见 `artifacts/realism162-validation/review.html`、`visual-review.md`、`comparison-checks.json`。before 复用161原图，来源见 `baseline-origin.json`；入口近景及宽幅地形均已审阅，位置/朝向记录于各目录 `environment-camera-poses.json`。接近机位(-17,0.05,49)、眼高1.6m、yaw=1.030376827、pitch=0.073611147；宽景(17,0.05,50)、yaw=0.422853926、pitch=0.067315195。平圆盘罐端、等尺寸混凝土管、方块棚柱、重复植被和大片均匀裸土仍明显，本轮改动不代表整体环境画质达标。
- 当前导出包17项独立检查全部退出0且PASS，包括工区道路/储罐碰撞、多建筑实际角色通行、入口/屋顶碰撞、三枪108项瞄准对齐、武器遮挡、网络状态规则及离线冒烟。仓库当前正门沿x=35从z=48到20.4532、从20到47.54725双向通过；旧depot路线x=23.5不作为正门验证。证据见 `verified/functional-results.json`、`verified/warehouse-door-traversal.json` 和对应日志。规则测试、冒烟与对齐检查分别不能替代真实联机、完整单局及移动靶伤害。
- `verification-summary.json` 核实3批捕获成功、7组相机一致、32项构建哈希一致；21份已完成日志未发现 ERROR/WARNING/FAIL/leak/orphan 文本。stage161默认出生机位采集超时本轮未复测，仍未解决；三枪及第三人称连续动作、手臂袖管问题仍待审阅。截图使用Forward+ / llvmpipe，不能证明硬件GPU性能。
- 本地预览：`./artifacts/realism162-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，需图形会话及相邻PCK；本轮从当前工作树导出并用于上述捕获/验证，说明与哈希见 preview/README.md、build.json。保留所有未提交修改，未推送、发布或改变后台服务。
- 下一步：定位默认出生帧等待超时；继续针对正常机位显眼的棚柱/暗平门梁、重复混凝土管与裸土地表做成组环境改进，并恢复第三人称走跑蹲及三枪腰射/ADS/开火/完整换弹/切枪连续实机审阅；补真实联网、完整单机、移动靶伤害与硬件性能。整体目标未完成，状态 continue。


### Stage163（2026-09-14）：车间折边雨檐、近侧草带与储罐受光响应
- 西车间入口增加折边雨檐及支撑，工区近侧新增分簇草带；调整水平储罐漆色、粗糙度和反射，使受光侧更清楚。本轮没有调整全局光照。正常机位可辨识入口与植被变化，但近处叶片偏大且交叠成片，储罐仍偏均匀塑料质感，宽景裸地、重复管件和方盒建筑尚未解决。
- 同机位 stage162→163 对照、入口近景及宽幅地形见 `artifacts/realism163-validation/review.html`、`visual-review.md`、`comparison-checks.json`。before 复用162原图，来源见 `baseline-origin.json`；各截图目录 `environment-camera-poses.json` 保存位置/朝向。接近机位(-17,0.05,49)、yaw=1.030376827、pitch=0.073611147；宽景(17,0.05,50)、yaw=0.422853926、pitch=0.067315195。截图固定机位并暂停逻辑，通行另行实测，不以截图数量判定画质。
- 当前导出包17项检查退出0且PASS：多建筑实际角色通行、工区/入口/屋顶碰撞、三枪108项瞄准对齐、武器遮挡、网络状态规则及离线冒烟。仓库当前正门x=35从z=48到20.4532、从20到47.54725双向通过；西车间x=-42双向通过，柱子/货架/墙面碰撞通过。新增雨檐是高处无碰撞装饰，不将原有屋顶检查当作新增雨檐弹道验证。证据见 `verified/functional-results.json` 及各测试日志。
- 首次验证完成7项后退出143，原因未确定；保留 `interrupted-roadside.log`、`runner-interruption.json`，续跑复用成功结果并重跑未完成项。最终 `verification-summary.json` 核实17项通过、3批捕获、7组相机一致、32项构建哈希一致，21份已完成日志无 ERROR/WARNING/FAIL/leak/orphan 文本。stage161默认出生机位超时未重测、未解决。软件Vulkan/llvmpipe不能证明硬件性能，新增620个植被节点仍需性能分析。
- 本地预览：`./artifacts/realism163-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，需图形会话及相邻PCK，见 preview/README.md、build.json。本包用于上述实机截图和测试；保留未提交修改，未推送或发布。
- 下一步：优先修正近景草叶形态/密度、裸土地表层次与建筑阴影可读性，定位默认出生帧等待；恢复第三人称走跑蹲及三枪腰射/ADS/开火/完整换弹/切枪实机审阅，处理手臂袖管。补真实双客户端联网、完整单局、移动靶伤害和硬件性能；规则测试与冒烟不能替代这些验证。整体写实目标尚未完成，状态 continue。

### Stage164（2026-09-14）：维修棚支撑、入口草叶与局部灯位
- 维修棚新增可辨识的檩条、前沿梁、连接立柱的斜撑及柱脚连接件，收薄雨槽并增加屋面板缝材质；缩小、疏开入口阔叶草，移动入口灯具和光源并降低能量。正常入口机位能看清棚底结构和草叶体量变化；屋面板缝在低视角较弱，白天截图不足以证明全局光照提升。中间斜撑方向错误已修正并重新导出、从头验证，中止版本仅保留于 draft-superseded，不计入最终结果。
- 同机位 stage163→164 对照、入口近景和宽幅地形见 `artifacts/realism164-validation/review.html`、`visual-review.md`。before 复用163原图并记录来源；七组位置与朝向一致，见 `comparison-checks.json` 和各目录 `environment-camera-poses.json`。维修棚 actor=(15.5,0.05,39)、眼高1.6、yaw=0、pitch=0.054113782；宽景 actor=(17,0.05,50)、yaw=0.422853926、pitch=0.067315195。大片均匀裸地、重复植被、无倒角棚柱、粗糙墙面污渍及细长袖管仍明显，整体画质未达标。
- 当前导出包17项检查全部退出0且PASS，涵盖建筑实际角色通行、入口/屋顶碰撞、三枪108项瞄准对齐、武器遮挡、网络状态规则及离线冒烟。维修棚中央双向通行及门板/立柱/屋面射线通过；仓库正门x=35从z=48到20.4532、从20到47.54725双向通过。新增支撑为装饰网格，不将原有碰撞检查作为新增构件弹道验证。日志与结果见 `verified/functional-results.json`。
- `verification-summary.json` 核实3批捕获、7组同机位、33项构建哈希，21份已完成日志未发现 ERROR/WARNING/FAIL/leak/orphan 文本。截图暂停逻辑，通行独立实测；软件Vulkan不能证明硬件性能。stage161默认出生帧等待超时仍未解决；本轮未执行真实联网、完整单局、移动靶伤害及三枪/第三人称连续动作审阅。
- 本地预览：`./artifacts/realism164-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，需图形会话及相邻PCK，说明与哈希见 preview/README.md、build.json。本包已用于上述实机截图及测试。保留全部未提交修改，未推送、发布或修改后台服务。
- 下一步：处理宽景裸地的连续材质层次、重复草簇和建筑阴影，避免只堆入口小构件；定位默认出生帧等待，并恢复第三人称走跑蹲、三枪腰射/ADS/开火/完整换弹/切枪的连续实机审阅，修正手臂袖管。补真实双客户端联网、完整单局、移动靶伤害和硬件性能验证。整体目标未完成，状态 continue。

### Stage165（2026-09-14）：地表沉积色差与维修棚低矮草丛
- 修改 meadow_ground、service_ground 着色器，加入沉积、局部暗湿色差与边缘碎屑混合；维修棚两侧草株合计128→192，扩大横向轮廓并降低高度。太阳阴影 normal bias 1.5→0.9，Forward+ 环境光能量0.32→0.24；天空环境光下建筑受光实际变化很小，不以参数变化宣称明显光照提升。本轮没有新增建筑几何，不将stage164支撑构件计作成果。首次较弱草稿隔离于 draft-superseded，最终重新导出并完整验证。
- 七组stage164→165同机位实机前后对照、入口近景及宽幅地形见 `artifacts/realism165-validation/review.html`、`visual-review.md`；baseline-origin.json记录原图来源，comparison-checks.json及各目录environment-camera-poses.json记录并核对位置与朝向。维修棚 actor=(15.5,0.05,39)、眼高1.6、yaw=0、pitch=0.054113782；宽景 actor=(17,0.05,50)、yaw=0.422853926、pitch=0.067315195。人工审阅可辨认入口草丛变矮变密，但宽景裸地仍空旷、放射状草株重复、建筑明暗偏平，整体画质未达标。
- 当前导出包17项检查全部退出0且PASS，覆盖设施实际角色通行、入口/屋顶碰撞、三枪108项瞄准对齐、武器遮挡、网络状态规则及离线冒烟。仓库正门x=35双向实测z=48→20.4532、20→47.54725；维修棚及工坊通行通过。原始日志和结果见 `verified/functional-results.json`，这些检查不等于完整单机对局、真实双客户端联网或移动靶伤害验证。
- `verification-summary.json`核实3批截图捕获、7组同机位、33项构建哈希；21份已完成日志未发现ERROR/WARNING/FAIL/leak/orphan文本。固定机位截图不证明默认出生点正常：stage161出生帧等待超时未解决，本轮未重跑。软件Vulkan截图不证明硬件帧率，新增植被性能尚待硬件验证。
- 本地预览：`./artifacts/realism165-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，需图形会话和相邻PCK；README.md、build.json提供说明及哈希。本包已用于本轮截图和测试。保留全部未提交修改，未推送、发布或修改后台服务。
- 下一步：继续优先处理宽景裸地过渡、重复草簇与建筑受光，并定位默认出生帧等待；恢复第三人称走跑蹲和三枪腰射/ADS/开火/完整换弹/切枪连续实机审阅，修正细长折面袖管。补完整单机、真实双客户端联机、移动靶伤害与硬件性能验证。整体目标未完成，状态continue。

### Stage166（2026-09-14）：西工坊雨棚结构与地表碎石沉积
- 西工坊雨棚增加板缝、底部加强条和随倾角旋转的实体碰撞；调整 meadow_ground、service_ground 的碎石沉积与暗车辙混合。入口板面结构与宽景浅色碎石块已可辨识，但地形仍平、草簇重复、建筑光照偏平。本轮未新增植被或调整光照，不宣称整体环境目标完成。
- stage165→166七组同机位实机对照见 `artifacts/realism166-validation/review.html`，人工审阅及局限见 `visual-review.md`。入口近景 `after/west-workshop-entrance.png`：actor=(-42,0.05,44)、眼高1.6、yaw=0、pitch=0.024994794；宽景 `after/terrain-wide.png`：actor=(17,0.05,50)、yaw=0.422853926、pitch=0.067315195。各捕获目录 environment-camera-poses.json 与 comparison-checks.json 记录并核对相机；基线是stage165保存图，非本轮重新拍摄。
- 当前包17项检查全部退出0且PASS，含实际角色建筑通行、入口/屋顶碰撞、三枪108项瞄准对齐、武器遮挡、网络状态规则和离线冒烟。工坊雨棚新增10条上下短射线全部命中指定本体且距离通过，避免旧屋顶导致假通过；真实角色双向通行、立柱及货架阻挡通过，见 `verified/west-workshop-traversal.json`。仓库正门双向通行通过。完整结果见 `verified/functional-results.json`。
- `verification-summary.json`核实3批捕获、7组同机位、33项构建哈希，21份完成日志未发现ERROR/WARNING/FAIL/leak/orphan文本。首次验证进程退出143，原因未确认，保留 interruption-note.json 后恢复并完成检查。默认出生帧等待超时仍未解决，固定机位不替代正常开局；尚未验证完整单局、真实双客户端联网、移动靶伤害及三枪/第三人称连续动作，软件Vulkan不证明硬件性能。
- 本地预览：`./artifacts/realism166-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，需图形会话与相邻PCK，说明及构建哈希见 README.md、build.json。本包用于上述截图和测试；保留全部未提交修改，未推送、发布或修改后台服务。
- 下一步：增加裸地与植被过渡的实际体积、减少草株重复并改善建筑明暗层次，定位默认出生等待；随后结合第三人称与第一人称连续动作审阅修正人物、长前臂及折面袖管，补完整单机和真实联机验证。整体目标未完成，状态continue。

### Stage167（2026-09-14）：维修棚钢构风化、入口沉积与低矮植被
- 新增 shelter_structural_steel 着色器，为维修棚门框、雨棚梁柱及排水构件加入灰绿色褪色、轻微雨痕和底部锈色；降低入口混凝土地表颗粒对比、扩大沉积与车辙过渡。两侧植被192→328株，提高阔叶比例并降低草株高度；新增低能量局部补光。实机近景可辨识钢构与植被变化，但棚体仍方硬、草叶重复、宽景裸地空旷且整体光照偏平；不宣称整体画质达标。
- stage166→167七组同机位对照见 `artifacts/realism167-validation/review.html`，逐图人工审阅见 `visual-review.md`。维修棚入口 `after-shelter/repair-shelter-entrance.png`：actor=(15.5,0.05,39)、眼高1.6、yaw=0、pitch=0.054113782；宽景 `after/terrain-wide.png`：actor=(17,0.05,50)、yaw=0.422853926、pitch=0.067315195。各捕获目录 environment-camera-poses.json 及 comparison-checks.json 核对位置与朝向；baseline-origin.json 记录stage166保存图来源，基线非本轮重拍。被替代草稿单独保存于 draft-superseded，最终包重新导出并验证。
- 当前包17项检查全部退出0且PASS，覆盖实际角色建筑通行、入口/屋顶碰撞、三枪108项瞄准对齐、武器遮挡、网络状态规则及离线冒烟。维修棚双向实测z=38→24.24992、24→37.75008，中心通道畅通、门侧及立柱阻挡通过；仓库正门和其他设施通行通过。证据见 `verified/functional-results.json`、`verified/repair-shelter-traversal.json`。
- `verification-summary.json`核实3批捕获、7组同机位、34项构建哈希，21份完成日志无ERROR/WARNING/FAIL/leak/orphan文本。固定机位截图不替代正常开局：stage161默认出生帧等待超时仍未解决，本轮未重跑；完整单局、真实双客户端联网、移动靶伤害、三枪和第三人称连续动作尚未完成验证。软件Vulkan不证明硬件性能。
- 本地预览：`./artifacts/realism167-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，需图形会话及相邻PCK；README.md、build.json提供说明及哈希。本包已用于上述截图和测试。保留全部未提交修改，未推送、发布或修改后台服务。
- 下一步：优先定位默认出生截图停滞，继续改善宽景裸地植被过渡、重复草簇及建筑阴影；结合第三人称与三枪连续动作审阅修正细长前臂和折面袖管，补完整单机、真实联机及移动靶验证。整体目标未完成，状态continue。

### Stage168（2026-09-14）：维修棚排水构造、接近区低草与环境光
- 维修棚前沿新增成对雨水管、弯头与管卡；以地面(19,45)为中心提高低草连续覆盖、降低并加宽细草，同时调整环境光、SSAO和太阳角直径。入口近景能辨识排水构造，宽景草带略连片；改善有限，大块裸地、重复草叶、简化远山和平淡室内光照仍明显，不能视为整体画质达标。排水管为装饰网格，不声称新增管体碰撞。
- stage167→168七组同机位对照及逐图审阅：`artifacts/realism168-validation/review.html`、`visual-review.md`。入口图 `after-shelter/repair-shelter-entrance.png`：actor=(15.5,0.05,39)、眼高1.6、yaw=0、pitch=0.054113782；宽景 `after/terrain-wide.png`：actor=(17,0.05,50)、yaw=0.422853926、pitch=0.067315195。完整相机位置与朝向见各目录 environment-camera-poses.json；comparison-checks.json 检查一致性，baseline-origin.json 说明基线复制自stage167，非本轮重拍。
- 当前导出包17项检查全部退出0且PASS，包括真实角色建筑通行、入口/屋顶碰撞、三枪108项瞄准对齐、武器遮挡、联网状态规则和离线冒烟。维修棚实测双向z=38→24.24992、24→37.75008，门侧阻挡与旁路通行通过；见 `verified/functional-results.json`、`verified/repair-shelter-traversal.json`。`verification-summary.json`核实3批捕获、7组同机位、34项构建哈希，21份完成日志无ERROR/WARNING/FAIL/leak/orphan文本。规则测试与冒烟不等同于真实联机和完整单局。
- 纠正历史记录：`tests/environment_spawn_review_capture.gd`会把角色手动移至(17,0.05,50)，其stage161捕获超时不能直接判定为真实默认出生点故障。本轮未重跑该诊断；真实默认出生视觉仍待验证。固定截图不替代正常行走或完整比赛。
- 本地预览：`./artifacts/realism168-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，需图形会话与相邻PCK；README.md及build.json提供说明和构建哈希。软件Vulkan不证明硬件性能。保留全部未提交修改，未推送、发布或修改后台服务。
- 下一步：从真实默认出生和正常行走机位改善道路—裸土—草坡的大尺度过渡，减少重复草叶；结合第三人称行走/跑步/蹲伏及第一人称三枪连续动作审阅修正细长前臂、折面袖管。补移动靶伤害、完整单机及真实双客户端联机验证。整体目标未完成，状态continue。

### Stage169（2026-09-14）：维修棚工作区、车辙材质与路径低草
- 维修棚右侧工作台增加四腿与下层搁板，移除重叠旧台面，增加侧置暖光；地表采用旋转的第二层土壤采样、降低车辙暗部并加入横向变化，棚外路径补稀疏低草。入口能辨识台面和底部结构，宽景车辙黑条有所减弱；棚内仍平淡，重复阔叶草、大块裸地、简化远山及细长左前臂仍明显，整体画质目标未完成。
- stage168→169七组同机位实机对照与逐图审阅：`artifacts/realism169-validation/review.html`、`visual-review.md`。入口 `after-shelter/repair-shelter-entrance.png`：actor=(15.5,0.05,39)、眼高1.6、yaw=0、pitch=0.054113782；宽景 `after/terrain-wide.png`：actor=(17,0.05,50)、yaw=0.422853926、pitch=0.067315195。完整相机记录见各目录 environment-camera-poses.json；before来自stage168留存截图，非本轮重拍，来源见baseline-origin.json。
- 最终导出包17项检查全部退出0且PASS，包括实际角色建筑通行、入口/屋顶碰撞、三枪108项瞄准、遮挡规则、联网状态规则及离线冒烟。维修棚双向z=38→24.24992、24→37.75008；中心向下射线无工作台碰撞，右侧台面高度0.975，木板阻挡及旁路通行通过。见 `verified/functional-results.json`、`verified/repair-shelter-traversal.json`。首次重叠台面的中止结果仅留在superseded-overlapping-bench，不作为最终证据。
- `verification-summary.json`核实3批捕获、7组同机位和34项构建哈希，21份完成日志未匹配ERROR/WARNING/FAIL/leak/orphan。联网规则不等于真实联机、离线冒烟不等于完整单局、固定截图不等于默认出生或连续行走验证；软件Vulkan不证明硬件GPU性能。
- 本地预览：`./artifacts/realism169-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，需图形会话及相邻PCK，README.md和build.json提供说明与哈希。上述截图和测试使用该包；保留全部未提交修改，未推送或发布，未修改后台服务。
- 下一步：从真实默认出生点连续行走至维修棚和草坡，改善植被复制、地表尺度及远山轮廓；结合第三人称行走/跑步/蹲伏和第一人称三枪动作审阅处理前臂比例、折面袖管。补移动靶伤害、完整单机与真实双客户端联机验证。状态continue。

### Stage170（2026-09-14）：维修棚透光高窗、草簇尺度与真实默认出生审阅
- 高窗增加透明度与实体窗格，抬高并增强棚内冷色补光；减少大阔叶草比例和尺寸。入口及宽景可辨玻璃后的屋顶结构，部分大草簇变为细草；室内亮度改善有限，宽直道路、大块裸地、重复树群与折面远山仍明显，不视为整体画质达标。补光为手工光源，装饰窗格未新增碰撞。
- stage169→170七组同机位实机对照与逐图审阅：`artifacts/realism170-validation/review.html`、`visual-review.md`。入口 `after-shelter/repair-shelter-entrance.png`：actor=(15.5,0.05,39)、眼高1.6、yaw=0、pitch=0.054113782；宽景 `after/terrain-wide.png`：actor=(17,0.05,50)、yaw=0.422853926、pitch=0.067315195。各目录 environment-camera-poses.json 保存完整机位；baseline-origin.json 明确before复制自stage169，非本轮重拍。
- 新增真实默认出生检查：start_solo后未传送，从(0,1,90)、yaw=0、pitch=0，经120次真实角色前行至(0,0.000845,78.999939)，正常落地并前进约11米。见 `default-spawn/` 下两张截图、camera-and-movement.json、capture.log及result.json。比赛模拟关闭、输入由脚本驱动，不等同于完整单局。历史stage161超时发生在手动传送的固定环境机位，不能作为默认出生故障证据。
- 当前导出包17项回归全部退出0且PASS：建筑通行、入口/屋顶碰撞、三枪108项瞄准、武器遮挡、联网状态规则及离线冒烟。维修棚实际角色双向z=38→24.24992、24→37.75008，门侧与玻璃阻挡、旁路通过；见 `verified/functional-results.json` 与 `verified/repair-shelter-traversal.json`。`verification-summary.json`核实3批捕获、7组同机位、34项构建哈希和默认出生检查，22份完成日志未匹配ERROR/WARNING/FAIL/leak/orphan。规则与冒烟不替代真实联机和完整单局。
- 本地预览：`./artifacts/realism170-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，需图形会话及相邻PCK；README.md和build.json提供说明与构建哈希。保留全部未提交修改，未推送、发布或修改后台服务。
- 下一步：以真实默认道路行走机位为主改善路肩、裸土与草坡的大尺度过渡及远景树群轮廓，避免继续只改维修棚局部；结合第三人称行走/跑步/蹲伏与第一人称三枪连续动作审阅处理细长前臂、折面袖管。补移动靶伤害、完整单机与真实双客户端联机验证；软件Vulkan截图不证明硬件性能。整体目标未完成，状态continue。

### Stage171（2026-09-14）：道路碎石肩、低矮草带与环境光回归
- 道路和草地shader统一世界坐标侵蚀边沿与碎石过渡；路边草退让距离加入变化，并降低、加宽草簇。Forward+环境光0.34→0.30、SSAO半径0.85→1.1。默认出生及前行机位可见沥青与泥土硬直边界减弱；草坡变化有限，建筑光照差异较小。本轮未改建筑几何，宽直空路、重复针叶树和棱角远山仍明显，整体目标未完成。
- 实机对照和逐图审阅：`artifacts/realism171-validation/review.html`、`visual-review.md`。七组环境before复制自stage170，来源见baseline-origin.json；after包含工坊/仓库/维修棚入口及terrain-wide。完整位置与朝向见各after目录environment-camera-poses.json；宽景actor=(17,0.05,50)、yaw=0.422853926、pitch=0.067315195；工坊入口actor=(-42,0.05,44)、yaw=0、pitch=0.024994794，眼高1.6。
- 默认出生与120步前行截图见`default-spawn/`，实际角色从(0,1,90)前进至(0,0.000845,78.999939)，yaw/pitch=0；未传送、使用真实移动碰撞，比赛模拟关闭。两组默认机位与stage170的位置/朝向/移动结果一致，见spawn-comparison-checks.json；不等同完整单局。
- 当前预览包17项回归全部退出0且PASS，覆盖建筑双向通行、入口/屋顶碰撞、三枪108项瞄准、武器遮挡、网络状态规则和离线冒烟。见`verified/functional-results.json`；`verification-summary.json`核实3批捕获、7组环境同机位、2组默认同机位、35项构建哈希，22份完成日志未匹配ERROR/WARNING/FAIL/leak/orphan。规则不替代真实联机，瞄准对齐不替代移动靶伤害，软件Vulkan不证明硬件性能。
- 本地预览：`./artifacts/realism171-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，需图形会话及相邻PCK；README.md、build.json提供说明和哈希。本轮截图与检查使用该包，保留全部未提交修改，未推送或发布。
- 下一步：继续从正常道路机位处理空旷构图、建筑入口及立面的空间层次、远景树群轮廓，避免仅调整小材质参数。随后结合第三人称走/跑/蹲与第一人称三枪连续动作审阅处理细长前臂、折面袖管；补移动靶伤害、完整单机和真实双客户端联机。状态continue。

### Stage172（2026-09-14）：默认出生道路雨棚、近景植被与结构投影
- 道路左侧(-12,0,65)新增可穿行坡顶雨棚：薄钢屋面、I形立柱、横梁、半高砖墙与百叶；两侧增加六株不同尺度树木及低草。默认出生及前行机位明显增加近景建筑层次，入口可见百叶与树木投影；本轮未调整全局光源。钢材颗粒感、宽直空路、重复树形、平坦裸地和折面远山仍明显，宽幅地形机位没有明显新收益，整体目标未完成。
- 实机前后对照及逐图审阅：`artifacts/realism172-validation/review.html`、`visual-review.md`。八组环境机位一致，新入口before用stage171包重拍，其余before继承stage171原图，见baseline-origin.json。入口`after-entry/arrival-canopy-entrance.png`：actor=(-12,0.05,76)、眼高1.6、yaw=0、pitch=0.029158402；宽幅`after/terrain-wide.png`：actor=(17,0.05,50)、yaw=0.422853926、pitch=0.067315195。完整机位保存于各目录environment-camera-poses.json。
- 默认出生和120步前行两组截图见`default-spawn/`：实际角色从(0,1,90)至(0,0.000844786,78.999938965)，yaw/pitch=0，与stage171机位及移动结果一致。未传送、比赛模拟关闭，不等同完整单局。新增雨棚真实角色双向z=73→56.49991、57→73.50009，主路z=80→63.49991；墙、屋顶、柱碰撞射线命中，中央通道畅通，见`verified/arrival-canopy-traversal.json`。
- 当前包18项回归全部退出0且PASS，覆盖建筑通行与碰撞、三枪108项瞄准、武器遮挡、网络状态规则及离线冒烟。`verification-summary.json`核实5批捕获、8组环境及2组默认同机位、36项构建哈希；25份完成日志未匹配ERROR/WARNING/FAIL/leak/orphan。规则不替代真实双客户端联机，瞄准不替代移动靶伤害，冒烟不替代完整单局，软件Vulkan截图不证明硬件性能。
- 本地预览：`./artifacts/realism172-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，需图形会话及相邻PCK；README.md和build.json提供说明与哈希。截图及回归使用当前导出包，全部未提交修改保留，未推送或发布。
- 下一步：继续改善正常道路机位的大尺度构图、重复树群和远山轮廓；结合第三人称走/跑/蹲及第一人称三枪连续动作审阅处理细长前臂、折面袖管，补移动靶伤害、完整单机和真实双客户端联机。不要再仅调整小材质参数或将局部改善视为整体达标。状态continue。

### Stage173（2026-09-14）：雨棚结构、道路修补与近树轮廓
- 道路雨棚新增屋顶纵向支撑、檐边和排水槽/落水管；道路着色器增加不同尺寸的暗色修补块，六株近树分别变化冠幅和高度。正常出生道路及入口机位可辨识局部变化；未调整全局光源，结构遮挡不能替代全局光照改进。宽幅地形基本无收益，空旷道路、规则矩形补丁、稀疏树冠、钢材噪点与折面远山仍明显，整体目标未完成。
- 实机前后对照：`artifacts/realism173-validation/review.html`、`visual-review.md`。八组环境相机位置/朝向一致；入口before使用stage172包重拍，其余来源见baseline-origin.json。入口`after-entry/arrival-canopy-entrance.png`：actor=(-12,0.05,76)、眼高1.6、yaw=0、pitch=0.029158402；宽幅`after/terrain-wide.png`：actor=(17,0.05,50)、yaw=0.422853926、pitch=0.067315195。
- 默认出生与前行对照在`default-spawn/`：角色从(0,1,90)移动120步至(0,0.000844786,78.999938965)，yaw/pitch=0，与stage172一致。雨棚双向真实角色通行、道路移动及墙/柱/顶碰撞通过，中央通道畅通，见`verified/arrival-canopy-traversal.json`。上述角色测试关闭比赛模拟，不代表完整单局。
- 当前包18项回归退出0且PASS，覆盖建筑通行/碰撞、三枪108项瞄准、武器遮挡、网络状态规则和离线冒烟。`artifacts/realism173-validation/verification-summary.json`核实5批截图捕获、8组环境同机位、36项构建哈希；26份日志未匹配ERROR/WARNING/FAIL/leak/orphan。验证进程曾退出143，原因未确定，随后补跑剩余检查并正常退出0；未将中断当作通过。网络规则不替代真实双客户端联机，冒烟不替代完整单局，软件Vulkan截图不证明硬件性能。
- 本地预览：`./artifacts/realism173-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，需图形会话及相邻PCK。README.md、build.json提供说明和哈希；保留全部未提交修改，未推送或发布。
- 下一步：优先处理正常道路的大尺度空旷构图、树冠实体轮廓、地面/远山过渡，并比较全局光照；避免继续只加附属细节。保留第三人称动作与第一人称三枪连续动作审阅、细长前臂/折面袖管修正、移动靶伤害、完整单机和真实双客户端联机验收。状态continue。


### Stage174（2026-09-14）：重建针叶树冠、弱化路面补丁与建筑阴影调整
- Blender 重建针叶树GLB及远景贴图，扩大叶簇和针叶覆盖；降低道路修补块与封边反差、扰动边缘；太阳shadow_normal_bias从0.9降至0.35、angular_distance从1.1降至0.8。正常出生、建筑入口和宽幅机位的近中景树冠明显更完整。没有新增建筑几何，阴影变化有限，梁柱白色噪点仍存在；重复树形、规则草丛、空旷道路与折面远山未解决，不视为整体达标。
- 实机审阅与八组同机位前后对照：`artifacts/realism174-validation/review.html`、`visual-review.md`、`comparison-checks.json`。arrival入口before使用stage173包重拍，其余来源见baseline-origin.json。入口`after-entry/arrival-canopy-entrance.png`：actor=(-12,0.05,76)、眼高1.6、yaw=0、pitch=0.029158402；宽幅`after/terrain-wide.png`：actor=(17,0.05,50)、yaw=0.422853926、pitch=0.067315195。各截图目录environment-camera-poses.json保存完整精度。
- 默认出生与120步前行实机截图见`default-spawn/`及spawn-contact.png：角色从(0,1,90)至(0,0.000844786,78.999938965)，yaw/pitch=0，与stage173位置、朝向和移动结果一致。雨棚、维修棚等建筑双向角色通行与碰撞通过，仓库门双向z=48→20.453、20→47.547；见`verified/functional-results.json`和相应通行日志。比赛模拟关闭，不代表完整单局。
- 当前导出包18项回归均退出0且PASS，覆盖建筑通行/碰撞、三枪108项瞄准、武器遮挡、联网状态规则和离线冒烟。`verification-summary.json`核实5批捕获、8组环境及默认出生/前行同机位、40项构建哈希；24份运行日志未匹配ERROR/WARNING/FAIL/leak/orphan。导入存在dummy renderer texture_2d_get null错误，见import.log；Forward+实机加载成功，导出完成。未测硬件性能，增加针叶的性能开销待评估。
- 本地预览：`./artifacts/realism174-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，需图形会话及相邻PCK；README.md、build.json提供说明与哈希。全部未提交修改保留，未推送、发布或修改后台服务。
- 下一步：从默认道路连续行走机位改善大尺度空旷构图、地形植被过渡和建筑梁柱阴影，避免继续仅调小参数；结合第三人称走/跑/蹲与第一人称三枪动作处理细长前臂及折面袖管。补移动靶伤害、完整单机与真实双客户端联机，规则/冒烟不能替代这些验收。整体目标未完成，状态continue。

### Stage175（2026-09-14）：默认道路维修雨棚工作区、局部草丛与灯具
- 在正常出生/前行可见的雨棚增加三跨压肋钢板工作墙及上部采光口、入口标识、工作台货箱、两条暖色顶灯与短缘石，并在道路外侧补四组共168株草。入口从空棚变成可辨识维修工作区；入口和出生视角改善明确，白天补光较弱。宽幅场景基本未变，重复树形、空旷道路、折面远山、钢梁噪点及细长前臂仍未解决，整体目标未完成。
- 实机前后对照及审阅：`artifacts/realism175-validation/review.html`、`visual-review.md`、`comparison-checks.json`。8组环境机位与stage174一致，来源见baseline-origin.json。入口`after-entry/arrival-canopy-entrance.png`：actor=(-12,0.05,76)、眼高1.6、yaw=0、pitch=0.029158402；宽幅`after/terrain-wide.png`：actor=(17,0.05,50)、yaw=0.422853926、pitch=0.067315195。各目录environment-camera-poses.json保存完整精度。
- 默认出生及120物理步前行截图/记录见`default-spawn/`，角色从(0,1,90)至(0,0.000844786,78.999938965)，yaw/pitch=0，与stage174一致。雨棚实际角色双向通行z=73→56.49991、57→73.50009，主路z=80→63.49991通过；新增工作墙、工作台、采光口及既有屋顶/柱碰撞通过，详见`verified/arrival-canopy-traversal.json`。比赛模拟关闭，不代表完整单局。
- 当前导出包18项回归退出0且PASS，覆盖建筑通行/碰撞、三枪108项瞄准、武器遮挡、联网状态规则和离线冒烟。`verification-summary.json`核实5批捕获、8组环境与出生移动同机位、40项构建哈希；24份接受的运行日志无匹配ERROR/WARNING/FAIL/leak/orphan。首次采光口探针误打既有柱，移到真实开口z=66后复测通过；首次出生截图进程XCB断言并超时，重试退出0。原失败保留在verified/initial-*及initial-default-spawn，不计为通过。
- 本地预览：`./artifacts/realism175-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，需图形会话及相邻PCK；README.md与build.json提供说明和哈希。直接导出成功，见export.log，本阶段未独立执行导入。保留未提交修改，未推送或发布。
- 下一步：优先从默认道路连续机位改善道路空旷构图、植被到远山的过渡与全局光照，避免继续只加局部附件；再结合第三人称走/跑/蹲及第一人称三枪连续动作审阅处理人物手臂。补移动靶伤害、完整单机与真实双客户端联机，尚未验证硬件性能。状态continue。


### Stage176（2026-09-14）：道路候车亭、草丛群落及日照调整
- 新增有坡屋顶、木条挡风墙、长凳和站牌的候车亭，补6组共330株草，环境光0.30→0.27、日照1.08→1.16。入口正常游戏视角能明确辨识新建筑，但仍有程序化构件感、阴影噪点和生硬草叶。候车亭在默认前行视野之外；宽幅前后构图几乎未变，不能视作整体环境改善完成。
- 前后实机对照：`artifacts/realism176-validation/review.html`、`visual-review.md`、`comparison-checks.json`。8组环境与stage175同机位。入口`after-entry/waiting-shelter-entrance.png`：actor=(8,0.05,87)、眼高1.6、yaw=-1.212025657、pitch=0.017554366；宽幅`after/terrain-wide.png`：actor=(17,0.05,50)、yaw=0.422853926、pitch=0.067315195。各目录environment-camera-poses.json记录完整精度。
- 候车亭实际角色进入x=12→15.66665、退出x=16→8.666702通过，挡风墙、上部木条、屋顶、凳面射线碰撞及开放入口通过。首次下挡风墙探针打中凳背，移至z=86.5后独立复测通过，原记录保留于verified/initial-windbreak-probe。默认出生120物理步从(0,1,90)至(0,0.000844786,78.999938965)，位置、朝向与stage175一致；截图冻结比赛模拟，不代表完整单局。
- 当前导出包19项回归退出0且PASS：建筑通行/碰撞、三枪108项瞄准、武器遮挡、联网状态规则及离线冒烟。`verification-summary.json`记录5批截图、8组环境和出生移动对照、41项构建哈希，25份接受的运行日志无匹配ERROR/WARNING/FAIL/leak/orphan。首次新增代码调用不存在的world.imported导致运行错误，已改PackedScene.instantiate并重新导出；无效运行保留于initial-invalid-import，未计入通过证据。
- 本地可运行预览：`./artifacts/realism176-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，需图形会话和相邻PCK，选择SOLO；README.md、build.json及export.log可复核。使用llvmpipe捕获，未验证硬件性能。本轮未做真实双客户端联机或完整单局，未推送或发布，保留所有未提交修改。
- 下一步：直接改默认道路连续行走可见的大尺度道路/地形过渡、林带与折面远山，并处理建筑阴影噪点，不再以视野外局部附件代替环境构图提升；随后结合第三人称走跑蹲和第一人称三枪动作审阅细长前臂、袖管与人物。仍需移动靶伤害、完整单机和真实双客户端联机。整体目标未完成，状态continue。


### Stage177（2026-09-14）：正常道路视角的碎石路肩、磨损边线与坡顶林带
- 调整road_surface.gdshader，在既有路面内扩展约两米碎石过渡，增加有交叉口渐隐及导数抗锯齿的磨损白边线；不改变道路碰撞。远林候选10,500→16,500，调整高坡分布和树冠颜色。默认前行与宽幅原图可明显辨识道路边界和连续坡顶树冠；草叶规律、裸坡折面、树冠广告牌及细长前臂仍未解决。
- 调整实际生效的world_visuals环境光0.30→0.34和SSAO半径/强度/幂为0.65/0.70/1.1。纠正stage176记录：world.gd里的0.27随后被world_visuals覆盖。本轮未新增建筑几何；仓库、维修棚和西工坊入口前后明暗差异很弱，不能算建筑画质问题已解决。
- 实机对照及审阅：`artifacts/realism177-validation/review.html`、`visual-review.md`、`comparison-checks.json`。8组环境机位与stage176一致，原图来源见baseline-origin.json。候车亭入口actor=(8,0.05,87)、眼高1.6、yaw=-1.212025657、pitch=0.017554366；宽幅after/terrain-wide.png：actor=(17,0.05,50)、yaw=0.422853926、pitch=0.067315195。仓库入口actor=(35,0.05,44)、yaw=0、pitch=0.024994794；完整精度在各目录environment-camera-poses.json。
- 当前导出包19项回归退出0且PASS，覆盖建筑通行/碰撞、三枪108项瞄准、武器遮挡、联网状态规则和离线冒烟。仓库双向z=48→20.4532及20→47.54725通过；默认角色120步由(0,1,90)至(0,0.000844786,78.999938965)，与前阶段一致。比赛逻辑冻结，不能代替完整单局或真实联网。背景贴地射线检查18块山体、7,809株树（1,802株幼树），最大根部误差0.000115米，见background-scenery.log。
- verification-summary.json记录4批环境捕获，另有1批出生移动捕获、8组环境同机位、42项构建哈希、25份运行日志。关键词扫描唯一命中为BACKGROUND_SCENERY_PASS行的max_root_error测量字段，并非运行错误。批量进程曾退出143，原因未知；按已完成审计续跑，未完成日志被重跑覆盖且未计为成功，见interruption.json。
- 本地预览：`./artifacts/realism177-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，图形会话下选择SOLO，保留相邻PCK。README.md、build.json、export.log可复核；未独立执行导入。llvmpipe捕获不代表硬件性能。保留所有未提交修改，未推送或发布。
- 下一步：直接改善建筑入口材质噪点与明暗层次、近地草丛及地形折面，避免仅调参数却没有可辨识效果；随后结合第三人称走跑蹲、第一人称三枪动作处理人物手臂，补移动靶伤害、完整单局和真实双客户端联机。整体目标未完成，状态continue。


### Stage178（2026-09-14）：维修棚双色门板、草带缺口与入口照明
- 门板增加暖灰上部/深绿下部材质分区、竖边框和中横档，正常入口与宽幅机位均能辨识；两侧草带留出裸土缺口，地面增加断续径流暗带。入口层次有所改善，但径流效果弱、水泥直边仍生硬，默认道路大尺度构图几乎不变，不能视作整体环境完成。
- 顶缝/椽条错开近共面位置，室内补光1.1→0.8；实际截图显示檐下和相邻仓库柱顶白色噪点仍存在，此项修复未成功。尖锐片状草叶、重复裸土、远山折面、细长前臂仍明显，具体记录见 `artifacts/realism178-validation/visual-review.md`。
- 同机位原始实机图：`artifacts/realism178-validation/review.html`、`comparison-checks.json`；前图源于stage177，来源见baseline-origin.json。维修棚入口actor=(15.5,0.05,39)、眼高1.6、yaw=0、pitch=0.054113782；宽幅actor=(17,0.05,50)、yaw=0.422853926、pitch=0.067315195，1280×800，各捕获目录保存完整精度机位。
- 维修棚实际角色双向z=38→24.24992、24→37.75008通过，门板、门廊柱、顶棚和板材阻挡检查通过。默认出生120物理步至(0,0.000844786,78.999938965)，与stage177一致；捕获冻结比赛模拟，不代表完整单局。
- 背景检查首次误用headless触发显示模式断言并挂起，结束该测试进程，原日志保留background-scenery-invalid-headless.log；改用Xvfb+Compatibility通过：18块山体、7809株树（1802株幼树），最大根部偏差0.000115米。该运行有驱动不支持VSync警告，不能声称全部日志无警告。
- 当前导出包19项回归退出0且PASS，覆盖建筑通行/碰撞、三枪108项瞄准、武器遮挡、联网状态规则及离线冒烟（装填、治疗、伤害、胜利等断言）。verification-summary.json记录4批环境捕获及1批出生移动捕获、8组环境同机位、42项构建哈希、25份运行日志；除上述VSync警告，扫描命中max_root_error是测量字段，并非错误。
- 本地可运行预览：`./artifacts/realism178-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，需图形会话，选择SOLO并保留相邻PCK；README.md、build.json与export.log可复核。llvmpipe截图不代表硬件性能，未完成完整单局或真实双客户端验证。保留未提交修改，未推送或发布。
- 下一步：先定位建筑檐下/柱顶白点根因，再改善默认道路连续机位的大片重复地表、草叶形态和远山折面；随后结合第三人称走跑蹲、第一人称三枪动作审阅处理人物/手臂，补移动靶伤害、完整单局与真实双客户端联机。整体目标未完成，状态continue。


### Stage179（2026-09-14）：维修棚木质底板与路边草簇形态、受光
- 维修棚新增14块木质顶棚底板与程序化粗糙木纹，加厚前梁；正常入口机位能辨识连续木面和板缝。道路草簇缩窄并增高，调整草叶朝天法线混合，宽幅机位的横向叶片铺毯减轻。未增加底板碰撞，沿用原屋顶碰撞。
- 实机审阅：棚中央亮噪点减少，但左侧接缝及相邻柱顶白点仍存在，不能认定根因已解决；大片重复裸土、尖锐片状草叶、远山折面、方块建筑和细长前臂仍明显。详情与8组环境同机位前后图见 `artifacts/realism179-validation/review.html`、`visual-review.md`、`comparison-checks.json`；前图来自stage178，来源保存在baseline-origin.json，未修图。
- 入口近景 `after-shelter/repair-shelter-entrance.png`：actor=(15.5,0.05,39)、眼高1.6、yaw=0、pitch=0.054113782；宽幅 `after/terrain-wide.png`：actor=(17,0.05,50)、眼高1.6、yaw=0.422853926、pitch=0.067315195。以上路径相对本阶段validation目录，各捕获目录保存完整精度environment-camera-poses.json。默认出生及前进120物理步的机位、移动记录与stage178完全一致，终点=(0,0.000844786,78.999938965)，无手动传送；截图冻结比赛模拟，不代表完整单局。
- 维修棚角色双向实际通行z=38→24.24992、24→37.75008通过，门板、柱、板材及屋顶阻挡通过；仓库门双向通行通过。导出包19项回归均退出0且PASS，覆盖建筑通行/碰撞、32处入口遮檐、12处屋顶、三枪108项瞄准、武器遮挡、联网状态规则及离线冒烟。详见verified/functional-results.json与verification-summary.json。
- 4批环境捕获及1批默认出生捕获通过，核对43项构建哈希、25份运行日志；背景图形检查通过（18块山体、7809株树、1802株幼树，最大根部偏差0.000115米），保留驱动不支持VSync的警告。max_root_error是测量字段。截图使用Forward+/Vulkan llvmpipe，不代表硬件性能；尚未验证完整单局及真实双客户端联机。
- 当前本地预览：`./artifacts/realism179-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，需图形会话，选择SOLO，保留相邻PCK。预览README.md、build.json与validation/export.log可复核。保留全部未提交修改，未推送或发布。
- 下一步：改善默认道路连续机位的重复空旷地表、草地过渡与远山折面，建立入口白点的可复现渲染诊断；随后审阅第三人称走跑蹲及第一人称三枪动作，处理人物/手臂缺陷，并补移动靶伤害、完整单局、真实双客户端验证。整体写实画面与功能目标未完成，状态continue。


### Stage180（2026-09-14）：远山岩土暴露与背景林带分布
- 调整 terrain_slopes.gdshader 的岩色和岩土暴露阈值、破碎接缝；world_visuals.gd 增加背景植被采样，放宽坡度与海拔覆盖，并按坡度控制密度。默认出生、草坡平视及宽幅实机对照可见更连续的山脊林冠，部分坡肩裸露减少。灰白裸坡与山体折面仍明显，不能以树量增加认定环境写实达标。本轮未修改建筑几何、碰撞体或光照设置。
- 实机证据：`artifacts/realism180-validation/review.html`、`visual-review.md`、`comparison-checks.json`；8组环境机位与stage179完全一致，来源见baseline-origin.json。入口近景 `after-shelter/repair-shelter-entrance.png`：actor=(15.5,0.05,39)、眼高1.6、yaw=0、pitch=0.054113782；宽幅 `after/terrain-wide.png`：actor=(17,0.05,50)、眼高1.6、yaw=0.422853926、pitch=0.067315195。各捕获目录保存完整精度environment-camera-poses.json。默认出生与前进120物理步记录同stage179一致，终点=(0,0.000844786,78.999938965)。截图未经修图，固定机位冻结比赛不代表完整单局。
- 导出包19项回归全部退出0且PASS：建筑/仓库门实际通行、入口及屋顶碰撞、三枪108项瞄准、武器遮挡、联网状态规则、离线冒烟等；详见verified/functional-results.json、verification-summary.json。4批环境捕获及默认出生捕获通过。背景图形检查18块山体、10309株树、2346株幼树，最大根部偏差0.000100米；25份运行日志扫描仅匹配测量字段max_root_error，无运行错误。43项构建哈希已保存。
- 当前本地预览：`./artifacts/realism180-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，需图形Linux会话，选择SOLO并保留相邻PCK；README.md、build.json及validation/export.log可复核。Forward+/Vulkan llvmpipe截图不代表硬件性能，未完成完整单局和真实双客户端验证。保留全部未提交修改，未推送或发布。
- 下一步继续环境：改善默认道路和入口近中景重复裸土、草地过渡，检查灰白坡面的雾、受光与材质贡献，建立檐口/柱顶白点固定机位诊断；仍需可辨识的建筑细节和光照改进。之后结合第三人称走跑蹲、第一人称三枪动作实机审阅处理人物与手臂，补移动靶伤害、完整单局、真实双客户端联机。整体目标未完成，状态continue。

### Stage181（2026-09-14）：维修棚入口暖光、檐口与地表植被
- 修改world_visuals.gd，增加木质檐口、檐下灯具及暖光，扩大两侧不规则草丛并提高草叶；修改service_ground.gdshader的颗粒尺度、湿土色差与法线强度，修改shelter_structural_steel.gdshader降低钢构反光。入口同机位可见木板暖色受光和更高草丛；檐口细节较小，宽幅土面虽然碎粒减少却更均匀，不能认定地表写实度显著提升。柱顶白点、灰白折面远山、默认道路空旷仍明显，整体目标未完成。
- 实机对照：`artifacts/realism181-validation/review.html`、`visual-review.md`、`comparison-checks.json`。8组环境机位与stage180完全一致；入口`after-shelter/repair-shelter-entrance.png`：actor=(15.5,0.05,39)、眼高1.6、yaw=0、pitch=0.054113782；宽幅`after/terrain-wide.png`：actor=(17,0.05,50)、眼高1.6、yaw=0.422853926、pitch=0.067315195。完整参数见各目录environment-camera-poses.json。默认出生及前进120物理步记录同基线一致，终点=(0,0.000844786,78.999938965)。原始截图未经美化。
- 导出包19项回归全部退出0且PASS，包括维修棚及其他建筑通行、仓库双向过门、入口/屋顶碰撞、三枪108组瞄准、武器遮挡、联网状态规则及离线冒烟；见verified/functional-results.json与verification-summary.json。4批环境捕获、默认出生捕获及背景检查通过；背景18块山体、10309株树、2346株幼树，最大根部偏差0.000100米。25份运行日志仅关键词命中正常字段max_root_error，未发现运行错误。43项构建文件哈希已保存。
- 本地预览：`./artifacts/realism181-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，图形Linux会话中选择SOLO，保留相邻PCK；README.md、build.json、validation/export.log可复核。冻结比赛捕获及有限前进不能替代完整单局，联网规则测试不能替代真实双客户端；llvmpipe截图不能代表硬件性能。保留所有未提交修改，未推送或发布。
- 下一步继续环境：优先默认机位可见的道路/裸土地表和植被过渡、灰白山体受光材质，以及柱顶白点固定机位诊断。随后结合第三人称走跑蹲与第一人称三枪动作审阅处理人物、手臂及武器剩余缺陷，补移动靶伤害、完整单局与真实双客户端联网。状态continue，不以本轮局部入口改善认定整体完成。


### Stage182（2026-09-14）：地表草色分区、棚板氧化与入口补光
- 修改grass.gdshader增加世界坐标黄绿草色斑块，service_ground.gdshader增加局部裸土色块和经过距离滤波的胎纹；shelter_metal.gdshader增加板间色差与接缝氧化，world_visuals.gd增强维修棚入口和内部补光。实机草坡与宽幅对照可辨认黄绿草带和较暖的斑驳土面，但胎纹在宽幅仍模糊，建筑改善偏弱；柱顶/檐角白点、西侧车间暗顶棚与白灯条、重复地坪、空旷直路及灰白折面远山仍未解决。不以局部色差认定整体完成。
- 证据：`artifacts/realism182-validation/review.html`、`visual-review.md`、`comparison-checks.json`，基线来自stage181。8组环境机位完整参数一致；入口`after-shelter/repair-shelter-entrance.png`：actor=(15.5,0.05,39)、眼高1.6、yaw=0、pitch=0.054113782；宽幅`after/terrain-wide.png`：actor=(17,0.05,50)、眼高1.6、yaw=0.422853926、pitch=0.067315195。各捕获目录保存完整机位。默认出生及实际前进120物理步记录与基线一致，终点=(0,0.000844786,78.999938965)。最终截图均晚于最终PCK导出；preliminary-incomplete目录不作最终证据。
- 最终导出包19项回归全部退出0且PASS，包含维修棚/车间/仓库双向通行、入口/屋顶碰撞、三枪108组瞄准、武器遮挡、联网状态规则和离线冒烟；见verified/functional-results.json、verification-summary.json。维修棚穿行终点分别z=24.24992和37.75008，门板/墙体/工作台与屋顶阻挡检查通过。4批环境捕获、默认出生捕获和背景检查通过；25份运行日志未检出错误警告，44项构建哈希已保存。未修改建筑碰撞几何。
- 本地预览：`./artifacts/realism182-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，图形Linux会话中选择SOLO，保留相邻PCK；README.md、build.json、validation/export-revised.log可复核。冻结比赛截图、有限前进和冒烟测试不代表完整单局；联网状态规则不代表真实双客户端，llvmpipe截图不代表硬件性能。保留所有未提交修改，未推送或发布。
- 下一步先做正常机位的材质归属与光照隔离诊断：定位维修棚白点、明确默认路肩/草地/山体各自材质覆盖后再改大面积地表，避免继续仅靠细微调色；改善车间暗顶棚与灯条反差。随后结合第三人称走跑蹲、第一人称三枪动作实机审阅处理细长前臂等人物/武器缺陷，并补移动靶伤害、完整单局与真实双客户端联机。整体目标未完成，状态continue。


### Stage183（2026-09-14）：车间顶棚衬板、局部补光与檐边植被
- 西侧车间增加有折边接缝的金属顶棚衬板和两处朝上补光，正常入口机位原先大块黑顶变为可读板面，是本轮主要可见改善；檐边新增28簇错落装饰草，山坡植被着色与裸岩混合调整，远景增益较轻。基础雾参数被world_visuals最终配置覆盖，不计为有效改善。白灯条/檐边白点、重复地表、空直道路、灰白山体和细长前臂仍存在，整体目标未完成。
- 对照与审阅：`artifacts/realism183-validation/review.html`、`visual-review.md`、`comparison-checks.json`。8组环境机位与stage182逐字段一致，包含入口近景和宽幅地形。入口actor=(-42,0.05,44)、target=(-42,1.9,34)；宽幅actor=(17,0.05,50)、target=(-46,12,-90)，眼高1.6；完整朝向见各捕获目录environment-camera-poses.json。默认出生及前进120物理步截图和记录见default-spawn。
- 最终包19项回归退出0且PASS，含车间/仓库双向通行、入口与屋顶碰撞、三枪108组瞄准、武器遮挡、联网状态规则及离线冒烟；见verified/functional-results.json。4批环境捕获、出生前进和图形背景贴地检查通过；18处山体、10309株树（2346株幼树），最大根部偏差0.000100米。verification-summary.json检查25份运行日志无错误警告，build.json保存45项哈希。验证曾退出143，已按成功检查点恢复完成，未将中断当作通过。
- 本地运行：`./artifacts/realism183-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，图形Linux会话选择SOLO，保留相邻PCK；README.md、build.json、validation/export.log可复核。冻结截图、有限前进及冒烟不替代完整单局；联网规则不替代真实双客户端；llvmpipe不代表硬件性能。保留全部未提交修改，未推送或发布。
- 下一步在实际生效的环境配置处诊断灰白远山与檐边白点，改变草地规则分布和道路边缘过渡，用固定机位确认明显增益；随后结合第三人称走跑蹲、第一人称手部实机审阅处理人物/武器余项，补完整单局、移动靶伤害与真实双客户端验证。状态continue。


### Stage184（2026-09-14）：车间排水细节、檐边植被与有效雾配置
- 西车间补檐沟、两侧落水管及管箍，檐边28簇草改为84簇不规则分组植被；将world_visuals最终生效的雾密度从0.0008降至0.00032，服务区车辙加入磨损噪声并减弱深色条纹。正常机位下植被略丰富、车辙略弱，但管件占屏很小、远景改善有限，不能算整体画质完成。空直道路、重复幼草/树形、灰色三角山体、偏亮灯条及细长前臂仍明显。
- 实机证据：`artifacts/realism184-validation/review.html`、`visual-review.md`、`comparison-checks.json`。8组环境前后机位与stage183逐字段一致，出生及前进120步记录也一致。入口actor=(-42,0.05,44)、yaw=0、pitch=0.024994794；宽幅actor=(17,0.05,50)、yaw=0.422853926、pitch=0.067315195；眼高1.6，完整记录见各目录environment-camera-poses.json。入口及宽幅原图见after/west-workshop-entrance.png、after/terrain-wide.png。
- 最终包19项回归全部退出0且PASS：含车间/仓库双向通行、入口屋顶碰撞、三枪108组瞄准、遮挡、联网状态规则和离线冒烟。新增两根落水管射线均命中z=45.53；西车间真实角色由z=48走至20.45267、反向由20走至47.54725，柱体/货架阻挡通过。4批环境捕获、出生前进及图形背景检查通过；背景18处山体、10309株树（2346株幼树）、最大根部偏差0.000100米。verification-summary.json汇总25份最终有效日志无错误警告；build.json记录45项哈希。
- 保留失败与中断证据：背景headless首次断言失败见background-scenery-headless-attempt.log，随后图形环境检查成功见background-scenery.log；回归进程退出143后按成功检查点续跑，未将失败或中断计为通过。
- 本地预览：`./artifacts/realism184-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，图形Linux会话选择SOLO，保留相邻PCK；README.md、build.json、validation/export.log可复核。冻结截图、有限通行及冒烟不替代完整单局；联网状态规则不替代真实双客户端；llvmpipe不代表硬件性能。全部既有未提交修改保留，未推送或发布。
- 下一步先定位默认出生和宽幅机位的灰色山体材质覆盖、规则幼草与道路边缘，做正常视距下明显可辨的环境改动，避免再次仅靠细微调色或小管件替代画质提升。继续保留第三人称走跑蹲、第一人称手部动作、移动靶伤害、完整单局和真实双客户端验证。整体目标未完成，状态continue。


### Stage185（2026-09-14）：车间成组窗面、草坡覆盖与远景雾调整
- 西车间入口两侧加入成组窗面、竖梃横档、窗台与遮雨板，正常接近机位可辨认连续分格立面，中央入口保持畅通；扩大草簇低密度区域覆盖，远坡植被着色变深，最终有效雾密度0.00032→0.00016。未重建光照系统。窗面仍是深色不透明实体，玻璃感不足；山体折面、重复树线、平坦地表及细长前臂仍明显，整体目标未完成。
- 实机前后对照与审阅：`artifacts/realism185-validation/review.html`、`visual-review.md`、`comparison-checks.json`。8组环境机位与stage184逐字段一致，默认出生与前进120物理步记录一致。入口actor=(-42,0.05,44)、yaw=0、pitch=0.024994794；宽幅actor=(17,0.05,50)、yaw=0.422853926、pitch=0.067315195；眼高1.6。入口及宽幅原图为after/west-workshop-entrance.png、after/terrain-wide.png；外侧窗组见after/west-workshop-approach.png，完整朝向见各捕获目录environment-camera-poses.json。
- 最终包19项回归退出0且PASS，含车间/仓库双向角色通行、入口屋顶碰撞、三枪108组瞄准、武器遮挡、联网状态规则和离线冒烟。新增两侧窗面射线x=-46.4/-36.4均命中z=41.11；车间角色z=48→20.45267、反向20→47.54687，柱体/货架阻挡通过。离线冒烟覆盖16个角色、换弹、治疗、伤害、胜利、射线、掩体、射击间隔和骨架；详细结果见verified/functional-results.json。
- 4批环境捕获、默认出生前进、图形背景贴地检查通过；背景18处山体、10309株树（2346株幼树）、最大根部偏差0.000100米。verification-summary.json汇总25份运行日志无错误警告，build.json保存45项哈希。
- 当前本地预览：`./artifacts/realism185-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，图形Linux会话选择SOLO，保留相邻PCK；预览README.md、build.json及validation/export.log可复核。冻结截图、有限通行及冒烟不替代完整单局；联网状态规则不替代真实双客户端；llvmpipe不代表硬件性能。保留全部既有未提交修改，未推送或发布。
- 下一步优先改变正常机位明显的山体轮廓、重复树线与地表分层，提升窗面材质可信度；结合第三人称走跑蹲和第一人称手臂动态实机审阅安排人物/武器余项，并补完整单局、移动靶伤害和真实双客户端验证。状态continue。


### Stage186（2026-09-14）：远景林簇开阔区与环境实机复核
- 远景树林加入低频开阔区、收紧分布阈值并缩小树体，连续重复树墙变为有间隔的林簇。18处山体的树量10309→4085（幼树2346→933），图形模式根部最大偏差0.000097米。正常出生和宽幅机位变化明显，但暴露出更空、更光滑的山面；不能将树量下降当作整体画质改善。
- 加入(24,57)附近羽化草甸权重，调整车间玻璃粗糙度和镜面响应。实机中主要前景仍空、窗面仍深黑不透明，这两项视觉收益有限，未完成地表和建筑材质目标；本阶段未重建光照。细长前臂、重复草簇、平滑山体仍需处理。
- 原始对照与审阅：`artifacts/realism186-validation/review.html`、`visual-review.md`、`comparison-checks.json`。8组环境机位逐字段匹配stage185，默认出生及前进120物理步记录一致。入口after/west-workshop-entrance.png：actor=(-42,0.05,44)、yaw=0、pitch=0.024994794；宽幅after/terrain-wide.png：actor=(17,0.05,50)、yaw=0.422853926、pitch=0.067315195；眼高1.6米。完整位置朝向见各捕获目录environment-camera-poses.json。
- 最终包19项回归退出0且PASS，包含建筑双向角色通行、入口/屋顶碰撞、三枪108组瞄准、武器遮挡、联网状态规则、16角色离线冒烟。4批实机捕获、默认出生前进和图形背景贴地通过；verification-summary.json汇总25份运行日志无错误警告，verified/functional-results.json保存各项结果，预览build.json保存45项哈希。
- 本地预览：`./artifacts/realism186-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，图形Linux会话选择SOLO，保留相邻PCK；README.md、build.json及validation/export.log可复核。有限通行/冒烟不替代完整单局，联网规则不替代真实双客户端，llvmpipe不代表硬件性能。保留既有未提交修改，未推送或发布。
- 下一步优先重塑裸露远山的沟谷、轮廓与岩土层次，并确认草甸遮罩实际覆盖正常宽幅/出生机位可见区域；继续改善窗面与入口明暗。保留第三人称走跑蹲、第一人称手臂动态、移动靶伤害、完整单局和真实双客户端实机验证。整体目标未完成，状态continue。

### Stage187（2026-09-14）：远坡沟谷与岩土层次实机验证
- 为远山两侧加入域扭曲支沟、坡面支脊，调整坡面岩土露出和宽尺度层理。正常出生点及宽幅对照中，车间和棚屋后方的光滑山坡出现可辨识纵向沟谷；山体仍圆钝偏蓝，部分褶皱有程序感。本轮未改建筑和全局灯光，近景裸土、重复草簇、黑窗及细长前臂仍明显，整体目标未完成。
- 原始同机位对照与实际审阅：`artifacts/realism187-validation/review.html`、`visual-review.md`、`comparison-checks.json`。8组环境机位逐字段匹配stage186，默认出生及前进120物理步记录一致。入口after/west-workshop-entrance.png：actor=(-42,0.05,44)、yaw=0、pitch=0.024994794；宽幅after/terrain-wide.png：actor=(17,0.05,50)、yaw=0.422853926、pitch=0.067315195；眼高1.6米，完整朝向见各目录environment-camera-poses.json。
- 最终包19项回归退出0且PASS，含车间/仓库双向角色通行、入口/屋顶碰撞、三枪108组瞄准、武器遮挡、联网状态规则、16角色离线冒烟。4批环境捕获、默认出生前进、图形背景贴地通过；18座山体、4019株树（915株幼树），根部最大误差0.000128米。verification-summary.json汇总25份运行日志无错误警告，verified/functional-results.json保存各项结果，build.json保存45项哈希。初次验证进程退出143原因未确认，记录于validation-interruption.json；保留成功结果后续跑完成全部检查。
- 当前本地预览：`./artifacts/realism187-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，图形Linux会话选择SOLO，保留相邻PCK；README.md、build.json和validation/export.log可复核。对照页23个本地资源链接有效。有限通行/冒烟不替代完整单局，联网规则不替代真实双客户端，llvmpipe不代表硬件性能。保留既有未提交修改，未推送或发布。
- 下一步优先改善正常出生与宽幅机位的草地密度变化、裸土和道路边缘过渡，处理建筑黑窗及入口内外光照；随后结合第三人称走跑蹲和第一人称手臂动态审阅安排人物/武器余项，补完整单局、移动靶伤害和真实双客户端验证。状态continue。

### Stage188（2026-09-14）：南侧院落草地连贯性与建筑材质实机复核
- 将新增草甸中心移到正常宽幅机位可见的(20,47)，增加18,000次局部放置尝试，保留棚前通路、道路和障碍排除。最终同机位图可见左前方及棚边草地更密、更连贯；灰土仍平、草土边缘偏硬，尚未完成环境画质目标。第一候选效果不足，保留candidate1证据并主动停止其未完验证，以第二候选重新完成全部检查。
- 车间高窗加入随视角变化的解析天空响应（EMISSION，不是真实场景反射），入口黑窗改善有限。已查明：workshop_frontage的高度4.55高窗使用该shader，west_workshop_canopy高度2.22的入口低窗仍绑定深色StandardMaterial3D。下一步应直接处理这组可见低窗及入口明暗；本轮未改变全局光照，不能宣称建筑/光照缺陷解决。
- 原始对照与审阅：`artifacts/realism188-validation/review.html`、`visual-review.md`、`comparison-checks.json`。8组环境机位逐字段匹配stage187，默认出生及前进120物理步记录一致。入口after/west-workshop-entrance.png：actor=(-42,0.05,44)、yaw=0、pitch=0.024994794；宽幅after/terrain-wide.png：actor=(17,0.05,50)、yaw=0.422853926、pitch=0.067315195；眼高1.6米。维修棚入口近景与完整机位记录亦已保存。
- 当前包第三人称静态站立/行走/蹲姿截图在`character-review/stance-gallery.png`，相机、脚本哈希与范围见result.json。实际审阅仍见肩肘块状、厚重腿靴；第一人称前臂偏细长。静态画廊不替代连续动作和握持细节验证，人物与武器目标继续保留。
- 最终19项功能回归退出0且PASS，含建筑双向角色通行、入口/屋顶碰撞、三枪108组瞄准、武器遮挡、联网状态规则及16角色单机冒烟（装填/治疗/伤害/胜利逻辑等）。4批环境捕获、出生前进、背景贴地和人物画廊通过；26份运行日志未检出错误警告。`verified/functional-results.json`、`verification-summary.json`保存结果；`artifact-integrity.json`确认25个本地资源链接及46项构建哈希有效。有限冒烟不替代完整单局，瞄准对齐不替代移动靶伤害，联网规则不替代真实双客户端，软件渲染不代表硬件性能。
- 本地预览：`./artifacts/realism188-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，图形Linux会话选择SOLO，保留相邻PCK；README.md、build.json、validation/export.log可复核。保留既有未提交修改，未推送或发布。
- 下一步优先修正实际可见低窗材质、草土过渡和入口光照，结合人物连续动作及第一人称手部审阅处理剩余缺陷，并补齐移动目标伤害、完整单局和真实双客户端验证。整体目标未完成，状态continue。

### Stage189（2026-09-14）：入口低窗与局部光照修正、最终包回归
- 西侧车间实际可见低窗改用既有解析天空玻璃shader，并加入两盏朝向立面的局部补光；正常接近和入口机位中低窗由黑变浅蓝灰、窗框更清楚。玻璃仍是偏平的不透明解析响应，缺少室内深度；未改碰撞。service_ground增加草土颜色混合，但实机地表改善很弱，宽幅灰地、重复山体和草簇边缘仍明显，不能视作整体环境提升完成。
- 同机位证据：`artifacts/realism189-validation/review.html`、`visual-review.md`、`comparison-checks.json`。8组环境机位逐字段匹配stage188，另有默认出生与前进120物理步对照。入口`after/west-workshop-entrance.png`角色(-42,0.05,44)、yaw=0、pitch=0.024994794；宽幅`after/terrain-wide.png`角色(17,0.05,50)、yaw=0.422853926、pitch=0.067315195；眼高1.6米。已实际审阅入口、接近、草坡、宽幅对照及出生、人物画廊；没有声称逐一审阅全部8对。
- 最终包19项功能检查退出0且PASS，包括建筑双向角色通行、入口/屋顶碰撞、三枪108组瞄准、遮挡、联网状态规则及16角色单机冒烟。4批环境捕获、默认出生前进、图形背景贴地及人物画廊通过；26份最终运行日志无检出的错误警告，46项构建哈希、25个本地页面链接核验通过。见`verified/functional-results.json`、`verification-summary.json`、`artifact-integrity.json`。首次背景测试误用headless触发图形上下文断言并超时，原始失败日志与改用图形上下文成功结果均保留，见`execution-attempts.json`，未修改断言。
- 本地预览：`./artifacts/realism189-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，图形Linux会话选择SOLO并保留相邻PCK；README.md、build.json及validation/export.log可复核。人物静态画廊仍见块状肩肘、厚重腿靴，第一人称前臂偏细长。有限冒烟不替代完整单局，静态瞄准不替代移动目标伤害，联网规则不替代真实双客户端，软件渲染不代表硬件性能。保留全部未提交修改，未推送或发布。
- 下一步：用同机位临时诊断材质定位宽幅灰地实际渲染归属（meadow或service_ground，其coverage/discard会影响可见覆盖），恢复后针对实际可见地面改善尺度、草土边缘和山体轮廓，继续处理低窗平板感；随后结合第三人称连续动作、第一人称握持审阅处理余项，补完整单局、移动目标伤害与真实双客户端。整体目标未完成，状态continue。

### Stage190（2026-09-14）：定位并消除宽幅前景灰白条纹地面
- 运行时诊断确认前景来自service_ground覆盖层；诊断粉色仅留在diagnostic目录，最终包不含该色。修正service_ground.gdshader噪声散列、土石配色和草土恢复色，降低镜面及远处高频法线。实际查看正常宽幅前后图，灰白横向条纹地面明显变为棕色压实土与暗轮迹；出生点路肩也更协调。建筑入口画面基本不变，本轮未修改建筑几何、碰撞或全局光照，不能声称整组环境目标完成。
- 同机位原图与审阅：`artifacts/realism190-validation/review.html`、`visual-review.md`、`comparison-checks.json`；8组环境机位逐字段匹配stage189，默认出生及前进120步记录一致。宽幅after/terrain-wide.png角色(17,0.05,50)、yaw=0.422853926、pitch=0.067315195；入口after/west-workshop-entrance.png角色(-42,0.05,44)、yaw=0、pitch=0.024994794；眼高1.6米，其他机位见environment-camera-poses.json。实际审阅宽幅前后、入口拼图及近景、出生前后与前进截图、当前人物静态画廊，未声称逐张审阅全部8对。
- 最终包19项功能检查退出0且PASS，包含建筑双向通行、入口/屋顶碰撞、三枪108组瞄准、武器遮挡、联网状态规则和16角色单机冒烟。4批环境捕获、出生前进、图形背景贴地及人物画廊通过；26份运行日志未检出错误警告，46项构建哈希与25个页面资源链接通过核验。见verified/functional-results.json、verification-summary.json、artifact-integrity.json。有限冒烟不替代完整单局，瞄准对齐不替代移动靶伤害，联网规则不替代真实双客户端，llvmpipe不代表显卡性能。
- 当前本地预览：`./artifacts/realism190-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，图形Linux会话选择SOLO并保留相邻PCK；README.md、build.json及validation/export.log可复核。保留全部未提交修改，未推送或发布。
- 仍见重复且边缘突兀的草簇、圆钝沟槽山体、过宽平直主路与不透明平板低窗；第一人称前臂偏细长，第三人称肩肘块状、腿靴厚重。下一步优先草簇分布与山体轮廓、低窗室内深度及入口光照，继续同机位回归，再结合连续人物动作与握持/换弹审阅处理余项，补完整单局、移动靶伤害和真实双客户端。整体目标未完成，状态continue。

### Stage191（2026-09-14）：车间窗框厚度、入口补光与硬地草边过渡
- 为西侧车间增加砖窗侧框、排水管与管夹，低窗增加上亮下暗的近似环境响应，并降低、暖化入口补光；草簇在硬地排除区外按距离与噪声渐变高度和密度，保留原0.5米排除范围。实机入口可辨窗框厚度及窗面明暗，宽幅和草坡可见较低、较不规则的草边；玻璃仍为不透明近似材质，不是真实反射或室内透视，未宣称整体画质达标。
- 前后原图与审阅：`artifacts/realism191-validation/review.html`、`visual-review.md`、`comparison-checks.json`。8组环境机位与stage190逐字段一致，默认出生及前进120步记录一致。入口after/west-workshop-entrance.png角色(-42,0.05,44)、yaw=0、pitch=0.024994794；宽幅after/terrain-wide.png角色(17,0.05,50)、yaw=0.422853926、pitch=0.067315195；眼高1.6米，完整位置朝向见各environment-camera-poses.json。实际审阅入口、宽幅及草坡前后、当前其他入口/筒仓/出生前进图和人物静态画廊，未声称逐张审阅全部8对。
- 最终19项检查PASS，涵盖建筑双向通行、入口/屋顶碰撞、三枪108组瞄准、武器遮挡、联网状态规则及16角色单机冒烟；新增窗框/排水管6条碰撞射线通过，车间前后门通行通过。4批环境捕获及出生前进、背景贴地、人物画廊通过；26份运行日志未检出错误警告，46项哈希与27个页面链接核验通过，见verified/functional-results.json、verification-summary.json、artifact-integrity.json。初次导出因Variant推断失败，显式Vector2修复后重新导出；筒仓与路边通行初次100秒超时，复测分别94.16及118.17秒PASS，失败与重试保留于failed-first-build和execution-attempts.json。未测真实双客户端、完整单局、移动目标伤害或连续换弹动画；llvmpipe不代表显卡性能，草地生成耗时尚未单独剖析。
- 当前本地预览：`./artifacts/realism191-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，图形Linux会话选择SOLO并保留相邻PCK；README.md、build.json及validation/export.log可复核。保留全部未提交修改，未推送或发布。
- 仍见宽幅前景空旷、平直宽路、圆钝沟槽山体、深处草带重复及窗面缺乏室内深度；第一人称前臂细长、第三人称肩臂块状和腿靴厚重。下一步继续处理正常机位可辨的山体轮廓、草带分布与建筑室内层次，再结合人物连续动作、握持和换弹实机审阅推进余项，补完整单局、移动目标伤害及真实双客户端。整体目标未完成，状态continue。

### Stage192（2026-09-14）：不对称远山轮廓与疏密林线
- 延续stage191环境检查点，修改world_visuals.gd的山体高度与远景植被分布：采用不对称主脊、侧肩、鞍部和有正负变化的侵蚀噪声，降低高处林线、增加林间空隙。实际审阅宽幅及车间接近前后图，密集山顶树列和纵向沟槽减少，正常出生机位可辨山峰与鞍部；山面仍光滑偏蓝、局部尖峰夸张。建筑、近地草簇与全局灯光本阶段没有新增改动，保留191改进，整体目标未完成。
- 同机位对照与实际审阅：`artifacts/realism192-validation/review.html`、`visual-review.md`、`comparison-checks.json`。四组位置朝向逐字段匹配191且基线原图哈希一致；入口after/west-workshop-entrance.png角色(-42,0.05,44)、yaw=0、pitch=0.024994794；宽幅after/terrain-wide.png角色(17,0.05,50)、yaw=0.422853926、pitch=0.067315195，眼高1.6米。完整位置朝向见after/environment-camera-poses.json；另审阅当前仓库入口、默认出生及前进120步图。
- 最终包6项检查退出0且PASS：车间/仓库双向碰撞通行、三枪108组瞄准、武器遮挡、联网状态规则、16角色单机冒烟。原始出生真实碰撞移动120步约11米，无手动传送，为隔离通行关闭比赛模拟。图形背景检查18座山体、4131株树（925株幼树），树根最大误差0.000105米。46项构建哈希、11个证据页链接、10张图片尺寸及10份无错误警告日志核验通过，见verification-summary.json、artifact-integrity.json及verified/functional-results.json；本阶段未重新运行此前全部19项检查。
- 本地预览：`./artifacts/realism192-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，图形Linux会话选择SOLO并保留相邻PCK；README.md、build.json、validation/export.log可复核。有限通行和冒烟不替代完整单局，联网状态规则不替代真实双客户端，瞄准对齐不替代移动目标伤害，llvmpipe不代表显卡性能。未新增第三人称或连续换弹截图验证；保留全部未提交修改，未推送或发布。
- 下一步优先正常宽幅及出生机位的重复草带、空旷前景与建筑室内层次，继续入口/地形同机位验证；随后结合第三人称连续动作和第一人称握持/换弹审阅处理细长前臂、块状肩肘和厚重腿靴，补完整单局、移动目标伤害及真实双客户端。状态continue。

### Stage193（2026-09-14）：工坊储罐旧漆与近地草簇疏密
- 在192基础上修改workyard_tank.gdshader、grass.gdshader及world_visuals.gd：储罐筒体/封头增加旧漆、雨痕、底部及接缝锈斑，增加压力表构件；近地草簇降低高度、扩大分布范围并错开中心，颜色改为平滑噪声变化。正常工坊接近机位可辨储罐表面细节，草团硬间隔有所缓和；雨痕仍偏重，压力表主要看到背面，宽幅改善有限。本阶段未修改建筑室内或全局灯光，不能视为整组环境升级完成。
- 四组实际游戏前后对照：`artifacts/realism193-validation/review.html`、`visual-review.md`、`comparison-checks.json`；机位逐字段匹配192，基线原图哈希一致。入口角色(-42,0.05,44)、yaw=0、pitch=0.024994794；宽幅角色(17,0.05,50)、yaw=0.422853926、pitch=0.067315195；眼高1.6米，完整位置朝向见after/environment-camera-poses.json。实际审阅工坊接近、两处入口和宽幅；8张1280×800原图及页面资源链接核验通过，46项构建哈希一致。
- 首次并行验证会话退出143；截图已保存且日志有ENVIRONMENT_REVIEW_CAPTURE_PASS，但截图子进程退出状态无法确认，异常保留于capture-process-audit.json。功能检查另行续跑，以verified/functional-results.json和各原始日志为准；不借用历史轮次结果。
- 本地预览：`./artifacts/realism193-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，图形Linux会话选择SOLO并保留相邻PCK；README.md、build.json和validation/export.log可复核。保留全部未提交修改，未推送或发布。
- 下一步优先缩小平面感阔叶、打破宽幅连续草带并补建筑入口室内光照层次，继续同机位和碰撞通行验证。宽幅裸土空旷、山面光滑偏蓝、窗面浅薄仍未解决；随后补第三人称连续动作、第一人称握持/换弹审阅，以及完整单局、移动目标伤害和真实双客户端。整体状态continue。
- 功能续跑完成：最终预览包6项检查全部退出0且PASS，包括工坊/仓库双向碰撞通行、三枪108组瞄准、武器遮挡、联网状态规则和16角色单机冒烟（换弹、治疗、伤害、胜利条件等规则）。单机冒烟不替代完整单局，联网规则不替代真实双客户端，llvmpipe不代表显卡性能。详见verification-summary.json及verified/functional-results.json。

### Stage194（2026-09-14）：维修间工作区、入口灯光与植被疏密
- 修改world_visuals.gd：后墙增加立柱、实体工作台、工具板及走线，增加暖色工作灯并收窄/降低顶灯；缩小维修场地阔叶比例，在宽幅右前景草带引入覆盖缺口。正常入口机位能看见工具墙暖光，工作台下部仍被箱子遮挡；宽幅连续草带减少但裸土空旷更突出。山体平滑偏蓝、窗片失真、植被重复仍明显，整体写实目标未完成。
- 四组实机同机位前后对照：artifacts/realism194-validation/review.html、visual-review.md、comparison-checks.json；before为193原始截图副本且哈希核验一致，after由194导出包运行生成，截图进程退出0且PASS。入口角色(-42,0.05,44)、yaw=0、pitch=0.024994794；宽幅(17,0.05,50)、yaw=0.422853926、pitch=0.067315195；眼高1.6米。完整位置朝向见after/environment-camera-poses.json，入口近景after/west-workshop-entrance.png、宽幅after/terrain-wide.png。
- 当前预览包串行6项检查全部退出0且PASS：工坊/仓库双向角色碰撞通行、三枪108组瞄准、武器遮挡、联网状态规则、16角色单机冒烟。新增工作台前沿射线碰撞检查通过，命中z=28.505；尚未单独覆盖角色正面走向工作台。结果及原始日志见verified/functional-results.json；8份导出/截图/测试日志无error或warning，24个页面资源链接有效，46项构建哈希已保存，见verification-summary.json、artifact-integrity.json、page-log-checks.json。
- 本地预览：`./artifacts/realism194-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，图形Linux会话选择SOLO并保留相邻PCK；README.md、build.json可复核。未验证完整单局、移动目标伤害、真实双客户端联网、连续人物/换弹画面；llvmpipe截图不代表硬件GPU性能。保留全部未提交修改，未推送或发布。
- 下一步优先宽幅裸土的车辙/碎石与草地过渡、远山材质层次及建筑窗面，继续同机位截图与通行检查；随后结合第三人称人物和第一人称手部动态审阅修正比例动画，补完整单局及真实双客户端。状态continue。

### Stage195（2026-09-14）：维修场车辙、窗面雨痕与工作台实走碰撞
- 修改service_ground.gdshader：连续直线/弯曲双轮车辙、碎石边缘及中央草色带，抑制车辙处原裸土混合；宽幅正常游戏视角可清楚辨认通行路径。修改workshop_glass.gdshader增加分片老化和雨痕，world_visuals.gd调整入口补光角度与强度。窗面改善有限，仍偏实心；车辙边缘宽且模糊、中央绿带均匀、地形平坦、远山平滑偏蓝、植被重复和支撑前臂细长仍需解决，整体目标未完成。
- 同机位四组前后图：artifacts/realism195-validation/review.html、visual-review.md、comparison-checks.json。before复制194原始实机图并核验哈希，after由195导出包实机生成，截图进程退出0且PASS。入口(-42,0.05,44)、yaw=0、pitch=0.024994794；宽幅(17,0.05,50)、yaw=0.422853926、pitch=0.067315195；眼高1.6米。完整相机记录after/environment-camera-poses.json，入口after/west-workshop-entrance.png、宽幅after/terrain-wide.png。
- 六项检查全部退出0且PASS：工坊/仓库双向角色通行、三枪108组瞄准、武器遮挡、联网状态规则、16角色单机冒烟。新增工作台实际前进阻挡检查：角色从(-46.9,0.3,30.5)移动至z=28.88544停止，与前沿射线z=28.505吻合；立柱/货架阻挡保留。详见verified/functional-results.json与原始日志、verification-summary.json。8张1280×800图片、24个页面链接、50项构建哈希已核验；8份导出/截图/测试日志无error或warning。
- 本地预览：`./artifacts/realism195-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，图形Linux会话选择SOLO并保留相邻PCK；README.md和build.json可复核。规则/冒烟不替代完整单局、移动目标伤害和真实双客户端；连续人物/换弹实机审阅及硬件GPU性能尚未覆盖。保留所有未提交修改，未推送或发布。
- 下一步：优先加强近景植被体积和疏密、远山/地表层次及建筑窗片真实感，继续相同机位对照与建筑通行；随后第三人称人物与第一人称手部动态审阅，补完整单局及真实双客户端。状态continue。

### Stage196（2026-09-15）：入口混凝土与宽景车辙过渡修正
- 修改 service_ground.gdshader、warehouse_concrete.gdshader、workshop_glass.gdshader 与 world_visuals.gd：减弱连续发白车辙边缘，增加断续土石色及草色过渡；入口混凝土降低重复细纹/法线强度，增加低频养护色差与通行磨暗；窗片增加框边遮暗并调整入口补光。入口地面与宽景路径有可见改善，窗片改善有限且仍像不透明色板；混凝土偏平滑、重复植被、平滑蓝色山体和细长折角前臂仍明显，整体目标未完成。
- 四组相同机位前后实机图：artifacts/realism196-validation/review.html、visual-review.md、comparison-checks.json。before 为195原始截图副本并核验哈希；after 来自196导出PCK，截图进程退出0且PASS。入口(-42,0.05,44)、yaw=0、pitch=0.024994794；宽景(17,0.05,50)、yaw=0.422853926、pitch=0.067315195；眼高1.6米，1280×800。完整机位见 after/environment-camera-poses.json，近景 after/west-workshop-entrance.png、after/depot-entrance-close.png，宽景 after/terrain-wide.png。
- 当前包六项串行检查全部退出0且PASS：工坊/仓库双向物理通行与工作台等阻挡、三枪108组瞄准、武器遮挡、联网状态规则、16角色单机冒烟。见 verified/functional-results.json、原始日志及 verification-summary.json。8张PNG、全部页面资源链接、50项构建哈希核验通过；7份截图/功能运行日志无ERROR/WARNING，见 page-log-checks.json、artifact-integrity.json；git diff --check通过。
- 首次使用相邻旧PCK的程序导出失败，缺脚本并生成不可用小包，日志保留在 failed-first-export/；改用无相邻PCK的独立引擎重新编辑器导出，当前PCK为190117584字节且实机验证通过。export.log仍保留26条headless纹理导入错误，未声明导出无错误。
- 本地预览：`./artifacts/realism196-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，图形Linux会话选择SOLO并保留相邻PCK；README.md及build.json可复核。截图固定模拟状态，冒烟/规则测试不能替代自然完整对局、移动目标伤害或真实双客户端；连续人物/换弹与硬件GPU性能仍未覆盖。保留所有未提交修改，未推送或发布。
- 下一步按最新环境审阅优先级转入完整前臂/袖口轮廓和第三人称动作，结合腰射、ADS、换弹20/50/80%实机帧纠正比例及动画，不再整轮微调枪械小零件；保留环境余项与完整单局、真实双客户端验证。状态continue。

### Stage197（2026-09-15）：前臂长度约束与阔叶轮廓，环境固定机位复核
- 按196交接修正第一人称左前臂静态长度至0.518米（右0.519米），加厚袖子截面；四段烘焙动画及运行时换弹通过移动肘端保持骨长，取消伸缩。阔叶增至12段曲面并加入叶柄、弯曲、不对称，每株7叶336三角形；重建Blender/GLB并导出197包。袖子折角减轻但透视中仍长、手套缺指节，植被仍色彩单一；本轮未改建筑/光照，不代表整体画质合格。
- 四组196→197同机位实机前后图及入口/宽景：artifacts/realism197-validation/review.html、visual-review.md、same-camera-audit.json。位置朝向见before/after/environment-camera-poses.json；工坊入口(-42,0.05,44)、yaw0/pitch0.024994794，宽景(17,0.05,50)、yaw0.422853926/pitch0.067315195，眼高1.6米。Forward+ llvmpipe 1280×800，不能作为硬件性能测试。
- 六项功能全部退出0且PASS：工坊/仓库双向通行及工作台等阻挡、三枪108组瞄准、武器遮挡、网络状态规则、16角色单机冒烟。新增换弹183次接触/594次骨长采样及6类中断通过，资产4段动画968次采样最大骨长误差0.00000012米。见verified/functional-results.json、reload_contact_rules.log、forearm_asset_rules.log；verification-summary.json核验24张PNG和44个页面链接，scoped git diff --check通过。
- 动作实机仅首枪AR30腰射/ADS/射击与离散换弹；action-timeline/0246-reload-0.png无RELOADING、30/119、左手回握。阶段交接时主动终止本轮捕获，退出143，无最终动作JSON，不记整套通过；另外两枪及第三人称尚未覆盖。不能以离散帧和骨长断言证明连续动作自然。
- 本地预览：`./artifacts/realism197-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，图形Linux选择SOLO，保留相邻PCK；README.md/build.json提供说明与哈希。实机已启动；导出退出0但日志有渲染线程finalize错误/ObjectDB退出警告，Blender曾修复手网格重复面。真实双客户端、自然完整一局及硬件GPU帧率仍待验证。保留所有未提交修改，未推送/发布。
- 下一步按最新VISUAL_REVIEW_ENVIRONMENT_PRIORITY：优先院落—道路—草地交界的可见地表结构，先识别meadow_ground/service_ground覆盖关系，再增加浅排水/压实路径/边缘碎石落叶，保留入口通行并做同机位对照；继续手套/袖口、第三人称及其他枪型动态审阅，补完整单局和真实联网。状态continue。

### Stage198（2026-09-15）：维修棚路径土石边缘与实际通行修正
- 在维修棚外路径两侧增加浅土石网格、岩土法线及400个碎石实例。初版白石和凸起土带过强；缩小压暗后实际横穿暴露碰撞阻塞，最终埋入边缘/端部并修正三角形朝向。失败图与日志保留 initial-review/、collision-review/，中断检查不计通过。本轮未新增建筑或光照实现，连续棕色带与近似等距碎石仍显人工，整体目标未完成。
- 197→198四组同机位前后图已保存并逐张审阅：artifacts/realism198-validation/review.html、visual-review.md、same-camera-audit.json；入口近景 after/depot-entrance-close.png，宽景 after/terrain-wide.png。位置朝向见 before/after/environment-camera-poses.json：宽景(17,0.05,50)、yaw0.422853926/pitch0.067315195，仓库入口(35,0.05,44)、yaw0/pitch0.024994794，眼高1.6米。基准为197原始PNG，哈希及相机一致；Forward+ llvmpipe 1280×800。
- 新增 tests/service_lane_traversal_review.gd：站立/蹲伏/机器人，横穿、弯道、两端及棚入口5路线双向实际移动30/30通过，导航就绪、bot最高卡住时间0。连同工坊/仓库通行、三枪108组瞄准、武器遮挡、网络状态规则、16角色单机冒烟共7项退出0且PASS，见 verified/functional-results.json、service-lane-traversal.json。网络状态规则不等于真实联网对局。
- 最终四张截图均保存且日志CAPTURE_PASS；外层运行器退出143，未取得截图子进程退出码，不记正常退出，详见 verified/capture-process-audit.json。verification-summary.json 核验预览/源文件哈希与四组相机；scoped git diff --check通过。退出原因未确认，保留原始日志。
- 本地预览：`./artifacts/realism198-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，图形Linux选择SOLO，保留相邻PCK；README.md/build.json提供运行说明与哈希。最终包已用于上述实机图与测试，未推送/发布。
- 下一步优先打断连续土带，弯道内外不同宽度沉积、裸露段与草簇交错、局部碎石簇；随后处理仓库坡板/地坪轮迹磨耗、门槛接缝、箱脚接触及光照，保持净空与通行。继续长袖/手指、第三人称和三枪连续动作审阅，补自然完整单局、真实双客户端和硬件性能验证。状态continue。


### Stage199（2026-09-15）：断续土石沉积、草簇与入口地坪磨耗
- 修改world_visuals.gd，将维修棚连续土带改为变宽沉积/裸露段，减少规则碎石并在间隙加入阔叶/细草；保留实际网格碰撞与3.4米中心净空。world.gd与warehouse_concrete.gdshader增加坡板边缘积污、接缝、地坪轮迹及箱脚接触色。本轮未改光照。宽景人工边框感减轻，但土堆仍规则、石块偏黑，磨耗偏模糊，建筑大平面、空旷地面和光照层次仍需改善，整体目标未完成。
- 四组198→199相同机位实机前后图及逐张审阅：artifacts/realism199-validation/review.html、visual-review.md、same-camera-audit.json。before为198原始PNG且核验哈希；after来自199导出包，Forward+ llvmpipe 1280×800。仓库入口(35,0.05,44)、yaw0/pitch0.024994794；宽景(17,0.05,50)、yaw0.422853926/pitch0.067315195，眼高1.6米，完整朝向见after/environment-camera-poses.json。近景after/depot-entrance-close.png，宽景after/terrain-wide.png。
- 七项检查全部退出0且PASS，见verified/functional-results.json：路径站立/蹲伏/机器人五路线双向移动30/30、工坊与仓库通行/阻挡、三枪108组瞄准、武器遮挡、网络状态规则、16角色单机冒烟。仓库移动检查为x23.5门，截图为x35门；不混称同门专项验证。网络规则不等于真实双客户端，冒烟不等于自然完整一局。
- 截图进程正常退出0，摘要标记ENVIRONMENT_REVIEW_CAPTURE_PASS frames=4，见capture-process-audit.json；导入/导出退出0，十份导入/导出/运行日志未检出ERROR/WARNING。verification-summary.json及build-hash-audit.json核验三份源码和预览exe/PCK哈希；源码范围git diff --check通过。
- 本地预览：`./artifacts/realism199-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，图形Linux选择SOLO并保留相邻PCK；README.md/build.json提供说明与哈希，当前包已用于上述实机验证。未推送/发布，保留所有未提交修改。
- 下一步优先光照层次、建筑体块/入口接触细节、地面与植被分布，继续正常机位前后对照与物理通行，避免整轮微调磨耗材质；结合第三人称、第一人称手部及三枪连续动作审阅补余项，并验证自然完整单局、真实双客户端和硬件GPU性能。状态continue。


### Stage200 — 仓库入口、雨棚边缘植被与日照（继续，整体未完成）
- 在仓库正门四米开口外增加带基座的折边防撞护角，在雨棚外侧增加固定种子的细草/阔叶草簇；日光 1.16→1.24、Forward+ 环境光 0.34→0.28，启用低强度 SSIL。
- 实机审阅：入口护角明显可辨，雨棚边缘植被局部增加；宽幅地表仍重复且空旷，护角材质仍偏混凝土，室内箱体重复，光照改善较小。不能作为整体画质完成。对照及详细局限：`artifacts/realism200-validation/review.html`、`visual-review.md`；入口/地形原图位于 `after/`。
- 四组相同相机：车间接近 (-17,.05,49), yaw/pitch 1.030377/.073611；车间入口 (-42,.05,44), 0/.024995；仓库入口 (35,.05,44), 0/.024995；宽幅地形 (17,.05,50), .422854/.067315；眼高 1.6，1280×800。精确值见 `artifacts/realism200-validation/after/environment-camera-poses.json`，基线 stage199 原图与机位一致性审计通过。
- 七项验证最终通过：道路、车间、仓库胶囊通行，三武器瞄准 108 样本、武器遮挡、联网状态规则、离线烟测。新增仓库正门与雨棚各双向实际移动及两侧护角射线；首次测试类型推断解析错误已修正，初次失败与独立通过重跑均留档。最终依据 `artifacts/realism200-validation/verification-summary.json` 和 `verified/functional-results.json`。
- 本地预览已导出并用于实机捕获：`artifacts/realism200-preview/Linux/IronMeridian`（相邻 pck 必须保留）；运行命令 `./artifacts/realism200-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，选择 SOLO。说明和哈希见预览 README.md、build.json。无外部发布。
- 下一步：继续改善宽幅机位中的地表材质和建筑轮廓差异、修正护角材质；保留三武器连续动作/第一人称手部与第三人称人物审阅、真实双客户端主要功能验证。软件 Vulkan 本轮截图不证明硬件帧时，联网规则测试不等于双客户端比赛。

### Stage201 — 仓库护角材质、雨棚排水与地表尺度（继续）
- 修正仓库护角的通用石材覆盖，恢复黄黑涂装；雨棚落水管改为连续三段，外缘增加碎石和细草；缩小服务区/草地土壤纹理尺度。保留 stage200 光照设置，本轮未声称新增光照收益。
- 四组正常机位前后对照已实机审阅：`artifacts/realism201-validation/review.html`、`visual-review.md`；原图在 before/、after/。基线为 stage200 原图，字节及相机一致性通过。机位位置/yaw/pitch：接近(-17,.05,49)/1.030377/.073611，车间入口(-42,.05,44)/0/.024995，仓库入口(35,.05,44)/0/.024995，宽景(17,.05,50)/.422854/.067315；眼高1.6，精确值见 after/environment-camera-poses.json。
- 入口黄黑护角与宽景雨棚管道连接可辨；地面仍糊、阔叶形态平板、草地边界突兀、建筑与箱体重复。碎石细草在宽景中贡献有限，整体画质未达目标。
- 七项检查均通过：道路/车间/仓库实际胶囊通行，三枪瞄准108样本，武器遮挡，联网状态规则，16角色离线烟测。仓库入口及雨棚双向通行、护角碰撞通过；四帧捕获退出0，十份日志无 ERROR/WARNING，源码和预览哈希一致。证据：`artifacts/realism201-validation/verification-summary.json`、`verified/functional-results.json`。
- 当前本地预览已导出并用于上述验证：`./artifacts/realism201-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，保留相邻PCK，图形界面选择SOLO；README.md/build.json说明与哈希齐备。保留未提交修改，无外部发布。
- 下一步：优先宽景草簇轮廓/分布过渡与建筑体块差异，继续同机位对照和物理通行；补齐第三人称、三枪/手部连续动作、自然完整单局和真实双客户端验证。当前网络规则不代表双客户端比赛，软件Vulkan不代表硬件性能。状态continue。


### Stage202 — 仓库雨棚结构、局部照明与前景植被（continue）
- 修改 `client/scripts/world_visuals.gd`：雨棚边梁/纵向支撑、两组暖光灯具；缩小两组林下阔叶并压低细草，宽景入口前草丛保留率 0.12→0.42。实际宽景可辨认棚底结构和灯具，雨棚近景能看到局部暖色反射；非全场画质完成。
- 同机位 stage201/202 对照、入口近景与宽幅地形：`artifacts/realism202-validation/review.html`；4 个常规机位及额外雨棚机位均记录位置、目标与 yaw/pitch，见 `after/environment-camera-poses.json`、`after-canopy/environment-camera-poses.json`。逐张结论：`visual-review.md`。入口通道画面保持畅通，车间接近画面的收益有限；大叶片、模糊裸土、重复建筑/箱体与细长袖管仍明显。
- 7 项打包预览检查通过：服务通道、车间通行、仓库/雨棚通行与碰撞、108 样本瞄准、武器遮挡、联网状态规则、单机 smoke。日志与哈希/相机审计：`artifacts/realism202-validation/verification-summary.json`、`verified/functional-results.json`。联网规则不代表真实双客户端；软件 Vulkan 不代表硬件性能。
- 本地预览：`artifacts/realism202-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，选择 SOLO；保留相邻 PCK。release 模板缺失已留失败日志，采用成功 export-pack + 本机 Godot 引擎组成预览，实际启动捕获/验证通过；README 与 build.json 记录方式和哈希。未提交、未推送、未发布，保留原有修改。
- 下一步：处理 `depot_loading_area()` 独立棚脚组仍偏大的平面阔叶（当前统一 0.75–1.35 缩放），改善裸土地表尺度和重复建筑轮廓，复查偏亮灯罩；随后继续第三人称人物及第一人称手部连续动作、真实双客户端主要功能验证。按当前环境优先级选择性整合 Android fix4 启动/预算分支，避免覆盖桌面改进；整体目标未完成。

### Stage203 — 仓库屋面、定向棚灯与棚脚植被（continue）
- `world_visuals.gd` 缩小仓库独立棚脚阔叶/细草，降低灯罩自发光并将棚灯改为向下聚光；新增 `depot_roof.gdshader` 压型板纹理，调整 `meadow_ground.gdshader` 入口磨损路线和碎石颗粒。实机雨棚屋面过亮暖斑消失，板纹和缩小植被可辨；灯罩仍偏白，宽景收益有限，裸土仍糊，尖片树枝、重复建筑与细长袖管未解决。
- stage202→203 五组原始实机同机位对照（含建筑入口和宽幅地形）：`artifacts/realism203-validation/review.html`；逐张审阅 `visual-review.md`，精确位置、目标、yaw/pitch 与原图 SHA256 见 `same-camera-audit.json`。全部相机一致，未用截图数量认定整体画质。
- 7 项打包预览回归通过：服务道路30条双向/姿态路线、车间通行、仓库中央门洞/雨棚双向通行及防撞柱射线、三枪108样本瞄准、武器遮挡、联网状态规则、16角色单机 smoke。证据：`artifacts/realism203-validation/verified/functional-results.json`、`verification-summary.json`；导入、打包、捕获和测试日志未检出 ERROR/WARNING。仓库测试未覆盖全部门边及蹲行/机器人入库；联网规则不等于真实双客户端比赛。
- 当前本地预览：`./artifacts/realism203-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，选择 SOLO，保留相邻 PCK。采用本机 Godot 引擎 + export-pack（无 Linux release 模板）；README/build.json 记录方法和哈希，实际启动捕获及回归通过。软件 Vulkan 不代表硬件 GPU 性能。保留原有未提交修改，未推送/发布。
- 下一步：优先修改近景 `fir_full` 尖片枝叶与车间大阔叶资产、提高裸土地表尺度可信度并拉开建筑轮廓差异，继续正常机位对照和门边碰撞验证；随后结合第三人称人物、第一人称手部/袖管与三枪连续动作审阅，补真实双客户端主要功能验证。Android fix4 保持独立待整合；整体目标未完成。

### Stage204 — 西车间维修棚、植被尺度与定向照明（continue）
- 维修棚增加坡屋面压型板着色、檐槽与雨水管，顶灯改为向下聚光；重建较小窄叶阔叶草资产，棚前草丛加密并修正缩放。正常接近机位可辨认过大平面叶片减少；维修棚近景板纹、排水构件与局部照明可辨，旧棚顶暖色高光斑消失。棚内工作台/柱体仍块状，宽景裸土模糊、重复棚屋、尖片树冠及山体棱面仍明显，整体目标未完成。
- 同机位前后、建筑入口近景和宽幅地形原始实机证据：`artifacts/realism204-validation/review.html`、`visual-review.md`；位置、目标、yaw/pitch 和原图哈希见 `same-camera-audit.json`。常规及仓库雨棚基线来自 stage203 原图；新增维修棚基线使用 stage203 PCK 与同一相机脚本实际重拍。
- 7 项打包预览验证通过：服务道路、车间/维修棚、仓库入口/雨棚通行，三枪108样本瞄准，武器遮挡，联网状态规则，16角色单机 smoke。新增维修棚实际角色双向通行和屋面/檐槽/雨水管射线碰撞检查。证据：`artifacts/realism204-validation/verified/functional-results.json`、各项 `.log`、`verification-summary.json`、`audit.log`。相机一致性与构建哈希校验通过；联网规则不等于真实双客户端，通行测试未覆盖全部门边/姿态。
- 导入退出0但有 dummy renderer `Parameter "t" is null` 错误，保留 `import.log`；打包、实机捕获和7项验证日志无 ERROR/WARNING。当前本地预览：`./artifacts/realism204-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，选择 SOLO，保留相邻 PCK；README/build.json 记录引擎+export-pack 方法与哈希。软件 Vulkan 不代表硬件性能。保留原有未提交修改，未推送/发布。
- 下一步：优先改善宽景裸土地表纹理尺度、近景尖片树冠和重复棚屋轮廓，并继续入口门边/蹲行验证；结合第三人称人物、细长第一人称袖管和三枪连续动作进行实机审阅，补真实双客户端主要功能。Android fix4 仍待独立评估整合。


### Stage205 — 圆顺山脊与地表颗粒校正（continue）
- 山体横断面改为 smoothstep，正常接近与宽景机位的尖折轮廓变圆顺；两种地面着色器降低颗粒频率、过滤边缘并增加不规则分布，弃用亮色圆粒过多的初稿。保留 stage204 建筑/植被/灯光改进。本阶段地面收益有限，均匀光滑山面、模糊裸土、重复尖片树冠和积木化棚内构件仍明显，未达到整体画质目标。
- 四组 stage204→205 同机位原始实机前后对照含车间/仓库入口及宽幅地形：`artifacts/realism205-validation/review.html`；逐图评价见 `visual-review.md`，精确位置、目标、yaw/pitch、尺寸及哈希见 `same-camera-audit.json`。
- 七项回归通过：道路通行、车间/维修棚通行与构件碰撞、仓库入口/雨棚通行、防撞柱射线、三枪108样本瞄准、武器遮挡、联网状态规则、16角色单机 smoke（通行项目各合计为一项）。执行于初稿 PCK，最终版游戏脚本和测试文件哈希完全一致，仅两种地面着色器随后修改；最终 PCK 另行 smoke 正常退出0。证据：`verified/functional-results.json`、`final-smoke.json`、`verification-summary.json`、`audit.log`（均位于 realism205-validation）。联网规则不等于双客户端实测，尚未覆盖所有门边姿态。
- 最终截图日志完成四张并输出 PASS，但包装进程退出143、引擎退出码未知，原因待查；没有将其记为干净退出。导入退出0但 dummy renderer 有 Parameter "t" is null。误用相邻旧 PCK 导出的小包已弃用并保留 failed-pack-attempt；最终由独立引擎重新导出，哈希核验通过。详细异常与验证范围见 `visual-review.md`。
- 当前可运行本地预览：`./artifacts/realism205-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，选择 SOLO；保留相邻 PCK。README/build.json 记录方法、哈希与限制。软件 Vulkan 不代表硬件性能；保留全部原有修改，未推送/发布。
- 下一步：优先近景尖片树冠、建筑轮廓差异和入口地面尺度，继续正常机位审阅，复查截图进程退出并补门边蹲行；结合第三人称人物、第一人称袖管与三枪连续动作安排缺陷修复，补真实双客户端主要功能。Android fix4 仍待独立整合；整体目标未完成。


### Stage206 — 针叶树近景几何修正与最终包复验（continue）
- 将近景针叶树的大三角叶片改为更短、更窄的径向针叶，增加枝梢分布并重新生成远景 billboard；建筑、地表和光照继承 stage205。本轮实机可辨识的主要收益是消除夸张扇片，不代表环境整体达标：树枝层次仍规律、树冠偏稀，地面模糊空旷、远山光滑、建筑及室内构件重复仍明显。
- 五组相同正常机位的 stage205→206 原始前后截图，覆盖车间接近、车间入口、仓库入口、宽幅地形和近景树林：`artifacts/realism206-validation/review.html`。精确位置、朝向、尺寸与哈希见 `same-camera-audit.json`，逐图评价见 `visual-review.md`。最终捕获正常退出0、5帧 PASS；基线捕获外层退出143、引擎退出未知，未记为干净退出。
- 最终预览包七项验证全部退出0并通过：道路通行、车间/维修棚通行、仓库入口/雨棚通行及护柱碰撞、三枪108样本瞄准、武器遮挡、联网状态规则、16角色单机 smoke。证据：`artifacts/realism206-validation/verified/functional-results.json` 和各项日志。中途外层会话中断的联网日志单独保留，剩余检查已重跑成功；联网规则不等于真实双客户端，通行未覆盖所有门边和姿态。
- `verification-summary.json` 核验7项构建哈希、7项测试、5组相机一致性及最终截图退出状态通过。Blender 构建退出0；针叶细化使树资产达到410564多边形、1248576顶点，存在几何开销，未声明硬件帧率改善。导入退出0但保留 dummy renderer Parameter "t" is null 日志。
- 当前本地预览：`./artifacts/realism206-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，选择 SOLO，保留相邻 PCK；需要图形桌面/Vulkan。README/build.json 记录预览与哈希。保留原有未提交修改，未推送或发布。
- 下一步：实施建筑轮廓差异、入口地表纹理尺度和连续地被的一组环境改进，继续同机位宽景及入口审阅；优化针叶树几何/LOD并补入口门边蹲行。之后结合第三人称人物、第一人称袖管及三枪连续动作实机审阅安排修复，并补真实双客户端主要功能；整体目标未完成。

### Stage207 — 厂房坡屋顶、通道地被与入口补光（continue）
- 两座厂房通风楼增加双坡金属屋面、屋脊、檐边和山墙，结构碰撞匹配斜面；维修通道边缘增加成组混合阔叶/细叶草，保留中央通路；提高车间入口局部补光。正常接近和宽景可辨认屋顶轮廓、右侧更密地被，入口补光收益较小。裸土模糊、远山光滑、建筑和箱体重复、树枝机械及袖管膨胀仍明显，整体目标未完成。
- 五组 stage206→207 同机位实机前后对照：`artifacts/realism207-validation/review.html`，含车间接近、两处建筑入口、宽幅地形及树林近景；已逐图审阅。`same-camera-audit.json` 保存精确位置、朝向、尺寸与哈希，`visual-review.md` 记录收益及缺陷；最终软件 Vulkan 捕获5帧 PASS、进程正常退出0。
- 最终包七项测试全部通过并退出0：道路、车间、仓库通行与碰撞，三枪108样本瞄准，武器遮挡，联网状态规则，16角色单机 smoke。车间新增两座厂房共四处坡屋顶射线，验证可见斜面命中高度。证据：`artifacts/realism207-validation/verified/functional-results.json` 及对应日志；联网规则不等于真实双客户端实测，尚未覆盖所有门边蹲行。
- 导入、导出退出0；`artifacts/realism207-validation/verification-summary.json` 核验7项构建哈希、测试、同机位及最终捕获状态通过。当前本地预览：`./artifacts/realism207-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，选择 SOLO，保留相邻 PCK，需要图形桌面/Vulkan。运行说明与哈希见预览目录 README.md/build.json；软件渲染不证明硬件性能。保留全部未提交修改，未推送或发布。
- 下一步：优先入口和通路地面纹理尺度、连续地被及针叶树几何/LOD，补入口门边蹲行；再结合第三人称人物、第一人称袖管与三枪连续动作实机审阅安排修复，补真实双客户端主要功能。Android fix4 仍待独立整合。

### Stage208 — 维修通路连续低草与碎石显露（continue）
- 提高通路边缘细叶草密度与横向覆盖，降低阔叶占比和草高，增加碎石并修正埋入地表的问题。正常宽景可辨认连续草带、碎石及保留的中央通路；碎石仍有人工铺排感，裸土模糊。本轮建筑与入口补光沿用207，仅做回归，不计新增提升；树林机械枝条、重复箱体、平滑地坪和过长袖管仍明显。
- 同机位207→208对照及入口、宽景、树林原图：`artifacts/realism208-validation/review.html`；相机位置与朝向见 `same-camera-audit.json`，逐图评价见 `visual-review.md`。首次截图退出143且原因未知，保留 `capture-interrupted.log`；重拍五帧PASS并正常退出0，见 `capture-process-audit.json`。软件Vulkan截图不证明硬件帧率。
- 最终包七项验证退出0且通过：30条道路站立/蹲行/机器人路线、车间和仓库通行/碰撞及坡屋顶射线、三枪108样本瞄准、武器遮挡、联网状态规则、16角色单机smoke。证据：`artifacts/realism208-validation/verified/functional-results.json`；`verification-summary.json`核验7项哈希、测试和同机位/捕获状态通过。联网规则不是实际双客户端测试，门边姿态尚未穷尽。
- 本地预览：`./artifacts/realism208-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，选择SOLO，需要图形桌面/Vulkan，保留相邻PCK；说明与哈希见该目录README.md/build.json。保留全部未提交修改，未推送、发布或部署。
- 下一步：继续环境优先，改进裸土纹理尺度、碎石自然分布和针叶树轮廓/LOD，补门边蹲行及建筑材质差异；随后结合第三人称人物、第一人称袖管与三枪动作实机审阅修复，并验证真实双客户端主要功能。Android fix4仍待独立整合，整体目标未完成。

### Stage209 — 降低路肩石带与细化地面尺度（continue）
- 将维修通路沉积网格降低到最高约3厘米并复用周围地面材质；缩小、外移和分散碎石，去除偏橙着色；同步细化地面碎石颜色/法线采样并增加土块变化。正常宽景中的凸起橙色石带明显减弱，路肩衔接更自然；裸土仍偏平偏糊。草丛布局、建筑与光照沿用208，本轮不计新增建筑或光照成果。
- 五组208→209同机位原图、建筑入口近景和宽幅地形实机对照：`artifacts/realism209-validation/review.html`；相机位置/朝向见`same-camera-audit.json`，逐图审阅见`visual-review.md`。Forward+软件Vulkan捕获5帧PASS并退出0。林地近景针叶三角片、僵硬枝条和过密遮挡仍明显，建筑重复、平滑地坪、袖管膨胀也未解决。
- 最终包七项测试全部退出0且PASS：道路30次站立/蹲行/机器人移动、车间及仓库通行/碰撞与坡屋顶射线、三枪108样本瞄准、武器遮挡、联网状态规则、16角色单机smoke。原始日志见`artifacts/realism209-validation/verified/`；`verification-summary.json`核验8项哈希、测试及相机/捕获状态通过。联网规则不能替代真实双客户端测试，软件渲染不证明硬件帧率，门边姿态仍待补测。
- 本地预览：`./artifacts/realism209-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，选择SOLO，需要图形桌面/Vulkan并保留相邻PCK。说明与哈希见该目录README.md/build.json；保留全部未提交修改，未推送、发布或部署。
- 下一步：优先近景针叶树冠轮廓、枝叶密度及LOD，再改善裸土层次、建筑材质差异和入口光照，补门边蹲行；随后结合第三人称人物、第一人称袖管与三枪连续动作实机审阅修复，完成真实双客户端主要功能验证。Android fix4仍待独立整合，整体目标未完成。

### Stage210 — 针叶侧枝不规则化与减面，环境目标继续（continue）
- 侧枝改为轻微弯曲、独立随机分布及短分叉，重建GLB/远景图/Blender源；多边形410564→354332（-13.7%）。初版树冠过稀已淘汰并留存`rejected-sparse/`，最终恢复针叶面积后重新导出。近景成对鱼骨重复有所减弱，但大三角针叶、粗直主枝、层状树冠仍明显，不能称树木或整体画质达标。本轮建筑和光照仅回归，未计新增改善。
- 五组209→210同机位实机对照、入口近景及宽景：`artifacts/realism210-validation/review.html`；相机位置/朝向见`same-camera-audit.json`，逐图评价与局限见`visual-review.md`。最终Forward+软件Vulkan捕获退出0/PASS。
- 初版包七项测试通过（道路、车间/仓库通行碰撞、三枪108样本瞄准、遮挡、联网状态规则、单机）；版本见`verified/tested-initial-build.json`。最终仅改针叶覆盖，另通过16角色单机烟测`final-smoke.json`和完整截图；`verification-summary.json`核验最终12项哈希、版本化测试和相机通过。联网规则不代替真实双客户端，门边蹲行未穷尽，软件渲染不证明硬件帧率。
- 本地预览：`./artifacts/realism210-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，选择SOLO，需要图形桌面/Vulkan并保留相邻PCK；说明/哈希见该目录README.md/build.json。保留全部未提交修改，未推送、发布或部署。
- 下一步：落实建筑窗面、入口光照和地坪材质差异，补门边蹲行；再修正近镜针叶/主枝实例尺度和裸土层次。继续第三人称人物、第一人称袖管与三枪连续动作审阅及真实双客户端验证。Android fix4仍待独立整合，整体目标未完成。

### Stage211 — 车间窗面、入口补光与地坪细化（continue）
- 修正窗面污迹采用物理窗面坐标，增加外侧下窗通风百叶及对应碰撞，增强入口反弹/地坪补光，并细化混凝土地坪颗粒与板间色差。入口窗格污迹排列更合理，地坪与光照改善较小，百叶在远景辨识度有限；玻璃仍为不透明近似反射。本轮没有新增植被改善，宽幅地形基本不变，不能判定整体画质达标。
- 五组210→211同机位实机对照、建筑入口近景及宽景：`artifacts/realism211-validation/review.html`；位置/朝向见`same-camera-audit.json`，逐图评价见`visual-review.md`。before复用210最终原图并记录来源/哈希，after最终包Forward+软件Vulkan捕获5帧PASS/退出0。近镜针叶三角片、粗直枝条、平坦空旷裸土和膨胀袖管仍明显。
- 最终包七项测试退出0/PASS：道路通行、车间/仓库碰撞通行、三枪108样本瞄准、武器遮挡、联网状态规则、16角色单机smoke。车间含11条路线/阻挡记录、34条射线，新增门口两侧各双向蹲行共4条通过。日志见`artifacts/realism211-validation/verified/`；`verification-summary.json`核验7项构建/源文件哈希、5组相机与图像、测试/截图通过，日志问题0。联网规则不代替真实双客户端，软件渲染不证明硬件帧率。
- 本地预览：`./artifacts/realism211-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，选择SOLO，需要图形桌面/Vulkan并保留相邻PCK；说明/哈希见该目录README.md/build.json。保留全部未提交修改，未推送、发布或部署。
- 下一步：优先修正近镜针叶面片/主枝尺度与树冠轮廓，再改善正常宽景裸土地表层次与植被分布；继续第三人称人物、第一人称袖管和三枪连续动作实机审阅，完成真实双客户端主要功能验证。Android fix4仍待独立整合，整体目标未完成。


### Stage212 — 针叶尺度与弯曲主枝，环境目标继续（continue）
- 主枝由粗直两段改为六段弯曲渐细，侧枝变细；针叶改为细长渐尖面并增加侧枝覆盖，重建GLB、远景图和Blender源。近镜大三角针叶和粗直尖刺感减弱，但层状树冠、棱面树干及锯齿仍明显。第一版过稀已淘汰，源码/截图/初次超时记录保留在`rejected-thin-canopy/`。本轮建筑和光照仅回归，宽幅裸土仍平坦，不能判定整体画质达标。
- 五组211→212同机位对照、建筑入口近景及宽幅地形实机图：`artifacts/realism212-validation/review.html`；位置/朝向及图像哈希见`same-camera-audit.json`，逐图评价见`visual-review.md`。before复用211最终原图并记录来源，after最终包Forward+软件Vulkan捕获5帧PASS/退出0。
- 最终包七项测试全部退出0/PASS：道路30次通行、车间11条路线/阻挡及34条射线（含4条门边双向蹲行）、仓库入口/雨棚通行与防护碰撞、三枪108样本瞄准、武器遮挡、联网状态规则、16角色单机烟测。日志见`artifacts/realism212-validation/verified/`；`verification-summary.json`核验10项构建哈希和5组同机位图像通过。`log-audit.json`保留导入阶段dummy纹理空参数错误1条（尚未修复），最终导出/截图/功能日志无ERROR标记，不能称日志零问题。
- 本地预览：`./artifacts/realism212-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，选择SOLO，需要图形桌面/Vulkan及相邻PCK；说明/哈希见该目录README.md/build.json。软件渲染不能证明硬件帧率，联网规则不代替真实双客户端；保留全部未提交修改，未推送、发布或部署。
- 下一步：优先正常宽景的裸土实体层次和植被分布，避免继续局限于针叶微调；结合第三人称人物、第一人称长袖管与三枪连续动作实机审阅修复，补真实双客户端主要功能验证。Android fix4仍待独立整合，整体目标未完成。


### Stage213 — 维修场裸土碎石与低草分布（continue）
- 南侧维修场增加嵌地细碎石和噪声分布低草，保留车辆/装卸通道净空，不增加碰撞体。首版碎石过白过密，实机审阅后淘汰；最终降低密度与尺度、改暗土色并重新构建、截图和测试。淘汰证据保留在`artifacts/realism213-validation/rejected-white-aggregate/`。宽景裸地增加可辨识的碎石与低草，但底材仍模糊、地形仍平、草带和树木重复明显；建筑与光照本轮仅回归，不计新增改善。
- 五组212→213同机位前后图、车间/仓库入口近景与宽幅地形实机图：`artifacts/realism213-validation/review.html`；位置/朝向及图像哈希见`same-camera-audit.json`，逐图评价见`visual-review.md`。before复用212最终图并记录来源，after最终包Forward+软件Vulkan捕获5帧PASS/退出0。树叶面片、棱面树干、重复砖纹、均匀护柱和过长袖管仍需修正，不能判定整体画质达标。
- 最终包七项测试全部退出0/PASS：道路30次通行、车间11条路线/阻挡及34条射线（含4条门边双向蹲行）、仓库入口/雨棚通行与防护碰撞、三枪108样本瞄准、武器遮挡、联网状态规则、16角色单机烟测。日志见`artifacts/realism213-validation/verified/`；`verification-summary.json`核验11项构建/源码哈希、5组同机位图像通过。`log-audit.json`扫描最终导入/导出/截图和七项测试日志，ERROR/WARNING标记0；不据此宣称212导入问题已根治。
- 本地预览：`./artifacts/realism213-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，选择SOLO，需要图形桌面/Vulkan及相邻PCK；说明见该目录README.md，构建哈希见验证目录build.json。软件渲染不能证明硬件帧率，联网规则不替代真实双客户端。保留全部未提交修改，未推送、发布或部署。
- 下一步：改善正常游戏宽景的地表材质与起伏、建筑重复和入口光照，避免把新增散布物当作环境完成；继续第三人称人物、第一人称袖管及三枪连续动作实机审阅，完成真实双客户端主要功能验证。Android fix4仍待独立整合，整体目标未完成。

### Stage214 — 维修棚入口辨识、建筑日照与低草层次（continue）
- 维修棚雨棚正面增加“02 / VEHICLE SERVICE”标识和端部色条，增强入口灯；调整太阳方位/高度，使车间门槛、仓库通道及维修棚门板形成可辨的明暗层次；提高维修场低草高度差并增加近距土壤团粒着色。新增装饰不带碰撞。宽景入口标识改善明显，但地表仍模糊、地形平、树冠重复和针叶面片明显，植被/地表仅有限改善，整体画质未达目标。
- 六组213→214同机位实机对照（含维修棚、车间、仓库入口近景及宽幅地形）：`artifacts/realism214-validation/review.html`。五组before复用213最终原图，维修棚近景用213/214包重新捕获；相机位置/朝向、来源及哈希见`same-camera-audit.json`、`repair-same-camera-audit.json`和各截图目录的姿态JSON；逐图局限见`visual-review.md`，修改范围见`change-scope.patch`。
- 最终包七项测试全部退出0/PASS：道路30次通行（含维修棚双向站立/蹲行/冲刺）、车间11条路线及34条射线、仓库入口/雨棚通行与护柱碰撞、三枪108样本瞄准、武器遮挡、联网状态规则、16角色单机烟测。`artifacts/realism214-validation/verification-summary.json`核验12项构建/源码哈希与6组同机位证据；`verified/`保存日志，`log-audit.json`扫描12份日志，ERROR/WARNING标记0。
- 本地可运行预览：`./artifacts/realism214-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，选择SOLO，需要图形桌面/Vulkan与相邻PCK；使用说明见预览目录README.md。软件Vulkan截图不证明硬件帧率，联网规则不能替代真实双客户端。保留全部未提交修改，未推送、发布或部署。
- 下一步：优先改善正常宽景的地形起伏、裸土材质与植被分布，修正重复树冠/长条针叶，避免继续将整轮局限于标牌或单个枝叶微调；随后结合第三人称人物、第一人称长袖管与三枪连续动作实机审阅安排修复，补真实双客户端主要功能验证。Android fix4仍待独立整合，整体目标未完成。

### Stage215 — 维修场碎土与路缘草簇疏密（continue）
- 调整`service_ground.gdshader`，减弱大尺度干湿色差，加入随屏幕导数淡出的碎土棱面着色和法线；`world_visuals.gd`将路肩草带改为疏密变化，并在轮迹中央加入更矮的恢复植被，保留装卸净空、不新增碰撞体。宽景近处颗粒与草带间隔可辨，但改善有限，裸土仍模糊、场地平坦、树冠重复及长条针叶明显。建筑与光照沿用214，仅回归，不计新增改善。
- 六组214→215同机位实机对照（宽幅地形、森林及车间/仓库/维修棚入口）：`artifacts/realism215-validation/review.html`。before复用214最终图并核验来源；位置/朝向、图片哈希见`same-camera-audit.json`、`repair-same-camera-audit.json`，逐机位评价见`visual-review.md`。最终包两次截图进程共6帧PASS/退出0。
- 最终包七项测试全部退出0/PASS：道路30次通行、车间11条路线及34条射线、仓库入口/雨棚通行与护柱碰撞、三枪108样本瞄准、武器遮挡、联网状态规则、16角色单机烟测（含装填、治疗、伤害、胜利、射线及掩体）。`artifacts/realism215-validation/verification-summary.json`核验12项构建/源码哈希及6组同机位证据；原始日志在`verified/`，`log-audit.json`扫描11份最终日志，ERROR/WARNING标记0。联网规则不等于真实双客户端验证，软件Vulkan不证明硬件帧率。
- 本地预览：`./artifacts/realism215-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，选择SOLO；需要图形桌面/Vulkan和相邻PCK，说明见`artifacts/realism215-preview/Linux/README.md`。保留全部未提交修改，未推送、发布或部署。
- 下一步：做能改变正常宽景轮廓的地形与植被组合改进，并修正森林近景长条叶片，避免持续只增加细碎噪声；保留建筑重复与入口光照、第三人称人物、第一人称袖管/手部及三枪连续动作审阅，补真实双客户端主要功能验证。Android fix4仍待独立整合，整体目标未完成。

### Stage216 — 维修棚前草坡与登坡碰撞（continue）
- `world_visuals.gd`在维修棚两侧增加0.72米路肩起伏，草根、网格法线和碰撞共用高度；宽景左前坡形明显，右侧较弱，中央入口保持通畅。本轮建筑/光照沿用既有版本。坡顶偏秃、形状规整，裸土模糊与重复植被仍明显，整体目标未完成。
- 六组215→216同机位实机对照：`artifacts/realism216-validation/review.html`；相机位置/朝向、来源与图片哈希见同目录`same-camera-audit.json`、`repair-same-camera-audit.json`、`baseline-provenance.json`。已查看宽景前后、车间接近、仓库及维修棚入口，评价见`visual-review.md`。
- 最终七项测试PASS/退出0：道路42次双向站立/蹲行/bot通行（含12次新坡通行与玩家登坡高度检查）、车间/仓库入口及碰撞、三枪108样本瞄准、武器遮挡、联网状态规则、16角色单机烟测。道路测试初次类型推断失败，显式float修复后重跑通过；两份日志均保留，见`verified/functional-results.json`及`grass-bank-collision-summary.json`。`verification-summary.json`核验13项构建/源码哈希与两次截图进程PASS。
- 本地预览：`./artifacts/realism216-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，选择SOLO，需要图形桌面/Vulkan和相邻PCK。软件Vulkan不证明硬件帧率，联网规则不能替代双客户端实连。保留全部未提交修改，未推送或部署。
- 下一步：成组改善宽景坡面、裸土过渡和植被分布，减少规整土包、重复树冠与长条针叶；继续建筑重复与入口光照审阅，然后结合第三人称人物及第一人称袖管/手部和三枪连续动作修复，补真实双客户端验证。Android fix4仍待独立整合。

### Stage217 — 不对称草坡、坡面覆盖与导航到达修复（continue）
- `world_visuals.gd`将维修场路肩土包改为不对称起伏，新增疏密变化的坡面草丛，并使补种草与碎石贴合实际地表。正常宽景左坡从光滑规整土包变为有裸露间隙的草坡，右坡变化较弱；本轮建筑与灯光仅做回归，不计新增改善。针叶过长、枝干棱角、裸土模糊和第一人称长袖管仍明显，整体目标未完成。
- 六组216→217同机位对照及入口/宽景实机截图已审阅：`artifacts/realism217-validation/review.html`；before复用216最终图，来源、位置/朝向和图片哈希见`baseline-provenance.json`、`same-camera-audit.json`、`repair-same-camera-audit.json`。逐机位局限见`visual-review.md`，最终两次截图进程均PASS/退出0。
- 首轮道路测试41/42，BOT在north_end反向路线提前停步；`bot_navigator.gd`缩小精确到达调用的最终路点容差，最终道路42/42通过，登坡峰值约0.869米。按引擎提示将导航合并栅格尺度改为0.001，最终日志不再出现边缘合并错误。首轮失败及引擎错误保留于`initial-run/`，最终道路数据见`grass-bank-collision-summary.json`。
- 最终包七项测试全部PASS/退出0：道路双向站立/蹲行/BOT、车间及仓库入口通行与碰撞、三枪108样本瞄准、武器遮挡、联网状态规则、16角色单机烟测（装填/治疗/伤害/胜利/射线/掩体等）。`verification-summary.json`核验15项源码/构建哈希与六组同机位证据；`verified/`保留日志，`log-audit.json`扫描11份最终日志，ERROR/WARNING均0。联网规则不能替代真实双客户端验证，软件Vulkan不证明硬件帧率。
- 本地预览：`./artifacts/realism217-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，选择SOLO，需要图形桌面/Vulkan和相邻PCK，说明见预览目录README.md。保留所有未提交修改，未推送、发布或部署。
- 下一步：成组改善森林近景针叶形状与宽景树冠轮廓，结合建筑重复和入口光照继续实机审阅，避免持续只修路肩小区域；保留第三人称人物、第一人称袖管/手部与三枪连续动作修复，补真实双客户端主要功能验证。Android fix4仍待独立整合。

### Stage218 — 近景松树材质与枝梢更新，环境整体仍未达标
- 修改 `tools/build_branching_fir.py`：连续树皮 UV/纹理、径向法线、较细短针叶及更多枝梢；重建 GLB、远景图与 Blender 源文件。近景硬棱面减轻，但树皮波浪/拉伸、纸片针叶仍明显；宽景树群反而偏疏，不计为整体画质完成。本轮建筑/光照仅作回归，下一阶段必须推进实际改进。
- `artifacts/realism218-validation/review.html` 保存 6 组同机位前后对照，含建筑入口、维修棚和宽幅地形；前图复用 stage217 最终实机图，来源见 baseline-provenance.json；same-camera-audit.json、repair-same-camera-audit.json 保存位置朝向与哈希。实际图像审阅见 visual-review.md。
- 导出包通过 7 项回归：服务路、车间/维修棚、仓库通行碰撞，三枪 108 样本瞄准、武器遮挡、网络状态规则、16 角色单机烟测；两次截图进程 PASS。15 项构建哈希吻合。证据见 verification-summary.json 与 verified/。网络规则不替代双客户端，脚本通行不替代完整人工游玩。
- 日志审计 11 份：首次 headless 导入有 1 条 dummy texture storage 的 Parameter "t" is null，退出码 0；导出、截图及 7 项回归无错误，0 warning。保留 import.log / log-audit.json；根因未解决，不宣称全部日志零错误。
- 当前本地预览：`artifacts/realism218-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，同目录 PCK；需图形桌面/Vulkan。截图为软件 Vulkan，不代表硬件帧率。完整树 500648 面/2002592 顶点、GLB 约 73 MB，部分道路/维修场树群缺少独立 LOD。
- 下一步：成组改善正常机位树群疏密/轮廓及 LOD，同时落实建筑材质尺度与入口光照，保持同机位对照和通行回归；随后继续人物、第一人称袖管/手部/三枪动作实机审阅及真实双客户端主要功能验证。保留所有未提交修改，未推送或发布。整体状态 continue。


### Stage219 — 车间砖墙、入口补光与维修场地表植被，整体仍未达标
- 缩小车间砖块尺度并降低砖色差，添加距离衰减的砖缝倒角法线；提升车间雨棚补光范围/能量；调整土壤采样与团块对比，维修场入口两侧新增168株低草。实机砖墙棋盘感减轻，补光及宽景改善较轻；土壤仍模糊、地形平坦，建筑与树冠重复、纸片针叶/波浪树皮尚未解决。不以局部改善宣称整体完成。
- `artifacts/realism219-validation/review.html` 保存6组同机位前后图（stage218最终导出包→stage219导出包），覆盖入口近景、维修棚及宽幅地形；来源见 baseline-provenance.json，相机位置/朝向见 same-camera-audit.json、repair-same-camera-audit.json；逐项实机观察见 visual-review.md。新增植被沿用既有随机源，后续维修场树木旋转/草丛分布也改变，差异不全来自材质。
- 当前导出包7项检查全部 PASS：服务巷、车间/维修棚、仓库通行碰撞，三枪108样本瞄准、武器遮挡、联网状态规则、16角色单机烟测；2次截图进程成功，16项构建哈希一致，6组相机一致。verification-summary.json、verified/ 保存证据；log-audit.json 扫描11份日志，0错误/0警告。联网规则仍不替代实际双客户端，脚本通行不替代完整人工游玩。
- 当前本地预览：`artifacts/realism219-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，保留同目录PCK，在图形桌面选择 SOLO；README.md 有启动说明。截图使用软件 Vulkan，不能宣称硬件帧率达标。
- 下一步：优先解决近景纸片针叶/树皮和重复树冠、补独立LOD，并成组改善宽景地形/建筑层次；植被改用独立固定随机源。继续相同机位与通行回归，再推进第三人称人物、第一人称手部/三枪动作和真实双客户端主要功能验证。所有未提交修改保留，未推送/发布。整体状态 continue。

### Stage220 — 维修区低灌木与入口构件实机验证，整体继续
- 新建 Blender 多层折叶灌木，维修区边坡布置45株；新增木百叶与定向暖光。植被使用独立固定随机源，保留stage219树木序列。宽幅与入口图中低叶簇可辨认，但百叶被棚檐/招牌遮挡，灯光改善不明显，建筑与光照未达到预期。裸地、模糊地表、纸片针叶和重复树冠仍明显；没有把局部改善当成完成。
- `artifacts/realism220-validation/review.html` 保存6组stage219→220同机位前后实机图，包含入口近景、宽幅地形和林地；相机位置/朝向见 same-camera-audit.json、repair-same-camera-audit.json，观察见 visual-review.md，来源见 baseline-provenance.json。新灌木45株约21.2万三角形，无新增LOD，硬件性能未验收。
- 7项功能检查退出码0并PASS：服务巷、车间/维修棚、仓库通行碰撞，三枪108样本瞄准、近墙遮挡、联网状态规则、16角色单机烟测。19项构建哈希、6组相机一致。证据见 verification-summary.json、verified/；真实双客户端联网及完整人工游玩尚未完成。
- 验证异常如实保留：五机位图片均保存并输出PASS后，截图进程650秒退出超时（124），已清理该进程；维修棚单机位正常退出。导入日志出现1条 dummy renderer texture_2d_get 的 Parameter "t" is null，导出与运行日志未匹配错误，根因待查。见 capture-timeout-note.json、capture-process-audit.json、log-audit.json；evidence_verified=false，不能宣称全部验证无异常。
- 本地预览：`artifacts/realism220-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，保留同目录PCK，图形桌面选择SOLO；启动说明在同目录README.md。已用该包实机截图及功能测试；软件Vulkan不证明硬件帧率。保留全部未提交修改，未推送/发布。
- 下一步：优先修正维修棚正常视角可见构件及入口照明，追查导入/截图退出异常；再改善近景针叶/树皮、树群LOD和宽景地表，继续同机位与通行验证。随后结合第三人称人物及第一人称手部动作审阅推进剩余缺陷和真实双客户端主要功能，状态continue。


### Stage221 — 维修棚可见构件、入口植被与补光（continue）
- 缩小并下移招牌，露出正常第一人称机位可辨识的拱顶木百叶；两扇停放门板新增18条竖向折肋。入口及路肩用独立随机源增加42株低灌木，保留原树木序列；暖光能量0.85→1.5。实机建筑轮廓与入口绿量改善可见，但补光变化有限，门板材质简单、灌木重复平片、纸片针叶与模糊裸土仍明显，不将局部改善计为整体完成。
- 两组220→221同机位前后实机图已逐张审阅：`artifacts/realism221-validation/review.html`，含宽幅地形及建筑入口近景；`visual-review.md`记录不足。前图复用220已保存PNG及其超时局限，来源见`baseline-provenance.json`；后图由221导出包生成，两进程均PASS/退出0。`same-camera-audit.json`核验1280×800与相同位置朝向：宽景角色(17,0.05,50)、目标(-46,12,-90)、yaw/pitch=0.422854/0.067315；入口角色(15.5,0.05,39)、目标(15.5,2.3,27)、yaw/pitch=0/0.054114，眼高偏移1.6，角度单位弧度。
- 最终8项检查PASS/退出0：棚体4条双向通行和6项碰撞探测、服务巷42次通行、车间入口、仓库通行/护栏、三枪108样本瞄准、武器遮挡、联网状态规则、16角色单机烟测（装填/治疗/伤害/胜利/射线/掩体等）。棚体初测沿过时x12.95/16.95路线撞现有门板/后墙，改用后门洞内x15/16并增加门板阻挡与中央开口探测；中途解析错误及初测日志均保留，游戏碰撞未改。见`verified/functional-results-initial.json`、`verified/shelter-frame-final-result.json`与最终`verified/functional-results.json`。
- `verification-summary.json`：本轮evidence_verified=true，20项源码/构建哈希一致、2组相机一致；`log-audit.json`审计12份最终日志，0错误/0警告。本轮未复现220导入/截图退出异常，不声称旧异常根因已解决。联网规则不替代真实双客户端，脚本通行不替代完整人工游玩；软件Vulkan不证明硬件帧率，新增灌木未增加LOD。
- 当前本地预览：`./artifacts/realism221-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，保留旁边PCK，图形桌面选择SOLO；启动说明见`artifacts/realism221-preview/README.md`。保留全部未提交修改，未推送/发布/部署。
- 下一步：成组处理正常机位树冠/灌木体积与LOD、宽景地表模糊及建筑材料层次，避免继续仅加植被数量；用相同机位验证实际视觉收益与入口通行。保留第三人称人物、第一人称手部/袖管及三枪连续动作审阅，补真实双客户端主要功能验证；Android fix4仍待独立整合。整体状态continue。

### Stage222 — 路肩宽叶灌木与维修棚门板风化（continue）
- 重建灌木叶片尺度、朝向、卷转和折脊，使87处既有实例在正常站立机位呈现可辨认叶簇，减少原先水平细线外观；单资产2355→1488面，未验证硬件帧率或LOD收益。维修棚门板加入沿肋雨痕、分色带褪漆和低位锈蚀；本轮保留221建筑结构、补光和碰撞，没有新增光照改动。源文件备份见 `artifacts/realism222-validation/source-before/`。
- 已逐张审阅221→222宽幅地形与入口近景实机对照：`artifacts/realism222-validation/review.html`、`visual-review.md`。灌木体积改善明显，门板褪漆可见，但近景叶片仍棱角化、灌木连续带整齐、针叶树重复和地表模糊明显，门板斑块仍偏平面，不作为整体完成。基线来自221正常退出截图，来源见 `baseline-provenance.json`。
- `same-camera-audit.json`核验两组1280×800相同位置朝向：宽景角色(17,0.05,50)、目标(-46,12,-90)、yaw/pitch=0.422854/0.067315；入口角色(15.5,0.05,39)、目标(15.5,2.3,27)、yaw/pitch=0/0.054114，眼高偏移1.6、弧度。后图均由本轮导出包生成，2次截图PASS/退出0。
- 8项功能检查全部PASS/退出0：棚体双向通行/门板及框架碰撞、服务巷通行、西侧车间和仓库通行、三枪108样本瞄准、武器遮挡、联网状态规则、16角色单机烟测（装填/治疗/伤害/胜利/射线/掩体等）。见 `verified/functional-results.json` 和对应日志；规则测试不替代真实双客户端，脚本通行不替代完整人工游玩。
- 20项源码/资产/构建哈希一致。`log-audit.json`审计12份最终日志：导入复现1条 `Parameter "t" is null`，位置dummy renderer texture_2d_get；导入退出0，导出和运行日志无匹配错误，0警告。未解决根因，故 `verification-summary.json` 为 evidence_verified=false、runtime_checks_passed=true，不宣称验证全程无异常。
- 当前本地预览：`./artifacts/realism222-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，保留旁边PCK，图形桌面选择SOLO；启动说明 `artifacts/realism222-preview/README.md`。软件Vulkan截图不证明硬件帧率；未推送/发布/部署，保留所有未提交修改。
- 下一步：成组处理针叶树轮廓/叶片尺度、宽景地表层次和过于连续的灌木带，评估LOD并保持同机位与入口通行验证；追查headless导入空纹理异常。随后补第三人称人物、第一人称手部/袖管及三枪连续动作实机审阅和真实双客户端主要功能；Android fix4仍待独立整合。整体continue。

### stage223 — 维修棚门板与路肩植被、入口补光（2026-09-15）
- 环境阶段：`shelter_door.gdshader` 将门板大块斑纹换成细长剥蚀/流痕，并添加槽纹法线起伏；`build_verge_shrub.py` 重建较小、窄、弯曲分段叶片，重新输出 Blender/GLB；`world_visuals.gd` 将路肩/入口灌木由87株减至54株并降低、打散体量，入口 SpotLight 1.5→0.85。未修改碰撞。
- 实机同机位前后：`artifacts/realism223-validation/review.html`，左侧来自 stage222 正常退出的保留截图，右侧为本轮导出包实际1280×800截图；来源见 `baseline-provenance.json`。宽景 actor=(17,0.05,50)、yaw=0.4228539261、pitch=0.067315195；入口 actor=(15.5,0.05,39)、yaw=0、pitch=0.0541137822，eye offset均1.6。`same-camera-audit.json` 验证两组完整机位完全一致，记录图片SHA256。
- 人工审阅：正常持枪机位可见门板大斑块消退、灌木叶形和边缘改善、地面暴露更多；补光差异小，不作为主要成果。针叶树重复轮廓、近处地面模糊斑驳、建筑表面简单和手臂长度感仍明显，整体目标未完成。详见 `visual-review.md`。单株7008三角形×54，无新增LOD、无硬件性能测量，不以株数减少声称性能提升。
- 本轮导出包8项检查全部exit0/PASS：维修棚真实移动四路线及门板/墙/屋顶碰撞、服务通道、西车间、仓库通行；瞄准108样本/3武器；武器遮挡；联网状态规则；单机16actors换弹/治疗/伤害/胜利等。两次截图进程均exit0/PASS。`verified/functional-results.json`、`capture-process-audit.json`、`verification-summary.json` 可复核。联网规则仍不等于真实双客户端，软件Vulkan截图不证明硬件帧率。
- 导入exit0但有1条 `Parameter "t" is null`（dummy renderer texture_2d_get），根因未解决；导出及10个运行检查日志无匹配错误。12日志审计：1error/0warning，因此 `runtime_checks_passed=true`、`evidence_verified=false`，不能描述全链路无错误。20项构建/源码哈希一致。
- 当前本地预览：`./artifacts/realism223-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，图形桌面菜单选SOLO，保留相邻PCK；说明见预览README。未推送、未发布，保留所有未提交修改。
- 下一步：继续在宽景正常机位改善针叶树冠层重复和地表纹理/植被过渡，并处理植被LOD成本；跟进导入纹理异常。随后结合第三人称与第一人称连续动作实机审阅，补真实双客户端主要功能验证；Android fix4隔离合并待办仍保留。不得将本轮局部改善当作全部目标完成。

### stage224 — 前臂比例修正与出生机位缺陷复核（2026-09-15）
- 按最新环境优先级文档追加的独立审阅，修正第一人称前臂：静止骨长约0.519m→0.300m，保持手腕位置；袖管/加固片轴向UV同步缩放以保持纹理密度，重建 Blender/GLB 与独立 Linux 包。本轮环境沿用223，没有新增环境资产。
- `artifacts/realism224-validation/review.html` 保存223→224宽景、入口与默认出生对照。两组环境完整机位一致，见 `same-camera-audit.json`；出生角色(0,0.0003644675,90)、相机(0,1.6003644466,90)、yaw/pitch=0，1280×800，见 `spawn-camera-audit.json`（含图片哈希）。环境两次、出生两次采集均exit0/PASS。
- 实际审阅确认前臂不再过长，但默认出生画面底部可见袖管近端黑色开口；ADS及换弹起始帧近端在画外，不能判定整个动作通过。连续动作采集主动停止exit143，无PASS/最终逐帧机位JSON；4张部分帧及脚本哈希见 `partial-action-manifest.json`。换弹中段、其他枪械动作及第三人称未完成，不伪报通过。详见 `visual-review.md`。
- 11项功能检查exit0/PASS：骨长968样本、三枪换弹接触/姿态、维修棚/服务巷/西车间/仓库通行碰撞、108样本瞄准、武器遮挡、联网规则、16角色单机烟测；见 `verified/functional-results.json`。这类测试未检出袖管拓扑缺陷，不能代替视觉审阅或真实双客户端。
- 25项构建/源码哈希核验一致；18日志审计1error/0warning：headless导入 `Parameter "t" is null` 未解决（导入exit0，导出及运行日志无匹配错误）。`verification-summary.json` 为 functional_checks_passed=true、runtime_checks_passed=false、evidence_verified=false，连续动作不完整。
- 当前本地预览：`./artifacts/realism224-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`；保留相邻PCK、桌面菜单SOLO，见预览README。未推送、未发布、未改后台服务，保留所有未提交修改。
- 下一步：按最新独立拓扑审阅补齐肘部→上臂连续形体及合理姿态，禁止用平盖或恢复过长前臂遮掩；重新检查默认出生、ADS、换弹中段。保留环境针叶树重复、地表模糊、简单建筑/LOD问题及第三人称、真实双客户端、Android fix4待办。整体continue。

### stage225 — 连续肘袖建模与换弹姿态回归定位（2026-09-15）
- 按stage224最新拓扑审阅，在原64点端环接续弯肘、上臂与圆弧肩端，保持0.300m前臂及腕位，未用平盖封口；重建Blender/GLB和Linux预览。焊接UV接缝检查原四个64点开口环剩两个袖口环，无非流形边，见 `artifacts/realism225-validation/sleeve-topology.json`。本轮环境未修改，不算新增环境提升。
- 实际打开224→225默认出生同机位对照及225 ADS、换弹中段、换弹完成原图，见 `review.html`、`visual-review.md`、`spawn-after/`。人物(0,0.0003644675,90)，相机(0,1.6003644466,90)，yaw/pitch=0，1280×800；完整机位/哈希见 `same-camera-audit.json`。四姿态采集exit0/PASS，完成帧弹药30/119。
- **视觉未通过**：默认持枪开口已被连续形体接续，但新增上臂共用Forearm权重，换弹中段横跨左侧画面形成粗大弯管，缺少合理肩肘约束。失败证据 `spawn-after/reload-middle.png`；静止改善和拓扑通过不能抵消动作回归。预览README已注明这是问题复现检查点。
- 11项功能检查exit0/PASS：骨长968样本、三枪换弹接触/姿态、四组建筑/巷道通行碰撞、108样本瞄准、武器遮挡、联网状态规则、16角色单机烟测，见 `verified/functional-results.json`。不代表真实双客户端或完整动作视觉验收。
- 27项构建/源码哈希一致；14日志审计仍有导入 `Parameter "t" is null` 1条错误（导入exit0；导出和运行日志未匹配错误）。见 `verification-summary.json`：functional_checks_passed/captures_passed/same_camera=true，visual_passed/pipeline_logs_clean/evidence_verified=false。
- 当前本地问题预览：`./artifacts/realism225-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，保留相邻PCK，图形桌面菜单选SOLO。未推送、未发布、未改后台服务，保留所有未提交修改。
- 下一步：独立上臂/肩肘约束及连续权重，保持腕位、前臂长度与换弹接触，先复核本轮失败中段再扩展其他枪械/第三人称。继续环境建筑入口、宽景地表植被/光照、LOD与模糊重复材质改进及同机位实机对照；保留导入纹理异常、真实双客户端、Android fix4隔离合并待办。整体continue。

### stage226 — 维修棚支撑、地表碎石植被与补光调整（2026-09-15）
- 修改 `client/scripts/world_visuals.gd`：雨棚侧面增加钢斜撑，场坪边缘增加560实例碎石与32簇细草，室内反射补光1.05→0.65。实际打开入口及宽景前后原图：入口斜撑明显、宽景右侧碎石带可辨；草丛和补光贡献较弱，石块偏扁平，不能当作整体环境完成。
- 同机位实机对照、入口近景、宽幅地形见 `artifacts/realism226-validation/review.html`、`before/`、`after/terrain-wide.png`、`repair-after/repair-shelter-entrance.png`；审阅见 `visual-review.md`。入口角色(15.5,0.05,39)，yaw=0、pitch≈0.054114；宽景角色(17,0.05,50)，yaw≈0.422854、pitch≈0.067315；眼高1.6、1280×800，精确参数与截图哈希见 `same-camera-audit.json`。
- 八项功能检查exit0/PASS：四组建筑/巷道通行碰撞、三枪108样本瞄准、武器遮挡、联网状态规则、16角色单机烟测，见 `verified/functional-results.json`。联网规则不等于真实双客户端验收；实机采集来自本轮导出预览。
- `verification-summary.json`：功能/前后采集/同机位/27项构建源码哈希均通过，审计日志无匹配错误；此前headless导入纹理错误本轮未复现，不宣称根治。继承stage225换弹中段上臂粗管遮屏缺陷，本轮未修复或通过动作视觉验收。
- 当前本地预览：`./artifacts/realism226-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`；保留相邻PCK，图形桌面菜单选SOLO，限制见README。未推送、未发布、未改后台服务，保留未提交修改。
- 下一步：改进宽景重复针叶树、模糊泥地和碎石形体，继续入口/宽景同机位审阅；安排上臂独立权重与肩肘约束，复核换弹失败中段和第三人称。真实双客户端主要流程、Android fix4及整体写实画质验收仍待完成。整体continue。

### stage227 — 维修棚排水、碎石形体与树冠层次（2026-09-15）
- 修改 `client/scripts/world_visuals.gd`：用单套向外排水的落水管替换旧管，560实例碎石增加不规则体积，九株针叶树增加冠幅/深度差异并调整两株成熟树的位置和高度；同步 `tests/western_grove_collision.gd` 的两株位置。保留stage226光照。
- 实际打开前后入口和宽景原图：成熟树高低层次、落水管外向出口和近景石块形体可辨；宽景碎石改善弱，泥地仍模糊、针叶树仍重复，入口细网出现摩尔纹。本轮未完成新的光照改进，整体画质未通过。
- 对照见 `artifacts/realism227-validation/review.html`，原图在 `before/`、`after/terrain-wide.png`、`repair-after/repair-shelter-entrance.png`；审阅见 `visual-review.md`。入口角色(15.5,0.05,39)，yaw=0、pitch≈0.054114；宽景角色(17,0.05,50)，yaw≈0.422854、pitch≈0.067315；眼高1.6，Forward+、1280×800。精确机位和图像哈希见 `same-camera-audit.json`。
- 当前本地预览：`./artifacts/realism227-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，保留相邻PCK，在图形桌面选择SOLO。未推送、未发布、未改后台服务，保留所有未提交修改。最初变量重名导入失败已修正，失败输出保留 `import-first-attempt.txt`。
- 下一步：改进地表材质尺度与清晰度、入口细网摩尔纹及植被重复，继续同机位入口/宽景审阅并安排光照改善；修复stage225上臂遮屏并复核第三人称/三枪动作。真实双客户端主要流程、Android fix4隔离合并及LOD性能仍待完成。整体continue。
- 最终验证：八项功能检查全部exit0/PASS（四组建筑/巷道通行碰撞、三枪108样本瞄准、武器遮挡、联网状态规则、16角色单机烟测），另九株树实际角色碰撞均通过。见 `artifacts/realism227-validation/verified/functional-results.json`、`verified/western-grove-collision.json`。`verification-summary.json` 确认前后采集、精确同机位、27项构建/源码哈希和独立树木测试脚本哈希一致，最终 `.log` 无匹配错误；最初失败导入 `.txt` 单独保留，不计为成功日志。联网规则不能替代真实双客户端；整体目标未完成。

### stage228 — 维修棚钢架、边缘植被与入口照明（2026-09-15）
- 调整 `shelter_structural_steel.gdshader` 的钢架绿漆/锈色与流痕，降低泛白；`world_visuals.gd` 加深围栏、改用alpha hash和各向异性过滤，增加维修场边缘草丛密度/高度并保留低矮中央通路；入口暖光能量3.4→2.2、角度65→74并调整衰减与光源尺寸。未改碰撞体。
- 已实际审阅宽景和入口前后原图：钢架深绿对比、道路左侧草丛及围栏亮度变化清楚，入口暖光热点略减弱；泥地仍模糊空旷、树冠重复、厂房墙面简单，围栏仍有颗粒感，光照改善有限。alpha hash动态闪烁未验收；整体画质未通过。
- 同机位对照 `artifacts/realism228-validation/review.html`；前图原样继承stage227实机截图并记录来源，后图由本轮导出预览采集。入口角色(15.5,0.05,39)、yaw=0、pitch≈0.054114；宽景角色(17,0.05,50)、yaw≈0.422854、pitch≈0.067315；眼高1.6，Forward+，1280×800。精确记录见 `same-camera-audit.json`。llvmpipe固定机位采集不代表交互帧率验收。
- 八项功能检查全部exit0/PASS：四组建筑/巷道双向通行和碰撞、三枪108样本瞄准、武器遮挡、联网状态规则、16角色单机烟测。证据 `verified/functional-results.json`；`verification-summary.json` 确认两处采集、同机位及28项源码/构建哈希通过，审计日志无匹配错误。联网规则不等于真实双客户端验证。
- 当前本地预览：`./artifacts/realism228-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，保留相邻PCK，图形桌面菜单选SOLO；说明见预览README。未推送、未发布、未改后台服务，保留未提交修改。
- 下一步：地表纹理尺度/清晰度、建筑周边地面分区和围栏颗粒感；安排第三人称与第一人称动态审阅，修复stage225换弹中段上臂粗管遮屏的肩肘权重问题。真实双客户端主要流程、Android fix4隔离整合及LOD性能仍待完成。整体continue。

### stage229 — 维修棚入口路缘、草丛和碎石车辙（2026-09-15）
- `world_visuals.gd` 增加入口平台两侧八段带碰撞路缘及外侧24株草丛，保留中央通道；`service_ground.gdshader` 增加入棚碎石铺面与成对车辙。沿用stage228照明，本轮未独立完成光照改善。
- 已逐张实机审阅：入口近景路缘厚度与接缝明确，宽景铺面/车辙变化可辨；草丛部分被已有灌木遮挡。铺面仍过于规整、略像平整涂层，泥地模糊、树冠重复、墙面简单及细网颗粒感未解决，整体画质未通过。
- 对照 `artifacts/realism229-validation/review.html`：前图原样继承stage228实机原图并保存来源哈希，后图由本轮导出预览采集。入口角色(15.5,0.05,39)、yaw=0、pitch≈0.054114；宽景角色(17,0.05,50)、yaw≈0.422854、pitch≈0.067315；眼高1.6，Forward+，1280×800。精确机位见 `same-camera-audit.json`，评价见 `visual-review.md`。llvmpipe静帧不代表交互帧率验收。
- 初次实机运行发现shader变量aggregate重定义；改名loading_aggregate后重建并重新验证，失败证据单独保留 `failed-first-attempt/`，不计入成功检查。
- 本地预览：`./artifacts/realism229-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，保留相邻PCK，在图形桌面菜单选择SOLO。未推送、未发布、未改后台服务，保留所有未提交修改。
- 下一步：改善碎石破碎边缘、地表尺度和植被重复，验证细网动态颗粒；结合第三人称及第一人称动作审阅，修复stage225换弹中段上臂粗管遮屏的肩肘权重。真实双客户端主要流程、Android fix4隔离整合及LOD性能仍待完成。整体continue；最终功能结果和哈希审计随后追加。
- 最终验证：八项检查全部exit0/PASS，包括四组建筑/巷道通行碰撞、三枪108样本瞄准、武器遮挡、联网状态规则、16角色单机烟测（换弹/治疗/伤害/胜利等逻辑）。`artifacts/realism229-validation/verified/functional-results.json` 保存结果和日志索引；`verification-summary.json` 确认两处实机采集、精确同机位与26项源码/构建哈希通过，最终审计日志无匹配错误。逻辑换弹通过不代表换弹画面通过，联网规则不代表双客户端通过。整体目标仍未完成。

### stage230 — 维修棚铺面破碎边缘与路缘植被（2026-09-15）
- `service_ground.gdshader` 调整入棚碎石铺面边缘、纹理混合和断续轮迹，减弱浅色矩形与两条笔直黑带；`world_visuals.gd` 增加两侧带碰撞砖基座、四组共64株细草，调整棚内补光位置、范围和衰减。
- 实际审阅宽景及入口同机位前后原图：宽景铺面与泥地衔接改善可辨，入口基座被门板/箱体和正面视角遮挡，补光观感变化有限，不能算建筑和光照阶段已达标。地面模糊、树形重复、远山简化、规整墙面及细网颗粒仍存在。审阅见 `artifacts/realism230-validation/visual-review.md`。
- 基线原样继承stage229实机图并保存来源哈希；本轮后图来自导出的Linux预览，1280×800 Forward+、llvmpipe。入口角色(15.5,0.05,39)、yaw=0、pitch≈0.054114；宽景角色(17,0.05,50)、yaw≈0.422854、pitch≈0.067315；眼高1.6。精确机位与图像哈希见同目录相机记录及最终审计，软件渲染静帧不代表交互性能验收。
- 当前本地启动：`./artifacts/realism230-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，保留相邻PCK，在图形桌面菜单选SOLO。未推送、未发布、未改后台服务，保留未提交修改。
- 下一步：优先改正常行走可见的维修棚外立面、入口结构和侧墙体量，用正面及侧向机位验证可辨变化，避免继续仅增加被遮挡的小构件。保留第三人称人物与三枪连续动作审阅、stage225换弹上臂遮屏修复、真实双客户端联机、Android fix4隔离整合和LOD性能验证。整体continue；最终检查结果随后追加。
- 最终验证：八项功能检查全部exit0/PASS，覆盖四组建筑/巷道通行碰撞、三枪108样本瞄准、武器遮挡、联网状态规则和16角色单机烟测。结果及日志索引见 `artifacts/realism230-validation/verified/functional-results.json`；`verification-summary.json` 确认两处实机采集、前后精确同机位及26项源码/构建哈希通过，错误扫描无匹配。对照页为同目录 `review.html`。联网规则不代表真实双客户端验收，换弹逻辑通过不代表手臂画面缺陷解决；整体目标仍未完成。

### stage231 — 维修棚可透视侧窗与实体碰撞（2026-09-15）
- `world_visuals.gd` 将大片连续实心侧墙替换为砖砌矮墙、三跨分格玻璃、钢窗框与窗台，保留前后入口。沿用stage230地表植被和补光；本轮没有新增地形/光照修改。新增正常行走侧面采集机位及六处玻璃碰撞检查。
- 实际审阅入口、宽景、侧面前后图：侧面窗带与砖墙层次明显，能透看到室内；正面与宽景改善有限。玻璃偏均匀发绿、铺面直边/纹理模糊、重复树形、简化远山和细网颗粒仍存在，不能算整体画质达标。详见 `artifacts/realism231-validation/visual-review.md` 和 `review.html`。
- 三处1280×800 Forward+精确同机位对照通过。入口角色(15.5,0.05,39)、yaw=0、pitch≈0.054114；宽景(17,0.05,50)、yaw≈0.422854、pitch≈0.067315；新增侧面(7.5,0.05,37)、yaw≈-0.714091、pitch≈0.025184；眼高偏移1.6。入口/宽景基线继承230，侧面基线用230导出程序重新采集；来源、图像哈希和精确机位见 `before/provenance.json`、`same-camera-audit.json`。软件渲染静帧不代表帧率验收。
- 八项功能检查全部exit0/PASS：维修棚四条胶囊通行路线与六处玻璃碰撞、道路/工坊/仓库通行、三枪108样本瞄准、武器遮挡、联网状态规则和16角色单机烟测。`verified/functional-results.json` 索引全部日志；`verification-summary.json` 确认三次采集、同机位和27项源码/构建哈希通过，错误扫描无匹配。联网规则不等于真实双客户端验收，换弹逻辑通过不代表上臂画面缺陷修复。
- 本地启动：`./artifacts/realism231-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，保留相邻PCK，在图形桌面选SOLO。未推送、未发布、未改服务，保留未提交修改。
- 下一步：继续环境宽景优先，成组处理铺面直边与近中景植被分布/轮廓，用现有宽景和侧面机位核验可辨收益；随后第三人称人物及三枪连续动作审阅，修复stage225换弹上臂遮屏。真实双客户端、Android fix4隔离整合与LOD/性能验证仍待完成。整体continue。

### stage232 — 草坡根部高度修正与同机位复核（2026-09-15）
- `world_visuals.gd` 将维修棚周边草丛根部贴合土坡高度，调整坡内/坡缘草丛高度与宽度分布；跳过零高度土坡网格并下沉外围顶点。沿用231建筑与光照，没有新增建筑或光照提升。
- 实际审阅三处前后图：宽景草坡层次可辨，入口变化有限；侧面棕色铺面的矩形边界仍存在，清理土坡外围未解决它，不能将该假设计为已修复。模糊铺面、重复树形、简化远山、均匀发绿的玻璃仍待改善。见 `artifacts/realism232-validation/visual-review.md` 与 `review.html`。
- 基线继承231并记录来源哈希。本轮由232导出程序采集1280×800 Forward+软件渲染截图：宽景角色(17,0.05,50)、yaw≈0.422854/pitch≈0.067315；入口(15.5,0.05,39)、yaw=0/pitch≈0.054114；侧面(7.5,0.05,37)、yaw≈-0.714091/pitch≈0.025184；眼高1.6。精确相机记录及对照见 `same-camera-audit.json`；静帧不代表性能验收。
- 本地启动：`./artifacts/realism232-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，保留相邻PCK，在图形桌面选SOLO。未推送、未发布、未改服务，保留未提交修改。
- 下一步：先通过地表绘制层诊断确定侧面矩形边界实际来源，连同近中景植被轮廓/材质尺度成组改善，再复用当前机位验证。保留第三人称与三枪连续动作审阅、stage225换弹上臂遮屏修复、真实双客户端联机、Android fix4隔离整合和LOD/性能验证。整体continue；功能检查最终结果随后追加。
- 最终验证：八项检查全部exit0/PASS，包括维修棚四条通行路线与六处玻璃碰撞、道路/工坊/仓库通行、三枪108样本瞄准、武器遮挡、网络状态规则和16角色单机烟测。`artifacts/realism232-validation/verified/functional-results.json` 索引原始日志；`verification-summary.json` 确认三次实机采集、精确同机位、27项源码/构建哈希均通过，错误扫描无匹配。网络规则不替代双客户端验收，换弹逻辑不替代手臂画面审阅；整体目标未完成。

### stage233 — 移除横穿维修棚的重复车道铺面（2026-09-15）
- 地表层隔离诊断确认侧面矩形边界来自 `service_yard` 连接片。`world_visuals.gd` 跳过与维修棚占地相交的连接片，沿用碎石通路，保留停车场。诊断隐藏整类材质的图仅作定位证据。建筑、植被和光照沿用230–232，本轮没有新增这三类改动，局部修复不代表整体目标完成。
- 已审阅宽景、入口及侧面前后图：侧面近景黄褐矩形边界消失，入口铺面衔接更连贯，宽景收益有限；露出的碎石重复、模糊地表、规则草株、发绿玻璃与简化远山仍明显。对照与结论见 `artifacts/realism233-validation/review.html`、`visual-review.md`。
- 基线继承232并保存来源哈希。三处1280×800 Forward+精确同机位通过：宽景角色(17,0.05,50)、yaw≈0.422854/pitch≈0.067315；入口(15.5,0.05,39)、yaw=0/pitch≈0.054114；侧面(7.5,0.05,37)、yaw≈-0.714091/pitch≈0.025184；眼高1.6。精确记录见 `same-camera-audit.json`；软件渲染静帧不代表性能验收。
- 八项检查全部exit0/PASS：维修棚四条通行路线与六处玻璃碰撞、道路/工坊/仓库通行、三枪108样本瞄准、武器遮挡、网络状态规则和16角色单机烟测。`verified/functional-results.json` 索引日志；`verification-summary.json` 确认采集、相机和27项源码/构建哈希通过，错误扫描无匹配。网络规则不替代真实双客户端，换弹逻辑不代表上臂画面缺陷修复。
- 本地启动：`./artifacts/realism233-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，保留相邻PCK，图形桌面选SOLO。未推送、未发布、未改服务，保留未提交修改。
- 下一步：成组改善正常行走近中景的碎石纹理尺度与植被分布/轮廓，并结合建筑和光照复核宽景可辨收益，避免继续仅修局部小缺陷。随后安排第三人称人物与三枪连续动作审阅，修复stage225换弹上臂遮屏；真实双客户端联机、Android fix4隔离整合、LOD/性能验证仍待完成。整体continue。

### stage234 — 维修棚碎石尺度、草丛高度与侧窗色彩调整（2026-09-15）
- `service_ground.gdshader` 混合旋转碎石采样、缩小土块尺度并降低压实地面反差；`world_visuals.gd` 调整草丛密度与高低分布，降低侧窗绿色染色和不透明度。建筑几何、碰撞与灯光沿用233，本轮未新增建筑几何或光照提升。
- 已人工审阅宽景、入口与侧面前后图：大块褐色斑驳减弱、侧窗趋于中性灰，草丛高低略有变化；碎石重复、磨砂状玻璃、重复灌木树形和简化远山仍明显。收益有限，不代表环境或整体目标完成。见 `artifacts/realism234-validation/review.html`、`visual-review.md`。
- 基线继承233并保存来源哈希。三处1280×800 Forward+精确同机位通过：宽景角色(17,0.05,50)、yaw≈0.422854/pitch≈0.067315；入口(15.5,0.05,39)、yaw=0/pitch≈0.054114；侧面(7.5,0.05,37)、yaw≈-0.714091/pitch≈0.025184；眼高1.6，精确记录见 `same-camera-audit.json`。软件渲染静帧不代表性能验收。
- 八项检查全部exit0/PASS：维修棚四条路线与六处玻璃碰撞、道路/工坊/仓库通行、三枪108样本瞄准、武器遮挡、网络状态规则和16角色单机烟测。`verified/functional-results.json` 索引原始日志；`verification-summary.json` 确认三次采集、相机及27项源码/构建哈希通过，错误扫描无匹配。网络规则不替代真实双客户端，换弹逻辑不代表手臂画面缺陷修复。
- 本地启动：`./artifacts/realism234-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，保留相邻PCK，在图形桌面选SOLO。见预览README。未推送、未发布、未改服务，保留未提交修改。
- 下一步：优先解决正常行走近景碎石重复，并成组改善建筑周围植被轮廓与光照层次，用同机位宽景判断可辨收益，避免继续仅做局部材质微调。保留第三人称人物、三枪连续动作与第一人称手臂实机审阅、stage225换弹上臂遮屏修复、真实双客户端联机、Android fix4隔离整合及LOD/性能验证。整体continue。


### stage235 — 维修棚排水构件、碎石去点阵与灌木层次（2026-09-15）
- `world_visuals.gd` 增加半圆檐沟、支架与落水管，调整灌木高度和间隔、棚内冷色补光；`service_ground.gdshader` 扰动并稀疏碎石分布、降低白点反差；`shelter_metal.gdshader` 增加拱顶至檐口的明暗与冲刷色差。
- 已人工审阅宽景、入口、侧面三组实机前后图：侧面排水构件可辨，地面规则白点减弱、灌木高低与间隙更明显；入口光照收益较小，重复平面叶形、简化远山、空旷道路及人工感窗面仍存在。对照与局限见 `artifacts/realism235-validation/review.html`、`visual-review.md`，不以局部改善判定整体完成。
- 基线继承234并记录来源哈希；235导出程序采集1280×800 Forward+截图。宽景角色(17,0.05,50)、yaw≈0.422854/pitch≈0.067315；入口(15.5,0.05,39)、yaw=0/pitch≈0.054114；侧面(7.5,0.05,37)、yaw≈-0.714091/pitch≈0.025184；眼高1.6。精确同机位核验见 `same-camera-audit.json`。
- 八项检查全部exit0/PASS：维修棚四条通行路线与六处玻璃碰撞、道路/工坊/仓库通行、三枪108样本瞄准、武器遮挡、网络状态规则和16角色单机烟测。`verified/functional-results.json` 索引原始日志；`verification-summary.json` 确认三次采集、相机及28项源码/构建哈希通过，错误扫描无匹配。网络规则不替代真实双客户端，软件渲染静帧不代表性能验收，换弹逻辑不代表手臂画面修复。
- 本地启动：`./artifacts/realism235-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，保留相邻PCK，图形桌面选SOLO；见预览README。未推送、未发布、未改服务，保留未提交修改。
- 下一步：成组改善植被叶形/树形差异、近中景与远山衔接和光照层次，继续用正常游戏机位判断收益；结合第三人称人物、三枪连续动作与第一人称手臂实机审阅安排缺陷，保留stage225换弹上臂遮屏修复、真实双客户端联机、Android fix4隔离整合与LOD/性能验证。整体continue。


### stage236 — 维修棚透明侧窗与细叶灌木组合（2026-09-15）
- 新增 Blender 细叶灌木源文件与GLB，35处灌木中的19处使用更高、疏透的细叶轮廓；侧窗改为带底部积尘和视角反射的透明材质，增加窗横梁与铰链，入口暖光能量由0.85降至0.55。
- 已人工审阅宽幅地形、入口近景、侧面三组实机前后图：细叶与低矮阔叶组合在正常机位可辨，侧窗能透见内部和背景，横梁可辨；铰链与入口光照变化收益小。远处松树重复、远山简化、道路空旷、地面和屋顶材质人工感仍明显，整体目标未完成。见 `artifacts/realism236-validation/review.html`、`visual-review.md`。
- 基线继承235并保存哈希，236导出程序采集1280×800 Forward+截图。宽景角色(17,0.05,50)、yaw≈0.422854/pitch≈0.067315；入口(15.5,0.05,39)、yaw=0/pitch≈0.054114；侧面(7.5,0.05,37)、yaw≈-0.714091/pitch≈0.025184；眼高1.6。三处精确同机位通过，见 `same-camera-audit.json`。
- 八项功能检查全部exit0/PASS：维修棚四条通行路线、墙顶及六处玻璃碰撞，道路/工坊/仓库通行，三枪108样本瞄准，武器遮挡，网络状态规则和16角色单机烟测。`verified/functional-results.json` 索引原始日志；`verification-summary.json` 确认三次采集与31项源码/构建哈希通过。网络规则不替代真实双客户端，软件渲染截图不代表性能验收或换弹手臂缺陷修复。
- 导入日志第19行出现一次 Godot dummy 渲染器 `texture_2d_get` 的 `Parameter "t" is null`；导入仍完成，新增灌木在导出实机截图中正常显示，导出、截图及功能日志无匹配错误。保留该诊断，未认定根因已修复。
- 本地启动：`./artifacts/realism236-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，保留相邻PCK，在图形桌面选SOLO；见预览README。未推送、未发布、未改服务，保留未提交修改。
- 下一步：继续改善树形重复、近中景与远山衔接、空旷道路及光照层次，避免仅重复窗面微调；结合第三人称人物、三枪连续动作与第一人称手臂实机审阅安排剩余缺陷。保留stage225换弹上臂遮屏修复、真实双客户端联机、Android fix4隔离整合及LOD/性能验证。整体continue。


### stage237 — 路侧混合阔叶树与林下植被（2026-09-15）
- 新增可重建 Blender 阔叶树（弯曲树干、分叉枝条、折面叶），替换道路两处、西侧四处针叶树，补充六处林下灌木，保留树干碰撞与通行范围。本轮未改建筑和光照。
- 人工审阅宽幅、维修棚入口、侧面三组236→237同机位实机图：宽景横展叶冠与侧面浅色分叉树干可辨，入口收益主要在边缘；树下灌木收益有限。树枝规律、树干光滑、碎叶感、远山简化、道路空旷和材质人工感仍明显。见 `artifacts/realism237-validation/review.html`、`visual-review.md`，整体未完成。
- 1280×800 Forward+；角色位置/弧度：宽景(17,0.05,50), yaw≈0.422854/pitch≈0.067315；入口(15.5,0.05,39), yaw=0/pitch≈0.054114；侧面(7.5,0.05,37), yaw≈-0.714091/pitch≈0.025184；眼高偏移1.6。三处精确同机位、34项构建哈希通过，见 `same-camera-audit.json`、`verification-summary.json`。
- 三次截图与八项功能检查全部exit0/PASS：维修棚双向通行和墙顶/玻璃碰撞，道路/工坊/仓库通行，三枪108样本瞄准，近墙武器遮挡，网络状态规则及16角色单机烟测。日志索引 `verified/functional-results.json`；网络规则不替代真实双客户端，软件渲染不代表性能验收。
- 首次截图因GDScript类型推断失败，补充显式bool并使用近似浮点坐标比较后重新构建、完整重跑通过；原始 `initial-capture-failure.log` 保留，最终验证日志无匹配错误。
- 当前本地预览：`./artifacts/realism237-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，保留相邻PCK，图形桌面选SOLO；启动说明见该预览README。未推送、未发布、未改服务，保留未提交修改。
- 下一步：成组改善近中景与远山衔接、空旷道路及光照层次，并安排第三人称人物、第一人称手臂及三枪连续动作实机审阅。保留stage225换弹上臂遮屏修复、真实双客户端联机、Android fix4隔离整合及LOD/性能验证。整体continue。

### stage238 — 维修棚遮阳、窗下植被与地表光照调整（2026-09-15）
- 增加两侧四层外挑遮阳百叶及支架，西侧五处矮灌木与不规则暗土过渡，降低道路碎石亮度、棚内补光；保留原结构碰撞。本轮为环境局部改善，未将整体目标标记完成。
- 人工审阅237→238宽景、入口、侧面同机位实机图：侧面窗上遮阳暗带与窗下植被清晰可辨；入口和宽景收益有限，远山重复、道路空旷、灌木排列规则、均匀拱顶和材质人工感仍存在。证据：`artifacts/realism238-validation/review.html`、`visual-review.md`。
- 三机位1280×800 Forward+，眼高偏移1.6m；宽景角色(17,0.05,50), yaw≈0.422854/pitch≈0.067315；入口(15.5,0.05,39), yaw=0/pitch≈0.054114；侧面(7.5,0.05,37), yaw≈-0.714091/pitch≈0.025184。精确坐标朝向逐字段一致、构建哈希匹配，见 `same-camera-audit.json`、`verification-summary.json`。
- 三次截图及八项检查全部exit0/PASS：维修棚入口双向穿行与墙顶玻璃碰撞，道路/工坊/仓库通行，三枪108样本瞄准，武器遮挡规则，网络状态规则及16角色单机烟测；最终日志无匹配错误。日志索引 `verified/functional-results.json`。自动物理通行不等于整图人工走查，网络规则不替代真实双客户端，软件Vulkan不构成性能验收。
- 本地可运行预览：`./artifacts/realism238-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，保留相邻PCK，图形桌面选SOLO；见该目录README。未推送、未发布、未改服务，保留所有既有未提交修改。
- 下一步：扩大到道路沿线和远山形态、疏密及光照层次，避免继续只细化棚屋；结合第三人称人物、三枪及第一人称手部连续动作审阅处理剩余缺陷。保留stage225换弹上臂遮屏、真实双客户端、Android fix4隔离整合及LOD/硬件性能验证。整体continue。

### stage239 — 山坡林带疏密、树线与地表明暗（2026-09-15）
- 提高背景森林候选密度，调整群落与林隙分布、树线高度及树冠宽高，降低雾密度，并给坡面加入排水区与干燥肩部色差。建筑沿用238，本轮没有新增建筑结构；整体目标仍未完成。
- 已人工审阅238→239宽景、入口、侧面同机位实机图：宽景中央与右侧谷地林带更连贯，峰顶高树减少；坡面色差及雾调整收益较细微，远山仍偏蓝灰平滑，近景路肩重复空旷、灌木平面感与建筑材质平整仍待解决。证据：`artifacts/realism239-validation/review.html`、`visual-review.md`，不以截图数量认定画质完成。
- 三机位1280×800 Forward+，眼高偏移1.6m；宽景角色(17,0.05,50), yaw≈0.422854/pitch≈0.067315；入口(15.5,0.05,39), yaw=0/pitch≈0.054114；侧面(7.5,0.05,37), yaw≈-0.714091/pitch≈0.025184。精确机位逐字段一致，35项源码/构建等哈希匹配；见 `same-camera-audit.json`、`verification-summary.json`。
- 三次截图与八项检查全部exit0/PASS：维修棚入口双向穿行及墙顶窗碰撞，道路/工坊/仓库通行，三枪108样本瞄准，武器遮挡规则，网络状态规则，16角色单机烟测（换弹/治疗/伤害/胜利/射线/射击间隔等）。独立图形模式背景根部检查PASS：18山体、19394棵树、最大落地误差0.000127m；缩小成年树后scale分类不再等于幼树数量。日志见 `verified/functional-results.json`、`verified/background_scenery.log`。
- 本地预览：`./artifacts/realism239-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，保留相邻PCK，图形桌面选SOLO，使用说明见预览README。软件Vulkan截图不代表硬件性能验收；网络规则检查不等于真实双客户端联机。未推送、未发布、未改服务，保留所有既有未提交修改。
- 下一步：优先补道路近中景裸土与植被体积、打破重复排列，并改善山体岩土过渡；随后结合第三人称全身、三枪与第一人称手部连续动作审阅安排缺陷。保留stage225换弹上臂遮屏、真实双客户端、Android fix4隔离整合及LOD/硬件性能验证。整体continue。

### stage240 — 维修路肩高低草灌群落（2026-09-15）
- 在闲置路肩加入六处大小不一、边缘高度衰减的草灌群落，复用现有GLB，避开维修及装卸通路。宽景转弯和装卸棚附近的高低层次可辨；入口、侧面图几乎没有改善，不能作为建筑画质提升。本轮未改建筑或光照，局部收益不代表整体完成。
- 已人工审阅239→240三个相同机位的实机对照：`artifacts/realism240-validation/review.html`、`visual-review.md`。细枝仍杂乱偏平面，远山蓝灰平滑，大面积地表及棚体材质仍简单。
- 三机位1280×800 Forward+、眼高1.6m：宽景角色(17,0.05,50), yaw≈0.422854/pitch≈0.067315；入口(15.5,0.05,39), yaw=0/pitch≈0.054114；侧面(7.5,0.05,37), yaw≈-0.714091/pitch≈0.025184。精确机位逐字段一致、构建哈希匹配；见 `same-camera-audit.json`、`verification-summary.json`，基线来源见 `before/provenance.json`。
- 三次截图及八项检查全部exit0/PASS：维修棚双向入口及墙顶窗碰撞，道路/工坊/仓库通行，三枪108样本瞄准，武器遮挡规则，网络状态规则，16角色单机烟测。日志索引 `verified/functional-results.json`，未匹配验证错误。自动通行不是整图人工走查，网络规则不是双客户端联机，换弹逻辑通过不等于换弹画面验收，软件Vulkan不代表硬件性能。
- 本地预览：`./artifacts/realism240-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，保留相邻PCK，图形桌面选择SOLO；预览README包含操作说明。未推送、未发布、未改服务，保留既有未提交修改。
- 下一步：扩大到山体岩土过渡、地表及建筑材质层次，避免继续只在维修棚增加植被。保留第三人称全身、三枪与第一人称手部连续动作审阅、stage225换弹上臂遮屏、真实双客户端、Android fix4隔离整合及LOD/目标硬件性能验证。整体continue。

### stage241 — 山坡岩土过渡与维修棚屋面风化（2026-09-15）
- 调整 terrain_slopes 的连续岩土斑块与坡度过渡，shelter_metal 增加褪色、雨蚀、氧化及粗糙度变化。侧面正常机位能辨认屋面新增的不同长度褐色痕迹，但仍有规则条纹；远山受雾和轮廓影响，改善很弱；入口正面基本无提升。本轮未改植被布局、全局灯光、建筑几何或碰撞，局部材质收益不代表整体目标完成。
- 已人工审阅240→241同机位宽幅、入口、侧面对照：`artifacts/realism241-validation/review.html`、`visual-review.md`。1280×800 Forward+，眼高1.6m；宽景角色(17,0.05,50), yaw≈0.422854/pitch≈0.067315；入口(15.5,0.05,39), yaw=0/pitch≈0.054114；侧面(7.5,0.05,37), yaw≈-0.714091/pitch≈0.025184。精确记录及图像哈希见 `same-camera-audit.json`，前图来源见 `before/provenance.json`。
- 三次截图与八项检查均exit0/PASS：维修棚双向入口及墙顶窗碰撞、维修通道/西车间/仓库通行、三枪108样本瞄准、武器遮挡、网络状态规则、16角色单机烟测。构建哈希匹配，未匹配验证错误，见 `verification-summary.json`、`verified/functional-results.json` 和对应日志。自动路线通行不等于整图人工走查，网络规则不等于真实双客户端，换弹逻辑不等于动画画质验收，软件Vulkan不代表硬件性能。
- 本地可运行预览：`./artifacts/realism241-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`；保留相邻PCK，在图形桌面选择SOLO，操作见预览README。未推送、未发布、未改服务，保留所有既有未提交修改。
- 下一步：优先改善近中景地表与植被交界、平滑山体轮廓和建筑结构规则感，以同机位可见收益评估，避免继续只做屋面小修。随后结合第三人称全身、三枪/第一人称手部连续动作审阅处理剩余缺陷；保留stage225换弹上臂遮屏、真实双客户端、Android fix4隔离整合及LOD/目标硬件性能验证。整体continue。

### stage242 — 维修棚门板风化、局部照明和路肩低草（2026-09-15）
- 修改 `client/scripts/world_visuals.gd` 与 `client/shaders/shelter_door.gdshader`：入口灯能量降低、棚内补光和工作台灯覆盖增加，门板下缘增加剥漆/粉化，轮迹边缘增加确定性低草并避开入口及装卸路线；未新增碰撞体。
- 已人工审阅241→242同机位宽幅地形、入口近景和侧面截图，见 `artifacts/realism242-validation/review.html`、`visual-review.md`。效果偏弱：右侧灌木下缘略丰富，门板下沿剥漆可见，但大片裸地、屋顶长条重复、规则建筑轮廓和平滑远山仍突出，不将局部改动视为环境目标完成。下一阶段必须扩大正常游戏距离可辨认的植被尺度/成簇覆盖和建筑轮廓变化，避免继续棚门微调。
- 相机1280×800 Forward+，角色原点/朝向：宽景(17,0.05,50), yaw≈0.422854/pitch≈0.067315；入口(15.5,0.05,39), yaw=0/pitch≈0.054114；侧面(7.5,0.05,37), yaw≈-0.714091/pitch≈0.025184；眼高另加1.6。`same-camera-audit.json` 确认三组记录完全相同，前图来源及哈希见 `before/provenance.json`。
- 三次截图及八项检查均exit0/PASS：维修棚双向入口和墙顶窗碰撞、服务通道/西车间/仓库通行、三枪108样本瞄准、武器遮挡、网络状态规则、16角色单机烟测（换弹/治疗/伤害/胜利等）。`verification-summary.json` 确认构建哈希匹配、未发现验证错误；详细日志见 `verified/functional-results.json`。自动通行不等于整图人工走查，网络规则不等于真实双客户端，软件Vulkan不代表目标硬件性能。
- 本地可运行预览：`./artifacts/realism242-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，保留相邻PCK，图形桌面选择SOLO；操作说明见预览README。未推送、未发布、未改服务，保留既有未提交修改。
- 后续仍保留第三人称人物、三枪/第一人称手部连续动作实机审阅、stage225换弹上臂遮屏、真实双客户端联机、Android fix4隔离整合及LOD/性能验证；按环境明显可见收益优先推进。整体continue。

### stage243 — 维修棚屋脊通风罩与较高灌草群落（2026-09-15）
- 修改 `client/scripts/world_visuals.gd`：新增屋脊百叶通风罩，扩大路肩成簇灌草并提高高度、密度，增加树脚草丛；入口增加反射日光灯，保留入口/装卸路线植被退让。侧面实机中通风罩清楚改变拱顶轮廓，宽景灌草覆盖明显增加；入口补光收益很弱，大片裸土、平滑尖峰远山和重复屋顶锈条仍突出，整体目标未完成。
- 已审阅242→243宽幅地形、入口近景、侧面三组同机位实机对照，见 `artifacts/realism243-validation/review.html`、`visual-review.md`。1280×800 Forward+；角色原点/朝向：宽景(17,0.05,50), yaw≈0.422854/pitch≈0.067315；入口(15.5,0.05,39), yaw=0/pitch≈0.054114；侧面(7.5,0.05,37), yaw≈-0.714091/pitch≈0.025184；眼高另加1.6米。完整精度、来源和哈希见 `same-camera-audit.json`、`before/provenance.json`。
- 首次屋顶探测被新增底座提前截获；将底座中心由5.20升至5.32米，重新导出和验证后原屋顶命中恢复约5.174米，未放宽测试。初次失败与中断记录保留在 `initial-roof-failure/`。
- 本地预览：`./artifacts/realism243-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，保留相邻PCK，图形桌面选择SOLO；详见预览README。未推送、未发布、未改服务，保留既有未提交修改。
- 下一步优先改善近中景大片裸地与植被群落的自然交界、远山轮廓/材质，避免继续棚门微调；保留第三人称人物、三枪/第一人称手部连续动作审阅、stage225换弹上臂遮屏、真实双客户端联机、Android fix4隔离整合及LOD/目标硬件性能验证。整体continue。
- 最终验证：三次实机截图与八项检查全部exit0/PASS；维修棚双向入口及墙顶窗碰撞、维修通道/西车间/仓库通行、三枪108样本瞄准、武器遮挡、网络状态规则、16角色单机烟测（换弹/治疗/伤害/胜利等）通过。`artifacts/realism243-validation/verification-summary.json` 确认前后相机完全一致、构建哈希匹配且最终日志未发现错误，逐项结果见 `verified/functional-results.json`。自动路线不等于整图人工走查，网络规则不等于真实双客户端，软件Vulkan不代表目标硬件性能。

### stage244 — 远山轮廓与维修通道细草调整（2026-09-15）
- 修改 `client/scripts/world_visuals.gd`：远山高度场增加分峰、鞍部和斜向侧脊，放宽维修通道草斑阈值并提高路肩、车辙中央草覆盖。没有新增建筑或光照改进。三组实机前后审阅显示远山形状变化可见，但侧面更圆钝、自然度没有充分改善；建筑脚边细草变化弱，大片裸土和重复屋面仍突出，不能作为整体画质完成。
- 243→244同机位对照及逐张审阅：`artifacts/realism244-validation/review.html`、`visual-review.md`。1280×800 Forward+；角色位置/朝向：宽景(17,0.05,50), yaw≈0.422854/pitch≈0.067315；入口(15.5,0.05,39), yaw=0/pitch≈0.054114；侧面(7.5,0.05,37), yaw≈-0.714091/pitch≈0.025184；眼高另加1.6米。完整记录及基线来源见 `same-camera-audit.json`、`before/provenance.json`。
- 本地预览：`./artifacts/realism244-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，保留相邻PCK，图形桌面选择SOLO；操作见预览README。未推送、未发布、未修改后台服务，保留既有未提交修改。
- 下一阶段优先以土层、石砾、枯草和成簇植被改善裸地与路肩交界，处理屋面重复锈条和入口材质/光照，避免继续仅增加细草实例。保留第三人称人物、三枪/手部连续动作、stage225换弹上臂遮屏、真实双客户端、Android fix4隔离整合及LOD/目标硬件性能验证。整体continue。
- 最终验证：三次实机截图、八项功能检查及远景贴地专项全部exit0/PASS。维修棚/工坊/仓库碰撞通行、通道42条站立/蹲伏/机器人路线、三枪108样本瞄准、武器遮挡、网络状态规则、16角色单机换弹/治疗/伤害/胜利烟测通过；18座山上20056棵树与4645株幼树最大根部误差0.000118米。`artifacts/realism244-validation/verification-summary.json` 确认相机完全一致、构建哈希匹配且验证日志无错误，原始结果见 `verified/functional-results.json` 和 `background-scenery.log`。自动路线不等于整图人工走查，网络规则不等于真实双客户端，软件Vulkan不代表目标硬件性能。

### stage245 — 维修棚屋面、窗下地表和门廊灯（2026-09-15）
- 减弱屋面板块色差与连续锈条，窗下加入批量石砾及低矮阔叶植物，降低门廊灯亮度并调整色温。首版实机发现白色石点失真，已降低石砾底色、重新导出并审阅最终三机位；判退图保留。侧面局部改进可辨认，宽幅差异很小；裸地模糊、平面叶片、圆钝远山及空旷室内仍明显，整体目标未完成。
- 244→245同机位前后对照：`artifacts/realism245-validation/review.html`，逐项画质判断见 `visual-review.md`。1280×800 Forward+；角色位置/朝向：宽景(17,0.05,50), yaw≈0.422854/pitch≈0.067315；入口(15.5,0.05,39), yaw=0/pitch≈0.054114；侧面(7.5,0.05,37), yaw≈-0.714091/pitch≈0.025184；眼高另加1.6米。完整精度、来源和哈希见 `same-camera-audit.json`。
- 八项功能检查 exit0/PASS：建筑双向入口及门窗墙顶碰撞、通道/工坊/仓库通行、三枪108采样瞄准、武器遮挡、网络状态规则及16角色单机烟测。功能检查针对首版导出；最终包仅一行装饰石砾底色修正，源码差异哈希证据见 `functional-build-provenance.json`。最终包三次实机截图通过，`verification-summary.json` 确认相机一致、最终构建哈希匹配、日志无错误。网络规则不等于真实双客户端，软件Vulkan不代表目标硬件性能。
- 当前本地预览：`./artifacts/realism245-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，保留相邻PCK，图形桌面选择SOLO；操作见预览README。首版功能测试包保留在Linux-initial。未推送或发布，保留既有未提交修改。
- 下一阶段扩大宽幅可见改造：优先裸土纹理尺度与不规则植被群落交界，避免继续窄带小物堆叠；随后处理远山/重复林带，并结合第三人称人物、第一人称三枪连续动作审阅继续stage225换弹上臂遮屏、真实双客户端联机、Android fix4隔离整合及LOD/性能验证。返回continue。

### stage246 — 维修棚通道草丛群落与硬地边界（2026-09-15）
- 修正维修棚过大的植被禁区，保留实际入口硬地与通道中心排除带；扩大南侧不规则草丛采样范围，提高路肩草簇高度，并调整土层/碎石纹理尺度。首版宽景变化不足，判退并保留证据后继续修改。最终宽景两侧草丛层次明显、侧面裸地有所分割；入口建筑与光照基本不变，仅作退化检查。近景地表偏平偏糊、大叶片扁平、圆钝远山和重复林带仍明显，整体目标未完成。
- 245→246三机位实机对照及人工审阅：`artifacts/realism246-validation/review.html`、`visual-review.md`；首版证据在 `initial-rejected/`。1280×800 Forward+，角色坐标/yaw/pitch：宽景(17,0.05,50)/0.422853926132941/0.067315194971276；入口(15.5,0.05,39)/0/0.0541137822480691；侧面(7.5,0.05,37)/-0.714090698612158/0.0251843095291505；眼高另加1.6米，精确记录见 `same-camera-audit.json`。
- 当前本地预览：`./artifacts/realism246-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，保留相邻PCK，图形桌面选择SOLO；操作见预览README。未推送、未发布，保留既有未提交修改。
- 下一阶段优先处理正常机位中的地表立体颗粒与大叶片形体/材质，避免继续仅加细草；随后处理远山、重复林带，并结合第三人称人物和三枪/手部连续动作审阅，继续stage225换弹上臂遮屏、真实双客户端、Android fix4隔离整合及LOD/目标硬件性能验证。整体continue。
- 最终包验证完成：八项检查均exit0/PASS，覆盖建筑入口/门窗墙顶碰撞、单机通行、三枪108采样瞄准、武器遮挡、网络状态规则和16角色单机烟测；日志见 `artifacts/realism246-validation/verified/`。三次最终包实机截图成功，`verification-summary.json` 确认前后相机一致、构建哈希匹配且最终日志无错误。网络规则检查不代表真实双客户端联机，软件Vulkan截图不代表目标硬件性能。

### stage247 — 通道压实轮迹与路肩高低群落（2026-09-16）
- 修改 `client/scripts/world_visuals.gd`、`client/shaders/service_ground.gdshader`：路肩统一高草改为高低群落，缩小两组维修棚阔叶实例，沿弯曲入口通道增加压实双轮迹和排水痕迹。宽景路径更连贯、草丛层次可辨认；侧面大灌木基本不变，裸土仍平且模糊。钢架旧化试验在入口产生条纹，已撤回并保留 `initial-rejected/`；建筑和光照改进尚未完成。
- 已人工审阅246→247三组最终实机同机位对照：`artifacts/realism247-validation/review.html`、`visual-review.md`。1280×800 Forward+；玩家坐标/yaw/pitch：宽景(17,0.05,50)/0.422853926132941/0.067315194971276；入口(15.5,0.05,39)/0/0.0541137822480691；侧面(7.5,0.05,37)/-0.714090698612158/0.0251843095291505；眼高另加1.6米，精确记录和基准来源见 `same-camera-audit.json`、`before/provenance.json`。
- 本地预览：`./artifacts/realism247-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，保留相邻PCK，桌面选择SOLO；操作见预览README。未推送、未发布、未修改后台服务，保留既有未提交修改。
- 下一阶段先定位侧面占屏大灌木的实际资产，处理叶片形体和地表颗粒，并推进正常机位可辨认的建筑、光照改善；保留第三人称人物、三枪/手部连续动作审阅、stage225换弹上臂遮屏、真实双客户端联机、Android fix4整合及LOD/目标硬件性能验证。整体continue。
- 最终包八项检查均 exit0/PASS：维修棚入口及门窗墙顶碰撞、服务通道/西车间/仓库双向通行、三枪108样本瞄准、武器遮挡、网络状态规则、16角色单机烟测（换弹/治疗/伤害/胜利等）。三次最终包实机截图成功；`artifacts/realism247-validation/verification-summary.json` 确认相机一致、构建哈希匹配、测试前后PCK均与最终预览一致，最终验证日志无错误。逐项结果见 `verified/functional-results.json`，包来源见 `verified/package-provenance.json`。自动路线不等于整图人工走查，网络规则不等于真实双客户端，软件Vulkan不代表目标硬件性能。

### stage248 — 维修棚细叶群落、连续排水与钢构/工作区光照（2026-09-16）
- 两组维修棚灌木统一使用现有细叶资产，消除侧面大片椭圆叶片；入口孤立排水矩形改为连续窄槽与金属横条；钢构加入不规则漆面斑驳，增强工作台暖光、减弱门廊暖光。三机位实机审阅确认局部变化可辨认，但钢构斑点仍程序化、混凝土均匀、室内层次有限；宽景裸土模糊、圆钝远山和重复林带未解决，整体目标未完成。
- 247→248同机位实机对照：`artifacts/realism248-validation/review.html`、`visual-review.md`。1280×800 Forward+软件Vulkan；玩家坐标/yaw/pitch：宽景(17,0.05,50)/0.422853926132941/0.067315194971276；入口(15.5,0.05,39)/0/0.0541137822480691；侧面(7.5,0.05,37)/-0.714090698612158/0.0251843095291505；眼高另加1.6米。首次入口采集外层进程终止143，已留存原日志并重采样，最终三次截图均正常退出。
- 本地预览：`./artifacts/realism248-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，保留相邻PCK，在图形桌面选择SOLO；操作见预览README。未推送、未发布、未修改后台服务，保留既有未提交修改。
- 下一阶段集中改善正常宽景的大面积地表颗粒、远山轮廓与林带重复，避免仅增加细碎装饰；保留第三人称人物、三枪/手部连续动作审阅、stage225换弹上臂遮屏、真实双客户端联机、Android fix4整合及LOD/目标硬件性能验证。整体continue。
- 最终包八项检查全部exit0/PASS：维修棚入口及门窗墙顶碰撞、服务通道/西车间/仓库通行、三枪108样本瞄准、武器遮挡、网络状态规则、16角色单机烟测（换弹/治疗/伤害/胜利等）。`artifacts/realism248-validation/verification-summary.json` 确认三次截图通过、前后相机一致、构建哈希匹配、测试前后PCK与预览一致、验证日志无错误；逐项日志在 `verified/`。自动路线不等于整图人工走查，网络规则不等于真实双客户端，软件Vulkan不代表目标硬件性能。

### stage249 — 收窄远山坡脊与调整高坡林线（2026-09-16）
- 修改 `client/scripts/world_visuals.gd`：圆钝山体改为收窄峰脊和内凹山麓，增加次级峰脊变化，降低高处林线并拓宽背景树冠。正常宽景与入口侧面可辨认轮廓变化，但山体仍偏规则光滑，远树仍有平面重复剪影，裸土模糊；本轮未修改建筑和灯光，不把stage248已有改善计入本轮，整体目标未完成。
- 已人工审阅248→249三组同机位实机图：`artifacts/realism249-validation/review.html`、`visual-review.md`。1280×800 Forward+软件Vulkan；玩家坐标/yaw/pitch：宽景(17,0.05,50)/0.422853926132941/0.067315194971276；入口(15.5,0.05,39)/0/0.0541137822480691；侧面(7.5,0.05,37)/-0.714090698612158/0.0251843095291505；眼高另加1.6米。精确相机及基准来源见 `same-camera-audit.json`、`before/provenance.json`。
- 图形模式检查18块真实山体网格与19,236棵背景树，树根最大误差0.000111米，检查通过；贴地结果不消除截图中的悬浮感和林带墙面感。原始日志 `verified/background_scenery.log`，包哈希记录 `verified/background-scenery-result.json`。
- 本地预览：`./artifacts/realism249-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，保留相邻PCK，图形桌面选择SOLO；操作见预览README。未推送、发布或修改后台服务，保留所有既有未提交修改。
- 下一阶段处理大面积地表尺度与山体不对称轮廓，继续消除林带重复；保留建筑光照整体审阅、第三人称人物、三枪/手部连续动作及stage225换弹上臂遮屏、真实双客户端联机、Android fix4整合及LOD/目标硬件性能验证。整体continue。
- 最终包八项回归全部exit0/PASS：维修棚门窗墙顶碰撞及入口通行、服务通道/西车间/仓库通行、三枪108样本瞄准、武器遮挡、网络状态规则、16角色单机烟测（换弹/治疗/伤害/胜利等）。`artifacts/realism249-validation/verification-summary.json` 确认三次截图通过、前后相机一致、构建哈希匹配、测试前后PCK与预览一致、验证日志无错误。自动路线不等于整图人工走查，软件Vulkan不代表目标设备性能。

### stage250 — 不对称远山峰肩与顺坡沟谷（2026-09-16）
- 修改 `client/scripts/world_visuals.gd`：各山体主峰位置与宽度产生差异，次峰改为偏置肩峰，并加入顺坡展宽沟谷。宽景中央、右侧山体轮廓变化可辨认，但仍有圆锥感、平滑坡面和条带状林群；前景泥土模糊、灌木等高过密未解决。本轮未修改建筑、灯光或武器，整体目标未完成。
- 已人工审阅249→250宽景、维修棚入口与侧面三组实机同机位对照：`artifacts/realism250-validation/review.html`、`visual-review.md`。1280×800 Forward+软件Vulkan；玩家坐标/yaw/pitch：宽景(17,0.05,50)/0.422853926132941/0.067315194971276；入口(15.5,0.05,39)/0/0.0541137822480691；侧面(7.5,0.05,37)/-0.714090698612158/0.0251843095291505；眼高另加1.6米。精确相机参数与基准来源见 `same-camera-audit.json`、`before/provenance.json`。
- 最终包八项回归全部exit0/PASS：维修棚入口及门窗墙顶碰撞、服务通道/西车间/仓库通行、三枪108样本瞄准、武器遮挡、网络状态规则、16角色单机烟测（换弹/治疗/伤害/胜利等）。图形检查18座山体及18,920棵背景树，树根最大误差0.000121米。`artifacts/realism250-validation/verification-summary.json` 确认截图成功、相机一致、构建哈希匹配、测试使用最终包、验证日志无错误；逐项日志见 `verified/`。网络规则不等于真实双客户端，自动路线不等于整图人工走查，软件Vulkan不代表目标硬件性能。
- 本地预览：`./artifacts/realism250-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，保留相邻PCK，图形桌面选择SOLO；操作见预览README。未推送、发布或修改后台服务，保留既有未提交修改。
- 下一阶段优先改善正常机位前景车辙、碎石与泥土尺度，拆分密集灌木高度和疏密，并结合建筑钢架材质及室内外光照审阅。保留第三人称人物、三枪/手部连续动作、stage225换弹上臂遮屏、真实双客户端联网、Android fix4整合及LOD/目标硬件性能验证。整体continue。

### stage251 — 维修棚入口植被分层与断续轮迹（2026-09-16）
- 修改 `client/scripts/world_visuals.gd` 与 `client/shaders/service_ground.gdshader`：减少维修棚周边高灌木数量与高度，保留稀疏高冠及低草；泥土轮迹增加带距离过滤的断续胎纹与碎土边缘。正常侧面机位入口坡道、柱脚明显露出，宽景道路遮挡减少；胎纹提升较弱，泥土模糊、钢架花斑、过亮屋面与远山圆锥感仍明显。本轮未修改建筑或灯光，整体目标未完成。
- 已人工审阅250→251宽景、入口和侧面三组实机同机位对照：`artifacts/realism251-validation/review.html`、`visual-review.md`。Before复用250原始截图并记录来源哈希，After由251导出包进入单机后固定模拟采集；1280×800 Forward+软件Vulkan。玩家坐标/yaw/pitch：宽景(17,0.05,50)/0.422853926132941/0.067315194971276；入口(15.5,0.05,39)/0/0.0541137822480691；侧面(7.5,0.05,37)/-0.714090698612158/0.0251843095291505；眼高另加1.6米。精确记录见 `same-camera-audit.json`、`before/provenance.json`。
- 最终包八项回归全部exit0/PASS：维修棚门窗墙顶碰撞及入口通行、服务道路42条往返路线、西车间与仓库通行、三枪108样本瞄准、武器遮挡、网络状态规则、16角色单机烟测（换弹/治疗/伤害/胜利等）。图形模式背景检查18座山体、18,920棵树，树根最大误差0.000121米。`artifacts/realism251-validation/verification-summary.json` 确认三次截图通过、相机一致、构建哈希匹配、测试使用最终包、日志无错误；逐项原始日志见 `verified/`。网络规则不替代真实双客户端，自动路线不等于整图人工走查，软件Vulkan不代表目标硬件性能。
- 本地预览：`./artifacts/realism251-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，保留相邻PCK，在图形桌面选择SOLO；操作见预览README。未推送、发布或修改后台服务，保留所有既有未提交修改。
- 下一阶段优先实际修改建筑钢架材质与室内外光照，用相同机位检查高频锈斑尺度/覆盖率和屋面曝光；继续改善地表清晰度。保留第三人称人物、三枪/手部连续动作、stage225换弹上臂遮屏、真实双客户端联机、Android fix4整合及LOD/目标硬件性能验证。整体continue。

### stage252 — 维修棚钢材、屋面与局部照明（2026-09-16）
- 修改 `shelter_structural_steel.gdshader`：均匀高频锈点改为柱脚与局部锈斑，加入屏幕导数过滤；`shelter_metal.gdshader` 降低屋面漆色、粉化与高光；`world_visuals.gd` 调低入口、外坪、室内及工作台补光。保留251植被与轮迹。入口钢柱、横梁外侧和排水管褐色颗粒明显减少，侧面屋面略暗；宽景改善有限，梁柱白色碎斑、地表模糊、远山圆锥感仍明显，整体目标未完成。
- 人工逐张审阅251→252宽景、入口与侧面同机位实机截图：`artifacts/realism252-validation/review.html`、`visual-review.md`。Before来源哈希见 `before/provenance.json`；After为252导出包单机固定模拟、1280×800 Forward+软件Vulkan。玩家坐标/yaw/pitch：宽景(17,0.05,50)/0.422853926132941/0.067315194971276；入口(15.5,0.05,39)/0/0.0541137822480691；侧面(7.5,0.05,37)/-0.714090698612158/0.0251843095291505；眼高另加1.6米。逐字段一致见 `same-camera-audit.json`。
- 最终包八项回归全部exit0/PASS：维修棚门窗墙顶碰撞及双向入口通行、服务道路42条路线、西工坊与仓库通行、三枪108样本瞄准、武器遮挡、网络状态规则、16角色单机烟测（换弹/治疗/伤害/胜利等）。背景图形检查18座山体、18,920棵树、4,305幼树，树根最大误差0.000121米。`artifacts/realism252-validation/verification-summary.json` 确认截图通过、相机一致、源码及构建哈希匹配、测试使用最终包、日志无错误；原始日志见 `verified/`。网络状态规则不代替真实双客户端；自动通行不等于整图人工走查；软件Vulkan不代表目标硬件帧率。
- 本地预览：`./artifacts/realism252-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，图形桌面选择SOLO，保持相邻PCK；操作见预览README。未推送或发布，未修改后台服务，保留既有未提交修改。
- 下一阶段优先隔离梁柱残余白斑（材质/阴影/重叠几何），改善大面积地面尺度与远山轮廓，再用相同机位验证。保留第三人称人物、三枪/第一人称手部连续动作、stage225换弹上臂遮屏、真实双客户端联机、Android fix4整合及LOD/目标硬件性能验证。整体continue。

### stage253 — 铁丝网透明噪点与钢架阴影隔离（2026-09-16）
- 修改 `world_visuals.gd`：后门铁丝网由透明哈希改为 alpha-scissor + alpha-to-coverage；`world.gd` 调整太阳阴影偏移，保留太阳与局部灯光投影。252包分别关闭局部阴影、SSIL、太阳阴影的实机诊断表明钢架白斑与太阳阴影相关；当前偏移仅部分改善，近处钢柱与斜撑仍有密集碎斑，不能标记修复完成。本轮未新增植被或改变地形，整体写实目标未完成。
- 人工审阅252→253宽景、入口及侧面同机位实机对照：`artifacts/realism253-validation/review.html`、`visual-review.md`。后门铁丝网、轮胎周边点状干扰减少，但建筑观感未大幅提升，地面模糊、远山圆锥感仍明显。Before来源及哈希见 `before/provenance.json`，机位及朝向见 `same-camera-audit.json` 与审阅表；1280×800 Forward+软件Vulkan，After使用253导出包进入单机固定模拟采集。
- 本地预览：`./artifacts/realism253-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，图形桌面选择SOLO，保持相邻PCK；操作见预览README。未推送或发布，未修改后台服务，保留既有未提交修改。
- 最终253包八项回归全部exit0/PASS：维修棚门窗墙顶碰撞及双向入口通行、服务道路42条路线、西工坊与仓库通行、三枪108样本瞄准、武器遮挡、联网状态规则、16角色单机烟测。背景图形检查18座山体、18,920棵树、4,305幼树，树根最大误差0.000121米。`artifacts/realism253-validation/verification-summary.json` 确认三次截图通过、相机一致、构建哈希匹配、测试使用最终包、日志无错误；原始日志见 `verified/`。联网规则不代替真实双客户端，自动路线不等于整图人工走查，软件Vulkan不代表目标硬件性能。
- 下一阶段转向正常机位大面积地表清晰度及山体轮廓，避免继续整轮局限于棚架微调。保留钢架阴影残余缺陷、第三人称人物、三枪/第一人称手部连续动作、stage225换弹上臂遮屏、真实双客户端联机、Android fix4整合及LOD/目标硬件性能验证。整体continue。

### stage254 — 服务道路碎石尺度与实机地表对照（2026-09-16）
- 修改 `world_visuals.gd`、`meadow_ground.gdshader`、`service_ground.gdshader`：三支服务道路新增3,200实例低矮角状碎石，轮迹缩小颗粒，两种地面材质加入分米级角状骨料与距离过滤。宽景前景碎石轮廓和接触阴影更清楚，入口/侧面收益有限；局部颗粒偏密，大面积泥地仍模糊。未改变建筑体量或光照，钢架白斑和远山圆锥感仍在，不能当作整体环境目标完成。
- 已逐张审阅253→254宽景、入口与侧面同机位实机截图：`artifacts/realism254-validation/review.html`、`visual-review.md`；Before来源哈希见 `before/provenance.json`。玩家坐标/yaw/pitch：宽景(17,0.05,50)/0.422853926132941/0.067315194971276；入口(15.5,0.05,39)/0/0.0541137822480691；侧面(7.5,0.05,37)/-0.714090698612158/0.0251843095291505；眼高另加1.6米。After由254导出包进入单机固定模拟采集，1280×800 Forward+软件Vulkan，详细比对见 `same-camera-audit.json`。
- 初次服务地面shader有未定义footprint错误，已修复、重新导出并重新采集/验证；失败证据保留 `initial-rejected/`，不混作通过结果。本地预览：`./artifacts/realism254-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，图形桌面选择SOLO，保持相邻PCK；操作见预览README。未推送或发布、未修改后台服务，保留既有未提交修改。
- 下一阶段优先远山轮廓与大面积裸地/植被过渡，同时继续隔离钢架白斑；保留第三人称人物、三枪/第一人称手部连续动作、stage225换弹上臂遮屏、真实双客户端联机、Android fix4整合及LOD/目标硬件性能验证。整体continue。
- 最终254包八项回归全部exit0/PASS：维修棚门窗墙顶碰撞及双向入口通行、服务道路42条路线、西工坊与仓库通行、三枪108样本瞄准、武器遮挡、联网状态规则、16角色单机烟测（换弹/治疗/伤害/胜利等）。背景检查18座山体、18,920棵树、4,305幼树，树根最大误差0.000121米。`artifacts/realism254-validation/verification-summary.json` 确认三次截图通过、相机一致、构建哈希匹配、测试使用最终包、最终日志无错误；原始日志见 `verified/`。自动路线不等于整图人工走查，联网规则不代替真实双客户端，软件Vulkan不代表目标硬件性能。整体continue。


### Stage255 — 远山宽山肩与偏置山脊；整体目标继续
- 按实际 stage254 检查点推进环境阶段。修改 `client/scripts/world_visuals.gd` 山体高度函数，扩大山肩、延长山脊、改变峰顶宽度及鞍部偏移；网格与林木继续共用高度函数。本轮没有修改建筑、地表材质或光照，不将远景局部改善当作整体完成。
- 实机对照：`artifacts/realism255-validation/review.html`，人工结论 `visual-review.md`；宽幅地形、维修棚入口和侧面三组 stage254→255 同机位截图，完整相机与散列见 `same-camera-audit.json`。玩家位置/yaw/pitch 分别为 (17,.05,50)/.4228539261/.0673151950、(15.5,.05,39)/0/.0541137822、(7.5,.05,37)/-.7140906986/.0251843095，眼高 +1.6；1280×800 Forward+ 软件 Vulkan。
- 审阅：左右山肩更宽、轮廓更连贯；重复尖峰与树林仍存在。前景裸土模糊、草地过渡稀疏、近处叶片偏大，钢柱白斑及阴影网点明显；入口建筑本身尚未改善。
- 验证：八项功能检查全部 PASS（维修棚/道路/车间/仓库碰撞通行，三枪108瞄准采样，武器遮挡，联网状态规则，16角色单机冒烟含换弹/治疗/伤害/胜利）。额外18山体、18634树、4219幼苗贴地检查 PASS，最大误差0.000133米。三次截图 PASS，36项构建散列匹配，测试前后最终包一致，无审计错误。证据：`artifacts/realism255-validation/verification-summary.json`、`verified/functional-results.json`、`verified/background_scenery.log`。规则检查不代表实际双客户端联机，固定机位和自动通行不代表人工全地图验收。
- 本地预览：`./artifacts/realism255-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`（图形桌面下选择 SOLO；说明见同目录上级 README.md）。未推送或外部发布，保留原有修改。
- 下一步：优先定位并修复正常机位大片裸土模糊的具体材质层，改善植被地面过渡和叶片比例，结合入口钢架白斑/阴影网点处理近景光照；继续处理重复建筑与森林。保留第三人称人物、第一人称三枪手臂及连续换弹（含历史上臂遮挡）、真实双客户端联机、Android与目标硬件性能任务。状态 continue。


### Stage256 — 压实土壤细节与道路低草过渡；整体目标继续
- 调整 `service_ground.gdshader` 的压实土壤混色、起伏及随像素覆盖淡出的细颗粒，提高各向异性过滤；缩小一类阔叶植被，在道路两侧增加独立种子的稀疏低草。仅本轮改动见 `artifacts/realism256-validation/stage256-changes.patch`。没有修改建筑和光照，未将局部改善当作整体完成。
- 同机位实机对照与人工审阅：`artifacts/realism256-validation/review.html`、`visual-review.md`；三组255→256截图涵盖宽幅地形、维修棚入口及侧面。位置/yaw/pitch 分别为 (17,.05,50)/.4228539261/.0673151950、(15.5,.05,39)/0/.0541137822、(7.5,.05,37)/-.7140906986/.0251843095，眼高+1.6；完整参数及图片散列见 `same-camera-audit.json`。1280×800 Forward+ 软件Vulkan。
- 审阅：宽幅视角右侧叶片比例和裸土至高草的过渡有所改善；入口土壤仅有轻微颗粒增益，侧面变化很小。大片泥土仍显模糊，侧门附近另一类高大植物未改善；钢柱网点状阴影、金属泛白、重复远山和工业建筑仍明显。不能按截图数量判断画质达标。
- 最终包八项检查全部 PASS：维修棚、道路42路线、西工坊及仓库碰撞通行，三枪108瞄准采样，武器遮挡，联网状态规则，16角色单机烟雾测试（换弹/治疗/伤害/胜利等）。额外18山体、18634树、4219幼苗贴地检查 PASS，最大误差0.000133米。三次截图通过，相机一致，36项构建散列匹配，测试前后最终包一致，最终日志无审计错误。证据：`verification-summary.json`、`verified/functional-results.json`、`verified/` 原始日志；首次编译命名冲突已修复，失败日志保存在 `initial-rejected/`。联网规则不等于真实双客户端；自动通行不等于全地图人工验收，软件Vulkan不代表目标硬件性能。
- 本地预览：`./artifacts/realism256-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`（图形桌面选择 SOLO；启动说明见 `artifacts/realism256-preview/README.md`）。保留原有未提交修改，未推送或外部发布。
- 下一步：固定入口机位，隔离入口聚光灯/补光投影和钢材着色，定位网点阴影并改善泛白板材，让下一阶段在建筑和光照上产生明显收益；当前尚不能确定阴影根因。继续处理裸土模糊、过大植被及重复远景。保留第三人称人物、第一人称三枪手臂与连续换弹/上臂遮挡、真实双客户端联机、Android及目标硬件性能验证。状态 continue。

### Stage257 — 维修棚涂漆、太阳阴影与道路植被；整体目标继续
- 改动棚顶着色为较暗高粗糙度涂漆，降低道路程序碎粒反差并随机旋转轮廓，增加车辙外路肩低草宽度和高度变化；太阳 shadow_bias .25→1.0、normal_bias .8→1.5。没有重建建筑布局。保留已有修改；`stage257-changes.patch` 是已有的人物记录，不是本轮环境补丁。
- 实机前后对照：`artifacts/realism257-validation/review.html`、`visual-review.md`。宽幅地形、入口、侧面位置/yaw/pitch 为 (17,.05,50)/.4228539261/.0673151950、(15.5,.05,39)/0/.0541137822、(7.5,.05,37)/-.7140906986/.0251843095，眼高+1.6；1280×800 Forward+ 软件Vulkan。相机与图片散列见 `same-camera-audit.json`。
- 入口同包诊断：旧太阳偏移下关闭44盏局部灯阴影，钢柱黑色网点仍存在；关闭太阳阴影后消失，支持该处太阳自遮挡来源。正式包使用新偏移，网点明显减少且保留门口斜向投影；见 `controlled-light-audit.json`、`capture-provenance.json`。棚顶更像暗色涂漆、路肩草丛更饱满；裸土仍模糊、实体碎石及远山重复、门板偏亮及少量亮点尚未解决，枪身与直筒袖口仍生硬。
- 最终包八项检查全部 PASS：四组建筑/道路碰撞通行、三枪108瞄准采样、武器遮挡、联网状态规则、16角色单机冒烟（换弹/治疗/伤害/胜利等）。六张截图采集成功、相机一致、37项构建散列匹配，测试/截图前后最终包一致，最终日志无审计错误。证据：`artifacts/realism257-validation/verification-summary.json`、`verified/functional-results.json` 及原始日志。规则测试不等于实际双客户端联机，固定机位与自动通行不等于全地图人工验收，软件Vulkan不代表目标硬件性能。
- 本地预览：`./artifacts/realism257-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，图形桌面选择 SOLO；说明见 `artifacts/realism257-preview/README.md`。未推送或外部发布。
- 下一步按最新环境优先级转入人物及三枪完整动作：第三人称正面/侧面3米、10米，第一人称常态/ADS/完整换弹连续关键帧，记录相机、距离和时间及包/脚本散列；优先修复轮廓、持枪姿态、弹匣交接与上臂遮挡，并回归瞄准/遮挡/单机。继续保留地表、重复场景、真实联机、Android及目标硬件验证。状态 continue。


### Stage258 — 第三人称软背包轮廓与动作采样扩展；整体目标继续
- 按最新 stage257 后续优先级审阅人物。`tools/build_operator.py` 将布背包硬直轮廓改为上下收束的多段弧面、压缩带凹凸和弯曲外袋/接缝，重新生成 Blender 与 operator.glb；本轮隔离补丁见 `artifacts/realism258-validation/stage258-operator.patch`。3米侧面改善可辨认，正面和10米收益很小，布料仍平、小腿偏细、靴子过大、持枪姿态僵硬，不能作为人物目标完成。
- stage257→258 正面/侧面3米、10米同机位实机对照：`artifacts/realism258-validation/review.html`、`operator-3m-comparison.jpg`、`operator-10m-comparison.jpg`、`visual-review.md`。角色(0,.05,68)、yaw/pitch0；相机3米正面(0,1.55,65)、侧面(3,1.55,68)，旋转分别(-.18131977,3.14159274,0)/(-.18131977,1.57079637,0)；10米正面(0,1.55,58)、侧面(10,1.55,68)，旋转分别(-.054944638,3.14159274,0)/(-.054944638,1.57079637,0)。FOV65，1280×800 Forward+软件Vulkan。完整相机/原图散列见 `same-camera-audit.json`，本轮未重复环境三机位截图。
- `tests/action_timeline_capture.gd` 增加 ADS 过程及持续开火采样、弹药消耗断言与 aiming/fire_left 记录。但完整实机采样约每图一分钟，主动终止了未完成的长序列；仅6张武器0局部截图，没有完整动作manifest/PASS。记录见 `action-capture-incomplete.json`；已查看过渡及最终ADS原图，枪身平、袖口直筒问题仍在。三枪完整换弹/持续开火/切枪、第三人称动态及动画规则尚未验证，不能把脚本覆盖范围当作实际通过。
- 当前本地预览：`./artifacts/realism258-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`（图形桌面选择 SOLO，保留相邻PCK；操作见 `artifacts/realism258-preview/README.md`）。PCK SHA256 `b573fe26fdeddd4b6e05bc3adfb55ff569e090c0044f97d6b04848bdb92bd00f`。未推送或发布、未修改后台服务，保留所有既有未提交修改。
- 下一步：先降低完整动作审阅的采样开销并补齐三枪换弹结束、连续开火/切枪和第三人称运动证据，再据实修正靴子/小腿比例及握持姿态；继续保留第一人称上臂遮屏、地表模糊、重复山林/建筑与光照残余缺陷，以及真实双客户端联网、Android和目标硬件性能验证。状态 continue。
- 最终验证补记：九项检查全部 PASS（四组建筑/道路通行碰撞、三枪108瞄准采样、武器遮挡、联网状态规则、前臂四动画968采样、16角色单机冒烟）；44项构建文件散列一致，测试前后PCK一致。汇总 `artifacts/realism258-validation/verification-summary.json`、原始结果 `verified/functional-results.json`。完整动作采样仍明确为未通过/未完成，动画规则与真实联机未运行。

### Stage259 — 维修棚挡风屏、道路碎石与草丛尺度；整体目标继续
- 按当前环境优先级实施：维修棚西侧增加十三条木板及钢支撑，新增局部木材着色器；道路碎石3200→1200并缩小、下沉、调浅，路边草丛降低高度并调整成簇分布；棚内补光0.48→0.65、工作台聚光2.4→1.8。保留所有既有未提交修改，未推送、发布或修改后台服务。
- stage258→259 正常游戏机位前后对照：`artifacts/realism259-validation/review.html`、`same-camera-audit.json`、`visual-review.md`。入口角色(15.5,.05,39)、yaw/pitch(0,.054113782)；侧面(7.5,.05,37)、(-.714090699,.025184310)；宽幅(17,.05,50)、(.422853926,.067315195)。眼高偏移1.6米，1280×800 Forward+软件Vulkan；三组相机完全一致，前后各3帧实机截图均PASS。
- 实际审阅：入口侧屏与宽幅过大黑碎石减少清楚可辨，中央入口仍开放，车辙更清晰；木板仍均匀、大片泥地模糊平滑、沟边岩石棱角大，棚顶亮斑和硬三角阴影、重复山林仍存在，补光收益有限。不能以截图数量或局部变化认定整体写实目标完成。
- 新增挡风屏真实角色胶囊阻挡、木板与板缝射线验证，保留中央双向通行；功能逐项日志见 `verified/functional-results.json`，最终汇总见 `artifacts/realism259-validation/verification-summary.json`。打包后扩展的外部碰撞测试散列单列于 `review-provenance.json`，并未改动游戏包。
- 本地预览：`./artifacts/realism259-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，图形桌面选择 SOLO，保留相邻PCK；说明 `artifacts/realism259-preview/README.md`。PCK SHA256 `44ac9c30d5610a11ac52d3106e0bc4a3745bb66f3a539f62ff3ce853f04414c3`。
- 下一步：继续解决正常机位的泥地材质过渡、棚顶亮斑与硬阴影，保留建筑/地形宽幅同机位审阅；结合stage258未完成项补齐三枪换弹、持续开火/切枪与第三人称动态，再修正靴子/小腿比例及握持姿态。真实双客户端联网、Android和目标硬件性能尚未验证，本轮联网状态规则不能替代实际联网。状态 continue。
- 最终验证补记：九项检查全部PASS（四组建筑/道路碰撞通行、三枪108瞄准采样、武器遮挡、联网状态规则、前臂四动画968采样、16角色单机冒烟）。三组同机位原图散列核验通过，44项构建文件一致；打包后扩展的外部碰撞测试单独核验，测试前后PCK一致。最终汇总 `artifacts/realism259-validation/verification-summary.json`，逐项日志 `artifacts/realism259-validation/verified/`。真实双客户端联机与完整动作截图仍未验证。

### Stage260 — 小腿与战斗靴比例、第三人称动态审阅；整体目标继续
- 按最新审阅检查点推进人物阶段：增大小腿裤管体积、缩短并降低战斗靴鞋面、调整鞋带位置，仅重建人物资产。阶段独立差异 `artifacts/realism260-validation/stage260-operator.patch`；环境沿用stage259，本轮没有新增建筑、植被或光照改进。保留所有既有未提交修改，未推送、发布或修改服务。
- 同机位stage259→260四组3米/10米正面与侧面对照：`artifacts/realism260-validation/review.html`、`same-camera-audit.json`，原图位于 before/operator 与 after/operator。人物(0,.05,68)，相机3米(0,1.55,65)/(3,1.55,68)、10米(0,1.55,58)/(10,1.55,68)，yaw为π/π÷2，pitch分别-.18131977/-.05494464，FOV65；精确姿态见camera.json。软件Vulkan Forward+ 1280×800。
- 实际审阅：3米靴头楔形和细小腿有所改善，10米收益小，头脸与装备仍像人偶。第三人称41关键帧/438tick采集通过，已打开0055行走、0198蹲走、0283换弹和0415恢复Idle：存在膝部截断感、手与枪接触不自然、脚底与阴影分离。grounded=true与根节点y=.000738不能证明鞋底接地，也不能直接把阴影偏移认作离地距离；尚未查明根因。详情 `artifacts/realism260-validation/visual-review.md`，动作机位/状态 `after/actions/action-timeline.json`。
- 最终包九项功能检查通过：四组建筑/道路碰撞通行、三枪108瞄准采样、武器遮挡、网络状态规则、前臂968采样及16角色单机冒烟。无窗口animation_rules因需要渲染服务器退出1，保留原始失败；随后图形模式重跑退出0、ANIMATION_RULES_PASS。该规则不验证世界坐标脚底接地，不能代替视觉审阅。汇总 `artifacts/realism260-validation/verification-summary.json`，原始日志 verified/ 与 after/animation/capture.log；构建45项散列一致，测试前后PCK一致。
- 当前本地预览：`./artifacts/realism260-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，图形桌面选择SOLO并保留相邻PCK；说明 `artifacts/realism260-preview/README.md`。PCK SHA256 `2a1c55ad9fe5820a2ce0970a80d7514458613f28d27c2ad65098a067adca2a8b`。
- 下一步：先量测动态蒙皮鞋底世界坐标、地面射线距离并对照旧包同动作时刻，修正蹲姿膝部与接地问题；补齐三枪第一人称瞄准/持续开火/换弹/切枪实机动作审阅及握持修正。继续保留泥地过渡、棚顶亮斑硬阴影及重复山林问题，并按环境同机位入口/宽幅截图复核后续修改。真实双客户端联机、Android和目标硬件性能仍未验证，状态continue。


### Stage261 — 维修棚地坪分块与车位线、路肩草丛及入口补光；整体目标继续
- 按当前环境优先级推进：地坪增加磨损车位边线、浇筑块色差和接缝，降低地坪法线幅度；弯道路肩草丛240→420并扩大簇宽；调整入口补光方向、范围和能量。保留既有未提交修改，未推送、发布或修改后台服务。
- stage260→261三组正常机位前后实机截图均采集PASS：入口角色(15.5,.05,39)、yaw/pitch(0,.054113782)；侧面(7.5,.05,37)、(-.714090699,.025184310)；宽幅(17,.05,50)、(.422853926,.067315195)。眼高偏移1.6米、1280×800 Forward+软件Vulkan。对照入口 `artifacts/realism261-validation/review.html`、精确机位 `same-camera-audit.json`、逐图结论 `visual-review.md`。
- 实际审阅：入口车位边线可辨认，地坪分块色差较轻；草丛整体观感很接近旧版，补光未消除顶棚亮斑和硬三角阴影，不能认定植被/光照已有显著改善。均匀梁柱、模糊泥地轮迹、棱角石块、重复山林仍明显，整体画质目标尚未完成。
- 当前本地预览：`./artifacts/realism261-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，图形桌面选择SOLO，保留相邻PCK；说明 `artifacts/realism261-preview/README.md`。PCK SHA256 `443d262ef3a41f7519ed1959e6c69c2edac0399c07c8555822c1fe924fff94c8`。
- 下一步：环境继续优先解决轮迹模糊宽带、路肩草簇层次和棚内亮斑/硬阴影，以相同入口/宽幅机位复核真实收益；随后结合stage260动态蒙皮鞋底坐标测量修正膝部及接地，并补齐三枪第一人称完整动作和握持审阅。真实双客户端联网、Android和目标硬件性能仍待验证；状态continue。
- 最终验证补记：stage261的9项功能测试全部PASS（四组建筑/道路通行、三枪瞄准108采样、武器遮挡、网络状态规则、前臂4动画968采样、单机冒烟16角色及换弹/治疗/伤害/胜利等）；退出码均0且无错误标记。45个构建文件散列一致，3组前后截图机位一致。汇总 `artifacts/realism261-validation/verification-summary.json`，原始日志 `artifacts/realism261-validation/verified/`。网络状态规则通过不代表真实双客户端联机已验证。


### Stage262 — 缩窄减淡道路车辙、圆缓远山轮廓；整体目标继续
- 以stage261冻结包为前图，修改service_ground.gdshader的轮迹宽度、暗化与矿物色过渡，并调整world_visuals.gd远山高度函数的峰顶圆度和噪声。未改建筑、灯光或植被布局；本轮仅完成环境阶段中的地表与远景部分，不能认定整组环境目标完成。
- 三组1280×800 Forward+软件Vulkan实机截图已保存：入口脚点(15.5,.05,39)、yaw/pitch(0,.054113782)；侧面(7.5,.05,37)、(-.714090699,.025184310)；宽幅(17,.05,50)、(.422853926,.067315195)，眼高1.6m。原图before/和after/、逐图审阅visual-review.md均位于artifacts/realism262-validation/。
- 实际观察：宽幅黑色车辙明显减轻，远山重复尖峰减少；近景泥土仍模糊，圆缓山丘仍重复，草树排列仍规则。入口棚顶亮斑、硬三角阴影及均匀梁柱未解决。
- 当前本地预览：./artifacts/realism262-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus，图形桌面选择SOLO并保留相邻PCK；说明artifacts/realism262-preview/README.md。
- 下一步仍优先改维修棚入口灯具照射范围与棚顶亮斑、建筑构架细节和路肩裸土/植被疏密过渡，以相同入口及宽幅机位复核；随后继续第三人称膝部/鞋底接地和三枪第一人称完整动作审阅。真实双客户端联网、Android及目标GPU性能仍待验证，状态continue。
- 最终验证：九项导出包测试全部PASS：四组建筑/道路碰撞通行、三枪108项瞄准采样、武器遮挡、网络状态规则、前臂四动画968采样、16角色单机冒烟（换弹/治疗/伤害/胜利等）。45项构建散列一致，测试前后PCK一致，三组前后机位完全一致且截图进程退出0、无错误标记。对照入口artifacts/realism262-validation/review.html；机位与截图散列same-camera-audit.json；汇总verification-summary.json，原始日志verified/。PCK SHA256 c0800db1d202da6ec64cc8965ce83c9a35ba0d125cfed144a3a43337e984ddf5。


### Stage263 — 维修棚波纹受光、树群轮廓与碎石露出；整体目标继续
- 修改shelter_metal.gdshader的波纹法线与板片色差；world_visuals.gd调整路边树冠高低/比例，并修复碎石低于道路面被遮住的问题（1200→2100实例，部分嵌入、车辙处较小）。未调整全局灯光，不代表入口光照问题已解决。
- stage262冻结包与stage263预览完成三组相同机位实机前后对照，入口/侧面/宽幅位置朝向完整见artifacts/realism263-validation/same-camera-audit.json；对照review.html，逐图观察visual-review.md。Forward+软件Vulkan、1280×800、固定第60帧。
- 实际收益：侧面棚顶波纹起伏明显，树群轮廓有变化，宽景碎石终于露出。缺陷：碎石偏白且散布均匀，泥土地表模糊、远山重复圆丘、树冠稀薄仍在；入口暖色热点与背墙硬影未解决。不能以新增细节或截图数量认定画质达标。
- 当前本地预览：./artifacts/realism263-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus；图形桌面选择SOLO，保留相邻PCK，见artifacts/realism263-preview/README.md。
- 下一步：优先降低碎石亮度并增加土色与成片疏密；以同PCK同入口机位隔离RepairApronReflectedDaylight与shelter_bounce的贡献后改灯光。随后结合第三人称鞋底/膝部/背包及三枪开火+1/+3/+6帧、换弹与握持审阅继续完善；历史animation_rules失败仍未关闭，真实双客户端联网、Android、目标GPU性能待验证。状态continue。
- 最终验证：九项导出包测试全部PASS：四组建筑/道路碰撞通行、三枪108项瞄准采样、武器遮挡、网络状态规则、前臂四动画968采样及16角色单机冒烟（换弹/治疗/伤害/胜利等）。45项构建散列一致，测试前后PCK一致；三组前后机位完全一致，截图进程退出0且无错误标记。汇总artifacts/realism263-validation/verification-summary.json，原始日志verified/，机位与截图散列same-camera-audit.json。PCK SHA256 7be51f0d688ec2d8caaa758ad339f0f7d93b8f46fbdf22f97b1b0642922df28b。网络规则通过不等于真实多人验证，前臂数值检查不等于完整动作画质通过。

### Stage264 — 维修棚照明、连接构造与路肩分布（2026-09-16）
- 在 stage263 冻结预览包上完成入口同机位逐灯隔离：分别关闭 apron / bounce / porch，日志确认每次仅改一灯。前两项仍有顶棚亮斑，关闭 porch 后减弱；将该全向灯改为灯带下方朝下聚光灯，保留能量与阴影。补充棚梁端板/六角螺栓，入口草丛随机簇化，路肩碎石调暗并簇化、减少轮迹颗粒。仅修改 world_visuals.gd，阶段差异单独保存，保留原有未提交修改。
- 实机审阅：顶棚黄色亮斑明显消退，入口/侧面连接板可辨，白色纸屑状碎石感减弱；植被改善较轻。后墙大块硬三角阴影仍存在；宽幅道路空旷、远山重复、树冠与地表纹理、周边矩形建筑仍未达标，不将本阶段视为整体完成。
- 相同机位前后入口、侧面、宽幅地形截图与位置/朝向：artifacts/realism264-validation/review.html；原图 before/、after/，same-camera-audit.json 确认 3 组一致。逐灯证据 light-isolation-audit.json，审阅 visual-review.md，源码差异 world_visuals.stage264.diff。
- 导出包九项检查全部退出 0、无错误、具 PASS：shelter_frame/service_lane/west_workshop/depot 通行碰撞、aim_alignment（三枪108样本）、weapon_obstruction_rules、network_status_rules、forearm_asset_rules（968样本）、offline-smoke（16角色、换弹/治疗/伤害/胜利等）。日志在 verified/，汇总 verification-summary.json；45 个构建文件哈希一致。联网规则并非真实双客户端，手臂数值检查不替代动作实机审阅，软件 Vulkan 不代表目标显卡性能。
- 本地预览：artifacts/realism264-preview/Linux/IronMeridian（同目录 .pck）；从项目根运行 `./artifacts/realism264-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，菜单 SOLO。测试前后 PCK SHA256 均为 18c8498cc9cf273869f5ee1170098ac02a42cb1c6f3becc8d802774a44967700。未推送或发布。
- 下一步：结合第三人称 3m/10m 实机检查 stage260 膝部裤装截断与脚底悬空，核对蒙皮顶点/权重与地面射线，避免仅挪角色根节点；补齐三枪瞄准/射击/换弹手部审阅与真实双客户端主要流程。继续追查棚内硬阴影、宽幅地形重复与空旷，保留建筑/人物/武器整体写实目标。状态 continue。

### Stage265 — 桦树分枝与中下部树冠体积（2026-09-16）
- 修改 tools/build_verge_birch.py 并重新生成 Blender / GLB 资产：不规则上升主枝、下垂末梢和枝端叶簇，使中下部树冠丰满；树干碰撞及摆放保持原状。源码快照、阶段差异与生成日志位于 artifacts/realism265-validation/。保留所有既有未提交修改，未推送或发布。
- 实机逐张审阅入口、侧面、宽幅地形：侧面及宽景树冠变化可辨，入口通道仍可见；树梢仍偏规则。绿色梁柱积木感、等距格栅、分段棚顶、模糊地面、重复远山、空旷道路以及枪体/袖管问题仍在。本轮是局部植被改善，没有重新设计建筑或灯光，不视为整体目标完成。
- 三组相同机位前后对照：artifacts/realism265-validation/review.html，原图 before/、after/；before 明确复用 stage264 冻结留存图，本轮未重拍。same-camera-audit.json 记录位置、俯仰、朝向和截图散列，确认三组一致；visual-review.md 记录逐机位结论。
- 导出包九项回归全部 PASS、退出0且无错误：四组建筑/道路碰撞通行、三枪108项瞄准、武器遮挡、网络状态规则、前臂968项数值采样及16角色单机冒烟（换弹/治疗/伤害/胜利等）。verification-summary.json 确认45项构建散列一致，原始日志 verified/；测试前后 PCK SHA256 均为 1100938b8dd03e3d0ec9d730aafb2d4672575cc125c42cb43a09fda21382dbbc。
- 当前本地可运行预览：`./artifacts/realism265-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，图形桌面菜单选择 SOLO，保留同目录 .pck；说明 artifacts/realism265-preview/README.md。软件 Vulkan 不代表目标显卡性能；网络状态规则不等于真实双客户端验证，前臂数值通过不等于动作画质达标。
- 下一步：按最新环境审阅优先级修正动作采样器，补齐三枪实际开火 +1/+3/+6 tick、恢复、连续射击与完整换弹的实机审阅及枪腕/相机变换证据；继续第三人称膝部、脚底缺陷和真实双客户端主要流程。保留建筑、地表、光照与远山整体写实目标。状态 continue。

### Stage266 — 修复动作采样与卡宾枪局部实机审阅（2026-09-16）
- 按 stage265 检查点修正 tests/action_timeline_capture.gd：依据实际接受射击采样 +1/+3/+6/+24 tick，覆盖连发、完整换弹和真正归零后的相机/枪体恢复；保存枪腕变换。补充逐样本原子写入 partial JSON，语法及独立合成覆盖写入测试通过，但新增增量机制尚未用于完整实机运行。阶段差异 artifacts/realism266-validation/sampling-change.patch。
- 独立数值流程 PASS：214 样本、1937 tick、29 次接受射击，三枪恢复及换弹通过；numeric-coverage-audit.json、numeric/action-timeline.json 和 numeric-check.log 可核查。数值文件中的计划图名不是实际截图。
- 实机仅完成卡宾枪腰射、ADS、单发 +1/+3/+6/+24 共九张，review.html、actions/、partial-render-evidence.json 与 visual-review.md 保存证据。软件 Vulkan 采样成本高，单发阶段后主动终止；完整渲染未 PASS，且本次没有落盘实际相机/枪腕元数据。脚本设定角色起点 (17,0.3,50)、yaw=0、pitch=0.1rad；独立数值变换不能替代截图运行测量。
- 实机未见这组单发画面明显手腕脱枪；机匣平板、厚瞄具、直袖管、绿色方梁、重复格栅、分段拱顶、模糊地面与规则远山仍突出。本轮未改画质资产，不声称视觉改善或整体完成。
- 冻结 stage265 包九项回归全部 PASS（四组通行碰撞、三枪瞄准、武器遮挡、网络状态规则、前臂骨长、单机冒烟），verified/functional-results.json 与 verification-summary.json 保存结果。真实双客户端、第三人称3m/10m及剩余动作实机仍未完成。
- 当前本地预览继续使用 `./artifacts/realism265-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，菜单 SOLO；同目录 .pck SHA256 为 1100938b8dd03e3d0ec9d730aafb2d4672575cc125c42cb43a09fda21382dbbc，验证前后一致。未推送或发布，保留已有修改。
- 下一步：分段补齐三枪连发/换弹/恢复实机及实际变换，审阅第三人称膝部脚底；据缺陷实施可辨识模型材质改进，避免持续只改测试设施。环境仍需方梁/格栅/拱顶与地表改进，保存同机位前后、入口近景和宽幅地形并验证通行；补真实双客户端主要流程。状态 continue。

### Stage267 — 维修棚连续钢拱与入口钢柱（2026-09-16）
- 修改 client/scripts/world_visuals.gd：四道叠块拱梁改为64段连续曲面、带腹板和内外翼缘的钢拱；两根门廊实心方柱改为工字钢截面，并保留碰撞。入口及侧面实机可辨弧线与截面明暗，宽幅整体提升有限；粗横梁、重复格栅、模糊地面、规则植被与远山仍明显。本轮未改地表、植被、光照，不代表环境组合阶段或整体目标完成。
- artifacts/realism267-validation/review.html、visual-review.md 保存审阅；before/ 为 stage265 冻结包基线（有来源哈希），after/ 为 stage267 包实际生成的入口、侧面和宽幅截图。camera-comparison.json 确认三机位位置、朝向、目标、眼高和1280×800视口完全一致；动态草云存在时序差异。入口角色(15.5,0.05,39),yaw0,pitch0.054113782；侧面(7.5,0.05,37),yaw-0.714090699,pitch0.025184310；宽幅(17,0.05,50),yaw0.422853926,pitch0.067315195，眼高1.6，完整精度见JSON。
- 冻结包九项回归全 PASS：棚屋/维修通道/车间/仓库通行碰撞、三枪108样本瞄准、武器遮挡、网络状态规则、前臂968样本及16角色单机冒烟。verified/functional-results.json、各测试日志和 verification-summary.json 为证据；网络规则不等于真实双客户端。45项构建文件哈希复核无差异，截图进程退出0且PASS。
- 当前本地预览：`./artifacts/realism267-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，菜单 SOLO。同目录 .pck SHA256 b6462aefa7d0cc05be4c2b66b156af3016884e3096c0f57a20d8aea0012e4e30，验证前后一致。保留所有已有修改，未推送或发布。
- 下一步优先实施地表纹理尺度/路肩植被疏密/建筑光照层次组合改善，兼顾粗横梁和重复格栅；继续相同机位实机对照与入口通行验证，不再仅细调钢拱。保留三枪连发/完整换弹/恢复截图与实际变换、第三人称3m/10m膝脚、第一人称手部和真实双客户端主要流程验证。状态 continue。

### Stage268 — 棚屋百叶、地表尺度与路肩草丛（2026-09-16）
- 修改 world_visuals.gd、porch_timber.gdshader、service_ground.gdshader：十三根浅色横条替换为九块下部竖板和四片倾斜上部百叶，降低木材亮度并加入方向性风化纹理；调整地表纹理尺度，草丛改为宽度不同且边缘稀疏的三组分布。百叶改变局部遮光，未修改全局光照。侧面正常游戏机位改善明确，宽幅提升有限；木板仍平、泥地仍模糊、绿色横梁粗重、部分灌木与远山重复，整体目标未完成。
- artifacts/realism268-validation/review.html、visual-review.md 保存三组实机前后审阅。before/ 复用 stage267 冻结包截图（before-provenance.json 记录来源），after/ 为本轮冻结包新截图。camera-comparison.json 确认位置、朝向、眼高和1280×800视口完全一致：入口(15.5,0.05,39),yaw0,pitch0.054113782；侧面(7.5,0.05,37),yaw-0.714090699,pitch0.025184310；宽幅(17,0.05,50),yaw0.422853926,pitch0.067315195，眼高1.6，完整精度见JSON。动态草云存在时序差异。
- 九项冻结包回归全部 PASS：四组建筑通行碰撞、三枪108样本瞄准、武器遮挡、网络状态规则、前臂968样本和16角色单机冒烟。维修棚额外验证四次胶囊穿越、侧屏阻挡、竖板/百叶命中及百叶缝隙射线通过；对应更新 tests/shelter_frame_traversal_review.gd。verified/functional-results.json、各日志与 verification-summary.json 可复核。45项构建文件哈希无变化，截图退出0且PASS。网络规则不等于真实双客户端；软件Vulkan不代表硬件帧率。
- 当前本地预览：`./artifacts/realism268-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，菜单 SOLO；README.md 记录启动方法。同目录 .pck SHA256 521799cb388b1410870e7b1e99ecb4e5d7a2e5235710376ad192fb70933d1c14，验证前后一致。source-change.diff 保存本轮增量，保留已有修改，未推送或发布。
- 下一步：第三人称3m/10m正侧面审阅膝部与靴底，结合蒙皮后脚底世界坐标/地面射线定位，避免整体下移掩盖问题；补三枪连射、完整换弹和恢复实机及实际变换，等待相机/武器稳定再捕获。环境继续改进粗梁、地面厚度感和植被层次，并保留真实双客户端及Android验证。状态 continue。

### Stage269 — 入口砌体柱脚、路肩过渡与局部照明（2026-09-16）
- 修改 world_visuals.gd、service_ground.gdshader：两根门廊钢柱增加带碰撞的砌体柱脚和顶盖，调整入口/地坪/室内局部补光；减少高路肩植被并增加高度过渡，调整车辙法线与压实地表粗糙度。入口柱脚正常机位可辨，宽幅高植被减少；光照和车辙受光改变较轻，未增加地形几何起伏。粗梁、偏金属观感木板、模糊泥地和重复远山仍明显，整体目标未完成。
- artifacts/realism269-validation/review.html、visual-review.md 保存逐图审阅。before/ 复用 stage268 冻结包基线（provenance.txt），after/ 为本轮冻结包三张1280×800实机截图。camera-comparison.json 确认位置、朝向、目标、眼高和视口完全相同：入口(15.5,0.05,39),yaw0,pitch0.054113782；侧面(7.5,0.05,37),yaw-0.714090699,pitch0.025184310；宽幅(17,0.05,50),yaw0.422853926,pitch0.067315195，眼高1.6，完整精度见JSON。草云有动态时序差异。
- 九项冻结包回归及新增柱脚碰撞探测全部 PASS：四组建筑/道路通行、三枪108样本瞄准、武器遮挡、网络状态规则、前臂968样本、16角色单机冒烟，另两根柱脚射线均命中z35.35。verified/functional-results.json、原始日志、porch-base-collision.json 与 verification-summary.json 可复核。截图退出0且PASS；45项构建文件哈希无差异。网络规则不代表真实双客户端，软件Vulkan不代表硬件或Android性能。
- 当前本地预览：`./artifacts/realism269-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，菜单 SOLO；README.md 记录启动方法。同目录 .pck SHA256 df625e8b1652c85429945f6867adbdaef02a154759d509a07dd07ed7f0dee0d3，验证前后一致。source-change.diff 保存本轮增量，保留所有已有修改，未推送或发布。
- 下一步继续处理粗横梁、木板厚度/粗糙度和地形植被层次；补第三人称3m/10m正侧面膝脚审阅及蒙皮后脚底世界坐标/地面射线，不整体下移掩盖缺陷。保留第一人称手部、三枪连射/完整换弹/恢复实机与实际变换、真实双客户端主要流程及Android验证。状态 continue。

### Stage270 — 雨棚入口构件比例与木板材质（2026-09-16）
- 修改 world_visuals.gd、porch_timber.gdshader：收细入口工字柱、连接板、檐口与排水管，将底板及螺栓移至砌体顶部；木板改为纵向细纹与底部潮湿色差，减弱宽条带的金属观感。入口正常机位可辨，宽幅提升很小；地表植被和光照沿用 stage269，本轮未新增改进。钢材均匀、砖块规则、泥地模糊和远山重复仍明显，整体目标未完成。
- artifacts/realism270-validation/review.html、visual-review.md 保存三组实机前后对照与逐图审阅；before/ 复用 stage269 冻结包截图，baseline-provenance.json 记录来源，after/ 为新冻结包实机截图。camera-comparison.json 确认位置、朝向、目标、眼高及1280×800视口完全一致：入口(15.5,0.05,39),yaw0,pitch0.054113782；侧面(7.5,0.05,37),yaw-0.714090699,pitch0.025184310；宽幅(17,0.05,50),yaw0.422853926,pitch0.067315195，眼高1.6，完整精度见JSON。动态草云有时序差异。
- tests/shelter_frame_traversal_review.gd 新增两根柱脚的正面阻挡及内侧绕行，共四次实际角色胶囊移动，均通过；保留中央入口双向通行。九项冻结包回归全部 PASS：四组建筑/道路通行、三枪108样本瞄准、武器遮挡、网络状态规则、前臂968样本、16角色单机冒烟。verified/functional-results.json、各原始日志与 verification-summary.json 可复核。45项构建文件哈希无变化，三帧截图退出0且PASS；网络规则不等于真实双客户端，软件Vulkan不代表硬件或Android性能。
- 当前本地预览：`./artifacts/realism270-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，菜单 SOLO；artifacts/realism270-preview/README.md 记录启动方法。同目录 .pck SHA256 afff99cb4e06e7c0ed4d49c4298af11e268c3e7bbfdc1ef473fbe4d691cdb659，验证前后一致。source-change.diff 保存本轮增量；保留所有已有修改，未推送或发布。
- 下一步：优先改善宽幅地面起伏与材质尺度、植被疏密与树种层次、远景轮廓及光照层次，避免继续整轮局限于入口小构件。保留第三人称3m/10m正侧面膝脚审阅（结合蒙皮脚底世界坐标及地面射线，避免整体下移掩盖问题）、第一人称三枪连射/完整换弹/恢复实机与实际变换检查，以及真实双客户端和Android验证。状态 continue。

### Stage271 — 第一人称袖口黑弧隔离与投影修复（2026-09-16）
- 按最新审阅检查点，在 stage270 环境阶段后完成同冻结包、同机位的基线/关闭SSAO/关闭SSIL/关闭第一人称投影四组实机隔离。只有关闭第一人称投影消除袖口外侧点状黑弧；浅色袖边仍在，不能混为同一缺陷。first_person.gd 对手臂和绑定武器递归关闭投影，actor.gd 对枪口网格同样处理，保留场景SSAO/SSIL及远端人物/武器投影。代价是取消第一人称自投影，其他受光角度与动作仍待审阅。本轮未新增环境资产，不宣称环境整体升级。
- 新增 tests/viewmodel_shadow_rules.gd，首次发现隐藏枪口网格仍投影，保留 initial-validation/ 失败日志；修复后重新构建，四次切枪32个第一人称网格检查及远端投影保留验证通过。最终10项冻结包回归全部PASS：投影规则、四组建筑/道路通行碰撞、三枪108样本瞄准、武器阻挡、网络状态规则、前臂968样本、16角色单机冒烟。artifacts/realism271-validation/verified/ 保存原始日志，verification-summary.json 汇总；48项构建文件哈希无差异，测试前后PCK一致。网络规则不等于真实双客户端验证。
- artifacts/realism271-validation/review.html、isolation-crops.png、visual-review.md 保存隔离及三组实际截图审阅。侧面before本轮使用270包重拍，入口/宽幅before复用270证据，baseline-provenance.json记录来源；after均为271冻结包新截图，捕获退出0且PASS。camera-comparison.json确认位置/朝向/眼高/视口相同：入口(15.5,0.05,39),yaw0,pitch0.054113782；侧面(7.5,0.05,37),yaw-0.714090699,pitch0.025184310；宽幅(17,0.05,50),yaw0.422853926,pitch0.067315195，眼高1.6，1280×800，完整精度见JSON。草云动态时间未冻结，60次同步姿态推进不等于60帧真实渲染预热，不据此声称时间稳定性。
- 当前本地预览：`./artifacts/realism271-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，菜单SOLO，启动说明见同阶段README.md。PCK SHA256 `5e19a9ab2a98f2b59f75aa83d219ad02949d330e4fe6b1304e7ed4dd54cae389`。source-change.diff保存本轮已有脚本增量，新测试单独保存；保留所有已有修改，未推送或发布。
- 局限及下一步：袖管仍长直、有浅色边，枪身大平面明暗偏平；泥地模糊、植被局部成带、远山重复仍明显。补三枪其他受光角度的连射/完整换弹/恢复实机与实际变换，并检查第三人称3m/10m正侧面膝脚及蒙皮后脚底世界坐标/地面射线；随后继续宽幅地形、植被和光照层次。真实双客户端和Android验证仍待完成，软件Vulkan不能代表硬件性能。整体目标未完成，状态continue。


### Stage272 — 棚顶构造、草丛疏密与日光/远山层次（2026-09-16）
- 修改 world_visuals.gd、world.gd：维修棚新增七道实体立边接缝；入口外围高草改为高低草团及露土空隙；远山错开距离和高度，日光转向形成入口树影与棚内受光变化。侧面屋顶分区及宽幅路肩变化可辨，左侧山脊起伏增加；右侧山包仍圆、裸地模糊、树线重复、枪身平板感和袖管长直仍明显，不宣称整体画质完成。
- artifacts/realism272-validation/review.html、visual-review.md 保存三组前后实机对照及逐图结论。before/复用stage271证据，来源见baseline-provenance.json；after/为272导出包实拍，捕获退出0且PASS。camera-comparison.json确认前后位置/朝向/眼高/视口完全一致：入口(15.5,0.05,39),yaw0,pitch0.054113782；侧面(7.5,0.05,37),yaw-0.714090699,pitch0.025184310；宽幅(17,0.05,50),yaw0.422853926,pitch0.067315195，眼高1.6，1280×800，完整精度见JSON。草云动态时间未冻结。
- 最终十项冻结包检查全部PASS：第一人称投影、维修棚/维修通道/西厂房/仓库实际角色通行碰撞、三枪108样本瞄准、武器遮挡、网络状态规则、前臂968样本及16角色单机冒烟。入口覆盖双向通行、柱脚阻挡和绕行，棚顶接缝不增加入口碰撞体。verified/保存原始日志；verification-summary.json汇总48项构建文件哈希无差异，测试前后PCK一致。网络规则不能替代真实双客户端；软件Vulkan不能代表硬件或Android性能。
- 本地预览：`./artifacts/realism272-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，菜单SOLO；同阶段README.md记录启动方式。PCK SHA256 `830c5d90ed68cb8cd6838d5850de1185a87be4069282024dd50aa7729012f61a`。source-change.diff保存本轮增量；保留所有既有修改，未推送或发布。
- 下一步：优先改善裸土地表细节、圆顶山体与重复树线，同时结合第三人称3m/10m正侧面膝脚接地、第一人称三枪不同受光下连射/完整换弹/恢复的实机审阅确定人物/手部缺陷。保留真实双客户端、Android、瞄准与碰撞完整验证目标。状态continue。


### Stage273 — 非对称远山轮廓与山脊林线（2026-09-16）
- 修改 world_visuals.gd：远山采用偏置主峰、较低肩峰与不对称坡面，背景树木按邻域山脊暴露程度减密。宽幅正常持枪机位可辨识主峰/肩坡变化，入口近景收益较小；建筑、近景地表及光照沿用272，不重复计为本轮成果。山坡仍光滑，裸地柔糊、树形重复、枪身平板感及袖管长直仍明显，整体写实目标未完成。
- artifacts/realism273-validation/review.html、visual-review.md 保存三组实机前后对照和逐图审阅；before/复用272证据，来源见baseline-provenance.json；after/为273导出包新截图，捕获退出0且PASS。camera-comparison.json确认完整机位字段相同：入口(15.5,0.05,39),yaw0,pitch0.054113782；侧面(7.5,0.05,37),yaw-0.714090699,pitch0.025184310；宽幅(17,0.05,50),yaw0.422853926,pitch0.067315195；眼高1.6，1280×800，完整精度见JSON。草云动态时间未冻结。
- 十项最终包检查全部PASS：第一人称投影，维修棚/维修通道/西厂房/仓库通行碰撞，三枪108样本瞄准，武器遮挡，网络状态规则，前臂968样本和16角色单机冒烟。入口双向穿行、柱脚阻挡及绕行通过；原始日志见verified/，verification-summary.json记录48项构建文件哈希无差异且测试前后PCK一致。网络规则不能替代真实双客户端，软件Vulkan不能证明硬件或Android性能。
- 本地预览：`./artifacts/realism273-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，菜单SOLO，启动说明见同阶段README.md。PCK SHA256 `0bd503763d7bc462884bfd4b2437f3ba7a2a325e5b0f8942080e4a4951e13126`。source-change.diff保存本轮增量；保留所有既有修改，未推送或发布。
- 下一完整阶段按最新VISUAL_REVIEW_ENVIRONMENT_PRIORITY.md转向人物与武器动作：第三人称约3米/10米正侧面，以及三枪正常持枪、瞄准过渡、连射、完整换弹和恢复的实机序列，记录机位和动作时刻；从证据选择最明显的比例/轮廓/动作缺陷实质修正并对照验证。真实双客户端、Android和环境剩余缺陷继续保留。状态continue。

### stage274 — 阴影退化回退、人物接地审阅修正与稳定预览验证（2026-09-16）
- 接续未完成试验；相同建筑侧面实机对照发现 bias 0.12 / normal 0.35 增加横梁和窗带密集斑点，恢复 1.0 / 1.5。未产生可接受的新环境画质提升，不能将本轮记作整体目标完成。
- 修正 `tests/operator_distance_capture.gd` 默认通过正常物理移动落地，并按全身网格测量左右靴底；3m/10m 正侧面捕获退出 0。旧摆位约 6.2cm 离地包含 5cm 夹具误差，落地后仍约 1.21cm，实际近景仍有悬浮感、假人头部和僵直膝腿，不算人物缺陷修复。
- 推荐预览 `artifacts/realism274-preview/Stable/Linux/IronMeridian`（同目录 PCK，运行加 `--path /tmp --rendering-method forward_plus`）。PCK 与 stage273 相同；试验 Linux/ 包仅保留为负面证据。48 项构建哈希一致。
- 稳定包入口、侧面、宽幅实机截图完成并逐张审阅，相机字段与 stage273 全部一致；入口可辨识，但裸地模糊、山坡平滑、构件整齐和重复树形仍突出。证据：`artifacts/realism274-validation/review.html`、`stable-environment/`、`camera-comparison.json`、`stable-operator/`、`visual-review.md`。
- 稳定包棚屋通行/碰撞、三枪瞄准108样本、武器遮挡和单机流程四项 PASS，日志在 `stable-verified/`。试验包只完成前五项，runner 返回143，原因未确认；旧基线人物捕获 PASS 后退出阶段被终止，部分动作捕获未完成，均单独记录，不冒充完整通过。
- 下一步：按最新环境审阅检查点，实质修正第三人称膝腿/靴底接触或第一人称袖管轮廓，并完成三枪举枪、连射、完整换弹和恢复实机序列；继续处理裸地/山坡/植被重复。真实双客户端联网仍须验证；保留人物、武器、环境与功能完整目标，勿再以小幅阴影参数试验充当整轮画质成果。未推送或发布。


### stage275 — 人物膝腿轮廓、靴底接触与稳定包验证（2026-09-16）
- 按最新274检查点修改 `tools/build_operator.py`：共享绑定/动作膝部IK长度0.415→0.430，小腿向踝部收束，靴底承重区降低并保留足弓/鞋尖抬起；重建 `art/operator.blend`、`client/assets/operator.glb`（17骨骼15动作）。保留全部既有修改，未提交、推送或发布。
- 四组3m/10m正侧面实机前后对照捕获退出0，完整相机字段一致，见 `artifacts/realism275-validation/review.html`、`camera-comparison.json`、`before-operator/`、`after-operator/`。3m侧面膝腿变化可辨，10m收益有限；双靴底几何间隙约12.10→1.10mm，但阴影仍分离，不能宣称悬浮感解决。头面部假人感、僵直手臂和硬裤袋仍明显。本轮没有环境改动，建筑/地表/光照沿用272/273成果。
- 冻结预览包四项功能检查均退出0且PASS：棚屋24项入口/柱脚/墙窗碰撞通行，三枪108样本瞄准，武器遮挡和16角色单机流程；原始日志在 `stable-verified/`。最终48项构建哈希无差异，汇总 `verification-summary.json`、`final-source-audit.json`。
- 动画规则虽输出PASS但约338秒仍未正常退出，手动终止返回143；兼容渲染复测240秒超时124无PASS，均不计通过，根因未确认。动作采集仅持枪和ADS过渡起点两图，约5分半后手动停止runner143；`actions/action-timeline.partial.json`、`actions/process-audit.json` 保存机位/时刻和未完成状态。已审阅两图，袖管长直、枪身平板及光滑山坡仍明显；完整ADS、连射、换弹、恢复、第三人称动作未验证。真实双客户端未运行，现有脚本依赖账号/服务密钥，按约束未读取；Android未验证。
- 当前本地预览：`./artifacts/realism275-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，菜单SOLO，启动说明见同阶段README.md。PCK SHA256 `b7586f874a866214583b88343f65a983eb644c919fa3c2f7dbfd7d10aa997d4a`。实机证据来自软件Vulkan，不能证明硬件性能。
- 下一阶段先定位动画退出/动作采集停滞并分段完成三枪与第三人称动作审阅，修正最明显手臂/人物轮廓缺陷；继续推进裸地、山坡、植被重复与建筑真实感，补齐允许的真实联网验证。整体目标未完成，状态continue。


### stage276 — 地表细节试验、动作采集诊断与稳定包验证（2026-09-16）
- 两种地表shader加入世界空间土壳颜色颗粒及远景导数衰减；真实入口、侧面、宽幅前后图已逐张审阅，变化很小，宽幅尤其有限。没有新增建筑、植被布局或光照改进，不把此轮视为显著环境组合提升。平滑山体、重复树形、规整建筑和直袖管仍明显。
- 相机位置/朝向/目标/眼高/分辨率三组完全一致；捕获退出0，无Godot错误。证据 `artifacts/realism276-validation/review.html`、`visual-review.md`、`camera-comparison.json`、`stable-environment/`。基线为274稳定包（273 PCK）；云风未冻结且包含275人物变化，不视为全图单变量实验。
- 动作捕获脚本加入阶段计时、单枪选项、关键帧筛选。两次诊断主动终止，保留 `diagnostic/process-audit.json` 与 `carbine/process-audit.json`；单枪仅得到持枪图，不能证明停滞修复，最新关键帧修改尚未完整运行。ADS/连射/换弹/恢复与第三人称动作仍未验证。
- 当前冻结包棚屋24项通行碰撞、三枪108样本瞄准、武器遮挡、16角色单机流程全部退出0且PASS，无Godot错误；日志 `stable-verified/`。三张截图采集正常退出0，48项源码构建哈希一致，测试前后PCK一致；见 `verification-summary.json`、`test-script-hashes.json`、`final-source-audit.json`。
- 本地预览：`./artifacts/realism276-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，菜单SOLO；说明同阶段README.md。PCK SHA256 `75640c225e3bcfb1498f62f732d17fb335f27cffde2936d2d6e9ba9ebcef4e85`。软件Vulkan截图不代表硬件性能；真实联网和Android未验证。未提交、推送、发布，保留既有修改。
- 下一步制作宽幅正常机位可辨的山坡表面/非均匀植被群落与建筑使用痕迹，避免继续仅加微弱颜色噪声；保留入口通行及同机位比较。按单枪单动作排查采集耗时，继续人物、第一人称手部和允许的真实联网验证。整体目标未完成，continue。

### stage277 — 门廊围护、路边植被与灯具组合改进（2026-09-16）
- 新增门廊两侧砖砌矮墙与压顶，灯具移至前梁并补壳体端盖、调整暖光；入口和侧面正常游戏机位可辨。路边草丛增加高度变化及阔叶频率，坡面加入侵蚀色块。逐图审阅确认宽幅远山变化不足，平滑山体、重复树形、规整建筑和空地仍明显；白昼暖光弱，不宣称环境或整体目标完成。
- before复用276实机图（非本轮重渲染），after由277导出包实际运行采集。入口、侧面、宽幅三组位置/目标/朝向/眼高/视口一致；见 `artifacts/realism277-validation/review.html`、`visual-review.md`、`camera-comparison.json`、`baseline-provenance.json`、`stable-environment/`。
- 五组功能测试全部退出0且PASS：道路42组站立/蹲姿/bot通行、棚屋24项通行碰撞、三枪108样本瞄准、武器遮挡、16角色单机流程。另以实际角色胶囊验证两侧新增矮墙阻挡，均通过；截图采集退出0，无扫描到的Godot错误。原始日志 `stable-verified/`，汇总 `verification-summary.json`；48项构建哈希一致、测试前后PCK一致，测试脚本哈希已保存。
- 本地预览：`./artifacts/realism277-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，菜单SOLO；运行说明同阶段README.md。PCK SHA256 `e20fb9390e9977417d70e3a433eed32f262d396d83cb5db5a83aca16bb29c91f`。软件Vulkan截图不代表硬件性能；真实联网、Android及人物/手部动作本轮未验证。保留未提交修改，未推送或发布。
- 下一步优先解决宽幅机位中平滑山形和重复树群，采用可见的形体/群落分布变化，避免仅加微弱shader噪声；增加建筑使用痕迹并保持入口通行。随后恢复第三人称人物及第一人称手部动作实机审阅，排查既有动作捕获停滞并补齐真实联网主要功能。整体未完成，continue。

### stage278 — 远山沟谷与林带群落调整、稳定包验证（2026-09-16）
- 将山体沟谷切削与主体起伏分离，补充岩面起伏；林带按遮蔽、暴露与海拔调整疏密和树木尺度。正常宽幅机位树群轮廓有所变化，但山坡依旧平滑，整体改善有限；建筑使用痕迹、近地表噪声和袖管僵硬仍需处理，不宣称环境或整体目标完成。独立改动见 `artifacts/realism278-validation/stage278.patch`。
- before复用277实机图（非本轮重渲染），after由278导出包运行单机采集入口、侧面及宽幅截图；三组位置/目标/yaw/pitch/眼高/视口完全一致，云风时间未锁定。证据 `artifacts/realism278-validation/review.html`、`visual-review.md`、`camera-comparison.json`、`baseline-provenance.json`、`stable-environment/`。
- 道路42组通行、棚屋24项入口/围护/窗面碰撞、三枪108样本瞄准、武器遮挡、16角色单机流程五组测试均退出0且PASS；原始日志 `stable-verified/`。远景18座山体、15,051个树实例贴地检查PASS，最大误差0.000200米，见 `background-scenery.log`。截图退出0，未扫描到Godot错误；48项构建哈希及测试前后PCK一致，汇总 `verification-summary.json`。
- 本地预览：`./artifacts/realism278-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，菜单SOLO；说明 `artifacts/realism278-validation/README.md`。PCK SHA256 `5ffc15d3cc90e810436b087c8871fad9006db60de13b60aa158516bc0086754c`。软件Vulkan截图不代表硬件性能；真实联网、Android与完整人物/手部动作本轮未验证。保留未提交修改，未推送或发布。
- 下一步制作正常机位可辨的山体岩层/破面与建筑使用痕迹，避免继续仅调微弱噪声；维持入口通行和相同机位对照。继续第三人称人物、第一人称手部动作实机审阅及既有动作采集停滞排查，补齐真实联网主要功能。整体目标未完成，continue。

### stage279 — 山坡岩层与棚屋风化、稳定预览及回归（2026-09-16）
- 增加倾斜岩层台阶及裸岩层状明暗，加强维修棚褪色、雨痕和下缘锈蚀。实机入口、侧面和宽幅对照显示收益有限：远山仍偏平滑圆锥，建筑框架规整，地表大片模糊铺色与植被重复尚未消除。本轮未新增植被模型或直接调整灯光，不宣称环境或整体目标完成。独立补丁 `artifacts/realism279-validation/stage279.patch`。
- before复用278真实截图，after来自279导出包；三组相机位置、目标、yaw/pitch、眼高及视口完全一致，云风时刻未锁定。证据 `artifacts/realism279-validation/review.html`、`visual-review.md`、`camera-comparison.json`、`baseline-provenance.json`、`stable-environment/`。截图进程退出0且PASS，无扫描到的Godot错误。
- 道路通行、棚屋24项入口/围护/窗面碰撞、三枪108样本瞄准、武器遮挡及16角色单机流程五组测试均退出0且PASS；原始日志 `stable-verified/`，汇总 `verification-summary.json`。18座山体、14961棵树及5975株幼苗贴地检查PASS，最大误差0.000239米。48项构建哈希一致，测试前后PCK一致。首次导入类型推断失败已修复为floorf并重新构建，失败证据保留在 `failed-initial/`。
- 当前本地预览：`./artifacts/realism279-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，菜单SOLO；说明 `artifacts/realism279-validation/README.md`。PCK SHA256 `4eb4aa386b0d0e83af63f153c1a7a613cd9fd277c140f57c0969657b64804f39`。软件Vulkan截图不代表硬件性能；本轮未验证真实联网、Android及完整第三人称/手部动作。保留所有未提交修改，未推送或发布。
- 下一步优先以真实几何打破可见山脊圆锥轮廓，在棚侧土路补充有分布逻辑的石块、枯草与裸土过渡，改善入口框架/板材厚度及局部遮蔽；必须在正常同机位确认明显收益，避免继续只调微弱风化权重。随后结合第三人称人物、第一人称手部动作实机审阅与真实联网回归处理剩余缺陷。整体未完成，continue。

### stage280 — 棚屋排水构件、墙脚植被与山脊轮廓（2026-09-16）
- 维修棚增加檐沟、落水管及管箍，墙脚改为碎石与不规则草丛，替换等距灌木；远山增加宽山脊、鞍部和非对称峰顶，棚内补光0.42降至0.34。侧面实机可辨排水构件及墙脚接地变化，宽幅可辨山脊变化；入口光照收益很小，碎石偏白、土路模糊、山体圆滑和草叶重复仍明显，不宣称整体目标完成。独立补丁 `artifacts/realism280-validation/stage280.patch`。
- before复用279原始实机截图，after由280冻结预览包采集；入口、侧面及宽幅三组相机位置/目标/yaw/pitch/眼高/视口完全一致，云风时刻未锁定。对照与逐图结论 `artifacts/realism280-validation/review.html`、`visual-review.md`；相机 `stable-environment/environment-camera-poses.json`、`camera-comparison.json`，来源 `baseline-provenance.json`。截图退出0且PASS，无扫描到的Godot错误。
- 道路42组通行、棚屋24项入口/围护/窗面碰撞、三枪108样本瞄准、武器遮挡和16角色单机流程五组测试均退出0且PASS。18座山体、14706棵树及5852株幼苗贴地检查PASS，最大误差0.000146米。48项构建哈希及测试前后预览包一致；汇总 `artifacts/realism280-validation/verification-summary.json`，原始日志 `stable-verified/`、`background-scenery.log`。
- 本地预览：`./artifacts/realism280-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，菜单SOLO；说明 `artifacts/realism280-validation/README.md`。软件Vulkan截图不代表真实显卡性能；本轮未验证联网、Android及完整第三人称/手部动作。保留未提交修改，未推送或发布。
- 下一步处理地表模糊、碎石亮度与过于规整的分布、山体岩面，同时安排第三人称人物与第一人称手部动作实机审阅，排查既有动作采集停滞并补齐双端联网主要功能验证，避免持续只积累环境截图。整体目标未完成，continue。

### stage281 — 维修棚侧檐、暗色散石与低草过渡（2026-09-16）
- 加宽抬高侧檐并增加外沿；墙脚碎石改为更小、暗色、半埋且不规则的散石，补204株低草；入口暖光收窄增强。侧面正常机位可辨构件厚度和建筑接地改善，入口补光差异很小，宽幅空间层次基本未变。近地材质模糊、山体圆滑及植被重复仍未解决，不宣称整体画质完成。独立补丁 `artifacts/realism281-validation/stage281.patch`。
- before复用280真实截图，after使用281冻结预览；入口、侧面及宽幅三组截图已实际打开对照，相机位置/目标/yaw/pitch/眼高/视口完全一致，云风时间未锁。证据 `artifacts/realism281-validation/review.html`、`visual-review.md`、`stable-environment/environment-camera-poses.json`、`camera-comparison.json`。首次采集及测试进程返回143原因不明，保留中断记录；完整重跑成功，详见 `interruption-note.md`。
- 42组道路通行、24项棚屋入口/围护碰撞、三枪108样本瞄准、武器遮挡及16角色单机流程全部退出0且PASS；18座山体、14706棵树、5852株幼苗贴地PASS（最大误差0.000146米）。截图完整退出0且PASS，48项源码/构建哈希及测试前后预览包一致。汇总 `artifacts/realism281-validation/verification-summary.json`，原始日志 `stable-verified/`、`background-scenery.log`。
- 本地预览：`./artifacts/realism281-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，菜单SOLO；说明 `artifacts/realism281-validation/README.md`。软件Vulkan非硬件性能验证；本轮未完成真实双端联网、Android及完整人物/手部动作验证。保留全部未提交修改，未推送、发布或修改服务。
- 下一阶段先给动作采集补可定位进度并限制为必要关键帧，实际审阅转身、蹲伏、换弹、倒地与第一人称手部穿插，补齐双端联网主要功能；随后处理近地纹理尺度及远山岩面轮廓。避免持续以环境截图数量代替整体进展。整体目标未完成，continue。

### stage282 — 人物动作采集恢复与换弹弹匣运动（2026-09-16）
- 按281最新检查点恢复动作采集，保留438模拟tick并仅保存必要关键帧。修复第三人称换弹左手移向腰侧而弹匣留在枪内的问题，弹匣现在随抽出阶段移动并复位；三枪、站/蹲、四进度24样本及取消复位回归PASS，日志 `artifacts/realism282-validation/reload-final.log`。精确手指抓握尚未证明。独立补丁 `stage282.patch`。
- 使用281/282冻结包分别完成实机采集，前后各23帧且退出0/PASS，所有对应帧相机位置与朝向完全一致。实际审阅行走、跑步、蹲行及换弹关键帧；可辨弹匣离枪与归位，但鞋底悬空、圆柱状肢体、粗糙迷彩与过暗面部仍明显。证据 `artifacts/realism282-validation/review.html`、`visual-review.md`、`camera-comparison.json`、`actions-before/`、`actions-after/`。未完成转身、倒地、第一人称手部及3米/10米正侧面审阅；本轮无新增环境改动或环境截图。
- 冻结282包道路42组通行、棚屋24项入口/围护碰撞、三枪108样本瞄准、武器遮挡恢复及16角色单机冒烟均退出0且PASS，原始日志 `stable-verified/`、汇总 `verification-summary.json`。测试前后PCK SHA256均为 `449e5eba951c5bbf56c4d4217ff11882e24c378f411f1c60667272dbd0ccfa0a`；仅外部换弹回归脚本在导出后细化，客户端源文件未变，详见 `source-package-audit.json`。
- 联网四客户端测试失败（入场/队伍快照超时）；单客户端明确诊断为登录前内容版本拒绝：客户端ash-valley-19、服务ash-valley-18，协议同为17。证据 `network-diagnosis.json`、`network-diagnostic.log`；联网战斗/倒地复活/同步未通过验证。未改后台服务、认证或绕过版本检查，保留失败日志及所有未提交修改，未推送或发布。
- 当前本地预览：`./artifacts/realism282-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，菜单SOLO；说明 `artifacts/realism282-validation/README.md`。软件Vulkan不代表硬件性能。下一步先测量动画姿态鞋底顶点与地面射线的间隙，修复可见脚底悬空（不可仅凭grounded下沉根节点），补转身/倒地及第一人称手部实机审阅，再处理近地纹理尺度与远山岩面；联网待获准处理本地服务内容版本后补验。整体目标未完成，continue。

### stage283 — 人物鞋底动画采样与接地审阅（2026-09-16）
- 承接282鞋底缺陷，Blender导出改为每个整数帧并保留四分之一/四分之三周期关键时刻，重新生成15个动作；没有下沉根节点或改胶囊。7种动作各121时刻（847样本）的蒙皮鞋底/地面射线回归PASS：最大支撑间隙24.24→7.32毫米，最低顶点穿地5.28→1.26毫米。证据 `artifacts/realism283-validation/sole-before/sole-cycle.json`、`sole-after/sole-cycle.json`、`animation-key-change.patch`。
- 冻结282/283包完成静止、跑步固定姿态的3米/10米正侧面八组实机对照，采集均正常退出；camera.json记录位置、朝向及65度FOV，全部对应机位一致。实际审阅 `comparison-sheet.jpg` 及近景原图：静止几何间隙约1.1毫米仍有投影分离，10米处本次改善几乎不可辨；面部过暗、袖管圆柱及迷彩粗糙仍明显。不以数值或截图数量宣称画质完成。详细结论 `artifacts/realism283-validation/visual-review.md`。
- 本轮无新增环境改动，入口/宽幅环境证据沿用281；已重验道路42组通行、棚屋24项入口/围护碰撞、三枪108样本瞄准及武器遮挡，均正常退出0/PASS。其他回归最终状态见本节后续验证收尾记录。原始中断/超时日志保留，打印PASS但无正常退出的执行不计为通过。
- 本地预览 `./artifacts/realism283-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，菜单SOLO；说明 `artifacts/realism283-validation/README.md`。软件Vulkan不代表硬件性能。联网本轮未重验，282的ash-valley-19/18内容版本不匹配仍未解决；未改服务、认证，未推送或发布，保留所有未提交修改。
- 下一步对太阳阴影偏移做受控人物接地前后对照，同时检查建筑入口自阴影伪影，再补转身/倒地和第一人称手部实机审阅，继续近地材质及远山轮廓；联网待允许处理服务内容版本后补验。整体目标未完成，continue。
- 验证收尾：六项回归正常退出0/PASS（含16角色单机及第三人称换弹）；完整动画最终Vulkan重试打印PASS后360秒未退出，exit_code=124，明确未计通过，已清理本次测试残留进程。下一阶段补查退出延迟。50项来源/构建哈希匹配、测试前后PCK一致；汇总 `artifacts/realism283-validation/verification-summary.json`，八组实机对照 `review.html`，异常日志 `animation_rules-final.log`。

### stage284 — 接地阴影与建筑入口自阴影对照（2026-09-16）
- 承接283检查点，太阳shadow_bias/normal_bias由1.0/1.5调整为0.5/0.3，改善静止人物脚边阴影接合；否决0.1/0.3候选，因道路标线出现黑色条纹伪影，保留候选截图。未修改人物根节点或环境几何，不将本次参数修正视为整体画质完成。
- 冻结284包完成建筑入口、侧面及宽幅地形三组实机前后对照，另补静止/跑步3米正侧面四组人物对照；对应相机位置、朝向一致，元数据与50项来源哈希匹配见 `artifacts/realism284-validation/source-camera-audit.json`。入口/侧面未见明显新增棚架自阴影条纹，跑步仍显悬浮、近地纹理模糊、植物叶片平面化及远山轮廓重复；完整审阅 `review.html`、`visual-review.md`，不以截图数量判定画质。
- 六项冻结包回归均退出0/PASS且无记录错误：道路42组、棚屋24项入口/围护碰撞、三枪108样本瞄准、武器遮挡恢复、三枪站立/蹲姿第三人称换弹及16角色单机冒烟。证据 `artifacts/realism284-validation/verification-summary.json` 与 `stable-verified/`；测试前后PCK哈希一致。软件Vulkan截图不代表硬件性能。
- 当前本地预览 `./artifacts/realism284-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，菜单SOLO，说明 `artifacts/realism284-validation/README.md`。联网本轮未重验，282记录的ash-valley-19/18内容版本不一致仍未解决，不能称联网可用。未修改后台服务、认证，未推送或发布，保留所有未提交修改。
- 下一步优先改善正常游戏机位的近地材质清晰度、植被形态和远山轮廓，继续保存同机位入口及宽幅地形对照并验证碰撞通行；再补人物转身/倒地及第一人称手臂审阅，保留联网验证和283动画测试退出延迟问题。整体目标未完成，continue。

### stage285 — 远山轮廓与近地土壤结皮（2026-09-16）
- 远山高度函数改为不等高交错峰，收窄沟槽，替换明显圆润双峰；地表增加带距离过滤的细小结皮裂隙、颜色和法线变化。本轮未改建筑、植被或光照，保留284结果。独立源代码差异 `artifacts/realism285-validation/stage285-source.patch`，保留所有既有未提交修改。
- 已实际审阅入口、棚屋侧面与宽幅地形三组前后原图：山峰变化在正常机位明显，土面细节仅近处改善；中距离仍模糊、草丛平面化且孤立、山面缺岩层，建筑钢架偏粗，第一人称枪械灰平。对照 `artifacts/realism285-validation/review.html`、结论 `visual-review.md`；before沿用284原图，after来自285冻结包。机位位置/朝向完全一致，50项来源/构建哈希匹配，见 `source-camera-audit.json` 与 `stable-environment/environment-camera-poses.json`。三帧实机采集退出0、无记录错误。
- 六项冻结包检查均退出0/PASS、无记录错误：道路42组、棚屋24项碰撞通行、三枪108样本瞄准、武器遮挡与恢复、三枪站立/蹲姿换弹、16角色单机冒烟（换弹/治疗/伤害/胜利/射线/掩体等）。汇总 `artifacts/realism285-validation/verification-summary.json`，原始日志 `stable-verified/`；测试前后PCK哈希一致。软件Vulkan不能证明硬件性能，新增土面采样的硬件成本未测。
- 本地预览 `./artifacts/realism285-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，菜单SOLO，说明 `artifacts/realism285-validation/README.md`。联网未重测，282记录的客户端ash-valley-19/服务ash-valley-18不一致仍阻塞；283完整动画检查PASS后退出超时仍未解决。未改后台服务或认证，未推送、发布或部署。
- 下一阶段继续中距离土壤与草地过渡、植物立体形态、建筑材料尺度和远山岩面，同机位实机复查并验证入口通行；随后补人物转身/倒地接地与第一人称手部审阅，保留联网主要功能验证及动画退出延迟排查。不能将局部改进视为整体完成，状态continue。

### stage286 — 维修棚草灌层次与钢构漆面光照响应（2026-09-16）
- 维修棚两侧新增576簇混合高度草与9株小灌木，保留中央入口及混凝土通道；钢构减少大尺度明暗斑块，增加距离过滤的细漆面颗粒并调整粗糙度、高光。本轮未改全局光照或建筑几何。两份源文件差异见 `artifacts/realism286-validation/stage286.patch`，保留所有既有未提交修改。
- 已实际审阅入口近景、棚屋侧面及宽幅地形三组前后原图：沿路肩的草灌层在正常机位明显更连续，入口通路清晰；钢构变化较细微，植物平面化、土面模糊、粗重框架与远山缺少岩层仍明显。对照 `artifacts/realism286-validation/review.html`、结论 `visual-review.md`；before复用285原图，after来自286冻结包。机位元数据完全一致、50项来源/构建哈希匹配，见 `source-camera-audit.json`；相机位置与朝向见 `stable-environment/environment-camera-poses.json`。三帧采集均退出0、无记录错误。
- 六项冻结包回归均退出0/PASS且无记录错误：道路42组、棚屋24项入口/围护碰撞通行、三枪108样本瞄准、武器遮挡恢复、三枪站立/蹲姿第三人称换弹、16角色单机冒烟。汇总 `artifacts/realism286-validation/verification-summary.json`、原始日志 `stable-verified/`；测试前后PCK哈希一致。新增585个装饰实例的硬件成本未测，软件Vulkan不能证明硬件性能。
- 本地预览 `./artifacts/realism286-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，菜单SOLO；说明 `artifacts/realism286-validation/README.md`。联网未重验，282的ash-valley-19/18内容版本不一致及283完整动画测试退出超时仍未解决。未改后台服务或认证，未推送、发布或部署。
- 下一阶段继续改善中距离土面与草地过渡、植物立体形态、建筑材料尺度及远山岩层，保存同机位对照并复验入口通行；随后补人物转身/倒地及第一人称手部实机审阅，保留联网主要功能和完整动画退出问题。整体目标未完成，continue。

### stage287 — 维修棚真实波纹屋顶与冻结包验证（2026-09-16）
- 将平滑拱顶改为200mm波距、36mm峰谷差的真实波纹几何，积尘与高光对应起伏；保留独立碰撞。侧面正常游戏机位改善可见，入口改善有限，宽幅地形基本未变；本阶段未修改地形、植被或全局光源，不能视为整体环境目标完成。
- 对照：`artifacts/realism287-validation/review.html`，`before/`使用stage286既有冻结截图（非本轮重跑旧包），`stable-environment/`为本轮入口、侧面、宽幅实机截图。各目录`environment-camera-poses.json`记录完整相机位置与朝向，`source-camera-audit.json`确认相同机位及50个构建源文件；详见`visual-review.md`。
- 冻结包六项回归全部退出0且无错误：42组道路通行、24项维修棚入口/立柱/侧墙/屋顶碰撞、108项瞄准采样、武器遮挡、第三人称换弹、16角色单机冒烟（换弹/治疗/伤害/胜利等）。证据：`artifacts/realism287-validation/verification-summary.json`及`stable-verified/`日志；包哈希测试前后相同，截图进程正常退出。
- 当前本地预览：`./artifacts/realism287-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，桌面环境打开菜单选择SOLO。屋顶35,840三角形，软件Vulkan截图不能证明真实显卡性能，运动闪烁未验证。保留全部既有修改，未推送或发布。
- 下一步：优先中景土壤清晰度、灌木体积、远山岩层的环境组合改进，避免继续仅打磨屋顶部件；随后审阅第三人称转身/倒地/跑动接地与第一人称手部。stage282联网地图版本不匹配、本轮未重测联网；stage283完整动画测试超时退出仍未闭环。整体状态continue。

### stage288 — 地表尺度与远山表面调整、冻结包回归（2026-09-16）
- 调整维修棚周边泥土/碎石采样尺度，减弱大块暗斑；细化远山分层高度与法线采样，调整岩面坡度覆盖和裂隙色差。本轮三份源文件差异见 `artifacts/realism288-validation/stage288.patch`，保留既有未提交修改。未改变建筑几何、植被实例或全局光照。
- 已实际审阅入口、侧面和宽幅地形三组相同机位对照：侧面土壤颗粒尺度有所改善，入口变化较小；远山仍呈圆锥山包，草片平面化与建筑粗重重复仍明显，不能视为环境目标完成。`artifacts/realism288-validation/review.html`、`visual-review.md`记录对照和局限；before复用287冻结原图，after来自288实际运行。`stable-environment/environment-camera-poses.json`记录位置与朝向，`source-camera-audit.json`确认机位一致及50项构建来源匹配；截图进程退出0、无记录错误。
- 冻结包六项回归全部退出0、无记录错误：道路通行、24项棚屋入口/围护碰撞与通行、三枪108样本瞄准、武器遮挡恢复、三枪两姿态第三人称换弹、16角色单机冒烟（换弹/治疗/伤害/胜利等）。见 `artifacts/realism288-validation/verification-summary.json` 与 `stable-verified/` 原始日志；测试前后包哈希一致。
- 当前本地预览：`./artifacts/realism288-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，桌面菜单选择SOLO；说明 `artifacts/realism288-validation/README.md`。软件Vulkan截图不能证明硬件性能。联网本轮未重测，282的地图版本不匹配、283完整动画测试退出超时均未闭环；未改后台服务或认证，未推送、发布或部署。
- 下一步优先实施正常宽幅机位可辨识的远山轮廓与灌木体积变化，并结合建筑周边地表过渡复查，避免继续仅调岩层着色参数；随后补第三人称转身/倒地/跑动接地与第一人称手部实机审阅，继续完成联网验证。整体目标未完成，continue。

### stage289 — 远山轮廓与细叶灌木体积（2026-09-16）
- 将远山线性尖锥轮廓改为宽肩、非对称山顶与鞍部缺口；重建细叶灌木 Blender/GLB，弯折枝条并加宽叶片、拉开空间分布。实现差异见 `artifacts/realism289-validation/stage289.patch`。保留既有未提交修改，未推送、发布或部署。
- 已审阅入口、侧面、宽幅地形相同机位对照：宽幅山脊轮廓明显变化，灌木更饱满；入口变化有限，建筑框架粗重重复、大叶纸片感、光滑岩面和草土过渡仍需改进。本轮未修改建筑几何或全局照明，整体环境目标未完成。对照与审阅见 `artifacts/realism289-validation/review.html`、`visual-review.md`；before复用288冻结原图，after为289冻结包实机截图，相机位置与朝向记录于 `stable-environment/environment-camera-poses.json`。
- 冻结包七项检查全部退出0且无记录错误：道路通行、24项建筑入口/围护碰撞、108样本瞄准、武器遮挡、第三人称换弹、16角色单机冒烟，以及18处远山/13,755棵背景树接地检查（最大误差约0.000006米）。`verification-summary.json`汇总原始日志、包哈希与来源审计；50项构建来源和前后相机一致，三处截图进程正常退出。接地检查前两次失败日志已保留，最终检查修正测试网格尺寸并使用实际渲染器；详见README。
- 当前本地预览：`./artifacts/realism289-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，桌面菜单选择SOLO。构建、截图及测试证据位于 `artifacts/realism289-validation/`；软件渲染截图不能证明硬件帧率。
- 下一步优先结合建筑入口与周边地表过渡调整光照和材质，改善正常机位的重复结构与空间层次；随后审阅第三人称转身/倒地/跑动接地和第一人称手部。联网本轮未重测，stage282地图版本不匹配与stage283完整动画测试退出超时仍未闭环。整体状态continue。

### stage290 — 维修棚入口识别、地坪与肩部植被（2026-09-16）
- 放大浅色搪瓷入口标识，调整灯具发光与门廊下照灯；缩细地坪接缝，增加落水口湿痕与干湿色差，将排水肩部高草替换为160簇短草。两个源文件差异见 `artifacts/realism290-validation/stage290.patch`，保留全部既有未提交修改。
- 已审阅入口近景、侧面和宽幅地形同机位实机对照：主要可见改善是标识可读性和接缝尺度；植被与光照差异有限，标识偏新且遮挡更多拱口，粗重重复钢架、片状大叶与光滑远山仍需改进。`review.html`、`visual-review.md`记录证据与局限；before复用289冻结原图，after来自290冻结包。`stable-environment/environment-camera-poses.json`记录位置与朝向，`source-camera-audit.json`确认前后机位一致和50项构建来源匹配，三帧截图进程正常退出。
- 冻结包六项回归全部退出0、无记录错误：道路通行、24项棚屋入口/围护碰撞与通行、三枪108样本瞄准、武器遮挡恢复、三枪两姿态第三人称换弹、16角色单机冒烟（换弹/治疗/伤害/胜利等）。汇总 `artifacts/realism290-validation/verification-summary.json`，原始日志 `stable-verified/`；测试前后包哈希一致。
- 当前本地预览：`./artifacts/realism290-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，桌面菜单选择SOLO；说明 `artifacts/realism290-validation/README.md`。软件Vulkan截图不能证明硬件性能。联网本轮未重测，stage282地图版本不匹配及stage283完整动画测试退出超时仍未闭环；未改后台服务或认证，未推送、发布或部署。
- 下一步应实施正常机位可辨识的建筑结构比例/破损污迹和大叶植被体积改进，避免仅继续调整标识或着色参数；补第三人称转身/倒地/跑动接地及第一人称手部实机审阅，并继续解决联网与完整动画退出问题。整体目标未完成，continue。

### stage291 — 维修棚遮阳与钢架比例、细叶灌木（2026-09-16）
- 缩短侧窗遮阳出挑并减薄叶片、边梁和门廊柱翼缘/斜撑；重新生成较小、弯曲的细叶灌木 Blender/GLB。源码差异见 `artifacts/realism291-validation/stage291.patch`，保留全部既有未提交修改。
- 已审阅入口近景、侧面、宽幅地形同机位实机对照：侧窗外伸块体和支撑厚重感有所下降，但宽景整体变化有限；另一类大平叶、重复锈纹与构件、草土过渡仍明显。本轮未调整全局照明，光照目标未完成。`review.html`、`visual-review.md`记录实际局限；before复用290冻结原图，after来自291冻结包。`stable-environment/environment-camera-poses.json`记录位置与朝向，`source-camera-audit.json`确认三处机位一致及50项构建来源匹配。
- 冻结包六项回归全部退出0且无记录错误：道路通行、24项棚屋入口/围护碰撞、三枪108样本瞄准、武器遮挡恢复、三枪两姿态第三人称换弹、16角色单机冒烟（换弹/治疗/伤害/胜利等）。截图进程退出0，测试前后包哈希一致；汇总 `artifacts/realism291-validation/verification-summary.json`，原始日志 `stable-verified/`。
- 当前本地预览：`./artifacts/realism291-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，桌面菜单选择SOLO；说明 `artifacts/realism291-validation/README.md`。软件Vulkan截图不能证明硬件性能。联网本轮未重测，stage282地图版本不匹配、stage283完整动画测试退出超时仍未闭环；未推送、发布、部署或修改后台服务/认证。
- 下一步优先定位正常机位突兀的宽叶资产及分布，结合建筑大尺度材质分区、场地植被过渡与室内外光照实施成组改善，避免继续局限于小型杆件；随后补第三人称全动作与第一人称手部实机审阅，解决联网及动画退出问题。整体目标未完成，continue。

### stage292 — 维修棚钢板分区、草土过渡与局部补光（2026-09-16）
- 屋顶加入灰绿色替换钢板，减弱周期性檐口锈蚀；扩展道路肩部草丛并压低外围高度，减少大叶草比例，加入根部土色过渡；提高入口与棚内局部补光。三个源码文件差异见 `artifacts/realism292-validation/stage292.patch`，保留全部既有未提交修改。
- 已逐张审阅入口、侧面及宽幅地形同机位前后实机截图：侧面钢板分区可辨识，草带边缘略有改善；入口补光与宽景整体差异有限，大片平面叶片、重复建筑及平滑远山仍明显，不能视为整体画质达标。对照 `artifacts/realism292-validation/review.html`，具体局限 `visual-review.md`；before复用源码审计一致的291冻结原图，after来自292冻结包。`stable-environment/environment-camera-poses.json`记录位置与朝向，`source-camera-audit.json`确认机位及构建来源一致。
- 冻结包六项回归全部退出0、无记录错误：42条道路通行路线、24项建筑入口/围护碰撞与通行、三枪108样本瞄准、武器遮挡恢复、三枪两姿态第三人称换弹、16角色单机冒烟（换弹/治疗/伤害/胜利等）。三帧截图进程正常退出，测试前后包哈希一致。汇总 `artifacts/realism292-validation/verification-summary.json`，原始日志 `stable-verified/`。
- 当前本地预览：`./artifacts/realism292-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，桌面菜单选择SOLO；说明 `artifacts/realism292-validation/README.md`。软件Vulkan截图不能证明硬件性能。联网本轮未重测，stage282地图版本不一致及stage283完整动画退出超时仍未闭环；未推送、发布、部署或修改后台服务/认证。
- 下一步准确定位侧面与宽幅前景大片叶子的实例及资产，改善尺寸、轮廓和空间分布，结合建筑重复结构与近地材质实施正常机位可见的改进；随后补第三人称全动作、第一人称手部实机审阅，并解决联网及动画退出问题。整体目标未完成，continue。

### stage293 — 桦树叶形、前景灌木高度与入口局部光照（2026-09-16）
- 重新生成较小且带弯曲轮廓的桦树叶片 Blender/GLB，压低棚边与前景灌木；修正木纹方向，将入口上方百叶改为分片木材并补支撑，提高入口局部补光。差异见 `artifacts/realism293-validation/stage293.patch`；保留全部既有未提交修改。
- 已逐张审阅入口近景、侧面、宽幅地形同机位实机前后对照：前景灌木遮挡下降、桦树冠略细密，但大片平叶仍存在；上方百叶被雨棚遮挡，建筑改善在正常机位不明显，入口光照差异也有限。重复建筑、草土地表与平滑远山未达目标。对照 `artifacts/realism293-validation/review.html`，局限见 `visual-review.md`；before复用292冻结原图，after来自293冻结包。`stable-environment/environment-camera-poses.json`记录相机位置与朝向，`source-camera-audit.json`确认三处机位一致及50项构建来源匹配。
- 冻结包六项回归全部退出0、无记录错误：42条道路通行路线、24项建筑入口/围护碰撞与通行、三枪108样本瞄准、武器遮挡恢复、三枪两姿态第三人称换弹、16角色单机冒烟（换弹/治疗/伤害/胜利等）。截图进程正常退出，测试前后包哈希一致；汇总 `artifacts/realism293-validation/verification-summary.json`，原始日志 `stable-verified/`。规则测试不能替代人物动作与手部的视觉审阅。
- 当前本地预览：`./artifacts/realism293-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，桌面菜单选择SOLO；说明 `artifacts/realism293-validation/README.md`。截图使用软件Vulkan，新增叶片几何的硬件性能尚未验证。联网本轮未重测，stage282地图版本不一致、stage283完整动画退出超时仍未闭环；未推送、发布、部署或修改后台服务/认证。
- 下一步先准确定位仍突兀的大平叶资产，并优先处理正常机位可见的大面积建筑墙面、构件重复和近地草土分布，避免继续修改被遮挡的小构件；补室内外光照、第三人称全动作及第一人称手部实机审阅，解决联网与完整动画退出问题。整体目标未完成，continue。


### stage294 — 维修棚灰泥露砖、阔叶草轮廓与入口光照（2026-09-16）
- 墙基加入不规则残留灰泥与局部露砖，调整材质法线；重新生成更窄、带扭转及卷曲的阔叶草 Blender/GLB，提高入口、门前与棚内局部补光。差异见 `artifacts/realism294-validation/stage294.patch`，保留全部既有未提交修改。
- 已审阅入口近景、侧面正常机位、宽幅地形的实机同机位前后对照：墙基材料分区明显可辨，但灰泥仍偏平；低草略细碎，枪旁灌木大平叶仍突出，宽景布局与远山改善有限，未达整体目标。对照 `artifacts/realism294-validation/review.html`，局限 `visual-review.md`。before复用293冻结原图，after来自294冻结包；`stable-environment/environment-camera-poses.json`记录位置与朝向，`source-camera-audit.json`确认三处机位及构建来源匹配。
- 冻结包六项回归全部退出0、无记录错误：42条道路通行路线、24项建筑入口/围护碰撞与通行、三枪108样本瞄准、武器遮挡恢复、三枪两姿态第三人称换弹、16角色单机冒烟（换弹/治疗/伤害/胜利等）。截图进程正常退出，测试前后包哈希一致。汇总 `artifacts/realism294-validation/verification-summary.json`，原始日志 `stable-verified/`；规则测试不能替代人物与手部视觉验收。
- 当前本地预览：`./artifacts/realism294-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，桌面菜单选择SOLO；说明 `artifacts/realism294-preview/README.md`。软件Vulkan截图不证明硬件性能。联网本轮未重测，stage282内容版本不一致、stage283完整动画退出超时仍未闭环；未推送、发布、部署或修改后台服务/认证。
- 下一步扩大正常游戏机位可见的道路与建筑之间场地层次及远山轮廓改进，准确定位残留大叶灌木实例，保留通行路线；随后补第三人称全动作、第一人称手部与室内外光照实机审阅，并解决联网及完整动画退出问题。整体目标未完成，continue。

### stage295 — 远山尖脊、棚边排水与草簇尺度（2026-09-16）
- 调整远山主峰为不对称尖脊轮廓；维修棚落水管增加斜出口及石衬地面排水槽；缩小棚边群落的阔叶草实例。差异 `artifacts/realism295-validation/stage295.patch`，保留全部既有未提交修改。
- 已逐张审阅入口、侧面及宽幅同机位实机前后对照：山峰轮廓变化最明显，但纵向沟槽仍程序化；侧面排水用途可辨，入口变化很小。低草调整没有解决枪旁大平叶，已定位额外的 `verge_fine_shrub.glb` 灌木实例。建筑重复、宽景空旷、地表过渡仍未解决；全局光照保持原状，不宣称光照提升。对照 `artifacts/realism295-validation/review.html`，详细局限 `visual-review.md`。before复用294冻结原图；after来自295冻结包，`stable-environment/environment-camera-poses.json`记录位置和朝向，`source-camera-audit.json`确认三处机位一致及50项来源匹配。
- 冻结包六项回归全部退出0、无记录错误：42条道路路线、24项建筑入口/围护碰撞与通行、三枪108样本瞄准、武器遮挡恢复、三枪两姿态第三人称换弹、16角色单机冒烟（换弹/治疗/伤害/胜利等）。截图进程正常退出，测试前后包哈希一致；汇总 `artifacts/realism295-validation/verification-summary.json`，原始日志 `stable-verified/`。规则通过不能替代人物及手部视觉审阅。
- 当前本地预览：`./artifacts/realism295-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，菜单选择单机；说明 `artifacts/realism295-preview/README.md`。软件Vulkan截图不证明硬件性能。联网本轮未重测，stage282内容版本不一致和stage283完整动画退出超时仍未闭环；未推送、发布、部署或修改后台服务/认证。
- 下一步直接修改已定位的大平叶灌木，同时扩大道路与建筑之间使用场地、重复立面及近地材质过渡的可见改进，补入口内外光照对照，保留通行路线；随后补第三人称全动作、第一人称手部实机审阅，并解决联网和完整动画退出问题。不继续以被遮挡小构件替代环境提升。整体目标未完成，continue。

### stage296 — 细叶灌木、维修地坪与入口补光（2026-09-16）
- 重建细叶灌木 Blender/GLB：缩小叶片、随机枝梢和叶位、加入叶柄；维修棚地坪增加宽修补带和弧形轮胎擦痕，调整入口反射光与棚内补光。改动见 `artifacts/realism296-validation/stage296-source.patch`，模型生成日志 `shrub-build.log`；保留既有未提交修改。
- 已逐张审阅入口、侧面及宽景实机同机位前后对照：路边灌木规则叶排减弱，入口修补带可辨；光照改善较轻，后墙仍暗。另一类大叶植被、远山棱面、重复厂房与宽景空地仍明显，整体观感提升有限。对照 `artifacts/realism296-validation/review.html`，局限 `visual-review.md`。before来自295冻结图，after来自296冻结包；`stable-environment/environment-camera-poses.json`保存位置与朝向，`source-camera-audit.json`确认机位和来源匹配。
- 冻结包六项回归全部退出0、无记录错误：42条道路路线、24项建筑入口/围护碰撞与通行、三枪108样本瞄准、武器遮挡恢复、三枪两姿态第三人称换弹、16角色单机冒烟。截图进程通过，测试前后包哈希一致；汇总 `artifacts/realism296-validation/verification-summary.json`，原始日志 `stable-verified/`。规则测试不代替人物与手部视觉验收。
- 当前本地预览：`./artifacts/realism296-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，菜单选择单机；说明 `artifacts/realism296-preview/README.md`。软件Vulkan截图不证明硬件性能。联网本轮未重测，stage282地图版本不一致、stage283完整动画退出超时仍未闭环。未推送、发布、部署或修改后台服务/认证。
- 下一步优先扩大宽景可见改进，处理远山棱面、建筑组团重复及地表疏密关系，避免继续堆叠入口小修饰；保留通行路线，再结合第三人称人物及第一人称手部全动作截图处理剩余缺陷，解决联网版本和动画退出问题。整体目标未完成，continue。

### stage297 — 维修棚侧翼、远山轮廓与植被疏密（2026-09-16）
- 增加西侧连续金属雨棚、支架与入口较大上角斜撑；放宽远山峰形并减弱直沟槽；调整路肩草簇分布、阔叶草比例、入口补光与太阳角直径。差异 `artifacts/realism297-validation/stage297-source.patch`，保留全部既有未提交修改。
- 已逐张审阅入口近景、侧面和宽幅地形的同机位实机前后对照：侧翼雨棚及远山轮廓变化明显，植被与全局光照差异较轻。大平叶、圆滑程序化山体、重复厂房和空旷地表仍未解决，入口混凝土偏亮平、后墙偏暗。对照 `artifacts/realism297-validation/review.html`，局限 `visual-review.md`；before为296冻结原图，after为297冻结包。`stable-environment/environment-camera-poses.json`记录相机位置与朝向，`source-camera-audit.json`确认三机位一致及55项来源匹配。
- 冻结包六项回归均退出0、无记录错误：42条道路路线、24项建筑入口/围护碰撞与通行、三枪108样本瞄准、武器遮挡恢复、三枪两姿态换弹规则、16角色单机冒烟（换弹/治疗/伤害/胜利等）；另增雨棚下6条双向实际角色通行路线全部通过。截图进程正常退出，测试前后包哈希一致；汇总 `artifacts/realism297-validation/verification-summary.json`，原始日志 `stable-verified/`、`awning-clearance.log`。规则测试不代替人物与手部视觉验收。
- 当前本地预览：`./artifacts/realism297-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，菜单选择单机；说明 `artifacts/realism297-preview/README.md`。软件Vulkan截图不证明硬件性能。联网本轮未重测，stage282地图版本不一致、stage283完整动画退出超时仍待闭环。未推送、发布、部署或修改后台服务/认证。
- 下一步扩大重复厂房立面、道路旁使用场地及近地材质过渡的可见改进，直接处理残留大叶实例；继续保持机位对照与通行检查，补室内外光照及第三人称人物/第一人称手部全动作实机审阅，解决联网版本和动画退出问题。不以入口小构件或截图数量判定整体画质，整体目标未完成，continue。

### stage298 — 车间立面、贴坡细草与棚内补光（2026-09-16）
- 两处车间增加下部砌体、防溅墙脚、立面分段与高位通风细节；服务区新增四簇不规则贴坡细草，并调整棚内外补光。仅本轮源码差异见 `artifacts/realism298-validation/stage298-source.patch`，保留既有未提交修改。
- 冻结包入口近景、侧面和宽幅地形实机前后对照均已审阅：侧墙下部层次和细草变化可辨识，入口补光改善较温和；重复厂房、圆滑/折面远山、大叶片状感、混凝土偏平亮仍存在。`review.html`、`visual-review.md`、`source-camera-audit.json` 位于上述验证目录；三机位位置/朝向完全一致，55项构建输入/产物审计匹配。
- 七项冻结包回归退出0、无记录错误：西侧车间通行、服务区道路通行、棚架入口围护碰撞、三枪108样本瞄准、武器遮挡恢复、三枪两姿态换弹规则、单机冒烟。截图进程退出0，测试前后包哈希一致。汇总 `verification-summary.json`，原始证据 `stable-verified/`。
- 新增东侧车间六条路线诊断为4通过、2失败：x=36.2双向均被原有随机货箱阻挡，中心x=35与左侧x=33.8双向通过。阻挡体位于(37.06186,0.75,39.27716)，尺寸(2.5,1.5,2)，来自 `world.gd` 随机掩体生成未排除车间通道。证据 `east-depot-diagnosis.json`、`stable-verified/east-depot-clearance.json`，不得宣称全部碰撞通过。
- 可运行本地预览：`./artifacts/realism298-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，菜单选择单机；说明 `artifacts/realism298-preview/README.md`。软件Vulkan不能证明硬件性能；本轮未复测联网，已有地图版本不一致和完整动画退出问题仍待闭环。未推送、发布、部署或修改后台服务/认证。
- 下一步先修随机货箱的车间通道净空排除（包含货箱占地及角色半径），同步视觉/碰撞/地图数据并复测六条路线；继续扩大建筑差异、近地材质与植被改进，补第三人称人物、第一人称手部全动作实机审阅和联网验证。整体目标未完成，continue。

### stage299 — 车间通道净空与地坪、路肩植被（2026-09-16）
- 随机货箱按完整占地并预留角色净空排除建筑通道，生成前同步排除视觉、碰撞与地图数据；修复298东侧仓库x=36.2双向阻塞，六条实际角色路线现全部通过。新增 `tests/east_depot_traversal_review.gd`，本轮差异 `artifacts/realism299-validation/stage299.patch`；保留既有未提交修改。
- 车间40块地坪改用连续混凝土着色，调整棚前地表色与入口补光，路肩增加27株阔叶草。已审阅四组同机位实机前后对照，含入口近景、侧面、车间地坪与宽幅地形：地坪斑驳减弱但偏均匀，植被和光照变化较轻；重复厂房、圆滑/折面远山、片状叶材质仍明显，不能认定整体画质达标。
- 对照 `artifacts/realism299-validation/review.html`、局限 `visual-review.md`，截图 `before/` 与 `stable-environment/`；before来自298冻结包，其中车间机位本轮补拍。相机位置/朝向见 `source-camera-audit.json`，四机位一致，56项来源无差异，截图进程退出0。
- 八项冻结包检查全部退出0、无记录错误：东/西车间通行、服务区道路通行、棚架碰撞、三枪108样本瞄准、武器遮挡恢复、三枪两姿态换弹规则、16角色单机冒烟。测试前后包哈希一致。汇总 `artifacts/realism299-validation/verification-summary.json`，原始日志 `stable-verified/`。规则测试不代替人物及手部动作画质验收。
- 当前本地预览：`./artifacts/realism299-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，菜单选择单机；说明 `artifacts/realism299-preview/README.md`。软件Vulkan不证明硬件性能；联网本轮未复测，stage282地图版本不一致和stage283完整动画退出超时仍待闭环。未推送、发布、部署或修改后台服务/认证。
- 下一步扩大正常机位可见的厂房建筑差异和地形轮廓改进，补地坪磨损/排水与地表过渡，避免只堆入口小构件；维持通道净空复测，随后结合第三人称人物、第一人称手部全动作截图安排剩余缺陷，完成联网与动画退出验证。整体目标未完成，continue。

### stage300 — 维修工位结构、地表衔接与作业照明（2026-09-16）
- 西侧工位柱梁细化为带碰撞的工字截面，实心工作台改为薄台面、桌腿和下层架，新增工具板挂件、暖色作业照明；地坪加入轮迹、油污及磨损黄线，门外铺齐平排水格栅和路肩过渡。入口外增加阔叶草与细草，道路植被口袋补细叶灌木；维修棚调整屋面漆层/锈蚀并增加雨棚灯。本轮差异 `artifacts/realism300-validation/stage300.patch`，保留此前未提交修改。
- 已实机审阅四组同机位前后对照，包含维修棚入口、侧面、西工位及宽幅地形；工位结构与光照改善最明显，正面入口和宽幅地形收益较弱。发现试加屋脊结构与既有通风器重叠，已删除并重新冻结、拍摄及验证；旧中间结果归档 superseded-ridge-overlap，不作为最终证据。
- 对照 `artifacts/realism300-validation/review.html`，原图 `before/`、`stable-environment/`，审阅 `visual-review.md`；`source-camera-audit.json` 记录位置、目标、眼高及 yaw/pitch，四机位完全一致，56项来源与构建校验无差异，最终截图进程退出0且无记录错误。
- 最终冻结包八项检查全部退出0、无记录错误并有PASS：东/西工位通行、服务道路、维修棚碰撞、三枪108样本瞄准、武器遮挡、三枪两姿态换弹、16角色单机烟测。西工位新增两扇入口跨格栅的站姿/蹲姿双向实际胶囊通行，共8条全部通过。汇总 `artifacts/realism300-validation/verification-summary.json`，原始日志 `stable-verified/`；测试前后包哈希一致且匹配构建。
- 本地预览：`./artifacts/realism300-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，图形桌面运行后选择单机，说明 `artifacts/realism300-preview/README.md`。软件Vulkan不代表硬件性能；联网及Android本轮未验证，stage282地图一致性和stage283完整动画退出超时仍待闭环。未推送、发布、部署或修改后台服务/认证。
- 远山粗钝、树冠片状噪点、重复厂房仍明显，人物与第一人称手部完整动作画质尚未验收。下一阶段优先改正常宽幅机位的山体轮廓、树冠及环境重复，维持入口通行检查；再结合第三人称和手部实机动作审阅安排剩余缺陷，补齐联网与动画退出验证。整体目标未完成，continue。

### stage301 — 山坡侵蚀起伏与路侧桦树冠层（2026-09-16）
- 加强远山沟槽及岩层位移，调整桦树叶片尺寸、分枝高度扰动与叶色；重新生成 Blender/GLB。建筑、地坪及作业照明沿用300，不重复计为新增。差异 `artifacts/realism301-validation/stage301.patch`，原始源码保留于 `source-before/`；保留此前未提交修改。
- 四组同机位实机前后图含宽幅地形、维修棚入口/侧面和西工位，人工审阅见 `artifacts/realism301-validation/visual-review.md`，对照 `review.html`。部分山脊沟壑更明显、桦树亮色碎点减少，但大面积山坡仍光滑、树冠横向分层、建筑重复；只是有限环境改进，不能认定整体画质达标。
- `source-camera-audit.json` 保存角色位置、目标及 yaw/pitch，四机位一致、56项来源与构建匹配；截图进程退出0且无记录错误。原图在 `before/` 与 `stable-environment/`。
- 冻结包八项检查全部退出0、无记录错误并有PASS：东/西工位通行、服务道路、维修棚碰撞、三枪108样本瞄准、武器遮挡恢复、三枪两姿态换弹、16角色单机冒烟。测试前后包哈希一致且匹配构建。汇总 `artifacts/realism301-validation/verification-summary.json`，原始日志 `stable-verified/`；规则通过不替代动作画质验收。
- 本地预览：`./artifacts/realism301-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`；说明 `artifacts/realism301-preview/README.md`。软件Vulkan不证明硬件性能，联网及Android本轮未验证，stage282地图一致性和stage283动画退出超时仍待闭环。未推送、发布、部署或修改服务/认证。
- 下一步重构白桦枝系空间分布与山体大尺度轮廓、减少建筑重复，避免继续仅调整系数；维持建筑入口碰撞和单机通行验证，再结合第三人称人物及第一人称手部完整动作实机审阅处理缺陷，补齐联网验证。整体目标未完成，continue。

### stage302 — 桦树空间枝系与山口轮廓（2026-09-16）
- 重构桦树侧枝围绕枝轴的空间分布及下垂枝梢，重新生成 Blender/GLB；远山主坡改为收尖曲线并加深鞍部。差异 `artifacts/realism302-validation/stage302.patch`，备份 `source-before/`。建筑、地表及灯光沿用300，本轮没有新增这些方面的成果；保留此前未提交修改。
- 审阅四组正常游戏机位前后图，包含维修棚入口/侧面、西工位及宽幅地形：树冠轮廓更连贯、山峰和山口更明确，但枝簇条带、规则锥形山体和重复厂房仍明显。对照 `artifacts/realism302-validation/review.html`，原图 `before/`、`stable-environment/`，局限见 `visual-review.md`。只完成有限环境改善，整体画质未达标。
- `source-camera-audit.json` 保存位置、目标、眼高及 yaw/pitch；四机位一致，56项来源/构建匹配，截图进程退出0且无记录错误。最终冻结包八项检查均退出0、无记录错误且有PASS：东/西工位、服务道路、维修棚碰撞通行，三枪108样本瞄准、武器遮挡、三枪两姿态换弹、16角色单机冒烟。首次测试驱动以143中断，原因未知；保留中断日志并成功补跑道路及余项。汇总 `artifacts/realism302-validation/verification-summary.json`，原始日志 `stable-verified/`，测试前后包哈希一致并匹配构建。
- 本地预览：`./artifacts/realism302-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，图形桌面启动后选择单机，说明 `artifacts/realism302-preview/README.md`。软件Vulkan不证明硬件性能；联网及Android本轮未验证，stage282地图一致性与stage283完整动画退出超时仍待闭环。未推送、发布、部署或修改后台服务/认证。
- 下一阶段优先增加正常机位可辨识的建筑入口进深、屋面及立面差异，补墙脚地表过渡与照明层次，避免再次整轮只调山峰系数；维持建筑入口碰撞及单机通行验证，再结合第三人称人物和第一人称手部完整动作截图处理缺陷，补齐联网和动画退出验证。整体目标未完成，continue。

### stage303 — 维修棚采光屋面与墙脚地表过渡（2026-09-16）
- 西侧维修棚整片屋面改为三段不透明波纹板、两道透明采光带，新增钢制边框及纵向檩条，利用现有太阳光；保留屋面实体碰撞。棚边增加碎石过渡与局部细草。差异 `artifacts/realism303-validation/stage303.patch`，原始源码 `source-before/`；保留此前所有未提交修改。
- 已审阅四组同机位实机前后图，含维修棚、建筑入口近景、侧面及宽幅地形。正常第一人称可辨识采光带与钢梁，但地面光照收益较小、玻璃厚度和反射感弱；入口及宽幅变化很小，规则山体、层叠树冠、空旷长路和重复建筑仍明显，不判定整体画质达标。对照 `artifacts/realism303-validation/review.html`，原图 `before/`、`stable-environment/`，判断与局限 `visual-review.md`。
- `source-camera-audit.json` 保存位置、目标、眼高及 yaw/pitch，四机位参数一致；56项来源/构建哈希匹配，截图进程退出0且无记录错误。最终冻结包八项测试均退出0、无记录错误且有PASS：东西工位、服务道路、维修棚碰撞通行，三枪108样本瞄准、武器遇障恢复、三枪两姿态换弹、16角色单机冒烟。西工位新增两条采光带上下双向共8次碰撞射线全部通过；实体角色入口、排水沟及棚内通路检查通过。汇总 `artifacts/realism303-validation/verification-summary.json`，原始日志 `stable-verified/`；测试前后包哈希一致并匹配构建。
- 当前本地预览：`./artifacts/realism303-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，图形桌面运行后选择单机；说明 `artifacts/realism303-preview/README.md`。软件Vulkan不证明硬件性能。联网及Android本轮未复测，stage282地图一致性、stage283完整动画退出超时仍待闭环；规则通过不代替人物、手臂与武器完整动作的画质验收。未推送、发布、部署或修改后台服务/认证。
- 下一阶段处理宽幅机位的地形轮廓、植被群落疏密和建筑周边地表过渡，减少大尺度重复，避免继续仅微调系数或堆小道具；保留固定机位及入口通行回归，结合第三人称人物和第一人称手部实机审阅安排剩余缺陷，补齐联网与动画退出验证。整体目标未完成，continue。

### stage304 — 维修棚屋脊设备、吊梁与墙边植被（2026-09-16）
- 将维修棚短通风罩替换为长百叶结构，加入顶部吊车轨道、偏置吊具、暖色作业灯及墙边低草。首版实机发现新旧通风罩重叠，已删除旧结构后重新导出、拍摄、复测；首版证据保存在 `artifacts/realism304-validation/rejected-overlapping-vent/`，不计为最终通过。本轮差异 `stage304.patch`、修改前源码 `world_visuals.before.gd`；保留此前未提交修改。
- 四组正常游戏机位前后原图已实际审阅，包含建筑入口、侧面、西工位及宽幅地形。侧面长通风罩轮廓可辨识，墙边植被有局部变化；入口吊具被门廊遮挡，灯光收益有限，西工位与宽景基本不变。规则山体、层叠树冠、空旷道路及建筑重复未解决；本轮只是局部改善，未满足整体目标。对照 `artifacts/realism304-validation/review.html`，原图 `before/`、`stable-environment/`，局限见 `visual-review.md`。
- `source-camera-audit.json` 记录位置、目标、眼高及 yaw/pitch，四机位前后参数一致；56项来源/构建哈希匹配。最终包八项检查全部退出0、无记录错误且有PASS：东西工位、服务道路、维修棚双向通行与门柱/墙/屋顶/玻璃碰撞、三枪108组瞄准、武器遇障恢复、三枪两姿态换弹、16角色单机冒烟。截图进程退出0且无记录错误，测试前后包哈希一致。汇总 `artifacts/realism304-validation/verification-summary.json`，原始日志 `stable-verified/`。
- 当前本地预览：`./artifacts/realism304-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，图形桌面启动后选择单机；说明 `artifacts/realism304-preview/README.md`。软件Vulkan不证明硬件性能；本轮未复测联网及Android，stage282地图一致性与stage283完整动画退出超时仍待闭环，规则测试不代替人物、手臂和武器完整动作画质验收。未推送、发布、部署或修改服务/认证。
- 下一阶段必须直接改善宽景可见的地形、植被群落空间结构及建筑群之间的过渡，避免继续以小型屋顶设备、细草或参数微调充当主要进展；维持同机位截图和建筑入口通行回归，随后结合第三人称人物与第一人称手部实机审阅，补齐联网及动画退出验证。整体目标未完成，continue。

### stage305 — 连续山脊轮廓与西侧路肩群落（2026-09-16）
- 将独立圆锥式远山改为连续主脊、偏置峰顶和局部鞍部，沿用地形高度/法线与植被落地计算；西侧路肩加入五组确定性灌草群落，避开道路交叉口，不新增碰撞体。本轮差异 `artifacts/realism305-validation/stage305.patch`，修改前源码同目录 `world.gd.before`、`world_visuals.gd.before`；保留此前未提交修改。
- 已实际审阅四组同机位前后实机图，含入口、建筑侧面、工坊及宽幅地形。宽景左右山体轮廓变化明显，但仍偏圆滑、缺少岩层；新增西侧植被的画面贡献较小。建筑和光照本轮未新增改造，重复碎石、均一地面、硬直建筑仍明显，尚未完成建筑/植被/光照组合改善，更未达整体目标。对照 `artifacts/realism305-validation/review.html`，原图 `before/`、`stable-environment/`，判断见 `visual-review.md`。
- `source-camera-audit.json` 记录相机位置、目标、眼高和 yaw/pitch，四机位前后完全一致；56项来源/构建哈希匹配。冻结预览包八项检查全部退出0、无记录错误且有PASS：东西工位、服务道路、维修棚入口双向通行及门柱/墙/屋顶/玻璃碰撞、三枪108样本瞄准、武器遇障恢复、三枪两姿态换弹、16角色单机冒烟。截图进程退出0且无记录错误，测试前后包哈希一致，最终汇总校验PASS。证据 `artifacts/realism305-validation/verification-summary.json`、`stable-verified/`。服务道路测试主要覆盖东侧，不能充当新增西侧每片植被的通行证明。
- 当前本地预览：`./artifacts/realism305-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，图形桌面启动后选择单机；说明 `artifacts/realism305-preview/README.md`。软件Vulkan截图不证明硬件性能；联网及Android本轮未复测，stage282地图一致性及stage283动画退出超时仍待闭环，规则检查不代替人物、手臂和武器完整动作画质验收。未推送、发布、部署或修改后台服务/认证。
- 下一阶段继续环境优先：改造正常机位占比大的工坊/维修棚屋面、墙脚与入口，连同地表使用痕迹、排水过渡和棚下日光阴影形成连贯改善，避免仅堆小草或配件。维持同机位对照和建筑通行碰撞回归，随后进行第三人称人物、第一人称手部动作实机审阅及联网主要功能验证。整体目标未完成，continue。

### stage306 — 西工坊透光屋面、轮迹与排水地表（2026-09-16）
- 改善工坊屋面板缝老化与局部氧化，加入可辨认的乳白条纹透光板；棚下增加弯曲轮迹、落水口湿痕及外侧柱脚低草。透光板发光仅近似散射，不是物理透射，也不能计为全局光照升级。碰撞几何未修改，低草无碰撞。本轮差异 `artifacts/realism306-validation/stage306.patch`，修改前源码同目录 `*.before`；保留此前未提交修改。
- 已逐张审阅四组相同正常机位的前后实机图：工坊采光板和地表使用痕迹明显可见，屋面老化收益较弱；维修棚入口、侧面及宽幅地形基本不变。宽景仍有均一砂砾、重复树形、空旷道路及偏圆滑山体，建筑仍偏硬直。属于局部改善，整体目标未完成。对照 `artifacts/realism306-validation/review.html`、原图 `before/` 与 `stable-environment/`，具体判断 `visual-review.md`。
- `source-camera-audit.json` 记录相机位置、目标、眼高及 yaw/pitch，四机位前后完全一致；58项来源/构建哈希匹配。当前本地预览：`./artifacts/realism306-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，图形桌面启动后选择单机；说明 `artifacts/realism306-preview/README.md`。软件 Vulkan 截图不证明硬件帧率；联网及 Android 本轮未复测，stage282地图一致性与stage283完整动画退出超时仍待闭环，人物、手部和武器完整动作画质尚未验收。
- 最终冻结包八项回归全部退出0、无记录错误且有PASS：东西工位、服务道路、维修棚双向通行和实体碰撞、三枪108组瞄准、武器遇障恢复、三枪两姿态换弹、16角色单机冒烟。截图进程退出0且有PASS，测试前后包哈希一致；最终汇总校验 `STAGE306_PHASE_VERIFICATION_PASS`。证据 `artifacts/realism306-validation/verification-summary.json`、`stable-verified/` 与 `stable-capture-process-audit.json`。通行回归不等于逐棵新增草检查；规则检查不代替完整动作审阅。
- 下一阶段直接改善建筑群间宽景地表过渡与植被群落空间分布，避免继续以局部低草和材质参数作为主要推进；维持相同机位对照与建筑通行回归，随后结合第三人称人物、第一人称手部实机审阅补剩余缺陷，并闭环联网与完整动画退出验证。未推送、发布、部署或修改服务/认证。整体目标未完成，continue。


### stage307 — 维修棚外灌草群落与服务道路轮迹（2026-09-16）
- 在维修棚外布置三片有高度渐变的灌草群落，避让主要步行与装卸路线；服务地表增加双轮压痕，棚内增加两组向下照明灯。未修改实体碰撞，保留全部已有未提交修改。差异及修改前源码：`artifacts/realism307-validation/stage307.patch`、同目录 `*.before`。
- 已审阅四组相同机位前后实机图：宽景中入口两侧灌木轮廓可辨，但整体收益仍局部；轮迹较弱，新增灯具在日光下贡献很小，不能算完成建筑或光照升级。工坊基本不变，均一砂砾、大块空地、重复植被和硬直建筑仍待处理。对照 `artifacts/realism307-validation/review.html`，入口及宽幅原图见 `stable-environment/`；前图沿用经来源哈希核验的stage306截图，具体判断见 `visual-review.md`。
- 四机位位置、目标、眼高及yaw/pitch前后完全一致，58项来源/构建哈希匹配，证据 `source-camera-audit.json`。冻结预览包八项回归全部退出0、无记录错误且有PASS：东西工位、服务道路、维修棚双向通行及门柱/墙/屋顶等碰撞、三枪108样本瞄准、武器遇障恢复、三枪两姿态换弹、16角色单机冒烟（开火间隔、治疗、伤害、胜利等）。截图进程退出0且有PASS，测试前后包哈希一致；汇总 `artifacts/realism307-validation/verification-summary.json`、`final-verification.log`，原日志 `stable-verified/`。路线检查不等于逐株植被检查，规则验证不代替动作画质验收。
- 当前可运行本地预览：`./artifacts/realism307-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，图形桌面启动后选择单机，说明 `artifacts/realism307-preview/README.md`。软件Vulkan截图不证明硬件性能；联网和Android本轮未复测，stage282地图一致性、stage283完整动画退出超时及人物/手部/武器完整动作画质仍待闭环。未推送、发布、部署或修改后台服务/认证。
- 下一阶段须直接改造画面占比大的建筑入口体量、棚下日光层次及道路到建筑的大片地表过渡，避免继续把小簇植被或微弱材质参数作为主要进展；保持同机位前后对照与通行碰撞回归，再补第三人称人物、第一人称手部实机审阅及联网主要功能验证。整体目标未完成，continue。


### stage308 — 维修棚玻璃分格门与连续草带（2026-09-16）
- 将入口两侧整片金属门改为上部六格玻璃、下部波纹护板，保留实体碰撞；扩大并延伸入口外草带，同步调整根部地表过渡。环境补光由0.27降到0.20，但实机收益甚微，不计为光照目标达成。修改范围及修改前源码见 `artifacts/realism308-validation/stage308.patch`、同目录 `*.before`；保留已有未提交修改。
- 已审阅四组正常第一人称相同机位前后实机图，包括入口近景、建筑侧面、工坊及宽幅地形；前图沿用stage307冻结包截图。本轮入口分格和加厚草带可辨，玻璃明暗条带偏强；大片均一砂砾、光滑远山、重复树形及硬直建筑仍明显。对照 `artifacts/realism308-validation/review.html`，原图 `before/` 与 `stable-environment/`，判断见 `visual-review.md`。四机位位置、目标、眼高及yaw/pitch完全一致，来源校验见 `source-camera-audit.json`。
- 当前本地预览：`./artifacts/realism308-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，在图形桌面启动后选择单机；说明 `artifacts/realism308-preview/README.md`。软件Vulkan截图不证明硬件性能；联网及Android本轮未复测，stage282地图一致性、stage283完整动画退出超时及人物/手部/武器完整动作画质仍待闭环。未推送、发布、部署或修改后台服务/认证。
- 下一阶段须直接改善大面积道路—地面—建筑过渡及屋顶墙体体量，并查明补光参数变化在实际渲染中作用甚微的原因；避免继续以小簇植被或微弱参数变化作为主要成果。保持同机位对照和建筑通行回归，随后完成第三人称人物、第一人称手部实机审阅与联网主要功能验证。整体目标未完成，continue。
- 最终冻结包八项回归全部退出0、无记录错误且有PASS：东西工位、服务道路、维修棚双向通行及门板/门柱/墙/屋顶/侧窗碰撞、三枪108样本瞄准、武器遇障恢复、三枪两姿态换弹、16角色单机冒烟（装弹、治疗、伤害、胜利、射线、掩体、开火间隔等）。截图进程退出0且有PASS，59项来源/构建哈希匹配，测试前后包哈希一致；汇总校验 `STAGE308_PHASE_VERIFICATION_PASS`。证据 `artifacts/realism308-validation/verification-summary.json`、`final-verification.log` 与 `stable-verified/`。这些规则检查不代替完整动作画质验收或联网验证。


### stage309 — 维修棚到道路的连续铺装与路肩过渡（2026-09-16）
- 新增约六米宽的转弯混凝土通路、板缝和轻微磨损，调整碎石肩线并增加肩部草与阔叶植物；修正 Forward+ 实际生效的环境补光0.28→0.20。既有建筑体量未重做；保留所有已有未提交修改，阶段差异见 `artifacts/realism309-validation/stage309.patch`。
- 已实际审阅入口近景、侧面、工坊与宽幅地形四组同机位截图：宽景中的转弯铺装清晰可辨，入口用途与道路连接更明确；混凝土仍偏平滑，旧有草株穿过板面，远景建筑重复和光滑山体仍明显。光照调整未证明明显视觉收益。前图为stage308冻结包原图，前后相机位置/目标/朝向/眼高完全一致；对照 `artifacts/realism309-validation/review.html`，原图 `before/` 与 `stable-environment/`，机位 `stable-environment/environment-camera-poses.json`，判断见 `visual-review.md`。
- 新铺装专用测试覆盖道路连接与棚内连接两段，站立/蹲伏/机器人双向共12路径全部通过、无卡住；证据 `stable-verified/paved-access-traversal.json` 与 `paved-access-process.json`。冻结包其余回归最终状态见本节后续验证条目。
- 当前本地预览：`./artifacts/realism309-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，图形桌面选择单机；说明 `artifacts/realism309-preview/README.md`。软件Vulkan截图不证明硬件性能；本轮未复测联网和Android，不关闭stage282地图一致性、stage283动画捕获退出超时及完整人物/手部/武器动作验收。未推送、发布、部署或修改服务/认证。
- 下一阶段将铺装表面与杂草规则修复结合更大范围建筑体量、坡地表面和有效日光层次改造，避免继续仅以细小局部变化作为主要成果；保持相同机位对照和通行碰撞验证，再补第三人称、手部动作与联网主要功能闭环。整体目标未完成，continue。
- 最终验证：冻结预览包八项回归全部退出0、无记录错误且有PASS，覆盖东西工位/服务路/维修棚通行碰撞、三枪108样本瞄准、遇障恢复、三枪两姿态换弹、16角色单机冒烟（装弹/治疗/伤害/胜利/射线/掩体/射击间隔）。额外12条铺装路线通过；四机位截图进程退出0且有PASS，60项来源与构建哈希匹配，测试前后包哈希一致。汇总 `artifacts/realism309-validation/verification-summary.json`，标记 `final-verification.log` 中 `STAGE309_PHASE_VERIFICATION_PASS`，原日志 `stable-verified/`。规则通过不代表整体画质、完整动作或联网已验收。


### stage310 — 修复维修棚通路草木穿板与混凝土表面（2026-09-17）
- 调整通路混凝土颜色、骨料、磨损、板缝及微表面法线；细节批处理前按通路范围清理相交草木，实测移除1055个实例。保留既有未提交修改，阶段差异与修改前源码见 `artifacts/realism310-validation/stage310.patch` 和 `*.before`。
- 逐张审阅入口、侧面、工坊及宽幅地形实机前后图：铺装穿草明显减少，板面不再大片浅白；边缘收口仍生硬，建筑棚架规整、远山平滑与树形重复仍明显。本轮没有完成建筑体量或整体光照改善，属于局部缺陷修复，不能当作环境目标完成。对照 `artifacts/realism310-validation/review.html`；原图 `before/`、`stable-environment/`，相机位置/目标/朝向/眼高记录 `stable-environment/environment-camera-poses.json`，详细判断 `visual-review.md`。
- 冻结预览八项回归全部退出0、无记录错误且有PASS：东西工位、服务道路、维修棚通行与碰撞、三枪108样本瞄准、武器遇障恢复、三枪两姿态换弹、16角色单机冒烟。另有站立/蹲伏/机器人双向12条铺装路径全部通过，导航就绪且无卡住。证据 `stable-verified/functional-results.json`、`paved-access-traversal.json` 及原始日志。
- 四机位前后位置与朝向一致，前图与stage309原图哈希一致；60项来源/构建哈希匹配，测试前后包哈希相同。汇总 `artifacts/realism310-validation/verification-summary.json`，`final-verification.log` 标记 `STAGE310_PHASE_VERIFICATION_PASS`。
- 当前本地预览：`./artifacts/realism310-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，图形桌面选择单机；说明 `artifacts/realism310-preview/README.md`。软件Vulkan截图不证明硬件性能；联网和Android本轮未复测，stage282地图一致性、stage283动画捕获退出超时及完整人物/手部/武器动作验收仍未闭环。未推送、发布、部署或修改后台服务/认证。
- 下一阶段应直接改造正常机位可见的屋顶/墙体轮廓、大片坡地材质与植被分布，并查明日光/环境补光层次不足原因；避免继续以铺装或小簇草木微调作为整轮主要成果。保持同机位截图和入口通行碰撞验证，再完成第三人称、第一人称手部实机复审与联网主要功能验证。整体目标未完成，continue。


### stage311 — 人物裤腿与侧袋轮廓及第三人称动作复审（2026-09-17）
- 按当前优先级文件在stage310环境阶段后转入人物审阅：修改 `tools/build_operator.py`，将方盒侧袋改为薄软袋/翻盖，调整大腿、小腿轮廓与膝踝褶皱；重新生成 Blender、GLB 和 Linux 预览。保存修改前源码与 `artifacts/realism311-validation/stage311.patch`，保留其他未提交修改。
- 用stage310冻结包与stage311包拍摄3米/10米正侧面，四组相机位置、朝向、FOV完全匹配：`artifacts/realism311-validation/review.html`、`before/camera.json`、`after/camera.json`。近景侧袋方块感减少、膝腿轮廓更连续；远景改善有限，裤腿仍筒状，头面简陋、护膝/靴子偏大、肩肘端枪僵硬，袖腿点状阴影未判因。环境山体、重复树形与建筑规整感仍未解决，整体目标未完成。
- 当前包第三人称行走/跑步/蹲行/起身/射击/换弹采集退出0，有PASS，最终23帧及相机/姿态元数据齐全：`third-actions/action-timeline.json`、`action-review.html`。人工打开行走、跑步、蹲行、换弹中末帧；首帧因夹具从y=0.3开始而悬空，后续grounded=true，不能宣称已完整验证动态接地。四条身体射线无遮挡，前臂长度稳定；动作只有当前包、weapon=0第三人称，无旧包同动作对照，也不替代三枪第一人称验收。
- 八项功能检查均退出0、无记录错误且有PASS：四类建筑/通路碰撞、三枪108样本瞄准、遇障恢复、三枪两姿态换弹、16角色单机冒烟。`animation-rules`虽有断言PASS但退出124；无PASS时间戳，超时原因未定，不能计完整通过。汇总 `artifacts/realism311-validation/verification-summary.json` 的 `phase_checks_pass=false`。60项来源/构建哈希、前后相机及测试前后包哈希一致；首次导入线程结束错误后重试成功，Blender胸前袋网格警告仍记录。
- 当前预览：`./artifacts/realism311-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`；图形桌面选单机，说明 `artifacts/realism311-preview/README.md`。联网夹具要求认证密钥，遵守禁读限制未运行；Android与硬件性能未验证。无推送、发布、部署或服务修改。
- 下一步：给动画规则PASS与退出增加时间证据定位超时；补三枪第一人称持枪/ADS/换弹完整关键帧，重点处理上臂遮屏、袖管与接触。结合已拍人物图修正最大肩肘/护膝靴子比例缺陷，点状阴影做固定机位隔离对照。之后仍须建筑体量、大片坡地植被及日光层次整改、同机位入口/宽幅实机与通行复验，并闭环联网；不以局部裤腿改善或截图数量判定完成。continue。


### stage312 — 维修棚采光带与路肩植被层次实机整改（2026-09-17）
- 按本轮明确的环境优先要求修改 `client/scripts/world_visuals.gd`：入口雨棚分为金属板与两条贯通透明采光带，对应移除木吊顶遮挡并加收边；路肩增加三组高低灌木与阔叶草。西侧雨棚及两盏服务灯属于既有内容，本轮没有新增，不计为本轮成果。差异与准确基线见 `artifacts/realism312-validation/stage312.patch`、`world_visuals.gd.before`。
- 首版实机侧视发现枝叶遮住武器和入口，已降低植株、将西侧簇移离近景并重建重拍；首版留在 `iteration1/`，不混入最终验证。最终入口、侧面、工坊、宽幅四图均已人工打开审阅，入口与武器可见，新增采光带和路肩中层植物可辨识；入口光照改善有限，钢架点状阴影、平滑远山、重复树形和规整道路仍明显。没有完成大范围建筑体量、坡地或整体光照整改，整体目标继续。
- 同机位前图来自实际运行stage311冻结包，最终图来自stage312包。对照 `artifacts/realism312-validation/review.html`，原图 `before/` 与 `stable-environment/`；相机位置、目标、yaw/pitch、眼高和1280×800视口记录于各自 `environment-camera-poses.json`。详细审阅 `visual-review.md`，不以截图数量判定画质。
- 当前本地预览：`./artifacts/realism312-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，图形桌面选择单机；说明 `artifacts/realism312-preview/README.md`。截图使用软件Vulkan，不能证明硬件性能；本轮未复测联网/Android，stage282地图一致性、stage283/311动画退出问题及完整人物/第一人称动作仍未闭环。未推送、发布、部署或修改后台服务、认证。
- 下一步优先处理宽幅图可见的山坡轮廓、土石表面与成片树群布局，并固定机位隔离钢架点状阴影原因；建筑需进一步打破规整体量，不能继续只靠小簇草木。随后补三枪第一人称持枪/ADS/换弹关键帧，修正筒状袖管、肩肘接触与人物比例，并补联网主要功能验证。continue。
- 最终验证：冻结包八项检查全部退出0、无记录错误且有PASS，覆盖东西工位、42条服务道路路线、维修棚入口/柱脚/玻璃/侧墙碰撞、三枪108样本瞄准、遇障恢复、三枪两姿态换弹及16角色单机冒烟。四机位截图进程退出0、有PASS，前后相机完全一致；60项来源与构建哈希匹配，测试前后包未变。汇总 `artifacts/realism312-validation/verification-summary.json`，标记 `final-verification.log` 中 `STAGE312_PHASE_VERIFICATION_PASS`；原始日志 `stable-verified/`。该标记仅表示本阶段检查通过，整体目标仍为continue。


### stage313 — 山脊与坡面实机对照、建筑通行回归（2026-09-17，continue）
- 调整 `world_visuals.gd` 山脊起伏和岩肩、`terrain_slopes.gdshader` 裸岩范围与草石颜色；`world.gd` 调整日光级联阴影分区。本轮没有新增建筑或植被网格，未把上一阶段采光带计作本轮成果；独立补丁见 `artifacts/realism313-validation/stage313.patch`。
- 已逐张审阅入口、侧面、车间、宽幅地形四组 stage312→313 原始实机对照：正常机位山形变化明显，浅色裸坡减少；部分峰顶过密过尖，树形重复、建筑规整、路缘过渡及钢梁黑斑仍存在，阴影调参不算修复。见 `artifacts/realism313-validation/review.html`、`visual-review.md`。两侧 `environment-camera-poses.json` 完全一致，含位置、朝向；玩家入口(15.5,.05,39)、侧面(7.5,.05,37)、车间(-28,.05,44)、宽景(17,.05,50)，视点高1.6米。
- 当前导出包8/8验证退出0且PASS：东仓、西车间、维修通道、棚架通行/碰撞；三枪108采样瞄准；武器受阻；三枪两姿态换弹规则；16角色单机冒烟（装填、治疗、伤害、胜利、射线等）。四机位采集退出0；60项文件哈希一致，测试前后PCK一致。证据 `artifacts/realism313-validation/verification-summary.json`、`final-verification.log`、`stable-verified/`；PCK SHA256 `4fd2d6506ccc04989c3fc4f6f22534009df0e5f44b4c03faeef3994d0e2d64cb`。
- 本地预览 `artifacts/realism313-preview/Linux/IronMeridian`（同目录PCK）；在图形桌面加 `--path /tmp --rendering-method forward_plus` 启动，选单机。软件Vulkan静态单机截图及无界面规则/通行测试不代表硬件帧率或完整操作审阅。本轮未测联网、Android；既有联网外部条件、地图一致性及动作验证超时问题未关闭。未推送或发布，保留所有原有修改。
- 下一步：降低宽景尖峰密度并扩大山肩尺度，推进可辨识建筑体量与植被树形/路缘过渡；固定入口逐项隔离钢梁黑斑成因。继续三枪第一人称ADS/换弹、第三人称落地与接触实机审阅，并补联网主要功能。整体写实目标未完成，继续环境优先，不回退成整轮机匣/手指微调。

### stage314 — 维修棚外露排风、山脊与环境补光（2026-09-17，continue）
- 在 `world_visuals.gd` 新增维修棚西侧排风立管、支架与雨帽，使入口近景和宽景均能辨识建筑轮廓变化；扩大山肩、降低峰顶噪声，三处灌木改为较低较宽比例；`world.gd` 与最终 Forward+ 环境光覆盖值同步由.20调至.24。既有屋脊通风器、雨棚及植被网格不计作新增。仅本轮源码差异见 `artifacts/realism314-validation/stage314.patch`，保留此前未提交修改。
- 已打开审阅入口、侧面、车间、宽景四组实机图。前图为stage313历史冻结包截图（来源哈希见 `baseline-provenance.json`），后图为本轮最终包；对照 `artifacts/realism314-validation/review.html`，详细结论 `visual-review.md`。前后相机JSON完全一致，记录位置、目标与yaw/pitch；入口(15.5,.05,39)、侧面(7.5,.05,37)、车间(-28,.05,44)、宽景(17,.05,50)，眼高1.6米。早期背面管线和光照覆盖修正前尝试单独存档，不作为最终证据。
- 最终8项测试全部退出0、有PASS且无记录错误：东西工位、服务道路、维修棚双向通行/柱脚/侧墙/玻璃碰撞，三枪108样本瞄准、武器遇障恢复、三枪两姿态换弹规则、16角色单机冒烟。四机位采集退出0且PASS；60项源码/构建哈希一致，测试前后包未变。证据 `artifacts/realism314-validation/verification-summary.json`、`final-verification.log` 与 `stable-verified/` 原始日志。
- 本地预览：`./artifacts/realism314-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，图形桌面选择单机，同目录保留PCK；说明 `artifacts/realism314-preview/README.md`。软件Vulkan静态截图和无界面功能测试不证明硬件帧率或完整人工游玩，本轮未新增联网/Android验证。未推送、发布、部署或修改后台服务。
- 局限与下一步：排风立管和山形变化可见，但灌木与补光改善较小，钢梁黑斑、团块山体、重复树冠、规整建筑和单调路缘仍明显；下一阶段固定入口隔离钢梁黑斑原因，并推进树形/道路边缘与建筑体量。继续保留第一人称筒状袖管、三枪ADS/换弹及第三人称比例/接触的实机整改，补联网主要功能和既有地图一致性、动画超时验证。整体写实目标未完成。

### stage315 — 独立百叶通风帽、道路树丛与斜向日照（2026-09-17，continue）
- 将维修棚连续屋脊通风结构改为两座独立百叶通风帽；道路旁乔木由三处增至六处，扩大九处灌木；调整日照方向、颜色和强度。仅本轮源码差异见 `artifacts/realism315-validation/stage315.patch`，保留原有未提交修改。
- 已逐张审阅入口近景、侧面、车间、宽幅地形实机原图与对照：`artifacts/realism315-validation/review.html`、`visual-review.md`。前图为stage314历史冻结包截图，非本轮重新采集，来源哈希见 `baseline-provenance.json`；后图为315最终包。相机JSON完全一致，保存位置、目标及yaw/pitch；入口(15.5,.05,39)、侧面(7.5,.05,37)、车间(-28,.05,44)、宽景(17,.05,50)，眼高1.6米。
- 八项功能测试全部退出0、PASS且无记录错误：东西工位、服务道路、维修棚通行与碰撞；三枪108采样瞄准；武器受阻；三枪两姿态换弹规则；16角色单机冒烟。四机位采集退出0且PASS，60项文件哈希一致，测试期间包未变。证据 `artifacts/realism315-validation/final-verification.json`、`stable-verified/functional-results.json`、`stable-verified/`原始日志及`stable-capture-process-audit.json`。自动物理通行和规则检查不等于完整人工游玩。
- 本地预览：`./artifacts/realism315-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，图形桌面选择单机，同目录PCK及README保留。截图使用软件Vulkan，未验证硬件帧率。本轮未复测联网，认证与房间准入条件仍需满足，历史地图一致性及动作验证超时未关闭；未读取凭据、修改后台服务、推送或发布。
- 局限与下一步：近景通风帽和斜向阴影可辨识，宽景植被填充仅有限改善空旷感；平坦路缘、重复树冠、团块远山和规整建筑仍明显。屋顶斑点在旧包提高阴影bias的诊断中未消失，未应用该实验，也未声称定位修复。下一阶段推进更有尺度变化的树形、路肩地表过渡和建筑体量，继续隔离屋顶斑点；结合第三人称比例/接触与三枪第一人称ADS/换弹实机审阅处理筒状袖管等缺陷，再补联网闭环。整体目标未完成，不回退为整轮机匣或手指微调。

### stage316 — 维修棚卷帘、路肩草丛与入口灯光（2026-09-17，continue）
- 新增半升卷帘、板条材质、导轨和控制盒；降低并打散服务道路草丛，减弱入口自发光和聚光灯。保留全部既有未提交修改，无推送、发布或服务变更。
- 已审阅四机位实机原图及入口/宽景对照：`artifacts/realism316-validation/review.html`、`visual-review.md`。前图为315历史截图，来源哈希见`baseline-provenance.json`；后图为316最终包。前后相机JSON完全一致，位置与朝向见`stable-environment/environment-camera-poses.json`；入口(15.5,.05,39)、侧面(7.5,.05,37)、车间(-28,.05,44)、宽景(17,.05,50)，眼高1.6米。
- 八项功能检查通过：四项建筑/道路实际物理通行与碰撞、三枪108采样瞄准、武器遮挡、三枪两姿态换弹规则、16角色单机冒烟。新增卷帘2.6米射线通过、3.1米命中，最低净空约2.82米。采集退出0且PASS，61项清单哈希一致，测试期间包未变。证据`artifacts/realism316-validation/final-verification.json`、`stable-verified/functional-results.json`及原始日志。
- 当前预览：`./artifacts/realism316-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，图形桌面选单机，相邻PCK及README保留。软件Vulkan截图不证明硬件帧率或完整人工游玩；本轮无新第三人称画质验收，联网认证准入与历史地图/动作超时仍未关闭。
- 局限：卷帘在入口可见但被雨棚遮挡较多，宽景草丛变化小，灯罩仍亮白；不能认定整体画质达标。下一阶段优先宽景可辨识的路肩起伏、土石/草地渐变和建筑周边空间体量，避免继续堆被遮挡的小配件；继续屋面斑点、人物比例/接触、第一人称筒状袖管及联网闭环。整体目标未完成。

### stage317 — 维修区草坡碰撞、地表过渡与雨棚斜撑（2026-09-17，continue）
- 增加正常宽景可辨识的路肩起伏，植被根部随地形、坡面露出裸土，新增东侧雨棚纵向钢斜撑。地形与碰撞共用高度函数；没有修改光照参数，局部明暗变化来自坡面及结构投影。保留既有未提交修改，无推送、发布或服务变更。
- 已审阅四机位最终包实机截图及入口、侧面、宽景前后对照：`artifacts/realism317-validation/review.html`、`visual-review.md`。前图为316历史截图，来源哈希见`before-provenance.json`；前后机位完全一致，位置与朝向见`stable-environment/environment-camera-poses.json`及审阅表。入口(15.5,.05,39)、侧面(7.5,.05,37)、车间(-28,.05,44)、宽景(17,.05,50)，眼高1.6米。
- 初版草坡反向横穿卡住，保留`attempt1-steep-bank/`失败证据；降低并平滑坡度后，站立、蹲行、机器人两路线双向共12项实际通行通过，站立/蹲行峰值爬升约1.03–1.06米。新增测试`tests/stage317_berm_traversal_review.gd`，结果与日志见`stable-verified/stage317-berm-traversal.json`、`berm-traversal.log`。
- 最终包八项检查全部通过：四项建筑/道路通行碰撞、三枪108采样瞄准、武器遮挡、三枪两姿态换弹规则、16角色单机冒烟。采集退出0，61项清单哈希一致，测试期间PCK未变；证据`artifacts/realism317-validation/final-verification.json`及`stable-verified/functional-results.json`。
- 当前预览：`./artifacts/realism317-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，图形桌面选择单机，相邻PCK与README保留。本轮未复测联网或验收第三人称、三枪ADS/换弹画质；软件Vulkan截图不证明硬件帧率或完整人工游玩。
- 局限与下一步：入口左侧草坡、坡脚阴影及侧面斜撑可辨识，但改善集中在维修棚周围，远处空地、重复树冠、规则建筑墙面、屋面斑点及亮白灯罩仍明显。下一阶段继续树形尺度/轮廓差异、建筑周边空间变化与灯光缺陷，再结合第三人称比例接触、第一人称筒状袖管实机审阅及联网闭环推进完整目标。整体目标未完成。

### stage318 — 门廊砌体、灌木层次与局部灯光（2026-09-17，continue）
- 维修棚入口新增有碰撞的砌体端柱，加高侧墙与压顶、调整木屏和百叶；五处灌木岛增加数量及冠幅高度变化，降低维修棚灯罩自发光与门廊灯强度并增加遮光边。独立生产源码差异见 `artifacts/realism318-validation/stage318-world.patch`，未把原有草坡或车间灯光计作新增。
- 已审阅入口近景、侧面、车间、宽幅地形四组实际游戏截图，前图为stage317历史冻结截图，后图为318导出包。对照与局限：`artifacts/realism318-validation/review.html`、`visual-review.md`；来源哈希 `before-provenance.json`。前后相机JSON完全一致，位置、目标及yaw/pitch见 `stable-environment/environment-camera-poses.json`：入口(15.5,.05,39)、侧面(7.5,.05,37)、车间(-28,.05,44)、宽景(17,.05,50)，眼高1.6米。
- 最终九项检查退出0、PASS且无记录错误：草坡站立/蹲行/机器人12条路线，四项建筑/道路通行与碰撞，三枪108采样瞄准、武器受阻、三枪两姿态换弹规则、16角色单机冒烟。棚架29项检查含新增端柱上部碰撞、侧屏开口、双向通行、柱脚绕行、卷帘净空及玻璃。两次驱动中断143原因未确认，保留中断证据；通过结论只采用最终完整退出的测试。证据 `artifacts/realism318-validation/final-verification.json`、`stable-verified/functional-results.json`及原始日志。
- 四机位采集退出0且PASS；构建与外部测试合并清单62项哈希一致，测试期间PCK未变。原始构建清单与导出后外部碰撞测试修订哈希分别保留。PCK SHA256 `38e0aa9afd0988f8fa5eacead7e5c8cf371e5c50bdbe62ca6467a4d07f5719e9`。
- 本地预览：`./artifacts/realism318-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，图形桌面选单机，同目录PCK及README保留。软件Vulkan截图与无界面规则测试不代表硬件帧率或完整人工游玩。本轮未复测联网、第三人称或第一人称手部画质；相关目标继续保留。未推送、发布、部署或修改后台服务，保留既有未提交修改。
- 局限与下一步：入口柱墙和侧面植物层次可辨识，但宽景整体与317接近；白墙仍平整、矩形污渍不自然、前场空旷、叶片卡片和重复树冠仍明显。下一阶段推进自然材质污渍、前场地表过渡与有用途的场景布置，保持通行空间；随后结合第三人称比例/接触、第一人称袖管与手部实机审阅，并补联网闭环。整体写实目标未完成。

### stage319 — 砌体风化、墙脚混植与落水沉积（2026-09-17，continue）
- 砌体剥落边缘改为不规则形状，增加雨水污迹；维修棚两侧增加八簇96实例低草/阔叶，保留入口通道；四处落水口增加沉积湿痕，入口灯能量1.8→1.45。仅本轮源码差异见 `artifacts/realism319-validation/stage319-world.patch`。保留全部既有未提交修改，未推送、发布或修改后台服务。
- 四组实机原图已逐张审阅：`artifacts/realism319-validation/review.html`、`visual-review.md`。前图为318归档截图，后图为319最终包；前后相机JSON完全一致，来源哈希见`before-provenance.json`。入口(15.5,.05,39)、侧面(7.5,.05,37)、车间(-28,.05,44)、宽景(17,.05,50)，眼高1.6米；目标与yaw/pitch见`stable-environment/environment-camera-poses.json`。
- 最终九项检查均退出0、PASS且无记录错误：草坡12条路线、四项建筑/道路物理通行碰撞、三枪108采样瞄准、武器遮挡、三枪两姿态换弹规则、16角色单机冒烟。棚架29项覆盖双向穿行、柱脚绕行、卷帘净空、侧屏及玻璃。证据 `artifacts/realism319-validation/final-verification.json`、`stable-verified/functional-results.json`及原始日志。自动测试不等于完整人工游玩。
- 四机位采集正常退出0且PASS；64项构建/外部测试清单哈希一致，测试期间PCK未变。首次实际渲染发现runoff同名变量编译错误，修正为pipe_runoff后重新构建并重跑全部最终检查；失败证据单独保留，不计通过。最终汇总 `final-assembly.log` 为STAGE319_FINAL_VERIFICATION_PASS。
- 当前本地预览：`./artifacts/realism319-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，图形桌面运行并保留同目录PCK；说明 `artifacts/realism319-preview/README.md`。Forward+软件Vulkan截图不证明硬件帧率。本轮未复测联网、第三人称及手部画质，整体目标未完成。
- 审阅结论与下一步：近景墙体剥落与墙脚植物可辨，但竖向污迹仍程序化；落水湿痕较弱，灯具白条未解决，宽景几乎不变。不能把本轮局部收益视为整体环境改善。下一阶段结合第三人称比例/接触与第一人称袖管、手部动作实机审阅处理主要缺陷，补stage311动画PASS后正常退出证据及当前包联网闭环；环境仍需更有尺度变化的建筑轮廓、远山和道路植被布置，避免继续以局部污渍调整替代整体进展。

### stage320 — 第三人称蹲姿支撑与动画完整退出验证（2026-09-17，continue）
- 按最新检查点重返人物审阅：修正截图测试使用真实 crouch/update_stance；Blender蹲姿髋部后移18cm、略抬高，双脚支撑加宽、双膝略向外，重新生成模型及15段动画。独立改动见 `artifacts/realism320-validation/operator-pose.patch`。保留既有未提交修改，未推送、发布或修改后台服务。
- 已逐张审阅stage319/320实际导出包的3m/10m正侧面原图，四组相机八项参数完全一致；对照 `artifacts/realism320-validation/review.html`，位置、朝向及FOV见 `before/camera.json`、`after/camera.json`。3m侧面小腿轮廓与支撑关系改善明显，10m正面收益小；头面、袖管、护膝和背包仍简化，空旷道路、折面山体及重复树形仍明显。完整判断见 `visual-review.md`。
- 最终动画检查PASS且正常退出0（316.509秒），补上当前包的完整退出证据；17骨骼、15动画、6材质。847次动态脚底取样通过，最深穿地1.26mm、最大双脚最小支撑间隙7.32mm。九项功能检查均PASS、退出0，覆盖建筑与地形碰撞通行、三枪108采样瞄准、遮挡、三枪两姿态换弹、16角色单机冒烟。证据 `animation/`、`sole-cycle/`、`stable-verified/functional-results.json`。
- 后图采集重试PASS、退出0（291.538秒）；61项构建清单哈希一致，测试期间PCK未变。汇总 `artifacts/realism320-validation/final-verification.json`、`final-assembly.log`。首次导入渲染线程错误及首次采集/动画异常退出143均保留，不计通过；Blender胸前口袋无效多边形警告仍记录。
- 本地预览：`./artifacts/realism320-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，保留同目录PCK，说明见 `artifacts/realism320-preview/README.md`。软件Vulkan实机截图不证明硬件帧率或完整人工游玩。
- 下一步：审阅三枪腰射、ADS、换弹关键帧与第一人称袖管/手部贴合，处理主要形体缺陷并补当前包联网闭环；环境继续推进建筑轮廓、远山、道路植被与入口光照的整体改善。本轮未复测联网，整体写实目标未完成。


### stage321 — 维修棚连续屋脊、道路低草与入口补光（2026-09-17，continue）
- 按当前环境优先级修改 `client/scripts/world_visuals.gd`：两个小通风帽替换为带百叶、立柱及坡顶的连续屋脊通风构件；三片道路边缘增加高低混合低草，避开主路、装卸路线；提升入口与棚内补光。保留原屋顶及建筑碰撞和全部既有未提交修改，未推送、发布、部署或修改后台服务。
- 使用冻结stage320包与stage321最终包重新采集四组正常游戏机位，八张原图逐张审阅；入口(15.5,.05,39)、侧面(7.5,.05,37)、车间(-28,.05,44)、宽景(17,.05,50)，眼高1.6米，1280×800。前后位置、目标、yaw/pitch记录完全一致，见 `artifacts/realism321-validation/before/environment-camera-poses.json`、`stable-environment/environment-camera-poses.json`；对照 `review.html`，判断 `visual-review.md`。
- 实际收益：侧面和宽景的连续屋脊轮廓明显，宽景左侧路肩低草改善局部硬地过渡；正面大部分屋脊被原屋顶遮挡，补光收益较弱，车间控制机位几乎不变。远山折面、重复树冠、带状植被、失真墙面污迹及过亮灯条仍明显，不能据截图数量或局部收益判定整体画质达标。
- 最终九项检查均PASS、退出0且无记录错误：草坡通行、东西建筑与道路/棚架碰撞通行、三枪108采样瞄准、武器遮挡、三枪两姿态换弹、16角色单机冒烟；棚架29项包括入口双向通行、柱脚阻挡与绕行、卷帘净空、屋顶、侧墙及玻璃。两次四机位采集均PASS、退出0，61项构建清单哈希一致，测试前后PCK未变。证据 `artifacts/realism321-validation/final-verification.json`、`final-assembly.log`、`stable-verified/functional-results.json`及原始日志。
- 本地预览：`./artifacts/realism321-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，图形桌面选择Solo，保留同目录PCK；说明 `artifacts/realism321-preview/README.md`。软件Vulkan、暂停逻辑后的实际游戏截图和自动物理测试不等于硬件帧率验证或完整人工游玩。本轮联网NOT_RUN：现有联网脚本会访问凭据，未执行、未读取密钥；第三人称画质沿用stage320审阅，本轮没有重新采集人物。
- 下一步：优先消除宽景远山折面与重复树冠，改善大尺度植被分布、墙面污迹和灯具曝光，继续同机位实机对照；保留三枪腰射/ADS/换弹关键帧与第一人称手部袖管审阅、第三人称剩余形体缺陷及当前包联网闭环任务。整体目标未完成。

### stage322 — 远山条带消除与林冠尺度变化（2026-09-17，continue）
- 修改 `client/scripts/world_visuals.gd`：移除远山高度量化造成的明亮等高条带，共用网格128→192格并缓存共享顶点法线；按坡地庇护程度改变林冠尺度，保持根部埋入及生产碰撞不变。有限差分法线与实际网格贴地检查保留；相对stage321的本轮补丁见 `artifacts/realism322-validation/stage322.patch`。保留既有未提交修改，未推送、发布、部署或修改服务。
- 冻结stage321与stage322包重新采集四组正常游戏机位，逐张审阅八张原图：宽景左侧山体白色条纹明显减少、坡面连续性改善；林冠变化较弱，入口及车间建筑近景基本不变。仍有大尺度墙面锈斑、重复树形/裂缝、刺眼屋顶高光及白灯管，本轮未解决这些缺陷，整体画质未达标。
- 对照 `artifacts/realism322-validation/review.html`、判断 `visual-review.md`；前后原图在 `before/` 与 `stable-environment/`。四机位入口(15.5,.05,39)、侧面(7.5,.05,37)、车间(-28,.05,44)、宽景(17,.05,50)，眼高偏移1.6米、1280×800；两份 `environment-camera-poses.json` 的位置、目标和yaw/pitch精确一致。
- 九项功能检查均PASS、退出0且无记录错误：草坡、东西建筑、道路、棚架碰撞通行，三枪108采样瞄准，武器遮挡，三枪两姿态换弹，16角色单机冒烟。首轮进程退出143、原因未知，保留 `interrupted-tests/`，仅保留已有退出码的两项，其余补跑成功。背景实际网格射线贴地测试：18山体、14417树实例，最大根部误差0.000137米；6965是小尺度实例计数而非物种数。
- 最终核验PASS：62项构建输入哈希一致、前后截图采集各PASS且退出0、测试前后PCK未变。证据 `artifacts/realism322-validation/final-verification.json`、`final-assembly.log`、`background-scenery-result.json`、`stable-verified/functional-results.json` 与对应原始日志。
- 当前本地预览：`./artifacts/realism322-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，需图形桌面及同目录PCK，选择Solo；说明 `artifacts/realism322-preview/README.md`。软件Vulkan截图与自动物理测试不等于硬件帧率或完整人工游玩。联网NOT_RUN：现有认证脚本会访问凭据，本轮未执行也未读取密钥；第三人称画质仍沿用stage320，手部/武器动作实机审阅待继续。
- 下一步：优先处理正常入口机位墙面锈斑尺度、左侧金属屋顶粗糙度与灯具曝光，再做同机位入口/宽景对照及碰撞通行复验；继续保留第三人称形体、第一人称手部袖管及三枪腰射/ADS/换弹关键帧审阅、当前包联网闭环任务。整体目标未完成。

### stage323 — 入口与车间抹灰尺度、灯具遮光（2026-09-17，continue）
- 修改 `client/shaders/workshop_masonry.gdshader`：大块软边褐斑改为墙脚局部剥落露砖，上部保留完整抹灰；`shelter_metal.gdshader` 降低粉化/补片增白与金属反射、提高粗糙度；`world_visuals.gd` 降低共用灯具自发光，入口主灯增加钢制遮光边框，无碰撞。保留原建筑碰撞及既有未提交修改，未推送、发布、部署或修改服务。
- 冻结stage322与最终stage323包各采集四个正常游戏机位，逐张审阅八张原图：入口、侧面及车间褐色大斑明显减少，入口灯带白条收敛；上墙波浪雨痕仍重复，屋顶调整收益小，宽景几乎不变，屋顶亮斑、贴片树木和远景折面仍明显。本轮未修改地形植被，整体画质未达标。
- 对照及审阅：`artifacts/realism323-validation/review.html`、`visual-review.md`，原图 `before/`、`stable-environment/`。入口(15.5,.05,39)、侧面(7.5,.05,37)、车间(-28,.05,44)、宽景(17,.05,50)，眼高偏移1.6米、1280×800；两份 `environment-camera-poses.json` 位置、目标及yaw/pitch完全一致。
- 九项功能检查全部PASS、退出0且无记录错误：草坡、东西建筑、道路及棚架碰撞通行，三枪108采样瞄准，武器遮挡，三枪两姿态换弹，16角色单机冒烟。包含入口双向进出、柱脚阻挡与绕行、卷帘净空及墙顶玻璃碰撞。最终核验PASS：62项构建清单哈希一致、测试前后PCK未变、两次实机采集均PASS且退出0。证据 `artifacts/realism323-validation/final-verification.json`、`final-assembly.log`、`stable-verified/functional-results.json` 及对应原始日志。
- 当前本地预览：`./artifacts/realism323-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，需要图形桌面及同目录PCK，选择Solo；说明 `artifacts/realism323-preview/README.md`。软件Vulkan静态实机与自动物理测试不代表硬件帧率或完整人工游玩。联网NOT_RUN：现有认证脚本访问凭据，本轮未执行且未读取密钥；第三人称视觉沿用stage320，第一人称动作审阅尚待继续。
- 下一步：优先修正墙面等距波浪雨痕、定位宽景左屋顶实际材质及过亮来源，结合植被分布与树形重复继续环境提升并保持同机位对照/通行复验；保留第三人称形体、第一人称手部袖管与三枪腰射/ADS/换弹实机关键帧及当前包联网闭环。整体目标未完成。

### stage324 — 墙面雨痕、坡屋面与道路灌木调整（2026-09-17，continue）
- 修改 `workshop_masonry.gdshader`，以大尺度干湿区域打断细雨痕、取消高频横向扭曲；`world.gd` 调整坡屋面底色、法线及高光；`world_visuals.gd` 降低道路边灌木高度/宽度/木本比例并增加空隙，保留通道排除范围与原碰撞。保留既有未提交修改，未推送、发布、部署或修改服务。
- 冻结stage323与最终stage324包四机位实机对照：入口、侧面及车间上墙重复波浪条纹明显减弱；宽景左屋面仍泛白且纹理嘈杂，中央椭圆灌木带仍高密，局部枝梢降低不足以改变主要轮廓。墙脚锯齿剥落、方硬结构、亮灯条、重复树形及远山折面仍突出，整体画质未达标。
- 证据：`artifacts/realism324-validation/review.html`、`visual-review.md`、`before/`、`stable-environment/`及四张`*-comparison.png`。入口(15.5,.05,39)、侧面(7.5,.05,37)、车间(-28,.05,44)、宽景(17,.05,50)，眼高1.6米、1280×800；两份`environment-camera-poses.json`完整位置/目标/yaw/pitch完全一致，审阅文档记录朝向。
- 九项功能检查全部PASS、退出0且无记录错误：草坡、东西建筑、道路及棚架碰撞通行，三枪108采样瞄准、武器遮挡、三枪两姿态换弹、16角色单机冒烟；包含入口双向进出、柱脚阻挡/绕行、卷帘净空、墙顶玻璃碰撞。最终核验PASS，62项构建清单哈希一致、测试前后PCK未变、前后采集各四帧且退出0。详见`final-verification.json`、`final-assembly.log`、`stable-verified/functional-results.json`及原始日志。
- 初次导入缩进错误已修复，保留`initial-import-failed.log`；首次新包采集退出143原因未知，保留`interrupted-environment/`及`interrupted-capture-audit.json`，未计为完整通过。最终补采成功且对照图已用最终四帧重新生成。
- 本地预览：`./artifacts/realism324-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，需图形桌面及同目录PCK，选择Solo；说明`artifacts/realism324-preview/README.md`。软件Vulkan静态截图与自动测试不代表硬件帧率或完整人工游玩。联网NOT_RUN：现有认证脚本访问凭据，本轮未执行也未读取密钥；第三人称视觉仍为stage320，第一人称手部/武器动作实机审阅待继续。
- 下一步：先定位宽景发白屋面的实际网格/材质、主椭圆灌木带的重叠植被层，再修正可见主体，不继续仅凭名称猜测参数；保持同机位入口/宽景与碰撞通行复验，随后处理重复树形、地形折面、墙脚边缘。保留第三人称形体、手部袖管、三枪腰射/ADS/换弹关键帧和当前包联网闭环。整体目标未完成。

### stage325 — 降低西侧草丘并复验通行（2026-09-17，continue）
- `world_visuals.gd` 降低西侧路肩主隆起并加入侵蚀沟槽，渲染、碰撞及植被落点使用同一高度函数；`world.gd` 与新增 `workshop_main_roof.gdshader` 调整主坡屋面涂层、粗糙度及面板色差。保留全部既有未提交修改，未推送、发布、部署或操作服务。
- stage324/325冻结包四机位实机审阅：宽景西侧高椭圆草丘明显降低、顶部更平；草丛仍连续密集，沟槽远观不明显。左屋顶仍泛白且细碎，屋面材质改动未达到预期效果；入口、侧面和车间没有明显视觉改善。建筑、植被及光照整体目标未完成。
- 同机位前后、入口近景和宽幅证据：`artifacts/realism325-validation/review.html`、`visual-review.md`、四张 `*-comparison.png`、`before/`、`stable-environment/`。入口(15.5,.05,39)、侧面(7.5,.05,37)、车间(-28,.05,44)、宽景(17,.05,50)，眼高1.6米、1280×800；两份 `environment-camera-poses.json` 位置与朝向完全相同，yaw/pitch另见审阅表。
- 九项功能检查最终PASS、退出0：18条草坡路线、东西建筑及棚架碰撞、42条道路/入口站立蹲行机器人路线、三枪108采样瞄准、武器遮挡、三枪两姿态换弹与16角色单机冒烟。道路首轮因旧草坡高度下限失败，完整保留 `initial-lane-failure/`；仅更新西坡爬升范围为0.25–0.70米、保留东坡要求后复测PASS，详见 `lane-retest/`。原测试修订及哈希保存在构建清单，未改冻结EXE/PCK。
- 最终核验 `final-verification.json` 与 `final-assembly.log` PASS：64项清单哈希一致、测试前后PCK一致、前后四帧采集均退出0。功能汇总 `stable-verified/functional-results.json` 指向各原始日志及复测记录。
- 当前本地预览：`./artifacts/realism325-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，图形桌面选择Solo，保留同目录PCK；说明 `artifacts/realism325-preview/README.md`。软件Vulkan截图与自动测试不能证明硬件性能或完整人工游玩。联网NOT_RUN：现有认证脚本读取凭据，遵守用户限制未执行；第三人称视觉沿用stage320，第一人称手部/武器动作实机审阅未完成。
- 下一步：定位宽景可见发白屋面的确切网格与材质，再处理亮屋面和灯条；打断连续草丛、重复树形及远山折面，维持入口/宽景同机位对照与碰撞复验。保留第三人称形体、手部袖管、三枪腰射/ADS/换弹关键帧及当前包联网闭环，不以本轮局部地形收益宣称整体完成。

### stage326 — 入口植被疏理及前雨棚材质复验（2026-09-17，continue）
- `world_visuals.gd` 减少维修棚周边灌木数量、冠幅和高冠，西侧植株外移；车间前雨棚及接缝肋改用粗糙涂层，降低顶棚及场坪补光。保留全部既有未提交修改，未推送、发布、部署或操作后台服务。
- stage325/326四机位实机对照：宽景入口两侧灌木遮挡减少；入口和车间近景变化有限，左侧屋面白亮高光仍未解决，不能判定材质调整成功。墙脚规律锯齿、重复树形和远山简化仍明显，整体写实目标未完成。
- 证据：`artifacts/realism326-validation/review.html`、`visual-review.md`、四张`*-comparison.png`及`before/`、`stable-environment/`原图。两组相机位置、目标、yaw/pitch完全一致；入口(15.5,.05,39)、侧面(7.5,.05,37)、车间(-28,.05,44)、宽景(17,.05,50)，眼高1.6米，详见`environment-camera-poses.json`。
- 冻结包九项自动检查全部PASS：草坡、东西建筑、维修道路及棚架通行/碰撞，三枪108采样瞄准，武器近墙遮挡，第三人称换弹规则和16角色单机冒烟。`stable-verified/functional-results.json`及各原始日志可复核；本轮未修改测试。`final-verification.json`、`final-assembly.log`核验PASS，64项构建哈希一致，测试前后PCK一致，两组截图采集退出0。
- 本地预览：`./artifacts/realism326-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，图形桌面选择Solo，保留同目录PCK，说明`artifacts/realism326-preview/README.md`。软件Vulkan与自动测试不等于硬件性能或完整人工游玩。联网NOT_RUN：现有认证脚本访问凭据，本轮遵守限制未执行、未读取凭据；当前第三人称视觉仍为stage320，第一人称动作画质未复验。
- 下一步：从宽景中实际可见白亮屋面定位网格/材质和光源贡献，消除白亮屋面与近景墙脚锯齿，不继续仅凭节点名称改参数；继续改善植被重复与地形。保留第三人称形体、手部袖管、三枪腰射/ADS/换弹关键帧和当前包联网闭环，整体保持continue。


### Stage327（2026-09-17）：环境墙脚、维修棚屋面/灯光与草簇
- 已完成一组可见环境修改：墙脚连续锯齿露砖改为局部剥落；维修棚顶降低镜面反射并统一肋条材质；工作台暖光减弱；棚外草簇调整为疏密不等的小簇。生产改动限于 `world_visuals.gd`、`workshop_masonry.gdshader`、`workshop_bay_roof.gdshader`，保留原有未提交修改。
- 冻结 stage326/327 包同机位实机对照已逐图审阅：`artifacts/realism327-validation/review.html`，入口、侧面、维修棚及宽景原图在 `before/`、`stable-environment/`。对应 `environment-camera-poses.json` 记录位置、目标、yaw/pitch、眼高及分辨率，4组前后一致。近景墙脚/棚顶改善明确；宽景左屋面白斑仍在，远山折面、重复树形、粗梁柱及灯条仍显简化。详见 `visual-review.md`。
- 同一导出包9项自动回归通过：五项建筑/地形通行与碰撞、三枪108样本瞄准、近墙武器阻挡、第三人称换弹规则、16角色单机冒烟。`stable-verified/functional-results.json` 与逐项日志可复核；`final-verification.json`/`final-assembly.log` 核验源码/包哈希、相机和截图，通过 `STAGE327_FINAL_VERIFICATION_PASS`。软件Vulkan截图及自动测试不代表完整人工游玩或硬件性能。
- 本地可运行预览：`artifacts/realism327-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`（项目根目录图形桌面运行，保留相邻pck；README含说明）。未发布、未push。
- 未完成/下一步：优先处理宽景左屋面残余白斑与远山折面；结合第三人称人物、第一人称三枪腰射/ADS/换弹关键帧继续审阅手部袖管与模型。当前包联网未测：现有认证测试入口访问凭据，本轮遵守禁止读取凭据的限制未执行，需要合规验证路径，不能报通过。人物视觉最近仍为stage320，换弹规则通过不代替视觉审阅。整体保持 continue。

### Stage328（2026-09-17）：消除工坊采光板白亮条，校正山体网格法线
- 修改 `workshop_roof_glazing.gdshader` 的自发光、粗糙度、透明度与积尘色；`world_visuals.gd` 山体改用实际三角面面积加权法线。正常宽景中左屋顶白条及工坊近景头顶白条已消失；山体明暗仅小幅变化，远山折面、重复树群、平坦裸地与粗梁柱仍明显，本轮未改善植被造型。没有把局部修复算作整体完成。
- 实机四组同机位前后对照已逐图审阅：`artifacts/realism328-validation/review.html`、`visual-review.md`、四张 `*-comparison.png`。原图位于 `before/` 和 `stable-environment/`；相邻 `environment-camera-poses.json` 记录精确位置/目标/弧度朝向/分辨率，前后完全一致。入口(15.5,.05,39)、侧面(7.5,.05,37)、工坊(-28,.05,44)、宽景(17,.05,50)，眼高1.6米。
- 冻结包9项自动回归全部PASS：五项地形/建筑通行碰撞、三枪108采样瞄准、武器遮挡、第三人称换弹规则和16角色单机冒烟；证据 `stable-verified/functional-results.json` 与逐项日志。新增山体法线检查、14417树根真实网格贴地检查PASS，最大误差 .000137，详见 `background-scenery.log`。`final-verification.json`/`final-assembly.log` 核验构建哈希、测试前后包、四组相机和截图，通过 `STAGE328_FINAL_VERIFICATION_PASS`。
- 当前本地预览：`./artifacts/realism328-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`（项目根目录图形桌面启动，保留同目录pck）；说明 `artifacts/realism328-preview/README.md`。软件Vulkan截图不代表硬件性能或完整人工游玩。保留所有未提交修改，未push、未发布。
- 未完成/下一步：继续环境成组改进，优先宽景重复树形、裸地起伏/草簇过渡、建筑粗柱与大墙面；山体需改善形体而非仅调法线。随后复验第三人称形体、第一人称三枪腰射/ADS/换弹手部袖管。联网NOT_RUN：认证测试路径需要访问凭据，本轮未读取，仍需合规验证路径；人物视觉最近仍stage320，规则PASS不替代画质审阅。整体 continue。

### Stage329（2026-09-17）：入口细钢柱、非对称山脊与草带/门廊光照调整
- `world_visuals.gd` 将入口通高粗砌筑柱改为矮基座、压顶及细钢柱；远山峰高、宽度和位置改为不等比例；草带边缘采用更宽的疏密过渡，入口补光增强、灯条减弱。入口上部视线与宽景山脊变化清楚；草带和光照变化较小，不能视为植被/光照写实目标完成。粗梁、大墙面、重复树群、平坦裸地和山体折面仍待处理。
- 冻结stage328/329四组同机位实机对照已逐图审阅：`artifacts/realism329-validation/review.html`、`visual-review.md`，原图在 `before/`、`stable-environment/`。两份 `environment-camera-poses.json` 完全一致，记录精确目标与yaw/pitch；入口(15.5,.05,39)、侧面(7.5,.05,37)、工坊(-28,.05,44)、宽景(17,.05,50)，眼高1.6米。软件Vulkan画面不能证明硬件性能或完整人工游玩。
- 当前冻结包9项自动回归最终通过：五项建筑/地形通行碰撞、三枪108样本瞄准、武器近墙遮挡、第三人称换弹规则、16角色单机冒烟。入口新增检测分别验证原有工字钢、新细柱和侧面空隙；首次脚本类型错误、第二次探针命中原钢构的失败日志及原始结果均保留，详见 `shelter-retry-note.md`。最终证据 `stable-verified/functional-results.json`、`shelter_frame-final.log`；一次测试进程被终止后串行重跑，说明见 `test-resume-note.txt`，未将中断算通过。
- 18座山体、15077棵树与7320幼苗检查PASS，最大树根贴地误差0.000149；见 `background-scenery-audit.json`/日志。`final-verification.json`、`final-assembly.log` 核验构建哈希、冻结包、相机及8张原图，结果 `STAGE329_FINAL_VERIFICATION_PASS`；整体目标仍未完成。
- 本地预览：`./artifacts/realism329-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`（项目根目录图形桌面运行，保留相邻pck；README含操作）。保留所有未提交修改，未push、未发布。
- 下一步：继续改善宽景树冠/树种差异、近地裸土与草簇层次，并调整建筑粗梁与大墙面；再结合当前包第三人称形体、第一人称三枪腰射/ADS/换弹实机审阅安排人物和手部缺陷。人物视觉最近仍stage320，规则测试不能代替视觉审阅。联网NOT_RUN：现有认证测试入口访问凭据，本轮没有读取，仍需符合限制的验证路径；不得报告联网通过。整体 continue。

### Stage330（2026-09-17）：入口斜撑减重、墙边植被疏密和日照调整
- `world_visuals.gd` 去除门廊重叠短斜撑，缩细保留斜撑与连接板；调整四处墙边草簇位置，降低密度、高度和灌木体积，减弱门廊补光。`world.gd` 调整太阳方向与角直径。入口角部及侧墙地基更清楚，斜向投影更明确；宽景改善仍有限，粗梁柱、大墙面、重复树形、平坦裸地与山体折面仍明显，整体目标未完成。
- 冻结stage329/330四组同机位实机前后对照已审阅：`artifacts/realism330-validation/review.html`、`visual-review.md`；原图在 `before/` 和 `stable-environment/`。两份 `environment-camera-poses.json` 完全一致，记录位置、目标与yaw/pitch。入口(15.5,.05,39)、侧面(7.5,.05,37)、工棚(-28,.05,44)、宽景(17,.05,50)，眼高1.6米。软件Vulkan截图不代表硬件性能或完整人工游玩。
- 当前冻结包9项串行回归全部PASS：五项地形/建筑通行碰撞、三枪108样本瞄准、武器遮挡、第三人称换弹规则、16角色单机冒烟。入口双向通行、柱脚阻挡/侧绕、门洞净空与窗面碰撞通过。证据 `stable-verified/functional-results.json` 及逐项日志；`final-verification.json`、`final-assembly.log` 核验64项构建哈希、测试前后包、相机和8张原图，结果 `STAGE330_FINAL_VERIFICATION_PASS`。本轮未重复背景山体/树根专项测试。
- 本地预览：`./artifacts/realism330-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`（项目根目录图形桌面运行，保留相邻pck，操作见README）。保留已有未提交修改，未push、未发布。
- 下一步：优先做能改变正常宽景观感的邻棚粗梁柱、大墙面分段与裸地形体/草地边界，并增加近中景树冠差异；随后复验当前包第三人称形体和三枪腰射/ADS/换弹手部。人物视觉最近仍stage320，本轮规则通过不替代实机动作审阅。联网NOT_RUN：现有认证测试入口访问凭据，本轮未读取，仍需符合限制的测试路径。整体 continue。


### Stage331：西侧维修棚窗组、树群与路缘植被（环境阶段，整体未完成）
- `client/scripts/world_visuals.gd`：维修棚封闭后墙新增两组工业玻璃窗、分格框、窗台及雨罩，增加轻量局部补光；西侧九棵树调整位置/尺度与树种分布，同步树干碰撞；新增两片不规则路缘植被。
- 正常持枪机位前后对照及入口、侧面、维修棚和宽幅原图：`artifacts/realism331-validation/review.html`；`before/` 与 `stable-environment/` 内各四张 PNG 及 `environment-camera-poses.json`（位置、目标、yaw/pitch 完全一致）。实机审阅见 `visual-review.md`：后墙窗组改善明确，宽幅植被与光照提升有限；树冠成团、平坦地表、重复石块、远山折面及前臂偏长仍存在，不能判定整体画质达标。
- 冻结导出包验证通过：9 项自动化测试覆盖土坡、东库、西维修棚、服务通道、棚架双向通行/碰撞、瞄准、武器遮挡、第三人称换弹及单机烟雾测试（16 actors，reload/heal/damage/victory/raycast/cover/fire_interval/rig）。全部 exit=0，无检测到的脚本/着色器错误；64 项构建哈希及测试前后 PCK 哈希一致。见 `artifacts/realism331-validation/final-verification.json`、`final-assembly.log`、`stable-verified/functional-results.json`。
- 前两次截图包装进程异常退出143，保留审计和首次原图；最终独立采集正常 exit=0、PASS frames=4，完整记录见 `stable-capture-process-audit.json`。不得以异常采集的 PASS 标记代替退出验证。
- 当前本地可运行预览：`artifacts/realism331-preview/Linux/IronMeridian`（同目录 PCK；启动说明 `artifacts/realism331-preview/README.md`）。软件 Vulkan/llvmpipe 不代表硬件帧率或完整人工试玩。联网 NOT_RUN：现有认证测试需要读取凭据，本轮遵守限制未执行。第三人称画质仍为 stage320 历史审阅，未冒充本包截图。
- 下一步：继续环境优先，改善宽幅正常机位能辨识的路缘土壤/草地过渡、树冠层次和重复石块，复拍相同机位及入口并回归通行；之后补当前包第三人称与第一人称手部动作审阅，保留联网验证缺口。未推送、未发布，保留已有未提交修改。


### Stage332：入口碎石、路肩草簇与补光（环境增量，整体未完成）
- `client/scripts/world_visuals.gd`：降低排水带碎石尺度与高度，打散入口碎石分布，增加三片路肩草簇并调整密度/高度过渡，降低入口和棚内补光。未修改建筑几何；本轮改善主要在近地过渡，不能算整体环境达标。
- 实机四组同机位对照已逐图审阅：`artifacts/realism332-validation/review.html`、`visual-review.md`。左侧为 stage331 冻结包原图（来源及哈希见 `before-provenance.json`），右侧为 stage332；两侧 `environment-camera-poses.json` 的位置、目标、yaw/pitch、眼高和分辨率完全相同。包含入口近景、建筑侧面、维修棚和宽幅地形。大块石链感减轻，但平坦地表、重复树冠、粗梁和远山折面仍明显；光照改善较小。
- 当前冻结包9项回归全部 exit=0、PASS，未检测到脚本/着色器错误：五项地形和建筑通行碰撞、三枪108样本瞄准、武器遮挡、三枪两姿态第三人称换弹规则、16角色单机冒烟（reload/heal/damage/victory/raycast/cover/fire_interval/rig）。棚屋双向穿行、柱脚阻挡/侧绕、门洞净空和窗面碰撞通过。证据：`stable-verified/functional-results.json` 及逐项日志。
- `artifacts/realism332-validation/final-assembly.log` 为 `STAGE332_FINAL_VERIFICATION_PASS`；`final-verification.json` 确认64项构建文件哈希、测试前后包一致、同机位和8张原图。实机截图采集正常 exit=0、PASS frames=4，见 `stable-capture-process-audit.json`。
- 本地预览：`./artifacts/realism332-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，需 Linux 图形桌面及相邻 PCK，操作见该目录 README。软件 Vulkan/llvmpipe 不证明硬件帧率或完整人工试玩。联网 NOT_RUN：现有认证测试路径需要凭据，本轮未读取。当前包第三人称及三枪腰射/ADS/换弹手部视觉审阅仍待补充，截图中前臂偏长仍存在。
- 下一步：优先改正常宽景可辨识的树冠层次、地形形体或建筑粗梁结构，避免继续仅调碎石；复拍同机位和入口并回归通行，随后补人物/手部实机审阅及符合限制的联网验证。整体 continue；保留已有未提交修改，未推送、未发布。


### Stage333 — 货运棚薄板采光带与路肩草簇（2026-09-17）
- 修改 `world_visuals.gd`：东侧货运棚薄板分段、两条半透明采光带、收窄檐边/梁翼缘；路肩草增加聚落噪声并降低高度。保留支柱及主梁碰撞，全局光照未改。
- 实机审阅 `artifacts/realism333-validation/review.html`：四机位与332位置/朝向完全一致，包含入口近景及宽幅地形。正常机位可见右侧棚边减薄；草丛改善有限，整体光照无明显提升；维修棚画面基本一致。重复树线、平坦混凝土、棱角远山及手臂/枪体质感仍明显，整体目标未完成。
- `final-verification.json` 全项通过：65构建哈希一致、9项测试PASS（坡地/库房/维修棚/服务路/入口碰撞通行、瞄准、遮挡、换弹、单机smoke），PCK测试前后一致；两批截图正常退出、8张原图1280×800。入口双向、柱脚阻挡侧绕、门洞净空与窗面碰撞有覆盖；库房路线不等于货运棚下专项通行。
- 首轮截图退出143且无PASS，原始证据保留于 `interrupted-environment/`，后续分批重拍成功；未把中断当成功。联网本轮NOT_RUN（既有路径需认证，未读取凭据），当前包人物和三枪/手臂动作画质仍待专门审阅。
- 本地可运行预览：`artifacts/realism333-preview/Linux/IronMeridian`（同目录PCK；运行命令见README.md）。截图为llvmpipe软件Vulkan，不代表硬件帧率。未推送或发布。
- 下一步：扩大地表材质层次、树木分布及建筑明暗改进，正常机位对照验证，不再将薄边/草高小改当整体提升；补货运棚下通行专项及当前包第三人称、第一人称手部审阅，保留联网主要功能待办。

### Stage334（2026-09-17）：装卸棚百叶边界、地坪参数与边缘灌木
- 修改 `client/scripts/world_visuals.gd`：装卸棚西后段新增9片倾斜百叶及2条支撑，具有实际碰撞和可穿射缝隙；地坪启用接缝/服务区磨损参数，棚外补3株灌木。仅局部几何改变遮挡，未调整全局光照，未将333采光带归为新增。
- 实机同机位333/334对照、入口近景及宽景：`artifacts/realism334-validation/review.html`；原图在 `before/`、`stable-environment/`、`depot-before/`、`depot-after/`，各目录 `environment-camera-poses.json` 保存位置/朝向/目标点。新增百叶在正常宽景右侧及棚内可辨识；草丛仍侵入硬化地面，灌木和材质改善有限，树冠重复、山石棱角、大面积均匀地表仍明显。详见 `visual-review.md`；整体目标未完成。
- 冻结预览包10项回归全部通过：新增 `tests/depot_canopy_traversal_review.gd` 验证两条路线双向真实胶囊通行、百叶阻挡与缝隙；另含土堤、东西建筑、服务路、维修棚、三枪108瞄准样本、武器遮挡、三枪双姿态第三人称弹匣跟随、16角色单机射击/换弹/治疗/伤害/胜利检查。证据 `stable-verified/functional-results.json` 及逐项日志。第三人称功能通过不代表人物/手部视觉审阅完成。
- `final-verification.json` / `final-assembly.log` PASS：66项构建文件哈希未变，测试包前后哈希一致，6组相机前后一致，12张原图尺寸有效。保留一次截图退出143日志，补跑成功并留审计。当前软件Vulkan截图不证明硬件帧率；联网 NOT_RUN，既有认证路径需要凭据，本轮未读取凭据。
- 本地预览：`artifacts/realism334-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`（图形桌面运行，保留同目录pck）；说明 `artifacts/realism334-preview/README.md`。未推送或发布，保留已有未提交修改。
- 下一阶段：优先按植被实际覆盖范围排除装卸硬化地坪内草丛（不仅按植株原点），并扩大正常宽景可见的地表、树冠和地形形体改善，继续同机位复拍/入口通行回归；随后补当前包第三人称人物、三枪第一人称手部腰射/ADS/换弹审阅及具备条件后的联网主要功能验证。不得以本轮局部改善宣称整体完成。

### Stage335（2026-09-17）：装卸地坪植被侵入修复与混凝土层次
- `world_visuals.gd` 按实际网格世界 AABB 排除地坪内草丛/灌木，处理原点在外但偏移旋转网格伸入的问题，本场景移除153实例；外围植被保留。`warehouse_concrete.gdshader` 新增装卸区独立边缘泥沙、积尘和拖痕；两盏工作灯开启阴影并调整能量/范围。沿用334建筑几何，未将其计为新增。
- 实机对照 `artifacts/realism335-validation/review.html`：装卸棚通路、连续混凝土及黄色边线明显恢复，灯光变化轻微；仓库入口近景保持通透。维修棚、西侧工作间和宽幅地形亦完成截图与审阅，宽景基本未变，重复树冠、折角远山、单调土色及前臂比例仍突出，整体目标未完成。详见 `visual-review.md`。
- 六组同机位前后原图及各目录 `environment-camera-poses.json` 保留相机位置/朝向/目标，包含入口和宽景；`final-verification.json` 全项通过：66构建文件哈希未变、包测试前后一致、12原图1280×800、机位匹配。
- 10项回归PASS，日志见 `stable-verified/functional-results.json` 及逐项日志：新增偏移旋转植被判定和区域外保留检查；装卸棚、东西建筑、维修棚、服务路及土堤通行碰撞；三枪108瞄准样本、遇障规则、三枪双姿态换弹、16角色单机射击/换弹/治疗/伤害/胜利冒烟测试。人物/手部功能测试不代替视觉审阅。
- 当前可运行预览：`artifacts/realism335-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，图形桌面运行并保留相邻pck，见预览README.md。截图为llvmpipe软件Vulkan，不代表硬件帧率。联网本轮NOT_RUN：既有认证测试路径需要凭据，未读取凭据，未声称发生认证失败；未推送或发布。
- 下一步：把改进扩展到正常宽景明显可见的树冠/植被分布和地形、土色层次，避免继续只做棚内小改；继续同机位与入口碰撞通行验证，再补当前包第三人称人物及三枪第一人称手部腰射/ADS/换弹实机审阅，保留联网主要功能验证待办。


### Stage336 — 建筑周边成熟树冠与林下层次（2026-09-17）
- 环境优先：调整维修棚周边及西侧林带共七棵桦树高度，扩大阔叶树冠横向尺度，增加四处灌木及受道路/地坪遮罩限制的林下落叶土色。建筑结构和主光照沿用 Stage335，不计为本轮新增。
- 实机审阅：入口、棚侧、西侧维修区、宽景共四个完全相同机位，保留八张原图、四组成对对照及完整位置/朝向。棚侧高于屋顶的树冠、维修区开口背景及宽景林带变化可辨；林下土色中远景贡献有限。证据：`artifacts/realism336-validation/review.html`、`visual-review.md`、`stable-environment/environment-camera-poses.json`。
- 冻结导出包验证：六组建筑/地形/服务通道碰撞与通行、三武器108组瞄准采样、武器遮挡、第三人称换弹规则、单机 smoke 共10项全部通过；截图进程无脚本/着色器错误。66个文件哈希、包前后哈希、机位及八张原图尺寸最终校验通过，见 `artifacts/realism336-validation/final-verification.json`、`final-assembly.log`、`stable-verified/functional-results.json`。首次着色器 litter 重名失败已修复重导出，原失败证据保留 `failed-first-shader-run/`，不计为通过。
- 本地预览：`artifacts/realism336-preview/Linux/IronMeridian`（相邻 .pck 必须保留）；启动命令和说明见同级预览目录 `README.md`。本机 llvmpipe 截图不能代表硬件帧率。
- 总体仍 continue：联网 NOT_RUN，现有路径需要 SERVER_SECRET 和内部构建校验，本轮未读取认证或绕过校验；第三人称换弹规则不代表人物画质已验收。下一阶段针对宽景前景土边/碎石或山体棱角做明显改进，继续处理树冠重复、棚内暗部和金属质感，再补第三人称人物与第一人称手部动态实机审阅及联网验证。未推送或发布，保留既有未提交修改。


### Stage337 — 维修棚地表碎石尺度与土色校正（2026-09-17）
- 调整 service_ground 泥土/石粒色彩，缩小程序碎石纹理与实体碎石并降低浮凸，略提高棚内补光。建筑几何、树木和草丛分布沿用336，本轮不计为建筑或植被新增改善。
- 实机审阅四个相同机位：入口、棚侧、西侧维修区、宽幅地形；前景大块碎石感减轻，土色略中性化。棚内补光差异很小，维修区基本不变；橙黄色裸土边带、大片空地、重复构件/树冠与棱角山体仍明显。本轮只是地表阶段性改进，不能视为环境或整体写实目标完成。
- 对照、原图和位置/朝向：`artifacts/realism337-validation/review.html`、`visual-review.md`、`before/`、`stable-environment/environment-camera-poses.json`。336基线来源和哈希见 `before-provenance.json`；四机位八张1280×800原图均保留，未后期调色。
- 冻结包10项验证全部PASS：六组建筑/土堤/服务通道碰撞和单机通行，三枪108组瞄准采样、武器遮挡、三枪双姿态换弹规则、16角色单机流程。`stable-verified/functional-results.json` 保存逐项结果和原始日志；`final-verification.json`、`final-assembly.log` 确认66构建文件哈希未变、测试前后包一致、截图进程通过、机位完全一致。
- 本地预览：`artifacts/realism337-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，保留相邻 .pck，在图形桌面运行；说明见 `artifacts/realism337-preview/README.md`。llvmpipe实机截图不能作为硬件帧率结论。
- 总体 continue。联网 NOT_RUN：既有认证测试路径需要凭据，本轮未读取认证或绕过校验。第三人称人物、第一人称手部及动态动画画质尚未验收；功能规则通过不能代替视觉审阅。未推送或发布，保留既有未提交修改。
- 下一步：追查正常宽景橙黄裸土边带的实际材质层，结合建筑大面积墙面/地坪材质和自然植被覆盖做明显环境改进，避免继续只做小尺度参数调整；保留同机位、入口碰撞通行验证，随后补人物与三枪手部腰射/ADS/换弹实机审阅及联网主要功能验证。


### Stage338 — 维修棚碎石肩色偏与弯道灌草（2026-09-17）
- 修改 `service_access.gdshader`，降低碎石肩饱和度、校正橙黄边带为灰褐色并扩大不规则过渡；`world_visuals.gd` 在服务弯道外侧补4处低灌木及林下草，保留通道净宽与植被清理逻辑。建筑几何和主光照未改，不能计为建筑/光照阶段完成。
- 实机同机位前后对照、入口近景和宽景见 `artifacts/realism338-validation/review.html`；原图在 `before/`、`stable-environment/`，相机位置/朝向见 `stable-environment/environment-camera-poses.json`。宽景橙黄边带明显减弱；入口与车间变化很小，灌草贡献有限。重复棚架/树冠、空旷道路、棱角远山及第一人称前臂形体仍突出，详见 `visual-review.md`，整体目标未完成。
- 冻结包10项验证全部PASS：六组建筑/土堤/服务通道碰撞通行、三枪108组瞄准采样、武器遮挡、三枪双姿态换弹规则、16角色单机流程。证据 `stable-verified/functional-results.json` 及逐项日志。`final-verification.json` / `final-assembly.log` PASS：66个构建文件哈希未变、测试前后包一致、两次截图进程通过、四组机位完全一致、八张1280×800原图有效。
- 本地预览：`artifacts/realism338-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，图形桌面运行，保留相邻pck；启动说明见预览目录 `README.md`。llvmpipe截图不能代表硬件帧率。联网NOT_RUN：既有认证测试路径需要凭据，本轮未读取凭据或绕过验证，也未声称发生认证失败。人物/手部动态画质尚未验收。未推送或发布，保留已有未提交修改。
- 下一步：实施正常宽景明确可见的建筑大平面/重复轮廓和光照层次改进，结合树冠分布或山体形体调整，避免继续只做土边/草高微调；继续同机位复拍、入口通行验证，随后补第三人称人物与三枪手部腰射/ADS/换弹实机审阅及具备条件后的联网主要功能验证。状态continue。


### Stage339 — 维修棚弧形采光带与入口日照（2026-09-17）
- `world_visuals.gd` 将维修棚两条弧形金属屋面替换为采光板并添加实体收边，侧墙外补两处灌木；新增 `shelter_rooflight.gdshader` 表现灰绿玻璃钢筋纹与污迹。采光板关闭阴影投射、背面低强度发光，属于近似透光，直射光偏清晰；未实现物理散射，主太阳和曝光未变。保留平滑拱顶与入口原有碰撞。
- 同机位实机前后对照、入口近景、侧面、宽幅地形及车间见 `artifacts/realism339-validation/review.html`；原图在 `before/` 与 `stable-environment/`，位置和朝向见 `stable-environment/environment-camera-poses.json`，前图来源与哈希见 `before-provenance.json`。侧面两条浅色弧形带明显可辨，入口内矮墙和门槛日照略改善；宽景和车间基本未变，不能计为整体环境改善完成。细节见 `visual-review.md`。
- 冻结包10项测试全部PASS：六组建筑/土堤/服务通道实际胶囊碰撞通行、三枪108组瞄准采样、武器遮挡、三枪双姿态换弹规则、16角色单机流程。维修棚两条路线双向进出、门柱阻挡与绕行、门洞和棚顶碰撞通过。证据 `stable-verified/functional-results.json` 及逐项日志；`final-verification.json` / `final-assembly.log` PASS：67构建文件哈希未变、测试前后包一致、两次截图进程通过、四组机位一致、八张1280×800原图有效。
- 本地可运行预览：`artifacts/realism339-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，在图形桌面运行并保留相邻pck；说明见预览目录 `README.md`。软件Vulkan截图不能代表硬件帧率。联网NOT_RUN：既有认证测试路径需要凭据，本轮未读取凭据、绕过验证或声称发生认证故障。人物/第一人称手部动态画质尚未验收。未推送或发布，保留全部既有未提交修改。
- 总体continue。下一阶段应实施正常宽景明显可见的树群分布、远山轮廓及建筑/场地大面积层次改进，避免再次仅做局部采光带或灌木微调；山体形体调整须同步核验地形高度与碰撞。继续同机位和建筑入口通行验证，随后补第三人称人物与三枪手部腰射/ADS/换弹实机审阅，以及具备条件后的联网主要功能验证。空旷道路、重复树冠/棚架、棱角远山和前臂形体仍是明确未解决问题。


### Stage340 — 道路旁针阔混交林与后院通行（2026-09-17）
- `world_visuals.gd` 将维修棚后方六株树扩为十二株高低错落的针阔混交树，增加林下草并同步树干实体碰撞。正常宽景可见高于棚顶的针叶树轮廓，侧面背景层次更清晰；本轮没有修改建筑、光照或远山，不视为整体环境目标完成。
- 实机同机位前后对照、建筑入口与宽幅地形见 `artifacts/realism340-validation/review.html`，原图在 `before/` 与 `stable-environment/`，相机位置和朝向见 `stable-environment/environment-camera-poses.json`，来源哈希见 `before-provenance.json`。入口保持畅通，车间画面仅作回归检查。空旷道路、重复树冠/建筑板材、硬阴影、棱角远山及人物手臂问题仍未解决，详见 `visual-review.md`。
- 冻结预览包10项功能测试全部PASS：六组建筑/土堤/服务通道碰撞通行、三枪108组瞄准采样、武器遮挡、三枪双姿态换弹规则与单机流程。服务通道新增路线首次四例失败源于测试直穿既有围栏；保留 `initial-failed-lane/` 原脚本、失败日志和结果，修订为穿过真实开口后72例全部通过，未改游戏围栏。修订脚本由冻结包外部加载，执行哈希见 `revised-lane/result.json`。
- `stable-verified/functional-results.json`、`final-verification.json` 与 `final-assembly.log` 可复核全部通过；67文件核验明确记录唯一外部测试脚本修订，原构建清单保留，游戏包前后哈希一致。两次截图进程通过、四组机位一致、八张1280×800原图有效；固定机位截图不替代动态动画验收。
- 本地预览：`artifacts/realism340-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，图形桌面运行，保留相邻pck，说明见预览 `README.md`。llvmpipe截图不代表硬件帧率。联网NOT_RUN：既有认证测试路径需要凭据，本轮未读取凭据或声称认证失败；人物及第一人称手部动态画质尚未验收。未推送或发布，保留已有未提交修改。
- 状态continue。下一阶段优先实施正常机位明显可见的建筑外立面、场地大面积材质与光照层次改进，结合远山形体处理，避免只添加少量植被；继续同机位复拍及入口碰撞验证，随后补第三人称人物和三枪手部腰射/ADS/换弹动态实机审阅，以及具备条件后的联网主要功能验证。

### Stage341 — 装卸棚百叶结构、墙脚植被与环境补光（2026-09-17）
- `world_visuals.gd` 将厚横板挡风墙改为两跨倾斜薄百叶，增加折边、立柱和混凝土基座；新建 `depot_louver.gdshader` 表现雨痕及粉化，墙脚增加草丛并沿用硬地清理。Forward+ 环境光与 SSIL 小幅提高。近景能辨识叶片间隙、薄边和支撑，宽景结构有所改善；阳光下百叶仍偏白，补光变化有限，不视为整体画质目标完成。
- 六组同机位实机前后对照含建筑入口、装卸棚近景和宽幅地形，见 `artifacts/realism341-validation/review.html`；原图在 `before/`、`stable-environment/`、`depot-340/`、`depot-341/`，各截图目录的 `environment-camera-poses.json` 记录位置、目标与朝向。近景主通道保持清晰。重复树群、粗枝灌木、空旷硬地、棱角远山及人物手臂仍需改进，详见 `visual-review.md`。截图采用软件 Vulkan 固定机位，不能代替动态动画或硬件性能验收。
- 冻结包十项测试全部 PASS：六组环境胶囊碰撞与双向通行、三枪108组瞄准采样、武器遮挡、三枪双姿态换弹规则、16角色单机开火/换弹/治疗/伤害/胜利流程。装卸棚新增射线验证叶片阻挡、真实间隙透射与中柱阻挡。证据见 `stable-verified/functional-results.json` 和逐项日志；`final-verification.json` / `final-assembly.log` 确认68构建文件哈希未变、测试前后包一致、截图进程通过和前后机位一致。
- 本地预览：`artifacts/realism341-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，图形桌面运行并保留相邻 pck，说明见该预览目录 `README.md`。联网 NOT_RUN：既有认证测试路径需要凭据，本轮未读取凭据或声称认证失败。人物和第一人称手部动态画质仍未验收。未推送或发布，保留既有未提交修改。
- 状态 continue。下一阶段扩大至场地大面积地表与建筑外立面层次，处理排列感树群、粗枝灌木和远山轮廓，避免继续只做单个棚体细节；形体变化同步验证碰撞并同机位复拍。随后补第三人称人物及三枪手部腰射/ADS/换弹实机审阅，以及具备认证条件后的联网主要功能验证。

### Stage342 — 远山轮廓与山脚植被过渡（2026-09-17）
- `world_visuals.gd` 降低山脊高频尖峰与侵蚀起伏，扩大山肩并调整林带分布；`terrain_slopes.gdshader` 减弱碎岩暴露、增加低坡植被过渡。正常宽景可辨识山脊更连贯、山脚林带更连续；右峰仍过圆，近处空旷硬地、重复树冠与建筑材质问题尚在。本轮未改建筑或光照，不将远景改善当作整体目标完成。
- 四组同机位实机前后对照覆盖建筑入口、侧面、车间通道及宽幅地形，见 `artifacts/realism342-validation/review.html`；原图在 `before/` 与 `stable-environment/`，位置、目标和朝向见 `stable-environment/environment-camera-poses.json`，画质判断见 `visual-review.md`。`background-scenery-result.json` 记录18组山体、21503棵树和10623株幼树的布置检查通过，最大根部贴地误差约0.000124；数量不代表画质或性能合格。
- 冻结预览十项功能测试全部 PASS：六组环境碰撞与通行、三枪108组瞄准采样、武器遮挡、三枪双姿态换弹规则、16角色单机流程。证据见 `stable-verified/functional-results.json` 与逐项日志；`final-verification.json` / `final-assembly.log` 确认68构建文件哈希未变、测试前后包一致、四组相机一致及八张原图有效。规则测试不替代人物和手部动态画质审阅。
- 本地预览：`artifacts/realism342-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，图形桌面运行并保留相邻 pck，说明见预览目录 `README.md`。截图使用软件 Vulkan，不能代表硬件帧率。联网 NOT_RUN：既有认证测试路径需要凭据，本轮未读取凭据或声称认证失败。未推送或发布，保留已有未提交修改。
- 状态 continue。下一阶段优先近处大面积地表、建筑外立面和光照层次，减少硬地空旷感及材质重复，继续同机位对照与入口通行验证；随后补第三人称人物和三枪手部腰射/ADS/换弹动态实机审阅，以及具备认证条件后的联网主要功能验证。

### Stage343 — 维修区进场地坪与植被过渡（2026-09-17）
- 调整 `service_access.gdshader` 的混凝土板块色差与接缝，新增外侧磨损黄色进场标线；`world_visuals.gd` 将维修转弯区四处灌丛改为更宽、更低的草丛；`depot_louver.gdshader` 降低绿色涂层基色。入口及宽景可辨识地坪网格减弱、草丛更连贯，但百叶直射受光仍偏白。未改建筑形体或光照参数；远山圆滑、树冠重复、梁柱规整及长直袖管仍未解决，不将局部改善视为整体完成。
- 四组正常第一人称同机位前后对照（入口、建筑侧面、工坊、宽幅地形）：`artifacts/realism343-validation/review.html`；原图在 `before/`、`stable-environment/`，位置和朝向见 `stable-environment/environment-camera-poses.json`，逐图局限见 `visual-review.md`。
- 冻结包重新运行十项功能测试全部退出0并PASS：六组环境碰撞与通行、三枪108个瞄准样本、武器遮挡、三枪双姿态换弹规则、16角色单机流程。服务道路72条站立/蹲姿/机器人路线全部通过，无卡住时间；入口双向通行及窗墙碰撞通过。见 `stable-verified/functional-results.json` 和逐项日志。`final-verification.json` / `final-assembly.log` 确认68构建文件哈希不变、包测试前后一致、四组相机一致及八张原图有效。功能规则不替代人物动作画质验收。
- 当前本地预览：`artifacts/realism343-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，图形桌面运行并保留相邻pck；说明见该目录README。联网NOT_RUN：既有认证测试路径需要凭据，未读取凭据，也未声称认证失败。未推送或发布，保留其他未提交修改。
- 归档纠错：本轮起初误用342编号，覆盖旧342预览包及部分元数据，旧包未恢复；当前预览与新测试以343为准。旧342四张截图已按历史哈希核验并恢复。详见 `archive-provenance.md`、`before-provenance.json` 和 `capture-package-provenance.json`，不得将旧342测试视为覆盖后包的验证。
- 状态continue。下一完整阶段转向第三人称人物与三枪第一人称手部动态实机审阅：3米/10米正侧面站立、蹲姿、移动、换弹，以及腰射/ADS/换弹关键帧；优先修复蹲姿肢体挤压、护具/靴头轮廓和长直袖管的资产或姿态根因，重建后同机位复核。实施入口与证据要求见 `artifacts/realism343-validation/next-character-stage.md`。保留建筑、地形和光照剩余缺陷及联网主流程验证，不再把完整轮次限定为地坪或单个枪械零件微调。

### Stage344 — 人物小腿与靴型修正及四姿态实机对照（2026-09-17）
- 按343最新检查点转入人物：调整 `tools/build_operator.py` 小腿截面与靴面环形轮廓，重建 Blender/GLB；骨长、动画和碰撞体不变。3米处裤脚收束和靴头过渡略有改善，10米收益很小；头面、服装、护膝仍简化，蹲姿与换弹手臂仍拥挤，整体写实目标未完成。
- 站立、蹲姿、跑动、换弹各3米/10米正侧面共16组同机位前后截图：`artifacts/realism344-validation/review.html`。实际查看近景各姿态及10米站立，判断见 `visual-review.md`；相机位置、朝向和姿态见 `before/camera.json`、`after/camera.json`。截图数量不代表画质验收。
- 当前冻结包五项功能测试退出0并PASS：建筑入口通行与窗墙碰撞、三枪108个瞄准样本、武器遮挡、三枪双姿态换弹规则、16角色单机流程。动画规则退出0；脚底接触847采样通过，最小间隙-0.001262m、最大支撑间隙0.007317m。证据见 `stable-verified/functional-results.json`、`animation-rules.log`、`sole-cycle.log`。`final-verification.json` 确认68构建文件哈希未变、测试前后包一致、16组相机一致、采集进程正常退出。
- 本地预览：`artifacts/realism344-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，图形桌面运行并保留相邻pck。首轮图形导入Mesa错误留存 `import-gl-driver-error.log`，随后无头导入导出及独立包测试成功。软件渲染不能代表硬件帧率；联网及三枪第一人称动作截图本轮NOT_RUN，不计通过。未推送、发布或读取凭据，保留既有未提交修改。
- 状态continue。下一阶段完成三枪腰射/ADS/开火/换弹关键帧与完整动作记录，结合人物蹲姿挤压、头面及护具形体做可辨识修正；保留环境建筑、重复树形、远山与光照剩余缺陷，环境再改时复用343机位及入口通行测试。联网主流程仍待既有认证条件具备后验证，详细入口见 `artifacts/realism344-validation/next-stage.md`。


### Stage345 — 维修棚折边檐口、路肩树丛与局部树影（2026-09-17）
- 按当前环境优先级修改 `client/scripts/world_visuals.gd`：维修棚增加氧化红折边檐板、压筋与收边，三处路肩加入大小错落的桦树和渐疏草灌。正常入口和宽景机位可辨识檐口与树冠层次，局部树影随植被改变；没有修改全局光照参数。树干近景仍有棱角、树列及远山重复、地面斑驳，工坊视角收益很小，整体写实目标未完成。
- 四组正常第一人称同机位前后实机对照（入口近景、棚侧面、工坊、宽幅地形）已逐组审阅：`artifacts/realism345-validation/review.html`；原图在 `before/`、`stable-environment/`，两者 `environment-camera-poses.json` 保存一致的位置与朝向；判断与局限见 `visual-review.md`。
- 初版树位挡住既有仓库路线，已移至路肩并修复树节点名称重复；失败证据保留于 `rejected-layout/`。最终包十项功能回归全部退出0并PASS，覆盖建筑双向入口/窗墙/门框净空、主要通道（服务道路72条路线）、三枪108个瞄准样本、武器遮挡、第三人称换弹规则及16角色单机流程。新增 `tests/stage345_grove_traversal_review.gd` 验证三棵树正面阻挡与侧向绕行共6条路线通过。证据：`stable-verified/functional-results.json`、逐项日志、`grove-traversal.log`。
- `artifacts/realism345-validation/final-verification.json` 核验68个构建文件无哈希差异、测试前后包一致、4组机位一致、8张原图有效及采集进程成功。当前本地预览：`artifacts/realism345-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`（图形桌面运行，保留相邻pck），使用说明见预览目录README。联网NOT_RUN：既有认证路径需要凭据，本轮未尝试或读取凭据；软件渲染不能代表硬件帧率。未推送或发布，保留既有未提交修改。
- 状态continue。下一阶段结合三枪腰射/ADS/开火/换弹与第三人称3米/10米站立、蹲姿、移动、换弹的实机动态审阅，修复长直袖管、肢体挤压等完整形体问题；同时保留树皮与重复树形、远山、地面材质及照明剩余缺陷。联网主流程仍待认证条件具备后验证。具体入口见 `artifacts/realism345-validation/next-stage.md`，不将本轮局部环境收益视作整体完成。


### Stage346 — 路肩白桦连续树干与树皮实机复核（2026-09-17）
- 修改 `tools/build_verge_birch.py` 并重建 Blender/GLB：增加弯曲树干采样，使用连续锥度、平滑法线和内嵌树皮纹理，移除方块树疤。棚侧及工坊正常机位近树的棱柱与白色贴片感减轻；删除树疤也改变后续随机枝叶分布。保留345建筑、路肩植物与树影，本轮未调整建筑、地表或全局光照，不计作全面环境升级。
- 四组同机位前后实机对照已审阅，含建筑入口近景、侧门、工坊及宽幅地形：`artifacts/realism346-validation/review.html`；原图和位置/朝向分别在 `before/`、`stable-environment/`，判断见 `visual-review.md`。远景收益有限，重复树冠、空旷道路、平面金属与混凝土、生硬草土边界、圆滑远山和长直袖管仍明显。
- 最终12项功能回归通过，覆盖建筑入口/门框/窗墙碰撞、主要道路、三枪108个瞄准样本、武器遮挡、三枪双姿态换弹以及16角色单机流程；新增植被布局6条阻挡/绕行路线通过。旧西侧树干测试坐标过时，改为读取当前场景全部11棵树位置后复测通过；过时坐标及首次漏计2棵树的失败日志、原结果均保留。证据：`stable-verified/functional-results.json`、`western-retest-final.log`、`western-retest-final/western-grove-collision.json`。
- `artifacts/realism346-validation/final-verification.json` 核验68个构建文件无哈希差异、测试前后包一致、4组机位一致、8张原图有效及两次采集正常退出。首轮导入texture空引用错误保留于 `first-import-null-texture.log`，重复缓存导入/导出成功。当前本地预览：`artifacts/realism346-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`（需图形桌面，保留同目录pck），说明见预览目录README。
- 状态continue。联网NOT_RUN：既有认证路径需要凭据，本轮未读取或尝试认证；llvmpipe截图不能代表硬件帧率。未推送或发布，保留既有未提交修改。下一阶段结合三枪腰射/ADS/开火/换弹及第三人称站立、蹲姿、移动、换弹实机动态审阅，处理完整手臂与人物形体；环境重复树形、地面、建筑大面和光照问题继续保留，见 `artifacts/realism346-validation/next-stage.md`。本轮局部树干收益不代表整体目标完成。


### Stage347 — 棚屋砖基座、入口补光与路肩植被调整（2026-09-17）
- 修改 `client/shaders/workshop_masonry.gdshader`、`client/scripts/world_visuals.gd`：棚屋下墙与柱脚露出砖砌基座，墙顶改为分块压顶；调整入口反射补光的颜色与强度，拓宽部分路肩植被区域并打散边缘。正常侧面机位的砖墙层次是主要可见收益；入口有所改善，但工坊基本不变、宽幅地形植被差异很有限，不将实例增加计作显著画质提升。
- 四组同机位前后实机对照已审阅，含建筑入口近景、侧面、工坊与宽幅地形：`artifacts/realism347-validation/review.html`。原图和相机位置/朝向见 `before/`、`stable-environment/environment-camera-poses.json`，具体判断见 `visual-review.md`。重复树形、空旷道路、草片边缘、圆滑远山、平面材质与长直袖管仍需改进。
- 最终导出包12项功能回归全部通过：建筑双向入口通行、砖柱脚阻挡及绕行、墙窗/门框净空、主要道路与植被碰撞、三枪108个瞄准样本、武器遮挡、三枪双姿态换弹规则及16角色离线烟测。证据：`artifacts/realism347-validation/stable-verified/functional-results.json` 及同目录逐项日志。换弹规则测试不等于人物视觉审阅。
- `artifacts/realism347-validation/final-verification.json` 核验68个构建文件无哈希差异、测试前后包一致、4组机位一致、8张原图有效、两次采集成功。当前本地预览：`artifacts/realism347-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`；需图形桌面并保留相邻pck，说明见预览目录README。截图使用llvmpipe，不能代表硬件帧率。
- 状态continue。联网NOT_RUN：既有服务/认证前提本轮未解决，未读取凭据或伪造联网结果。未推送或发布，保留所有既有未提交修改。下一阶段结合第三人称3米/10米站立、蹲姿、移动、换弹和三枪第一人称腰射/ADS/开火/换弹实机审阅，处理完整人物与手臂形体；同时保留环境重复植被、空旷道路、地形材质与照明缺陷，详见 `artifacts/realism347-validation/next-stage.md`。本轮环境局部收益不代表整体目标完成。


### Stage348 — 人物袖管形体修正与动作/通行回归（2026-09-17）
- 接续stage347实际检查点，修改 `tools/build_operator.py` 的上臂/前臂布料起伏，减少贯穿袖管的整圈鼓包，将压缩褶皱集中在肘部和袖口；重建 `art/operator.blend`、`client/assets/operator.glb`。保留既有未提交修改，本轮隔离差异见 `artifacts/realism348-validation/operator-change.diff`。
- 冻结347与348预览包完成3米/10米、正面/侧面、站立/蹲姿/跑步固定相位/换弹共16组同机位实机对照；位置、朝向及FOV完全一致。证据入口 `artifacts/realism348-validation/review.html`，原图及机位见 `operator-before/`、`operator-confirm/camera.json`。实际审阅结论见 `visual-review.md`：近景袖管更连续，但肩肘仍圆团，头部、手套与靴子简化；10米收益很小，不算整体人物画质达标。
- 最终包12项功能回归全部正常通过，覆盖建筑入口双向通行、柱脚绕行/墙窗碰撞、主要道路与植被、三枪108个瞄准样本、武器遮挡、三枪双姿态换弹及16角色单机烟测；另有蒙皮/蹲姿脚底/走跑/换弹/跳跃/死亡动画断言正常通过。证据 `stable-verified/functional-results.json`、逐项日志及 `animation/process.log`。断言通过不代表完整动作视觉通过。
- 完整三枪动作采集主动中止退出143，保留第一枪腰射和部分ADS截图（已审阅）；没有其余两枪/完整射击换弹的本轮视觉通过结论。首次人物新版采集退出143原因未确认，保留15张原图，随后完整重试正常退出0。退出状态见 `render-check-results.json`、`action-interruption.json`、`operator-process-audit.json`，不伪报部分采集通过。
- `artifacts/realism348-validation/final-verification.json` 核验68个构建文件无变化、测试前后包哈希一致、16组相机一致、32张对照原图有效。当前本地可运行预览 `artifacts/realism348-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，保留同目录pck，详见预览README；实际Vulkan Forward+截图使用llvmpipe，不代表硬件帧率。
- 状态continue。本轮环境未修改，重复树冠、空旷道路、圆滑远山和平面材质仍明显；联网、Android及真实GPU性能NOT_RUN，未读取凭据、推送或发布。下一阶段按 `artifacts/realism348-validation/next-stage.md` 优先落实正常机位可辨识的建筑/地表植被/入口照明组合改进，保存入口及宽幅地形同机位前后图与碰撞通行验证；之后分枪补齐动作采集，保留人物、第一人称手部及联网完整目标。


### Stage349 — 维修棚墙墩、路肩植被与入口补光（2026-09-17）
- 按当前环境优先级修改 `client/scripts/world_visuals.gd` 与 `client/shaders/service_ground.gdshader`：维修棚侧面新增8根下砖上抹灰墙墩及压顶，两肩新增5组共280株细草/灌丛；局部道路碎石/潮湿明暗与棚内外补光调整。保留全部既有未提交修改，未推送或发布。
- 冻结348包与349包完成入口、侧景、宽幅地形及邻区工坊4组同机位实机前后对照。入口 `artifacts/realism349-validation/review.html`；原图 `before/`、`stable-environment/`，位置、目标与yaw/pitch见各目录 `environment-camera-poses.json`。侧墙和肩部草带变化可辨识，补光收益轻微；宽景地面改善弱，规则墙墩和空旷平滑远景仍明显，不能据此宣称整体画质达标。详见 `visual-review.md`。
- 349最终包12项功能检查全部退出0且无错误，覆盖维修棚入口双向进出、柱脚绕行、墙窗/屋顶碰撞、道路及林地通行、三枪108个瞄准样本、武器近墙遮挡、三枪双姿态换弹与16角色离线烟测。日志及结果 `artifacts/realism349-validation/stable-verified/functional-results.json`；功能断言不代表完整动作视觉通过。
- `artifacts/realism349-validation/final-verification.json` 核验68个构建文件无变化、测试前后包哈希一致、4组相机一致和8张对照原图有效。首次基线采集退出143原因未确认，保留 `before-interruption.json` 与中断日志；完整重试正常退出0，不把部分采集报为通过。
- 当前本地可运行预览 `artifacts/realism349-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，保留同目录pck，详见预览README。截图使用Xvfb + Vulkan Forward+ llvmpipe，不代表真实GPU性能；联网认证前置问题本轮未解决，联网、Android及硬件性能NOT_RUN。人物与第一人称三枪完整动作仍待验收，stage348中断采集仍未补齐。
- 状态continue。下一阶段读 `artifacts/realism349-validation/next-stage.md`，继续环境优先：实际混凝土前坪板使用 `warehouse_concrete.gdshader`，本轮道路着色器不影响该板面。直接改善可见板面的尺度、接缝/排水污迹、土草过渡与墙墩比例，沿用349机位对照并复验入口碰撞；随后结合人物和第一人称手部实机审阅安排剩余缺陷。


### Stage350 — 维修棚窗带比例、混凝土分缝与草带层次（2026-09-17）
- 修改 `client/scripts/world_visuals.gd` 与 `client/shaders/warehouse_concrete.gdshader`：8处整高白墩改为低砖墩和细钢柱，直接调整可见前坪混凝土的板块明暗、接缝与积尘；6处草群各28增至42并扩大分布，入口和棚内局部补光降低。保留既有修改，未推送或发布。
- 完成入口、侧景、工坊及宽幅地形4组同机位实机对照并逐一审阅，见 `artifacts/realism350-validation/review.html`、`visual-review.md`。before/复用349真实原图，来源哈希见 before-provenance.json；350原图见 stable-environment/，位置、目标及yaw/pitch见 environment-camera-poses.json。窗带粗白块减少、入口分缝更清楚；宽景收益轻微，空旷道路、圆滑远丘、片状树叶与简化正面墙仍明显，整体目标未完成。
- 冻结350包12项功能测试全部退出0且无错误：林地/道路/建筑通行、维修棚真实胶囊双向进出和柱脚绕行、墙窗屋顶阻挡、三枪108个瞄准样本、近墙武器遮挡、三枪双姿态换弹和16角色离线烟测。结果及日志 `artifacts/realism350-validation/stable-verified/functional-results.json`；不能替代人物与手部动作视觉验收。
- `artifacts/realism350-validation/final-verification.json` 核验构建源码及包哈希一致、测试前后包不变、两批截图正常退出、4组相机完全相同及8张原图有效。本地预览 `artifacts/realism350-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，须保留同目录PCK，启动方法见预览README。截图使用软件Vulkan llvmpipe，不代表真实GPU性能。
- 状态continue。联网认证前置问题未解决，联网、Android、真实GPU性能NOT_RUN；人物和第一人称三枪完整动作仍待验收。下一阶段按 `artifacts/realism350-validation/next-stage.md` 优先改善宽景实际可见的道路肩部、草土过渡和地形层次，兼顾建筑正面比例，避免只在维修棚局部增加细节；保存同机位对照并复验碰撞，随后补齐人物、手部及三枪动作审阅。

### Stage351 — 路肩草带缺口、风化檐板与局部补光（2026-09-17）
- 修改 `client/scripts/world_visuals.gd`：五类地表植被应用确定性的疏密缺口，降低部分草高；新增 `client/shaders/porch_fascia.gdshader`，为维修棚檐板加入褪色、雨痕和下缘积污；前坪补光0.78→0.64、棚内补光1.25→1.45。未修改碰撞几何，保留所有既有修改，未推送或发布。
- 四组同机位实机对照与逐图审阅见 `artifacts/realism351-validation/review.html`、`visual-review.md`。基线复用350原图，来源及哈希见 `before/provenance.json`；本轮入口、侧景、工坊和宽幅地形原图及相机位置/yaw/pitch见 `stable-environment/`。宽景左侧连续草带出现可辨缺口，右侧疏密变化可见；入口檐板风化可辨，但偏粉、平面感仍在，补光收益轻微。裸露底面偏平偏绿，道路空旷、圆丘、片状树叶和工坊重复工具仍明显，整体目标未完成。
- 同一冻结包12项功能检查全部退出0且无错误：八项林地/坡地/道路/建筑碰撞通行检查（含维修棚双向进出、柱脚阻挡与绕行、墙窗和门洞射线）、三枪108个瞄准样本、近墙遮挡规则、三枪双姿态换弹规则及16角色单机烟测。结果和原始日志见 `artifacts/realism351-validation/stable-verified/functional-results.json`，功能断言不能替代人物与手部动作视觉验收。
- `artifacts/realism351-validation/final-verification.json` 确认构建源码及包哈希一致、测试前后包不变、两批截图退出0、四组前后相机记录完全一致与八张原图有效。本地可运行预览：`artifacts/realism351-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，保留同目录PCK，详见预览README。截图使用Forward+ / llvmpipe软件Vulkan，真实GPU性能、Android未验证；已有联网认证前置问题本轮未解决，联网NOT_RUN。
- 状态continue。下一阶段先读 `artifacts/realism351-validation/next-stage.md`：统一仍未受疏密约束的旧草层，让宽景缺口呈现可信泥土、沉积与浅排水变化；按实际画面处理偏粉檐板及工坊重复构件，并复验入口碰撞。保留第三人称肩部/头部/手套与第一人称三枪完整动作审阅、联网验证的剩余目标，不以截图数量或局部改善宣告完成。


### Stage352 — 旧草层疏密统一、沉积裸土与檐板残漆（2026-09-17）
- 修改 `client/scripts/world_visuals.gd`、`client/shaders/meadow_ground.gdshader`、`client/shaders/porch_fascia.gdshader`：三个旧草层统一生长遮罩，服务区五处加入褐色沉积与浅流纹理；粉褐檐板改为灰绿残漆/氧化混合，前坪与棚内补光降低。未改变碰撞几何，保留既有修改，未推送或发布。
- 四组同机位实机前后图与逐图审阅见 `artifacts/realism352-validation/review.html`、`visual-review.md`。before/复用351真实原图，来源哈希见 before/provenance.json；本轮入口近景、侧景、车间及宽幅地形图和位置/yaw/pitch见 stable-environment/。入口颜色和宽景局部裸土变化可辨，但锈蚀偏条带、道路空旷、远山光滑、叶片感和车间重复构件仍明显；这是局部收益，不是整体画质达标。
- 冻结352包12项功能检查全部退出0且无错误：八项环境通行/碰撞（含维修棚真实玩家胶囊双向进出、柱脚阻挡绕行、墙窗及门洞射线）、三枪108个瞄准样本、近墙遮挡、三枪双姿态换弹规则及16角色单机烟测。结果与原始日志见 `artifacts/realism352-validation/stable-verified/functional-results.json`，不能替代完整人物和手部动作视觉验收。
- `artifacts/realism352-validation/final-verification.json` 确认构建文件哈希一致、测试前后包不变、两批截图退出0、四组相机完全一致及八张原图可读。本地预览：`artifacts/realism352-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，保留相邻PCK，启动说明见预览README。截图使用Forward+ / llvmpipe软件Vulkan，真实GPU性能和Android未验证；既有联网认证前置问题未解决，联网NOT_RUN。
- 状态continue。下一阶段先读 `artifacts/realism352-validation/next-stage.md`，针对西侧车间墙窗/工作区重复与道路中景空疏，进行正常机位可辨识的结构和空间层次改进，不再仅调檐板或泥土参数；保存同机位对照并复验真实玩家通行。随后推进第三人称肩颈/手套及三枪完整持枪、ADS、射击、换弹实机审阅，保留联网和硬件验证目标。


### Stage353 — 西侧车间备件架、百叶与环境实机复验（2026-09-17）
- 修改 `client/scripts/world_visuals.gd`：远端重复工作台替换为四层备件架及开放料盒，后墙重复窗改为金属百叶，加入弱冷光，与近端暖灯区分；道路灌丛加入间断分布。`tests/west_workshop_traversal_review.gd` 新增真实玩家胶囊撞架及层板射线断言，均通过。保留所有既有修改，未推送或发布。
- 四组同机位对照、入口近景与宽幅地形截图见 `artifacts/realism353-validation/review.html`、`stable-environment/`，相机位置与朝向见该目录 `environment-camera-poses.json`。前图复用352实机原图，来源哈希见 `before/provenance.json`。逐图审阅见 `visual-review.md`：货架和百叶可辨、工位重复减少，但画面占比小；光照变化弱，宽景植被差异很弱，长道路空旷、平滑山坡、均匀地表及角状树冠仍明显，宽景视觉验收未通过，整体目标未完成。
- 冻结包12项检查全部退出0且无错误：八项环境通行/碰撞（含新增货架阻挡、维修棚双向进出与柱脚绕行）、三枪108组瞄准、近墙武器遮挡、三枪双姿态换弹规则、16角色单机烟测。原始日志与结果见 `artifacts/realism353-validation/stable-verified/functional-results.json`。功能规则测试不能替代人物与手部动作实机视觉审阅。
- `artifacts/realism353-validation/final-verification.json` 确认构建源码及包哈希一致、测试前后包不变、两批截图正常、四组前后相机一致。当前本地预览命令：`./artifacts/realism353-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，需保留相邻PCK；说明见预览README。截图为Forward+ / llvmpipe软件Vulkan，目标GPU性能未验证；既有认证前置条件未解决，联网NOT_RUN。
- 状态continue。下一阶段读 `artifacts/realism353-validation/next-stage.md`：优先改造正常宽景足够近的道路中景空间，用场地高差、排水边界、成簇错落植被和裸土分区打破均匀空白，避免再次只调密度或小构件。保存同机位对照并验证胶囊通行；继续保留第三人称人物、第一人称手部与三枪完整动作、联网及目标硬件验证目标。


### Stage354 — 道路护岸、碎石沟床与通行回归修复（2026-09-17）
- 修改 `client/scripts/world_visuals.gd`，新增 `client/shaders/drainage_stone.gdshader`：维修棚道路侧增加低石护岸、碎石沟床和分簇草灌。建筑及照明沿用353，本轮不算新增。正常侧景和宽景中地表高差边界可辨，但圆石三排排列像沙袋，空旷道路、平滑远山及角状树叶仍明显，整体画质未达标。
- 四组同机位对照、入口近景与宽幅原图见 `artifacts/realism354-validation/review.html`、`stable-environment/`；相机位置/目标/yaw/pitch见该目录 `environment-camera-poses.json`。前图复用353真实截图，来源哈希见 before-provenance.json；逐图判断见 review.md。
- 首版护岸封住旧 z=41 路肩横穿路线，导致五种通行组合失败；保留旧测试，在几何和植物中留出缺口，重建后六种组合全部通过。失败证据保存在 initial-regression/，修复对照见 regression-fix-verification.json。扩展道路测试90组双向路线与护岸胶囊阻挡/射线断言全部通过。
- 最终12项检查均退出0且无错误，覆盖八项环境通行/碰撞、三枪108个瞄准样本、近墙遮挡、三枪双姿态换弹和16角色单机烟测，见 stable-verified/functional-results.json。外置道路测试首跑有类型推断解析错误，显式bool修复后复验通过；原始构建快照未覆盖，external-test-revision.json单列修订哈希。final-verification.json因此完整快照匹配为false，但游戏源码及包匹配、其余文件匹配和外置修订校验均true，测试前后PCK未变；四组相机一致，两批截图正常。
- 本地预览：`./artifacts/realism354-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，保留相邻PCK，详见预览README。截图使用Forward+ / llvmpipe软件Vulkan，目标GPU性能未验证；既有联网认证前置条件未解决，联网NOT_RUN。未推送、发布或启动其他开发代理。
- 状态continue。下一阶段读 `artifacts/realism354-validation/next-stage.md`：改造护岸不规则断面、嵌土底部及砌缝，结合宽景改善路肩裸土与草丛过渡，保留入口和z=41横穿缺口并复验碰撞。继续处理建筑与光照整体层次，保留第三人称人物、第一人称手部及三枪完整动作实机审阅、联网和目标硬件验证目标。

### Stage355 — 护岸轮廓及路肩植被过渡（2026-09-17）

- world_visuals.gd 将圆鼓护岸石改为削角错缝石块，并拓宽草灌疏密过渡。实机侧景可辨变化，但石面仍平滑均一，宽景局部更显块状，整体提升有限；建筑和光照本轮未改，环境目标未达标。
- 四个相同正常机位前后图（入口、维修棚侧面、车间、宽幅地形）及审阅：artifacts/realism355-validation/review.html、review.md；相机位置/朝向：stable-environment/environment-camera-poses.json；前图来源：before-provenance.json。
- 冻结包 12 项测试全通过：8 项环境检查、108 个三枪瞄准样本、贴墙规则、三枪两姿态换弹、16 角色单机冒烟。服务道路 90 条移动路线与护岸胶囊/射线碰撞均通过。final-verification.json 证实源码/测试/包哈希一致及测试前后 PCK 未变；原始日志在 stable-verified/。
- 当前本地预览：artifacts/realism355-preview/Linux/IronMeridian（同目录 PCK，启动见预览 README.md）。截图使用 Forward+ / llvmpipe；联网认证前置条件未解决，联网及目标 GPU 性能 NOT_RUN，无外部发布。
- 状态 continue。下一阶段见 artifacts/realism355-validation/next-stage.md：优先宽景道路、远山、树冠及建筑入口光照，不再整轮只改石块；保留入口/旧缺口/南端通行与碰撞断言。随后继续第三人称人物、第一人称手臂及三枪实机审阅，保留完整功能与联网验收目标。


### Stage356 — 维修棚檐口、入口照明与树群层次（2026-09-17）

- world_visuals.gd 与 porch_fascia.gdshader 减薄维修棚檐板、将重复锈条改为拼缝/下缘局部腐蚀，调整两盏入口灯，并抬高三棵桦树及四棵针叶树。入口金属边缘和宽景树群轮廓可辨改善；室内仍暗，大片水泥地空旷、墙体平整、护岸石光滑和叶片平面感仍明显，整体目标未完成。
- 四个相同正常机位前后对照、入口近景及宽幅地形见 artifacts/realism356-validation/review.html、review.md 和 stable-environment/；相机位置/目标/yaw/pitch见 stable-environment/environment-camera-poses.json。前图复用355实机截图，来源哈希见 before-provenance.json；本轮独立修改见 stage356.patch。
- 冻结预览包12项检查全部通过：8项环境通行/碰撞、三枪108个瞄准样本、近墙遮挡、三枪两姿态换弹与16角色单机烟测。道路90条移动路线及护岸胶囊/射线记录均通过。final-verification.json 确认源码/测试/包哈希一致、测试前后PCK未变、相机一致及两批截图正常；原始日志见 stable-verified/functional-results.json 及相邻日志。
- 当前本地预览：./artifacts/realism356-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus，保留同目录PCK，详见预览README.md。截图为Forward+ / llvmpipe软件Vulkan；目标GPU性能未验证，既有联网认证前置条件未解决，联网NOT_RUN；无外部发布。
- 状态continue。下一阶段见 artifacts/realism356-validation/next-stage.md：优先宽景道路连续车辙、破损边缘及裸土植被过渡，结合车间墙体/屋顶接缝改善大平面，保持90条通行路线。随后继续第三人称人物、第一人称手部与三枪持枪/ADS/射击/换弹实机审阅，保留联网和目标硬件验收目标。

### stage357 — 环境局部改进、同机位审阅与冻结包验证（整体继续）
- 改动 `client/shaders/service_access.gdshader`、`client/scripts/world_visuals.gd`：加强维修道路轮迹/剥蚀，新增四组路肩低植被、车间泛水收边及两处天窗投光；保留既有未提交修改。
- 四组正常机位原色前后对照、入口近景和宽幅地形已实际审阅，见 `artifacts/realism357-validation/review.html`、`review.md`；精确位置/朝向见 `stable-environment/environment-camera-poses.json`，与356基线完全一致。改善小，大片平地、重复树冠、方块挡土石及偏暗车间仍明显，未达到整体环境显著提升要求。
- 冻结包12项功能验证全部通过：道路90条通行+1项挡土碰撞、建筑入口/棚架/林地/车间等通行，瞄准三枪108采样，武器遮挡，第三人称三枪两姿态换弹，单机16角色含治疗/伤害/胜利等冒烟。最终审计 `artifacts/realism357-validation/final-verification.json` 与 `stable-verified/functional-results.json`；源码/包哈希一致，两批实机截图成功。
- 本地可运行预览 `artifacts/realism357-preview/Linux/IronMeridian`（同目录PCK；运行参数 `--path /tmp --rendering-method forward_plus`）。截图用llvmpipe软件Vulkan，目标GPU性能未验；联网认证前置问题仅沿用此前检查点，本轮未复核/未运行联网验收，不能由单机通过推定联网通过。未推送或外部发布。
- 下一阶段：按 `artifacts/realism357-validation/next-stage.md` 优先改宽景中可辨识的地表起伏/路土衔接、树冠体积层次、建筑大平面，保持入口与道路通行；之后仍须第三人称人物、第一人称手臂/三枪外观及联网主要功能验收。状态 continue。

### stage358 — 路肩植被与排水石改进、光照覆盖问题定位（整体继续）
- 调整维修棚金属漆、四组路肩灌木/草丛、排水石不规则断面及三向岩石纹理。正常机位可辨识植被填充与石块变化，但建筑规整、大面积平地及树冠平面感仍明显；棚体漆色改善很小。world.gd 补光数值被 world_visuals.gd 的实际环境初始化覆盖，不能算作有效光照改善。
- 四组原色同机位前后对照、建筑入口近景与宽幅地形已实际审阅：artifacts/realism358-validation/review.html、review.md。前图复用357实机截图（before-provenance.json）；精确位置/目标/yaw/pitch见 stable-environment/environment-camera-poses.json，与基线完全一致。独立源码差异见 stage358.patch。
- 冻结包12项检查全部通过：8项环境通行/碰撞、三枪108个瞄准样本、近墙遮挡、第三人称三枪两姿态换弹与16角色单机冒烟。道路90条实际移动路线及1项护岸胶囊/射线碰撞均通过；建筑入口双向通行、棚柱阻挡/绕行通过。artifacts/realism358-validation/final-verification.json 确认源码/测试/包哈希一致、测试前后PCK未变及两批截图正常；原始结果/日志见 stable-verified/functional-results.json 与相邻日志。
- 当前本地预览：./artifacts/realism358-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus（保留相邻PCK，详见预览README.md）。截图为Forward+ / llvmpipe软件Vulkan，目标GPU性能未验；此前联网认证前置问题本阶段未复核，联网NOT_RUN。没有推送或外部发布，保留既有未提交修改。
- 状态continue。下一阶段见 artifacts/realism358-validation/next-stage.md：直接修改实际生效的环境光配置并复拍工坊；同时优先宽景地表起伏/路土衔接、树冠体积与建筑大平面，避免继续仅靠局部加草。随后仍须第三人称人物、第一人称手臂及三枪持枪/ADS/射击/换弹外观审阅、联网主要功能和目标硬件验证。

### stage359 — 工坊棚内材质与西侧草坡、冻结预览验证（整体继续）
- 工坊屋顶按朝向区分浅灰镀锌内侧和旧化外侧；新增两处带凹槽坡面，网格、碰撞和区域植被根部共用高度。实际环境光强度由0.30调整到0.44，但入口截图补光差异几乎不可见，不能计作光照问题已解决。保留所有既有未提交修改。
- 五组正常机位原色前后对照已实际审阅，包含入口近景、宽幅地形与额外工坊接近视角：artifacts/realism359-validation/review.html、review.md。棚顶内侧材质和接近视角的坡面轮廓明显变化；宽景收益不足，新坡仍像植被稀疏的孤立土包，树冠片状重复和建筑规整问题未解决。相机位置/目标/yaw/pitch见 stable-environment/environment-camera-poses.json 与 shoulder-after/environment-camera-poses.json；五组前后完全一致。
- 冻结包13项检查全部通过：新增坡面站立/蹲伏/机器人双向12条路线、既有建筑入口等通行碰撞、三枪108个瞄准样本、近墙遮挡、第三人称换弹和16角色单机冒烟。维修道路90条路线及1项挡土碰撞通过。artifacts/realism359-validation/final-verification.json 确认源码/包哈希一致、测试期间包未变和截图进程通过；逐项结果及日志见 stable-verified/functional-results.json。
- 本地可运行预览：./artifacts/realism359-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus（保留同目录PCK；详见预览README.md）。截图采用Forward+ / llvmpipe软件Vulkan；目标GPU性能未验，此前联网认证前置问题本轮未复核，联网NOT_RUN。没有推送或外部发布。
- 状态continue。下一阶段按 artifacts/realism359-validation/next-stage.md 改善正常宽景中的连续地形、坡面植被过渡与树冠体积，增加建筑厚度/空间层次，并用实机确认有效补光；继续保留人物、第一人称手部与三枪动作外观审阅、联网主要功能和目标硬件验证目标。

### stage360 — 维修棚侧面百叶、路肩植被与入口补光（整体继续）
- 维修棚东侧砌体上方增加立柱和倾斜百叶；入口新增朝内补光，后墙、窗带与地面更易辨认；路肩低草斑块由4处扩展至9处并调整高度过渡。入口侧面变化可辨识，宽景草带更连续，但补光仅为近似，建筑规整、树冠卡片感、平坦道路与车间大屋面问题仍未解决。保留既有未提交修改。
- 四组普通站立机位前后原始截图已实际审阅，包含入口近景与宽幅地形：artifacts/realism360-validation/review.html；具体观察与局限见 next-stage.md。基线来自359，来源哈希见 before-provenance.json；位置、目标、yaw/pitch见 stable-environment/environment-camera-poses.json，四组前后逐字段一致。阶段源码差异见 stage360-world.diff。
- 冻结包13项检查全部通过：建筑入口/后出口通行、立柱阻挡绕行、坡面12条路线、维修道路90条移动路线及1项挡土碰撞、三枪108个瞄准样本、武器遮挡、三枪两姿态第三人称换弹及16角色单机冒烟。新增东侧百叶没有单独逐片射线断言。artifacts/realism360-validation/final-verification.json 确认源码/测试/包哈希一致、测试前后PCK未变与截图进程通过；逐项日志见 stable-verified/functional-results.json。
- 本地预览：./artifacts/realism360-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus（保留相邻PCK，详见预览README.md）。截图为Forward+ / llvmpipe软件Vulkan，目标GPU性能未验；此前联网认证前置问题本阶段未复核，联网NOT_RUN。没有推送或外部发布。
- 状态continue。下一阶段优先解决正常机位显眼的树冠卡片轮廓、草地与裸土过渡和车间屋面材质尺度，沿用机位复核并保持通行。仍须第三人称人物、第一人称手臂与三枪动作外观审阅、联网主要功能及目标硬件验证；不以本次局部改善认定整体目标完成。

### stage361 — 树高差异、屋面分板与土壤过渡（视觉提升不足，继续）
- 普通树增加高度差异并同步远景卡片，九棵道路树延长实体显示距离；车间主屋面增加替换板色、褪色与接缝径流，建筑裸土边缘增加不规则过渡。保留树干横向尺寸及既有未提交修改；本轮未改全局光照。独立源码差异：artifacts/realism361-validation/stage361-environment.diff。
- 已实际审阅入口近景、侧面、棚内和宽景四组同机位前后图：artifacts/realism361-validation/review.html。入口与侧面提升几乎不可辨，棚内不能证明外屋面效果，宽景树线重复和地表空旷仍明显；本轮没有达到正常机位明显辨识的一组环境提升标准。相机位置、目标和yaw/pitch见 stable-environment/environment-camera-poses.json，与360基线一致；观察及下一阶段安排见 next-stage.md。
- 冻结预览包13项检查全部通过，包括建筑入口双向通行与碰撞、坡面12条路线、服务道路90条通行及1项挡墙碰撞、三枪108个瞄准样本、武器遮挡、三枪两姿态换弹及16角色单机冒烟。artifacts/realism361-validation/final-verification.json 确认源码/测试/包哈希一致、测试前后PCK未变及截图进程通过；逐项日志索引：stable-verified/functional-results.json。这些规则检查不替代人物与手部外观验收。
- 当前本地预览：./artifacts/realism361-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus（保留相邻PCK；详见预览README.md）。截图使用Forward+ / llvmpipe软件Vulkan；目标GPU性能和联网未验，历史联网认证前置问题本轮未复核。没有推送或外部发布。
- 状态continue。下一阶段定位宽景实际可见树木的多处实例化路径，成组改善树冠体积、疏密、灌木与碎石裸土过渡，增加可见外屋面的结构分区，并以正常行走机位复核建筑、地表与光照层次及入口净空；仍保留人物、第一人称手臂与三枪动作实机审阅、联网主要功能和目标硬件验证目标。

### stage362 — 维修棚门洞砌体、林缘轮廓与入口补光（继续）
- 调整西侧树高、树冠宽度及灌木体量；抬高入口砖基、增加砌体门框，提高棚内补光。四组同机位实机前后图已审阅：入口基座/门框及宽景林缘轮廓变化可辨，工坊主体变化很小，远处灌木改善不突出。大片平直硬地、重复百叶与树叶、稀疏远景仍明显。差异见 artifacts/realism362-validation/environment362.patch；对照见 review.html，逐机位意见见 visual-review.json。
- 入口近景、侧面、工坊及宽幅地形原图保存在 artifacts/realism362-validation/stable-environment/，位置、朝向和目标见 environment-camera-poses.json；与 before/ 的361基线相机记录完全一致。
- 冻结预览13项检查全部通过：建筑中央双向通行、砖基阻挡及绕行、新门框碰撞、坡面12条路线、服务道路90条移动路线及挡土墙碰撞、三枪108个瞄准样本、武器遮挡、三枪两姿态换弹、16角色单机冒烟。最终核对见 artifacts/realism362-validation/final-verification.json，逐项日志见 stable-verified/functional-results.json。游戏源码/包哈希一致，测试前后PCK未变；导出后修订了外部入口测试两处几何预期，原版与修订哈希均保留，因此原始全清单匹配字段为false，修订后验证清单匹配为true。
- 本地预览：./artifacts/realism362-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus（保持相邻PCK；详见预览README.md）。截图为Forward+ / llvmpipe软件Vulkan，目标GPU性能未验；历史联网认证前置问题本轮未复核，联网NOT_RUN。没有推送或外部发布。
- 状态continue。下一阶段继续改善正常机位的单调铺地、林缘地表过渡及建筑重复构件，再结合第三人称人物、第一人称手部与三枪动作实机审阅安排缺陷；保留联网主要功能和目标硬件验证。当前局部环境提升不代表整体画质目标完成。

### stage363 — 维修道路分板与补带、路肩草丛及入口雨棚（继续）
- 加强混凝土分板深浅、锯缝碎边与横向维修补带，加密路肩草丛；入口增加折边雨棚并扩大灯光照射角。阶段差异：artifacts/realism363-validation/environment363.patch。实际宽景中补带、接缝及右路肩变化可辨；正面雨棚受原有大檐口遮挡，补光收益不突出，工坊近乎不变，不将这些参数调整算作显著建筑/光照提升。
- 四组同机位前后实机图已逐项审阅：artifacts/realism363-validation/review.html，含入口近景与宽幅地形；before/复用362冻结原图，来源见 baseline-provenance.json。前后 environment-camera-poses.json 完全相同，位置与朝向均保留。逐机位局限与下一阶段见 next-stage.md；重复百叶、平板建筑、稀疏相似树冠及前臂外形仍明显。
- 冻结预览13项检查全部通过：道路、林缘与建筑胶囊通行及碰撞、维修棚双向进入与净空、三枪108个瞄准样本、武器遮挡、三枪两姿态换弹、16角色单机冒烟。日志索引：artifacts/realism363-validation/stable-verified/functional-results.json。final-verification.json 确认72个清单文件一致、测试前后包未变、两批截图进程正常退出及四组相机一致。
- 当前本地预览：./artifacts/realism363-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus（保留相邻PCK；详见README.md）。实机截图使用Xvfb / Vulkan llvmpipe / Forward+；联网本轮未复测，实体GPU性能未验。没有推送或外部发布，保留已有未提交修改。
- 状态continue。下一阶段优先改善正常机位可见的建筑开间、门窗凹进、屋面收边与重复百叶节奏，并用可控对照验证光照层次，保持入口净空。随后结合第三人称人物、第一人称手部与三枪动作实机审阅安排剩余缺陷；继续保留联网主要功能和目标硬件验证，整体画质目标未完成。

### stage364 — 维修棚钢框玻璃侧墙与院落植物（继续）
- 两侧厚木百叶改为三格细钢框玻璃窗，保留门柱、斜撑及开放入口；墙脚与院落增补低矮阔叶植物，并添加窗边反射补光。阶段差异：artifacts/realism364-validation/environment364.patch。实机入口和侧视中透光窗格明确减轻叠条感；植物与已有灌木交叠，补光收益有限，宽景地表及林地整体变化不足，不能计作整体环境目标完成。
- 四组同机位原始前后图已逐项审阅：artifacts/realism364-validation/review.html，包含建筑入口近景及宽幅地形。before/复用363冻结截图，baseline-provenance.json保存来源与哈希；stable-environment/environment-camera-poses.json记录位置、目标与朝向，前后完全一致。next-stage.md记录车间近乎不变、规则地坪、稀薄树冠、硬质边界和袖管手套等未解决问题。
- 冻结包13项测试全部通过：建筑入口双向通行、门柱阻挡绕行、玻璃侧墙射线与胶囊碰撞、道路与坡面通行、三枪108个瞄准样本、武器遮挡、三枪两姿态换弹及16角色单机冒烟。日志索引：artifacts/realism364-validation/stable-verified/functional-results.json；final-verification.json确认72个清单文件哈希一致、测试前后包未变、两批截图进程通过及四组相机一致。
- 当前本地预览：./artifacts/realism364-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus（保留相邻PCK；详见预览README.md）。截图使用Xvfb / Vulkan llvmpipe / Forward+；联网本轮未复测，实体GPU性能未验。保留已有未提交修改，没有推送或外部发布。
- 状态continue。下一阶段成组改善宽景道路、建筑与林缘之间的连续地表过渡、材质尺度和重复构件，保持窗墙碰撞与入口净空回归；随后结合第三人称人物、第一人称手部及三枪动作实机审阅安排缺陷，并完成联网主要功能与目标硬件验证。整体写实目标仍未完成。

### stage365 — 维修棚铺地肩部泥沙、碎石与低矮灌草（继续）
- 扩展铺地边缘的不规则泥沙混合，将碎石移到完成面附近并调整尺度，在弯道外侧增加三处低矮灌草。阶段补丁：artifacts/realism365-validation/environment365.patch。建筑与光照沿用364，本轮未新增改动。实机可辨地表过渡，但碎石偏亮、扁片感与刻意颗粒带仍明显，新增植物未明显缓解远景空旷，不能判定整体画质提升达标。
- 四组同机位前后截图已审阅，包含建筑入口近景、侧面、车间及宽幅地形：artifacts/realism365-validation/review.html。before复用364冻结包原图，baseline-provenance.json保存来源；stable-environment/environment-camera-poses.json记录位置及朝向。next-stage.md记录各机位收益与缺陷。
- 365冻结包13项检查全部通过：建筑双向进入、门柱阻挡与绕行、玻璃侧墙碰撞和净空、道路坡面与林缘通行、三枪108个瞄准样本、武器遮挡、三枪两姿态换弹、16角色单机冒烟。日志索引：artifacts/realism365-validation/stable-verified/functional-results.json。final-verification.json确认72个清单文件一致、测试前后包未变、两批截图正常退出及四组相机完全一致。
- 当前本地预览：./artifacts/realism365-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus（保留相邻PCK，详见预览README.md）。截图使用Xvfb / Vulkan llvmpipe / Forward+；联网本轮未复测，实体GPU性能未验。保留已有未提交修改，没有推送或外部发布。
- 状态continue。下一阶段优先修正碎石明度与扁片轮廓，将沉积/落叶/草土过渡、宽景林缘疏密、建筑基脚与接触阴影作为一组明显可辨的环境改进，保持入口净空；随后继续第三人称人物、第一人称手部及三枪动作实机审阅，并补齐联网主要功能与目标硬件验证。整体目标未完成。

### stage366 — 路肩灌草、碎石修正与建筑基脚接触效果（继续）
- 调整维修通道嵌入碎石数量、尺度、明度及散布，增加三处路肩灌草，添加墙基泥污并增强SSAO。阶段补丁：artifacts/realism366-validation/environment366.patch。入口侧面灌草填补局部空缺可辨；墙基及阴影变化较弱，宽景构图接近365，亮石子扁片感仍明显，建筑重复和远景空旷尚未解决。
- 四组同机位前后实机图已审阅，包含入口近景、侧面、车间及宽幅地形：artifacts/realism366-validation/review.html。before复用365冻结截图，baseline-provenance.json记录来源；stable-environment/environment-camera-poses.json记录相机位置和朝向，前后完全一致。角色冻结拍摄不替代动态单机冒烟。next-stage.md记录实际收益与剩余缺陷。
- 冻结包确认5项检查正常退出通过：路肩通行、林缘通行、西侧树林碰撞、装卸雨棚通行及维修棚框架通行；覆盖维修棚双向进入、门柱阻挡绕行、入口净空与侧窗墙碰撞。日志索引：artifacts/realism366-validation/stable-verified/functional-results.json。final-verification.json确认72个清单文件一致、测试前后包未变。第二批截图虽保存图片并打印PASS，但外层143中断，退出未确认；批量功能检查亦143中断，原因未知，未收集退出码的stage317不计通过。完整功能套件尚未完成。
- 当前可运行本地预览：./artifacts/realism366-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus（保留相邻PCK，详见预览README.md）。导入导出成功，截图采用Xvfb / Vulkan llvmpipe / Forward+。联网与实体GPU性能本轮未复测；保留所有已有未提交修改，未推送或外部发布。
- 状态continue。下一阶段先补完动态单机冒烟、三枪瞄准/遮挡/换弹及剩余道路回归；隔离残余亮石子来源，成组改善建筑形体、地表和宽景林缘并保持入口净空。随后复审第三人称人物、第一人称手部及联网主要功能。整体写实目标未完成。

### stage367 — 入口旧漆招牌、嵌入碎石与墙脚灌草（继续）
- 修正维修入口浅白凸起碎石的尺度、密度、高光与埋入高度；入口招牌改为旧漆材质并增加折边和固定件；提高墙脚灌草层次、补充两处植物群，Forward+天空补光从0.44降至0.36。阶段差异：artifacts/realism367-validation/environment367.patch。入口及宽幅正常机位可辨亮石减少和灌草变化；光照收益有限，车间机位变化很小，不计作显著改善。
- 已审阅四组同机位前后实机截图，包括建筑入口近景、侧面、车间及宽幅地形：artifacts/realism367-validation/review.html。before复用366原图且核对哈希；stable-environment/environment-camera-poses.json记录位置和朝向，前后完全一致。两批截图进程均正常退出；拍摄冻结场景，动态通行由独立测试验证。
- 367冻结包13项检查全部通过，补齐上一阶段未完成的回归：建筑双向进入、门柱阻挡绕行、玻璃侧墙与净空、道路坡面林缘通行、三枪108个瞄准样本、近墙武器遮挡、三枪两姿态换弹，以及16角色单机冒烟（治疗/伤害/胜利等）。索引：artifacts/realism367-validation/stable-verified/functional-results.json。final-verification.json确认72个清单文件一致、测试前后资源包未变。
- 当前本地预览：./artifacts/realism367-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus（需要图形显示并保留相邻PCK，见预览README.md）。截图采用Vulkan llvmpipe / Forward+。联网未验证：现有网络脚本涉及认证及密钥读取流程，本轮未运行或读取密钥；实体GPU性能未验。保留已有未提交修改，未推送或发布。
- 状态continue。建筑平墙粗柱、右侧重复棚架、大块护坡石折面及树形重复仍明显，第一人称袖管偏直。下一阶段优先改善棚架/建筑轮廓、护坡石尺度形状及道路到远景植被连续层次，以相同机位核验收益；随后补齐第三人称人物、第一人称手部与三枪动作实机审阅、联网主要功能和目标硬件验证。细节与后续见artifacts/realism367-validation/next-stage.md，整体目标未完成。

### Stage368：棚架采光开口与路肩植被；实机验证完成，整体继续
- 东侧棚架两跨上部横板分别减至六排、八排，形成错落采光开口；旧漆调暗、粗糙度提高。四处路肩石组缩低并增加姿态变化，增加细叶草与矮灌木；未调整全局光照。
- Stage367/368 四个相同正常游戏机位对照、入口近景及宽幅地形见 `artifacts/realism368-validation/review.html`，位置与朝向见 `stable-environment/environment-camera-poses.json`。实机可辨识棚架上部开口，但日照板条仍偏白、前景及棚侧块状大石仍明显；不将视野外石组调整算作这些缺陷已解决，墙柱与树形重复也未解决。
- 冻结 Linux 预览 `artifacts/realism368-preview/Linux/IronMeridian`（启动见同目录上级 README.md）。实际 Forward+ 截图使用 llvmpipe；13 项功能检查全部通过，含建筑双向通行和阻挡、service_lane 90 条路线、108 个瞄准样本、贴墙规则、第三人称换弹及 16 角色离线烟测。证据：`artifacts/realism368-validation/stable-verified/functional-results.json`、`final-verification.json`；四机位一致，72 项文件清单一致，测试包哈希未变。没有执行联网验证或硬件 GPU 性能验证。
- 下一步：定位宽景前景、棚侧大石的实际生成路径，针对可见轮廓、落地关系及植被遮接改进；继续日照板条材质、入口墙柱与树形分布，再做第三人称人物和第一人称手部实机审阅，保留联网完整验收。详见 `artifacts/realism368-validation/next-stage.md`。不以本轮有限环境收益宣布总体完成。

### Stage369：道路挡土石墙轮廓与石脚植被，整体继续
- 改进实际可见的 drainage 石墙：偏移窄顶冠、错落石块高度与旋转、石脚低矮阔叶植物；减弱矿物色差并增加细微受光起伏，保持可见网格碰撞。未改全局光照。准确增量见 `artifacts/realism369-validation/environment369.patch`。
- 已审阅四组同机位前后实机截图（含建筑入口近景、棚侧、车间及宽幅地形）：`artifacts/realism369-validation/review.html`；位置与朝向见 `stable-environment/environment-camera-poses.json`。棚侧和宽景左侧连续平顶石块轮廓有所改善，但折面仍明显；日照板墙偏白、粗柱、树形重复及右侧前景石块未解决，入口/车间无显著画质增益。
- 当前冻结包13项检查全部通过，含建筑双向进入与阻挡、站立/蹲伏/机器人道路通行、石墙胶囊阻挡与射线命中、108个瞄准样本、贴墙规则、第三人称换弹和16角色单机烟测。`final-verification.json` 核对四机位、两个截图进程、72项文件清单及包哈希；详细日志在 `artifacts/realism369-validation/stable-verified/`。
- 可运行预览：`artifacts/realism369-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`（图形显示、保留相邻PCK）。实机截图为 llvmpipe 软件渲染；联网与硬件GPU未验证，人物/手部专门视觉验收仍待完成。保留未提交修改，未推送或发布。
- 下一阶段优先建筑板墙日照材质、入口粗柱和棚架结构，结合右侧石块实际生成路径及地表树形层次改进；之后补齐人物手部动作截图与联网完整验收。详见 `artifacts/realism369-validation/next-stage.md`。状态 continue，整体写实目标未完成。

### Stage370：棚架旧漆、路肩草丛与接触阴影，整体继续
- 调暗百叶旧漆、增加底部潮污与折边磨损；排水路肩六组新增108株细叶草；调整 SSAO 半径/强度与 SSIL。准确增量见 `artifacts/realism370-validation/environment370.patch`，保留此前全部未提交修改。
- 四组相同正常游戏机位前后截图已实机审阅，含入口近景、棚侧、车间与宽幅地形：`artifacts/realism370-validation/review.html`；位置与朝向在 `stable-environment/environment-camera-poses.json`。百叶更暗，但草丛和遮蔽收益细微；粗柱、直梁、折面石块、重复树形及罐体纹理拉伸仍明显，不能视为整体写实目标完成。
- 冻结包13项功能检查全部通过，含建筑进入/阻挡与单机通行、108个瞄准样本、贴墙规则、第三人称换弹和16角色单机烟测。`artifacts/realism370-validation/final-verification.json` 核验四机位一致、两个截图进程成功、72项文件哈希一致及测试包未改变；原始日志在 `stable-verified/`。
- 本地预览：`./artifacts/realism370-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，保留相邻PCK并使用图形显示；说明见 `artifacts/realism370-preview/README.md`。截图为 llvmpipe 软件渲染，联网和硬件GPU性能未验证，人物/手部专门视觉验收待完成。未推送或发布。
- 下一阶段应集中进行正常机位可见的入口墩/墙脚构造、石块埋入关系和前中景树灌轮廓改进，避免继续整轮小幅颜色调整；随后补齐人物、手部及联网验收。详见 `artifacts/realism370-validation/next-stage.md`。状态 continue。

### Stage371：入口砌体与钢斜撑、石脚植被，整体继续
- 维修棚入口新增显露砖砌柱脚/矮墙、压顶与底座、钢斜撑及连接板；四处道路石块周围增加不规则两簇植物。沿用Stage370光照。准确增量见 `artifacts/realism371-validation/environment371.patch`，保留此前全部未提交修改。
- 已审阅四组相同正常游戏机位前后实机截图：`artifacts/realism371-validation/review.html`，含入口近景、棚侧、车间和宽幅地形；相机位置与朝向见 `stable-environment/environment-camera-poses.json`。入口砌体和斜撑可明显辨识，宽景新增植被收益难以辨识，不能以植物数量认定画质改善。粗重梁柱、折面石块、重复树形和大面积平板棚顶仍待改进。
- 冻结包13项检查全部通过：维修棚双向进入、柱脚阻挡/绕行及门洞净空，其他建筑和道路站立/蹲伏/机器人通行，108组瞄准样本、武器遮挡、第三人称换弹规则及16角色单机烟测。`artifacts/realism371-validation/final-verification.json` 核验四机位相同、两个截图进程成功、72项文件哈希和包未改变；逐项结果及原始日志在 `stable-verified/`。
- 本地预览：`./artifacts/realism371-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`（需要图形显示并保留相邻PCK）。截图使用llvmpipe软件渲染；本轮未完成联网、硬件GPU性能以及人物/手部专门视觉验收。未推送或发布。
- 下一阶段优先修正正常机位中可见的前中景石块折面、树灌轮廓重复及日照板墙材质，随后补齐人物、手部动作截图和联网验收。详见 `artifacts/realism371-validation/next-stage.md`。状态 continue，整体目标未完成。

### Stage372：排水石岸轮廓与路肩留白，整体继续
- 排水石块改为多环圆钝轮廓与光滑法线；修正石材噪声高度插值并衰减亚像素法线细节，路肩植物应用裸地留白并降低部分株高与木本频率。沿用Stage371建筑与光照。增量见 `artifacts/realism372-validation/world_visuals.gd.diff` 和 `drainage_stone.gdshader.diff`，保留全部未提交修改。
- 已审阅四组相同正常游戏机位前后截图，含入口、棚侧、车间和宽幅地形：`artifacts/realism372-validation/review.html`；位置与朝向见 `stable-environment/environment-camera-poses.json`。石岸折角减少可辨识，但仍偏均匀灰色团块，墙根灌木密集、棚顶与梁柱平直、地坪模糊和树形重复仍明显。静态截图不能证明运动闪烁已消除，本轮局部改进不代表建筑/光照或整体目标完成。
- 冻结包13项检查通过，含建筑双向进入、柱脚阻挡/绕行和净空、道路站立/蹲伏/机器人通行、108个瞄准样本、武器遮挡、第三人称换弹规则及单机烟测。`artifacts/realism372-validation/final-verification.json` 核验四机位一致、两个截图进程成功、72项文件哈希及包未改变；原始日志见 `stable-verified/`。
- 本地预览：`./artifacts/realism372-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，需图形显示并保留相邻PCK；说明见该预览目录的 `README.md`。软件Vulkan截图，本轮未重跑联网，硬件GPU及人物/手部专门视觉验收待完成。未推送或发布。
- 下一阶段集中改进车间棚顶支承与接缝、梁柱截面、地坪尺度和接触光影，配合墙根留白及树形变化；保留同机位对照并重新检查通行，随后补人物/手部与联网验收。详见 `artifacts/realism372-validation/next-stage.md`。状态 continue。

### Stage373 — 环境结构、地坪与植被实机验证（continue）
- 车间屋檩/檐口改为薄壁开口钢截面，地坪减少云状污斑并加入细骨料/抹平纹，微增天窗局部补光；建筑周边植物降低高度并形成不规则空隙。正常机位可辨识屋檩厚度和窗下地表，入口改善有限，宽景整体变化较小，未达到整体写实目标。
- 保存 Stage372→373 四组相同机位原始实机截图、位置/朝向和对照页：`artifacts/realism373-validation/review.html`。软件 Vulkan/llvmpipe 渲染；13 项功能测试通过，覆盖建筑站立/蹲伏双向通行、碰撞、单机烟测、108 样本瞄准、武器遮挡和第三人称换弹规则。72 个清单文件一致，冻结包未变，见 `artifacts/realism373-validation/final-verification.json` 与 `stable-verified/`。
- 本地预览：`artifacts/realism373-preview/Linux/IronMeridian`，同目录 `.pck`；启动说明见预览 README。本轮未测联网、硬件 GPU，未完成专门的人物/手部画质审阅；无推送或发布。
- 下一步：优先修复车间储罐失真法线/纹理、近景圆块石头和植被卡片感，同机位复核；再安排第三人称人物与第一人称手部截图及联网回归。具体审阅与局限见 `artifacts/realism373-validation/next-stage.md`。

### Stage374 — 圆管采样与堆场植被修正，整体继续（continue）
- 预制圆管使用世界空间三平面混凝土采样，堆场植物每组110→48株并缩小尺寸；保留空心几何和碰撞。本轮对象为圆管，并非Stage373误称的车间储罐。新增 `client/shaders/precast_concrete.gdshader`，增量见 `artifacts/realism374-validation/world-visuals-stage374.diff`；保留既有未提交修改。
- 实际审阅入口、棚侧、车间、宽幅地形与圆管专项前后截图，机位位置/朝向一致；对照见 `artifacts/realism374-validation/review.html`，相机见 `stable-environment/environment-camera-poses.json` 和 `pipe-after/environment-camera-poses.json`。条纹减轻，但圆管偏白平滑、管口阴影弱，棚顶薄、地坪模糊、石岸和树形重复仍明显；不能认定本轮完成建筑/植被/光照的一组整体改进。
- 冻结包13项功能检查通过，含可进入建筑双向通行/柱脚碰撞、道路站立/蹲伏/机器人路线、108样本瞄准、遮挡、换弹规则与单机烟测。道路首轮超时124，保留原日志；提高等待上限后的复测退出0并输出PASS。73项文件哈希一致，测试前后PCK未变，详见 `artifacts/realism374-validation/final-verification.json` 及 `stable-verified/`。
- 截图文件成功保存不等于采集进程验收通过：入口首轮和圆管after进程退出143；车间/宽景有PASS但未收集退出码；棚侧独立补采退出0。原始审计保留，`capture_exit_validation_complete=false`，未伪报整套采集通过。
- 本地预览：`./artifacts/realism374-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，保留相邻PCK并提供图形显示；说明见预览README。本轮软件Vulkan截图，联网、硬件GPU及人物/手部专门画质验收未完成。未推送或发布。
- 下一步：同机位配套改进入口屋面接缝/支承厚度、地坪与圆管骨料尺度/接触光影、墙根裸地与植被簇差异；解决截图退出审计缺口，继续建筑通行回归，再补人物/手部和联网验收。详见 `artifacts/realism374-validation/next-stage.md`；整体目标未完成。

### Stage375 — 维修棚屋面结构、入口草簇及补光，整体继续（continue）
- 修改 `client/scripts/world_visuals.gd`：棚底木板替换为双面折板屋面，矩形檩条改为窄开口钢构件；入口草簇6→4、降低高度与密度，地坪/棚内补光降低。保留屋面碰撞体与此前所有未提交修改；本轮差异见 `artifacts/realism375-validation/stage375-source.diff`。
- 已实际打开入口近景、棚侧、车间与宽幅地形的同机位前后截图。入口结构层次有局部改善，但车间几乎无变化、宽景提升不明显；圆石重复、灌木碎噪、圆管偏白与地坪模糊仍在，不认定整体环境目标完成。对照 `artifacts/realism375-validation/review.html`，具体审阅 `visual-review.md`，位置/目标/偏航/俯仰记录 `stable-environment/environment-camera-poses.json`。
- 本轮2个实机采集进程均退出0、有PASS且未报错，覆盖4个1280×800机位；前图复用Stage374，历史退出审计缺口仍如实保留。13项功能检查全部退出0通过，含建筑双向进出、柱脚阻挡/绕行、道路林地通行、3武器108样本瞄准、武器遮挡、第三人称换弹规则及16角色单机烟测。日志见 `artifacts/realism375-validation/stable-verified/`，汇总 `final-verification.json`；73项文件哈希一致，测试前后PCK一致。
- 本地预览启动：`./artifacts/realism375-preview/Linux/launch.sh`，保留同目录IronMeridian及PCK，需要图形显示。实际截图使用软件Vulkan，不作为硬件帧率结论。现有联网夹具读取认证密钥，遵守禁止读取密钥要求未执行，未声称联网通过；人物/手部专项画质审阅也未完成。未推送或发布。
- 下一步：扩大到宽景可见的石岸形体差异、墙根裸地与植被簇分布、地坪及圆管的尺度/接触光影，继续固定机位对照与建筑通行验证；随后补第三人称人物、第一人称手部审阅，并在不读取密钥的可用测试环境补联网主要流程。

### Stage376 — 石岸断面、草簇裸地与混凝土管材质，整体继续（continue）
- 修改 `world_visuals.gd` 石岸形体/平面法线及碰撞网格，降低路肩草簇并扩大裸土缺口；`precast_concrete.gdshader` 调整骨料、灰色基调和管内间接光遮蔽。保留所有原有未提交修改，阶段差异见 `artifacts/realism376-validation/stage376-source.diff`。
- 实际查看入口、棚侧、车间和宽景的固定机位前后图：管堆亮白感减轻、草簇更低；石岸虽摆脱圆滑轮廓，但宽景长条石像混凝土板/梁，需优先修正。车间变化有限，地坪模糊、植被碎噪与重复树形仍在，未达到整体写实目标。对照 `artifacts/realism376-validation/review.html`，详细审阅 `visual-review.md`；坐标、目标、偏航和俯仰见 `stable-environment/environment-camera-poses.json`，四机位与Stage375完全一致。
- 两个实机采集进程均退出0并输出PASS，覆盖入口近景和宽幅地形等四图。冻结包13项功能检查全部通过，包括建筑双向通行/柱脚窗面碰撞、道路站立/蹲伏/机器人路线、108样本瞄准、武器遮挡、第三人称换弹规则及16角色单机烟测。73项构建输入哈希一致，测试前后PCK一致；汇总 `artifacts/realism376-validation/final-verification.json`，原始日志 `stable-verified/`。
- 本地可运行预览：`./artifacts/realism376-preview/Linux/launch.sh`，需图形显示并保留相邻二进制及PCK。截图使用软件Vulkan，不代表硬件性能验收；联网认证夹具读取密钥，本轮遵守限制未运行，未声称联网通过。人物及手部专门画质审阅仍待完成，未推送或发布。
- 下一步：优先消除长条石的板梁/积木观感，配套改善入口地坪尺度、接触阴影和植被簇群过渡；继续同机位实机审阅及建筑通行回归。随后补人物/手部审阅与不暴露密钥的联网测试，详见 `artifacts/realism376-validation/next-stage.md`。


### Stage377 — 修正石岸板梁轮廓与入口材质尺度，整体继续（continue）
- 修改 `world_visuals.gd`：石岸收窄顶面、增加斜裂与埋深/倾角差异，保持匹配的网格碰撞；调整低矮草簇间距。`drainage_stone.gdshader` 增加低处土色过渡，`service_access.gdshader` 缩小骨料尺度并补入口墙根积尘遮蔽。阶段差异保存于 `artifacts/realism377-validation/stage377-source.diff`；保留此前未提交修改。
- 实际审阅入口、棚侧、车间及宽景四组同机位前后图：路边长板梁感减轻，石块仍偏人工多边形；入口材质变化较轻，车间基本不变。建筑主体、全局光照、重复树冠及简单山体尚未解决，不以本轮局部改善判定整体完成。对照 `artifacts/realism377-validation/review.html`，审阅 `visual-review.md`；位置、目标、偏航和俯仰记录于 `stable-environment/environment-camera-poses.json`，与Stage376一致。
- 两个本轮截图进程均正常退出0并输出PASS，四图1280×800。13项冻结包功能检查全部通过，包含建筑双向通行/碰撞、道路站立/蹲姿/机器人路线、石岸胶囊阻挡及射线、108样本瞄准、武器遮挡、第三人称换弹规则及16角色单机烟测。73项构建输入/包哈希一致，测试前后PCK一致；汇总 `artifacts/realism377-validation/final-verification.json`，原始日志 `stable-verified/`。
- 本地预览 `./artifacts/realism377-preview/Linux/launch.sh`，需图形显示与Vulkan，保留相邻二进制及PCK。软件Vulkan截图不能证明硬件帧率。联网未重测：现有认证夹具读取密钥，遵守用户限制未运行该入口，未读取或输出密钥；人物与手部专项实机画质审阅仍未完成。未推送或发布。
- 下一步：优先实施正常机位可见的建筑主体形体、远景山体/重复树冠及光照层次改进，避免继续只调地坪噪声；维持入口近景和宽景对照，复测可进入建筑碰撞与单机通行。随后补人物/手部审阅，并使用不读取密钥的可用测试环境验证联网主要功能。


### Stage378 — 屋脊通风构造、林缘和远山调整，整体继续（continue）
- 修改 `client/scripts/world_visuals.gd`：维修棚百叶通风体加宽加高，增强入口林缘灌木，调整山脊细节与鞍部，增加天空环境补光及间接光。阶段差异 `artifacts/realism378-validation/stage378-source.diff`；保留此前未提交修改。
- 审阅入口、棚侧、车间、宽景四组同机位实机前后图：棚顶构造变化明显，灌木更丰满；山体仍偏圆滑，树冠重复和地表人工感仍在，车间光照改善不明显。不能据此判定整体画质达标。对照 `artifacts/realism378-validation/review.html`，具体局限 `visual-review.md`；前图复用 Stage377，四组相机位置/目标/偏航/俯仰与本轮逐项一致，元数据在 `stable-environment/environment-camera-poses.json`。
- 13 项冻结包功能检查全部通过：建筑双向通行/碰撞、道路站立/蹲姿/机器人路线、石岸阻挡、108 样本瞄准、武器遮挡、第三人称换弹规则、16 角色单机烟测。两个截图进程退出0并输出PASS；73项构建输入/包哈希一致，测试前后PCK一致。另山体植被几何检查通过，最大树根贴地误差0.000137米。汇总 `artifacts/realism378-validation/final-verification.json`，原始日志 `stable-verified/` 和 `background-scenery.log`。
- 当前本地预览 `./artifacts/realism378-preview/Linux/launch.sh`，需图形显示与Vulkan及相邻二进制/PCK。软件Vulkan截图不证明硬件帧率。联网未重测：现有认证夹具读取密钥，遵守用户限制未运行该入口，未读取或输出密钥。人物/手部专项画质审阅仍未完成；未推送或发布。
- 下一步：补第三人称3米/10米正侧面与三把武器握持、瞄准、连续换弹实机审阅，处理明显比例/衣物/装备绑定问题，避免只调机匣或手指；继续保留建筑主体、远山、重复树冠、地表及光照缺陷，寻找不读取现有密钥的隔离联网验证方式。见 `artifacts/realism378-validation/next-stage.md`。

### Stage379：车间屋面采光与维修棚树下植被（2026-09-18）
- 加宽车间两条屋顶透光带，增加支撑横条，调整透光材质与局部采光；维修棚周围改为有间隙、高低变化的灌木群落。正常第一人称机位可辨认屋面与树下层次变化，入口通路保持可用。
- 已逐张审阅四机位前后实机截图，相机参数完全一致；入口近景、侧面、车间与宽幅地形对照见 `artifacts/realism379-validation/review.html`，原图及位置/朝向见其中 `before-environment/`、`stable-environment/environment-camera-poses.json`。宽幅地形改善有限，叶片重复、透光板偏清玻璃、铺装规整及管道材质仍明显；具体审阅见 `visual-review.md`。
- 冻结预览包13项功能检查通过，含单机冒烟、可进入建筑双向通行/碰撞、车间屋顶与支柱碰撞、瞄准及武器遮挡；两次图形进程均成功。73项构建输入哈希一致，测试前后包哈希一致，证据见 `artifacts/realism379-validation/final-verification.json` 与 `stable-verified/`。软件 Vulkan 截图不代表独立显卡性能。
- 本地可运行预览：`./artifacts/realism379-preview/Linux/launch.sh`（需图形环境，菜单选择单机）。保留既有未提交修改；未推送、未外部发布、未读取既有密钥。
- 下一步：结合第三人称3/10米及第一人称手部/换弹实机审阅安排剩余缺陷，继续改善宽幅地表、植被材质与建筑入口观感，避免回到仅武器微调。联网主要功能仍需不读取既有认证信息的隔离配置验证；整体目标未完成。

### Stage380：车间磨砂屋面、连续地坪及草地交界（2026-09-18）
- 车间透光板改为磨砂芯层近似，消除透板可见的清晰树冠；两米方块地面改为连续浇筑地坪和较淡切缝，拓宽并降低局部采光，沿砾石边缘增加低草、留出中段通路。阶段源码差异见 `artifacts/realism380-validation/stage380-source.diff`，保留既有未提交修改。
- 已审阅入口近景、棚侧、车间和宽幅地形四组前后实机图，四组相机位置及朝向逐项一致。车间屋面与地坪变化明确；入口及宽景基本不变，重复树冠、均匀草地、车间外方形铺装、白色管道及平淡袖口仍明显，整体目标未完成。对照 `artifacts/realism380-validation/review.html`，审阅 `visual-review.md`，相机记录 `stable-environment/environment-camera-poses.json`。
- 冻结包13项功能检查全部通过，包含单机流程、建筑入口/车间双向站蹲通行、构件碰撞、道路机器人路线、108样本瞄准、武器遮挡和第三人称换弹规则；两次截图进程通过，73项构建输入/包哈希一致，测试前后PCK一致。证据 `artifacts/realism380-validation/final-verification.json` 与 `stable-verified/`。规则检查不代替人物和手部画质审阅，软件Vulkan不代表硬件性能。
- 当前本地预览 `./artifacts/realism380-preview/Linux/launch.sh`（需图形显示与Vulkan，保留相邻二进制/PCK）。未推送、未发布；联网本轮未运行，未读取既有认证信息。
- 下一步：重点改善正常宽景中的树冠轮廓、草地分布及铺装重复；结合第三人称3米/10米和第一人称三把武器瞄准/换弹截图处理人物与手部缺陷，并使用不读取既有密钥的隔离配置验证联网主要功能。见 `artifacts/realism380-validation/next-stage.md`。

### Stage381：服务车道连续铺装、管材风化与棚侧植被（2026-09-18）
- 消除服务车道交替明暗方格，改为连续浇筑面与有限切缝；降低预制管材亮度并增加风化，调整棚侧十处植被群落间隙与高度，降低入口灯能量并扩大照射角。阶段差异见 `artifacts/realism381-validation/stage381-source.diff`，未修改碰撞几何，保留既有未提交修改。
- 已审阅入口近景、棚侧、维修工位及宽幅地形四组同机位实机对照，位置与朝向完全一致。宽景方格消除、管材变暗及棚侧裸土间隙可辨认；入口三角亮斑仍明显，树冠重复、地表平滑及部分设施方块感尚未解决。对照 `artifacts/realism381-validation/review.html`，相机 `stable-environment/environment-camera-poses.json`，评估 `visual-review.md`。
- 冻结包13项功能测试全部通过，含建筑双向通行/碰撞、单机流程、108样本瞄准、武器遮挡与第三人称换弹规则；73项构建输入及测试前后包哈希一致。验证控制进程曾被SIGTERM中断，未登记测试已重跑；两组截图均有完成标记，但第二组子进程退出码未知，未伪记成功。证据 `artifacts/realism381-validation/final-verification.json`、`stable-verified/` 与 `stable-capture-process-audit.json`。软件Vulkan截图不代表硬件性能。
- 当前可运行本地预览 `./artifacts/realism381-preview/Linux/launch.sh`（需图形环境与Vulkan，保留相邻二进制/PCK）。未推送、未外部发布；本轮未运行联网验证，整体目标未完成。
- 下一步：优先改进正常宽景中的树冠轮廓、灌木团块和地表层次，处理入口灯具遮光/方向；随后完成第三人称3米/10米及第一人称主要武器手部、ADS和换弹实机审阅，并用隔离本地配置验证双客户端加入、同步、伤害及重生。详见 `artifacts/realism381-validation/next-stage.md`。

### Stage382：维修棚条灯、入口植被与地坪距离细节（2026-09-18）
- 将维修棚三个聚光源改为实体条形灯及柔和点光源，减少墙面硬锥形亮区；降低入口草丛高度和密度、挪开两处灌木；弱化混凝土切缝和远距裂纹，增加近景骨料。脱离墙体的排水管候选已撤回，未计入最终包。保留所有既有未提交修改。
- 已直接审阅入口、侧面、车间与宽幅地形四组同机位实机对照，相机位置与朝向逐项一致。墙光连续性和宽景切缝改善可见，车间画面几乎无变化；骨料仍呈重复碎斑，树冠重复、山体平滑及建筑积木感未解决。证据 `artifacts/realism382-validation/review.html`、`visual-review.md`、`stable-environment/environment-camera-poses.json`。
- 最终冻结包13项功能测试全部通过，包括建筑通行/碰撞、单机流程、108样本瞄准、武器遮挡和第三人称换弹规则；两组截图退出码均0，73项构建输入/产物哈希一致，测试前后PCK一致（81c10ddf8f002667a8c4057ef61b7dc1f97c515f6bed4776fdebcd6b4e49f652）。见 `artifacts/realism382-validation/final-verification.json`、`stable-verified/`。软件Vulkan截图不证明硬件帧率。
- 本地预览 `./artifacts/realism382-preview/Linux/launch.sh`（需图形环境及Vulkan，保留相邻二进制/PCK）。人物stage381基线四张静态截图退出0；第一人称基线仅持枪及ADS，进程退出143，换弹未完成，不能当作本阶段人物改进或动作验收。本轮未验证联网主要功能；未推送、未外部发布，整体状态continue。
- 下一完整stage383遵循最新环境优先级文件：实质修改Blender人物源模型、第一人称袖管/肘部形体与握持姿态，重新导出并补齐三把武器射击、ADS相机记录和换弹关键序列；用不读取既有密钥的隔离本地配置补验联网加入、同步、伤害及重生。不得再以环境细节替代人物形体阶段。详见 `artifacts/realism382-validation/next-stage.md`。

### Stage383 检查点：人物袖管形体、冻结预览与回归（2026-09-18，动作验收未完成）
- 按最新优先级修改 `tools/build_operator.py`、`tools/build_viewmodel.py` 并重新导出 Blender/GLB：调整上臂/前臂截面、肘褶和袖口收束，保持骨架长度与握枪锚点。静态对照可见局部轮廓改善，但面部面罩感、护具简化、袖管长直及布料结构仍未解决，不是整体目标完成。
- 四张第三人称3米/10米正侧面采集退出0、同机位记录一致；已直接审阅人物图、第一人称持枪和ADS前后图。证据 `artifacts/realism383-validation/review.html`、`visual-review.md`、`operator-camera-comparison.json`、`sleeve-camera-comparison.json`。换弹基线左臂呈粗弯管状，尚不能判断新模型修复。
- 冻结包16项规则/通行/单机测试全部通过，覆盖建筑入口碰撞、单机流程、108样本瞄准、968样本前臂规则、三枪换弹接触及武器遮挡。74项源/产物哈希一致，测试前后PCK一致。证据 `artifacts/realism383-validation/final-verification.json` 与 `stable-verified/functional-results.json`。
- 本地预览 `./artifacts/realism383-preview/Linux/launch.sh` 已导出并用于实机采集（需要图形环境与Vulkan）。软件Vulkan不证明硬件帧率；联网主要流程本轮未验证。未推送、未发布，保留既有修改，整体continue。
- 三个采集仍运行，未验收：before-sleeve PID3541379、after-sleeve PID3548463、三枪action-timeline PID3566628；其partial不能算通过。下一轮先续接现有进程、补齐换弹前后与三枪实际动作审图及退出状态，勿并发重复启动；随后优先面部、弯肘裁片/袖口、装备材质分离，并补受用户约束的隔离联网验证。详见 `artifacts/realism383-validation/next-stage.md`。本记录不是完整stage383动作通过声明。

### Stage384 检查点：换弹结构复核与采集失败记录（2026-09-18，整体继续）
- 接续383实际文件与最新人物优先级；旧采集进程已不存在，partial不算完成。直接审阅383换弹中段前后实机图并核对同机位：左袖粗弯管问题仍在；定位整段上臂/肘袖绑定Forearm的结构嫌疑，尚未修复验证。对照为历史图拼接，本轮没有新模型画质成果。
- 为 tests/sleeve_pose_review_capture.gd 增加指定帧筛选，新增 tools/run_sleeve_pose_review.py，要求退出码、完整审计及目标截图共同通过，记录超时并清理进程。编译与真实进程1秒超时失败路径检查通过，无进程组残留；成功截图路径仍待验证。
- 正式换弹完成帧采集600秒超时退出-15，无新增截图；保留日志和机位。七项功能最终通过：瞄准、遮挡、第三人称换弹、换弹接触、前臂规则、单机冒烟、维修棚碰撞/通行；维修棚首次150秒超时，独立复测147.22秒退出0。联网仍未验证。
- 证据 artifacts/realism384-validation/review.html、final-verification.json、reload-comparison.png、workshop-retry/west-workshop-traversal.json。当前本地预览仍为 ./artifacts/realism383-preview/Linux/launch.sh，EXE/PCK哈希与383相同，未重新导出或发布。
- 下一步优先完成肩部锚定及独立上臂/肘袖变形，并取得同机位ADS、换弹中段/结束和三枪动作完整采集；之后继续人物面部、装备与环境剩余缺陷及隔离联网主要功能验证。不能以本轮验证工具改进代替画质目标完成。

### Stage385 检查点：建筑入口、针叶植被与环境对照（2026-09-18，整体继续）
- 按本轮环境优先要求增加维修间折边金属门框与上沿（净宽3.8米），调整棚内补光、地表微噪声，并重新生成更紧凑的Blender针叶树。正常机位树冠较连贯，近景门框深度可辨；地表白色碎斑仍明显、照明改善有限，不能视作整体画质完成。
- 冻结383/385使用相同采集脚本，完成并直接审阅正常接近、建筑入口近景、宽幅地形三组实机前后对照；相机位置/朝向完全一致，六张1280×800图片与生产文件哈希已审计。证据 artifacts/realism385-validation/review.html、visual-review.md、camera-image-audit.json。
- 单机16角色冒烟、108样本瞄准、武器遮挡通过；门框碰撞及双向通行按新13.60/17.40边界修正外部测试后通过。道路首测300秒超时，独立复测退出0，站立/蹲伏/机器人双向进出通过。维修棚实际路线通过，但六个旧固定树干探针和一个树冠/屋顶AABB仍失败，在383基线复现同样七项；不宣称综合碰撞全通过。原始失败与复测见 final-verification.json、baseline-comparison.json、frame-recheck/、lane-recheck/。
- 当前本地可运行预览 ./artifacts/realism385-preview/Linux/launch.sh，已用于上述游戏截图；首次导入清理错误保留，重试导入/导出成功。软件Vulkan不证明硬件性能，联网本轮未验证。未推送或发布，保留已有修改，整体continue。
- 下一步定位白色碎斑的实际网格/材质并改善地表与灌木密度层次；核对真实树干碰撞和屋顶枝叶间距，修复旧探针及必要场景问题。随后结合第三人称与第一人称实机审阅继续面部、袖管弯肘和换弹动作缺陷，并完成受约束的联网主要功能验证，不以截图数量判定完成。

### Stage386 检查点：地表碎斑、灌木层次与入口可读性（2026-09-18，整体继续）
- 替换路面噪声哈希并降低碎粒颜色/法线强度，减少维修棚树下灌木及路肩阔叶密度、高度；提高入口补光和门板亮度。实机正常接近、入口近景与宽幅地形都可见白色方块碎斑减少、路面更连续、树下通道更清楚；建筑照明改善温和，未进行建筑整体重建。
- 完成并直接审阅冻结385与386三组相同机位前后图，相机位置/俯仰/偏航完全一致；六张1280×800图片及生产文件SHA256已审计。证据 artifacts/realism386-validation/review.html、visual-review.md、camera-image-audit.json；before来源记录在 baseline-provenance.json，after保存实机采集日志与完整机位。
- 仍有黑色扁碎石、灰白地面大块直线过渡、重复针叶树及简化棚顶；第一人称袖管和第三人称人物完整目标保留。下一步先定位碎石实际网格并改善地面过渡，核对真实树干接触与屋顶枝叶间距；随后结合人物与手部实机审阅处理面部/装备、肩肘袖管与换弹，并完成隔离联网主要功能验证。
- 最终验证：门框36项、道路站立/蹲伏/机器人双向通行、108样本三枪瞄准、武器遮挡与单机冒烟通过；维修棚综合23/30通过，六个固定树干探针及一个树冠/屋顶AABB失败与385完全一致，未宣称碰撞全通过。functional-results.json、baseline-comparison.json 和原始日志可复核；总测试进程因七项已知失败退出1。
- 当前本地预览 ./artifacts/realism386-preview/Linux/launch.sh 已完成导出并用于全部新截图；final-verification.json 确认源码、截图与测试PCK哈希一致。联网本轮未验证，软件Vulkan不证明硬件性能。未推送或发布，保留已有未提交修改，整体continue。

### Stage387 检查点：地表补修带与碎石色调收敛（2026-09-18，整体继续）
- 调整维修棚两组碎石色调，入口混凝土补修带共享周围底色并减弱深色接缝。实机淘汰了过亮白色碎石方案，保留在 artifacts/realism387-validation/rejected-bright-gravel/；最终收益温和，建筑与光照无明显提升，未达到整体环境目标。
- 直接审阅正常接近、入口近景、宽幅地形三组同机位前后图；before继承冻结386实机图，after由387预览新采集。机位位置/朝向、六张1280×800图片及哈希见 camera-image-audit.json；对照与局限见 artifacts/realism387-validation/review.html、visual-review.md、baseline-provenance.json。
- 门框36项、道路站立/蹲伏/机器人双向通行、三枪108项瞄准、武器遮挡、单机冒烟通过。维修棚综合仍23/30通过，六个树干探针和一个树冠/屋顶AABB失败与386一致；总测试退出1，未宣称碰撞全通过。证据 functional-results.json、baseline-comparison.json 与原始测试日志。
- 当前可运行预览 ./artifacts/realism387-preview/Linux/launch.sh；final-verification.json 已核对冻结源码、截图及测试PCK一致。联网本轮未复测，软件Vulkan不证明硬件性能。保留未提交修改，未推送或发布，整体continue。
- 下一步优先独立验证可见树干与玩家碰撞、检查屋顶实际枝叶接触并修复必要几何；改变重复植被轮廓、扁平碎石和大块地面过渡，不再仅靠亮度微调。之后继续第三人称面部/装备、第一人称肩肘袖管和换弹实机审阅，并补充联网主要流程验证；详见 artifacts/realism387-validation/next-stage.md。

### Stage388 检查点：雨棚枝叶间距、排水构件与树旁通行（2026-09-18，整体继续）
- 将维修棚右侧针叶树后移，树冠AABB不再与雨棚相交；增加折边雨槽、落水管和固定环，提高三块碎石体积。正常机位可见棚顶露出和石块轮廓变化，但建筑构件占比较小、入口观感基本相同，未达到整体环境改善目标；本轮没有升级全局光照。
- 直接审阅正常接近、建筑入口近景、宽幅地形三组同机位前后实机图。before继承冻结387图，after由388预览新采集；位置/朝向、图片哈希及来源见 artifacts/realism388-validation/review.html、camera-image-audit.json、baseline-provenance.json 和 after/environment-camera-poses.json。
- 七项回归全部通过：雨棚、维修棚、门框、道路通行，三枪108项瞄准，武器遮挡，16角色单机冒烟。维修棚32/32含新树位玩家阻挡与侧面绕行；七个树干探针按实际坐标/缩放修正，不能将旧探针失配计作六处实体碰撞修复。可见树皮与圆柱碰撞仍有间隙。证据 functional-results.json、原始日志及 visual-review.md。
- 当前本地可运行预览 ./artifacts/realism388-preview/Linux/launch.sh，已用于新截图；final-verification.json 确认冻结源码、采集和测试包哈希一致。联网本轮未复测，软件Vulkan不证明硬件性能。保留全部未提交修改，未推送或发布，整体continue。
- 下一步优先消除宽幅机位中的地面直线拼接、重复针叶树轮廓及稀疏林下层次，并做专门光照对照；校准可见树干接触。随后继续第三人称面部/装备、第一人称肩肘袖管和换弹实机审阅，补充联网主要功能验证。详见 artifacts/realism388-validation/next-stage.md。

### Stage389 检查点：混合树种、林下落地与建筑日照（2026-09-18，整体继续）
- 维修区两株重复针叶树改用既有阔叶树资产，林下植被按地形高度落地；调整太阳方向/能量和环境光，在正常接近、入口与宽幅图中可见树冠轮廓和建筑投影变化。道路肩部增加泥土过渡与边界扰动。建筑本体几何未升级，不能将本轮视作整体写实目标完成。
- before继承冻结388实机图，after由389预览重新采集；直接审阅三组同机位前后图，含入口近景和宽幅地形。位置/朝向、1280×800原图、哈希与来源见 artifacts/realism389-validation/review.html、camera-image-audit.json、baseline-provenance.json、after/environment-camera-poses.json；审阅结论见 visual-review.md。
- 七项回归全部通过：雨棚、道路、维修棚（32/32）、门框通行，瞄准对齐、武器遮挡、单机冒烟。证据 functional-results.json 与对应日志。初次地形高度函数参数错误造成编译及测试失败，日志保留 initial-failed/；已修复并重新导出、截图及测试，最终日志无ERROR，未隐瞒失败记录。
- 当前本地预览 ./artifacts/realism389-preview/Linux/launch.sh；final-verification.json 确认源码/测试脚本/预览与截图采集包哈希一致。联网本轮未复测，软件Vulkan不证明硬件帧率。保留全部未提交修改，未推送或发布，整体continue。
- 局限与下一步：宽幅道路斜直线接缝仍明显，入口地坪过平净，远景和叶片细节仍弱；优先做正常机位可辨识的建筑实际形体/材质与铺地连续性改进，继续混合植被层次，专门校准可见树皮和圆柱碰撞。随后保留第三人称面部/装备、第一人称袖管/手部/换弹实机审阅及联网主要流程验证。详见 artifacts/realism389-validation/next-stage.md。

### Stage390 检查点：入口连接、路缘灌木与地坪接缝（2026-09-18，整体继续）
- 补充维修棚梁柱斜撑与连接板、三组路缘灌木；删除道路前景斜向接缝，保留横向施工缝；混凝土噪声改为稳定哈希，降低入口和棚内补光。旧版已有斜撑，整体建筑轮廓变化有限，不能视作整体环境目标完成。
- 三组实机同机位前后图已审阅（道路接近、建筑入口、宽幅地形）。before沿用冻结389原图，after由390预览新采集；相机位置/朝向逐字段一致。证据：artifacts/realism390-validation/review.html、camera-image-audit.json、baseline-provenance.json、visual-review.md，原图在 before/、after/。
- 七项回归全部通过：雨棚、道路（站立/蹲伏/机器人双向）、维修棚、棚架通行，瞄准对齐108样本、武器遮挡、单机冒烟（16角色及换弹/治疗/伤害/胜利等）。日志与 functional-results.json、final-verification.json 在同目录；最终导入/导出/截图/测试日志ERROR为0，源码、测试及预览哈希匹配。
- 本地可运行预览：./artifacts/realism390-preview/Linux/launch.sh。联网本轮未复测，软件Vulkan截图不证明硬件帧率；保留全部未提交修改，无推送或外部发布，整体continue。
- 局限与下一步：地坪仍过平滑、污渍人工感和裸土边界生硬，树冠碎点及远景简化明显；下一阶段处理正常道路机位可见的成片地表/植被层次，不再只微调斜撑或灯光。继续校准树皮与碰撞，并安排第三人称面部/装备、第一人称袖管/换弹手部和联网主流程验证。见 artifacts/realism390-validation/next-stage.md。

### Stage391 检查点：维修区地表过渡与路肩植被（2026-09-18，整体继续）
- 地坪边缘增加渐变覆盖，路肩草带按实际道路曲线重新分布，增加采样与阔叶比例并降低靠路侧高度；保留入口和装卸通道留空。正常接近及宽幅前景的土壤硬切边减轻，但改进有限；建筑形体和灯光沿用390，不能宣称环境或整体画质目标完成。
- 已直接审阅三组同机位前后实机图，包含道路接近、建筑入口近景、宽幅地形。before冻结390图，after使用391预览新采集；位置/朝向逐字段一致。证据：artifacts/realism391-validation/review.html、camera-image-audit.json、baseline-provenance.json、visual-review.md；原图在 before/、after/。
- 七项回归全部通过：雨棚、道路、维修棚和棚架通行，三枪108项瞄准、武器遮挡、单机冒烟（16角色及换弹/治疗/伤害/胜利等）。首轮测试进程在维修棚阶段退出143，原因未知；保留 interrupted/ 原始记录，续跑未完成项目后正常退出0。最终日志ERROR为0，源码/测试/预览哈希一致；见 functional-results.json、final-verification.json 与原始日志。
- 当前本地可运行预览：./artifacts/realism391-preview/Linux/launch.sh，已用于实机截图。联网本轮未复测，软件Vulkan不证明硬件帧率；保留全部未提交修改，未推送或外部发布，整体continue。
- 下一步：优先改善宽幅图右侧针叶树碎片树冠与轮廓，核对树冠/屋顶实际几何穿插及可见树皮/玩家胶囊接触，不能仅用AABB或复制碰撞半径自证。继续建筑窗洞深度、材质尺度与入口光照；保留第三人称面部/装备、第一人称袖管/手部/换弹和联网主流程验证。详见 artifacts/realism391-validation/next-stage.md。

### Stage392 检查点：维修棚门轨、林下覆盖与入口补光（2026-09-18，整体继续）
- 增加推拉门双轨、四组吊杆/滚轮，夹丝玻璃抗锯齿并降低基础不透明度；调整入口和棚内补光，右侧林下增加三处不规则阔叶/草覆盖。入口近景门轨构造更清楚；玻璃、光照及宽幅植被变化较弱，不将局部改善视为整体目标完成。
- 已实机审阅道路接近、建筑入口近景及宽幅地形三组同机位对照：before 冻结391原图，after 为392预览运行新截图，1280×800，相机位置/朝向逐字段一致。证据：artifacts/realism392-validation/review.html、camera-image-audit.json、baseline-provenance.json、visual-review.md；原图在 before/、after/。
- 七项回归全部通过且退出0：雨棚、道路、维修棚与棚架通行/阻挡，三枪108项瞄准、武器遮挡、单机冒烟（16角色，换弹/治疗/伤害/胜利/射线/掩体/射击间隔/骨架）。导入、导出和截图运行成功；最终日志ERROR为0，源码/测试/预览哈希一致。见 artifacts/realism392-validation/final-verification.json、functional-results.json 和各原始日志。
- 当前本地可运行预览：./artifacts/realism392-preview/Linux/launch.sh，已用于实机截图。本轮未复测联网，软件Vulkan截图不证明硬件帧率；保留全部未提交修改，未推送或外部发布，整体continue。
- 下一步优先修复宽幅机位针叶树碎片树冠，校准真实树皮表面与玩家胶囊接触，改善道路/入口地坪过平净及材质尺度；继续第三人称面部/装备、第一人称袖管/手部/换弹实机审阅及联网主要功能验证。详见 artifacts/realism392-validation/next-stage.md，不能继续以门轨或灯光微调替代主要缺陷。

### Stage393 检查点：冷杉碎片轮廓改善及环境回归（2026-09-18，整体继续）
- 重建Blender冷杉，调整针叶分层采样、尺寸与枝梢覆盖；正常道路接近和宽幅机位树冠更完整、裸枝碎点减少。仍有规则水平枝层；建筑和灯光沿用392，地坪平净、材质重复及袖管圆筒感未解决，不宣称整体完成。网格增至633068多边形、2532272顶点，性能成本未实测。
- 已直接审阅三组同机位前后实机图，覆盖道路接近、维修棚入口、宽幅地形；before冻结392原图，after由393导出预览新采集。1280×800、相机位置与朝向逐字段一致。证据：artifacts/realism393-validation/review.html、camera-image-audit.json、visual-review.md；原图在before/、after/。
- 七项回归全部通过且退出0：雨棚、道路、维修棚与棚架通行/阻挡，三枪108项瞄准、武器遮挡、单机冒烟（16角色及换弹/治疗/伤害/胜利/射线/掩体/射击间隔/骨架）。源码/测试/预览哈希匹配，见functional-results.json和final-verification.json。
- 日志审计保留一条导入错误：import.log:31 `Parameter "t" is null`，位于Godot dummy渲染器texture_2d_get；导入继续完成，导出、截图及七项测试日志未发现ERROR。根因未独立定位，不记录为全流程零错误。
- 当前本地可运行预览：./artifacts/realism393-preview/Linux/launch.sh，已用于实机截图。本轮未复测联网，软件Vulkan不证明硬件帧率；树干碰撞未改，建筑通行通过不证明树皮碰撞贴合。保留全部未提交修改，未推送或外部发布，整体continue。
- 下一步：改善冷杉枝层空间分布和LOD，独立采样树皮截面核对玩家胶囊接触及树冠/屋顶实际穿插，避免继续只增加针叶数；继续地坪覆盖/尺度与建筑材质、人物和手臂动作实机审阅、联网主流程与硬件性能验证。详见artifacts/realism393-validation/next-stage.md。

### Stage394 检查点：打散冷杉枝层并修复棚顶间距回归（2026-09-18，整体继续）
- 重建冷杉GLB、Blender源文件和远景图，打散枝条高度、俯仰、长度及方向，减少针叶密度。正常道路接近及宽幅机位的水平层叠感减弱，仍有程序化轮廓和针叶颗粒感；入口近景收益很小。网格从633068降到430712多边形（约32%），不是帧率收益。本轮未改善建筑大面、地坪或光照，不将树冠调整视为环境整体要求完成。
- 首次维修棚回归发现第一棵院边树的变换网格包围盒与棚顶在Z方向重叠约0.01105米；这是保守包围盒判定，非已证实三角面穿插。将树从(22.4,0.02,42.0)移到(22.4,0.02,42.25)，相关碰撞和树下植物随移，测试射线同步，未放宽断言。保留首次失败与截图：artifacts/realism394-validation/attempt1-before-clearance-fix/。
- 已人工审阅最终包三组实机前后图：道路接近、维修棚入口、宽幅院落及局部远山；before冻结393原图，after为394新截图。宽幅画面的地坪平净、灌木重复和建筑材质尺度仍明显，袖管圆筒感未解决。详见artifacts/realism394-validation/visual-review.md。
- 最终七项回归全部通过且退出0：雨棚、道路、维修棚及棚架通行/阻挡，三枪108项瞄准，武器遮挡，单机冒烟（16角色及换弹/治疗/伤害/胜利/射线/掩体/射击间隔/骨架）。三组1280×800机位位置/朝向逐字段一致，源码、测试、资源及预览散列核对通过。证据：artifacts/realism394-validation/review.html、camera-image-audit.json、functional-results.json、final-verification.json和各原始日志。
- 当前本地可运行预览：./artifacts/realism394-preview/Linux/launch.sh，已用于最终实机截图。缺少Linux导出模板，标准发布导出失败保留在export-release-attempt.log；采用已有Godot4.4.1可执行文件加导出PCK。导入退出0但保留一条dummy texture的`Parameter "t" is null`错误，根因未定位；最终导出、截图和七项测试日志无ERROR。
- 本轮未复测联网；软件Vulkan不证明硬件帧率，建筑通行和树心射线不证明树皮碰撞贴合。保留全部未提交修改，未推送或外部发布，整体continue。下一步优先道路/入口地坪覆盖与尺度、地表植被重复、建筑大面材质和光照关系，避免再次整轮只调针叶；随后继续第三人称人物、第一人称手臂及三枪动作实机审阅、联网主流程和硬件性能验证。详见artifacts/realism394-validation/next-stage.md。

### Stage395 — 正常游戏机位的日照、路肩与维修棚饰面阶段（2026-09-18）
- 调整日照角度和 Forward+ 环境光；维修棚墙面加入旧涂装分区，道路加入局部浇筑色差，七组路肩灌木改变冠幅、高度及底层疏密。实机主要收益是前场与道路出现清晰斜向树影；建筑饰面和地表变化仍偏轻，不能视为环境整体完成。
- 保存 stage394 原图来源与散列、本轮相同三个机位的前后对照、入口近景和宽幅地形；逐图审阅见 `artifacts/realism395-validation/visual-review.md`，对照页 `comparison.html`，位置/朝向及1280×800尺寸核对见 `camera-image-audit.json`（通过）。
- 冻结预览上七项回归全部通过：depot_canopy/service_lane/repair_shelter/shelter_frame 通行与阻挡、aim_alignment 三枪瞄准、weapon_obstruction_rules、offline-smoke（16 actors、换弹/治疗/伤害/胜利/射线/掩体/射速/骨架）。日志与结果见同目录 `functional-results.json`；`final-verification.json` 确认截图输入哈希一致、七项通过且扫描日志无 ERROR。
- 本地预览：`artifacts/realism395-preview/Linux/launch.sh`。本轮导出新 PCK，复用已验证的 Godot 4.4.1 可执行文件（本机缺少 Linux 导出模板），已使用该组合生成实机截图。软件 Vulkan 截图不能证明硬件可玩帧率。
- 本轮未复测依赖认证的联网流程；树皮胶囊精确接触、树冠与棚顶三角面间距、第三人称人物与第一人称手臂动作审阅仍待完成。保留所有未提交修改，无推送、发布或服务修改；状态 continue。
- 下一步：按 `artifacts/realism395-validation/next-stage.md`，优先检查正常机位可见建筑网格的材质绑定，改善大面墙材质尺度、门窗收口及地面接缝，继续降低宽幅植被与地表重复；随后衔接人物/手部实机审阅及联网验证，不回到只做武器微调。


### Stage396 — 维修棚墙板材质绑定、收口与入口轮迹（2026-09-18，整体继续）
- 修复维修棚后墙使用屋面材质造成的大面失真，改为世界米制板缝、浅色上墙和绿色下墙，加入折边、墙脚泛水及出口门框收口，保留2.6米出口净宽；入口地面增加渐隐泥土轮迹。近景可辨识，但上墙仍过于均匀、砖纹重复，宽幅收益有限。本轮未调整植被或光照，不把此局部阶段视为整体环境完成。
- 已人工审阅三个相同机位的 stage395 前图与 stage396 实机后图：道路接近、维修棚入口、宽幅院落及局部远山。证据位于 `artifacts/realism396-validation/`：`comparison.html`、`visual-review.md`、`before/`、`after/`；`camera-image-audit.json` 核对位置、朝向与1280×800尺寸全部一致。宽幅机位不足以代表整张地图，下一阶段增加开阔道路地形机位。
- 七项回归全部通过且退出0：雨棚、道路、维修棚、棚架通行及阻挡，三枪108项瞄准，武器遮挡，单机冒烟（16角色、换弹、治疗、伤害、胜利、射线、掩体、射速、骨架）。原始日志及 `functional-results.json` 已保存；`final-verification.json` 确认截图输入仍与源码及预览匹配，扫描日志无ERROR，环境阶段验证通过。
- 当前本地可运行预览：`artifacts/realism396-preview/Linux/launch.sh`，已用于本轮实机截图与测试。采用新导出的PCK和已有已验证Godot4.4.1可执行文件（本机缺少Linux导出模板）；导入、导出均退出0。软件Vulkan截图不证明硬件帧率。
- 本轮未复测联网。树皮胶囊精确接触、树冠与棚顶三角面间距、第三人称人物和第一人称手臂动作审阅仍待完成；截图中的袖管圆筒感仍明显。保留全部未提交修改，无推送或外部发布，整体状态continue。
- 下一步：按 `artifacts/realism396-validation/next-stage.md` 增加开阔道路机位，改善地形起伏、排水与土壤过渡、植被层次和重复轮廓，继续建筑材质尺度及光照审阅；再衔接人物、手部与联网主流程验证。


### Stage397 — 维修棚入口浅排水沟与路肩衔接（2026-09-18，整体继续）
- 新增两条约9米混凝土浅沟，将地形、植被根部及碰撞高度同步过渡。初版19厘米沟沿实际阻挡角色，降低至12厘米并减缓坡面后重新导出和验证；失败日志保留在 `artifacts/realism397-validation/service-lane-steep-lip-failed.log`。本轮未调整光照或重做树冠，不能视为环境整体完成。
- 已人工审阅 stage396/397 四组同机位实机前后图，含建筑入口近景、宽幅院落及新增道路远山机位。`artifacts/realism397-validation/comparison.html`、`visual-review.md`、`before/`、`after/` 保存证据；两份 `environment-camera-poses.json` 记录位置与朝向，`camera-image-audit.json` 确认1280×800和机位一致。入口左侧构造更明确，但宽幅收益很小，前场发白、路面补丁尺度重复、树冠颗粒与轮廓重复仍突出，右沟槽与植被关系仍需近查。
- 最终预览七项检查全部退出0并通过：雨棚、道路、维修棚、棚架通行与阻挡，三枪108项瞄准，武器遮挡，单机冒烟。道路含站立、蹲伏和机器人双向路线。`functional-results.json` 和各原始日志保存结果；`final-verification.json` 确认前后截图成功、最终截图输入仍匹配预览、日志无ERROR，阶段验证通过。
- 当前本地可运行预览：`artifacts/realism397-preview/Linux/launch.sh`。本机缺少Linux导出模板，使用已有Godot4.4.1可执行文件与新导出的PCK；本轮截图和全部回归实际使用该组合。软件Vulkan截图不能证明硬件帧率。
- 未复测联网；第三人称人物、第一人称手臂动作、袖管圆筒感、树皮精确碰撞及树冠与棚顶间距仍未解决。保留所有未提交修改，无推送、外部发布或服务修改；整体状态continue。
- 下一步：按 `artifacts/realism397-validation/next-stage.md`，优先改善正常宽幅机位中大面积地表的明暗、土壤过渡与路面补丁尺度，降低树冠颗粒和重复轮廓，并继续入口植被相交与建筑材质尺度审阅；随后衔接人物、手部及联网主流程验证。

### Stage398 — 道路重复修补与路肩地表衔接验证（2026-09-18，整体继续）
- 道路规则网格修补改为五处稀疏不规则修补，调整路肩湿土与草地碎石衔接；续完冻结预览验证。正常道路远景中成对重复的大补丁明显消除，但入口及宽幅院落收益有限，路面仍偏平滑、前坪偏浅、树冠颗粒与重复轮廓明显。本轮未新增建筑几何或照明调整，不能视为环境整体完成。
- 保存并审阅四组同机位前后实机图，包含建筑入口近景、宽幅地形和道路远景：`artifacts/realism398-validation/comparison.html`、`visual-review.md`、`before/`、`after/`。两份 `environment-camera-poses.json` 记录位置与朝向；`camera-image-audit.json` 确认四组机位与1280×800尺寸一致。前图来源保留在 `before-provenance.txt`。
- 最终预览七项检查全部通过且退出0：雨棚、服务通道、维修棚和入口框架通行/阻挡，瞄准对齐，武器近墙遮挡，单机冒烟。结果与原始日志见 `functional-results.json` 及同目录日志；`final-verification.json` 核验截图输入仍匹配、包内三份地表着色器与源码一致，扫描日志无ERROR。验证通过只表示本阶段回归通过。
- 当前本地可运行预览：`artifacts/realism398-preview/Linux/launch.sh`；新PCK配合已有Godot4.4.1可执行文件（缺少Linux导出模板），已实际用于截图和七项测试。软件Vulkan截图不能证明硬件帧率；本轮未复测联网，不作联网通过结论。
- 保留全部未提交修改，无推送、外部发布或服务修改，整体continue。下一阶段按 `artifacts/realism398-validation/next-stage.md` 优先推进宽幅植被分组、树冠轮廓和建筑受光，继续入口材质尺度及植被相交检查，不能再只做小幅地表着色；随后审阅第三人称肩肘、第一人称手臂动作与袖管，并完成联网主流程及剩余碰撞验证。

### Stage399 — 维修棚林带层次、雨棚折边与局部照明（2026-09-18，整体继续）
- 调整服务通道林带的幼树/高树比例与树冠宽度，地表植被贴合地形，并增加三处低矮再生植被；维修棚雨棚增加折边与两处局部照明。四组正常游戏机位审阅显示树群高低层次改善较明显，建筑和照明收益有限；大面积浅色前坪、针叶树稀薄轮廓、远景空旷及袖管失真仍未解决，不能视为环境或整体写实目标完成。
- 四组相同机位前后实机图（含入口近景、宽幅地形）见 `artifacts/realism399-validation/comparison.html`、`before/`、`after/`，位置、目标和朝向见两目录的 `environment-camera-poses.json`；审阅结论与来源见 `visual-review.md`、`before-provenance.txt`。`final-verification.json` 确认机位一致、截图所用可执行文件/PCK未变及日志无ERROR；图片差异不代表画质通过。
- 最终七项回归全部通过：雨棚、服务通道、维修棚和入口框架通行/阻挡，瞄准对齐、武器近墙遮挡及单机冒烟。维修棚首次失败为测试沿用旧树尺度预期，已更新三处预期并复测通过；初次完整结果和失败原始记录保留在 `initial-functional-results.json`、`repair-shelter-stale-expectation.json/.log`，最终结果见 `functional-results.json` 及各测试日志。树干半径检查不等价于可见树皮精确碰撞，另一组树的屋顶包围盒检查也不覆盖本轮林带树冠。
- 当前本地可运行预览：`artifacts/realism399-preview/Linux/launch.sh`。缺少Linux导出模板，使用已有Godot4.4.1可执行文件与新导出PCK，实际用于本轮截图和测试；软件Vulkan不代表硬件帧率。本轮未复测联网及人物/手部动作，不作通过结论。
- 下一步见 `artifacts/realism399-validation/next-stage.md`：优先处理宽幅画面的大面积浅色前坪、针叶树覆盖率与建筑材质尺度，直接检查林带树冠/建筑及树皮碰撞；随后衔接第三人称肩肘、第一人称默认/ADS/换弹动作与双客户端联网主流程。保留所有未提交修改，无推送、外部发布或服务修改，整体状态continue。

### Stage400 — 冷杉枝叶覆盖与前坪磨蚀实机审阅（2026-09-18，整体继续）
- 同多边形预算下增加针叶尺寸和小枝覆盖，重新生成模型与远景贴图；前坪增加不规则磨蚀色差。四组实机对照可辨认树冠覆盖改善，前坪收益很小。未新增建筑几何或修改照明，薄片檐口、均匀砖墙、空旷道路与平坦远山仍明显，本轮不构成环境整体达标。
- 对照及逐图审阅：`artifacts/realism400-validation/comparison.html`、`visual-review.md`。before沿用stage399已验证after原图，来源见 `baseline-provenance.txt`；after本轮重新截图。前后 `environment-camera-poses.json` 保存位置和朝向且完全一致，包含入口近景、院落宽幅及道路远景。
- 七项功能回归全部通过：四项建筑/通道通行与阻挡、瞄准对齐、武器遮挡、单机冒烟，结果见 `functional-results.json` 和原始日志。最终审计确认截图成功且包哈希仍匹配，但 `import.log:31` 有 dummy renderer `Parameter "t" is null`；导入退出0，原因未确认，故 `final-verification.json` 的阶段通过标记为false。保留该错误，不宣称日志无ERROR或完整验证通过。
- 当前本地可运行预览：`artifacts/realism400-preview/Linux/launch.sh`，已有Godot4.4.1可执行文件配新PCK（本机缺少Linux导出模板），实际用于本轮截图及七项测试。软件Vulkan不能证明硬件帧率；未复测联网、人物及手部动态，树皮精确碰撞仍需验证。
- 下一步见 `artifacts/realism400-validation/next-stage.md`：先调查导入错误，再实质改善建筑入口构件/材质尺度及室内外明暗、道路与远景层次；随后衔接第三人称、第一人称动作和双客户端联网主流程。保留全部未提交修改，无推送、发布或服务修改，整体continue。

### Stage401 — 维修棚入口构件、压顶材质与定向照明（2026-09-18，整体继续）
- 移除入口重复砖座和重叠斜撑，为保留斜撑补碰撞；增加砖色变化与压顶石材着色器，调整室内定向灯和草丛高度。正常游戏机位可辨识入口轮廓简化，草丛和灯光收益有限；道路空旷、浅色前坪、规则砖材与后墙偏亮仍明显，未达到整体写实目标。
- 四组相同机位前后实机对照含入口近景、宽幅地形和道路远景：`artifacts/realism401-validation/comparison.html`、`before/`、`after/`；位置、朝向和目标记录在前后 `environment-camera-poses.json`。before沿用stage400已验证after原图，来源见 `baseline-provenance.txt`；逐图结论见 `visual-review.md`。
- 七项回归全部通过：四项建筑/通道通行与阻挡、瞄准、武器近墙遮挡和单机冒烟。入口两条路线双向通过、砖柱阻挡、两处斜撑射线命中均通过；原始日志与 `functional-results.json`、`final-verification.json` 保存证据。审计确认机位一致、截图包散列未变，本轮日志无ERROR。stage400 dummy renderer空纹理错误在本轮Vulkan导入未复现，不能声称根因修复。
- 本地可运行预览：`artifacts/realism401-preview/Linux/launch.sh`，已有Godot4.4.1引擎配本轮新PCK，实际用于截图和测试。本机缺Linux导出模板，软件Vulkan不代表显卡帧率；联网、人物和手部动态本轮未复测，树皮精确碰撞仍待验证。
- 下一步见 `artifacts/realism401-validation/next-stage.md`：优先改变前坪与路缘空间层次、成片地被和排水/磨损过渡，避免继续仅调微小色差；随后衔接第三人称肩肘、第一人称默认/ADS/换弹及双客户端联网主流程。保留所有未提交修改，无推送、发布或后台服务修改，整体continue。

### Stage402 — 维修棚前坪成片地被与铺装过渡（2026-09-18，整体继续）
- 增加入口通道外侧不规则低矮草群，压暗铺装并扩大草土过渡，降低维修棚灯能量。本轮没有新增建筑几何；正常接近机位可见草土边缘更连续，但入口亮墙改善很小，道路远景几乎未变，平坦前坪、规则砖材和简单远山仍明显，不以局部改善宣称整体完成。
- 四组固定机位前后实机截图、建筑入口近景和宽幅地形见 `artifacts/realism402-validation/comparison.html`、`before/`、`after/`；基线沿用stage401已验证after，来源见 `before/baseline-provenance.txt`，位置及朝向见前后 `environment-camera-poses.json`。逐图结论见 `visual-review.md`，本轮独立源码差异见 `stage402-source.diff`。
- 七项回归全部通过：四项建筑/通道通行与阻挡、瞄准对齐、武器近墙遮挡和单机冒烟。入口两条路线双向通行、砖柱与斜撑阻挡通过；原始日志和 `functional-results.json` 保留。`final-verification.json` 确认相同机位、捕获包哈希未变及本轮日志无ERROR；阶段证据检查通过不代表画质达标。
- 当前本地可运行预览：`artifacts/realism402-preview/Linux/launch.sh`，Godot4.4.1引擎配本轮新PCK，实际用于截图及全部七项测试。本机缺Linux导出模板；软件Vulkan不能证明显卡帧率。联网、人物及手部动态本轮未复测，前臂直筒观感和树皮精确碰撞仍待处理。
- 下一步见 `artifacts/realism402-validation/next-stage.md`：实质改变道路中景路肩高差、浅沟和成片地被，检查建筑后墙自然光与材质贡献及标线贴地高度；随后衔接第三人称、第一人称默认/ADS/换弹和双客户端联网。保留所有未提交修改，无推送、发布或后台服务修改，整体continue。

### Stage403 — 维修棚通风构造与道路植被土坡（2026-09-18，整体继续）
- 维修棚后墙新增两组带水平叶片和边框的深色通风窗，降低棚内补光；西侧道路新增两处带浅沟的植被土坡及匹配地形碰撞。入口机位能辨识百叶构造，道路中景能辨识新增高差；宽景收益有限，平坦铺装、规则砖材、树叶片和简化远山仍明显。
- 四组相同机位前后实机截图含建筑入口近景和宽幅地形：`artifacts/realism403-validation/comparison.html`、`before/`、`after/`。before沿用stage402已验证after原图，来源见 `baseline-provenance.txt`；精确位置、目标及朝向见前后 `environment-camera-poses.json`，逐图评价见 `visual-review.md`，本轮源码差异见 `environment-source.diff`。
- 八项测试通过：新增路肩、四项建筑/通道通行、瞄准108样本三武器、武器近墙阻挡、单机冒烟。新增路肩五条地形射线及角色横穿验证通过，角色最高抬升约0.854m后回到平地。首次测试类型推断错误修复后复测通过，原始失败保留在 `diagnostics/`；完整日志、`functional-results.json` 和 `final-verification.json` 可复核。审计确认机位一致、捕获输入哈希不变、最终日志无ERROR。
- 当前本地预览：`artifacts/realism403-preview/Linux/launch.sh`，已有Godot4.4.1 Linux引擎配本轮新PCK，实际用于截图和测试。本机缺Linux导出模板；软件Vulkan不证明显卡帧率。本轮未复测联网、第三人称和手部动态，树皮精确碰撞仍待验证。
- 下一步见 `artifacts/realism403-validation/next-stage.md`：继续处理铺装层次、重复砖材、树叶片和远山，再衔接第三人称肩肘与持枪姿态、第一人称默认/ADS/换弹及双客户端联网主流程。保留全部未提交修改，无推送、发布或后台服务修改；不以本轮阶段证据通过宣称整体画质目标完成，整体continue。

### Stage404 — 维修棚残存抹灰、墙脚植被与补光（2026-09-18，整体继续）
- 维修棚两侧砖墙增加不规则残存水泥抹灰，降低彩砖差异；外侧新增低矮草群，降低棚灯并调整入口补光。入口近景的整墙重复砖条减弱，但抹灰仍偏平面，墙脚草和光照收益有限；宽幅地形与道路远景几乎没有可辨识改善，不能视作整体画质达标。
- 四组相同机位实机前后图含建筑入口近景、宽幅地形：`artifacts/realism404-validation/comparison.html`、`before/`、`after/`。before沿用stage403已验证after原图，来源见 `before/baseline-provenance.txt`；精确位置、目标及朝向见前后 `environment-camera-poses.json`，逐图评价见 `visual-review.md`，本轮差异见 `environment-source.diff`。
- 八项回归通过：路肩横穿、四项建筑/通道通行与阻挡、三武器108样本瞄准、近墙武器遮挡及16角色单机冒烟。入口双向通行及柱、窗、挡板和斜撑阻挡通过。原始日志与 `functional-results.json` 保留，`final-verification.json` 确认四机位一致、捕获输入哈希匹配、最终日志无ERROR；仅表示本阶段证据与功能核验通过。
- 本地预览：`artifacts/realism404-preview/Linux/launch.sh`，已有Godot4.4.1 Linux引擎配本轮新PCK，实际用于截图及测试。本机缺Linux导出模板，软件Vulkan不能证明显卡帧率。本轮未复测联网、第三人称及手部动态，树皮精确碰撞仍未验证。
- 下一步见 `artifacts/realism404-validation/next-stage.md`：优先实质改变宽景中的大块铺装、重复树冠与远山，再衔接第三人称肩肘与持枪姿态、第一人称默认/ADS/换弹和双客户端主流程。保留全部未提交修改，无推送、发布或后台服务修改；整体continue。

### Stage405 — 道路重铺段与入口铺装细节（2026-09-18，整体继续）
- 两个地表着色器加入南北道路深色重铺段、近景沥青颗粒，以及入口混凝土扫纹/管沟修补带。道路正常机位可辨识重铺色差，但边缘仍规整；入口和宽景收益较弱，重复树冠、简单远山和大块铺装仍未解决。本轮未新增建筑、植被或光照改动，不能视作环境整体达标。
- 同机位前后实机图：`artifacts/realism405-validation/comparison.html`、`before/`、`after/`，包含入口近景和宽幅地形；before复用stage404已验证after原图，来源见 `baseline-provenance.txt`。四机位actor位置依次为(17,0.00010254,50)、(15.5,0.05,39)、(17,0.05,50)、(2,0.05,61)，眼高偏移1.6m；精确yaw/pitch及目标见 `after/environment-camera-poses.json`。逐图结论见 `visual-review.md`，源码差异见 `environment-source.diff`。
- 八项打包预览测试通过：路肩横穿、四项建筑/通道通行与阻挡、三武器108样本瞄准、近墙武器阻挡及16角色单机冒烟；日志与 `functional-results.json` 可复核。`final-verification.json` 确认前后机位一致、捕获输入哈希匹配、测试集完整及最终日志无ERROR，仅代表本阶段证据与功能通过。
- 本地预览：`artifacts/realism405-preview/Linux/launch.sh`。缺Linux导出模板，沿用Godot4.4.1引擎搭配本轮新PCK，已实际用于截图及测试。软件Vulkan不证明硬件帧率；本轮未复测联网、第三人称、手部动态、移动纹理闪烁及树皮精确接触。
- 下一步见 `artifacts/realism405-validation/next-stage.md`：优先实质改变宽景树冠重复、远山和地被布局并验证碰撞，继续建筑/光照，再衔接第三人称肩肘与持枪、第一人称默认/ADS/换弹和双客户端流程。保留全部未提交修改，无推送、发布或后台服务修改；整体continue。

### Stage406 — 林缘冠幅与西北山体轮廓（2026-09-18，整体继续）
- 调整维修道路、西侧路肩及棚边树冠高宽比例，并提高西北背景山脊；树干碰撞随横向尺度调整。正常机位可辨识林缘高低变化和山体，但近路树影减少，大片浅色铺装更暴露；山坡仍光滑、建筑柱梁厚重和植被重复感仍在。本轮未修改建筑、材质或灯光参数，不代表环境整体达标。
- 四组同机位实机对照含入口近景及宽幅地形：`artifacts/realism406-validation/comparison.html`、`before/`、`after/`。before原样复用stage405已验证after，见 `baseline-provenance.txt`；位置、yaw/pitch及眼高见 `after/environment-camera-poses.json`，逐图审阅见 `visual-review.md`，差异见 `environment-source.diff`。
- 最终八项功能检查通过：路肩横穿、四项建筑/通道通行与阻挡、三武器108样本瞄准、近墙武器阻挡及16角色单机冒烟。维修棚测试首次因旧树干半径断言失败，保留 `initial-checks/`，更新明确米制预期半径后重测通过，未放宽3cm容差或移除路线。最终日志及 `functional-results.json` 可复核。
- `final-verification.json` 确认四机位一致、实机捕获退出码0、输入哈希匹配、八项测试齐全及最终日志无ERROR，仅表示本阶段证据与功能通过。本地预览：`artifacts/realism406-preview/Linux/launch.sh`，沿用Godot4.4.1引擎配本轮新PCK，实际用于截图及测试；本机缺Linux导出模板，软件Vulkan不证明硬件帧率。
- 下一步见 `artifacts/realism406-validation/next-stage.md`：优先建筑构件比例、墙脚/排水/路肩植被连续过渡及入口光照，再衔接第三人称、第一人称动态和双客户端流程。本轮未复测联网、人物手部动态及树皮精确接触。保留全部未提交修改，无推送、发布或后台服务修改；整体continue。

### Stage407 — 维修棚入口、排水边植被与局部光照（2026-09-18，整体继续）
- 删除入口重复斜撑，降低老旧水泥墙脚明度，新增沿排水两侧渐疏的草丛，并调整前坪、天窗和工位补光。入口近景能辨识结构与墙脚改善；宽景变化较小，粗重柱梁、大片浅色铺装、光滑山坡及相似树冠仍明显，整体写实目标未完成。
- 四组同机位实机前后对照：`artifacts/realism407-validation/comparison.html`，含建筑入口近景与宽幅地形；位置和朝向见 `before/after/environment-camera-poses.json`，逐图审阅见 `visual-review.md`，改动见 `stage407.patch`。改前使用stage406预览重新抓图，监督进程退出143后子进程完成四张图及完成标记，未收集退出码，明确记为null；改后抓图退出0，来源及限制见 `baseline-provenance.txt` 和两份 `process-result.json`。
- 八项检查全部退出0：路肩、四项建筑/通道通行与阻挡、三武器108样本瞄准、近墙武器阻挡及16角色单机冒烟。单机首次监督中断的日志保留，最终重新运行通过，见 `functional-results.json` 及测试日志。本轮未重测联网、人物和手部动态。
- `final-verification.json` 已核对四机位一致、输入哈希、八项测试和日志；仅表示阶段证据与功能通过。本地可运行预览：`artifacts/realism407-preview/Linux/launch.sh`，复用Godot4.4.1引擎配本轮新导出PCK，已用于截图与测试；软件Vulkan不证明硬件帧率。
- 下一步见 `artifacts/realism407-validation/next-stage.md`：补第三人称持枪/移动/换弹、第一人称默认/ADS/换弹与双客户端实机审阅，再按实际缺陷修复；继续推进宽景地表用途与修补痕迹、土草连续过渡和山体植被层次。保留所有未提交修改，无推送、发布或后台服务修改；整体continue。

### Stage408 — 维修场地被、棚檐排水及坡面与入口光照（2026-09-18，整体继续）
- 增高并增加符合地表侵蚀分区的维修场草簇；新增维修棚檐沟、落水管，降低入口局部补光，调整远山起伏和岩土着色。实机近景草簇变化可辨识，但排水和补光收益很小，远山仍光滑，粗梁、大块浅色铺地和重复树冠未实质解决；不能将本轮小幅改善视为整体目标完成。
- 四组同机位前后对照含入口近景及宽幅地形：`artifacts/realism408-validation/comparison.html`。before原样复用stage407退出0的after，见 `baseline-provenance.json`；本轮after使用新PCK实机捕获，退出0。相机位置与朝向见 `after/environment-camera-poses.json`，逐图审阅见 `visual-review.md`，源码差异见 `stage408.patch`。
- 八项检查全部通过：道路路肩、四项建筑/通道通行与阻挡、三武器108样本瞄准、近墙武器规则及16角色单机冒烟。维修棚覆盖胶囊前后门通行、门柱阻挡及绕行；见 `functional-results.json` 和对应日志。本轮未复测联网、人物/手部完整动作及树皮精确碰撞。
- `final-verification.json` 核对四机位一致、捕获退出0、预览输入哈希匹配、八项测试齐全及日志无ERROR。当前可运行预览：`artifacts/realism408-preview/Linux/launch.sh`，复用Godot4.4.1引擎配本轮新导出PCK，已实际用于截图与检查。软件Vulkan捕获不代表硬件帧率。
- 下一步见 `artifacts/realism408-validation/next-stage.md`：优先修复正常机位明显的柱梁比例、铺地分区、重复树冠与平滑山体，再衔接第三人称/手部动态和双客户端主流程。保留所有未提交修改，无推送、发布或后台服务修改；整体continue。

### Stage409 — 维修棚檐口、入口轮迹与边缘地被（2026-09-18，整体继续）
- 减少檐口密集竖缝，改为褐色旧漆；新增入口向场地扩散的泥土轮迹，增加两侧草簇与阔叶地被，调整入口反射补光。近景可辨识这些变化，但粗重方梁、大片铺地、重复树冠及光滑偏蓝山体仍明显，整体写实目标未完成。
- 四组固定机位实机前后对照：`artifacts/realism409-validation/comparison.html`，含入口近景及宽幅地形。before复用stage408已验证after，来源见 `baseline-provenance.json`；本轮新PCK捕获after退出0。位置与朝向见 `after/environment-camera-poses.json`，逐图局限见 `visual-review.md`，本轮源码差异见 `stage409.patch`。
- 八项检查全部退出0：道路路肩、四项建筑/通道通行与阻挡、三武器108样本瞄准、近墙武器规则及16角色单机冒烟。含维修棚前后门胶囊通行、柱脚阻挡和绕行；见 `functional-results.json`。本轮未复测联网、第三人称与手部完整动作；不声称树皮精确碰撞通过。
- `final-verification.json` 核对四机位一致、捕获完成、预览输入哈希、八项检查齐全及日志无ERROR。本地可运行预览：`artifacts/realism409-preview/Linux/launch.sh`，已实际用于本轮截图与功能检查；软件Vulkan不证明硬件帧率。
- 下一步应实质处理柱梁比例、铺地用途分区、道路矩形色差和远山/树冠轮廓，不再整轮停留于色值和草簇调整；随后补人物、手部与双客户端主流程审阅。详见 `artifacts/realism409-validation/next-stage.md`。保留所有未提交修改，无推送、发布或后台服务修改；整体continue。

### Stage410 — 维修棚窗框、边缘灌木与入口补光验证（2026-09-18，整体继续）
- 缩细侧窗框和薄檐边，增加场地边缘灌木并变化尺寸，提高入口局部补光；正常机位可辨识新增灌木，但粗柱梁、大片铺地、道路矩形色差及光滑山体仍明显。招牌后移导致横梁遮挡，属于视觉回归；本轮未通过画质验收，不能视为整体目标完成。
- 四组同机位前后实机对照含建筑入口和宽幅地形：`artifacts/realism410-validation/comparison.html`。before复用stage409已验证after，after来自本轮新PCK且捕获退出0；坐标与朝向见 `after/environment-camera-poses.json`，逐图结论见 `visual-review.md`，修改见 `stage410.patch`。
- 八项功能检查全部退出0：道路路肩、四项建筑/通道检查、三武器108样本瞄准、近墙武器规则和16角色单机冒烟。覆盖维修棚前后门胶囊通行、柱脚阻挡及绕行，见 `functional-results.json` 与对应日志。未复测双客户端联网、第三人称及手部完整动作。
- `final-verification.json` 确认四机位一致、预览哈希匹配、捕获完成、八项测试齐全和日志无ERROR；技术通过不代表画质通过。本地预览 `artifacts/realism410-preview/Linux/launch.sh` 已实际用于截图与测试，软件Vulkan不代表硬件帧率。
- 下一步首先消除招牌遮挡回归，再实质修改柱梁、铺地与道路分区、山体和树冠形态，随后补人物/手部动态与双客户端主流程。详见 `artifacts/realism410-validation/next-stage.md`。保留未提交修改，无推送、发布或后台服务修改；整体continue。

### Stage411 — 修复入口招牌遮挡并复核环境与通行（2026-09-18，整体继续）
- 将维修棚招牌移至前檐外侧，缩薄檐口，减弱棚内地面分块反差并加入边缘积尘。实机确认招牌恢复完整可见；改进仍属局部，未新增植被或调整光照。道路矩形色块、大片铺地、重复树冠、偏蓝光滑山体与粗柱梁仍明显，不能通过整体画质验收。
- 四组同机位对照含入口近景和宽幅地形：`artifacts/realism411-validation/comparison.html`；before复用stage410已验证after，来源见 `baseline-provenance.json`，after为本轮新PCK捕获且退出0。位置与朝向见 `after/environment-camera-poses.json`，逐图实际审阅见 `visual-review.md`，源码差异见 `stage411.patch`。
- 八项功能检查退出0，覆盖道路路肩、建筑入口/通道通行及阻挡、三武器108样本瞄准、近墙规则和16角色单机冒烟，见 `functional-results.json`。本轮未复测联网、第三人称与手部完整动作，不声称树皮精确碰撞通过。
- `final-verification.json` 确认四机位一致、捕获完成、预览哈希匹配、测试齐全和日志无ERROR。本地预览 `artifacts/realism411-preview/Linux/launch.sh` 已实际用于截图与测试；软件Vulkan不证明硬件帧率。
- 下一步实质处理道路/场地用途分区及硬矩形材质边界，再处理远山、树冠和光照；随后补人物/手部动态及联网主流程，见 `artifacts/realism411-validation/next-stage.md`。不能再以招牌、色值或草簇微调替代环境阶段。保留全部未提交修改，无推送、发布或后台服务修改；整体continue。

### Stage412 — 道路局部修补与水泥作业坪过渡（2026-09-18，整体继续）
- 将整幅深色道路矩形重铺块拆成错位车道修补，加入出口细土过渡；修正水泥沟槽回填被黑色沥青再次覆盖的问题。正常机位确认横跨道路的硬色块和作业坪斜向深色带消退。本轮没有新增建筑、植被或光照成果；道路仍偏平整，圆锥远山、重复树冠、粗梁柱及圆筒袖管仍明显，整体画质未达标。
- 四组同机位前后实图含入口近景、宽幅地形、道路正向远景：`artifacts/realism412-validation/comparison.html`。before复用stage411已验证after，来源见 `baseline-provenance.json`；after来自本轮预览，捕获退出0。位置/朝向见 `after/environment-camera-poses.json`，实际审阅见 `visual-review.md`，修改见 `stage412.patch`。
- 八项功能检查均退出0，覆盖道路路肩、建筑/通道胶囊通行和阻挡、三武器108样本瞄准、近墙规则及16角色单机烟测，见 `functional-results.json` 与对应日志。中断尝试另存且不计通过；本轮未复测联网、第三人称或第一人称完整动作。
- `final-verification.json` 已核对四机位一致、捕获退出、截图与预览哈希、八项测试及日志。可运行预览：`artifacts/realism412-preview/Linux/launch.sh`；软件Vulkan截图不证明硬件帧率，技术通过不等于视觉验收。
- 下一阶段按当前环境审阅优先级和 `artifacts/realism412-validation/next-stage.md` 转入袖管、肘部、机匣形体的实质改进，审阅默认/ADS/换弹及其他武器和第三人称，再补联网主流程；远山、树冠、铺地及光照仍保留在整体目标中。保留全部未提交修改，无推送、外部发布或后台服务修改；整体continue。

### Stage413 — 肩肘骨骼结构与完整四姿势复核（2026-09-18，整体继续）
- 承接stage412道路修复，新增左右上臂骨骼、肘部渐变蒙皮及上下臂定长求解，同步换弹手掌接触约束，重建Blender/GLB并导出本地预览。新版换弹中段拱肘略降低，但粗大折管形袖子仍未解决，默认/ADS/完成姿势无明显视觉提升，不算人物画质验收通过。
- 本轮重新运行412基准和413新版完整四姿势（无单姿势筛选），逐图审阅；同机位对照 `artifacts/realism413-validation/comparison.html`，参数见两组sleeve-pose-review.json。基准包装退出0；新版包装退出143，子进程随后生成全部四图及内部PASS并结束，引擎退出码未知，包装检查不计通过，原始记录保留。
- 当前预览11类功能检查通过：三武器瞄准108样本、换弹接触183样本及上下臂长度、6次规则中断、第三人称换弹规则、建筑/道路通行碰撞、近墙与16角色单机烟测。见 functional-results.json；初次第三人称标记识别错误记录保留，重跑通过。规则不证明连续动作自然。
- 其他武器及第三人称动作捕获未完成，timeline仅两图后主动终止、退出-15，不能算动态通过；当前联网未复测，也未重拍413入口和宽幅地形环境组。光滑远山、重复树冠、平整空旷铺地、建筑和光照仍待改善。
- 本地预览 `artifacts/realism413-preview/Linux/launch.sh` 已用于截图和检查；证据/哈希见 `artifacts/realism413-validation/final-verification.json`，实际缺陷见 visual-review.md。下一步按 next-stage.md 结构性修正肩锚点、肘部方向和换弹路径，再补完整四姿势、其他武器与第三人称连续动作、联网及环境。保留全部未提交修改，无推送或外部发布；整体continue。

### Stage414 — 袖管候选修正与跨武器、第三人称实机审阅（2026-09-18，整体继续）
- 调整袖管预弯、弯折半径和上臂长度并同步肩锚点，重建Blender/GLB及预览。实图证实换弹倒U形袖管依然明显，默认/ADS改善很小；该候选未解决主要形体问题，不能算视觉验收。
- 完整四姿势无过滤捕获正常退出0，与413相同机位对照见 `artifacts/realism414-validation/comparison.html`。新增其他两把武器及第三人称站/蹲换弹中段实图，补充捕获正常退出0，见 `weapon-contacts/contact-review.json`及四张PNG；参数包含相机位置/朝向。全部为关键帧，连续动作仍未覆盖。
- 第三人称头脸、护具和肩袖仍像简化人偶，蹲姿呈坐凳轮廓；手掌/弹匣遮挡导致部分接触不能确认。远处疑似悬空角色待动态复核。详细结论 `artifacts/realism414-validation/review.md`。
- 当前11项功能检查通过，覆盖瞄准、换弹接触/中断、第三人称规则、道路与建筑通行碰撞、近墙及16角色单机烟测。`final-verification.json`核对截图、正常退出、相机、日志和源文件/预览哈希。当前联网未复测，414入口/宽幅环境组未重拍；历史证据不计当前通过。
- 当前本地预览 `artifacts/realism414-preview/Linux/launch.sh`。下一阶段按 `artifacts/realism414-validation/next-stage.md` 重做肘部截面、袖管拓扑/蒙皮与肩肘轨迹，避免继续仅改角度；补连续动作、其他武器第三人称近景。远山、重复树冠、空旷场地、建筑与光照及联网仍属于未完成目标。保留全部未提交修改，无推送、发布或服务修改；整体continue。


### stage415 — 袖管结构候选与当前预览实机诊断（continue）
- 修改 `tools/build_viewmodel.py` 的肘部弯曲半径、内侧截面压缩及前臂/上臂过渡蒙皮，重建blend/glb和本地预览；保留全部既有未提交修改。实际同机位对照：倒U形袖管仍在且更饱满，**视觉验收失败，不作为画质提升完成**。
- 完整四姿势未使用pose过滤，进程退出0；其他两武器及第三人称站/蹲换弹四张也退出0并逐张审阅。第三人称仍有无面人偶、肩部生硬和坐凳式蹲姿；手部接触部分遮挡。离散截图不证明连续动作自然。
- 当前预览11项功能检查通过，覆盖瞄准、换弹接触/中断、遮挡、单机及道路/建筑通行。当前联网、连续动作和415入口/宽幅环境组未复测。导入退出0但保留dummy texture错误；未隐瞒构建初始网格修复记录。
- 21个骨骼样本确认换弹中点三武器左肘高于手腕约19–25cm；下一阶段修改 `place_reload_hand` 固定肘部朝向与手腕下探轨迹，并同步袖缝蒙皮，不再继续仅调袖管参数。之后处理第三人称姿态、光滑山体/重复树冠/道路空间及光照，补当前联网和连续动作实测。
- 证据：`artifacts/realism415-validation/` 中 `review.md`、`sleeve-comparison.jpg`、`camera-comparison.json`、`sleeve-after/`、`weapon-contacts/`、`arm-diagnostic.json`、`functional-results.json`、`final-verification.json`；后者证据完整性通过，不代表视觉通过。后续方案 `next-stage.md`。
- 可运行本地预览：`artifacts/realism415-preview/Linux/launch.sh`，来源见 `source-manifest.json`。未push、外部发布、修改后台服务或读取输出密钥。


### stage416 — 修复换弹左肘上拱并完成当前实机审阅（continue）
- `client/scripts/first_person.gd` 改为绕伸臂轴平滑引导肘部朝身体外下方。与415同机位实机对照确认倒U形左袖消失；左手/弹匣落在画面下缘，不能把裁出画面的肘部视为自然造型。右臂圆管、袖口生硬和人物肩颈/蹲姿仍未解决。
- 当前预览完整四姿势（无pose过滤），其他两武器及第三人称站/蹲换弹均实际截图、逐张审阅，两个采集进程退出0。第三人称手掌接触部分遮挡，远处疑似离地角色待动态复核。21个骨骼样本及三武器60Hz换弹轨迹用于诊断，不代表连续动作视觉通过。
- 当前11项功能检查全部通过，覆盖换弹接触/中断、瞄准、近墙遮挡、道路/建筑通行碰撞及16角色单机烟测。`final-verification.json` 校验当前源文件/预览哈希、完整姿势、相机一致性、进程及截图；技术完整性通过，整体视觉未通过。当前联网、连续动作视觉与416环境入口/宽幅组未复测。
- 证据：`artifacts/realism416-validation/` 下 `review.md`、`comparison.html`、`sleeve-comparison.jpg`、`camera-comparison.json`、`sleeve-after/`、`weapon-contacts/`、`reload-motion-probe.json`、`reload-motion-displacement.png`、`functional-results.json`、`final-verification.json`。
- 本地可运行预览：`artifacts/realism416-preview/Linux/launch.sh`，来源见 `source-manifest.json`。下一阶段按 `next-stage.md` 优先结构性改造光滑山体与重复树冠，保留已有道路过渡，补同机位环境前后对照、入口/宽幅实机图与通行测试；人物连续动作、建筑、光照及当前联网仍属完整目标。保留全部未提交修改，未push或外部发布。


### stage417 — 山脊汇流沟谷结构与当前环境实机验证
- 按实际 stage416 检查点推进山体结构：`world_visuals.gd` 用不等宽深的 V 形沟谷与中坡支沟替换规则圆槽，扩大峰块差异并缩小顶脊圆角。保留已存在的道路结构修复及所有未提交修改。
- 重新运行416基线与417当前包的入口、宽幅地形、道路远景，六张原图逐张审阅；三机位位置/朝向一致，两采集进程退出0。峰块与分叉沟谷有明显变化，入口通道可见，道路未重现旧横向矩形补丁；但单色坡面、过锐尖峰、浅色沟边线、重复树冠及管状袖子仍明显，整体视觉未通过。
- 当前包11项功能检查全部通过，覆盖单机16角色 smoke、道路及建筑入口/服务通道站蹲碰撞通行、三武器瞄准108样本、遮挡与换弹规则。独立背景检查通过18山体网格法线及树根贴地，最大误差0.000209。源文件/预览/截图输入哈希、机位及技术证据完整性核验全部通过。
- 证据：`artifacts/realism417-validation/` 下 `review.md`、`compare-repair-shelter-entrance.jpg`、`compare-terrain-wide.jpg`、`compare-road-horizon.jpg`、`before/`、`after/`、`functional-results.json`、`background-scenery.log`、`final-verification.json`；阶段源码差异和原文件另存，便于复核。
- 当前本地预览：`artifacts/realism417-preview/Linux/launch.sh`，当前PCK已重新导出并用于本轮实机截图。本轮未覆盖联网、人物完整四姿势及连续动作视觉；数值规则不能证明自然性。下一步见 `next-stage.md`，结构性处理重复树冠及山坡层次，人物改造须补完整四姿势、其他武器、第三人称和连续换弹接触审阅；建筑、光照与联网仍在完整目标内。未push或外部发布，状态continue。


### stage418 — 山脊与坡脚结构调整，环境及完整人物实机复核
- 从实际417检查点推进：`world_visuals.gd` 扩大山脊圆角、平滑沟底并降低沟切深度，添加不等宽坡脚堆积扇；网格与树根使用相同高度场。已有道路过渡修复保留，本轮三机位未见旧横向硬色带回归，不重复宣称修复道路。
- 重新运行417/418同机位入口、宽幅地形、道路远景，六张原图逐张查看并保存相机位置/朝向。山峰与坡脚轮廓发生可见变化，但蓝灰光滑坡面、浅色沟槽、重复树冠和简化空旷建筑仍明显，整体视觉未通过。
- 当前418完整四姿势（无pose过滤）及SG-8、SR-5、第三人称站/蹲换弹中点全部实机截图、逐张审阅，采集退出0、换弹回填通过。三武器均有粗长袖体和左手交换落出画面问题；第三人称接触部分被装备/膝部遮挡，仍呈人偶形态。蹲姿图远处疑似离地角色待连续落地复核；离散截图和规则不能证明连续动作自然。首次补充采集中断143未产出图片，失败记录保留。
- 当前预览11项功能检查通过：单机16角色烟测、三武器瞄准108样本、近墙遮挡、换弹接触/中断、道路与建筑入口站蹲碰撞通行。独立背景检查18山体法线、20004树贴地通过，最大误差0.000143。最终核验源码/预览/采集输入哈希、机位一致性及技术证据完整性通过；当前联网与连续动作视觉未验证。
- 证据：`artifacts/realism418-validation/` 下 `comparison.html`、`review.md`、`before/`、`after/`、三张 `compare-*.jpg`、`sleeve-four/`、`weapon_contact_review_capture/`、`functional-results.json`、`background_scenery/capture.log`、`final-verification.json`、`stage418-source.diff`、`source-manifest.json`。
- 本地可运行预览：`artifacts/realism418-preview/Linux/launch.sh`。下一阶段见 `next-stage.md`：结构性调整手臂/袖体比例与换弹路径构图，补连续动作及第三人称遮挡接触证据，再推进树冠层次、山体材质、建筑与光照；联网保留待验证。保留全部未提交修改，未push、外部发布或改动认证/后台服务。状态continue。


### stage419 — 换弹路径可见性修复与完整人物复核
- 保留已有道路/环境修改，调整第一人称换弹抬起、前移及抽出/插入/回位时序。418/419同机位中点对照显示左手与弹匣由画面下沿移入画面；未重建袖体，巨大肘部鼓包、腕部骤缩、弯管状袖体仍明显，不视为整体画质完成。
- 当前419完整四姿势无过滤采集通过并逐张审阅；SG-8、SR-5及第三人称站蹲中点补充四图通过并逐张审阅。AR另保留36/50/60/74%四相位。第三人称仍呈人偶形态，装备和膝部遮挡接触，远处疑似离地角色需连续复核。离散截图不能证明连续自然性。
- 当前包11项功能检查最终通过，覆盖单机16角色烟测、三武器108瞄准样本、遮挡、换弹、道路及建筑入口/通道碰撞。首次换弹规则浮点边界失败保留，改用实际渲染进度后重跑通过（201接触、594骨长样本）；原17图采集主动中断143，仅4图，未宣称整批通过。源码/预览/采集输入哈希与证据核验通过。
- 证据：`artifacts/realism419-validation/` 下 `comparison.html`、`compare-reload-middle.jpg`、`review.md`、`sleeve-four/`、`other-weapons-and-third/`、`weapon_contact_review_capture/`、`functional-results.json`、`reload_contact_rules-retry.log`、`final-verification.json`、`source-manifest.json`。相机位置与朝向见对应采集JSON。
- 本地可运行预览：`artifacts/realism419-preview/Linux/launch.sh`。下一阶段按 `next-stage.md` 结构性重构肩肘与袖体变形，补连续换弹/落地和第三人称其他武器动作；继续山体、树冠、建筑空间与光照。本轮未新增环境三机位，不能沿用418截图判定当前包环境通过；当前联网未验证。全部未提交修改保留，未push/发布或改动后台服务、认证。状态continue。


### stage420 — 袖体骨段重构与当前包复核
- 减小前臂中心线弯曲，上臂截面改沿肩肘骨段铺设，肘部权重按物理距离混合；重建Blender/GLB。419/420同机位对照仅见有限轮廓改善，左肘大鼓包、长硬袖体依旧明显，不能判定形体修复完成。
- 当前420完整四姿势无过滤采集、SG-8/SR-5换弹中点及第三人称站蹲补充均完成，8张逐一实机审阅。人物仍像人偶，蹲姿后景疑似悬空角色需连续追查；未覆盖连续抽出/交换/插入/回位、落地和其他武器第三人称动作。
- 当前包11项功能检查通过：单机16角色、三武器108瞄准样本、换弹接触201/骨长594样本及6种中断、遮挡、道路与建筑通行碰撞。65项源文件与采集输入哈希核验通过；规则通过不代表动作自然。当前联网未验证，本轮无新入口/宽幅地形图，环境未验收。
- 证据：`artifacts/realism420-validation/index.html`、`review.md`、`comparison-default-spawn.jpg`、`comparison-reload-middle.jpg`、`sleeve-four/`、`other-weapons-and-third/`、`functional-results.json`、`final-verification.json`。相机位置朝向见采集JSON；默认机位与419一致。
- 本地预览：`artifacts/realism420-preview/Linux/launch.sh`。release因缺导出模板失败，export-pack成功，当前使用Godot可执行文件加PCK运行并完成上述验证；非正式发行包。下一步见本轮`next-stage.md`：连续动作追查与结构性肩肘修复，并推进山坡、树冠、建筑空间和光照，环境阶段补当前同机位前后/入口/宽幅图及碰撞。保留未提交修改，未push/发布、未改服务或认证。整体状态continue。

### stage421 — 三武器完整换弹抽样与当前预览复核
- 新增 `tests/weapon_motion_review_capture.gd`，实际Forward+采集三武器第一人称、第三人称站姿/蹲姿9段261帧，固定60Hz模拟、10Hz留图；本地审阅页支持动画和逐帧原图。隔离人物保留光照物理，不能据隐藏地面的图判断脚底悬空，也未验证实时输入、帧间穿插或走跑跳落地。
- 当前完整四姿势无过滤重新采集并全部审阅。左肘鼓包、腕部骤缩、右袖弯管仍突出；其他武器复用相似换匣动作。第三人称肩臂僵硬、人物简化，蹲姿枪膝遮挡手部接触，不能判定动作自然。本轮为验证工具和缺陷定位阶段，未改美术资产，不宣称画质提升。
- 11项当前功能回归通过，涵盖单机、三武器瞄准、遮挡、换弹接触/骨长/中断及道路建筑通行；65项源文件与当前预览一致，证据核验通过。联网 `/protocol` 探测404，未验证联网对战。早期全世界序列仅2帧后终止143，保留且未计通过。
- 证据：`artifacts/realism421-validation/index.html`、`review.md`、`motion/motion-review.json`、`sleeve-four/`、`functional-results.json`、`verification.json`、`source-equivalence.json`、`network-readiness.json`。逐帧相机见采集JSON。当前本地预览仍为 `artifacts/realism420-preview/Linux/launch.sh`。
- 下一步见本轮 `next-stage.md`：结构性修复肩肘/袖体后完整四姿势与三武器动作复核，补世界内第三人称移动落地，再推进山体、树冠、建筑和光照；环境修改需新同机位前后/入口/宽幅及碰撞证据。保留全部未提交修改，未push/发布、未改服务认证。整体状态continue。

### stage422 — 袖体截面改善与三武器动作复核
- 将前臂叠加鼓包改为连续收窄截面，降低折痕幅度并收窄上臂，重建Blender/GLB及当前预览。同机位同帧421/422对比可见右前臂鼓包减少，但左肘圆团、长直袖管仍突出；这不是整体画质完成，也不足以视为肩肘结构修复。
- 当前完整四姿势无过滤采集退出0，四图均审阅；三武器第一人称/第三人称站蹲9段261样本齐全，肩部僵硬、通用换弹轨迹和简化人物仍明显。动作采集控制进程退出143，子进程后续虽写出完成标记，退出状态未取得，因此保留passed=false；总核验唯一失败为motion process failed。10Hz采样未覆盖实时输入、帧间穿插及世界内走跑跳落地。
- 当前包11项功能检查通过，包含单机、三武器瞄准、遮挡、换弹接触/骨长/中断及道路建筑通行；中断的首次单机日志保留，重跑退出0。65项源文件与预览输入一致。联网端点HTTP404，联网主要流程未验证。实机场景仍有平滑锥形山体、重复树冠和宽空道路；本轮未修改环境几何、未新增入口/宽幅专项图，不沿用旧图验收。
- 证据：`artifacts/realism422-validation/index.html`、`review.md`、`comparison-motion-ar-048.jpg`、`comparison-camera.json`、`sleeve-four/`、`motion/motion-review.json`、`motion/process-result.json`、`functional-results.json`、`verification.json`、`source-equivalence.json`。相机位置朝向保存在采集JSON。当前本地预览：`artifacts/realism422-preview/Linux/launch.sh`。
- 下一步按实际大肘团重做肩部定位、肘部弯曲变形与武器专用换弹，不能再只缩袖径；完整四姿势、三武器与世界内第三人称动作复核。保留建筑、地形植被、光照和联网目标，环境修改必须补同机位前后、入口近景、宽幅地形和碰撞证据。未push/发布、未改服务认证，保留全部未提交修改。整体状态continue。

### stage423 — 肩部锚定结构修复与当前包复核
- 以肩部锚点和腕部双骨求解替代沿前臂外推肩部，重建Blender/GLB。首版上臂横挡手部和弹匣，已淘汰并保留证据；423b降低肩部并调整上臂长度，同帧422/A/B对比可见左肘团和新增遮挡退出主要视野。右肘尖角、直袖管和袖口衔接仍不自然，不宣称人物画质完成。
- 当前包完整四姿势无过滤捕获退出0，四图均审阅；结束帧左手回到护木、弹药30/119，但静帧不能证明回握自然。三武器第一/第三人称站蹲9段261帧齐全，其他武器通用换弹、第三人称肩袖棱角和蹲姿僵硬仍明显。动作控制进程退出143、子进程退出码未回收，保留passed=false；总核验唯一失败motion process failed。未覆盖实时输入、帧间穿插和世界内走跑跳落地。
- 当前包11项功能检查通过，覆盖单机、瞄准、遮挡、换弹规则和道路建筑通行；65项源文件一致。联网/protocol探测HTTP404，联网主流程未验证。本轮没有环境修改，不沿用旧入口/宽幅图验收；平滑尖山、重复树冠、宽空道路、建筑和光照目标保留。
- 证据：`artifacts/realism423b-validation/review.md`、`index.html`、`compare-036.jpg`、`comparison-camera.json`、`sleeve-four/process-result.json`及四张PNG、`motion/motion-review.json`、`motion/process-result.json`、`functional-results.json`、`verification.json`。相机位置朝向在采集JSON。联网记录：`artifacts/realism423-validation/network-dependency.json`。当前本地预览：`artifacts/realism423b-preview/Linux/launch.sh`（Godot可执行文件+PCK）。
- 下一步先修复动作采集控制进程143退出并取得正常退出结果；继续肩肘变形与武器专用换弹接触、世界内第三人称移动落地验证，再推进山体轮廓和山脚中景结构。环境修改需新同机位前后、入口近景、宽幅地形和碰撞证据。未push/发布、未改服务认证，保留全部未提交修改。整体状态continue。
### stage424 — 场地弯道结构过渡与当前人物复核
- 维修棚支路改为17点连续弯道，路面、碎石与植被避让共用路径；去掉场地横向深色矩形带，加宽主路衔接渐隐。同机位宽幅图可见原直条改为弯曲过渡；主路自身灰色色带、空旷路面、光滑棱面山体和重复树冠仍存在，未宣称环境完成。
- 保存道路、入口、宽幅三组前后图和相机位置朝向；入口机位主要修改在身后，仅用于外观复核。当前包11项功能检查通过，覆盖三武器瞄准、换弹约束、遮挡、单机和建筑/道路/场地通行。
- 完整四姿势无--pose过滤采集，四图均实际审阅；三武器第一人称及第三人称站蹲9段261样本齐全，抽帧审阅仍见直袖管、尖肘、硬袖口、块状肩部和简化面部。结束帧30/119且左手回到护木附近，不证明连续回握自然；未覆盖世界内移动换弹、转向开火切换及脚部着地。
- motion、sleeve、after-fixed监督进程退出143，子进程虽完成输出仍保留passed=false；综合verification.json未通过，不将文件齐全等同进程成功。联网端点HTTP404，主要联网功能未验证。当前包已重新导出并实机采集，编译脚本不能以原文SHA直接比较，详见source-verification-note.txt。
- 证据：`artifacts/realism424-validation/environment-comparison.html`、`camera-comparison.json`、`sleeve/`、`motion/index.html`、`final-checks/functional-results.json`、`verification.json`、`review.md`、`network-readiness.json`。本地预览：`artifacts/realism424-preview/Linux/launch.sh`。
- 下一步结构性重做上臂—肘部—前臂轮廓和蒙皮体积，复核四姿势及多武器连续动作；排查采集监督中断以取得可靠进程退出证据。继续推进山体、植被、建筑和光照，补足联网验证。未push/发布、未改后台服务，保留未提交修改。整体状态continue。

### Stage426b — 山体结构试改、同机位审阅与多武器动作证据（目标未完成）
- 调整world_visuals.gd共享山体高度场，拓宽山脊并加入低频岩脊；426实机产生尖峰已拒绝，426b减幅减频。425道路修补和424场地过渡为既有修改。当前道路中远处横向色带、山壁光滑材质仍未消除，不将本轮当作环境达标。
- 425→426b入口/宽幅地形/道路三组同机位对照与相机元数据：artifacts/realism426b-validation/environment-comparison.html、camera-comparison.json；三张已审阅。环境包装进程143，引擎退出码未取得，截图及完成标记存在但保留passed=false。
- 426未筛选完整四姿势采集退出0且四张已审阅（artifacts/realism426-validation/sleeve-all-four-sheet.jpg），不可标为426b四姿势通过。426b三武器第一人称、站/蹲第三人称9段261帧换弹采集退出0：motion/process-result.json、motion-viewer.html。部分五帧表已审阅，未连续播放/逐帧审阅全部序列。前臂细直、袖口突变、第三人称肩胸块感明显；蹲姿SG8选帧动作变化很小待追查。隔离诊断隐藏世界，不覆盖实景移动、走跑跳和联网。
- 426b新跑11项功能检查通过，含单机、建筑入口碰撞通行、道路通行、瞄准108样本及换弹规则：artifacts/realism426b-validation/final-checks/functional-results.json。8001协议200仅证明可达，双客户端主要流程未验证。
- 本地预览：artifacts/realism426b-preview/Linux/launch.sh；总证据verification.json与review.md位于同阶段validation目录。未推送、未发布。
- 下一步：优先追查道路横向色带的实际来源并完成明显有效的场地过渡；随后结构性修正前臂体积/肩肘/袖口，检查SG8蹲姿换弹及护木弹匣连续接触，当前版本重跑完整四姿势与实景动作。保留树冠分布、建筑材质、山壁和光照改造及联网功能目标。

### Stage427 — 道路诊断与当前包完整姿势/功能复验（目标未完成）
- 道路风化采样旋转/域扰动候选在426b→427同机位实拍中无明显效果，未接受为横向色带修复。入口、宽幅地形、道路前后采集均退出0；相机位置/朝向一致：artifacts/realism427-validation/environment-comparison.html、camera-comparison.json。太阳阴影关闭诊断仍有条带；其包装退出143、子进程退出码未取得，保留passed=false，勿混作完整通过。
- 新增环境诊断模式及动作world-visible开关。当前427完整四姿势未筛选采集退出0，四张均已审阅：sleeve-all-four-sheet.jpg。前臂细直、袖口突变未解决。
- 当前427隔离动作9段261帧退出0，三武器第一人称和站/蹲第三人称：motion-isolated/process-result.json、motion-viewer.html。已审阅部分五帧表，未连续播放全部序列；SG8第三人称蹲姿选帧几乎无手位移待追查。成功采集隐藏世界，初次实景动作中断143；不代表实景连续动作通过。
- 当前包11项功能复验通过：final-checks/functional-results.json（单机、建筑入口/道路通行碰撞、瞄准108样本、遮挡、换弹规则）。联网主要流程未验证；规则不证明动画自然。
- 当前本地预览：artifacts/realism427-preview/Linux/launch.sh。完整审阅/限制/哈希：artifacts/realism427-validation/review.md、verification.json。未推送或发布。
- 下一步仍先定位道路色带：flat-road/hide-cross-road同机位隔离并据此结构性修复，勿继续仅改噪声；随后查SG8蹲姿动画、肩肘与前臂/袖口结构并补实景连续动作。保留建筑材质、光滑山体、重复树冠、光照与双客户端功能目标。

### Stage428 — 摄影沥青替换道路大块底色，完成当前四姿势复核（目标未完成）
- 用双尺度旋转摄影沥青采样替换道路程序化大尺度底色，保留路肩渐变/车辙/补丁；同机位对照横向硬色带明显减弱，仍有裂纹平铺重复。道路、建筑入口、宽幅地形当前采集退出0，相机记录一致：artifacts/realism428-validation/environment-comparison.html、camera-comparison.json。before明确为427基线。
- 当前428六项功能复验退出0：道路通行、维修棚及框架碰撞通行、三武器108样本瞄准、武器近墙避障、16角色单机流程；见 checks/results.json。未重跑联网主要流程。
- 当前未筛选完整四姿势重采集903.681秒退出0，四张已审阅：sleeves-verified/process-result.json、sleeve-all-four-sheet.jpg。前臂细直、肘部体积突变和袖口分段仍明显；静态通过不代表动作自然。首次 sleeves/ 退出码未知，不作通过证据。
- 实景连续动作软件渲染714.58秒只保存第一武器两帧，主动中止退出-15、passed=false：motion/process-result.json、interruption.json；不能证明完整换弹、其他武器、第三人称或接触通过。motion-viewer.html仅局部帧。
- 本地预览：artifacts/realism428-preview/Linux/launch.sh；PCK a04eea403edba8842994880b1ef955f4ad2bd0886ce13d15ea2f05e216630ae8。审阅与总证据：artifacts/realism428-validation/review.md、verification.json。未推送或发布。
- 下一步：降低实景动作采集成本后结构性修正前臂/上臂截面、肘部蒙皮和换弹IK工作空间；查SG8蹲姿，补三武器与第三人称连续肩肘/袖口/护木/弹匣接触证据。保留光滑山体、重复树冠、建筑材质/场地空旷、光照与当前联网验证目标，不再以道路微调替代推进。

### Stage429 — 当前包四姿势实审、碰撞复验与动作采集诊断（目标未完成）
- 未改游戏资产、未生成新包；当前本地预览仍为 artifacts/realism428-preview/Linux/launch.sh（哈希见 artifacts/realism429-validation/verification.json）。428道路改善不是本轮新改善，无新的环境前后对照。
- 完整未过滤四姿势已生成且全部审阅：sleeves-forward/、sleeve-all-four-sheet.jpg。监督进程退出143，子进程随后完成四图及PASS日志，退出码未知；process-result.json明确passed=false。前臂细直、袖口突变仍明显；静态不能证明回握自然。
- 当前包三武器伤害/墙体遮挡6项、维修棚/场地通行碰撞32项退出0：functions/process-result.json及两份审计JSON。未覆盖联网或完整单机对局。
- 新增九段动作采集运行器、逐帧本地查看器，采集脚本增加逐帧耗时/部分证据落盘及紧凑诊断模式。工具编译、Godot解析和启动失败落盘检查通过。两次实景动作尝试各仅首帧后主动中止，passed=false；motion-compact/与motion-forward-compact/保留PNG、耗时、viewer.html，不能代表其他武器/第三人称通过。
- 审阅与证据：artifacts/realism429-validation/review.md、verification.json。保留所有原有修改，未推送或发布。
- 下一步先解决采集绘制成本和SIGTERM监督状态，再结构性修改手臂截面/肘部/袖口及IK；补三武器与第三人称站蹲实景连续接触，追查SG8蹲姿。山体、植被、建筑、光照及双客户端主要功能继续保留，勿把工具修复视作画质完成。

### Stage430 — 前臂/上臂袖子结构增容及当前包完整四姿势（目标未完成）
- 修改 tools/build_viewmodel.py 整段前臂截面、深度和上臂袖子体积，重新生成Blend/GLB；具体前后参数见 artifacts/realism430-validation/change-scope.json。细杆感减轻，但肘部分段、手套与弹匣接触仍明显，未改蒙皮权重，不能宣称动作自然。
- 新本地预览 artifacts/realism430-preview/Linux/launch.sh；导入/导出成功。完整未过滤四姿势退出0（839.768秒），四图均已审阅，见 sleeves-forward/process-result.json、sleeve-before-after.jpg、reload-middle-before-after.jpg。以428成功采集为基线，camera-comparison.json记录相同出生机位及朝向。
- 当前冻结PCK三武器伤害/遮挡6项、维修棚与场地碰撞通行32项退出0，见 functions/ 内JSON与日志。PCK SHA256为1757ebe0bec27e0cea2c45225ad7f7fac94c85c2a89e72f7b9d9bb679a02749f。未覆盖联网或完整对局；四姿势不是连续动作证明。
- 审阅与范围：artifacts/realism430-validation/review.md、verification.json。本轮无环境修改与新环境近景/宽幅对照，光滑山体、重复树冠、场地空旷及建筑光照仍待推进。未推送或发布，保留所有既有修改。
- 下一步结构性处理肘部连接/蒙皮与袖口，降低实景动作采集成本，补三武器及第三人称站蹲连续动作（追查SG8蹲姿、肩肘、护木、换弹与回握接触）；之后继续环境结构、光照及当前版本双客户端主要功能验证，不以截图数量或局部通过结束整体目标。

### Stage431 — 实景动作采样与植被几何负担定位（目标未完成）
- 未改游戏运行时/资产，当前本地预览仍为 artifacts/realism430-preview/Linux/launch.sh，冻结PCK哈希不变。改进动作采集诊断、裁除统计、部分证据查看器，新增 tests/scene_geometry_inventory.gd；Python编译、git diff --check、实际Godot库存脚本退出0。
- 冻结场景17,369几何节点，资源实例累计约1.545亿三角面（不是屏幕绘制量）；冷杉92实例、单棵861,424面，占约7925万。证据 artifacts/realism431-geometry.json、realism431-geometry.log、realism431-diagnostic-summary.json。部分直接放置树木无距离分级。
- Compatibility 640×400关闭阴影并裁远处细节的实景诊断，绘制图元约2738万→116万、单次截图渲染约31秒→8秒；不代表正式Forward+画质或交互FPS改善。保留所有中止和解析失败记录，未将多次部分结果拼成通过。
- artifacts/realism431-motion-local-retry/ 保存卡宾枪0–132帧23张采样、viewer.html及早/晚接触表，均已审阅；弹药29→30并复位，但前臂直筒、袖口突变和换弹接触问题仍待解决。仅一条片段完成，进程主动中止后 passed=false；其余八条、完整四姿势、换弹中断与连续输入未覆盖。
- 详见 artifacts/realism431-review.md。本轮未复测联网、伤害瞄准、入口碰撞和单机通行，无正式环境前后/入口/宽幅新对照；旧验证未计为本轮通过。保留所有修改，未推送或发布。
- 下一步先对高面数冷杉建立中远景LOD并统一直接放置树木距离分级，保留近景枝形；用正式Forward+相同机位、入口近景和宽幅地形审阅并复测通行。补齐三武器第一/第三人称站蹲动作与完整四姿势，再结构性处理肩肘、袖口、护木和插匣接触；建筑、地形植被、光照与单机/联网完整目标继续保留。

### Stage432 — 冷杉中景模型及当前包环境/四姿势复核（目标未完成）
- 新增 tools/build_fir_mid.py、fir_mid.glb，保留整片针叶岛并简化枝干，中景源模型861,424→212,950三角面（减少75.3%，不代表FPS）；统一普通与直接放置冷杉18m/70m/300m距离分级，近景模型及树干碰撞不变。来源说明已更新。
- 新本地预览 artifacts/realism432-preview/Linux/launch.sh，PCK SHA256 662bfcaf718366236369243f23fc7965ba2231c98e36666f33e284807bb9d743。导出退出0，源文件/输出哈希及Python编译、git diff --check通过；导入日志有dummy texture storage空纹理错误，原因未确认，截图未见缺失贴图。
- artifacts/realism432-validation/environment-comparison.html 保存430→432相同机位道路、入口、宽幅地形、林下四组正式Forward+前后对照，camera-comparison.json记录位置朝向一致，全部八图已审阅。道路横向硬矩形未重现，裂纹重复仍在；中景保留立体枝冠，但远处冷杉切公告板后偏亮、轮廓突变，是可见回退。光滑山体、重复阔叶树冠、建筑光照仍未解决。
- 当前冻结包五项维修棚/西侧林地/道路边缘/西侧车间/入口碰撞与通行脚本均退出0，见 checks/results.json及日志。完整未过滤四姿势退出0且四图已审阅，见 sleeve-poses/process-result.json；换弹29→30并回到持枪姿势，但前臂直筒、袖口鼓起和圆柱拇指问题仍明显。静态截图不能证明连续插匣/回握自然；其他武器、第三人称、联网、完整对局及伤害瞄准未在本轮复测。
- 审阅与限制见 artifacts/realism432-validation/review.md。下一步先修复远景树冠回退并动态检查LOD边界，再补三武器第一/第三人称站蹲连续动作，据实际接触与肩肘缺陷做结构修改；继续地形结构/材质、建筑空间、植被分布、光照与当前版本单机联网主要功能。未推送发布，保留所有既有修改。

### Stage433 — 远景冷杉结构回退修复与当前包通行复核（目标未完成）
- 新增 fir_far.glb：由完整针叶岛筛选及枝干简化生成60,365三角面的立体远景树，70–300m替代不受光公告板；生成脚本支持 --far，来源说明已记录。远景不投影，近景及树干碰撞不变。
- 当前本地预览 artifacts/realism433-preview/Linux/launch.sh，PCK SHA256 2a217c83ff310d62802dc6e28caa7c55d466ce4e076c9a1f779da4546d44e6b6。导出退出0；导入退出0但仍有dummy texture storage空纹理错误，原因未确认。保留所有未提交修改，未推送发布。
- artifacts/realism433-validation/environment-comparison.html 保存432→433道路、入口、宽幅地形、林下四组对照；camera-comparison.json确认相同位置与朝向。当前Forward+截图运行退出0，四组均已人工审阅：远树亮绿色平面轮廓减轻，道路横向硬矩形未重现、入口畅通；山体光滑、阔叶冠重复、裂纹重复和前臂直筒仍明显。局部回退修复不等于整体画质达标。
- 当前冻结包维修棚双向角色通行、11棵西侧树干阻挡、道路边坡实际跨越三项通过，见checks/results.json与日志。verification.json及review.md记录哈希、截图、范围和限制。未覆盖动态LOD切换/性能、当前人物完整四姿势及连续动作、联网、完整对局、伤害瞄准；不沿用432通过结论。
- 下一步进入三武器第一/第三人称站蹲连续动作审阅，按肩肘、直筒前臂、袖口和换弹接触实际缺陷做结构修改，并运行未过滤完整四姿势。保留LOD动态验证、山体结构材质、植被分布、建筑空间光照和当前版本单机联网主要功能全部目标。

### Stage434 — 三武器九组动作实机复验与缺陷定位（目标未完成）
- 使用冻结433预览 artifacts/realism433-preview/Linux/launch.sh，未重新导出或改变正式游戏画面。证据入口 artifacts/realism434-validation/index.html，详细审阅 docs/VISUAL_REVIEW_STAGE434.md。
- 未过滤四姿势Forward+截图全部生成并逐张审阅；包装器被外部终止143，Godot随后完成截图及PASS标记，但退出码未知，不能报告正常退出。原记录保留，poses/recovery-audit.json记录恢复审计。两采集包装器新增SIGTERM进程组清理与失败落盘，实际中断测试均通过，见checks/capture-signal-cleanup.json。
- 修复动作诊断裁剪遗漏中远景冷杉及MultiMesh的问题，三武器第一人称、第三人称站姿/蹲姿九段261样本采集退出0，九张接触表全部审阅；motion-lod-cull/viewer.html及process-result.json保存逐帧证据和哈希。640×400关闭阴影裁剪场景仅供动作诊断，10Hz模拟采样不等于连续操作自然；此前中断的motion记录保留。
- 新增tests/sleeve_reach_review.gd，606个左右手诊断状态没有支持肩部漂移或肘部完全伸直猜测；左肘31.57–142.07度、肩漂移小于0.000001m。直锥形袖管、鼓起袖口仍明显；第三人称躯干肩部僵硬、面部和护膝粗糙，蹲姿手匣接触常被装备膝部遮挡。下轮优先结构性修改袖形和腕部衔接，并改善第三人称身体配合，补近景连续动作。
- 当前包重新通过瞄准对齐、三武器开阔/遮挡伤害、第一/第三人称换弹规则、本地可靠动作序列、建筑双向通行碰撞和道路边缘通行，见checks/current-checks.json、aim-damage-process.json、traversal-checks.json。规则和本地动作不代表真实联网，本轮未读取认证密钥、未验证联网。
- 山体光滑、树冠重复、道路裂纹重复、建筑空间与光照、LOD动态表现和联网主要功能仍未完成；保留整体目标及所有未提交修改，未推送发布。下一轮以袖管与腕部结构修改的相同机位前后对照起步，完整四姿势及三武器动作复验后继续环境结构提升。

### Stage435 — 当前包三武器动作复验及袖口局部修复（整体目标未完成）
- 袖管末端退到袖口起点并统一接缝半径，重建 Blender/GLB、导出当前本地预览 artifacts/realism435-preview/Linux/launch.sh；PCK SHA256 13cf68e6b474fe94da9eb478e5aabf3665b8e9a82e7dd6d2655d7610fe8c19bc。仅局部改善，长锥前臂仍明显，不能视为整体画质推进完成。保留所有未提交修改，未推送发布。
- 证据入口 artifacts/realism435-validation/index.html；审阅 docs/VISUAL_REVIEW_STAGE435.md。保存默认机位和换弹关键帧434/435前后对照及相机元数据。未新增建筑入口近景和宽幅地形图，不以旧截图计当前包环境通过。
- 三武器第一人称、第三人称站姿/蹲姿九段261样本正常退出0，耗时1448.66秒；九组关键帧表已审阅，motion/viewer.html及process-result.json可复核。640×400兼容渲染关闭阴影并裁剪远景，仅供诊断；10Hz采样不证明连续实操自然。第三人称头身僵硬、面部肘膝粗糙，蹲姿手匣接触遮挡，仍需结构性修改和近景连续证据。
- 两次均运行完整四姿势、未用--pose；均收到来源未确认的终止信号，包装器记录interrupted，子进程-15，仅第二次产出默认截图。poses/和poses-retry/保留失败日志，完整四姿势未通过，不能用旧图或规则替代。
- 当前包八项检查通过：瞄准对齐、第一/第三人称换弹规则、606样本肩肘测量、建筑入口双向通行碰撞、道路边缘通行、三武器遮挡伤害、可靠动作规则；见checks/current-checks.json与additional-checks.json。未运行需要认证配置的真实联网测试，未读取密钥或修改服务。
- 下一步定位四姿势中断，优先改前臂整体轮廓或第三人称头身/武器配合，保持手部接触并补侧面近景连续动作、其他武器ADS、移动换弹与打断切枪。道路裂纹重复、光滑山体、重复树冠、建筑空间与照明、完整场景性能及真实联网继续保留，不再连续以袖口微调替代结构性提升。

### Stage436 — 当前环境对照、山体岩肩结构及完整四姿势复验（整体目标未完成）
- 当前道路/场地过渡在435基线与436同机位实机图中连续，未见原横向硬矩形；本轮在真实山体高度场加入两层斜向断层岩肩，轮廓变化明显，但部分尖峰生硬、蓝灰坡面仍光滑，不能视为写实山体完成。入口盒状空间、道路裂纹与树冠重复仍待处理。
- 导出本地预览 artifacts/realism436-preview/Linux/launch.sh；证据入口 artifacts/realism436-validation/review.html，审阅 docs/VISUAL_REVIEW_STAGE436.md。四组环境前后图覆盖场地、建筑入口、宽幅地形、道路远景，记录一致相机位置朝向；evidence-audit.json核对12张图、相机和当前包哈希。
- 当前包完整四姿势（未传--pose）正常退出0，四张均已审阅：默认、ADS、换弹中段、换弹结束。长锥前臂、鼓起手套/袖口仍明显；结束恢复持枪及弹数不能证明连续插拔弹匣接触自然。其他武器与第三人称连续动作本轮未复验，不将435记录算当前通过。
- 当前建筑四条双向通行/两处碰撞、道路五处地面与路肩跨越检查通过，见functional-results.json；三武器108样本瞄准检查游戏退出0，包装器143单独记录在aim-result.json。环境后对照包装器143，但子进程完成四图及完成标记，游戏退出码未收集，process-result.json未标驱动通过；重复采集取消、地形规则中断均保留记录，不算通过。
- 未验证当前真实联网及完整战斗流程；软件渲染采图不证明交互性能。下一步结构性修改前臂/腕部轮廓和第三人称肩肘身体配合，完整四姿势并补其他武器、第三人称近景连续动作，检查袖口、护木和换弹接触；继续建筑、地形植被、光照与功能全目标。保留未提交修改，未推送发布。

### Stage437 — 前臂整体截面修改、完整四姿势及当前包功能检查（整体目标未完成）
- 承接436道路/场地审阅，修改整段前臂的收窄曲线、偏移与圆角布料截面，重建Blender/GLB及437预览；中段鼓胀减少，但长锥袖管、厚手套、僵硬换弹仍明显，不算人物或整体画质完成。
- 当前本地预览 artifacts/realism437-preview/Linux/launch.sh；PCK 408bc70c04111a2e280c2145df73e7a2ca94f8c6d449fabb6b17958299a1556b。审阅 docs/VISUAL_REVIEW_STAGE437.md，证据入口 artifacts/realism437-validation/review.html。四姿势未传--pose，753.031秒正常退出0，四组436/437对照全部审阅，相机元数据一致。
- 当前包八项检查全部退出0：606项肩肘测量、换弹接触规则、三武器瞄准、建筑入口射线、四条双向通行/两护栏、道路路肩、六次遮挡伤害及战斗规则；见 functional-results.json、combat-results.json。初次中断另存不计通过；导入dummy texture警告与拓扑修复如实记录。
- 九段动作采集仍运行，02:00 UTC已有第一人称武器0/1完整23/31帧、武器2前2帧；第三人称未审阅，不计九段通过。保留包装器2024998/游戏2025195继续运行；下轮先核查 motion/process-result.json 与 capture.log，确认命令后接续，勿重复启动。兼容模式关闭阴影/裁剪远景的10Hz采样不证明连续动作、光照或性能自然。
- 下一步先收尾现有三武器及第三人称站/蹲动作证据，审阅肩肘、袖口、护木、换弹接触，再做腕臂比例或躯干参与换弹的结构修改。437未新增环境入口/宽幅图，未验真实联网或完整单机交互性能；道路裂纹、山体、树冠、建筑空间和光照目标继续保留。所有未提交修改保留，未推送发布。

### Stage438 — 补齐九段动作审阅与证据审计（整体目标未完成）
- 437遗留动作采集已生成九段261张最终截图：三武器第一人称、第三人称站姿/蹲姿全部接触表完成审阅。原进程已消失，旧状态仍写running且退出码为空；保留原记录，不重复启动，不将完成标记推断为正常退出。审计evidence_complete=true、process_exit_verified=false、passed=false。
- 第一人称长锥袖管/厚手套仍明显，第三人称头部几何简陋、肩肘及躯干近乎固定，蹲姿僵硬；10Hz离散采样不能证明帧间接触或连续动作自然。下一阶段优先肩肘躯干协调及腕臂/人物比例的结构修改，随后完整四姿势（不带--pose）及三武器、第三人称动态近景验证。
- 新增动作证据审计并接入采集器和查看器，区分截图完整性与进程退出；八项审计测试通过，覆盖丢帧、旧包、截断图片、结束后引擎错误及未知退出码。查看器静态检查完成，未验证浏览器播放。证据入口 artifacts/realism438-validation/review.html；审阅 docs/VISUAL_REVIEW_STAGE438.md。
- 本轮无模型/场景修改，不宣称画质改善；继续使用 artifacts/realism437-preview/Linux/launch.sh，PCK 408bc70c04111a2e280c2145df73e7a2ca94f8c6d449fabb6b17958299a1556b。437四姿势及功能检查是上轮结果，本轮未重跑；真实联网、完整单机交互、正式光照仍未覆盖。保留道路裂纹、光滑山体、重复树冠、建筑入口空间和地形目标；后续补当前版本同机位环境对照/入口近景/宽幅地形、通行碰撞与瞄准验证。未推送发布，保留全部未提交修改。

### Stage439 — 第三人称换弹躯干联动与当前包功能验证（画面验收未完成）
- 承接438实际动作缺陷，为换弹加入胸部前倾/侧倾与低头，肩臂和武器同步变换，重建Blender/GLB。修复骨骼烘焙遗漏轴向扭转造成约5cm手/弹匣偏离；改为保留完整旋转，三武器站/蹲规则全部通过，未放宽容差。尚无439第三人称截图审阅，不宣称动作视觉改善。
- 当前本地预览 artifacts/realism439-preview/Linux/launch.sh；PCK 9ef87308bec978f294232167074a1ddea3cade832442f2968eb7283e69ee2d44。证据入口 artifacts/realism439-validation/review.html；模型/工具/测试哈希见manifest.json，审阅 docs/VISUAL_REVIEW_STAGE439.md。
- 对当前冻结包完成九项检查，全部退出0：八项功能断言（换弹接触、第三人称换弹、108次瞄准采样、入口碰撞、建筑通行、道路路肩、六次遮挡伤害、战斗规则）及606项肩肘诊断测量；后者不证明外形自然。日志与哈希见 functional-results.json。中断批次另存，未计通过。
- 完整四姿势两次被中断，仅default/ADS；第一次九组动作采集也中断，均保留失败记录。第三次完整四姿势不带--pose，包装器2131445；九组动作重试包装器2118442。02:37:58 UTC仍运行，分别0/28张PNG；handoff.json保存命令/进程/包哈希。下轮先核查现有进程及process-result.json，勿重复启动；九组查看器已生成但仅部分证据，最终完成后重建审计。
- 实际审阅当前默认/ADS及武器0部分换弹：长锥袖管、厚手套仍明显，重复裂纹/树冠、光滑山体与建筑体块仍待修。九组兼容诊断采集关闭阴影并裁剪远景，10Hz离散图不证明连续动作自然或正式画质。当前四姿势未通过、第三人称未审阅，未覆盖转身/移动换弹及帧间接触。
- 下一步先收尾上述完整四姿势与三武器第一/第三人称站蹲动作，审阅肩肘、袖口、护木、弹匣接触，按缺陷修改腕臂比例或动作。继续环境同机位前后对照、入口近景、宽幅地形及建筑/植被/光照目标；本轮未新增当前环境全套截图。真实联网未测：现有网络夹具会读取SERVER_SECRET并启动服务，与本任务限制冲突，未执行；未验证完整单机交互性能。保留未提交修改，未推送或发布。

### Stage440 — 移动换弹腿部步态修复与冻结包实机对照（整体目标未完成）
- 修复第三人称移动换弹仍播放静止腿部的问题：按实际速度为换弹叠加走、跑、蹲行腿部轨道，保留上身换弹动作。三武器×三种步态规则在439包全部失败，在440源代码及冻结包全部通过；当前包第三人称换弹接触规则亦通过。规则不证明动作自然。
- 实机物理移动对照保存 before/after 六帧、相机与人物数据，入口 artifacts/realism440-review/review.html；reload-walk-before-after.jpg 可见修复后交替迈步。仅覆盖武器0直线行走换弹，未覆盖转向、急停、脚底锁定、切换过程和帧间接触；GIF是离散采样，非连续录像。
- 当前本地预览 artifacts/realism440-preview/Linux/launch.sh，PCK 7877360a646c76fec929b295dcb301ef21d9243d975c8afeba7d793d3122a417；验证日志 validation/results.json，审阅 docs/VISUAL_REVIEW_STAGE440.md，交接 artifacts/realism440-review/handoff.json。
- 440完整四姿势采集未带--pose，包装器2148447、xvfb2148453，process-result.json仍为running/未通过。继承439完整四姿势包装器2131445、九组动作包装器2118442仍待收尾；旧包证据不得计为440通过，勿重复启动。实际审阅439部分第一人称动作仍见长直袖管、突兀袖口和厚手套。
- 下一步核查现有采集，完整审阅四姿势、其他武器和第三人称肩肘/袖口/护木/换弹接触，再选择结构性人物修改。继续道路修复后的环境同机位、入口近景、宽幅地形审阅，改善山体、重复树冠和建筑；440尚未重测瞄准、建筑通行、完整单机和联网。现有联网夹具读取SERVER_SECRET并启动服务，受本任务限制未执行。未推送或发布，保留全部未提交修改。

### Stage441 — 三武器换弹退出步态连续性（整体目标未完成）
- 修复移动换弹结束时腿部突然重置到步行起点：恢复原步态相位，在上身过渡期间继续驱动腿骨。440冻结包回归失败，441冻结包三武器×走/跑/蹲行×三时点共27组退出检查通过；当前移动换弹、第三人称换弹规则及瞄准对齐通过。接触规则运行中断，未计通过。
- 同机位、同人物位置的三武器实机退出窗口前后各54帧，已审阅对照图；artifacts/realism441-review/review.html、reload-exit-comparison.jpg、before/after/capture.json及evidence-integrity.json可复核。只覆盖连续换弹末尾和退出窗口，独立平面兼容渲染，不代表完整换弹、脚底锁定或正式地图表现。肩臂仍粗、髋部协调及手部接触待改善。
- 当前本地预览 artifacts/realism441-preview/Linux/launch.sh；PCK b4e22f2f7b65d9dffefe83f52819cee56442c006f96d23423a141c2f20e16f5d。审阅 docs/VISUAL_REVIEW_STAGE441.md；验证 validation/results.json；进程交接 artifacts/realism441-review/handoff.json。
- 441完整四姿势首轮SIGTERM中断；已不带--pose重跑，artifacts/realism441-poses-retry/process-result.json仍running，包装器2164563。当前建筑通行验证尚待结果。继承440四姿势2148447及439九组动作2118442继续运行；先检查结果，勿重复启动，旧包不得计为441通过。439完整四姿势已审阅作缺陷参考，仍见直细袖管、厚手套与突兀袖口。
- 下一步先收尾当前四姿势及其他武器第一/第三人称完整动作，审阅肩肘、袖口、护木与换弹接触，按实际缺陷结构修改。道路435/436修复后仍需当前版本同机位环境对照、入口近景、宽幅地形与碰撞通行证据，继续改善山体、重复树冠、建筑和光照。完整单机与真实联网未验证；现有联网夹具读取SERVER_SECRET且启动服务，受任务限制未执行。保留全部未提交修改，未推送、发布、部署或修改后台服务。

### Stage442 — 主路照片纹理去重复与当前包四姿势审阅（整体目标未完成）
- 道路shader改为四米单元随机偏移、连续混合照片采样并使用textureGrad。同机位前后实机图显示巨大分叉裂纹重复明显减弱；纵向裂纹仍平行，服务场地独立材质和路肩灰褐带未解决，不冒称场地过渡完成。
- 环境主路、场地、入口近景、宽幅地形前后图及四组comparison.jpg位于 artifacts/realism442-validation/。441对照进程退出0；442四图及PASS日志齐全，但监督进程丢失，退出码未知，process-result记supervisor_lost/false。机位JSON记录脚本角色位置/朝向，未记录绘制瞬间Camera3D世界变换；下轮补录并核对宽幅视向。
- 当前包完整四姿势（无--pose）退出0通过，已逐张审阅；artifacts/realism442-poses/process-result.json、四张PNG及four-poses-contact-sheet.jpg。支撑手回到护木、弹药恢复，但前臂细长锥形、肘部环带明显，静帧不证明连续动作自然。当前九组动作任务仅2张样本后中断，artifacts/realism442-motion/viewer.html仅供部分诊断；其他武器及第三人称完整动作未覆盖。
- 当前道路路肩通行、仓库双向入口/侧墙碰撞、三武器六组瞄准伤害/遮挡均退出0通过，见 artifacts/realism442-validation/functional-results.json 及详细JSON。完整单机smoke中断未通过；联网未测，现有夹具需读取SERVER_SECRET并启动服务，与任务约束不兼容。旧439动作及440四姿势后来完成，只算旧包参考。
- 本地预览 artifacts/realism442-preview/Linux/launch.sh，PCK b1d2f57ca895e7c627db021ec90b895bef32a1b3284aecbb69d61b4b41b606b1；导入/导出退出0。审阅 docs/VISUAL_REVIEW_STAGE442.md。下一轮补齐其他武器/第三人称连续动作证据，再针对整段前臂、肘部体积与袖口连接作结构修改；保留服务场地过渡、光滑山体、重复树冠、建筑空旷和光照层次的完整目标，补完整单机与合规联网验证。保留全部未提交修改，未推送、发布或改后台服务。


### Stage443 — 服务道路轮廓与过渡修复、当前人物接触审阅（整体目标未完成）
- 服务入口道路改为沿程变宽、左右不对称边缘，打断连续轮迹并降低深色弧带。相同机位前后实机图可见黑灰弧带明显减弱；场地横向硬边仍在，不宣称全部道路过渡问题已解决。环境前后三机位均退出0，补记实际Camera3D世界位置/前向量并逐项确认相同；入口近景、宽幅地形和对照见 artifacts/realism443-validation/，机位见 camera-comparison.json。
- 当前包维修棚/仓库/雨棚六次双向通行、两处侧墙碰撞、路肩通行、三武器瞄准伤害/遮挡和完整单机smoke均退出0通过。有效证据汇总 validated-checks.json；首次仓库测试启动后脚本发生变化，已排除并独立复跑，不用旧结果代替新增路线验证。真实联网未执行，现有夹具读取SERVER_SECRET并启动服务，未运行。
- 完整四姿势无--pose复跑通过并逐张审阅，见 poses-retry/process-result.json 与 four-poses-contact-sheet.jpg。新增九组换弹关键帧测试，覆盖三武器第一人称、第三人称站/蹲姿，45张图及结束弹量断言通过；keyframes/ 下三张contact-sheet.jpg已审阅。兼容渲染的稀疏关键帧不证明连续动作自然；原连续采样中断，仅保留第一武器前1.6秒部分证据，不计完整动作通过。
- 当前仍见细长锥形前臂、鼓胀手套、肘部亮环和第三人称肩臂棱块；第三人称画面占比不足以确认袖口与弹匣精确接触。下一阶段重塑整段前臂/肘部截面、曲率与袖口连接，复核蒙皮/法线，再跑完整四姿势和近景连续换弹、移动换弹。继续保留场地硬边、光滑山体、重复树冠、建筑空旷/材质、光照及联网功能目标。
- 本地可运行预览 artifacts/realism443-preview/Linux/launch.sh；PCK a3fe0a1aa149d16da9907db11d518e52049f414a76cd8f8123840c5731840913，来源与哈希见 preview/provenance.json（完整路径 artifacts/realism443-preview/provenance.json）。详细审阅 docs/VISUAL_REVIEW_STAGE443.md。保留全部未提交修改，未推送、发布、部署或修改后台服务。


### Stage444：场地边缘试验、当前包功能与人物复验（总体未完成）
- 修改 service_yard.gdshader 圆角距离场/透明过渡并扩大支撑平面，但同机位前后实机对照没有有意义的改善；道路横向硬边尚未定位，不记为修复。服务入口、建筑入口近景及宽幅地形对照、相机位置与朝向见 artifacts/realism444-validation/ 与 docs/VISUAL_REVIEW_STAGE444.md。after 正常退出0；before 包装退出143，三图及相机数据恢复但保留失败状态。
- 当前444包建筑六条双向通行、两侧墙体碰撞、路肩通行、三武器瞄准命中/掩体阻挡、单机smoke均通过，证据在 validation/functions/。本轮联网未验证，未读取服务凭据或运行依赖认证的夹具。
- 完整四姿势无--pose重试退出0并逐张审阅，poses-full/ 保存结果；首次捕获中断仍保留。contact/ 另外两武器及第三人称站/蹲换弹中点四图退出0并审阅。细长管状前臂、肩肘棱块、狙击枪握把接触和蹲姿手臂/膝部拥挤仍突出。motion/ 仅18张卡宾枪稀疏采样，主动中止，不能证明连续动作、插弹轨迹或其他武器动态通过。
- 本地预览 artifacts/realism444-preview/Linux/launch.sh；PCK d0964fc966f23c4ce714cc4b2b56c536ce93f7b0d35d796379625e4f326e5adc，来源见该预览 provenance.json。保留所有未提交修改，未推送、发布或改后台服务。
- 下一阶段先隔离主路/service-access/service-yard/实体坡道/阴影以确定横向硬边来源，再结构性修改交接并取得明显同机位改善；不要继续叠加颜色或噪声。随后重塑肩肘腕整体形体与各武器握持，补三武器及第三人称连续换弹。建筑、光滑山体、重复树冠、光照和当前联网验证仍未完成。

### stage445：场地平面化、道路根因隔离与当前包人物复审

- service_yard 从透明薄盒改为朝上平面；445正式同机位前后对照未见明显道路改善，环境目标未通过。去阴影/去法线诊断仍有横带，去维修沟槽材质诊断明显减弱横带，后者仅诊断、尚未进入预览。详见 `docs/VISUAL_REVIEW_STAGE445.md` 与 `artifacts/realism445-validation/access-normal-vs-no-trench.png`。
- 当前445实机已保存入口近景、宽幅地形、完整四姿势、SG08/SR05换弹中点及第三人称站/蹲换弹截图。确认管状前臂、袖口突变、手掌脱离握把、块状肩肘；蹲姿接触重叠及背景人物悬浮仍待调查。静态截图不证明连续动作自然。证据索引 `artifacts/realism445-validation/evidence-index.json`，相机记录 camera-comparison.json 及各捕获目录。
- 当前包建筑双向通行/墙体阻挡、路肩通行、三武器瞄准伤害与掩体、单机smoke通过，日志在 validation/functions；联网认证夹具未运行，连续动作未覆盖。no-bump诊断包装器退出143，不能计作通过；no-trench诊断退出0且实际捕获标记通过。
- 本地预览 `artifacts/realism445-preview/Linux/launch.sh`，PCK SHA256 `4ad40947351325a92be25459a18681aabbe7522bfc82eb0b4da587c9db624ba7`；来源 provenance.json。未推送或发布，保留未提交修改。
- 下一步：将沟槽诊断转为正式路面结构/材质修复并重新导出、同机位验收；据本轮实机缺陷修改整段手臂形体与多武器握持锚点，补连续换弹/第三人称移动。保留山体、重复树冠、建筑/光照及联网完整目标。状态 continue，不能以捕获数量或断言通过判定整体完成。


### Stage446：道路横向修补带消除，当前人物全姿势审阅
- 删除 service_access.gdshader 中全宽虚构管沟修补图案，正常 Forward+ 实机前后对照确认横向浅灰硬矩形消失；三机位完全一致，含入口近景和宽幅地形。证据：artifacts/realism446-validation/environment-before-after.png、camera-comparison.json。门槛地坪分界、光滑山体、重复树冠与空旷背景仍未解决。
- 当前446包建筑六条双向通路/两处墙体阻挡、路肩通行、三武器瞄准遮挡、单机 smoke 均退出0通过，日志在 functions/；当前版本联网尚未验证。
- 完整四姿势无 --pose 筛选通过（720.716秒）；SG08/SR05 换弹与 AR30 第三人称站蹲捕获通过（831.407秒），已审阅全部接触原图与两张人物联系表。长直前臂、膨大袖口、右掌离开握把及简化第三人称形体仍明显，截图标记不代表动作自然通过。
- 本地预览：artifacts/realism446-preview/Linux/launch.sh；当前 pck SHA256 68af52db0bfb7b1bfa98e1c9c7c74f48a6843763cdfd95043344654508631016。审阅 docs/VISUAL_REVIEW_STAGE446.md；证据索引 artifacts/realism446-validation/evidence-index.json。未推送或发布。
- 下一步：结构性修改肩肘腕体积及握持锚点/旋转，补连续拔匣、插匣、回握及三武器第一/第三人称动作证据；现有离散截图不覆盖动态接触、射击回弹、跑动转身和站蹲过渡。保留山体树冠、建筑室内照明及当前联网验证任务，整体目标未完成。

### Stage447：前臂整体截面重塑与当前预览接触缺陷复审
- 承接446已完成的道路修补带修复，本轮修改 build_viewmodel.py 的整段前臂体积、渐缩与非对称肌肉截面，重建 first_person.blend/glb。实机前后对照仅部分改善；厚袖口、团块手掌和 SG08/SR5 右掌离开握把仍明显，整体画质未完成。
- 当前包三武器瞄准6用例、建筑六条双向通路/两处墙体阻挡、路肩和单机 smoke 重试通过；日志 artifacts/realism447-validation/functions。当前联网未复测，446环境截图不能代表447环境验收。
- 完整四姿势无筛选运行两次均中断，最终仅默认/ADS；其他武器捕获两张后中断，第三人称缺失。动作任务中断，保留 AR30/SG08 共51帧诊断采样及 viewer.html；未覆盖SR5/第三人称、移动输入/站蹲过渡/网络动作，联系表不证明连续自然。各 process-result.json 均保留非通过结果，终止原因未确认。
- 本地预览 artifacts/realism447-preview/Linux/launch.sh，PCK SHA256 511cba94d63d62d92fc12152ca33fbbff4952be4ceee0e76dfdcc4a2a69eafe7；缺导出模板后 export-pack 成功并配同版本Godot。证据索引 artifacts/realism447-validation/evidence-index.json；审阅 docs/VISUAL_REVIEW_STAGE447.md。未推送、发布或改后台服务，保留未提交修改。
- 下一步先排查捕获进程终止并补完整四姿势和第三人称实机证据；针对各武器握把/护木锚点、腕部旋转与肩肘链做结构修改，复审换弹全程。继续山体轮廓、树冠分布、建筑室内及光照和联网验证；环境修改必须同机位前后、入口近景及宽幅地形复验。状态 continue。

### Stage448 — 当前包人物补证与捕获入口加固
- 未修改运行时资产，不算新画质改善；本地预览继续使用 `artifacts/realism447-preview/Linux/launch.sh`。
- 完整四姿势（无 --pose）561.639秒通过，SG/SR及第三人称站蹲中段655.633秒通过，八张原图逐张审阅。新增 `tools/run_weapon_contact_review.py` 记录哈希、退出与完整样本，支持独立第三人称；三个非法输入检查通过。
- 当前PCK重新通过三武器瞄准伤害/墙阻挡、建筑六条双向通行/两侧墙阻挡、单机烟测。详见 `artifacts/realism448-validation/evidence-index.json` 和 `docs/VISUAL_REVIEW_STAGE448.md`。
- 画质仍不足：SR右掌与握把空隙、细杆前臂和厚袖口、第三人称肩胸/脸/靴子简化；蹲姿接触被膝部遮挡，远处角色离地观感待运行复核。静态采样不能证明连续动作自然，联网未测。
- 下一步：结构性处理整段肘腕/袖口与三武器包握变换，随后完整四姿势及连续拔匣—插匣—回握、第三人称站蹲验证；继续山体、重复树冠、建筑室内光照和联网目标。不得再以细小手指或颜色修改代替整体推进。

### Stage449 — 右掌整体贴合与当前包完整静态复测
- 调整整只右手/手套向握把贴合的变换，重建 Blender/GLB 并导出当前预览 `artifacts/realism449-preview/Linux/launch.sh`。SG/SR 同机位对比间隙略缩，钩片手掌、细前臂和厚袖口仍明显，不能视作整体画质推进完成。
- 当前包完整四姿势（无 --pose）、SG/SR及第三人称站蹲四张捕获均通过并逐张审阅；瞄准六项、建筑六条双向路线/两处墙阻挡及单机 smoke 通过。第三人称肩胸、脸和靴子仍简化；蹲姿接触部分遮挡。证据 `artifacts/realism449-validation/`，审阅 `docs/VISUAL_REVIEW_STAGE449.md`。
- 动作采样 KeyboardInterrupt，保留56帧（AR23/SG31/SR2）及 `motion/viewer.html`，第三人称全程缺失，明确未通过；中断原因未确认，静态/选帧不证明连续动作自然。联网未复测；导入退出0但含 dummy renderer texture_2d_get ERROR，实际截图有纹理。
- 下一步停止连续手掌微调，结构性处理重复尖锥山体与光滑坡面，保存同机位前后、建筑入口近景、宽幅地形及相机参数，复测通行。继续植被分布、建筑室内光照、人物肩肘/袖口/护木/换弹全程与联网目标。本轮未改环境，不以旧环境验证替代当前验收。状态 continue；未推送或发布。

### Stage450 — 山峰展宽与环境当前包复测
- 修改山体实际高度场，将部分针尖峰改为不等宽峰肩；前后实机可见轮廓变化，但光滑山壁、重复环状山群仍明显，整体画质未达标。道路当前机位未见横向硬矩形，路肩拉伸模糊仍在。
- 导出本地预览 `artifacts/realism450-preview/Linux/launch.sh`；449/450重新捕获入口近景、宽幅地形、道路远景，三组相机完全一致。对照及相机/哈希证据：`artifacts/realism450-validation/comparison-audit.json`、`comparisons/`；详见 `docs/VISUAL_REVIEW_STAGE450.md`。
- 当前450包建筑六条双向通行与两处墙阻挡、三武器六项射击伤害/遮挡、单机烟测全部通过。首次功能启动漏设证据目录后主动终止，保留失败记录并重新运行，未混算通过。
- 复审449人物仅定位细腕、厚袖口、片状手掌和第三人称肩胸缺陷；450未跑人物完整四姿势或连续动作，不沿用旧通过结论。联网未执行。
- 下一步结构性重排主山体/支脊/谷地并改坡面，停止只调峰顶系数；随后整段肩肘、前臂袖口、包握修改，完整四姿势及AR/SG/SR、第三人称连续动作复测。保留植被、建筑室内光照和联网目标。状态 continue；未推送或发布。

### Stage451 — 重排山群谷地并复审当前人物
- 将18处等间距环山替换为11处主山/支脊/低鞍部布局，保留树根高度场元数据。450/451同机位入口、宽幅地形和道路对照已逐张审阅，连续山墙明显退后降低；光滑坡面与锯齿峰线尚未修复。两版本道路当前机位均无横向硬矩形，本轮不重复宣称道路修复。
- 本地预览 `artifacts/realism451-preview/Linux/launch.sh`；证据索引 `artifacts/realism451-validation/evidence-index.json`，相机与对照 `comparison-audit.json`、`comparisons/`，详阅 `docs/VISUAL_REVIEW_STAGE451.md`。451环境捕获退出0；450对照虽三帧及PASS标记完整，外层退出143，未冒充正常退出。
- 当前451包完整四姿势（无单姿势筛选）、SG/SR与第三人称站蹲四张全部退出0并逐张审阅。细长腕部、厚袖口、圆片/钩片手掌仍明显；第三人称肩胸、肘部和靴子简化，蹲姿接触部分遮挡。远处离地角色待连续观察，不能凭单帧定为悬空故障。静态采样不证明连续换弹自然。
- 当前包建筑六条双向通行/两处墙阻挡、三武器六项瞄准伤害/遮挡与单机烟测通过。联网和连续拔匣/插匣/回握/切枪/移动未执行，不沿用历史通过。
- 下一步整体处理前臂—腕掌—袖口结构与第三人称肩肘，补连续动作和落地观察；并继续坡面细节、植被层次、路肩拉伸、建筑内部布置光照与联网验证。不能用隐藏远山或手指微调代替总体画质推进。状态 continue；保留未提交修改，未推送或发布。

### Stage452 — 整段前臂体积及肘部蒙皮，当前包实机复审
- 调整前臂截面、上臂转折与肘部双骨过渡，让装饰补强/缝线共享变形；重建Blender/GLB和本地预览 `artifacts/realism452-preview/Linux/launch.sh`。前臂不再过细，但偏圆鼓、肘环断层仍明显，不能判定写实达标。
- 完整四姿势无筛选、SG/SR及第三人称站蹲四张均退出0并逐图审阅；8组451/452相机一致。当前包建筑通行/墙阻挡8项、瞄准伤害/遮挡6项、单机烟测通过。证据 `artifacts/realism452-validation/evidence-index.json`，详阅 `docs/VISUAL_REVIEW_STAGE452.md`。
- 九段换弹有限采样任务仍运行（motion/process-result.json）；AR/SG采样接触表已审阅，SR及第三人称动态未完整覆盖。640×400兼容诊断关闭阴影并裁远处细节，不代表正常画质或实时动作自然；下一轮先收取最终状态并补审，不重复启动同任务。联网未运行。
- 当前包入口、宽幅地形、道路远景三图已审阅，三组前后相机一致；引擎三帧PASS但外层退出143，整组不记通过，保留interruption-observation.json。道路横向矩形未复现；场地模糊、拉伸、重复树冠、光滑山壁、空旷及室内硬板感仍在，本轮未改环境。
- 下一步收齐动作证据，结构性处理肘关节/肩肘运动链并追踪疑似离地NPC；继续地形坡面、植被层次、建筑内部光照与联网验证。状态 continue；未推送或发布，保留全部未提交修改。

### Stage453 — 曲线路肩实体土方及当前包全姿势复审
- 为修理棚引道建立连续不规则隆起截面及真实碰撞。452/453同机位入口、宽幅地形和道路三组均正常退出并逐图审阅，起伏可见，但新路肩偏黄亮、外缘偏硬，融合仍不合格；横向硬矩形未复现，不声称已修复。
- 当前预览 `artifacts/realism453-final-preview/Linux/launch.sh`，PCK `1bf784f69593086274367212e6002360ebfd270ca38d4b5141f925eb67574ce1`。审阅 `docs/VISUAL_REVIEW_STAGE453.md`，本地图册 `artifacts/realism453-validation/review.html`，相机记录 `comparison-audit.json`，索引 `evidence-index.json`。法线修正前中间包及失败/中断记录保留，不作为当前通过。
- 当前包完整四姿势无筛选、SG/SR和第三人称站蹲全部退出0并逐图审阅。分离弹匣可见，但前臂鼓胀、腕部过窄、袖口环形断层与肩肘僵硬仍明显；蹲姿手/枪/膝接触部分遮挡，远处疑似离地角色需连续追踪。静态截图不证明连续动作自然。
- 当前包建筑通行/墙阻挡8项、三武器瞄准伤害/遮挡6项、单机烟测通过；新增四处路肩支撑与八条双向横穿通过。联网未执行。452九段261帧旧采样已收齐并补审，旧包装退出码未知，仅作缺陷追查，不能认证453。
- 下一步先将路肩外端实际埋入地面并统一接缝空间材质，随后整体调整前臂—腕掌—袖口及肩肘运动链，验证连续插匣/回握和角色落地；继续建筑内部光照、坡面/植被/空旷道路及联网验证。状态 continue；未推送或发布，保留全部未提交修改。

### Stage454 — 路肩接缝融合与当前包动作缺陷复审
- 路肩和修理棚场地共用世界坐标土石材质，外缘/端部埋入地面，降低交接处隆起并保留真实碰撞；453/454同机位入口、宽幅地形和道路对照已逐图审阅，黄色硬边明显减弱。道路横向硬矩形本次未复现，不宣称全局解决；光滑山体、重复树冠、空旷道路和前景纹理拉伸仍在。
- 当前可运行预览 `artifacts/realism454-final-preview/Linux/launch.sh`，PCK `c73a8010dbb4de1915800b673530befb77f40cdfe4623cbe93b1846ab0eab901`。详见 `docs/VISUAL_REVIEW_STAGE454.md`、`artifacts/realism454-validation/stage454-evidence.json` 和三份 `*-comparison.jpg`；相机位置朝向见 `after-final/environment-camera-poses.json`。环境三图及完成标记齐全，但进程退出码无法恢复，`after-final/recovery-audit.json` 明确未判通过。
- 当前包 `functions-verified/` 路肩四点支撑/八条横穿、建筑通行与墙阻挡、三武器瞄准命中/遮挡、单机烟测全部退出0通过。联网在本地 `/auth/login` 返回HTTP404，双客户端未开始；证据 `online-test.log`，未改后台或认证。
- 复审AR/SG换弹采样和SG/SR半程近景：前臂鼓胀、腕部过窄、袖口断层、掌指形体仍明显，插匣/回握接触被遮挡，未认证连续动作自然。`motion-final/viewer.html` 保留73帧（AR23/SG31/SR19），采集已中断，第三人称未覆盖；`contacts-final/` 仅两图且中断，均非通过。
- 完整四姿势无筛选任务 `poses-full-retry/` 仍运行（包装进程2735081，xvfb2735085，1200秒超时），尚未通过；下一轮先查其终态并审阅四图，避免重复启动。随后补齐第三人称连续动作，结构性调整整段前臂—腕掌—袖口及肩肘链；继续建筑内部光照、山体植被、道路空间和联网验证。状态 continue，整体目标未完成；未推送或发布，保留全部未提交修改。

### Stage455 — 整段前臂收形与腕掌蒙皮
- 在454道路接缝修复后推进人物结构：整段前臂中段收窄压平、减少弯曲，并在手部合并后重建袖口/腕掌的 Forearm/Hand 平滑混合权重；重新生成 Blender/GLB。实机换弹抬臂鼓胀明显减轻，但腕部过窄、圆鼓掌垫和肘部环形断层仍未解决。
- 当前预览 `artifacts/realism455-final-preview/Linux/launch.sh`，PCK `037077b24a82997830cf99b431a8bb28c4bf1eb838ecbc802a05b3caa4bd9140`。报告 `docs/VISUAL_REVIEW_STAGE455.md`，索引 `artifacts/realism455-validation/evidence-index.json`，完整四姿势前后对照 `pose-comparison.jpg`，四机位一致审计 `camera-comparison-audit.json`。454遗留四姿势确认退出0，仅用作基线。
- 当前包完整四姿势无筛选及SG/SR、第三人称站/蹲四项补充截图全部退出0并逐图审阅。肩肘、头脸、靴子仍简化，蹲姿手/枪/膝遮挡且远处角色疑似离地；插匣、回握及落地连续过程尚未认证。七项当前包功能检查全部退出0：路肩、建筑通行/墙阻挡、瞄准伤害/遮挡、单机烟测及三项换弹规则，日志见 `functions-verified/`。
- `motion/` 动态任务仍运行，包装进程2765231、xvfb2765232，2400秒超时；索引快照44帧，AR第一人称23帧齐、SG未齐，其余未覆盖。下轮先查 `motion/process-result.json` 并重建查看器，避免重复启动；兼容诊断渲染/离散采样不证明正常光照或连续动作自然。修复前中间包已隔离，不计通过。
- 本地联网路由探测 `/auth/login` HTTP404，双客户端未验证，见 `network-route-probe.json`。本轮未重拍环境，不继承旧环境采集通过结论；平滑山体、重复树冠、空旷道路和建筑光照仍待推进。
- 下一步收取动态终态并补审其他武器/第三人称插匣回握、追踪落地，再结构性修正肩肘—袖口—腕掌；继续环境同机位入口/宽幅地形对照与通行、联网验证。状态 continue；未推送或发布，保留全部未提交修改。

### Stage456 — 肘部连续曲面与当前人物复审（未完成整体目标）
- 肘部中心线与前臂相切、截面沿实际曲线转向，重新生成 Blender/GLB 并导出预览；SG同机位对照可见环形凸起减轻，但长细袖管、袖口斜边、圆鼓手套和简化枪托仍在。独立补丁 `artifacts/realism456-validation/source-stage456.patch`，报告 `docs/VISUAL_REVIEW_STAGE456.md`。
- 当前本地预览 `artifacts/realism456-final-preview/Linux/launch.sh`，PCK `67cd09098f61682266af5a481ee081e2d16b4e413e9932688382a621db19ec13`；索引 `artifacts/realism456-validation/evidence-index.json`。当前包七项单机/瞄准/建筑与路肩通行/换弹规则均真实退出0，见 `functions/summary.json`，不证明连续动作自然。
- 当前SG/SR半程截图及默认/ADS已实际查看；完整四姿势前两次被终止（-15），未判通过。无筛选完整重试 `poses-complete-retry/` 正运行（包装2829498、xvfb2829499，1800秒超时）；`contacts/` 仍待第三人称站/蹲（包装2805971、xvfb2806118，2400秒超时）。下轮先读取终态及存活状态，不重复启动；须补审四姿势与机位一致性，不能用两张图代替。
- 455遗留动态九段261张已齐且日志有完成标记，但退出码不可恢复，`motion/recovery-audit.json` 仍passed=false。已重建viewer并查看SG/SR及第三人称AR站/蹲采样；泛用换弹、圆块头脸、粗大装备与屈膝站姿明显。旧包仅诊断，不计456动态通过；插匣/回握连续接触仍未覆盖。
- `/auth/login` 当前探测HTTP404，双客户端未验证，见 `network-probe.json`。本轮未重拍环境，平滑山体、重复树冠、空旷道路和建筑光照继续保留，不继承旧环境验收。
- 下一步先收齐并审阅现有截图任务，再结构性推进整个人物比例、肩肘/躯干/骨盆姿态与头脸装备，补三武器插匣回握；恢复环境同机位入口/宽幅地形改进与通行、联网验证。状态continue；未推送发布，保留所有未提交修改。
- 本轮收尾补充：`contacts/process-result.json` 已真实退出0，SG/SR与第三人称站/蹲四图齐全并逐图审阅；圆块头脸、粗大装备、屈膝站姿、蹲姿手枪膝遮挡仍在，远处角色疑似离地待动态核实。完整四姿势重试仍未完成，下一轮先收取该任务终态。

### Stage457 — 连续面罩与贴面护目镜重建、当前人物证据补齐
- 替换头脸独立椭球拼装，生成连续颌部/颧部/额头与贴面镜框镜片；Blender构建、Godot导入和导出均退出0。同机位 `artifacts/realism457-validation/head-before-after.png` 可见凸眼与圆块下颌减轻，未视为整体画质完成；报告 `docs/VISUAL_REVIEW_STAGE457.md`。
- 本地预览 `artifacts/realism457-final-preview/Linux/launch.sh`，PCK SHA256 `7c56ee828ed9074880572cec6fef6238cbdf6a8b4035ee8791a2ec761bfda233`。完整四姿势无筛选采集退出0且全部审阅（`poses/process-result.json`）；第三人称站/蹲补采退出0且全部审阅（`third-retry/process-result.json`），机位与456一致性见 `third-camera-comparison.json`。
- SG/SR半程图已审阅，但首次组合采集中断退出-15，`contacts/process-result.json` 保留passed=false，不以第三人称补采改写原结果。当前七项单机/瞄准/建筑入口与路肩碰撞通行/换弹规则检查退出0，见 `functions/summary.json`；不证明连续动作自然。
- 仍有细长前臂、袖口突变、块状手套、站立屈膝和蹲姿肢体拥挤；远处角色疑似离地需正常物理连续核查。下一阶段结构性处理整条肩肘—袖口—腕掌比例与运动链，补三武器插匣、松手、回握、移动/中断连续证据，避免继续局部头脸微调。
- 当前 `/auth/login` 空JSON探测HTTP404，双客户端未验证（`network-readiness.json`）。本轮未新增环境对照；光滑山体、重复树冠、宽阔空旷道路、建筑与光照仍待结构性推进，须补当前同机位前后、入口近景、宽幅地形及通行验证。状态continue；未推送发布，保留全部未提交修改。

### Stage458（2026-09-19）：当前457包复审、完整四姿势与相邻动作帧工具
- 本轮未改游戏美术、未导出新包，不记为新的道路修复或整体画质通过。新增 `tools/build_motion_review_viewer.py` 相邻采样帧并排、逐帧/键盘及实际间隔显示；实际生成页的DOM替身交互检查通过，未做浏览器视觉验收。
- `artifacts/realism458-validation/before/` 三机位实机基线已逐图审阅，相机坐标/朝向已保存；道路仍宽阔空旷、山体平滑折面、树冠重复。没有本轮after图。
- 当前PCK重新通过路肩、建筑通行、瞄准伤害、单机冒烟四项；完整无--pose四姿势退出0，四图均已查看，中段弹匣确实脱离、末段补弹30/119，袖管细长及掌部块感仍待结构修改。当前联网未验证，静态截图不证明连续动作自然。
- 动作诊断已获得AR/SG各23采样，兼容渲染/远景剔除不用于最终光照评价；原未剔除任务主动终止并记录失败。`motion-culled/` 仍运行：runner2898281/xvfb2898282/engine2898458，1800秒超时。下一轮先收取终态、重建viewer，避免重复启动；SR及第三人称尚未完整审阅。
- 证据索引 `artifacts/realism458-validation/evidence-index.json`；审阅 `docs/VISUAL_REVIEW_STAGE458.md`；预览仍为 `artifacts/realism457-final-preview/Linux/launch.sh`。下一步结合剩余真实动作修改整条肩肘—袖口—腕掌结构；继续道路场地/山体植被实质修改、同机位前后对照、入口碰撞、建筑光照及联网验证。状态continue，未推送/发布。

### Stage459（2026-09-19）：连续路肩形体、当前预览及人物全套采样
- 南北/东西道路增加连续渐变土坡网格与碰撞，路口、端部及维修棚入口降坡；同机位前后、入口近景、宽幅地形均已实际审阅。近侧路缘形体改善，宽景变化有限，未消除所有横向色差、空旷道路、山体折面和重复树冠。
- 当前预览 `artifacts/realism459-final-preview/Linux/launch.sh`，PCK SHA256 `da01091d80f45619f21f19f7eeb38b4a9fc301bd4cc50a1ccf835da77c84e149`。修正初次编译和第二次三角朝向错误后第三次导出成功，invalid目录保留失败记录。
- 当前包新增8条土坡跨越、原路肩通行、建筑双向进入/护栏阻挡、三武器瞄准伤害及单机冒烟五项均真实退出0，见 `artifacts/realism459-validation/functions-verified/`。完整无--pose四姿势及SG/SR、第三人称站蹲采集均退出0，八图全部审阅。
- 环境三图完整且机位逐字段一致，但采集外层退出143、引擎退出码不可恢复，`environment-capture-audit.json`保留passed=false。旧457九段动作帧虽完整，原退出码也无法恢复，`inherited-motion-audit.json`不记通过；未把旧动作当当前验证。
- 人物仍有细长前臂、圆筒袖口、块状肩袖手套及蹲姿肘膝枪身拥挤，远处角色疑似离地。下一阶段结构修改整条肩肘—袖口—腕掌及IK根部约束，补三武器插匣/回握、站蹲、移动/中断连续证据，并核查正常物理中的远处角色；静帧不证明动作自然。
- `/health`200、空登录401，认证双客户端联网未验证。证据索引 `artifacts/realism459-validation/evidence-index.json`，报告 `docs/VISUAL_REVIEW_STAGE459.md`。保留建筑、地形植被、光照及功能完整目标；状态continue，未推送/发布，保留全部未提交修改。

## Stage460（2026-09-19）：道路混合修改及当前包人物复核，continue

- 将道路方格四角混合改为旋转扭曲域的三角足迹混合；同机位道路、入口近景、宽幅地形前后对照已审阅并记录相机。效果有限，横向色差及整体场地过渡尚未验收，不能当作明显画质提升已完成。
- 当前包环境采集、道路/坡肩通行、建筑入口双向及阻挡、AR/SG/SR瞄准遮挡伤害、单机smoke均退出0；详见 `artifacts/realism460-validation/validation-summary.json` 和 `functions-verified/`。
- 无过滤完整四姿势重试退出0；SG/SR及第三人称站/蹲换弹中点采集退出0且逐张审阅。仍有细长直袖、圆鼓手套、方块头肩和蹲姿轮廓拥挤。首次四姿势中断退出-15，保留失败记录。
- 动态采集1200秒超时退出-15，不通过；实际保留AR23帧完整采样时间线、SG6帧早段，SR及第三人称动态未覆盖。兼容渲染局部回放 `motion/viewer.html` 已生成，未浏览器播放；静态图不能证明连续动作自然。
- 本地预览 `artifacts/realism460-final-preview/Linux/launch.sh`，当前包哈希和逐项证据见汇总；完整审阅 `docs/VISUAL_REVIEW_STAGE460.md`。未推送、未发布，保留已有修改。
- 下一步：道路/场地过渡仍需结构性修复；结合本轮人物缺陷量测整段换弹肩位移、肘角及腕旋转，修改整臂比例与稳定肩肘轨迹，复核所有武器袖口/护木/弹匣接触及第三人称连续动作。保留建筑多样性、山体/树冠、光照及认证双客户端联网验证全部未完成目标。

## Stage461（2026-09-19）：弧形道路接入及当前人物基线，continue

- 新增带碰撞的弧形沥青接入面、退让混凝土起点、打开路沿标线并消除道路贴图低频明暗。修复候选包三角绕序导致的卡碰撞后重新导出；道路、入口、宽幅地形三个相同机位前后图均已审阅，局部接缝改善，但宽幅视觉变化有限，明显整体环境提升仍未完成。
- 当前预览 `artifacts/realism461-fixed-preview/Linux/launch.sh`，PCK SHA256 `58f70c41092fad480809b4200c042f6e7c32571cc92a4126d049f76212eee1db`。当前包接入双向各12/12路点、道路8次横穿、路肩12项、建筑6路线/2阻挡射线、三武器瞄准伤害及单机smoke六项均退出0，见 `artifacts/realism461-fixed-validation/functions-verified/`。
- 完整无筛选四姿势退出0；独立显示 :250 的SG/SR及第三人称站蹲补拍退出0，八张图全部审阅。前臂细长、圆团袖口掌部、第三人称肩肘鼓包及蹲姿膝枪手拥挤仍明显。可见持握弹匣，不应误报缺失；静态节点不能证明连续动作自然。
- 环境重试三图与相机元数据完整、退出0，但日志含NO GRAB，passed=false保留。初次截图中断及第二次其他武器X连接失败记录保留；不混用旧候选通过结果。当前连续动作和认证双客户端联网未验证；无认证health返回404不代表整个后台故障。
- 报告 `docs/VISUAL_REVIEW_STAGE461.md`，证据索引 `artifacts/realism461-fixed-validation/validation-summary.json`。下一阶段按当前人物基线结构性调整整臂比例和肩肘轨迹，先量测换弹肩位移/肘角/腕旋转，再复核三武器回握及第三人称站蹲连续接触；追查正常物理中的远处角色离地观感。保留道路宽幅效果、建筑多样性、山体植被、光照和联网完整目标。未推送或发布，保留全部已有修改。

## Stage462（2026-09-19）：道路照明烘焙候选，图形验证未通过，continue

- 将沥青低频照明校正移至 mipmap 生成前，随机采样同时旋转 UV/梯度；新增同机位对照工具。纹理指标改善不代表实机矩形色差消除，道路场地过渡尚未验收。
- 当前导出 `artifacts/realism462-preview/Linux/launch.sh`，PCK `fbc859864f853c5cc04911f27cd2d3aad4a7e1e6a14724656944bcc9d993a93a`；导入/导出退出0，当前包接入通行、建筑碰撞、三武器瞄准伤害、单机smoke四项通过。图形可玩性尚未验证。
- 多图形进程竞争资源后改为仅留环境采集，入口首帧仍未产出；937.274秒主动中断退出-15，三机位请求无PNG，仅入口相机元数据。完整无筛选四姿势、其他武器及第三人称、连续动作采集均中断，无当前图像/动态证据，不能沿用461通过结论。
- `diagnostic-no-bump` 图实际使用461包，仅用于旧色带原因排查。联网脚本新增导出包选择，当前尝试在本地 `/auth/login` 返回404，双客户端尚未启动；未改后台或认证。
- 报告 `docs/VISUAL_REVIEW_STAGE462.md`；当前结果 `artifacts/realism462-validation/validation-summary.json`。下一步先串行定位渲染首帧开销，补齐道路/入口/宽幅同机位前后实机图，判断是否保留候选；随后完整人物四姿势、SG/SR及第三人称、连续肩肘腕和回握接触审阅，推进整臂结构修改。保留建筑、山体植被、光照和联网全部目标。未推送、未发布，保留所有原有修改。

## Stage463（2026-09-19）：道路实机恢复、同机位过渡改善与人物复审，continue

- 道路过滤改为三线性 mipmap，法线改用解析噪声梯度；隔离实验定位本机 llvmpipe 的各向异性/显式梯度采样问题，失败日志保留。当前 Forward+ 道路图恢复，较461同机位宽横向矩形明暗带明显减弱；强颗粒和移动闪烁仍待检查，场地大片光滑表面未解决。
- 道路、入口、宽景三组同机位前后图全部人工审阅，相机位置/朝向和哈希见 `artifacts/realism463-validation/comparisons/camera-comparison.json`。首次环境组360秒超时产出两图，道路独立重试258.614秒退出0；合并目录注明来源，不冒充整组通过。
- 当前包道路横穿、路肩、建筑通行碰撞、三武器瞄准伤害、单机smoke五项均通过，见 `functions-verified/`。无筛选完整四姿势622.912秒退出0；SG/SR与第三人称站蹲换弹补拍重试660.92秒退出0，八张人物图全部人工审阅，初次补拍中断也保留。
- 人物仍有管状细长前臂、球状袖口、生硬腕折、第三人称肩肘鼓包和蹲姿膝枪手拥挤。代码中换弹IK可移动肩部来追手掌目标，下一阶段联合修改整臂比例/袖形、肩部约束和三武器弹匣轨迹，不能只微调手指。当前中点与四姿势不证明连续动作，须覆盖0.6换匣交接、插入及回握，并补正常物理下第三人称跑动/蹲起；远处角色离地观感也需正常物理复查。
- 本地预览 `artifacts/realism463-preview/Linux/launch.sh`，PCK `8a0cc357acc965122ea37618a8a5290ea5760dd7edc49d31e30588fbaf53e5a1`。能生成实机帧不代表交互帧率合格。联网预检 `/auth/login` HTTP404，双客户端未验证；未改后台或认证。
- 报告 `docs/VISUAL_REVIEW_STAGE463.md`，证据索引 `artifacts/realism463-validation/validation-summary.json`。保留人物武器、建筑多样性、山体植被、场地过渡、光照和联网完整目标。未推送、未发布，保留所有已有修改。

### stage464 — 前臂体积与当前包人物/功能复核（继续）
- 调整前臂肌腹截面并重建Blender/GLB及本地预览；同机位前后对比仅有限改善，腕部、袖口和第三人称肩颈体块仍需结构修改。审阅：`docs/VISUAL_REVIEW_STAGE464.md`。
- 全四姿势均出图并逐张审阅，但wrapper退出143，不能计正常退出通过；其他武器/第三人称四张正常通过。AR换弹0—2.2秒23帧已检查，九组动作采集主动中断退出-15，其余八组未覆盖；插匣接触仍不清楚。播放器：`artifacts/realism464-validation/motion-culled-retry/viewer.html`。
- 当前PCK五项本地检查通过：道路坡度、路肩、建筑入口通行、瞄准伤害、单机；联网认证路由探测404，未验双客户端。总证据：`artifacts/realism464-validation/validation-summary.json`。预览：`artifacts/realism464-preview/Linux/launch.sh`。
- 下一步：联合修整肩肘腕、袖口及换弹轨迹，补齐其他武器与第三人称动态、跑动蹲起接触，重跑正常退出的完整四姿势；继续处理道路噪点、山体与重复植被并重拍入口/宽幅同机位，保留建筑、光照与联网目标。未发布、未推送。

### stage465 — 当前包完整四姿势、SR 动作与审计范围修复（2026-09-19）

- 游戏仍为 stage464，未把本轮工具/验证当作画质提升。动作工具支持指定组并严格区分部分通过与九组全套通过；4 项范围/缺帧/异常退出测试通过。
- SR 第一人称及第三人称站姿各 33 帧正常退出，已审阅；目录 `artifacts/realism465-validation/shotgun-motion/` 实为 weapon 2 SR。九组未全部覆盖，固定模拟诊断采图不证明实时交互自然。
- 当前包 Forward+ 完整四姿势（无 --pose）630.883 秒退出 0，四张逐张审阅；道路、路肩、建筑入口、三武器瞄准伤害、单机五项重跑通过。认证路由本轮仍 HTTP 404，联网未验证。
- 可见长套筒前臂、生硬腕袖、第三人称鼓肩细颈与僵硬躯干；道路强颗粒、光滑山体、重复树冠仍在。下一步整臂/肩肘袖口与换弹轨迹联合结构修改，补 SG、第三人称蹲姿及正常移动动作，再继续环境与联网目标。
- 证据索引：`artifacts/realism465-validation/validation-summary.json`；审阅：`docs/VISUAL_REVIEW_STAGE465.md`；本地预览：`artifacts/realism464-preview/Linux/launch.sh`。本轮无新增环境同机位前后对照。

### stage466 — 双臂肩部约束与换弹轨迹结构修改（2026-09-19）

- 第一人称持枪／换弹改为双臂 IK，肩部按相机中立位置约束，降低抬枪前伸幅度；同机位换弹中段对照可见枪托回到画面内。左肩漂移约 0.0000085m，右肩仍有约 0.05465m 前伸补偿，未宣称完全固定。
- 当前导出包完整四姿势无 --pose 重跑 604.585 秒退出 0，四张逐张审阅；首次运行退出 -15 的记录保留。SG 第一人称／第三人称蹲姿各 31 帧正常退出并审阅，全九组未覆盖，10Hz 诊断不证明连续动作自然。
- 当前包换弹接触、肩肘骨长诊断、三武器瞄准伤害、建筑入口通行及单机五项本地检查通过；联网接口仍 404，双客户端未验证。
- 长管状前臂、生硬袖口、第三人称厚重体型和手部接触细节仍需结构修改；下一步重建肌腹／肘袖连续轮廓与形变，补近景和连续输入动作，再推进道路噪点、山体、重复树冠、建筑与光照。无新增环境验收，保留环境同机位／入口／宽幅及联网目标。
- 审阅：`docs/VISUAL_REVIEW_STAGE466.md`；证据：`artifacts/realism466-validation/validation-summary.json`、`full-four-poses-retry/`、`sg-motion/viewer.html`；预览：`artifacts/realism466-preview/Linux/launch.sh`。未推送或发布。

### Stage467（2026-09-19）道路试改与当前包完整四姿势／SR 动作审阅
- 道路 shader 调整骨料尺度、法线远近衰减和破损边缘混合；466/467 重采道路、入口、宽幅地形同机位前后对照。实机仍像亮碎石，改善不足，**道路画质未验收**，整体 continue。
- 当前467包五项功能检查通过：起伏道路、路肩碰撞、建筑通行、瞄准伤害、单机冒烟。完整四姿势无过滤采集并审阅；另补 SR 第一／第三人称站姿各33帧，未运行全9段。长管前臂、厚硬袖口、肩肘分段及装备块状感仍在；枪身遮挡使弹匣插入／护木接触不能完整确认。诊断动作采样不证明正常画质或实时动作自然。
- 本地 /protocol、/auth/login 返回404，联网主要功能未验证；未改后台。报告 docs/VISUAL_REVIEW_STAGE467.md；证据 artifacts/realism467-validation/{comparison,full-four-poses,sr-motion,functions-verified}/，汇总 validation-summary.json。可运行预览 artifacts/realism467-preview/Linux/launch.sh，指纹已核对，未发布／推送。
- 下一步：优先结构性处理沥青胶结表层与亮骨料、路肩及入口场地过渡，勿继续仅调色加草；随后改前臂肩肘袖口及换弹接触。山体、重复树冠、建筑光照、其他武器连续动作和联网仍保留为未完成目标。

## Stage468 — 道路分层材质与当前人物审阅（2026-09-19）

将路面改为胶结料、嵌入骨料及边缘剥蚀分层，减弱浅色碎石毯与连续亮边。stage467 存档与 stage468 Forward+ 同机位三组对照已审阅，含入口近景和宽幅地形；入口矩形边缘、道路接缝、平滑山体及重复树冠仍未解决。详见 `docs/VISUAL_REVIEW_STAGE468.md`。

当前包未过滤的完整四姿势采集退出 0，逐张审阅仍见直管袖、厚袖口、块状枪托与手掌。SR 第一人称、SG 第三人称站姿两段换弹采样退出 0，共64张，仅为 Compatibility 离散诊断；九段全套未完成，AR 部分21张和中断记录保留。没有宣称连续动作自然或接触通过。五项当前包测试通过：道路、路肩、建筑通行/碰撞、瞄准伤害、单机 smoke。联网两个本地接口 HTTP404，双客户端与联网主要功能未验证。

证据：`artifacts/realism468-validation/validation-summary.json`、`comparison/`、`full-four-poses-retry/`、`other-weapons-third-person/viewer.html`、`functions-verified/functional-results.json`。本地预览：`artifacts/realism468-preview/Linux/launch.sh`，PCK `dffae7f07f45035fb73cc31a00a9df5ff7a5721a1d5fe64185830132e6522a43`，未推送或发布。

下一步：结构修改前臂肌腹、肘弯和袖口，复查护木握持与换弹接触，补齐其余武器/第三人称蹲姿及正常渲染连续动作。继续保留场地几何、山体植被、建筑光照与联网完整目标。状态 continue。

## Stage469 — 道路接缝与场地坡面、当前动作复核（2026-09-19）

东西路拆段齐平对接，维修棚22×22平面改为弯道扫掠坡面与下沉边肩，更新碰撞。当前469包 Forward+ 三机位前后对照已审阅并核对相机：差异较小，横向色带和硬材料边界仍在，**未达到道路/场地明显效果验收**。首次环境进程-15保留，重试三机位退出0。

未过滤完整四姿势退出0并逐图审阅，直管前臂、厚袖口仍需结构修改。SR第一人称及AR第三人称站姿两段采样退出0，共56张，仅Compatibility动作诊断；肩肘拼接感、弹匣接触遮挡仍在，未证明连续动作自然。五项当前包检查通过：建筑双向通行/碰撞、道路、路肩、瞄准伤害、单机smoke。联网接口HTTP404，未验证联网主要功能。

证据：`artifacts/realism469-validation/validation-summary.json`、`comparison/`、`full-four-poses/`、`other-weapons-third-person/viewer.html`、`functions/functional-results.json`；报告 `docs/VISUAL_REVIEW_STAGE469.md`。本地预览 `artifacts/realism469-preview/Linux/launch.sh`，PCK `716e20491202e590251ae46f5d9643e3eb32dfa8954a13653cbe9fb518671369`。未推送或发布。

下一步：依据本轮人物审阅结构修改前臂肌腹、肩肘动作锚点及袖口衔接，联合验证护木支撑与换弹接触，补正常渲染连续动作及其余武器/蹲姿。道路横带需近距离定位真实边界后处理，不能继续色值微调；山体植被、建筑光照及联网完整目标保留。状态continue。

### Stage470（2026-09-19）：道路接合结构修复与当前人物复核
- 支路网格止于主路边界并匹配接合高度，剔除退化三角形；宽横向粉尘改为弧形双轮迹。同机位道路/入口/宽幅地形 Forward+ 实机对照已审阅，横跨主路浅带明显减弱，土场硬边、平坦建筑场地、光滑远山及重复树冠仍在。
- 当前包完整四姿势（无 --pose）全部采集与审阅；另完成霰弹枪第一人称、第三人称蹲姿各31帧。后者仅 Compatibility 动作诊断，非全部动作通过：管状前臂、厚袖口、分块肩肘仍明显，换弹交接部分出画，采样间连续性及细部接触未证实。
- 当前包建筑通行、坡道路面、路肩、瞄准伤害、单机 smoke 五项通过，新增接缝12支撑点+6双向穿越通过。联网接口仍HTTP404，未验证联网；保留初次中断及解析失败记录。
- 证据：docs/VISUAL_REVIEW_STAGE470.md；artifacts/realism470-validation/validation-summary.json、comparison/、full-four-poses/、other-weapons-third-person-retry/viewer.html、functions/。本地预览 artifacts/realism470-preview/Linux/launch.sh，PCK d0ed75b63a8b3358d10b34948ad9e724bcd32d89bd6843e7db50460b2223a96a。未推送或发布，整体目标未完成。
- 下一步：结构性修复前臂截面与袖口衔接，结合肩肘、手掌朝向及换弹路径检查护木/弹匣接触；修改后重跑完整四姿势，补其他武器及近距第三人称站/蹲连续动作。继续保留地形植被、建筑场地光照、单机/联网功能目标，不以截图数或规则通过替代画质审阅。

### Stage471 — 前臂截面结构与当前包验证（2026-09-19）

承接470道路接合修复，本轮将第一人称前臂改为宽厚独立的椭圆肌腹，并匹配肘部截面；重建 Blender/GLB 和本地预览。完整四姿势 Forward+ 采集通过且四组前后对照已审阅，前臂膨胀感减轻，但手套块状、直臂僵硬、换弹接触靠近屏幕下沿仍明显。当前包六项通行/碰撞/瞄准/单机检查通过。动作诊断保存 AR、SG 第一人称完整采样和 SR 蹲姿第三人称33帧；九段总采集主动终止，仅60帧，未通过，连续动作自然性与剩余姿态未验证。联网未认证验证，GET 404 不作为服务不存在的结论。

证据：`docs/VISUAL_REVIEW_STAGE471.md`、`artifacts/realism471-validation/validation-summary.json`、`comparison/`、`full-four-poses-retry/`、两动作目录的 `viewer.html`；预览 `artifacts/realism471-preview/Linux/launch.sh`（PCK 8b99476b40efc6296ada3bdc9680c092143136ae3d14ed554b8b4c85dd5f019c）。下一步：近距第三人称肩肘和第一人称换弹路径结构修改，补正常渲染动态接触及其余武器姿态；继续场地硬边、山体植被、建筑光照和联网。整体 continue，未推送发布。

### Stage472 — 换弹可见路径与当前包复核

- 接续471/470实际文件，修改 `first_person.gd`：轴向抽匣后侧移展示，再下探弹袋；同机位对照确认中段手与弹匣从屏幕下沿裁切变为完整可见。人物形体尚未通过。
- 本地预览 `artifacts/realism472-preview/Linux/launch.sh`；正常 Forward+ 完整四姿势全部实机审阅通过采集，四项本版功能测试通过（单机、三武器瞄准伤害、入口通行碰撞、换弹接触规则）。哈希及证据见 `artifacts/realism472-validation/validation-summary.json`。
- 第一次动作采集 KeyboardInterrupt/-15，仅留霰弹枪18帧，保留失败；第三人称步枪站姿补采23帧成功，均为低清GL诊断，九段套件未通过。两组 viewer.html 与审阅图已保存；不能证明连续动作自然。
- 审阅 `docs/VISUAL_REVIEW_STAGE472.md`：前臂僵直、厚袖口、块状手套与棱角肩肘仍突出。下一阶段优先结构性修正肩肘/袖口衔接并拉近第三人称审阅，补齐其他武器插匣、蹲姿/移动换弹；仍需场地硬边、山体植被、建筑与光照推进，重拍入口/宽幅地形并验证联网。整体继续，未发布、未推送。

### Stage473 — 弯道场地过渡与当前四姿势审阅

- 场地遮罩改用实际16段弯道中心线，拓宽不规则填土坡脚并抬高道路渐隐边缘；当前包三机位与重新采集的472包相机完全一致，保存道路、入口、宽幅地形对照。接入处有所改善，但主路填土偏宽、近景三角硬边仍存在，不判环境完成。
- 本地预览 `artifacts/realism473-preview/Linux/launch.sh`，PCK `a9711875d104e3a5bf6362cf2bec39d2b84c67faf0d1dc0a546a6b2ecff869b5`。当前包单机、三武器瞄准伤害、路肩/接缝/维修棚通行碰撞通过；完整四姿势无过滤采集并实际审阅，细长前臂、圆盘袖口、肩肘形体仍需结构修改。
- 环境主采集中断后独立补齐道路图，保留来源及失败状态。两次动作采集均只有霰弹枪两帧，补采由本轮主动终止，第三人称尚未覆盖；viewer明确不完整，不能证明连续动作自然。联网仅健康探测，未验证对战同步。
- 证据 `docs/VISUAL_REVIEW_STAGE473.md`、`artifacts/realism473-validation/validation-summary.json`、`comparison/`、`sleeve-poses/`。下一步处理前臂/袖口体积与肩肘链，补其他武器及近距第三人称完整动作、插匣/回握接触；继续场地硬边、山体植被、建筑光照和联网实测。整体continue，保留未提交修改，未推送发布。


### Stage474 — 主路覆盖修复与完整四姿势、九段动作诊断

- 限制维修场地遮罩侵入沥青，给扫掠土方添加顶点渐隐；已审阅473→474相同三机位道路、入口、宽景对照，主路浅色矩形覆盖消除，白色边线恢复连续。前场斜向硬边和暗缝仍在，不判环境完成。相机与截图来源见 `comparison/camera-comparison.json`、`after-combined/provenance.json`。
- 当前包路肩/路口/维修棚实际通行碰撞、三武器瞄准命中与遮挡、单机烟测通过。完整正常世界四姿势无过滤重跑退出0、全部实机审阅；中断尝试保留。前臂细长僵直、圆环袖口仍明显，补弹成功不代表连续动作自然。
- 三武器×第一人称/第三人称站蹲九段换弹诊断共261帧，进程退出0且时间线完整；隐藏世界、低清无阴影，审阅发现肩袖块状，精细接触不可确认，full_suite_passed=false。未覆盖实时混合动作与联网同步；联网仅健康探测。
- 证据 `docs/VISUAL_REVIEW_STAGE474.md`、`artifacts/realism474-validation/validation-summary.json`、`comparison/`、`sleeve-poses-retry/`、`isolated-motion/viewer.html`。本地预览 `artifacts/realism474-preview/Linux/launch.sh`，PCK `b477984496a68cc31547474ccd9b72c5904f114d4ed0c313fe157fe0008326f4`。
- 下一步整体修改前臂—肘部—袖口连续体积与肩肘/回握轨迹，补正常世界其他武器和近距第三人称动态接触；继续残余场地硬边、山体植被、建筑光照及当前版真实联网。整体continue，保留未提交修改，未推送发布。


### Stage475 — 场地按像素深度过渡与正常世界人物复核

- 两个场地 shader 改用 alpha hash 深度处理，474→475 同机位入口、宽景、道路对照确认前场斜向硬边明显软化；近处新增颗粒，移动闪烁未覆盖，环境未完成。精确机位与对照在 `artifacts/realism475-validation/comparison/`。
- 当前475包完整四姿势无过滤通过且全部实机审阅；霰弹枪、狙击枪及第三人称站/蹲换弹中点重跑665秒退出0，四张正常世界截图均审阅，首次中断记录保留。细直前臂、厚环袖口、圆鼓肩部与收缩肘部仍明显；蹲姿接触遮挡，远处角色疑似悬空待定位。静态采样不证明连续动作自然。
- 当前包路肩、路口、维修棚通行碰撞、三武器瞄准伤害及单机烟测通过；网络仅健康探测，实际联网玩法未验证。
- 证据 `docs/VISUAL_REVIEW_STAGE475.md`、`artifacts/realism475-validation/validation-summary.json`、`viewer.html`、`sleeve-poses/`、`contacts-retry/`、`functional/`。本地预览 `artifacts/realism475-preview/Linux/launch.sh`，PCK `4dba476b18aa22362e12632e4106f0e2e3f72275dbb1fa7b058bdfc55369465b`。
- 下一步整体修改前臂—肘部—袖口体积与肩肘解算，补拔匣、插匣、回握连续过程；继续消除地面重叠颗粒，推进山体、树冠差异、建筑室内、光照及真实联网验证。整体continue，保留所有未提交修改，未推送发布。


### Stage476 — 上臂连续截面重建与当前包人物审阅

- 上臂改为肘到肩的连续三次曲线与分段解剖截面，重建 Blender/GLB 并导出476本地包；实机上臂多在镜头外，前臂细直、袖口厚环仍明显，本轮可见改善不足，不能视为人物目标完成。
- 当前包完整四姿势与SG/SR、第三人称站蹲换弹中点共八张正常世界截图全部生成并审阅；475→476同机位对照保留。第三人称肩肘、鞋和装备仍简化，背景角色疑似悬空需定位。静态通过只代表采样成功。
- 正常世界AR连续采样运行825.69秒仅保存0–0.3秒四帧后主动停止，部分帧已审阅，full_suite_passed=false；保留 viewer 与中断记录，拔匣、插匣、回握以及其他武器和第三人称连续过程均未完成。软件渲染负担需调查。
- 当前476包维修棚通行碰撞、三武器瞄准伤害与单机冒烟测试退出0；未重跑全地图/路肩路口，也未验证实际联网。本轮无专门入口/宽幅地形新截图，历史环境验证不算当前包通过。
- 证据 `docs/VISUAL_REVIEW_STAGE476.md`、`artifacts/realism476-validation/validation-summary.json`、`sleeve-poses/`、`contacts/`、`comparison/`、`motion-first-ar/viewer.html`、`functional/`。本地预览 `artifacts/realism476-preview/Linux/launch.sh`，PCK `f838daae493bac36f110603a08aac8fe5f0f6c61e8cda0a6e85ebb3e8fdb5105`。
- 下一步调查正常世界渲染成本，整体修改可见前臂—肘部—袖口体积及肩肘/回握轨迹，补完整动态接触；保留地面颗粒闪烁、山体树冠、建筑室内、光照和联网目标。整体continue，保留全部未提交修改，未推送发布。


### Stage477 — 道路低缓过渡重建及人物实机复审

- 将高路肩改成延伸至道路内侧的低缓碎石断面（设计峰值 0.24→0.075m），统一铺装、边线和轮迹尺度；道路远景车行面明显收窄、土堤减弱。入口与宽景灰色场地、直边和模糊材质仍需修复。
- 保存476→477道路/入口/地形三组同机位对照，位置、朝向和图像哈希见 `artifacts/realism477-validation/comparison/camera-comparison.json`。
- 当前477包道路八方向横穿、维修库通行碰撞、AR/SG/SR瞄准遮挡及单机smoke通过。联网登录前置 `/auth/login` HTTP404，未验证联网成功、未修改后台。
- 完整四姿势一次运行通过并逐图审阅；补齐SG/SR及第三人称站蹲换弹中点。细长前臂、硬袖口、肩肘转折和简化人物枪械仍突出；遮挡不能证明接触正确，连续换弹/站蹲/移动与ADS切换未覆盖。
- 当前可启动预览 `artifacts/realism477-preview/Linux/launch.sh`；PCK SHA256 `65d24d0ef1808615227d9ba4bfdf3bb2ae5c65cb295a7e70544307d8ae2020bd`。证据汇总 `artifacts/realism477-validation/validation-summary.json`，审阅 `docs/VISUAL_REVIEW_STAGE477.md`。
- 下一步：联合修改前臂比例、肘部弯曲和镜头构图/持枪约束，再跑完整人物覆盖并补连续动作。保留场地过渡、山体、树冠、建筑光照和联网完整目标；本轮不宣称整体完成。


### Stage478 — 前臂体积调整、完整姿势与换弹采样复核

- 接续477道路结构阶段，加厚前臂近肘/中段并收窄腕端，重新生成Blender/GLB及本地包。改善有限：长直前臂、硬袖口、钩状手套及肩肘构图仍需结构性修复，不视为整体画质完成。
- 当前包Forward+完整四姿势一次运行、SG/SR及第三人称站蹲换弹中点均完成并逐图审阅；同机位前后对照见 `artifacts/realism478-validation/comparison/`。蹲姿手臂枪械膝部拥挤；远处疑似悬空人物可能来自截图脚本冻结世界物理，需正常运行辨别。
- AR换弹23帧诊断序列及恢复采样已审阅，见 `motion-first-ar/viewer.html`；仅640×400兼容模式、关闭阴影/裁远景，不代表完整动态或正常环境通过。66–78帧手和弹匣在画外、114–120帧回握需更密采样；其他武器/第三人称连续动作未覆盖。
- 当前包道路、维修棚入口通行碰撞、三武器瞄准遮挡6样本、单机smoke通过。修正旧骨骼数和Y轴弹匣退出断言后viewmodel_rules第三次重跑通过；原headless关键帧45次空图像错误作废，新增图形环境守卫并验证退出1。保留所有失败日志；606项可达性只作诊断。
- 构建包含右手网格自动修复与headless dummy纹理错误，未隐瞒为干净构建。联网 `/auth/login` HTTP404，仍未验证；本轮未重拍专门道路/入口/宽景环境组，不沿用477作为当前通过。
- 预览 `artifacts/realism478-preview/Linux/launch.sh`，PCK `1336410956782ea98a6c35845199fe3bde5fc8757ff713b852660e88f9a8424e`；审阅 `docs/VISUAL_REVIEW_STAGE478.md`，汇总 `artifacts/realism478-validation/validation-summary.json`。
- 下一步联合修正肩肘约束、前臂投影长度及回握轨迹，补正常运行落地和更密连续接触证据。保留道路场地直边、山体树冠、建筑室内/光照及联网目标。整体continue，保留未提交修改，未推送发布。

### Stage479 — 道路共享地表采样、当前包环境与人物复核

- 提取共用地表采样，让道路外肩接入场地纹理、法线和粗糙度；最终采用三线性mip过滤。相同三机位前后实机对照已审阅，但道路横向色带与浅色折线边界仍明显，未达到“明显改善”验收要求。
- 当前包完整四姿势、SG/SR换弹中点及第三人称站蹲换弹截图全部完成并逐图审阅；前臂细长、肘端鼓胀、硬袖口及第三人称肩部形体仍需结构性修复。掌面/枪托被遮挡不能证明接触自然；连续换弹、移动和正常落地未覆盖。
- 当前包道路8路线、维修棚入口通行碰撞7路线、三武器瞄准遮挡6样本及16角色单机smoke通过。联网本轮未验证。中断的旧捕获日志与局部截图保留，不计为完整通过；llvmpipe结果不代表硬件GPU性能。
- 预览：`artifacts/realism479-filtered-preview/Linux/launch.sh`；PCK `78143285c670977c8e4bc630d72c2c06ad826c8379c1b524d184d5a89acecbe4`。证据：`artifacts/realism479-validation/comparison/`、`filtered-sleeve-poses/`、`filtered-weapon-contacts/`、`filtered-functional/results.json`；审阅 `docs/VISUAL_REVIEW_STAGE479.md`，汇总 `artifacts/realism479-validation/validation-summary.json`。
- 下一步优先定位独立224×224场地覆盖平面与入口地坪硬裁切对道路色带的贡献，修复实际场地轮廓和几何接缝，再重拍三机位并重跑通行。随后联合修改肩肘形体与回握路径；保留山体、树冠、建筑室内/光照及联网目标。整体continue，未推送或发布。

### Stage480：场地覆盖收束、当前包环境与人物实机复核（continue）
- 将维修场地地面从 224×224 收到实际 52×46 范围，移除场地 shader 重复道路肩带；同机位对照确认右侧重复浅带消失，但横向硬色差仍在，未判整体完成。
- 当前包 `artifacts/realism480-preview/Linux/launch.sh`；PCK SHA256 `00f1d0f2d3b88baf66d9d0d0a235e0c648333b498196445ff99c503eee2418b0`。环境入口/道路/宽幅地形三组对照及相机元数据：`artifacts/realism480-validation/comparison/`。
- 当前包道路 8 路线、入口/场地 7 路线及树木间距、三枪命中/墙体阻挡 6 案例、offline-smoke 通过：`artifacts/realism480-validation/functional/results.json`。首次 shader 错误版本保留但排除，修复后已重新导出并验证。
- 完整四姿势（无 --pose 过滤）通过并全部实看：`artifacts/realism480-validation/sleeve-poses/`；其他两枪换弹中段及第三人称站/蹲四张通过并全部实看：`artifacts/realism480-validation/weapon-contacts/`。袖筒细长、近肘鼓包、腕口突变；第三人称头脸简化、蹲姿手/弹匣/膝部遮挡，连续动作与全程接触尚未证明。
- 本机未认证 `/auth/login` 探测 404，联网主要流程未验证；未读取认证信息、未改服务。完整审阅：`docs/VISUAL_REVIEW_STAGE480.md`。
- 下一步优先结构性修改第一人称上臂/肘/前臂/袖口与蒙皮、肩部约束，并补连续换弹/瞄准/跑动及第三人称接触证据；随后隔离道路横向贴面交叠，推进山体、重复树冠、建筑材质和光照。补足当前包联网验证，勿用截图数量或旧通过记录代替质量判断。

## Stage481：道路连续路肩尝试与当前包完整审阅（未验收）

- 恢复右侧场地段连续路肩，导出 `artifacts/realism481-preview/Linux/launch.sh`；三机位前后图与相机数据保存在 `artifacts/realism481-validation/comparison/`。实看横向硬矩形仍在，不能认定明显改善。关闭太阳阴影的同机位诊断亦保留边界，下一步隔离地面覆盖层/材质混合。
- 完整四姿势手臂、其他两枪换弹及第三人称站/蹲换弹均完成实机截图并逐图审阅。细长前臂、硬袖口肩肘、简化面部仍明显；未覆盖连续抽匣插匣回握、跑动落地及 ADS 切换，不能判动作自然。
- 当前包原有道路8路线、维修棚7路线、三枪6瞄准案例、16角色单机 smoke 子进程退出0；新增24条横穿仅22通过，最终 `frontage-colliders/` 保存 FAIL。z26右肩两方向命中同一碰撞体 `(9.283261,0.38303,26)`，疑似挡土石，须核对设计通行口，禁止移动路线掩盖。联网本轮未验证。
- 详见 `docs/VISUAL_REVIEW_STAGE481.md`、`artifacts/realism481-validation/validation-summary.json`；未发布、未改后台服务，保留未提交修改。下一轮先解决道路覆盖层真实硬边界并同机位验收，再结构性修改肩肘/前臂与连续回握；建筑、地形植被、光照、单机与联网目标继续保留。

### stage482：道路转入口结构修复与当前人物审阅（continue）
- 移除独立连接沥青面，直接展开连续路肩并统一泥地过渡距离场；三组同机位前后图显示右侧横向浅灰矩形带明显减弱。入口近景、宽幅地形及相机记录：`artifacts/realism482-validation/comparison/`、`environment/`；审阅：`docs/VISUAL_REVIEW_STAGE482.md`。
- 当前包完成并审阅完整四姿势 `sleeve/`，以及 SG8/SR5换弹、第三人称站立/蹲姿 `contacts/` 四图。仍有肘部鼓胀、前臂过细、硬袖口及接触遮挡；蹲姿背景角色疑似悬空待区分捕获初始化与运行物理。离散截图不能证明连续换弹、回握、肩肘轨迹自然。
- 当前包维修棚7路线/碰撞、3武器6伤害遮挡案例及16角色单机smoke通过；道路横穿22/24通过，z26右侧双向碰撞失败未修复。联网仅本地API健康200，未验证主要联网流程。证据汇总：`artifacts/realism482-validation/validation-summary.json`。
- 本地预览：`artifacts/realism482-preview/Linux/launch.sh`；来源摘要见同级上层 `build-manifest.json`。未推送、未发布，保留既有修改。
- 下一步：结构性修改袖体/肩肘及回握运动并补连续证据，修复z26通行问题；继续山体、树冠、建筑空间材质、光照和当前联网验证。整体目标未完成。


### Stage483 — 北侧横穿口碰撞修复与当前人物复审
- 挡土石北端逐层退让，恢复 z26 双向横穿；保留其余网格碰撞和随机序列，未降低测试阈值。当前冻结包道路 24/24、维修棚 7 路线及 25 碰撞检查、三枪命中/遮挡 6 案例、16 角色单机 smoke 通过。
- 当前预览：`artifacts/realism483-preview/Linux/launch.sh`；包散列与来源见 build-manifest.json。验证汇总：`artifacts/realism483-validation/validation-summary.json`；实图审阅：`docs/VISUAL_REVIEW_STAGE483.md`。
- 环境四机位实图、入口近景、宽幅地形及相同相机前后对照已审阅；相机位置/朝向随图记录。横穿口变化受树木遮挡，视觉收益有限，整体画面基本一致，不能宣称明显画质提升。
- 完整四姿势图全部生成并审阅，捕获断言通过；外层执行 exit143、结果文件未收尾，原因未知，不能记作无异常运行。SG-8/SR-5 与第三人称站/蹲换弹中段四图正常捕获退出并审阅。当前仍有细长前臂、鼓起肘肩、硬袖口和简化面部，蹲姿接触遮挡；背景离地角色需连续场景核实。
- 下一步优先结构性修改共用袖体、肘腕体积和蒙皮，重跑完整四姿势与多枪/第三人称，并补抽匣—插匣—回握、ADS、奔跑落地连续证据。建筑/场地硬材质边界、光滑山体、重复树冠、光照和当前联网主流程仍未完成；不以石块或颜色微调替代这些工作。未发布，保留未提交修改。

### Stage484 — 连续袖体包络与完整人物动作复审
- 前臂改为连续三次曲线包络并同步肘侧边界，重新生成 Blender/GLB 和本地预览；同机位前后对照显示鼓包略减、过渡更连续，仍有锥形僵硬感，不能视为整体画质达标。
- 当前预览：`artifacts/realism484-preview/Linux/launch.sh`。当前包三枪瞄准/遮挡、道路通行、维修棚通行碰撞、16 角色单机 smoke 均退出 0；汇总 `artifacts/realism484-validation/validation-summary.json`。
- 完整四姿势（未使用单 pose）、其他两枪及第三人称站/蹲换弹中段均正常退出 0，8 张正式截图逐张审阅。步枪换弹 23 帧诊断序列完整退出 0，但仅一个 Compatibility 片段，不能证明全动作通过。图片、相机与过程日志在本轮 validation 目录，实图评述见 `docs/VISUAL_REVIEW_STAGE484.md`。
- 短弹匣包覆不足、圆鼓护垫、第三人称尖鼓肘袖与简化面部仍明显；蹲姿膝盖遮挡接触，背景离地角色需连续核查。下一步按武器重建抽匣—换新—插匣—回握目标/朝向，补第三人称侧面连续肩肘和奔跑落地，而非继续局部尺寸微调。
- 本轮没有重新捕获环境专用机位，历史环境证据不记作当前通过。保留建筑入口/场地、光滑山体、重复植被及光照改造目标；联网未运行，现有脚本依赖认证信息，遵守不读取密钥限制，不能推断联网故障。未发布，保留所有未提交修改。

### Stage485 — 三枪换弹退出、转腕与返回路径
- 按三种武器设定弹匣退出距离和转腕，左掌目标随弹匣朝向变化，返回先对齐再插入；生成当前预览 `artifacts/realism485-preview/Linux/launch.sh`。源码快照、包散列、日志见本轮 validation/build-manifest.json。
- 完整四姿势（无单 pose 筛选）及其他两枪、第三人称站/蹲中段正式采集均退出 0，逐张实图审阅；相机与同机位前后对照已保存。评述 `docs/VISUAL_REVIEW_STAGE485.md`，汇总 `artifacts/realism485-validation/validation-summary.json`。
- 路径变化明显，但换弹中段左手/弹匣下移过多而出画，不能宣称画质改善通过。锥形袖筒、圆鼓护垫、第三人称肩肘和面部仍不自然；蹲姿接触被膝盖遮挡，背景疑似悬空角色仍待连续核查。
- 当前包单机 16 角色 smoke、三枪命中/遮挡 6 案例、道路 24 项、维修棚 7 路线及 25 碰撞检查通过。17 图扩展采集人工终止仅留 4 图；两次连续动作诊断均人工终止，仅开头两帧，审计明确未通过，未冒充连续验证。
- 下一步优先修复换弹全过程可见性及掌部包覆，定位逐帧采集耗时，补抽匣—插匣—回握与第三人称侧面肩肘、奔跑落地连续实证。随后推进山体、植被层次、建筑/场地材质与光照结构，补当前环境固定机位、入口近景和宽幅地形对照；本轮无新环境专用图，联网未运行，整体目标未完成。未发布或推送，保留全部未提交修改。

### Stage486 — 换弹出画回归修复，当前包复审（整体继续）
- 按各枪弹匣退出距离设置左下方交换路径，修复 Stage485 换弹中段左手/弹匣出画；同机位前后图 `artifacts/realism486-validation/reload-before-after.jpg`，相机记录 `reload-comparison-cameras.json`。道路结构已有 Stage482 检查点，本轮未改环境，也未将旧图算作当前环境通过。
- 当前 Forward+ 完整四姿势运行退出 0，四图逐张审阅；三枪瞄准遮挡、单机冒烟、道路24项及维修棚7路线/25次碰撞检查均退出0。证据在 `artifacts/realism486-validation/validation-summary.json`、`functional-processes.json` 及对应日志。
- 其他武器/第三人称四图完整且已审阅，但监控退出143、子进程退出码未知，整组不计通过，见 `other-third/recovery-audit.json`。九段动作诊断仅25帧，步枪第一人称23帧已审阅；第二枪采集停滞原因未明，主动终止，整套未通过，见 `motion/viewer.html` 和恢复审计。10Hz诊断采样不证明连续动作自然。
- 当前本地预览 `artifacts/realism486-preview/Linux/launch.sh`；10项源码/包散列核对一致。详审 `docs/VISUAL_REVIEW_STAGE486.md`。长直前臂、硬袖口、团块掌部、第三人称肩肘及蹲姿接触仍明显不足；联网未验证，无推送/发布，保留原有未提交修改。
- 下一步：结构性修改掌部包覆、腕/前臂体积及肩肘联动，查明采集停滞和监控退出，补齐其他武器、第三人称侧面连续动作及跑跳落地。随后推进山体、植被、建筑场地过渡及光照，补当前环境固定机位对照/入口近景/宽幅图，并补不读取现有密钥的本地联网验证。不能以本轮可见性修复宣称整体完成。

### Stage487 — 道路外坡结构修改与当前环境、人物复审（整体继续）
- 将道路外侧改为最高约 0.38m 的缓起伏土坡，在建筑路线和服务入口压平过渡，导出当前预览 `artifacts/realism487-preview/Linux/launch.sh`。同机位前后各三张环境图、入口近景和宽幅场地图均正常采集并审阅，对照 `artifacts/realism487-validation/road-before-after-comparison.png`，位置朝向见各目录相机 JSON。
- 完整四姿势（未筛选单 pose）与其他武器/第三人称四图重试均退出 0，八图逐张审阅；当前包道路24项、建筑通行/碰撞32项、瞄准6项及16人单机冒烟通过。失败和中断记录保留，详见 `docs/VISUAL_REVIEW_STAGE487.md`、`artifacts/realism487-validation/validation-summary.json`。13项输入已复核，环境脚本仅有注释修正，实际运行快照保留。
- 外坡起伏有所改善，但同机位对照仍有宽泥色带，尚未达到明显道路过渡修复的要求。细长前臂、硬袖口、团块掌部及第三人称肩肘仍不自然；蹲姿膝盖遮挡接触，背景疑似悬空角色需连续核查。静态图不能证明连续换弹或跑跳自然；联网本轮未运行。
- 下一步先联合修改道路断面宽度、材质覆盖及入口距离场，再做同机位复核；随后推进整臂比例、腕肘连续形体和第三人称动作实证。保留山体、重复树冠、建筑场地、光照及无现有密钥的本地联网验证目标。未推送或发布，保留全部未提交修改，整体目标未完成。

### Stage488 — 路肩断面收窄与当前环境、人物复验（整体继续）
- 收窄路肩并调整入口展宽和材质混合；当前预览 `artifacts/realism488-preview/Linux/launch.sh`。同机位道路、入口、宽幅地形三组前后对照已生成并审阅，机位匹配，但宽棕色带仍明显，**本轮道路视觉修复未验收**。
- 定位共享地表 `meadow_surface.gdshaderinc` 仍以 8m/7m 道路距离覆盖宽碎石带，使提前混入地表不能恢复自然地面；本轮保留该文件不变，源码及哈希已存档。下一阶段统一道路、地表与入口距离场及覆盖顺序，不能继续仅调色或土埂峰值。
- 当前包环境采集、完整四姿势（无 pose 过滤）、其他两枪及第三人称站蹲四图均退出0且逐张审阅；道路24项、入口通行/碰撞32项、三枪瞄准6项、单机冒烟通过。证据汇总 `artifacts/realism488-validation/validation-summary.json`，详审 `docs/VISUAL_REVIEW_STAGE488.md`。
- 长直前臂、厚袖口、块状掌部和第三人称肩肘仍不足；蹲姿膝盖遮挡换弹接触，远处离地角色需连续记录核查。静态截图不证明连续动作自然，联网本轮未验证。后续补侧面连续换弹/跑跳及不读取现有密钥的本地联网验证，保留建筑、山体、植被和光照目标。未推送或发布，保留全部未提交修改。

### Stage489（2026-09-19）：共用道路边界与当前包完整人物复审
- 修改 meadow_surface.gdshaderinc / road_surface.gdshader，共用主路、横路、入口距离及侵蚀边界，修正草地 8/7 米边界与路缘错位；未改人物资产或碰撞网格。
- 当前预览：`artifacts/realism489-preview/Linux/launch.sh`；PCK `7a19e86c780a8e9f77cb6921973b1a5b17c547d61eceafa4b5541e3ec293373a`，输入哈希验证通过。
- 三个环境机位前后对照完成且相机一致：`artifacts/realism489-validation/comparison/`。裸土带明显收窄，但泥绿长条仍偏光滑平直，入口变化小，宽幅场地仍空旷；不判整体道路画质通过。前两次环境采集中断 -15 的日志保留，第三次完整通过。
- 完整四姿势（无单个 --pose）和其他两武器、第三人称站/蹲换弹均完整运行通过并逐图审阅，证据在 `sleeve/`、`contact/`。长管前臂、厚袖口、圆块肩肘、简化脸靴仍明显，蹲姿接触被膝盖部分遮挡；离散采样不能证明连续动作自然。
- 当前包 roads 24、shelter 32、aim 6 采样及单机 16 actors 冒烟通过：`functional-processes.json`；未验证当前联网及所有建筑。
- 审阅：`docs/VISUAL_REVIEW_STAGE489.md`；汇总：`artifacts/realism489-validation/stage489-summary.json`。下一阶段优先肩肘空间关系、袖筒截面与弯曲轮廓的结构性修改，补持枪/瞄准/换弹/移动连续证据，复查第三人称看似离地角色；环境继续真实地表形态、场地磨损、山体与树冠结构，并保留建筑、光照和联网目标。状态 continue，未发布，保留所有未提交修改。

### Stage490：前臂截面与当前包人物/功能复验（整体继续）
- 调整前臂中段宽厚比和折面，重建 Blender/GLB 并导出 `artifacts/realism490-preview/Linux/launch.sh`。PCK `a1ce13d4c455d0090d00195ad0763ee82dd333e91a3fa99d235ef00ab15a1f6f`，资产哈希复核一致；同机位出生/ADS对照已审阅，改善有限，长直袖筒仍未达标。
- 当前包完整四姿势（无 --pose）与其他两枪、第三人称站蹲四图均完整退出0并逐图审阅；aim六项、建筑通行/碰撞和16人单机冒烟通过。第三人称圆肩、脸靴简化、膝盖遮挡接触仍明显；联网未验证。
- 完整9段连续动作采样未完成：Forward+仅2帧；兼容模式步枪第一人称0–1.1秒共12帧，均主动终止并保留失败状态。已审阅部分联系图，不能证明完整换弹自然；查看 `artifacts/realism490-validation/motion-compat/viewer.html`。实测约1.58万draw calls/1491万primitives，需降低场景渲染成本后补完整连续动作，不能继续仅凭静态图或规则断言通过。
- 审阅 `docs/VISUAL_REVIEW_STAGE490.md`；汇总 `artifacts/realism490-validation/stage490-summary.json`。下一步肩肘空间关系、弯曲袖筒与蹲姿结构，补其他武器和第三人称连续接触/跑跳及隔离本地联网验证。环境泥绿长带、空旷场地、光滑山体、重复树冠及建筑光照目标保留；本轮未重采环境三机位，不沿用历史通过。未发布，保留全部未提交修改。

### Stage491：路肩沉积轮廓尝试与当前包完整审阅（整体继续）
- 修改路肩外沿沉积高度及地表草地覆盖逻辑，三机位 stage490→491 同位置朝向对照已逐图审阅：局部轮廓变化，连续绿褐色带仍明显，入口和宽景变化很小，未达到道路显著改善门槛。证据 `artifacts/realism491-validation/comparison/`，相机记录见 `camera-comparison.json`。
- 当前包完整四姿势重试退出0（无 --pose，616.68秒），SG/SR及第三人称站蹲四样本退出0（714.946秒），全部逐图审阅。长细前臂、圆盘袖口、简化肩颈与蹲姿膝枪拥挤仍存在；换弹完成30/119不证明过程自然。首次四姿势SIGTERM失败保留；疑似悬空远景角色待区分捕获状态与正常落地。
- 当前包道路6项、建筑32项、三武器瞄准6样本、16角色单机冒烟四子进程通过；外层收集器退出143异常保留，当前联网及连续动作未验证。日志 `artifacts/realism491-validation/functional-processes.json`。
- 本地预览 `artifacts/realism491-preview/Linux/launch.sh`，PCK `506a212da4c3f14b3e5dcfa1cb45a78945f306a584b95da2c0cd426b6e875c91`。缺导出模板使export-release失败，export-pack成功后复用490运行时；输入及包哈希一致。审阅 `docs/VISUAL_REVIEW_STAGE491.md`，汇总 `artifacts/realism491-validation/stage491-summary.json`。
- 下一步结构性改造：world.gd整块y=0地表遮住下凹路肩，需共同修改地形基底网格与碰撞、衔接场地并保留入口平整，重复相同机位与通行检查；随后修复前臂/袖口/肩肘并补连续动作。建筑、山体树冠、光照和隔离本地联网目标均保留，不能再以局部颜色起伏代替整体进展。未发布，保留所有未提交修改，状态continue。

### Stage492：路肩外缘结构尝试、同机位对照与完整人物采样（整体继续）
- 扩展路肩剖面至12m，增加不连续沉积和冲刷缺口，压低入口通道；更新高度检查上限并导出当前包。三机位491→492对照均已审阅，相机/分辨率一致；变化有限，连续平坦绿褐带及场地硬边仍明显，不认定道路显著修复。证据 `artifacts/realism492-validation/comparison/`。
- 当前包道路横穿24项、路缘6项、建筑入口/碰撞32项、三武器瞄准6项及16角色单机冒烟通过。完整四姿势无 --pose 重跑退出0（590.924秒），SG/SR及第三人称站蹲四图退出0（904.438秒），全部逐图审阅；首次中断和错误启动日志保留。袖管细长、圆盘袖口、圆肩及蹲姿接触遮挡未解决；连续动作与当前联网未验证，背景悬空角色需排除捕获冻结影响。
- 预览 `artifacts/realism492-preview/Linux/launch.sh`；PCK `fad5442d49f499c946b48b48dfde8bc061e5cbeaa858e316e882df22a801fabe`。审阅 `docs/VISUAL_REVIEW_STAGE492.md`；汇总 `artifacts/realism492-validation/stage492-summary.json`，包含当前子进程结果与证据索引。
- 下一步直接处理 world.gd 的整块平面地表：基底网格与碰撞共同衔接路肩/场地，不继续叠加局部土坡；再做整体肩肘、袖筒和握持路径修改与连续动作验证。建筑、山体植被、光照、隔离本地联网目标均保留。未发布、保留未提交修改，状态 continue。

### Stage493：开挖地形基底与碰撞、当前包环境及人物复核（整体继续）
- world.gd 平面地表改为开挖网格与三角碰撞，道路随基底贴合，下调路肩剖面并保留入口平整。完整场景射线证实沟底约 -0.278/-0.193m、入口约 0/0.065m；旧平面遮挡问题已从结构上处理。独立差异 `artifacts/realism493-validation/road-structure.patch`。
- 重新采集492基线与493当前包的入口、宽幅地形、道路三机位并逐图审阅，相机匹配；道路宽直色带仍明显，视觉改善不足，不认定显著修复。当前包24条道路横穿、32条棚入口碰撞路线、路缘、三武器6项瞄准及16角色单机冒烟均通过。
- 完整四姿势无单独 --pose，退出0（710.657秒）；其他两把武器换弹与第三人称站蹲四图退出0（640.832秒），全部审阅。细长前臂、圆盘掌根、球状肩肘和接触遮挡仍在；连续动作、当前联网未验证，背景悬空角色待排除捕获冻结影响。
- 预览 `artifacts/realism493-preview/Linux/launch.sh`，PCK `cfa78b4fa5d3e148849f8dabd68775cbd8f00fb7add79f55e95dd364eebaa041`。审阅 `docs/VISUAL_REVIEW_STAGE493.md`；证据汇总 `artifacts/realism493-validation/stage493-summary.json`。
- 下一步逐层诊断道路实际暴露面与 shader 固定轴线遮罩，统一几何/材质边界后同机位复拍；随后整体修改肩肘腕链、袖筒和手掌体积并补连续动作。保留建筑、地形植被、光照及隔离本地联网目标。未发布，保留全部未提交修改，状态 continue。

### Stage494：道路表面统一、当前包回归与完整姿势审阅（未完成整体目标）

- 道路与场地改用同一开挖网格及碰撞，着色器按道路轴向处理铺装/路肩及端部过渡；生成 `artifacts/realism494-preview/Linux/launch.sh` 本地预览。
- 当前包道路24条路径、入口32项、三武器瞄准6样本与单机烟测通过：`artifacts/realism494-validation/checks.json`。联网未重验，不引用旧结果。
- 审阅入口、宽幅地形、道路三组同机位对照（stage493存档基线），保存相机/方向及来源；视觉改善有限，仍有宽平路肩，不能算道路过渡明显改善已完成。原采样被中断的记录保留，道路和其他武器补跑成功。
- 第一人称完整四姿势（无单姿势过滤）及霰弹枪、精确射手步枪、第三人称站/蹲换弹中段均实机采样并逐图审阅。细长前臂、大手套、圆鼓肩肘膝、光滑几何化枪体仍明显；静态图不证明连续换弹自然。背景疑似悬空角色需排除冻结采样影响。
- 证据索引：`artifacts/realism494-validation/stage-summary.json`；审阅：`docs/VISUAL_REVIEW_STAGE494.md`；对照 `comparison/`，人物 `sleeve-full/` 与 `weapon-contact-retry/`（均位于该 validation 目录）。
- 下一步：先对宽平路肩/场地做有明显实图效果的结构修改；随后修正整条手臂和第三人称关节比例，补三武器/第三人称连续动作与地面接触验证。山体、树冠、建筑、光照及联网仍未完成，不以截图数量或断言通过判定画质。

### Stage495：路沟剖面与路肩覆盖修复、当前实图审阅（continue）

- 收窄共享地形/碰撞的宽平沟底，使沟位、坡宽、深度沿路变化，并共用矿物路肩侵入边界。当前入口/宽幅/道路三组同机位对照已审阅，位置朝向存入 `environment/environment-camera-poses.json`；宽棕色/绿色带仍明显，视觉改善有限，不判道路要求完成。只读追查发现植被覆盖仍用旧道路距离及 colony_map，下一步需验证并统一整体边界。
- 当前包道路24条、入口32项、三武器瞄准6样本、单机烟测通过，见 `artifacts/realism495-validation/checks.json`；不代表整个地图碰撞或真实联网通过。
- 完整四姿势无单个 --pose，退出0、667.775秒，四图逐一审阅：细长前臂、大掌体与光滑枪体仍明显，ADS护木接触部分遮挡，换弹结束左手回护木。不能证明连续换弹自然。其他武器/第三人称捕获退出-15、status=interrupted、零图，原因未确定；当前证据缺失，需补跑，不沿用旧结果。
- 预览 `artifacts/realism495-preview/Linux/launch.sh`，PCK `37aa1bcff620c835d62d35972ea85885619ee1d07d7e70944138e409d60fb2e4`；审阅 `docs/VISUAL_REVIEW_STAGE495.md`；索引 `artifacts/realism495-validation/stage-summary.json`。全部修改保留，未发布。
- 下一步：统一道路/植被覆盖/前场边界并用同机位证明明显改善；补其他武器和第三人称，再结构性修改整条肩肘腕链及袖筒/掌体比例并验证连续接触。建筑、山体、树冠、光照、联网及地面接触仍未完成。

### Stage496：统一道路覆盖边界、补齐当前人物实图（continue）

- 道路恢复距离写入 colony_map G 通道，地表、覆盖与草根共用边界，移除强制绿色带。495→496 道路/入口/宽幅同机位对照全部审阅；道路绿色带减弱，但宽棕色路肩、空旷平路仍明显，不判整体完成。对照、相机位置方向和来源哈希见 `artifacts/realism496-validation/comparison/`、`environment-complete/source-manifest.json`。
- 当前包道路24条、入口32项、三武器瞄准6样本及单机烟测通过：`artifacts/realism496-validation/checks.json`。初次环境及首次道路补拍退出-15，原因未知、记录保留；第二次道路补拍退出0，不能把汇集三图算作首次进程通过。
- `artifacts/realism496-sleeves/` 无过滤完整四姿势与 `artifacts/realism496-contact/` 其他两武器/第三人称站蹲四图全部退出0并逐图审阅。多武器重复掌腕圆盘、长细前臂与袖口突变，第三人称肩肘僵硬；蹲姿远处角色悬空待正常运行追查。静态换弹采样不能证明连续动作或接触自然。
- 本地预览 `artifacts/realism496-preview/Linux/launch.sh`，PCK `23d41e7da8ccffc83a359a1a66738a2473ece5c4ae334756c68dcf8ec7586337`；详细审阅 `docs/VISUAL_REVIEW_STAGE496.md`，证据索引 `artifacts/realism496-validation/stage-summary.json`。保留未提交修改，未发布。
- 下一步先结构性修复肩肘腕链、袖筒截面/长度与掌体比例及换弹/护木目标，完整四姿势、多武器第三人称复验并补连续动作；追查角色接地。继续保留山体、重复树冠、建筑场地、光照、全地图碰撞与当前包联网目标，本轮未运行需要认证配置的联网脚本。

### Stage497：道路坡面修订与当前包完整人物审阅（continue）

- 调整入口过渡宽度、路侧沟深与外坡，渲染/碰撞共用地形；496→497入口、宽幅地形、道路三组同机位实图已审阅，相机与哈希见 `artifacts/realism497-validation/comparison/`。改善有限，宽棕色路肩与平坦场地仍明显，不算完成要求的显著环境改善。
- 当前包道路24条、入口32项、三武器瞄准6样本与单机烟测通过，见 `artifacts/realism497-validation/checks.json`。环境采集退出0。完整无过滤四姿势 `artifacts/realism497-sleeves/`、其他武器与第三人称站蹲 `artifacts/realism497-contact/` 均退出0并逐图审阅：腕部圆盘、锥形袖筒、掌体偏厚及第三人称肩肘团块仍需结构修复。静态帧不能证明连续接触自然；远处悬空角色需正常运行追查。
- 当前预览 `artifacts/realism497-preview/Linux/launch.sh`，PCK `0d8933b0bf701d3bb1805327f74953b761636c5347663977548cdb09f8c8c1b2`；详见 `docs/VISUAL_REVIEW_STAGE497.md` 与 `artifacts/realism497-validation/stage-summary.json`。联网预检本机8000的health/protocol均为HTML404，未修改服务或尝试认证，当前联网未验证。所有未提交修改保留，未发布。
- 下一阶段落实共用前臂/袖筒截面、肩肘腕链与掌体比例的结构修改，验证护木和换弹接触；重跑完整四姿势、多武器及第三人称并补动态过程。道路场地的明显改善仍欠账，建筑、山体、树冠、光照、全地图碰撞与联网目标继续保留。

### Stage499 — 道路断面试改与当前包实机复核（2026-09-20）
- 在实际使用的 `world_visuals.gd:road_cut_height` 加入排水凹槽及轮辙，共享视觉网格与碰撞高度；三机位对照显示收益有限，均宽路肩、大块平坦前场仍明显，未达到显著环境改善要求。
- 当前本地预览：`artifacts/realism499-preview/Linux/launch.sh`；PCK SHA256 `de4abd6af7f5d58b747a4f0a451a4eb1e9ebd03883a708dcdf1ccf1ff09cf632`。审阅入口 `artifacts/realism499-validation/review.html`，详细结论 `docs/VISUAL_REVIEW_STAGE499.md`。
- Forward+ 环境重采三张全部审阅，`environment-dummy/process-result.json` passed；`comparison-dummy/` 保存相同机位前后对照、入口近景和宽幅地形，相机位置/朝向三组一致。首次环境采集音频错误记录保留；工具增加 Dummy 音频驱动。
- 当前包道路24路线、入口32项、三武器瞄准6项、单机 smoke 通过，见 `realism499-validation/checks.json`。这些检查不代表全部碰撞/玩法通过。localhost:8000 的 health/protocol 均返回 HTML 404，联网未验证。
- 完整第一人称四姿势通过采集且全部审阅（`realism499-sleeves/`）；其他两武器换弹中段、第三人称站/蹲换弹四张同样完成（`realism499-contact/`）。锥形袖筒、环状腕掌、肩肘团块仍不自然；静帧不能证明换弹接触及连续动作自然。
- `realism499-motion/` 兼容渲染诊断采集被中断，仅25张部分帧，完整动态未通过。第三人称背景悬空存在采集偏差：脚本暂停全局物理只推进主角，需正常物理实机复核，不能直接认定游戏缺陷。
- 工件冲突：曾误覆盖既有498预览包及导入/导出日志，其旧截图和测试不得证明该替换包；本轮仅引用499当前包证据，详情见审阅文档。
- 下一步：结构性修改实际 `excavated_surface` 使用的道路外沿宽度、坡面及维修场地轮廓，做出宽幅实图可辨的过渡，保留入口坡道与通行；不要修改无调用的 `road_graded_shoulders`。随后重塑前臂横截面、肩肘可达性及掌体比例，补全所有武器连续动作与正常物理第三人称复核。建筑、山体植被、光照和联网目标继续保留；本轮状态 continue。

### Stage500 — 场地实体过渡与人物当前包审阅
- 场地平面改为共享地形高度网格，连接车道两侧增加不等长实体边坡及匹配碰撞；499→500 同机位道路/入口/宽幅三组实机对照已审阅，宽幅起伏改善明显，道路硬色带仍未解决。
- 当前500包道路24路线、入口32项通行碰撞、三武器6项瞄准伤害及单机冒烟通过。完整四姿势无过滤重采、SG/SR及第三人称站蹲换弹中段四图重采均退出0并审阅；首轮SIGTERM原因未知，失败证据保留。静帧不代表连续动作通过，联网仅接口预检，未验证玩法。
- 人物仍有锥形前臂、圆厚腕掌、突兀袖口、团块肩肘和装备遮挡接触。暂停全局物理的采集图出现背景角色悬空，须正常物理复核。下一轮结构性修改共用前臂/袖口/腕掌及肩肘，重生成资产后完整四姿势、多武器连续换弹和正常物理第三人称验证；继续保留道路、山体植被、建筑、光照和联网目标。
- 证据：docs/VISUAL_REVIEW_STAGE500.md；artifacts/realism500-validation/{review.html,stage-summary.json,functional-results.json,comparison/camera-comparison.json}。本地预览 artifacts/realism500-preview/Linux/launch.sh，PCK SHA256 6da7ed94a8d1b0102bb1b17401ffc22562cf73c317228ee0789ba25cc44ec00b。状态 continue；未推送或发布。

### Stage501 — 腕掌连接实验未通过视觉验收
- 重生成第一人称资产并导出501实验包；完整四姿势无过滤、SG/SR及第三人称站蹲四图均退出0，八组500→501同机位对照已审阅。腕端盖虽被埋入袖口，AR/SR换弹出现更明显环状掌体，判定视觉回退，不作为推荐版本。
- 当前501包道路24路线、入口32项、三武器6项瞄准伤害、单机冒烟均通过。动态候选因视觉回退主动终止：仅25帧（武器0为23帧、武器1为2帧），九段套件未通过；静帧及10Hz诊断均不能证明连续动作自然。联网未测，现有脚本需读取服务密钥，未执行。
- 下一步在手套合并前建立掌根语义范围和前臂过渡截面，排查整手套轴向旋转误伤折叠手指；随后重验完整四姿势、九段动作及正常物理第三人称肩肘/袖口/护木/弹匣接触。道路硬色带、山体植被、建筑、光照及联网目标仍未完成。
- 证据：docs/VISUAL_REVIEW_STAGE501.md；artifacts/realism501-validation/{comparison/review.html,comparison/pairs.json,functional-results.json,stage-summary.json}；artifacts/realism501-motion/{viewer.html,recovery-audit.json,stop-reason.json}。本地实验预览 artifacts/realism501-preview/Linux/launch.sh，PCK SHA256 2333c066545aed33c23d7e9fbe607d26e00be5ca047e0de1c54024ea74aee6c3。状态 continue，保留全部未提交修改，未推送或发布。

### Stage502 — 掌根语义范围修复与完整静态审阅
- 将掌根旋转限制在合并手指前的原始掌体环，修复501误伤弯曲指尖造成的AR/SR夸张掌体外翻；重生成并导出502实验包。前臂锥形、支撑掌环状、袖口及第三人称肩肘仍不自然，人物整体未验收。
- 当前502完整四姿势及SG/SR/第三人称站蹲四图全部采集退出0并实际审阅；八组501→502对照相机及姿势元数据一致。当前包瞄准6项、入口32项、道路24路线、单机冒烟通过。联网未测，未读取密钥。
- 九段动作套件仍在运行，有1800秒超时上限；记录时仅AR23帧、SG2帧，完整动态未通过。下一轮先核验 realism502-motion/process-result.json 与存活进程，不重复启动；结束后重建viewer及审计。兼容渲染10Hz采样不等于连续动作自然，正常物理第三人称仍需复核。
- 证据 docs/VISUAL_REVIEW_STAGE502.md；artifacts/realism502-validation/{comparison/review.html,comparison/pairs.json,functional-results.json,stage-summary.json,motion-process-checkpoint.json}。本地实验预览 artifacts/realism502-preview/Linux/launch.sh，PCK SHA256 a0eadf90d318a66900e7b405f0b6154694ee5aea60ea9f0374aa2900099dc0b8。
- 下一步接续动态审阅，再结构性重建前臂截面、袖口与掌/护木接触；道路硬色带、山体植被、建筑、光照及联网目标保留。本轮没有重新采集环境三机位，不沿用500截图作为502验收。状态continue，未推送或发布。

### Stage503：前臂整体截面与袖口连续性；当前包审阅完成，整体目标未完成

- 五截面 Hermite 前臂替换单段鼓胀，宽深独立、袖口接续导数；重生成资产和本地预览 `artifacts/realism503-preview/Linux/launch.sh`。PCK SHA256 `61f5996133cd0695e5f475266f465fd9ddf3388049e531b41884a7612b4ba19c`。
- 完整无过滤四姿势重跑成功（613.759秒）；SG/SR及第三人称站蹲成功（804.792秒）。八组同机位502/503对照已审阅：`artifacts/realism503-validation/comparison/review.html`。前臂收敛可见，但掌体长薄、环钩握持、腕部折转和第三人称肩肘块状仍未解决；静态截图不能证明连续动作自然。初次四姿势中断保留为失败。
- 当前包瞄准6项、入口32项、道路24路线及单机冒烟通过，见 `artifacts/realism503-validation/functional-results.json`。联网、当前连续动作、当前环境三机位未覆盖；构建重复/无效面和导入空纹理错误未解决。502遗留动作采集已结束并如实保留不完整失败，不计为503验证。
- 详细审阅 `docs/VISUAL_REVIEW_STAGE503.md`；汇总 `artifacts/realism503-validation/stage-summary.json`。下一步结构性修复掌体/腕部及换弹接触，补连续动作与正常物理第三人称；继续道路过渡、山体植被、建筑和光照，补当前环境对照与联网验证。状态continue，未推送或发布。

### Stage504：场地贴地网格实验；三机位对照未达到明显改善

- service_yard 平板改为顺应开挖地形的网格，非停车连接道收窄弯曲并加入车辙。503→504道路、建筑入口、宽幅地形同机位实机对照已保存并审阅，视觉差异很小；道路硬矩形问题未验收，不能计作明显画质推进。
- 当前504包瞄准6项、入口32项、道路24路线和单机冒烟通过，证据 `artifacts/realism504-validation/functions/`。人物完整四姿势两次及SG/SR/第三人称采集被SIGTERM中断且无图，失败记录保留；来源未知，结束时相关进程已不存活。不得沿用503人物通过结论，连续动作未覆盖。
- 本地实验预览 `artifacts/realism504-preview/Linux/launch.sh`，PCK SHA256 `036759c2401eeb519ee91edab8229baa2bd8dd26a4f70f2eb54bd6ef0088365a`。审阅 `docs/VISUAL_REVIEW_STAGE504.md`，证据 `artifacts/realism504-validation/{comparison/,stage-summary.json}`，相机位置与朝向已记录。
- 下一步先对道路色带做交叉道路/阴影/凹凸/覆盖层单变量定位，再修改实际来源；补当前人物全四姿势及其他武器、第三人称与连续动作。当前环境图仍有长薄前臂、不自然握持、平滑山体和重复树冠。建筑、光照及当前双客户端联网继续保留；8001端点可达不等于联网通过。状态continue，未推送或发布。

### Stage505：修正虚假道路入口；实机对照仍未达到明显改善

- 移除z26虚假跨路开挖及z49.2西侧镜像入口，展开入口外侧坡脚；通行测试纠正入口分类，未放宽阈值。当前包瞄准6项、入口32项、道路24路线、单机冒烟通过：`artifacts/realism505-validation/functions/results.json`。
- 三组同机位环境对照完成并审阅：`artifacts/realism505-validation/comparison/`，包含相机位置、朝向和图像哈希。视觉变化很小，土肩条带/边坡硬折未解决，不算道路过渡目标达成。平滑分面山体、重复树冠仍在。
- 当前505完整无过滤四姿势通过并审阅，`character-current/`；SG/SR及第三人称站姿三张留在 `contact/`，整套因SIGTERM退出-15，缺蹲姿，不计通过。长薄掌体、窄腕、环钩握持和块状肩肘仍需结构修改；连续换弹和当前联网未验证。
- 本地预览 `artifacts/realism505-preview/Linux/launch.sh`，PCK SHA256 `748a2cb439bca2007c6cbe5b86f39803067431a2d9fcea417adadcafb7954419`。详细审阅 `docs/VISUAL_REVIEW_STAGE505.md`；汇总 `artifacts/realism505-validation/stage-summary.json`。中断记录原样保留，未推送或发布。
- 下一步定位仍可见道路/场地硬边的具体网格和覆盖层并完成有明显效果的几何过渡；随后结构性修复掌体与腕部及换弹接触，补全第三人称站蹲与连续动作。继续保留建筑、地形植被、光照、全地图碰撞和联网目标。状态continue。

### Stage506 — 维修场道路过渡与当前人物完整审阅（整体未完成）
- 连接道增加共享碰撞的冠部/轮辙，混凝土向压实碎石过渡，土肩加入米级不规则边界。同机位实机宽景可见灰色平板感减轻；宽土肩、尖锥土丘、光滑山体与重复树冠仍未解决。
- 首版道路24路线中2条被路口台阶阻挡，保留失败记录；压平路口后最终包24路线、入口32项、三武器瞄准/遮挡6项及单机烟测全部通过，未放宽阈值。
- 最终包环境三机位前后对照及相机记录在 `artifacts/realism506-validation/comparison/`；完整四姿势在 `character-final/`，其他两武器与第三人称站蹲换弹中段在 `contact-final/`，均正常退出并实际审阅。细腕、钩状手、握把贴合和粗糙肩肘仍明显，采集通过不等于画质通过；连续动作与当前联网未验证。
- 预览：`artifacts/realism506-preview-final/Linux/launch.sh`；PCK SHA256 `c79fdad10c335bf733673d9d70a99127052387ca6e620266a62f75abfafdabc9`。审阅 `docs/VISUAL_REVIEW_STAGE506.md`，证据索引 `artifacts/realism506-validation/stage-summary.json`。
- 下一步：据当前实机缺陷结构性修正前臂—腕—掌比例与接触姿态，复核第三人称肩肘/持弹位置，重新完整四姿势并补连续动作证据；随后继续地形植被、建筑光照与当前联网主要功能。不再以袖口/手指微调代替整体人物改进。

### Stage507：腕掌结构试改、当前包完整姿势审阅与功能复验
- 将掌根改为Hermite中心线扫掠并扩大近端截面，重新生成Blend/GLB和本地预览 `artifacts/realism507-preview/Linux/launch.sh`；PCK `d1de4d5b86a092f367e4997d4f9ef9914428b8ea774260e897f3c421969b8ed8`。对照实机可见收益有限，不算人物整体画质完成。
- 完整四姿势重试4/4、其他两武器及第三人称站蹲4/4正式采集完成并审阅，保留首次SIGTERM失败。截图、相机和审阅见 `docs/VISUAL_REVIEW_STAGE507.md`、`artifacts/realism507-validation/stage-summary.json`。
- 当前包瞄准6/6、维修棚32/32、道路24/24、单机烟测通过；联网未验证。九组低清动作采集549.5秒无新增后主动中止，仅25帧部分证据，退出-15，未通过；终态审计和viewer已保存。
- 下一步：整体修正细长前臂、薄右掌及肩肘握持关系，补齐三武器站蹲连续换弹，检查袖口/护木/弹匣接触及背景人物疑似悬空。禁止继续仅掌根/手指微调。环境本轮未改：宽土肩、光滑山体、重复树冠、建筑/光照继续待做；修改后重拍同机位前后、入口和宽幅地形。整体目标未完成。

### Stage508：维修场连续低岸、当前包环境对照与人物完整审阅
- 将三个孤立锥状土堆替换为沿入口曲线延伸的连续低岸与浅排水趾，共享主地形高度和碰撞。三组同机位前后实机对照可见孤立尖堆消失；宽裸土、远山与重复树冠仍未解决。相机/对照见 `artifacts/realism508-validation/comparison/`。
- 当前包道路24条、入口32条、三武器瞄准遮挡6项及单机烟测通过。新增低岸横穿四条均可移动，但z=40双向最高脚底约0.70米，超过0.65米阈值，失败2/4；保留失败与碰撞诊断，疑有旧独立草岸叠加，尚未逐节点确认。
- 当前完整四姿势4/4、其他两武器与第三人称站蹲4/4采集成功并实际审阅，保留首次中止记录。细长前臂、折腕、粗糙肩肘仍明显，蹲姿手/匣/膝遮挡，背景人物疑似悬空。静态阶段不证明连续动作自然；当前联网与完整连续动作未验证。
- 本地预览 `artifacts/realism508-preview/Linux/launch.sh`；PCK `633ecdd3d6c5253ba23a0e245cc3dfbaa87a6dd7954710276ce88f3f96a7acae`。审阅 `docs/VISUAL_REVIEW_STAGE508.md`，证据索引 `artifacts/realism508-validation/stage-summary.json`。
- 下一步：先统一东侧旧草岸网格、植物高度与碰撞并命名诊断节点，修复两条失败路线；随后整体调整肩部锚点、两段手臂比例、前臂截面和腕掌连接，复拍完整姿势并补三武器站蹲连续换弹。继续建筑、地形植被、光照与联网功能，不以截图数量或局部改善判定整体完成。

### Stage509：维修场地叠加草岸修复与当前人物审阅
- 删除三块旧草岸网格和碰撞，植物随整平地表落地；z40横穿峰值由约0.70米降到0.30米，未放宽阈值。当前包场地4路线、道路24路线、入口32路线、三武器瞄准/遮挡6项及单机冒烟全部通过，见 `artifacts/realism509-validation/checks.json`。
- 三机位当前环境截图与508基线相机一致，已审阅入口近景、宽幅和道路对照；场地隆起降低，但宽幅改善有限，山体光滑、树冠重复和空旷仍未解决。基线重拍中断记录保留。
- 当前包完整四姿势采集通过且逐图审阅；SG8/SR-5中段两图已审阅，但整组采集SIGTERM中断，不能算通过。第三人称站立/蹲姿补拍退出0且逐图审阅。前臂细长、腕掌骤窄、肩肘简化和蹲姿接触遮挡仍明显；背景人物疑似离地待查。静态截图不证明连续动作自然，当前联网未复测。
- 可运行预览 `artifacts/realism509-preview/Linux/launch.sh`；审阅 `docs/VISUAL_REVIEW_STAGE509.md`；汇总 `artifacts/realism509-validation/stage-summary.json`。
- 下一步：整体修改肩部锚点、上下臂比例与腕掌过渡，重跑完整四姿势并补三武器连续换弹、第三人称蹲起接触和人物落地核查；继续地形植被、建筑、光照及联网验证。状态 continue，整体目标未完成。

### Stage510 — 手臂整体比例修正与当前包人物复验（continue）
- 调整第一人称肩锚点、上臂/前臂长度为0.33/0.26米、前臂截面和袖口过渡，重建Blend/GLB及本地预览 `artifacts/realism510-preview/Linux/launch.sh`；保留既有未提交修改。
- 完整四姿势无过滤采集通过，逐图审阅并保存509/510四组对照；腕部骤缩减轻，但袖管锥形和硬折角、武器大平面仍明显。其他武器与第三人称四张关键帧全部出图并审阅（SG/SR换弹中段、武器0站/蹲换弹中段），不能代表连续动作通过；蹲姿手膝接触遮挡，背景角色悬空待查。
- 当前510包道路、场地边坡、入口碰撞/通行、瞄准伤害和单机冒烟通过：`artifacts/realism510-validation/checks.json`。联网实际尝试在本地/auth/login返回404，未通过，不改后台/认证。
- 九组连续动作三次尝试主动中断，保留partial与退出-15记录，未完成任何整组。606个离散样本只作诊断：相机坐标肩锚点左侧基本稳定、右侧最大约2.27厘米修正，不将移动骨架坐标差值当作身体肩部滑动。构建退出0但保留网格修复及导入空纹理诊断。
- 证据：`docs/VISUAL_REVIEW_STAGE510.md`、`artifacts/realism510-validation/stage-summary.json`、character/、comparison/、contacts/、reach/、motion*/、online-run.log；预览来源及哈希见 `artifacts/realism510-preview/build-provenance.json`。
- 下一步：降低动作采集开销并补齐三武器第一/第三人称连续过程，追查背景角色落地、肩肘袖管与蹲姿手膝接触后作结构修改；继续山体、树冠重复、建筑群与光照目标，环境改动必须同机位前后/入口/宽幅截图及碰撞复验。整体目标未完成。

### Stage511 — 九组动作诊断采集及实际审阅（continue）
- 采集器新增分项耗时、显式简化背景开关及来源记录，本地播放器显示诊断限制；游戏模型、场景和510预览未修改，不算画质改善。
- 三武器第一人称、第三人称站/蹲九组261帧全部采齐并逐组审阅，正常退出0；两次均有188条材质空引用ERROR，延迟清理未修复，严格审计仍失败。最后一次214.236秒，261张图与已审阅试跑逐一SHA相同，未屏蔽错误或将采齐写成通过。
- 明显缺陷：第一人称枪托大平面及膨大轮廓、锥管袖形和袖口断层；第三人称动作机械，蹲姿手/膝/弹匣接触被遮挡。640×400、简化背景及10Hz固定模拟采样不能证明正常画质、实时移动、蹲起或连续接触自然。本轮未重跑完整四姿势、环境碰撞、单机或联网；先前登录404仍待解决。
- 证据：`docs/VISUAL_REVIEW_STAGE511.md`、`artifacts/realism511-validation/stage-summary.json`、`motion-sheets/`、`motion-cleanup/viewer.html`、`motion-cleanup/recovery-audit.json`、`motion-cleanup/capture.log`及`runtime-comparison.json`。本地预览仍为`artifacts/realism510-preview/Linux/launch.sh`。
- 下一步：正常画质蹲姿侧面近景确认遮挡，实施枪托/袖管或蹲姿空间关系的结构修改，重跑完整四姿势并复核九组动作；追查诊断退出材质错误。宽裸道路、山体、重复树冠、建筑和光照目标保留，环境修改仍须同机位前后/入口/宽幅截图和通行碰撞复验。

### Stage512 — 场地实体轮辙与当前预览复验
- 沿维修入口车辆曲线加入双轮辙和低辙边，局部0.25米地形采样与碰撞同步；环境/四姿势采集统一先推进全部人物落地。保留所有原有修改，未推送或发布。
- 新预览：`artifacts/realism512-preview/Linux/launch.sh`，哈希见同级上层 `build-provenance.json`。三个固定机位前后图、入口近景与宽幅地形全部采集并审阅，相机一致；`artifacts/realism512-validation/comparison/`。宽幅轮辙效果仍偏弱，未达到明显改善目标。
- 当前512包边坡4、轮辙4、入口32、场地4、瞄准伤害6项通过；道路首次240秒超时，独立复测24项通过。单机烟雾退出0，16人物及换弹/治疗/伤害/胜利/射线/掩体等通过。保留全部日志。
- 完整四姿势无过滤执行，1084.483秒退出0，四图均审阅；长锥形袖管、厚重枪托和大平面仍明显。换弹结束左手回护木附近，但未证明连续肩肘/袖口/换弹接触自然。
- 其他武器与第三人称侧面连续采集因并发软件渲染负载主动终止，退出-15、0样本，未通过。联网在本地 `/auth/login` HTTP404阻塞，未启动双客户端，不改认证/后台。
- 审阅：`docs/VISUAL_REVIEW_STAGE512.md`；汇总：`artifacts/realism512-validation/stage-summary.json`。状态continue。
- 下一步：结构性调整场地横断面与压实区，串行采集同机位确认明显效果；随后改枪托与肩肘袖管体积，保留完整四姿势并补三武器第一/第三人称连续动作。继续山体、树冠、建筑、光照及联网功能验证，不以采集通过或截图数量判断画质完成。

### stage513：道路接入面跟随车辙，当前包人物全姿势与动作诊断
- 维修场地覆盖网格横向细分16→48，接入段跟随实际道路挖槽高度，消除覆盖面抹平轮辙的问题；宽幅同机位对照可见车辙连续进入场地。入口保持通畅，但主路横向色带、规律边坡、光滑山体和重复树冠仍待修复。
- 当前可运行预览：`artifacts/realism513-preview/Linux/launch.sh`；新PCK及源码/采集脚本核对见 `build-provenance.json` 和 `artifacts/realism513-validation/final-provenance-check.json`，六项匹配。三机位正常画质前后对照、入口近景及宽幅图均保存，相机一致；详见 `docs/VISUAL_REVIEW_STAGE513.md`。
- 当前513包七项功能套件通过：轮辙、边坡、维修入口32路线、场地墙/屋顶碰撞、道路24路线、三武器瞄准伤害6例、单机综合冒烟。完整四姿势无过滤通过且逐张审阅；长锥形袖管、肘部形体不清及枪托大平面仍明显。
- 三武器第一人称及第三人称站/蹲九段在简化背景诊断中采齐261样本，已看九组接触表及第三人称局部原图；但188条材质空引用错误，动作验证失败。首次中断的7样本也保留为失败。诊断不证明正常画质、实时动作自然或遮挡处接触正确；未覆盖行走叠加、输入ADS转换和联网同步。
- 本地登录 `/auth/login` HTTP404，双客户端未验证；未改后台或认证。汇总 `artifacts/realism513-validation/stage-summary.json`；状态continue。
- 下一步：结构性调整肩肘/袖管/袖口连接与枪托比例，先核实真实网格握持变形，避免把解析中心线位移当作表面裂缝；修复动作采集材质错误并补对侧手部接触视角。重新导出后完整四姿势及三武器第一/第三人称动作复验，继续建筑、地形植被、光照及联网剩余目标。

### Stage514（2026-09-20）：卡宾枪枪托结构与当前包人物复核
- 延续513道路/场地阶段，扩大卡宾枪贯通开孔、减薄框架及后肩垫、降低贴腮鼓包，重建 GLB/Blender 与本地预览 `artifacts/realism514-preview/Linux/launch.sh`。保留全部已有未提交修改；未推送、发布或修改后台服务。
- 当前514包完整四姿势采集通过并逐张审阅，`artifacts/realism514-validation/compare-*.png` 保存513/514同机位对照，`comparison.json` 确认相机/动作状态一致。枪托重量感减轻，但腕部骤缩和长管状袖子仍明显，不能视为整体画质完成。
- 其他两种武器、第三人称站/蹲换弹中段四图已全部查看，采集退出0且PASS：`contacts/process-result.json`、`contacts/contact-review.json`（均位于514验证目录）。其他武器厚重大块枪托、肩肘形体和遮挡接触仍待修复；静态中段不证明连续动作自然。背景角色在该脚本中冻结，不将远景悬空直接归因于游戏物理。
- 当前包七项单机、瞄准伤害、道路/车辙/场地/入口碰撞通行检查通过：`artifacts/realism514-validation/tests/process-results.json`。实际双客户端联网失败：包内容版本 ash-valley-19，8002 API 为 ash-valley-18，登录前不兼容退出；`online-diagnosis.json` 有证据。8002空登录422仅证明路由存在，历史8000的404不代表认证故障。
- 完整审阅 `docs/VISUAL_REVIEW_STAGE514.md`；构建对应关系和汇总见514验证目录 `final-provenance-check.json`、`stage-summary.json`。本轮未新增环境前后图，建筑、山体、重复树冠、光照与连续动作目标继续保留。
- 下一步：优先修正右腕握把映射对近端连接的影响，检查最终网格，重跑完整四姿势并补三武器/第三人称连续换弹，核对肩肘、袖口、护木、弹匣接触。先短流程定位513采集结束后的材质错误，避免盲目重复全部长录像；联网需服务版本对齐后重新实测，遵守不改后台服务约束。状态 continue。

### Stage515（2026-09-20）：右腕变形顺序与当前人物/功能证据
- 右手握把映射提前到手掌/附件阶段，再生成腕部连接，避免合并后再次压缩近端；重建 Blender/GLB。当前预览 `artifacts/realism515-preview/Linux/launch.sh`（缺release模板，export-pack成功配合已有执行文件）。16项哈希一致，保留全部既有修改。
- 当前包完整四姿势和其他两武器、第三人称站/蹲中段采集均退出0且通过，八图逐张审阅；同机位前后见515验证目录 compare-*.png。本轮视觉收益有限，长锥袖、腕口骤缩、肩肘僵硬及其他武器大块枪托仍明显，不能代表人物画质完成。详细机位、遮挡和局限见 `docs/VISUAL_REVIEW_STAGE515.md`。
- 当前包七项单机、瞄准、道路/车辙/边坡/场地/维修入口通行碰撞通过：`artifacts/realism515-validation/tests/process-results.json`。烟测首次运行器退出143，保留中断记录后单独重跑成功；不计中断尝试为通过。
- 两帧短诊断定位到简化背景材质释放路径：简化有188条错误，原始材质无错误，均退出0；`cleanup-results.json` 不证明完整动作。连续换弹、行走叠加、ADS转换及遮挡接触仍未验证。当前只读协议检查客户端 ash-valley-19 / 服务 ash-valley-18，不兼容，联网未通过；未改后台或认证。
- 本轮无新增环境前后图，513只能作历史证据。汇总 `artifacts/realism515-validation/stage-summary.json`；状态 continue。下一步整体调整肩肘/前臂长度与袖管到袖口关系，避免继续腕部小改；采用原始材质或修复释放路径后补完整三武器第一/第三人称动作。保留道路硬色带、建筑入口/宽幅地形、山体树冠与光照目标及当前版本功能复验。

### Stage516（2026-09-20）：道路边坡结构调整与当前环境/人物复验
- 修改 `world_visuals.gd` 道路边坡宽深、错位不等宽汇水沟及场地附近共享碰撞/渲染采样范围；当前包 `artifacts/realism516-preview/Linux/launch.sh`，export-pack退出0并配合既有执行文件。未推送、发布或修改服务，保留全部未提交修改。
- 本轮重新运行515前图及516后图，同机位道路、维修入口近景、宽幅地形对照见 `artifacts/realism516-validation/comparison/`，机位与朝向已记录。逐图审阅发现改善有限，场地连续双土脊仍明显，不能算环境画质验收。定位到独立 `service_yard_relief()` 连续rut/lip几何，下一步应结构性打断/重塑沉积边缘，不能继续色值/草簇小改。
- 当前包完整四姿势（未使用单个pose）及其他两武器、第三人称站/蹲中点采集均退出0，八图逐张审阅；长锥前臂、袖口骤缩、厚重枪托、肩肘与蹲姿手枪膝空间关系仍待改。第三人称蹲图远处悬空人物需追踪实体。静帧不证明连续换弹、肩肘插值或护木重新接触自然。
- 七项功能检查六过一失败：维修入口/场地/车辙/边坡/瞄准伤害/单机烟测通过；道路西侧z26横穿5.313m后受阻，低于6.4m要求，不放宽断言。烟测首次中断143记录保留，单独重跑退出0通过。未在本轮重跑515碰撞，不能断言回归来源。客户端ash-valley-19与本机服务ash-valley-18不兼容，联网未通过。
- 审阅 `docs/VISUAL_REVIEW_STAGE516.md`；汇总 `artifacts/realism516-validation/stage-summary.json`。状态continue；下一阶段先定位道路阻挡并重塑场地土脊，以相同机位复验，再整体修改人物肩肘/袖管/握持并补连续动作证据。建筑、地形植被、光照和当前版本联网目标均保留。

### stage517 — 道路/场地几何过渡及当前人物审阅（2026-09-20）
- 去掉场地连续双凸脊，改为随弯道变化的断续浅车辙；路肩网格与碰撞跟随挖低路面，修复 z26 西向横穿被垂直坡边挡住的问题，未放宽测试断言。
- 当前包七项功能测试全部通过（含入口/场地/道路通行、瞄准伤害、单机 smoke）。环境三机位与 stage516 相同，前后对照实际审阅确认凸脊改善；入口近景和宽幅地形及相机记录见 artifacts/realism517-validation/final-environment/、comparison/。中间 after/ 不作最终证据。
- 完整四姿势及其他两武器、第三人称站/蹲四张均采集成功并逐张审阅；确认锥形前臂、腕袖收窄、长颈僵肩、换弹枪托过大、蹲姿手臂弹匣挤膝，背景悬空角色待查。九段261帧动作诊断日志有188条材质空引用错误，不能记通过；正常画质连续接触尚未验收。
- 联网仍有服务 ash-valley-18 / 客户端 ash-valley-19 内容版本不匹配，未修改后台。预览 artifacts/realism517-preview/Linux/launch.sh；PCK SHA256 5ca7f4dd7ea2f138135d05e8f4ea6615fd9a6933537ab67543e92c4159b88a45。审阅 docs/VISUAL_REVIEW_STAGE517.md；汇总 artifacts/realism517-validation/stage-summary.json。
- 下一步：结构性调整颈肩比例、前臂截面与袖口、分武器换弹目标及肩肘补偿，定位材质错误和悬空角色，复验完整四姿势与正常画质连续动作。保留山体、树冠、建筑内部、光照及联网功能完整目标；整体继续，未发布、未推送。

### stage518 — 四姿态串行复验，躯干瞄准验证进行中（2026-09-20）
- 当前预览完整四姿态采集退出0、600.04秒，process-result passed=true；证据 artifacts/realism518-validation/arms-serial-recheck/，逐图审阅详见 docs/VISUAL_REVIEW_STAGE518.md。
- 补弹和静态准星可见性通过；锥形袖管、腕部骤缩、环状拇指、换弹枪托厚重及机匣强反光仍明显，不能记整体画质达标或连续动作通过。
- 已启动518躯干站/蹲六瞄准姿势串行采集 chest-after-serial，尚待最终结果与517同机位对照。旧并行超时/中断不作通过证据。当前包其他武器、连续动作和功能复验仍待完成，保留全部环境目标。
- 实测 fpsgame-goal.service inactive/dead、MainPID=0；当前采集进程不能证明持续开发服务已恢复。未改服务、发布或推送。

### Android 0.52.4 发布（2026-09-25）
- 已发布包含当前工作区最新建筑、植被、武器及移动端优化的 Android 包，进一步改善草地、路肩和场地阴影材质。版本名 `0.52.4-android.20260925`，versionCode `20260926`；构建和证据目录 `artifacts/android-latest-20260925-r6/`。
- 下载：`https://d3j1sc8stx5n1c.cloudfront.net/downloads/IronMeridian-Android-0.52.4-20260925.apk`。下载页和二维码已同步，公网完整下载 SHA256 与测试包一致：`cf9f0f6b912e27a585230570e92019da490628e263c473c76bd7dd9b3e09698a`；`publication.json` 状态 passed，无公网登录表单。
- Pixel 10 Device Farm 随机操作与原生操作测试均 PASSED；已审阅单机、射击和转视角截图：弹药30→24，镜头方向改变，计时和伤害反馈正常。证据 `native-walkthrough-reviewed.json`。
- 触屏、瞄准、陀螺仪逻辑、记住登录及登录恢复测试通过；打包源码在 Linux 对 AWS 的 solo/duo 联网测试通过。未验证 Android 原生联网、实体陀螺仪手感或实际帧率，不将源码联网测试当作 Android 联网实测。
- 联网测试等待开局权威快照稳定后执行原有暂停菜单断言；未放宽断言，也未修复服务器开局初始化延迟。整体写实画质目标继续，未推送 GitHub；本次发布不代表后台持续开发服务恢复。

### Android 0.52.6 最新优化发布（2026-09-25）
- 包含最新工作区场景、建筑、武器、移动输入和加载优化，以及 stage526 草丛实例颜色调整；570 项源码清单在发布前核对一致。版本 `0.52.6-android.20260925`，versionCode `20260928`，证据 `artifacts/android-latest-20260925-r8/`。
- 已发布：`https://d3j1sc8stx5n1c.cloudfront.net/downloads/IronMeridian-Android-0.52.6-20260925.apk`。下载页及二维码同步；公网完整 APK SHA256 `6ad45ae28d1c6fe8df1f69abfe576b185ff6ce02a1d8e6762682ce24a7204523` 与测试包一致，`publication.json` passed，网站无登录表单。
- Pixel 10 原生随机操作及脚本操作测试均 PASSED；人工审阅单机、射击、转视角截图，弹药30→24、镜头转动及计时正常。触屏、准星、陀螺仪逻辑和登录记忆测试通过。打包源码的 Linux 客户端完成 AWS solo/duo 联网及登录恢复检查。
- 原生 Android 联网、物理陀螺仪手感和帧率未实测；Android 路边草丛仍偏黑，不能以桌面草色修复宣称手机画面达标。详见 `docs/VISUAL_REVIEW_STAGE526.md`。
- 未推送 GitHub，未使用 CloudFormation，未更改 ECS 网络；本次发布不代表后台持续开发服务恢复，整体写实目标继续。


## 2026-09-25 Android 0.52.7 发布完成

用户要求 Android 包含最新优化。已通过现有私有 S3 + CloudFront OAC 发布 `IronMeridian-Android-0.52.7-20260925.apk`，同步下载页和二维码，未推送 GitHub。源码快照 573 个文件与工作区一致；APK 约 320 MiB，version code 20260929，继续使用既有签名。

修复 Android 地表缓存导出时 MultiMesh 实例和颜色数据丢失：使用 Xvfb/OpenGL 烘焙并读回验证，保存 253886 个草丛实例、1081 个批次。包含当前场景、武器、移动加载、触屏和陀螺仪源码优化。

证据目录：`artifacts/android-latest-20260925-r10`。Device Farm 原生随机事件和游戏操作测试均 PASSED；截图确认单机场景、开火弹药 30/120→25/120、视角转动。对应源码的 AWS 单人/双人联网、登录记忆和触屏/瞄准/陀螺仪回归通过。原生 Android 联网、实体陀螺仪手感及 FPS 尚未实测；部分路边草丛仍偏暗，整体写实画面目标未完成。

`publication.json` 确认公网 APK SHA-256 为 `43177a0314e1d93974ec064801f4329c642f0e2797ac4a7db3af72e82bf5a39c`，与测试包一致；下载页无登录表单，公网登录页面及 API docs 检查通过。未修改 ECS 网络。
