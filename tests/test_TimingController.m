function test_TimingController()
    % TimingControllerクラスのユニットテスト

    fprintf('\n========================================\n');
    fprintf('  TimingController Unit Tests\n');
    fprintf('========================================\n\n');

    % パス追加
    addpath(genpath('core'));

    total_tests = 0;
    passed_tests = 0;

    try
        % Test 1: 初期化
        fprintf('Test 1: 初期化テスト...\n');
        timer = TimingController();
        assert(~isempty(timer), 'Timer creation failed');
        passed_tests = passed_tests + 1;
        fprintf('  ✅ PASSED\n\n');
        total_tests = total_tests + 1;

    catch ME
        fprintf('  ❌ FAILED: %s\n\n', ME.message);
        total_tests = total_tests + 1;
    end

    try
        % Test 2: クロックスタート
        fprintf('Test 2: クロックスタートテスト...\n');
        timer = TimingController();
        timer.start();
        assert(timer.is_started, 'Clock not started');
        assert(~isempty(timer.clock_start), 'Clock start time not set');
        passed_tests = passed_tests + 1;
        fprintf('  ✅ PASSED\n\n');
        total_tests = total_tests + 1;

    catch ME
        fprintf('  ❌ FAILED: %s\n\n', ME.message);
        total_tests = total_tests + 1;
    end

    try
        % Test 3: 経過時間測定精度
        fprintf('Test 3: 経過時間測定精度テスト...\n');
        timer = TimingController();
        timer.start();
        pause(0.1);
        elapsed = timer.get_elapsed_time();
        assert(elapsed >= 0.09 && elapsed <= 0.15, ...
            sprintf('Timing error too large: %.3f sec', elapsed));
        fprintf('  測定値: %.3f秒 (期待値: 0.10秒)\n', elapsed);
        passed_tests = passed_tests + 1;
        fprintf('  ✅ PASSED\n\n');
        total_tests = total_tests + 1;

    catch ME
        fprintf('  ❌ FAILED: %s\n\n', ME.message);
        total_tests = total_tests + 1;
    end

    try
        % Test 4: スケジュール生成
        fprintf('Test 4: スケジュール生成テスト...\n');
        timer = TimingController();
        schedule = timer.create_schedule(0.5, 1.0, 5);
        expected = [0.5, 1.5, 2.5, 3.5, 4.5];
        assert(length(schedule) == 5, 'Schedule length mismatch');
        assert(all(abs(schedule - expected) < 0.001), 'Schedule values mismatch');
        fprintf('  生成スケジュール: [%.1f, %.1f, %.1f, %.1f, %.1f]\n', schedule);
        passed_tests = passed_tests + 1;
        fprintf('  ✅ PASSED\n\n');
        total_tests = total_tests + 1;

    catch ME
        fprintf('  ❌ FAILED: %s\n\n', ME.message);
        total_tests = total_tests + 1;
    end

    try
        % Test 5: イベント記録
        fprintf('Test 5: イベント記録テスト...\n');
        timer = TimingController();
        timer.start();
        pause(0.05);
        timestamp = timer.record_event();
        assert(timestamp >= 0.04 && timestamp <= 0.10, 'Event timestamp error');
        fprintf('  記録タイムスタンプ: %.3f秒\n', timestamp);
        passed_tests = passed_tests + 1;
        fprintf('  ✅ PASSED\n\n');
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
        fprintf('✅ All TimingController tests PASSED!\n\n');
    else
        fprintf('⚠️  Some tests FAILED (%d/%d)\n\n', total_tests - passed_tests, total_tests);
    end
end
