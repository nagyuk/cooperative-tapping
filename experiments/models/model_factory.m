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
        case 'bayes'
            % Bayesianモデルの本格初期化 - Python版と同様
            n_hypothesis = config.BAYES_N_HYPOTHESIS; % 20
            x_min = -3;
            x_max = 3;

            % 仮説空間の初期化 (Python版: linspace(-3, 3, 20))
            model.likelihood = linspace(x_min, x_max, n_hypothesis);

            % 事前確率の初期化 (均等分布)
            model.h_prov = ones(1, n_hypothesis) / n_hypothesis;

        case 'bib'
            % BIBモデルの本格初期化 - Python版と同様
            n_hypothesis = config.BAYES_N_HYPOTHESIS; % 20
            x_min = -3;
            x_max = 3;

            % Bayesian部分の初期化
            model.likelihood = linspace(x_min, x_max, n_hypothesis);
            model.h_prov = ones(1, n_hypothesis) / n_hypothesis;

            % BIB固有のパラメータ
            model.l_memory = config.BIB_L_MEMORY; % 1

            % メモリの初期化 (Python版: np.random.normal(0.0, scale, l_memory))
            if model.l_memory > 0
                model.memory = normrnd(0.0, config.SCALE, [1, model.l_memory]);
            end
        otherwise
            error('Unknown model type: %s', model_type);
    end
end