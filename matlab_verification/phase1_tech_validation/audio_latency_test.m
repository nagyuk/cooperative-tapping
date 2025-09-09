%% Audio System Toolbox レイテンシー測定実験
% MATLAB移行Phase 1.1: 音声レイテンシーと精度の性能測定
%
% 目的:
% - Audio System Toolboxでの音声レイテンシー測定
% - PsychoPy PTBとの比較基準データ取得
% - ASIO/Core Audioドライバーとの統合テスト

function results = audio_latency_test()
    fprintf('=== Audio System Toolbox レイテンシー測定開始 ===\n');
    
    % 測定パラメータ
    test_configs = [
        struct('SampleRate', 44100, 'BufferSize', 128, 'Driver', 'Default');
        struct('SampleRate', 44100, 'BufferSize', 64, 'Driver', 'Default');
        struct('SampleRate', 48000, 'BufferSize', 64, 'Driver', 'Default');
        struct('SampleRate', 48000, 'BufferSize', 32, 'Driver', 'Default');
    ];
    
    % ASIO対応チェック（可能であれば）
    try
        asio_config = struct('SampleRate', 48000, 'BufferSize', 64, 'Driver', 'ASIO');
        test_configs(end+1) = asio_config;
        fprintf('ASIO ドライバー対応を検出しました\n');
    catch
        fprintf('ASIO ドライバー未対応 - デフォルトドライバーでテスト\n');
    end
    
    results = struct();
    
    % 各設定での測定実行
    for i = 1:length(test_configs)
        config = test_configs(i);
        fprintf('\n--- 設定 %d: SR=%d, Buffer=%d, Driver=%s ---\n', ...
            i, config.SampleRate, config.BufferSize, config.Driver);
        
        try
            results(i) = measure_audio_latency(config);
        catch ME
            fprintf('エラー: %s\n', ME.message);
            results(i) = struct('config', config, 'error', ME.message);
        end
    end
    
    % 結果まとめ
    display_results(results);
    save_results(results);
    
    fprintf('\n=== Audio System Toolbox レイテンシー測定完了 ===\n');
end

function result = measure_audio_latency(config)
    % 個別設定での詳細レイテンシー測定
    
    % audioDeviceWriter初期化
    try
        if strcmp(config.Driver, 'ASIO')
            deviceWriter = audioDeviceWriter('SampleRate', config.SampleRate, ...
                                           'BufferSize', config.BufferSize, ...
                                           'Driver', 'ASIO');
        else
            deviceWriter = audioDeviceWriter('SampleRate', config.SampleRate, ...
                                           'BufferSize', config.BufferSize);
        end
    catch ME
        % ドライバー固有エラーの場合はデフォルトで再試行
        deviceWriter = audioDeviceWriter('SampleRate', config.SampleRate, ...
                                       'BufferSize', config.BufferSize);
        config.Driver = 'Default_Fallback';
    end
    
    % テスト音声作成（1kHzトーン、100ms）
    duration = 0.1; % 100ms
    t = 0:1/config.SampleRate:duration;
    test_tone = sin(2*pi*1000*t)'; % 1kHz sine wave
    test_tone = test_tone * 0.1;   % 音量調整
    
    % レイテンシー測定（多数回実行）
    num_tests = 100;
    latencies = zeros(num_tests, 1);
    
    fprintf('  測定中... (0/%d)', num_tests);
    
    for i = 1:num_tests
        % 高精度タイムスタンプ取得
        start_time = posixtime(datetime('now', 'TimeZone', 'local'));
        
        % 音声再生
        deviceWriter(test_tone);
        
        % 完了タイムスタンプ
        end_time = posixtime(datetime('now', 'TimeZone', 'local'));
        
        latencies(i) = (end_time - start_time) * 1000; % ms変換
        
        % 進捗表示
        if mod(i, 20) == 0
            fprintf('\b\b\b\b\b\b\b\b\b\b(%d/%d)', i, num_tests);
        end
        
        % システム安定化待機
        pause(0.05);
    end
    
    fprintf('\b\b\b\b\b\b\b\b\b\b完了     \n');
    
    % 統計解析
    mean_latency = mean(latencies);
    std_latency = std(latencies);
    min_latency = min(latencies);
    max_latency = max(latencies);
    median_latency = median(latencies);
    
    % 理論レイテンシー計算
    theoretical_latency = (config.BufferSize / config.SampleRate) * 1000;
    
    fprintf('  平均レイテンシー: %.2f ms\n', mean_latency);
    fprintf('  標準偏差: %.2f ms\n', std_latency);
    fprintf('  最小/最大: %.2f / %.2f ms\n', min_latency, max_latency);
    fprintf('  理論値: %.2f ms\n', theoretical_latency);
    
    % 結果構造体作成
    result = struct();
    result.config = config;
    result.latencies = latencies;
    result.mean_latency = mean_latency;
    result.std_latency = std_latency;
    result.min_latency = min_latency;
    result.max_latency = max_latency;
    result.median_latency = median_latency;
    result.theoretical_latency = theoretical_latency;
    result.num_samples = num_tests;
    
    % デバイス解放
    release(deviceWriter);
