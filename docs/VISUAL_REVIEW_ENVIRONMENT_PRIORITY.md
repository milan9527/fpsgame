## Stage515 首两帧独立复核：右腕修复仍待换弹证据

证据：`artifacts/realism515-validation/independent-partial-visual-review.json`。实际查看 default-spawn 与 ADS 原图；默认姿势右腕大部分被枪遮挡，不能据此确认右腕修复。左袖仍呈长锥形，拇指仍有环状轮廓；ADS 红点可见，仅说明这一静帧无遮挡。当前源脚本已把右手握持映射移到腕根弯曲之前，515 manifest 的手臂 GLB 哈希与独立权重审计一致。继续审阅换弹和连续接触，不重复以权重正确代替几何验收。宽直道路、远山折线及简单建筑体块仍明显，人物阶段完成后需实质推进环境结构，不把持枪微调当作整体达标。

## 当前导出手臂：腕部权重实测一致，继续检查几何连接

2026-09-20 09:48 UTC 独立读取当前源GLB，证据及可重跑脚本：`artifacts/realism514-validation/independent-wrist-audit/result.json`、同目录 `audit.py`。被测GLB SHA256为 `f31aec5ece1b5481ef2da621a98caa4a54eecd647c89e5324e4ab72f58e64784`，不是514预览包的证明。左右腕过渡带内袖管、腕带、手套与皮革垫的实际顶点骨骼权重均符合相同smoothstep曲线，最大绝对残差小于0.0001。此证据不支持将当前问题直接归因于这些材质之间存储权重不一致；优先检查几何腕根、握持映射和变形后的表面连接。权重一致不证明无缝、握持正确或连续动作通过，仍需实图和运动验证。

## Stage514 枪托实图对照：有改善，但下一步应修人物结构

补充完整静态姿势复核：`artifacts/realism514-validation/independent-full-pose-review.json`。默认与换弹完成的枪臂区域像素平均通道差为0.036/255，只支持这两个采样帧外观接近，不证明中间动作或接触正确。机匣在默认/完成姿势呈灰色，而换弹上表面近白；下一轮材质调整先检查表面法线、粗糙度和姿势下光照响应，避免仅全局压暗基色。ADS静态准星可见，手腕骤缩、环状拇指与长锥形袖管仍需优先结构修复。

独立对照513/514原始1280×800换弹中段，出生相机记录一致，证据：`artifacts/realism514-validation/independent-stock-comparison.json`。514尾垫轮廓缩小、镂空扩大、下框变细，属于可见改善；上框仍呈大平楔形，机匣上面近白，不能宣称整体写实达标。袖管长锥形、袖腕骤变与左拇指环状轮廓未改善。下一阶段优先联合修肩肘/袖管/腕掌结构，检查真实变形网格，再做完整四姿势及三武器连续动作；不要再以多轮枪托细调替代人物结构。四姿势采集已退出0，但本条只直接审阅换弹中段对照，不代表连续动作或联网验收。

## 登录检查纠正：8000 属于其他项目

2026-09-20 09:19 UTC 独立检查记录：`artifacts/realism513-validation/independent-api-port-diagnosis.json`。本机8000由 `/home/ec2-user/bedrock/OptimizePrompt/server.py` 占用；此前该端口的404不能作为游戏登录路由损坏的证据。主游戏API实际映射127.0.0.1:8002，双人开发API为127.0.0.1:8001。两者 `/health` 返回200，空请求POST `/auth/login` 返回预期422字段校验，说明路由存在。后续使用正确端口，不要为此前404修改认证逻辑；真实账号登录、远程链路与双客户端对战仍待验证，此记录不代表联网验收通过。

## 右腕根后续变形定位：握持映射再次移动已对齐的掌根

独立数值证据：`artifacts/realism513-validation/independent-wrist-transform-diagnosis.json`。按当前 solve_elbow 和 Hermite 中心线计算，右掌最靠袖口的中心线点在最终握持映射中仍获得约0.80权重、移动约35.8毫米；袖口不参与这一映射。代码注释声称保留袖口过渡，但 world-Z 遮罩在掌根弯曲后不能保持该中心线。
这是解析中心线探针，不是最终重网格顶点或实测可见缝隙，不能直接把35.8毫米写成画面断层。后台唯一源码任务应在结构修正时检查真实近端网格的前后位移，以作者纵向权重固定腕根或调整变形顺序，同时保留枪柄/指尖接触；结合完整四姿势和三武器连续动作验证。前台未修改游戏源码或新增构建。

## Stage512 枪托结构定位：完成当前环境采集后优先落实

独立实图证据：`artifacts/realism512-validation/independent-stock-structure-review.json`，包含原图、采集结果及建模脚本哈希。
实际查看1280×800换弹中段：枪托虽有贯穿开口，外围三角框和尾垫仍厚重，大平面明显；机匣上表面近白，需检查粗糙度与光照响应，不能只继续压暗基色。
定位 `tools/build_assets.py` 的 `Butt stock` / `Stock opening cutter` / cheek saddle / comb（审阅时503–551行）。下一结构修改应调整框架截面、尾垫比例与承托面层次，并保留合并枪托节点的换弹/遮挡变换契约。
完成正在运行的环境验证后优先执行此结构修改及袖管腕掌过渡，使用新包完整四姿势同机位复拍。中段弹匣离开弹仓是正常动作，静帧不能证明连续接触失败或通过。本审阅没有新增构建或功能通过结论。

## Stage513 宽幅地形实图复核

独立对比512/513原始1280×800 `terrain-wide`，相机记录一致；证据：`artifacts/realism513-validation/independent-terrain-visual-review.json`。
513入口前景已经出现可见车辙凹槽与凸起土肩，不应再说完全没有形体变化；但部分横断面像宽土堤，边缘仍偏折面，不能据此宣称整体画质达标。
人物袖管、腕掌过渡和大平面枪身仍占据显著画面面积。完成当前环境采集/验证后落实上方枪托和袖腕结构优先级，不继续以单独地形轮次替代。此对比不代表功能验证通过。

## Stage512 正常画质宽幅对照：尚未证明结构改善

独立证据：`artifacts/realism512-validation/independent-environment-comparison.json`。
实际查看 terrain-wide 前后原图，两边相机记录一致；建筑轮廓、布局和持枪手臂比例仍基本相同。
宽幅平均通道差仅0.803/255，入口0.0405/255；图片并非逐像素相同，但像素变化不能证明写实度提高。
长窄袖管和腕部骤变、宽平机匣/枪托、远山折面、近似树冠仍可见。继续优先落实人物及武器轮廓和变形的结构改动，
以正常持枪、ADS和换弹同机位复拍证明效果，不再把此组环境图计为明显画质提升。
此独立审阅不代表整组采集退出成功，也不证明单机、碰撞或联网通过。

## Stage511 材质错误：独立日志定位

Stage513 复核：`artifacts/realism513-validation/independent-material-error-localization.json`。261帧最后保存于日志第266行，PASS第267行，首条材质错误第268行，共188条；PASS之前没有ERROR。错误仍位于采集完成后的窗口，尚未证明游戏运行期间受影响。请沿用下述短采样释放标记诊断，不为同一错误再次完整采九段。



证据：`artifacts/realism511-validation/independent-material-error-localization.json`。
两次完整采样均先保存261帧、输出PASS，再出现188条材质错误；四种函数各47条，延迟释放未改变此序列。
PASS位于`game.queue_free()`之前，不能代替进程及日志验收。下一次请用隔离短采样、释放前后标记和背景材质覆盖开关定位，避免为同一退出错误重复九段全采样。日志顺序尚不能证明根因或受影响资源数量。继续优先正常画质枪托/袖管及蹲姿结构修改，不把诊断完成当作画质提升。

## Stage510 背景人物悬空：已完成隔离验证

