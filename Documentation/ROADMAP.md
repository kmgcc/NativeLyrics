# 路线图：从「可用的抽取产物」到「优秀的开源组件」

> 本文档是**长期执行计划**，不是设计文档，也不是发布说明。
> 每个阶段都有明确的**验收门**；门不过，不进入下一阶段。
> 文档依据：2026-09-12 第三方独立审计（冻结快照 `717dd28` / tag `0.1.4`）。
> 审计的原始数据、测量方法与结论均由本文第 2 节承接；审计报告本身不随仓库分发。
>
> **项目名已定案：`MelismaKit`（2026-09-12）；Phase 1A 改名已于 2026-09-12 执行完毕。**
> 本文件中的**文件路径、target 名、命令已同步为新名**。仍出现旧名 `NativeLyrics` 的位置只限于历史条目 —— 第 2 节冻结快照基线、1.4 命名决策记录、第 9 节复现审计命令、第 10 节决策记录 —— 那是**当时的名字**，不是笔误。

---

## 0. 如何使用本文档

### 0.1 执行纪律（硬约束）

1. **仓库在每个阶段结束时必须处于可 `build` / `test` / `run` 的状态。** 不允许出现「重构到一半」的中间提交。
2. **先跑通，再加固。** 任何新能力先用最小实现跑起来并实测，再补防御。不要为了「将来可能需要」提前加抽象、协议层、泛型包装。
3. **改任何有性能含义的代码之前，先记录当前数字。** Phase 0 建立的测量工具是后续所有性能改动的唯一裁判。
4. **不改视觉行为的改动与改视觉行为的改动必须分成不同提交。** 后者必须附截图/GIF。
5. **一次只做一件事。** commit 标题描述可观察行为，不提内部代号。
6. **第 10 节的「保护清单」是硬约束**，不是建议。清单里的东西看起来复杂／不优雅，但都是经过实测或测试验证的正确设计。任何想动它们的提案，必须先在 issue 里给出量化证据。
7. **任务 ID 不可复用。** 完成后在本文档把 `[ ]` 改成 `[x]`，保留历史，不要删除行。

### 0.2 状态标记

| 标记 | 含义 |
|---|---|
| `[ ]` | 未开始 |
| `[~]` | 进行中 |
| `[x]` | 已完成（附完成日期与 commit） |
| `[!]` | 阻塞（附阻塞原因与解除条件） |
| `[-]` | 明确不做（附理由与决定日期） |

---

## 1. 定位：什么叫「像 AMLL 一样优秀」

AMLL（Apple Music-like Lyrics）之所以成为一个被广泛使用的项目，不是因为它的渲染代码最漂亮，而是因为它同时具备六件事。本项目的目标就是把同样六件事做齐 —— 用原生 AppKit / Core Text / Core Animation 的路线。

| # | AMLL 具备的 | 本项目的对应目标 |
|---|---|---|
| 1 | **格式话语权**：TTML 规范文档 + 公开歌词库（amll-ttml-db）+ 编辑器工具 | 成为「原生 macOS 上渲染 TTML 歌词」的参考实现；提供 TTML 校验/检视 CLI；建立可复现的 fixture 语料库 |
| 2 | **一个能点开就用的成品**：网页播放器 | 一个可下载的独立 macOS 预览 App（不只是 Demo 控制台） |
| 3 | **文档站**：amll.dev + 指南 | DocC 生成的 API 文档 + 文档站 + 接入指南 + 截图/视频 |
| 4 | **多种集成路径** | AppKit 直用 / SwiftUI 挂载 / 未来 iOS 与 visionOS |
| 5 | **视觉质量本身就是卖点** | 展示画廊；黄金图像回归测试守住视觉不退化 |
| 6 | **贡献者能安全地改** | 快而可信的 CI、黄金图像测试、清晰的所有权边界、good-first-issue |

**不追求的**：不做播放器、不做音乐库、不做歌词抓取、不做账号体系。本项目永远是**组件**。任何把 Track / Media Library / 音频播放 / 主题持久化拉进来的提案都应当被拒绝。

### 1.1 一句话定位（写进 README 首行）

> **MelismaKit — 用原生 AppKit、Core Text 与 Core Animation 渲染逐字同步歌词的 macOS 组件。**

其余卖点（零依赖、MainActor 安全、视口有界图层、可预测媒体时钟）作为副标题。

### 1.2 边界（继承审计结论，不变）

| 归组件 | 归宿主 |
|---|---|
| TTML 解析、时序策略、布局、Core Text、Core Animation、运动、滚动、hover、seek 动画、入场/退场、高亮、模糊、辉光、调色、合成、display link 与播放时钟预测 | Track / Media Library、音频播放、AppSettings、ThemeStore、Window 生命周期、Now Playing、WebView fallback、App 自身状态 |

**判据**：第三方开发者 clone 本仓库后，在完全不知道宿主播放器存在的前提下，必须能 build / test / 跑示例 App / 跑 Probe / 通过 SPM 接入 / 只看文档就完成接入。

### 1.3 目标状态（Target State）架构

```
Host App
  │
  ├─ LyricsView（@MainActor NSView，唯一有状态边界）
  │    ├─ LyricsDocument（纯值模型，Sendable/Codable）
  │    │    ▲
  │    │    └─ LyricDecoder 协议 ← TTMLDecoder /（后续）LRCDecoder / YRCDecoder / ASSDecoder
  │    ├─ LyricsPreset ──► LyricsConfiguration（完整值类型配置）
  │    ├─ TimingPolicy（时序预处理，纯函数）
  │    ├─ LyricsClock / LyricsTimeline / LyricsInteraction（三个独立时间概念）
  │    ├─ TextLayoutEngine（Core Text，带字体与度量缓存）
  │    └─ GroupLayers → LineLayers → WordLayers → GlyphLayers（视口有界物化）
  │
  ├─ SwiftUI 桥（薄 NSViewRepresentable）
  └─ LyricsDiagnostics（仅 Debug：缓存字节、layout 次数、帧耗时）
```

相对现状的**新增**：`LyricDecoder` 协议（格式扩展）、`LyricsPreset`（配置预设）、`LyricsDiagnostics`（把实现指标移出公共契约）、字体缓存。
**不变**：三层时间概念、值模型、视口有界图层物化、宿主持有 view。

### 1.4 命名决策

现状 `NativeLyrics` 是临时工程名：它描述的是「原生歌词」，是**品类名**而不是项目名，无法形成品牌，也无法注册仓库/包名而不与一大堆同类项目混淆。

> **决策状态：已定案 —— `MelismaKit`（2026-09-12）。**
> 它是唯一通过 1.4 节全部 6 项判定清单的候选；其余候选（`MeloLyrics` / `Melisma` 裸名 / `Melodyrics` / `Utagoe` / `Lyricore` / `LUMA` / `SMLK`）的实测数据一并保留在下方，仅作历史记录，不再作为备选。
> **改名已于 2026-09-12 执行**（Phase 1A）：包名、产品、target、目录、类型、脚本与文档均已改用 `MelismaKit`。远端仓库改名状态见 P1-2。
> 一旦执行 Phase 1A，名字**永不再改**：改名成本随发布时间线性上升。

#### 维护者提出的候选（含 2026-09-12 实测）

