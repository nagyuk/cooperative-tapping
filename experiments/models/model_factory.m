function model = model_factory(model_type, config)
    % モデルファクトリー - 指定されたモデルタイプに応じてモデルを作成
    %
    % Input:
    %   model_type - 'sea', 'bayes', 'bib'のいずれか
    %   config - 設定構造体
    %
    % Output:
    %   model - モデル構造体
    
    model = struct();
    model.type = model_type;
    model.config = config;
    
    switch lower(model_type)
        case 'sea'
            model.cumulative_se = 0;
            model.update_count = 0;
        case {'bayes', 'bib'}
            % Bayesian/BIBモデルの初期化
            model.cumulative_se = 0;
            model.update_count = 0;
            % 将来的にはより複雑な初期化が可能
        otherwise
            error('Unknown model type: %s', model_type);
    end
end