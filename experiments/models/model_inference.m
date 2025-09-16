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
            next_interval = (model.config.SPAN / 2) - (avg_se * 0.5);
            
        case 'bayes'
            % Bayesian モデル (簡易実装)
            next_interval = (model.config.SPAN / 2) + (se * 0.2);
            
        case 'bib'
            % BIB (Bayesian-Inverse Bayesian) モデル (簡易実装)
            next_interval = (model.config.SPAN / 2) + (se * 0.4);
            
        otherwise
            % デフォルト: 固定補正
            next_interval = (model.config.SPAN / 2) + (se * 0.3);
    end
    
    % 間隔の制約 (0.2秒 - 1.2秒)
    next_interval = max(0.2, min(1.2, next_interval));
end