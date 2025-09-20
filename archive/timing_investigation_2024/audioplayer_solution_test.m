% audioplayerオブジェクト事前初期化による6n+1問題解決テスト
% 詳細なデバッグログ付き

function audioplayer_solution_test()
    fprintf('=== audioplayerオブジェクト解決方式テスト ===\n');
    fprintf('6n+1問題をaudioplayerによる事前初期化で解決\n\n');

    try
        % 音声ファイル読み込み
        stim_sound_path = fullfile(pwd, 'assets', 'sounds', 'stim_beat_optimized.wav');
        player_sound_path = fullfile(pwd, 'assets', 'sounds', 'player_beat_optimized.wav');

        [sound_stim, fs_stim] = audioread(stim_sound_path);
        [sound_player, fs_player] = audioread(player_sound_path);

        fprintf('音声ファイル読み込み完了\n');

        % audioplayerオブジェクト解決方式の実行
        perform_audioplayer_solution_test(sound_stim, fs_stim, sound_player, fs_player);

    catch ME
        fprintf('ERROR: %s\n', ME.message);
    end
end

function perform_audioplayer_solution_test(sound_stim, fs_stim, sound_player, fs_player)
    fprintf('\n--- audioplayerオブジェクト事前初期化テスト ---\n');

    % 録音設定
    fs = 44100;
    duration = 15; % 15秒録音

    fprintf('これから%d秒間の録音・再生を開始します\n', duration);
    fprintf('12音を1.0秒間隔で再生します（audioplayerオブジェクト方式）\n');

    % audioplayerオブジェクトの事前初期化
    fprintf('\n=== audioplayerオブジェクト事前初期化 ===\n');
    players = cell(12, 1);
    init_start_time = posixtime(datetime('now'));

    for i = 1:12
        init_time = tic;
        if mod(i, 2) == 1
            players{i} = audioplayer(sound_stim(:,1), fs_stim);
            sound_type = '刺激音';
        else
            players{i} = audioplayer(sound_player(:,1), fs_player);
            sound_type = 'プレイヤー音';
        end
        init_elapsed = toc(init_time);

        % 6n+1パターンのマーキング
        if mod(i, 6) == 1 && mod(i, 2) == 1
            pattern_marker = ' ← ★6n+1刺激音';
        else
            pattern_marker = '';
        end

        fprintf('初期化%d: %s, 時間%.3fms%s\n', i, sound_type, init_elapsed*1000, pattern_marker);
    end

    total_init_time = posixtime(datetime('now')) - init_start_time;
    fprintf('全audioplayerオブジェクト初期化完了: %.3fs\n', total_init_time);

    % 録音準備
    recorder = audiorecorder(fs, 16, 1);

    % カウントダウン
    for i = 3:-1:1
        fprintf('%d...\n', i);
        pause(1);
    end

    fprintf('\n=== 録音・再生開始 ===\n');
    record(recorder);

    % タイミング記録用配列
    planned_times = [];
    actual_start_times = [];
    actual_play_times = [];
    play_delays = [];

    start_time = posixtime(datetime('now'));
    num_sounds = 12;

    % main_experimentと同じStage1パターン（audioplayerオブジェクト使用）
    for sound_index = 1:num_sounds
        % main_experimentと同じ絶対時刻スケジューリング
        target_time = (sound_index - 1) * 1.0 + 0.5;
        planned_times(end+1) = target_time;

        % 待機開始時刻
        wait_start = posixtime(datetime('now')) - start_time;

        % main_experimentと同じ待機システム
        while (posixtime(datetime('now')) - start_time) < target_time
            pause(0.001); % 1ms間隔の安定した待機
        end

        % 音声再生直前の時刻記録
        pre_play_time = posixtime(datetime('now')) - start_time;
        actual_start_times(end+1) = pre_play_time;

        % audioplayerオブジェクトによる音声再生
        play_start = tic;
        play(players{sound_index});
        play_elapsed = toc(play_start);

        % 音声再生直後の時刻記録
        post_play_time = posixtime(datetime('now')) - start_time;
        actual_play_times(end+1) = post_play_time;
        play_delays(end+1) = play_elapsed;

        % 詳細ログ
        wait_time = pre_play_time - wait_start;
        timing_error = pre_play_time - target_time;

        % 音声タイプとパターンマーキング
        if mod(sound_index, 2) == 1
            sound_type = '刺激音';
        else
            sound_type = 'プレイヤー音';
        end

        if mod(sound_index, 6) == 1 && mod(sound_index, 2) == 1
            pattern_marker = ' ← ★6n+1刺激音';
        else
            pattern_marker = '';
        end

        fprintf('音%d: %s, 目標%.3fs, 実際%.3fs, 誤差%+.1fms, play遅延%.3fms%s\n', ...
            sound_index, sound_type, target_time, pre_play_time, timing_error*1000, ...
            play_elapsed*1000, pattern_marker);

        % 前の音との間隔計算
        if sound_index > 1
            interval = pre_play_time - actual_start_times(end-1);
            interval_error = interval - 1.0; % 期待1.0秒との差

            if mod(sound_index, 6) == 1 && mod(sound_index, 2) == 1
                interval_marker = ' ← ★6n+1前間隔';
            else
                interval_marker = '';
            end

            fprintf('     → 前音からの間隔: %.3fs (誤差%+.1fms)%s\n', ...
                interval, interval_error*1000, interval_marker);
        end
    end

    % 録音終了
    pause(1.0);
    stop(recorder);
    audio_data = getaudiodata(recorder);

    fprintf('\n=== タイミング解析 ===\n');

    % 間隔分析
    intervals = [];
    for i = 2:length(actual_start_times)
        interval = actual_start_times(i) - actual_start_times(i-1);
        intervals(end+1) = interval;
    end

    % 6n+1パターン分析
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

    % 統計
    fprintf('\n内部時計測定結果:\n');
    fprintf('平均間隔: %.3fs (期待1.0s)\n', mean(intervals));
    fprintf('標準偏差: %.3fs (%.1fms)\n', std(intervals), std(intervals)*1000);

    if ~isempty(pattern_6n1_intervals) && ~isempty(other_intervals)
        fprintf('\n6n+1パターン分析（内部時計）:\n');
        fprintf('6n+1前間隔: %.3f±%.3fs (%d個)\n', ...
            mean(pattern_6n1_intervals), std(pattern_6n1_intervals), length(pattern_6n1_intervals));
        fprintf('その他間隔: %.3f±%.3fs (%d個)\n', ...
            mean(other_intervals), std(other_intervals), length(other_intervals));

        difference = mean(pattern_6n1_intervals) - mean(other_intervals);
        fprintf('★内部時計差分: %+.1fms (6n+1の方が%s)\n', ...
            difference*1000, iif(difference > 0, '長い', '短い'));
    end

    % play()関数の遅延分析
    fprintf('\nplay()関数遅延分析:\n');
    fprintf('平均play遅延: %.3fms\n', mean(play_delays)*1000);
    fprintf('最大play遅延: %.3fms\n', max(play_delays)*1000);
    fprintf('最小play遅延: %.3fms\n', min(play_delays)*1000);

    % 6n+1のplay遅延
    pattern_6n1_play_delays = [];
    other_play_delays = [];

    for i = 1:length(play_delays)
        if mod(i, 6) == 1 && mod(i, 2) == 1
            pattern_6n1_play_delays(end+1) = play_delays(i);
        else
            other_play_delays(end+1) = play_delays(i);
        end
    end

    if ~isempty(pattern_6n1_play_delays)
        fprintf('6n+1のplay遅延: %.3f±%.3fms (%d個)\n', ...
            mean(pattern_6n1_play_delays)*1000, std(pattern_6n1_play_delays)*1000, length(pattern_6n1_play_delays));
        fprintf('その他のplay遅延: %.3f±%.3fms (%d個)\n', ...
            mean(other_play_delays)*1000, std(other_play_delays)*1000, length(other_play_delays));
    end

    % 音響解析実行
    fprintf('\n=== 音響解析開始 ===\n');
    analyze_acoustic_intervals_with_logs(audio_data, fs, planned_times, actual_start_times);

    % データ保存
    save('audioplayer_solution_data.mat', 'audio_data', 'fs', 'planned_times', ...
         'actual_start_times', 'actual_play_times', 'play_delays', 'intervals');

    fprintf('\n測定データを audioplayer_solution_data.mat に保存\n');
