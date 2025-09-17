# モデル再設計要件定義書

## 概要

協調タッピング実験システムのモデル再設計における要件定義です。
現在のMATLAB実装の課題を解決し、より自然で効果的な人間-コンピュータ協調を実現します。

## 現在の問題

### 測定された課題
- **ITI遅延**: 期待値1.0秒に対し実測1.555秒（55%遅延）
- **反応時間の誤認**: 人間の自然な反応時間0.555秒を「エラー」として扱い
- **悪循環**: システムが急ぐ → 人間がさらに遅れる → システムがもっと急ぐ

### 実装上の問題
1. **反応時間未考慮**: `SE = 反応時間 + 真の同期エラー`の混同
2. **逆補正ロジック**: `SPAN/2 - (avg_se * 0.5)` による過度な急速化
3. **決定論的動作**: ランダム変動なしによる予測可能性
4. **固定係数**: 理論的根拠のない0.5係数

## 設計原則

### 1. 協調優先アプローチ
- **従来**: 人間の「エラー」を補正する
- **新方式**: 人間に合わせて協調する

### 2. 反応時間の適切な扱い
- 反応時間を自然な現象として受け入れ
- 真の同期エラーのみを調整対象とする

### 3. 予測不可能性の導入
- ランダム変動により自然な協調を促進
- 機械的すぎる動作の回避

### 4. 学習と適応
- 個人差への対応
- 実験進行に伴う適応的調整

## 新モデル要件

### 高優先度要件（必須）

#### R1: 反応時間オフセット機能
```matlab
% 要件: 推定反応時間の自動計算と適用
estimated_reaction_time = calculate_reaction_time_baseline(initial_taps);
adjusted_se = raw_se - estimated_reaction_time;
```

**受け入れ基準**:
- Stage1データから個人の平均反応時間を推定
- 推定誤差±50ms以内での反応時間オフセット
- 調整後SEが理論値に近づくこと

#### R2: 正の補正ロジック
```matlab
% 要件: 協調方向への調整
next_interval = (config.SPAN / 2) + (adjusted_se * cooperation_gain);
```

**受け入れ基準**:
- 人間が遅れた場合、システムも遅らせる
- 人間が早い場合、システムも早める
- ITI平均値が1.0±0.1秒の範囲内に収束

#### R3: ランダム変動の復活
```matlab
% 要件: 自然な変動の導入
random_variation = normrnd(0, config.SCALE);
final_interval = base_interval + random_variation;
```

**受け入れ基準**:
- SCALE=0.1による正規分布変動
- システムの予測可能性低下
- より自然な協調リズムの実現

### 中優先度要件（推奨）

#### R4: 適応的協調ゲイン
```matlab
% 要件: 動的な補正強度調整
cooperation_gain = calculate_adaptive_gain(trial_number, performance_metrics);
```

**受け入れ基準**:
- 初期：大きなゲイン（探索的）
- 後期：小さなゲイン（安定化）
- 性能指標に基づく自動調整

#### R5: 学習率の動的調整
```matlab
% 要件: 実験進行に応じた学習調整
learning_rate = max(min_rate, initial_rate * decay_factor^trial_number);
```

**受け入れ基準**:
- 指数的減衰による学習率調整
- 過学習防止メカニズム
- 安定収束の達成

### 低優先度要件（将来拡張）

#### R6: 個人差対応
- 被験者特性の自動検出
- パーソナライズされた協調パラメータ

#### R7: 高度なBayesian実装
- 仮説空間の動的調整
- より精密な確率的推論

## 実装仕様

### 新モデルアーキテクチャ
```matlab
function model = create_enhanced_model(model_type, config)
    model.type = model_type;
    model.config = config;

    % 反応時間推定モジュール
    model.reaction_time_estimator = ReactionTimeEstimator();

    % 協調制御モジュール
    model.cooperation_controller = CooperationController();

    % ランダム変動生成器
    model.random_generator = RandomVariationGenerator(config.SCALE);

    % 学習・適応モジュール
    model.learning_module = LearningModule();
end
```

### 推論プロセス
```matlab
function next_interval = enhanced_inference(model, raw_se, trial_number)
    % 1. 反応時間オフセット
    adjusted_se = raw_se - model.reaction_time_estimator.get_offset();

    % 2. 協調的補正
    cooperation_gain = model.learning_module.get_current_gain(trial_number);
    base_interval = (model.config.SPAN / 2) + (adjusted_se * cooperation_gain);

    % 3. ランダム変動追加
    variation = model.random_generator.generate();
    final_interval = base_interval + variation;

    % 4. 制約適用
    next_interval = apply_constraints(final_interval, 0.2, 1.2);

    % 5. 学習更新
    model.learning_module.update(adjusted_se, trial_number);
end
```

## 検証方法

### 単体テスト
1. **反応時間推定精度テスト**
2. **協調ロジック動作テスト**
3. **ランダム変動分布テスト**
4. **学習収束テスト**

### 統合テスト
1. **ITI収束性能テスト**: 1.0±0.1秒への収束
2. **安定性テスト**: 長時間実験での動作安定性
3. **個人差対応テスト**: 異なる反応特性での性能

### 実験検証
1. **従来モデルとの比較実験**
2. **主観的協調感の評価**
3. **学習効果の測定**

## 成功基準

### 定量的指標
- **ITI精度**: 平均1.0±0.1秒
- **収束時間**: 10タップ以内での安定化
- **変動係数**: 10%以下の安定性

### 定性的指標
- **協調感**: 被験者の主観的評価向上
- **予測可能性**: システムの機械的動作感の軽減
- **学習効果**: 実験進行による改善の確認

## リスク分析

### 技術的リスク
- **反応時間推定誤差**: 個人差による推定困難
- **パラメータ調整**: 最適値探索の複雑性
- **計算負荷**: リアルタイム性能への影響

### 対策
- 保守的な推定アルゴリズム
- A/Bテストによる段階的改善
- プロファイリングによる性能最適化

## タイムライン

### Phase 1 (Week 1-2): 基本機能実装
- 反応時間オフセット機能
- 正の補正ロジック
- ランダム変動復活

### Phase 2 (Week 3): 適応機能実装
- 適応的ゲイン調整
- 学習モジュール

### Phase 3 (Week 4): 検証・最適化
- 総合テスト
- パフォーマンス調整
- ドキュメント整備

---

**作成者**: Claude Code
**作成日**: 2025年9月17日
**バージョン**: 1.0
**対象システム**: MATLAB協調タッピング実験システム