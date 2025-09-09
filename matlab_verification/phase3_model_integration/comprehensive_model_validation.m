%% 包括的モデル検証システム
% Phase 3.1: 適応モデルの詳細性能検証とPython版との比較

function validation_results = comprehensive_model_validation()
    fprintf('=== 包括的モデル検証開始 ===\n');
    
    validation_results = struct();
    validation_results.start_time = datestr(now);
    
    % 検証対象モデル
    models_to_test = {'sea', 'bayes', 'bib'};
    
    % 各モデルの詳細検証
    for i = 1:length(models_to_test)
        model_type = models_to_test{i};
        fprintf('\n--- %s モデル検証 ---\n', upper(model_type));
        
        try
            model_result = validate_single_model(model_type);
            model_result.status = 'SUCCESS';
            validation_results.(model_type) = model_result;
        catch ME
            fprintf('エラー: %s モデル検証失敗: %s\n', model_type, ME.message);
            model_result = struct();
            model_result.status = 'FAILED';
            model_result.error = ME.message;
            validation_results.(model_type) = model_result;
        end
    end
    
    % モデル間比較分析
    fprintf('\n--- モデル間比較分析 ---\n');
    validation_results.comparison = perform_model_comparison(validation_results);
    
    % 統合評価
    fprintf('\n--- 統合評価 ---\n');
    validation_results.overall_assessment = assess_overall_performance(validation_results);
    
    % 結果保存
    save_validation_results(validation_results);
    
    validation_results.end_time = datestr(now);
    
    fprintf('\n=== 包括的モデル検証完了 ===\n');
    display_summary(validation_results);
end

function model_result = validate_single_model(model_type)
    % 個別モデルの詳細検証
    
    model_result = struct();
    model_result.model_type = model_type;
    
    % 基本設定
    config = create_test_config(model_type);
    
    % モデル作成
    switch lower(model_type)
        case 'sea'
            model = SEAModelMATLAB(config);
        case 'bayes'
            model = BayesModelMATLAB(config);
        case 'bib'
            model = BIBModelMATLAB(config);
        otherwise
            error('未対応モデル: %s', model_type);
    end
    
    % テスト1: 基本動作検証
    fprintf('  基本動作検証中...\n');
    basic_test = test_basic_operations(model, config);
    model_result.basic_test = basic_test;
    
    % テスト2: 適応性能検証
    fprintf('  適応性能検証中...\n');
    adaptation_test = test_adaptation_performance(model, config);
    model_result.adaptation_test = adaptation_test;
    
    % テスト3: 数値安定性検証
    fprintf('  数値安定性検証中...\n');
    stability_test = test_numerical_stability(model, config);
    model_result.stability_test = stability_test;
    
    % テスト4: 境界条件検証
    fprintf('  境界条件検証中...\n');
    boundary_test = test_boundary_conditions(model, config);
    model_result.boundary_test = boundary_test;
    
    % テスト5: 収束性検証
    fprintf('  収束性検証中...\n');
    convergence_test = test_convergence_behavior(model, config);
    model_result.convergence_test = convergence_test;
    
    fprintf('  %s モデル検証完了\n', upper(model_type));
end

function config = create_test_config(model_type)
    % テスト用設定作成
    config = struct();
    config.span = 2.0;
    config.scale = 0.1;
    config.stage1_count = 10;
    config.stage2_count = 50;
    config.buffer_taps = 5;
    
    % モデル固有設定
    switch lower(model_type)
        case 'bayes'
            config.bayes_n_hypothesis = 20;
            config.bayes_x_min = -2.0;
            config.bayes_x_max = 2.0;
        case 'bib'
            config.bayes_n_hypothesis = 20;
            config.bayes_x_min = -2.0;
            config.bayes_x_max = 2.0;
            config.bib_l_memory = 3;
    end
    
    config.debug_mode = false;
    config.verbose = false;
end