独立运行510打包预览，进程退出0，证据：
`artifacts/realism510-validation/independent-grounding-runtime/result.json`、
`artifacts/realism510-validation/independent-grounding-runtime/independent-review.json`。
只推进本地人物120个物理帧时，15个机器人均未接地，距地面约0.80–1.82米；
再推进全部16个人物180个物理帧后，16个均报告接地，最大地面射线间隙约0.0304米。
这支持截图脚本暂停游戏物理后只推进本地人物导致背景角色停在出生高度。
下一轮修正截图流程，让所有角色在捕获前完成物理落地，再审阅实际脚底画面；
不要仅凭此前截图修改游戏重力或碰撞。此隔离测试不能代替正常对战验证、
蒙皮脚底接触检查或第三人称蹲姿手膝穿插检查。整体画质目标仍未完成。

## Stage500 独立手部与环境实图复核

补充普通持枪与 ADS 对照：`artifacts/realism500-validation/independent-spawn-ads-review.json`。普通持枪已出现暴露的圆形腕掌端面、袖腕骤变与环形拇指，因此缺陷并非换弹专属；ADS 武器遮挡大部分掌腕，只能确认该静帧视窗未被遮住，不能据此验收人物比例或弹道。结构修复后必须同时复拍普通持枪、ADS、换弹。

证据：`artifacts/realism500-validation/independent-hand-environment-review.json`（两张原图与采集记录 SHA256）。已直接查看 SG 换弹中段与场地宽幅：SG 左手确实持有弹匣，问题是圆盘状腕掌端面、环状拇指轮廓和袖管骤缩；右手也有圆块突出。下一结构改动应优先联合修复掌体、腕部、袖管与肩肘腕比例，再以相同姿态复拍；不要用道路微调替代。静帧不能证明三武器完整换弹和第三人称正常物理接地通过。

环境可见新增土坡，建筑梁柱、板材、管道和箱体细节已存在；右前坡脊仍生硬，绿灰地表斑块过渡、大片光滑入口、相近树冠及折面远山仍需改进。人物 contact 采集记录为 interrupted/-15，partial complete=false，不能将已有一张 SG 截图视为整组成功。整体写实目标仍未达到。

## Stage499 独立当前画面复核

当前已查看 reload-middle 与 terrain-wide 两张实图，哈希及证据边界见 `artifacts/realism499-validation/independent-current-priority-review.json`。整体写实目标仍未达到。

当前源码补核（哈希见 `artifacts/realism499-validation/independent-rig-source-audit.json`）：袖管已有 UpperArm/Forearm 混合权重，补强布片使用对应的前臂轴向距离权重，不能沿用“整个袖管只绑一根骨骼”的历史诊断。上臂沿贝塞尔曲线生成，但权重距离采用直线长度乘参数，并非曲线弧长；这只是待验证近似，不能直接认定为变形根因。IK 仅在可达距离被钳制时修正肩点。下一轮应记录三武器整段换弹的肩点修正峰值、肘部连续性与变形后轮廓，再联合调整前臂和掌体比例；当前源码哈希尚未与499构建输入绑定。

下一轮优先落实人物结构修改：联合调整前臂截面/长度、掌体比例和肩肘腕目标，验证全武器可达性及连续换弹接触。换弹中段确有弹匣，问题是长锥形袖筒、骤缩手腕、圆环状掌指，不应误判为缺少弹匣移除动作。不要再以道路微细节替代人物结构修复。

环境已有建筑梁柱与板材细节；仍需处理大片平坦前场、均宽棕色路肩、重复树冠和折面山体。两张静态图不证明连续动作或其他武器/第三人称通过，也未证明联网或 Android 修复。保留并补齐九片段采集的中断证据，不将主后台进程运行等同于子任务全部通过。

# 当前实机审阅与下一阶段优先级

更新时间：2026-09-20。整体写实目标尚未达到。此文件保存当前可执行重点，历史记录仅按需查询：
`docs/archive/VISUAL_REVIEW_ENVIRONMENT_PRIORITY-through-stage256.md`。
不要把历史阶段的优先级或测试结果直接套到当前源码。

## 当前优先级：stage497 独立实机复核（2026-09-20）

独立查看第一人称换弹中段及第三人称站姿换弹中段两张实机截图；路径、SHA256、结论和限制见
`artifacts/realism497-validation/independent-current-priority-review.json`。
第一人称掌/拇指仍呈分离圆块、手指钩状，前臂细长渐尖，袖口到腕部连接突兀；
第三人称肩肘圆块感和简化手腕仍明显。优先修改共同的前臂/袖管截面、掌部比例和
肩—肘—腕连续结构，再核对武器接触。不要继续以路面或单根手指微调代替结构改进。
验证必须覆盖AR四种姿态、其他武器、第三人称及连续动作；本次两张静帧不证明全姿态或动态无穿插。
宽阔稀疏路肩、重复树形、简化远山仍需改善，保留同机位环境对比和通行/瞄准/单机回归。
整体目标尚未完成；当前在线功能也未验证通过，最近记录的本地API预检返回404。
此结论仅针对stage497截图，不代表后续未完成源码的运行状态。

补充实看 `environment/terrain-wide.png` 与 `environment/road-horizon.png`：入口已有可读建筑构架、
散石和植被，不能描述成完全没有细节；主要问题是大块光滑入口场地、连续宽棕路肩、
同类树冠轮廓和棱角蓝色远山。后续环境修改应在场地尺度形成高差与不规则植被/冲蚀分区，
保留入口可通行宽度和射击视线；树形与分组、远山地貌尺度也需改变。
验收同机位整幅构图与中远景层次，单独改变沟深数值不能证明明显改善。补充图片哈希见同一审阅JSON。

测试覆盖补充：stage497 的24项道路检查是固定通行路线，入口32项是7条移动路线与射线/树木包围盒等混合断言；它们尚未证明全地图脚底支撑和稳定落地。6项瞄准检查仅证明静态本地开火/遮挡结果，不能证明桌面、触摸、陀螺仪或联网移动目标命中正常。补正常物理下的地形相对脚底支撑和真实输入验证；世界坐标Y为负本身不是跌落证据。证据及当前脚本哈希见 `artifacts/realism497-validation/independent-test-coverage-review.json`，历史运行未记录脚本哈希，勿声称完全绑定。

## 最新补充：stage452 SG/SR 换弹时间序列

独立查看SG与SR各九张动作抽样帧，证据及哈希：
`artifacts/realism452-validation/independent-sg-sr-motion-review.json`。
两者均可见武器抬起、左手携脱离弹匣降低再返回，随后回到初始方向；
SG与SR的72/96/120帧可辨认各自的脱离弹匣，不能称拔出动作缺失。
旧弹匣处理、新弹匣身份与准确接触关系仍未验证。
两种武器的中段动作都明显暴露钩状手指、圆形掌/拇指凸起，以及简化的右腕握持。
应将掌指腕结构修复覆盖三把武器，并按武器核对弹匣接触与最终护木重新握持；
大面积光滑枪托和管状前臂仍需改善。此审查是640×400兼容渲染诊断，
主体每0.4秒抽样，不证明帧间无穿插、最终材质光照合格或真实对战通过。

## 最新补充：stage452 AR 弹匣接触近景

已进一步检查0.4–1.8秒每0.1秒一张的15帧局部放大图，证据：
`artifacts/realism452-validation/independent-ar-contact-detail-review.json`。
0.4–0.7秒可见弹匣离开机匣并随左手下移，1.6–1.8秒可见返回及表观插入；
因此不能再把拔出动作描述为缺失。0.8–1.5秒弹匣持续在左手旁可见，
尚不能确认旧弹匣处理与新弹匣获取，也不能由距离接近证明实际接触关系。
优先改善脱离机匣时特别明显的钩状手指、圆形掌/拇指凸起，以及右手腕到握把的连贯结构；
结合动作节点核对弹匣归属、插入和最终恢复护木握持。此次裁剪不覆盖最后重新握持阶段。
放大图来自低分辨率兼容渲染诊断，10Hz抽样不能证明帧间无穿插或最终画质合格。

## stage452 AR 换弹时间序列

