%% タイミング精度実測・最適化システム
% Phase 3.3: 実験環境でのタイミング精度測定と最適化

function optimization_results = timing_precision_optimization()
    fprintf('=== タイミング精度実測・最適化開始 ===\n');
    
    optimization_results = struct();
    optimization_results.start_time = datestr(now);
    optimization_results.system_info = get_system_info();
    
    % Step 1: ベースライン精度測定
    fprintf('\n--- Step 1: ベースライン精度測定 ---\n');
    baseline_results = measure_baseline_precision();
    optimization_results.baseline = baseline_results;
    
    % Step 2: Audio System Toolbox精度測定
    fprintf('\n--- Step 2: Audio System Toolbox精度測定 ---\n');
    audio_results = measure_audio_precision();
    optimization_results.audio = audio_results;
    
    % Step 3: 統合システム精度測定
    fprintf('\n--- Step 3: 統合システム精度測定 ---\n');
    integrated_results = measure_integrated_precision();
    optimization_results.integrated = integrated_results;
    
    % Step 4: 最適化パラメータ探索
    fprintf('\n--- Step 4: 最適化パラメータ探索 ---\n');
    optimization_params = optimize_timing_parameters();
    optimization_results.optimization = optimization_params;
    
    % Step 5: 最適化後性能検証
    fprintf('\n--- Step 5: 最適化後性能検証 ---\n');
    optimized_results = verify_optimized_performance(optimization_params);
    optimization_results.optimized = optimized_results;
    
    % 総合評価
    fprintf('\n--- 総合評価 ---\n');
    optimization_results.assessment = assess_timing_performance(optimization_results);
    
    % 結果保存
    save_optimization_results(optimization_results);
    
    optimization_results.end_time = datestr(now);
    
    fprintf('\n=== タイミング精度最適化完了 ===\n');
    display_optimization_summary(optimization_results);
end

function system_info = get_system_info()
    % システム情報取得
    system_info = struct();
    
    % MATLAB情報
    system_info.matlab_version = version;
    system_info.matlab_release = version('-release');
    
    % プラットフォーム情報
    if ispc
        system_info.platform = 'Windows';
    elseif ismac
        system_info.platform = 'macOS';
    elseif isunix
        system_info.platform = 'Linux';
    else
        system_info.platform = 'Unknown';
    end
    
    % Toolbox確認
    system_info.audio_toolbox = license('test', 'Audio_Toolbox');
    
    % Psychtoolbox確認
    try
        KbCheck;
        system_info.psychtoolbox = true;
    catch
        system_info.psychtoolbox = false;
    end
    
    fprintf('システム情報:\n');
    fprintf('  Platform: %s\n', system_info.platform);
    fprintf('  MATLAB: %s\n', system_info.matlab_release);
    fprintf('  Audio Toolbox: %s\n', logical2str(system_info.audio_toolbox));
    fprintf('  Psychtoolbox: %s\n', logical2str(system_info.psychtoolbox));
end

function baseline_results = measure_baseline_precision()
    % ベースライン精度測定
    baseline_results = struct();
    
    % 基本posixtime精度
    fprintf('  posixtime基本精度測定中...\n');
    posix_precision = measure_posixtime_precision();
    baseline_results.posixtime = posix_precision;
    
    % pause関数精度
    fprintf('  pause関数精度測定中...\n');
    pause_precision = measure_pause_precision();
    baseline_results.pause = pause_precision;
    
    % tic/toc精度
    fprintf('  tic/toc精度測定中...\n');
    tictoc_precision = measure_tictoc_precision();
    baseline_results.tictoc = tictoc_precision;
    
    fprintf('  ベースライン測定完了\n');
end

