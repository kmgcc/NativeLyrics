# Licensing and provenance

MelismaKit is distributed under the GNU Affero General Public License,
version 3, only (`AGPL-3.0-only`). The complete license text is in
[LICENSE](../LICENSE).

## Source provenance

This repository is an extraction of the native lyric implementation from an
AGPL-licensed parent project. The extraction keeps the native renderer,
decoder, value models, tests, synthetic fixtures, Demo, and probe in a package
that has no dependency on that parent application's source tree.

The implementation was developed to reproduce the observable timing, layout,
motion, and interaction contracts of AMLL. The AMLL integration submodule used
during development is itself marked `AGPL-3.0-only`. Generated web renderer
assets and application-private parity pages are not distributed here.

The Swift package has no third-party package dependency. System frameworks such
as AppKit, Core Text, Core Animation, Core Image, Foundation, and SwiftUI are
platform libraries, not bundled third-party source.

`MotionTests` contains an independently written closed-form test oracle based
on the published behavior of AMLL's Pushkine spring solver. It does not bundle
the solver's source; the test comment records the MIT reference.

The bundled TTML files are synthetic fixtures created for renderer tests and
Demo scenarios. Do not add downloaded lyrics, artwork, audio, or other
third-party assets without recording their separate license and provenance.

This file records the conservative license choice for the extracted code. It
does not grant permission to relicense AMLL-derived behavior or any future
third-party asset under a different license.
