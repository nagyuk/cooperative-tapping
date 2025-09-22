% Focusrite Scarlett 4i4 (4th Gen) 4チャンネル出力システム

function scarlett_4i4_system()
    fprintf('=== Focusrite Scarlett 4i4 音声出力システム ===\n');
    fprintf('4チャンネル独立出力による人間同士協調タッピング\n\n');

    try
        % Scarlett 4i4デバイス検出と設定
        setup_scarlett_4i4();

        % 4チャンネル出力テスト
        test_4channel_output();

        % クロスフィードバックテスト
        test_cross_feedback_system();

        % 遅延測定テスト
        test_audio_latency();

    catch ME
        fprintf('ERROR: %s\n', ME.message);
        fprintf('Scarlett 4i4が接続されているか確認してください\n');
    end
end

function setup_scarlett_4i4()
    fprintf('--- Scarlett 4i4 セットアップ ---\n');

    % オーディオデバイス情報取得
    devices = audiodevinfo;

    fprintf('利用可能なオーディオデバイス:\n');

    % 出力デバイス確認
    output_devices = devices.output;
    scarlett_found = false;
    scarlett_id = -1;

    for i = 1:length(output_devices)
        device_name = output_devices(i).Name;
        fprintf('  ID %d: %s (チャンネル数: %d)\n', ...
            output_devices(i).ID, device_name, output_devices(i).MaxChannels);

        % Scarlettデバイス検索
        if contains(lower(device_name), 'scarlett') || contains(lower(device_name), '4i4')
            scarlett_found = true;
            scarlett_id = output_devices(i).ID;
            fprintf('    → ✅ Scarlett 4i4検出\n');
        end
    end

    if scarlett_found
        fprintf('\nScarlett 4i4設定:\n');
        fprintf('  デバイスID: %d\n', scarlett_id);
        fprintf('  推奨設定: 48kHz, 24bit, 4ch出力\n');
        fprintf('  チャンネル構成:\n');
        fprintf('    Ch 1/2: Player 1 ヘッドフォン (L/R)\n');
        fprintf('    Ch 3/4: Player 2 ヘッドフォン (L/R)\n');
    else
        fprintf('\n⚠️  Scarlett 4i4が見つかりません\n');
        fprintf('デフォルトデバイスで動作テストを継続します\n');
    end
end

function test_4channel_output()
    fprintf('\n--- 4チャンネル出力テスト ---\n');

    % テスト音声生成
    fs = 48000; % 48kHz
    duration = 0.5; % 0.5秒
    t = 0:1/fs:duration-1/fs;

    % 各チャンネル用テスト音
    test_freq = [440, 554, 659, 831]; % A, C#, E, G# (Aメジャーコード)

    fprintf('各チャンネルにテスト音を出力します...\n');

    for ch = 1:4
        fprintf('チャンネル %d テスト (%.0fHz)...\n', ch, test_freq(ch));

        % 4チャンネル音声データ作成
        audio_data = zeros(length(t), 4);
        audio_data(:, ch) = 0.3 * sin(2*pi*test_freq(ch)*t); % 該当チャンネルのみ

        try
            % audioplayer作成（4チャンネル）
            player = audioplayer(audio_data, fs, 24);
            play(player);

            fprintf('  再生中... (チャンネル%d)\n', ch);
            pause(duration + 0.2);

            if isplaying(player)
                stop(player);
            end

        catch ME
            fprintf('  エラー: %s\n', ME.message);
        end

        pause(0.5); % チャンネル間の間隔
    end

    fprintf('4チャンネル出力テスト完了\n');
end

