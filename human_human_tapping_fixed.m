% 人間同士協調交互タッピング（2チャンネル対応版）
% MATLABの制限を回避した実装

function human_human_tapping_fixed()
    fprintf('=== 人間同士協調交互タッピング（修正版）===\n');
    fprintf('2チャンネル×2出力による高精度システム\n\n');

    % 実験システム初期化
    runner = initialize_human_human_system_fixed();

    if runner.initialization_success
        % 実験実行
        run_human_human_experiment_fixed(runner);
    else
        fprintf('システム初期化に失敗しました\n');
    end
end

function runner = initialize_human_human_system_fixed()
    fprintf('--- システム初期化（修正版）---\n');

    runner = struct();
    runner.initialization_success = false;

    try
        % 音声システム初期化（2チャンネル対応）
        runner = setup_audio_system_fixed(runner);

        % キー入力システム初期化
        runner = setup_input_system_fixed(runner);

        % 実験パラメータ設定
        runner = setup_experiment_parameters_fixed(runner);

        % データ収集システム初期化
        runner = setup_data_collection_fixed(runner);

        runner.initialization_success = true;
        fprintf('✅ システム初期化完了\n\n');

    catch ME
        fprintf('❌ 初期化エラー: %s\n', ME.message);
        runner.initialization_success = false;
    end
end

function runner = setup_audio_system_fixed(runner)
    fprintf('音声システムセットアップ（2チャンネル版）...\n');

    % デバイス検出
    devices = audiodevinfo;
    runner.audio_devices = devices;

    fprintf('  利用可能な出力デバイス:\n');
    for i = 1:length(devices.output)
        fprintf('    %d: %s\n', devices.output(i).ID, devices.output(i).Name);
    end

    % 音声ファイル読み込み/生成
    runner = load_audio_files_fixed(runner);

    % 2チャンネル用audioplayerオブジェクト作成
    runner = create_audio_players_fixed(runner);

    fprintf('  音声システム準備完了（2チャンネル×複数player方式）\n');
end

function runner = load_audio_files_fixed(runner)
    runner.fs = 44100; % 44.1kHz（一般的）

    % メトロノーム音
    runner.metro_sound = generate_metronome_sound_fixed(runner.fs);
    fprintf('  メトロノーム音生成 (%.1fs)\n', length(runner.metro_sound)/runner.fs);

    % 刺激音
    stim_path = fullfile(pwd, 'assets', 'sounds', 'stim_beat_optimized.wav');
    if exist(stim_path, 'file')
        [runner.stim_sound, fs_original] = audioread(stim_path);
        if fs_original ~= runner.fs
            runner.stim_sound = resample(runner.stim_sound, runner.fs, fs_original);
        end
        % モノラル変換
        if size(runner.stim_sound, 2) > 1
            runner.stim_sound = mean(runner.stim_sound, 2);
        end
        fprintf('  刺激音読み込み (%.1fs)\n', length(runner.stim_sound)/runner.fs);
    else
        runner.stim_sound = generate_stimulus_sound_fixed(runner.fs);
        fprintf('  刺激音生成 (%.1fs)\n', length(runner.stim_sound)/runner.fs);
    end
end

function runner = create_audio_players_fixed(runner)
    fprintf('  audioplayerオブジェクト作成中...\n');

    % ステレオ変換（左右同じ音）
    metro_stereo = [runner.metro_sound, runner.metro_sound];
    stim_stereo = [runner.stim_sound, runner.stim_sound];

    % 各プレイヤー用audioplayerオブジェクト
    runner.metro_player = audioplayer(metro_stereo, runner.fs);
    runner.stim_player1 = audioplayer(stim_stereo, runner.fs); % Player 1用刺激音
    runner.stim_player2 = audioplayer(stim_stereo, runner.fs); % Player 2用刺激音

    fprintf('    メトロノーム、刺激音×2 のaudioplayerオブジェクト作成完了\n');

    % 音声テスト
    fprintf('  音声テスト実行中...\n');
    try
        play(runner.metro_player);
        pause(0.3);
        stop(runner.metro_player);
        fprintf('    ✅ 音声再生テスト成功\n');
    catch ME
        fprintf('    ⚠️  音声再生テストエラー: %s\n', ME.message);
    end
end

