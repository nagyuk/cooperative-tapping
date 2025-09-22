% 人間同士協調交互タッピング プロトタイプシステム
% プログラマブルキー + Scarlett 4i4による完全実装

function human_human_tapping_prototype()
    fprintf('=== 人間同士協調交互タッピング プロトタイプ ===\n');
    fprintf('400-SKB075 × 2 + Scarlett 4i4による高精度システム\n\n');

    % 実験システム初期化
    runner = initialize_human_human_system();

    if runner.initialization_success
        % 実験実行
        run_human_human_experiment(runner);
    else
        fprintf('システム初期化に失敗しました\n');
    end
end

function runner = initialize_human_human_system()
    fprintf('--- システム初期化 ---\n');

    runner = struct();
    runner.initialization_success = false;

    try
        % 音声システム初期化
        runner = setup_audio_system(runner);

        % キー入力システム初期化
        runner = setup_input_system(runner);

        % 実験パラメータ設定
        runner = setup_experiment_parameters(runner);

        % データ収集システム初期化
        runner = setup_data_collection(runner);

        runner.initialization_success = true;
        fprintf('✅ システム初期化完了\n\n');

    catch ME
        fprintf('❌ 初期化エラー: %s\n', ME.message);
        runner.initialization_success = false;
    end
end

function runner = setup_audio_system(runner)
    fprintf('音声システムセットアップ...\n');

    % Scarlett 4i4デバイス検出
    devices = audiodevinfo;
    runner.scarlett_detected = false;
    runner.scarlett_device_id = -1;

    for i = 1:length(devices.output)
        device_name = devices.output(i).Name;
        if contains(lower(device_name), 'scarlett') || contains(lower(device_name), '4i4')
            runner.scarlett_detected = true;
            runner.scarlett_device_id = devices.output(i).ID;
            fprintf('  Scarlett 4i4検出: %s\n', device_name);
            break;
        end
    end

    if ~runner.scarlett_detected
        fprintf('  ⚠️  Scarlett 4i4未検出、デフォルトデバイス使用\n');
    end

    % 音声ファイル読み込み/生成
    runner = load_audio_files(runner);

    % 4チャンネル出力用audioplayerオブジェクト事前作成
    runner = create_audio_players(runner);

    fprintf('  音声システム準備完了\n');
end

function runner = load_audio_files(runner)
    % 音声ファイル読み込みまたは生成

    runner.fs = 48000; % 48kHz統一

    % メトロノーム音
    metro_path = fullfile(pwd, 'assets', 'sounds', 'metro_beat.wav');
    if exist(metro_path, 'file')
        [runner.metro_sound, fs_original] = audioread(metro_path);
        if fs_original ~= runner.fs
            runner.metro_sound = resample(runner.metro_sound, runner.fs, fs_original);
        end
    else
        runner.metro_sound = generate_metronome_sound(runner.fs);
        fprintf('  メトロノーム音生成\n');
    end

    % 刺激音
    stim_path = fullfile(pwd, 'assets', 'sounds', 'stim_beat_optimized.wav');
    if exist(stim_path, 'file')
        [runner.stim_sound, fs_original] = audioread(stim_path);
        if fs_original ~= runner.fs
            runner.stim_sound = resample(runner.stim_sound, runner.fs, fs_original);
        end
    else
        runner.stim_sound = generate_stimulus_sound(runner.fs);
        fprintf('  刺激音生成\n');
    end

    % モノラル変換
    if size(runner.metro_sound, 2) > 1
        runner.metro_sound = mean(runner.metro_sound, 2);
    end
    if size(runner.stim_sound, 2) > 1
        runner.stim_sound = mean(runner.stim_sound, 2);
    end

    fprintf('  音声ファイル準備完了\n');
end

function runner = create_audio_players(runner)
    % 4チャンネル用audioplayerオブジェクト事前作成

    % メトロノーム用（全チャンネル）
    metro_4ch = zeros(length(runner.metro_sound), 4);
    metro_4ch(:, [1,2,3,4]) = repmat(runner.metro_sound, 1, 4);
    runner.metro_player = audioplayer(metro_4ch, runner.fs, 24);

    % Player 1→Player 2 刺激音（Ch 3/4）
    stim_p1_to_p2 = zeros(length(runner.stim_sound), 4);
    stim_p1_to_p2(:, [3,4]) = repmat(runner.stim_sound, 1, 2);
    runner.stim_p1_to_p2_player = audioplayer(stim_p1_to_p2, runner.fs, 24);

    % Player 2→Player 1 刺激音（Ch 1/2）
    stim_p2_to_p1 = zeros(length(runner.stim_sound), 4);
    stim_p2_to_p1(:, [1,2]) = repmat(runner.stim_sound, 1, 2);
    runner.stim_p2_to_p1_player = audioplayer(stim_p2_to_p1, runner.fs, 24);

    fprintf('  4チャンネルaudioplayerオブジェクト作成完了\n');
end

