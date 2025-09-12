%% キーボード入力処理システム
% リアルタイムキーボード入力の検出と処理
% PsychoPy event.getKeys()相当の機能を提供

classdef InputHandlerMATLAB < handle
    properties (Access = private)
        config              % 実験設定
        timing_controller   % タイミング制御システム
        psychtoolbox_available % Psychtoolbox利用可能性
        
        % 入力状態管理
        last_key_state      % 前回のキー状態
        key_press_history   % キー押下履歴
        input_mode          % 入力モード
        
        % パフォーマンス監視
        response_times      % 応答時間履歴
        polling_stats       % ポーリング統計
    end
    
    methods (Access = public)
        function obj = InputHandlerMATLAB(config)
            % 入力処理システム初期化
            obj.config = config;
            obj.timing_controller = TimingControllerMATLAB(config);
            
            % Psychtoolbox利用可能性チェック
            obj.psychtoolbox_available = obj.checkPsychtoolbox();
            
            % 入力システム初期化
            obj.initializeInputSystem();
            
            % 状態初期化
            obj.last_key_state = false;
            obj.key_press_history = [];
            obj.response_times = [];
            obj.polling_stats = struct();
            obj.polling_stats.total_polls = 0;
            obj.polling_stats.successful_detections = 0;
            obj.polling_stats.average_poll_rate = 0;
            
            fprintf('InputHandler初期化完了 (PTB: %s, モード: %s)\n', ...
                logical2str(obj.psychtoolbox_available), obj.input_mode);
        end
        
        function tap_time = waitForTap(obj, timeout)
            % タップ待機 (タイムアウト付き)
            % timeout: タイムアウト時間 (秒)
            % 戻り値: タップ時刻 (タイムアウト時はNaN)
            
            if nargin < 2
                timeout = 3.0; % デフォルト3秒
            end
            
            start_time = obj.timing_controller.getCurrentTime();
            tap_time = NaN;
            poll_count = 0;
            
            % 入力方式に応じた処理
            if obj.psychtoolbox_available
                tap_time = obj.waitForTapPTB(start_time, timeout);
            else
                tap_time = obj.waitForTapFallback(start_time, timeout);
            end
            
            % 統計更新
            if ~isnan(tap_time)
                response_time = tap_time - start_time;
                obj.response_times(end+1) = response_time;
                obj.polling_stats.successful_detections = obj.polling_stats.successful_detections + 1;
            end
        end
        
        function is_pressed = checkKeyPress(obj, key_name)
            % 単発キー押下チェック
            % key_name: チェックするキー名 (デフォルト: 'space')
            % 戻り値: キーが押されたかどうか
            
            if nargin < 2
                key_name = 'space';
            end
            
            is_pressed = false;
            
            if obj.psychtoolbox_available
                is_pressed = obj.checkKeyPressPTB(key_name);
            else
                is_pressed = obj.checkKeyPressFallback(key_name);
            end
            
            obj.polling_stats.total_polls = obj.polling_stats.total_polls + 1;
        end
        
        function pressed_keys = getAllPressedKeys(obj)
            % 現在押されているすべてのキー取得
            % 戻り値: 押下キーのセル配列
            
            pressed_keys = {};
            
            if obj.psychtoolbox_available
                pressed_keys = obj.getAllPressedKeysPTB();
            else
                pressed_keys = obj.getAllPressedKeysFallback();
            end
        end
        
        function flushInputBuffer(obj)
            % 入力バッファクリア
            if obj.psychtoolbox_available
                % PTBの場合
                while KbCheck
                    % バッファクリア
                end
            else
                % フォールバックの場合
                % 特別な処理は不要
            end
            
            obj.last_key_state = false;
        end
        
        function stats = getInputStats(obj)
            % 入力統計取得
            stats = obj.polling_stats;
            
            if length(obj.response_times) > 0
                stats.mean_response_time = mean(obj.response_times);
                stats.std_response_time = std(obj.response_times);
                stats.min_response_time = min(obj.response_times);
                stats.max_response_time = max(obj.response_times);
            else
                stats.mean_response_time = NaN;
                stats.std_response_time = NaN;
                stats.min_response_time = NaN;
                stats.max_response_time = NaN;
            end
            
            if stats.total_polls > 0
                stats.detection_rate = stats.successful_detections / stats.total_polls;
            else
                stats.detection_rate = 0;
            end
            
            stats.total_responses = length(obj.response_times);
        end
        
        function printStats(obj)
            % 統計情報表示
            stats = obj.getInputStats();
            
            fprintf('\n=== 入力処理統計 ===\n');
            fprintf('入力方式: %s\n', obj.input_mode);
            fprintf('総ポーリング回数: %d\n', stats.total_polls);
            fprintf('成功検出回数: %d\n', stats.successful_detections);
            fprintf('検出率: %.2f%%\n', stats.detection_rate * 100);
            fprintf('総応答回数: %d\n', stats.total_responses);
            
            if ~isnan(stats.mean_response_time)
                fprintf('平均応答時間: %.3f秒\n', stats.mean_response_time);
                fprintf('応答時間範囲: %.3f - %.3f秒\n', ...
                    stats.min_response_time, stats.max_response_time);
            end
            fprintf('==================\n');
        end
    end
    
    methods (Access = private)
        function available = checkPsychtoolbox(obj)
            % Psychtoolbox利用可能性チェック
            try
                KbCheck;
                available = true;
            catch
                available = false;
            end
        end
        
        function initializeInputSystem(obj)
            % 入力システム初期化
            if obj.psychtoolbox_available
                obj.input_mode = 'Psychtoolbox';
                obj.initializePTB();
            else
                obj.input_mode = 'Fallback';
                obj.initializeFallback();
            end
        end
        
        function initializePTB(obj)
            % Psychtoolbox入力システム初期化
            try
                % キーボードの初期化
                KbName('UnifyKeyNames');
                
                % 初期状態クリア
                obj.flushInputBuffer();
                
                fprintf('Psychtoolbox入力システム初期化完了\n');
            catch ME
                fprintf('Psychtoolbox初期化エラー: %s\n', ME.message);
                obj.psychtoolbox_available = false;
                obj.input_mode = 'Fallback';
                obj.initializeFallback();
            end
        end
        
        function initializeFallback(obj)
            % フォールバック入力システム初期化
            fprintf('フォールバック入力システムを使用\n');
            fprintf('注意: リアルタイム入力検出は制限されます\n');
        end
        
        function tap_time = waitForTapPTB(obj, start_time, timeout)
            % Psychtoolboxを使用したタップ待機
            tap_time = NaN;
            poll_interval = 0.001; % 1msポーリング間隔
            
            while ~obj.timing_controller.checkTimeout(start_time, timeout)
                [keyIsDown, ~, keyCode] = KbCheck;
                space_pressed = keyCode(KbName('space'));
                
                % エッジ検出 (押下瞬間のみ)
                if space_pressed && ~obj.last_key_state
                    tap_time = obj.timing_controller.getCurrentTime();
                    obj.last_key_state = true;
                    break;
                elseif ~space_pressed && obj.last_key_state
                    obj.last_key_state = false;
                end
                
                % ポーリング間隔待機
                pause(poll_interval);
                obj.polling_stats.total_polls = obj.polling_stats.total_polls + 1;
            end
        end
        
        function tap_time = waitForTapFallback(obj, start_time, timeout)
            % フォールバック方式でのタップ待機
            tap_time = NaN;
            
            fprintf('スペースキーを押してください (%.1f秒以内)...\n', timeout);
            
            try
                % input()を使用したブロッキング入力
                tic;
                user_input = input('', 's');
                elapsed = toc;
                
                if elapsed <= timeout
                    tap_time = start_time + elapsed;
                else
                    fprintf('タイムアウトしました\n');
                end
                
            catch
                fprintf('入力エラーが発生しました\n');
            end
        end
        
        function is_pressed = checkKeyPressPTB(obj, key_name)
            % Psychtoolboxキー押下チェック
            try
                [keyIsDown, ~, keyCode] = KbCheck;
                is_pressed = keyCode(KbName(key_name));
            catch
                is_pressed = false;
            end
        end
        
        function is_pressed = checkKeyPressFallback(obj, key_name)
            % フォールバック方式キー押下チェック
            % 注意: リアルタイム検出は不可能
            is_pressed = false;
            fprintf('フォールバック入力: リアルタイム検出不可\n');
        end
        
        function pressed_keys = getAllPressedKeysPTB(obj)
            % Psychtoolbox全押下キー取得
            pressed_keys = {};
            
            try
                [keyIsDown, ~, keyCode] = KbCheck;
                if keyIsDown
                    key_indices = find(keyCode);
                    for i = 1:length(key_indices)
                        key_name = KbName(key_indices(i));
                        pressed_keys{end+1} = key_name;
                    end
                end
            catch
                % エラー時は空配列を返す
            end
        end
        
        function pressed_keys = getAllPressedKeysFallback(obj)
            % フォールバック方式全押下キー取得
            pressed_keys = {};
            fprintf('フォールバック入力: 全キー検出不可\n');
        end
    end
    
    methods (Access = public, Static)
        function demo()
            % InputHandlerデモンストレーション
            fprintf('=== InputHandler デモンストレーション ===\n');
            
            % テスト設定
            config = struct();
            config.high_precision_timing = true;
            
            % 入力処理システム作成
            input_handler = InputHandlerMATLAB(config);
            
            % 基本機能テスト
            fprintf('\n1. 基本入力機能テスト\n');
            fprintf('5秒以内にスペースキーを3回押してください\n');
            
            tap_times = [];
            for i = 1:3
                fprintf('タップ %d/3 待機中...\n', i);
                tap_time = input_handler.waitForTap(5.0);
                
                if ~isnan(tap_time)
                    tap_times(end+1) = tap_time;
                    fprintf('  タップ検出: %.3f秒\n', tap_time);
                else
                    fprintf('  タイムアウト\n');
                end
            end
            
            % 間隔分析
            if length(tap_times) >= 2
                intervals = diff(tap_times);
                fprintf('\nタップ間隔:\n');
                for i = 1:length(intervals)
                    fprintf('  間隔 %d: %.3f秒\n', i, intervals(i));
                end
                fprintf('平均間隔: %.3f秒\n', mean(intervals));
            end
            
            % 統計表示
            fprintf('\n2. 統計情報\n');
            input_handler.printStats();
            
            fprintf('=== InputHandler デモ完了 ===\n');
        end
        
        function accuracyTest()
            % 入力精度テスト
            fprintf('=== InputHandler 精度テスト ===\n');
            
            config = struct();
            config.high_precision_timing = true;
            input_handler = InputHandlerMATLAB(config);
            
            if ~input_handler.psychtoolbox_available
                fprintf('Psychtoolbox未利用可能 - 精度テスト制限あり\n');
                return;
            end
            
            % メトロノームタッピングテスト
            fprintf('\nメトロノームタッピング精度テスト\n');
            fprintf('600ms間隔の音に合わせてスペースキーを押してください (10回)\n');
            
            num_beats = 10;
            metronome_interval = 0.6; % 600ms
            
            % 簡易ビープ音生成
            fs = 8000;
            duration = 0.1;
            t = 0:1/fs:duration;
            beep_sound = sin(2*pi*1000*t);
            
            beat_times = [];
            tap_times = [];
            
            start_time = input_handler.timing_controller.getCurrentTime();
            
            for beat = 1:num_beats
                % ビート時刻
                beat_time = start_time + (beat-1) * metronome_interval;
                beat_times(end+1) = beat_time;
                
                % ビート音再生
                input_handler.timing_controller.waitUntil(beat_time);
                sound(beep_sound, fs);
                
                % タップ待機 (次のビートまで)
                if beat < num_beats
                    next_beat_time = start_time + beat * metronome_interval;
                    tap_time = input_handler.waitForTap(metronome_interval * 1.2);
                else
                    tap_time = input_handler.waitForTap(metronome_interval);
                end
                
                if ~isnan(tap_time)
                    tap_times(end+1) = tap_time;
                    sync_error = (tap_time - beat_time) * 1000; % ms
                    fprintf('  ビート %d: 同期エラー %+.1fms\n', beat, sync_error);
                else
                    fprintf('  ビート %d: タップなし\n', beat);
                end
            end
            
            % 精度分析
            if length(tap_times) >= length(beat_times) * 0.5
                sync_errors = [];
                for i = 1:min(length(tap_times), length(beat_times))
                    sync_errors(end+1) = (tap_times(i) - beat_times(i)) * 1000;
                end
                
                fprintf('\n精度分析結果:\n');
                fprintf('検出率: %.1f%% (%d/%d)\n', ...
                    length(tap_times)/num_beats*100, length(tap_times), num_beats);
                fprintf('平均同期エラー: %+.1fms\n', mean(sync_errors));
                fprintf('同期エラー標準偏差: %.1fms\n', std(sync_errors));
                fprintf('同期エラー範囲: %.1f - %.1fms\n', ...
                    min(sync_errors), max(sync_errors));
            else
                fprintf('十分なデータが得られませんでした\n');
            end
            
            fprintf('=== 精度テスト完了 ===\n');
        end
    end
end

function str = logical2str(logical_val)
    if logical_val
        str = '利用可能';
    else
        str = '利用不可';
    end
end