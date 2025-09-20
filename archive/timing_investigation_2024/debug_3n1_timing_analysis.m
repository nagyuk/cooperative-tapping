% 3n+1問題の詳細分析テストコード
% MATLAB仕様レベルでの調査

function debug_3n1_timing_analysis()
    fprintf('=== 3n+1タイミング問題の詳細分析 ===\n');

    % テスト1: posixtime()精度調査
    test_posixtime_precision();

    % テスト2: sound()関数遅延測定
    test_sound_function_delays();

    % テスト3: メモリ使用量監視
    test_memory_patterns();

    % テスト4: 純粋タイミングループテスト
    test_pure_timing_loop();
end

function test_posixtime_precision()
    fprintf('\n--- Test 1: posixtime()精度調査 ---\n');

    measurements = [];
    base_time = posixtime(datetime('now'));

    for i = 1:100
        start_time = posixtime(datetime('now'));
        % 1ms待機
        pause(0.001);
        end_time = posixtime(datetime('now'));
        actual_duration = end_time - start_time;
        measurements(end+1) = actual_duration;

        fprintf('測定%d: 期待1ms vs 実測%.3fms\n', i, actual_duration * 1000);
    end

    fprintf('posixtime()統計:\n');
    fprintf('  平均: %.6fms\n', mean(measurements) * 1000);
    fprintf('  標準偏差: %.6fms\n', std(measurements) * 1000);
    fprintf('  最小: %.6fms\n', min(measurements) * 1000);
    fprintf('  最大: %.6fms\n', max(measurements) * 1000);
end

function test_sound_function_delays()
    fprintf('\n--- Test 2: sound()関数遅延測定 ---\n');

    % テスト用短い音声作成
    fs = 44100;
    duration = 0.1; % 100ms
    t = 0:1/fs:duration;
    test_sound = sin(2*pi*440*t); % 440Hz音

    delays = [];

    for i = 1:30
        % 音再生直前の時刻
        pre_time = posixtime(datetime('now'));

        % 音再生
        sound(test_sound, fs);

        % 音再生直後の時刻
        post_time = posixtime(datetime('now'));

        delay = (post_time - pre_time) * 1000; % ms変換
        delays(end+1) = delay;

        fprintf('音再生%d: 遅延%.3fms (6n+1=%s)\n', i, delay, ...
            iif(mod(i, 6) == 1, 'YES', 'no'));

        pause(0.2); % 200ms間隔
    end

    % 6n+1パターンの分析
    pattern_6n1 = delays(1:6:end);  % 1, 7, 13, 19...
    pattern_other = delays(~ismember(1:length(delays), 1:6:length(delays)));

    fprintf('sound()遅延統計:\n');
    fprintf('  6n+1パターン: %.3f±%.3fms\n', mean(pattern_6n1), std(pattern_6n1));
    fprintf('  その他パターン: %.3f±%.3fms\n', mean(pattern_other), std(pattern_other));
end

function test_memory_patterns()
    fprintf('\n--- Test 3: メモリ使用量監視 ---\n');

    % メモリ使用量を30回測定
    for i = 1:30
        mem_info = memory;
        mem_used = mem_info.MemUsedMATLAB / 1024 / 1024; % MB変換

        fprintf('測定%d: メモリ使用量%.1fMB (6n+1=%s)\n', i, mem_used, ...
            iif(mod(i, 6) == 1, 'YES', 'no'));

        % ダミー処理（音声データ相当）
        dummy_data = randn(44100, 1); % 1秒分の音声データ相当
        pause(0.1);
        clear dummy_data;
    end
end

function test_pure_timing_loop()
    fprintf('\n--- Test 4: 純粋タイミングループテスト ---\n');

    start_time = posixtime(datetime('now'));
    target_intervals = 0.5:0.5:15; % 0.5秒間隔で30回

    for i = 1:length(target_intervals)
        target_time = target_intervals(i);

        % 目標時刻まで待機
        while (posixtime(datetime('now')) - start_time) < target_time
            % 空ループ
        end

        actual_time = posixtime(datetime('now')) - start_time;
        error_ms = (actual_time - target_time) * 1000;

        fprintf('ループ%d: 目標%.3fs vs 実測%.3fs, 誤差%.3fms (6n+1=%s)\n', ...
            i, target_time, actual_time, error_ms, ...
            iif(mod(i, 6) == 1, 'YES', 'no'));
    end
end

function result = iif(condition, true_val, false_val)
    if condition
        result = true_val;
    else
        result = false_val;
    end
end