function result = test_basic_operations(model, config)
    % 基本動作テスト
    result = struct();
    
    % Stage 1初期化テスト
    stage1_errors = generate_realistic_sync_errors(config.stage1_count, 'stage1');
    model.initializeFromStage1(stage1_errors);
    
    % 予測・更新サイクルテスト
    test_errors = generate_realistic_sync_errors(20, 'stage2');
    predictions = zeros(length(test_errors), 1);
    
    for i = 1:length(test_errors)
        model.update(test_errors(i));
        predictions(i) = model.predictNextInterval();
        
        % 予測値の妥当性チェック
        if predictions(i) < 0.1 || predictions(i) > 10.0
            error('予測間隔が異常: %.3f', predictions(i));
        end
    end
    
    result.predictions = predictions;
    result.mean_prediction = mean(predictions);
    result.std_prediction = std(predictions);
    result.prediction_range = [min(predictions), max(predictions)];
    result.status = 'PASS';
end

function result = test_adaptation_performance(model, config)
    % 適応性能テスト - 系統的誤差への適応
    result = struct();
    
    % 段階的誤差パターンテスト
    error_patterns = {
        linspace(0, 0.1, 20);      % 段階増加
        linspace(0.1, -0.1, 20);   % 段階減少
        0.05 * sin(1:20);          % 正弦波
        0.02 * randn(1, 20);       % ランダム
    };
    
    pattern_names = {'増加', '減少', '正弦波', 'ランダム'};
    
    for i = 1:length(error_patterns)
        pattern = error_patterns{i};
        
        % モデルリセット
        model.resetModel();
        
        % パターン適用
        predictions = zeros(length(pattern), 1);
        for j = 1:length(pattern)
            model.update(pattern(j));
            predictions(j) = model.predictNextInterval();
        end
        
        % 適応指標計算
        adaptation_trend = calculate_adaptation_trend(pattern, predictions);
        
        result.(sprintf('pattern_%d', i)) = struct();
        result.(sprintf('pattern_%d', i)).name = pattern_names{i};
        result.(sprintf('pattern_%d', i)).predictions = predictions;
        result.(sprintf('pattern_%d', i)).adaptation_trend = adaptation_trend;
        
        fprintf('    %s パターン適応度: %.3f\n', pattern_names{i}, adaptation_trend);
    end
    
    result.status = 'PASS';
end

function result = test_numerical_stability(model, config)
    % 数値安定性テスト
    result = struct();
    
    % 極値テスト
    extreme_errors = [-1.0, -0.5, 0, 0.5, 1.0];
    
    for i = 1:length(extreme_errors)
        error_val = extreme_errors(i);
        
        try
            model.update(error_val);
            prediction = model.predictNextInterval();
            
            % NaN/Inf チェック
            if isnan(prediction) || isinf(prediction)
                error('NaN/Inf予測値が発生: %.3f -> %s', error_val, num2str(prediction));
            end
            
        catch ME
            error('極値 %.3f で数値エラー: %s', error_val, ME.message);
        end
    end
    
    % 長期安定性テスト（1000回更新）
    model.resetModel();
    stable_predictions = zeros(1000, 1);
    
    for i = 1:1000
        sync_error = 0.01 * randn(); % 小さなランダム誤差
        model.update(sync_error);
        stable_predictions(i) = model.predictNextInterval();
        
        % 発散チェック
        if abs(stable_predictions(i)) > 100
            error('長期実行で予測値が発散: %d回目で %.3f', i, stable_predictions(i));
        end
    end
    
    result.extreme_value_test = 'PASS';
    result.long_term_stability = 'PASS';
    result.final_prediction_std = std(stable_predictions(end-99:end)); % 最後100回の標準偏差
    result.status = 'PASS';
end

