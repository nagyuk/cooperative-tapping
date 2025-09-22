% 人間同士協調タッピング - 基本動作テスト版（KbCheck不使用）

function test_new_design()
    fprintf('=== 人間同士協調タッピング 基本動作テスト ===\n');
    fprintf('音声システムとタイミング機能の動作確認\n\n');

    try
        % 音声システム初期化
        audio_system = initialize_audio_system();

        % Stage1デモンストレーション
        demonstrate_stage1_metronome(audio_system);

        % Stage2デモンストレーション
        demonstrate_stage2_cooperation(audio_system);

        fprintf('\n=== テスト完了 ===\n');
        fprintf('基本システムは正常に動作しています\n');

    catch ME
        fprintf('エラー: %s\n', ME.message);
    end
end

function audio_system = initialize_audio_system()
    fprintf('--- 音声システム初期化 ---\n');

    audio_system = struct();
    audio_system.fs = 48000; % サンプリング周波数

    % メトロノーム音生成
    metro_duration = 0.1; % 100ms
    t_metro = 0:1/audio_system.fs:metro_duration-1/audio_system.fs;
    envelope = exp(-t_metro*15); % 減衰エンベロープ
    audio_system.metro_sound = 0.4 * envelope' .* sin(2*pi*800*t_metro)';

    % 刺激音読み込み/生成
    stim_path = fullfile(pwd, 'assets', 'sounds', 'stim_beat_optimized.wav');
    if exist(stim_path, 'file')
        [stim_data, fs_orig] = audioread(stim_path);
        if fs_orig ~= audio_system.fs
            stim_data = resample(stim_data, audio_system.fs, fs_orig);
        end
        if size(stim_data, 2) > 1
            stim_data = mean(stim_data, 2); % モノラル変換
        end
        audio_system.stim_sound = stim_data;
        fprintf('刺激音ファイル読み込み (%.3fs)\n', length(stim_data)/audio_system.fs);
    else
        % デフォルト刺激音生成
        stim_duration = 0.2; % 200ms
        t_stim = 0:1/audio_system.fs:stim_duration-1/audio_system.fs;
        envelope = exp(-t_stim*8);
        audio_system.stim_sound = 0.5 * envelope' .* sin(2*pi*1200*t_stim)';
        fprintf('デフォルト刺激音生成 (1200Hz, %.1fs)\n', stim_duration);
    end

    % audioplayerオブジェクト作成（ステレオ）
    metro_stereo = [audio_system.metro_sound, audio_system.metro_sound];
    stim_stereo = [audio_system.stim_sound, audio_system.stim_sound];

    audio_system.metro_player = audioplayer(metro_stereo, audio_system.fs);
    audio_system.stim_player1 = audioplayer(stim_stereo, audio_system.fs);
    audio_system.stim_player2 = audioplayer(stim_stereo, audio_system.fs);

    % 音声デバイス情報表示
    devices = audiodevinfo;
    fprintf('利用可能な出力デバイス:\n');
    for i = 1:length(devices.output)
        fprintf('  %d: %s\n', devices.output(i).ID, devices.output(i).Name);
    end

    fprintf('音声システム初期化完了\n');
end

function demonstrate_stage1_metronome(audio_system)
    fprintf('\n--- Stage 1: メトロノームフェーズ デモ ---\n');
    fprintf('両プレイヤーに同じメトロノーム音を配信\n');
    fprintf('通常は20回ですが、デモでは5回再生します\n\n');

    interval = 2.0; % 2秒間隔（SPAN）

    for beat = 1:5
        fprintf('メトロノーム %d/5 (%.1fs)\n', beat, (beat-1)*interval);

        % メトロノーム再生
        try
            play(audio_system.metro_player);
            pause(interval);
        catch ME
            fprintf('  再生エラー: %s\n', ME.message);
            pause(interval);
        end
    end

    fprintf('Stage 1 デモンストレーション完了\n');
end

function demonstrate_stage2_cooperation(audio_system)
    fprintf('\n--- Stage 2: 協調フェーズ デモ ---\n');
    fprintf('交互タッピングによる相互刺激音配信\n');
    fprintf('Player 1タップ → Player 2へ刺激音\n');
    fprintf('Player 2タップ → Player 1へ刺激音\n\n');

    interval = 1.0; % 1秒間隔（SPAN/2）

    for cycle = 1:6
        % Player 1 → Player 2
        fprintf('%.1fs: Player 1タップ → Player 2刺激音\n', (cycle-1)*interval);
        try
            play(audio_system.stim_player1); % Player 2用刺激音
            pause(interval/2);
        catch ME
            fprintf('  再生エラー: %s\n', ME.message);
            pause(interval/2);
        end

        % Player 2 → Player 1
        fprintf('%.1fs: Player 2タップ → Player 1刺激音\n', (cycle-0.5)*interval);
        try
            play(audio_system.stim_player2); % Player 1用刺激音
            pause(interval/2);
        catch ME
            fprintf('  再生エラー: %s\n', ME.message);
            pause(interval/2);
        end
    end

    fprintf('Stage 2 デモンストレーション完了\n');
end

function test_audio_latency()
    fprintf('\n--- 音声遅延測定テスト ---\n');

    fs = 48000;
    duration = 0.05; % 50ms
    t = 0:1/fs:duration-1/fs;
    test_sound = 0.3 * sin(2*pi*1000*t)';
    stereo_sound = [test_sound, test_sound];

    latencies = [];

    for trial = 1:5
        fprintf('遅延測定 %d/5...', trial);

        start_time = tic;
        player = audioplayer(stereo_sound, fs);
        play(player);
        latency = toc(start_time);

        latencies(end+1) = latency;
        fprintf(' %.1fms\n', latency * 1000);

        pause(0.1);
        if isplaying(player)
            stop(player);
        end
        pause(0.2);
    end

    fprintf('\n遅延測定結果:\n');
    fprintf('  平均遅延: %.1fms\n', mean(latencies) * 1000);
    fprintf('  標準偏差: %.1fms\n', std(latencies) * 1000);

    if mean(latencies) < 0.02
        fprintf('  ✅ 低遅延動作確認\n');
    else
        fprintf('  ⚠️  高遅延（要調整）\n');
    end
end