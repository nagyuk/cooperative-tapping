classdef (Abstract) BaseModel < handle
    % BaseModel - タッピングモデル抽象基底クラス
    %
    % 全モデル（SEA, Bayesian, BIB）の共通インターフェース

    properties (Access = protected)
        config  % 実験設定
    end

    properties (Abstract, Access = public)
        model_type  % 'SEA', 'Bayesian', 'BIB'
    end

    methods (Abstract, Access = public)
        % 同期エラーから次の間隔を予測
        next_interval = predict_next_interval(obj, se)
    end

    methods (Access = public)
        function obj = BaseModel(config)
            % BaseModel コンストラクタ
            %
            % Parameters:
            %   config - 実験設定構造体

            obj.config = config;
        end

        function info_str = get_model_info(obj)
            % モデル情報を文字列で返す
            info_str = sprintf('Model: %s', obj.model_type);
        end
    end
end
