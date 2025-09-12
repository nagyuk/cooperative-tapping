%% Python版とMATLAB版の数値計算結果比較
% Phase 3.2: 同一入力データでの計算結果一致性検証

function comparison_results = python_matlab_comparison()
    fprintf('=== Python-MATLAB 数値計算結果比較開始 ===\n');
    
    comparison_results = struct();
    comparison_results.start_time = datestr(now);
    
    % 比較対象モデル
    models_to_compare = {'sea', 'bayes', 'bib'};
    
    % 標準テストケース生成
    fprintf('\n標準テストケース生成中...\n');
    test_cases = generate_standard_test_cases();
    comparison_results.test_cases = test_cases;
    
    % 各モデルでの比較実行
    for i = 1:length(models_to_compare)
        model_type = models_to_compare{i};
        fprintf('\n--- %s モデル比較 ---\n', upper(model_type));
        
        try
            model_comparison = compare_model_implementation(model_type, test_cases);
            model_comparison.status = 'SUCCESS';
            comparison_results.(model_type) = model_comparison;
        catch ME
            fprintf('エラー: %s モデル比較失敗: %s\n', model_type, ME.message);
            model_comparison = struct();
            model_comparison.status = 'FAILED';
            model_comparison.error = ME.message;
            comparison_results.(model_type) = model_comparison;
        end
    end
    
    % 総合一致性評価
    fprintf('\n--- 総合一致性評価 ---\n');
    comparison_results.overall_consistency = evaluate_overall_consistency(comparison_results);
    
    % 結果保存
    save_comparison_results(comparison_results);
    
    comparison_results.end_time = datestr(now);
    
    fprintf('\n=== Python-MATLAB 比較完了 ===\n');
    display_comparison_summary(comparison_results);
end

function test_cases = generate_standard_test_cases()
    % 標準テストケース生成
    test_cases = struct();
    
    % 基本設定
    test_cases.config = struct();
    test_cases.config.span = 2.0;
    test_cases.config.scale = 0.1;
    test_cases.config.bayes_n_hypothesis = 20;
    test_cases.config.bayes_x_min = -3.0;
    test_cases.config.bayes_x_max = 3.0;
    test_cases.config.bib_l_memory = 1;
    
    % テストケース1: 典型的な同期エラーシーケンス
    test_cases.case1 = struct();
    test_cases.case1.name = '典型的同期エラー';
    test_cases.case1.stage1_errors = [0.05, -0.02, 0.03, -0.01, 0.04, -0.03, 0.02, -0.04, 0.01, -0.02];
    test_cases.case1.stage2_errors = [0.02, -0.01, 0.03, -0.02, 0.01, 0.015, -0.005, 0.025, -0.015, 0.008];
    
    % テストケース2: 段階的改善パターン
    test_cases.case2 = struct();
    test_cases.case2.name = '段階的改善';
    test_cases.case2.stage1_errors = linspace(0.1, 0.01, 10);
    test_cases.case2.stage2_errors = linspace(0.01, 0.001, 10);
    
    % テストケース3: 振動パターン
    test_cases.case3 = struct();
    test_cases.case3.name = '振動パターン';
    test_cases.case3.stage1_errors = 0.05 * sin(linspace(0, 2*pi, 10));
    test_cases.case3.stage2_errors = 0.02 * sin(linspace(0, 4*pi, 10));
    
    % テストケース4: ランダムパターン（再現可能）
    rng(12345); % 再現性のためのシード固定
    test_cases.case4 = struct();
    test_cases.case4.name = 'ランダムパターン';
    test_cases.case4.stage1_errors = 0.08 * randn(1, 10);
    test_cases.case4.stage2_errors = 0.03 * randn(1, 10);
    
    % テストケース5: 極値ケース
    test_cases.case5 = struct();
    test_cases.case5.name = '極値ケース';
    test_cases.case5.stage1_errors = [-0.2, 0.2, -0.15, 0.15, -0.1, 0.1, -0.05, 0.05, 0, 0];
    test_cases.case5.stage2_errors = [-0.1, 0.1, -0.08, 0.08, -0.05, 0.05, -0.02, 0.02, 0, 0];
    
    fprintf('生成された標準テストケース: %d種類\n', 5);
