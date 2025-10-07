% 人間同士協調タッピング実験システム (PsychPortAudio版)
% 2プレイヤーによる交互タッピング協調実験

% グローバル変数宣言
global experiment_running
global experiment_clock_start
global player1_key_pressed player2_key_pressed
global player1_last_press_time player2_last_press_time
global space_key_pressed

% メイン実行
run_human_human_experiment();

function run_human_human_experiment()
    % メイン関数

    % グローバル変数初期化
    global experiment_running
    global experiment_clock_start
    global player1_key_pressed player2_key_pressed
    global player1_last_press_time player2_last_press_time
    global space_key_pressed

    experiment_running = true;
    experiment_clock_start = 0;
    player1_key_pressed = false;
    player2_key_pressed = false;
    player1_last_press_time = 0;
    player2_last_press_time = 0;
    space_key_pressed = false;

    fprintf('=== 人間同士協調タッピング実験 (PsychPortAudio版) ===\n');

    try
        % 実験実行
        runner = initialize_human_human_runner();
        success = execute_human_human_experiment(runner);

        if success
            fprintf('\n実験が正常に完了しました！お疲れ様でした\n');
        else
            fprintf('\n実験が中断されました\n');
        end

        cleanup_human_human_resources(runner);

    catch ME
        fprintf('\n✗ 実験中にエラー: %s\n', ME.message);
        if exist('runner', 'var')
            cleanup_human_human_resources(runner);
        end
        rethrow(ME);
    end
end

function runner = initialize_human_human_runner()
    % 実験システム初期化

    fprintf('INFO: 人間同士実験システムを初期化中...\n');

    % PsychToolboxパス追加
    if exist('Psychtoolbox', 'dir')
        addpath(genpath('Psychtoolbox'));
    end

    % 基本構造
    runner = struct();
    runner.assets_dir = pwd;

    % 実験パラメータ
    runner.stage1_beats = 10;  % Stage1メトロノームビート数
    runner.stage2_cycles = 20; % Stage2交互タッピングサイクル数
    runner.target_interval = 1.0; % 目標間隔（秒）

    % 参加者情報
    fprintf('\n=== 参加者情報入力 ===\n');
    runner.participant_id = input('参加者ID (例: P001): ', 's');
    if isempty(runner.participant_id)
        runner.participant_id = 'anonymous';
    end

    % データ構造初期化
    runner.data = struct();
    runner.data.stage1_metro_times = [];
    runner.data.stage1_player1_taps = [];
    runner.data.stage1_player2_taps = [];
    runner.data.stage2_taps = [];  % [player_id, tap_time, cycle_number]
    runner.data.experiment_start_time = datetime('now');

    % PsychPortAudio初期化
    fprintf('INFO: PsychPortAudio音声システム初期化中...\n');
    runner.audio = initialize_stereo_audio_system();

    if isempty(runner.audio)
        error('PsychPortAudio音声システム初期化に失敗しました');
    end

    fprintf('INFO: PsychPortAudio音声システム初期化完了\n');

    % キー入力ウィンドウ作成
    runner.input_fig = figure('Name', 'Human-Human Cooperative Tapping', ...
        'NumberTitle', 'off', ...
        'MenuBar', 'none', 'ToolBar', 'none', ...
        'Position', [100, 100, 800, 600], ...
        'KeyPressFcn', @human_human_key_press_handler, ...
        'KeyReleaseFcn', @human_human_key_release_handler, ...
        'CloseRequestFcn', @human_human_window_close_handler, ...
        'Color', [0.2, 0.2, 0.2]);

    % 初期表示
    runner.window_axes = axes('Position', [0, 0, 1, 1], 'Visible', 'off');
    runner = update_window_display(runner, 'init');

    figure(runner.input_fig);

    fprintf('INFO: 初期化完了\n');
end

