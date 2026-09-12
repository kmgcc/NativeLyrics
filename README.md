# MelismaKit

![MelismaKit 渲染对唱歌词：包含注音（Ruby）、罗马音、翻译以及逐字高亮效果](Documentation/images/hero.png)

`MelismaKit` 是一个专为 macOS 打造的原生歌词渲染组件，基于 AppKit、Core Text、Core Animation 与 Core Image 构建。它直接支持与 AMLL 兼容的 TTML 歌词格式，并以秒为单位维护媒体计时；宿主应用仅需提供播放状态，并继续持有音频播放器的完整控制权。

本软件包分为两个产物（Products）：

- `MelismaKit`：包含核心渲染器、TTML 解码器、时间线、布局引擎、动效系统、交互逻辑以及数据值模型。
- `MelismaKitSwiftUI`：包含一个轻量级的 `NSViewRepresentable` 桥接封装。用于挂载宿主持有的 `LyricsView`，不会镜像内部渲染状态，亦不创建第二套控制器层级。

外观样式与渲染行为完全由组件内部自持。`LyricsConfiguration` 提供了对排版字体、调色板、对齐方式、翻译/Ruby注音/罗马音、逐字高亮与脏话过滤模式、封面模糊通道、图层混合模式、栅格化渲染质量、DisplayLink 帧率上限以及动效参数的完整控制。宿主应用只需传入语义化配置和播放状态，无需直接侵入图层树或处理 DOM 细节。

## 系统要求

- macOS 15 或更高版本
- Swift 6.1 或更高版本的兼容工具链
- 渲染器核心依赖 AppKit；SwiftUI 支持为可选依赖（通过 `MelismaKitSwiftUI`）

## Swift Package Manager

添加软件包依赖：

```swift
dependencies: [
    .package(url: "https://github.com/kmgcc/melismakit.git", from: "0.2.0")
]
```

然后在目标 Target 中链接所需产物：

```swift
dependencies: [
    .product(name: "MelismaKit", package: "MelismaKit"),
    .product(name: "MelismaKitSwiftUI", package: "MelismaKit")
]
```

## 最简 AppKit 接入

`LyricsView` 是该组件的对外边界。宿主在主线程（MainActor）上创建实例、加载 TTML 字节数据、同步播放采样，并处理歌词点击 Seek：

```swift
import MelismaKit

@MainActor
final class LyricsController {
    let view = LyricsView(frame: .zero)

    init() {
        view.onSeek = { sourceTime in
            // 通知宿主音频播放器跳转（Seek）到 sourceTime
        }
    }

    func load(ttml: Data) throws {
        try view.load(ttml: ttml, time: 0, playing: false)
    }

    func update(time: Double, isPlaying: Bool) {
        view.synchronize(time: time, playing: isPlaying)
    }
}
```

当宿主需要自定义呈现样式时，直接配置该组件：

```swift
var configuration = LyricsConfiguration()
configuration.fontSize = 36
configuration.showTranslation = true
configuration.motion.pointerExitDelay = 0
configuration.palette.mainActive = LyricsColor(0.95, 0.98, 1.0)
lyricsController.view.configuration = configuration
```

对于后台导入场景，可在 UI 线程之外完成解码，再将已解析的 Document 对象安装到主线程的视图中。同步调用方的 `load(ttml:)` 依然可用且行为保持不变：

```swift
@MainActor
func loadInBackground(_ data: Data, into view: LyricsView) async throws {
    let document = try await TTMLDecoder().decodeAsync(data)
    view.install(document: document)
}
```

## SwiftUI 接入

SwiftUI 产物有意保持职责归属明确：

```swift
import MelismaKit
import MelismaKitSwiftUI
import SwiftUI

struct LyricsPanel: View {
    let lyricsView: LyricsView

    var body: some View {
        MelismaKitViewRepresentable(view: lyricsView)
    }
}
```

请在宿主的状态或控制器生命周期中持有 `LyricsView`。尽管 SwiftUI 可能会频繁重建 Representable 结构体值，底层的 AppKit 视图依然是渲染和交互的唯一数据源（Single Source of Truth）。

## 渲染特性