end

function model_comparison = compare_model_implementation(model_type, test_cases)
    % 個別モデルの実装比較
    
    model_comparison = struct();
    model_comparison.model_type = model_type;
    
    % MATLAB版実装結果取得
    fprintf('  MATLAB版実行中...\n');
    matlab_results = run_matlab_implementation(model_type, test_cases);
    model_comparison.matlab_results = matlab_results;
    
    % Python版参照実装結果生成
    fprintf('  Python版参照実装実行中...\n');
    python_results = generate_python_reference_results(model_type, test_cases);
    model_comparison.python_results = python_results;
    
    % 数値一致性分析
    fprintf('  数値一致性分析中...\n');
    consistency_analysis = analyze_numerical_consistency(matlab_results, python_results);
    model_comparison.consistency_analysis = consistency_analysis;
    
    fprintf('  %s モデル比較完了\n', upper(model_type));
end

function matlab_results = run_matlab_implementation(model_type, test_cases)
    % MATLAB実装でのテストケース実行
    
    matlab_results = struct();
    config = test_cases.config;
    
    case_names = {'case1', 'case2', 'case3', 'case4', 'case5'};
    
    for i = 1:length(case_names)
        case_name = case_names{i};
        test_case = test_cases.(case_name);
        
        % モデル作成
        switch lower(model_type)
            case 'sea'
                model = SEAModelMATLAB(config);
            case 'bayes'
                model = BayesModelMATLAB(config);
            case 'bib'
                model = BIBModelMATLAB(config);
        end
        
        % Stage 1処理
        model.initializeFromStage1(test_case.stage1_errors);
        
        % Stage 2処理
        stage2_predictions = zeros(length(test_case.stage2_errors), 1);
        for j = 1:length(test_case.stage2_errors)
            model.update(test_case.stage2_errors(j));
            stage2_predictions(j) = model.predictNextInterval();
        end
        
        % 結果記録
        case_result = struct();
        case_result.case_name = test_case.name;
        case_result.stage2_predictions = stage2_predictions;
        
        % モデル固有状態
        switch lower(model_type)
            case 'sea'
                state = model.getSEAState();
                case_result.final_cumulative_modify = state.cumulative_modify;
                case_result.final_average_modify = state.average_modify;
            case 'bayes'
                state = model.getBayesState();
                case_result.final_hypothesis_probs = state.probabilities;
                case_result.final_best_hypothesis = state.best_hypothesis;
                case_result.final_entropy = state.entropy;
            case 'bib'
                state = model.getBIBState();
                case_result.final_hypothesis_probs = state.probabilities;
                case_result.final_memory = state.memory;
                case_result.final_memory_mean = state.memory_mean;
        end
        
        matlab_results.(case_name) = case_result;
    end
end

function python_results = generate_python_reference_results(model_type, test_cases)
    % Python版参照実装結果生成（アルゴリズム再実装）
    
    python_results = struct();
    config = test_cases.config;
    
    case_names = {'case1', 'case2', 'case3', 'case4', 'case5'};
    
    for i = 1:length(case_names)
        case_name = case_names{i};
        test_case = test_cases.(case_name);
        
        % Python版アルゴリズム再実装
        switch lower(model_type)
            case 'sea'
                case_result = python_sea_reference(test_case, config);
            case 'bayes'
                case_result = python_bayes_reference(test_case, config);
            case 'bib'
                case_result = python_bib_reference(test_case, config);
        end
        
        case_result.case_name = test_case.name;
        python_results.(case_name) = case_result;
    end
end

function result = python_sea_reference(test_case, config)
    % Python版SEAアルゴリズム参照実装
    
    se_history = test_case.stage1_errors;
    modify = sum(se_history);
    
    stage2_predictions = zeros(length(test_case.stage2_errors), 1);
    
    for i = 1:length(test_case.stage2_errors)
        se = test_case.stage2_errors(i);
        
        % 履歴更新
        se_history(end+1) = se;
        modify = modify + se;
        
        % 平均修正値計算
        avg_modify = modify / length(se_history);
        
        % Python版ロジック: np.random.normal((SPAN / 2) - avg_modify, SCALE)
        % 決定論的版（比較のため）
        random_interval = (config.span / 2) - avg_modify;
        
        stage2_predictions(i) = random_interval;
    end
    
    result = struct();
    result.stage2_predictions = stage2_predictions;
    result.final_cumulative_modify = modify;
    result.final_average_modify = modify / length(se_history);
