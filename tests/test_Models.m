function test_Models()
    % モデルクラス（SEA, Bayesian, BIB）のユニットテスト

    fprintf('\n========================================\n');
    fprintf('  Model Classes Unit Tests\n');
    fprintf('========================================\n\n');

    % パス追加
    addpath(genpath('core'));
    addpath(genpath('experiments'));

    % テスト用設定
    config = struct();
    config.SPAN = 2.0;
    config.SCALE = 0.02;
    config.BAYES_N_HYPOTHESIS = 20;
    config.BIB_L_MEMORY = 1;
    config.DEBUG_MODEL = false;

    total_tests = 0;
    passed_tests = 0;

    %% SEAModel Tests
    fprintf('--- SEAModel Tests ---\n\n');

    try
        % Test 1: SEA初期化
        fprintf('Test 1: SEA初期化テスト...\n');
        model = SEAModel(config);
        assert(strcmp(model.model_type, 'SEA'), 'Model type mismatch');
        assert(~isempty(model), 'Model creation failed');
        passed_tests = passed_tests + 1;
        fprintf('  ✅ PASSED\n\n');
        total_tests = total_tests + 1;

    catch ME
        fprintf('  ❌ FAILED: %s\n\n', ME.message);
        total_tests = total_tests + 1;
    end

    try
        % Test 2: SEA予測（SEがゼロ）
        fprintf('Test 2: SEA予測テスト (SE=0)...\n');
        model = SEAModel(config);
        next_interval = model.predict_next_interval(0.0);
        expected = config.SPAN / 2;  % 1.0秒
        assert(abs(next_interval - expected) < 0.1, ...
            sprintf('Prediction error too large: %.3f (expected ~%.3f)', next_interval, expected));
        fprintf('  予測値: %.3f秒 (期待値: ~%.3f秒)\n', next_interval, expected);
        passed_tests = passed_tests + 1;
        fprintf('  ✅ PASSED\n\n');
        total_tests = total_tests + 1;

    catch ME
        fprintf('  ❌ FAILED: %s\n\n', ME.message);
        total_tests = total_tests + 1;
    end

    try
        % Test 3: SEA複数回更新
        fprintf('Test 3: SEA複数回更新テスト...\n');
        model = SEAModel(config);
        for i = 1:10
            se = normrnd(0, 0.01);
            next_interval = model.predict_next_interval(se);
        end
        info = model.get_model_info();
        assert(~isempty(info), 'Model info failed');
        fprintf('  %s\n', info);
        passed_tests = passed_tests + 1;
        fprintf('  ✅ PASSED\n\n');
        total_tests = total_tests + 1;

    catch ME
        fprintf('  ❌ FAILED: %s\n\n', ME.message);
        total_tests = total_tests + 1;
    end

    %% BayesianModel Tests
    fprintf('--- BayesianModel Tests ---\n\n');

    try
        % Test 4: Bayesian初期化
        fprintf('Test 4: Bayesian初期化テスト...\n');
        model = BayesianModel(config);
        assert(strcmp(model.model_type, 'Bayesian'), 'Model type mismatch');
        passed_tests = passed_tests + 1;
        fprintf('  ✅ PASSED\n\n');
        total_tests = total_tests + 1;

    catch ME
        fprintf('  ❌ FAILED: %s\n\n', ME.message);
        total_tests = total_tests + 1;
    end

    try
        % Test 5: Bayesian予測
        fprintf('Test 5: Bayesian予測テスト...\n');
        model = BayesianModel(config);
        next_interval = model.predict_next_interval(0.0);
        assert(~isnan(next_interval), 'Prediction returned NaN');
        assert(~isinf(next_interval), 'Prediction returned Inf');
        fprintf('  予測値: %.3f秒\n', next_interval);
        passed_tests = passed_tests + 1;
        fprintf('  ✅ PASSED\n\n');
        total_tests = total_tests + 1;

    catch ME
        fprintf('  ❌ FAILED: %s\n\n', ME.message);
        total_tests = total_tests + 1;
    end

    try
        % Test 6: Bayesian学習（事後確率更新）
        fprintf('Test 6: Bayesian学習テスト...\n');
        model = BayesianModel(config);

        % 一貫したSEで学習
        for i = 1:20
            model.predict_next_interval(0.5);
        end

        info = model.get_model_info();
        fprintf('  %s\n', info);
        passed_tests = passed_tests + 1;
        fprintf('  ✅ PASSED\n\n');
        total_tests = total_tests + 1;

    catch ME
        fprintf('  ❌ FAILED: %s\n\n', ME.message);
        total_tests = total_tests + 1;
    end

    %% BIBModel Tests
    fprintf('--- BIBModel Tests ---\n\n');

    try
        % Test 7: BIB初期化
        fprintf('Test 7: BIB初期化テスト...\n');
        model = BIBModel(config);
        assert(strcmp(model.model_type, 'BIB'), 'Model type mismatch');
        passed_tests = passed_tests + 1;
        fprintf('  ✅ PASSED\n\n');
        total_tests = total_tests + 1;

    catch ME
        fprintf('  ❌ FAILED: %s\n\n', ME.message);
        total_tests = total_tests + 1;
    end

    try
        % Test 8: BIB予測
        fprintf('Test 8: BIB予測テスト...\n');
        model = BIBModel(config);
        next_interval = model.predict_next_interval(0.0);
        assert(~isnan(next_interval), 'Prediction returned NaN');
        assert(~isinf(next_interval), 'Prediction returned Inf');
        fprintf('  予測値: %.3f秒\n', next_interval);
        passed_tests = passed_tests + 1;
        fprintf('  ✅ PASSED\n\n');
        total_tests = total_tests + 1;

    catch ME
        fprintf('  ❌ FAILED: %s\n\n', ME.message);
        total_tests = total_tests + 1;
    end

    try
        % Test 9: BIB逆ベイズ学習
        fprintf('Test 9: BIB逆ベイズ学習テスト...\n');
        model = BIBModel(config);

        % 複数回学習
        for i = 1:20
            se = normrnd(0.3, 0.1);
            model.predict_next_interval(se);
        end

        info = model.get_model_info();
        fprintf('  %s\n', info);
        passed_tests = passed_tests + 1;
        fprintf('  ✅ PASSED\n\n');
        total_tests = total_tests + 1;

    catch ME
        fprintf('  ❌ FAILED: %s\n\n', ME.message);
        total_tests = total_tests + 1;
    end

    %% モデル比較テスト
    fprintf('--- Model Comparison Test ---\n\n');

    try
        % Test 10: 3つのモデルの動作比較
        fprintf('Test 10: モデル動作比較テスト...\n');
        sea = SEAModel(config);
        bayes = BayesianModel(config);
        bib = BIBModel(config);

        se_values = [0.1, -0.05, 0.15, -0.1, 0.05];

        fprintf('  SE値: [%.2f, %.2f, %.2f, %.2f, %.2f]\n', se_values);
        fprintf('\n  予測結果:\n');
        fprintf('  %-10s %-10s %-10s\n', 'SEA', 'Bayesian', 'BIB');

        for i = 1:length(se_values)
            sea_pred = sea.predict_next_interval(se_values(i));
            bayes_pred = bayes.predict_next_interval(se_values(i));
            bib_pred = bib.predict_next_interval(se_values(i));
            fprintf('  %.3f     %.3f      %.3f\n', sea_pred, bayes_pred, bib_pred);
        end

        passed_tests = passed_tests + 1;
        fprintf('\n  ✅ PASSED\n\n');
        total_tests = total_tests + 1;

    catch ME
        fprintf('  ❌ FAILED: %s\n\n', ME.message);
        total_tests = total_tests + 1;
    end

    % 結果サマリー
    fprintf('========================================\n');
    fprintf('  Test Results: %d/%d PASSED\n', passed_tests, total_tests);
    fprintf('========================================\n\n');

    if passed_tests == total_tests
        fprintf('✅ All Model tests PASSED!\n\n');
    else
        fprintf('⚠️  Some tests FAILED (%d/%d)\n\n', total_tests - passed_tests, total_tests);
    end
end