function posix_precision = measure_posixtime_precision()
    % posixtime精度測定
    num_samples = 10000;
    intervals = [];
    
    prev_time = posixtime(datetime('now', 'TimeZone', 'local'));
    
    for i = 1:num_samples
        current_time = posixtime(datetime('now', 'TimeZone', 'local'));
        if current_time > prev_time
            intervals(end+1) = (current_time - prev_time) * 1000000; % マイクロ秒
            prev_time = current_time;
        end
    end
    
    posix_precision = struct();
    posix_precision.min_resolution_us = min(intervals);
    posix_precision.mean_resolution_us = mean(intervals);
    posix_precision.std_resolution_us = std(intervals);
    posix_precision.num_samples = length(intervals);
    
    fprintf('    posixtime分解能: %.1f μs (平均: %.1f μs)\n', ...
        posix_precision.min_resolution_us, posix_precision.mean_resolution_us);
end

function pause_precision = measure_pause_precision()
    % pause関数精度測定
    target_intervals = [0.001, 0.005, 0.01, 0.05, 0.1]; % ms
    num_repeats = 100;
    
    pause_precision = struct();
    
    for i = 1:length(target_intervals)
        target = target_intervals(i);
        measured_intervals = zeros(num_repeats, 1);
        
        for j = 1:num_repeats
            start_time = posixtime(datetime('now', 'TimeZone', 'local'));
            pause(target);
            end_time = posixtime(datetime('now', 'TimeZone', 'local'));
            
            measured_intervals(j) = (end_time - start_time) * 1000; % ms
        end
        
        mean_measured = mean(measured_intervals);
        std_measured = std(measured_intervals);
        error_mean = mean_measured - target * 1000;
        
        pause_precision.(sprintf('target_%dms', round(target*1000))) = struct();
        pause_precision.(sprintf('target_%dms', round(target*1000))).target_ms = target * 1000;
        pause_precision.(sprintf('target_%dms', round(target*1000))).mean_measured_ms = mean_measured;
        pause_precision.(sprintf('target_%dms', round(target*1000))).std_measured_ms = std_measured;
        pause_precision.(sprintf('target_%dms', round(target*1000))).error_mean_ms = error_mean;
        
        fprintf('    pause(%.1fms): 平均%.1fms, 誤差%+.1fms, σ=%.1fms\n', ...
            target*1000, mean_measured, error_mean, std_measured);
    end
end

function tictoc_precision = measure_tictoc_precision()
    % tic/toc精度測定
    target_intervals = [0.001, 0.005, 0.01, 0.05, 0.1];
    num_repeats = 100;
    
    tictoc_precision = struct();
    
    for i = 1:length(target_intervals)
        target = target_intervals(i);
        measured_intervals = zeros(num_repeats, 1);
        
        for j = 1:num_repeats
            tic_start = tic;
            pause(target);
            measured_intervals(j) = toc(tic_start) * 1000; % ms
        end
        
        mean_measured = mean(measured_intervals);
        std_measured = std(measured_intervals);
        error_mean = mean_measured - target * 1000;
        
        tictoc_precision.(sprintf('target_%dms', round(target*1000))) = struct();
        tictoc_precision.(sprintf('target_%dms', round(target*1000))).target_ms = target * 1000;
        tictoc_precision.(sprintf('target_%dms', round(target*1000))).mean_measured_ms = mean_measured;
        tictoc_precision.(sprintf('target_%dms', round(target*1000))).std_measured_ms = std_measured;
        tictoc_precision.(sprintf('target_%dms', round(target*1000))).error_mean_ms = error_mean;
        
        fprintf('    tic/toc(%.1fms): 平均%.1fms, 誤差%+.1fms, σ=%.1fms\n', ...
            target*1000, mean_measured, error_mean, std_measured);
    end
end

