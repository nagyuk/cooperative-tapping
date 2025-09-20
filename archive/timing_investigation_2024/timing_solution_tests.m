% 音響タイミング問題の根本的解決手法テスト
% 複数のアプローチを実際にテストして最適解を見つける

function timing_solution_tests()
    fprintf('=== 音響タイミング問題 根本的解決手法テスト ===\n');
    fprintf('実音響測定で1.0秒間隔の正確性を検証\n\n');

    % 音声ファイル読み込み
    stim_path = fullfile(pwd, 'assets', 'sounds', 'stim_beat_optimized.wav');
    player_path = fullfile(pwd, 'assets', 'sounds', 'player_beat_optimized.wav');
    [sound_stim, fs_stim] = audioread(stim_path);
    [sound_player, fs_player] = audioread(player_path);

    results = {};

    % 手法1: audioplayerの同期再生
    fprintf('=== 手法1: audioplayerの同期再生 ===\n');
    results{end+1} = test_synchronized_audioplayer(sound_stim, fs_stim, sound_player, fs_player);

    % 手法2: 強制停止+即座再生
    fprintf('\n=== 手法2: 強制停止+即座再生 ===\n');
    results{end+1} = test_forced_stop_method(sound_stim, fs_stim, sound_player, fs_player);

    % 手法3: 外部コマンド使用
    fprintf('\n=== 手法3: 外部afplayコマンド ===\n');
    results{end+1} = test_external_afplay_method(sound_stim, fs_stim, sound_player, fs_player);

    % 手法4: 複数audioplayer事前準備
    fprintf('\n=== 手法4: 複数audioplayer事前準備 ===\n');
    results{end+1} = test_multiple_audioplayer_method(sound_stim, fs_stim, sound_player, fs_player);

    % 手法5: タイミング補正方式
    fprintf('\n=== 手法5: タイミング補正方式 ===\n');
    results{end+1} = test_timing_correction_method(sound_stim, fs_stim, sound_player, fs_player);

    % 結果比較
    fprintf('\n=== 全手法結果比較 ===\n');
    compare_all_results(results);
end

function result = test_synchronized_audioplayer(sound_stim, fs_stim, sound_player, fs_player)
    fprintf('audioplayerの同期再生による正確なタイミング制御...\n');

    % 録音準備
    recorder = audiorecorder(44100, 16, 1);
    fprintf('4秒録音開始...\n');
    pause(1);
    record(recorder);

    % 同期再生テスト
    players = {audioplayer(sound_stim(:,1), fs_stim), audioplayer(sound_player(:,1), fs_player)};

    start_time = posixtime(datetime('now'));
    actual_times = [];

    for i = 1:4
        target_time = (i-1) * 1.0 + 0.5;

        % 前の音の完了を確認
        if i > 1
            while isplaying(players{mod(i-2, 2) + 1})
                pause(0.001);
            end
        end

        % 目標時刻まで待機
        while (posixtime(datetime('now')) - start_time) < target_time
            pause(0.001);
        end

        % 再生開始
        play(players{mod(i-1, 2) + 1});
        actual_times(end+1) = posixtime(datetime('now')) - start_time;

        fprintf('音%d再生: %.3fs\n', i, actual_times(end));
    end

    pause(1);
    stop(recorder);

    % 音響解析
    audio_data = getaudiodata(recorder);
    result = analyze_timing_accuracy(audio_data, 44100, '同期audioplayer', actual_times);
end

function result = test_forced_stop_method(sound_stim, fs_stim, sound_player, fs_player)
    fprintf('強制停止による音響分離...\n');

    % 録音準備
    recorder = audiorecorder(44100, 16, 1);
    fprintf('4秒録音開始...\n');
    pause(1);
    record(recorder);

    % 強制停止テスト
    players = {audioplayer(sound_stim(:,1), fs_stim), audioplayer(sound_player(:,1), fs_player)};

    start_time = posixtime(datetime('now'));
    actual_times = [];

    for i = 1:4
        target_time = (i-1) * 1.0 + 0.5;

        % 前の音を強制停止
        if i > 1
            stop(players{mod(i-2, 2) + 1});
            pause(0.01); % 短い待機
        end

        % 目標時刻まで待機
        while (posixtime(datetime('now')) - start_time) < target_time
            pause(0.001);
        end

        % 再生開始
        play(players{mod(i-1, 2) + 1});
        actual_times(end+1) = posixtime(datetime('now')) - start_time;

        fprintf('音%d再生: %.3fs\n', i, actual_times(end));
    end

    pause(1);
    stop(recorder);

    % 音響解析
    audio_data = getaudiodata(recorder);
    result = analyze_timing_accuracy(audio_data, 44100, '強制停止', actual_times);
