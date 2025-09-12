% グローバル変数宣言（スクリプトレベル）
global experiment_key_buffer experiment_running

% メイン実行
final_python_experiment_main();

function final_python_experiment_main()
    % main関数 - Python版の完全再現
    
    % グローバル変数初期化
    global experiment_key_buffer experiment_running
    experiment_key_buffer = {};
    experiment_running = true;
    
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
    
    % 設定
    config = struct();
    config.SPAN = 1.0;
    config.STAGE1 = 10;
    config.STAGE2 = 20;
    config.BUFFER = 2;
    config.SCALE = 0.1;
    config.SOUND_STIM = 'assets/sounds/stim_beat.wav';
    config.SOUND_PLAYER = 'assets/sounds/player_beat.wav';
    
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
    
    % データ初期化
    runner = reset_all_experiment_data(runner);
    
    % モデル初期化
    runner.model = create_experiment_model(model_type, config);
    
    % 音声読み込み
    [runner.sound_stim, runner.fs_stim] = audioread(config.SOUND_STIM);
    [runner.sound_player, runner.fs_player] = audioread(config.SOUND_PLAYER);
    
    % audioplayerオブジェクトを作成して滑らかな音声再生を実現
    runner.player_stim = audioplayer(runner.sound_stim(:,1), runner.fs_stim);
    runner.player_player = audioplayer(runner.sound_player(:,1), runner.fs_player);
    
    % 入力ウィンドウ作成
    runner.input_fig = create_experiment_input_window();
    
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

function model = create_experiment_model(model_type, config)
    % モデル作成
    model = struct();
    model.type = model_type;
    model.config = config;
    model.cumulative_se = 0;
    model.update_count = 0;
end

