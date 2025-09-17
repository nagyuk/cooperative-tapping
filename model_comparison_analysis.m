function model_comparison_analysis()
    % 元のPythonモデルと現在のMATLABモデルの比較分析

    fprintf('=== モデル実装比較分析 ===\n\n');

    % === SEAモデル比較 ===
    fprintf('--- SEAモデル実装比較 ---\n');

    fprintf('\n**元のPython実装** (legacy/src/models/sea.py:45-47):\n');
    fprintf('  random_interval = np.random.normal(\n');
    fprintf('      (self.config.SPAN / 2) - avg_modify,\n');
    fprintf('      self.config.SCALE\n');
    fprintf('  )\n');
    fprintf('  → 公式: SPAN/2 - avg_modify + ランダム変動\n');

    fprintf('\n**現在のMATLAB実装** (experiments/models/model_inference.m:17):\n');
    fprintf('  next_interval = (model.config.SPAN / 2) - (avg_se * 0.5);\n');
    fprintf('  → 公式: SPAN/2 - (avg_se * 0.5)\n');

    fprintf('\n**重要な違い**:\n');
    fprintf('1. **補正の強度**:\n');
    fprintf('   - Python: 100%% 補正 (avg_modify)\n');
    fprintf('   - MATLAB: 50%% 補正 (avg_se * 0.5)\n');
    fprintf('2. **ランダム変動**:\n');
    fprintf('   - Python: あり (SCALE=0.1による正規分布)\n');
    fprintf('   - MATLAB: なし (完全決定論的)\n');
    fprintf('3. **設計思想**:\n');
    fprintf('   - Python: 人間の誤差を完全に相殺しようとする\n');
    fprintf('   - MATLAB: 人間の誤差を部分的に相殺しようとする\n\n');

    % === 実測データでの検証 ===
    fprintf('--- 実測データでの動作比較 ---\n');

    % 実験データの読み込み
    data_path = 'data/raw/20250916/anonymous_sea_202509161727/processed_taps.csv';
    data = readtable(data_path);
    stim_taps = data.stim_tap;
    player_taps = data.player_tap;

    % 同期エラーの計算
    sync_errors = (player_taps - stim_taps) - 1.0;

    fprintf('\n**実測データ**: %d個のSE値\n', length(sync_errors));
    fprintf('平均SE: %.3f秒, 標準偏差: %.3f秒\n', mean(sync_errors), std(sync_errors));

    % Python方式シミュレーション
    cumulative_modify = 0;
    fprintf('\n**Pythonモデルシミュレーション** (完全補正):\n');
    for i = 1:5
        se = sync_errors(i);
        cumulative_modify = cumulative_modify + se;
        avg_modify = cumulative_modify / i;
        python_interval = 1.0 - avg_modify; % ランダム変動除く

        fprintf('  Step %d: SE=%.3f, AvgModify=%.3f, NextInterval=%.3f\n', ...
            i, se, avg_modify, python_interval);
    end

    % MATLAB方式 (現在の実装)
    cumulative_se = 0;
    fprintf('\n**MATLABモデル** (部分補正):\n');
    for i = 1:5
        se = sync_errors(i);
        cumulative_se = cumulative_se + se;
        avg_se = cumulative_se / i;
        matlab_interval = 1.0 - (avg_se * 0.5);

        fprintf('  Step %d: SE=%.3f, AvgSE=%.3f, NextInterval=%.3f\n', ...
            i, se, avg_se, matlab_interval);
    end

    % === 理論的問題の特定 ===
    fprintf('\n--- 理論的問題の特定 ---\n');

    fprintf('\n**1. 反応時間の扱い**:\n');
    fprintf('   測定されるSE = 反応時間 + 真の同期エラー\n');
    fprintf('   現在: 反応時間も「エラー」として補正対象\n');
    fprintf('   問題: システムが過度に急いでしまう\n');

    fprintf('\n**2. 学習の方向性**:\n');
    fprintf('   人間が遅れる → システムが急ぐ → さらに人間が遅れる\n');
    fprintf('   → 悪循環による安定性の欠如\n');

    fprintf('\n**3. 固定補正係数の問題**:\n');
    fprintf('   0.5という係数に理論的根拠なし\n');
    fprintf('   個人差、学習効果、疲労等を無視\n');

    % === 改善アプローチの提案 ===
    fprintf('\n--- 改善アプローチ提案 ---\n');

    fprintf('\n**提案1: 反応時間オフセット導入**\n');
    fprintf('  adjusted_se = raw_se - estimated_reaction_time\n');
    fprintf('  → 真の同期エラーのみを補正対象とする\n');

    fprintf('\n**提案2: 適応的協調アプローチ**\n');
    fprintf('  next_interval = SPAN/2 + (adjusted_se * adaptive_gain)\n');
    fprintf('  → 人間に合わせる方向の調整\n');

    fprintf('\n**提案3: ランダム変動の復活**\n');
    fprintf('  予測可能性を下げ、自然な協調を促進\n');

    fprintf('\n**提案4: 学習率の動的調整**\n');
    fprintf('  初期: 大きな調整（探索）\n');
    fprintf('  後期: 小さな調整（安定化）\n');

    % === 実装優先度 ===
    fprintf('\n--- 実装優先度 ---\n');
    fprintf('**高優先度**:\n');
    fprintf('1. 反応時間推定とオフセット導入\n');
    fprintf('2. 正の補正ロジック（協調方向）\n');
    fprintf('3. ランダム変動の復活\n');
    fprintf('\n**中優先度**:\n');
    fprintf('4. 適応的補正係数\n');
    fprintf('5. 学習率の動的調整\n');
    fprintf('\n**低優先度**:\n');
    fprintf('6. 高度なBayesian実装\n');
    fprintf('7. 個人差対応アルゴリズム\n');

    fprintf('\n=== 分析完了 ===\n');
end