function audio_results = measure_audio_precision()
    % Audio System Toolbox精度測定
    audio_results = struct();
    
    if ~license('test', 'Audio_Toolbox')
        fprintf('  Audio System Toolbox利用不可\n');
        audio_results.status = 'UNAVAILABLE';
        return;
    end
    
    try
        % 様々な設定での測定
        test_configs = [
            struct('SampleRate', 44100, 'BufferSize', 128);
            struct('SampleRate', 44100, 'BufferSize', 64);
            struct('SampleRate', 48000, 'BufferSize', 64);
            struct('SampleRate', 48000, 'BufferSize', 32);
        ];
        
        for i = 1:length(test_configs)
            config = test_configs(i);
            config_name = sprintf('sr%d_buf%d', config.SampleRate, config.BufferSize);
            
            fprintf('  設定 %s 測定中...\n', config_name);
            
            try
                config_result = measure_audio_config_precision(config);
                audio_results.(config_name) = config_result;
            catch ME
                fprintf('    エラー: %s\n', ME.message);
                audio_results.(config_name) = struct('status', 'FAILED', 'error', ME.message);
            end
        end
        
        audio_results.status = 'SUCCESS';
        
    catch ME
        fprintf('  Audio測定エラー: %s\n', ME.message);
        audio_results.status = 'FAILED';
        audio_results.error = ME.message;
    end
end

function config_result = measure_audio_config_precision(config)
    % 特定Audio設定での精度測定
    
    % audioDeviceWriter作成
    deviceWriter = audioDeviceWriter('SampleRate', config.SampleRate, ...
                                   'BufferSize', config.BufferSize);
    
    % テスト音声生成
    duration = 0.1; % 100ms
    t = 0:1/config.SampleRate:duration;
    test_tone = sin(2*pi*1000*t)' * 0.1;
    
    % レイテンシー測定
    num_tests = 50;
    latencies = zeros(num_tests, 1);
    
    for i = 1:num_tests
        start_time = posixtime(datetime('now', 'TimeZone', 'local'));
        deviceWriter(test_tone);
        end_time = posixtime(datetime('now', 'TimeZone', 'local'));
        
        latencies(i) = (end_time - start_time) * 1000; % ms
        pause(0.05); % 安定化待機
    end
    
    % 理論レイテンシー
    theoretical_latency = (config.BufferSize / config.SampleRate) * 1000;
    
    config_result = struct();
    config_result.config = config;
    config_result.latencies_ms = latencies;
    config_result.mean_latency_ms = mean(latencies);
    config_result.std_latency_ms = std(latencies);
    config_result.min_latency_ms = min(latencies);
    config_result.max_latency_ms = max(latencies);
    config_result.theoretical_latency_ms = theoretical_latency;
    
    fprintf('    平均レイテンシー: %.2fms (理論値: %.2fms)\n', ...
        config_result.mean_latency_ms, theoretical_latency);
    
    release(deviceWriter);
end

function integrated_results = measure_integrated_precision()
    % 統合システムでの精度測定
    integrated_results = struct();
    
    % TimingController精度測定
    fprintf('  TimingController精度測定中...\n');
    timing_ctrl_result = measure_timing_controller_precision();
    integrated_results.timing_controller = timing_ctrl_result;
    
    % InputHandler精度測定
    fprintf('  InputHandler精度測定中...\n');
    input_handler_result = measure_input_handler_precision();
    integrated_results.input_handler = input_handler_result;
    
    % 統合実験システム精度測定
    fprintf('  統合実験システム精度測定中...\n');
    experiment_system_result = measure_experiment_system_precision();
    integrated_results.experiment_system = experiment_system_result;
    
    fprintf('  統合システム測定完了\n');
end

function timing_ctrl_result = measure_timing_controller_precision()
    % TimingController精度測定
    
    config = struct('high_precision_timing', true);
    timing_ctrl = TimingControllerMATLAB(config);
    
    % 精度測定実行
    [precision_ms, stability_ms] = timing_ctrl.measureTimingPrecision(100);
    
    timing_ctrl_result = struct();
    timing_ctrl_result.precision_ms = precision_ms;
    timing_ctrl_result.stability_ms = stability_ms;
    timing_ctrl_result.performance_stats = timing_ctrl.getPerformanceStats();
    
    fprintf('    TimingController精度: %.2fms, 安定性: %.2fms\n', ...
        precision_ms, stability_ms);
end

