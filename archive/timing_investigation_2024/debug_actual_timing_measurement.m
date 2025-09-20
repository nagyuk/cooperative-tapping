% 実際のStage1音再生タイミングを正確に測定

function debug_actual_timing_measurement()
    fprintf('=== Stage1実際のタイミング測定 ===\n');

    % 実験と同じ設定で音声読み込み
    stim_sound_path = fullfile(pwd, 'assets', 'sounds', 'stim_beat_optimized.wav');
    player_sound_path = fullfile(pwd, 'assets', 'sounds', 'player_beat_optimized.wav');

    if ~exist(stim_sound_path, 'file')
        error('刺激音ファイルが見つかりません: %s', stim_sound_path);
    end
    if ~exist(player_sound_path, 'file')
        error('プレイヤー音ファイルが見つかりません: %s', player_sound_path);
    end

    [sound_stim, fs_stim] = audioread(stim_sound_path);
    [sound_player, fs_player] = audioread(player_sound_path);

    fprintf('音声ファイル読み込み完了\n');

    % Stage1と同じパターンでタイミング測定
    required_taps = 5; % 短縮版
    total_sounds = required_taps * 2;

    fprintf('\n--- 実際のStage1パターン再現 ---\n');

    start_time = posixtime(datetime('now'));
    actual_times = [];
    target_times = [];

    for sound_index = 1:total_sounds
        % 実験と同じ目標時刻計算
        target_time = (sound_index - 1) * 1.0 + 0.5;
        target_times(end+1) = target_time;

        % 実験と同じ待機ループ
        current_time = posixtime(datetime('now')) - start_time;

        % 粗い待機
        while current_time < (target_time - 0.01)
            pause(0.002);
            current_time = posixtime(datetime('now')) - start_time;
        end

        % 精密待機
        while current_time < target_time
            current_time = posixtime(datetime('now')) - start_time;
        end

        % 音声再生直前の時刻記録
        pre_sound_time = posixtime(datetime('now')) - start_time;

        % 音声再生
        if mod(sound_index, 2) == 1
            % 刺激音
            sound(sound_stim(:,1), fs_stim);
            sound_type = '刺激音';
        else
            % プレイヤー音
            sound(sound_player(:,1), fs_player);
            sound_type = 'プレイヤー音';
        end

        % 音声再生直後の時刻記録
        post_sound_time = posixtime(datetime('now')) - start_time;
        actual_times(end+1) = post_sound_time;

        sound_delay = (post_sound_time - pre_sound_time) * 1000;
        timing_error = (post_sound_time - target_time) * 1000;

        fprintf('音%d: %s, 目標%.3fs, 実際%.3fs, 誤差%.1fms, 音声遅延%.1fms\n', ...
            sound_index, sound_type, target_time, post_sound_time, timing_error, sound_delay);

        % 前の音との間隔計算
        if sound_index > 1
            interval = post_sound_time - actual_times(end-1);
            fprintf('     → 前音からの間隔: %.3fs (期待1.0s)\n', interval);
        end

        pause(0.05); % 短い待機
    end

    % 間隔分析
    fprintf('\n--- 間隔分析 ---\n');
    intervals = [];
    for i = 2:length(actual_times)
        interval = actual_times(i) - actual_times(i-1);
        intervals(end+1) = interval;
        fprintf('間隔%d: %.3fs\n', i-1, interval);
    end

    fprintf('\n間隔統計:\n');
    fprintf('平均間隔: %.3fs (期待1.0s)\n', mean(intervals));
    fprintf('標準偏差: %.3fs\n', std(intervals));
    fprintf('最小間隔: %.3fs\n', min(intervals));
    fprintf('最大間隔: %.3fs\n', max(intervals));

    % 不規則パターンの特定
    irregular_indices = find(abs(intervals - 1.0) > 0.1);
    if ~isempty(irregular_indices)
        fprintf('\n不規則な間隔:\n');
        for idx = irregular_indices
            fprintf('  間隔%d: %.3fs (誤差%.3fs)\n', idx, intervals(idx), intervals(idx) - 1.0);
        end
    end
end