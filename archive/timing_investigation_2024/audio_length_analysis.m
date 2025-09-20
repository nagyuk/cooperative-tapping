% 音声ファイル長さ分析と短縮版作成

function audio_length_analysis()
    fprintf('=== 音声ファイル長さ分析 ===\n');

    % 現在の音声ファイル解析
    stim_sound_path = fullfile(pwd, 'assets', 'sounds', 'stim_beat_optimized.wav');
    player_sound_path = fullfile(pwd, 'assets', 'sounds', 'player_beat_optimized.wav');

    [sound_stim, fs_stim] = audioread(stim_sound_path);
    [sound_player, fs_player] = audioread(player_sound_path);

    stim_duration = length(sound_stim) / fs_stim;
    player_duration = length(sound_player) / fs_player;

    fprintf('現在の音声ファイル:\n');
    fprintf('  刺激音長さ: %.3fs (%.0fサンプル)\n', stim_duration, length(sound_stim));
    fprintf('  プレイヤー音長さ: %.3fs (%.0fサンプル)\n', player_duration, length(sound_player));
    fprintf('  間隔期待値: 1.0s\n');

    % 重複問題の診断
    if stim_duration > 0.5
        fprintf('⚠️  刺激音が長すぎます (%.3fs > 0.5s推奨)\n', stim_duration);
    end
    if player_duration > 0.5
        fprintf('⚠️  プレイヤー音が長すぎます (%.3fs > 0.5s推奨)\n', player_duration);
    end

    % 重複シミュレーション
    fprintf('\n重複分析:\n');
    fprintf('  音1(0.5s)再生開始 + 長さ%.3fs = %.3fs終了\n', stim_duration, 0.5 + stim_duration);
    fprintf('  音2(1.5s)再生開始\n');
    overlap = (0.5 + stim_duration) - 1.5;
    if overlap > 0
        fprintf('  ❌ 重複時間: %.3fs\n', overlap);
    else
        fprintf('  ✅ 重複なし（%.3fs空白）\n', -overlap);
    end

    % 最適な音声長さの提案
    optimal_length = 0.4; % 0.4秒を提案
    fprintf('\n最適化提案:\n');
    fprintf('  推奨音声長さ: %.1fs\n', optimal_length);
    fprintf('  理由: 1.0s間隔の%.0f%%、%.1fs余裕\n', optimal_length/1.0*100, 1.0-optimal_length);

    % 短縮版音声ファイル作成
    create_shortened_audio_files(sound_stim, fs_stim, sound_player, fs_player, optimal_length);

    % タイミング精度テスト
    test_timing_precision_with_shortened_audio();
end

function create_shortened_audio_files(sound_stim, fs_stim, sound_player, fs_player, target_duration)
    fprintf('\n=== 短縮版音声ファイル作成 ===\n');

    % 目標サンプル数計算
    target_samples_stim = round(target_duration * fs_stim);
    target_samples_player = round(target_duration * fs_player);

    % 短縮（トリミング）
    sound_stim_short = sound_stim(1:min(target_samples_stim, length(sound_stim)), :);
    sound_player_short = sound_player(1:min(target_samples_player, length(sound_player)), :);

    % フェードアウト追加（クリック音防止）
    fade_samples = round(0.01 * fs_stim); % 10msフェードアウト
    if length(sound_stim_short) > fade_samples
        fade_curve = linspace(1, 0, fade_samples)';
        sound_stim_short(end-fade_samples+1:end, :) = sound_stim_short(end-fade_samples+1:end, :) .* fade_curve;
    end

    fade_samples_player = round(0.01 * fs_player);
    if length(sound_player_short) > fade_samples_player
        fade_curve = linspace(1, 0, fade_samples_player)';
        sound_player_short(end-fade_samples_player+1:end, :) = sound_player_short(end-fade_samples_player+1:end, :) .* fade_curve;
    end

    % 保存
    short_stim_path = fullfile(pwd, 'assets', 'sounds', 'stim_beat_short.wav');
    short_player_path = fullfile(pwd, 'assets', 'sounds', 'player_beat_short.wav');

    audiowrite(short_stim_path, sound_stim_short, fs_stim);
    audiowrite(short_player_path, sound_player_short, fs_player);

    fprintf('短縮版ファイル作成完了:\n');
    fprintf('  %s (%.3fs)\n', short_stim_path, length(sound_stim_short)/fs_stim);
    fprintf('  %s (%.3fs)\n', short_player_path, length(sound_player_short)/fs_player);
end

function test_timing_precision_with_shortened_audio()
    fprintf('\n=== 短縮版音声での精度テスト ===\n');

    % 短縮版音声読み込み
    try
        short_stim_path = fullfile(pwd, 'assets', 'sounds', 'stim_beat_short.wav');
        short_player_path = fullfile(pwd, 'assets', 'sounds', 'player_beat_short.wav');

        [sound_stim_short, fs_stim] = audioread(short_stim_path);
        [sound_player_short, fs_player] = audioread(short_player_path);

        fprintf('短縮版音声読み込み完了\n');

        % 簡易タイミングテスト（録音なし）
        fprintf('\n5音タイミングテスト開始...\n');

        start_time = posixtime(datetime('now'));
        planned_times = [];
        actual_times = [];

        for i = 1:5
            target_time = (i-1) * 1.0 + 0.5;
            planned_times(end+1) = target_time;

            % 待機
            while (posixtime(datetime('now')) - start_time) < target_time
                pause(0.001);
            end

            % 音声再生（短縮版）
            actual_time = posixtime(datetime('now')) - start_time;
            actual_times(end+1) = actual_time;

            if mod(i, 2) == 1
                sound(sound_stim_short(:,1), fs_stim);
                type_str = '刺激音';
            else
                sound(sound_player_short(:,1), fs_player);
                type_str = 'プレイヤー音';
            end

            timing_error = (actual_time - target_time) * 1000;
            fprintf('音%d: %s, 目標%.3fs, 実際%.3fs, 誤差%+.1fms\n', ...
                i, type_str, target_time, actual_time, timing_error);

            if i > 1
                interval = actual_time - actual_times(end-1);
                interval_error = (interval - 1.0) * 1000;
                fprintf('     → 間隔: %.3fs (誤差%+.1fms)\n', interval, interval_error);
            end
        end

        % 統計
        intervals = [];
        for i = 2:length(actual_times)
            intervals(end+1) = actual_times(i) - actual_times(i-1);
        end

        fprintf('\n短縮版音声タイミング統計:\n');
        fprintf('  平均間隔: %.3fs (期待1.0s)\n', mean(intervals));
        fprintf('  標準偏差: %.1fms\n', std(intervals)*1000);
        fprintf('  最大誤差: %.1fms\n', max(abs(intervals - 1.0))*1000);

        if std(intervals) < 0.005 % 5ms以下
            fprintf('  ✅ 短縮版音声で高精度タイミング達成！\n');
        else
            fprintf('  ⚠️  更なる調整が必要\n');
        end

    catch ME
        fprintf('短縮版テストエラー: %s\n', ME.message);
    end
end