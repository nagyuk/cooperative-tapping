classdef DataRecorder < handle
    % DataRecorder - 実験データ記録・保存クラス
    %
    % 全実験タイプで統一されたデータ管理を提供
    % - タップデータ記録
    % - MAT/CSV形式での保存
    % - メタデータ管理

    properties (Access = public)
        experiment_type       % 'human_computer' or 'human_human'
        participant_ids       % 参加者IDリスト（cell array）
        experiment_start_time % 実験開始時刻
        data                  % データ構造体
    end

    properties (Access = private)
        save_dir = ''         % 保存ディレクトリ
    end

    methods
        function obj = DataRecorder(experiment_type, participant_ids)
            % DataRecorder コンストラクタ
            %
            % Parameters:
            %   experiment_type - 'human_computer' or 'human_human'
            %   participant_ids - 参加者IDリスト (cell array or string)

            obj.experiment_type = experiment_type;

            % 参加者IDをcell arrayに統一
            if ischar(participant_ids) || isstring(participant_ids)
                obj.participant_ids = {char(participant_ids)};
            else
                obj.participant_ids = participant_ids;
            end

            obj.experiment_start_time = datetime('now');

            % データ構造初期化
            obj.data = struct();
            obj.data.stage1_data = [];
            obj.data.stage2_data = [];
            obj.data.metadata = struct();
        end

        function record_stage1_event(obj, timestamp, varargin)
            % Stage1イベントを記録
            %
            % Parameters:
            %   timestamp - イベント時刻（秒）
            %   varargin - 追加データ（名前-値ペア）

            event = struct('timestamp', timestamp);

            % 追加データを格納
            for i = 1:2:length(varargin)
                event.(varargin{i}) = varargin{i+1};
            end

            obj.data.stage1_data = [obj.data.stage1_data; event];
        end

        function record_stage2_tap(obj, player_id, timestamp, varargin)
            % Stage2タップを記録
            %
            % Parameters:
            %   player_id - プレイヤーID (1 or 2, or 'human'/'computer')
            %   timestamp - タップ時刻（秒）
            %   varargin - 追加データ（名前-値ペア）

            tap = struct('player_id', player_id, 'timestamp', timestamp);

            % 追加データを格納
            for i = 1:2:length(varargin)
                tap.(varargin{i}) = varargin{i+1};
            end

            obj.data.stage2_data = [obj.data.stage2_data; tap];
        end

        function set_metadata(obj, key, value)
            % メタデータを設定
            obj.data.metadata.(key) = value;
        end

        function save_data(obj, base_dir)
            % データを保存
            %
            % Parameters:
            %   base_dir - ベースディレクトリ（デフォルト: 'data/raw'）

            if nargin < 2
                base_dir = fullfile(pwd, 'data', 'raw');
            end

            % 保存ディレクトリ作成
            obj.save_dir = obj.create_save_directory(base_dir);

            % MATファイル保存（Figureオブジェクト除外）
            obj.save_mat_file();

            % CSVファイル保存
            obj.save_csv_files();

            fprintf('💾 データ保存完了: %s\n', obj.save_dir);
        end

        function save_dir = create_save_directory(obj, base_dir)
            % 保存ディレクトリを作成
            %
            % Returns:
            %   save_dir - 作成されたディレクトリパス

            timestamp = datestr(obj.experiment_start_time, 'yyyymmdd_HHMMSS');
            date_str = datestr(obj.experiment_start_time, 'yyyymmdd');

            % ディレクトリ名生成
            if strcmp(obj.experiment_type, 'human_human')
                dir_name = sprintf('%s_%s_human_human_%s', ...
                    obj.participant_ids{1}, obj.participant_ids{2}, timestamp);
            else
                % human_computerの場合
                model_name = 'unknown';
                if isfield(obj.data.metadata, 'model_type')
                    model_name = obj.data.metadata.model_type;
                end
                dir_name = sprintf('%s_%s_%s', ...
                    obj.participant_ids{1}, model_name, timestamp);
            end

            save_dir = fullfile(base_dir, obj.experiment_type, date_str, dir_name);

            if ~exist(save_dir, 'dir')
                mkdir(save_dir);
            end
        end

        function save_mat_file(obj)
            % MATファイル保存

            data_to_save = struct();
            data_to_save.experiment_type = obj.experiment_type;
            data_to_save.participant_ids = obj.participant_ids;
            data_to_save.experiment_start_time = obj.experiment_start_time;
            data_to_save.data = obj.data;

            save(fullfile(obj.save_dir, 'experiment_data.mat'), 'data_to_save');
        end

        function save_csv_files(obj)
            % CSVファイル保存

            % Stage1データ
            if ~isempty(obj.data.stage1_data)
                obj.save_stage1_csv();
            end

            % Stage2データ
            if ~isempty(obj.data.stage2_data)
                obj.save_stage2_csv();
            end
        end

        function save_stage1_csv(obj)
            % Stage1 CSVファイル保存
            % 実験タイプによって形式を調整

            stage1_data = obj.data.stage1_data;

            if strcmp(obj.experiment_type, 'human_computer')
                % 人間-コンピュータ: 同期タップ
                filename = 'stage1_synchronous_taps.csv';
            else
                % 人間-人間: メトロノーム
                filename = 'stage1_metronome.csv';
            end

            % struct arrayをtableに変換
            if isstruct(stage1_data)
                tbl = struct2table(stage1_data);
            else
                tbl = table(stage1_data, 'VariableNames', {'Timestamp'});
            end

            writetable(tbl, fullfile(obj.save_dir, filename));
        end

        function save_stage2_csv(obj)
            % Stage2 CSVファイル保存

            stage2_data = obj.data.stage2_data;

            if strcmp(obj.experiment_type, 'human_computer')
                filename = 'stage2_alternating_taps.csv';
            else
                filename = 'stage2_cooperative_taps.csv';
            end

            % struct arrayをtableに変換
            tbl = struct2table(stage2_data);

            writetable(tbl, fullfile(obj.save_dir, filename));
        end
    end
end
