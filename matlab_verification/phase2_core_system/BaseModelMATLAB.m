%% 基本適応モデル抽象クラス
% 全ての適応モデル (SEA, Bayes, BIB) の基盤クラス
% 対応するPython版: src/models/base.py

classdef (Abstract) BaseModelMATLAB < handle
    properties (Access = protected)
        config              % 実験設定
        span               % 基本間隔 (秒)
        sync_errors        % 同期エラー履歴
        intervals          % 間隔履歴
        update_count       % 更新回数
        
        % モデル固有パラメータ
        model_params       % モデル固有設定格納
    end
    
    methods (Access = public)
        function obj = BaseModelMATLAB(config)
            % 基本コンストラクタ
            obj.config = config;
            obj.span = config.span;
            obj.sync_errors = [];
            obj.intervals = [];
            obj.update_count = 0;
            obj.model_params = struct();
            
            % 子クラスでの初期化
            obj.initializeModel();
        end
        
        function initializeFromStage1(obj, stage1_sync_errors)
            % Stage 1データからモデル初期化
            % stage1_sync_errors: Stage 1で取得した同期エラー配列
            
            obj.sync_errors = stage1_sync_errors;
            obj.intervals = repmat(obj.span, length(stage1_sync_errors), 1);
            
            % モデル固有の初期化処理
            obj.processStage1Data(stage1_sync_errors);
            
            fprintf('%s: Stage 1データから初期化 (%d点)\n', ...
                class(obj), length(stage1_sync_errors));
        end
        
        function update(obj, sync_error)
            % 同期エラーに基づくモデル更新
            % sync_error: 最新の同期エラー (秒)
            
            obj.sync_errors(end+1) = sync_error;
            obj.update_count = obj.update_count + 1;
            
            % モデル固有の更新処理
            obj.updateModel(sync_error);
        end
        
        function next_interval = predictNextInterval(obj)
            % 次回間隔の予測
            % 戻り値: 予測間隔 (秒)
            
            next_interval = obj.computeNextInterval();
            
            % 予測間隔の履歴記録
            obj.intervals(end+1) = next_interval;
            
            % 妥当性チェック
            next_interval = obj.validateInterval(next_interval);
        end
        
        function state = getModelState(obj)
            % モデル状態取得 (デバッグ・分析用)
            state = struct();
            state.model_type = class(obj);
            state.span = obj.span;
            state.sync_errors = obj.sync_errors;
            state.intervals = obj.intervals;
            state.update_count = obj.update_count;
            state.model_params = obj.model_params;
        end
        
        function resetModel(obj)
            % モデル状態リセット
            obj.sync_errors = [];
            obj.intervals = [];
            obj.update_count = 0;
            
            % モデル固有のリセット処理
            obj.resetModelSpecific();
        end
    end
    
    methods (Abstract, Access = protected)
        % 子クラスで実装必須のメソッド
        
        initializeModel(obj)
        % モデル固有の初期化処理
        
        processStage1Data(obj, stage1_sync_errors)  
        % Stage 1データの処理
        
        updateModel(obj, sync_error)
        % 同期エラーに基づく内部状態更新
        
        next_interval = computeNextInterval(obj)
        % 次回間隔の計算ロジック
        
        resetModelSpecific(obj)
        % モデル固有のリセット処理
    end
    
    methods (Access = protected)
        function valid_interval = validateInterval(obj, interval)
            % 間隔の妥当性チェックと制限
            % 極端な値の制限 (0.5倍 ～ 2.0倍)
            
            min_interval = obj.span * 0.5;
            max_interval = obj.span * 2.0;
            
            valid_interval = max(min_interval, min(max_interval, interval));
            
            if valid_interval ~= interval
                fprintf('警告: 間隔制限適用 %.3f -> %.3f\n', interval, valid_interval);
            end
        end
        
        function smoothed_error = smoothSyncError(obj, sync_error, window_size)
            % 同期エラーの平滑化処理
            if nargin < 3
                window_size = 5; % デフォルト窓サイズ
            end
            
            if length(obj.sync_errors) < window_size
                smoothed_error = sync_error;
            else
                recent_errors = obj.sync_errors(end-window_size+1:end);
                smoothed_error = mean(recent_errors);
            end
        end
        
        function trend = calculateErrorTrend(obj, window_size)
            % 同期エラーのトレンド計算
            if nargin < 2
                window_size = 10;
            end
            
            if length(obj.sync_errors) < window_size
                trend = 0;
            else
                recent_errors = obj.sync_errors(end-window_size+1:end);
                x = (1:length(recent_errors))';
                coeffs = polyfit(x, recent_errors, 1);
                trend = coeffs(1); % 傾き
            end
        end
        
        function variance = calculateErrorVariance(obj, window_size)
            % 同期エラーの分散計算
            if nargin < 2
                window_size = 10;
            end
            
            if length(obj.sync_errors) < 2
                variance = 0;
            elseif length(obj.sync_errors) < window_size
                variance = var(obj.sync_errors);
            else
                recent_errors = obj.sync_errors(end-window_size+1:end);
                variance = var(recent_errors);
            end
        end
        
        function is_converged = checkConvergence(obj, threshold, window_size)
            % 収束判定
            if nargin < 3
                window_size = 20;
            end
            if nargin < 2
                threshold = 0.01; % 10ms以下
            end
            
            if length(obj.sync_errors) < window_size
                is_converged = false;
            else
                recent_errors = obj.sync_errors(end-window_size+1:end);
                error_std = std(recent_errors);
                is_converged = error_std < threshold;
            end
        end
        
        function logModelUpdate(obj, sync_error, next_interval)
            % モデル更新ログ出力 (デバッグ用)
            if obj.config.debug_mode || obj.config.verbose
                fprintf('[%s] SE: %+.3f, 次間隔: %.3f, 更新回数: %d\n', ...
                    class(obj), sync_error, next_interval, obj.update_count);
            end
        end
    end
    
    methods (Static, Access = protected)
        function filtered_data = applyLowPassFilter(data, cutoff_freq, sample_rate)
            % ローパスフィルタ適用 (ノイズ除去)
            if nargin < 3
                sample_rate = 1; % データ点間隔が1秒と仮定
            end
            
            if length(data) < 3
                filtered_data = data;
                return;
            end
            
            % 簡易移動平均フィルタ
            window_size = max(3, round(sample_rate / cutoff_freq));
            window_size = min(window_size, length(data));
            
            filtered_data = zeros(size(data));
            for i = 1:length(data)
                start_idx = max(1, i - floor(window_size/2));
                end_idx = min(length(data), i + floor(window_size/2));
                filtered_data(i) = mean(data(start_idx:end_idx));
            end
        end
        
        function outlier_free_data = removeOutliers(data, threshold_std)
            % 外れ値除去
            if nargin < 2
                threshold_std = 2.5; % 2.5σ超えを外れ値とする
            end
            
            if length(data) < 3
                outlier_free_data = data;
                return;
            end
            
            mean_val = mean(data);
            std_val = std(data);
            
            outlier_mask = abs(data - mean_val) < threshold_std * std_val;
            outlier_free_data = data(outlier_mask);
            
            if sum(~outlier_mask) > 0
                fprintf('外れ値除去: %d点中%d点を除外\n', ...
                    length(data), sum(~outlier_mask));
            end
        end
        
        function adaptive_param = calculateAdaptiveParameter(errors, base_param, sensitivity)
            % 誤差に応じた適応パラメータ計算
            if nargin < 3
                sensitivity = 0.1;
            end
            
            if isempty(errors)
                adaptive_param = base_param;
                return;
            end
            
            recent_error_magnitude = mean(abs(errors(max(1, end-9):end)));
            adaptation_factor = 1 + sensitivity * recent_error_magnitude / 0.1; % 100ms基準
            
            adaptive_param = base_param * adaptation_factor;
        end
    end
end