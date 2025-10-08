classdef HumanHumanExperiment < BaseExperiment
    % HumanHumanExperiment - 人間同士協調タッピング実験クラス
    %
    % 2人の参加者による交互タッピング実験を実装

    properties (Access = protected)
        experiment_type = 'human_human'

        % 参加者情報
        participant1_id
        participant2_id

        % オーディオバッファ
        player1_stage1_buffer
        player2_stage1_buffer
        player1_stage2_buffer
        player2_stage2_buffer

        % キー状態
        player1_key_pressed = false
        player2_key_pressed = false
        player1_last_press_time = 0
        player2_last_press_time = 0
    end

    methods (Access = public)
        function obj = HumanHumanExperiment()
            % HumanHumanExperiment コンストラクタ

            obj@BaseExperiment();

            fprintf('人間-人間協調タッピング実験\n');

            % 参加者情報入力
            obj.get_participant_info();

            % DataRecorder初期化
            obj.recorder = DataRecorder('human_human', {obj.participant1_id, obj.participant2_id});

            % オーディオバッファ準備
            obj.prepare_audio_buffers();
        end

        function get_participant_info(obj)
            % 参加者情報入力

            fprintf('\n=== 参加者情報入力 ===\n');
            obj.participant1_id = input('参加者1 ID (例: P001): ', 's');
            if isempty(obj.participant1_id)
                obj.participant1_id = 'P1_anonymous';
            end

            obj.participant2_id = input('参加者2 ID (例: P002): ', 's');
            if isempty(obj.participant2_id)
                obj.participant2_id = 'P2_anonymous';
            end

            fprintf('参加者1: %s (出力1/2, Sキー)\n', obj.participant1_id);
            fprintf('参加者2: %s (出力3/4, Cキー)\n', obj.participant2_id);
        end

        function prepare_audio_buffers(obj)
            % オーディオバッファ準備

            % 音声ファイル読み込み
            p1_sound = obj.audio.load_sound_file('assets/sounds/stim_beat_optimized.wav');
            p2_sound = obj.audio.load_sound_file('assets/sounds/player_beat_optimized.wav');

            % Stage1バッファ（全チャンネル - 両プレイヤーが聞く）
            obj.player1_stage1_buffer = obj.audio.create_buffer(p1_sound, [1,1,1,1]);
            obj.player2_stage1_buffer = obj.audio.create_buffer(p2_sound, [1,1,1,1]);

            % Stage2バッファ（チャンネル分離 - 相手の音を聞く）
            obj.player1_stage2_buffer = obj.audio.create_buffer(p2_sound, [1,1,0,0]);  % P1にはP2音
            obj.player2_stage2_buffer = obj.audio.create_buffer(p1_sound, [0,0,1,1]);  % P2にはP1音

            fprintf('✅ オーディオバッファ作成完了\n');
            fprintf('   Stage1: 両プレイヤーが両方の音を聞く\n');
            fprintf('   Stage2: Player1→P2音, Player2→P1音\n');
        end
    end

    methods (Access = protected)
        function key_press_handler(obj, src, event)
            % キー押下ハンドラ（オーバーライド）

            % 親クラスのハンドラ呼び出し
            key_press_handler@BaseExperiment(obj, src, event);

            % プレイヤーキー処理
            current_time = obj.timer.get_current_time();

            switch event.Key
                case 's'
                    if current_time - obj.player1_last_press_time > 0.05  % デバウンス
                        obj.player1_key_pressed = true;
                        obj.player1_last_press_time = current_time;
                    end
                case 'c'
                    if current_time - obj.player2_last_press_time > 0.05
                        obj.player2_key_pressed = true;
                        obj.player2_last_press_time = current_time;
                    end
            end
        end

        function key_release_handler(obj, ~, event)
            % キーリリースハンドラ（オーバーライド）

            switch event.Key
                case 's'
                    obj.player1_key_pressed = false;
                case 'c'
                    obj.player2_key_pressed = false;
            end
        end

        function display_instructions(obj)
            % 実験説明（オーバーライド）

            obj.update_display({'人間-人間協調タッピング実験', '', ...
                'Stage1: 両プレイヤーが交互に鳴る音を聞いて', ...
                '        1秒間隔のリズムを学習', '', ...
                'Stage2: 相手の音に合わせて交互にタップ', '', ...
                'Player1: Sキー | Player2: Cキー', '', ...
                'スペースキーで開始'}, 'color', [0.2, 1.0, 0.2]);

            obj.wait_for_space();
        end

        function run_stage1(obj)
            % Stage1: メトロノームフェーズ

            obj.update_display('Stage 1: メトロノームフェーズ', 'color', [1.0, 0.8, 0.3]);
            pause(1);

            % タイミングスタート
            obj.timer.start();

            % メトロノームスケジュール作成（0.5秒オフセット、1.0秒間隔）
            total_sounds = obj.stage1_beats * 2;
            schedule = obj.timer.create_schedule(0.5, 0.5, total_sounds);

            fprintf('Stage1開始: %d音再生\n', total_sounds);

            for i = 1:total_sounds
                if ~obj.is_running
                    return;
                end

                % 目標時刻まで待機
                obj.timer.wait_until(schedule(i), @() obj.escape_pressed);

                % 音声再生
                actual_time = obj.timer.record_event();

                if mod(i, 2) == 1
                    % Player1音
                    obj.audio.play_buffer(obj.player1_stage1_buffer, false);
                    fprintf('[%d/%d] Player1音 %.3fs\n', ceil(i/2), obj.stage1_beats, actual_time);
                else
                    % Player2音
                    obj.audio.play_buffer(obj.player2_stage1_buffer, false);
                    fprintf('       Player2音 %.3fs\n', actual_time);
                end

                % データ記録
                obj.recorder.record_stage1_event(actual_time, 'sound_type', mod(i,2)+1);
            end

            fprintf('Stage1完了\n');
        end

        function run_stage2(obj)
            % Stage2: 協調タッピングフェーズ

            obj.update_display('Stage 2: 協調タッピング', 'color', [1.0, 0.8, 0.3]);
            pause(1);

            fprintf('Stage2開始: 交互タッピング\n');

            current_player = 1;  % Player1スタート
            cycle_count = 0;

            % Player1の最初のタップ待機
            obj.update_display('Player1: Sキーでスタート', 'color', [0.2, 1.0, 0.2]);

            while cycle_count < obj.stage2_cycles && obj.is_running
                if current_player == 1
                    % Player1のタップ待機
                    obj.player1_key_pressed = false;
                    while ~obj.player1_key_pressed && obj.is_running
                        pause(0.001);
                        drawnow;
                    end

                    if ~obj.is_running
                        return;
                    end

                    % タップ記録
                    tap_time = obj.timer.record_event();
                    obj.recorder.record_stage2_tap(1, tap_time, 'cycle', cycle_count + 1);

                    % Player2に音を再生
                    obj.audio.play_buffer(obj.player2_stage2_buffer, false);

                    fprintf('Player1タップ: %.3fs (サイクル %d)\n', tap_time, cycle_count + 1);

                    current_player = 2;

                else
                    % Player2のタップ待機
                    obj.player2_key_pressed = false;
                    while ~obj.player2_key_pressed && obj.is_running
                        pause(0.001);
                        drawnow;
                    end

                    if ~obj.is_running
                        return;
                    end

                    % タップ記録
                    tap_time = obj.timer.record_event();
                    obj.recorder.record_stage2_tap(2, tap_time, 'cycle', cycle_count + 1);

                    % Player1に音を再生
                    obj.audio.play_buffer(obj.player1_stage2_buffer, false);

                    fprintf('Player2タップ: %.3fs (サイクル %d)\n', tap_time, cycle_count + 1);

                    current_player = 1;
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

            fprintf('参加者1: %s\n', obj.participant1_id);
            fprintf('参加者2: %s\n', obj.participant2_id);

            % Stage1結果
            fprintf('\n--- Stage 1 ---\n');
            fprintf('メトロノーム音: %d回\n', length(obj.recorder.data.stage1_data));

            % Stage2結果
            fprintf('\n--- Stage 2 ---\n');
            fprintf('総タップ数: %d回\n', length(obj.recorder.data.stage2_data));

            if ~isempty(obj.recorder.data.stage2_data)
                % 簡易統計
                taps = obj.recorder.data.stage2_data;
                timestamps = [taps.timestamp];

                if length(timestamps) > 1
                    intervals = diff(timestamps);
                    fprintf('平均間隔: %.3f秒 (SD=%.3f)\n', mean(intervals), std(intervals));
                end
            end

            obj.update_display('実験完了！ありがとうございました', 'color', [0.2, 1.0, 0.2]);
        end
    end
end
