function test_DataRecorder()
    % DataRecorderクラスのユニットテスト

    fprintf('\n========================================\n');
    fprintf('  DataRecorder Unit Tests\n');
    fprintf('========================================\n\n');

    % パス追加
    addpath(genpath('core'));

    total_tests = 0;
    passed_tests = 0;

    try
        % Test 1: 初期化（単一参加者）
        fprintf('Test 1: 単一参加者初期化テスト...\n');
        recorder = DataRecorder('human_computer', 'P001');
        assert(strcmp(recorder.experiment_type, 'human_computer'), 'Experiment type mismatch');
        assert(length(recorder.participant_ids) == 1, 'Participant count mismatch');
        assert(strcmp(recorder.participant_ids{1}, 'P001'), 'Participant ID mismatch');
        passed_tests = passed_tests + 1;
        fprintf('  ✅ PASSED\n\n');
        total_tests = total_tests + 1;

    catch ME
        fprintf('  ❌ FAILED: %s\n\n', ME.message);
        total_tests = total_tests + 1;
    end

    try
        % Test 2: 初期化（複数参加者）
        fprintf('Test 2: 複数参加者初期化テスト...\n');
        recorder = DataRecorder('human_human', {'P001', 'P002'});
        assert(strcmp(recorder.experiment_type, 'human_human'), 'Experiment type mismatch');
        assert(length(recorder.participant_ids) == 2, 'Participant count mismatch');
        passed_tests = passed_tests + 1;
        fprintf('  ✅ PASSED\n\n');
        total_tests = total_tests + 1;

    catch ME
        fprintf('  ❌ FAILED: %s\n\n', ME.message);
        total_tests = total_tests + 1;
    end

    try
        % Test 3: Stage1イベント記録
        fprintf('Test 3: Stage1イベント記録テスト...\n');
        recorder = DataRecorder('human_computer', 'P001');
        recorder.record_stage1_event(1.234, 'beat_number', 1);
        recorder.record_stage1_event(2.345, 'beat_number', 2, 'is_tap', true);
        assert(length(recorder.data.stage1_data) == 2, 'Stage1 data count mismatch');
        assert(recorder.data.stage1_data(1).timestamp == 1.234, 'Timestamp mismatch');
        passed_tests = passed_tests + 1;
        fprintf('  ✅ PASSED\n\n');
        total_tests = total_tests + 1;

    catch ME
        fprintf('  ❌ FAILED: %s\n\n', ME.message);
        total_tests = total_tests + 1;
    end

    try
        % Test 4: Stage2タップ記録
        fprintf('Test 4: Stage2タップ記録テスト...\n');
        recorder = DataRecorder('human_human', {'P001', 'P002'});
        recorder.record_stage2_tap(1, 3.456, 'cycle', 1);
        recorder.record_stage2_tap(2, 4.567, 'cycle', 1);
        assert(length(recorder.data.stage2_data) == 2, 'Stage2 data count mismatch');
        assert(recorder.data.stage2_data(1).player_id == 1, 'Player ID mismatch');
        passed_tests = passed_tests + 1;
        fprintf('  ✅ PASSED\n\n');
        total_tests = total_tests + 1;

    catch ME
        fprintf('  ❌ FAILED: %s\n\n', ME.message);
        total_tests = total_tests + 1;
    end

    try
        % Test 5: メタデータ設定
        fprintf('Test 5: メタデータ設定テスト...\n');
        recorder = DataRecorder('human_computer', 'P001');
        recorder.set_metadata('model_type', 'SEA');
        recorder.set_metadata('version', '2.0');
        assert(strcmp(recorder.data.metadata.model_type, 'SEA'), 'Metadata mismatch');
        assert(strcmp(recorder.data.metadata.version, '2.0'), 'Metadata version mismatch');
        passed_tests = passed_tests + 1;
        fprintf('  ✅ PASSED\n\n');
        total_tests = total_tests + 1;

    catch ME
        fprintf('  ❌ FAILED: %s\n\n', ME.message);
        total_tests = total_tests + 1;
    end

    try
        % Test 6: ディレクトリ名生成（human_computer）
        fprintf('Test 6: ディレクトリ名生成テスト (human_computer)...\n');
        recorder = DataRecorder('human_computer', 'P001');
        recorder.set_metadata('model_type', 'SEA');
        save_dir = recorder.create_save_directory('tests/temp_data');
        assert(contains(save_dir, 'P001'), 'Directory name missing participant ID');
        assert(contains(save_dir, 'SEA'), 'Directory name missing model type');
        fprintf('  生成ディレクトリ: %s\n', save_dir);
        passed_tests = passed_tests + 1;
        fprintf('  ✅ PASSED\n\n');
        total_tests = total_tests + 1;

    catch ME
        fprintf('  ❌ FAILED: %s\n\n', ME.message);
        total_tests = total_tests + 1;
    end

    try
        % Test 7: ディレクトリ名生成（human_human）
        fprintf('Test 7: ディレクトリ名生成テスト (human_human)...\n');
        recorder = DataRecorder('human_human', {'P001', 'P002'});
        save_dir = recorder.create_save_directory('tests/temp_data');
        assert(contains(save_dir, 'P001'), 'Directory name missing participant 1 ID');
        assert(contains(save_dir, 'P002'), 'Directory name missing participant 2 ID');
        fprintf('  生成ディレクトリ: %s\n', save_dir);
        passed_tests = passed_tests + 1;
        fprintf('  ✅ PASSED\n\n');
        total_tests = total_tests + 1;

    catch ME
        fprintf('  ❌ FAILED: %s\n\n', ME.message);
        total_tests = total_tests + 1;
    end

    % クリーンアップ
    if exist('tests/temp_data', 'dir')
        rmdir('tests/temp_data', 's');
    end

    % 結果サマリー
    fprintf('========================================\n');
    fprintf('  Test Results: %d/%d PASSED\n', passed_tests, total_tests);
    fprintf('========================================\n\n');

    if passed_tests == total_tests
        fprintf('✅ All DataRecorder tests PASSED!\n\n');
    else
        fprintf('⚠️  Some tests FAILED (%d/%d)\n\n', total_tests - passed_tests, total_tests);
    end
end
