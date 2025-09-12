%% BIB (Bayesian-Inverse Bayesian) 推論モデル
% 軍司氏のBayesian-Inverse Bayesian推論理論に基づく適応モデル
% 対応するPython版: src/models/bib.py

classdef BIBModelMATLAB < BayesModelMATLAB
    properties (Access = private)
        l_memory          % メモリ長 (逆ベイズ学習用)
        memory            % 同期エラーメモリ
    end
    
    methods (Access = public)
        function obj = BIBModelMATLAB(config)
            % BIBモデルコンストラクタ
            obj@BayesModelMATLAB(config);
        end
    end
    
    methods (Access = protected)
        function initializeModel(obj)
            % 親クラス初期化
            initializeModel@BayesModelMATLAB(obj);
            
            % BIB固有パラメータ
            if isfield(obj.config, 'bib_l_memory')
                obj.l_memory = obj.config.bib_l_memory;
            else
                obj.l_memory = 1; % デフォルトメモリ長
            end
            
            % メモリ初期化
            if obj.l_memory > 0
                obj.memory = obj.scale * randn(1, obj.l_memory); % 正規分布で初期化
            else
                obj.memory = [];
            end
            
            % モデルパラメータ更新
            obj.model_params.l_memory = obj.l_memory;
            obj.model_params.model_name = 'BIB';
            obj.model_params.description = 'Bayesian-Inverse Bayesian';
            
            fprintf('BIBモデル初期化完了 (メモリ長=%d)\n', obj.l_memory);
            if obj.l_memory > 0
                fprintf('  初期メモリ: [%s]\n', sprintf('%.3f ', obj.memory));
            end
        end
        
        function processStage1Data(obj, stage1_sync_errors)
            % Stage 1データの処理
            % BIB: 通常のBayes処理に加えてメモリ初期化
            
            % 親クラスの処理
            processStage1Data@BayesModelMATLAB(obj, stage1_sync_errors);
            
            % メモリをStage 1データで初期化
            if obj.l_memory > 0 && length(stage1_sync_errors) >= obj.l_memory
                obj.memory = stage1_sync_errors(end-obj.l_memory+1:end);
                fprintf('BIB: メモリをStage 1データで初期化 [%s]\n', ...
                    sprintf('%.3f ', obj.memory));
            end
        end
        
        function updateModel(obj, sync_error)
            % BIB推論による更新
            
            % 逆ベイズ学習実行
            if obj.l_memory > 0
                obj.performInverseBayesianLearning(sync_error);
            end
            
            % 通常のベイズ更新
            updateModel@BayesModelMATLAB(obj, sync_error);
            
            % デバッグログ
            if obj.update_count <= 10 || mod(obj.update_count, 20) == 0
                [max_prob, max_idx] = max(obj.h_prov);
                best_hypothesis = obj.likelihood(max_idx);
                
                if obj.l_memory > 0
                    memory_mean = mean(obj.memory);
                    fprintf('BIB更新 #%d: SE=%+.3f, 最適仮説=%.3f (P=%.3f), メモリ平均=%.3f\n', ...
                        obj.update_count, sync_error, best_hypothesis, max_prob, memory_mean);
                else
                    fprintf('BIB更新 #%d: SE=%+.3f, 最適仮説=%.3f (P=%.3f) [メモリなし]\n', ...
                        obj.update_count, sync_error, best_hypothesis, max_prob);
                end
            end
        end
        
        function resetModelSpecific(obj)
            % BIB固有のリセット処理
            resetModelSpecific@BayesModelMATLAB(obj);
            
            % メモリリセット
            if obj.l_memory > 0
                obj.memory = obj.scale * randn(1, obj.l_memory);
            end
        end
    end
    
    methods (Access = private)
        function performInverseBayesianLearning(obj, sync_error)
            % 逆ベイズ学習の実行
            
            if obj.l_memory <= 0
                return; % メモリ長が0の場合は通常のベイズ
            end
            
            % メモリ平均に基づく新仮説計算
            new_hypothesis = mean(obj.memory);
            
            % 確率分布の逆転
            % P_inv(h) = (1 - P(h)) / (N - 1)
            sum_prob = sum(obj.h_prov);
            inv_h_prov = (1 - obj.h_prov) / (obj.n_hypothesis - 1);
            
            % 正規化確保
            inv_h_prov = inv_h_prov / sum(inv_h_prov);
            
            % 逆確率に基づいて置換する仮説選択
            selected_idx = obj.sampleFromDistribution(inv_h_prov);
            
            % 仮説置換
            old_hypothesis = obj.likelihood(selected_idx);
            obj.likelihood(selected_idx) = new_hypothesis;
            
            % デバッグ情報
            if obj.update_count <= 5
                fprintf('  逆ベイズ: 仮説[%d] %.3f -> %.3f (メモリ平均)\n', ...
                    selected_idx, old_hypothesis, new_hypothesis);
            end
            
            % メモリ更新 (FIFO)
            obj.memory = [obj.memory(2:end), sync_error];
        end
        
        function selected_idx = sampleFromDistribution(obj, distribution)
            % 確率分布からのサンプリング
            cumsum_dist = cumsum(distribution);
            rand_val = rand();
            selected_idx = find(cumsum_dist >= rand_val, 1, 'first');
            
            if isempty(selected_idx)
                selected_idx = obj.n_hypothesis; % フォールバック
            end
        end
    end
    
    methods (Access = public)
        function inference(obj, sync_error)
            % Python版互換インターフェース (BIB版)
            obj.update(sync_error);
            next_interval = obj.predictNextInterval();
        end
        
        function state = getBIBState(obj)
            % BIB固有状態取得
            state = obj.getBayesState(); % 親クラスの状態を継承
            
            % BIB固有情報追加
            state.l_memory = obj.l_memory;
            if obj.l_memory > 0
                state.memory = obj.memory;
                state.memory_mean = mean(obj.memory);
                state.memory_std = std(obj.memory);
            else
                state.memory = [];
                state.memory_mean = NaN;
                state.memory_std = NaN;
            end
        end
        
        function memory_vals = getMemory(obj)
            % メモリ値取得
            memory_vals = obj.memory;
        end
        
        function memory_length = getMemoryLength(obj)
            % メモリ長取得
            memory_length = obj.l_memory;
        end
        
        function mean_memory = getMemoryMean(obj)
            % メモリ平均取得
            if obj.l_memory > 0 && ~isempty(obj.memory)
                mean_memory = mean(obj.memory);
            else
                mean_memory = NaN;
            end
        end
        
        function plotBIBState(obj, figure_num)
            % BIB状態可視化
            if nargin < 2
                figure_num = 2;
            end
            
            figure(figure_num);
            
            % サブプロット1: 事後分布
            subplot(2, 1, 1);
            bar(obj.likelihood, obj.h_prov);
            xlabel('仮説値');
            ylabel('確率');
            title('BIB事後分布');
            grid on;
            
            % 最適仮説をハイライト
            [~, max_idx] = max(obj.h_prov);
            hold on;
            bar(obj.likelihood(max_idx), obj.h_prov(max_idx), 'r');
            hold off;
            
            % サブプロット2: メモリ履歴
            if obj.l_memory > 0
                subplot(2, 1, 2);
                plot(1:obj.l_memory, obj.memory, 'o-', 'LineWidth', 2);
                xlabel('メモリ位置');
                ylabel('同期エラー');
                title(sprintf('BIBメモリ (長さ=%d, 平均=%.3f)', obj.l_memory, mean(obj.memory)));
                grid on;
                
                % 平均線
                hold on;
                yline(mean(obj.memory), '--r', sprintf('平均=%.3f', mean(obj.memory)));
                hold off;
            end
        end
    end
    
    methods (Access = public, Static)
        function demo()
            % BIBモデルデモンストレーション
            fprintf('=== BIBモデル デモンストレーション ===\n');
            
            % テスト設定
            config = struct();
            config.span = 2.0;
            config.scale = 0.1;
            config.bayes_n_hypothesis = 20;
            config.bayes_x_min = -2;
            config.bayes_x_max = 2;
            config.bib_l_memory = 3; % メモリ長3
            config.debug_mode = true;
            
            % モデル作成
            bib_model = BIBModelMATLAB(config);
            
            % Stage 1シミュレーション
            stage1_errors = [0.05, -0.02, 0.03, -0.01, 0.04, ...
                           -0.03, 0.02, -0.04, 0.01, -0.02];
            bib_model.initializeFromStage1(stage1_errors);
            
            % Stage 2シミュレーション
            fprintf('\nStage 2シミュレーション:\n');
            simulated_errors = [0.02, -0.01, 0.03, -0.02, 0.01, 0.015, -0.005];
            
            for i = 1:length(simulated_errors)
                se = simulated_errors(i);
                bib_model.update(se);
                next_interval = bib_model.predictNextInterval();
                
                [best_hyp, best_prob] = bib_model.getBestHypothesis();
                memory_mean = bib_model.getMemoryMean();
                
                fprintf('  ステップ %d: SE=%+.3f -> 間隔=%.3f, 最適仮説=%.3f (P=%.3f), メモリ平均=%.3f\n', ...
                    i, se, next_interval, best_hyp, best_prob, memory_mean);
            end
            
            % 最終状態表示
            final_state = bib_model.getBIBState();
            fprintf('\n最終状態:\n');
            fprintf('  最適仮説: %.3f (確率: %.3f)\n', ...
                final_state.best_hypothesis, final_state.best_probability);
            fprintf('  エントロピー: %.3f\n', final_state.entropy);
            fprintf('  メモリ長: %d\n', final_state.l_memory);
            fprintf('  メモリ平均: %.3f ± %.3f\n', ...
                final_state.memory_mean, final_state.memory_std);
            
            % BIB状態可視化
            bib_model.plotBIBState();
            
            fprintf('=== BIBモデル デモ完了 ===\n');
        end
        
        function compareModels()
            % Bayes vs BIB 比較デモ
            fprintf('=== Bayes vs BIB 比較デモ ===\n');
            
            % 共通設定
            config = struct();
            config.span = 2.0;
            config.scale = 0.1;
            config.bayes_n_hypothesis = 15;
            config.bayes_x_min = -1.5;
            config.bayes_x_max = 1.5;
            config.bib_l_memory = 2;
            
            % モデル作成
            bayes_model = BayesModelMATLAB(config);
            bib_model = BIBModelMATLAB(config);
            
            % 共通テストデータ
            test_errors = [0.1, -0.05, 0.03, -0.02, 0.04, -0.03, 0.01, -0.01];
            
            fprintf('\n比較結果:\n');
            fprintf('%-6s %-8s %-12s %-12s %-12s %-12s\n', ...
                'Step', 'SE', 'Bayes_Int', 'Bayes_Hyp', 'BIB_Int', 'BIB_Hyp');
            fprintf('%s\n', repmat('-', 1, 70));
            
            for i = 1:length(test_errors)
                se = test_errors(i);
                
                % Bayes更新
                bayes_model.update(se);
                bayes_interval = bayes_model.predictNextInterval();
                [bayes_hyp, ~] = bayes_model.getBestHypothesis();
                
                % BIB更新
                bib_model.update(se);
                bib_interval = bib_model.predictNextInterval();
                [bib_hyp, ~] = bib_model.getBestHypothesis();
                
                fprintf('%-6d %+.3f   %-12.3f %-12.3f %-12.3f %-12.3f\n', ...
                    i, se, bayes_interval, bayes_hyp, bib_interval, bib_hyp);
            end
            
            fprintf('\n=== 比較デモ完了 ===\n');
        end
    end
end