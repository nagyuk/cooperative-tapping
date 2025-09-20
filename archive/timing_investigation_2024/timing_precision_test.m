% 音声録音なしでのタイミング精度テスト
% ソフトウェアレベルでの各手法の遅延特性を分析

function timing_precision_test()
    fprintf('=== タイミング精度テスト（録音なし版）===\n');
    fprintf('各手法のソフトウェア遅延特性を詳細分析\n\n');

    % 音声ファイル読み込み
    stim_path = fullfile(pwd, 'assets', 'sounds', 'stim_beat_optimized.wav');
    player_path = fullfile(pwd, 'assets', 'sounds', 'player_beat_optimized.wav');
    [sound_stim, fs_stim] = audioread(stim_path);
    [sound_player, fs_player] = audioread(player_path);

    results = {};

    % 手法1: sound()関数の遅延分析
    fprintf('=== 手法1: sound()関数遅延分析 ===\n');
    results{end+1} = test_sound_function_delays(sound_stim, fs_stim, sound_player, fs_player);

    % 手法2: audioplayerの遅延分析
    fprintf('\n=== 手法2: audioplayer遅延分析 ===\n');
    results{end+1} = test_audioplayer_delays(sound_stim, fs_stim, sound_player, fs_player);

    % 手法3: 複数audioplayerの遅延分析
    fprintf('\n=== 手法3: 複数audioplayer遅延分析 ===\n');
    results{end+1} = test_multiple_audioplayer_delays(sound_stim, fs_stim, sound_player, fs_player);

    % 手法4: 外部コマンド遅延分析
    fprintf('\n=== 手法4: 外部コマンド遅延分析 ===\n');
    results{end+1} = test_external_command_delays();

    % 手法5: 待機精度分析
    fprintf('\n=== 手法5: 待機システム精度分析 ===\n');
    results{end+1} = test_wait_system_precision();

    % 結果比較
    fprintf('\n=== 全手法遅延特性比較 ===\n');
    compare_delay_results(results);

    % 最適化提案
    propose_optimization(results);
end

function result = test_sound_function_delays(sound_stim, fs_stim, sound_player, fs_player)
    fprintf('sound()関数の実行遅延を測定...\n');

    delays = [];
    intervals = [];

    last_time = posixtime(datetime('now'));

    for i = 1:10
        % sound()実行時間測定
        start_time = tic;
        current_clock = posixtime(datetime('now'));

        if mod(i, 2) == 1
            sound(sound_stim(:,1), fs_stim);
        else
            sound(sound_player(:,1), fs_player);
        end

        execution_delay = toc(start_time);
        delays(end+1) = execution_delay;

        % 実際の間隔測定
        if i > 1
            actual_interval = current_clock - last_time;
            intervals(end+1) = actual_interval;
        end
        last_time = current_clock;

        fprintf('  再生%d: 実行遅延%.3fms\n', i, execution_delay * 1000);

        % 1秒待機
        pause(1.0);
    end

    mean_delay = mean(delays);
    std_delay = std(delays);
    mean_interval = mean(intervals);

    fprintf('sound()関数統計:\n');
    fprintf('  平均実行遅延: %.3fms\n', mean_delay * 1000);
    fprintf('  遅延標準偏差: %.3fms\n', std_delay * 1000);
    fprintf('  平均実間隔: %.3fs\n', mean_interval);

    result = struct('method', 'sound()関数', 'mean_delay', mean_delay, ...
                   'std_delay', std_delay, 'mean_interval', mean_interval);
end

