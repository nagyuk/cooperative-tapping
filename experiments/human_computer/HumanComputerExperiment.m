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

            % 注意: オーディオバッファ準備はinitialize_systems()で行う
        end

        function initialize_systems(obj)
            % システム初期化（オーバーライド）

            % 親クラスの初期化を呼ぶ（audio, timer, input_windowを作成）
            initialize_systems@BaseExperiment(obj);

            % オーディオバッファ準備（audioが初期化された後）
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
    end

    methods (Access = protected)
        function run_stage1(obj)
            % Stage1: 完全周期メトロノームフェーズ
            % 刺激音とプレイヤー音を1.0秒間隔で交互に自動再生（キー入力なし）

            % タイミングスタート
            obj.timer.start();

            % 音数の計算（刺激音とプレイヤー音が交互）
            % stage1_beats回のサイクル = beats*2回の音
            required_sounds = obj.stage1_beats * 2;  % 刺激音10回 + プレイヤー音10回 = 20音

            fprintf('Stage1開始: %d回の完全周期メトロノーム（刺激音%d回 + プレイヤー音%d回）\n', ...
                required_sounds, obj.stage1_beats, obj.stage1_beats);
            fprintf('刺激音→プレイヤー音を正確に1.0秒間隔で再生\n\n');

            % 音スケジュール作成（1.0秒間隔で交互、0.5秒オフセット）
            % sound_index=1: 0.5秒, 2: 1.5秒, 3: 2.5秒...
            sound_schedule = obj.timer.create_schedule(0.5, 1.0, required_sounds);

            for sound_index = 1:required_sounds
                if ~obj.is_running
                    return;
                end

                % 次の音再生タイミングまで待機
                obj.timer.wait_until(sound_schedule(sound_index), @() obj.escape_pressed);

                % 音再生時刻記録
                actual_time = obj.timer.record_event();
                target_time = sound_schedule(sound_index);

                if mod(sound_index, 2) == 1
                    % 奇数: 刺激音（0秒、1秒、2秒...）
                    pair_num = ceil(sound_index / 2);
                    fprintf('[%d/%d] 刺激音再生 (%.3fs地点, 目標%.3fs)\n', ...
                        pair_num, obj.stage1_beats, actual_time, target_time);
                    obj.audio.play_buffer(obj.stim_buffer, 0);

                    % データ記録
                    obj.recorder.record_stage1_event(actual_time, ...
                        'sound_type', 'stim', 'beat_number', pair_num);
                else
                    % 偶数: プレイヤー音（0.5秒、1.5秒、2.5秒...）
                    pair_num = sound_index / 2;
                    fprintf('       プレイヤー音再生 (%.3fs地点, 目標%.3fs) - 練習リズム\n', ...
                        actual_time, target_time);
                    obj.audio.play_buffer(obj.player_buffer, 0);

                    % データ記録
                    obj.recorder.record_stage1_event(actual_time, ...
                        'sound_type', 'player', 'beat_number', pair_num);
                end
            end

            fprintf('\nStage1完了: %d回の完全周期メトロノーム\n', obj.stage1_beats);
        end

        function run_stage2(obj)
            % Stage2: 協調交互タッピングフェーズ
            % システム（刺激音）が先に開始し、人間がその中間でタップ
            % 元のmain_experiment.mの仕様に準拠

            fprintf('Stage2開始: コンピュータとの協調交互タッピング\n');
            fprintf('Stage1で学習した1.0秒間隔を基準とした交互タッピングです\n');
            fprintf('システムが刺激音のタイミングを動的に調整します\n\n');

            % Stage1から継続的な時刻基準
            current_time = obj.timer.get_elapsed_time();

            % 初期間隔（Stage1の1.0秒間隔基準）
            initial_interval = 1.0;
            next_stim_time = current_time + initial_interval;

            fprintf('INFO: Stage2協調交互タッピング開始\n');
            fprintf('次のシステム刺激音まで: %.3f秒\n', initial_interval);
            fprintf('システム音の中間地点（%.3f秒後）でタップしてください\n\n', initial_interval / 2);

            turn = 0;
            flag = 1;  % 1: システムターン, 0: プレイヤーターン

            % データ記録用配列
            stim_taps = [];
            player_taps = [];

            while turn < obj.stage2_cycles && obj.is_running
                current_abs_time = obj.timer.get_elapsed_time();
                time_until_stim = next_stim_time - current_abs_time;

                % システムのターン
                if time_until_stim <= 0 && flag == 1
                    % 刺激音再生
                    tap_time = obj.timer.record_event();
                    obj.audio.play_buffer(obj.stim_buffer, 0);

                    stim_taps(end+1) = tap_time;

                    fprintf('[%d回目の刺激音] %.3fs地点\n', turn + 1, tap_time);

                    % データ記録（最初の刺激音はSEなし）
                    obj.recorder.record_stage2_tap('stim', tap_time, 'turn', turn + 1);

                    flag = 0;
                    turn = turn + 1;

                    % 最終ターン判定
                    if turn >= obj.stage2_cycles
                        fprintf('INFO: 最終ターン(%d)到達。最後のタップをしてください\n', turn);
                        break;
                    end
                end

                % プレイヤーのターン
                if flag == 0
                    if obj.key_pressed
                        % タップ記録
                        tap_time = obj.timer.record_event();
                        player_taps(end+1) = tap_time;

                        fprintf('[%d回目のプレイヤータップ] %.3fs地点\n', turn, tap_time);

                        % SE計算（元の実装準拠）
                        % SE = stim_tap[n] - (player_tap[n-1] + player_tap[n])/2
                        if length(stim_taps) >= 1 && length(player_taps) >= 2
                            current_stim = stim_taps(end);
                            prev_player = player_taps(end-1);
                            curr_player = player_taps(end);
                            se = current_stim - (prev_player + curr_player) / 2;
                        elseif length(stim_taps) >= 1 && length(player_taps) == 1
                            % 初回は簡易計算
                            se = stim_taps(end) - player_taps(end);
                        else
                            se = 0;
                        end

                        % モデル推論
                        predicted_interval = obj.model.predict_next_interval(se);

                        % データ記録
                        obj.recorder.record_stage2_tap('player', tap_time, ...
                            'turn', turn, 'se', se, 'predicted_interval', predicted_interval);

                        fprintf('  SE=%.3f -> 次の刺激音まで予測間隔=%.3f秒\n', se, predicted_interval);

                        % 次の刺激音時刻を設定
                        next_stim_time = tap_time + predicted_interval;
                        flag = 1;
                        obj.key_pressed = false;
                    end
                end

                % CPU負荷軽減
                pause(0.00001);
                drawnow;
            end

            fprintf('\nStage2完了: %dサイクル\n', turn);
        end
    end
end
