# 協調タッピング実験システム改善提案書

## 概要

本提案書は、現在の協調タッピング実験システムにおけるベイズ・BIB推論モデルの科学的厳密性と理論的妥当性を向上させるための包括的改善案を提示します。研究の本質である「ベイズ・BIB推論と人間の認知特性の近似度評価」により焦点を当てた設計見直しを行います。

## 1. 現状分析と根本的問題

### 1.1 研究目的の再確認
**本質的課題**: ベイズ推論・BIB推論が人間の協調タッピング行動をどの程度再現できるか

**現在の実装問題**:
- 正規分布ノイズによる本質的アルゴリズムの性能隠蔽
- 恣意的パラメータ選択による結果の信頼性低下
- 限定的な「人間らしさ」評価指標

## 2. 正規分布ランダム性削除提案

### 2.1 削除の根拠

#### 科学的根拠
```matlab
% 現在の実装（問題あり）
prediction = normrnd(selected_likelihood, 0.3);  % アルゴリズム性能を曖昧化
next_interval = (SPAN/2) - prediction;

% 提案する実装（純粋）
prediction = selected_likelihood;  % 純粋なアルゴリズム出力
next_interval = (SPAN/2) - prediction;
```

#### 利点
1. **アルゴリズム性能の純粋評価**: ノイズに隠されない真の性能
2. **再現性向上**: 確定的出力による実験の完全再現性
3. **比較公平性**: SEA・Bayes・BIBの本質的差異の明確化
4. **理論的整合性**: 数学的に明確な予測メカニズム

### 2.2 実装方針

#### Phase 1: 完全決定論的実装
```matlab
function next_interval = model_inference_deterministic(model, se)
    switch lower(model.type)
        case 'sea'
            % 純粋なSE平均補正
            avg_se = model.cumulative_se / model.update_count;
            next_interval = (model.config.SPAN / 2) - avg_se;

        case 'bayes'
            % 期待値による決定論的予測
            expected_prediction = sum(model.likelihood .* model.h_prov);
            next_interval = (model.config.SPAN / 2) - expected_prediction;

        case 'bib'
            % BIB学習後の期待値予測
            expected_prediction = sum(model.likelihood .* model.h_prov);
            next_interval = (model.config.SPAN / 2) - expected_prediction;
    end
end
```

#### Phase 2: 制御された確率性（オプション）
```matlab
% 研究で必要な場合のみ、明示的に制御された確率性
if config.enable_stochasticity
    % MAP推定 vs サンプリングの比較実験
    prediction = sample_from_posterior(model.h_prov, model.likelihood);
else
    % 期待値による決定論的予測
    prediction = expectation(model.h_prov, model.likelihood);
end
```

## 3. パラメータ最適化手法

### 3.1 データ駆動型パラメータ決定

#### 手法1: 人間データフィッティング
```matlab
function optimal_params = fit_human_data(human_experiment_data)
    % 人間同士の協調タッピングデータから逆推定

    % 最適化対象パラメータ
    params = struct();
    params.n_hypothesis = [10, 15, 20, 25, 30];  % 仮説数
    params.likelihood_range = [-3, -2, -1, 1, 2, 3];  % 仮説空間
    params.learning_rate = [0.1, 0.3, 0.5, 0.7, 0.9];  % 学習率

    % 目的関数: 人間データとの類似度
    objective = @(p) calculate_similarity(simulate_model(p), human_experiment_data);

    % ベイズ最適化による効率的探索
    optimal_params = bayesopt(objective, param_space, 'MaxObjectiveEvaluations', 100);
end
```

#### 手法2: クロスバリデーション
```matlab
function [best_params, cv_scores] = cross_validate_parameters(data, k_folds)
    param_grid = generate_parameter_grid();
    cv_scores = zeros(size(param_grid));

    for i = 1:length(param_grid)
        scores = zeros(k_folds, 1);

        for fold = 1:k_folds
            [train_data, test_data] = split_data(data, fold, k_folds);

            % モデル訓練
            model = train_model(train_data, param_grid(i));

            % テストデータでの性能評価
            scores(fold) = evaluate_model(model, test_data);
        end

        cv_scores(i) = mean(scores);
    end

    [~, best_idx] = max(cv_scores);
    best_params = param_grid(best_idx);
end
```

