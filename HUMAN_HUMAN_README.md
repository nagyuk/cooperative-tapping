# 人間同士協調タッピング実験システム

PsychPortAudioを使用した高精度な2プレイヤー協調タッピング実験システム

## 概要

このシステムは、2人の参加者が交互にキーをタップすることで、協調的なリズム生成能力を研究するための実験プログラムです。

## システム要件

- MATLAB R2025a以降
- PsychToolbox 3.0.22以降（プロジェクトに同梱）
- Scarlett 4i4オーディオインターフェース（推奨）
  - 左チャンネル: Player 1用音声
  - 右チャンネル: Player 2用音声

## セットアップ

### 1. PsychToolboxセットアップ（初回のみ）

```matlab
setup_psychtoolbox
```

### 2. オーディオハードウェア設定

1. Scarlett 4i4をUSB接続
2. ヘッドフォン/イヤフォンを接続:
   - Output 1 (左): Player 1用
   - Output 2 (右): Player 2用

### 3. 実験実行

```matlab
run_human_human
```

## 実験構成

### Stage 1: メトロノームフェーズ

- **目的**: 両プレイヤーが1.0秒間隔のリズムを学習
- **動作**: 正確な1秒間隔でメトロノーム音が再生
- **操作**:
  - Player 1: Sキーでタップ
  - Player 2: Cキーでタップ
- **デフォルト**: 10ビート

### Stage 2: 協調タッピングフェーズ

- **目的**: プレイヤー間の協調的リズム生成を測定
- **動作**:
  - Player 1からスタート
  - 相手がタップすると自分の耳に刺激音が聞こえる
  - Player 1: 左耳の音に合わせてSキー
  - Player 2: 右耳の音に合わせてCキー
- **デフォルト**: 20サイクル（40タップ）

## キー操作

- **Player 1**: `S` キー
- **Player 2**: `C` キー
- **開始**: `Space` キー
- **中断**: `Escape` キー

## データ出力

実験データは以下のディレクトリに保存されます：

```
data/raw/YYYYMMDD/[participant]_human_human_[timestamp]/
├── experiment_data.mat              # MATLAB形式の完全データ
├── stage1_metronome.csv             # Stage1メトロノームタイムスタンプ
└── stage2_cooperative_taps.csv      # Stage2タップデータ
```

### Stage 2データ形式

`stage2_cooperative_taps.csv`:
- **PlayerID**: タップしたプレイヤー (1 or 2)
- **TapTime**: タップ時刻（秒、実験開始からの経過時間）
- **CycleNumber**: サイクル番号

## 技術仕様

### オーディオシステム

- **バックエンド**: PsychPortAudio
- **遅延クラス**: 2 (低遅延モード)
- **サンプリングレート**: 22.05kHz
- **出力**: ステレオ (2チャンネル)
- **推定遅延**: ~7ms (Scarlett 4i4使用時)

### タイミング精度

- **時刻参照**: `posixtime(datetime('now'))`
- **ポーリング間隔**: 1ms
- **キー入力デバウンス**: 50ms

### ステレオ分離

- **Player 1刺激音**: 左チャンネルのみ (`[sound, zeros]`)
- **Player 2刺激音**: 右チャンネルのみ (`[zeros, sound]`)
- **メトロノーム**: 両チャンネル (`[sound, sound]`)

## 主要ファイル

- `run_human_human.m` - エントリーポイント
- `human_human_experiment.m` - メイン実験システム
- `assets/sounds/stim_beat_optimized.wav` - 最適化済み刺激音

## カスタマイズ

`human_human_experiment.m`内のパラメータ編集：

```matlab
runner.stage1_beats = 10;      % Stage1ビート数
runner.stage2_cycles = 20;     % Stage2サイクル数
runner.target_interval = 1.0;  % 目標間隔（秒）
```

## トラブルシューティング

### PsychToolboxが認識されない

```matlab
setup_psychtoolbox
```

### Scarlett 4i4が検出されない

1. USB接続を確認
2. macOSのサウンド設定で認識されているか確認
3. MATLABを再起動

### 音が聞こえない

```matlab
% PsychPortAudio再初期化
InitializePsychSound(1);
```

### タイミング精度の確認

```matlab
GetSecs  % 現在時刻を返す（動作確認）
```

## 実験結果分析

実験終了後、自動的に以下の統計が表示されます：

- **Stage 1**: プレイヤー別タップ数、平均間隔、標準偏差
- **Stage 2**: 総タップ数、平均間隔、標準偏差、協調精度、交互性チェック

## 開発履歴

- **2025-10-07**: PsychPortAudioベース実装完成
  - ステレオ2チャンネル対応
  - 高精度タイミングシステム
  - グローバル変数による入力管理

## ライセンス

このプロジェクトはCLAUDE.mdに記載されたガイドラインに従います。
