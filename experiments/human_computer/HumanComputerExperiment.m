classdef HumanComputerExperiment < BaseExperiment
    % HumanComputerExperiment - 人間-コンピュータ協調タッピング実験クラス
    %
    % 人間参加者とコンピュータ（SEA/Bayesian/BIBモデル）による協調タッピング実験

    properties (Access = protected)
        experiment_type = 'human_computer'

        % 参加者情報
        participant_id
        model         % モデルインスタンス (SEAModel/BayesianModel/BIBModel)

        % オーディオバッファ
        metronome_buffer
        stim_buffer
        player_buffer

        % キー状態
        key_pressed = false
        last_key_time = 0

        % 実験設定
        experiment_config
    end

    methods (Access = public)
        function obj = HumanComputerExperiment()
            % HumanComputerExperiment コンストラクタ

            obj@BaseExperiment();

            fprintf('人間-コンピュータ協調タッピング実験\n');

            % 実験設定読み込み
            obj.load_experiment_config();

            % モデル選択と参加者情報入力
            obj.select_model_and_participant();

            % DataRecorder初期化
            obj.recorder = DataRecorder('human_computer', {obj.participant_id});
            obj.recorder.set_metadata('model_type', obj.model.model_type);

            % オーディオバッファ準備
            obj.prepare_audio_buffers();
        end

        function load_experiment_config(obj)
            % 実験設定読み込み

            % デフォルト設定
            config = struct();
            config.SPAN = 2.0;              % 目標サイクル期間（秒）
            config.SCALE = 0.02;            % ランダム変動スケール
            config.BAYES_N_HYPOTHESIS = 20; % ベイズ仮説数
            config.BIB_L_MEMORY = 1;        % BIBメモリ長
            config.DEBUG_MODEL = false;     % モデルデバッグ出力

            % configファイルが存在すれば読み込み
            if exist('experiments/configs/experiment_config.m', 'file')
                try
                    addpath('experiments/configs');
                    config = experiment_config();
                catch
                    warning('設定ファイル読み込み失敗。デフォルト設定を使用します。');
                end
            end

            obj.experiment_config = config;
        end

        function select_model_and_participant(obj)
            % モデル選択と参加者情報入力

            fprintf('\n=== モデル選択 ===\n');
            fprintf('  1. SEA (Synchronization Error Averaging)\n');
            fprintf('  2. Bayesian\n');
            fprintf('  3. BIB (Bayesian-Inverse Bayesian)\n');

            model_choice = input('モデル番号 (1-3): ');
            if isempty(model_choice) || model_choice < 1 || model_choice > 3
                model_choice = 1;
                fprintf('デフォルト: SEA\n');
            end

            % モデルインスタンス作成
            switch model_choice
                case 1
                    obj.model = SEAModel(obj.experiment_config);
                case 2
                    obj.model = BayesianModel(obj.experiment_config);
                case 3
                    obj.model = BIBModel(obj.experiment_config);
            end

            fprintf('選択されたモデル: %s\n', obj.model.model_type);

            % 参加者情報
            obj.participant_id = input('参加者ID (例: P001): ', 's');
            if isempty(obj.participant_id)
                obj.participant_id = 'anonymous';
            end

            fprintf('参加者ID: %s\n', obj.participant_id);
        end

        function prepare_audio_buffers(obj)
            % オーディオバッファ準備

            % 音声ファイル読み込み
            stim_sound = obj.audio.load_sound_file('assets/sounds/stim_beat_optimized.wav');
            player_sound = obj.audio.load_sound_file('assets/sounds/player_beat_optimized.wav');

            % バッファ作成（2チャンネルステレオ）
            obj.metronome_buffer = obj.audio.create_buffer(stim_sound, [1,1,0,0]);
            obj.stim_buffer = obj.audio.create_buffer(stim_sound, [1,1,0,0]);
            obj.player_buffer = obj.audio.create_buffer(player_sound, [1,1,0,0]);

            fprintf('✅ オーディオバッファ作成完了\n');
        end
    end

    methods (Access = protected)
        function key_press_handler(obj, src, event)
            % キー押下ハンドラ（オーバーライド）

            % 親クラスのハンドラ呼び出し
            key_press_handler@BaseExperiment(obj, src, event);

            % プレイヤーキー処理（Spaceキー）
            current_time = obj.timer.get_current_time();

            switch event.Key
                case 'space'
                    if current_time - obj.last_key_time > 0.05  % デバウンス
                        obj.key_pressed = true;
                        obj.last_key_time = current_time;
                    end
            end
        end

        function key_release_handler(obj, ~, event)
            % キーリリースハンドラ（オーバーライド）

            switch event.Key
                case 'space'
                    obj.key_pressed = false;
            end
        end

        function display_instructions(obj)
            % 実験説明（オーバーライド）

            obj.update_display({'人間-コンピュータ協調タッピング実験', '', ...
                sprintf('モデル: %s', obj.model.model_type), '', ...
                'Stage1: メトロノームに合わせてタップ', ...
                '        リズムを学習', '', ...
                'Stage2: コンピュータと交互にタップ', ...
                '        協調的にリズムを維持', '', ...
                'スペースキーでタップ', '', ...
                'スペースキーで開始'}, 'color', [0.2, 1.0, 0.2]);

            obj.wait_for_space();
        end

        function run_stage1(obj)
            % Stage1: 同期タッピングフェーズ（メトロノームと同期）

            obj.update_display('Stage 1: 同期タッピング', 'color', [1.0, 0.8, 0.3]);
            pause(1);

            % タイミングスタート
            obj.timer.start();

            % メトロノームスケジュール作成
            metronome_schedule = obj.timer.create_schedule(0.5, obj.target_interval, obj.stage1_beats);

            fprintf('Stage1開始: %dビートのメトロノーム同期\n', obj.stage1_beats);

            for i = 1:obj.stage1_beats
                if ~obj.is_running
                    return;
                end

                % メトロノーム音再生タイミングまで待機
                obj.timer.wait_until(metronome_schedule(i), @() obj.escape_pressed);

                % メトロノーム音再生
                metronome_time = obj.timer.record_event();
                obj.audio.play_buffer(obj.metronome_buffer, false);

                fprintf('[%d/%d] メトロノーム %.3fs\n', i, obj.stage1_beats, metronome_time);

                % データ記録
                obj.recorder.record_stage1_event(metronome_time, 'beat_number', i);

                % プレイヤータップ待機（次のメトロノームまで）
                if i < obj.stage1_beats
                    next_metronome_time = metronome_schedule(i+1);
                else
                    next_metronome_time = metronome_time + obj.target_interval;
                end

                obj.key_pressed = false;
                while obj.timer.get_elapsed_time() < next_metronome_time && obj.is_running
                    if obj.key_pressed
                        tap_time = obj.timer.record_event();
                        obj.audio.play_buffer(obj.player_buffer, false);
                        fprintf('       プレイヤータップ %.3fs\n', tap_time);

                        % SE計算（簡易版 - Stage1では記録のみ）
                        se = tap_time - metronome_time - obj.target_interval;

                        obj.recorder.record_stage1_event(tap_time, 'beat_number', i, 'is_tap', true, 'se', se);
                        obj.key_pressed = false;
                    end
                    pause(0.001);
                    drawnow;
                end
            end

            fprintf('Stage1完了\n');
        end

        function run_stage2(obj)
            % Stage2: 交互タッピングフェーズ（コンピュータと交互）

            obj.update_display('Stage 2: 交互タッピング', 'color', [1.0, 0.8, 0.3]);
            pause(1);

            fprintf('Stage2開始: コンピュータとの交互タッピング\n');

            current_turn = 'human';  % 'human' or 'computer'
            cycle_count = 0;
            last_tap_time = obj.timer.get_elapsed_time();

            % 人間の最初のタップ待機
            obj.update_display('スペースキーでタップ開始', 'color', [0.2, 1.0, 0.2]);

            while cycle_count < obj.stage2_cycles && obj.is_running
                if strcmp(current_turn, 'human')
                    % 人間のタップ待機
                    obj.key_pressed = false;
                    while ~obj.key_pressed && obj.is_running
                        pause(0.001);
                        drawnow;
                    end

                    if ~obj.is_running
                        return;
                    end

                    % タップ記録
                    tap_time = obj.timer.record_event();
                    obj.audio.play_buffer(obj.player_buffer, false);

                    % SE計算
                    se = tap_time - last_tap_time - obj.target_interval;

                    obj.recorder.record_stage2_tap('human', tap_time, 'cycle', cycle_count + 1, 'se', se);

                    fprintf('人間タップ: %.3fs (SE=%.3f, サイクル %d)\n', tap_time, se, cycle_count + 1);

                    last_tap_time = tap_time;
                    current_turn = 'computer';

                else
                    % コンピュータのタップ（モデル予測）
                    % 前回のSEを使用して次の間隔を予測
                    if cycle_count > 0
                        prev_tap = obj.recorder.data.stage2_data(end);
                        if isfield(prev_tap, 'se')
                            se = prev_tap.se;
                        else
                            se = 0;
                        end
                    else
                        se = 0;  % 初回
                    end

                    % モデルに次の間隔を予測させる
                    predicted_interval = obj.model.predict_next_interval(se);

                    % 待機
                    target_time = last_tap_time + predicted_interval;
                    obj.timer.wait_until(target_time - obj.timer.clock_start, @() obj.escape_pressed);

                    % コンピュータタップ
                    tap_time = obj.timer.record_event();
                    obj.audio.play_buffer(obj.stim_buffer, false);

                    % SE計算
                    computer_se = tap_time - last_tap_time - obj.target_interval;

                    obj.recorder.record_stage2_tap('computer', tap_time, 'cycle', cycle_count + 1, 'se', computer_se, 'predicted_interval', predicted_interval);

                    fprintf('コンピュータタップ: %.3fs (予測間隔=%.3f, SE=%.3f)\n', tap_time, predicted_interval, computer_se);

                    last_tap_time = tap_time;
                    current_turn = 'human';
                    cycle_count = cycle_count + 1;
                end
            end

            fprintf('Stage2完了: %dサイクル\n', cycle_count);
        end

        function display_results(obj)
            % 結果表示（オーバーライド）

            fprintf('\n========================================\n');
            fprintf('           実験結果\n');
            fprintf('========================================\n');

            fprintf('参加者ID: %s\n', obj.participant_id);
            fprintf('モデル: %s\n', obj.model.model_type);
            fprintf('モデル情報: %s\n', obj.model.get_model_info());

            % Stage1結果
            fprintf('\n--- Stage 1 ---\n');
            fprintf('メトロノームビート: %d回\n', obj.stage1_beats);

            % Stage2結果
            fprintf('\n--- Stage 2 ---\n');
            fprintf('総タップ数: %d回\n', length(obj.recorder.data.stage2_data));

            if ~isempty(obj.recorder.data.stage2_data)
                % SE統計
                taps = obj.recorder.data.stage2_data;
                se_values = [taps.se];

                fprintf('同期エラー統計:\n');
                fprintf('  平均SE: %.3f秒\n', mean(se_values));
                fprintf('  SE標準偏差: %.3f秒\n', std(se_values));
            end

            obj.update_display('実験完了！ありがとうございました', 'color', [0.2, 1.0, 0.2]);
        end
    end
end
