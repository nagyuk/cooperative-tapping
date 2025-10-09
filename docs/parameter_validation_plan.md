# モデルパラメータ妥当性確立計画

## 背景

現在のHuman-Computerモデルのパラメータ（SPAN, SCALE, BAYES_N_HYPOTHESIS, BIB_L_MEMORY）は直感的に設定されており、経験的妥当性を欠いている。

## 目標

Human-Humanデータに基づいた、統計的に妥当なパラメータ設定を確立する。

---

## 戦略: Human-Humanデータ駆動型アプローチ

### 理論的根拠

1. **生態学的妥当性**: Human-Humanの協調タッピングが自然な人間行動のグランドトゥルース
2. **パラメータの意味**: 人間ペアの統計的特性がモデルパラメータの目標値
3. **客観的評価**: モデルの「人間らしさ」を定量評価可能

---

## 実験計画

### Phase 1: パイロット実験（1-2週間）

**目的**: プロトコル検証と予備的データ収集

**参加者**: N=3-5ペア
**実験条件**:
- Stage1: 10ビート（現行と同じ）
- Stage2: 20サイクル

**測定指標**:
- Inter-Tap Interval (ITI): 連続タップ間隔
- Synchronization Error (SE): 理想タイミングからのずれ
- Asynchrony: 両プレイヤー間のタイミング差

**データ分析**:
```matlab
% パイロットデータから予備的統計量を計算
pilot_stats = analyze_pilot_data('data/raw/human_human/');
fprintf('予備的推定値:\n');
fprintf('  平均ITI: %.3f ± %.3f秒\n', pilot_stats.mean_iti, pilot_stats.std_iti);
fprintf('  推奨SPAN: %.3f秒\n', pilot_stats.mean_iti * 2);
fprintf('  推奨SCALE: %.3f\n', pilot_stats.std_iti);
```

---

### Phase 2: 文献調査（並行作業、2-3週間）

**調査対象**:
1. Sensorimotor synchronization研究
   - Repp & Su (2013)
   - Konvalinka et al. (2010)
2. Joint action dynamics
3. 運動制御理論（Schmidt's Law, Central Tendency）

**目標**:
- パラメータの理論的妥当範囲の特定
- モデル構造の理論的妥当性検証
- 必要に応じたモデル改良案の作成

---

### Phase 3: 本実験（1-2ヶ月）

**目的**: 統計的に信頼できるベースラインデータ収集

**参加者**: N=10-20ペア
**実験条件**:
- Stage1: 10ビート
- Stage2: 30サイクル（より多くのデータ）
- セッション間休憩（疲労の影響を軽減）

**統制変数**:
- 音楽経験（リズム感の個人差）
- 年齢・性別（必要に応じて）

**データ収集**:
```matlab
% 統一されたデータ収集プロトコル
clear classes; rehash toolboxcache
run_unified_experiment  % Option 2: Human-Human

% データは自動的に以下に保存:
% data/raw/human_human/YYYYMMDD/[p1]_[p2]_human_human_[timestamp]/
```

---

### Phase 4: パラメータ推定と検証（2-3週間）

#### 4.1 基本統計量の計算

```matlab
% analysis/estimate_parameters_from_human_data.m

function params = estimate_parameters_from_human_data(data_dir)
    % 全Human-Humanデータを読み込み
    all_files = dir(fullfile(data_dir, '**/*stage2_cooperative_taps.csv'));

    all_iti = [];
    all_se = [];
    all_asynchrony = [];

    for i = 1:length(all_files)
        data = readtable(fullfile(all_files(i).folder, all_files(i).name));

        % Inter-Tap Interval計算
        timestamps = data.timestamp;
        iti = diff(timestamps);
        all_iti = [all_iti; iti];

        % Asynchrony計算（両プレイヤー間のずれ）
        p1_taps = data.timestamp(data.player_id == 1);
        p2_taps = data.timestamp(data.player_id == 2);

        min_len = min(length(p1_taps), length(p2_taps));
        if min_len > 0
            async = p1_taps(1:min_len) - p2_taps(1:min_len);
            all_asynchrony = [all_asynchrony; async];
        end
    end

    % パラメータ推定
    params.SPAN_mean = 2 * median(all_iti);
    params.SPAN_ci = [prctile(all_iti*2, 2.5), prctile(all_iti*2, 97.5)];

    params.SCALE_mean = std(all_iti);
    params.SCALE_ci = bootci(1000, @std, all_iti);

    % 自己相関からメモリ長推定
    if length(all_iti) > 20
        [acf, lags] = autocorr(all_iti, 10);
        significant_lag = find(acf < 0.2, 1);
        if ~isempty(significant_lag)
            params.BIB_L_MEMORY = significant_lag - 1;
        else
            params.BIB_L_MEMORY = 1;  % デフォルト
        end
    else
        params.BIB_L_MEMORY = 1;
    end

    % N_HYPOTHESIS推定（変動の幅から）
    % 仮説空間の範囲: ±3SD程度をカバー
    params.BAYES_N_HYPOTHESIS = ceil(6 * params.SCALE_mean / 0.05);  % 0.05秒刻み

    % 結果表示
    fprintf('=== Human-Humanデータから推定されたパラメータ ===\n');
    fprintf('データ数: %d タップ, %d セッション\n', length(all_iti), length(all_files));
    fprintf('\n');
    fprintf('SPAN = %.3f (95%%CI: [%.3f, %.3f])\n', ...
        params.SPAN_mean, params.SPAN_ci(1), params.SPAN_ci(2));
    fprintf('SCALE = %.3f (95%%CI: [%.3f, %.3f])\n', ...
        params.SCALE_mean, params.SCALE_ci(1), params.SCALE_ci(2));
    fprintf('BAYES_N_HYPOTHESIS = %d (推奨)\n', params.BAYES_N_HYPOTHESIS);
    fprintf('BIB_L_MEMORY = %d\n', params.BIB_L_MEMORY);

    % 詳細統計
    fprintf('\n=== 詳細統計 ===\n');
    fprintf('ITI: Mean=%.3fs, SD=%.3fs, CV=%.2f%%\n', ...
        mean(all_iti), std(all_iti), 100*std(all_iti)/mean(all_iti));
    fprintf('Asynchrony: Mean=%.3fs, SD=%.3fs\n', ...
        mean(all_asynchrony), std(all_asynchrony));
end
```