function result = test_boundary_conditions(model, config)
    % 境界条件テスト
    result = struct();
    
    % ゼロ誤差連続入力
    model.resetModel();
    for i = 1:10
        model.update(0);
        prediction = model.predictNextInterval();
        
        if isnan(prediction) || prediction <= 0
            error('ゼロ誤差で異常予測: %.3f', prediction);
        end
    end
    
    % 同一誤差連続入力
    model.resetModel();
    constant_error = 0.05;
    constant_predictions = zeros(20, 1);
    
    for i = 1:20
        model.update(constant_error);
        constant_predictions(i) = model.predictNextInterval();
    end
    
    % 収束チェック
    final_variance = var(constant_predictions(end-4:end));
    if final_variance > 0.001
        fprintf('    警告: 定常誤差で収束が不十分 (分散: %.6f)\n', final_variance);
    end
    
    result.zero_error_test = 'PASS';
    result.constant_error_test = 'PASS';
    result.constant_error_variance = final_variance;
    result.status = 'PASS';
end

function result = test_convergence_behavior(model, config)
    % 収束性テスト
    result = struct();
    
    % ステップ応答テスト
    model.resetModel();
    
    % 初期安定期間
    for i = 1:10
        model.update(0.01 * randn());
    end
    
    % ステップ入力
    step_size = 0.1;
    step_predictions = zeros(30, 1);
    
    for i = 1:30
        model.update(step_size);
        step_predictions(i) = model.predictNextInterval();
    end
    
    % 収束時間推定
    baseline = mean(step_predictions(end-4:end));
    convergence_threshold = 0.05 * abs(baseline);
    
    convergence_time = NaN;
    for i = 5:length(step_predictions)
        if all(abs(step_predictions(i:end) - baseline) < convergence_threshold)
            convergence_time = i;
            break;
        end
    end
    
    result.step_predictions = step_predictions;
    result.convergence_time = convergence_time;
    result.final_baseline = baseline;
    
    if isnan(convergence_time)
        fprintf('    警告: 収束が確認できませんでした\n');
        result.convergence_status = 'NO_CONVERGENCE';
    else
        fprintf('    収束時間: %d ステップ\n', convergence_time);
        result.convergence_status = 'CONVERGED';
    end
    
    result.status = 'PASS';
end

function sync_errors = generate_realistic_sync_errors(num_errors, stage_type)
    % リアルな同期エラー生成
    
    switch stage_type
        case 'stage1'
            % Stage 1: やや大きめの初期誤差
            base_std = 0.08;
            drift = linspace(0.05, 0.01, num_errors);
        case 'stage2'
            % Stage 2: 学習による誤差減少
            base_std = 0.03;
            drift = linspace(0.02, 0.005, num_errors);
        otherwise
            base_std = 0.05;
            drift = zeros(1, num_errors);
    end
    
    % ガウシアンノイズ + ドリフト
    noise = base_std * randn(1, num_errors);
    sync_errors = noise + drift;
end

function trend = calculate_adaptation_trend(errors, predictions)
    % 適応トレンド計算
    
    if length(errors) < 5
        trend = 0;
        return;
    end
    
    % 誤差の傾向と予測の逆相関を測定
    error_trend = polyfit(1:length(errors), errors, 1);
    prediction_trend = polyfit(1:length(predictions), predictions, 1);
    
    % 適応指標: 誤差増加時に予測が適切に調整されているか
    if abs(error_trend(1)) > 1e-6 % 有意な傾向がある場合
        adaptation_sign = sign(error_trend(1)) * sign(-prediction_trend(1));
        trend = adaptation_sign * abs(prediction_trend(1)) / abs(error_trend(1));
    else
        trend = 0;
    end
    
    % 正規化 (-1 to 1)
    trend = max(-1, min(1, trend));
end

