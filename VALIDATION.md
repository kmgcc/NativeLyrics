# MelismaKit validation

This document records checks for the standalone package. It deliberately
separates package behavior from host-specific acceptance such as artwork
analysis, fullscreen composition, or a player's audio-session lifecycle.

## Reproducible checks

Run these commands from the repository root:

```sh
swift package dump-package
swift build --configuration debug
swift test --configuration debug
swift run --quiet MelismaKitProbe \
  Sources/MelismaKitDemo/Resources/complex.ttml \
  /tmp/melismakit-probe 10 760 720 --paused
bash script/build_and_run.sh --build-only
```

The package test suite currently contains 99 XCTest cases. It covers TTML
decoding, AMLL absolute timing, explicit W3C relative timing, metadata,
translations, romanization, Ruby, duet/background layers, layout, bounded
glyph caching, clock semantics, resize reflow, focus movement, seek behavior,
hover behavior, entry/exit motion, emphasis, glow, blur, compositing channels,
and the public timing/configuration contracts.

The asynchronous decoder test verifies that `decodeAsync(_:)` produces the same
document as the existing synchronous decoder. `LyricsView.load(ttml:)` retains
the original synchronous path; `install(document:)` shares the same renderer
state transition after parsing.

`MelismaKitProbe` uses a checked-in synthetic TTML fixture and reports frame count,
render percentile, and glyph-cache size. It is a deterministic smoke and
regression tool, not a machine-independent performance claim.

## Demo paths

The standalone Demo includes synthetic fixtures for word timing, line timing,
glow, duet/Ruby, and background vocals. It supports:

- opening an external TTML file;
- play/pause, seek, follow, resize, and native lyric-click callbacks;
- configuration controls for typography, palette, motion, language layers,
  surface styles, channel blending, and raster/display-link quality;
- optional external catalog discovery through explicit `--library-root` paths.

The catalog scanner accepts a root containing `Tracks/<track>/lyrics.ttml`, a
`Tracks` directory, or a single directory containing `lyrics.ttml`. It does not
read an application-specific registry or assume a particular player bundle.

## Host acceptance boundary

The package-level suite does not establish a host application's complete visual
parity. A consuming app should additionally verify its own main, fullscreen,
and compact/mini-player surfaces; theme and artwork mapping; player clock
updates; pause/play/seek transitions; track replacement; window reparenting;
occlusion; and restart behavior. Those checks belong to the host integration
repository and should use the exact signed app and real playback path.