function runner = setup_input_system_fixed(runner)
    fprintf('キー入力システムセットアップ...\n');

    % プログラマブルキー設定
    runner.player1_key = 'q'; % Player 1用キー
    runner.player2_key = 'p'; % Player 2用キー

    % キー状態管理
    runner.key_states = struct();
    runner.key_states.player1_pressed = false;
    runner.key_states.player2_pressed = false;

    fprintf('  キー設定: Player 1=''%s'', Player 2=''%s''\n', ...
        runner.player1_key, runner.player2_key);

    % キー入力テスト
    fprintf('  キー入力テスト（5秒間、任意のキーを押してください）...\n');
    test_start = posixtime(datetime('now'));
    key_detected = false;

    while (posixtime(datetime('now')) - test_start) < 5
        [keyIsDown, ~, keyCode] = KbCheck;
        if keyIsDown
            key_names = KbName(keyCode);
            fprintf('    検出キー: %s\n', key_names);
            key_detected = true;
            break;
        end
        pause(0.01);
    end

    if key_detected
        fprintf('    ✅ キー入力システム動作確認\n');
    else
        fprintf('    ⚠️  キー入力未検出（動作に問題がある可能性）\n');
    end

    fprintf('  キー入力システム準備完了\n');
end

function runner = setup_experiment_parameters_fixed(runner)
    fprintf('実験パラメータ設定...\n');

    % Stage 1: メトロノームフェーズ
    runner.stage1_beats = 10; % 10ビート（短縮版）
    runner.stage1_interval = 1.0; % 1秒間隔

    % Stage 2: 協調フェーズ
    runner.stage2_cycles = 10; % 10サイクル（短縮版）
    runner.stage2_target_interval = 1.0; % 1秒間隔

    % タイミング設定
    runner.clock_start = 0;

    fprintf('  Stage 1: %dビート, %.1fs間隔\n', runner.stage1_beats, runner.stage1_interval);
    fprintf('  Stage 2: %dサイクル, %.1fs間隔\n', runner.stage2_cycles, runner.stage2_target_interval);
    fprintf('  実験パラメータ設定完了\n');
end

function runner = setup_data_collection_fixed(runner)
    fprintf('データ収集システムセットアップ...\n');

    % データ構造初期化
    runner.data = struct();

    % Stage 1データ
    runner.data.stage1_metro_times = [];
    runner.data.stage1_player1_taps = [];
    runner.data.stage1_player2_taps = [];

    % Stage 2データ
    runner.data.stage2_taps = []; % [player_id, tap_time, cycle_number]
    runner.data.stage2_intervals = []; % [from_player, to_player, interval]

    % タイムスタンプ
    runner.data.experiment_start_time = datetime('now');

    fprintf('  データ収集システム準備完了\n');
end

function run_human_human_experiment_fixed(runner)
    fprintf('=== 実験開始 ===\n');

    % 実験説明
    display_experiment_instructions_fixed();

    % Stage 1: メトロノームフェーズ
    fprintf('\n--- Stage 1: メトロノームフェーズ ---\n');
    runner = run_stage1_metronome_fixed(runner);

    % Stage間の休憩
    fprintf('\nStage間休憩（3秒）...\n');
    pause(3);

    % Stage 2: 協調フェーズ
    fprintf('\n--- Stage 2: 協調フェーズ ---\n');
    runner = run_stage2_cooperation_fixed(runner);

    % 結果分析と保存
    analyze_and_save_results_fixed(runner);

    fprintf('\n=== 実験完了 ===\n');
end

function display_experiment_instructions_fixed()
    fprintf('\n=== 実験説明 ===\n');
    fprintf('Stage 1: メトロノーム音に合わせて両プレイヤーがタップ\n');
    fprintf('         Player 1=''q''キー, Player 2=''p''キー\n');
    fprintf('         両プレイヤーに同じメトロノーム音が聞こえます\n');
    fprintf('\nStage 2: 交互タッピング協調フェーズ\n');
    fprintf('         Player 1から開始\n');
    fprintf('         相手がタップすると刺激音が聞こえます\n');
    fprintf('         （注意：現在は同じスピーカーから音が出ます）\n');
    fprintf('\nESCキーで実験中断可能\n');

    input('\n準備ができたらEnterキーを押してください...');
end

function runner = run_stage1_metronome_fixed(runner)
    fprintf('メトロノームフェーズ開始 (%d beats)\n', runner.stage1_beats);

    runner.clock_start = posixtime(datetime('now'));
    beat_count = 0;

    while beat_count < runner.stage1_beats
        % ESCキーチェック
        if check_escape_key_fixed()
            fprintf('実験中断\n');
            return;
        end

        % メトロノーム再生タイミング
        target_time = beat_count * runner.stage1_interval + 0.5; % 0.5秒オフセット
        current_time = posixtime(datetime('now')) - runner.clock_start;

        if current_time >= target_time
            % メトロノーム再生
            try
                if isplaying(runner.metro_player)
                    stop(runner.metro_player);
                end
                play(runner.metro_player);
            catch ME
                fprintf('音声再生エラー: %s\n', ME.message);
            end

            beat_count = beat_count + 1;
            metro_time = posixtime(datetime('now')) - runner.clock_start;
            runner.data.stage1_metro_times(end+1) = metro_time;

            fprintf('♪ %d/%d: %.3fs\n', beat_count, runner.stage1_beats, metro_time);
        end

        % キー入力チェック
        runner = check_key_inputs_stage1_fixed(runner);

        pause(0.001); % 1ms精度
    end

    fprintf('Stage 1完了\n');
