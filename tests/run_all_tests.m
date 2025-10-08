function run_all_tests()
    % 統合テストスイート - すべてのユニットテストを実行
    %
    % Usage:
    %   run_all_tests()

    fprintf('\n');
    fprintf('╔════════════════════════════════════════════════════════╗\n');
    fprintf('║  Cooperative Tapping Experiment System v2.0            ║\n');
    fprintf('║  Unified OOP Architecture - Unit Test Suite            ║\n');
    fprintf('╚════════════════════════════════════════════════════════╝\n');

    % テスト開始時刻
    test_start_time = datetime('now');

    % パス追加
    addpath(genpath('core'));
    addpath(genpath('experiments'));
    addpath(genpath('tests'));

    % テスト結果集計
    all_results = struct();
    all_results.tests = {};
    all_results.total = 0;
    all_results.passed = 0;
    all_results.failed = 0;

    %% Test 1: TimingController
    fprintf('\n');
    fprintf('┌────────────────────────────────────────────────────────┐\n');
    fprintf('│ Running: TimingController Tests                        │\n');
    fprintf('└────────────────────────────────────────────────────────┘\n');

    try
        test_TimingController();
        all_results.tests{end+1} = struct('name', 'TimingController', 'status', 'PASSED');
        all_results.passed = all_results.passed + 1;
    catch ME
        fprintf('❌ TimingController tests FAILED: %s\n', ME.message);
        all_results.tests{end+1} = struct('name', 'TimingController', 'status', 'FAILED');
        all_results.failed = all_results.failed + 1;
    end
    all_results.total = all_results.total + 1;

    %% Test 2: DataRecorder
    fprintf('\n');
    fprintf('┌────────────────────────────────────────────────────────┐\n');
    fprintf('│ Running: DataRecorder Tests                            │\n');
    fprintf('└────────────────────────────────────────────────────────┘\n');

    try
        test_DataRecorder();
        all_results.tests{end+1} = struct('name', 'DataRecorder', 'status', 'PASSED');
        all_results.passed = all_results.passed + 1;
    catch ME
        fprintf('❌ DataRecorder tests FAILED: %s\n', ME.message);
        all_results.tests{end+1} = struct('name', 'DataRecorder', 'status', 'FAILED');
        all_results.failed = all_results.failed + 1;
    end
    all_results.total = all_results.total + 1;

    %% Test 3: Models (SEA, Bayesian, BIB)
    fprintf('\n');
    fprintf('┌────────────────────────────────────────────────────────┐\n');
    fprintf('│ Running: Model Classes Tests (SEA/Bayesian/BIB)        │\n');
    fprintf('└────────────────────────────────────────────────────────┘\n');

    try
        test_Models();
        all_results.tests{end+1} = struct('name', 'Models', 'status', 'PASSED');
        all_results.passed = all_results.passed + 1;
    catch ME
        fprintf('❌ Model tests FAILED: %s\n', ME.message);
        all_results.tests{end+1} = struct('name', 'Models', 'status', 'FAILED');
        all_results.failed = all_results.failed + 1;
    end
    all_results.total = all_results.total + 1;

    %% Final Report
    test_end_time = datetime('now');
    duration = test_end_time - test_start_time;

    fprintf('\n');
    fprintf('╔════════════════════════════════════════════════════════╗\n');
    fprintf('║                  FINAL TEST REPORT                     ║\n');
    fprintf('╚════════════════════════════════════════════════════════╝\n\n');

    fprintf('Test Suites:\n');
    for i = 1:length(all_results.tests)
        test = all_results.tests{i};
        if strcmp(test.status, 'PASSED')
            fprintf('  ✅ %-30s %s\n', test.name, test.status);
        else
            fprintf('  ❌ %-30s %s\n', test.name, test.status);
        end
    end

    fprintf('\n');
    fprintf('Summary:\n');
    fprintf('  Total Test Suites:  %d\n', all_results.total);
    fprintf('  Passed:             %d\n', all_results.passed);
    fprintf('  Failed:             %d\n', all_results.failed);
    fprintf('  Success Rate:       %.1f%%\n', (all_results.passed / all_results.total) * 100);
    fprintf('  Duration:           %s\n', char(duration));

    fprintf('\n');
    if all_results.failed == 0
        fprintf('╔════════════════════════════════════════════════════════╗\n');
        fprintf('║  🎉 ALL TESTS PASSED! SYSTEM IS READY FOR USE! 🎉    ║\n');
        fprintf('╚════════════════════════════════════════════════════════╝\n\n');
    else
        fprintf('╔════════════════════════════════════════════════════════╗\n');
        fprintf('║  ⚠️  SOME TESTS FAILED - PLEASE REVIEW FAILURES ⚠️    ║\n');
        fprintf('╚════════════════════════════════════════════════════════╝\n\n');
    end

    fprintf('Test completed at: %s\n\n', datestr(test_end_time));
end