function audio = initialize_stereo_audio_system()
    % PsychPortAudioステレオシステム初期化

    audio = struct();

    try
        % PsychPortAudio初期化
        InitializePsychSound(1);

        % デバイス検索
        devices = PsychPortAudio('GetDevices');

        % Scarlett 4i4を優先的に検索
        device_id = [];
        for i = 1:length(devices)
            if devices(i).NrOutputChannels >= 2
                device_name = devices(i).DeviceName;
                if contains(lower(device_name), 'scarlett') || contains(lower(device_name), '4i4')
                    device_id = devices(i).DeviceIndex;
                    fprintf('✅ Scarlett 4i4検出: %s (DeviceIndex=%d)\n', ...
                        device_name, device_id);
                    break;
                end
            end
        end

        % Scarlett見つからない場合はデフォルトデバイス
        if isempty(device_id)
            device_id = -1;
            fprintf('⚠️  Scarlett 4i4未検出、デフォルトデバイス使用\n');
        end

        % 音声ファイル読み込み
        stim_path = fullfile(pwd, 'assets', 'sounds', 'stim_beat_optimized.wav');
        if ~exist(stim_path, 'file')
            error('音声ファイルが見つかりません: %s', stim_path);
        end

        [sound_data, fs] = audioread(stim_path);
        if size(sound_data, 2) > 1
            sound_data = mean(sound_data, 2); % モノラル化
        end

        audio.fs = fs;
        audio.sound_mono = sound_data;

        % ステレオバッファ作成用の音声データ
        % メトロノーム: 両チャンネル
        % 刺激音: 左チャンネルのみ (Player 1用)
        % プレイヤー音: 右チャンネルのみ (Player 2用)

        % PsychPortAudioデバイスオープン (ステレオ出力)
        % mode=1: 再生のみ, reqlatencyclass=2: 低遅延モード
        audio.pahandle = PsychPortAudio('Open', device_id, 1, 2, fs, 2);

        % 遅延情報取得
        status = PsychPortAudio('GetStatus', audio.pahandle);
        fprintf('PsychPortAudio初期化完了:\n');
        fprintf('  サンプリング周波数: %d Hz\n', fs);
        fprintf('  出力遅延: %.3f ms\n', status.PredictedLatency * 1000);

        % メトロノーム音バッファ (ステレオ両チャンネル)
        metro_stereo = [sound_data, sound_data]';
        audio.metro_buffer = PsychPortAudio('CreateBuffer', audio.pahandle, metro_stereo);

        % Player 1刺激音バッファ (左チャンネルのみ)
        p1_stereo = [sound_data, zeros(size(sound_data))]';
        audio.player1_buffer = PsychPortAudio('CreateBuffer', audio.pahandle, p1_stereo);

        % Player 2刺激音バッファ (右チャンネルのみ)
        p2_stereo = [zeros(size(sound_data)), sound_data]';
        audio.player2_buffer = PsychPortAudio('CreateBuffer', audio.pahandle, p2_stereo);

        fprintf('音声バッファ作成完了 (メトロノーム, Player1左, Player2右)\n');

    catch ME
        fprintf('❌ PsychPortAudio初期化エラー: %s\n', ME.message);
        audio = [];
        return;
    end
end

function success = execute_human_human_experiment(runner)
    % 実験実行
    global experiment_running

    success = false;

    try
        % 実験説明
        display_experiment_instructions(runner);

        % Stage1: メトロノームフェーズ
        fprintf('\n=== Stage 1: メトロノームフェーズ ===\n');
        runner = update_window_display(runner, 'stage1_ready');
        wait_for_space_key();

        [runner, stage1_ok] = run_stage1_metronome(runner);
        if ~stage1_ok || ~experiment_running
            return;
        end

        % Stage2: 協調フェーズ（Stage間休憩なし）
        fprintf('\n=== Stage 2: 協調タッピングフェーズ ===\n');
        runner = update_window_display(runner, 'stage2_ready');
        wait_for_space_key();

        [runner, stage2_ok] = run_stage2_cooperative(runner);
        if ~stage2_ok || ~experiment_running
            return;
        end

        % データ保存
        save_experiment_data(runner);

        success = true;

    catch ME
        fprintf('ERROR: 実験実行エラー: %s\n', ME.message);
        success = false;
    end
