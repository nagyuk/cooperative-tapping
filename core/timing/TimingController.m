classdef TimingController < handle
    % TimingController - 高精度タイミング制御クラス
    %
    % 全実験で統一されたタイミング管理を提供
    % - posixtime()による統一時刻参照
    % - 高精度スケジューリング
    % - タイムスタンプ記録

    properties (Access = public)
        experiment_start_time  % 実験開始時刻（datetime）
        clock_start           % 実験開始POSIX時刻（秒）
    end

    properties (Access = private)
        is_started = false
    end

    methods
        function obj = TimingController()
            % TimingController コンストラクタ
            % 実験開始時刻は後でstart()を呼んで初期化
        end

        function start(obj)
            % タイミングクロック開始
            obj.experiment_start_time = datetime('now');
            obj.clock_start = posixtime(obj.experiment_start_time);
            obj.is_started = true;

            fprintf('⏱️  タイミングクロック開始: %s\n', ...
                datestr(obj.experiment_start_time, 'yyyy-mm-dd HH:MM:SS'));
        end

        function elapsed = get_elapsed_time(obj)
            % 実験開始からの経過時間を取得（秒）
            %
            % Returns:
            %   elapsed - 経過時間（秒）

            if ~obj.is_started
                error('TimingController:NotStarted', 'タイミングクロックが開始されていません');
            end

            elapsed = posixtime(datetime('now')) - obj.clock_start;
        end

        function current_posix = get_current_time(obj)
            % 現在のPOSIX時刻を取得（グローバル参照）
            %
            % Returns:
            %   current_posix - 現在のPOSIX時刻

            current_posix = posixtime(datetime('now'));
        end

        function wait_until(obj, target_time, check_escape_fn)
            % 指定時刻まで待機（高精度ポーリング）
            %
            % Parameters:
            %   target_time - 目標時刻（実験開始からの秒数）
            %   check_escape_fn - Escape確認関数（オプション）

            if ~obj.is_started
                error('TimingController:NotStarted', 'タイミングクロックが開始されていません');
            end

            % 高精度ポーリング（1msごと）
            while obj.get_elapsed_time() < target_time
                % Escape確認（提供されている場合）
                if nargin >= 3 && ~isempty(check_escape_fn)
                    if check_escape_fn()
                        error('TimingController:Interrupted', '実験が中断されました');
                    end
                end
                pause(0.001);
            end
        end

        function timestamp = record_event(obj)
            % イベント発生時刻を記録
            %
            % Returns:
            %   timestamp - 実験開始からの経過時間（秒）

            if ~obj.is_started
                error('TimingController:NotStarted', 'タイミングクロックが開始されていません');
            end

            timestamp = obj.get_elapsed_time();
        end

        function schedule_times = create_schedule(obj, start_offset, interval, num_events)
            % イベントスケジュールを作成
            %
            % Parameters:
            %   start_offset - 最初のイベントまでの時間（秒）
            %   interval - イベント間隔（秒）
            %   num_events - イベント数
            %
            % Returns:
            %   schedule_times - スケジュールされた時刻配列（秒）
            %
            % Example:
            %   schedule = timer.create_schedule(0.5, 1.0, 10);
            %   % [0.5, 1.5, 2.5, 3.5, ..., 9.5]

            schedule_times = start_offset + (0:num_events-1) * interval;
        end
    end
end
