%% タイミング精度検証テスト
% MATLAB移行Phase 1.2: posixtime使用によるマイクロ秒精度タイミング検証
%
% 目的:
% - posixtime()によるタイミング精度測定
% - PsychoPy core.Clock()との比較
% - 実験で必要な1-5ms精度の実現確認

function results = timing_precision_test()
    fprintf('=== タイミング精度検証開始 ===\n');
    
    % 複数の精度テスト実行
    tests = {
        struct('name', 'マイクロ秒精度基本テスト', 'test_func', @test_microsecond_precision);
        struct('name', '短間隔タイミング精度', 'test_func', @test_short_interval_precision);
        struct('name', '長時間安定性テスト', 'test_func', @test_long_term_stability);
        struct('name', 'tic/toc比較テスト', 'test_func', @test_tictoc_comparison);
        struct('name', 'システム負荷影響テスト', 'test_func', @test_system_load_impact);
    };
    
    results = struct();
    
    for i = 1:length(tests)
        fprintf('\n--- %s ---\n', tests{i}.name);
        results.(sprintf('test%d', i)) = tests{i}.test_func();
        results.(sprintf('test%d', i)).name = tests{i}.name;
    end
    
    % 総合評価とレポート生成
    overall_assessment = evaluate_timing_performance(results);
    generate_timing_report(results, overall_assessment);
    
    fprintf('\n=== タイミング精度検証完了 ===\n');
end

function result = test_microsecond_precision()
    % posixtime()の基本精度測定
    fprintf('  posixtime()基本精度を測定中...\n');
    
    num_samples = 10000;
    intervals = [];
    
    % 連続測定での最小分解能確認
    prev_time = posixtime(datetime('now', 'TimeZone', 'local'));
    
    for i = 1:num_samples
        current_time = posixtime(datetime('now', 'TimeZone', 'local'));
        if current_time > prev_time
            intervals(end+1) = (current_time - prev_time) * 1000000; % マイクロ秒
            prev_time = current_time;
        end
    end
    
    % 統計解析
    min_resolution = min(intervals);
    mean_resolution = mean(intervals);
    std_resolution = std(intervals);
    
    fprintf('    最小分解能: %.1f μs\n', min_resolution);
    fprintf('    平均分解能: %.1f μs\n', mean_resolution);
    fprintf('    標準偏差: %.1f μs\n', std_resolution);
    
    result = struct();
    result.min_resolution_us = min_resolution;
    result.mean_resolution_us = mean_resolution;
    result.std_resolution_us = std_resolution;
    result.intervals_us = intervals;
    result.num_samples = length(intervals);
end

function result = test_short_interval_precision()
    % 短間隔（1-10ms）での精度テスト
    fprintf('  短間隔タイミング精度テスト中...\n');
    
    target_intervals = [1, 2, 5, 10]; % ms
    num_repeats = 1000;
    
    results_by_interval = struct();
    
    for target_ms = target_intervals
        fprintf('    目標間隔: %d ms\n', target_ms);
        
        measured_intervals = zeros(num_repeats, 1);
        
        for i = 1:num_repeats
            start_time = posixtime(datetime('now', 'TimeZone', 'local'));
            pause(target_ms / 1000); % 目標間隔待機
            end_time = posixtime(datetime('now', 'TimeZone', 'local'));
            
            measured_intervals(i) = (end_time - start_time) * 1000; % ms
        end
        
        % 精度分析
        mean_measured = mean(measured_intervals);
        std_measured = std(measured_intervals);
        error_mean = mean_measured - target_ms;
        error_std = std_measured;
        
        fprintf('      測定平均: %.3f ms (誤差: %+.3f ms)\n', mean_measured, error_mean);
        fprintf('      標準偏差: %.3f ms\n', std_measured);
        
        results_by_interval.(sprintf('target_%dms', target_ms)) = struct(...
            'target_ms', target_ms, ...
            'measured_intervals', measured_intervals, ...
            'mean_measured', mean_measured, ...
            'std_measured', std_measured, ...
            'error_mean', error_mean, ...
            'error_std', error_std ...
        );
    end
    
    result = results_by_interval;
end