function input_handler_result = measure_input_handler_precision()
    % InputHandler精度測定
    
    config = struct('high_precision_timing', true);
    input_handler = InputHandlerMATLAB(config);
    
    input_handler_result = struct();
    input_handler_result.psychtoolbox_available = input_handler.psychtoolbox_available;
    input_handler_result.input_mode = input_handler.input_mode;
    input_handler_result.stats = input_handler.getInputStats();
    
    fprintf('    InputHandler: %s (PTB: %s)\n', ...
        input_handler_result.input_mode, logical2str(input_handler_result.psychtoolbox_available));
end

function experiment_system_result = measure_experiment_system_precision()
    % 実験システム全体の精度測定
    
    % 簡易実験システムでの測定
    config = struct();
    config.model_type = 'sea';
    config.span = 2.0;
    config.stage1_count = 5;
    config.stage2_count = 10;
    config.sample_rate = 48000;
    config.buffer_size = 64;
    config.output_directory = fullfile('matlab_verification', 'phase3_model_integration', 'timing_test');
    
    try
        % データ収集システム作成（音声・入力は除く）
        data_collector = DataCollectorMATLAB(config);
        
        % 簡易タイミングテスト
        base_time = posixtime(datetime('now', 'TimeZone', 'local'));
        timing_errors = [];
        
        for i = 1:10
            target_time = base_time + i * config.span;
            
            % 簡易待機
            while posixtime(datetime('now', 'TimeZone', 'local')) < target_time
                pause(0.001);
            end
            
            actual_time = posixtime(datetime('now', 'TimeZone', 'local'));
            timing_error = (actual_time - target_time) * 1000; % ms
            timing_errors(end+1) = timing_error;
            
            % データ記録
            data_collector.recordTap(i, 1, target_time, actual_time, timing_error);
        end
        
        data_collector.finalizeData();
        
        experiment_system_result = struct();
        experiment_system_result.timing_errors_ms = timing_errors;
        experiment_system_result.mean_error_ms = mean(abs(timing_errors));
        experiment_system_result.std_error_ms = std(timing_errors);
        experiment_system_result.max_error_ms = max(abs(timing_errors));
        experiment_system_result.status = 'SUCCESS';
        
        fprintf('    実験システム精度: 平均誤差%.1fms, 最大誤差%.1fms\n', ...
            experiment_system_result.mean_error_ms, experiment_system_result.max_error_ms);
        
    catch ME
        experiment_system_result = struct();
        experiment_system_result.status = 'FAILED';
        experiment_system_result.error = ME.message;
        fprintf('    実験システム測定エラー: %s\n', ME.message);
    end
end

function optimization_params = optimize_timing_parameters()
    % 最適化パラメータ探索
    optimization_params = struct();
    
    % 最適なpause間隔の探索
    fprintf('  最適pause間隔探索中...\n');
    optimal_pause = find_optimal_pause_interval();
    optimization_params.optimal_pause_interval = optimal_pause;
    
    % 最適なポーリング戦略の探索
    fprintf('  最適ポーリング戦略探索中...\n');
    optimal_polling = find_optimal_polling_strategy();
    optimization_params.optimal_polling = optimal_polling;
    
    % Audio設定最適化
    fprintf('  Audio設定最適化中...\n');
    optimal_audio = find_optimal_audio_settings();
    optimization_params.optimal_audio = optimal_audio;
    
    fprintf('  パラメータ最適化完了\n');
end

