%% 協調タッピング実験システム MATLAB実装
% メインクラス - 実験全体の制御とオーケストレーション
% 
% 対応するPython版: src/experiment/runner.py

classdef CooperativeTappingMATLAB < handle
    properties (Access = private)
        config                  % 実験設定
        audioWriter            % 音声出力デバイス
        model                  % 適応モデル (SEA/Bayes/BIB)
        dataCollector          % データ収集システム
        experimentState        % 実験状態管理
        timingController       % 高精度タイミング制御
        inputHandler           % キーボード入力処理
        
        % 実験データ
        tapTimes               % タップタイミング記録
        stimTimes              % 刺激タイミング記録
        syncErrors             % 同期エラー履歴
        stage                  % 現在のステージ (1 or 2)
        tapCount               % タップカウンター
        
        % 音声素材
        stimSound              % 刺激音データ
        playerSound            % プレイヤー音データ
        
        % フラグ
        isRunning              % 実験実行中フラグ
        isPaused               % 一時停止フラグ
        experimentStartTime    % 実験開始タイムスタンプ
    end
    
    methods (Access = public)
        function obj = CooperativeTappingMATLAB(model_type, varargin)
            % コンストラクタ
            % model_type: 'sea', 'bayes', 'bib'のいずれか
            % varargin: 追加設定パラメータ
            
            fprintf('協調タッピング実験システム初期化中...\n');
            
            % 設定読み込み
            obj.config = obj.loadConfiguration(model_type, varargin{:});
            
            % コンポーネント初期化
            obj.initializeAudioSystem();
            obj.initializeModel(model_type);
            obj.initializeDataCollector();
            obj.initializeTimingController();
            obj.initializeInputHandler();
            obj.loadAudioAssets();
            
            % 状態初期化
            obj.resetExperimentState();
            
            fprintf('初期化完了\n');
        end
        
        function runExperiment(obj)
            % メイン実験実行
            fprintf('=== 協調タッピング実験開始 ===\n');
            
            try
                % 実験前準備
                obj.prepareExperiment();
                
                % Stage 1: メトロノーム同期 (固定間隔)
                obj.runStage1();
                
                % Stage 1-2 間の移行
                obj.transitionToStage2();
                
                % Stage 2: 適応的協調タッピング
                obj.runStage2();
                
                % 実験完了処理
                obj.finalizeExperiment();
                
                fprintf('=== 実験正常完了 ===\n');
                
            catch ME
                fprintf('実験エラー: %s\n', ME.message);
                obj.handleExperimentError(ME);
                rethrow(ME);
            end
        end
        
        function results = getResults(obj)
            % 実験結果取得
            results = obj.dataCollector.getResults();
        end
        
        function saveResults(obj, output_dir)
            % 結果保存
            if nargin < 2
                output_dir = obj.config.output_directory;
            end
            obj.dataCollector.saveResults(output_dir);
        end
        
        function delete(obj)
            % デストラクタ - リソース解放
            obj.cleanup();
        end
    end
    
    methods (Access = private)
        function config = loadConfiguration(obj, model_type, varargin)
            % 設定ファイル読み込みと初期化
            
            % デフォルト設定
            config = struct();
            
            % 基本実験パラメータ
            config.model_type = model_type;
            config.span = 2.0;              % 基本間隔 (秒)
            config.stage1_count = 10;       % Stage1 タップ数
            config.stage2_count = 100;      % Stage2 タップ数
            config.buffer_taps = 5;         % バッファタップ数
            
            % 音声設定
            config.sample_rate = 48000;     % サンプリング周波数
            config.buffer_size = 64;        % 音声バッファサイズ
            config.audio_driver = 'Default'; % 音声ドライバー
            
            % ファイルパス
            config.assets_dir = fullfile('assets', 'sounds');
            config.stim_sound_file = fullfile(config.assets_dir, 'stim_beat.wav');
            config.player_sound_file = fullfile(config.assets_dir, 'player_beat.wav');
            
            % 出力設定
            timestamp = datestr(now, 'yyyymmdd_HHMMSS');
            config.output_directory = fullfile('data', 'raw', ...
                datestr(now, 'yyyymmdd'), sprintf('%s_%s', model_type, timestamp));
            
            % 追加パラメータ処理
            for i = 1:2:length(varargin)
                if i+1 <= length(varargin)
                    config.(varargin{i}) = varargin{i+1};
                end
            end
            
            % 出力ディレクトリ作成
            if ~exist(config.output_directory, 'dir')
                mkdir(config.output_directory);
            end
            
            fprintf('設定読み込み完了: %s model\n', config.model_type);
        end
        
        function initializeAudioSystem(obj)
            % 音声システム初期化
            fprintf('音声システム初期化中...\n');
            
            try
                % Audio System Toolbox デバイス作成
                obj.audioWriter = audioDeviceWriter(...
                    'SampleRate', obj.config.sample_rate, ...
                    'BufferSize', obj.config.buffer_size);
                
                % ASIO対応チェック
                if strcmp(obj.config.audio_driver, 'ASIO')
                    try
                        release(obj.audioWriter);
                        obj.audioWriter = audioDeviceWriter(...
                            'SampleRate', obj.config.sample_rate, ...
                            'BufferSize', obj.config.buffer_size, ...
                            'Driver', 'ASIO');
                        fprintf('ASIO ドライバー使用\n');
                    catch
                        fprintf('ASIO 利用不可 - デフォルトドライバー使用\n');
                    end
                end
                
                fprintf('音声システム初期化完了\n');
                
            catch ME
                error('音声システム初期化失敗: %s', ME.message);
            end
        end
        
        function initializeModel(obj, model_type)
            % 適応モデル初期化
            fprintf('%s モデル初期化中...\n', upper(model_type));
            
            switch lower(model_type)
                case 'sea'
                    obj.model = SEAModelMATLAB(obj.config);
                case 'bayes'
                    obj.model = BayesModelMATLAB(obj.config);
                case 'bib'
                    obj.model = BIBModelMATLAB(obj.config);
                otherwise
                    error('未サポートモデル: %s', model_type);
            end
            
            fprintf('%s モデル初期化完了\n', upper(model_type));
        end
        
        function initializeDataCollector(obj)
            % データ収集システム初期化
            obj.dataCollector = DataCollectorMATLAB(obj.config);
        end
        
        function initializeTimingController(obj)
            % 高精度タイミング制御初期化
            obj.timingController = TimingControllerMATLAB(obj.config);
        end
        
        function initializeInputHandler(obj)
            % キーボード入力処理初期化
            obj.inputHandler = InputHandlerMATLAB(obj.config);
        end
        
        function loadAudioAssets(obj)
            % 音声ファイル読み込み
            fprintf('音声ファイル読み込み中...\n');
            
            % 刺激音読み込み
            if exist(obj.config.stim_sound_file, 'file')
                [obj.stimSound, fs] = audioread(obj.config.stim_sound_file);
                if fs ~= obj.config.sample_rate
                    obj.stimSound = resample(obj.stimSound, obj.config.sample_rate, fs);
                end
            else
                % デフォルト音生成 (1kHz, 100ms)
                fprintf('刺激音ファイル未検出 - デフォルト音生成\n');
                obj.stimSound = obj.generateDefaultBeep(1000, 0.1);
            end
            
            % プレイヤー音読み込み
            if exist(obj.config.player_sound_file, 'file')
                [obj.playerSound, fs] = audioread(obj.config.player_sound_file);
                if fs ~= obj.config.sample_rate
                    obj.playerSound = resample(obj.playerSound, obj.config.sample_rate, fs);
                end
            else
                % デフォルト音生成 (800Hz, 100ms)
                fprintf('プレイヤー音ファイル未検出 - デフォルト音生成\n');
                obj.playerSound = obj.generateDefaultBeep(800, 0.1);
            end
            
            fprintf('音声ファイル読み込み完了\n');
        end
        
        function sound_data = generateDefaultBeep(obj, frequency, duration)
            % デフォルトビープ音生成
            t = 0:1/obj.config.sample_rate:duration;
            sound_data = sin(2*pi*frequency*t)' * 0.1; % 音量調整
        end
        
        function resetExperimentState(obj)
            % 実験状態リセット
            obj.tapTimes = [];
            obj.stimTimes = [];
            obj.syncErrors = [];
            obj.stage = 0;
            obj.tapCount = 0;
            obj.isRunning = false;
            obj.isPaused = false;
            obj.experimentStartTime = [];
        end
        
        function prepareExperiment(obj)
            % 実験前準備
            fprintf('実験準備中...\n');
            
            % 参加者指示表示
            obj.displayInstructions();
            
            % システム最適化
            obj.optimizeSystemPerformance();
            
            % 実験開始
            obj.isRunning = true;
            obj.experimentStartTime = posixtime(datetime('now', 'TimeZone', 'local'));
            
            fprintf('実験準備完了\n');
        end
        
        function displayInstructions(obj)
            % 参加者への指示表示
            fprintf('\n=== 実験説明 ===\n');
            fprintf('これから協調タッピング実験を開始します。\n\n');
            fprintf('Stage 1: メトロノームに合わせてスペースキーを押してください (10回)\n');
            fprintf('Stage 2: 音に合わせて交互にタッピングしてください (100回)\n\n');
            fprintf('準備ができたらEnterキーを押してください...\n');
            
            input('', 's'); % Enter待ち
        end
        
        function optimizeSystemPerformance(obj)
            % システムパフォーマンス最適化
            % MATLAB環境での処理優先度調整等
            fprintf('システム最適化実行中...\n');
            
            % ガベージコレクション実行
            java.lang.System.gc();
            
            % 警告一時無効化 (実験中の中断防止)
            warning('off', 'all');
            
            fprintf('システム最適化完了\n');
        end
        
        function runStage1(obj)
            % Stage 1: メトロノーム同期実行
            fprintf('\n--- Stage 1: メトロノーム同期開始 ---\n');
            
            obj.stage = 1;
            stage1_start = posixtime(datetime('now', 'TimeZone', 'local'));
            
            % メトロノーム間隔 (固定)
            interval = obj.config.span;
            next_stim_time = stage1_start + interval;
            
            for tap = 1:obj.config.stage1_count
                fprintf('Stage 1 タップ %d/%d\n', tap, obj.config.stage1_count);
                
                % 刺激音タイミング待機
                obj.timingController.waitUntil(next_stim_time);
                
                % 刺激音再生
                stim_time = obj.playStimulus();
                obj.stimTimes(end+1) = stim_time;
                
                % 参加者タップ待機・検出
                tap_time = obj.waitForTap();
                if ~isnan(tap_time)
                    obj.tapTimes(end+1) = tap_time;
                    obj.tapCount = obj.tapCount + 1;
                    
                    % 同期エラー計算
                    sync_error = tap_time - stim_time;
                    obj.syncErrors(end+1) = sync_error;
                    
                    fprintf('  同期エラー: %+.3f秒\n', sync_error);
                end
                
                % 次刺激タイミング設定
                next_stim_time = stim_time + interval;
                
                % データ収集
                obj.dataCollector.recordTap(tap, 1, stim_time, tap_time, sync_error);
            end
            
            fprintf('--- Stage 1 完了 ---\n');
        end
        
        function transitionToStage2(obj)
            % Stage 1→2 移行処理
            fprintf('\n--- Stage 2 移行準備 ---\n');
            
            % モデル初期化 (Stage 1データ使用)
            if length(obj.syncErrors) > 0
                obj.model.initializeFromStage1(obj.syncErrors);
            end
            
            pause(1); % 移行時間
            fprintf('--- Stage 2 移行完了 ---\n');
        end
        
        function runStage2(obj)
            % Stage 2: 適応的協調タッピング実行
            fprintf('\n--- Stage 2: 適応的協調タッピング開始 ---\n');
            
            obj.stage = 2;
            
            % 初期間隔
            current_interval = obj.config.span;
            last_tap_time = obj.stimTimes(end); % Stage 1最後の刺激時刻
            
            for tap = 1:obj.config.stage2_count
                fprintf('Stage 2 タップ %d/%d\n', tap, obj.config.stage2_count);
                
                % 次の刺激タイミング予測
                next_stim_time = last_tap_time + current_interval;
                
                % 刺激音タイミング待機・再生
                obj.timingController.waitUntil(next_stim_time);
                stim_time = obj.playStimulus();
                obj.stimTimes(end+1) = stim_time;
                
                % 参加者タップ待機・検出
                tap_time = obj.waitForTap();
                if ~isnan(tap_time)
                    obj.tapTimes(end+1) = tap_time;
                    obj.tapCount = obj.tapCount + 1;
                    
                    % 同期エラー計算
                    sync_error = tap_time - stim_time;
                    obj.syncErrors(end+1) = sync_error;
                    
                    % モデル更新・次間隔予測
                    obj.model.update(sync_error);
                    current_interval = obj.model.predictNextInterval();
                    
                    fprintf('  同期エラー: %+.3f秒, 次間隔: %.3f秒\n', ...
                        sync_error, current_interval);
                    
                    last_tap_time = tap_time;
                    
                    % データ収集
                    obj.dataCollector.recordTap(tap, 2, stim_time, tap_time, sync_error);
                end
            end
            
            fprintf('--- Stage 2 完了 ---\n');
        end
        
        function stim_time = playStimulus(obj)
            % 刺激音再生（高精度タイミング）
            stim_time = posixtime(datetime('now', 'TimeZone', 'local'));
            obj.audioWriter(obj.stimSound);
        end
        
        function tap_time = waitForTap(obj)
            % 参加者タップ待機（タイムアウト付き）
            timeout = 3.0; % 3秒タイムアウト
            tap_time = obj.inputHandler.waitForTap(timeout);
        end
        
        function finalizeExperiment(obj)
            % 実験完了処理
            fprintf('\n実験完了処理中...\n');
            
            % 最終データ処理
            obj.dataCollector.finalizeData();
            
            % 結果自動保存
            obj.saveResults();
            
            % システム設定復元
            warning('on', 'all');
            
            obj.isRunning = false;
            
            fprintf('実験完了処理終了\n');
        end
        
        function handleExperimentError(obj, ME)
            % 実験エラー処理
            fprintf('実験エラー処理中...\n');
            
            % 部分データ保存
            try
                obj.dataCollector.savePartialResults(obj.config.output_directory);
            catch
                fprintf('部分データ保存失敗\n');
            end
            
            % システム設定復元
            warning('on', 'all');
            
            obj.isRunning = false;
        end
        
        function cleanup(obj)
            % リソース解放
            if ~isempty(obj.audioWriter)
                release(obj.audioWriter);
            end
        end
    end
end