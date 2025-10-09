# 実験設定システム

ExperimentConfigクラスを使用して、実験パラメータを柔軟に設定できます。

## 使用方法

### 1. プリセット設定を使用

```matlab
% デフォルト設定
exp = HumanHumanExperiment('default');

% パイロット実験用設定
exp = HumanHumanExperiment('pilot');

% 本実験用設定
exp = HumanHumanExperiment('main');
```

### 2. カスタム設定を対話的に作成

```matlab
% カスタム設定モード（対話的に入力）
exp = HumanHumanExperiment('custom');

% 各パラメータを入力
% Stage1ビート数 [デフォルト: 10]: 15
% Stage2サイクル数 [デフォルト: 20]: 25
% ...
```

### 3. 設定オブジェクトを事前に作成

```matlab
% 設定を作成
config = ExperimentConfig();
config.stage1_beats = 12;
config.stage2_cycles = 25;
config.enable_practice = true;
config.practice_cycles = 3;

% 設定を表示
config.display_config();

% 実験に渡す
exp = HumanHumanExperiment(config);
```

### 4. 設定を保存・読み込み

```matlab
% 設定を保存
config = ExperimentConfig('pilot');
config.save_config();  % 自動でファイル名生成
% または
config.save_config('my_config.mat');

% 設定を読み込み
config = ExperimentConfig.load_from_file('my_config.mat');
exp = HumanHumanExperiment(config);
```

---

## プリセット設定の詳細

### デフォルト設定 ('default')

従来の標準的な設定値。

```
Stage1ビート数: 10
Stage2サイクル数: 20
目標タップ間隔: 1.0秒

練習試行: 無効
デバッグ: 無効
```

### パイロット実験用 ('pilot')

短時間で完了し、詳細なログを出力。

```
Stage1ビート数: 10
Stage2サイクル数: 15  ← 短め
目標タップ間隔: 1.0秒

練習試行: 有効（5サイクル）
デバッグ: 有効（詳細ログ）
```

**推奨用途**:
- 実験プロトコルの検証
- 参加者へのデモンストレーション
- データ収集システムのテスト

### 本実験用 ('main')

統計的検出力を確保するための設定。

```
Stage1ビート数: 10
Stage2サイクル数: 30  ← 長め
目標タップ間隔: 1.0秒

練習試行: 無効
デバッグ: 無効
```

**推奨用途**:
- パイロット実験完了後の本実験
- 論文用データ収集

---

## パラメータ一覧

### 実験設計パラメータ

| パラメータ | デフォルト | 説明 | 推奨範囲 |
|-----------|-----------|------|---------|
| `stage1_beats` | 10 | Stage1のビート数 | 5-50 |
| `stage2_cycles` | 20 | Stage2のサイクル数 | 5-100 |
| `target_interval` | 1.0 | 目標タップ間隔（秒） | 0.3-3.0 |

**Stage2サイクル数の目安**:
- パイロット実験: 10-15（約15-20秒、疲労軽減）
- 本実験: 20-30（約30-45秒、十分なデータ）

### モデルパラメータ（Human-Computer実験用）

| パラメータ | デフォルト | 説明 | 推奨範囲 |
|-----------|-----------|------|---------|
| `SPAN` | 2.0 | 目標サイクル期間（秒） | 0.5-5.0 |
| `SCALE` | 0.02 | ランダム変動スケール | 0.001-1.0 |
| `BAYES_N_HYPOTHESIS` | 20 | ベイズ仮説数 | 10-50 |
| `BIB_L_MEMORY` | 1 | BIBメモリ長 | 1-10 |

**注意**: これらの値はパイロット実験後に更新予定（Human-Humanデータに基づく）。

### 実験フロー設定

| パラメータ | デフォルト | 説明 |
|-----------|-----------|------|
| `enable_practice` | false | 練習試行を実施するか |
| `practice_cycles` | 5 | 練習試行のサイクル数 |

**練習試行の使用**:
- パイロット実験: 有効推奨（参加者の理解度確認）
- 本実験: 無効推奨（参加者は既に経験済み）

