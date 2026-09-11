# 队内语音开发

当前源码已接入采样率转换、编码、抖动缓冲、专服队内转发、麦克风采集、按键说话和播放设置。合成音频已通过四客户端到实际混音器的链路验证；真实麦克风与耳机设备尚未验收，发布包仍为 0.34。

## 音频格式

`client/scripts/voice_codec.gd` 使用每包独立的 IMA ADPCM。输入为 16 kHz、单声道、20 ms（320 个采样），输出固定 164 字节；未包含 RPC/IP 开销的持续发送载荷为每秒 8200 字节。双声道输入取平均，非有限数值转为静音，幅度限制在 PCM16 范围。

包头依次为小端有符号 16 位初始采样、8 位步长索引、8 位格式版本 1。余下 319 个采样编码为 4 位差分，低半字节在先，最后一个高半字节为零。每包携带初始预测值与步长，不依赖前包解码状态。接收器严格检查长度、版本、步长索引与末尾填充。

这是不依赖原生扩展的宽带语音基础格式，尚未实现 Opus、回声消除或噪声抑制。

## 输入采样率转换

`client/scripts/voice_resampler.gd` 将设备采样率转换到 16 kHz。32 抽头加窗 sinc 滤波、128 个预计算分数相位用于限制混叠；整数采样时钟保证跨输入分块的确定性。缓冲仅保留滤波所需历史，不积累整段录音。单次超过 8192 帧的积压输入被丢弃并重置，调用方仍需处理设备停顿与重新启用。

## 接收抖动缓冲

`client/scripts/voice_jitter.gd` 以 60 ms 初始等待处理短暂乱序，最多保留 10 个包，拒绝重复、已播放或超出窗口的数据。缺包时用上一采样在 5 ms 内淡出至静音；连续缺少 5 包后清空，长时间无数据或播放停顿也会重置，防止旧语音延迟重放。这一层不代替服务器的鉴权、队伍筛选和发送限速。

## 已执行验证

- `tests/voice_audio.gd`：合成双音信号编码 RMS 误差约 0.009633、异常包校验、静音、乱序、重复包、丢包淡出、缓冲上限及停顿重置。日志 `artifacts/voice-audio-rules.log`。
- `.venv/bin/python tools/test_voice_codec.py`：用当前 Python 3.11 的标准库 IMA 解码器独立解码合成测试包，320 个输出采样逐一一致。日志 `artifacts/voice-codec-independent.log`。该交叉测试依赖 Python 3.11 的 `audioop`，不要求游戏运行时安装 Python。
- `tests/voice_resampler.gd`：8/16/44.1/48/96 kHz 五种输入，整块与分块转换完全相同；1 kHz 幅度保持、12 kHz 折叠抑制和缓冲边界通过。日志 `artifacts/voice-resampler.log`。

上述测试只使用生成的合成信号，没有采集人员声音。队伍鉴权与限速转发现已接入。采集、播放及设置的验证范围见下文，真实设备验收仍待完成。

## 专服转发

`voice_relay.gd` 维护每个连接独立的 50 包/秒令牌桶，最多突发 6 包；64 个序号的重放窗口允许短暂乱序，拒绝重复与过旧序号。大幅向前跳号不会在网络恢复后永久锁定发送者。无效格式不进入限速或重放状态，超额包不会转发；新回合与连接移除时清理状态。

`submit_voice(round_id, sequence, packet)` 使用独立的不可靠通道 5。发送者由连接身份确定，必须已完成鉴权、处于双人模式和当前回合，且未进入账号撤销流程。大厅按票据中的邀请队伍筛选；live/finished 阶段按权威队伍分配筛选，允许淘汰成员与队友交流。不给发送者回声，也不向敌队转发。

专服不解码或保存音频，直接将合法数据转发为 `receive_voice(round_id, sender, sequence, packet)`。客户端再次检查回合、模式和编码格式后发出 `voice_packet_received` 信号；播放组件订阅该信号，玩家开启收听后才创建队友音频流。采集器在同一回合持续递增序号，松开说话键不会归零。

`artifacts/voice-relay-rules.log` 验证限速、突发、重放窗口、乱序、长间隔恢复、大厅队伍、战斗队伍、撤销会话和重置。`.venv/bin/python tools/test_rescue_network.py --parties --voice-relay` 使用四个真实客户端发送合成音频，刻意先发奇数序号再发偶数序号，并同时提交伪造的旧回合数据。每个接收者只收到原队友的两个序号类别，解码出的采样与发送者标识对应；救援、胜负和四条战绩继续通过。主日志 `artifacts/voice-relay-network.log`，专服与客户端日志以 `voice-relay-network-` 开头。这是数据转发验收，不代替真实麦克风和播放设备验收。

新增 RPC 后，独立开发专服已重新构建并启动，两个客户端对已部署服务的登录、邀请和同队入场验证通过：`artifacts/voice-relay-deployment.log`、`artifacts/voice-relay-deployed-admission.log`。

## 采集、播放与玩家设置

`voice_capture.gd` 使用独立静音总线上的 AudioStreamMicrophone / AudioEffectCapture，不向本地扬声器回放麦克风。输入转换为 16 kHz 后按 320 帧封包；松开按键立即停止流并清理残留采样。同一回合序号连续，换回合归零。超过 150 ms 的处理停顿、超过 120 ms 的采集积压或超大输入会丢弃积压，避免恢复后发送旧话音。

`voice_playback.gd` 为每个队友创建独立抖动缓冲和 AudioStreamGenerator；等待 60 ms 后启动、预排约 40 ms 音频，音频总线有限幅器。禁用收听、静音或切换回合会停止并销毁流；500 ms 无新音频自动释放说话者，退出场景移除总线。`team_voice.gd` 连接玩家设置与当前回合；仅在线双人、窗口有焦点、未打开菜单/背包/地图/按键设置且按住说话键时启动发送。

暂停菜单新增收听开关、麦克风开关与队内语音音量。收听默认关闭并保存选择，麦克风每次启动游戏默认关闭且不保存启用状态；音量与主音量相乘。默认 T 按键说话，可在 KEYBOARD CONTROLS 修改，避免与观战按键冲突。发送期间 HUD 显示 TEAM MIC • TRANSMITTING；这表示发送流程已开启，不保证设备具有有效输入。双人只有一个队友，关闭收听即可静音队友。未提供设备选择、回声消除、噪声抑制或麦克风电平校准。

验证记录：

- `artifacts/voice-playback.log`：真实 Godot 混音器捕获到合成音频，RMS 约 0.1625；默认关闭、静音后输出静默、超时释放及总线回收通过。
- `artifacts/voice-capture.log`：注入合成设备采样，验证转换/封包、默认不发送、静音输入总线、跨按键周期序号连续、积压丢弃及回合重置；测试没有打开真实麦克风。
- `artifacts/team-voice-ui.log`、`artifacts/team-voice-settings.png`：真实界面中的默认麦克风关闭、单机禁止发送、改键入口、菜单布局和离场清理通过。
- `artifacts/voice-bindings.log`：改键、跨观战冲突、保存失败、暂停期间输入捕获回归通过。
- `artifacts/voice-playback-network.log` 与 `artifacts/voice-relay-network-client-0.log` 至 `-3.log`：四个真实客户端接收各自队友音频，解码与混音输出均通过，同时保留救援和四条组队战绩验证。仍使用合成输入与无物理扬声器的混音驱动。
