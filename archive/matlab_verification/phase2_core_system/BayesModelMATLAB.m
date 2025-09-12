%% Bayesian推論モデル
% ベイズ推論による適応的タイミング制御
% 対応するPython版: src/models/bayes.py

classdef BayesModelMATLAB < BaseModelMATLAB
    properties (Access = private)
        n_hypothesis       % 仮説数
        x_min             % 仮説空間最小値
        x_max             % 仮説空間最大値
        likelihood        % 尤度値 (仮説空間)
        h_prov            % 仮説確率 (事後確率)
        scale             % 分散スケール
        prediction_scale  % 予測時の分散
    end
    
    methods (Access = public)
        function obj = BayesModelMATLAB(config)
            % Bayesモデルコンストラクタ
            obj@BaseModelMATLAB(config);
        end
    end
    
    methods (Access = protected)
        function initializeModel(obj)
            % Bayes固有の初期化
            
            % 設定パラメータ読み込み
            if isfield(obj.config, 'bayes_n_hypothesis')
                obj.n_hypothesis = obj.config.bayes_n_hypothesis;
            else
                obj.n_hypothesis = 20; % デフォルト仮説数
            end
            
            if isfield(obj.config, 'bayes_x_min')
                obj.x_min = obj.config.bayes_x_min;
            else
                obj.x_min = -3; % デフォルト最小値
            end
            
            if isfield(obj.config, 'bayes_x_max')
                obj.x_max = obj.config.bayes_x_max;
            else
                obj.x_max = 3; % デフォルト最大値
            end
            
            if isfield(obj.config, 'scale')
                obj.scale = obj.config.scale;
            else
                obj.scale = 0.1; % デフォルト分散スケール
            end
            
            obj.prediction_scale = 0.3; % Python版と同一
            
            % 仮説空間初期化
            obj.likelihood = linspace(obj.x_min, obj.x_max, obj.n_hypothesis);
            obj.h_prov = ones(1, obj.n_hypothesis) / obj.n_hypothesis; % 均等事前分布
            
            % モデルパラメータ保存
            obj.model_params.n_hypothesis = obj.n_hypothesis;
            obj.model_params.x_min = obj.x_min;
            obj.model_params.x_max = obj.x_max;
            obj.model_params.scale = obj.scale;
            obj.model_params.prediction_scale = obj.prediction_scale;
            obj.model_params.model_name = 'Bayes';
            obj.model_params.description = 'Bayesian Inference';
            
            fprintf('Bayesモデル初期化完了 (仮説数=%d, 範囲=[%.1f,%.1f])\n', ...
                obj.n_hypothesis, obj.x_min, obj.x_max);
        end
        
        function processStage1Data(obj, stage1_sync_errors)
            % Stage 1データの処理
            % Bayesモデル: Stage 1データで事後確率を更新
            
            fprintf('Bayes: Stage 1データで事後確率更新中...\n');
            
            for i = 1:length(stage1_sync_errors)
                se = stage1_sync_errors(i);
                obj.updateBayesianPosterior(se);
            end
            
            % 最も確率の高い仮説を表示
            [max_prob, max_idx] = max(obj.h_prov);
            best_hypothesis = obj.likelihood(max_idx);
            
            fprintf('Bayes: Stage 1更新完了, 最適仮説=%.3f (確率=%.3f)\n', ...
                best_hypothesis, max_prob);
        end
        
        function updateModel(obj, sync_error)
            % 同期エラーに基づくベイズ更新
            obj.updateBayesianPosterior(sync_error);
            
            % デバッグログ
            if obj.update_count <= 10 || mod(obj.update_count, 20) == 0
                [max_prob, max_idx] = max(obj.h_prov);
                best_hypothesis = obj.likelihood(max_idx);
                entropy = -sum(obj.h_prov .* log(obj.h_prov + eps));
                
                fprintf('Bayes更新 #%d: SE=%+.3f, 最適仮説=%.3f (P=%.3f), エントロピー=%.3f\n', ...
                    obj.update_count, sync_error, best_hypothesis, max_prob, entropy);
            end
        end
        
        function next_interval = computeNextInterval(obj)
            % ベイズ推論に基づく次回間隔計算
            
            % 仮説からサンプリング
            selected_hypothesis = obj.sampleFromPosterior();
            
            % 予測分散を考慮した正規分布サンプリング
            prediction = selected_hypothesis + obj.prediction_scale * randn();
            
            % 間隔計算 (Python版と同一ロジック)
            next_interval = (obj.span / 2) - prediction;
            
            % 負の値の制限
            if next_interval < 0.1
                next_interval = 0.1; % 最小100ms
            end
        end
        
        function resetModelSpecific(obj)
            % Bayes固有のリセット処理
            obj.h_prov = ones(1, obj.n_hypothesis) / obj.n_hypothesis;
        end
    end
    
    methods (Access = private)
        function updateBayesianPosterior(obj, sync_error)
            % ベイズ事後確率更新
            
            % 尤度計算 (正規分布)
            likelihood_values = zeros(1, obj.n_hypothesis);
            for i = 1:obj.n_hypothesis
                likelihood_values(i) = normpdf(sync_error, obj.likelihood(i), obj.prediction_scale);
            end
            
            % 事後確率更新
            post_prov = likelihood_values .* obj.h_prov;
            
            % 正規化
            sum_post = sum(post_prov);
            if sum_post > 0
                obj.h_prov = post_prov / sum_post;
            else
                % 数値的問題の場合は均等分布にリセット
                obj.h_prov = ones(1, obj.n_hypothesis) / obj.n_hypothesis;
                fprintf('警告: ベイズ更新で数値的問題発生、事前分布にリセット\n');
            end
        end
        
        function selected_hypothesis = sampleFromPosterior(obj)
            % 事後分布からサンプリング
            
            % 累積確率計算
            cumsum_prob = cumsum(obj.h_prov);
            
            % ランダムサンプリング
            rand_val = rand();
            selected_idx = find(cumsum_prob >= rand_val, 1, 'first');
            
            if isempty(selected_idx)
                selected_idx = obj.n_hypothesis; % フォールバック
            end
            
            selected_hypothesis = obj.likelihood(selected_idx);
        end
    end
    
    methods (Access = public)
        function inference(obj, sync_error)
            % Python版互換インターフェース
            obj.update(sync_error);
            next_interval = obj.predictNextInterval();
        end
        
        function state = getBayesState(obj)
            % Bayes固有状態取得
            state = obj.getModelState();
            
            % Bayes固有情報追加
            state.hypotheses = obj.likelihood;
            state.probabilities = obj.h_prov;
            state.n_hypothesis = obj.n_hypothesis;
            
            % 統計情報
            [max_prob, max_idx] = max(obj.h_prov);
            state.best_hypothesis = obj.likelihood(max_idx);
            state.best_probability = max_prob;
            state.entropy = -sum(obj.h_prov .* log(obj.h_prov + eps));
            state.effective_hypotheses = 1 / sum(obj.h_prov.^2); % 有効仮説数
        end
        
        function likelihood_vals = getLikelihood(obj)
            % 尤度値取得 (Python版互換)
            likelihood_vals = obj.likelihood;
        end
        
        function hypothesis_probs = getHypothesis(obj)
            % 仮説確率取得 (Python版互換)
            hypothesis_probs = obj.h_prov;
        end
        
        function [best_hyp, best_prob] = getBestHypothesis(obj)
            % 最も確率の高い仮説取得
            [best_prob, max_idx] = max(obj.h_prov);
            best_hyp = obj.likelihood(max_idx);
        end
        
        function entropy_val = getEntropy(obj)
            % 事後分布のエントロピー計算
            entropy_val = -sum(obj.h_prov .* log(obj.h_prov + eps));
        end
        
        function plotPosterior(obj, figure_num)
            % 事後分布可視化
            if nargin < 2
                figure_num = 1;
            end
            
            figure(figure_num);
            bar(obj.likelihood, obj.h_prov);
            xlabel('仮説値');
            ylabel('確率');
            title('ベイズ事後分布');
            grid on;
            
            % 最適仮説をハイライト
            [~, max_idx] = max(obj.h_prov);
            hold on;
            bar(obj.likelihood(max_idx), obj.h_prov(max_idx), 'r');
            hold off;
        end
    end
    
    methods (Access = public, Static)
        function demo()
            % Bayesモデルデモンストレーション
            fprintf('=== Bayesモデル デモンストレーション ===\n');
            
            % テスト設定
            config = struct();
            config.span = 2.0;
            config.scale = 0.1;
            config.bayes_n_hypothesis = 20;
            config.bayes_x_min = -2;
            config.bayes_x_max = 2;
            config.debug_mode = true;
            
            % モデル作成
            bayes_model = BayesModelMATLAB(config);
            
            % Stage 1シミュレーション
            stage1_errors = [0.05, -0.02, 0.03, -0.01, 0.04, ...
                           -0.03, 0.02, -0.04, 0.01, -0.02];
            bayes_model.initializeFromStage1(stage1_errors);
            
            % Stage 2シミュレーション
            fprintf('\nStage 2シミュレーション:\n');
            simulated_errors = [0.02, -0.01, 0.03, -0.02, 0.01];
            
            for i = 1:length(simulated_errors)
                se = simulated_errors(i);
                bayes_model.update(se);
                next_interval = bayes_model.predictNextInterval();
                
                [best_hyp, best_prob] = bayes_model.getBestHypothesis();
                entropy = bayes_model.getEntropy();
                
                fprintf('  ステップ %d: SE=%+.3f -> 間隔=%.3f, 最適仮説=%.3f (P=%.3f), H=%.3f\n', ...
                    i, se, next_interval, best_hyp, best_prob, entropy);
            end
            
            % 最終状態表示
            final_state = bayes_model.getBayesState();
            fprintf('\n最終状態:\n');
            fprintf('  最適仮説: %.3f (確率: %.3f)\n', ...
                final_state.best_hypothesis, final_state.best_probability);
            fprintf('  エントロピー: %.3f\n', final_state.entropy);
            fprintf('  有効仮説数: %.1f\n', final_state.effective_hypotheses);
            
            % 事後分布可視化
            bayes_model.plotPosterior();
            
            fprintf('=== Bayesモデル デモ完了 ===\n');
        end
    end
end