| 候选 | 展开 | 优点 | 实测风险 |
|---|---|---|---|
| **MelismaKit** ⭐ | Melisma（一字多音）+ Kit | **命名空间完全空白**：GitHub 同名仓库 **0** 个（`melismakit` / `melisma-kit` 均为 0）；npm / PyPI 全空闲；`kmgcc/melismakit` 空闲；**`melismakit.com` / `.dev` / `.app` 全部未注册**。**语义全候选最准**：melisma 指「一个音节跨多个音高」——正是逐字/逐音节卡拉OK高亮在动画化的东西。`-Kit` 后缀是 Swift/Apple 生态的标准惯例（HealthKit / MapKit / StoreKit），**一眼表明这是开发者库而不是音乐 App**，同时补上了裸名 `Melisma` 唯一的短板（非音乐背景的人不知道这个词），也避免了 SMLK 那种「music 一词超出边界」的误导。旁证：`MelismaApp/melisma`（Android，1★）独立地用同一个词命名了「逐字歌词显示」这同一概念 —— 语义契合得到验证，且无竞争威胁 | ① 拼写略生僻，有人会写成 melizma；② 10 字符的模块名略长（`MelismaKitSwiftUI` 17 字符）；③ 未搜到名为 Melisma 的音乐类商业产品，但这只是**未搜到**而非**确认不存在**。缓解：**类型名不加前缀**（`LyricsView` / `LyricsConfiguration` / `TTMLDecoder` 保持原样），`Kit` 只出现在包与 module 上 |
| **LUMA** | Lyrics UI & Motion Architecture | 展开准确；4 字母、好记好念；`import Luma` / `LumaView` 简洁 | **命名空间极拥挤**：GitHub 同名仓库 **12352** 个；npm 与 PyPI 均**已被占用**。高星同名项目横跨媒体与图形软件：`LumaTeam/Luma3DS`（6.7k★）、`visgl/luma.gl`（2.5k★，WebGL 可视化）、`Filoppi/Luma-Framework`（828★，游戏 mod）。同赛道还有 Luma AI、LumaFusion 等商业产品。**搜索不可发现**，且存在同类软件商标撞名风险 |
| **SMLK** | Swift music Lyrics Kit | 命名空间**几乎全空**：GitHub 同名仅 **31** 个且头部全是 0–1★ 的无关仓库；npm / PyPI 全空闲 | ① 纯首字母缩写难念、难记、搜索引擎基本不索引，品牌价值弱（对照：AMLL 至少可读作一个词）；② 「music Lyrics Kit」中的 *music* **超出了项目边界** —— 1.2 节明确规定本项目不做音乐库/播放器，只做歌词渲染，这个名字会误导采用者 |
| **MeloLyrics** | Melo（旋律）+ Lyrics | **字符串命名空间第一梯队**：GitHub 同名仅 **3** 个（全部 0★ 且是无关 JS 项目）；npm / PyPI 全空闲；`kmgcc/melolyrics` 空闲；`melolyrics.dev` / `.app` 未解析。**可读性全候选最高**（自解释、任何语言都能念、符合 Swift 生态描述性命名惯例）；模块名链条自然：`MeloLyrics` / `MeloLyricsView` / `MeloLyricsSwiftUI`；`Melo` 前缀可延展出 `MeloLyricsKit` / `MeloLyricsTTML` | **同赛道品牌撞名最重**（与 LUMA 的「数量拥挤」不同，这里是「全在音乐 App 赛道」）：`melomusic.app`（Melo – The Future of Music）、App Store「Melo – AI Song Generator」(id6742782430，**Music 分类且兼容 macOS**)、`melo-app.com`（Mélo 音乐探索）、App Store「Melo: AI Music, Song generator」、`51melo.com` + App Store「MELO音乐」、`InsMelo`、以及 **7636★** 的 `myshell-ai/MeloTTS`。后果：① 搜 “Melo lyrics” 会先撞到一堆 AI 写歌 App，可发现性打折；② **路线图 P6-4 的「可下载预览 App」会直接踩进 Music 分类**，而那个位置已站着至少两个 Melo。另：`melolyrics.com` 已被注册（实测仅 114 字节、无 title/description → 纯占位，无实际产品），`.com` 拿不到 |

#### 此前调研的候选（实测可用性）

| 候选 | 含义 | GitHub 同名仓库数 | npm | PyPI | `kmgcc/<名>` |
|---|---|---|---|---|---|
| **Melodyrics** | melody + lyrics | **0** | 空闲 | 空闲 | 空闲 |
| Lyricore | lyric + core | **2** | — | — | 空闲 |
| Utagoe 歌声 | 「歌声」——组件把歌声渲染成文字 | **13** | 空闲 | 空闲 | 空闲 |
| Portamento | 音高滑移 —— 对应焦点滚动滑行 | 19 | — | — | 空闲 |
| Melisma | 一个音节跨多个音高的唱法 —— 对应「逐字卡拉OK高亮」 | 27 | 空闲 | 空闲 | 空闲 |
| Rubato | 弹性速度 —— 对应内部可预测媒体时钟 | 238 | 占用 | 占用 | 空闲 |
| Kotodama 言霊 | 「言灵」 | 157 | 占用 | 占用 | 空闲 |
| ~~Kashi~~ 歌詞 | 「歌词」——语义最直接 | 8162 | 占用 | 空闲 | 空闲 |
| ~~Kanade~~ | 「奏」 | 1352 | 占用 | 占用 | 空闲 |
| ~~Hibiki~~ | 「响」 | 1039 | 占用 | 占用 | 空闲 |
| ~~Nagare~~ | 「流」 | 488 | 占用 | 占用 | 空闲 |

排除理由：`Kashi` 命名空间最拥挤（8162），搜索不可发现；`Kanade` / `Hibiki` / `Nagare` 同样拥挤且 npm/PyPI 已被占用。
`Melodyrics` 完全避开 “Melo” 品牌拥挤且命名空间为 0，但拼写略绕（听写易漏字母），是可读性方案的备选。

#### 综合对比（截至 2026-09-12）

| 名字 | 全串同名仓库 | npm+PyPI | 可读性/可发现性 | 语义准确度 | 同赛道品牌撞名 | 判定清单 6 项 |
|---|---|---|---|---|---|---|
| **MelismaKit** ⭐ | **0** | 空闲 | 高（`-Kit` 表明是开发者库，无需知道 melisma 的含义） | **最高**（一字多音＝逐字高亮） | **极轻**（未搜到音乐类产品） | **6/6 通过** |
| **MeloLyrics** | 3 | 空闲 | **最高（完全自解释）** | 中（旋律 vs 文字） | **重**（多个音乐 App + MeloTTS 7.6k★） | 5/6（品牌撞名） |
| **Melisma**（裸名） | 27 | 空闲 | 中（需知音乐术语） | **最高** | 极轻 | 5/6（可发现性） |
| Melodyrics | **0** | 空闲 | 高（但拼写绕） | 中 | 极轻 | 5/6（可读性） |
| Utagoe | 13 | 空闲 | 中（需知是日语） | 高（歌声） | 极轻 | 5/6（可发现性） |
| Lyricore | 2 | — | 高 | 中 | 轻 | 5/6 |
| LUMA | 12352 | 占用 | 高 | 中（缩写） | 重（媒体/图形软件） | 3/6 |
| SMLK | 31 | 空闲 | 低（难念、难搜） | 中 | 极轻 | 4/6（可读性 + 边界误导） |

**读法**：`MelismaKit` 是**唯一 6 项判定清单全部通过的候选** —— 命名空间为 0（含全部相关域名）、语义最准、无同赛道品牌撞名，而 `-Kit` 后缀正好补上了裸名 `Melisma` 唯一的短板。`MeloLyrics` 在「完全自解释」上仍是最强，但代价是 “Melo” 在音乐 App 赛道的拥挤，会直接影响 P6-4。

**仓库名**：`melismakit`（连写小写，同名 0）。

**命名映射（已定案，Phase 1A 按此执行）**

| 项 | 值 |
|---|---|
| GitHub 仓库 | `kmgcc/melismakit` |
| 包名 / 产品 | `MelismaKit`、`MelismaKitSwiftUI` |
| 可执行 | `MelismaKitDemo`、`MelismaKitProbe` |
| module | `import MelismaKit` |
| 类型名 | **不加前缀**：`LyricsView` / `LyricsConfiguration` / `TTMLDecoder` / `LyricsDocument` 保持原样（`Kit` 只出现在包与 module 上，避免 `MelismaKitViewRepresentable` 这类冗长名） |
| 副标题 | 「用原生 AppKit、Core Text 与 Core Animation 渲染逐字同步歌词的 macOS 组件」 |
| 领域 / 文档站 | `melismakit.dev` 或 `melismakit.app`（均未注册） |


#### 评估建议（历史记录 — 名字已于 2026-09-12 定案为 `MelismaKit`）

- **`MelismaKit` 是当前首选**（2026-09-12 维护者提出并完成实测）。仓库 `melismakit`、module `MelismaKit`、产品 `MelismaKit` / `MelismaKitSwiftUI` / `MelismaKitDemo` / `MelismaKitProbe`。它是唯一通过全部 6 项判定清单的候选，且 `-Kit` 后缀同时解决了三个问题：① 表明这是开发者库而非音乐 App；② 与 1.2 节的「永远是组件」边界自洽；③ 让非音乐背景的开发者不必知道 melisma 的含义也能判断用途。P6-4 的预览 App 也不再有品牌冲突。
- **MeloLyrics 是「完全自解释」维度上最强的一个，但品牌撞名重。** 若选它：仓库 `melolyrics`、module `MeloLyrics`、产品 `MeloLyrics` / `MeloLyricsSwiftUI` / `MeloLyricsDemo` / `MeloLyricsProbe`。**前提是接受 “Melo” 在音乐 App 赛道的拥挤**；因此把 P6-4（可下载预览 App）改为「不品牌化，仅作 `<Name> Preview` 示例包」，或届时重新评估。
- **LUMA 的展开很好，但裸名不可用。** 若保留 LUMA 这个品牌，走**复合标识**可以拿到干净命名空间：仓库 `luma-lyrics`、包 `LumaLyrics`、Swift module `LumaLyrics`（实测 GitHub 同名仓库仅 **1** 个，npm/PyPI 全空闲）。代价是失去 4 字母的简洁。
- **SMLK 唯一的问题是「好不好被找到」。** 若坚持 SMLK，建议对外呈现为 `SMLK` + 明确副标题，并优先抢注 Swift Package Index 词条；同时把展开里的 *music* 去掉（例如 *Swift Lyrics Kit* / *Swift Motion Lyrics Kit*），以免与项目边界冲突。
- 若两者都要，`Utagoe` / `Melisma` 的实测命名空间质量目前最好（13 / 27，包管理器全空闲）。