end

function display_experiment_instructions(runner)
    % ウィンドウに実験説明を表示
    runner = update_window_display(runner, 'instructions');

    fprintf('\n========================================\n');
    fprintf('実験説明をウィンドウに表示しました\n');
    fprintf('準備ができたらスペースキーを押してください\n');
    fprintf('========================================\n\n');

    % スペースキー待機
    wait_for_space_key();
end

function [runner, success] = run_stage1_metronome(runner)
    % Stage1: 完全周期メトロノーム段階
    % 両プレイヤーが両方の音を聞いて、決まったタイミングを学習
    global experiment_running
    global experiment_clock_start

    success = false;

    % ウィンドウ表示更新
    runner = update_window_display(runner, 'stage1_running');

    fprintf('Stage1開始: 両プレイヤーが両方の音（左と右）を聞いて1秒間隔を学習\n');

    % タイマー初期化
    runner.clock_start = posixtime(datetime('now'));
    experiment_clock_start = runner.clock_start;

    % 全音声の絶対スケジュール作成
    % Player1音とPlayer2音を交互に再生するが、両プレイヤーが両方聞く
    total_sounds = runner.stage1_beats * 2;

    for sound_index = 1:total_sounds
        if ~experiment_running
            return;
        end

        % 絶対時刻スケジューリング: 0.5, 1.5, 2.5, 3.5, 4.5...秒
        target_time = (sound_index - 1) * 1.0 + 0.5;

        % 待機
        while (posixtime(datetime('now')) - experiment_clock_start) < target_time
            if check_escape_key()
                fprintf('実験中断\n');
                return;
            end
            pause(0.001);
        end

        % 音声再生
        actual_time = posixtime(datetime('now')) - experiment_clock_start;

        if mod(sound_index, 2) == 1
            % 奇数: Player1音（左チャンネル）- 両プレイヤーが聞く
            pair_num = ceil(sound_index / 2);
            fprintf('[%d/%d] Player1音(左) %.3fs\n', ...
                pair_num, runner.stage1_beats, actual_time);

            PsychPortAudio('FillBuffer', runner.audio.pahandle, runner.audio.player1_buffer);
            PsychPortAudio('Start', runner.audio.pahandle, 1, 0, 1);

            runner.data.stage1_player1_taps(end+1) = actual_time;
        else
            % 偶数: Player2音（右チャンネル）- 両プレイヤーが聞く
            pair_num = sound_index / 2;
            fprintf('       Player2音(右) %.3fs\n', actual_time);

            PsychPortAudio('FillBuffer', runner.audio.pahandle, runner.audio.player2_buffer);
            PsychPortAudio('Start', runner.audio.pahandle, 1, 0, 1);

            runner.data.stage1_player2_taps(end+1) = actual_time;
        end

        runner.data.stage1_metro_times(end+1) = actual_time;
    end

    fprintf('\n=== Stage1 完了 ===\n');
    fprintf('Player1音: %d回, Player2音: %d回\n', ...
        length(runner.data.stage1_player1_taps), length(runner.data.stage1_player2_taps));

    success = true;
end