function optimal_pause = find_optimal_pause_interval()
    % 最適pause間隔探索
    
    pause_intervals = [0.0001, 0.0005, 0.001, 0.002, 0.005]; % 秒
    num_tests = 50;
    
    best_interval = pause_intervals(1);
    best_accuracy = Inf;
    
    for i = 1:length(pause_intervals)
        interval = pause_intervals(i);
        
        % 精度測定
        target_duration = 0.01; % 10ms
        errors = zeros(num_tests, 1);
        
        for j = 1:num_tests
            start_time = posixtime(datetime('now', 'TimeZone', 'local'));
            target_end_time = start_time + target_duration;
            
            % ハイブリッド待機
            coarse_duration = target_duration * 0.8;
            pause(coarse_duration);
            
            while posixtime(datetime('now', 'TimeZone', 'local')) < target_end_time
                pause(interval);
            end
            
            actual_end_time = posixtime(datetime('now', 'TimeZone', 'local'));
            errors(j) = abs(actual_end_time - target_end_time) * 1000; % ms
        end
        
        mean_error = mean(errors);
        
        if mean_error < best_accuracy
            best_accuracy = mean_error;
            best_interval = interval;
        end
        
        fprintf('    pause間隔%.1fms: 平均誤差%.3fms\n', interval*1000, mean_error);
    end
    
    optimal_pause = struct();
    optimal_pause.interval_s = best_interval;
    optimal_pause.accuracy_ms = best_accuracy;
    
    fprintf('    最適pause間隔: %.1fms (精度: %.3fms)\n', ...
        best_interval*1000, best_accuracy);
end

function optimal_polling = find_optimal_polling_strategy()
    % 最適ポーリング戦略探索
    
    strategies = {
        struct('name', 'Constant_1ms', 'type', 'constant', 'interval', 0.001);
        struct('name', 'Constant_0.5ms', 'type', 'constant', 'interval', 0.0005);
        struct('name', 'Adaptive_Coarse_Fine', 'type', 'adaptive', 'coarse_ratio', 0.9);
        struct('name', 'Exponential_Backoff', 'type', 'exponential', 'base_interval', 0.0001);
    };
    
    best_strategy = strategies{1};
    best_performance = Inf;
    
    for i = 1:length(strategies)
        strategy = strategies{i};
        
        % 戦略テスト
        performance = test_polling_strategy(strategy);
        
        if performance.mean_error < best_performance
            best_performance = performance.mean_error;
            best_strategy = strategy;
        end
        
        fprintf('    %s: 平均誤差%.3fms\n', strategy.name, performance.mean_error);
    end
    
    optimal_polling = best_strategy;
    optimal_polling.performance = best_performance;
    
    fprintf('    最適ポーリング戦略: %s (精度: %.3fms)\n', ...
        best_strategy.name, best_performance);
end

function performance = test_polling_strategy(strategy)
    % ポーリング戦略テスト
    
    num_tests = 20;
    target_duration = 0.02; % 20ms
    errors = zeros(num_tests, 1);
    
    for i = 1:num_tests
        start_time = posixtime(datetime('now', 'TimeZone', 'local'));
        target_end_time = start_time + target_duration;
        
        switch strategy.type
            case 'constant'
                while posixtime(datetime('now', 'TimeZone', 'local')) < target_end_time
                    pause(strategy.interval);
                end
                
            case 'adaptive'
                coarse_duration = target_duration * strategy.coarse_ratio;
                pause(coarse_duration);
                
                while posixtime(datetime('now', 'TimeZone', 'local')) < target_end_time
                    pause(0.0001);
                end
                
            case 'exponential'
                current_interval = strategy.base_interval;
                
                while posixtime(datetime('now', 'TimeZone', 'local')) < target_end_time
                    pause(current_interval);
                    remaining = target_end_time - posixtime(datetime('now', 'TimeZone', 'local'));
                    
                    if remaining > 0.001
                        current_interval = min(0.001, remaining * 0.1);
                    else
                        current_interval = strategy.base_interval;
                    end
                end
        end
        
        actual_end_time = posixtime(datetime('now', 'TimeZone', 'local'));
        errors(i) = abs(actual_end_time - target_end_time) * 1000; % ms
    end
    
    performance = struct();
    performance.mean_error = mean(errors);
    performance.std_error = std(errors);
    performance.max_error = max(errors);
end