**判定清单**（名字定了之后逐条过）：

1. GitHub `kmgcc/<名>` 是否空闲（已实测候选）
2. npm / PyPI 是否空闲（防止同生态撞名）
3. Swift Package Index 可否索引；`import <Name>` 是否与已知 Swift 包冲突
4. 是否与同赛道商业产品撞名（媒体/图形/AI 软件类商标）
5. 作为 Swift module 是否合法：无空格、非关键字、CamelCase 可读
6. 副标题能否一句话说清「原生 macOS 逐字同步歌词渲染组件」

### 1.5 命名已定案，各阶段不受阻

名字已于 2026-09-12 定案为 `MelismaKit`，因此**没有任何阶段再被命名阻塞**。推荐顺序与依赖关系：

| Phase | 依赖命名 | 说明 |
|---|---|---|
| **1A 改名** | — | **推荐第一个执行**。零行为风险；先改名可让 Phase 0 的产物一出生就带正确名字 |
| Phase 0 | 否 | 基线与测量基础设施，不碰包名与产品名。若在 1A 之前做，产物需随 1A 改名一遍 |
| 1B provenance | 否 | 纯文档与注释 |
| Phase 2 | 否 | 装载阻塞是纯实现问题 —— 想先解决「每次切歌冻结 UI 一秒」，可直接从 2-1 开始 |
| Phase 3 | 1A/1B | API 语义重命名（P3-1..P3-5）本身不依赖项目名；DocC/README 措辞依赖 1A |

**三条可并行的起步路径**（择一即可）：

- **稳**：`1A 改名 → Phase 0 → 1B → Phase 2`（推荐）
- **先修痛点**：`Phase 2 的 P2-1..P2-4（字体缓存，零视觉变化）` 可与任何步骤并行
- **先清 BLOCKER**：`1B provenance` 独立可做，做完即清掉审计唯一的 BLOCKER

---

## 2. 现状基线（所有后续改动的对照物）

冻结快照 `717dd28`（tag `0.1.4`，**当时的包名是 `NativeLyrics`**）。环境：macOS 26.6.2 / arm64、Xcode 26.6、Swift 6.3.3。
**数字均为 Release 构建实测。**

### 2.1 健康项（已通过，后续不得回退）

| 项 | 实测 |
|---|---|
| Debug / Release 构建 | 通过，**零警告** |
| `swift test` | 99 用例全绿，0.8 秒 |
| 第三方依赖 | **零** |
| `swift package dump-package` | 通过 |
| 外部消费者 `.package(url:from: "0.1.4")` | 解析到 `717dd28` 成功 |
| Swift 6 language mode 消费者编译 README 示例 | 通过 |
| Swift 5 消费者越界调用 MainActor | **编译期 error**（不是 warning） |
| `LyricsView` 释放 | `autoreleasepool` 排空后干净出栈，无保留环 |
| 文档替换后的图层 | 3 → 5 → 2 → 3，无累积泄漏 |
| 图层占用 vs 文档长度 | 120 行 = 564 个 CALayer；400 行 = 1684 个 —— **按视口有界** |
| glyph 缓存 | 12 轮 load/render churn 后 485 KB / 4 MB 预算，未越界 |
| 空文档（`<body><div/>`） | 不崩溃 |
| 仓库卫生 | 无 TODO/FIXME、无密钥、无宿主字符串、无 `/Users/`、无 agent 残留 |

### 2.2 待解决项（数字即验收阈值）

**A. 装载阻塞（最严重）**

| 文档 | 行数 | decode | `load()` 总计 | 布局占比 |
|---|---|---|---|---|
| 合成 | 120 | 17.5–26.1 ms | **520.6 / 695.0 / 926.5 ms** | 96–97% |
| 合成 | 400 | 74.7–151.0 ms | **881.1 / 1409.3 / 1640.6 ms** | 95% |
| ruby | 120 | 20.0 ms | **561.8 ms** | 96% |
| line-timed | 120 | 13.0 ms | **267.2 ms** | 95% |
| 长词压力 | 120 | 15.3 ms | **1412.5 ms** | 99% |

`decodeAsync` 只覆盖 decode 部分（1–17%）。根因指向 `TextLayout.swift` 的 `font()` 每次调用 `NSFontManager.shared.availableMembers(ofFontFamily:)` 且**无字体缓存**。

**B. 稳态帧（现状尚可，是回退护栏）**

| 文档 | p50 | p95 | p99 | max | >8.33ms | >16.67ms |
|---|---|---|---|---|---|---|
| bundled complex（8 行，Probe 默认） | 0.244 | 1.195 | 3.173 | 9.14 | 1/1200 | 0 |
| 120 行 | 0.465 | 1.468 | 3.783 | 8.16 | 0/1200 | 0 |
| 400 行 | 0.707 | 1.987 | 3.425 | 20.20 | 3/1200 | 1 |
| 120 行 line-timed | 0.136 | 1.166 | 4.183 | 11.35 | 4/1200 | 0 |
| 120 行长词压力 | 5.080 | 18.393 | 65.159 | 484.6 | 257/1200 | 70/1200 |

每 glyph layer 每帧约 10 µs，只发生在**正在动画的那一行**（`LayerRenderer` 的 `inkKey` 每帧都变 → 每 glyph 重建 9 个 `CGColor`）。

**C. 测量盲区**：`LyricsProbe` 默认 fixture 只有 **8 行**；只报 p95；`load()` 发生在 trace 起点之前，**完全测不到**。

**D. provenance**：`Documentation/LICENSING.md` 称实现「reproduce the observable contracts of AMLL」，但 `Motion.swift` 的 `interludeSample` 与 AMLL `lyric-player/dom/interlude-dots.ts` **逐行对应**（同一常量积 `1.70158*1.525`、同一变量名 `c2`、同一 `0.25/0.75` walk、同一 `1.5π` sine、同一 `2^-10x`、同一 `500/1000/750/375/2000` 阈值）。仓库内**无 AMLL 版权声明**。AGPL-3.0-only 与上游兼容，但缺 §5 要求的署名与修改声明。Pushkine 为 MIT（`MotionTests` 已正确标注出处，是全仓 provenance 最规范的一处）。

---

## 3. 阶段总览

### 3.1 推荐执行顺序

名字已于 2026-09-12 定案为 `MelismaKit`，因此**推荐把改名的 1A 提到最前面执行**，而不是留到原 Phase 1 的位置。理由：

- Phase 0 会**新建** target、脚本目录、CI job、基线文档 —— 这些如果先按原名建，P1-5 就得把它们再改一遍，纯属重复劳动；
- 1A 改名是**零行为风险**的机械操作（重命名 + 更新引用），越早做越便宜；
- 1A 完成后，Phase 0 产出的所有工件天然带上正确的名字，后续每个 Phase 都不必再考虑命名。

```
1A 改名 ──► Phase 0 基线与可复现性 ──► 1B provenance ──► Phase 2 ──► 3 ──► 4 ──► 5 ──► 6 ──► 7
（零风险）    （零产品代码改动）        （零风险）        （性能）
```

若不想先动仓库名，按原顺序（Phase 0 → 1A → 1B → …）也完全可行，代价只是 Phase 0 的产物要跟着改名走一遍。

### 3.2 阶段清单

| Phase | 目标 | 预估 | 行为风险 | 前置 |
|---|---|---|---|---|
| **1A** | **改名 → MelismaKit**（零行为风险，推荐先做） | 1–2 天 | 无 | — |
| 0 | 基线与可复现性 | 1–2 天 | 无 | 1A（或与 1A 独立） |
| 1B | Provenance 与合规 | 1–2 天 | 无 | — |
| 2 | 消灭装载阻塞 | 3–5 天 | **可能**（分批布局） | Phase 0 |
| 3 | 公共 API 定型 | 5–8 天 | 无（重命名/preset） | 1A、1B |
| 4 | 质量基础设施 | 1–2 周 | 无 | Phase 3 |
| 5 | 性能、稳健、可访问性 | 1–2 周 | **可能**（RTL/量化） | Phase 4 |
| 6 | 生态（「像 AMLL」的主体） | 2–4 周 | 无 | Phase 5 |
| 7 | 社区与 1.0 | 持续 | 无 | Phase 6 |

---

## Phase 1A — 改名 → MelismaKit 🔨 建议第一个执行

> **为什么排第一**：Phase 0 会新建 target、脚本目录、CI job 与基线文档；先改名，这些工件一出生就是正确的名字，避免二次改名。1A 是**零行为风险**的机械操作 —— 只改名字与引用，不动任何逻辑。
> **前置**：无。名字已于 2026-09-12 定案（见 1.4）。

