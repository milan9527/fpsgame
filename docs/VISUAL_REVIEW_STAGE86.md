# Stage86：袖料织纹与三武器同机位复核

本轮延续stage85检查点，按stage31反馈继续处理第一人称近景。整体写实目标尚未完成，状态continue；本轮没有重复stage29验收。

## 实际改动

`tools/build_viewmodel.py`新增固定随机种子的可平铺多尺度染色纹理，袖料叠加细纱与稀疏防撕裂线，加强部位采用斜纹，并调整颜色与微法线强度。重新生成`art/first_person.blend`及`client/assets/first_person.glb`。本轮没有修改袖子几何、骨架或动作；形体沿用stage85。

与stage85同机位裁切对比，袖料从均匀橄榄色表面变为较浅、带细织纹和不均匀染色的表面。变化可见，但宽褶仍过于规则，腕掌过渡与手指比例仍需修改，不能据此认定手臂已达到写实标准。

- 前后对照：`../artifacts/realism86-validation/sleeve-before-after.jpg`
- 源码腰射/ADS：`../artifacts/realism86-validation/source-aim-pairs.jpg`
- 源码换弹三个时刻：`../artifacts/realism86-validation/source-reload-poses.jpg`

## 截图条件与观察

使用实际游戏场景、Godot 4.4.1 Forward+ Vulkan llvmpipe软件渲染，1280×800；固定玩家位置(17,0.05,50)、yaw=atan2(-18,16)、pitch=-0.03。每把武器采集腰射、ADS及换弹进度25%/50%/75%；ADS使用游戏自身视野变化。脚本冻结场景并设置动作时刻，因此这些是游戏渲染姿态截图，不代表手动连续游玩或硬件帧率验收。

源码三武器合成图已逐行审阅：

- 卡宾枪：腰射和ADS光学瞄具位置连贯；布料层次比stage85丰富，但机匣仍偏暗厚重，金属与聚合物区分不足。
- 霰弹枪：ADS后部轮廓宽大，换弹时枪托大面积黑色平滑面明显；袖料织纹可见，但手指偏短圆，腕部仍有管状感，应优先修整主要截面与连接。
- 精确射手步枪：腰射及ADS瞄镜居中，换弹三个抽样时刻没有明显脱手；枪托和镜筒仍偏简化。静态抽样不能排除连续动作中的短暂穿插。
- 背景仓库入口、地面植被分布和远山仍重复、空旷且偏游戏化。本轮未改环境与第三人称人物，整体目标明确未完成。

## 自动验证与局限

源码与预览PCK各运行六项检查，共12项退出0并输出PASS：三武器瞄准对齐108采样、换弹接触183采样、近墙遮挡规则、视模规则、武器视觉规则、单机烟雾测试。详见`../artifacts/realism86-validation/test-results.json`及对应日志。几何/规则检查通过不等于视觉形体自然，也不是全地图碰撞遍历。

Blender构建与PCK导出成功。Godot导入退出0，仍记录已有`Parameter "t" is null`（dummy/storage/texture_storage.h:107），保留在`import.log`，未宣称修复。真实联网未运行，remote_snapshot只是进程内检查；标准Linux发布模板不可用，采用Godot可执行文件和导出PCK生成预览。

## 预览包复核与证据

预览包三武器腰射/ADS及三个换弹时刻也已逐行审阅，袖料变化与源码一致，上述形体局限仍可见。源码与包内各15张截图、两个采集进程均退出0并输出PASS，索引及SHA见`../artifacts/realism86-validation/capture-status.json`。逐帧每通道平均绝对RGB差约0.097–0.665（0–255量程），不是逐像素完全一致；该统计仅辅助目视核对，不代替画质判断。

- 包内腰射/ADS：`../artifacts/realism86-validation/packaged-aim-pairs.jpg`
- 包内换弹：`../artifacts/realism86-validation/packaged-reload-poses.jpg`
- 本地预览：仓库根目录运行`artifacts/realism86-preview/Linux/IronMeridian --path /tmp`，保留同目录`IronMeridian.pck`。
- 运行说明与验证：`../artifacts/realism86-preview/Linux/README.md`、`build.json`、`verification.json`；六个构建输入/产物哈希均与记录一致，见`../artifacts/realism86-validation/build-hash-check.json`。

未push或发布，保留工作区已有修改。当前预览经过软件Vulkan实际截图与单机自动检查，真实联网、全地图碰撞及整体写实画质尚未验收，状态continue。

## 下一阶段

下一轮优先改善霰弹枪宽厚的后部轮廓、枪托材质及手套腕掌过渡，继续同机位腰射/ADS/换弹验收；随后处理仓库入口、道路边缘和植被层次并增加机位。人物、光照、真实联网与更广地图碰撞仍需推进。