独立检查 0–2.2 秒的九个抽样帧，拼图与原图哈希记录于
`artifacts/realism452-validation/independent-ar-motion-review.json`。
武器抬起、左手降低再返回，2.1 秒弹药由29变30，证明时间序列推进；
不证明动作自然或帧间无穿插。0.6–1.5秒左手仍呈分离钩状手指与圆形掌部，
右前臂长管状，腕部与握把关系简化。抽样图不能清楚辨认完整拔出、换入弹匣过程，
下一步利用已有中间帧核对弹匣与手的接触，并改善连续掌指腕结构。
此序列使用640×400兼容渲染、关闭阴影并剔除远景细节，只用于动作诊断，
不能替代完整画质截图或真实输入验证。

## stage452 第三人称实图

已查看站姿与蹲姿换弹中段原图，哈希、同机位元数据及观察范围记录于
`artifacts/realism452-validation/independent-third-person-review.json`。
人物头面部仍呈均匀无特征表面，护目镜呈椭圆凸块，手肘轮廓膨胀、靴子过于光滑简化。
应推进头面部、衣物体积和肘部/靴子的连贯结构改善。蹲姿膝盖遮住手与弹匣，
现有截图不能确认握持自然或无穿插，需要补侧面或接触近景。
蹲姿图背景约 x660/y248 的人物看似悬空：先定位该 actor，记录实际坐标、落地状态
与支撑碰撞体，再判断是否故障；不要直接依据这张静态图宣称碰撞失败。
contact 捕获进程退出码0仅证明四张预期截图生成，不证明动作或整体画质合格。

## stage452 换弹手部结构

已实际查看本轮 AR 换弹中段与 SR 换弹中段原始截图，记录图像哈希及范围：
`artifacts/realism452-validation/independent-first-person-review.json`。
AR 左手仍有分离钩状手指、圆盘状拇指/掌部凸起；SR 右手在握把后方呈薄弯片，
缺乏可辨认的手指包握，腕部圆形凸起也明显。两张图都存在长筒状前臂、宽厚袖口，
SR 枪托及机匣的大块均匀表面尤其明显。下一轮优先完成掌心、拇指与手指的连贯结构、
各武器握持姿态以及手腕到前臂和袖口的比例修正；应产生清晰可见的整体形体改善。
本次没有查看 stage451 对照图，不判定本轮改善或退步。

本轮四姿态捕获报告已生成，但这次独立审阅只覆盖上述两张图，静态截图不证明连续换弹
自然或网格无穿插。仍需逐图检查完整 AR 四姿态、SG/SR 与实际第三人称 actor，
并检查正常帧推进的拔弹匣、插入、重新握持过程。当前 aim/offline 进程报告均为退出码0，
只代表相应功能检查。宽阔空旷道路、细碎树冠与远山材质层次仍需改善，整体画质未达标。

## 历史独立反馈：stage413 第一人称对照

已实际查看 stage413 与 stage412 的腰射、ADS 同机位截图，尚未看到明显袖管或机匣形体改善。
ADS 元数据完全相同，平均 RGB 差异仅 0.090/255；数值只说明差异小，不替代目视评价。
证据：`artifacts/realism413-validation/independent-ads-comparison-review.json`、
`artifacts/realism413-validation/independent-default-spawn-comparison-review.json`。
下一步完成当前换弹截图，检查肘部大体积折弯，并验证预期模型修改确实进入导出资源。
不要用导出成功或微小像素变化宣称画质达到要求。整体目标仍未完成。

## stage411 入口标识修复背景：道路材质与人物形体

stage411 独立入口前后实图审阅：
`artifacts/realism411-validation/independent-entrance-review.json`。
已核对两张截图相机元数据完全相同，并记录图像哈希。入口近景中，原来被横梁遮住的
“02 / VEHICLE SERVICE”文字已完整显示在外侧檐口，可认定该机位的遮挡回归修复。
不要继续把已验证的入口招牌作为下一轮主要工作。本次比较仅覆盖入口，
不证明道路远景、人物动作或整体画质达标。室内地坪仍有明显矩形材质变化，
前景铺装过渡突兀；长圆筒袖管、膨胀肘部、大平面机匣和光滑远山仍可见。
下一轮完成一项道路/作业区过渡的实质改善后，优先推进下述人物与第一人称多姿态验收。

以下为 stage410 回归背景及仍适用的验收要求：

独立实图审阅证据：`artifacts/realism410-validation/independent-visual-review.json`。
已对照入口 before/after，并检查 road-horizon after；没有审阅道路 before，
不据此声称道路改善。入口原本清楚的“02 / VEHICLE SERVICE”招牌在后移后被屋顶横梁遮挡，
只剩窄条文字。先恢复入口与接近机位中招牌的真实可见性，采用合理安装位置或结构净空，
不要使用穿透遮挡的材质。修改梁柱时保留通行与碰撞验证。

道路 after 仍有横跨路面的矩形深色色带，山体轮廓光滑圆锥化，树冠颗粒感和重复感明显。
先定位色带对应的网格或材质，再改善铺装修补接缝、磨损与粗糙度的实际尺度，
不要仅增加噪声或调整整幅图颜色。山体需要有地形与岩层依据的轮廓和中景层次。
修复回归并完成一项实质环境形体或材质改善后，回到完整人物和第一人称模型：
袖管仍像长圆筒、肘部膨胀，机匣仍有大块平面；检查默认持枪、瞄准、
换弹中段与末段以及第三人称，避免持续只微调灌木、灯光或装饰条。

stage410 后台报告八项功能检查通过，但静态图与该报告不证明动态人物、
双客户端、精确树干碰撞或整体验收通过。整体目标仍未完成。

人物动作覆盖核查：`artifacts/realism410-validation/independent-animation-coverage-audit.json`。
第三人称补充核查：`artifacts/realism411-validation/independent-third-person-coverage-audit.json`。
`third_person_reload_rules` 的三武器、两姿态、四时间点是直接跳帧的24个数值样本，
不能证明连续播放或手指与弹匣表面的接触。`operator_pose_capture` 检查15个动画的75个
蒙皮包围盒样本，但只保存各组三人物中点图及第一组转向图；它直接加载人物模型，
未装配实际 actor 的武器。`animation_gallery` 只有待机、走路、蹲姿的一张实景图。
人物阶段复用这些入口，但补实际持枪 actor 的三武器站立/蹲姿换弹序列和中断恢复，
以正常帧推进观察过渡；不要把跳帧断言、截图数量和连续动作自然程度混为一项通过。
该轮报告不含袖管多姿态截图、`reload_contact_rules` 或第三人称换弹检查。
现有 `tools/run_sleeve_pose_review.py` 使用 `--pose` 筛选单张也可返回通过；
完整首轮验收应不传此筛选参数，并核对实际生成默认持枪、ADS、换弹中段和完成四张图。
该捕获场景只选择武器0，不能据此认定另两种武器或第三人称通过。
修改人物/手臂后，固定预览与PCK哈希，逐图审阅四姿态，再补其他武器与第三人称。
已有换弹接触测试能检查骨长、手掌与弹匣包围盒接触及恢复，不能证明肩部锚定、
蒙皮形变、手指包握或网格无穿插；同时观察连续动作中的肩肘、护肘与缝线、
手掌/弹匣关系。复用现有瞄准、换弹、遮挡和单机检查，不把截图存在当作画质通过。

## 历史背景：stage386 路肩过渡、树木碰撞与人物形体

stage386 入口与远景已独立逐图对照 before/after，两组相机元数据完全一致，证据：
`artifacts/realism386-validation/independent-environment-comparison-review.json`。
两机位前景的重复浅色碎斑均明显减少，可接受这一局部改善；下述 stage385
材质隔离建议保留为历史诊断背景，不再把“消除同一碎斑”当作下一轮主要任务。
远景仍能看到笔直的铺装补丁边界、突兀的深黑碎石，以及路面与泥土过渡不足。
后续应检查真实铺装尺度、接缝用途、路肩侵蚀和碎石颜色/嵌入深度，保持同机位对照，
避免再次单纯增加噪声。入口结构层次保留，室内仍较均匀；袖管的圆筒形体与机匣大平面
尚未解决。静态截图不证明换弹、人物、碰撞或性能达标，树木与肩肘验收继续按下文执行。