| ID | 任务 | 细节 |
|---|---|---|
| `[x]` P1-1 | 确定名字 | **`MelismaKit`**（2026-09-12 定案，6/6 通过判定清单）。映射表见 1.4 | 
| `[x]` P1-2 | 重命名 GitHub 仓库 | 2026-09-12 完成（`gh repo rename melismakit`）。旧 URL redirect 有效：`git ls-remote https://github.com/kmgcc/NativeLyrics.git HEAD` 正常返回，`gh repo view kmgcc/NativeLyrics` 解析到 `kmgcc/melismakit`。本地已 `git remote set-url origin https://github.com/kmgcc/melismakit.git`。**tag 与历史未动**（`0.1.0`–`0.1.4` 原样保留在远端）。附带补上了仓库描述与 10 个 topics |
| `[x]` P1-3 | 重命名包与产品 | 2026-09-12 完成。`Package.swift` 全部改名；目录 `git mv` 保留历史（`Sources/NativeLyrics/`→`Sources/MelismaKit/`、`Sources/NativeLyricsSwiftUI/`→`Sources/MelismaKitSwiftUI/`、`Sources/NativeLyricsDemo/`→`Sources/MelismaKitDemo/`、`Sources/LyricsProbe/`→`Sources/MelismaKitProbe/`、`Tests/NativeLyricsTests/`→`Tests/MelismaKitTests/`） |
| `[x]` P1-4 | 重命名 Swift 类型与文件 | 2026-09-12 完成。实际改名**只有一处**：`NativeLyricsViewRepresentable` → `MelismaKitViewRepresentable`（文件同步改名）。**保持原名的**：`LyricsView`、`LyricsConfiguration`、`LyricsDocument`、`LyricWord`、`TextLayoutEngine`、`TTMLDecoder`、`LyricsClock`、`LyricsTimeline`、`TimingPolicy` 等全部「歌词领域概念」类型 —— `Kit` 只出现在包与 module 上 |
| `[x]` P1-5 | 更新所有引用 | 2026-09-12 完成。README、`Documentation/INTEGRATION.md`、`Documentation/LICENSING.md`、本文件、`VALIDATION.md`、`BEHAVIOR-REGRESSIONS.md`、Demo bundle id（`org.example.MelismaKitDemo`）、`script/Info.plist`、`script/build_and_run.sh`（含 `MelismaKit Demo.app`）、`.codex/environments/environment.toml` 全部改名。`.github/workflows/macos-ci.yml` 经检查**不含任何旧名**，无需改动。`script/Info.plist` 的 `CFBundleShortVersionString` 同步 `0.1`→`0.2`（改名是 breaking change，属 0.2 线） |
| `[x]` P1-6 | tag 策略 | 2026-09-12 策略确认：旧 tag `0.1.x` 保留（**历史不可重写**）。新名从 `0.2.0` 起，用 **annotated** tag `v0.2.0`。注意 `0.1.4` 是 lightweight 而 `0.1.0`–`0.1.3` 是 annotated —— 新线一律 annotated。tag 本体在 P1-8 随发布创建 |
| `[x]` P1-7 | 全仓旧名清零检查 | 2026-09-12 通过。`rg -i "nativelyrics\|native[ _-]lyrics"` 在**已跟踪文件**中只剩本文件的历史条目（第 2/9/10 节与 P1-2 任务描述本身）；其余全仓为零。`.codex/environments/environment.toml` **有意不改**：它被 gitignore，且其 `name` 字段跟随**本地检出目录名**，而目录名不在 1A 范围内（见执行记录） |
| `[x]` P1-8 | 外部消费者验证 | 2026-09-12 完成。仓库外新建消费者（`swift-tools-version: 6.1` → Swift 6 language mode），写 `.package(url: "https://github.com/kmgcc/melismakit.git", from: "0.2.0")` → 解析到 **`0.2.0` / revision `5665da5`**；`.product(name: "MelismaKit", package: "MelismaKit")` 与 `MelismaKitSwiftUI` 均链接成功；README 与 INTEGRATION 的全部示例代码编译通过、**零警告**、可运行。annotated tag `v0.2.0` 已推送。<br>**注意一个易错点**：URL 推导出的 package identity 是小写 `melismakit`，而 `.product(package:)` 里写的是 `MelismaKit` —— SwiftPM 对 identity 做大小写不敏感匹配，实测可用；README 的写法不用改 |

**1A 执行记录（2026-09-12）**

| 检查项 | 结果 |
|---|---|
| 目录改名方式 | 全部 `git mv`，git 识别为 `R`（重命名），**无「删除 + 新增」**，历史完整 |
| 类型改名范围 | 仅 `NativeLyricsViewRepresentable` → `MelismaKitViewRepresentable` 一处；其余歌词领域类型名全部保持不变 |
| `swift package dump-package` | 通过 |
| `swift build`（Debug） | 通过，**零警告** |
| `swift build -c release` | 通过，**零警告** |
| `swift test` | **99 用例全绿**，1.46 s |
| Probe | `MelismaKitProbe … --paused` → 361 帧，`renderP95Milliseconds` **1.33 ms**（冻结基线 1.195 ms，同量级，无回退） |
| Demo 无头路径 | `--dump-import` 输出 `title=MelismaKit — motion laboratory`；`--dump-catalog` 正常 |
| Demo App 包 | `script/build_and_run.sh --build-only` → `dist/MelismaKit Demo.app`，`codesign --verify --deep --strict` 通过 |
| Demo 启动 | `--verify` 启动成功、存活 2 s 无崩溃、正常退出 |
| 远端改名（P1-2） | 完成。`kmgcc/NativeLyrics` → `kmgcc/melismakit`；旧 URL redirect 实测有效；`0.1.x` tag 与历史未动 |
| 外部消费者（P1-8） | 完成。`from: "0.2.0"` → revision `5665da5`；README/INTEGRATION 全部示例在 Swift 6 mode 下零警告编译并运行 |
| 全新 clone 复验 | 完成。`git clone` 到仓库外 → `dump-package` / Debug / Release（均零警告）/ `swift test` 99 全绿 / Probe / Demo 无头路径全部正常 |
| 本地检出目录 | **仍叫 `NativeLyrics/`** —— 不在 git 管辖内，也不在 1A 任务范围内。改名会打断正在使用该路径的编辑器与工具，建议由维护者在确认无进程占用后手动 `mv`，并同步 `.codex/environments/environment.toml` 的 `name` 字段 |

**Gate 1A**：`git grep` 旧名仅剩历史记录；全新 clone 后 `swift build`（Debug + Release，零警告）/ `swift test` / 跑 Demo / 跑 Probe 全部正常；外部消费者能从新 URL 解析 `v0.2.0`；GitHub 旧仓名 redirect 生效。

---

## Phase 0 — 基线与可复现性

> **为什么必须早做**：审计发现的三个关键数字（装载 0.9 s、p99、Probe 盲区）目前只存在于一次性审计里。没有它们，Phase 2 和 Phase 5 无法验收，也无法防止回退。
> 这一阶段**不改任何产品代码**。
> **执行时机**：推荐在 1A 改名之后（见 3.1）；与 1A 独立，也可先做，代价是产出物要跟着改名走一遍。

| ID | 任务 | 产出 | 验收 |
|---|---|---|---|
| `[ ]` P0-1 | 把审计测量工程移植进仓库 | `Tests/MelismaKitBench/`（或 `script/bench/`）：① 规模 fixture 生成器（120/400 行、word/line 定时、ruby、长词压力、翻译）② 帧耗时分布统计（p50/p95/p99/max + 超预算帧数）③ 装载计时（decode / install / 首次渲染分离） | `swift run MelismaKitBench --scale 120` 输出与 2.2 节同量级的数字 |
| `[ ]` P0-2 | 把 35 个对抗性解码用例转成 XCTest | `Tests/.../DecoderRobustnessTests.swift`：空/非 XML/错 root/缺 body/未闭合/错命名空间/NUL/零时长/乱序/重叠/重复 id/空 p/嵌套 x-bg/CDATA/subFrameRate/tick/emoji/ZWJ/RTL/组合字符/超长行/DOCTYPE 四种/实体引用/无界行/空白行 | 全绿；每条用例明确断言「抛错」或「成功 + 预期结构」 |
| `[ ]` P0-3 | 建立可复现 fixture 语料库 | `Fixtures/`（**合成**、可再生成、带 SHA256 清单）：覆盖 word/line 定时、duet、ruby、翻译、romanization、背景声部、interlude、长词、CJK/emoji/RTL/组合字符 | 生成器可重跑且字节一致；清单入仓 |
| `[ ]` P0-4 | 扩展 `MelismaKitProbe` | 增加 `--load-timing`（报告 decode / install / 首帧）、`p50 / p99 / max`、`--scale` 多档；默认 fixture 换成真实规模（保留 8 行作冒烟） | 输出的 JSON 含 `loadMilliseconds` 与完整分布；`VALIDATION.md` 同步更新 |
| `[ ]` P0-5 | CI 第一步加固 | 增加：Release 构建、`swift run MelismaKitProbe` 冒烟、`-Xswiftc -warnings-as-errors` | 三项红灯即失败；当前零警告下应全绿 |
| `[ ]` P0-6 | 基线快照文档 | `Documentation/PERFORMANCE.md`：记录 2.2 节全部数字 + 复现命令 + 硬件信息 | 新机器上按文档能复现同量级结果 |
| `[ ]` P0-7 | 把 2.2 节数字写进 CI 作为阈值护栏 | 帧耗时 / 装载耗时断言（宽松阈值，防大幅回退） | 故意把 `reflowBatchLimit` 改成 1 会让 CI 红 |

