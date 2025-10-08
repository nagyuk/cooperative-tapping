classdef SEAModel < BaseModel
    % SEAModel - Synchronization Error Averaging モデル
    %
    % 同期エラーの平均値を用いて次のタップ間隔を予測

    properties (Access = public)
        model_type = 'SEA'
    end

    properties (Access = private)
        cumulative_se = 0  % 累積同期エラー
        update_count = 0   % 更新回数
    end

    methods (Access = public)
        function obj = SEAModel(config)
            % SEAModel コンストラクタ
            obj@BaseModel(config);
        end

        function next_interval = predict_next_interval(obj, se)
            % 同期エラーから次の間隔を予測
            %
            % Parameters:
            %   se - 同期エラー（秒）
            %
            % Returns:
            %   next_interval - 予測される次の間隔（秒）

            % 累積SEを更新
            obj.cumulative_se = obj.cumulative_se + se;
            obj.update_count = obj.update_count + 1;

            % 平均SEを計算
            avg_se = obj.cumulative_se / obj.update_count;

            % 次の間隔を予測: (SPAN/2) - avg_SE + ランダム変動
            base_interval = (obj.config.SPAN / 2) - avg_se;
            random_variation = normrnd(0, obj.config.SCALE);
            next_interval = base_interval + random_variation;

            % デバッグ出力
            if isfield(obj.config, 'DEBUG_MODEL') && obj.config.DEBUG_MODEL
                fprintf('SEA: SE=%.3f, avg_SE=%.3f, base=%.3f, variation=%.3f, result=%.3f\n', ...
                    se, avg_se, base_interval, random_variation, next_interval);
            end
        end

        function info_str = get_model_info(obj)
            % モデル情報を文字列で返す（オーバーライド）
            if obj.update_count > 0
                avg_se = obj.cumulative_se / obj.update_count;
                info_str = sprintf('SEA Model (Updates: %d, Avg SE: %.3f)', ...
                    obj.update_count, avg_se);
            else
                info_str = 'SEA Model (Not yet updated)';
            end
        end
    end
end
