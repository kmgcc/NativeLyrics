# MelismaKit 性能基线（Phase 0 快照 / Phase 2 复测）

> 本文档是 Phase 0（P0-6）的产出：记录装载与帧耗时基线数字、复现命令与 CI 阈值护栏依据；
> Phase 2（P2-4）在其上复测并记录字体/度量缓存后的收敛结果。
> **所有数字均为 Release 构建实测。** 测量工具：`MelismaKitBench`（`swift run -c release MelismaKitBench --scale N --mode M`）。

## 1. 目的与边界

- 基线是后续所有性能改动的**唯一裁判**（ROADMAP §0.1 执行纪律第 3 条）。
- 数字是**量级参照**，不是与机器无关的绝对性能断言。
- **Phase 0 快照（改动前）**：无字体缓存的装载路径（`NSFontManager.availableMembers(ofFontFamily:)`
  每次全量查询）会产生数倍波动 —— 这正是审计 HIGH 项（Phase 2 要修）的体现。
- **Phase 2 复测（P2-1..P2-3 之后）**：字体解析与文本度量按 key 缓存，`availableMembers`
  每个 family 只查询一次；装载时间收敛到稳定低位（见 §3/§4 对比）。
- 帧耗时统计口径：120fps 渲染 10 秒（1200 帧），**丢弃首帧**（首帧含装载布局），
  nearest-rank 百分位，`>8.33ms` / `>16.67ms` 为超预算帧数。

## 2. 环境

| 项 | 值 |
|---|---|
| 机器 | Apple Silicon（arm64） |
| 系统 | macOS 26.6.2 |
| 工具链 | Xcode 26.6 / Swift 6.3.3 |
| 构建 | `swift build -c release`（零警告） |
| 视口 | 760×720（`--width/--height` 可调） |

## 3. 装载基线（decode / install / 总计，毫秒）

| 文档 | 行数 | 审计实测（0.1.4 快照） | Phase 0 复测（2026-09-12） | Phase 2 复测（2026-09-12，P2-1..P2-3 后） |
|---|---|---|---|---|
| 合成（word） | 120 | decode 17.5–26.1 / load 520.6–926.5 | decode 9.6 / install 194.3 / 总计 203.9 | decode 11.5–14.5 / install 46–59 / 总计 61–74 |
| 合成（word） | 400 | decode 74.7–151.0 / load 881.1–1640.6 | decode 28.3 / install 190.7 / 总计 218.9 | decode 28–34 / install 44–52 / 总计 72–86 |
| ruby | 120 | decode 20.0 / load 561.8 | decode 11.5 / install 175.3 / 总计 186.9 | decode 10.9 / install 94.7 / 总计 105.6 |
| line-timed | 120 | decode 13.0 / load 267.2 | decode 3.1 / install 111.1 / 总计 114.1 | decode 3.1 / install 35.7 / 总计 38.8 |
| 长词压力（longWord） | 120 | decode 15.3 / load 1412.5 | decode 5.5 / install 1195.3 / 总计 1200.8 | decode 5.6 / install 132.0 / 总计 137.6 |

- `install` 即 §2.2 的「布局占比」主体：120 行 word 中 install 占总计 95%+。
- 装载阻塞（审计 HIGH，Phase 2 目标）：Phase 0 复测中真实播放器切歌冻结 0.27–1.64 s 即来自 `install`；
  Phase 2 复测收敛到 35–132 ms，其中长词压力路径（P2-2 直接受益者，逐字符字体解析改为按 run 复用）
  从 ~1.2 s 降到 ~0.13 s（约 9×）。

## 4. 稳态帧基线（毫秒，丢首帧，n=1200）