end

function runner = check_key_inputs_stage1_fixed(runner)
    [keyIsDown, ~, keyCode] = KbCheck;

    if keyIsDown
        key_names = KbName(keyCode);
        tap_time = posixtime(datetime('now')) - runner.clock_start;

        if contains(key_names, runner.player1_key) && ~runner.key_states.player1_pressed
            runner.data.stage1_player1_taps(end+1) = tap_time;
            runner.key_states.player1_pressed = true;
            fprintf('  → P1: %.3fs\n', tap_time);
        end

        if contains(key_names, runner.player2_key) && ~runner.key_states.player2_pressed
            runner.data.stage1_player2_taps(end+1) = tap_time;
            runner.key_states.player2_pressed = true;
            fprintf('  → P2: %.3fs\n', tap_time);
        end
    else
        % キーリリース状態更新
        runner.key_states.player1_pressed = false;
        runner.key_states.player2_pressed = false;
    end
end

function runner = run_stage2_cooperation_fixed(runner)
    fprintf('協調フェーズ開始 (%d cycles)\n', runner.stage2_cycles);
    fprintf('Player 1 (''q''キー) から開始してください\n');

    cycle_count = 0;
    current_player = 1; % 1: Player 1のターン, 2: Player 2のターン
    last_tap_time = posixtime(datetime('now')) - runner.clock_start;

    while cycle_count < runner.stage2_cycles
        % ESCキーチェック
        if check_escape_key_fixed()
            fprintf('実験中断\n');
            return;
        end

        % キー入力チェック
        [tap_detected, player_id, tap_time] = check_key_inputs_stage2_fixed(runner);

        if tap_detected
            % 正しいプレイヤーのターンかチェック
            if player_id == current_player
                % タップデータ記録
                runner.data.stage2_taps(end+1, :) = [player_id, tap_time, cycle_count + 1];

                % 間隔計算
                if size(runner.data.stage2_taps, 1) > 1
                    interval = tap_time - last_tap_time;
                    runner.data.stage2_intervals(end+1, :) = [player_id, 3-player_id, interval];
                end

                % 相手に刺激音送信
                send_stimulus_to_partner_fixed(runner, player_id);

                fprintf('C%d: P%d → %.3fs (間隔%.3fs)\n', ...
                    cycle_count + 1, player_id, tap_time, ...
                    tap_time - last_tap_time);

                % 次のプレイヤーに交代
                current_player = 3 - current_player; % 1↔2切り替え
                last_tap_time = tap_time;

                % サイクル完了チェック（両プレイヤーがタップ完了）
                if current_player == 1
                    cycle_count = cycle_count + 1;
                    fprintf('  --- サイクル %d 完了 ---\n', cycle_count);
                end
            else
                fprintf('  → Player %dのターンです（''%s''キー）\n', ...
                    current_player, ...
                    iif(current_player == 1, runner.player1_key, runner.player2_key));
            end
        end

        pause(0.001); % 1ms精度
    end

    fprintf('Stage 2完了\n');
end

function [tap_detected, player_id, tap_time] = check_key_inputs_stage2_fixed(runner)
    tap_detected = false;
    player_id = 0;
    tap_time = 0;

    [keyIsDown, ~, keyCode] = KbCheck;

    if keyIsDown
        key_names = KbName(keyCode);
        current_time = posixtime(datetime('now')) - runner.clock_start;

        if contains(key_names, runner.player1_key) && ~runner.key_states.player1_pressed
            tap_detected = true;
            player_id = 1;
            tap_time = current_time;
            runner.key_states.player1_pressed = true;
        elseif contains(key_names, runner.player2_key) && ~runner.key_states.player2_pressed
            tap_detected = true;
            player_id = 2;
            tap_time = current_time;
            runner.key_states.player2_pressed = true;
        end
    else
        % キーリリース状態更新
        runner.key_states.player1_pressed = false;
        runner.key_states.player2_pressed = false;
    end
end