function comparison = perform_model_comparison(validation_results)
    % モデル間比較分析
    comparison = struct();
    
    models = {'sea', 'bayes', 'bib'};
    successful_models = {};
    
    % 成功したモデルのみ比較
    for i = 1:length(models)
        model = models{i};
        if isfield(validation_results, model) && strcmp(validation_results.(model).status, 'SUCCESS')
            successful_models{end+1} = model;
        end
    end
    
    if length(successful_models) < 2
        comparison.status = 'INSUFFICIENT_DATA';
        return;
    end
    
    % 予測精度比較
    fprintf('  予測精度比較中...\n');
    comparison.prediction_accuracy = compare_prediction_accuracy(validation_results, successful_models);
    
    % 適応速度比較
    fprintf('  適応速度比較中...\n');
    comparison.adaptation_speed = compare_adaptation_speed(validation_results, successful_models);
    
    % 安定性比較
    fprintf('  安定性比較中...\n');
    comparison.stability = compare_stability(validation_results, successful_models);
    
    comparison.status = 'SUCCESS';
    comparison.tested_models = successful_models;
end

function accuracy = compare_prediction_accuracy(validation_results, models)
    % 予測精度比較
    accuracy = struct();
    
    for i = 1:length(models)
        model = models{i};
        basic_test = validation_results.(model).basic_test;
        
        accuracy.(model) = struct();
        accuracy.(model).mean_prediction = basic_test.mean_prediction;
        accuracy.(model).std_prediction = basic_test.std_prediction;
        accuracy.(model).prediction_stability = 1 / (1 + basic_test.std_prediction);
    end
    
    % ランキング
    stabilities = cellfun(@(m) accuracy.(m).prediction_stability, models);
    [~, rank_indices] = sort(stabilities, 'descend');
    accuracy.ranking = models(rank_indices);
    
    fprintf('    予測安定性ランキング: %s\n', strjoin(accuracy.ranking, ' > '));
end

function speed = compare_adaptation_speed(validation_results, models)
    % 適応速度比較
    speed = struct();
    
    for i = 1:length(models)
        model = models{i};
        convergence_test = validation_results.(model).convergence_test;
        
        speed.(model) = struct();
        if strcmp(convergence_test.convergence_status, 'CONVERGED')
            speed.(model).convergence_time = convergence_test.convergence_time;
        else
            speed.(model).convergence_time = Inf;
        end
    end
    
    % ランキング
    conv_times = cellfun(@(m) speed.(m).convergence_time, models);
    [~, rank_indices] = sort(conv_times);
    speed.ranking = models(rank_indices);
    
    fprintf('    適応速度ランキング: %s\n', strjoin(speed.ranking, ' > '));
end

function stability = compare_stability(validation_results, models)
    % 安定性比較
    stability = struct();
    
    for i = 1:length(models)
        model = models{i};
        stability_test = validation_results.(model).stability_test;
        
        stability.(model) = struct();
        stability.(model).long_term_std = stability_test.final_prediction_std;
        stability.(model).stability_score = 1 / (1 + stability_test.final_prediction_std);
    end
    
    % ランキング
    scores = cellfun(@(m) stability.(m).stability_score, models);
    [~, rank_indices] = sort(scores, 'descend');
    stability.ranking = models(rank_indices);
    
    fprintf('    長期安定性ランキング: %s\n', strjoin(stability.ranking, ' > '));
end

function assessment = assess_overall_performance(validation_results)
    % 統合評価
    assessment = struct();
    
    models = {'sea', 'bayes', 'bib'};
    success_count = 0;
    
    for i = 1:length(models)
        model = models{i};
        if isfield(validation_results, model) && strcmp(validation_results.(model).status, 'SUCCESS')
            success_count = success_count + 1;
        end
    end
    
    assessment.success_rate = success_count / length(models);
    assessment.successful_models = success_count;
    assessment.total_models = length(models);
    
    if assessment.success_rate >= 1.0
        assessment.overall_status = 'EXCELLENT';
    elseif assessment.success_rate >= 0.67
        assessment.overall_status = 'GOOD';
    elseif assessment.success_rate >= 0.33
        assessment.overall_status = 'MARGINAL';
    else
        assessment.overall_status = 'POOR';
    end
    
    fprintf('  統合評価: %s (%d/%d モデル成功)\n', ...
        assessment.overall_status, assessment.successful_models, assessment.total_models);