| 文档 | p50 | p95 | p99 | max | >8.33ms | >16.67ms |
|---|---|---|---|---|---|---|
| 120 行 word（Phase 2 复测） | 0.42–0.43 | 0.81–0.84 | 1.26–1.49 | 2.7–3.1 | 0 | 0 |
| 120 行 word（Phase 0 复测） | 0.362 | 0.446 | 0.606 | 1.512 | 0 | 0 |
| 120 行 word（审计 0.1.4） | 0.465 | 1.468 | 3.783 | 8.16 | 0/1200 | 0 |
| 400 行 word（Phase 2 复测） | 0.60–0.67 | 1.04–1.53 | 1.54–2.28 | 2.2–12.7 | 0–4 | 0 |
| 400 行 word（Phase 0 复测） | 0.573 | 1.284 | 1.852 | 2.808 | 0 | 0 |
| 120 行 ruby（Phase 2 复测） | 0.322 | 0.533 | 1.009 | 1.680 | 0 | 0 |
| 120 行 ruby（Phase 0 复测） | 0.313 | 0.392 | 0.579 | 1.431 | 0 | 0 |
| 120 行 line-timed（Phase 2 复测） | 0.114 | 0.276 | 0.495 | 1.317 | 0 | 0 |
| 120 行 line-timed（Phase 0 复测） | 0.112 | 0.231 | 0.399 | 3.343 | 0 | 0 |
| 120 行 longWord（Phase 2 复测） | 5.098 | 8.231 | 11.057 | 46.441 | 59 | 2 |
| 120 行 longWord（Phase 0 复测） | 4.926 | 8.774 | 12.004 | 72.686 | 79 | 5 |
| bundled complex（8 行，Probe 默认，审计） | 0.244 | 1.195 | 3.173 | 9.14 | 1/1200 | 0 |

- 长词压力行是刻意构造的极端路径（每行一个 360+ 字符超长单词），数字劣化属预期，用作回归锚点；
  Phase 2 后超预算帧数进一步下降（79→59）。
- 每 glyph layer 每帧约 10 µs，只发生在**正在动画的那一行**（`LayerRenderer` 的 `inkKey`
  每帧变化导致每 glyph 重建 9 个 `CGColor`）—— 审计观察，未修改。

## 5. 复现命令

```sh
# 五档基线（Release）
swift run -c release MelismaKitBench --scale 120 --mode word
swift run -c release MelismaKitBench --scale 400 --mode word
swift run -c release MelismaKitBench --scale 120 --mode ruby
swift run -c release MelismaKitBench --scale 120 --mode line
swift run -c release MelismaKitBench --scale 120 --mode longWord

# 机器可读 JSON（CI 门禁输入）
swift run -c release MelismaKitBench --scale 120 --json

# Probe 等价口径（文件或生成文档，--load-timing 报告装载三段）
swift run -c release MelismaKitProbe --scale 120 --load-timing /tmp/probe 10 760 720
```

## 6. CI 阈值护栏（P0-7，`script/bench_gate.py`）

门禁输入：`MelismaKitBench --scale 120 --json`（word 模式，CI 上 Release 构建）。

| 指标 | 基线（2026-09-12） | Phase 2 后实测 | 阈值 | 余量 |
|---|---|---|---|
| installMS | 103–751（改动前） | 46–95 | 4000 | 40–85× |
| frameP50 | 0.36–0.86 | 0.42 | 50 | 115× |
| frameP99 | 0.61–5.34 | 1.49 | 100 | 65× |
| frameMax | 1.5–9.4 | 2.7–3.1 | 600 | 190–220× |
| >8.33ms 帧数 | 0–1 | 0 | 900 | — |
| >16.67ms 帧数 | 0 | 0 | 300 | — |

验证方式：把单行布局人为拖慢 40×（install → ~5.5 s）时门禁报红（exit 1）。
`reflowBatchLimit` 改为 1 **不会**触发门禁：它只影响 seek/焦点切换后的增量布局路径，
10 秒连续播放测量不覆盖该路径 —— 该交互路径的护栏留给 Phase 4 正式化（P4-8）。

## 7. 已知事项

- **波动（Phase 0 观察，已收敛）**：改动前装载数字随系统负载波动数倍（无字体缓存所致，
  `availableMembers` 每次全量查询）。Phase 2 引入字体/度量缓存后，装载收敛到稳定低位
  （120 行 word 多轮实测 46–59 ms，波动从数倍收窄到 ±15% 以内）。
- **装载内剩余热点**（Phase 2 后，量级已不构成阻塞）：120 行 word 的 `install` 仍有 46–59 ms，
  主体是首次装载的 Core Text 整形与 glyph 位图缓存构建；`decode` 在 400 行时占 28–34 ms
  （TTML 解析，未优化，见 ROADMAP Phase 4）。若未来需要进一步压缩首帧耗时，可评估
  P2-5（分批首次装载），当前同步路径已足够快，暂不引入首帧不完整的复杂度。
- 审计的 Instruments 汇总脚本（`script/summarize_profile.py`）仍适用于宿主侧验证。
