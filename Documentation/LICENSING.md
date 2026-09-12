# Licensing and provenance

MelismaKit is distributed under the GNU Affero General Public License,
version 3, only (`AGPL-3.0-only`). The complete license text is in
[LICENSE](../LICENSE). Third-party attribution is in [NOTICE](../NOTICE).

SPDX-License-Identifier: AGPL-3.0-only

## Project origin

This repository is an extraction of a native lyric implementation from an
AGPL-licensed parent project. The extraction keeps the native renderer,
decoder, value models, tests, synthetic fixtures, Demo, and probe in a package
that has no dependency on that parent application's source tree.

## Upstream attribution

The implementation was developed to match the observable timing, layout,
motion, and interaction behavior of **AMLL (Apple Music-like Lyrics)** — and,
for a number of functions, by reading its source rather than its documentation.
Those functions are derived works and are credited here.

| Item | Value |
|---|---|
| Project | Apple Music-like Lyrics (AMLL) |
| Repository | <https://github.com/steve-xmh/applemusic-like-lyrics> |
| License | `AGPL-3.0-only` |
| Derived modules | `packages/core` (lyric player, layout, motion, word splitting), `packages/ttml` (TTML profile) |
| Access date | 2026-09-12 |
| Upstream trees consulted | 0.2.1 legacy line (declared `GPL-3.0`), current main (declared `AGPL-3.0-only`) |

The derived material is limited to timing, layout, motion, and interaction
behavior. It has been modified: translated from TypeScript to Swift and adapted
to AppKit, Core Text, and Core Animation. The XML decoder, the Core Text layout
engine, the layer tree, the value model, and the host-clock handling are
original work.

MelismaKit is **not** an official port of AMLL, and is not affiliated with or
endorsed by the AMLL project. The two share a file format, not a codebase.

### Where the derivation list lives

[`Documentation/PROVENANCE.md`](PROVENANCE.md) records, symbol by symbol, which
functions of the eight library sources are derived, which are independent, and
which could not be determined. Derived files carry a header comment pointing at
that list.

Both upstream trees and this project are `AGPL-3.0-only`, so the licenses are
compatible and no relicensing is involved. What section 5 of the AGPL requires,
and what this repository previously did not provide, is the attribution and the
statement that the material was modified.

## Third-party dependencies

The Swift package has **no third-party package dependency**. System frameworks
such as AppKit, Core Text, Core Animation, Core Image, Foundation,
NaturalLanguage, and SwiftUI are platform libraries, not bundled third-party
source.

`MotionTests` contains an independently written closed-form test oracle based
on the published behavior of the Pushkine spring solver. It does not bundle the
solver's source; the test comment records the MIT reference. This is the model
to follow for any future reference implementation: write the oracle yourself,
record the origin and license in a comment, and do not copy the code.

## Asset policy

The bundled TTML files are synthetic fixtures written for renderer tests and
Demo scenarios. Do not add downloaded lyrics, artwork, audio, or other
third-party assets without recording their provenance.

Because lyrics are copyrightable independently of the recording, a fixture that
reproduces real lyrics needs its own justification. Write original text, or
record all of the following:

```markdown
### <asset file name>

| Field | Value |
|---|---|
| What it is | e.g. TTML lyric file / artwork / audio clip |
| Origin | URL, or the exact command and inputs that generated it |
| Author / rights holder | name, or "generated" |
| License | SPDX identifier, or "permission granted by <holder> on <date>" |
| Added by / date | who added it and when |
| Why it is needed | which test or demo scenario depends on it |

If the asset is a real song's lyrics, also state why an original fixture could
not serve the same purpose.
```

A fixture without such an entry should not be merged.

## What this file does not do

This file records the conservative license choice for the extracted code. It
does not grant permission to relicense AMLL-derived behavior, nor any future
third-party asset, under a different license.