end

function result = test_external_afplay_method(sound_stim, fs_stim, sound_player, fs_player)
    fprintf('外部afplayコマンドによる音声再生...\n');

    % 一時ファイル作成
    temp_stim = fullfile(tempdir, 'temp_stim.wav');
    temp_player = fullfile(tempdir, 'temp_player.wav');
    audiowrite(temp_stim, sound_stim, fs_stim);
    audiowrite(temp_player, sound_player, fs_player);

    % 録音準備
    recorder = audiorecorder(44100, 16, 1);
    fprintf('4秒録音開始...\n');
    pause(1);
    record(recorder);

    start_time = posixtime(datetime('now'));
    actual_times = [];

    for i = 1:4
        target_time = (i-1) * 1.0 + 0.5;

        % 目標時刻まで待機
        while (posixtime(datetime('now')) - start_time) < target_time
            pause(0.001);
        end

        % afplayで再生
        if mod(i, 2) == 1
            system(sprintf('afplay "%s" &', temp_stim));
        else
            system(sprintf('afplay "%s" &', temp_player));
        end

        actual_times(end+1) = posixtime(datetime('now')) - start_time;
        fprintf('音%d再生: %.3fs\n', i, actual_times(end));
    end

    pause(1);
    stop(recorder);

    % 一時ファイル削除
    delete(temp_stim);
    delete(temp_player);

    % 音響解析
    audio_data = getaudiodata(recorder);
    result = analyze_timing_accuracy(audio_data, 44100, '外部afplay', actual_times);
end

function result = test_multiple_audioplayer_method(sound_stim, fs_stim, sound_player, fs_player)
    fprintf('複数audioplayer事前準備による制御...\n');

    % 全音声を個別に準備
    players = cell(4, 1);
    for i = 1:4
        if mod(i, 2) == 1
            players{i} = audioplayer(sound_stim(:,1), fs_stim);
        else
            players{i} = audioplayer(sound_player(:,1), fs_player);
        end
    end

    % 録音準備
    recorder = audiorecorder(44100, 16, 1);
    fprintf('4秒録音開始...\n');
    pause(1);
    record(recorder);

    start_time = posixtime(datetime('now'));
    actual_times = [];

    for i = 1:4
        target_time = (i-1) * 1.0 + 0.5;

        % 目標時刻まで待機
        while (posixtime(datetime('now')) - start_time) < target_time
            pause(0.001);
        end

        % 専用オブジェクトで再生
        play(players{i});
        actual_times(end+1) = posixtime(datetime('now')) - start_time;

        fprintf('音%d再生: %.3fs\n', i, actual_times(end));
    end

    pause(1);
    stop(recorder);

    % 音響解析
    audio_data = getaudiodata(recorder);
    result = analyze_timing_accuracy(audio_data, 44100, '複数audioplayer', actual_times);
end

