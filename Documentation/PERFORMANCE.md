# MelismaKit 性能基线（Phase 0 快照）

> 本文档是 Phase 0（P0-6）的产出：记录装载与帧耗时基线数字、复现命令与 CI 阈值护栏依据。
> **所有数字均为 Release 构建实测。** 测量工具：`MelismaKitBench`（`swift run -c release MelismaKitBench --scale N --mode M`）。

## 1. 目的与边界

- 基线是后续所有性能改动的**唯一裁判**（ROADMAP §0.1 执行纪律第 3 条）。
- 数字是**量级参照**，不是与机器无关的绝对性能断言：同一台机器、不同系统负载下，
  无字体缓存的装载路径（`NSFontManager.availableMembers(ofFontFamily:)` 每次全量查询）
  会产生数倍波动 —— 这正是审计 HIGH 项（Phase 2 要修）的体现。
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

| 文档 | 行数 | 审计实测（0.1.4 快照） | Phase 0 复测（2026-09-12） | 复测波动范围 |
|---|---|---|---|---|
| 合成（word） | 120 | decode 17.5–26.1 / load 520.6–926.5 | decode 9.6 / install 194.3 / 总计 203.9 | 总计 104–786 |
| 合成（word） | 400 | decode 74.7–151.0 / load 881.1–1640.6 | decode 28.3 / install 190.7 / 总计 218.9 | — |
| ruby | 120 | decode 20.0 / load 561.8 | decode 11.5 / install 175.3 / 总计 186.9 | — |
| line-timed | 120 | decode 13.0 / load 267.2 | decode 3.1 / install 111.1 / 总计 114.1 | — |
| 长词压力（longWord） | 120 | decode 15.3 / load 1412.5 | decode 5.5 / install 1195.3 / 总计 1200.8 | — |

- `install` 即 §2.2 的「布局占比」主体：120 行 word 中 install 占总计 95%+。
- 装载阻塞（审计 HIGH，Phase 2 目标）：真实播放器切歌冻结 0.27–1.64 s 即来自 `install`。

## 4. 稳态帧基线（毫秒，丢首帧，n=1200）

| 文档 | p50 | p95 | p99 | max | >8.33ms | >16.67ms |
|---|---|---|---|---|---|---|
| 120 行 word（Phase 0 复测） | 0.362 | 0.446 | 0.606 | 1.512 | 0 | 0 |
| 120 行 word（审计 0.1.4） | 0.465 | 1.468 | 3.783 | 8.16 | 0/1200 | 0 |
| 400 行 word | 0.573 | 1.284 | 1.852 | 2.808 | 0 | 0 |
| 120 行 ruby | 0.313 | 0.392 | 0.579 | 1.431 | 0 | 0 |
| 120 行 line-timed | 0.112 | 0.231 | 0.399 | 3.343 | 0 | 0 |
| 120 行 longWord | 4.926 | 8.774 | 12.004 | 72.686 | 79 | 5 |
| bundled complex（8 行，Probe 默认，审计） | 0.244 | 1.195 | 3.173 | 9.14 | 1/1200 | 0 |

- 长词压力行是刻意构造的极端路径（每行一个 360+ 字符超长单词），数字劣化属预期，用作回归锚点。
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

| 指标 | 基线（2026-09-12） | 阈值 | 余量 |
|---|---|---|---|
| installMS | 103–751 | 4000 | 5–40× |
| frameP50 | 0.36–0.86 | 50 | 60–140× |
| frameP99 | 0.61–5.34 | 100 | 20–160× |
| frameMax | 1.5–9.4 | 600 | 60–400× |
| >8.33ms 帧数 | 0–1 | 900 | — |
| >16.67ms 帧数 | 0 | 300 | — |

验证方式：把单行布局人为拖慢 40×（install → ~5.5 s）时门禁报红（exit 1）。
`reflowBatchLimit` 改为 1 **不会**触发门禁：它只影响 seek/焦点切换后的增量布局路径，
10 秒连续播放测量不覆盖该路径 —— 该交互路径的护栏留给 Phase 4 正式化（P4-8）。

## 7. 已知事项

- **波动**：装载数字随系统负载波动数倍（无字体缓存所致）。Phase 2（P2-1..P2-4）引入
  字体缓存后应收敛；届时需按本文档第 5 节复测并更新本快照。
- 审计的 Instruments 汇总脚本（`script/summarize_profile.py`）仍适用于宿主侧验证。