function send_stimulus_to_partner_fixed(runner, tapping_player)
    % 相手のプレイヤーに刺激音送信（簡易版）

    try
        if tapping_player == 1
            % Player 1がタップ → Player 2への刺激音
            if isplaying(runner.stim_player2)
                stop(runner.stim_player2);
            end
            play(runner.stim_player2);
        else
            % Player 2がタップ → Player 1への刺激音
            if isplaying(runner.stim_player1)
                stop(runner.stim_player1);
            end
            play(runner.stim_player1);
        end
    catch ME
        fprintf('刺激音再生エラー: %s\n', ME.message);
    end
end

function escape_pressed = check_escape_key_fixed()
    [keyIsDown, ~, keyCode] = KbCheck;
    escape_pressed = keyIsDown && any(strcmp(KbName(keyCode), 'ESCAPE'));
end

function analyze_and_save_results_fixed(runner)
    fprintf('\n=== 実験結果分析 ===\n');

    % Stage 1分析
    analyze_stage1_results_fixed(runner);

    % Stage 2分析
    analyze_stage2_results_fixed(runner);

    % データ保存
    save_experiment_data_fixed(runner);
end

function analyze_stage1_results_fixed(runner)
    fprintf('\nStage 1 結果:\n');

    % Player 1分析
    if length(runner.data.stage1_player1_taps) >= 2
        p1_intervals = diff(runner.data.stage1_player1_taps);
        fprintf('  Player 1: %d taps, 平均間隔 %.3fs, 標準偏差 %.1fms\n', ...
            length(runner.data.stage1_player1_taps), mean(p1_intervals), std(p1_intervals)*1000);
    else
        fprintf('  Player 1: %d taps （分析不可）\n', length(runner.data.stage1_player1_taps));
    end

    % Player 2分析
    if length(runner.data.stage1_player2_taps) >= 2
        p2_intervals = diff(runner.data.stage1_player2_taps);
        fprintf('  Player 2: %d taps, 平均間隔 %.3fs, 標準偏差 %.1fms\n', ...
            length(runner.data.stage1_player2_taps), mean(p2_intervals), std(p2_intervals)*1000);
    else
        fprintf('  Player 2: %d taps （分析不可）\n', length(runner.data.stage1_player2_taps));
    end
end

function analyze_stage2_results_fixed(runner)
    fprintf('\nStage 2 結果:\n');

    if size(runner.data.stage2_taps, 1) >= 2
        fprintf('  総タップ数: %d\n', size(runner.data.stage2_taps, 1));

        % 間隔分析
        if ~isempty(runner.data.stage2_intervals)
            intervals = runner.data.stage2_intervals(:, 3);
            fprintf('  平均間隔: %.3fs (目標1.0s)\n', mean(intervals));
            fprintf('  標準偏差: %.1fms\n', std(intervals)*1000);
            fprintf('  協調精度: %.1f%%\n', max(0, (1 - std(intervals)/mean(intervals)) * 100));
        end

        % プレイヤー別分析
        player1_taps = sum(runner.data.stage2_taps(:, 1) == 1);
        player2_taps = sum(runner.data.stage2_taps(:, 1) == 2);
        fprintf('  Player 1 taps: %d\n', player1_taps);
        fprintf('  Player 2 taps: %d\n', player2_taps);

        % 交互性チェック
        if abs(player1_taps - player2_taps) <= 1
            fprintf('  ✅ 適切な交互タッピング\n');
        else
            fprintf('  ⚠️  交互タッピングに不均衡\n');
        end
    else
        fprintf('  データ不足（分析不可）\n');
    end
end

function save_experiment_data_fixed(runner)
    % 実験データ保存
    timestamp = datestr(runner.data.experiment_start_time, 'yyyymmdd_HHMMSS');
    filename = sprintf('human_human_experiment_%s.mat', timestamp);

    save(filename, 'runner');
    fprintf('\n💾 実験データ保存: %s\n', filename);
end

% ヘルパー関数
function metro_sound = generate_metronome_sound_fixed(fs)
    duration = 0.15; % 150ms
    t = 0:1/fs:duration-1/fs;

    % エンベロープ付きクリック音
    envelope = exp(-t*15); % 適度な減衰
    metro_sound = 0.4 * envelope' .* sin(2*pi*800*t)';
end

function stim_sound = generate_stimulus_sound_fixed(fs)
    duration = 0.2; % 200ms
    t = 0:1/fs:duration-1/fs;

    % エンベロープ付き高音ビープ
    envelope = exp(-t*8); % 緩やかな減衰
    stim_sound = 0.5 * envelope' .* sin(2*pi*1200*t)';
end

function result = iif(condition, true_val, false_val)
    if condition
        result = true_val;
    else
        result = false_val;
    end
end