function result = test_audioplayer_delays(sound_stim, fs_stim, sound_player, fs_player)
    fprintf('audioplayerの実行遅延を測定...\n');

    % audioplayerオブジェクト作成
    player_stim = audioplayer(sound_stim(:,1), fs_stim);
    player_player = audioplayer(sound_player(:,1), fs_player);

    delays = [];
    intervals = [];

    last_time = posixtime(datetime('now'));

    for i = 1:10
        % play()実行時間測定
        start_time = tic;
        current_clock = posixtime(datetime('now'));

        if mod(i, 2) == 1
            play(player_stim);
        else
            play(player_player);
        end

        execution_delay = toc(start_time);
        delays(end+1) = execution_delay;

        % 実際の間隔測定
        if i > 1
            actual_interval = current_clock - last_time;
            intervals(end+1) = actual_interval;
        end
        last_time = current_clock;

        fprintf('  再生%d: 実行遅延%.3fms\n', i, execution_delay * 1000);

        % 1秒待機
        pause(1.0);
    end

    mean_delay = mean(delays);
    std_delay = std(delays);
    mean_interval = mean(intervals);

    fprintf('audioplayer統計:\n');
    fprintf('  平均実行遅延: %.3fms\n', mean_delay * 1000);
    fprintf('  遅延標準偏差: %.3fms\n', std_delay * 1000);
    fprintf('  平均実間隔: %.3fs\n', mean_interval);

    result = struct('method', 'audioplayer', 'mean_delay', mean_delay, ...
                   'std_delay', std_delay, 'mean_interval', mean_interval);
end

function result = test_multiple_audioplayer_delays(sound_stim, fs_stim, sound_player, fs_player)
    fprintf('複数audioplayerオブジェクトの遅延を測定...\n');

    % 10個のaudioplayerオブジェクト事前作成
    players = cell(10, 1);
    for i = 1:10
        if mod(i, 2) == 1
            players{i} = audioplayer(sound_stim(:,1), fs_stim);
        else
            players{i} = audioplayer(sound_player(:,1), fs_player);
        end
    end

    delays = [];
    intervals = [];

    last_time = posixtime(datetime('now'));

    for i = 1:10
        % 専用オブジェクトでplay()実行時間測定
        start_time = tic;
        current_clock = posixtime(datetime('now'));

        play(players{i});

        execution_delay = toc(start_time);
        delays(end+1) = execution_delay;

        % 実際の間隔測定
        if i > 1
            actual_interval = current_clock - last_time;
            intervals(end+1) = actual_interval;
        end
        last_time = current_clock;

        fprintf('  再生%d: 実行遅延%.3fms\n', i, execution_delay * 1000);

        % 1秒待機
        pause(1.0);
    end

    mean_delay = mean(delays);
    std_delay = std(delays);
    mean_interval = mean(intervals);

    fprintf('複数audioplayer統計:\n');
    fprintf('  平均実行遅延: %.3fms\n', mean_delay * 1000);
    fprintf('  遅延標準偏差: %.3fms\n', std_delay * 1000);
    fprintf('  平均実間隔: %.3fs\n', mean_interval);

    result = struct('method', '複数audioplayer', 'mean_delay', mean_delay, ...
                   'std_delay', std_delay, 'mean_interval', mean_interval);
end

function result = test_external_command_delays()
    fprintf('外部コマンド実行遅延を測定...\n');

    delays = [];
    intervals = [];

    last_time = posixtime(datetime('now'));

    for i = 1:5  % 外部コマンドは重いので5回に減らす
        % system()実行時間測定
        start_time = tic;
        current_clock = posixtime(datetime('now'));

        % 軽量なシステムコマンド
        system('echo "test" > /dev/null');

        execution_delay = toc(start_time);
        delays(end+1) = execution_delay;

        % 実際の間隔測定
        if i > 1
            actual_interval = current_clock - last_time;
            intervals(end+1) = actual_interval;
        end
        last_time = current_clock;

        fprintf('  コマンド%d: 実行遅延%.3fms\n', i, execution_delay * 1000);

        % 1秒待機
        pause(1.0);
    end

    mean_delay = mean(delays);
    std_delay = std(delays);
    mean_interval = mean(intervals);

    fprintf('外部コマンド統計:\n');
    fprintf('  平均実行遅延: %.3fms\n', mean_delay * 1000);
    fprintf('  遅延標準偏差: %.3fms\n', std_delay * 1000);
    fprintf('  平均実間隔: %.3fs\n', mean_interval);

    result = struct('method', '外部コマンド', 'mean_delay', mean_delay, ...
                   'std_delay', std_delay, 'mean_interval', mean_interval);
end

