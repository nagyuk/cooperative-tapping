% グローバル変数宣言（スクリプトレベル）
global experiment_key_buffer experiment_running
global experiment_key_pressed experiment_last_key_time experiment_last_key_type
global experiment_clock_start

% メイン実行
run_cooperative_tapping_experiment();

function run_cooperative_tapping_experiment()
    % main関数 - Python版の完全再現
    
    % グローバル変数初期化
    global experiment_key_buffer experiment_running
    global experiment_key_pressed experiment_last_key_time experiment_last_key_type
    global experiment_clock_start
    experiment_key_buffer = {};
    experiment_running = true;
    experiment_key_pressed = false;
    experiment_last_key_time = 0;
    experiment_last_key_type = '';
    experiment_clock_start = 0;
    
    fprintf('=== Python版協調タッピング実験 完全再現 ===\n');
    
    try
        % 実験実行
        runner = initialize_experiment_runner();
        success = execute_full_experiment(runner);
        
        if success
            fprintf('\n実験が正常に完了しました！お疲れ様でした\n');
        else
            fprintf('\n実験が中断されました\n');
        end
        
        cleanup_all_resources(runner);
        
    catch ME
        fprintf('\n✗ 実験中にエラー: %s\n', ME.message);
        if exist('runner', 'var')
            cleanup_all_resources(runner);
        end
        rethrow(ME);
    end
end

function runner = initialize_experiment_runner()
    % Python版ExperimentRunner.__init__()再現
    
    fprintf('INFO: ExperimentRunnerを初期化中...\n');
    
    % パス設定とライブラリ読み込み
    addpath('experiments/configs');
    addpath('experiments/models');
    addpath('experiments/utils');
    addpath('experiments');  % PsychPortAudio関数用

    % 基本構造
    runner = struct();
    runner.assets_dir = pwd;  % 現在のディレクトリ（ルート）
    
    
    % 設定ファイルから読み込み
    config = experiment_config();
    
    % ユーザー設定
    fprintf('モデル選択: 1=SEA, 2=Bayes, 3=BIB\n');
    model_choice = input('モデル番号 (1-3): ');
    if isempty(model_choice) || model_choice < 1 || model_choice > 3
        model_choice = 1;
    end
    
    model_types = {'sea', 'bayes', 'bib'};
    model_type = model_types{model_choice};
    
    user_id = input('参加者ID: ', 's');
    if isempty(user_id), user_id = 'anonymous'; end
    
    % Runner構造体の追加設定
    runner.config = config;
    runner.model_type = model_type;
    runner.user_id = user_id;
    runner.serial_num = datestr(now, 'yyyymmddHHMM');
    runner.play_call_count = 0;

    % デバッグ記録用配列
    runner.debug_log = {};
    runner.debug_count = 0;
    
    % データ初期化
    runner = reset_all_experiment_data(runner);
    
    % モデル初期化
    runner.model = model_factory(model_type, config);
    
    % PsychPortAudio高精度音声システム初期化
    fprintf('INFO: PsychPortAudio高精度音声システム初期化中...\n');
    runner.audio_system = initialize_ptb_audio_system();

    if isempty(runner.audio_system)
        error('PsychPortAudio音声システム初期化に失敗しました');
    end

    fprintf('INFO: PsychPortAudio高精度音声システム初期化完了\n');
    
    % 入力ウィンドウ作成（直接作成）
    runner.input_fig = figure('Name', 'Cooperative Tapping', 'NumberTitle', 'off', ...
        'MenuBar', 'none', 'ToolBar', 'none', ...
        'Position', [100, 100, 500, 300], ...
        'KeyPressFcn', @experiment_key_press_handler, ...
        'CloseRequestFcn', @experiment_window_close_handler, ...
        'Color', [0.2, 0.2, 0.2]);
    
    % 表示テキスト
    axes('Position', [0, 0, 1, 1], 'Visible', 'off');
    text(0.5, 0.7, '協調タッピング実験', 'HorizontalAlignment', 'center', ...
        'FontSize', 16, 'Color', 'white', 'FontWeight', 'bold');
    text(0.5, 0.5, 'スペースキー: タップ', 'HorizontalAlignment', 'center', ...
        'FontSize', 12, 'Color', 'white');
    text(0.5, 0.3, 'Escapeキー: 実験中止', 'HorizontalAlignment', 'center', ...
        'FontSize', 12, 'Color', 'white');
    
    figure(runner.input_fig);
    
    fprintf('INFO: 初期化完了\n');
