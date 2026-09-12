import AppKit
import Foundation
import ImageIO
import MelismaKit
import MelismaKitBenchCore
import UniformTypeIdentifiers

// MARK: - 命令行参数

private struct Options {
    var decodeOnly: [String] = []
    var file: String?
    var output = "/tmp/melismakit-probe"
    var time: Double?
    var width = 760.0
    var height = 720.0
    var scale: Int?
    var mode: SyntheticTTML.ScaleMode = .word
    var paused = false
    var core = false
    var upstream = false
    var loadTiming = false
}

private let helpText = """
用法:
  MelismaKitProbe [file.ttml] <输出目录> [time] [width] [height] [选项]
  MelismaKitProbe --scale <N> [--mode <word|line|ruby|longWord>] <输出目录> [time] [width] [height] [选项]

选项:
  --decode-only <文件...>   只解码并报告 OK/ERR（不渲染）
  --scale <N>               生成 N 行规模文档（缺省文件时默认 120 行真实规模）
  --mode <M>                规模文档类型（默认 word）
  --load-timing             额外测量 decode / install / 首帧并写入 JSON
  --paused                  按暂停态渲染（3s @120fps）
  --core / --upstream       切换表面 / 计时预设
"""

private func parseArgs() -> Options {
    var o = Options()
    var positionals: [String] = []
    let args = Array(CommandLine.arguments.dropFirst())
    var i = 0
    func next(_ fallback: String) -> String {
        defer { i += 1 }
        guard i + 1 < args.count else { return fallback }
        return args[i + 1]
    }
    while i < args.count {
        switch args[i] {
        case "--decode-only":
            positionals.append(args[i])
            positionals.append(contentsOf: args[(i + 1)...])
            i = args.count
        case "--scale": o.scale = Int(next("")) ?? o.scale
        case "--mode": o.mode = SyntheticTTML.ScaleMode(rawValue: next("word")) ?? .word
        case "--load-timing": o.loadTiming = true
        case "--paused": o.paused = true
        case "--core": o.core = true
        case "--upstream": o.upstream = true
        case "--help", "-h":
            print(helpText)
            exit(0)
        default:
            if args[i].hasPrefix("-") { i += 1; continue }
            positionals.append(args[i])
        }
        i += 1
    }
    if positionals.first == "--decode-only" {
        o.decodeOnly = Array(positionals.dropFirst())
        return o
    }
    var cursor = 0
    if let s = positionals.first, !s.hasPrefix("-") {
        if o.scale == nil { o.file = s; cursor = 1 }
    }
    let rest = Array(positionals.dropFirst(cursor))
    if !rest.isEmpty { o.output = rest[0] }
    if rest.count > 1 { o.time = Double(rest[1]) }
    if rest.count > 2 { o.width = Double(rest[2]) ?? o.width }
    if rest.count > 3 { o.height = Double(rest[3]) ?? o.height }
    return o
}

// MARK: - 主流程

@MainActor private func run(_ o: Options) throws {
    if !o.decodeOnly.isEmpty {
        for path in o.decodeOnly {
            let url = URL(fileURLWithPath: path)
            do {
                let document = try TTMLDecoder().decode(Data(contentsOf: url))
                print("OK\t\(document.groups.count)\t\(String(format: "%.3f", document.duration))\t\(path)")
            } catch {
                print("ERR\t\(error.localizedDescription)\t\(path)")
            }
        }
        return
    }

    // 输入文档：显式文件，或生成的真实规模文档（默认 120 行 word）。
    let ttml: Data
    var sourceLabel: String
    if let file = o.file {
        ttml = try Data(contentsOf: URL(fileURLWithPath: file))
        sourceLabel = file
    } else {
        let lines = o.scale ?? 120
        ttml = Data(SyntheticTTML.scaled(lines: lines, mode: o.mode).utf8)
        sourceLabel = "generated:\(lines)-line/\(o.mode.rawValue)"
    }

    let output = URL(fileURLWithPath: o.output, isDirectory: true)
    try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
    _ = NSApplication.shared
    let view = LyricsView(frame: NSRect(x: 0, y: 0, width: o.width, height: o.height))
    view.automaticDisplayUpdates = false
    if o.core { view.configuration.surface = .coreReference }
    if o.upstream { view.configuration.profile = .upstream }

    let time = o.time ?? (o.scale != nil || o.file == nil ? 10 : 8)
    try view.load(ttml: ttml, time: o.paused ? time : 0, playing: !o.paused, hostTime: 0)

    var frames: [LyricsFrame] = []
    for tick in 0...Int((o.paused ? 3 : max(0, time)) * 120) {
        frames.append(view.render(at: Double(tick) / 120))
    }
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    try encoder.encode(frames).write(to: output.appendingPathComponent("trace.json"))
    try encoder.encode(view.diagnosticTimings).write(to: output.appendingPathComponent("timing.json"))
    if let image = view.snapshotImage(),
       let dest = CGImageDestinationCreateWithURL(output.appendingPathComponent("frame.png") as CFURL, UTType.png.identifier as CFString, 1, nil) {
        CGImageDestinationAddImage(dest, image, nil)
        guard CGImageDestinationFinalize(dest) else { throw LyricsError.invalidTTML("PNG export failed") }
    }

    // 装载计时（decode / install / 首帧），独立于渲染循环。
    var load: Measure.LoadTiming?
    if o.loadTiming {
        load = try Measure.loadTiming(ttml: ttml, width: o.width, height: o.height)
    }

    let stats = Measure.FrameStats(values: frames.dropFirst().map(\.renderMilliseconds))
    var summary: [String: Any] = [
        "tool": "MelismaKitProbe",
        "source": sourceLabel,
        "frames": frames.count,
        "groups": view.document?.groups.count ?? 0,
        "p50": stats.p50,
        "p95": stats.p95,
        "p99": stats.p99,
        "max": stats.max,
        "over8ms": stats.over8ms,
        "over16ms": stats.over16ms,
        "cacheBytes": frames.last?.glyphCacheBytes ?? 0,
        "output": output.path,
    ]
    if let load {
        summary["loadMilliseconds"] = [
            "decodeMS": load.decodeMS,
            "installMS": load.installMS,
            "firstRenderMS": load.firstRenderMS,
            "totalMS": load.totalMS,
        ]
    }
    let data = try JSONSerialization.data(withJSONObject: summary, options: .sortedKeys)
    FileHandle.standardOutput.write(data)
    FileHandle.standardOutput.write(Data([10]))
}

MainActor.assumeIsolated {
    do {
        try run(parseArgs())
    } catch {
        FileHandle.standardError.write(Data((error.localizedDescription + "\n").utf8))
        exit(1)
    }
}