#### 手法3: 多目的最適化
```matlab
function pareto_optimal = multi_objective_optimization()
    % 複数の評価指標を同時最適化
    objectives = {
        @prediction_accuracy,     % 予測精度
        @adaptation_speed,        % 適応速度
        @stability_measure,       % 安定性
        @human_similarity        % 人間類似度
    };

    % NSGA-II による多目的最適化
    pareto_optimal = nsga2(objectives, parameter_bounds, population_size, generations);
end
```

### 3.2 実験的パラメータ決定プロセス

#### Step 1: ベースライン人間実験
```matlab
% 人間同士の協調タッピング実験を実施
% - 6名 × 3セッション = 18データセット
% - SE-ITI, SEv-ITIv等の基準指標を測定
human_baseline = conduct_human_human_experiment(n_subjects=6, n_sessions=3);
```

#### Step 2: パラメータ空間探索
```matlab
% 系統的パラメータ探索
parameter_study_results = systematic_parameter_search(
    n_hypothesis_range=[5:5:50],
    likelihood_range_options={[-4,4], [-3,3], [-2,2], [-1,1]},
    memory_length_range=[0:1:5]
);
```

#### Step 3: 統計的検証
```matlab
% 統計的有意性の確認
[p_values, effect_sizes, confidence_intervals] = statistical_validation(
    parameter_study_results,
    human_baseline,
    correction_method='bonferroni'
);
```

## 4. 人間らしさ評価指標の改善

### 4.1 現在の指標の限界

**SE-ITIv相関の問題**:
- 単一指標による評価の限界
- 因果関係の不明確性
- コントロール条件の不足

### 4.2 包括的評価フレームワーク

#### 4.2.1 予測可能性指標
```matlab
function predictability_score = evaluate_predictability(model_output, human_data)
    % 予測誤差の分散
    prediction_variance = var(model_output - human_data);

    % 時系列予測精度
    [~, forecast_error] = time_series_prediction(model_output, human_data);

    % 総合予測可能性スコア
    predictability_score = 1 / (1 + prediction_variance + forecast_error);
end
```

#### 4.2.2 適応性指標
```matlab
function adaptation_score = evaluate_adaptation(response_data)
    % 変化点検出
    change_points = detect_change_points(response_data);

    % 適応速度計算
    adaptation_speed = calculate_adaptation_speed(response_data, change_points);

    % 適応完了度
    adaptation_completeness = calculate_adaptation_completeness(response_data);

    adaptation_score = weighted_combination(adaptation_speed, adaptation_completeness);
end
```

#### 4.2.3 協調性指標
```matlab
function coordination_score = evaluate_coordination(model_data, partner_data)
    % 相互情報量
    mutual_information = calculate_mutual_information(model_data, partner_data);

    % 位相同期度
    phase_locking_value = calculate_phase_locking(model_data, partner_data);

    % 相互予測精度
    cross_prediction_accuracy = cross_prediction_analysis(model_data, partner_data);

    coordination_score = [mutual_information, phase_locking_value, cross_prediction_accuracy];
end
```

#### 4.2.4 統合類似度指標
```matlab
function human_similarity_index = calculate_hsi(model_behavior, human_behavior)
    % 複数次元での類似度評価
    dimensions = {
        'temporal_pattern',      % 時間パターン類似度
        'variability_structure', % 変動構造類似度
        'response_distribution', % 応答分布類似度
        'correlation_structure', % 相関構造類似度
        'adaptation_dynamics'    % 適応ダイナミクス類似度
    };

    similarity_scores = zeros(length(dimensions), 1);

    for i = 1:length(dimensions)
        similarity_scores(i) = evaluate_dimension(
            model_behavior,
            human_behavior,
            dimensions{i}
        );
    end

    % 主成分分析による次元削減と統合
    [coeff, scores] = pca(similarity_scores');
    human_similarity_index = scores(1);  % 第1主成分
end
```

### 4.3 コントロール条件の追加

#### 4.3.1 ランダムベースライン
```matlab
function random_baseline = generate_random_baseline(experiment_params)
    % 完全ランダム応答
    random_responses = rand(experiment_params.n_trials, 1) * 2 - 1;  % [-1, 1]

    % 制約付きランダム（物理的制約考慮）
    constrained_random = apply_physical_constraints(random_responses);

    random_baseline = constrained_random;
end
```

