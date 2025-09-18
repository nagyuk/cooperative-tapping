# オリジナル実装分析ドキュメント

## 概要

協調タッピング実験システムのオリジナル実装（legacy/original/）の詳細分析とMATLAB移植のためのリファレンスドキュメントです。

## ファイル構成

### 実験プログラム
1. **modify.py** - SEAモデル（Synchronization Error Averaging）
2. **bayes0.py** - Bayesianモデル（l_memory=0の標準ベイズ推論）
3. **bayes1.py** - BIBモデル（l_memory=1のBayesian-Inverse Bayesian）

### 共通モジュール
4. **bayes.py** - ContBayesクラス定義（Bayesian/BIB推論エンジン）

### 音声ファイル
5. **button02a.mp3** - 刺激音（機械音）
6. **button03a.mp3** - プレイヤー音（人間タップ音）

## 共通実験パラメータ

```python
# 全モデル共通設定
span = 2           # 基準間隔（秒）- Stage1は2秒間隔、Stage2は1秒間隔
stage1 = 10        # Stage1タップ数
stage2 = 100       # Stage2タップ数
buffer = 10        # 解析から除外するデータ数（前後10個ずつ）
scale = 0.1        # ランダム変動の標準偏差
```

## 実験フロー

### Stage1: リズム確立フェーズ
```python
# 2秒間隔で10回の機械音を再生
while stage1_num < stage1:
    if timer.getTime() >= span:  # 2秒経過
        sound_02a.play()         # 刺激音再生
        timer.reset()
        stage1_num += 1
```

### Stage2: 協調タッピングフェーズ
```python
# 交互タッピング（100+20回）
while turn < (stage2 + buffer*2):
    if timer.getTime() >= random_second and flag == 1:
        sound_02a.play()              # 機械音
        stim_tap.append(clock.getTime())
        flag = 0  # プレイヤーターンに切り替え

    if flag == 0 and 'space' in keys:
        player_tap.append(clock.getTime())  # 人間タップ記録
        sound_03a.play()                    # プレイヤー音

        # SE計算とモデル推論
        se = calculate_se()
        random_second = model_prediction(se)

        timer.reset()
        flag = 1  # 機械ターンに切り替え
```

## モデル実装詳細

### 1. SEAモデル（modify.py）

**同期エラー計算**:
```python
# SE = 機械音時刻 - (前回人間タップ + 今回人間タップ)/2
stim_SE.append(stim_tap[turn] - (player_tap[turn] + player_tap[turn + 1])/2)
modify += stim_SE[turn]  # 累積SE
```

**次間隔予測**:
```python
# 平均SEを基準間隔から引く + ランダム変動
avg_modify = modify / (turn + 1)
random_second = np.random.normal((span / 2) - avg_modify, scale)
```

**重要な特徴**:
- **完全補正**: 平均SEを100%補正
- **ランダム変動**: 正規分布（平均0、標準偏差0.1）
- **累積学習**: 全SE履歴の平均を使用
- **制約なし**: 負の値も許容（即座反応）

### 2. Bayesianモデル（bayes0.py）

**ContBayesクラス初期化**:
```python
b0 = ContBayes(-3, 3, 20, 0, scale)
# x_min=-3, x_max=3, n_hypothesis=20, l_memory=0, scale=0.1
```

**推論プロセス**:
```python
def inference(self, data):
    # ベイズ学習: 事後確率更新
    post_prov = [norm(self.likelihood[i], 0.3).pdf(data)
                 for i in range(self.n_hypothesis)] * self.h_prov
    post_prov /= np.sum(post_prov)
    self.h_prov = post_prov

    # 確率的予測
    return np.random.normal(
        loc=np.random.choice(self.likelihood, p=self.h_prov),
        scale=0.3
    )
```

**次間隔計算**:
```python
# Bayesian推論結果を基準間隔から引く
random_second = (span / 2) - b0.inference(stim_SE[turn])
```

### 3. BIBモデル（bayes1.py）

**ContBayesクラス初期化**:
```python
b1 = ContBayes(-3, 3, 20, 1, scale)
# l_memory=1でInverse Bayesian学習を有効化
```

**Inverse Bayesian学習**:
```python
if self.l_memory > 0:
    new_hypo = np.mean(self.memory)  # メモリ平均から新仮説
    inv_h_prov = (1 - self.h_prov) / (self.n_hypothesis - 1)  # 確率反転
    # 反転確率で仮説を選択して置換
    self.likelihood[np.random.choice(np.arange(self.n_hypothesis), p=inv_h_prov)] = new_hypo
    self.memory = np.roll(self.memory, -1)  # メモリローテーション
    self.memory[-1] = data  # 新データ追加
```

## 重要な設計原則

### 1. タイミング制御
```python
# オリジナルの正しいタイミング制御
if 'space' in keys:
    player_tap.append(clock.getTime())  # タップ時刻記録
    # SE計算とモデル推論
    random_second = model_prediction()
    timer.reset()  # 人間タップ直後にリセット
    flag = 1
```