function [runner, success] = run_stage2_cooperative(runner)
    % Stage2: 協調タッピングフェーズ
    global experiment_running
    global experiment_clock_start
    global player1_key_pressed player2_key_pressed
    global player1_last_press_time player2_last_press_time

    success = false;

    % ウィンドウ表示更新
    runner = update_window_display(runner, 'stage2_running');

    fprintf('Stage2開始: Player 1 (Sキー) から開始\n');

    cycle_count = 0;
    current_player = 1;  % 1: Player 1のターン, 2: Player 2のターン
    last_tap_time = posixtime(datetime('now')) - experiment_clock_start;

    while cycle_count < runner.stage2_cycles
        if ~experiment_running || check_escape_key()
            fprintf('実験中断\n');
            return;
        end

        % 現在時刻
        current_time = posixtime(datetime('now')) - experiment_clock_start;

        % プレイヤータップ検出
        tap_detected = false;
        tapping_player = 0;

        if current_player == 1 && player1_key_pressed && ...
                (current_time - player1_last_press_time) > 0.05
            tap_detected = true;
            tapping_player = 1;
            player1_last_press_time = current_time;
        elseif current_player == 2 && player2_key_pressed && ...
                (current_time - player2_last_press_time) > 0.05
            tap_detected = true;
            tapping_player = 2;
            player2_last_press_time = current_time;
        end

        if tap_detected
            % タップデータ記録
            runner.data.stage2_taps(end+1, :) = [tapping_player, current_time, cycle_count + 1];

            % 間隔計算
            interval = current_time - last_tap_time;

            % 相手に刺激音送信
            if tapping_player == 1
                % Player 1がタップ → Player 2の右耳に音
                PsychPortAudio('FillBuffer', runner.audio.pahandle, runner.audio.player2_buffer);
            else
                % Player 2がタップ → Player 1の左耳に音
                PsychPortAudio('FillBuffer', runner.audio.pahandle, runner.audio.player1_buffer);
            end
            PsychPortAudio('Start', runner.audio.pahandle, 1, 0, 1);

            fprintf('C%d: P%d tap → %.3fs (間隔 %.3fs)\n', ...
                cycle_count + 1, tapping_player, current_time, interval);

            % 次のプレイヤーに交代
            current_player = 3 - current_player; % 1↔2切り替え
            last_tap_time = current_time;

            % サイクル完了チェック
            if current_player == 1
                cycle_count = cycle_count + 1;
                fprintf('  --- サイクル %d/%d 完了 ---\n', cycle_count, runner.stage2_cycles);
            end
        end

        pause(0.001); % 1ms polling
    end

    fprintf('Stage 2完了\n');
    success = true;
end

function save_experiment_data(runner)
    % データ保存

    fprintf('\n=== データ保存 ===\n');

    % 保存ディレクトリ作成
    timestamp = datestr(runner.data.experiment_start_time, 'yyyymmdd_HHMMSS');
    date_str = datestr(runner.data.experiment_start_time, 'yyyymmdd');

    data_dir = fullfile(pwd, 'data', 'raw', date_str, ...
        sprintf('%s_human_human_%s', runner.participant_id, timestamp));

    if ~exist(data_dir, 'dir')
        mkdir(data_dir);
    end

    % データ分析
    analyze_and_display_results(runner);

    % MAT形式で保存
    save(fullfile(data_dir, 'experiment_data.mat'), 'runner');

    % CSV形式でStage1データ保存
    if ~isempty(runner.data.stage1_metro_times)
        stage1_data = table(...
            runner.data.stage1_metro_times', ...
            'VariableNames', {'MetronomeTime'});
        writetable(stage1_data, fullfile(data_dir, 'stage1_metronome.csv'));
    end

    % CSV形式でStage2データ保存
    if ~isempty(runner.data.stage2_taps)
        stage2_data = table(...
            runner.data.stage2_taps(:,1), ...
            runner.data.stage2_taps(:,2), ...
            runner.data.stage2_taps(:,3), ...
            'VariableNames', {'PlayerID', 'TapTime', 'CycleNumber'});
        writetable(stage2_data, fullfile(data_dir, 'stage2_cooperative_taps.csv'));
    end

    fprintf('💾 データ保存完了: %s\n', data_dir);
end