#### 4.3.2 最適制御ベースライン
```matlab
function optimal_baseline = generate_optimal_baseline(experiment_params)
    % 最小二乗誤差制御
    lqr_controller = design_lqr_controller(system_dynamics, cost_function);

    % 最適応答生成
    optimal_responses = simulate_optimal_control(lqr_controller, experiment_params);

    optimal_baseline = optimal_responses;
end
```

## 5. 代替・改良アプローチ

### 5.1 階層ベイズモデル

#### 5.1.1 個体差を考慮したモデル
```matlab
function hierarchical_model = create_hierarchical_bayes_model()
    % レベル1: 個体特異的パラメータ
    individual_params = struct();
    individual_params.sensitivity = normal_prior(0, 1);
    individual_params.bias = normal_prior(0, 0.5);

    % レベル2: 集団レベルハイパーパラメータ
    population_params = struct();
    population_params.mean_sensitivity = normal_prior(0, 2);
    population_params.sensitivity_variance = gamma_prior(1, 1);

    hierarchical_model = struct();
    hierarchical_model.individual = individual_params;
    hierarchical_model.population = population_params;
end
```

#### 5.1.2 文脈依存パラメータ
```matlab
function context_adaptive_model = create_context_model()
    % 文脈特徴量の定義
    context_features = {
        'trial_number',          % 試行回数
        'recent_error_magnitude', % 直近エラー大きさ
        'error_trend',           % エラー傾向
        'partner_predictability' % パートナー予測可能性
    };

    % 文脈依存パラメータ更新
    for feature = context_features
        model.params.(feature{1}) = update_context_parameter(
            current_context.(feature{1}),
            model.params.(feature{1})
        );
    end
end
```

### 5.2 強化学習ベースアプローチ

#### 5.2.1 Q学習モデル
```matlab
function q_learning_model = create_q_learning_tapper()
    % 状態空間: [SE, SE_velocity, ITI_history]
    state_dimensions = [21, 11, 5];  % 離散化レベル

    % 行動空間: ITI調整量
    action_space = linspace(-0.5, 0.5, 11);  % -0.5〜+0.5秒調整

    % Q-table初期化
    Q_table = zeros([state_dimensions, length(action_space)]);

    % 学習パラメータ
    params = struct();
    params.learning_rate = 0.1;
    params.discount_factor = 0.9;
    params.exploration_rate = 0.1;

    q_learning_model = struct();
    q_learning_model.Q_table = Q_table;
    q_learning_model.params = params;
    q_learning_model.state_space = state_dimensions;
    q_learning_model.action_space = action_space;
end
```

#### 5.2.2 報酬関数設計
```matlab
function reward = calculate_reward(se_current, se_previous, iti_stability)
    % 多目的報酬関数

    % 同期誤差削減報酬
    sync_reward = -abs(se_current) + 0.5 * (abs(se_previous) - abs(se_current));

    % 安定性報酬
    stability_reward = -iti_stability * 0.3;

    % 協調性報酬（相互適応）
    coordination_reward = calculate_mutual_adaptation_reward();

    % 重み付き合成
    reward = 0.6 * sync_reward + 0.3 * stability_reward + 0.1 * coordination_reward;
end
```

### 5.3 動的システムアプローチ

#### 5.3.1 結合振動子モデル
```matlab
function coupled_oscillator = create_coupled_oscillator_model()
    % Kuramoto振動子の拡張
    params = struct();
    params.natural_frequency = 0.5;  % 1/2秒の自然周波数
    params.coupling_strength = 0.3;   % 結合強度
    params.noise_amplitude = 0.1;     % 内部ノイズ

    % 状態変数: [位相, 位相速度]
    state = struct();
    state.phase = 0;
    state.phase_velocity = params.natural_frequency;

    coupled_oscillator = struct();
    coupled_oscillator.params = params;
    coupled_oscillator.state = state;
end

function next_state = update_coupled_oscillator(oscillator, partner_phase)
    % Kuramoto方程式
    phase_coupling = oscillator.params.coupling_strength * ...
                    sin(partner_phase - oscillator.state.phase);

    % 位相更新
    oscillator.state.phase_velocity = oscillator.params.natural_frequency + phase_coupling;
    oscillator.state.phase = oscillator.state.phase + oscillator.state.phase_velocity * dt;

    next_state = oscillator.state;
end
```