function runner = setup_input_system(runner)
    fprintf('キー入力システムセットアップ...\n');

    % プログラマブルキー設定
    runner.player1_key = 'q'; % Player 1用キー
    runner.player2_key = 'p'; % Player 2用キー

    % キー状態管理
    runner.key_states = struct();
    runner.key_states.player1_pressed = false;
    runner.key_states.player2_pressed = false;
    runner.key_states.last_check_time = 0;

    fprintf('  キー設定: Player 1=''%s'', Player 2=''%s''\n', ...
        runner.player1_key, runner.player2_key);
    fprintf('  キー入力システム準備完了\n');
end

function runner = setup_experiment_parameters(runner)
    fprintf('実験パラメータ設定...\n');

    % Stage 1: メトロノームフェーズ
    runner.stage1_beats = 20; % 20ビート
    runner.stage1_interval = 1.0; % 1秒間隔

    % Stage 2: 協調フェーズ
    runner.stage2_cycles = 50; % 50サイクル（100タップ）
    runner.stage2_target_interval = 1.0; % 1秒間隔

    % タイミング設定
    runner.clock_start = 0;

    fprintf('  Stage 1: %dビート, %.1fs間隔\n', runner.stage1_beats, runner.stage1_interval);
    fprintf('  Stage 2: %dサイクル, %.1fs間隔\n', runner.stage2_cycles, runner.stage2_target_interval);
    fprintf('  実験パラメータ設定完了\n');
end

function runner = setup_data_collection(runner)
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

function run_human_human_experiment(runner)
    fprintf('=== 実験開始 ===\n');

    % 実験説明
    display_experiment_instructions();

    % Stage 1: メトロノームフェーズ
    fprintf('\n--- Stage 1: メトロノームフェーズ ---\n');
    runner = run_stage1_metronome(runner);

    % Stage間の休憩
    fprintf('\nStage間休憩（5秒）...\n');
    pause(5);

    % Stage 2: 協調フェーズ
    fprintf('\n--- Stage 2: 協調フェーズ ---\n');
    runner = run_stage2_cooperation(runner);

    % 結果分析と保存
    analyze_and_save_results(runner);

    fprintf('\n=== 実験完了 ===\n');
end

function display_experiment_instructions()
    fprintf('\n実験説明:\n');
    fprintf('Stage 1: メトロノーム音に合わせて両プレイヤーがタップ\n');
    fprintf('         Player 1=''q''キー, Player 2=''p''キー\n');
    fprintf('Stage 2: 交互タッピング、相手のタップが刺激音として聞こえます\n');
    fprintf('         Player 1から開始\n');
    fprintf('\nESCキーで実験中断可能\n');

    input('準備ができたらEnterキーを押してください...');
end

function runner = run_stage1_metronome(runner)
    fprintf('メトロノームフェーズ開始 (%d beats)\n', runner.stage1_beats);

    runner.clock_start = posixtime(datetime('now'));
    beat_count = 0;

    while beat_count < runner.stage1_beats
        % ESCキーチェック
        if check_escape_key()
            fprintf('実験中断\n');
            return;
        end

        % メトロノーム再生タイミング
        target_time = beat_count * runner.stage1_interval + 0.5; % 0.5秒オフセット
        current_time = posixtime(datetime('now')) - runner.clock_start;

        if current_time >= target_time
            % メトロノーム再生
            play(runner.metro_player);

            beat_count = beat_count + 1;
            metro_time = posixtime(datetime('now')) - runner.clock_start;
            runner.data.stage1_metro_times(end+1) = metro_time;

            fprintf('メトロノーム %d/%d: %.3fs\n', beat_count, runner.stage1_beats, metro_time);
        end

        % キー入力チェック
        runner = check_key_inputs_stage1(runner);

        pause(0.001); % 1ms精度
    end

    fprintf('Stage 1完了\n');
end

function runner = check_key_inputs_stage1(runner)
    [keyIsDown, ~, keyCode] = KbCheck;

    if keyIsDown
        key_names = KbName(keyCode);
        tap_time = posixtime(datetime('now')) - runner.clock_start;

        if contains(key_names, runner.player1_key) && ~runner.key_states.player1_pressed
            runner.data.stage1_player1_taps(end+1) = tap_time;
            runner.key_states.player1_pressed = true;
            fprintf('  Player 1 tap: %.3fs\n', tap_time);
        end

        if contains(key_names, runner.player2_key) && ~runner.key_states.player2_pressed
            runner.data.stage1_player2_taps(end+1) = tap_time;
            runner.key_states.player2_pressed = true;
            fprintf('  Player 2 tap: %.3fs\n', tap_time);
        end
    else
        % キーリリース状態更新
        runner.key_states.player1_pressed = false;
        runner.key_states.player2_pressed = false;
    end
end