**Gate 0**：`swift test` 全绿（含新增用例）；Probe 能同时报告装载时间与 p50/p99/max；CI 含 Release + Probe + warnings-as-errors 三项；性能基线文档可复现。

---

## Phase 1B — Provenance 与合规

> **为什么重要**：这是审计判定为 **BLOCKER** 的一项 —— `Documentation/LICENSING.md` 声称实现「reproduce the observable contracts of AMLL」，但代码证据显示部分函数是逐行翻译且缺 AMLL 署名。
> **前置**：无。**修复风险为零**（纯文档与注释）。**达成 Gate 1B 即清掉审计唯一的 BLOCKER。**

| ID | 任务 | 细节 |
|---|---|---|
| `[ ]` P1-9 | 逐文件比对 AMLL，产出派生清单 | 对 `Motion.swift`、`TimingPolicy.swift`、`TextLayout.swift`、`LayerRenderer.swift`、`Timeline.swift`、`TTMLDecoder.swift` 逐一比对 AMLL `packages/core/src/**`。产出表格：文件 → 函数 → 派生/独立 → 上游文件与行。**无法判定的一律写「无法确定」，不许猜** |
| `[ ]` P1-10 | 修正 `Documentation/LICENSING.md` | 把「reproduce the observable contracts」改为准确表述；新增「上游署名」节：AMLL 仓库 URL、`AGPL-3.0-only`、涉及模块、访问日期、Pushkine MIT（保留现有正确做法作为模板） |
| `[ ]` P1-11 | 增加 `NOTICE` | 列出本项目版权 + AMLL 版权 + Pushkine MIT 全文/引用 |
| `[ ]` P1-12 | 派生文件头注释 | 对 P1-9 判定为派生的文件，在文件头加一行「Portions derived from AMLL (<URL>), AGPL-3.0-only. Modified for native AppKit.」 |
| `[ ]` P1-13 | 第三方资产政策 | 已有（`LICENSING.md` 末尾），补一条 fixture 提交模板（要求记录来源与 license） |
| `[ ]` P1-14 | README 加截图/GIF | 至少 1 张主视觉 + 3 张特性图（逐字高亮、ruby、interlude dots）；存 `Documentation/images/` |
| `[ ]` P1-15 | README 加「与 AMLL 的关系」一段 | 明说：AMLL 是 Web 实现，本项目是原生实现；部分算法派生自 AMLL 并在 NOTICE 中署名；格式兼容，不是 AMLL 的官方 Swift 移植 |

**Gate 1B**：P1-9 的派生清单覆盖全部 8 个源文件；`NOTICE` 与 `LICENSING.md` 经维护者逐条确认与清单一致；派生文件头有派生声明；README 有「与 AMLL 的关系」段与至少 1 张截图。

---

## Phase 2 — 消灭装载阻塞

> **这是当前最严重的功能缺陷**：真实播放器每次切歌冻结 UI 0.27–1.64 秒。

| ID | 任务 | 说明 | 风险 |
|---|---|---|---|
| `[ ]` P2-1 | 加字体解析缓存 | `TextLayout.swift` 的 `font()` 每次调 `NSFontManager.shared.availableMembers(ofFontFamily:)`；`fontRuns` 对每个 atom 的每个 run 都调一次。加 `[FontKey: CTFont]` 缓存（key 需覆盖 family / size / weight / script / italic） | **低，视觉无变化** |
| `[ ]` P2-2 | 消除逐字符字体解析 | `TextLayout.swift` 超长词分支对每个字符调 `font()`；改为按 run 解析一次后复用 | 低 |
| `[ ]` P2-3 | 度量结果缓存 | `measuredWidth` 与 `baseRuns` 对同一文本重复整形；同 key 复用 | 低 |
| `[ ]` P2-4 | 复测 | 目标：120 行 `load()` < 150 ms，400 行 < 400 ms（Phase 0 基线的 15–25%） | — |
| `[ ]` P2-5 | 首次装载走分批 reflow | 现有 `beginIncrementalReflow` / `processIncrementalReflow` 已实现分批（每帧 ≤4 组、4 ms 预算），但首次装载走的是同步 `reflowAll`。改造之 | **中**：首帧完整性、入场动画起点、`onFrame` 消费者都可能受影响 |
| `[ ]` P2-6 | 首帧语义显式化 | 分批装载期间「哪些行可用」必须有明确契约（`LyricsFrame` 里标明 incomplete 或保证可见区先完成） | 中 |
| `[ ]` P2-7 | `decodeAsync` 可取消 | `Task.detached{}.value` 不响应取消（实测 2 ms 后 cancel，97 ms 后仍成功返回）。改为检查取消 + 继承优先级 | 低 |
| `[ ]` P2-8 | 装载回归测试 | 断言 120 行 `load()` 在阈值内；断言分批装载不会让可见行长时间空窗 | — |

**决策点**：若 P2-1..P2-3 已把 120 行降到 < 150 ms，**P2-5/P2-6 可以先不做**。宁可保留「同步但够快」的简单路径，也不要为了架构纯洁引入首帧不完整的复杂度。

**Phase 2 验收门**：`Documentation/PERFORMANCE.md` 更新，120 行 `load()` < 150 ms、400 行 < 400 ms；Phase 0 的帧耗时护栏未回退；视觉由截图对比确认无变化（若做了 P2-5，需附分批期间的录屏）。

---

## Phase 3 — 公共 API 定型

> **本期是唯一低成本的窗口**：现在还没有外部用户，重命名是免费的；0.2.0 之后再改就是 breaking change。
> 判据：把自己当作第一次使用本库的第三方 macOS 开发者。

### 3A. 去掉宿主词汇

| ID | 现状 | 目标 |
|---|---|---|
| `[ ]` P3-1 | `LyricsProfile.currentPlayer` / `.upstream` | `.nativeDefault` / `.upstreamReference` |
| `[ ]` P3-2 | `LyricsSurfaceStyle.artisticFullscreen` / `.appleStyle` / `.coreReference` | `.opaqueFullscreen` / `.highContrastFullscreen` / `.reference` |
| `[ ]` P3-3 | `fullscreenAppleStyleMode`、`fullscreenLyricDodgeMode`、`coverBlurGenericMode`、`coverBlurHideActiveMainLine`、`coverBlurSuppressEmphasisGlow` | 收进 `LyricsPreset`，不再单独公开 |
| `[ ]` P3-4 | `LyricsCoverBlurProfile`、`LyricsRenderLayer`、`LyricsChannelBlendConfiguration` | 收进 preset；保留为 advanced 类型但不再是顶层必读概念 |
| `[ ]` P3-5 | 注释里的宿主语义（`Timeline.swift` 的「player publishes at 4–10 Hz」、`TimingPolicy.swift` 的「legacy adapter」、`Document.swift` 的「host ThemeStore adapter」「the adapter's blendOpacity」） | 改写为中性表述（描述宿主时钟特性，不描述某个 App） |

### 3B. 引入 preset

| ID | 任务 |
|---|---|
| `[ ]` P3-6 | 新增 `LyricsPreset`：`.window` / `.fullscreen` / `.coverBlurLight` / `.coverBlurDark` / `.reference`，每个返回预填好的 `LyricsConfiguration` |
| `[ ]` P3-7 | 把 Demo `main.swift` 里手写的 10 行 coverBlurDark palette 逻辑搬进 preset（这是「第三方被迫自己发明配置」的直接证据） |
| `[ ]` P3-8 | `LyricsConfiguration` 保持为完整值类型配置（**不拆**），但公开文档只推荐先选 preset |

### 3C. 收缩公共面

| ID | 任务 | 理由 |
|---|---|---|
| `[ ]` P3-9 | 移除 `EmphasisSample`、`InterludeSample` 的 `public` | 在公共 API 中无任何入口（实测引用数 0/1，全在库内） |
| `[ ]` P3-10 | `LyricsClock` 移出 public，或为 `LyricsView` 提供 `currentMediaTime` 访问器 | 现在能构造但无法观测 |
| `[ ]` P3-11 | `LyricsFrame` 的实现指标（`glyphCacheBytes`/`glyphCacheMisses`/`layoutCount`/`renderMilliseconds`）移入 `LyricsDiagnostics`（仅 Debug 或需显式开启） | 实现指标不应进公共契约 |
| `[ ]` P3-12 | `diagnosticTimings` 改名/收进诊断类型 | 名字含 "diagnostic" 却是 public 常驻 API |
| `[ ]` P3-13 | `LyricsError` 细分：`.notTTML` / `.malformedXML` / `.invalidTiming` / `.emptyDocument` / `.unsupportedFeature` | 宿主现在无法区分「文件不是 TTML」和「XML 坏了」，无法给用户不同提示 |
| `[ ]` P3-14 | 收回 `public override`：`hitTest` / `menu(for:)` / `mouseDown` / `mouseUp` / `mouseMoved` / `mouseEntered` / `mouseExited` / `scrollWheel` | override 父类实现不需要 public |
| `[ ]` P3-15 | 上下文菜单「Copy lyrics」改为可配置（本地化字符串 + 开关） | 硬编码英文无法本地化 |

