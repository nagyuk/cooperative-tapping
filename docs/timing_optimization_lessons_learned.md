# タイミング最適化における学びと教訓

## 実装日時
2025-09-18

## 概要
協調タッピング実験システムにおけるタイミング精度向上の取り組みから得られた重要な学びと技術的知見をまとめる。

## 問題の背景

### 発見された主要な問題
1. **ITI遅延問題**: 期待値1.0秒に対して実測1.555秒の遅延
2. **キー入力遅延**: メインループでの処理時刻と実際の押下時刻の乖離
3. **音声再生の不安定性**: 従来のstop-play方式による遅延増加

## 実装した解決策

### 1. 超安定音声システム (play_optimized_sound)

```matlab
% 音声プール方式による遅延削減
runner.player_pool_size = 3;  % 最適サイズ
runner.player_pool = cell(runner.player_pool_size, 1);

% stop()を省略してplay()のみ実行
play(current_player);
```

**学び**:
- `stop()`呼び出しが音声遅延の主要因
- プール方式により安定した低遅延再生を実現
- ウォームアップによる初回遅延の解消が重要

### 2. 実際のキー押下時刻記録システム

```matlab
% キーハンドラーでの実時刻記録
global experiment_last_key_time experiment_clock_start
actual_key_time = experiment_last_key_time - experiment_clock_start;

% メインループでの処理遅延計算
key_delay = processing_time - actual_key_time;
```

**学び**:
- メインループでの`posixtime`取得は処理遅延を含む
- グローバル変数による直接記録が最も正確
- 遅延の可視化により問題の定量化が可能

### 3. モデル推論デバッグシステム

```matlab
% デバッグログ記録
debug_entry = struct();
debug_entry.turn = turn;
debug_entry.se = se;
debug_entry.model_output = random_second;
debug_entry.timer_reset_time = posixtime(datetime('now')) - runner.clock_start;
```

**学び**:
- 各ステップの詳細ログが問題特定に必須
- SEからモデル出力までの流れの可視化
- 構造体配列による効率的なデータ収集

## 重要な技術的発見

### 1. MATLAB音声システムの特性
- `audioplayer`オブジェクトの作成コストは高い
- `stop()`は予想以上の処理時間を要する
- プール方式 + ラウンドロビンが最も安定

### 2. タイミング計測の落とし穴
- `posixtime(datetime('now'))`の実行タイミングが重要
- キーハンドラーでの記録が最も正確な時刻を提供
- 処理遅延の定量化により改善効果の測定が可能

### 3. グローバル変数の効果的活用
- MATLABでのイベント処理にはグローバル変数が実用的
- 適切な初期化・クリーンアップが安定性に必須
- キーハンドラーとメインループ間の連携に有効

## 未解決の謎

### ITI遅延の根本原因
**現象**: 期待1.0秒に対して実測1.555秒（約0.555秒の遅延）

**調査結果**:
- モデル推論処理時間: 微小（1ms未満）
- 音声再生遅延: 改善済み（5.8ms±0.2ms）
- キー入力遅延: 定量化済み（10-50ms程度）
- タイマーリセット処理: 正常

**推測される原因**:
1. MATLABのループ処理における潜在的遅延
2. `pause()`やその他の待機処理の累積効果
3. 実験設計における論理的な遅延要因

**今後の調査方針**:
- より詳細なタイムスタンプ記録
- Stage2開始時の詳細分析
- Python版との比較検証

## ベストプラクティス

### 1. 音声システム
```matlab
% プール作成
for i = 1:pool_size
    pool{i} = audioplayer(sound_data, fs);
    % ウォームアップ
    play(pool{i}); pause(0.01); stop(pool{i});
end

% 再生時
play(current_player);  % stop()を省略
```

### 2. タイミング計測
```matlab
% キーハンドラー
global experiment_last_key_time experiment_clock_start
experiment_last_key_time = posixtime(datetime('now'));

% メインループ
actual_time = experiment_last_key_time - experiment_clock_start;
```

### 3. デバッグログ
```matlab
% 構造化ログ
debug_entry = struct();
debug_entry.timestamp = posixtime(datetime('now'));
debug_entry.event_type = 'key_press';
debug_entry.value = actual_time;
runner.debug_log{end+1} = debug_entry;
```

## 成果の定量化

### 改善された指標
- **音声遅延**: 20.7ms → 5.8ms（約72%改善）
- **音声安定性**: σ=7.0ms → σ=0.2ms（約97%改善）
- **キー入力遅延**: 可視化により定量化達成
- **デバッグ能力**: 全ステップの詳細記録が可能

### 残存課題
- **ITI遅延**: 根本原因未特定（0.555秒の謎）
- **総合的遅延**: さらなる改善の余地あり

## 今後の展望

### 短期目標
1. ITI遅延の根本原因特定
2. Python版との詳細比較
3. より高精度なタイミング計測手法の探索

### 長期目標
1. リアルタイム実験システムの完全最適化
2. 他の実験パラダイムへの応用
3. 知見の学術的な発信

## まとめ

今回の最適化作業により、音声システムとキー入力処理において大幅な改善を達成した。特に、従来見過ごされていた`stop()`処理の遅延や、キー入力時刻の正確な記録の重要性が明らかになった。

一方で、ITI遅延の根本原因は依然として謎であり、これは今後の重要な研究課題となる。本ドキュメントの知見は、類似のリアルタイム実験システムの開発において貴重な参考資料となることを期待する。