end

function result = python_bayes_reference(test_case, config)
    % Python版Bayesアルゴリズム参照実装
    
    n_hypothesis = config.bayes_n_hypothesis;
    x_min = config.bayes_x_min;
    x_max = config.bayes_x_max;
    
    % 仮説空間初期化
    likelihood = linspace(x_min, x_max, n_hypothesis);
    h_prov = ones(1, n_hypothesis) / n_hypothesis;
    
    % Stage 1処理
    for se = test_case.stage1_errors
        % ベイズ更新
        post_prov = zeros(1, n_hypothesis);
        for j = 1:n_hypothesis
            post_prov(j) = normpdf(se, likelihood(j), 0.3) * h_prov(j);
        end
        h_prov = post_prov / sum(post_prov);
    end
    
    % Stage 2処理
    stage2_predictions = zeros(length(test_case.stage2_errors), 1);
    
    for i = 1:length(test_case.stage2_errors)
        se = test_case.stage2_errors(i);
        
        % ベイズ更新
        post_prov = zeros(1, n_hypothesis);
        for j = 1:n_hypothesis
            post_prov(j) = normpdf(se, likelihood(j), 0.3) * h_prov(j);
        end
        h_prov = post_prov / sum(post_prov);
        
        % 予測（決定論的版）
        [~, max_idx] = max(h_prov);
        prediction = likelihood(max_idx);
        
        % Python版ロジック: (SPAN / 2) - prediction
        stage2_predictions(i) = (config.span / 2) - prediction;
    end
    
    result = struct();
    result.stage2_predictions = stage2_predictions;
    result.final_hypothesis_probs = h_prov;
    [~, max_idx] = max(h_prov);
    result.final_best_hypothesis = likelihood(max_idx);
    result.final_entropy = -sum(h_prov .* log(h_prov + eps));
end

function result = python_bib_reference(test_case, config)
    % Python版BIBアルゴリズム参照実装
    
    n_hypothesis = config.bayes_n_hypothesis;
    x_min = config.bayes_x_min;
    x_max = config.bayes_x_max;
    l_memory = config.bib_l_memory;
    
    % 初期化
    likelihood = linspace(x_min, x_max, n_hypothesis);
    h_prov = ones(1, n_hypothesis) / n_hypothesis;
    memory = config.scale * randn(1, l_memory);
    
    % Stage 1処理
    for se = test_case.stage1_errors
        if l_memory > 0
            % 逆ベイズ学習
            new_hypo = mean(memory);
            inv_h_prov = (1 - h_prov) / (n_hypothesis - 1);
            inv_h_prov = inv_h_prov / sum(inv_h_prov);
            
            % 仮説置換（決定論的版）
            [~, selected_idx] = max(inv_h_prov);
            likelihood(selected_idx) = new_hypo;
            
            % メモリ更新
            memory = [memory(2:end), se];
        end
        
        % 通常のベイズ更新
        post_prov = zeros(1, n_hypothesis);
        for j = 1:n_hypothesis
            post_prov(j) = normpdf(se, likelihood(j), 0.3) * h_prov(j);
        end
        h_prov = post_prov / sum(post_prov);
    end
    
    % Stage 2処理
    stage2_predictions = zeros(length(test_case.stage2_errors), 1);
    
    for i = 1:length(test_case.stage2_errors)
        se = test_case.stage2_errors(i);
        
        if l_memory > 0
            % 逆ベイズ学習
            new_hypo = mean(memory);
            inv_h_prov = (1 - h_prov) / (n_hypothesis - 1);
            inv_h_prov = inv_h_prov / sum(inv_h_prov);
            
            [~, selected_idx] = max(inv_h_prov);
            likelihood(selected_idx) = new_hypo;
            
            memory = [memory(2:end), se];
        end
        
        % 通常のベイズ更新
        post_prov = zeros(1, n_hypothesis);
        for j = 1:n_hypothesis
            post_prov(j) = normpdf(se, likelihood(j), 0.3) * h_prov(j);
        end
        h_prov = post_prov / sum(post_prov);
        
        % 予測
        [~, max_idx] = max(h_prov);
        prediction = likelihood(max_idx);
        stage2_predictions(i) = (config.span / 2) - prediction;
    end
    
    result = struct();
    result.stage2_predictions = stage2_predictions;
    result.final_hypothesis_probs = h_prov;
    result.final_memory = memory;
    result.final_memory_mean = mean(memory);