end

function analyze_acoustic_intervals_with_logs(audio_data, fs, planned_times, software_times)
    % 前回と同じ音響解析（改良版）
    window_size = round(0.02 * fs);
    hop_size = round(0.005 * fs);

    energy = [];
    time_axis = [];

    for i = 1:hop_size:(length(audio_data) - window_size)
        window = audio_data(i:i+window_size-1);
        energy(end+1) = sum(window.^2);
        time_axis(end+1) = i / fs;
    end

    % 音響イベント検出
    max_energy = max(energy);
    background_level = median(energy);
    dynamic_range = max_energy / background_level;

    if dynamic_range > 100
        threshold_factor = 0.15;
    elseif dynamic_range > 10
        threshold_factor = 0.25;
    else
        threshold_factor = 0.4;
    end

    threshold = max_energy * threshold_factor;
    min_interval = 0.6;

    detected_events = [];
    last_detection = -min_interval;

    for i = 5:(length(energy)-5)
        if energy(i) > threshold
            local_max = true;
            for j = (i-3):(i+3)
                if j ~= i && energy(j) >= energy(i)
                    local_max = false;
                    break;
                end
            end

            if local_max && (time_axis(i) - last_detection) >= min_interval
                detected_events(end+1) = time_axis(i);
                last_detection = time_axis(i);
            end
        end
    end

    fprintf('検出された音響イベント: %d個\n', length(detected_events));

    % 音響間隔の計算
    if length(detected_events) >= 2
        acoustic_intervals = [];
        for i = 2:length(detected_events)
            interval = detected_events(i) - detected_events(i-1);
            acoustic_intervals(end+1) = interval;
        end

        % 6n+1パターン分析（音響）
        acoustic_pattern_6n1_intervals = [];
        acoustic_other_intervals = [];

        for i = 1:length(acoustic_intervals)
            sound_index = i + 1;
            if mod(sound_index, 6) == 1 && mod(sound_index, 2) == 1
                acoustic_pattern_6n1_intervals(end+1) = acoustic_intervals(i);
            else
                acoustic_other_intervals(end+1) = acoustic_intervals(i);
            end
        end

        fprintf('\n音響測定結果:\n');
        fprintf('平均間隔: %.3fs\n', mean(acoustic_intervals));
        fprintf('標準偏差: %.3fs (%.1fms)\n', std(acoustic_intervals), std(acoustic_intervals)*1000);

        if ~isempty(acoustic_pattern_6n1_intervals) && ~isempty(acoustic_other_intervals)
            fprintf('\n6n+1パターン分析（音響）:\n');
            fprintf('6n+1前間隔: %.3f±%.3fs (%d個)\n', ...
                mean(acoustic_pattern_6n1_intervals), std(acoustic_pattern_6n1_intervals), length(acoustic_pattern_6n1_intervals));
            fprintf('その他間隔: %.3f±%.3fs (%d個)\n', ...
                mean(acoustic_other_intervals), std(acoustic_other_intervals), length(acoustic_other_intervals));

            acoustic_difference = mean(acoustic_pattern_6n1_intervals) - mean(acoustic_other_intervals);
            fprintf('★音響差分: %+.1fms (6n+1の方が%s)\n', ...
                acoustic_difference*1000, iif(acoustic_difference > 0, '長い', '短い'));

            % 解決効果の判定
            if abs(acoustic_difference) < 10 % 10ms以下
                fprintf('→ ✅ 6n+1問題解決！ (差分10ms以下)\n');
            elseif abs(acoustic_difference) < 20 % 20ms以下
                fprintf('→ 🔶 6n+1問題改善 (差分20ms以下)\n');
            else
                fprintf('→ ❌ 6n+1問題残存 (差分20ms超)\n');
            end
        end
    end
end

function result = iif(condition, true_val, false_val)
    if condition
        result = true_val;
    else
        result = false_val;
    end
end