end

function runner = reset_all_experiment_data(runner)
    % Python版reset_data()再現
    runner.stim_tap = [];
    runner.player_tap = [];
    runner.stim_se = [];
    runner.full_stim_tap = [];
    runner.full_player_tap = [];
end



function success = execute_full_experiment(runner)
    % Python版run()メソッド再現
    global experiment_running
    
    success = false;
    
    try
        % Stage1実行
        [runner, stage1_ok] = run_experiment_stage1(runner);
        if ~stage1_ok || ~experiment_running
            return;
        end
        
        % Stage2実行
        [runner, stage2_ok] = run_experiment_stage2(runner);
        if ~stage2_ok || ~experiment_running
            return;
        end
        
        % データ分析・保存
        process_and_save_experiment_data(runner);
        
        success = true;
        
    catch ME
        fprintf('ERROR: 実験実行エラー: %s\n', ME.message);
        success = false;
    end
end

function [runner, success] = run_experiment_stage1(runner)
    % Stage1: 完全に周期的な1秒間隔メトロノーム段階（修正版）
    % 目的: 被験者に正確な1.0秒間隔を学習させる
    % 動作: 刺激音A→プレイヤー音B を正確に1.0秒間隔で交互再生
    global experiment_running

    success = false;
    stage1_completed_taps = 0;
    required_taps = runner.config.STAGE1;

    fprintf('\n=== Stage 1: 完全周期メトロノーム段階（修正版）===\n');
    fprintf('刺激音Aとプレイヤー音Bが正確に1.0秒間隔で交互に再生されます\n');
    fprintf('音声A（刺激音）: 聞くだけ、タップしない\n');
    fprintf('音声B（プレイヤー音）: この音に合わせてタップ\n');
    fprintf('目標: %d回のタップで正確な1.0秒間隔を学習\n', required_taps);

    % 開始待機
    fprintf('準備ができたらスペースキーを押してください...\n');
    wait_for_space_key();

    % タイマー初期化
    runner.clock_start = posixtime(datetime('now'));

    % グローバル変数設定
    global experiment_clock_start
    experiment_clock_start = runner.clock_start;

    fprintf('開始! 正確な1.0秒間隔で音声が再生されます\n');

    % Stage1: 純粋な1秒間隔メトロノーム（タップ検出なし）
    fprintf('純粋メトロノーム開始: 刺激音→プレイヤー音を正確に1秒間隔で再生\n');
    fprintf('タップ練習用ですが、タップ検出は行いません（規則性優先）\n');

    % 全音声の絶対スケジュール作成
    total_sounds = required_taps * 2;

    for sound_index = 1:total_sounds
        if ~experiment_running
            break;
        end

        % 絶対時刻スケジューリング: 0.5, 1.5, 2.5, 3.5, 4.5...秒
        % 0.5秒のオフセットでスタート時バタつきを回避
        target_time = (sound_index - 1) * 1.0 + 0.5;

        % シンプルで確実な待機システム
        while (posixtime(datetime('now')) - experiment_clock_start) < target_time
            % Escapeキーチェックのみ
            keys = get_all_recent_keys();
            if any(strcmp(keys, 'escape'))
                fprintf('実験が中断されました\n');
                return;
            end
            pause(0.001); % 1ms間隔の安定した待機
        end

        % 音声再生（統一基準時刻）
        global experiment_clock_start
        actual_time = posixtime(datetime('now')) - experiment_clock_start;

        if mod(sound_index, 2) == 1
            % 奇数: 刺激音（0秒、2秒、4秒...）
            pair_num = ceil(sound_index / 2);
            fprintf('[%d/%d] 刺激音再生 (%.3fs地点, 目標%.3fs)\n', ...
                pair_num, required_taps, actual_time, target_time);
            runner = play_stim_sound(runner);
            runner.stim_tap(end+1) = actual_time;
            runner.full_stim_tap(end+1) = actual_time;
        else
            % 偶数: プレイヤー音（1秒、3秒、5秒...）
            pair_num = sound_index / 2;
            fprintf('       プレイヤー音再生 (%.3fs地点, 目標%.3fs) - 練習タップ\n', ...
                actual_time, target_time);
            runner = play_player_sound(runner);

            % Stage1でもプレイヤー音時刻を記録（データ整合性のため）
            runner.player_tap(end+1) = actual_time;
            runner.full_player_tap(end+1) = actual_time;
        end
    end

    % Stage1完了（タップ数は音数に基づく）
    stage1_completed_taps = required_taps; % プレイヤー音の回数

    % Stage1完了処理
    fprintf('\n=== Stage1 完全周期メトロノーム完了 ===\n');
    fprintf('完了したプレイヤー音タップ: %d回\n', stage1_completed_taps);

    % 同期精度の分析
    if length(runner.stim_tap) > 0 && length(runner.player_tap) > 0
        sync_errors = [];
        min_length = min(length(runner.stim_tap), length(runner.player_tap));

        for i = 1:min_length
            sync_error = runner.player_tap(i) - runner.stim_tap(i);
            sync_errors(end+1) = sync_error;
        end

        if ~isempty(sync_errors)
            mean_sync_error = mean(sync_errors);
            std_sync_error = std(sync_errors);
            fprintf('プレイヤー音タッピング精度 - 平均遅延: %.3fs, 標準偏差: %.3fs\n', ...
                mean_sync_error, std_sync_error);
        end
    end

    % Stage1からStage2へのスムーズな移行設計
    if length(runner.stim_tap) > 0
        runner.last_stim_tap_time = runner.stim_tap(end);
    else
        global experiment_clock_start
        runner.last_stim_tap_time = posixtime(datetime('now')) - experiment_clock_start;
    end

    % Stage2初期タイミングの計算（Stage1の最後の刺激音から1秒後開始）
    global experiment_clock_start
    stage1_end_time = posixtime(datetime('now')) - experiment_clock_start;

    % Stage2は学習した1.0秒間隔を基準とした交互タッピングに移行
    % 最後の刺激音から1秒後にStage2の最初の人間タップを期待
    runner.next_expected_tap_time = runner.last_stim_tap_time + 1.0;

    fprintf('Stage2開始準備完了:\n');
    fprintf('  最後の刺激音: %.3fs地点\n', runner.last_stim_tap_time);
    fprintf('  次の期待タップ: %.3fs地点 (1.0秒後)\n', runner.next_expected_tap_time);
    fprintf('  Stage1で学習した1.0秒間隔を基準とした交互タッピングです\n');

    success = true;
