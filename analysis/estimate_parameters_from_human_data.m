function params = estimate_parameters_from_human_data(data_dir)
    % estimate_parameters_from_human_data - Human-Humanデータからモデルパラメータを推定
    %
    % Usage:
    %   params = estimate_parameters_from_human_data('data/raw/human_human/')
    %
    % Returns:
    %   params - 推定されたパラメータ構造体
    %     .SPAN_mean           - 推奨SPAN値
    %     .SPAN_ci             - 95%信頼区間
    %     .SCALE_mean          - 推奨SCALE値
    %     .SCALE_ci            - 95%信頼区間
    %     .BAYES_N_HYPOTHESIS  - 推奨仮説数
    %     .BIB_L_MEMORY        - 推奨メモリ長

    if nargin < 1
        data_dir = fullfile(pwd, 'data', 'raw', 'human_human');
    end

    % 全Human-Humanデータを読み込み
    all_files = dir(fullfile(data_dir, '**', '*stage2_cooperative_taps.csv'));

    if isempty(all_files)
        error('Human-Humanデータが見つかりません: %s', data_dir);
    end

    fprintf('読み込み中: %d個のセッションデータ...\n', length(all_files));

    all_iti = [];
    all_asynchrony = [];
    session_data = cell(length(all_files), 1);

    for i = 1:length(all_files)
        filepath = fullfile(all_files(i).folder, all_files(i).name);
        data = readtable(filepath);

        % Inter-Tap Interval計算
        timestamps = data.timestamp;
        iti = diff(timestamps);
        all_iti = [all_iti; iti];

        % Asynchrony計算（両プレイヤー間のずれ）
        p1_taps = data.timestamp(data.player_id == 1);
        p2_taps = data.timestamp(data.player_id == 2);

        min_len = min(length(p1_taps), length(p2_taps));
        if min_len > 0
            async = abs(p1_taps(1:min_len) - p2_taps(1:min_len));
            all_asynchrony = [all_asynchrony; async];
        end

        % セッション単位のデータ保存
        session_data{i}.iti = iti;
        session_data{i}.asynchrony = async;
        session_data{i}.filename = all_files(i).name;
    end

    % === パラメータ推定 ===

    % SPAN推定（ITI中央値の2倍 = サイクル期間）
    params.SPAN_mean = 2 * median(all_iti);
    params.SPAN_ci = [prctile(all_iti*2, 2.5), prctile(all_iti*2, 97.5)];

    % SCALE推定（ITI標準偏差）
    params.SCALE_mean = std(all_iti);

    % ブートストラップで信頼区間計算
    if length(all_iti) > 100
        params.SCALE_ci = bootci(1000, @std, all_iti);
    else
        % データが少ない場合は近似
        se = params.SCALE_mean / sqrt(length(all_iti));
        params.SCALE_ci = [params.SCALE_mean - 1.96*se, params.SCALE_mean + 1.96*se];
    end

    % BIB_L_MEMORY推定（自己相関から）
    if length(all_iti) > 20
        [acf, ~] = autocorr(all_iti, min(10, floor(length(all_iti)/2)));
        significant_lag = find(acf < 0.2, 1);
        if ~isempty(significant_lag)
            params.BIB_L_MEMORY = max(1, significant_lag - 1);
        else
            params.BIB_L_MEMORY = 1;
        end
    else
        params.BIB_L_MEMORY = 1;
    end

    % BAYES_N_HYPOTHESIS推定（変動範囲から）
    % 仮説空間: 平均 ± 3SD を 0.05秒刻みでカバー
    variation_range = 6 * params.SCALE_mean;
    params.BAYES_N_HYPOTHESIS = max(10, ceil(variation_range / 0.05));

    % === 結果表示 ===
    fprintf('\n========================================\n');
    fprintf('   Human-Humanデータからの推定結果\n');
    fprintf('========================================\n');
    fprintf('データ数: %d タップ, %d セッション\n', length(all_iti), length(all_files));
    fprintf('\n');

    fprintf('--- 推奨パラメータ ---\n');
    fprintf('SPAN = %.3f秒\n', params.SPAN_mean);
    fprintf('  (95%%信頼区間: [%.3f, %.3f])\n', params.SPAN_ci(1), params.SPAN_ci(2));
    fprintf('\n');
    fprintf('SCALE = %.4f\n', params.SCALE_mean);
    fprintf('  (95%%信頼区間: [%.4f, %.4f])\n', params.SCALE_ci(1), params.SCALE_ci(2));
    fprintf('\n');
    fprintf('BAYES_N_HYPOTHESIS = %d\n', params.BAYES_N_HYPOTHESIS);
    fprintf('  (±%.2f秒の範囲を0.05秒刻みでカバー)\n', variation_range/2);
    fprintf('\n');
    fprintf('BIB_L_MEMORY = %d\n', params.BIB_L_MEMORY);
    fprintf('  (自己相関が0.2未満になるラグ)\n');
    fprintf('\n');

    fprintf('--- 詳細統計 ---\n');
    fprintf('ITI (Inter-Tap Interval):\n');
    fprintf('  平均    = %.3f秒\n', mean(all_iti));
    fprintf('  中央値  = %.3f秒\n', median(all_iti));
    fprintf('  標準偏差 = %.3f秒\n', std(all_iti));
    fprintf('  変動係数 = %.2f%%\n', 100 * std(all_iti) / mean(all_iti));
    fprintf('\n');
    fprintf('Asynchrony (プレイヤー間のずれ):\n');
    fprintf('  平均    = %.3f秒\n', mean(all_asynchrony));
    fprintf('  中央値  = %.3f秒\n', median(all_asynchrony));
    fprintf('  標準偏差 = %.3f秒\n', std(all_asynchrony));
    fprintf('\n');

    % === 可視化 ===
    figure('Name', 'Human-Human Data Analysis', 'Position', [100, 100, 1200, 800]);

    % ITI分布
    subplot(2, 3, 1);
    histogram(all_iti, 30, 'Normalization', 'pdf');
    hold on;
    xline(mean(all_iti), 'r--', 'LineWidth', 2, 'Label', sprintf('Mean=%.3f', mean(all_iti)));
    xline(median(all_iti), 'b--', 'LineWidth', 2, 'Label', sprintf('Median=%.3f', median(all_iti)));
    xlabel('Inter-Tap Interval (s)');
    ylabel('Probability Density');
    title('ITI Distribution');
    grid on;

    % ITI時系列
    subplot(2, 3, 2);
    plot(all_iti, '-o', 'MarkerSize', 3);
    hold on;
    yline(mean(all_iti), 'r--', 'Mean');
    yline(mean(all_iti) + std(all_iti), 'r:', '+1SD');
    yline(mean(all_iti) - std(all_iti), 'r:', '-1SD');
    xlabel('Tap Index');
    ylabel('ITI (s)');
    title('ITI Time Series');
    grid on;

    % 自己相関
    subplot(2, 3, 3);
    if length(all_iti) > 20
        [acf, lags] = autocorr(all_iti, min(10, floor(length(all_iti)/2)));
        stem(lags, acf, 'filled');
        hold on;
        yline(0.2, 'r--', 'Threshold=0.2');
        xlabel('Lag');
        ylabel('Autocorrelation');
        title(sprintf('ACF (Memory=%d)', params.BIB_L_MEMORY));
        grid on;
    else
        text(0.5, 0.5, 'データ不足', 'HorizontalAlignment', 'center');
    end

    % Asynchrony分布
    subplot(2, 3, 4);
    histogram(all_asynchrony, 30, 'Normalization', 'pdf');
    hold on;
    xline(mean(all_asynchrony), 'r--', 'LineWidth', 2, 'Label', sprintf('Mean=%.3f', mean(all_asynchrony)));
    xlabel('Asynchrony (s)');
    ylabel('Probability Density');
    title('Asynchrony Distribution');
    grid on;

    % セッション間比較
    subplot(2, 3, 5);
    session_means = cellfun(@(x) mean(x.iti), session_data);
    session_stds = cellfun(@(x) std(x.iti), session_data);
    errorbar(1:length(session_means), session_means, session_stds, 'o-');
    hold on;
    yline(mean(all_iti), 'r--', 'Overall Mean');
    xlabel('Session');
    ylabel('Mean ITI (s)');
    title('Session-wise Comparison');
    grid on;

    % QQプロット（正規性確認）
    subplot(2, 3, 6);
    qqplot(all_iti);
    title('Q-Q Plot (Normality Check)');
    grid on;

    % 保存されたパラメータをファイルに出力
    save('analysis/estimated_parameters.mat', 'params', 'session_data');
    fprintf('結果を保存: analysis/estimated_parameters.mat\n');
    fprintf('========================================\n');
end
