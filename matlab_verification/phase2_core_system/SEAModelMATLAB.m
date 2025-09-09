%% SEA (Synchronization Error Averaging) モデル
% 同期エラーの平均化による適応的タイミング制御
% 対応するPython版: src/models/sea.py

classdef SEAModelMATLAB < BaseModelMATLAB
    properties (Access = private)
        se_history         % 同期エラー履歴
        modify             % 累積修正値
        scale              % 分散スケール
    end
    
    methods (Access = public)
        function obj = SEAModelMATLAB(config)
            % SEAモデルコンストラクタ
            obj@BaseModelMATLAB(config);
        end
    end
    
    methods (Access = protected)
        function initializeModel(obj)
            % SEA固有の初期化
            obj.se_history = [];
            obj.modify = 0;
            
            % 設定パラメータ
            if isfield(obj.config, 'scale')
                obj.scale = obj.config.scale;
            else
                obj.scale = 0.1; % デフォルト分散スケール
            end
            
            % モデルパラメータ保存
            obj.model_params.scale = obj.scale;
            obj.model_params.model_name = 'SEA';
            obj.model_params.description = 'Synchronization Error Averaging';
            
            fprintf('SEAモデル初期化完了 (scale=%.3f)\n', obj.scale);
        end
        
        function processStage1Data(obj, stage1_sync_errors)
            % Stage 1データの処理
            % SEAモデルではStage 1データで累積修正値を初期化
            
            obj.se_history = stage1_sync_errors;
            obj.modify = sum(stage1_sync_errors);
            
            avg_modify = obj.modify / length(obj.se_history);
            fprintf('SEA: Stage 1累積修正値=%.3f, 平均修正値=%.3f\n', ...
                obj.modify, avg_modify);
        end
        
        function updateModel(obj, sync_error)
            % 同期エラーに基づくモデル更新
            % SEAモデル: 同期エラー履歴と累積修正値を更新
            
            obj.se_history(end+1) = sync_error;
            obj.modify = obj.modify + sync_error;
            
            % デバッグログ
            if obj.update_count <= 10 || mod(obj.update_count, 20) == 0
                avg_modify = obj.modify / length(obj.se_history);
                fprintf('SEA更新 #%d: SE=%+.3f, 累積=%.3f, 平均=%.3f\n', ...
                    obj.update_count, sync_error, obj.modify, avg_modify);
            end
        end
        
        function next_interval = computeNextInterval(obj)
            % 次回間隔の計算 (SEAアルゴリズム)
            
            if isempty(obj.se_history)
                % 履歴がない場合は基本間隔
                next_interval = obj.span;
                return;
            end
            
            % 平均修正値計算
            avg_modify = obj.modify / length(obj.se_history);
            
            % 正規分布による間隔生成
            % Python版: np.random.normal((SPAN / 2) - avg_modify, SCALE)
            base_interval = (obj.span / 2) - avg_modify;
            noise = obj.scale * randn(); % 正規分布ノイズ
            
            next_interval = base_interval + noise;
            
            % 負の値の制限
            if next_interval < 0.1
                next_interval = 0.1; % 最小100ms
                fprintf('SEA: 間隔下限制限適用 (%.3f -> %.3f)\n', ...
                    base_interval + noise, next_interval);
            end
        end
        
        function resetModelSpecific(obj)
            % SEA固有のリセット処理
            obj.se_history = [];
            obj.modify = 0;
        end
    end
    
    methods (Access = public)
        function inference(obj, sync_error)
            % Python版互換インターフェース
            % Python版のinference()メソッドと同等
            
            obj.update(sync_error);
            next_interval = obj.predictNextInterval();
        end
        
        function state = getSEAState(obj)
            % SEA固有状態取得
            state = obj.getModelState();
            
            % SEA固有情報追加
            state.se_history_length = length(obj.se_history);
            state.cumulative_modify = obj.modify;
            if ~isempty(obj.se_history)
                state.average_modify = obj.modify / length(obj.se_history);
            else
                state.average_modify = 0;
            end
            state.scale = obj.scale;
        end
        
        function avg_modify = getAverageModify(obj)
            % 平均修正値取得
            if isempty(obj.se_history)
                avg_modify = 0;
            else
                avg_modify = obj.modify / length(obj.se_history);
            end
        end
        
        function total_modify = getCumulativeModify(obj)
            % 累積修正値取得
            total_modify = obj.modify;
        end
        
        function history_length = getHistoryLength(obj)
            % 履歴長取得
            history_length = length(obj.se_history);
        end
    end
    
    methods (Access = public, Static)
        function demo()
            % SEAモデルデモンストレーション
            fprintf('=== SEAモデル デモンストレーション ===\n');
            
            % テスト設定
            config = struct();
            config.span = 2.0;
            config.scale = 0.1;
            config.debug_mode = true;
            
            % モデル作成
            sea_model = SEAModelMATLAB(config);
            
            % Stage 1シミュレーション
            stage1_errors = [0.05, -0.02, 0.03, -0.01, 0.04, ...
                           -0.03, 0.02, -0.04, 0.01, -0.02];
            sea_model.initializeFromStage1(stage1_errors);
            
            % Stage 2シミュレーション
            fprintf('\nStage 2シミュレーション:\n');
            simulated_errors = [0.02, -0.01, 0.03, -0.02, 0.01];
            
            for i = 1:length(simulated_errors)
                se = simulated_errors(i);
                sea_model.update(se);
                next_interval = sea_model.predictNextInterval();
                
                fprintf('  ステップ %d: SE=%+.3f -> 次間隔=%.3f秒\n', ...
                    i, se, next_interval);
            end
            
            % 最終状態表示
            final_state = sea_model.getSEAState();
            fprintf('\n最終状態:\n');
            fprintf('  履歴長: %d\n', final_state.se_history_length);
            fprintf('  累積修正値: %.3f\n', final_state.cumulative_modify);
            fprintf('  平均修正値: %.3f\n', final_state.average_modify);
            
            fprintf('=== SEAモデル デモ完了 ===\n');
        end
    end
end