end

function [runner, success] = run_experiment_stage2(runner)
    % Stage2: 協調交互タッピング段階
    % 目的: Stage1で学習した基準周期を基にした協調的なタイミング調整
    global experiment_running

    success = false;
    flag = 1; % 1: Stimulus turn, 0: Player turn
    turn = 0;

    fprintf('\n=== Stage 2: 協調交互タッピング段階 ===\n');
    fprintf('Stage1で学習した1.0秒間隔を基準とした交互タッピングです\n');
    fprintf('システムが刺激音のタイミングを動的に調整します\n\n');

    % Stage1からのスムーズな移行（準備待機を削除）
    fprintf('Stage1からStage2への移行:\n');
    fprintf('  前段階の学習間隔: 1.0秒\n');
    fprintf('  この段階の目標間隔: 1.0秒（協調交互タッピング）\n\n');

    % Stage2のタイマー初期化（Stage1から継続、統一基準）
    global experiment_clock_start
    current_time = posixtime(datetime('now')) - experiment_clock_start;

    % Stage1からのスムーズな移行タイミング計算
    if runner.next_expected_tap_time > current_time
        time_to_next_tap = runner.next_expected_tap_time - current_time;
        fprintf('Stage1から継続: 次のタップまで%.3f秒\n', time_to_next_tap);
    else
        % Stage1から時間が経過している場合の調整（1.0秒基準）
        elapsed_time = current_time - runner.last_stim_tap_time;
        target_interval = 1.0; % Stage1で学習した1.0秒間隔
        time_to_next_tap = target_interval - mod(elapsed_time, target_interval);

        fprintf('Stage1からの経過時間調整: %.3f秒経過, 次まで%.3f秒\n', ...
            elapsed_time, time_to_next_tap);
    end

    % 最小間隔保証（1.0秒基準）
    if time_to_next_tap < 0.3
        time_to_next_tap = 1.0; % Stage1学習間隔にリセット
    end

    % 初期値（Stage1の1.0秒間隔を尊重）
    random_second = time_to_next_tap;
    runner.timer_start = posixtime(datetime('now'));

    fprintf('INFO: Stage2協調交互タッピング開始\n');
    fprintf('次のシステム刺激音まで: %.3f秒\n', random_second);
    fprintf('システム音の中間地点（%.3f秒後）でタップしてください\n\n', random_second / 2);
    
    % Stage2メインループ（統一時刻基準）
    next_stim_time = current_time + random_second;  % 次の刺激音の絶対時刻

    while experiment_running
        global experiment_clock_start
        current_abs_time = posixtime(datetime('now')) - experiment_clock_start;
        time_until_stim = next_stim_time - current_abs_time;
        
        % システムのターン
        if time_until_stim <= 0 && flag == 1
            % 刺激音再生前のタイミング記録（統一基準）
            global experiment_clock_start
            pre_stim_time = posixtime(datetime('now')) - experiment_clock_start;

            % 最適化された刺激音再生
            runner = play_optimized_sound(runner);

            % 刺激音再生後のタイミング記録（統一基準）
            tap_time = posixtime(datetime('now')) - experiment_clock_start;
            if length(runner.player_tap) > 0
                actual_iti = tap_time - runner.player_tap(end);
            else
                actual_iti = tap_time;
            end

            fprintf('[%d回目の刺激音] 実際ITI=%.3fs\n', ...
                turn+1, actual_iti);

            runner.stim_tap(end+1) = tap_time;
            runner.full_stim_tap(end+1) = tap_time;
            
            flag = 0;
            turn = turn + 1;
            
            % 最終ターン判定
            if turn >= (runner.config.STAGE2 + runner.config.BUFFER*2)
                fprintf('INFO: 最終ターン(%d)到達。最後のタップをしてください\n', turn);
                
                % 最終タップ待機（1回だけメッセージ表示）
                fprintf('最後のタップ (Space) または終了 (Escape)\n');
                final_wait_start = posixtime(datetime('now'));
                
                while experiment_running
                    keys = get_all_recent_keys();
                    
                    if any(strcmp(keys, 'space'))
                        % メインループでの処理時刻（統一基準）
                        global experiment_clock_start
                        processing_time = posixtime(datetime('now')) - experiment_clock_start;

                        % 実際のキー押下時刻（キーハンドラーで記録）
                        global experiment_last_key_time
                        actual_key_time = experiment_last_key_time - experiment_clock_start;

                        % 遅延計算
                        key_delay = processing_time - actual_key_time;

                        % 実際のキー押下時刻を使用
                        final_time = actual_key_time;
                        runner.player_tap(end+1) = final_time;
                        runner.full_player_tap(end+1) = final_time;

                        % 最終タップ記録（音声再生なし）
                        fprintf('最終タップ: 実際=%.3fs, 処理=%.3fs, 遅延=%.3fs\n', ...
                            actual_key_time, processing_time, key_delay);
                        fprintf('実験完了！お疲れ様でした\n');
                        
                        success = true;
                        return;
                    elseif any(strcmp(keys, 'escape'))
                        fprintf('実験を終了しました\n');
                        return;
                    end
                    
                    % CPU負荷軽減とタイムアウト処理
                    pause(0.05);
                    if (posixtime(datetime('now')) - final_wait_start) > 30
                        fprintf('タイムアウトしました。実験を終了します\n');
                        return;
                    end
                end
                
                return;
            end
        end
        
        % プレイヤーのターン
        if flag == 0
            keys = get_all_recent_keys();
            if any(strcmp(keys, 'space'))
                % メインループでの処理時刻（統一基準）
                global experiment_clock_start
                processing_time = posixtime(datetime('now')) - experiment_clock_start;

                % 実際のキー押下時刻（キーハンドラーで記録）
                global experiment_last_key_time
                actual_key_time = experiment_last_key_time - experiment_clock_start;

                % 遅延計算
                key_delay = processing_time - actual_key_time;

                % 実際のキー押下時刻を使用
                tap_time = actual_key_time;
                runner.player_tap(end+1) = tap_time;
                runner.full_player_tap(end+1) = tap_time;

                % プレイヤータップ記録（音声再生なし）
                fprintf('[%d回目のプレイヤータップ] 実際=%.3fs, 処理=%.3fs, 遅延=%.3fs\n', ...
                    turn, actual_key_time, processing_time, key_delay);

                pause(0.1);

                % オリジナル準拠のstim_SE計算
                % Python: stim_SE[turn] = stim_tap[turn] - (player_tap[turn] + player_tap[turn+1])/2
                % MATLAB配列構造に合わせて修正
                if length(runner.stim_tap) >= 1 && length(runner.player_tap) >= 2
                    % 現在のstim_tapは最新追加分（今の機械音）
                    current_stim = runner.stim_tap(end);

                    % 前回と今回のplayer_tapの平均
                    prev_player = runner.player_tap(end-1);
                    curr_player = runner.player_tap(end);

                    % SE = 現在の機械音 - (前回 + 現在の人間タップ)/2
                    se = current_stim - (prev_player + curr_player) / 2;
                    runner.stim_se(end+1) = se;

                    fprintf('DEBUG: SE計算 = %.3f - (%.3f + %.3f)/2 = %.3f\n', ...
                        current_stim, prev_player, curr_player, se);
                else
                    se = 0.0;
                    runner.stim_se(end+1) = se;
                    fprintf('DEBUG: SE計算スキップ (データ不足)\n');
                end

                % モデル推論（オリジナル準拠）
                random_second = model_inference(runner.model, se);

                % デバッグログ記録
                runner.debug_count = runner.debug_count + 1;
                debug_entry = struct();
                debug_entry.turn = turn;
                debug_entry.se = se;
                debug_entry.model_output = random_second;
                debug_entry.timer_reset_time = actual_key_time;
                runner.debug_log{end+1} = debug_entry;

                fprintf('DEBUG[%d]: SE=%.3f -> model_output=%.3f, timer_reset=%.3f\n', ...
                    turn, se, random_second, debug_entry.timer_reset_time);

                % 次の刺激音時刻を設定（統一基準）
                next_stim_time = actual_key_time + random_second;
                flag = 1;
            end
            
            if any(strcmp(keys, 'escape'))
                return;
            end
        end
        
        % CPU負荷軽減 (0.01ms休憩 - 最高精度維持)
        pause(0.00001);
    end
