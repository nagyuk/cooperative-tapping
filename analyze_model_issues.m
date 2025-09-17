function analyze_model_issues()
    % 現在のモデル実装の課題を定量的に分析する

    fprintf('=== モデル課題分析 ===\n');

    % 実験データの読み込み
    data_path = 'data/raw/20250916/anonymous_sea_202509161727/processed_taps.csv';
    if ~exist(data_path, 'file')
        error('実験データが見つかりません: %s', data_path);
    end

    data = readtable(data_path);
    stim_taps = data.stim_tap;
    player_taps = data.player_tap;

    % ITI（Inter-Tap Interval）の計算
    itis_stim_to_player = player_taps - stim_taps;
    itis_player_to_stim = stim_taps(2:end) - player_taps(1:end-1);

    fprintf('\n--- ITI分析結果 ---\n');
    fprintf('期待値:\n');
    fprintf('  Stim → Player ITI: 1.0秒 (SPAN/2)\n');
    fprintf('  Player → Stim ITI: 1.0秒 (SPAN/2)\n\n');

    fprintf('実測値:\n');
    fprintf('  Stim → Player ITI: %.3f ± %.3f秒\n', ...
        mean(itis_stim_to_player), std(itis_stim_to_player));
    fprintf('  Player → Stim ITI: %.3f ± %.3f秒\n', ...
        mean(itis_player_to_stim), std(itis_player_to_stim));

    % 遅延分析
    delay_stim_to_player = mean(itis_stim_to_player) - 1.0;
    delay_player_to_stim = mean(itis_player_to_stim) - 1.0;

    fprintf('\n遅延分析:\n');
    fprintf('  Stim → Player遅延: %.3f秒 (%.1f%%)\n', ...
        delay_stim_to_player, delay_stim_to_player / 1.0 * 100);
    fprintf('  Player → Stim遅延: %.3f秒 (%.1f%%)\n', ...
        delay_player_to_stim, delay_player_to_stim / 1.0 * 100);

    % モデルロジック分析
    fprintf('\n--- 現在のモデルロジック問題分析 ---\n');

    % 同期エラー（SE）の計算
    sync_errors = itis_stim_to_player - 1.0;
    fprintf('同期エラー (SE):\n');
    fprintf('  平均SE: %.3f秒\n', mean(sync_errors));
    fprintf('  SE標準偏差: %.3f秒\n', std(sync_errors));

    % SEAモデルのシミュレーション
    fprintf('\nSEAモデル動作シミュレーション:\n');
    cumulative_se = 0;
    span_half = 1.0; % SPAN/2 = 1.0秒

    for i = 1:5
        se = sync_errors(i);
        cumulative_se = cumulative_se + se;
        avg_se = cumulative_se / i;
        predicted_interval = span_half - (avg_se * 0.5);

        fprintf('  Step %d: SE=%.3f, AvgSE=%.3f, NextInterval=%.3f\n', ...
            i, se, avg_se, predicted_interval);
    end

    % 問題の特定
    fprintf('\n--- 特定された問題 ---\n');
    fprintf('1. SEAモデルの逆補正: next_interval = SPAN/2 - (avg_se * 0.5)\n');
    fprintf('   → 人間が遅れると、システムがさらに間隔を短縮\n');
    fprintf('   → 悪循環により、さらなる遅延を誘発\n\n');

    fprintf('2. 人間の反応時間未考慮:\n');
    fprintf('   → 平均遅延%.3f秒の大部分は人間の反応時間\n', delay_stim_to_player);
    fprintf('   → モデルは反応時間を「エラー」として誤認\n\n');

    fprintf('3. 固定補正係数:\n');
    fprintf('   → 0.5という係数に理論的根拠なし\n');
    fprintf('   → 個人差や学習効果を無視\n\n');

    % 改善提案
    fprintf('--- 改善提案 ---\n');
    fprintf('1. 反応時間オフセット導入\n');
    fprintf('2. 正の補正ロジック（人間に合わせる方向）\n');
    fprintf('3. 適応的補正係数\n');
    fprintf('4. 学習アルゴリズムの改良\n');

    % データ可視化用の値を出力
    fprintf('\n--- 分析用データ ---\n');
    fprintf('ITI_stim_to_player = [');
    fprintf('%.3f ', itis_stim_to_player(1:min(10, length(itis_stim_to_player))));
    fprintf('];\n');

    fprintf('ITI_player_to_stim = [');
    fprintf('%.3f ', itis_player_to_stim(1:min(10, length(itis_player_to_stim))));
    fprintf('];\n');
end