**重要**: `timer.reset()`は人間タップ検出直後に実行

### 2. SE（同期エラー）定義
```python
# オリジナルの正確なSE定義
SE = stim_tap[n] - (player_tap[n] + player_tap[n+1]) / 2
```
- 機械音タイミング vs 前後人間タップの中点
- 正の値: 機械が遅れ、負の値: 機械が早い

### 3. データ構造
```python
# 初期値設定（Stage1終了時の状態をシミュレート）
stim_tap = [span * stage1]      # [20.0] - 最後の機械音時刻
player_tap = [span * (stage1 - 1/2)]  # [19.0] - 最後の人間タップ時刻
```

### 4. モデル共通インターフェース
```python
# 全モデル共通の最終計算式
random_second = (span / 2) - model_prediction
# span/2 = 1.0秒（基準ITI）から予測値を引く
```

### 5. 制約条件
```python
# オリジナルには間隔制約なし（負の値も許容）
# 負の間隔 → システムが即座に反応
# 極端な間隔も許容 → より自然な適応行動
```

## データ出力

### CSVファイル
```python
# タップデータ
df = pd.DataFrame({'Player_tap': player_tap, 'Stim_tap': stim_tap})
df.to_csv(f'{model_name}_tap_{serial_num}.csv')

# SEデータ
df = pd.DataFrame({'Player_SE': player_SE, 'Stim_SE': stim_SE})
df.to_csv(f'{model_name}_SE_{serial_num}.csv')
```

### 分析グラフ
1. **ITI時系列**: Stim/Player別のITI推移
2. **ITIv時系列**: ITI変化量の推移
3. **SE時系列**: 同期エラーの推移
4. **SEv時系列**: SE変化量の推移
5. **ITIヒストグラム**: 分布比較
6. **散布図**: SE vs ITI, SEv vs ITI等の相関分析

## MATLAB移植の重要ポイント

### 1. 正確なSE計算
```matlab
% オリジナル準拠のSE計算
se = stim_tap(turn) - (player_tap(turn) + player_tap(turn + 1))/2;
```

### 2. モデル実装の一致
```matlab
% SEAモデル
avg_modify = cumulative_se / update_count;
base_interval = (config.SPAN / 2) - avg_modify;  % 100%補正
next_interval = base_interval + normrnd(0, config.SCALE);

% Bayesianモデル
prediction = bayesian_inference(se);
next_interval = (config.SPAN / 2) - prediction;  % 減算式
```

### 3. タイミング制御
```matlab
% 人間タップ検出直後にタイマーリセット
if any(strcmp(keys, 'space'))
    tap_time = posixtime(datetime('now')) - runner.clock_start;
    runner.player_tap(end+1) = tap_time;
    runner.timer_start = posixtime(datetime('now'));  % 即座にリセット
    % SE計算とモデル推論は後で実行
end
```

### 4. 制約条件の除去
```matlab
% オリジナル準拠: 制約なし
% next_interval = max(0.2, min(1.2, next_interval)); ← 削除
% 負の値や極端な値も許容してオリジナルの動作を再現
```

### 5. SE計算タイミング
```matlab
% オリジナルのSE計算は「前回」と「今回」の人間タップを使用
% 現在の実装で正しく再現されているか要確認
```

## 現在のMATLAB実装との主要な差異

### 1. **制約条件**
- **オリジナル**: 制約なし（負の値許容）
- **現在**: 0.2-1.2秒制約 → **要修正**

### 2. **SE計算方法**
- **オリジナル**: `stim_tap[n] - (player_tap[n] + player_tap[n+1])/2`
- **現在**: 要確認 → **検証必要**

### 3. **プレイヤー音再生**
- **オリジナル**: 人間タップ時にplayer音再生
- **現在**: プレイヤー音なし → **設計変更済み（OK）**

### 4. **ランダム変動**
- **オリジナル**: 全モデルで`scale=0.1`の正規分布
- **現在**: SEAのみ実装済み → **要確認**

## 検証要項

1. **SE計算の一致**: オリジナルと同じSE値が計算されるか
2. **モデル出力の一致**: 同じSE入力で同じ予測値が得られるか
3. **制約除去**: 負の値や極端な値の許容
4. **タイミング精度**: 人間タップ→機械音の間隔がモデル予測通りか
5. **データ構造**: CSVファイルフォーマットの互換性
6. **統計分析**: ITI、SE分布の再現性

## 次のアクション

1. **制約条件除去**: `model_inference.m`の0.2-1.2秒制約削除
2. **SE計算検証**: オリジナルとの計算式一致確認
3. **Bayesian/BIBランダム変動**: 確率的出力の実装確認
4. **総合テスト**: 3モデル全てでオリジナル準拠動作の検証

---

**作成者**: Claude Code
**作成日**: 2025年9月17日
**バージョン**: 1.0
**参照**: legacy/original/ オリジナル実装群