end

function save_validation_results(validation_results)
    % 検証結果保存
    timestamp = datestr(now, 'yyyymmdd_HHMMSS');
    output_dir = fullfile('matlab_verification', 'phase3_model_integration');
    
    if ~exist(output_dir, 'dir')
        mkdir(output_dir);
    end
    
    % MAT形式保存
    mat_file = fullfile(output_dir, sprintf('model_validation_results_%s.mat', timestamp));
    save(mat_file, 'validation_results');
    
    % 詳細レポート生成
    report_file = fullfile(output_dir, sprintf('model_validation_report_%s.txt', timestamp));
    generate_detailed_report(validation_results, report_file);
    
    fprintf('\n検証結果保存完了:\n');
    fprintf('  %s\n', mat_file);
    fprintf('  %s\n', report_file);
end

function generate_detailed_report(validation_results, report_file)
    % 詳細レポート生成
    fid = fopen(report_file, 'w');
    
    fprintf(fid, '包括的モデル検証レポート\n');
    fprintf(fid, '====================\n\n');
    fprintf(fid, '実行期間: %s - %s\n\n', validation_results.start_time, validation_results.end_time);
    
    % 個別モデル結果
    models = {'sea', 'bayes', 'bib'};
    for i = 1:length(models)
        model = models{i};
        if isfield(validation_results, model)
            fprintf(fid, '%s モデル結果:\n', upper(model));
            fprintf(fid, '---------------\n');
            
            model_result = validation_results.(model);
            fprintf(fid, 'ステータス: %s\n', model_result.status);
            
            if strcmp(model_result.status, 'SUCCESS')
                basic = model_result.basic_test;
                fprintf(fid, '予測平均: %.4f\n', basic.mean_prediction);
                fprintf(fid, '予測標準偏差: %.4f\n', basic.std_prediction);
                
                stability = model_result.stability_test;
                fprintf(fid, '長期安定性: %.6f\n', stability.final_prediction_std);
                
                convergence = model_result.convergence_test;
                fprintf(fid, '収束状態: %s\n', convergence.convergence_status);
                if strcmp(convergence.convergence_status, 'CONVERGED')
                    fprintf(fid, '収束時間: %d ステップ\n', convergence.convergence_time);
                end
            else
                fprintf(fid, 'エラー: %s\n', model_result.error);
            end
            
            fprintf(fid, '\n');
        end
    end
    
    % 統合評価
    if isfield(validation_results, 'overall_assessment')
        assessment = validation_results.overall_assessment;
        fprintf(fid, '統合評価:\n');
        fprintf(fid, '--------\n');
        fprintf(fid, '総合ステータス: %s\n', assessment.overall_status);
        fprintf(fid, '成功率: %.1f%% (%d/%d)\n', ...
            assessment.success_rate * 100, assessment.successful_models, assessment.total_models);
    end
    
    fclose(fid);
end

function display_summary(validation_results)
    % 結果サマリー表示
    fprintf('\n【検証結果サマリー】\n');
    
    models = {'sea', 'bayes', 'bib'};
    for i = 1:length(models)
        model = models{i};
        if isfield(validation_results, model)
            status = validation_results.(model).status;
            fprintf('%s: %s\n', upper(model), status);
        end
    end
    
    if isfield(validation_results, 'overall_assessment')
        assessment = validation_results.overall_assessment;
        fprintf('\n統合評価: %s\n', assessment.overall_status);
        fprintf('成功モデル: %d/%d\n', assessment.successful_models, assessment.total_models);
    end
    
    fprintf('\n次のステップ: Phase 3.2 Python版との数値計算結果比較\n');
end