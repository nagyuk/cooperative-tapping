% 音1と音2の結合問題を解決するテスト

function audio_separation_test()
    fprintf('=== 音響分離問題解決テスト ===\n');

    % 音声ファイル読み込み
    stim_sound_path = fullfile(pwd, 'assets', 'sounds', 'stim_beat_optimized.wav');
    player_sound_path = fullfile(pwd, 'assets', 'sounds', 'player_beat_optimized.wav');

    [sound_stim, fs_stim] = audioread(stim_sound_path);
    [sound_player, fs_player] = audioread(player_sound_path);

    fprintf('音声ファイル解析:\n');
    fprintf('  刺激音長さ: %.3fs (%.0fサンプル)\n', length(sound_stim)/fs_stim, length(sound_stim));
    fprintf('  プレイヤー音長さ: %.3fs (%.0fサンプル)\n', length(sound_player)/fs_player, length(sound_player));

    % 解決策1: 強制停止による分離
    test_forced_stop_separation(sound_stim, fs_stim, sound_player, fs_player);

    % 解決策2: 待機時間追加による分離
    test_wait_based_separation(sound_stim, fs_stim, sound_player, fs_player);
end

function test_forced_stop_separation(sound_stim, fs_stim, sound_player, fs_player)
    fprintf('\n--- 解決策1: 強制停止による分離テスト ---\n');

    % audioplayerオブジェクト作成
    player1 = audioplayer(sound_stim(:,1), fs_stim);
    player2 = audioplayer(sound_player(:,1), fs_player);

    % 録音設定
    recorder = audiorecorder(44100, 16, 1);

    fprintf('5秒間のテスト録音開始...\n');
    record(recorder);

    start_time = posixtime(datetime('now'));

    % 音1再生
    fprintf('音1再生開始 (0.5s)\n');
    while (posixtime(datetime('now')) - start_time) < 0.5
        pause(0.001);
    end
    play(player1);

    % 音1強制停止 + 音2再生
    fprintf('音1停止 + 音2再生開始 (1.5s)\n');
    while (posixtime(datetime('now')) - start_time) < 1.5
        pause(0.001);
    end
    stop(player1); % 強制停止
    pause(0.01);   % 短い待機
    play(player2);

    % 終了待機
    pause(2.0);
    stop(recorder);

    % 音響解析
    audio_data = getaudiodata(recorder);
    analyze_separation_result(audio_data, 44100, '強制停止方式');
end

function test_wait_based_separation(sound_stim, fs_stim, sound_player, fs_player)
    fprintf('\n--- 解決策2: 待機時間追加による分離テスト ---\n');

    % audioplayerオブジェクト作成
    player1 = audioplayer(sound_stim(:,1), fs_stim);
    player2 = audioplayer(sound_player(:,1), fs_player);

    % 録音設定
    recorder = audiorecorder(44100, 16, 1);

    fprintf('5秒間のテスト録音開始...\n');
    record(recorder);

    start_time = posixtime(datetime('now'));

    % 音1再生
    fprintf('音1再生開始 (0.5s)\n');
    while (posixtime(datetime('now')) - start_time) < 0.5
        pause(0.001);
    end
    play(player1);

    % 音1完全終了待機 + 音2再生
    sound1_duration = length(sound_stim) / fs_stim;
    wait_time = 1.5 + sound1_duration + 0.1; % 音1長さ + 余裕100ms

    fprintf('音1完全終了待機 + 音2再生開始 (%.3fs)\n', wait_time);
    while (posixtime(datetime('now')) - start_time) < wait_time
        pause(0.001);
    end
    play(player2);

    % 終了待機
    pause(2.0);
    stop(recorder);

    % 音響解析
    audio_data = getaudiodata(recorder);
    analyze_separation_result(audio_data, 44100, '待機時間追加方式');
end

function analyze_separation_result(audio_data, fs, method_name)
    fprintf('\n%s の結果:\n', method_name);

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

    % ピーク検出
    max_energy = max(energy);
    threshold = max_energy * 0.15;
    min_interval = 0.3; % より短い間隔で検出

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
                fprintf('  検出: %.3fs地点\n', time_axis(i));
            end
        end
    end

    fprintf('  検出数: %d個\n', length(detected_events));

    if length(detected_events) == 2
        interval = detected_events(2) - detected_events(1);
        fprintf('  ✅ 2音分離成功！間隔: %.3fs\n', interval);
    elseif length(detected_events) == 1
        fprintf('  ❌ 結合継続（1音として検出）\n');
    else
        fprintf('  ⚠️  予期しない検出数\n');
    end
end