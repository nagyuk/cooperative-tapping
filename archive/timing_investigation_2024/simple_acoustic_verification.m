% 簡易音響検証システム（マイクアクセス不要）
% 聴覚による主観評価を客観化

function simple_acoustic_verification()
    fprintf('=== 簡易音響検証システム ===\n');
    fprintf('マイクなしで6n+1問題を検証します\n\n');

    % 実験音声読み込み
    stim_sound_path = fullfile(pwd, 'assets', 'sounds', 'stim_beat_optimized.wav');
    player_sound_path = fullfile(pwd, 'assets', 'sounds', 'player_beat_optimized.wav');

    [sound_stim, fs_stim] = audioread(stim_sound_path);
    [sound_player, fs_player] = audioread(player_sound_path);

    fprintf('音声ファイル読み込み完了\n');

    % テスト1: 6n+1パターンの主観評価
    test_6n1_subjective_evaluation(sound_stim, fs_stim, sound_player, fs_player);

    % テスト2: タイミング精度の別手法測定
    test_alternative_timing_measurement(sound_stim, fs_stim, sound_player, fs_player);

    % テスト3: システム負荷との相関
    test_system_load_correlation(sound_stim, fs_stim, sound_player, fs_player);
end

function test_6n1_subjective_evaluation(sound_stim, fs_stim, sound_player, fs_player)
    fprintf('\n--- テスト1: 6n+1パターン主観評価 ---\n');
    fprintf('以下の音列を聞いて、6n+1の刺激音で遅延を感じるかテストします\n');
    fprintf('音番号と体感される遅延をメモしてください\n\n');

    fprintf('音の種類：\n');
    fprintf('- 奇数番号: 刺激音\n');
    fprintf('- 偶数番号: プレイヤー音\n');
    fprintf('- 6n+1番号 (1,7,13...): ← ここで遅延があるか聞いてください\n\n');

    input('準備ができたらEnterを押してください...');

    % 18音を再生（3回の6n+1パターンを含む）
    for i = 1:18
        % 目標タイミング（1.2秒間隔）
        target_time = (i-1) * 1.2;

        % 正確な待機
        start_time = posixtime(datetime('now'));
        while (posixtime(datetime('now')) - start_time) < target_time
            pause(0.001);
        end

        % 6n+1パターンのマーキング
        if mod(i, 6) == 1 && mod(i, 2) == 1
            pattern_marker = ' ← 6n+1刺激音！遅延を感じますか？';
        else
            pattern_marker = '';
        end

        % 音再生
        if mod(i, 2) == 1
            sound(sound_stim(:,1), fs_stim);
            fprintf('音%d: 刺激音%s\n', i, pattern_marker);
        else
            sound(sound_player(:,1), fs_player);
            fprintf('音%d: プレイヤー音\n', i);
        end

        pause(0.1); % 表示の見やすさ
    end

    fprintf('\n主観評価終了\n');
    fprintf('6n+1の刺激音（1番、7番、13番）で遅延を感じましたか？\n');
end

function test_alternative_timing_measurement(sound_stim, fs_stim, sound_player, fs_player)
    fprintf('\n--- テスト2: 代替タイミング測定 ---\n');
    fprintf('tic/tocによる高精度測定\n');

    times = [];
    intervals = [];

    for i = 1:12
        % tic/tocによる高精度測定
        tic;

        % 音再生
        if mod(i, 2) == 1
            sound(sound_stim(:,1), fs_stim);
            sound_type = '刺激音';
        else
            sound(sound_player(:,1), fs_player);
            sound_type = 'プレイヤー音';
        end

        elapsed = toc;
        times(end+1) = elapsed;

        % 6n+1パターンの検出
        if mod(i, 6) == 1 && mod(i, 2) == 1
            pattern_marker = ' ← 6n+1パターン';
        else
            pattern_marker = '';
        end

        fprintf('音%d: %s, 経過時間%.6fs%s\n', i, sound_type, elapsed, pattern_marker);

        % 間隔計算
        if i > 1
            interval = times(i) - times(i-1);
            intervals(end+1) = interval;
            fprintf('   間隔: %.6fs\n', interval);
        end

        pause(1.0); % 1秒間隔
    end

    % 6n+1間隔の分析
    if length(intervals) >= 6
        pattern_indices = [];
        for i = 2:length(times)
            if mod(i, 6) == 1 && mod(i, 2) == 1 % 6n+1刺激音
                pattern_indices(end+1) = i-1; % 間隔のインデックス
            end
        end

        if ~isempty(pattern_indices)
            pattern_intervals = intervals(pattern_indices);
            other_intervals = intervals;
            other_intervals(pattern_indices) = [];

            fprintf('\ntic/toc測定結果:\n');
            fprintf('6n+1前間隔: %.6f±%.6fs\n', mean(pattern_intervals), std(pattern_intervals));
            fprintf('その他間隔: %.6f±%.6fs\n', mean(other_intervals), std(other_intervals));

            if ~isempty(other_intervals)
                diff = mean(pattern_intervals) - mean(other_intervals);
                fprintf('差分: %.6fs (%.1fms)\n', diff, diff*1000);
            end
        end
    end
end

function test_system_load_correlation(sound_stim, fs_stim, sound_player, fs_player)
    fprintf('\n--- テスト3: システム負荷相関テスト ---\n');
    fprintf('CPU負荷を変化させて6n+1パターンとの相関を調査\n');

    % 軽負荷テスト
    fprintf('\n軽負荷状態でのテスト:\n');
    run_load_test(sound_stim, fs_stim, sound_player, fs_player, 'light');

    pause(2);

    % 重負荷テスト
    fprintf('\n重負荷状態でのテスト:\n');
    % 負荷生成
    load_task = parfeval(backgroundPool, @generate_cpu_load, 0, 3);

    run_load_test(sound_stim, fs_stim, sound_player, fs_player, 'heavy');

    % 負荷停止
    cancel(load_task);

    fprintf('\nシステム負荷テスト完了\n');
end

function run_load_test(sound_stim, fs_stim, sound_player, fs_player, load_type)
    fprintf('%s負荷での音再生テスト:\n', load_type);

    for i = 1:6
        start_time = tic;

        if mod(i, 2) == 1
            sound(sound_stim(:,1), fs_stim);
            sound_type = '刺激音';
        else
            sound(sound_player(:,1), fs_player);
            sound_type = 'プレイヤー音';
        end

        elapsed = toc(start_time);

        if mod(i, 6) == 1 && mod(i, 2) == 1
            pattern_marker = ' ← 6n+1！';
        else
            pattern_marker = '';
        end

        fprintf('  音%d: %s, 遅延%.3fms%s\n', i, sound_type, elapsed*1000, pattern_marker);

        pause(0.8);
    end
end

function generate_cpu_load(duration)
    % CPU負荷生成（duration秒間）
    end_time = posixtime(datetime('now')) + duration;
    while posixtime(datetime('now')) < end_time
        % CPU集約的な処理
        sum(rand(1000, 1000) * rand(1000, 1000));
    end
end