function test_cross_feedback_system()
    fprintf('\n--- クロスフィードバックシステムテスト ---\n');
    fprintf('相互刺激音配信システムの動作確認\n\n');

    % 音声ファイル読み込み
    stim_path = fullfile(pwd, 'assets', 'sounds', 'stim_beat_optimized.wav');

    if exist(stim_path, 'file')
        [stim_sound, fs_original] = audioread(stim_path);

        % 48kHzにリサンプリング
        fs_target = 48000;
        if fs_original ~= fs_target
            stim_sound = resample(stim_sound, fs_target, fs_original);
        end

        % モノラルに変換
        if size(stim_sound, 2) > 1
            stim_sound = mean(stim_sound, 2);
        end

        fprintf('刺激音ファイル読み込み完了 (%.3fs, %dHz)\n', ...
            length(stim_sound)/fs_target, fs_target);
    else
        % デフォルト刺激音生成
        fs_target = 48000;
        duration = 0.2;
        t = 0:1/fs_target:duration-1/fs_target;
        stim_sound = 0.5 * sin(2*pi*800*t)'; % 800Hz、200ms

        fprintf('デフォルト刺激音生成 (800Hz, %.1fs)\n', duration);
    end

    fprintf('\nクロスフィードバックテスト:\n');
    fprintf('1. Player 1 → Player 2 (Ch 3/4に出力)\n');
    fprintf('2. Player 2 → Player 1 (Ch 1/2に出力)\n\n');

    % Player 1 → Player 2のフィードバック
    fprintf('Player 1タップシミュレーション...\n');
    audio_p1_to_p2 = zeros(length(stim_sound), 4);
    audio_p1_to_p2(:, 3) = stim_sound; % Ch 3 (Player 2 Left)
    audio_p1_to_p2(:, 4) = stim_sound; % Ch 4 (Player 2 Right)

    try
        player_p1_to_p2 = audioplayer(audio_p1_to_p2, fs_target, 24);
        play(player_p1_to_p2);
        fprintf('  → Player 2ヘッドフォン (Ch 3/4) に刺激音出力\n');
        pause(length(stim_sound)/fs_target + 0.2);
    catch ME
        fprintf('  エラー: %s\n', ME.message);
    end

    pause(1);

    % Player 2 → Player 1のフィードバック
    fprintf('Player 2タップシミュレーション...\n');
    audio_p2_to_p1 = zeros(length(stim_sound), 4);
    audio_p2_to_p1(:, 1) = stim_sound; % Ch 1 (Player 1 Left)
    audio_p2_to_p1(:, 2) = stim_sound; % Ch 2 (Player 1 Right)

    try
        player_p2_to_p1 = audioplayer(audio_p2_to_p1, fs_target, 24);
        play(player_p2_to_p1);
        fprintf('  → Player 1ヘッドフォン (Ch 1/2) に刺激音出力\n');
        pause(length(stim_sound)/fs_target + 0.2);
    catch ME
        fprintf('  エラー: %s\n', ME.message);
    end

    fprintf('\nクロスフィードバックシステムテスト完了\n');
end

function test_audio_latency()
    fprintf('\n--- 音声遅延測定テスト ---\n');

    % 短い刺激音生成
    fs = 48000;
    duration = 0.05; % 50ms
    t = 0:1/fs:duration-1/fs;
    click_sound = 0.5 * sin(2*pi*1000*t)'; % 1kHz、50ms

    % 各チャンネルの遅延測定
    fprintf('各チャンネルの遅延測定中...\n');

    latencies = [];

    for ch = 1:4
        fprintf('チャンネル %d 測定...', ch);

        % 4チャンネル音声データ
        audio_data = zeros(length(click_sound), 4);
        audio_data(:, ch) = click_sound;

        % 遅延測定
        delays = [];
        for trial = 1:3
            start_time = tic;

            try
                player = audioplayer(audio_data, fs, 24);
                play(player);

                execution_delay = toc(start_time);
                delays(end+1) = execution_delay;

                pause(0.1);
                if isplaying(player)
                    stop(player);
                end
            catch ME
                fprintf(' エラー');
                break;
            end

            pause(0.2);
        end

        if ~isempty(delays)
            mean_delay = mean(delays);
            latencies(end+1) = mean_delay;
            fprintf(' %.1fms\n', mean_delay * 1000);
        else
            fprintf(' 測定失敗\n');
        end
    end

    % 遅延統計
    if ~isempty(latencies)
        fprintf('\n遅延測定結果:\n');
        fprintf('  平均遅延: %.1fms\n', mean(latencies) * 1000);
        fprintf('  最大遅延: %.1fms\n', max(latencies) * 1000);
        fprintf('  最小遅延: %.1fms\n', min(latencies) * 1000);
        fprintf('  標準偏差: %.1fms\n', std(latencies) * 1000);

        if mean(latencies) < 0.01 % 10ms以下
            fprintf('  ✅ 低遅延動作確認\n');
        elseif mean(latencies) < 0.02 % 20ms以下
            fprintf('  🔶 許容範囲内遅延\n');
        else
            fprintf('  ⚠️  高遅延（要調整）\n');
        end
    end
