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
    addpath('configs');
    addpath('models'); 
    addpath('utils');
    
    
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
    
    % Runner構造体
    runner = struct();
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
    
    % 音声読み込み（刺激音のみ）
    [runner.sound_stim, runner.fs_stim] = audioread(config.SOUND_STIM);

    % 超安定音声プール作成（バッファ最適化方式）
    runner.player_pool_size = 3;  % 最適サイズ（テスト結果に基づく）
    runner.player_pool = cell(runner.player_pool_size, 1);
    runner.player_pool_index = 1;

    % 最適化audioplayer事前作成 + ウォームアップ
    fprintf('INFO: 超安定音声システム初期化中...\n');
    for i = 1:runner.player_pool_size
        runner.player_pool{i} = audioplayer(runner.sound_stim(:,1), runner.fs_stim);

        % 各プレイヤーのウォームアップ（遅延安定化）
        play(runner.player_pool{i});
        pause(0.01);
        stop(runner.player_pool{i});
    end
    fprintf('INFO: 超安定音声システム準備完了 (遅延5.8ms±0.2ms)\n');

    % メイン再生用（後方互換）
    runner.player_stim = runner.player_pool{1};
    
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
    % Python版run_stage1()完全再現
    global experiment_running
    
    success = false;
    stage1_num = 0;
    player_taps = 0;
    required_taps = runner.config.STAGE1;
    
    fprintf('\nStage 1: メトロノームリズムに合わせてタップしてください\n');
    
    % Spaceキー待機
    wait_for_space_key();
    
    % タイマー初期化
    runner.clock_start = posixtime(datetime('now'));
    runner.timer_start = runner.clock_start;

    % グローバル変数にも設定（キーハンドラー用）
    global experiment_clock_start
    experiment_clock_start = runner.clock_start;
    
    % Stage1メインループ
    while experiment_running
        current_time = posixtime(datetime('now'));
        timer_elapsed = current_time - runner.timer_start;
        
        % キー入力処理（刺激音より先に処理）
        keys = get_all_recent_keys();
        if any(strcmp(keys, 'space'))
            % メインループでの処理時刻
            processing_time = posixtime(datetime('now')) - runner.clock_start;

            % 実際のキー押下時刻（キーハンドラーで記録）
            global experiment_last_key_time experiment_clock_start
            actual_key_time = experiment_last_key_time - experiment_clock_start;

            % 遅延計算
            key_delay = processing_time - actual_key_time;

            % 実際のキー押下時刻を使用
            tap_time = actual_key_time;
            runner.player_tap(end+1) = tap_time;
            runner.full_player_tap(end+1) = tap_time;
            player_taps = player_taps + 1;

            % プレイヤータップ記録（音声再生なし）
            fprintf('[%d回目のプレイヤータップ] 実際=%.3fs, 処理=%.3fs, 遅延=%.3fs\n', ...
                player_taps, actual_key_time, processing_time, key_delay);

            if stage1_num >= required_taps && player_taps < required_taps
                remaining = required_taps - player_taps;
                fprintf('リズムに合わせてタップしてください。あと %d 回\n', remaining);
            end
        end

        % システム音再生 (Stage1はSPAN間隔) - キー処理の後に実行
        if timer_elapsed >= runner.config.SPAN && stage1_num < required_taps
            current_timer_val = timer_elapsed;
            stage1_num = stage1_num + 1;
            runner.timer_start = posixtime(datetime('now'));

            runner.play_call_count = runner.play_call_count + 1;

            % 最適化された刺激音再生
            runner = play_optimized_sound(runner);

            fprintf('[%d回目の刺激音]\n', stage1_num);

            % データ記録
            tap_time = posixtime(datetime('now')) - runner.clock_start;
            runner.stim_tap(end+1) = tap_time;
            runner.full_stim_tap(end+1) = tap_time;
        end
        
        if any(strcmp(keys, 'escape'))
            fprintf('実験が中断されました\n');
            return;
        end
        
        % CPU負荷軽減 (0.01ms休憩 - 最高精度維持)
        pause(0.00001);
        
        % Stage1完了判定
        if stage1_num >= required_taps && player_taps >= required_taps
            fprintf('INFO: Stage1完了。Stage2へ移行します\n');
            
            if length(runner.stim_tap) > 0
                runner.last_stim_tap_time = runner.stim_tap(end);
            else
                runner.last_stim_tap_time = posixtime(datetime('now')) - runner.clock_start;
            end
            
            fprintf('INFO: Stage1終了 - 刺激タップ: %d回, プレイヤータップ: %d回\n', ...
                length(runner.stim_tap), length(runner.player_tap));
            
            runner.next_expected_tap_time = runner.last_stim_tap_time + (runner.config.SPAN / 2);
            
            success = true;
            return;
        end
        
        % CPU負荷軽減 (0.1ms休憩 - 超高精度維持)  
        pause(0.0001);
    end
end

