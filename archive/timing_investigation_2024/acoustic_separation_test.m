% 実音響測定による音響分離テスト
% 内部時計ではなく実際の音響結果のみで判定

function acoustic_separation_test()
    fprintf('=== 実音響分離テスト ===\n');
    fprintf('内部時計無視、音響測定のみで判定\n\n');

    % 現在の音声ファイルで音響測定
    fprintf('--- 現在の音声ファイル（0.3秒）でのテスト ---\n');
    test_acoustic_separation('optimized');

    % さらに短い音声ファイルを作成してテスト
    fprintf('\n--- より短い音声ファイル（0.15秒）を作成してテスト ---\n');
    create_ultra_short_audio();
    test_acoustic_separation('ultra_short');

    % 最短音声ファイルを作成してテスト
    fprintf('\n--- 最短音声ファイル（0.1秒）を作成してテスト ---\n');
    create_minimal_audio();
    test_acoustic_separation('minimal');
end

function create_ultra_short_audio()
    % 0.15秒の音声ファイル作成
    stim_path = fullfile(pwd, 'assets', 'sounds', 'stim_beat_optimized.wav');
    player_path = fullfile(pwd, 'assets', 'sounds', 'player_beat_optimized.wav');

    [sound_stim, fs_stim] = audioread(stim_path);
    [sound_player, fs_player] = audioread(player_path);

    % 0.15秒にカット
    target_samples = round(0.15 * fs_stim);
    sound_stim_ultra = sound_stim(1:min(target_samples, length(sound_stim)), :);
    sound_player_ultra = sound_player(1:min(target_samples, length(sound_player)), :);

    % フェードアウト
    fade_samples = round(0.005 * fs_stim);
    if length(sound_stim_ultra) > fade_samples
        fade_curve = linspace(1, 0, fade_samples)';
        sound_stim_ultra(end-fade_samples+1:end, :) = sound_stim_ultra(end-fade_samples+1:end, :) .* fade_curve;
        sound_player_ultra(end-fade_samples+1:end, :) = sound_player_ultra(end-fade_samples+1:end, :) .* fade_curve;
    end

    % 保存
    audiowrite(fullfile(pwd, 'assets', 'sounds', 'stim_beat_ultra_short.wav'), sound_stim_ultra, fs_stim);
    audiowrite(fullfile(pwd, 'assets', 'sounds', 'player_beat_ultra_short.wav'), sound_player_ultra, fs_player);

    fprintf('0.15秒音声ファイル作成完了\n');
end

function create_minimal_audio()
    % 0.1秒の音声ファイル作成
    stim_path = fullfile(pwd, 'assets', 'sounds', 'stim_beat_optimized.wav');
    player_path = fullfile(pwd, 'assets', 'sounds', 'player_beat_optimized.wav');

    [sound_stim, fs_stim] = audioread(stim_path);
    [sound_player, fs_player] = audioread(player_path);

    % 0.1秒にカット
    target_samples = round(0.1 * fs_stim);
    sound_stim_minimal = sound_stim(1:min(target_samples, length(sound_stim)), :);
    sound_player_minimal = sound_player(1:min(target_samples, length(sound_player)), :);

    % フェードアウト
    fade_samples = round(0.005 * fs_stim);
    if length(sound_stim_minimal) > fade_samples
        fade_curve = linspace(1, 0, fade_samples)';
        sound_stim_minimal(end-fade_samples+1:end, :) = sound_stim_minimal(end-fade_samples+1:end, :) .* fade_curve;
        sound_player_minimal(end-fade_samples+1:end, :) = sound_player_minimal(end-fade_samples+1:end, :) .* fade_curve;
    end

    % 保存
    audiowrite(fullfile(pwd, 'assets', 'sounds', 'stim_beat_minimal.wav'), sound_stim_minimal, fs_stim);
    audiowrite(fullfile(pwd, 'assets', 'sounds', 'player_beat_minimal.wav'), sound_player_minimal, fs_player);

    fprintf('0.1秒音声ファイル作成完了\n');
end

function test_acoustic_separation(audio_type)
    fprintf('\n%s音声での実音響測定...\n', audio_type);

    % 音声ファイル選択
    if strcmp(audio_type, 'optimized')
        stim_path = fullfile(pwd, 'assets', 'sounds', 'stim_beat_optimized.wav');
        player_path = fullfile(pwd, 'assets', 'sounds', 'player_beat_optimized.wav');
    elseif strcmp(audio_type, 'ultra_short')
        stim_path = fullfile(pwd, 'assets', 'sounds', 'stim_beat_ultra_short.wav');
        player_path = fullfile(pwd, 'assets', 'sounds', 'player_beat_ultra_short.wav');
    elseif strcmp(audio_type, 'minimal')
        stim_path = fullfile(pwd, 'assets', 'sounds', 'stim_beat_minimal.wav');
        player_path = fullfile(pwd, 'assets', 'sounds', 'player_beat_minimal.wav');
    end

    [sound_stim, fs_stim] = audioread(stim_path);
    [sound_player, fs_player] = audioread(player_path);

    fprintf('音声長さ: 刺激音%.3fs, プレイヤー音%.3fs\n', ...
        length(sound_stim)/fs_stim, length(sound_player)/fs_player);

    % 録音設定
    recorder = audiorecorder(44100, 16, 1);

    fprintf('6秒間の録音・再生開始...\n');
    for i = 3:-1:1
        fprintf('%d...\n', i);
        pause(1);
    end

    record(recorder);
    start_time = posixtime(datetime('now'));

    % 4音だけテスト（音1,2,3,4）
    for sound_index = 1:4
        target_time = (sound_index - 1) * 1.0 + 0.5;

        while (posixtime(datetime('now')) - start_time) < target_time
            pause(0.001);
        end

        if mod(sound_index, 2) == 1
            sound(sound_stim(:,1), fs_stim);
            fprintf('音%d: 刺激音再生\n', sound_index);
        else
            sound(sound_player(:,1), fs_player);
            fprintf('音%d: プレイヤー音再生\n', sound_index);
        end
    end

    pause(1.5);
    stop(recorder);

    % 音響解析（分離判定のみ）
    audio_data = getaudiodata(recorder);
    separation_result = analyze_separation_only(audio_data, 44100, audio_type);
end

function result = analyze_separation_only(audio_data, fs, audio_type)
    % 音響分離の成功/失敗のみを判定

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
    threshold = max_energy * 0.15; % 緩い閾値
    min_interval = 0.3; % 短い最小間隔

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

    detected_count = length(detected_events);
    expected_count = 4; % 音1,2,3,4

    fprintf('%s音響分離結果:\n', audio_type);
    fprintf('  検出数: %d個 (期待4個)\n', detected_count);

    if detected_count == expected_count
        fprintf('  ✅ 完全分離成功！\n');
        result = 'success';
    elseif detected_count == (expected_count - 1)
        fprintf('  ❌ 音1-2結合継続\n');
        result = 'combined';
    elseif detected_count > expected_count
        fprintf('  ⚠️  過剰検出（ノイズ混入）\n');
        result = 'noise';
    else
        fprintf('  ❌ 検出不足\n');
        result = 'insufficient';
    end

    % 検出時刻表示
    for i = 1:length(detected_events)
        fprintf('  検出%d: %.3fs\n', i, detected_events(i));
    end

    result = result;
end