function analyze_and_display_results(runner)
    % 結果分析と表示

    fprintf('\n========================================\n');
    fprintf('           実験結果分析\n');
    fprintf('========================================\n');

    % Stage 1分析
    fprintf('\n【Stage 1 - メトロノーム（交互音声）】\n');
    fprintf('  総音声数: %d\n', length(runner.data.stage1_metro_times));
    fprintf('  Player1音: %d回\n', length(runner.data.stage1_player1_taps));
    fprintf('  Player2音: %d回\n', length(runner.data.stage1_player2_taps));

    % 全体の間隔分析
    if length(runner.data.stage1_metro_times) >= 2
        all_intervals = diff(runner.data.stage1_metro_times);
        fprintf('  全体平均間隔: %.3fs (目標1.0s)\n', mean(all_intervals));
        fprintf('  標準偏差: %.1fms\n', std(all_intervals)*1000);
    end

    % Player1音の間隔（2秒間隔のはず）
    if length(runner.data.stage1_player1_taps) >= 2
        p1_intervals = diff(runner.data.stage1_player1_taps);
        fprintf('  Player1音間隔: 平均 %.3fs (目標2.0s)\n', mean(p1_intervals));
    end

    % Player2音の間隔（2秒間隔のはず）
    if length(runner.data.stage1_player2_taps) >= 2
        p2_intervals = diff(runner.data.stage1_player2_taps);
        fprintf('  Player2音間隔: 平均 %.3fs (目標2.0s)\n', mean(p2_intervals));
    end

    % Stage 2分析
    fprintf('\n【Stage 2 - 協調タッピング】\n');

    if size(runner.data.stage2_taps, 1) >= 2
        fprintf('  総タップ数: %d\n', size(runner.data.stage2_taps, 1));

        % 間隔分析
        intervals = diff(runner.data.stage2_taps(:, 2));
        fprintf('  全体平均間隔: %.3fs (目標 %.1fs)\n', mean(intervals), runner.target_interval);
        fprintf('  標準偏差: %.1fms\n', std(intervals)*1000);
        fprintf('  最小間隔: %.3fs\n', min(intervals));
        fprintf('  最大間隔: %.3fs\n', max(intervals));

        % プレイヤー別分析
        p1_taps = sum(runner.data.stage2_taps(:, 1) == 1);
        p2_taps = sum(runner.data.stage2_taps(:, 1) == 2);
        fprintf('  Player 1 taps: %d\n', p1_taps);
        fprintf('  Player 2 taps: %d\n', p2_taps);

        % 協調精度
        coordination_accuracy = max(0, (1 - std(intervals)/mean(intervals)) * 100);
        fprintf('  協調精度: %.1f%%\n', coordination_accuracy);

        if abs(p1_taps - p2_taps) <= 1
            fprintf('  ✅ 適切な交互タッピング\n');
        else
            fprintf('  ⚠️  交互タッピングに不均衡\n');
        end
    else
        fprintf('  データ不足 (分析不可)\n');
    end

    fprintf('========================================\n');
end

function cleanup_human_human_resources(runner)
    % リソースクリーンアップ

    try
        % PsychPortAudio停止・クローズ
        if isfield(runner, 'audio') && ~isempty(runner.audio)
            if isfield(runner.audio, 'pahandle')
                PsychPortAudio('Close', runner.audio.pahandle);
                fprintf('PsychPortAudio停止完了\n');
            end
        end
    catch ME
        fprintf('⚠️  PsychPortAudioクリーンアップエラー: %s\n', ME.message);
    end

    try
        % ウィンドウクローズ
        if isfield(runner, 'input_fig') && ishandle(runner.input_fig)
            close(runner.input_fig);
        end
    catch
        % Ignore
    end

    fprintf('リソースクリーンアップ完了\n');
end

% === キーボードハンドラ ===

function human_human_key_press_handler(~, event)
    % キー押下ハンドラ
    global player1_key_pressed player2_key_pressed
    global experiment_running space_key_pressed

    key = event.Key;

    if strcmp(key, 's')
        player1_key_pressed = true;
    elseif strcmp(key, 'c')
        player2_key_pressed = true;
    elseif strcmp(key, 'space')
        space_key_pressed = true;
    elseif strcmp(key, 'escape')
        experiment_running = false;
    end