function runner = run_stage2_cooperation(runner)
    fprintf('協調フェーズ開始 (%d cycles)\n', runner.stage2_cycles);
    fprintf('Player 1から開始してください\n');

    cycle_count = 0;
    current_player = 1; % 1: Player 1のターン, 2: Player 2のターン
    last_tap_time = posixtime(datetime('now')) - runner.clock_start;

    while cycle_count < runner.stage2_cycles
        % ESCキーチェック
        if check_escape_key()
            fprintf('実験中断\n');
            return;
        end

        % キー入力チェック
        [tap_detected, player_id, tap_time] = check_key_inputs_stage2(runner);

        if tap_detected
            % 正しいプレイヤーのターンかチェック
            if player_id == current_player
                % タップデータ記録
                runner.data.stage2_taps(end+1, :) = [player_id, tap_time, cycle_count + 1];

                % 間隔計算
                if length(runner.data.stage2_taps) > 1
                    interval = tap_time - last_tap_time;
                    runner.data.stage2_intervals(end+1, :) = [player_id, 3-player_id, interval];
                end

                % 相手に刺激音送信
                send_stimulus_to_partner(runner, player_id);

                fprintf('Cycle %d: Player %d tap: %.3fs\n', cycle_count + 1, player_id, tap_time);

                % 次のプレイヤーに交代
                current_player = 3 - current_player; % 1↔2切り替え
                last_tap_time = tap_time;

                % サイクル完了チェック（両プレイヤーがタップ完了）
                if current_player == 1
                    cycle_count = cycle_count + 1;
                end
            else
                fprintf('  → Player %dのターンです\n', current_player);
            end
        end

        pause(0.001); % 1ms精度
    end

    fprintf('Stage 2完了\n');
end

function [tap_detected, player_id, tap_time] = check_key_inputs_stage2(runner)
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

function send_stimulus_to_partner(runner, tapping_player)
    % 相手のプレイヤーに刺激音送信

    if tapping_player == 1
        % Player 1がタップ → Player 2に刺激音（Ch 3/4）
        play(runner.stim_p1_to_p2_player);
    else
        % Player 2がタップ → Player 1に刺激音（Ch 1/2）
        play(runner.stim_p2_to_p1_player);
    end
end

function escape_pressed = check_escape_key()
    [keyIsDown, ~, keyCode] = KbCheck;
    escape_pressed = keyIsDown && any(strcmp(KbName(keyCode), 'ESCAPE'));
end

function analyze_and_save_results(runner)
    fprintf('\n--- 実験結果分析 ---\n');

    % Stage 1分析
    analyze_stage1_results(runner);

    % Stage 2分析
    analyze_stage2_results(runner);

    % データ保存
    save_experiment_data(runner);
end

function analyze_stage1_results(runner)
    fprintf('\nStage 1 分析:\n');

    % Player 1分析
    if length(runner.data.stage1_player1_taps) >= 2
        p1_intervals = diff(runner.data.stage1_player1_taps);
        fprintf('  Player 1: %d taps, 平均間隔 %.3fs, 標準偏差 %.1fms\n', ...
            length(runner.data.stage1_player1_taps), mean(p1_intervals), std(p1_intervals)*1000);
    end

    % Player 2分析
    if length(runner.data.stage1_player2_taps) >= 2
        p2_intervals = diff(runner.data.stage1_player2_taps);
        fprintf('  Player 2: %d taps, 平均間隔 %.3fs, 標準偏差 %.1fms\n', ...
            length(runner.data.stage1_player2_taps), mean(p2_intervals), std(p2_intervals)*1000);
    end
end

function analyze_stage2_results(runner)
    fprintf('\nStage 2 分析:\n');

    if size(runner.data.stage2_taps, 1) >= 2
        fprintf('  総タップ数: %d\n', size(runner.data.stage2_taps, 1));

        % 間隔分析
        if ~isempty(runner.data.stage2_intervals)
            intervals = runner.data.stage2_intervals(:, 3);
            fprintf('  平均間隔: %.3fs\n', mean(intervals));
            fprintf('  標準偏差: %.1fms\n', std(intervals)*1000);
            fprintf('  協調精度: %.1f%%\n', (1 - std(intervals)/mean(intervals)) * 100);
        end

        % プレイヤー別分析
        player1_taps = sum(runner.data.stage2_taps(:, 1) == 1);
        player2_taps = sum(runner.data.stage2_taps(:, 1) == 2);
        fprintf('  Player 1 taps: %d\n', player1_taps);
        fprintf('  Player 2 taps: %d\n', player2_taps);
    end
end

function save_experiment_data(runner)
    % 実験データ保存

    timestamp = datestr(runner.data.experiment_start_time, 'yyyymmdd_HHMMSS');
    filename = sprintf('human_human_experiment_%s.mat', timestamp);

    save(filename, 'runner');
    fprintf('\n実験データ保存: %s\n', filename);
end

% ヘルパー関数
function metro_sound = generate_metronome_sound(fs)
    duration = 0.1;
    t = 0:1/fs:duration-1/fs;
    envelope = exp(-t*20);
    metro_sound = 0.3 * envelope' .* sin(2*pi*800*t)';
end

function stim_sound = generate_stimulus_sound(fs)
    duration = 0.2;
    t = 0:1/fs:duration-1/fs;
    envelope = exp(-t*10);
    stim_sound = 0.4 * envelope' .* sin(2*pi*1200*t)';
end