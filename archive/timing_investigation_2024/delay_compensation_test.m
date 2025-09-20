% 音声再生遅延補正システムのテスト
% 7ms遅延を補正して完璧な1.0秒間隔を実現

function delay_compensation_test()
    fprintf('=== 音声再生遅延補正システムテスト ===\n');
    fprintf('測定された7ms遅延を補正して正確なタイミングを実現\n\n');

    % 音声ファイル読み込み
    stim_path = fullfile(pwd, 'assets', 'sounds', 'stim_beat_optimized.wav');
    player_path = fullfile(pwd, 'assets', 'sounds', 'player_beat_optimized.wav');
    [sound_stim, fs_stim] = audioread(stim_path);
    [sound_player, fs_player] = audioread(player_path);

    % 複数の補正値をテスト
    compensation_values = [0, -0.005, -0.007, -0.010, -0.015]; % 0ms, 5ms, 7ms, 10ms, 15ms早める

    for i = 1:length(compensation_values)
        compensation = compensation_values(i);
        fprintf('\n=== 補正値 %.1fms のテスト ===\n', compensation * 1000);

        if compensation == 0
            test_no_compensation(sound_stim, fs_stim, sound_player, fs_player);
        else
            test_delay_compensation(sound_stim, fs_stim, sound_player, fs_player, compensation);
        end
    end

    % 最適補正値の特定
    fprintf('\n=== 最適補正値の特定 ===\n');
    find_optimal_compensation(sound_stim, fs_stim, sound_player, fs_player);
end

function test_no_compensation(sound_stim, fs_stim, sound_player, fs_player)
    fprintf('補正なし（従来版）のタイミング測定...\n');

    % 複数audioplayerを事前準備
    players = cell(6, 1);
    for i = 1:6
        if mod(i, 2) == 1
            players{i} = audioplayer(sound_stim(:,1), fs_stim);
        else
            players{i} = audioplayer(sound_player(:,1), fs_player);
        end
    end

    start_time = posixtime(datetime('now'));
    actual_play_times = [];

    for sound_index = 1:6
        % 従来の実装（補正なし）
        target_time = (sound_index - 1) * 1.0 + 0.5;

        % posixtime()による高精度待機
        while (posixtime(datetime('now')) - start_time) < target_time
            pause(0.001);
        end

        % 再生開始時刻記録
        pre_play = posixtime(datetime('now')) - start_time;

        % 音声再生
        play(players{sound_index});

        actual_play_times(end+1) = pre_play;

        fprintf('音%d: 目標%.3fs, 実際%.3fs, 誤差%+.1fms\n', ...
            sound_index, target_time, pre_play, (pre_play - target_time) * 1000);
    end

    % 間隔分析
    analyze_intervals(actual_play_times, '補正なし');
end

function test_delay_compensation(sound_stim, fs_stim, sound_player, fs_player, compensation)
    fprintf('補正値%.1fmsでのタイミング測定...\n', compensation * 1000);

    % 複数audioplayerを事前準備
    players = cell(6, 1);
    for i = 1:6
        if mod(i, 2) == 1
            players{i} = audioplayer(sound_stim(:,1), fs_stim);
        else
            players{i} = audioplayer(sound_player(:,1), fs_player);
        end
    end

    start_time = posixtime(datetime('now'));
    actual_play_times = [];

    for sound_index = 1:6
        % 補正版実装
        base_target_time = (sound_index - 1) * 1.0 + 0.5;
        compensated_target_time = base_target_time + compensation; % 早める

        % posixtime()による高精度待機（補正済み）
        while (posixtime(datetime('now')) - start_time) < compensated_target_time
            pause(0.001);
        end

        % 再生開始時刻記録
        pre_play = posixtime(datetime('now')) - start_time;

        % 音声再生
        play(players{sound_index});

        actual_play_times(end+1) = pre_play;

        % 目標時刻との比較（補正前の時刻と比較）
        original_error = (pre_play - base_target_time) * 1000;

        fprintf('音%d: 目標%.3fs, 実際%.3fs, 誤差%+.1fms\n', ...
            sound_index, base_target_time, pre_play, original_error);
    end

    % 間隔分析
    analyze_intervals(actual_play_times, sprintf('%.1fms補正', compensation * 1000));
end