function result = test_wait_system_precision()
    fprintf('待機システムの精度を測定...\n');

    target_intervals = [0.1, 0.5, 1.0, 1.5, 2.0]; % 様々な待機時間をテスト
    wait_errors = [];

    for target_idx = 1:length(target_intervals)
        target = target_intervals(target_idx);
        errors = [];

        for i = 1:5
            start_time = posixtime(datetime('now'));

            % pause()による待機
            pause(target);

            actual_wait = posixtime(datetime('now')) - start_time;
            error = actual_wait - target;
            errors(end+1) = error;

            fprintf('  目標%.1fs: 実際%.3fs, 誤差%+.1fms\n', ...
                target, actual_wait, error * 1000);
        end

        mean_error = mean(errors);
        wait_errors(end+1) = abs(mean_error);

        fprintf('    平均誤差: %+.1fms\n', mean_error * 1000);
    end

    % posixtime()による高精度待機テスト
    fprintf('\nposixtime()高精度待機テスト:\n');
    precise_errors = [];

    for i = 1:10
        start_time = posixtime(datetime('now'));
        target_time = start_time + 1.0;

        % 高精度待機
        while posixtime(datetime('now')) < target_time
            pause(0.001);
        end

        actual_time = posixtime(datetime('now'));
        error = actual_time - target_time;
        precise_errors(end+1) = error;

        fprintf('  精密待機%d: 誤差%+.1fms\n', i, error * 1000);
    end

    mean_pause_error = mean(wait_errors);
    mean_precise_error = mean(abs(precise_errors));

    fprintf('待機システム統計:\n');
    fprintf('  pause()平均誤差: %.1fms\n', mean_pause_error * 1000);
    fprintf('  posixtime()精密待機誤差: %.1fms\n', mean_precise_error * 1000);

    result = struct('method', '待機システム', 'pause_error', mean_pause_error, ...
                   'precise_error', mean_precise_error, 'mean_delay', mean_precise_error, ...
                   'std_delay', std(abs(precise_errors)), 'mean_interval', 1.0);
end

function compare_delay_results(results)
    fprintf('\n手法別遅延特性比較:\n');
    fprintf('%-20s | 平均遅延 | 遅延標準偏差 | 間隔精度\n', '手法');
    fprintf('--------------------------------------------------------\n');

    for i = 1:length(results)
        r = results{i};
        if strcmp(r.method, '待機システム')
            fprintf('%-20s | %.1fms   | %.1fms      | %.3fs\n', ...
                r.method, r.precise_error*1000, r.std_delay*1000, r.mean_interval);
        else
            fprintf('%-20s | %.1fms   | %.1fms      | %.3fs\n', ...
                r.method, r.mean_delay*1000, r.std_delay*1000, r.mean_interval);
        end
    end
end

function propose_optimization(results)
    fprintf('\n=== 最適化提案 ===\n');

    % 最も遅延の少ない手法を特定
    min_delay = inf;
    best_method = '';

    for i = 1:length(results)
        r = results{i};
        if strcmp(r.method, '待機システム')
            current_delay = r.precise_error;
        else
            current_delay = r.mean_delay;
        end

        if current_delay < min_delay
            min_delay = current_delay;
            best_method = r.method;
        end
    end

    fprintf('最低遅延手法: %s (%.1fms)\n', best_method, min_delay * 1000);

    % 実用的推奨
    fprintf('\n実用的推奨:\n');

    if min_delay < 0.002  % 2ms以下
        fprintf('✅ %sは実用的な精度です\n', best_method);
        fprintf('→ main_experimentでの実装を推奨\n');
    elseif min_delay < 0.005  % 5ms以下
        fprintf('🔶 %sは許容範囲内です\n', best_method);
        fprintf('→ 実装可能だが更なる最適化余地あり\n');
    else
        fprintf('❌ 全手法とも遅延が大きすぎます\n');
        fprintf('→ 根本的なアプローチ変更が必要\n');
    end

    % 具体的な改善提案
    fprintf('\n改善提案:\n');
    fprintf('1. audioplayerオブジェクトの事前初期化\n');
    fprintf('2. posixtime()による高精度待機\n');
    fprintf('3. 音声ファイルの更なる短縮（0.1秒以下）\n');
    fprintf('4. システム優先度の調整\n');
    fprintf('5. リアルタイム処理フレームワークの採用\n');
end