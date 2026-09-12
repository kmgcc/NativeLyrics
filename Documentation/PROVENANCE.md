# Source provenance

This file records which parts of MelismaKit are original work and which parts
are derived from [AMLL (Apple Music-like Lyrics)](https://github.com/steve-xmh/applemusic-like-lyrics),
which is licensed `AGPL-3.0-only`.

It exists because the package is an independent native implementation of the
same *format* as AMLL, but not an independent implementation of every
*algorithm*. Some behavior was deliberately matched against AMLL's source
rather than its documentation, and that has to be stated rather than implied.

## How to read the verdicts

| Verdict | Meaning |
|---|---|
| **派生** | Derived. Concrete structural evidence exists: preserved numeric constants, preserved variable names, identical branch thresholds, or the same formula shape. |
| **独立** | Independent. No upstream counterpart was found for the algorithm; a shared high-level idea does not count. |
| **无法确定** | Cannot determine. A correspondence is plausible but unconfirmed. Recorded rather than resolved by guessing. |

A shared *idea* (both implementations scroll the active line toward a position,
both split CJK into characters) is never enough to call something derived.
Derivation requires matching constants or structure.

## Verification status

Two rounds of evidence are recorded, and they are not equivalent.

| Round | Scope | Status |
|---|---|---|
| Direct maintainer check | `Motion.swift` `interludeSample`; `Motion.swift` `SpringParameters`; `Document.swift` layout constants (`alignPosition`, `overscan`, `wordFadeWidth`) | **Verified against upstream source**, both sides quoted below |
| Assisted exhaustive pass | All eight library sources, upstream legacy 0.2.1 + current main | **Machine-assisted; pending line-by-line maintainer confirmation** — see the note under the table |

Gate 1B requires the maintainer to confirm this list item by item before the
package is promoted. Until that happens, treat the assisted pass as a strong
starting point, not as an audited result.

## Derivation list

All eight library sources are covered.

### `Motion.swift`

| Symbol | Verdict | Upstream | Notes |
|---|---|---|---|
| `interludeSample(elapsed:duration:profile:)` | **派生** | `core/src/lyric-player/dom/interlude-dots.ts` | Confirmed by direct comparison, both sides quoted below |
| `EmphasisEnvelope.sample` | **派生** | `core/src/lyric-player/dom-slim/lyric-line.ts` `initEmphasizeAnimation` | `shape(du/2)*0.6`, `shape(du/3)*0.5`, `*1.6`/`*1.5`/`*1.2`, `min(1.2)`/`min(0.8)`, `du/2.5/anchor*char` delay, `min(0.3, blur*0.3)` glow, `sin(π)` float `*0.05` with the background `*2` factor, `*1.4` float duration |
| `Curves` (`emphasisIn` / `emphasisOut` / 32-sample curve) | **派生** | `dom-slim/lyric-line.ts` `makeEmpEasing` | Control points `(0.2, 0.4, 0.58, 1)` and `(0.3, 0, 0.58, 1)`; the 32-sample count matches `ANIMATION_FRAME_QUANTITY = 32` |
| `SpringParameters.position` / `.scale` / `.background` | **派生** | `core/src/lyric-player/base.ts` | Confirmed by direct comparison, both sides quoted below |
| `SpringParameters.position(interval:slow:end:profile:)` | **派生** | `core/src/lyric-player/base/layout.ts` `computeLinePosYSpringParams` | `clamp(interval, 100, 800)`, `ratio = (1-(x-100)/700)**0.2`, `k = 170 + ratio*50`, `damping = 2.2*sqrt(k)` |
| `SpringTrack` | **独立** | — | The delay-queue interface resembles AMLL's `Spring`, but the solver is Apple's `SwiftUI.Spring`, not the upstream solver |
| `lyricLineFall*`, `exitCatchUpTime`, `HighlightSmoother` | **独立** | — | No upstream counterpart found |

### `TimingPolicy.swift`

| Symbol | Verdict | Upstream | Notes |
|---|---|---|---|
| `advanceFirstWords` | **派生** | player fork `core/src/lyric-player/base.ts` `applyEarlyWordLeadIn` | Same front-word selection (`.prefix(2)`), same one-millisecond floor on the segment anchor, same `start = max(line.start, word.start - lead*(1-a))` shape, same near/far caps `260` / `180` / `leadIn*0.6` (milliseconds upstream, seconds here) |
| `prepare` (advance / lead-in pass, end caps, main-background sync) | **派生** | player fork `base.ts`; upstream `base/layout.ts` | Same advance model (`amount` `0.4`/`0.6`, boundary `prev.start + prev.duration*0.3`) and the same main/background shared range |
| `convertExcessiveBackgroundLines`, `cleanUnintentionalLineOverlaps`, `normalizeLineWordsAndBounds`, `restore` | **无法确定** | — | No matching upstream function found, including for the `overlap > 0.1 && overlap > nextDuration*0.1` threshold. The adjacent upstream `applyTrailingWordCatchUp` end-clipping pass is a plausible ancestor, but the correspondence is unconfirmed |

### `Timeline.swift`

| Symbol | Verdict | Upstream | Notes |
|---|---|---|---|
| `LyricsTimeline.update` | **派生** | `base.ts` `setCurrentTime`; `base/timeline.ts` `commitPlayerTimeState` | Buffered foreground span between the hot endpoints, the seek-focus rule, and end-of-song focus `hasBottom ? count : count-1` |
| Interlude detection | **派生** | `base.ts` `getCurrentInterlude`; `base/layout.ts` `computeCurrentInterlude` | `0.25` s gap trim, `4` s minimum gap, `+0.02` s lookahead |
| `LyricsInteraction`, `LyricsClock` | **独立** | — | Native pointer and host-clock state machines; `backwardsJitterTolerance` has no upstream counterpart because upstream is delta-driven |

### `TTMLDecoder.swift`

| Symbol | Verdict | Upstream | Notes |
|---|---|---|---|
| `amll:empty-beat`, `x-bg` / `x-translation` / `x-roman` roles, duet default agent `v1`, background `( )` stripping | **派生** | `packages/ttml/src/parser.ts` | Same attribute name, same role names, same default agent, same parenthesised-background rule |
| XML tree, media-absolute and W3C-relative clock resolution, ruby, metadata, sidecars, diagnostics | **独立** | — | Same parse *domain* as `parser.ts`, no structural or numeric copy |

### `TextLayout.swift`

| Symbol | Verdict | Upstream | Notes |
|---|---|---|---|
| `makeAtoms` | **派生** | `core/src/utils/lyric-split-words.ts` `chunkAndSplitLyricWords` | Interpolated per-character timing (`start + offset/total*(end-start)`), `total = max(1, non-space length)`, CJK character splitting unless the word carries a romanization |
| `qualifies` (emphasis gating) | **派生** | `base.ts` `shouldEmphasize` | `duration >= 1s`, any CJK length, non-CJK length `> 1 && <= 7` |
| `MaskPath` fade constants | **派生** | `dom-slim/lyric-line.ts` | Leading `fadeWidth*1.5` and trailing `fadeWidth*0.5` |
| `balancedBreaks` | **独立** | — | No balanced-wrap algorithm exists anywhere in upstream core |
| Font resolution, shaping, width measurement, CJK detection, obscenity masking | **独立** | — | Native Core Text; the obscenity idea is shared, the implementation is not |

### `LayerRenderer.swift`

| Symbol | Verdict | Upstream | Notes |
|---|---|---|---|
| Main-line scale `0.97` and `alphaTarget = (scale-0.97)/0.03` | **派生** | `base.ts` (`SCALE_ASPECT = 97`), `dom-slim/lyric-line.ts` | Same constant and same normalization window |
| `GlyphCache`, glyph/word/line/group layer stacks, ink compositing, Core Image filters, glow | **独立** | — | Native layer tree; the blur radius uses a distance term with no upstream equivalent (`blurLevel` is an integer there) |

### `LyricsView.swift`

| Symbol | Verdict | Upstream | Notes |
|---|---|---|---|
| Layout and stack parameters | **派生** | `base.ts` `calcLayout`; `base/layout.ts` `computeGroupPresentation` | `alignPosition 0.35`, buffered opacity `0.85`, `hidePassedLines` at `interlude.anchor + 1`, background-first placement, `baseDelay 0.05` with the `/= 1.05` stagger, interlude dot margin `fontSize*0.4` |
| `install` / `load` / `clear` / `render` / display link / reflow / incremental layout, entry and wake animations, pointer tracking, `snapshotImage` | **独立** | — | Native `NSView` lifecycle throughout; no upstream structural counterpart |
| Background reveal curve, blur radius formula | **无法确定** | — | Upstream uses different parameters (`bgScale`, integer `blurLevel`); the shared idea is confirmed, the formula is not |

## Two-sided evidence for the directly verified items

### `Motion.swift` `interludeSample`

Upstream `packages/core/src/lyric-player/dom/interlude-dots.ts`:

```ts
const c1 = 1.70158;
const c2 = c1 * 1.525;
...
scale *= Math.sin(1.5 * Math.PI - (currentDuration / breatheDuration) * 2) / 20 + 1;
if (currentDuration < 2000) { scale *= easeOutExpo(currentDuration / 2000); }
...
if (interludeDuration - currentDuration < 750) {
    scale *= 1 - easeInOutBack((750 - (interludeDuration - currentDuration)) / 750 / 2);
}
if (interludeDuration - currentDuration < 375) { globalOpacity *= clamp(0, (...)/375, 1); }
const dotsDuration = Math.max(0, interludeDuration - 750);
scale = Math.max(0, scale) * 0.7;
const dot0Opacity = clamp(0.25, ((currentDuration * 3) / dotsDuration) * 0.75, 1);
```

`Sources/MelismaKit/Motion.swift`:

```swift
let breathe = duration/ceil(duration/(profile == .upstream ? 4.5 : 1.5))
var scale = sin(1.5 * .pi - elapsed/breathe*2*(profile == .upstream ? .pi : 1))/20 + 1
if elapsed < 2 { scale *= 1-pow(2,-10*elapsed/2) }
if remaining < 0.75 {
    let x = (0.75-remaining)/0.75/2, c2 = 1.70158*1.525
    let ease = pow(2*x,2)*((c2+1)*2*x-c2)/2
    scale *= 1-ease
}
if remaining < 0.375 { opacity *= Curves.clamp(remaining/0.375) }
let d = duration-0.75
... return max(0.25, min(1, candidate))
return .init(scale:max(0,scale)*0.7,opacity:opacity,walk:walk)
```

The constant `1.70158 * 1.525` and the local name `c2` are both preserved.

### `Motion.swift` `SpringParameters`

Upstream `packages/core/src/lyric-player/base.ts`:

```ts
protected posYSpringParams: Partial<SpringParams> = { mass: 0.9, damping: 15, stiffness: 90 };
protected scaleSpringParams: Partial<SpringParams> = { mass: 2, damping: 25, stiffness: 100 };
protected scaleForBGSpringParams: Partial<SpringParams> = { mass: 1, damping: 20, stiffness: 50 };
```

`Sources/MelismaKit/Motion.swift`:

```swift
public static let position = SpringParameters(mass:0.9,damping:15,stiffness:90)
public static let scale = SpringParameters(mass:2,damping:25,stiffness:100)
public static let background = SpringParameters(mass:1,damping:20,stiffness:50)
```

### `Document.swift` layout constants

Upstream `packages/core/src/lyric-player/base.ts`:

```ts
protected alignPosition = 0.35;
protected overscanPx = 300;
protected wordFadeWidth = 0.5;
```

`Sources/MelismaKit/Document.swift`:

```swift
public var alignPosition: Double = 0.35
public var wordFadeWidth: Double = 0.5
public var overscan: Double = 300
```

## What upstream this was compared against

| Tree | Version | Declared license |
|---|---|---|
| `applemusic-like-lyrics` legacy line | 0.2.1 | `GPL-3.0` |
| `applemusic-like-lyrics` current main | 0.5.1 | `AGPL-3.0-only` |

The package is distributed as `AGPL-3.0-only`, which is compatible with both.
The decisive tree for `advanceFirstWords` is the player's own AMLL fork, which
is not present in either upstream tree; it is itself a patch on upstream
`base.ts`.

## Maintaining this file

Adding code that is translated from an upstream source requires, in the same
change, a row here, an attribution in [`NOTICE`](../NOTICE), and a derivation
header on the file. A change that copies upstream structure without recording
it here is a licensing defect, not a style issue.
