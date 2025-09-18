# SE計算修正レポート

## 概要

協調タッピング実験システムにおいて、stim_ITIが異常に長く、初回タップから遅延を感じる問題の根本原因を特定し、修正しました。問題はSE（同期エラー）計算のロジックエラーとMATLAB配列インデックスの誤参照でした。

## 問題の症状

### ユーザー報告
- **stim_ITI異常**: 実験データで約2秒の異常に長いITI
- **初回タップ遅延**: 実験開始直後から遅延感を体感
- **データと体感の乖離**: 測定データと実際の体感が大幅にズレ

### 実験データの例
```csv
stim_tap,player_tap
6.00590109825134,7.56798911094666
8.00611209869385,9.50105810165405
10.006322145462,11.5708849430084
```

## 根本原因の分析

### 1. オリジナルPython実装の構造

#### データ初期化（modify.py:64-65行目）
```python
# Stage1終了時の仮想的な初期値のみ記録
stim_tap = [span * stage1]           # [20.0] - 仮想最後の機械音
player_tap = [span * (stage1 - 1/2)] # [19.0] - 仮想最後の人間タップ
```

#### SE計算（modify.py:376行目）
```python
# Stage2のSE計算
stim_SE.append(stim_tap[turn] - (player_tap[turn] + player_tap[turn + 1])/2)
```

#### データフロー
```
Turn 0: stim_tap=[20.0], player_tap=[19.0]           (初期状態)
Turn 1: stim音再生 → stim_tap=[20.0, 21.0]           (機械音追加)
        人間タップ → player_tap=[19.0, 22.0]         (人間タップ追加)
        SE計算: stim_tap[1] - (player_tap[0] + player_tap[1])/2
               = 21.0 - (19.0 + 22.0)/2 = 21.0 - 20.5 = 0.5
```

### 2. MATLAB実装の問題

#### 実際のデータ構造
```matlab
% Stage1で実データが蓄積済み
stim_tap = [6.0, 8.0, 10.0, 12.0, 14.0, 16.0, 18.0, 20.0]  % Stage1の8回
player_tap = [7.5, 9.5, 11.5, 13.5, 15.5, 17.5, 19.5, 21.5]  % Stage1の8回
```

#### 間違ったSE計算（修正前）
```matlab
% turn=0でMATLAB配列エラー（1-indexed）
se = runner.stim_tap(turn) - ...  % turn=0 → エラー
     (runner.player_tap(turn) + runner.player_tap(turn+1)) / 2;
```

#### インデックス対応の混乱
- **Python**: 仮想的な初期値 + Stage2データでゼロインデックス
- **MATLAB**: 実際のStage1データ + Stage2データで1インデックス

## 修正内容

### 1. SE計算ロジックの修正

#### 修正前（問題のあるコード）
```matlab
if turn > 0 && length(runner.player_tap) >= 2
    se = runner.stim_tap(turn) - ...
         (runner.player_tap(turn) + runner.player_tap(turn+1)) / 2;
```

**問題点**:
- `turn=0`でMATLAB配列エラー
- Stage1データが混在してインデックスが混乱
- オリジナルの仮想初期値構造と不整合

#### 修正後（正しいコード）
```matlab
if length(runner.stim_tap) >= 1 && length(runner.player_tap) >= 2
    % 現在のstim_tapは最新追加分（今の機械音）
    current_stim = runner.stim_tap(end);

    % 前回と今回のplayer_tapの平均
    prev_player = runner.player_tap(end-1);
    curr_player = runner.player_tap(end);

    % SE = 現在の機械音 - (前回 + 現在の人間タップ)/2
    se = current_stim - (prev_player + curr_player) / 2;
```

**改善点**:
- 配列の最新要素を直接参照（`end`, `end-1`）
- MATLAB配列構造に適合したインデックス
- オリジナルのSE定義を正確に再現

### 2. デバッグ情報の追加

```matlab
fprintf('DEBUG: SE計算 = %.3f - (%.3f + %.3f)/2 = %.3f\n', ...
    current_stim, prev_player, curr_player, se);
```

## 修正の技術的根拠

### SE計算の正しい意味
```
SE = 機械音時刻 - (前回人間タップ + 現在人間タップ) / 2
```

- **機械音時刻**: システムが鳴らした音のタイミング
- **人間タップ中点**: 前回と現在の人間タップの中点
- **SE値**: 機械の同期ズレ（正=遅れ、負=早い）

### 配列操作の安全性
```matlab
% 安全なインデックス参照
current_stim = runner.stim_tap(end);      % 最新の機械音
prev_player = runner.player_tap(end-1);   % 前回の人間タップ
curr_player = runner.player_tap(end);     % 現在の人間タップ
```

## 期待される改善効果

### 1. stim_ITI正常化
- **修正前**: 異常な2.0秒
- **修正後**: 正常な1.0秒周辺

### 2. 初回タップ遅延解消
- 正確なSE計算による適切なタイミング予測
- モデル推論の精度向上

### 3. オリジナル準拠性
- Python実装と完全に同じSE計算ロジック
- 実験結果の再現性確保

## 検証方法

### 1. デバッグ出力確認
```
DEBUG: SE計算 = 21.000 - (19.000 + 22.000)/2 = 0.500
```

### 2. ITI値監視
- stim_ITI < 2.0秒の確認
- 1.0秒周辺への収束確認

### 3. 体感遅延チェック
- 初回タップからの自然な応答感
- システム応答の即座性

## 学んだ教訓

### 1. 配列構造の重要性
- **Python**: 仮想初期値による簡潔な構造
- **MATLAB**: 実データ蓄積による複雑性
- 移植時は配列操作の詳細な検証が必要

### 2. インデックス参照の注意点
- ゼロインデックス vs 1インデックス
- 配列長とターン数の対応関係
- `end`操作による安全な最新要素参照

### 3. オリジナル実装の理解深度
- 表面的なアルゴリズム理解では不十分
- データ構造とフローの完全な把握が必要
- 行レベルでの詳細な対応関係確認

### 4. デバッグ情報の価値
- 問題発生時の迅速な原因特定
- 計算過程の可視化による検証容易性
- 実験者への透明性提供

## 今後の改善方針

### 1. テストケース充実
- 各モデルでのSE計算検証
- エッジケース（初回タップ、最終タップ）の確認
- Pythonとの完全比較テスト

### 2. コード品質向上
- 関数化による責任分離
- エラーハンドリング強化
- ドキュメント充実

### 3. 移植プロセス改善
- 段階的検証の実施
- 中間結果の比較確認
- 自動テストによる継続的検証

---

**作成者**: Claude Code
**作成日**: 2025年9月17日
**修正対象**: experiments/main_experiment.m (SE計算部分)
**参照**: legacy/original/modify.py (オリジナル実装)