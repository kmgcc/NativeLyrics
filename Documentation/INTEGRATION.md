# Integration boundary

`NativeLyrics` is a component, not a player framework. The renderer owns the
lyrics document after installation, layout, animation, hit testing, and all
appearance decisions represented by `LyricsConfiguration`. The host owns the
audio player, track selection, persistence, artwork acquisition, and the
decision about when to provide playback samples.

## Data flow

| Concern | NativeLyrics | Host application |
| --- | --- | --- |
| TTML parsing and timing profile | Owns | Supplies source `Data` |
| Document, line, word, Ruby, and translation values | Owns after decode/install | May inspect or retain values |
| Typography, palette, layout, effects, and motion | Owns through `LyricsConfiguration` | Supplies semantic configuration |
| Media clock source | Predicts between supplied samples | Supplies media time and play/pause state |
| Lyric click target | Emits `onSeek` in source seconds | Performs the actual player seek |
| Track/library storage | Not included | Owns |
| Artwork blur extraction and theme persistence | Not included | Owns, then maps results to configuration |
| SwiftUI lifecycle | Provides a thin mount point | Owns the `LyricsView` lifetime |

The package has no dependency on an application module, track model, settings
store, theme store, WebView, audio engine, bundle resource, or notification
protocol. It also has no required third-party Swift package dependency.

## Recommended lifecycle

Create and use `LyricsView` on the main actor. Configure it before loading a
document, then choose one of these input paths:

1. `try view.load(ttml:time:playing:hostTime:)` for a synchronous path.
2. `try await TTMLDecoder().decodeAsync(data)` followed by
   `view.install(document:time:playing:hostTime:)` for an import path that must
   keep XML parsing off the UI executor.

After installation, send the current media sample through
`view.synchronize(time:playing:seek:motion:hostTime:)`. Do not integrate frame
deltas in the host; the view's `LyricsClock` predicts from host-time samples
and keeps paused and seeked positions exact.

Use `view.onSeek` to connect lyric clicks to the host player. The callback's
value is a source/media time in seconds. Any player-specific seek offset stays
in the host's seek policy or in the component's explicit timing configuration;
it is not hidden in a compatibility adapter.

## Appearance and behavior

The component deliberately exposes native behavior as typed configuration:

- `palette`, `backdropColor`, `blendMode`, and `channelBlend` control semantic
  ink and compositing channels;
- typography, alignment, translations, Ruby, romanization, obscenity, and
  `lineTimingOnly` control content presentation;
- `motion` controls blur, reflow, entry/exit, click cascade, and bounded word
  anticipation;
- `surface`, cover-blur channel selection, raster scale, and `fpsCap` describe
  host presentation needs without requiring layer-tree or DOM edits.

These are renderer-owned behaviors. A host can expose only the small subset it
wants in its settings UI while still passing a complete typed configuration to
the view.

`LyricsProfile.currentPlayer` preserves the existing native timing behavior for
compatibility. `LyricsProfile.upstream` is an explicit alternative. The
profile is a value on the component and does not require knowledge of a
particular player.

## SwiftUI boundary

`NativeLyricsSwiftUI.NativeLyricsViewRepresentable` is intentionally a thin
`NSViewRepresentable`:

```swift
@MainActor
struct LyricsSurface: View {
    let view: LyricsView

    var body: some View {
        NativeLyricsViewRepresentable(view: view)
    }
}
```

The representable does not copy configuration, playback state, or callbacks.
Keep those on the host-owned `LyricsView` or on a small host controller. This
prevents SwiftUI value recreation from producing a second source of truth.

## Independence check

The repository is intentionally verifiable without any player checkout. From
the repository root, a clean environment can run:

```sh
swift package dump-package
swift build --configuration debug
swift test --configuration debug
swift run --quiet NativeLyricsDemo
swift run --quiet LyricsProbe \
  Sources/NativeLyricsDemo/Resources/complex.ttml \
  /tmp/native-lyrics-probe 10 760 720 --paused
```

The Demo's optional catalog accepts only roots supplied through
`--library-root`; it does not read a host application's registry. The parity
HTML harness used during the original migration is intentionally not part of
this repository because it depended on host-specific resources.