### デバッグ設定

| パラメータ | デフォルト | 説明 |
|-----------|-----------|------|
| `DEBUG_MODEL` | false | モデルの詳細ログを出力 |
| `DEBUG_TIMING` | false | タイミングの詳細ログを出力 |

---

## 実用例

### 例1: パイロット実験の実施

```matlab
% パイロット設定で実験
clear classes; rehash toolboxcache

exp = HumanHumanExperiment('pilot');
exp.execute();

% 結果:
% - Stage2: 15サイクル（短め）
% - 練習試行あり
% - 詳細ログ出力
```

### 例2: 本実験の実施

```matlab
% 本実験設定
clear classes; rehash toolboxcache

exp = HumanHumanExperiment('main');
exp.execute();

% 結果:
% - Stage2: 30サイクル（十分なデータ）
% - 練習試行なし
% - ログ最小限
```

### 例3: カスタム設定でテスト

```matlab
% 短時間テスト用の設定
config = ExperimentConfig('default');
config.stage1_beats = 5;   % 短縮
config.stage2_cycles = 10; % 短縮
config.DEBUG_TIMING = true;

exp = HumanHumanExperiment(config);
exp.execute();
```

### 例4: 設定の保存と再利用

```matlab
% セッション1: 設定を作成・保存
config = ExperimentConfig('custom');
% ... 対話的に設定 ...
config.save_config('experiments/configs/saved/my_pilot_config.mat');

% セッション2: 保存した設定を使用
config = ExperimentConfig.load_from_file('experiments/configs/saved/my_pilot_config.mat');
exp = HumanHumanExperiment(config);
exp.execute();
```

---

## 設定の妥当性検証

ExperimentConfigは自動的にパラメータを検証します：

```matlab
config = ExperimentConfig('default');
config.stage2_cycles = 150;  % 範囲外（推奨: 5-100）

% 警告が表示される:
% ⚠️  設定の検証で警告が見つかりました:
%   1. stage2_cycles=150 は範囲外です（推奨: 5-100）
% 続行しますか？ (y/n):
```

---

## トラブルシューティング

### 問題: ExperimentConfig not found

**原因**: パスが設定されていない

**解決**:
```matlab
addpath('experiments/configs')
```

### 問題: 設定が反映されない

**原因**: MATLABのクラスキャッシュ

**解決**:
```matlab
clear classes
rehash toolboxcache
```

### 問題: 保存した設定が読み込めない

**原因**: ファイルパスが間違っている

**解決**:
```matlab
% 絶対パスで確認
config = ExperimentConfig.load_from_file(fullfile(pwd, 'experiments/configs/saved/my_config.mat'));
```

---

## ベストプラクティス

### 1. プリセットを基本に

最初はプリセット設定を使用し、必要に応じてカスタマイズ：

```matlab
% まずプリセットで試す
exp = HumanHumanExperiment('pilot');

% 問題なければ本実験へ
exp = HumanHumanExperiment('main');
```

### 2. 重要な設定は保存

パイロット実験で最適化した設定は保存して再利用：

```matlab
config = ExperimentConfig('pilot');
config.stage2_cycles = 18;  % パイロットで最適と判明
config.save_config('experiments/configs/saved/optimized_pilot.mat');
```

### 3. 設定の記録

実験ごとに使用した設定をログに記録：

```matlab
exp = HumanHumanExperiment('main');
exp.config.display_config();  % 設定を表示
% この出力を実験ノートに記録
```

### 4. パラメータの段階的変更

一度に多くのパラメータを変えない：

```matlab
% 良い例: 1つずつ変更
config = ExperimentConfig('default');
config.stage2_cycles = 25;  % これだけ変更
```

---

## 今後の拡張予定

- [ ] Human-Humanデータに基づくモデルパラメータの更新
- [ ] 参加者特性に応じた動的調整
- [ ] GUI設定エディタ
- [ ] 実験履歴の自動記録

---

**作成日**: 2025-10-09
**最終更新**: 2025-10-09
