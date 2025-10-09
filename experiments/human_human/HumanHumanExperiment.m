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

            % 注意: オーディオバッファ準備はinitialize_systems()で行う
        end

        function initialize_systems(obj)
            % システム初期化（オーバーライド）

            % 親クラスの初期化を呼ぶ（audio, timer, input_windowを作成）
            initialize_systems@BaseExperiment(obj);

            % オーディオバッファ準備（audioが初期化された後）
            obj.prepare_audio_buffers();
        end

        function get_participant_info(obj)
            % 参加者情報入力（ID検証機能付き）

            fprintf('\n=== 参加者情報入力 ===\n');
            fprintf('ID形式: P + 3桁の数字（例: P001）\n');
            fprintf('空欄の場合: 匿名ID（P1_anonymous/P2_anonymous）\n\n');

            % ID形式検証関数（P + 3桁の数字）
            validate_id = @(id) ~isempty(regexp(id, '^P\d{3}$', 'once'));

            % 参加者1 ID入力
            while true
                obj.participant1_id = input('参加者1 ID (例: P001): ', 's');
                if isempty(obj.participant1_id)
                    obj.participant1_id = 'P1_anonymous';
                    break;
                elseif validate_id(obj.participant1_id)
                    break;
                else
                    fprintf('❌ ID形式が不正です。P + 3桁の数字で入力してください（例: P001）\n');
                end
            end

            % 参加者2 ID入力
            while true
                obj.participant2_id = input('参加者2 ID (例: P002): ', 's');
                if isempty(obj.participant2_id)
                    obj.participant2_id = 'P2_anonymous';
                    break;
                elseif validate_id(obj.participant2_id)
                    % 重複チェック
                    if strcmp(obj.participant2_id, obj.participant1_id)
                        fprintf('❌ 参加者1と同じIDです。異なるIDを入力してください。\n');
                        continue;
                    end
                    break;
                else
                    fprintf('❌ ID形式が不正です。P + 3桁の数字で入力してください（例: P002）\n');
                end
            end

            % 確認
            fprintf('\n=== 入力内容の確認 ===\n');
            fprintf('参加者1: %s (出力1/2, Sキー)\n', obj.participant1_id);
            fprintf('参加者2: %s (出力3/4, Cキー)\n', obj.participant2_id);
            fprintf('\n');
            confirm = input('この内容でよろしいですか？ (y/n): ', 's');
            if ~strcmpi(confirm, 'y')
                fprintf('\nやり直します...\n');
                obj.get_participant_info();  % 再帰呼び出し
            end
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

            % ★重要★ 初回再生遅延対策: ダミー音声で事前ウォームアップ
            % この処理により、Stage1 turn1の最初の2音が正確な1秒間隔になります。
            % 詳細: docs/audio_warmup_necessity.md 参照
            fprintf('INFO: オーディオハードウェアウォームアップ中...\n');
            obj.audio.warmup_audio();
            fprintf('✅ オーディオウォームアップ完了\n');
        end

        function key_press_handler(obj, src, event)
            % キー押下ハンドラ（オーバーライド）

            % 親クラスのハンドラ呼び出し
            key_press_handler@BaseExperiment(obj, src, event);

            % プレイヤーキー処理（大文字小文字両対応）
            current_time = obj.timer.get_current_time();

            switch lower(event.Key)  % 大文字小文字を区別しない
                case 's'
                    if current_time - obj.player1_last_press_time > 0.05  % デバウンス50ms
                        obj.player1_key_pressed = true;
                        obj.player1_last_press_time = current_time;
                    end
                case 'c'
                    if current_time - obj.player2_last_press_time > 0.05  % デバウンス50ms
                        obj.player2_key_pressed = true;
                        obj.player2_last_press_time = current_time;
                    end
            end
        end

        function key_release_handler(obj, ~, event)
            % キーリリースハンドラ（オーバーライド）

            switch lower(event.Key)  % 大文字小文字を区別しない
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

            % タイマー開始（元の実装準拠: wait_for_space直後）
            obj.timer.start();
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

    methods (Access = protected)
        function run_stage1(obj)
            % Stage1: メトロノームフェーズ
            % 注意: timerは既にdisplay_instructions()で開始済み

            % メトロノームスケジュール作成（0.5秒オフセット、1.0秒間隔）
            total_sounds = obj.stage1_beats * 2;
            schedule = obj.timer.create_schedule(0.5, 1.0, total_sounds);

            fprintf('Stage1開始: %d音再生\n', total_sounds);

            for i = 1:total_sounds
                if ~obj.is_running
                    return;
                end

                % 目標時刻まで待機
                obj.timer.wait_until(schedule(i), @() obj.escape_pressed);

                if mod(i, 2) == 1
                    % Player1音（元の実装準拠: 再生直前に時刻記録）
                    actual_time = obj.timer.record_event();
                    obj.audio.play_buffer(obj.player1_stage1_buffer, 0);

                    fprintf('[%d/%d] Player1音 %.3fs\n', ceil(i/2), obj.stage1_beats, actual_time);

                    % データ記録
                    obj.recorder.record_stage1_event(actual_time, 'sound_type', 1, 'player', 1);
                else
                    % Player2音（元の実装準拠: 再生直前に時刻記録）
                    actual_time = obj.timer.record_event();
                    obj.audio.play_buffer(obj.player2_stage1_buffer, 0);

                    fprintf('       Player2音 %.3fs\n', actual_time);

                    % データ記録
                    obj.recorder.record_stage1_event(actual_time, 'sound_type', 2, 'player', 2);
                end
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
    end
end