function optimal_audio = find_optimal_audio_settings()
    % 最適Audio設定探索
    
    optimal_audio = struct();
    
    if ~license('test', 'Audio_Toolbox')
        optimal_audio.status = 'UNAVAILABLE';
        fprintf('    Audio System Toolbox利用不可\n');
        return;
    end
    
    % 設定候補
    audio_configs = [
        struct('SampleRate', 48000, 'BufferSize', 32);
        struct('SampleRate', 48000, 'BufferSize', 64);
        struct('SampleRate', 44100, 'BufferSize', 64);
        struct('SampleRate', 44100, 'BufferSize', 128);
    ];
    
    best_config = audio_configs(1);
    best_latency = Inf;
    
    for i = 1:length(audio_configs)
        config = audio_configs(i);
        
        try
            latency = measure_audio_latency_quick(config);
            
            if latency < best_latency
                best_latency = latency;
                best_config = config;
            end
            
            fprintf('    SR%d/Buf%d: %.2fms\n', config.SampleRate, config.BufferSize, latency);
            
        catch ME
            fprintf('    SR%d/Buf%d: エラー\n', config.SampleRate, config.BufferSize);
        end
    end
    
    optimal_audio.config = best_config;
    optimal_audio.latency_ms = best_latency;
    optimal_audio.status = 'SUCCESS';
    
    fprintf('    最適Audio設定: SR%d/Buf%d (レイテンシー: %.2fms)\n', ...
        best_config.SampleRate, best_config.BufferSize, best_latency);
end

function latency = measure_audio_latency_quick(config)
    % 高速Audio レイテンシー測定
    
    deviceWriter = audioDeviceWriter('SampleRate', config.SampleRate, ...
                                   'BufferSize', config.BufferSize);
    
    duration = 0.05; % 50ms
    t = 0:1/config.SampleRate:duration;
    test_tone = sin(2*pi*1000*t)' * 0.1;
    
    num_tests = 10;
    latencies = zeros(num_tests, 1);
    
    for i = 1:num_tests
        start_time = posixtime(datetime('now', 'TimeZone', 'local'));
        deviceWriter(test_tone);
        end_time = posixtime(datetime('now', 'TimeZone', 'local'));
        
        latencies(i) = (end_time - start_time) * 1000; % ms
        pause(0.02);
    end
    
    latency = mean(latencies);
    release(deviceWriter);
end

function optimized_results = verify_optimized_performance(optimization_params)
    % 最適化後性能検証
    optimized_results = struct();
    
    fprintf('  最適化パラメータによる性能検証中...\n');
    
    % 最適化TimingController作成
    config = struct();
    config.high_precision_timing = true;
    config.optimal_pause_interval = optimization_params.optimal_pause_interval.interval_s;
    
    timing_ctrl = TimingControllerMATLAB(config);
    
    % 性能測定
    [precision_ms, stability_ms] = timing_ctrl.measureTimingPrecision(100);
    
    optimized_results.precision_ms = precision_ms;
    optimized_results.stability_ms = stability_ms;
    optimized_results.optimization_params = optimization_params;
    
    fprintf('    最適化後精度: %.2fms, 安定性: %.2fms\n', precision_ms, stability_ms);
end

function assessment = assess_timing_performance(optimization_results)
    % タイミング性能総合評価
    assessment = struct();
    
    % ベースライン vs 最適化後の比較
    if isfield(optimization_results, 'baseline') && isfield(optimization_results, 'optimized')
        baseline_precision = optimization_results.baseline.posixtime.min_resolution_us / 1000; % ms
        optimized_precision = optimization_results.optimized.precision_ms;
        
        improvement_factor = baseline_precision / optimized_precision;
        assessment.improvement_factor = improvement_factor;
        
        if optimized_precision < 1.0
            assessment.precision_grade = 'EXCELLENT';
        elseif optimized_precision < 5.0
            assessment.precision_grade = 'GOOD';
        elseif optimized_precision < 10.0
            assessment.precision_grade = 'ACCEPTABLE';
        else
            assessment.precision_grade = 'POOR';
        end
    else
        assessment.precision_grade = 'UNKNOWN';
    end
    
    % 実験要求仕様との比較
    required_precision_ms = 5.0; % 実験で必要な精度
    
    if isfield(optimization_results, 'optimized')
        achieved_precision = optimization_results.optimized.precision_ms;
        
        if achieved_precision <= required_precision_ms
            assessment.experiment_suitability = 'SUITABLE';
        else
            assessment.experiment_suitability = 'INSUFFICIENT';
        end
        
        assessment.precision_margin = required_precision_ms - achieved_precision;
    else
        assessment.experiment_suitability = 'UNKNOWN';
    end
    
    fprintf('精度評価: %s (実験適合性: %s)\n', ...
        assessment.precision_grade, assessment.experiment_suitability);