function result = test_long_term_stability()
    % 長時間（1分間）での安定性テスト
    fprintf('  長時間安定性テスト中（60秒）...\n');
    
    test_duration = 60; % 秒
    measurement_interval = 0.1; % 100ms間隔
    expected_measurements = test_duration / measurement_interval;
    
    timestamps = [];
    intervals = [];
    
    start_time = posixtime(datetime('now', 'TimeZone', 'local'));
    last_time = start_time;
    
    fprintf('    進捗: ');
    progress_counter = 0;
    
    while true
        current_time = posixtime(datetime('now', 'TimeZone', 'local'));
        elapsed = current_time - start_time;
        
        if elapsed >= test_duration
            break;
        end
        
        % 間隔測定
        if current_time - last_time >= measurement_interval
            timestamps(end+1) = current_time;
            if length(timestamps) > 1
                intervals(end+1) = (timestamps(end) - timestamps(end-1)) * 1000; % ms
            end
            last_time = current_time;
            
            % 進捗表示
            progress_counter = progress_counter + 1;
            if mod(progress_counter, 50) == 0
                fprintf('%.0f%% ', (elapsed/test_duration)*100);
            end
        end
        
        pause(0.001); % CPUリソース節約
    end
    
    fprintf('完了\n');
    
    % ドリフト分析
    if length(intervals) > 10
        mean_interval = mean(intervals);
        std_interval = std(intervals);
        drift_per_minute = (intervals(end) - intervals(1));
        
        fprintf('    平均間隔: %.3f ms\n', mean_interval);
        fprintf('    標準偏差: %.3f ms\n', std_interval);
        fprintf('    1分間ドリフト: %+.3f ms\n', drift_per_minute);
    end
    
    result = struct();
    result.test_duration_s = test_duration;
    result.intervals_ms = intervals;
    result.timestamps = timestamps;
    result.mean_interval = mean(intervals);
    result.std_interval = std(intervals);
    result.num_measurements = length(intervals);
    if length(intervals) > 1
        result.drift_per_minute = intervals(end) - intervals(1);
    else
        result.drift_per_minute = 0;
    end
end

function result = test_tictoc_comparison()
    % tic/tocとposixtime比較
    fprintf('  tic/toc vs posixtime 比較テスト中...\n');
    
    num_tests = 1000;
    posixtime_results = zeros(num_tests, 1);
    tictoc_results = zeros(num_tests, 1);
    
    for i = 1:num_tests
        % posixtime測定
        t1_posix = posixtime(datetime('now', 'TimeZone', 'local'));
        pause(0.001); % 1ms
        t2_posix = posixtime(datetime('now', 'TimeZone', 'local'));
        posixtime_results(i) = (t2_posix - t1_posix) * 1000;
        
        % tic/toc測定
        tic_start = tic;
        pause(0.001); % 1ms
        tictoc_results(i) = toc(tic_start) * 1000;
    end
    
    % 比較統計
    posix_mean = mean(posixtime_results);
    posix_std = std(posixtime_results);
    tictoc_mean = mean(tictoc_results);
    tictoc_std = std(tictoc_results);
    
    fprintf('    posixtime - 平均: %.3f ms, 標準偏差: %.3f ms\n', posix_mean, posix_std);
    fprintf('    tic/toc   - 平均: %.3f ms, 標準偏差: %.3f ms\n', tictoc_mean, tictoc_std);
    fprintf('    差異: %.3f ms\n', abs(posix_mean - tictoc_mean));
    
    result = struct();
    result.posixtime_mean = posix_mean;
    result.posixtime_std = posix_std;
    result.tictoc_mean = tictoc_mean;
    result.tictoc_std = tictoc_std;
    result.mean_difference = abs(posix_mean - tictoc_mean);
    result.posixtime_results = posixtime_results;
    result.tictoc_results = tictoc_results;
end

function result = test_system_load_impact()
    % システム負荷がタイミング精度に与える影響
    fprintf('  システム負荷影響テスト中...\n');
    
    % 基準測定（軽負荷）
    baseline_intervals = measure_timing_under_load('baseline', 500);
    
    % 高負荷での測定
    fprintf('    高負荷条件でテスト中...\n');
    load_intervals = measure_timing_under_load('high_load', 500);
    
    % 比較分析
    baseline_mean = mean(baseline_intervals);
    baseline_std = std(baseline_intervals);
    load_mean = mean(load_intervals);
    load_std = std(load_intervals);
    
    impact_mean = load_mean - baseline_mean;
    impact_std = load_std - baseline_std;
    
    fprintf('    基準条件 - 平均: %.3f ms, 標準偏差: %.3f ms\n', baseline_mean, baseline_std);
    fprintf('    負荷条件 - 平均: %.3f ms, 標準偏差: %.3f ms\n', load_mean, load_std);
    fprintf('    負荷影響 - 平均差: %+.3f ms, 標準偏差差: %+.3f ms\n', impact_mean, impact_std);
    
    result = struct();
    result.baseline_mean = baseline_mean;
    result.baseline_std = baseline_std;
    result.load_mean = load_mean;
    result.load_std = load_std;
    result.impact_mean = impact_mean;
    result.impact_std = impact_std;
    result.baseline_intervals = baseline_intervals;
    result.load_intervals = load_intervals;
end