stage385 入口实图已独立复核（2026-09-18）：
`artifacts/realism385-validation/after/repair-shelter-entrance.png`。
门框、斜撑、砖半墙和弧形屋顶已具结构层次，但画面下方路面仍有成片重复浅色碎斑；
入口室内的材质更均匀，不能将两处表面混为同一问题。左前臂仍显长圆管，
机匣侧面大平面明显，当前截图不支持整体写实目标达成。

下一步先用同机位材质隔离定位碎斑，避免继续盲调噪声：
源码 `RepairServiceAccess` 为18×20平面，中心(15,0.052,42)，使用
`service_access.gdshader`；该shader没有ALPHA输出，仅在道路范围外discard。
下方 `service_ground.gdshader` 则输出ALPHA，并含access_chips与aggregate_islands。
仅据白斑形状不能断言是哪层材质造成。请在独立审阅场景分别把两层替换成不同纯色，
保留原机位、光照及深度关系，记录白斑所在像素属于哪层，再对实际来源修改；
诊断纯色不得进入正式预览。修复后补入口和道路远景前后图，
检查碎斑尺度、明暗对比、重复频率及道路接缝，避免只把整个路面压暗。

`baseline-comparison.json` 中六处树木探针及一处树冠/屋顶AABB检查在383与385都失败，
这只证明失败早已存在。下一轮应以当前树干实际位置和碰撞体半径重新做玩家通行测试，
并以几何/近景判定树冠与屋顶是否实际穿插；保留原失败记录，不可仅删除断言报通过。
人物与第一人称袖管仍按下列约束继续，环境局部改进不能替代人物与动作验收。

树干失败已进一步定位，证据：
`artifacts/realism385-validation/independent-tree-probe-diagnosis.json`。
四棵庭院树当前scale为0.95/0.42/1.15/0.58，旧探针仍用0.48/0.32/0.62/0.25；
已有实测命中x与当前圆柱半径0.14×scale完全一致。旧路边(11.5,17.8)探针实际命中
当前(11.8,17.8)、scale1.72的树；(13,11.9)当前scale1.22也与实测一致；
旧(10.9,23)坐标已不在当前树表中。可据此更新探针定位，但必须额外核对
可见树干与碰撞体贴合、玩家近树接触和路线通行，不能仅复制生产半径作为验收。
树冠/屋顶AABB重叠仍未解决，以上数值吻合不证明树冠没有穿屋顶。

stage384 袖管变形依赖已独立核查源码并记录哈希：
`artifacts/realism384-validation/independent-sleeve-deformation-dependencies.json`。
整条袖子（含追加弯肘与上臂）目前单骨骼绑定 Forearm；换弹保持前臂长度但移动肘点，
现有长度检查不证明肩部锚定或肘部形体可信。修复肩肘链时同步检查附件的变形场：
护肘仅覆盖原前臂第8至55环（共97环），缝边沿其边界，长缝线覆盖原前臂全部97环；
它们不是追加上臂网格，不能简单统一改绑上臂。若混合权重进入原前臂区域，
独立的护肘、转网格缝边和长缝线须按同一骨架坐标下的表面位置继承相应权重，
避免只改袖布导致分离。远端袖口与绑带仍须保持手腕连接。
此为源码依赖及修复约束，不是已经观察到附件分离。
验收补同机位默认、稳定ADS、实际换弹中段/完成图；被遮挡时另补肘部和握持近景，
同时检查肩肘连续性、肘部体积、护肘与缝线贴合，不能仅以前臂长度测试通过收尾。

stage383 维修站道路机位已新增独立实图审阅：
`artifacts/realism383-validation/independent-service-approach-review.json`。
人物当前修复收尾后，环境下一轮应处理前景路面重复浅色斑点与矩形补丁边界、
路肩突兀过渡，以及右侧针叶树稀疏细枝和灌木细碎噪点；优先改变可见形体与尺度，
避免仅增加纹理噪声。维修站重复墙板还需窗洞深度、结构连接与顺水流向的污迹。
保留相机位置 (17, 1.60010254, 50)、旋转 (0.1, 0, 0) 做前后对照，
另补入口近景与通行检查。此单帧不证明碰撞或性能，也不是前后改善量结论。
当前 action-timeline partial 只有 hip 和 ADS 过渡起始两帧；
ADS action_frame=0、aim_blend=0.1167、sight_aiming=false，不能作为稳定瞄准证据。
shot_events/recovery_checks 均为空，完整射击、恢复和换弹仍需完成采集。

stage383 换弹中段已直接对照 before/after，逐帧姿态、相机、29发弹药和剩余1.0秒完全一致：
`artifacts/realism383-validation/independent-reload-comparison-review.json`。
新版左侧远端袖管波浪轮廓更明显，但近端与弯肘仍是粗圆管状，已有缝线不能解决受力失真。
下一次模型修改应集中于肘窝局部压缩褶皱、肘外侧张力和体积分布，保持手腕与握持锚点；
同时复查同一换弹中段、结束姿态与ADS。左手及弹匣接触位于画面下方，不能据此验收接触或排除穿插。
两套记录仍为 partial/passed=false；本次检查时原袖管采集进程已不在进程列表，不能继续称其正在运行，
需要后台任务确认终止原因并补齐结束姿态。此项为新增动作形体证据，不代表整体画质达标。

stage383 卡宾枪 ADS 已直接对照 before/after 同姿态图片，逐帧相机/弹药/ADS记录一致：
`artifacts/realism383-validation/independent-ads-comparison-review.json`。
新袖管下侧轮廓和非对称褶皱更明显，但只是局部小幅改善；仍缺可信裁片缝线、袖口厚度与肘部受力结构。
瞄具窗口和红点在两图均未被遮挡，此静帧不能证明命中射线对齐。
机匣后部仍有大平面和明显棱面。优先补袖口到手套过渡及布料结构，不要继续只提高全局褶皱幅度。
本次两套元数据均为 partial/passed=false，截图进程仍运行；换弹与完整采集尚未验收。

stage383 人物3米侧面已与 stage382/before-operator 基线直接对照，相机和人物姿态记录一致：
`artifacts/realism383-validation/independent-side-comparison-review.json`。
袖管轮廓、迷彩图案有变化，但上臂仍呈圆鼓光滑体块，尚不足以证明写实形体显著改善。
下一步应改变肘部弯曲时的布料受力结构、肩袖裁片过渡和装备材质分离，避免继续只增加褶皱幅度。
背包、头盔和靴子仍明显简化。手指被遮挡，不能据此验收握持或换弹；
脚底记录距地约1.1毫米，不应误报漂浮。该结论仅覆盖此静态侧面，不代替动作测试。

stage383 新人物3米正面实图已直接审阅：
`artifacts/realism383-validation/after-operator/idle-3m-0.png`。
面部仍是光滑面罩状体块，头盔、背心袋、护膝和靴子明显简化，肩袖偏圆鼓，
迷彩大斑块尚未呈现可信的布料层次。下一轮优先面部解剖、肘袖受力褶皱和装备材质分离，
不能仅以褶皱幅度增加宣称人物已达写实要求。这是新图单帧审阅，不是前后改善量结论；
握持局部被遮挡，尚不能验收接触。远处人物高度也不作为物理缺陷证据。
完整相机记录、动作采样和测试仍以后台最终归档为准。

stage383 动作验收脚本范围已核查：
`artifacts/realism383-validation/independent-action-acceptance-scope.json`。
已有 `action_timeline_capture.gd` 可在 `REVIEW_KEYFRAMES=1` 下验证三枪实际射击、
后坐恢复和换弹完成，不需要新建重复静帧脚本。不要设置 `REVIEW_WEAPON` 后宣称覆盖三枪。
默认第三人称动作发生在三枪循环之后，仅使用最后一把武器；不是三枪第三人称换弹证据。
`weapon_review_capture.gd` 直接设置换弹剩余时间，只能验收静态形体。
本次是源码范围核查，不是 stage383 动作已通过；仍需冻结包、进程成功退出、
完整 action-timeline.json 以及直接审图。当前后台正在采集，勿并发重复启动。

