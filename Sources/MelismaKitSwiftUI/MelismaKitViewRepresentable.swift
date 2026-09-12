import AppKit
import MelismaKit
import SwiftUI

/// The smallest SwiftUI bridge for the native lyric surface.
///
/// `LyricsView` remains the source of truth for rendering, playback time,
/// configuration, and callbacks. The host owns the view's lifetime and can
/// continue to call `load`, `install`, `synchronize`, and the interaction
/// methods directly. This wrapper only gives SwiftUI a place to mount the
/// AppKit view; it does not mirror renderer state or add an orchestration
/// layer.
@MainActor
public struct MelismaKitViewRepresentable: NSViewRepresentable {
    public typealias NSViewType = LyricsView

    public let view: LyricsView

    public init(view: LyricsView) {
        self.view = view
    }

    public init(_ view: LyricsView) {
        self.init(view: view)
    }

    public func makeNSView(context: Context) -> LyricsView {
        view
    }

    public func updateNSView(_ nsView: LyricsView, context: Context) {}
}