end

function process_and_save_experiment_data(runner)
    % データ処理・保存（Stage1/Stage2分離対応）
    fprintf('INFO: データ分析開始 - 全刺激: %d回, 全プレイヤー: %d回\n', ...
        length(runner.full_stim_tap), length(runner.full_player_tap));

    % Stage1とStage2のデータ分離
    stage1_count = runner.config.STAGE1;

    % Stage1データ（同期タッピング - モデル学習には使用しない）
    if length(runner.full_stim_tap) >= stage1_count
        stage1_stim = runner.full_stim_tap(1:stage1_count);
        stage1_player = runner.full_player_tap(1:min(stage1_count, length(runner.full_player_tap)));

        fprintf('INFO: Stage1データ - 刺激: %d回, プレイヤー: %d回（同期タッピング）\n', ...
            length(stage1_stim), length(stage1_player));
    else
        stage1_stim = [];
        stage1_player = [];
    end

    % Stage2データ（協調交互タッピング - モデル学習用）
    if length(runner.full_stim_tap) > stage1_count
        stage2_stim = runner.full_stim_tap(stage1_count+1:end);
        stage2_player_start = min(stage1_count+1, length(runner.full_player_tap));
        stage2_player = runner.full_player_tap(stage2_player_start:end);

        fprintf('INFO: Stage2データ - 刺激: %d回, プレイヤー: %d回（協調交互タッピング）\n', ...
            length(stage2_stim), length(stage2_player));
    else
        stage2_stim = [];
        stage2_player = [];
    end

    % Stage2データの長さ調整（分析用）
    if ~isempty(stage2_stim) && ~isempty(stage2_player)
        min_len = min(length(stage2_stim), length(stage2_player));
        runner.stim_tap = stage2_stim(1:min_len);
        runner.player_tap = stage2_player(1:min_len);

        % バッファ除外（Stage2のみ）
        buffer_start = runner.config.BUFFER;
        if length(runner.stim_tap) > buffer_start
            runner.stim_tap = runner.stim_tap(buffer_start+1:end);
            runner.player_tap = runner.player_tap(buffer_start+1:end);
        end

        fprintf('INFO: 分析用Stage2データ（バッファ除外後）- %d回\n', length(runner.stim_tap));
    else
        runner.stim_tap = [];
        runner.player_tap = [];
        fprintf('WARNING: Stage2データが不足しています\n');
    end
    
    % 保存
    date_str = datestr(now, 'yyyymmdd');
    
    % データ保存ディレクトリ設定（フォールバック付き）
    if isfield(runner.config, 'DATA_DIR')
        data_dir = runner.config.DATA_DIR;
    else
        data_dir = '../data/raw';  % フォールバック
        fprintf('WARNING: DATA_DIRが見つからないためデフォルト値を使用: %s\n', data_dir);
    end
    
    experiment_dir = fullfile(data_dir, date_str, ...
        sprintf('%s_%s_%s', runner.user_id, runner.model_type, runner.serial_num));
    
    if ~exist(experiment_dir, 'dir')
        mkdir(experiment_dir);
    end
    
    % processed_taps.csv（Stage2データのみ - モデル学習用）
    if ~isempty(runner.stim_tap)
        processed_table = table(runner.stim_tap(:), runner.player_tap(:), ...
            'VariableNames', {'stim_tap', 'player_tap'});
        writetable(processed_table, fullfile(experiment_dir, 'processed_taps.csv'));
        fprintf('INFO: Stage2分析データ保存完了: processed_taps.csv\n');
    end

    % stage1_synchronous_taps.csv（Stage1同期タッピングデータ）
    if ~isempty(stage1_stim) && ~isempty(stage1_player)
        % 長さ調整
        min_len_stage1 = min(length(stage1_stim), length(stage1_player));
        stage1_table = table(stage1_stim(1:min_len_stage1)', stage1_player(1:min_len_stage1)', ...
            'VariableNames', {'stim_tap', 'player_tap'});
        writetable(stage1_table, fullfile(experiment_dir, 'stage1_synchronous_taps.csv'));
        fprintf('INFO: Stage1同期データ保存完了: stage1_synchronous_taps.csv\n');
    end

    % stage2_alternating_taps.csv（Stage2交互タッピング生データ）
    if ~isempty(stage2_stim) && ~isempty(stage2_player)
        % 長さ調整
        min_len_stage2 = min(length(stage2_stim), length(stage2_player));
        stage2_table = table(stage2_stim(1:min_len_stage2)', stage2_player(1:min_len_stage2)', ...
            'VariableNames', {'stim_tap', 'player_tap'});
        writetable(stage2_table, fullfile(experiment_dir, 'stage2_alternating_taps.csv'));
        fprintf('INFO: Stage2生データ保存完了: stage2_alternating_taps.csv\n');
    end

    % debug_log.csv - デバッグ情報保存
    if ~isempty(runner.debug_log)
        debug_turns = [];
        debug_ses = [];
        debug_model_outputs = [];
        debug_timer_resets = [];

        for i = 1:length(runner.debug_log)
            entry = runner.debug_log{i};
            debug_turns(end+1) = entry.turn;
            debug_ses(end+1) = entry.se;
            debug_model_outputs(end+1) = entry.model_output;
            debug_timer_resets(end+1) = entry.timer_reset_time;
        end

        debug_table = table(debug_turns(:), debug_ses(:), debug_model_outputs(:), debug_timer_resets(:), ...
            'VariableNames', {'turn', 'se', 'model_output', 'timer_reset_time'});
        writetable(debug_table, fullfile(experiment_dir, 'debug_log.csv'));
        fprintf('INFO: デバッグログ保存完了: debug_log.csv\n');
    end
    
    % raw_taps.csv（配列長調整付き）
    if ~isempty(runner.full_stim_tap) && ~isempty(runner.full_player_tap)
        % 配列長を統一
        min_len_raw = min(length(runner.full_stim_tap), length(runner.full_player_tap));
        raw_stim = runner.full_stim_tap(1:min_len_raw);
        raw_player = runner.full_player_tap(1:min_len_raw);

        raw_table = table(raw_stim(:), raw_player(:), ...
            'VariableNames', {'stim_tap', 'player_tap'});
        writetable(raw_table, fullfile(experiment_dir, 'raw_taps.csv'));
        fprintf('INFO: 生データ保存完了: raw_taps.csv (長さ調整: %d回)\n', min_len_raw);
    end
    
    fprintf('INFO: データ保存完了: %s\n', experiment_dir);
