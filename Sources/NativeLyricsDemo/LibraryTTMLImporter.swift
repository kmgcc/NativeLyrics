import Foundation
import NativeLyrics

/// The Demo passes the library's original AMLL TTML directly to the native
/// decoder. The original bytes remain available for the renderer while the
/// parsed document supplies catalog metadata and preview setup.
struct DemoTTMLImportResult: Sendable {
    let data: Data
    let document: LyricsDocument
}

enum DemoTTMLImporter {
    static func load(_ data: Data) throws -> DemoTTMLImportResult {
        DemoTTMLImportResult(data: data, document: try TTMLDecoder().decode(data))
    }

    static func metadataTitle(_ data: Data) -> String? {
        guard let document = try? TTMLDecoder().decode(data) else { return nil }
        return document.metadata["musicName"]?.first
            ?? (document.title == "TTML Lyrics" ? nil : document.title)
    }
}

struct DemoLibrarySong: Sendable, Equatable {
    let title: String
    let subtitle: String
    let lyricURL: URL
    let audioURL: URL?
    let rootLabel: String
}

enum DemoLibraryCatalog {
    private static let maxSongs = 48

    /// Discover lyric bundles below explicitly supplied folders.
    ///
    /// The standalone Demo deliberately does not know about an application's
    /// library registry or storage layout. A host can pass one or more
    /// library roots with `--library-root`; selecting a file through Open TTML
    /// remains available when no roots are supplied.
    static func discover(roots: [URL]) -> [DemoLibrarySong] {
        var lyricURLs = Set<URL>()
        for root in roots {
            let root = root.standardizedFileURL
            if root.lastPathComponent.caseInsensitiveCompare("Tracks") == .orderedSame {
                collectTrackDirectory(at: root, into: &lyricURLs)
            } else {
                let tracks = root.appendingPathComponent("Tracks", isDirectory: true)
                collectTrackDirectory(at: tracks, into: &lyricURLs)

                let directLyric = root.appendingPathComponent("lyrics.ttml")
                if FileManager.default.fileExists(atPath: directLyric.path) {
                    lyricURLs.insert(directLyric.standardizedFileURL)
                }
            }

            // A caller may point at a parent directory containing several
            // library roots. Recursively inspect only explicitly supplied
            // roots and only collect directories named `Tracks`.
            if lyricURLs.isEmpty, let enumerator = FileManager.default.enumerator(
                at: root,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) {
                for case let url as URL in enumerator {
                    guard url.lastPathComponent.caseInsensitiveCompare("Tracks") == .orderedSame else { continue }
                    collectTrackDirectory(at: url, into: &lyricURLs)
                }
            }
        }

        let songs = lyricURLs.compactMap(makeSong)
        return songs.sorted {
            let left = $0.title.localizedStandardCompare($1.title)
            if left == .orderedSame { return $0.lyricURL.path < $1.lyricURL.path }
            return left == .orderedAscending
        }.prefix(maxSongs).map { $0 }
    }

    static func roots(from arguments: [String]) -> [URL] {
        var roots: [URL] = []
        var index = 0
        while index < arguments.count {
            if arguments[index] == "--library-root", index + 1 < arguments.count {
                roots.append(URL(fileURLWithPath: arguments[index + 1]))
                index += 2
            } else {
                index += 1
            }
        }
        return roots
    }

    private static func collectTrackDirectory(at directory: URL, into lyricURLs: inout Set<URL>) {
        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return }
        for entry in entries {
            let lyric = entry.appendingPathComponent("lyrics.ttml")
            if FileManager.default.fileExists(atPath: lyric.path) {
                lyricURLs.insert(lyric.standardizedFileURL)
            }
        }
    }

    private static func makeSong(url: URL) -> DemoLibrarySong? {
        guard let data = try? Data(contentsOf: url),
              let imported = try? DemoTTMLImporter.load(data) else { return nil }
        let meta = readMetadata(at: url.deletingLastPathComponent().appendingPathComponent("meta.json"))
        let documentTitle = imported.document.title == "TTML Lyrics" ? nil : imported.document.title
        let title = meta.title ?? documentTitle ?? url.deletingLastPathComponent().lastPathComponent
        let subtitle = [meta.artist, meta.album].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
        let directory = url.deletingLastPathComponent()
        let audio = ["audio.m4a", "audio.mp3", "audio.flac", "audio.wav"]
            .map { directory.appendingPathComponent($0) }
            .first { FileManager.default.fileExists(atPath: $0.path) }
        return DemoLibrarySong(title: title, subtitle: subtitle, lyricURL: url, audioURL: audio, rootLabel: rootName(for: url))
    }

    private struct Meta {
        var title: String?
        var artist: String?
        var album: String?
    }

    private static func readMetadata(at url: URL) -> Meta {
        guard let data = try? Data(contentsOf: url),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return Meta() }
        func string(_ key: String) -> String? {
            guard let value = object[key] as? String,
                  !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
            return value
        }
        return Meta(title: string("title"), artist: string("artist"), album: string("album"))
    }

    private static func rootName(for url: URL) -> String {
        let components = url.pathComponents
        if let index = components.lastIndex(where: { $0.caseInsensitiveCompare("Tracks") == .orderedSame }), index > 0 {
            return components[index - 1]
        }
        return url.deletingLastPathComponent().lastPathComponent.isEmpty
            ? "Folder"
            : url.deletingLastPathComponent().lastPathComponent
    }
}