### 3D. 可发现性

| ID | 任务 |
|---|---|
| `[ ]` P3-16 | 每个 public symbol 补 DocC 注释（含 `- Parameter`、最简单示例、时间单位说明） |
| `[ ]` P3-17 | 明确文档化：所有时间单位为**秒**、媒体域、源时间不被改写 |
| `[ ]` P3-18 | 明确文档化：`onSeek` / `onFrame` **恒在主 actor 回调**，不得阻塞 |
| `[ ]` P3-19 | 明确文档化：组件会设置宿主窗口的 `acceptsMouseMovedEvents`（或改为不修改 + 文档说明需要宿主开启） |
| `[ ]` P3-20 | 明确文档化：RTL/bidi 不支持（见 Phase 5）；空文档是合法输入 |
| `[ ]` P3-21 | 写出「最小接入」示例到 README 顶部（当前已不错，保持） |
| `[ ]` P3-22 | SwiftUI 桥的 `.id` / 生命周期约束写进文档与 `init` 断言（现在 `updateNSView` 为空，宿主每次 `body` 新建 view 会被静默丢弃） |

**Phase 3 验收门**：公共 API diff 经逐条评审；`LyricsConfiguration` 顶层必读概念从 46 个降到「preset + 约 15 个常用字段」；DocC 能构建且无未文档化 public symbol；Demo 基于 preset 重写且控件数减少；旧名/宿主词汇全仓清零。

---

## Phase 4 — 质量基础设施

> 目标：**让一个陌生贡献者能安全地改渲染代码。** 这是从「个人项目」变成「开源项目」的分水岭。

| ID | 任务 | 说明 | 验收 |
|---|---|---|---|
| `[ ]` P4-1 | 黄金图像回归测试 | 用 `snapshotImage()` + 确定性 `render(at:)` 生成 PNG，与入仓的 golden 比对（允许极小容差）。覆盖：逐字高亮中段、line-timed、ruby、翻译、duet、背景声部、interlude 入场/呼吸/退场、blur 过渡、coverBlur 双通道、discrete 模式 | 故意改一个颜色常量会让 CI 红 |
| `[ ]` P4-2 | 交互录制式回归 | 用固定事件序列（scroll / hover / click）驱动确定性帧序列，断言 `LyricsFrame` 的 y/scale/blur/opacity 轨迹 | 轨迹变化导致断言失败 |
| `[ ]` P4-3 | SwiftUI 测试 target | 至少覆盖：挂载、宿主替换 view 的行为、`updateNSView` 语义、representable 与 view 生命周期 | 新增 target 在 CI 中运行 |
| `[ ]` P4-4 | 并发测试 | `decodeAsync` 后台执行、取消响应（P2-7 后）、优先级、后台 `install` 到 MainActor、多处并发 decode | 取消测试断言「被取消」 |
| `[ ]` P4-5 | 错误路径测试 | 承接 P0-2 的对抗用例，按类别补齐断言 | 全绿 |
| `[ ]` P4-6 | 消除测试假绿 | `LayoutTests` 里两处 `guard ... else { return }`（"Helvetica Neue" / "Inter" / "PingFang SC"）改为 `throw XCTSkip(...)`；`Inter` 不是系统字体，很多机器上该测试从未生效 | CI 日志显式显示 skipped 数量 |
| `[ ]` P4-7 | 消除「共享公式」式测试 | `BehaviorRegressionTests` 里重算 `fontSize*0.4` 这类生产公式的断言，改为断言可观察关系（相对位置、单调性、边界） | 重构 marker 几何不破坏测试语义 |
| `[ ]` P4-8 | 性能阈值进 CI | 装载耗时与帧 p99 的宽松阈值（P0-7 的正式版） | 回退 2× 时 CI 红 |
| `[ ]` P4-9 | 覆盖率报告 | 至少按 target 统计；识别 0 覆盖的 public 路径 | 报告进 CI artifact |
| `[ ]` P4-10 | CI matrix | `swiftLanguageModes: [.v6]` 构建；`.macOS(.v15)` 最低版本验证；Xcode/工具链显式 pin；外部消费者 resolve+build job | 四项各自独立可失败 |
| `[ ]` P4-11 | Instruments 证据 | 对 120 行文档跑 Time Profiler + Core Animation FPS，用仓库已有的 `script/summarize_profile.py` 出报告；记录 `CA::Transaction::commit` 与 CI filter encode 的 inclusive 时间 | `Documentation/PERFORMANCE.md` 含 GPU/合成侧数字（当前完全缺失） |

**Phase 4 验收门**：任意一次「改渲染行为」的提交都必须伴随 golden 更新，否则 CI 红；CI 覆盖 Debug/Release/v6/最低平台/外部消费者；`Documentation/PERFORMANCE.md` 同时含 CPU 与合成侧数字。

---

## Phase 5 — 性能、稳健、可访问性

| ID | 任务 | 说明 | 视觉影响 |
|---|---|---|---|
| `[ ]` P5-1 | 每帧工作量收敛到视口 | `render(at:)` 现在遍历**全部** group（`isVisible` 只挡内容更新，不挡 spring/blur/opacity 计算）。改为按可见索引窗口 ± overscan | 可能（边界行进出场时机）→ 必须有 P4-2 轨迹测试护住 |
| `[ ]` P5-2 | 消除每帧堆分配 | `Timeline.update` 的 `bounds.map(\.end).max()`、`Set(filter)`；`LyricsView.render` 里的 4 个数组。缓存 `maxEnd`、复用集合 | 无 |
| `[ ]` P5-3 | ink 颜色成本 | 活动行每帧重建 9 个 `CGColor`（每 glyph ≈10 µs）。把 alpha 量化到 32 档或做 `CGColor` 池 | 理论上有（量化台阶）→ 需目视确认 |
| `[ ]` P5-4 | `GlyphCache` 逐出 O(1) | 现在 `entries.min(by:)` + 捕获闭包 + 两次字典查找，逐出扫全表 | 无 |
| `[ ]` P5-5 | `attachSidecars` 复杂度 | 每个 `<p>` 线性扫全树（O(行×节点)）；改为先建 `for` → nodes 索引 | 无 |
| `[ ]` P5-6 | 修复 DOCTYPE 守卫 | 守卫当前**不可达**（四种 DOCTYPE 实测全部通过），实体引用文本被**静默吞掉**。补 `foundInternalEntityDeclarationWithName` 等回调置位，或直接拒绝；被丢弃的实体补 diagnostic | 无（不改变合法文档） |
| `[ ]` P5-7 | W3C 相对文档的错误信息 | 默认 profile 下抛 "end precedes begin in div"，真实原因是文档不是 media-absolute。改为可诊断的错误 | 无 |
| `[ ]` P5-8 | 无界 `<p>` 的行为文档化 | 无任何时间的 `<p>` 会导致整篇抛错；至少写进文档，或给出更明确的错误 | 无 |
| `[ ]` P5-9 | RTL / bidi | 现状零支持（`grep bidi\|rightToLeft\|writingDirection` 无命中）。**二选一**：(a) 实现 bidi run 排序 + mask 方向；(b) 明确写进文档并在解码时给 diagnostic | (a) 有；(b) 无 |
| `[ ]` P5-10 | 可访问性 | 现状只有一行 `setAccessibilityRole(.group)` + label "Lyrics"。补：逐行可访问元素、当前行、karaoke 进度；或提供 `accessibilityLyric(forGroup:)` 供宿主实现 | 无 |
| `[ ]` P5-11 | `deinit` 隔离 | `deinit` 访问 MainActor 状态（v5 下合法，实际总在主线程释放）。改为显式 `releaseRenderingResources()` 路径为主 | 无 |
| `[ ]` P5-12 | 长词/病态输入护栏 | 260 字符不可断词会产生 260 个 glyph layer，实测 p95 18.4 ms / p99 65 ms。至少加 diagnostic；必要时对单 atom 的 piece 数设上限 | 可能有 |
| `[ ]` P5-13 | 量化「每帧每 glyph」成本进文档 | `Documentation/PERFORMANCE.md` 记录 200/400 片实测（1.89 / 3.95 ms） | 无 |

**Phase 5 验收门**：400 行文档在 120 Hz 下 p99 进帧预算；`Documentation/PERFORMANCE.md` 同时含 CPU 与合成侧数字；RTL 与可访问性都有明确结论（实现或文档化）；golden 图像零变化（P5-1/P5-3 若动了视觉必须显式批准并更新 golden）。