function fig = create_experiment_input_window()
    % 入力ウィンドウ作成
    fig = figure('Name', 'Cooperative Tapping', 'NumberTitle', 'off', ...
        'MenuBar', 'none', 'ToolBar', 'none', ...
        'Position', [100, 100, 500, 300], ...
        'KeyPressFcn', @experiment_key_press_handler, ...
        'CloseRequestFcn', @experiment_window_close_handler, ...
        'Color', [0.2, 0.2, 0.2]);
    
    % 表示テキスト
    axes('Position', [0, 0, 1, 1], 'Visible', 'off');
    text(0.5, 0.7, 'Python版協調タッピング実験', 'HorizontalAlignment', 'center', ...
        'FontSize', 16, 'Color', 'white', 'FontWeight', 'bold');
    text(0.5, 0.5, 'スペースキー: タップ', 'HorizontalAlignment', 'center', ...
        'FontSize', 12, 'Color', 'white');
    text(0.5, 0.3, 'Escapeキー: 実験中止', 'HorizontalAlignment', 'center', ...
        'FontSize', 12, 'Color', 'white');
    
    figure(fig);
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
    fprintf('準備ができたらSpaceキーを押してください\n');
    
    % Spaceキー待機
    wait_for_space_key_input();
    
    fprintf('開始! メトロノームのリズムに交互にタップしてください\n');
    
    % タイマー初期化
    runner.clock_start = posixtime(datetime('now'));
    runner.timer_start = runner.clock_start;
    
    % Stage1メインループ
    while experiment_running
        current_time = posixtime(datetime('now'));
        timer_elapsed = current_time - runner.timer_start;
        
        % システム音再生 (Stage1はSPANの2倍間隔)
        if timer_elapsed >= (runner.config.SPAN * 2) && stage1_num < required_taps
            current_timer_val = timer_elapsed;
            stage1_num = stage1_num + 1;
            runner.timer_start = posixtime(datetime('now'));
            
            runner.play_call_count = runner.play_call_count + 1;
            fprintf('DEBUG: Play Call #%d\n', runner.play_call_count);
            fprintf('DEBUG: Condition met. Timer val: %.4f, SPAN*2: %.4f\n', current_timer_val, runner.config.SPAN * 2);
            
            % 音声再生（前の音をリセットしてから再生）
            fprintf('DEBUG: Playing sound_stim.\n');
            stop(runner.player_stim);
            play(runner.player_stim);
            
            fprintf('[%d回目の刺激音]\n', stage1_num);
            
            % データ記録
            tap_time = posixtime(datetime('now')) - runner.clock_start;
            runner.stim_tap(end+1) = tap_time;
            runner.full_stim_tap(end+1) = tap_time;
        end
        
        % キー入力処理
        keys = get_all_recent_keys();
        if any(strcmp(keys, 'space'))
            tap_time = posixtime(datetime('now')) - runner.clock_start;
            runner.player_tap(end+1) = tap_time;
            runner.full_player_tap(end+1) = tap_time;
            player_taps = player_taps + 1;
            
            stop(runner.player_player);
            play(runner.player_player);
            fprintf('[%d回目のプレイヤータップ音]\n', player_taps);
            
            if stage1_num >= required_taps && player_taps < required_taps
                remaining = required_taps - player_taps;
                fprintf('リズムに合わせてタップしてください。あと %d 回\n', remaining);
            end
        end
        
        if any(strcmp(keys, 'escape'))
            fprintf('実験が中断されました\n');
            return;
        end
        
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
        
        pause(0.01);
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
    
    % Stage2メインループ
    while experiment_running
        current_time = posixtime(datetime('now'));
        timer_elapsed = current_time - runner.timer_start;
        
        % システムのターン
        if timer_elapsed >= random_second && flag == 1
            stop(runner.player_stim);
            play(runner.player_stim);
            fprintf('[%d回目の刺激音]\n', turn+1);
            
            tap_time = posixtime(datetime('now')) - runner.clock_start;
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
                        final_time = posixtime(datetime('now')) - runner.clock_start;
                        runner.player_tap(end+1) = final_time;
                        runner.full_player_tap(end+1) = final_time;
                        
                        stop(runner.player_player);
                        play(runner.player_player);
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
                tap_time = posixtime(datetime('now')) - runner.clock_start;
                runner.player_tap(end+1) = tap_time;
                runner.full_player_tap(end+1) = tap_time;
                
                stop(runner.player_player);
            play(runner.player_player);
                fprintf('[%d回目のプレイヤータップ音]\n', turn);
                
                pause(0.1);
                
                % 同期エラー計算
                if length(runner.player_tap) >= 2 && length(runner.stim_tap) > 0
                    se = runner.stim_tap(end) - mean(runner.player_tap(end-1:end));
                    runner.stim_se(end+1) = se;
                else
                    se = 0.0;
                    runner.stim_se(end+1) = se;
                end
                
                % モデル推論
                random_second = perform_experiment_model_inference(runner.model, se);
                
                runner.timer_start = posixtime(datetime('now'));
                flag = 1;
            end
            
            if any(strcmp(keys, 'escape'))
                return;
            end
        end
        
        pause(0.01);
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
    experiment_dir = fullfile('data/raw', date_str, ...
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
    
    % raw_taps.csv
    if ~isempty(runner.full_stim_tap)
        raw_table = table(runner.full_stim_tap(:), runner.full_player_tap(:), ...
            'VariableNames', {'stim_tap', 'player_tap'});
        writetable(raw_table, fullfile(experiment_dir, 'raw_taps.csv'));
    end
    
    fprintf('INFO: データ保存完了: %s\n', experiment_dir);
end

% キーボード処理関数群
function experiment_key_press_handler(~, event)
    global experiment_key_buffer
    experiment_key_buffer{end+1} = event.Key;
    if length(experiment_key_buffer) > 50
        experiment_key_buffer = experiment_key_buffer(end-25:end);
    end
end

function experiment_window_close_handler(~, ~)
    global experiment_running
    experiment_running = false;
end

function wait_for_space_key_input()
    while true
        keys = get_all_recent_keys();
        if any(strcmp(keys, 'space'))
            break;
        end
        pause(0.05);
    end
end

function keys = get_all_recent_keys()
    global experiment_key_buffer
    
    if isempty(experiment_key_buffer)
        keys = {};
    else
        keys = experiment_key_buffer;
        experiment_key_buffer = {};
    end
    
    drawnow;
end

function next_interval = perform_experiment_model_inference(model, se)
    % モデル推論
    switch lower(model.type)
        case 'sea'
            model.cumulative_se = model.cumulative_se + se;
            model.update_count = model.update_count + 1;
            avg_se = model.cumulative_se / model.update_count;
            next_interval = (model.config.SPAN / 2) - (avg_se * 0.5);
        otherwise
            next_interval = (model.config.SPAN / 2) + (se * 0.3);
    end
    
    next_interval = max(0.2, min(1.2, next_interval));
end

function cleanup_all_resources(runner)
    global experiment_running experiment_key_buffer
    
    experiment_running = false;
    
    if isfield(runner, 'input_fig') && isvalid(runner.input_fig)
        delete(runner.input_fig);
    end
    
    clear global experiment_key_buffer experiment_running;
end