function intervals = measure_timing_under_load(condition, num_samples)
    % 指定条件下でのタイミング測定
    intervals = zeros(num_samples, 1);
    
    if strcmp(condition, 'high_load')
        % 高負荷生成（並列計算）
        load_data = randn(1000, 1000);
    end
    
    for i = 1:num_samples
        if strcmp(condition, 'high_load')
            % 負荷処理実行
            dummy = load_data * load_data';
        end
        
        t1 = posixtime(datetime('now', 'TimeZone', 'local'));
        pause(0.002); % 2ms待機
        t2 = posixtime(datetime('now', 'TimeZone', 'local'));
        
        intervals(i) = (t2 - t1) * 1000; % ms
    end
end

function assessment = evaluate_timing_performance(results)
    % 総合的なタイミング性能評価
    fprintf('\n=== 総合性能評価 ===\n');
    
    assessment = struct();
    
    % 基本精度評価
    basic_test = results.test1;
    assessment.basic_resolution_us = basic_test.min_resolution_us;
    assessment.basic_precision_rating = 'EXCELLENT';
    if basic_test.min_resolution_us > 100
        assessment.basic_precision_rating = 'GOOD';
    elseif basic_test.min_resolution_us > 1000
        assessment.basic_precision_rating = 'ACCEPTABLE';
    end
    
    % 短間隔精度評価
    short_test = results.test2;
    target_1ms = short_test.target_1ms;
    assessment.short_interval_accuracy = target_1ms.error_mean;
    assessment.short_interval_rating = 'EXCELLENT';
    if abs(target_1ms.error_mean) > 0.5
        assessment.short_interval_rating = 'GOOD';
    elseif abs(target_1ms.error_mean) > 1.0
        assessment.short_interval_rating = 'ACCEPTABLE';
    end
    
    % 安定性評価
    stability_test = results.test3;
    assessment.stability_drift = stability_test.drift_per_minute;
    assessment.stability_rating = 'EXCELLENT';
    if abs(stability_test.drift_per_minute) > 0.1
        assessment.stability_rating = 'GOOD';
    elseif abs(stability_test.drift_per_minute) > 1.0
        assessment.stability_rating = 'ACCEPTABLE';
    end
    
    % 実験適合性評価
    assessment.experiment_suitable = true;
    assessment.experiment_rating = 'SUITABLE';
    
    if basic_test.min_resolution_us > 1000 || abs(target_1ms.error_mean) > 2.0
        assessment.experiment_suitable = false;
        assessment.experiment_rating = 'UNSUITABLE';
    elseif basic_test.min_resolution_us > 500 || abs(target_1ms.error_mean) > 1.0
        assessment.experiment_rating = 'MARGINAL';
    end
    
    fprintf('基本分解能: %.1f μs (%s)\n', assessment.basic_resolution_us, assessment.basic_precision_rating);
    fprintf('短間隔精度: %+.3f ms (%s)\n', assessment.short_interval_accuracy, assessment.short_interval_rating);
    fprintf('長期安定性: %+.3f ms/分 (%s)\n', assessment.stability_drift, assessment.stability_rating);
    fprintf('実験適合性: %s\n', assessment.experiment_rating);
end

function generate_timing_report(results, assessment)
    % 詳細レポート生成・保存
    timestamp = datestr(now, 'yyyymmdd_HHMMSS');
    report_file = fullfile('matlab_verification', 'phase1_tech_validation', ...
                          sprintf('timing_precision_report_%s.txt', timestamp));
    
    fid = fopen(report_file, 'w');
    
    fprintf(fid, 'MATLAB タイミング精度検証レポート\n');
    fprintf(fid, '生成日時: %s\n', datestr(now));
    fprintf(fid, '=====================================\n\n');
    
    fprintf(fid, '【総合評価】\n');
    fprintf(fid, '基本分解能: %.1f μs (%s)\n', assessment.basic_resolution_us, assessment.basic_precision_rating);
    fprintf(fid, '短間隔精度: %+.3f ms (%s)\n', assessment.short_interval_accuracy, assessment.short_interval_rating);
    fprintf(fid, '長期安定性: %+.3f ms/分 (%s)\n', assessment.stability_drift, assessment.stability_rating);
    fprintf(fid, '実験適合性: %s\n\n', assessment.experiment_rating);
    
    fprintf(fid, '【詳細結果】\n');
    test_names = fieldnames(results);
    for i = 1:length(test_names)
        if startsWith(test_names{i}, 'test')
            test_data = results.(test_names{i});
            fprintf(fid, '%d. %s\n', i, test_data.name);
            % 詳細データの書き出し（簡略化）
            fprintf(fid, '   [詳細データは省略]\n\n');
        end
    end
    
    fclose(fid);
    
    fprintf('\n詳細レポートを保存しました: %s\n', report_file);
end