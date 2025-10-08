classdef BIBModel < BaseModel
    % BIBModel - Bayesian-Inverse Bayesian モデル
    %
    % ベイズ推論に逆ベイズ学習を組み合わせたモデル
    % メモリを使用して仮説空間を動的に更新

    properties (Access = public)
        model_type = 'BIB'
    end

    properties (Access = private)
        likelihood  % 仮説空間（-3 ~ 3の範囲）
        h_prov      % 各仮説の事後確率
        n_hypothesis % 仮説数
        l_memory    % メモリ長
        memory      % SEのメモリ配列
    end

    methods (Access = public)
        function obj = BIBModel(config)
            % BIBModel コンストラクタ

            obj@BaseModel(config);

            % Bayesian部分の初期化
            obj.n_hypothesis = config.BAYES_N_HYPOTHESIS;  % 通常20
            x_min = -3;
            x_max = 3;

            % 仮説空間の初期化（均等分割）
            obj.likelihood = linspace(x_min, x_max, obj.n_hypothesis);

            % 事前確率の初期化（均等分布）
            obj.h_prov = ones(1, obj.n_hypothesis) / obj.n_hypothesis;

            % BIB固有のパラメータ
            obj.l_memory = config.BIB_L_MEMORY;  % 通常1

            % メモリの初期化（正規分布で初期化）
            if obj.l_memory > 0
                obj.memory = normrnd(0.0, config.SCALE, [1, obj.l_memory]);
            else
                obj.memory = [];
            end
        end

        function next_interval = predict_next_interval(obj, se)
            % 同期エラーから次の間隔を予測（逆ベイズ + ベイズ更新）
            %
            % Parameters:
            %   se - 同期エラー（秒）
            %
            % Returns:
            %   next_interval - 予測される次の間隔（秒）

            % === Inverse Bayesian学習 ===
            if obj.l_memory > 0
                % メモリの平均から新しい仮説を計算
                new_hypo = mean(obj.memory);

                % 確率分布を反転
                inv_h_prov = (1 - obj.h_prov) / (obj.n_hypothesis - 1);

                % 反転確率に基づいて仮説を選択して置換
                cumsum_inv = cumsum(inv_h_prov);
                rand_val = rand();
                replace_idx = find(cumsum_inv >= rand_val, 1, 'first');
                obj.likelihood(replace_idx) = new_hypo;

                % メモリを更新（古い値を削除、新しいSEを追加）
                obj.memory = [obj.memory(2:end), se];
            end

            % === 通常のベイズ推論 ===
            post_prov = zeros(1, obj.n_hypothesis);

            for i = 1:obj.n_hypothesis
                % 正規分布での尤度計算
                likelihood_val = normpdf(se, obj.likelihood(i), 0.3);
                post_prov(i) = likelihood_val * obj.h_prov(i);
            end

            % 正規化
            post_prov = post_prov / sum(post_prov);
            obj.h_prov = post_prov;

            % 確率的予測
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
                fprintf('BIB: SE=%.3f, selected_likelihood=%.3f, prediction=%.3f, result=%.3f\n', ...
                    se, selected_likelihood, prediction, next_interval);
            end
        end

        function info_str = get_model_info(obj)
            % モデル情報を文字列で返す（オーバーライド）
            [max_prob, max_idx] = max(obj.h_prov);
            most_likely_hyp = obj.likelihood(max_idx);

            if obj.l_memory > 0
                info_str = sprintf('BIB Model (Most likely: %.3f, prob: %.3f, Memory: %d)', ...
                    most_likely_hyp, max_prob, obj.l_memory);
            else
                info_str = sprintf('BIB Model (Most likely: %.3f, prob: %.3f, No memory)', ...
                    most_likely_hyp, max_prob);
            end
        end
    end
end