end

function consistency = analyze_numerical_consistency(matlab_results, python_results)
    % 数値一致性分析
    
    consistency = struct();
    case_names = {'case1', 'case2', 'case3', 'case4', 'case5'};
    
    total_differences = [];
    
    for i = 1:length(case_names)
        case_name = case_names{i};
        
        matlab_pred = matlab_results.(case_name).stage2_predictions;
        python_pred = python_results.(case_name).stage2_predictions;
        
        % 予測値差分分析
        pred_diff = abs(matlab_pred - python_pred);
        max_diff = max(pred_diff);
        mean_diff = mean(pred_diff);
        rms_diff = sqrt(mean(pred_diff.^2));
        
        case_consistency = struct();
        case_consistency.max_difference = max_diff;
        case_consistency.mean_difference = mean_diff;
        case_consistency.rms_difference = rms_diff;
        case_consistency.relative_error = mean_diff / mean(abs(python_pred));
        
        % 一致性判定
        if max_diff < 1e-10
            case_consistency.consistency_level = 'IDENTICAL';
        elseif max_diff < 1e-6
            case_consistency.consistency_level = 'VERY_HIGH';
        elseif max_diff < 1e-3
            case_consistency.consistency_level = 'HIGH';
        elseif max_diff < 1e-2
            case_consistency.consistency_level = 'MODERATE';
        else
            case_consistency.consistency_level = 'LOW';
        end
        
        total_differences = [total_differences; pred_diff];
        consistency.(case_name) = case_consistency;
        
        fprintf('    %s: %s (最大差分: %.2e)\n', ...
            case_name, case_consistency.consistency_level, max_diff);
    end
    
    % 総合一致性
    consistency.overall_max_diff = max(total_differences);
    consistency.overall_mean_diff = mean(total_differences);
    consistency.overall_rms_diff = sqrt(mean(total_differences.^2));
    
    if consistency.overall_max_diff < 1e-6
        consistency.overall_consistency = 'EXCELLENT';
    elseif consistency.overall_max_diff < 1e-3
        consistency.overall_consistency = 'GOOD';
    elseif consistency.overall_max_diff < 1e-2
        consistency.overall_consistency = 'ACCEPTABLE';
    else
        consistency.overall_consistency = 'POOR';
    end
end

function overall_consistency = evaluate_overall_consistency(comparison_results)
    % 総合一致性評価
    
    overall_consistency = struct();
    models = {'sea', 'bayes', 'bib'};
    
    successful_comparisons = 0;
    consistency_scores = [];
    
    for i = 1:length(models)
        model = models{i};
        if isfield(comparison_results, model) && strcmp(comparison_results.(model).status, 'SUCCESS')
            successful_comparisons = successful_comparisons + 1;
            
            analysis = comparison_results.(model).consistency_analysis;
            
            % 数値スコア化
            if strcmp(analysis.overall_consistency, 'EXCELLENT')
                score = 100;
            elseif strcmp(analysis.overall_consistency, 'GOOD')
                score = 80;
            elseif strcmp(analysis.overall_consistency, 'ACCEPTABLE')
                score = 60;
            else
                score = 40;
            end
            
            consistency_scores(end+1) = score;
        end
    end
    
    if isempty(consistency_scores)
        overall_consistency.average_score = 0;
        overall_consistency.grade = 'FAILED';
    else
        overall_consistency.average_score = mean(consistency_scores);
        overall_consistency.successful_models = successful_comparisons;
        overall_consistency.total_models = length(models);
        
        if overall_consistency.average_score >= 90
            overall_consistency.grade = 'EXCELLENT';
        elseif overall_consistency.average_score >= 75
            overall_consistency.grade = 'GOOD';
        elseif overall_consistency.average_score >= 60
            overall_consistency.grade = 'ACCEPTABLE';
        else
            overall_consistency.grade = 'POOR';
        end
    end
    
    fprintf('総合一致性評価: %s (平均スコア: %.1f)\n', ...
        overall_consistency.grade, overall_consistency.average_score);