第一人称 ADS 基线已直接审图并核对采集审计中的图片哈希：
`artifacts/realism382-validation/independent-ads-baseline-review.json`。
这一帧红点与瞄具窗口没有被手臂或机匣遮住，但左前臂仍长直，枪身后部大平面和方正结构明显。
这只是 stage381 单把卡宾枪的静帧，不能证明射线对齐或 stage382 改善。
该采集退出码143，最终逐姿态元数据未落盘、换弹未验证；不得用出生点相机记录替代ADS记录。
后续须保存新模型ADS相机状态，并单独审查换弹中段和完成姿态。

stage382 首张 stable-environment 入口图已与 before 同机位直接比较：
`artifacts/realism382-validation/independent-entrance-comparison-review.json`。
相机元数据一致；该视角中长直袖管与机匣大平面尚无明显形体改善。
前景阴影变化不能用来验收人物或武器。截图套件仍在运行，此结果只约束入口视角，
不能据此否定尚未采集的专门手臂动作图，也不能宣称新模型已经验收通过。

第一人称出生点基线已直接审图并绑定图片及相机 SHA256：
`artifacts/realism382-validation/independent-first-person-baseline-review.json`。
weapon=0、非ADS、1280×800；左前臂长直，迷彩大斑块和少量袖口褶皱没有解决肘部形体，
机匣大平面与方正过渡仍突出。下一次对照必须包含袖管/肘部或枪械轮廓的实质修改，
仅增加表面细节不足以关闭此项。手部部分遮挡，三枪、ADS、射击及换弹仍需单独验证。

stage382 新采集的人物基线已直接审阅3米正侧面：
`artifacts/realism382-validation/independent-operator-baseline-review.json`。
这是 stage381 冻结包的 before 图片，不是 stage382 改善结果。正面面部是光滑面罩状体块，
肩袖、背心袋、护膝和靴子结构简化；侧面袖管宽厚光滑，肘膝过渡缺少衣褶与人体结构。
下一阶段必须先实质处理人物源模型和姿态，不能再用棚架、地坪细节替代。
握枪接触被遮挡，不能直接判为通过；camera.json 的静止鞋底间隙约1.1毫米，
不支持把当前角色判为明显悬空，也不证明运动时脚部接触正确。

10米正侧面基线也已直接审图，图片哈希与采集审计一致：
`artifacts/realism382-validation/independent-operator-distance-baseline-review.json`。
人物约110像素高，轮廓可辨，但不足以关闭3米图中的面部、衣褶及握持缺陷。
宽阔空路、相似松树与光滑山体仍明显。背景人物看似离地不能直接判为运行时悬空：
当前截图脚本暂停 game 逻辑与物理，仅让本地人物落地；若排查背景角色接地，
必须补充正常运行游戏中的角色状态与接地采样，避免依据暂停场景修改游戏物理。

最新独立直接审图证据：
`artifacts/realism381-validation/independent-current-visual-review.json`。
直接查看最终 terrain-wide 图片：宽景仍有重复铺装、光滑山体和相似树冠/灌木；
第一人称左袖管长直、肘部结构不明显，机匣大面平直，
这些占据常用游戏画面的形体问题不能靠新增划痕、螺丝或地坪噪声解决。
这是最终静态画面的观察，不是前后对比，也不证明人物动作、联网或硬件性能。
stage381 的 final-verification.json 记录13项功能测试通过，但第二组截图控制进程
被 SIGTERM 中断，子进程退出码未知；完成标记不能替代成功退出证明。

后台已接续新一轮；不重启或并发修改后台正在处理的源码。下一完整阶段：

1. 用当前冻结包采集第三人称3米/10米正侧面，以及三把武器持枪、ADS、连续射击、
   换弹关键序列；记录相机、武器和动作时刻，直接查看图片，不用规则检查代替审图。
2. 针对图片证实的主要缺陷，实质修改 Blender 源资产、绑定或游戏姿态并重新导出。
   优先手臂比例、袖管与肘部轮廓、握持接触以及人物关节形体，避免又只做屋面/草地微调。
3. 用相同机位和动作时刻复核变化，验证单机、瞄准、武器遮挡及相关碰撞/动作退出码，
   保存包哈希和本地可运行预览。其后继续建筑、植被、地形与光照剩余问题，不缩小整体目标。

下面 stage311/312 仅为历史缺陷定位线索；旧超时不能直接判定当前版本失败，
旧规则通过也不能替代当前画质验收。

## stage311 历史动画验证缺口（2026-09-17）

独立复核见 `artifacts/realism311-validation/independent-animation-timeout-review.json`。
`animation-process-results.json` 的 animation-rules 为 exit_code=124，虽有 PASS 标记，
不能记作完整通过。脚本在 PASS 后直接 quit()；无时间戳，尚不能区分临近超时才完成断言
与退出阶段耗时。若没有后续正常退出结果，定向复测记录 PASS 时刻与退出耗时后再判因。
第三人称最终 action-timeline.json 已 complete=true、passed=true，共23张采样图，
此前 partial 的空 samples 已被最终结果取代；不要再据此判断采集未完成。
阶段总结仍需分别核对退出码、最终动作元数据与实际图片，并完成三枪第一人称审阅。

独立直接审图记录：`artifacts/realism311-validation/independent-crouch-reload-review.json`
（含图片与元数据 SHA256）。0175 蹲行图中膝盖挤近腹部与枪身，脚缩于身体下方，
大腿与膝部呈圆鼓体块，护膝像圆片；头部缺乏面部结构，袖管呈团块状。
0343 换弹图仍是胸前聚拢持枪轮廓，单帧无法证明弹匣交接；小腿、靴子和头部过于简化。
这些是当前缺陷，不宣称由 stage311 引入。后续先补侧面蹲姿转换与完整换弹关键序列，
检查髋膝踝关系、鞋底世界坐标与地面接触、手与弹匣交接，再实质修正源模型/绑定。
grounded=true 和前臂长度通过不等于姿态写实；不要仅从阴影偏移判断悬空。

## 历史直接观察

2026-09-17 stage312 stable 侧面同机位前后审阅：
`artifacts/realism312-validation/independent-stable-side-review.json`（图片与元数据散列）。
相机元数据一致；改变主要在门廊顶板与入口右后方灌木，建筑整体体量与日光观感仍相近。
左雨棚下亮白条和右立柱网点在前后图都存在，不判为新增回归，也不能凭图确定根因。
长直袖管、大块平直机匣、光滑远山和重复树形仍明显。当前验证结束后优先三枪
第一人称持枪/ADS/换弹与实质轮廓修正；光照问题用固定机位受控对照定位。
stable 四张环境截图采集已正常退出（exit=0），这不代表整个阶段功能或整体画质验收通过。

2026-09-17 stage312 已归档 iteration1 独立审阅：
`artifacts/realism312-validation/independent-iteration1-environment-review.json`。
入口前后相机元数据一致；可见改变主要在雨棚顶板，整体入口明暗未见显著改善，
钢架仍有网点表现，尚不能判断材质、阴影或抗锯齿哪个是原因。
本次还直接查看 iteration1 的 terrain-wide：灌木团与通路可辨，远山仍光滑，
棚架和道路仍规整；未打开 before 同宽景，不作植被前后改善结论。
第一人称长直袖管与大块平直机匣仍占据主要画面，应优先进行三枪持枪/ADS/换弹审阅和
轮廓修正，不以顶板与灌木局部调整替代人物武器阶段。此审阅只针对归档 iteration1，
不等同于当前 stage312 最终包验收，保留后台正在进行的修改与验证。