---

## Phase 6 — 生态（「像 AMLL」的主体）

> Phase 0–5 让它**能用**；Phase 6 让它**被用**。

### 6A. 文档与分发

| ID | 任务 |
|---|---|
| `[ ]` P6-1 | DocC 文档：`swift package generate-documentation` + 手写文章（Getting Started / Configuration / Timing / Handling Lyrics / Troubleshooting） |
| `[ ]` P6-2 | 文档站（GitHub Pages 或独立域名）：DocC 产物 + 指南 + showcase |
| `[ ]` P6-3 | 上架 **Swift Package Index**（获得徽章与可搜索性） |
| `[ ]` P6-4 | 发布可下载的独立预览 App（`MelismaKitDemo` 升格为 `MelismaKit Preview.app`：拖入 TTML 即预览，不需要写代码） |
| `[ ]` P6-5 | 展示画廊：至少 8 个场景的截图/GIF + 生成脚本（可重跑，避免手工截图过期） |
| `[ ]` P6-6 | 接入指南补齐：AppKit 直用、SwiftUI、时间推送策略（低频采样 + 内部预测）、seek 策略、主题映射 |

### 6B. 工具与语料

| ID | 任务 |
|---|---|
| `[ ]` P6-7 | `melismakit-ttml` CLI：`validate`（含 diagnostics 输出）/ `inspect`（行数、定时模式、ruby/翻译统计）/ `convert`（w3cRelative ↔ amllAbsolute，吸收 `script/prepare_fixture.py`） |
| `[ ]` P6-8 | 与 AMLL TTML 规范的对照文档：明确支持/不支持的子集（region/style、set/animate、timeBase 变体、frameRate 等） |
| `[ ]` P6-9 | fixture 语料库：合成为主 + 经授权的真实样本（**必须**记录来源与 license，见 `LICENSING.md` 政策） |
| `[ ]` P6-10 | 与 amll-ttml-db 的关系说明（消费它，不复制它） |

### 6C. 格式扩展

| ID | 任务 | 前置 |
|---|---|---|
| `[ ]` P6-11 | 抽出 `LyricDecoder` 协议（`LyricsDocument` 已是纯值模型，不需要改模型） | — |
| `[ ]` P6-12 | LRC 解码器（含 `[mm:ss.xx]` 行定时 + 简单扩展） | P6-11 |
| `[ ]` P6-13 | YRC 解码器 | P6-11 |
| `[ ]` P6-14 | ASS/SSA 解码器（`\k` / `\kf` 卡拉OK标签） | P6-11 |
| `[ ]` P6-15 | 每个新格式都带完整测试 + fixture + 文档中的支持范围表 | — |

### 6D. 平台

| ID | 任务 | 说明 |
|---|---|---|
| `[ ]` P6-16 | 先做**平台抽象评估**，不要直接开工 | AppKit 贯穿 `LyricsView` / `LayerRenderer`(`NSColor`/`NSFont`) / `TextLayout`(`NSFontManager`) / `Motion`(`SwiftUI`)。产出：需抽象的类型清单 + 工作量估计 |
| `[ ]` P6-17 | 若评估通过：抽出平台层（`NSFont↔CTFont`、`NSColor→CGColor`、`NSView↔UIView`、tracking area、display link） | `CADisplayLink` 两边都有，成本主要在字体解析与颜色 |
| `[ ]` P6-18 | iOS / iPadOS 支持 | 依赖 P6-17 |
| `[ ]` P6-19 | visionOS 支持 | 依赖 P6-17 |

**Phase 6 验收门**：陌生人从 README 到「跑起来看到歌词」< 5 分钟；SPI 已索引；文档站上线；预览 App 可下载；至少 2 种新格式可用且有测试；平台抽象评估有结论。

---

## Phase 7 — 社区与 1.0

| ID | 任务 |
|---|---|
| `[ ]` P7-1 | `CONTRIBUTING.md`：如何跑测试、如何更新 golden、如何提交视觉改动（必须附截图）、commit 规范 |
| `[ ]` P7-2 | `CODE_OF_CONDUCT.md` |
| `[ ]` P7-3 | Issue 模板：Bug（含最小 TTML 片段 + Probe 输出）、Feature、Format support |
| `[ ]` P7-4 | PR 模板：范围、关键选择、未覆盖边界、**实际验证过的路径**、截图 |
| `[ ]` P7-5 | `SECURITY.md`（XML 解析、资源耗尽、畸形输入的报告流程） |
| `[ ]` P7-6 | 发布自动化：tag → Release notes → 校验外部消费 |
| `[ ]` P7-7 | `CHANGELOG.md`（Keep a Changelog 格式），从 0.2.0 起重置 |
| `[ ]` P7-8 | good-first-issue 池：从 Phase 5/6 的低风险项里挑（RTL 文档、可访问性、格式解码器、文档站） |
| `[ ]` P7-9 | Discussion 区 / 使用示例仓库 |
| `[ ]` P7-10 | **1.0.0**：API 冻结，宣布语义化版本承诺与弃用政策 |
| `[ ]` P7-11 | 1.0 前做一次完整审计复跑（本文档第 2 节的全部数字 + Phase 3 的 API 评审） |

---

## 4. 验收门汇总

| Gate | 条件 |
|---|---|
| **G1A** | 改名完成（`MelismaKit`）且 `git grep` 旧名仅剩历史记录；全新 clone 后 Debug+Release 构建零警告 / 测试 / Demo / Probe 全部正常；外部消费者能从新 URL 解析 `v0.2.0`；GitHub 旧仓名 redirect 生效 —— **✅ 2026-09-12 全部通过** |
| **G0** | 性能基线可复现；CI 有 Release + Probe + warnings-as-errors；对抗用例进测试 |
| **G1B** | 派生清单覆盖全部源文件；`NOTICE` + `LICENSING.md` 与清单一致；派生文件头有声明；README 有「与 AMLL 的关系」段与截图。**达成即清掉审计唯一的 BLOCKER** |
| G2 | 120 行 `load()` < 150 ms；400 行 < 400 ms；帧护栏无回退；截图确认视觉无变化 |
| G3 | 公共 API 无宿主词汇；preset 可用；DocC 无未文档化 public symbol；Demo 控件数下降 |
| G4 | 改渲染必触发 golden 失败；CI matrix 完成；PERFORMANCE.md 含合成侧数字 |
| G5 | 400 行 120 Hz p99 进预算；RTL 与可访问性有结论；golden 零变化或已批准 |
| G6 | README→运行 < 5 分钟；SPI 索引；文档站上线；≥2 新格式 |
| G7 | 1.0.0 发布且带 API 冻结政策 |

---

## 5. 风险登记

| 风险 | 影响 | 缓解 |
|---|---|---|
| 改名影响已有使用者 | 仓库 URL 变化、SPM 依赖失效 | 旧仓名保留 GitHub redirect；发布 CHANGELOG 迁移说明；0.2.0 是 breaking 但无外部用户的窗口期 |
| 分批首次装载破坏视觉（P2-5） | 出现空窗或入场动画错位 | **优先只做 P2-1..P2-3**；若已达标则不做 P2-5 |
| RTL 实现引入布局回归（P5-9） | 现有 LTR 行为退化 | 先只做文档化（选项 b）；实现时以 `TextLayout` 纯函数层为界，加 mask 方向测试 |
| ink 颜色量化被用户看出台阶（P5-3） | 视觉退化 | 量化档位可配置；默认先用最大档；必须目视确认 |
| 派生清单不完整（P1-9） | 合规风险残留 | 逐文件过一遍全部 8 个源文件，宁可标注保守；无法判定的写「无法确定」而不是猜 |
| Phase 6 范围失控 | 长期不发布 | 严格按 gate 推进；P6-16 只出评估不直接开工；格式扩展每个独立可交付 |
| 未来 agent 以「架构不洁」为由重写 renderer | 摧毁已验证的设计 | 第 10 节保护清单 + G4 的 golden 测试作为硬护栏 |

---

## 6. 保护清单（硬约束：不要动）

以下内容**看起来复杂／不优雅，但都由实测或测试验证过**。任何改动提案必须先在 issue 里给出量化证据。