end

% 必要なハンドラ関数
function experiment_key_press_handler(~, event)
    % 最適化版キー入力ハンドラ（グローバル変数使用）
    global experiment_key_pressed experiment_last_key_time experiment_last_key_type

    experiment_key_pressed = true;
    experiment_last_key_time = posixtime(datetime('now'));
    experiment_last_key_type = event.Key;
end

function experiment_window_close_handler(~, ~)
    assignin('base', 'experiment_running', false);
end

function keys = get_all_recent_keys()
    % 最適化版キー取得関数（グローバル変数使用）
    global experiment_key_pressed experiment_last_key_type

    keys = {};
    if experiment_key_pressed
        if ~isempty(experiment_last_key_type)
            keys{end+1} = experiment_last_key_type;
        end
        experiment_key_pressed = false; % リセット
        experiment_last_key_type = '';
    end
end

function wait_for_space_key()
    fprintf('準備ができたらSpaceキーを押してください\n');
    
    while true
        keys = get_all_recent_keys();
        if any(strcmp(keys, 'space'))
            break;
        elseif any(strcmp(keys, 'escape'))
            error('実験が中止されました');
        end
        pause(0.05);
    end
    
    fprintf('開始! メトロノームのリズムに交互にタップしてください\n');
end

function runner = play_stim_sound(runner)
    % PsychPortAudio高精度刺激音再生

    try
        play_stim_sound_ptb(runner.audio_system);
    catch ME
        fprintf('WARNING: PTB刺激音再生失敗: %s\n', ME.message);
    end