end

function human_human_key_release_handler(~, event)
    % キーリリースハンドラ
    global player1_key_pressed player2_key_pressed
    global space_key_pressed

    key = event.Key;

    if strcmp(key, 's')
        player1_key_pressed = false;
    elseif strcmp(key, 'c')
        player2_key_pressed = false;
    elseif strcmp(key, 'space')
        space_key_pressed = false;
    end
end

function human_human_window_close_handler(~, ~)
    % ウィンドウクローズハンドラ
    global experiment_running

    experiment_running = false;
    delete(gcf);
end

% === ユーティリティ関数 ===

function wait_for_space_key()
    % スペースキー待機（Figureキーイベント使用）
    global space_key_pressed experiment_running

    % フラグリセット
    space_key_pressed = false;

    % スペースキーが押されるまで待機
    while ~space_key_pressed && experiment_running
        pause(0.05);
        drawnow; % イベント処理を強制実行
    end

    % フラグリセット
    space_key_pressed = false;
end

function is_escape = check_escape_key()
    % Escapeキーチェック（グローバル変数から判定）
    global experiment_running

    % experiment_runningがfalseの場合はEscapeが押された
    is_escape = ~experiment_running;

    % イベント処理を確実に実行
    drawnow;
end

function runner = update_window_display(runner, mode)
    % ウィンドウ表示を更新

    if ~isfield(runner, 'window_axes') || ~isvalid(runner.window_axes)
        return;
    end

    % 現在の表示をクリア
    cla(runner.window_axes);
    axes(runner.window_axes);

    switch mode
        case 'init'
            % 初期画面
            text(0.5, 0.5, '初期化完了', ...
                'HorizontalAlignment', 'center', ...
                'FontSize', 20, 'Color', 'white', 'FontWeight', 'bold');

        case 'instructions'
            % 実験説明
            text(0.5, 0.9, '実験説明', ...
                'HorizontalAlignment', 'center', ...
                'FontSize', 22, 'Color', 'white', 'FontWeight', 'bold');

            text(0.5, 0.75, 'Stage 1: メトロノームフェーズ', ...
                'HorizontalAlignment', 'center', ...
                'FontSize', 16, 'Color', [0.3, 0.8, 1.0], 'FontWeight', 'bold');
            text(0.5, 0.68, '左耳の音と右耳の音が1秒間隔で交互に再生されます', ...
                'HorizontalAlignment', 'center', 'FontSize', 12, 'Color', 'white');
            text(0.5, 0.62, '両プレイヤーは両方の音を聞いて、正確な1秒間隔を学習してください', ...
                'HorizontalAlignment', 'center', 'FontSize', 12, 'Color', 'white');

            text(0.5, 0.50, 'Stage 2: 協調タッピングフェーズ', ...
                'HorizontalAlignment', 'center', ...
                'FontSize', 16, 'Color', [1.0, 0.8, 0.3], 'FontWeight', 'bold');
            text(0.5, 0.43, 'Player 1 (Sキー) から開始', ...
                'HorizontalAlignment', 'center', 'FontSize', 12, 'Color', 'white');
            text(0.5, 0.37, '相手がタップすると自分の耳に音が聞こえます', ...
                'HorizontalAlignment', 'center', 'FontSize', 12, 'Color', 'white');
            text(0.5, 0.31, 'できるだけ正確な1秒間隔を維持してください', ...
                'HorizontalAlignment', 'center', 'FontSize', 12, 'Color', 'white');

            text(0.5, 0.15, 'スペースキーを押して開始', ...
                'HorizontalAlignment', 'center', ...
                'FontSize', 18, 'Color', [0.2, 1.0, 0.2], 'FontWeight', 'bold');
            text(0.5, 0.05, 'Escapeキーで中断', ...
                'HorizontalAlignment', 'center', 'FontSize', 10, 'Color', [0.8, 0.8, 0.8]);

        case 'stage1_ready'
            % Stage1準備
            text(0.5, 0.6, 'Stage 1: メトロノームフェーズ', ...
                'HorizontalAlignment', 'center', ...
                'FontSize', 24, 'Color', [0.3, 0.8, 1.0], 'FontWeight', 'bold');
            text(0.5, 0.45, '左耳の音と右耳の音が1秒間隔で交互に再生されます', ...
                'HorizontalAlignment', 'center', 'FontSize', 14, 'Color', 'white');
            text(0.5, 0.35, '両プレイヤーは両方の音を聞いてリズムを学習', ...
                'HorizontalAlignment', 'center', 'FontSize', 14, 'Color', 'white');
            text(0.5, 0.2, 'スペースキーを押して開始', ...
                'HorizontalAlignment', 'center', ...
                'FontSize', 18, 'Color', [0.2, 1.0, 0.2], 'FontWeight', 'bold');

        case 'stage1_running'
            % Stage1実行中
            text(0.5, 0.6, 'Stage 1 実行中', ...
                'HorizontalAlignment', 'center', ...
                'FontSize', 24, 'Color', [0.3, 0.8, 1.0], 'FontWeight', 'bold');
            text(0.5, 0.45, '左と右の音を聞いて', ...
                'HorizontalAlignment', 'center', 'FontSize', 16, 'Color', 'white');
            text(0.5, 0.35, '1秒間隔のリズムを学習してください', ...
                'HorizontalAlignment', 'center', 'FontSize', 16, 'Color', 'white');

        case 'stage2_ready'
            % Stage2準備
            text(0.5, 0.7, 'Stage 2: 協調タッピングフェーズ', ...
                'HorizontalAlignment', 'center', ...
                'FontSize', 24, 'Color', [1.0, 0.8, 0.3], 'FontWeight', 'bold');
            text(0.5, 0.55, 'Player 1 (Sキー) から開始', ...
                'HorizontalAlignment', 'center', 'FontSize', 16, 'Color', [0.3, 0.8, 1.0]);
            text(0.5, 0.45, '相手がタップすると自分の耳に音が聞こえます', ...
                'HorizontalAlignment', 'center', 'FontSize', 14, 'Color', 'white');
            text(0.5, 0.35, 'Player 1: Sキー (左耳に音)', ...
                'HorizontalAlignment', 'center', 'FontSize', 14, 'Color', [0.3, 0.8, 1.0]);
            text(0.5, 0.27, 'Player 2: Cキー (右耳に音)', ...
                'HorizontalAlignment', 'center', 'FontSize', 14, 'Color', [1.0, 0.8, 0.3]);
            text(0.5, 0.15, 'スペースキーを押して開始', ...
                'HorizontalAlignment', 'center', ...
                'FontSize', 18, 'Color', [0.2, 1.0, 0.2], 'FontWeight', 'bold');

        case 'stage2_running'
            % Stage2実行中
            text(0.5, 0.6, 'Stage 2 実行中', ...
                'HorizontalAlignment', 'center', ...
                'FontSize', 24, 'Color', [1.0, 0.8, 0.3], 'FontWeight', 'bold');
            text(0.5, 0.45, 'Player 1: Sキー', ...
                'HorizontalAlignment', 'center', 'FontSize', 18, 'Color', [0.3, 0.8, 1.0]);
            text(0.5, 0.35, 'Player 2: Cキー', ...
                'HorizontalAlignment', 'center', 'FontSize', 18, 'Color', [1.0, 0.8, 0.3]);
            text(0.5, 0.2, '1秒間隔を維持してください', ...
                'HorizontalAlignment', 'center', 'FontSize', 14, 'Color', 'white');
    end

    drawnow;
end