1. **宿主持有 `NSView`**（而不是 SwiftUI 值语义视图）。它持有 display link、spring 状态、hover 状态机、glyph cache；改成值语义必然引入第二套状态。
2. **SwiftUI 桥保持薄、`updateNSView` 为空**。与「宿主持有 view」的前提一致。只需补生命周期文档与断言。
3. **三个独立的时间概念**（`LyricsTimeline` 状态机时间 / `LyricsClock` 宿主时钟 / `MaskPath` 媒体时间）。各自可独立测试，合并会毁掉当前最强的测试资产。
4. **`LyricsClock` 的陈旧采样容忍（`backwardsJitterTolerance = 0.35`）与暂停/恢复重基规则**。看起来像 hack，实际解决低频宿主采样这一真实问题，有测试。
5. **spring 映射到 Apple `SwiftUI.Spring` + pushkine 闭式解做测试 oracle**。数值跨三种阻尼区验证到 1e-9，且 provenance 是全仓最规范的一处。
6. **一个 glyph 一个 layer 三元组 + 视口外 `discardContent()`**。实测 120 行只有 564 个 CALayer，代价可控、收益明确。不要「优化」成共享 layer。
7. **`TimingPolicy` 的五段预处理**（偏移平移 → 背景拍平 → 主/背景同步 → 重叠清理 → lead-in 反推 + cap）。每段对应一个具体回归与专门测试。
8. **`MaskPath` 的 knots / anticipation / `singleTimedSpan` 三分支**。解决「单 span 行」「带时间的空格」「时间戳回退」三个真实输入畸形。
9. **`render(at:)` 确定性入口 + `automaticDisplayUpdates` 开关**。整个可测性、Probe、golden 测试都建立在这上面。
10. **`snapshotImage` 的逐组捕获 + Core Image 复刻合成滤镜**。`CALayer.render(in:)` 本来就不含 compositor filter。这是导出路径，不是热路径。
11. **单一 `LyricsConfiguration` 值类型 + `Equatable`**。不要拆成几十个 setter。
12. **`swiftLanguageModes: [.v5]`（当前）**。全仓迁 v6 是独立工程（可放 Phase 4/5 作为可选任务），且 `@MainActor` 已能在编译期拦住 v5 消费者的越界调用（已实测）。

---

## 7. 已知不做（明确排除）

| 项 | 理由 |
|---|---|
| 变成播放器 / 音乐库 / 歌词抓取工具 | 违反 1.2 节边界 |
| 支持 AMLL 的全部 TTML 特性（region/style 布局、set/animate、内嵌媒体） | 这些在原生歌词渲染里无对应语义；改为**明确文档化不支持**并对输入给 diagnostic |
| 内置主题持久化 / `UserDefaults` / 任何全局状态 | 组件不得持有跨实例状态 |
| 依赖第三方 Swift 包 | 零依赖是当前最强的采用优势之一 |
| 引入 WebView fallback | 本项目的存在理由就是原生渲染 |
| 重写公开 Git 历史 | 与 myPlayer2 的既定规则一致；tag 保留 |

---

## 8. 待决策事项

| # | 事项 | 阻塞 | 状态 |
|---|---|---|---|
| D-1 | ~~项目名称~~ | ~~阻塞 Phase 1A~~ | **已完成**：取名 `MelismaKit`（2026-09-12）并**执行完毕 Phase 1A 全部 P1-1..P1-8**，G1A 于 2026-09-12 通过。命名到此冻结，不再改 |
| D-2 | Phase 2 是否做分批首次装载（P2-5） | 阻塞 P2-5/P2-6 | 待 P2-1..P2-4 实测后决定 |
| D-3 | RTL：实现还是仅文档化（P5-9） | 阻塞 P5-9 | 待 Phase 5 开始时定 |
| D-4 | 是否支持 iOS（P6-16/17） | 阻塞 Phase 6D | 待 Phase 6 开始时定 |
| D-5 | 是否对外提供独立预览 App 的签名分发（P6-4） | 阻塞 P6-4 | 待 Phase 6 开始时定 |

---

## 9. 附录 A：复现审计测量

> 以下命令针对**冻结快照 `717dd28`（tag `0.1.4`）**，即当时包名仍为 `NativeLyrics` 的状态。要在当前代码上执行同样的测量，把 `NativeLyrics*` 换成 `MelismaKit*`、`LyricsProbe` 换成 `MelismaKitProbe` 即可（见 P0-4，Phase 0 会把这条路径固化成工具）。

```sh
# 构建与测试
swift build                                    # 零警告
swift build -c release
swift test                                     # 99 用例

# 外部消费者解析（README 主推的接入方式）
#   在仓库外新建包，依赖 .package(url: "https://github.com/kmgcc/NativeLyrics.git", from: "0.1.4")
swift package resolve                          # → 717dd282…

# 确定性渲染 trace（注意：这看不到 load() 的代价）
swift run --quiet LyricsProbe \
  Sources/NativeLyricsDemo/Resources/complex.ttml /tmp/probe 30 760 720

# Instruments（仓库已有汇总脚本）
xctrace record --template 'Time Profiler' --launch -- <预览 App>
python3 script/summarize_profile.py <trace.xml>   # CA::Transaction::commit / Filter::encode inclusive

# Swift 5 消费者越界调用应编译失败（隔离验证）
#   在 v5 mode 消费者里写 Task.detached { view.synchronize(...) } → error
```

**注意**：审计期间使用的规模 fixture 生成器、对抗性解码用例、Release 装载/帧耗时测量工程都位于仓库外的一次性目录，**尚未入仓**。把它们落进仓库是 P0-1 / P0-2 / P0-3 的核心内容，否则这轮审计的可复现性会丢失。

---

## 10. 附录 B：完成记录

### 决策记录

| 日期 | 决定 | 说明 |
|---|---|---|
| 2026-09-12 | 本路线图建立，依据第三方独立审计（快照 `717dd28` / `0.1.4`） | 审计结论：不适合立即公开；1 个 BLOCKER（provenance）+ 5 个 HIGH。全文数字见第 2 节 |
| 2026-09-12 | **D-1 名字暂缓**：`NativeLyrics` 暂时保留不改 | 维护者候选 `LUMA`（Lyrics UI & Motion Architecture）与 `SMLK`（Swift music Lyrics Kit）入档待评，实测可用性见 1.4。本轮**不执行任何改名** |
| 2026-09-12 | 本轮不开始执行任何 Phase | 维护者先审阅本文件；Phase 0 / Phase 2 不依赖 D-1，可随时启动 |
| 2026-09-12 | `MeloLyrics` 加入候选并完成实测 | 全串命名空间第一梯队（同名仓库 3、npm/PyPI 空闲、`.dev`/`.app` 可用、`.com` 仅空占位）；可读性/可发现性全候选最高。代价：「Melo」在音乐 App 赛道拥挤（多个 App Store Music 分类 App + `MeloTTS` 7.6k★），会影响到 P6-4 的品牌化预览 App。详见 1.4 综合对比表 |
| 2026-09-12 | **命名定案：`MelismaKit`** | P1-1 完成。仓库 `melismakit`、module `MelismaKit`、产品 `MelismaKit` / `MelismaKitSwiftUI` / `MelismaKitDemo` / `MelismaKitProbe`；**类型名不加前缀**。改名执行排在 **Phase 1A 且推荐作为第一个执行步骤**（先改名再建 Phase 0 的测量工件，避免二次改名）。其余候选转入历史记录 |
| 2026-09-12 | **计划顺序调整** | Phase 1 拆为 1A（改名）/ 1B（provenance）两个独立阶段；推荐执行顺序 `1A → 0 → 1B → 2 → 3 → …`。Gate 相应拆为 G1A / G0 / G1B |
| 2026-09-12 | **Phase 1A 改名执行完毕，G1A 通过** | P1-1..P1-8 全部完成。本地：包名/产品/target/目录/类型/文档/脚本全部改为 `MelismaKit`，目录用 `git mv` 保留历史，类型名只改 `MelismaKitViewRepresentable` 一处（commit `e90ca7b`）。远端：仓库 `kmgcc/NativeLyrics` → `kmgcc/melismakit`，旧 URL redirect 有效，annotated tag `v0.2.0` 已推送，`0.1.x` tag 与历史未动。验证：Debug+Release 零警告、`swift test` 99 全绿、Probe p95 1.33 ms（基线 1.195，无回退）、Demo 包与启动正常、全新 clone 复验通过、外部消费者 `from: "0.2.0"` 解析到 revision `5665da5` 且 README 示例零警告可运行。**下一步：Phase 0** |

### 任务完成记录

| 日期 | Phase | 任务 | commit |
|---|---|---|---|
| 2026-09-12 | 1A | P1-3 包/产品/target/目录改名 | `e90ca7b` |
| 2026-09-12 | 1A | P1-4 类型改名（`MelismaKitViewRepresentable`） | `e90ca7b` |
| 2026-09-12 | 1A | P1-5 全部引用改名（README / Documentation / VALIDATION / BEHAVIOR-REGRESSIONS / script / bundle id） | `e90ca7b` |
| 2026-09-12 | 1A | P1-6 tag 策略确认（`v0.2.0` annotated） | `e90ca7b` |
| 2026-09-12 | 1A | P1-7 全仓旧名清零检查通过 | `e90ca7b` |
| 2026-09-12 | 1A | P1-2 GitHub 仓库改名 `kmgcc/NativeLyrics` → `kmgcc/melismakit` | `5793004` |
| 2026-09-12 | 1A | P1-8 外部消费者 `from: "0.2.0"` 解析 + README 示例编译通过 | `5793004` |
