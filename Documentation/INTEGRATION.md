# 接入边界

`MelismaKit` 是一个 UI 组件，而非播放器框架。歌词文档在加载完成后的状态、布局、动画、点击命中测试（hit testing）以及由 `LyricsConfiguration` 所体现的所有外观决策均归渲染器自身所有。而宿主应用负责管理音频播放器、曲目选择、数据持久化、封面获取以及决定何时提供播放采样。

## 数据流向

| 职责领域 | MelismaKit | 宿主应用 |
| --- | --- | --- |
| TTML 解析与计时策略文件 | 负责 | 提供原始 `Data` 数据 |
| 文档、行、词、Ruby 注音与翻译的值对象 | 解码/安装后负责持有 | 可按需检查或保留值对象 |
| 排版字体、调色板、布局、视觉特效与动效 | 通过 `LyricsConfiguration` 负责 | 提供语义化配置 |
| 媒体时钟源 | 在传入的采样之间进行插值预测 | 提供媒体时间戳与播放/暂停状态 |
| 歌词点击命中目标 | 触发 `onSeek`（单位为源媒体秒数） | 执行播放器的实际 Seek 跳转 |
| 曲目/曲库存储 | 不包含 | 负责 |
| 封面模糊提取与主题持久化 | 不包含 | 负责提取，并将结果映射为配置 |
| SwiftUI 生命周期 | 提供极薄的挂载点 | 负责持有 `LyricsView` 的生命周期 |

本软件包不依赖任何宿主业务模块、曲目数据模型、设置存储、主题存储、WebView、音频引擎、Bundle 资源或通知协议。它同样没有任何强制依赖的第三方 Swift Package。

## 推荐生命周期

在主线程（MainActor）上创建并使用 `LyricsView`。在加载歌词文档前先进行配置，然后选择以下两条加载路径之一：

1. `try view.load(ttml:time:playing:hostTime:)` 用于同步加载路径。
2. `try await TTMLDecoder().decodeAsync(data)` 结合随后的 `view.install(document:time:playing:hostTime:)` 用于需要将 XML 解析移出 UI 线程的异步导入路径。

安装完成后，通过 `view.synchronize(time:playing:seek:motion:hostTime:)` 传递当前的媒体播放采样。宿主无需在外部累加帧时间差；视图内置的 `LyricsClock` 会基于宿主时间采样进行预测插值，并确保在暂停和 Seek 时位置绝对精准。

使用 `view.onSeek` 将歌词点击连接到宿主播放器。该回调的传参为源媒体时间（单位：秒）。任何针对特定播放器的 Seek 偏移量应保留在宿主的 Seek 策略中，或传入组件显式的计时配置中；绝不能隐藏在兼容性适配层里。

## 外观与行为

组件有意将原生能力暴露为强类型配置：

- `palette`、`backdropColor`、`blendMode` 以及 `channelBlend` 控制语义化墨水与图层合成通道；
- 排版字体、对齐方式、翻译、Ruby 注音、罗马音、脏话过滤模式以及 `lineTimingOnly` 控制内容呈现方式；
- `motion` 控制模糊、重排版动画、进出场、点击级联延迟以及有界的单词前向预测；
- `surface`、封面模糊通道选择、栅格化缩放比例（raster scale）以及 `fpsCap` 描述宿主的呈现需求，无需外部侵入图层树或 DOM。

这些都是渲染器内部持有的行为。宿主可以在其设置 UI 中仅暴露其所需的一小部分选项，同时依然能向视图传递完整的强类型配置对象。

`LyricsProfile.currentPlayer` 保留了原有的原生计时行为以实现兼容；`LyricsProfile.upstream` 则是显式的上游风格替代项。计时预设是组件上的一个枚举值，无需了解任何特定播放器的细节。

## SwiftUI 边界

`MelismaKitSwiftUI.MelismaKitViewRepresentable` 被有意设计为一个极薄的 `NSViewRepresentable`：

```swift
@MainActor
struct LyricsSurface: View {
    let view: LyricsView

    var body: some View {
        MelismaKitViewRepresentable(view: view)
    }
}
```

该 Representable 不会拷贝配置、播放状态或回调。请将这些状态保留在宿主持有的 `LyricsView` 或轻量级宿主控制器中。这可以防止 SwiftUI 的结构体重复创建导致产生第二数据源（second source of truth）。

## 独立性验证

本仓库被有意设计为在脱离任何播放器源码树的情况下均可完全独立验证。在纯净环境下，直接在仓库根目录运行：

```sh
swift package dump-package
swift build --configuration debug
swift test --configuration debug
swift run --quiet MelismaKitDemo
swift run --quiet MelismaKitProbe   Sources/MelismaKitDemo/Resources/complex.ttml   /tmp/melismakit-probe 10 760 720 --paused
```

Demo 的可选曲库功能仅接收通过 `--library-root` 显式指定的根目录；它绝不读取宿主应用的注册表。在最初迁移过程中使用的视觉对齐 HTML 测试线束（harness）被有意排除在本仓库之外，因为它依赖宿主特有的私有资源。
