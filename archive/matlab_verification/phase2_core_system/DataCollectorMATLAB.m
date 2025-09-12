%% データ収集・保存システム
% 実験データの収集、処理、保存を統括
% 対応するPython版: src/experiment/data_collector.py + runner.py内のデータ処理部分

classdef DataCollectorMATLAB < handle
    properties (Access = private)
        config              % 実験設定
        output_directory    % 出力ディレクトリ
        experiment_id       % 実験ID
        start_time          % 実験開始時刻
        
        % 生データ配列
        raw_tap_data        % 生タップデータ (構造体配列)
        stim_times          % 刺激タイミング配列
        player_times        % プレイヤータップタイミング配列
        sync_errors         % 同期エラー配列
        stage_info          % ステージ情報配列
        
        % 処理済みデータ
        processed_data      % 処理済みデータ構造体
        metadata           % メタデータ
        
        % ファイル管理
        file_prefix        % ファイル名プレフィックス
    end
    
    methods (Access = public)
        function obj = DataCollectorMATLAB(config)
            % データ収集システム初期化
            obj.config = config;
            obj.output_directory = config.output_directory;
            
            % 実験ID生成 (YYYYMMDD_HHMMSS形式)
            obj.experiment_id = datestr(now, 'yyyymmdd_HHMMSS');
            obj.start_time = posixtime(datetime('now', 'TimeZone', 'local'));
            
            % ファイル名プレフィックス
            obj.file_prefix = sprintf('%s_%s', config.model_type, obj.experiment_id);
            
            % データ配列初期化
            obj.resetData();
            
            % メタデータ初期化
            obj.initializeMetadata();
            
            fprintf('DataCollector初期化完了: ID=%s\n', obj.experiment_id);
        end
        
        function recordTap(obj, tap_number, stage, stim_time, tap_time, sync_error)
            % タップデータ記録
            % tap_number: タップ番号
            % stage: ステージ (1 or 2)
            % stim_time: 刺激タイミング
            % tap_time: タップタイミング (NaNも可)
            % sync_error: 同期エラー
            
            % 生データ記録
            tap_entry = struct();
            tap_entry.tap_number = tap_number;
            tap_entry.stage = stage;
            tap_entry.stim_time = stim_time;
            tap_entry.tap_time = tap_time;
            tap_entry.sync_error = sync_error;
            tap_entry.timestamp = posixtime(datetime('now', 'TimeZone', 'local'));
            
            obj.raw_tap_data(end+1) = tap_entry;
            
            % 個別配列にも記録
            obj.stim_times(end+1) = stim_time;
            if ~isnan(tap_time)
                obj.player_times(end+1) = tap_time;
                obj.sync_errors(end+1) = sync_error;
            end
            obj.stage_info(end+1) = stage;
            
            % 定期的なプログレス表示
            if mod(length(obj.raw_tap_data), 20) == 0
                fprintf('データ記録: %d タップ (Stage %d)\n', ...
                    length(obj.raw_tap_data), stage);
            end
        end
        
        function finalizeData(obj)
            % データの最終処理・計算
            fprintf('データ最終処理中...\n');
            
            obj.processed_data = struct();
            
            % 基本統計
            obj.processed_data.total_taps = length(obj.raw_tap_data);
            obj.processed_data.stage1_taps = sum(obj.stage_info == 1);
            obj.processed_data.stage2_taps = sum(obj.stage_info == 2);
            obj.processed_data.successful_taps = sum(~isnan([obj.raw_tap_data.tap_time]));
            
            % タイミングデータ処理
            obj.processTimingData();
            
            % 同期エラー・ITI計算
            obj.calculateSynchronizationMetrics();
            
            % バッファ処理 (Stage 2のみ)
            obj.applyBufferProcessing();
            
            % 変動係数計算
            obj.calculateVariations();
            
            % メタデータ更新
            obj.updateFinalMetadata();
            
            fprintf('データ最終処理完了\n');
        end
        
        function saveResults(obj, output_dir)
            % 結果保存
            if nargin < 2
                output_dir = obj.output_directory;
            end
            
            % 出力ディレクトリ確認・作成
            if ~exist(output_dir, 'dir')
                mkdir(output_dir);
            end
            
            fprintf('結果保存中: %s\n', output_dir);
            
            % CSV形式で保存
            obj.saveCSVFiles(output_dir);
            
            % MAT形式で保存
            obj.saveMATFile(output_dir);
            
            % メタデータ保存
            obj.saveMetadata(output_dir);
            
            fprintf('結果保存完了: %s\n', output_dir);
        end
        
        function savePartialResults(obj, output_dir)
            % 部分データ保存 (エラー時用)
            if nargin < 2
                output_dir = obj.output_directory;
            end
            
            fprintf('部分データ保存中...\n');
            
            try
                % 最低限のデータ保存
                raw_data = obj.raw_tap_data;
                partial_file = fullfile(output_dir, sprintf('%s_partial_data.mat', obj.file_prefix));
                save(partial_file, 'raw_data');
                fprintf('部分データ保存完了: %s\n', partial_file);
            catch ME
                fprintf('部分データ保存失敗: %s\n', ME.message);
            end
        end
        
        function results = getResults(obj)
            % 結果取得
            results = struct();
            results.experiment_id = obj.experiment_id;
            results.config = obj.config;
            results.raw_data = obj.raw_tap_data;
            results.processed_data = obj.processed_data;
            results.metadata = obj.metadata;
            results.stim_times = obj.stim_times;
            results.player_times = obj.player_times;
            results.sync_errors = obj.sync_errors;
        end
    end
    
    methods (Access = private)
        function resetData(obj)
            % データ配列リセット
            obj.raw_tap_data = struct('tap_number', {}, 'stage', {}, ...
                'stim_time', {}, 'tap_time', {}, 'sync_error', {}, 'timestamp', {});
            obj.stim_times = [];
            obj.player_times = [];
            obj.sync_errors = [];
            obj.stage_info = [];
            obj.processed_data = struct();
        end
        
        function initializeMetadata(obj)
            % メタデータ初期化
            obj.metadata = struct();
            obj.metadata.experiment_id = obj.experiment_id;
            obj.metadata.start_time = obj.start_time;
            obj.metadata.model_type = obj.config.model_type;
            obj.metadata.config = obj.config;
            obj.metadata.matlab_version = version;
            obj.metadata.creation_date = datestr(now);
            
            % システム情報
            if ispc
                obj.metadata.platform = 'Windows';
            elseif ismac
                obj.metadata.platform = 'macOS';
            elseif isunix
                obj.metadata.platform = 'Linux';
            else
                obj.metadata.platform = 'Unknown';
            end
        end
        
        function processTimingData(obj)
            % タイミングデータ処理
            if isempty(obj.raw_tap_data)
                return;
            end
            
            % 有効なタップのみ抽出
            valid_taps = ~isnan([obj.raw_tap_data.tap_time]);
            valid_stim_times = [obj.raw_tap_data(valid_taps).stim_time];
            valid_tap_times = [obj.raw_tap_data(valid_taps).tap_time];
            
            obj.processed_data.valid_stim_times = valid_stim_times;
            obj.processed_data.valid_tap_times = valid_tap_times;
            obj.processed_data.valid_tap_count = length(valid_tap_times);
        end
        
        function calculateSynchronizationMetrics(obj)
            % 同期エラー・ITI計算
            if length(obj.sync_errors) < 2
                return;
            end
            
            % 同期エラー統計
            obj.processed_data.sync_error_mean = mean(obj.sync_errors);
            obj.processed_data.sync_error_std = std(obj.sync_errors);
            obj.processed_data.sync_error_range = [min(obj.sync_errors), max(obj.sync_errors)];
            
            % ITI (Inter-Tap Interval) 計算
            if length(obj.player_times) >= 2
                stim_itis = diff(obj.stim_times);
                player_itis = diff(obj.player_times);
                
                obj.processed_data.stim_itis = stim_itis;
                obj.processed_data.player_itis = player_itis;
                obj.processed_data.stim_iti_mean = mean(stim_itis);
                obj.processed_data.player_iti_mean = mean(player_itis);
                obj.processed_data.stim_iti_std = std(stim_itis);
                obj.processed_data.player_iti_std = std(player_itis);
            end
        end
        
        function applyBufferProcessing(obj)
            % バッファ処理 (Stage 2データのみ対象)
            stage2_indices = find(obj.stage_info == 2);
            
            if length(stage2_indices) > obj.config.buffer_taps
                % バッファ除去後のインデックス
                buffer_removed_indices = stage2_indices(obj.config.buffer_taps+1:end);
                
                % バッファ処理済みデータ
                obj.processed_data.buffer_removed_indices = buffer_removed_indices;
                obj.processed_data.buffer_removed_count = length(buffer_removed_indices);
                
                % バッファ処理済み同期エラー
                buffer_removed_sync_errors = [];
                for i = 1:length(buffer_removed_indices)
                    idx = buffer_removed_indices(i);
                    if idx <= length(obj.raw_tap_data) && ~isnan(obj.raw_tap_data(idx).sync_error)
                        buffer_removed_sync_errors(end+1) = obj.raw_tap_data(idx).sync_error;
                    end
                end
                
                obj.processed_data.buffer_removed_sync_errors = buffer_removed_sync_errors;
                if length(buffer_removed_sync_errors) > 0
                    obj.processed_data.buffer_removed_se_mean = mean(buffer_removed_sync_errors);
                    obj.processed_data.buffer_removed_se_std = std(buffer_removed_sync_errors);
                end
            end
        end
        
        function calculateVariations(obj)
            % 変動係数計算
            if isfield(obj.processed_data, 'stim_itis') && length(obj.processed_data.stim_itis) > 1
                obj.processed_data.stim_iti_cv = obj.processed_data.stim_iti_std / obj.processed_data.stim_iti_mean;
            end
            
            if isfield(obj.processed_data, 'player_itis') && length(obj.processed_data.player_itis) > 1
                obj.processed_data.player_iti_cv = obj.processed_data.player_iti_std / obj.processed_data.player_iti_mean;
            end
            
            if length(obj.sync_errors) > 1
                obj.processed_data.sync_error_cv = obj.processed_data.sync_error_std / abs(obj.processed_data.sync_error_mean + eps);
            end
        end
        
        function updateFinalMetadata(obj)
            % 最終メタデータ更新
            obj.metadata.end_time = posixtime(datetime('now', 'TimeZone', 'local'));
            obj.metadata.duration_seconds = obj.metadata.end_time - obj.metadata.start_time;
            obj.metadata.total_taps = obj.processed_data.total_taps;
            obj.metadata.successful_taps = obj.processed_data.successful_taps;
            obj.metadata.completion_rate = obj.processed_data.successful_taps / obj.processed_data.total_taps;
            obj.metadata.finalization_date = datestr(now);
        end
        
        function saveCSVFiles(obj, output_dir)
            % CSV形式でデータ保存
            
            % 1. 生タップデータ (raw_taps.csv)
            if ~isempty(obj.raw_tap_data)
                raw_table = struct2table(obj.raw_tap_data);
                raw_csv_file = fullfile(output_dir, sprintf('%s_raw_taps.csv', obj.file_prefix));
                writetable(raw_table, raw_csv_file);
            end
            
            % 2. 処理済みタップデータ (processed_taps.csv) - Stage 2のみ
            stage2_data = obj.raw_tap_data(obj.stage_info == 2);
            if ~isempty(stage2_data)
                processed_table = struct2table(stage2_data);
                processed_csv_file = fullfile(output_dir, sprintf('%s_processed_taps.csv', obj.file_prefix));
                writetable(processed_table, processed_csv_file);
            end
            
            % 3. 同期エラーデータ
            if ~isempty(obj.sync_errors)
                se_table = table(obj.sync_errors', 'VariableNames', {'Sync_Error'});
                se_csv_file = fullfile(output_dir, sprintf('%s_synchronization_errors.csv', obj.file_prefix));
                writetable(se_table, se_csv_file);
            end
            
            % 4. ITIデータ
            if isfield(obj.processed_data, 'stim_itis')
                stim_iti_table = table(obj.processed_data.stim_itis', 'VariableNames', {'Stim_ITI'});
                stim_iti_file = fullfile(output_dir, sprintf('%s_stim_intertap_intervals.csv', obj.file_prefix));
                writetable(stim_iti_table, stim_iti_file);
            end
            
            if isfield(obj.processed_data, 'player_itis')
                player_iti_table = table(obj.processed_data.player_itis', 'VariableNames', {'Player_ITI'});
                player_iti_file = fullfile(output_dir, sprintf('%s_player_intertap_intervals.csv', obj.file_prefix));
                writetable(player_iti_table, player_iti_file);
            end
            
            % 5. 実験設定CSV
            config_data = struct2table(struct(obj.config), 'AsArray', true);
            config_csv_file = fullfile(output_dir, sprintf('%s_experiment_config.csv', obj.file_prefix));
            writetable(config_data, config_csv_file);
        end
        
        function saveMATFile(obj, output_dir)
            % MAT形式で統合データ保存
            data_struct = struct();
            data_struct.experiment_id = obj.experiment_id;
            data_struct.raw_data = obj.raw_tap_data;
            data_struct.processed_data = obj.processed_data;
            data_struct.metadata = obj.metadata;
            data_struct.stim_times = obj.stim_times;
            data_struct.player_times = obj.player_times;
            data_struct.sync_errors = obj.sync_errors;
            data_struct.stage_info = obj.stage_info;
            
            mat_file = fullfile(output_dir, sprintf('%s_complete_data.mat', obj.file_prefix));
            save(mat_file, 'data_struct');
        end
        
        function saveMetadata(obj, output_dir)
            % メタデータ保存
            metadata_file = fullfile(output_dir, sprintf('%s_data_metadata.csv', obj.file_prefix));
            
            % メタデータをテーブル形式に変換
            field_names = fieldnames(obj.metadata);
            field_values = cell(length(field_names), 1);
            
            for i = 1:length(field_names)
                value = obj.metadata.(field_names{i});
                if isnumeric(value)
                    field_values{i} = value;
                elseif ischar(value) || isstring(value)
                    field_values{i} = char(value);
                elseif isstruct(value)
                    field_values{i} = '[struct]';
                else
                    field_values{i} = '[complex]';
                end
            end
            
            metadata_table = table(field_names, field_values, ...
                'VariableNames', {'Parameter', 'Value'});
            writetable(metadata_table, metadata_file);
        end
    end
    
    methods (Access = public, Static)
        function demo()
            % DataCollectorデモンストレーション
            fprintf('=== DataCollector デモンストレーション ===\n');
            
            % テスト設定
            config = struct();
            config.model_type = 'demo';
            config.span = 2.0;
            config.stage1_count = 5;
            config.stage2_count = 10;
            config.buffer_taps = 2;
            config.output_directory = fullfile('matlab_verification', 'phase2_core_system', 'demo_data');
            
            % データ収集システム作成
            collector = DataCollectorMATLAB(config);
            
            % Stage 1データシミュレーション
            fprintf('Stage 1データ記録中...\n');
            base_time = posixtime(datetime('now', 'TimeZone', 'local'));
            
            for i = 1:config.stage1_count
                stim_time = base_time + (i-1) * config.span;
                tap_time = stim_time + 0.05 * randn(); % ランダム遅延
                sync_error = tap_time - stim_time;
                
                collector.recordTap(i, 1, stim_time, tap_time, sync_error);
            end
            
            % Stage 2データシミュレーション
            fprintf('Stage 2データ記録中...\n');
            last_time = base_time + config.stage1_count * config.span;
            
            for i = 1:config.stage2_count
                stim_time = last_time + i * (config.span + 0.1 * randn());
                tap_time = stim_time + 0.03 * randn();
                sync_error = tap_time - stim_time;
                
                collector.recordTap(config.stage1_count + i, 2, stim_time, tap_time, sync_error);
            end
            
            % データ最終処理
            collector.finalizeData();
            
            % 結果保存
            collector.saveResults();
            
            % 結果表示
            results = collector.getResults();
            fprintf('\nデモ結果:\n');
            fprintf('  実験ID: %s\n', results.experiment_id);
            fprintf('  総タップ数: %d\n', results.processed_data.total_taps);
            fprintf('  成功タップ数: %d\n', results.processed_data.successful_taps);
            fprintf('  同期エラー平均: %.3f秒\n', results.processed_data.sync_error_mean);
            fprintf('  同期エラー標準偏差: %.3f秒\n', results.processed_data.sync_error_std);
            
            fprintf('=== DataCollector デモ完了 ===\n');
        end
    end
end