| | |
|---|---|
| ![逐字高亮](Documentation/images/word-highlight.png) | ![主文本上方的 Ruby 注音](Documentation/images/ruby.png) |
| 当前活跃行的逐字卡拉OK式扫亮效果 | 主文本上方的 Ruby 注音（振假名），并支持罗马音与歌词翻译图层 |
| ![两行歌词之间的间奏点](Documentation/images/interlude-dots.png) | ![长音节处的重音发光](Documentation/images/glow.png) |
| 无歌词演唱时的呼吸间奏跳动点 | 由逐字时间驱动的重音缩放（Emphasis）、发光（Glow）与动态模糊 |

上述所有图片均由 `MelismaKitProbe` 基于内置固件确定性渲染生成，而非手动截屏。重新生成方式见 [Demo 与探针工具](#demo-与探针工具)。

## Demo 与探针工具

在仓库根目录下运行 AppKit Demo：

```sh
swift run --quiet MelismaKitDemo
swift run --quiet MelismaKitDemo --ttml /path/to/lyrics.ttml
```

Demo 内置了覆盖逐字计时、逐行计时、发光动效、对唱/Ruby 注音以及伴唱人声的 TTML 测试固件。可以通过打开面板选择外部文件。若要检查基于文件夹的曲库目录，可显式传入一个或多个根目录；Demo 绝不会读取任何特定宿主应用的曲库注册表：

```sh
swift run --quiet MelismaKitDemo --dump-catalog   --library-root /path/to/Library
```

曲库扫描器支持包含 `Tracks/<track>/lyrics.ttml` 的根目录、`Tracks` 目录或直接包含 `lyrics.ttml` 的单曲目录。同目录下的 `meta.json` 与音频文件为可选项。

进行确定性渲染基准测量：

```sh
swift run --quiet MelismaKitProbe   Sources/MelismaKitDemo/Resources/complex.ttml   /tmp/melismakit-probe 10 760 720 --paused
```

当前的测试与人工验证记录参见 [VALIDATION.md](VALIDATION.md)，回归测试所覆盖的渲染器契约参见 [BEHAVIOR-REGRESSIONS.md](BEHAVIOR-REGRESSIONS.md)。

项目的未来演进方向及各阶段执行计划参见 [路线图 (Documentation/ROADMAP.md)](Documentation/ROADMAP.md)。

## 架构与兼容性

核心软件包不依赖任何特定的播放器应用、曲目数据模型、设置存储、主题存储、WebView、音频引擎或应用 Bundle 资源。它完全通过值类型、配置对象、`onSeek` 回调以及传入 `synchronize` 的播放采样与宿主通信。

`LyricsProfile.currentPlayer` 是为需要现有原生计时行为的宿主提供的兼容性预设；`LyricsProfile.upstream` 则是显式的上游风格预设。两者均在组件内部实现，宿主无需维护复杂的兼容协调层。

更多接入细节详见 [接入指南 (Documentation/INTEGRATION.md)](Documentation/INTEGRATION.md)。

## 与 AMLL 的关系

[AMLL (Apple Music-like Lyrics)](https://github.com/steve-xmh/applemusic-like-lyrics) 是一个 Web 端实现：基于 TypeScript、DOM 图层树与浏览器渲染管线。MelismaKit 是专为 macOS 打造的原生实现，基于 AppKit、Core Text 与 Core Animation。**它并非 AMLL 的官方 Swift 移植版本，亦未隶属于 AMLL 项目或获得其背书。**

两者共享的是格式规范，而非代码库。MelismaKit 解析相同的 TTML 规范子集，因此能在 AMLL 中正常呈现的文件也能在此渲染。其计时、布局、动效和交互行为经过精心设计，以匹配 AMLL 的可观察行为 —— 并且有若干函数是通过直接阅读 AMLL 源码而非文档实现的。这些函数属于派生作品：

- [`NOTICE`](NOTICE) 记录了对 AMLL 的致谢归属、派生涉及的模块以及代码查阅日期。
- [`Documentation/PROVENANCE.md`](Documentation/PROVENANCE.md) 逐个符号列出了各库源码文件中哪些函数属于派生、哪些属于独立原创，以及哪些尚无法完全确定。

两个项目均采用 `AGPL-3.0-only` 许可证，因此协议完全兼容。

## 许可证

本项目仅在 GNU Affero 通用公共许可证第 3 版（`AGPL-3.0-only`）下分发。详见 [LICENSE](LICENSE)、[NOTICE](NOTICE) 以及 [Documentation/LICENSING.md](Documentation/LICENSING.md)。