前台实际打开 `artifacts/realism310-validation/stable-environment/terrain-wide.png`（1280×800）。
当前维修棚与道路之间已有连续混凝土通路，棚内入口可辨；板面边缘仍有草叶，前景碎石棱角和
粒径分布重复，远山表面光滑、地形层次不足。右侧棚架横梁与立柱轮廓规整，场景仍显空疏。
枪身占屏很大，灰色机匣平直、材质分区弱；左袖管笔直，肘腕姿态与布料折叠解释不足。
这些是当前截图直接可见的问题；未在本次前台审阅中比较旧图，不宣称改进幅度。
这张静帧不能证明换弹动作、第三人称人物或手机效果，不能关闭完整动作验收。
stage310 自身审阅也明确本轮仅修复通路局部缺陷。下一轮按下方人物与武器动作阶段推进，
不要再把单独修改铺装、草株或泥土参数作为主要阶段；环境大范围整改仍需后续完成。

## 下一完整阶段：人物与武器动作的实机缺陷修复

待正在执行的阶段完成后，由唯一后台 worker 执行；前台不并行修改游戏文件。
环境已连续完成多轮迭代，现在按任务说明“随后结合第三人称人物与第一人称手部审阅”推进。

1. 使用当前导出包先拍摄第三人称人物在约3米、10米正常交战距离的正面与侧面，
   检查头身比例、肩肘膝轮廓、衣物层次、装备连接与持枪姿态；保留实际距离和相机参数。
   不用 Blender 工作视图代替游戏画面，不从环境静帧推断人物质量。
2. 为三把武器采集正常持枪、瞄准，以及连续换弹的关键时刻或短序列；
   检查手指接触、左右手握持、弹匣交接、关节折叠、袖管和历史 stage225 上臂遮屏问题。
   使用现有截图/动作脚本，先限定读取相关脚本，不加载全部历史证据。
3. 从上述实机证据选择影响最大的一项轮廓或动作缺陷，实质修正 Blender 源资产及其导出资源，
   必要时修正 Godot 挂点与动画。若问题来自材质或姿态，先证明原因再修改对应实现。
   不把整阶段缩减为小螺丝、单根手指或无明显观感差异的参数微调。
4. 同机位、同动作时刻保留前后对比；验证三枪瞄准、武器遮挡与相关动画规则、单机运行。
   若更改世界几何，再补对应碰撞通行验证。提供当前可运行预览并说明已知不足。
   已通过的旧包测试不能证明新包通过；记录最终包和相关资源散列。

## 仍需完成的整体范围

- 建筑：大表面材质、合理结构和场景分布，减少重复空旷感，保持入口与室内可玩。
- 地形植被：解决远山轮廓重复、泥地模糊与碎石比例，树草形态和疏密自然，而非只加密株数。
- 光照：用受控对照定位入口钢架网点、金属偏白及明暗平的问题；根因未确认前不猜测已解决。
- 人物、三枪及手臂：静态比例和完整动作都要审阅，不以一张环境图代替。
- 功能：单机、瞄准、碰撞、本地可运行预览；保留联网和 Android 启动/输入验证任务。
  服务器修复后的联网验证属于已发布客户端，不能自动归属于最新画面预览。
- 性能：软件 Vulkan 截图只证明该环境可渲染，不能证明玩家设备帧率或 Android 兼容性。

最终验收仍覆盖全部目标；不得以轮次数、截图数量或小幅改善宣称接近原作程度。
未经用户确认不得推送 GitHub。保留所有已有修改，不改后台服务、任务说明或结果 schema。

## stage257 独立基线审阅补充

前台已实际复核3米侧面人物与卡宾枪ADS截图，证据和图片散列：
`artifacts/realism257-validation/independent-baseline-review.json`。
背包硬块轮廓、小腿与靴子比例、持枪僵硬和第一人称枪身大平面仍明显。
当前worker正在做环境材质调整；该阶段收尾后仍须完成上述人物与三枪动作修正，不得用环境改动替代。
人物躯干边缘点纹根因未证实，先做受控材质/阴影对照再改。
动作脚本每枪单次射击及ADS终点不能证明连续射击和开镜过渡；明确验证范围。
OOM前启动的验证不能默认成功，按最终包补齐缺失结果；优先串行重型截图以降低峰值内存。

## stage257 入口阴影诊断复核

独立审阅与图片散列见 `artifacts/realism257-validation/independent-entrance-diagnostic-review.json`。
基线与 diagnostic 入口图相机元数据一致，左内侧钢柱密集点纹仍明显；
该柱区域平均 RGB 差仅约 0.18/0.14/0.16（0–255），不能当作缺陷改善。
diagnostic 同时有 no_local_shadows.gd 和 no_sun_shadows.gd，却没有截图对应脚本与包散列，
因此当前证据不能严格证明某类阴影是根因或已被排除。
下一次对照使用同一 PCK，原始、关闭局部阴影、关闭太阳阴影分别输出独立目录，
记录脚本/PCK 散列、实际修改光源数量及相机；若都保留点纹，再检查重叠面、透明抖动与法线。
不要用关闭全部阴影作为最终画面修复。

## stage257 换弹早期帧审阅

证据与散列：`artifacts/realism257-validation/independent-reload-review.json`。
已查看卡宾枪 0115 与 0127 帧，仅相隔 0.2 秒，HUD 剩余换弹 2.0/1.8 秒；
这些图不能证明拔匣、插匣、操作枪机及恢复握持完成，也不能覆盖另外两枪。
枪托外轮廓棱角、大块斑驳表面以及袖管宽直的收束仍需改善。
手套、弹匣与机匣投影相互遮挡，不能仅凭这两图断言手指接触正确或存在穿模。
最终包应串行完成动作采集，保留完整 manifest 与脚本/包散列；
按 action_frame 和 reload_left 对照放开护木、弹药交接、插入和恢复握持时刻。
若手指接触仍不可见，再补诊断视角。完成脚本尾部写入的 manifest 前，不把局部 PNG 当作全流程通过。

## stage260 独立动作接地审阅

证据：`artifacts/realism260-validation/independent-ground-contact-review.json`（图片、manifest、脚本与失败日志散列）。实际查看0198蹲走与0415换弹后Idle原图：膝部呈截断裤管，Idle仍有鞋底与路面分离观感；人物动作不合格。两帧均grounded=true、根节点y=0.000738，0415速度为零，不能仅以出生未落地解释。阴影分离不等于鞋底世界距离，先测蒙皮鞋底世界坐标、向下地面射线、骨骼及模型根变换；膝部另查顶点权重与裤管连接，避免只下移整个角色掩盖形变。固定包、机位、动画时间比较前后。当前manifest只有41个第三人称weapon0采样，不证明三枪第一人称完整流程；无窗口animation_rules仍为明确失败，须补实际窗口化结果。

## stage261 独立远景基线审阅

证据：`artifacts/realism261-validation/independent-terrain-baseline-review.json`。已查看 before/terrain-wide.png 原图，路边植被与工业建筑已有场景覆盖，不应再笼统称为空场景。主要差距是前景车辙宽而模糊、远山连续尖峰与面状明暗、第一人称袖管偏直及枪身大平面。最终 after 尚未审阅，不能声称这些缺陷已改善；先完成同机位对照，再优先处理可见尺度和轮廓问题，避免仅增加草丛数量。人物鞋底/膝部与三枪完整动作继续单独验证，不以环境通过替代。

## stage261 独立入口前后对照

已实际打开 before/after 入口原图，两个相机清单完全一致。详细散列与审阅见 `artifacts/realism261-validation/independent-entrance-comparison-review.json`。黄色维修标记可辨，但混凝土整体仍均匀；棚顶亮斑、后墙硬边阴影仍明显。绿色钢柱梁、第一人称长直袖管及大片平坦枪身仍不满足写实目标。后续优先改善可见材质/结构与人物接地、膝部和握持，不将新增标记作为主要画质收益。此审阅仅覆盖入口图，不代表宽幅、完整动作或 Android 验证。

## stage261 独立宽幅前后对照