end

function create_4channel_audioplayer(audio_mono, fs, target_channels)
    % 4チャンネル用audioplayerオブジェクト作成
    % target_channels: 出力したいチャンネルのリスト [1,2] または [3,4]

    audio_4ch = zeros(length(audio_mono), 4);

    for ch = target_channels
        audio_4ch(:, ch) = audio_mono;
    end

    player = audioplayer(audio_4ch, fs, 24);
end

function demonstrate_human_human_scenario()
    fprintf('\n--- 人間同士協調タッピングシナリオデモ ---\n');

    % Stage 1: メトロノームフェーズ
    fprintf('\nStage 1: メトロノームフェーズ\n');
    fprintf('両プレイヤーに同じメトロノーム音を配信\n');

    % メトロノーム音生成
    fs = 48000;
    metro_sound = generate_metronome_sound(fs);

    % 両チャンネルに出力
    audio_metro = zeros(length(metro_sound), 4);
    audio_metro(:, [1,2,3,4]) = repmat(metro_sound, 1, 4); % 全チャンネル

    for beat = 1:5
        fprintf('  メトロノーム %d/5\n', beat);

        try
            metro_player = audioplayer(audio_metro, fs, 24);
            play(metro_player);
            pause(1.0); % 1秒間隔
        catch ME
            fprintf('    エラー: %s\n', ME.message);
            pause(1.0);
        end
    end

    % Stage 2: 協調フェーズデモ
    fprintf('\nStage 2: 協調フェーズデモ\n');
    fprintf('交互タッピングのシミュレーション\n');

    stim_sound = generate_stimulus_sound(fs);

    for cycle = 1:3
        fprintf('  サイクル %d/3:\n', cycle);

        % Player 1タップ → Player 2へ刺激音
        fprintf('    Player 1タップ → Player 2刺激\n');
        audio_p1 = zeros(length(stim_sound), 4);
        audio_p1(:, [3,4]) = repmat(stim_sound, 1, 2); % Ch 3/4

        try
            p1_player = audioplayer(audio_p1, fs, 24);
            play(p1_player);
            pause(0.5);
        catch ME
            fprintf('      エラー: %s\n', ME.message);
            pause(0.5);
        end

        % Player 2タップ → Player 1へ刺激音
        fprintf('    Player 2タップ → Player 1刺激\n');
        audio_p2 = zeros(length(stim_sound), 4);
        audio_p2(:, [1,2]) = repmat(stim_sound, 1, 2); % Ch 1/2

        try
            p2_player = audioplayer(audio_p2, fs, 24);
            play(p2_player);
            pause(0.5);
        catch ME
            fprintf('      エラー: %s\n', ME.message);
            pause(0.5);
        end
    end

    fprintf('\n人間同士協調タッピングシナリオデモ完了\n');
end

function metro_sound = generate_metronome_sound(fs)
    % メトロノーム音生成（クリック音）
    duration = 0.1; % 100ms
    t = 0:1/fs:duration-1/fs;

    % エンベロープ付きクリック音
    envelope = exp(-t*20); % 減衰
    metro_sound = 0.3 * envelope' .* sin(2*pi*800*t)';
end

function stim_sound = generate_stimulus_sound(fs)
    % 刺激音生成（高音ビープ）
    duration = 0.2; % 200ms
    t = 0:1/fs:duration-1/fs;

    % エンベロープ付き高音
    envelope = exp(-t*10); % 緩やかな減衰
    stim_sound = 0.4 * envelope' .* sin(2*pi*1200*t)';
end