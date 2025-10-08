# 協調タッピング実験システム v2.0 - 統合OOPアーキテクチャ

OOPベースの統合実験システム。人間-コンピュータ実験と人間-人間実験を共通基盤で管理。

## 🎯 概要

このシステムは、複数の実験タイプを統合管理するためのオブジェクト指向アーキテクチャです。

### サポートする実験タイプ

1. **人間-コンピュータ実験** (実装予定)
   - SEA (Synchronization Error Averaging)
   - Bayesian推論モデル
   - BIB (Bayesian-Inverse Bayesian)

2. **人間-人間協調実験** ✅ (実装済み)
   - 2人の参加者による交互タッピング
   - 協調的リズム生成研究

## 🏗️ システムアーキテクチャ

```
cooperative-tapping/
├── run_unified_experiment.m     # 統合エントリーポイント
├── core/                        # コアシステム（全実験共通）
│   ├── BaseExperiment.m         # 抽象基底クラス
│   ├── audio/
│   │   └── AudioSystem.m        # PsychPortAudio管理
│   ├── timing/
│   │   └── TimingController.m   # 高精度タイミング制御
│   └── data/
│       └── DataRecorder.m       # データ記録・保存
├── experiments/                 # 実験タイプ別実装
│   ├── human_computer/
│   │   ├── HumanComputerExperiment.m  # (TODO)
│   │   └── models/
│   │       ├── SEAModel.m
│   │       ├── BayesianModel.m
│   │       └── BIBModel.m
│   └── human_human/
│       └── HumanHumanExperiment.m     # ✅ 実装済み
├── ui/                          # UI共通コンポーネント
├── utils/                       # ユーティリティ
└── config/                      # 設定ファイル
```

## 🚀 クイックスタート

### 前提条件

- MATLAB R2025a以降
- PsychToolbox 3.0.22以降（同梱）
- Scarlett 4i4オーディオインターフェース（推奨）

### 実験実行

```matlab
% 統合システムから実験選択
run_unified_experiment
```

実験タイプを選択:
1. 人間-コンピュータ実験（実装予定）
2. 人間-人間協調実験 ✅

## 📚 クラス設計

### 1. BaseExperiment（抽象基底クラス）

全実験タイプの共通機能を提供:

```matlab
classdef (Abstract) BaseExperiment < handle
    properties
        audio          % AudioSystemインスタンス
        timer          % TimingControllerインスタンス
        recorder       % DataRecorderインスタンス
    end

    methods (Abstract)
        run_stage1(obj)
        run_stage2(obj)
    end

    methods
        execute(obj)   % 実験実行メインフロー
    end
end
```

### 2. AudioSystem

PsychPortAudio統合管理:

```matlab
audio = AudioSystem('channels', 4);
sound = audio.load_sound_file('path/to/sound.wav');
buffer = audio.create_buffer(sound, [1,1,0,0]);  % 出力1/2のみ
audio.play_buffer(buffer);
```

**主な機能:**
- Scarlett 4i4自動検出
- 4チャンネルバッファ作成
- チャンネルマスク指定（例: `[1,1,0,0]` = 出力1/2のみ）

### 3. TimingController

高精度タイミング制御:

```matlab
timer = TimingController();
timer.start();                              % クロック開始
elapsed = timer.get_elapsed_time();         % 経過時間取得
timer.wait_until(5.0);                      % 5秒まで待機
schedule = timer.create_schedule(0.5, 1.0, 10);  % スケジュール作成
```

**特徴:**
- posixtime()による統一時刻参照
- 1msポーリングによる高精度待機
- イベントスケジューリング

### 4. DataRecorder

データ記録・保存:

```matlab
recorder = DataRecorder('human_human', {'P001', 'P002'});
recorder.record_stage1_event(timestamp, 'type', 'metronome');
recorder.record_stage2_tap(player_id, timestamp, 'cycle', 1);
recorder.save_data();
```

**保存形式:**
```
data/raw/human_human/20251008/P001_P002_human_human_20251008_143022/
├── experiment_data.mat
├── stage1_metronome.csv
└── stage2_cooperative_taps.csv
```

### 5. HumanHumanExperiment

人間-人間協調実験実装:

