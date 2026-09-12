# MelismaKit 验证指南

本文档记录了针对独立软件包的各项验证检查。它刻意将软件包自身的行为与宿主特有的验收项（例如封面色彩分析、全屏视图合成或播放器的音频会话生命周期）解耦开来。

## 可复现的验证检查

在仓库根目录下运行以下命令：

```sh
swift package dump-package
swift build --configuration debug
swift test --configuration debug
swift run --quiet MelismaKitProbe   Sources/MelismaKitDemo/Resources/complex.ttml   /tmp/melismakit-probe 10 760 720 --paused
swift run --quiet MelismaKitBench --scale 120
bash script/build_and_run.sh --build-only
```

软件包测试套件目前包含 150 个 XCTest 用例。它覆盖了 TTML 解码、AMLL 绝对时间轴、显式 W3C 相对时间轴、元数据、歌词翻译、罗马音、Ruby 注音、对唱/伴唱图层、布局排版、有界字形缓存（bounded glyph cache）、时钟语义、窗口缩放重排（resize reflow）、焦点移动、跳转定位（seek）行为、悬停交互行为、入场/退场动画、重音强调、发光（glow）、动态模糊、合成通道、公开的计时与配置契约，以及 39 条解码器对抗性健壮性用例（`DecoderRobustnessTests`）和可复现语料库完整性用例（`SyntheticCorpusTests`）。

异步解码器测试验证了 `decodeAsync(_:)` 与现有同步解码器生成完全一致的 Document 文档对象。`LyricsView.load(ttml:)` 保留了原有的同步路径；`install(document:)` 在解析完成后共享相同的渲染器状态机转换。

`MelismaKitProbe` 使用内置的代码库合成 TTML 测试固件，并报告渲染帧数、渲染耗时分位数以及字形缓存大小。它是一个确定性的冒烟测试与回归测试工具，而非与机器硬件无关的绝对性能断言。

## 测量工具（Phase 0）

`MelismaKitProbe` 与 `MelismaKitBench` 共用同一套测量口径（`MelismaKitBenchCore`：nearest-rank 百分位、丢首帧、120fps）：

- `MelismaKitProbe --scale 120 /tmp/probe 10 760 720`：生成 120 行真实规模文档并渲染（缺省文件时默认即此行为；传文件路径则按文件渲染，8 行内置固件保留作冒烟）。
- `MelismaKitProbe --load-timing`：额外报告 decode / install（布局）/ 首帧三段时间，写入 JSON 的 `loadMilliseconds`。
- `MelismaKitBench --scale 120`：装载 + 10 秒帧耗时分布（p50/p95/p99/max、>8.33ms / >16.67ms 帧数、字形缓存）。
- `MelismaKitBench --mode line|ruby|longWord`：切换文档类型（对应 `Documentation/PERFORMANCE.md` 的对照行）。
- `MelismaKitBench --emit-fixtures` / `--verify-fixtures`：重新生成或校验 `Fixtures/` 语料库与 `SHA256SUMS.txt`（字节一致）。
- 所有测量数字与复现命令见 `Documentation/PERFORMANCE.md`；CI 中的性能阈值护栏由 `script/bench_gate.py` 执行。

## Demo 体验路径

独立的 Demo 包含用于测试逐字计时、逐行计时、发光效果、对唱/Ruby 注音以及伴唱人声的合成固件。它支持：

- 打开外部 TTML 文件；
- 播放/暂停、Seek 跳转、自动跟随、窗口缩放以及原生歌词点击回调；
- 针对排版字号、调色板、动效、多语言图层、表面样式、通道混合以及栅格化/DisplayLink 刷新率质量的配置控制项；
- 通过显式传入 `--library-root` 路径，支持可选的外部曲库目录探测。

曲库扫描器支持包含 `Tracks/<track>/lyrics.ttml` 的根目录、`Tracks` 目录、或直接包含 `lyrics.ttml` 的单一目录。它不会读取任何宿主应用专有的注册表，也不依赖特定的播放器 App Bundle。

## 宿主验收边界

软件包级别的测试套件并不等同于宿主应用已达到完整的视觉对齐。接入该组件的应用应当在其自身工程中额外验证：应用主界面、全屏模式以及紧凑/迷你播放器表面的渲染表现；主题与封面色彩映射；播放器媒体时钟更新；暂停/播放/Seek 状态切换；切歌与曲目替换；窗口重设父容器（reparenting）；视图遮挡以及应用重启恢复行为。这些检查属于宿主集成仓库的验收范畴，且应使用经过签名的真实应用和真实音频播放管线进行测试。