end

function save_comparison_results(comparison_results)
    % 比較結果保存
    timestamp = datestr(now, 'yyyymmdd_HHMMSS');
    output_dir = fullfile('matlab_verification', 'phase3_model_integration');
    
    if ~exist(output_dir, 'dir')
        mkdir(output_dir);
    end
    
    % MAT形式保存
    mat_file = fullfile(output_dir, sprintf('python_matlab_comparison_%s.mat', timestamp));
    save(mat_file, 'comparison_results');
    
    % 詳細レポート生成
    report_file = fullfile(output_dir, sprintf('comparison_report_%s.txt', timestamp));
    generate_comparison_report(comparison_results, report_file);
    
    fprintf('\n比較結果保存完了:\n');
    fprintf('  %s\n', mat_file);
    fprintf('  %s\n', report_file);
end

function generate_comparison_report(comparison_results, report_file)
    % 詳細比較レポート生成
    fid = fopen(report_file, 'w');
    
    fprintf(fid, 'Python-MATLAB 数値計算結果比較レポート\n');
    fprintf(fid, '=====================================\n\n');
    fprintf(fid, '実行期間: %s - %s\n\n', comparison_results.start_time, comparison_results.end_time);
    
    % 個別モデル結果
    models = {'sea', 'bayes', 'bib'};
    for i = 1:length(models)
        model = models{i};
        if isfield(comparison_results, model)
            fprintf(fid, '%s モデル比較結果:\n', upper(model));
            fprintf(fid, '-------------------\n');
            
            model_result = comparison_results.(model);
            fprintf(fid, 'ステータス: %s\n', model_result.status);
            
            if strcmp(model_result.status, 'SUCCESS')
                consistency = model_result.consistency_analysis;
                fprintf(fid, '総合一致性: %s\n', consistency.overall_consistency);
                fprintf(fid, '最大差分: %.2e\n', consistency.overall_max_diff);
                fprintf(fid, '平均差分: %.2e\n', consistency.overall_mean_diff);
                fprintf(fid, 'RMS差分: %.2e\n', consistency.overall_rms_diff);
            else
                fprintf(fid, 'エラー: %s\n', model_result.error);
            end
            
            fprintf(fid, '\n');
        end
    end
    
    % 総合評価
    if isfield(comparison_results, 'overall_consistency')
        overall = comparison_results.overall_consistency;
        fprintf(fid, '総合評価:\n');
        fprintf(fid, '--------\n');
        fprintf(fid, '等級: %s\n', overall.grade);
        fprintf(fid, '平均スコア: %.1f/100\n', overall.average_score);
        fprintf(fid, '成功モデル数: %d/%d\n', overall.successful_models, overall.total_models);
    end
    
    fclose(fid);
end

function display_comparison_summary(comparison_results)
    % 比較結果サマリー表示
    fprintf('\n【Python-MATLAB比較結果サマリー】\n');
    
    models = {'sea', 'bayes', 'bib'};
    for i = 1:length(models)
        model = models{i};
        if isfield(comparison_results, model)
            if strcmp(comparison_results.(model).status, 'SUCCESS')
                consistency = comparison_results.(model).consistency_analysis.overall_consistency;
                fprintf('%s: %s\n', upper(model), consistency);
            else
                fprintf('%s: FAILED\n', upper(model));
            end
        end
    end
    
    if isfield(comparison_results, 'overall_consistency')
        overall = comparison_results.overall_consistency;
        fprintf('\n総合評価: %s (%.1f/100)\n', overall.grade, overall.average_score);
    end
    
    fprintf('\n次のステップ: Phase 3.3 タイミング精度実測・調整\n');
end