#### 5.3.2 適応的結合強度
```matlab
function adaptive_coupling = update_coupling_strength(coupling_current, sync_error_history)
    % エラー履歴に基づく結合強度適応
    recent_errors = sync_error_history(end-5:end);
    error_trend = polyfit(1:length(recent_errors), recent_errors, 1);

    % エラー増加傾向→結合強度増加
    if error_trend(1) > 0
        coupling_delta = 0.05;
    else
        coupling_delta = -0.02;
    end

    adaptive_coupling = max(0.1, min(1.0, coupling_current + coupling_delta));
end
```

### 5.4 予測符号化モデル

#### 5.4.1 階層的予測モデル
```matlab
function predictive_model = create_predictive_coding_model()
    % 複数階層の予測
    levels = struct();

    % レベル1: 短期予測（次のITI）
    levels.short_term = struct();
    levels.short_term.prediction = 1.0;  % 初期予測
    levels.short_term.precision = 1.0;   % 予測精度

    % レベル2: 中期予測（トレンド）
    levels.medium_term = struct();
    levels.medium_term.trend = 0.0;      % トレンド予測
    levels.medium_term.precision = 0.5;

    % レベル3: 長期予測（戦略）
    levels.long_term = struct();
    levels.long_term.strategy = 'sync';   % 同期戦略
    levels.long_term.confidence = 0.8;

    predictive_model = levels;
end

function updated_model = update_predictive_model(model, observation, prediction_error)
    % 予測誤差に基づく階層的更新

    % レベル1更新（短期）
    model.short_term.prediction = model.short_term.prediction + ...
                                 0.3 * prediction_error * model.short_term.precision;

    % レベル2更新（中期）
    trend_error = calculate_trend_error(observation);
    model.medium_term.trend = model.medium_term.trend + ...
                             0.1 * trend_error * model.medium_term.precision;

    % レベル3更新（長期）
    strategy_update = evaluate_strategy_effectiveness(model.long_term.strategy);
    if strategy_update < 0.5
        model.long_term.strategy = switch_strategy(model.long_term.strategy);
    end

    updated_model = model;
end
```

## 6. 実装ロードマップ

### Phase 1: 基盤整備（2週間）
```matlab
% 1. 決定論的モデルの実装
implement_deterministic_models();

% 2. パラメータ最適化フレームワーク
setup_parameter_optimization_framework();

% 3. 拡張評価指標の実装
implement_comprehensive_evaluation_metrics();
```

### Phase 2: データ収集（3週間）
```matlab
% 1. 人間-人間ベースライン実験
human_baseline_data = conduct_human_human_experiments(n_subjects=12);

% 2. パラメータ最適化実験
optimal_parameters = optimize_model_parameters(human_baseline_data);

% 3. 統計的検証
validation_results = statistical_validation(optimal_parameters);
```

### Phase 3: 高度モデル実装（4週間）
```matlab
% 1. 階層ベイズモデル
hierarchical_bayes = implement_hierarchical_bayes();

% 2. 強化学習モデル
q_learning_tapper = implement_q_learning_model();

% 3. 予測符号化モデル
predictive_coder = implement_predictive_coding();
```

### Phase 4: 総合評価（2週間）
```matlab
% 1. 全モデルの比較実験
comparative_results = comprehensive_model_comparison();

% 2. 統計解析と効果量計算
statistical_analysis = analyze_results_with_effect_sizes();

% 3. 論文執筆
generate_research_report(comparative_results, statistical_analysis);
```

## 7. 期待される成果

### 7.1 科学的貢献
- **理論的厳密性**: 数学的に明確なモデル比較
- **実験的妥当性**: 統計的に検証された結果
- **再現性**: 確定的実装による完全再現性

### 7.2 実用的価値
- **最適化パラメータ**: 科学的根拠に基づく設定値
- **汎用評価フレームワーク**: 他研究への適用可能性
- **実装可能性**: 実時間実験での動作保証

### 7.3 理論的発展
- **認知モデリング**: より生物学的にplausibleなモデル
- **協調メカニズム**: 人間-機械協調の理論的理解
- **適応学習**: 動的環境での学習メカニズム解明

---

## 結論

本提案は、現在の研究の本質的価値を最大化しつつ、科学的厳密性を大幅に向上させる包括的改善案です。正規分布ランダム性の削除により、純粋なアルゴリズム性能の比較が可能となり、データ駆動型パラメータ最適化により客観的な設定値が得られます。さらに、多次元評価指標と代替アプローチにより、「人間らしさ」の理解が深化し、協調タッピング研究の新たな地平が開かれることが期待されます。