end

function runner = play_player_sound(runner)
    % PsychPortAudio高精度プレイヤー音再生

    try
        play_player_sound_ptb(runner.audio_system);
    catch ME
        fprintf('WARNING: PTBプレイヤー音再生失敗: %s\n', ME.message);
    end
end

% 互換性のためのラッパー関数
function runner = play_optimized_sound(runner)
    runner = play_stim_sound(runner);
end

% PsychPortAudio高精度音声システム関数群
function audio_system = initialize_ptb_audio_system()
    fprintf('=== PsychPortAudio高精度音声システム初期化 ===\n');
    try
        InitializePsychSound(1);
        fprintf('✅ PsychPortAudio初期化完了\n');

        assets_dir = pwd;  % ルートディレクトリ
        stim_path = fullfile(assets_dir, 'assets', 'sounds', 'stim_beat_optimized.wav');
        player_path = fullfile(assets_dir, 'assets', 'sounds', 'player_beat_optimized.wav');

        [stim_data, fs_stim] = audioread(stim_path);
        [player_data, fs_player] = audioread(player_path);

        fprintf('✅ 音声ファイル読み込み完了\n');

        reqlatencyclass = 2;
        freq = fs_stim;
        nchannels = 1;

        stim_handle = PsychPortAudio('Open', [], 1, reqlatencyclass, freq, nchannels);
        player_handle = PsychPortAudio('Open', [], 1, reqlatencyclass, freq, nchannels);

        fprintf('✅ PsychPortAudioハンドル作成完了\n');

        PsychPortAudio('FillBuffer', stim_handle, stim_data(:,1)');
        PsychPortAudio('FillBuffer', player_handle, player_data(:,1)');

        fprintf('✅ 音声バッファ事前ロード完了\n');

        audio_system = struct();
        audio_system.stim_handle = stim_handle;
        audio_system.player_handle = player_handle;
        audio_system.stim_data = stim_data(:,1)';
        audio_system.player_data = player_data(:,1)';
        audio_system.fs = freq;
        audio_system.initialized = true;

        fprintf('=== PsychPortAudio高精度音声システム準備完了 ===\n');
    catch ME
        fprintf('❌ PsychPortAudio初期化エラー: %s\n', ME.message);
        audio_system = [];
    end
end

function play_stim_sound_ptb(audio_system)
    try
        PsychPortAudio('FillBuffer', audio_system.stim_handle, audio_system.stim_data);
        PsychPortAudio('Start', audio_system.stim_handle, 1, 0, 0);
    catch ME
        fprintf('ERROR: PTB刺激音再生失敗: %s\n', ME.message);
    end
end

function play_player_sound_ptb(audio_system)
    try
        PsychPortAudio('FillBuffer', audio_system.player_handle, audio_system.player_data);
        PsychPortAudio('Start', audio_system.player_handle, 1, 0, 0);
    catch ME
        fprintf('ERROR: PTBプレイヤー音再生失敗: %s\n', ME.message);
    end
end

function cleanup_ptb_audio(audio_system)
    if isempty(audio_system) || ~audio_system.initialized
        return;
    end
    try
        PsychPortAudio('Close', audio_system.stim_handle);
        PsychPortAudio('Close', audio_system.player_handle);
        fprintf('✅ PsychPortAudioリソース解放完了\n');
    catch ME
        fprintf('⚠️ リソース解放警告: %s\n', ME.message);
    end
end

function cleanup_all_resources(runner)
    global experiment_running experiment_key_buffer
    global experiment_key_pressed experiment_last_key_time experiment_last_key_type
    global experiment_clock_start

    experiment_running = false;

    if isfield(runner, 'audio_system') && ~isempty(runner.audio_system)
        cleanup_ptb_audio(runner.audio_system);
    end

    if isfield(runner, 'input_fig') && isvalid(runner.input_fig)
        delete(runner.input_fig);
    end

    clear global experiment_key_buffer experiment_running;
    clear global experiment_key_pressed experiment_last_key_time experiment_last_key_type;
    clear global experiment_clock_start;
end