function find_optimal_compensation(sound_stim, fs_stim, sound_player, fs_player)
    fprintf('最適補正値を細かく探索...\n');

    % 細かい補正値で探索
    fine_compensations = [-0.012, -0.010, -0.008, -0.007, -0.006, -0.005, -0.004];
    best_score = inf;
    best_compensation = 0;
    results = [];

    for compensation = fine_compensations
        % 短縮テスト（4音のみ）
        players = cell(4, 1);
        for i = 1:4
            if mod(i, 2) == 1
                players{i} = audioplayer(sound_stim(:,1), fs_stim);
            else
                players{i} = audioplayer(sound_player(:,1), fs_player);
            end
        end

        start_time = posixtime(datetime('now'));
        actual_times = [];

        for sound_index = 1:4
            base_target_time = (sound_index - 1) * 1.0 + 0.5;
            compensated_target_time = base_target_time + compensation;

            while (posixtime(datetime('now')) - start_time) < compensated_target_time
                pause(0.001);
            end

            pre_play = posixtime(datetime('now')) - start_time;
            play(players{sound_index});
            actual_times(end+1) = pre_play;
        end

        % 精度評価
        target_times = [0.5, 1.5, 2.5, 3.5];
        errors = actual_times - target_times;
        mean_error = mean(errors);
        std_error = std(errors);
        score = abs(mean_error) + std_error; % 平均誤差の絶対値 + 標準偏差

        fprintf('補正%.1fms: 平均誤差%+.1fms, 標準偏差%.1fms, スコア%.3f\n', ...
            compensation * 1000, mean_error * 1000, std_error * 1000, score);

        results(end+1,:) = [compensation, mean_error, std_error, score];

        if score < best_score
            best_score = score;
            best_compensation = compensation;
        end

        pause(0.5); % 短い休憩
    end

    fprintf('\n最適補正値: %.1fms (スコア%.3f)\n', best_compensation * 1000, best_score);

    % 結果表示
    fprintf('\n補正値探索結果:\n');
    fprintf('補正値(ms) | 平均誤差(ms) | 標準偏差(ms) | スコア\n');
    fprintf('--------------------------------------------------\n');
    for i = 1:size(results, 1)
        fprintf('%+8.1f   | %+9.1f   | %9.1f   | %.3f\n', ...
            results(i,1)*1000, results(i,2)*1000, results(i,3)*1000, results(i,4));
    end

    % 実装推奨
    fprintf('\n実装推奨:\n');
    if best_score < 0.002  % 2ms未満
        fprintf('✅ 補正値%.1fmsを main_experiment に実装することを強く推奨\n', best_compensation * 1000);
        generate_implementation_code(best_compensation);
    elseif best_score < 0.005  % 5ms未満
        fprintf('🔶 補正値%.1fmsは改善効果あり、実装を検討\n', best_compensation * 1000);
    else
        fprintf('❌ 十分な改善効果なし、別のアプローチが必要\n');
    end
end

function analyze_intervals(times, method_name)
    if length(times) < 2
        fprintf('%s: 間隔分析不可\n', method_name);
        return;
    end

    intervals = [];
    for i = 2:length(times)
        intervals(end+1) = times(i) - times(i-1);
    end

    mean_interval = mean(intervals);
    std_interval = std(intervals);
    max_error = max(abs(intervals - 1.0));

    fprintf('%s間隔分析:\n', method_name);
    fprintf('  平均間隔: %.3fs (期待1.0s)\n', mean_interval);
    fprintf('  標準偏差: %.1fms\n', std_interval * 1000);
    fprintf('  最大誤差: %.1fms\n', max_error * 1000);

    % 詳細間隔表示
    for i = 1:length(intervals)
        error_ms = (intervals(i) - 1.0) * 1000;
        fprintf('  間隔%d: %.3fs (誤差%+.1fms)\n', i, intervals(i), error_ms);
    end

    % 6n+1パターン分析（音数が十分な場合）
    if length(intervals) >= 6
        % 6n+1前間隔を特定
        pattern_6n1_intervals = [];
        other_intervals = [];

        for i = 1:length(intervals)
            sound_index = i + 1; % 間隔iの終点の音番号
            if mod(sound_index, 6) == 1 && mod(sound_index, 2) == 1
                pattern_6n1_intervals(end+1) = intervals(i);
            else
                other_intervals(end+1) = intervals(i);
            end
        end

        if ~isempty(pattern_6n1_intervals) && ~isempty(other_intervals)
            difference = mean(pattern_6n1_intervals) - mean(other_intervals);
            fprintf('  6n+1パターン差分: %+.1fms\n', difference * 1000);
        end
    end
end

function generate_implementation_code(optimal_compensation)
    fprintf('\n=== main_experiment実装コード ===\n');
    fprintf('以下のコードをStage1の音声再生部分に適用:\n\n');

    fprintf('%% 最適化されたStage1音声再生（補正版）\n');
    fprintf('AUDIO_DELAY_COMPENSATION = %.6f; %% %.1fms補正\n\n', optimal_compensation, optimal_compensation * 1000);

    fprintf('for sound_index = 1:total_sounds\n');
    fprintf('    %% 補正済み目標時刻計算\n');
    fprintf('    base_target_time = (sound_index - 1) * 1.0 + 0.5;\n');
    fprintf('    compensated_target_time = base_target_time + AUDIO_DELAY_COMPENSATION;\n\n');

    fprintf('    %% 高精度待機\n');
    fprintf('    while (posixtime(datetime(''now'')) - runner.clock_start) < compensated_target_time\n');
    fprintf('        pause(0.001);\n');
    fprintf('    end\n\n');

    fprintf('    %% 音声再生（既存のaudioplayerまたはsound()）\n');
    fprintf('    if mod(sound_index, 2) == 1\n');
    fprintf('        play(runner.stim_player); %% または sound(runner.sound_stim(:,1), runner.fs_stim);\n');
    fprintf('    else\n');
    fprintf('        play(runner.player_player); %% または sound(runner.sound_player(:,1), runner.fs_player);\n');
    fprintf('    end\n');
    fprintf('end\n\n');

    fprintf('この実装により、理論上は1.0秒間隔の±1ms精度が達成されます。\n');
end