function result = test_timing_correction_method(sound_stim, fs_stim, sound_player, fs_player)
    fprintf('タイミング補正による精度向上...\n');

    % 録音準備
    recorder = audiorecorder(44100, 16, 1);
    fprintf('4秒録音開始...\n');
    pause(1);
    record(recorder);

    % 補正値（前回の測定結果から推定）
    timing_corrections = [0, -0.664, -0.154, -0.012]; % 実測値から逆算

    start_time = posixtime(datetime('now'));
    actual_times = [];

    for i = 1:4
        base_target_time = (i-1) * 1.0 + 0.5;
        corrected_target_time = base_target_time + timing_corrections(i);

        % 補正された時刻まで待機
        while (posixtime(datetime('now')) - start_time) < corrected_target_time
            pause(0.001);
        end

        % 音声再生
        if mod(i, 2) == 1
            sound(sound_stim(:,1), fs_stim);
        else
            sound(sound_player(:,1), fs_player);
        end

        actual_times(end+1) = posixtime(datetime('now')) - start_time;
        fprintf('音%d再生: %.3fs (補正%.3fs)\n', i, actual_times(end), timing_corrections(i));
    end

    pause(1);
    stop(recorder);

    % 音響解析
    audio_data = getaudiodata(recorder);
    result = analyze_timing_accuracy(audio_data, 44100, 'タイミング補正', actual_times);
end

function result = analyze_timing_accuracy(audio_data, fs, method_name, software_times)
    % 音響解析で実際の間隔を測定

    % エネルギー解析
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
    threshold = max_energy * 0.15;
    min_interval = 0.2;

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

    % 間隔計算
    acoustic_intervals = [];
    for i = 2:length(detected_events)
        acoustic_intervals(end+1) = detected_events(i) - detected_events(i-1);
    end

    % 結果評価
    fprintf('\n%s結果:\n', method_name);
    fprintf('  検出音数: %d個 (期待4個)\n', length(detected_events));

    if length(acoustic_intervals) >= 3
        mean_interval = mean(acoustic_intervals);
        std_interval = std(acoustic_intervals);
        max_error = max(abs(acoustic_intervals - 1.0));

        fprintf('  平均間隔: %.3fs (期待1.0s)\n', mean_interval);
        fprintf('  標準偏差: %.1fms\n', std_interval * 1000);
        fprintf('  最大誤差: %.1fms\n', max_error * 1000);

        % 評価スコア
        interval_accuracy = 1 - abs(mean_interval - 1.0);
        precision_score = 1 - std_interval;
        total_score = (interval_accuracy + precision_score) / 2;

        fprintf('  精度スコア: %.3f (1.0が完璧)\n', total_score);

        if total_score > 0.95
            fprintf('  ✅ 優秀: 高精度タイミング達成\n');
        elseif total_score > 0.8
            fprintf('  🔶 良好: 実用レベル\n');
        else
            fprintf('  ❌ 不良: 更なる改善必要\n');
        end

        result = struct('method', method_name, 'score', total_score, ...
                       'mean_interval', mean_interval, 'std_interval', std_interval, ...
                       'detected_count', length(detected_events));
    else
        fprintf('  ❌ 分析不可: 検出音数不足\n');
        result = struct('method', method_name, 'score', 0, ...
                       'mean_interval', NaN, 'std_interval', NaN, ...
                       'detected_count', length(detected_events));
    end

    % 詳細間隔表示
    for i = 1:length(acoustic_intervals)
        fprintf('  間隔%d: %.3fs (誤差%+.1fms)\n', i, acoustic_intervals(i), (acoustic_intervals(i) - 1.0)*1000);
    end
end

function compare_all_results(results)
    fprintf('手法比較:\n');
    fprintf('%-20s | スコア | 平均間隔 | 標準偏差 | 検出数\n', '手法');
    fprintf('----------------------------------------------------------\n');

    best_score = 0;
    best_method = '';

    for i = 1:length(results)
        r = results{i};
        if ~isnan(r.mean_interval)
            fprintf('%-20s | %.3f  | %.3fs   | %.1fms   | %d\n', ...
                r.method, r.score, r.mean_interval, r.std_interval*1000, r.detected_count);
        else
            fprintf('%-20s | %.3f  | 分析不可 | 分析不可 | %d\n', ...
                r.method, r.score, r.detected_count);
        end

        if r.score > best_score
            best_score = r.score;
            best_method = r.method;
        end
    end

    fprintf('\n🏆 最優秀手法: %s (スコア%.3f)\n', best_method, best_score);

    if best_score > 0.95
        fprintf('→ この手法をmain_experimentに実装することを推奨\n');
    else
        fprintf('→ 全手法とも不十分。更なる手法検討が必要\n');
    end
end