end

function save_optimization_results(optimization_results)
    % 最適化結果保存
    timestamp = datestr(now, 'yyyymmdd_HHMMSS');
    output_dir = fullfile('matlab_verification', 'phase3_model_integration');
    
    if ~exist(output_dir, 'dir')
        mkdir(output_dir);
    end
    
    % MAT形式保存
    mat_file = fullfile(output_dir, sprintf('timing_optimization_results_%s.mat', timestamp));
    save(mat_file, 'optimization_results');
    
    % 設定ファイル生成
    config_file = fullfile(output_dir, sprintf('optimized_timing_config_%s.m', timestamp));
    generate_optimized_config_file(optimization_results, config_file);
    
    fprintf('\n最適化結果保存完了:\n');
    fprintf('  %s\n', mat_file);
    fprintf('  %s\n', config_file);
end

function generate_optimized_config_file(optimization_results, config_file)
    % 最適化設定ファイル生成
    fid = fopen(config_file, 'w');
    
    fprintf(fid, '%% 最適化されたタイミング設定\n');
    fprintf(fid, '%% 生成日時: %s\n\n', datestr(now));
    
    fprintf(fid, 'function config = get_optimized_timing_config()\n');
    fprintf(fid, '    config = struct();\n\n');
    
    if isfield(optimization_results, 'optimization')
        opt = optimization_results.optimization;
        
        if isfield(opt, 'optimal_pause_interval')
            fprintf(fid, '    %% 最適pause間隔\n');
            fprintf(fid, '    config.optimal_pause_interval = %.6f; %% 秒\n\n', ...
                opt.optimal_pause_interval.interval_s);
        end
        
        if isfield(opt, 'optimal_audio')
            fprintf(fid, '    %% 最適Audio設定\n');
            fprintf(fid, '    config.audio_sample_rate = %d;\n', opt.optimal_audio.config.SampleRate);
            fprintf(fid, '    config.audio_buffer_size = %d;\n\n', opt.optimal_audio.config.BufferSize);
        end
    end
    
    fprintf(fid, '    %% 高精度タイミング有効化\n');
    fprintf(fid, '    config.high_precision_timing = true;\n\n');
    
    fprintf(fid, 'end\n');
    
    fclose(fid);
end

function display_optimization_summary(optimization_results)
    % 最適化結果サマリー表示
    fprintf('\n【タイミング精度最適化サマリー】\n');
    
    if isfield(optimization_results, 'assessment')
        assessment = optimization_results.assessment;
        fprintf('精度評価: %s\n', assessment.precision_grade);
        fprintf('実験適合性: %s\n', assessment.experiment_suitability);
        
        if isfield(assessment, 'improvement_factor')
            fprintf('改善倍率: %.1fx\n', assessment.improvement_factor);
        end
    end
    
    if isfield(optimization_results, 'optimized')
        optimized = optimization_results.optimized;
        fprintf('最適化後精度: %.2fms\n', optimized.precision_ms);
        fprintf('安定性: %.2fms\n', optimized.stability_ms);
    end
    
    fprintf('\n次のステップ: Phase 3.4 データ形式互換性検証\n');
end

function str = logical2str(logical_val)
    if logical_val
        str = '利用可能';
    else
        str = '利用不可';
    end
end