已实际查看 before/terrain-wide.png 与 after/terrain-wide.png；相机清单完全相同。证据：`artifacts/realism261-validation/independent-terrain-comparison-review.json`。本轮远景提升很小，不能以新增草株数量代表明显写实提升。下一次环境修改优先处理近景车辙：现有宽深色带与模糊地面缺乏可读的碎石/压实土尺度及粗糙度变化；其次打破远山连续尖峰与平面明暗。先在相同宽幅机位验证肉眼可见的改善，再追加小道具。像素差只描述变化范围，不是画质评分。人物膝部/鞋底、袖管与三枪完整动作仍未完成。

## stage258 ADS/开火独立审阅与 stage262 资产关联

证据：`artifacts/realism258-validation/independent-ads-fire-review.json`。实际查看0090-ads-0和0114-fire-0：瞄具边框较厚、机匣大片平面、导轨重复槽口和长直袖管仍明显。258与262构建清单中的viewmodel生成脚本、blend、glb及动作采集脚本散列相同；这说明资产未变，不证明最新运行姿态或光照相同。两帧弹药30→29但姿态几乎一致，不能据此说开火失效。归档source-before脚本在shoot后advance24才截图，且其与after采集的对应仍需证明；单张延迟截图不能验收枪口焰/后坐峰值。请唯一后台编辑者优先补固定包shot+1/+3/+6与回正采样、实际时间步及三枪完整manifest，再评估机匣轮廓、粗糙度和袖口造型改进；保留瞄准射线验证。手指接触被遮挡，不武断判定穿模。


## stage262 独立宽幅前后对照

实际查看两张 terrain-wide 原图，相机清单逐项完全一致；图片散列与结论见 `artifacts/realism262-validation/independent-terrain-comparison-review.json`。车辙缩窄减淡、远山尖峰圆缓均有可见收益，但近景泥地仍模糊，轨迹仍像平滑色带，圆丘和树影仍重复。下一步保留当前车辙明度，增加具有一致真实尺度的压实土/碎石及粗糙度变化，打破山丘间距和树林成簇规律；用同机位验证，不以增加草数量代替观感提升。棚顶亮斑需入口机位复核；人物接地、长直袖管、平坦机匣和三枪完整动作仍需独立完成。此对照不代表 Android、硬件性能或完整游戏画质验收。


## stage262 入口光照独立诊断
实际查看 after/repair-shelter-entrance.png：顶棚约(640,296)暖色集中亮斑、后墙硬斜阴影仍明显。诊断与图/当前源码散列见 `artifacts/realism262-validation/independent-entrance-light-diagnostic.json`。当前 RepairApronReflectedDaylight 俯角仅8°、半锥角78°，锥体包含向上照射方向，可能照到棚底，但不能据此认定它是暖色亮斑来源。下一步冻结包及入口机位，分别仅关闭该灯、仅关闭 shelter_bounce 对照；若亮斑保留，再隔离其他灯及检查棚底材质法线/高光。不要先改全局曝光，否则难以识别原因。此轮为定位建议，尚无隔离渲染或修复结论。

## stage262 侧面金属材质独立审阅
实际查看 after/repair-shelter-side.png 原图，记录及散列见 artifacts/realism262-validation/independent-side-material-review.json。曲面棚顶当前主要是宽色条，当前轮若加强面板色差，务必同机位检查是否仅增强条纹；优先让细窄压型结构、粗糙度和连接节点可读。绿色柱梁均匀锐直、白色横条同色等距、顶部曲梁分段也仍明显。此记录只是stage262基线，不评价尚未完成的stage263，也不替代功能验证。

## stage263 侧面金属前后独立审阅
实际查看 before/after 的 repair-shelter-side.png；两份机位JSON完全一致，图像散列与限制记录于 artifacts/realism263-validation/independent-side-material-review.json。新棚顶细窄压型筋更可读，改善不只是宽色条增强，但均匀绿色锐直柱梁、白色等距横条及分段拱边仍明显简化。下一步优先补连接板/螺栓/边缘倒角等有结构依据的节点，保留现有压型可读性，不再只做色差循环。两图树形和动态阴影有变化，不能以全图差异量作材质收益。入口亮斑仍按stage262灯具隔离建议验证；移动闪烁、Android和整体画质均未由本次静态图证明。

## stage263 宽幅碎石独立审阅及包复核

已打开 after/terrain-wide.png 原图：白色碎石均匀散布，呈纸屑感。下一步不要只加数量或整体压暗，应按轮迹中心细碎低矮、路肩及排水低处局部聚集安排尺度和密度，混入土色并保持行走轮迹清晰。近景泥地模糊、稀薄树冠、重复圆丘及枪袖形体仍未达标。入口灯光继续同包隔离。

独立读取九项原始日志并核对 PASS 标记；预览 PCK 实际散列与测试包一致。记录 artifacts/realism263-validation/independent-wide-ground-review.json。规则测试不证明真实多人、Android 或完整动作画质。

### Stage264 independent isolation review — 2026-09-16
- Same entrance camera verified across before/apron/bounce/porch manifests. All four capture runs exit0/PASS without error markers; each isolation log confirms exactly one light disabled. Independent numeric evidence: artifacts/realism264-validation/independent-light-isolation-review.json.
- Actual before/porch PNG inspection identifies the porch OmniLight at local (15.5,2.72,34.05) as the main warm roof hotspot contributor. Roof ROI [550,280,735,311] mean absolute channel difference is 40.36/255 after porch removal, versus apron6.66 and bounce0.008. The captures are not identical; apron/bounce changes simply do not resolve this hotspot.
- Porch-off retains the hard backwall diagonal shadow (backwall mean delta0.134/255). Handle that independently; do not claim both lighting defects fixed by porch removal. Prefer a physically placed, directed/shadowed fixture and compare final build to this porch-off reference. Preserve readable door material and avoid solving local problems with global exposure changes.
- This is diagnostic evidence on the baseline, not final stage264 build or gameplay acceptance. Repetitive structural joints/slats, bright uniform gravel and first-person weapon/arm finish remain open.

### Stage264 final side comparison and priority correction
同机位清单逐项一致，已实际检查 before/after 侧面原图，图片散列和独立结论见 `artifacts/realism264-validation/independent-side-final-review.json`。白纸屑感碎石明显减少、棚底暖色亮斑消失，保留这些收益。绿色方柱梁、分段拱边、等距白条仍简化，小连接节点不足以证明整体造型显著提升。第一人称大平面机匣和长直袖管仍占据明显画面面积，树冠稀薄规则、近景地面模糊。
纠正此前措辞：后墙硬斜阴影本身不是缺陷证据，直射日光可能合理地产生硬阴影；继续调整前先证明日光/遮挡来源，不要为了柔和而破坏合理光照。下一轮优先第一人称枪袖轮廓与三枪完整动作采样，再处理树冠体积和结构节点，避免继续只做局部灯光微调。当前四项通行回归通过，其他测试运行中；不代表整体画质验收。

### Stage264 动作采样覆盖缺口（独立源码审阅）
当前 `tests/action_timeline_capture.gd` 的单发 fire-N 在 REVIEW_KEYFRAMES=1 时只保存 frame23，即开火后24个模拟tick（0.4秒）；不能据此判断开火瞬间枪袖表现。外层 frame%12 过滤还会吞掉新增的 frame2/5，必须统一采样判定后再 continue，不能只往内部列表加入帧号。下一阶段对三枪记录开火后第1、3、6tick和恢复姿态；持续射击按实际弹药减少的成功射击事件采样，补充射击tick及摄像机、枪和手腕世界变换。完整换弹继续保留。证据及源码SHA见 `artifacts/realism264-validation/independent-action-sampling-review.json`。这是验证覆盖不足，不是射击失效的证据；前台未改游戏或测试源码，留给唯一后台worker处理。

### Stage265 树冠收益与几何开销独立审阅
同机位 before/after 清单一致，树冠中下部更饱满，但上部细枝规则、建筑方梁、近景模糊地面和大平面枪袖仍未达标。原始 GLB 为80,326三角面，其中叶片58,016面，按旧生成器推导叶片26,880面，新叶面数约2.16倍；这不是实机渲染面数，Godot导入已启用自动LOD，不能声称没有LOD。继续加密前应测导入LOD及实际远景/Android开销，优先改善簇状分布与不对称树冠。证据及散列见 `artifacts/realism265-validation/independent-tree-cost-review.json`。九项功能结果均exit0且无错误标记；仍不证明Android启动或整体画质。保持下一轮三枪枪袖完整动作及开火1/3/6tick采样优先级，避免树叶数量循环替代核心第一人称观感修复。