```matlab
classdef HumanHumanExperiment < BaseExperiment
    methods (Access = protected)
        function run_stage1(obj)
            % Stage1: メトロノームフェーズ
        end

        function run_stage2(obj)
            % Stage2: 協調タッピングフェーズ
        end
    end
end
```

## 🔧 実験フロー

### 共通フロー（BaseExperiment.execute()）

```
1. システム初期化
   ├── AudioSystem初期化
   ├── TimingController初期化
   ├── DataRecorder初期化
   └── 入力ウィンドウ作成

2. 実験説明表示

3. Stage 1実行（サブクラス実装）

4. Stage 2実行（サブクラス実装）

5. データ保存
   ├── MAT形式
   └── CSV形式

6. 結果表示

7. クリーンアップ
   ├── AudioSystem クローズ
   └── ウィンドウ削除
```

### 人間-人間実験フロー

**Stage 1: メトロノームフェーズ**
- 両プレイヤーが両方の音を聞く
- Player1音とPlayer2音が0.5秒間隔で交互再生
- 1秒間隔のリズムを学習

**Stage 2: 協調タッピングフェーズ**
- Player1がSキーでタップ → Player2にPlayer1音が聞こえる
- Player2がCキーでタップ → Player1にPlayer2音が聞こえる
- 20サイクル繰り返し

## 🎨 カスタマイズ

### 新しい実験タイプの追加

1. `BaseExperiment`を継承
2. `run_stage1()`, `run_stage2()`を実装
3. `run_unified_experiment.m`に選択肢を追加

```matlab
classdef MyExperiment < BaseExperiment
    properties (Access = protected)
        experiment_type = 'my_experiment'
    end

    methods (Access = protected)
        function run_stage1(obj)
            % Stage1実装
        end

        function run_stage2(obj)
            % Stage2実装
        end
    end
end
```

### パラメータ調整

BaseExperiment継承クラスのプロパティを変更:

```matlab
obj.stage1_beats = 15;        % Stage1ビート数
obj.stage2_cycles = 30;       % Stage2サイクル数
obj.target_interval = 0.8;    % 目標間隔（秒）
```

## 📊 データ出力

### MAT形式

```matlab
load('experiment_data.mat');
% data_to_save構造体:
%   - experiment_type
%   - participant_ids
%   - experiment_start_time
%   - data
%     - stage1_data (struct array)
%     - stage2_data (struct array)
%     - metadata
```

### CSV形式

**stage1_metronome.csv:**
| timestamp | sound_type |
|-----------|------------|
| 0.501     | 1          |
| 1.002     | 2          |

**stage2_cooperative_taps.csv:**
| player_id | timestamp | cycle |
|-----------|-----------|-------|
| 1         | 10.523    | 1     |
| 2         | 11.234    | 1     |

## 🔬 技術仕様

### オーディオシステム
- **サンプリングレート**: 22.05kHz
- **遅延クラス**: 2（低遅延モード）
- **チャンネル数**: 4
- **推定遅延**: ~7ms (Scarlett 4i4)

### タイミング精度
- **時刻参照**: posixtime()
- **ポーリング間隔**: 1ms
- **精度**: サブミリ秒

## 🚧 TODO

- [ ] HumanComputerExperimentクラス実装
- [ ] モデルクラス実装（SEA, Bayesian, BIB）
- [ ] WindowDisplayクラス実装（UI統一）
- [ ] 設定ファイルシステム
- [ ] ユニットテスト
- [ ] パフォーマンス最適化

## 📖 開発履歴

**2025-10-08: v2.0 統合OOPシステム構築**
- BaseExperiment抽象クラス設計
- AudioSystem, TimingController, DataRecorderコアクラス実装
- HumanHumanExperiment実装
- 統合エントリーポイント作成

## 🎓 設計原則

1. **DRY (Don't Repeat Yourself)**
   - 共通機能をコアクラスに集約

2. **単一責任原則**
   - 各クラスは明確な単一の責任を持つ

3. **開放閉鎖原則**
   - 拡張に開いており、修正に閉じている

4. **依存性逆転原則**
   - 抽象（BaseExperiment）に依存、具象に依存しない

## 📝 ライセンス

CLAUDE.mdに記載されたガイドラインに従います。

---

**Status**: 🚧 開発中（Phase 1完了）
- ✅ コアシステム実装完了
- ✅ HumanHuman実験実装完了
- ⏳ HumanComputer実験実装予定