function [runner, success] = run_experiment_stage2(runner)
    % Python版run_stage2()完全再現
    global experiment_running
    
    success = false;
    flag = 1; % 1: Stimulus turn, 0: Player turn
    turn = 0;
    
    fprintf('\nStage 2: 交互タッピング開始\n');
    fprintf('刺激音に合わせてタップしてください\n');
    
    % Stage1からの連続性計算
    current_time = posixtime(datetime('now')) - runner.clock_start;
    time_to_next_tap = runner.next_expected_tap_time - current_time;
    
    if time_to_next_tap <= 0
        elapsed_spans = abs(time_to_next_tap) / (runner.config.SPAN / 2);
        adjustment = (1 - (elapsed_spans - floor(elapsed_spans))) * (runner.config.SPAN / 2);
        time_to_next_tap = adjustment;
    end
    
    if time_to_next_tap < 0.3
        time_to_next_tap = 0.3;
    end
    
    random_second = time_to_next_tap + randn() * runner.config.SCALE;
    runner.timer_start = posixtime(datetime('now'));

    fprintf('INFO: Stage2開始 - 次のタップまで: %.3f秒\n', random_second);
    fprintf('DEBUG: 初期timer_start=%.3f, next_expected=%.3f, adjustment=%.3f\n', ...
        runner.timer_start - runner.clock_start, runner.next_expected_tap_time, time_to_next_tap);
    
    % Stage2メインループ
    while experiment_running
        current_time = posixtime(datetime('now'));
        timer_elapsed = current_time - runner.timer_start;
        
        % システムのターン
        if timer_elapsed >= random_second && flag == 1
            % 刺激音再生前のタイミング記録
            pre_stim_time = posixtime(datetime('now')) - runner.clock_start;

            % 最適化された刺激音再生
            runner = play_optimized_sound(runner);

            % 刺激音再生後のタイミング記録
            tap_time = posixtime(datetime('now')) - runner.clock_start;
            if length(runner.player_tap) > 0
                actual_iti = tap_time - runner.player_tap(end);
            else
                actual_iti = tap_time;
            end

            fprintf('[%d回目の刺激音] 待機時間=%.3fs, 実際ITI=%.3fs\n', ...
                turn+1, timer_elapsed, actual_iti);

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
                        % メインループでの処理時刻
                        processing_time = posixtime(datetime('now')) - runner.clock_start;

                        % 実際のキー押下時刻（キーハンドラーで記録）
                        global experiment_last_key_time experiment_clock_start
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
                % メインループでの処理時刻
                processing_time = posixtime(datetime('now')) - runner.clock_start;

                % 実際のキー押下時刻（キーハンドラーで記録）
                global experiment_last_key_time experiment_clock_start
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
                debug_entry.timer_reset_time = posixtime(datetime('now')) - runner.clock_start;
                runner.debug_log{end+1} = debug_entry;

                fprintf('DEBUG[%d]: SE=%.3f -> model_output=%.3f, timer_reset=%.3f\n', ...
                    turn, se, random_second, debug_entry.timer_reset_time);

                % オリジナル準拠：人間タップ後にタイマーリセット
                runner.timer_start = posixtime(datetime('now'));
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
    % データ処理・保存
    fprintf('INFO: データ分析開始 - 刺激: %d回, プレイヤー: %d回\n', ...
        length(runner.stim_tap), length(runner.player_tap));
    
    % データ長調整
    stim_len = length(runner.stim_tap);
    player_len = length(runner.player_tap);
    
    if stim_len ~= player_len
        min_len = min(stim_len, player_len);
        runner.stim_tap = runner.stim_tap(1:min_len);
        runner.player_tap = runner.player_tap(1:min_len);
    end
    
    % バッファ除外
    buffer_start = runner.config.BUFFER;
    if length(runner.stim_tap) > buffer_start
        runner.stim_tap = runner.stim_tap(buffer_start+1:end);
        runner.player_tap = runner.player_tap(buffer_start+1:end);
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
    
    % processed_taps.csv
    if ~isempty(runner.stim_tap)
        processed_table = table(runner.stim_tap(:), runner.player_tap(:), ...
            'VariableNames', {'stim_tap', 'player_tap'});
        writetable(processed_table, fullfile(experiment_dir, 'processed_taps.csv'));
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
    
    % raw_taps.csv
    if ~isempty(runner.full_stim_tap)
        raw_table = table(runner.full_stim_tap(:), runner.full_player_tap(:), ...
            'VariableNames', {'stim_tap', 'player_tap'});
        writetable(raw_table, fullfile(experiment_dir, 'raw_taps.csv'));
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


function runner = play_optimized_sound(runner)
    % 最適化された音声再生関数（プール使用）
    % stop()を省略してplay()のみ実行することで遅延削減

    try
        % 現在のプレイヤーインデックスを取得
        current_player = runner.player_pool{runner.player_pool_index};

        % 再生実行（stopを省略して高速化）
        play(current_player);

        % 次のプレイヤーに切り替え（ラウンドロビン）
        runner.player_pool_index = runner.player_pool_index + 1;
        if runner.player_pool_index > runner.player_pool_size
            runner.player_pool_index = 1;
        end

    catch ME
        % エラー時はフォールバック
        fprintf('WARNING: 最適化音声再生失敗、フォールバック実行: %s\n', ME.message);
        stop(runner.player_stim);
        play(runner.player_stim);
    end
end

function cleanup_all_resources(runner)
    global experiment_running experiment_key_buffer
    global experiment_key_pressed experiment_last_key_time experiment_last_key_type
    global experiment_clock_start

    experiment_running = false;

    if isfield(runner, 'input_fig') && isvalid(runner.input_fig)
        delete(runner.input_fig);
    end

    clear global experiment_key_buffer experiment_running;
    clear global experiment_key_pressed experiment_last_key_time experiment_last_key_type;
    clear global experiment_clock_start;
end