### Stage266 恢复姿态验收缺口（独立源码审阅）
新脚本已统一开火1/3/6tick采样，保留该修复。当前固定recovery48tick只消退0.06后坐力；actor最大recoil0.18、每秒衰减0.075，最坏需144tick才能归零。audit_capture.py只断言fire_left==0，该字段是射击冷却，不能证明镜头回正。建议有上限地等待recoil到容差内及枪姿态稳定，保存末态并分别断言镜头/枪恢复，保留开火固定时刻采样。证据及源码SHA见 `artifacts/realism266-validation/independent-recovery-coverage-review.json`。这是源码验证覆盖缺口，采样仍运行，不能声称本次实测恢复失败；前台未修改游戏或测试源码。

### Stage266 枪械材质导出排查（独立只读审阅）
- 当前 carbine.glb 的 Receiver、Receiver edge、Grip 均实际内嵌颜色、法线和金属/粗糙度图像，详见 `artifacts/realism266-validation/independent-carbine-material-review.json`（包含资产散列与各图片字节数）。build_assets.py 的表面细节使用图像节点导出，并非仅留在 Blender 的程序节点。
- 因此暂不把画面枪体偏平归因于“未导出材质”；先结合动作截图审阅轮廓、袖管比例和运行时受光。此结论只针对当前源码 GLB，不代替冻结 PCK 画面或 Android 验证。

### Stage266 恢复覆盖复核与 ADS 实图
已确认后台采纳前述恢复验证建议：有上限等待 recoil/kick 归零，额外采集 neutral，比较射前 ADS 的镜头角度、枪位置与角度。此前“仅检查冷却”的源码缺口关闭；采集进程仍运行，尚不宣称实测恢复通过。独立证据及源码/图片散列：`artifacts/realism266-validation/independent-recovery-followup-and-ads-review.json`。实际查看 `actions/0079-ads-0.png`：导轨与瞄具轮廓可辨，但机匣大平面、长直袖管、中央方梁/等距横条和远山圆丘重复仍明显。该单张中未辨明发光瞄点，先比对稳定 ADS 帧和运行时状态再判缺陷。完成现有动作采样后优先枪袖轮廓，勿将采样覆盖补齐当成画质完成。

### Stage266 ADS HUD采样一致性
当前动作采样器关闭 game.process 后只调用 update_hud，没有同步正常游戏每帧设置的 sight_aiming；稳定 ADS 中心截图仍保留白色腰射十字。请按运行时 aim_blend > 0.5 规则同步 HUD 并保存/断言状态，再评估瞄点画面；此为采样一致性问题，不证明实际游戏 ADS 故障。当前源码与冻结包范围不同，避免据此直接改枪模。证据与散列：`artifacts/realism266-validation/independent-ads-hud-parity-review.json`。无需为单项 HUD 修复重复整套昂贵渲染；继续实际模型材质改进。

### Stage267 钢构侧面独立实图复核
实际并排查看 before/after 的 repair-shelter-side.png，原始机位 JSON 完全一致。钢拱翼缘和前柱凹截面可辨，属于局部改善；主体横梁仍厚重，地面大面积软糊，入口前高草遮挡视线，枪机匣与长直袖管仍突出。格栅等距本身不是错误，应改善厚度、连接、材质尺度和受光，而非随机打乱。下一轮优先组合地表行走/排水宏观变化与细颗粒法线粗糙度、沿墙/排水线成簇植被、建筑接触光照；保留入口清晰通行，避免仅继续细调钢拱或全屏锐化。本次只审阅侧面已有实图，不声称新增渲染、宽景或 Android 验证。图片与机位散列见 `artifacts/realism267-validation/independent-structure-visual-review.json`。

### Stage268 宽景独立复核
仅查看本轮 terrain-wide 实际截图，未做前后改善量判断：前景车辙仍是宽软浅色带，石粒清晰度明显高于泥土底材；左侧路肩中景仍近似连续高草条带。后续地表应验证压实区粗糙度、辙边法线/高度与低矮植被过渡，避免全局锐化。当前按计划继续人物膝脚及三枪动作审阅；枪机匣与直袖管仍占据前景，环境修改不能代替它们的改善。证据见 artifacts/realism268-validation/independent-wide-review.json。

### Stage268 侧面材质独立对照
前后截图机位元数据相同，基线哈希符合来源记录。下部竖板的大块平滑纵向明暗仍偏金属观感，正常游戏距离木纹与板缝不明显；后续验证木材粗糙度、板边厚度，不能仅靠压暗。左前臂旁点状弧带两版均有，来源未定位，不判为本轮新增缺陷；必要时用同机位隐藏武器截图隔离来源。证据：artifacts/realism268-validation/independent-side-material-review.json。整体目标未完成。

### Stage269 入口独立审阅与下一轮优先级
同机位前后入口实际截图可见两侧砖柱脚及顶盖，属于局部接合改善；粗绿横梁、平板机匣、直袖管仍突出。两个新增柱脚射线命中 z=35.35，中央 x=15/16 四次胶囊通行通过；这些证据不覆盖紧贴新柱脚边缘的胶囊绕行，尚无证据判定碰撞有错。独立证据：artifacts/realism269-validation/independent-entrance-review.json。
完成本轮验证后，下一轮优先转向第一人称机匣/袖管或第三人称膝部/靴底的可见缺陷，至少完成一项明确的模型或材质修复并以真实游戏前后图证明；不要再次只做棚屋细节小改。人物脚底应结合蒙皮后顶点和地面射线定位，不能直接下移根节点掩盖；三枪完整换弹/连射实机证据仍待完成。整体目标保持未完成。

### Stage269 袖管外侧点状暗带定位
实际放大查看侧面截图：左前臂轮廓外的地面存在宽幅点状暗弧，与紧贴袖边的浅色滚边是两个不同现象，不能仅靠修改缝线解释。证据与图像散列：`artifacts/realism269-validation/independent-sleeve-halo-review.json`，裁图 `independent-sleeve-halo-crop.png`。当前源码同时启用 SSAO 和 SSIL，但尚无因果证据。下一步固定同机位、姿态、渲染方法、光照及预热帧，依次单独关闭 SSAO、还原后单独关闭 SSIL、还原后关闭第一人称模型投影，必要时隐藏第一人称模型隔离；保存各自实际参数与实图。依据对照选择局部修复，保留建筑接触光照，不从单张图直接全局关闭 AO 或修改袖管几何。本次未执行上述 A/B 渲染，整体目标未完成。

### 第270轮独立复核：柱脚覆盖更新

实际 actor.move_step 胶囊测试已覆盖左右柱脚正面阻挡及各自内侧绕行，四条采样路径通过，补上269轮仅射线检查柱脚的缺口；不代表任意方向都已覆盖。验证器使用打包资源及工作区外部测试脚本，最终归档请保留脚本哈希和 PCK 前后哈希。全景仍显示近景地面偏软、草带规则及第一人称枪械/袖子大块平面；下一轮优先执行已有枪械/袖子与黑晕定位反馈。独立证据：`artifacts/realism270-validation/independent-wide-and-traversal-review.json`。

### 第 271 轮独立 SSAO 对照复核

已目视检查 baseline 与 ssao-off 的同位置袖管裁图，两个 camera records 完全一致，脚本及 PCK 哈希一致，两次捕获退出 0。关闭 SSAO 后，袖管左外侧点状黑弧仍明显存在，因此仅关闭 SSAO 不构成修复。等待 SSIL / 第一人称阴影隔离结果，不提前认定根因。证据：`artifacts/realism271-validation/independent-ssao-sleeve-comparison.png`、`independent-ssao-sleeve-review.json`。当前证据不包含多帧时域稳定性验证。
