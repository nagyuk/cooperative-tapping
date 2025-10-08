classdef BayesianModel < BaseModel
    % BayesianModel - ベイズ推論モデル
    %
    % ベイズ学習により同期エラーから仮説分布を更新し、次の間隔を予測

    properties (Access = public)
        model_type = 'Bayesian'
    end

    properties (Access = private)
        likelihood  % 仮説空間（-3 ~ 3の範囲）
        h_prov      % 各仮説の事後確率
        n_hypothesis % 仮説数
    end

    methods (Access = public)
        function obj = BayesianModel(config)
            % BayesianModel コンストラクタ

            obj@BaseModel(config);

            % 仮説空間初期化
            obj.n_hypothesis = config.BAYES_N_HYPOTHESIS;  % 通常20
            x_min = -3;
            x_max = 3;

            % 仮説空間の初期化（均等分割）
            obj.likelihood = linspace(x_min, x_max, obj.n_hypothesis);

            % 事前確率の初期化（均等分布）
            obj.h_prov = ones(1, obj.n_hypothesis) / obj.n_hypothesis;
        end

        function next_interval = predict_next_interval(obj, se)
            % 同期エラーから次の間隔を予測（ベイズ更新）
            %
            % Parameters:
            %   se - 同期エラー（秒）
            %
            % Returns:
            %   next_interval - 予測される次の間隔（秒）

            % ベイズ学習: 各仮説の事後確率を更新
            post_prov = zeros(1, obj.n_hypothesis);

            for i = 1:obj.n_hypothesis
                % 正規分布での尤度計算
                likelihood_val = normpdf(se, obj.likelihood(i), 0.3);
                post_prov(i) = likelihood_val * obj.h_prov(i);
            end

            % 正規化
            post_prov = post_prov / sum(post_prov);
            obj.h_prov = post_prov;

            % 確率的予測: 仮説から確率的にサンプリング
            cumsum_prob = cumsum(obj.h_prov);
            rand_val = rand();
            selected_idx = find(cumsum_prob >= rand_val, 1, 'first');
            selected_likelihood = obj.likelihood(selected_idx);

            % 予測値に正規分布ノイズを追加
            prediction = normrnd(selected_likelihood, 0.3);

            % 次の間隔を計算
            next_interval = (obj.config.SPAN / 2) - prediction;

            % デバッグ出力
            if isfield(obj.config, 'DEBUG_MODEL') && obj.config.DEBUG_MODEL
                fprintf('Bayes: SE=%.3f, selected_likelihood=%.3f, prediction=%.3f, result=%.3f\n', ...
                    se, selected_likelihood, prediction, next_interval);
            end
        end

        function info_str = get_model_info(obj)
            % モデル情報を文字列で返す（オーバーライド）
            [max_prob, max_idx] = max(obj.h_prov);
            most_likely_hyp = obj.likelihood(max_idx);

            info_str = sprintf('Bayesian Model (Most likely hypothesis: %.3f, prob: %.3f)', ...
                most_likely_hyp, max_prob);
        end
    end
end