#### 4.2 モデル検証

```matlab
% analysis/validate_model_against_human.m

function results = validate_model_against_human(model_type, human_data_dir)
    % Human-Humanデータ読み込み
    human_stats = compute_human_statistics(human_data_dir);

    % モデルシミュレーション（同じ条件で）
    model_stats = simulate_model(model_type, human_stats.mean_se_sequence);

    % 統計的比較
    results.iti_ks_test = kstest2(human_stats.iti, model_stats.iti);
    results.iti_diff = mean(model_stats.iti) - mean(human_stats.iti);
    results.iti_cv_diff = std(model_stats.iti)/mean(model_stats.iti) - ...
                          std(human_stats.iti)/mean(human_stats.iti);

    % 評価基準
    if abs(results.iti_diff) < 0.05 && abs(results.iti_cv_diff) < 0.1
        results.verdict = 'GOOD: Human-like behavior';
    elseif abs(results.iti_diff) < 0.1 && abs(results.iti_cv_diff) < 0.2
        results.verdict = 'ACCEPTABLE: Within reasonable range';
    else
        results.verdict = 'POOR: Needs parameter adjustment';
    end

    % 結果表示
    fprintf('=== Model Validation: %s ===\n', model_type);
    fprintf('ITI difference: %.3fs\n', results.iti_diff);
    fprintf('CV difference: %.2f%%\n', results.iti_cv_diff * 100);
    fprintf('KS test p-value: %.3f\n', results.iti_ks_test);
    fprintf('Verdict: %s\n', results.verdict);
end
```

---

### Phase 5: 独立検証（2-3週間）

**目的**: フィッティングしたモデルの汎化性能を検証

**方法**:
1. 新しいHuman-Humanデータを収集（N=5ペア）
2. Phase 4で決定したパラメータでモデルをテスト
3. 予測精度を評価

---

## 実装ロードマップ

### 短期（今すぐ実施可能）

1. **データ収集の開始**
   ```bash
   # 現在のシステムで既にHuman-Humanデータ収集可能
   clear classes; rehash toolboxcache
   run_unified_experiment  # Option 2
   ```

2. **分析スクリプトの作成**
   - `analysis/estimate_parameters_from_human_data.m`
   - `analysis/validate_model_against_human.m`
   - `analysis/visualize_human_human_data.m`

### 中期（1-2ヶ月）

1. **パイロット実験実施** (N=3-5ペア)
2. **文献調査**
3. **予備的パラメータ推定**

### 長期（3-6ヶ月）

1. **本実験実施** (N=10-20ペア)
2. **最終パラメータ決定**
3. **論文執筆**

---

## 期待される成果

### 科学的貢献

1. **経験的に妥当なパラメータ**: Human-Humanデータに基づく客観的根拠
2. **モデル評価基準**: 「人間らしさ」の定量的指標
3. **モデル比較**: SEA/Bayesian/BIBの相対的性能

### 実用的利益

1. **ロバストな実験システム**: 参加者体験の向上
2. **再現性**: 他研究者が同じパラメータで追試可能
3. **拡張性**: 新しいモデルの開発指針

---

## リスクと対策

### リスク1: Human-Humanデータの個人差が大きすぎる

**対策**:
- 音楽経験で層別化
- 混合効果モデルで個人差を明示的にモデリング
- パラメータに個人差を許容する設計

### リスク2: モデル構造自体が不適切

**対策**:
- 文献調査で理論的妥当性を事前確認
- 必要に応じてモデル改良
- 複数モデルの比較評価

### リスク3: データ収集に時間がかかる

**対策**:
- パイロット実験で効率的なプロトコルを確立
- 既存データの活用（今後収集するデータを段階的に分析）

---

## 結論

**推奨アプローチ: Human-Humanデータ駆動型**

1. Human-Humanデータが自然な人間行動のグランドトゥルース
2. パラメータの統計的妥当性を確立可能
3. モデルの「人間らしさ」を客観評価可能
4. 現在のシステムで既にデータ収集可能

**今すぐ始めるべきこと**:
1. パイロット実験の実施（N=3-5ペア）
2. 分析スクリプトの作成
3. 文献調査の開始

---

**作成日**: 2025-10-09
**次回更新**: パイロット実験完了後