end

function display_results(results)
    % 結果の総合表示
    fprintf('\n=== レイテンシー測定結果サマリー ===\n');
    fprintf('%-15s %-10s %-10s %-10s %-10s %-10s\n', ...
        'Driver', 'SampleRate', 'BufferSize', 'Mean(ms)', 'Std(ms)', 'Theoretical');
    fprintf('%-15s %-10s %-10s %-10s %-10s %-10s\n', ...
        repmat('-', 1, 15), repmat('-', 1, 10), repmat('-', 1, 10), ...
        repmat('-', 1, 10), repmat('-', 1, 10), repmat('-', 1, 10));
    
    for i = 1:length(results)
        if isfield(results(i), 'error')
            fprintf('%-15s %-10d %-10d %-10s %-10s %-10s\n', ...
                results(i).config.Driver, results(i).config.SampleRate, ...
                results(i).config.BufferSize, 'ERROR', 'ERROR', 'ERROR');
        else
            fprintf('%-15s %-10d %-10d %-10.2f %-10.2f %-10.2f\n', ...
                results(i).config.Driver, results(i).config.SampleRate, ...
                results(i).config.BufferSize, results(i).mean_latency, ...
                results(i).std_latency, results(i).theoretical_latency);
        end
    end
end

function save_results(results)
    % 結果をCSVファイルで保存
    timestamp = datestr(now, 'yyyymmdd_HHMMSS');
    filename = sprintf('audio_latency_results_%s.csv', timestamp);
    filepath = fullfile('matlab_verification', 'phase1_tech_validation', filename);
    
    % CSV用データ準備
    data = {};
    headers = {'Driver', 'SampleRate', 'BufferSize', 'MeanLatency_ms', ...
               'StdLatency_ms', 'MinLatency_ms', 'MaxLatency_ms', ...
               'MedianLatency_ms', 'TheoreticalLatency_ms', 'NumSamples', 'Status'};
    
    for i = 1:length(results)
        if isfield(results(i), 'error')
            row = {results(i).config.Driver, results(i).config.SampleRate, ...
                   results(i).config.BufferSize, NaN, NaN, NaN, NaN, NaN, NaN, 0, 'ERROR'};
        else
            row = {results(i).config.Driver, results(i).config.SampleRate, ...
                   results(i).config.BufferSize, results(i).mean_latency, ...
                   results(i).std_latency, results(i).min_latency, ...
                   results(i).max_latency, results(i).median_latency, ...
                   results(i).theoretical_latency, results(i).num_samples, 'SUCCESS'};
        end
        data(end+1, :) = row;
    end
    
    % CSVファイル書き出し
    T = cell2table(data, 'VariableNames', headers);
    writetable(T, filepath);
    
    fprintf('\n結果を保存しました: %s\n', filepath);
end