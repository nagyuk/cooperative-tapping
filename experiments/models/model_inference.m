function next_interval = model_inference(model, se)
    % モデル推論 - 同期エラーから次の間隔を予測
    %
    % Input:
    %   model - モデル構造体
    %   se - 同期エラー（秒）
    %
    % Output:
    %   next_interval - 予測される次の間隔（秒）
    
    switch lower(model.type)
        case 'sea'
            % SEA (Synchronization Error Averaging) モデル
            model.cumulative_se = model.cumulative_se + se;
            model.update_count = model.update_count + 1;
            avg_se = model.cumulative_se / model.update_count;
            % Python版と同様: 100%補正 + ランダム変動
            base_interval = (model.config.SPAN / 2) - avg_se;
            random_variation = normrnd(0, model.config.SCALE);
            next_interval = base_interval + random_variation;
            
        case 'bayes'
            % Bayesian モデル - Python版と同様の本格実装
            % ベイズ学習: 各仮説の事後確率を更新
            n_hyp = length(model.likelihood);
            post_prov = zeros(1, n_hyp);

            for i = 1:n_hyp
                % 正規分布での尤度計算 (Python版: norm(likelihood[i], 0.3).pdf(se))
                likelihood_val = normpdf(se, model.likelihood(i), 0.3);
                post_prov(i) = likelihood_val * model.h_prov(i);
            end

            % 正規化
            post_prov = post_prov / sum(post_prov);
            model.h_prov = post_prov;

            % 確率的予測: 仮説から確率的にサンプリング
            % Python版: np.random.choice(likelihood, p=h_prov)
            cumsum_prob = cumsum(model.h_prov);
            rand_val = rand();
            selected_idx = find(cumsum_prob >= rand_val, 1, 'first');
            selected_likelihood = model.likelihood(selected_idx);

            % 予測値に正規分布ノイズを追加
            prediction = normrnd(selected_likelihood, 0.3);

            % Python版と同様: (SPAN/2) - prediction
            next_interval = (model.config.SPAN / 2) - prediction;
            
        case 'bib'
            % BIB (Bayesian-Inverse Bayesian) モデル - Python版と同様の本格実装

            % Inverse Bayesian学習
            if model.l_memory > 0
                % メモリの平均から新しい仮説を計算
                new_hypo = mean(model.memory);

                % 確率分布を反転 (Python版: (1 - h_prov) / (n_hypothesis - 1))
                n_hyp = length(model.h_prov);
                inv_h_prov = (1 - model.h_prov) / (n_hyp - 1);

                % 反転確率に基づいて仮説を選択して置換
                cumsum_inv = cumsum(inv_h_prov);
                rand_val = rand();
                replace_idx = find(cumsum_inv >= rand_val, 1, 'first');
                model.likelihood(replace_idx) = new_hypo;

                % メモリを更新 (Python版: np.roll(memory, -1))
                model.memory = [model.memory(2:end), se];
            end

            % 通常のベイズ推論を実行（Bayesianモデルと同じロジック）
            n_hyp = length(model.likelihood);
            post_prov = zeros(1, n_hyp);

            for i = 1:n_hyp
                likelihood_val = normpdf(se, model.likelihood(i), 0.3);
                post_prov(i) = likelihood_val * model.h_prov(i);
            end

            post_prov = post_prov / sum(post_prov);
            model.h_prov = post_prov;

            % 確率的予測
            cumsum_prob = cumsum(model.h_prov);
            rand_val = rand();
            selected_idx = find(cumsum_prob >= rand_val, 1, 'first');
            selected_likelihood = model.likelihood(selected_idx);

            prediction = normrnd(selected_likelihood, 0.3);
            next_interval = (model.config.SPAN / 2) - prediction;
            
        otherwise
            % デフォルト: 固定補正
            next_interval = (model.config.SPAN / 2) + (se * 0.3);
    end
    
    % 間隔の制約 (0.2秒 - 1.2秒)
    next_interval = max(0.2, min(1.2, next_interval));
end