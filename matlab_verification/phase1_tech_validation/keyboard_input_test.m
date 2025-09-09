%% キーボード入力システム検証テスト
% MATLAB移行Phase 1.3: リアルタイムキーボード入力システムの実装と検証
%
% 目的:
% - KbCheckを使用したノンブロッキング入力システム
% - PsychoPy event.getKeys()相当の機能実現
% - タップタイミング検出の精度検証

function results = keyboard_input_test()
    fprintf('=== キーボード入力システム検証開始 ===\n');
    
    % Psychtoolboxの利用可能性チェック
    ptb_available = check_psychtoolbox();
    
    if ptb_available
        fprintf('Psychtoolbox検出 - KbCheck使用\n');
        test_functions = {
            struct('name', 'KbCheck基本機能テスト', 'func', @test_kbcheck_basic);
            struct('name', 'タッピング精度テスト', 'func', @test_tapping_precision);
            struct('name', 'リアルタイム応答性テスト', 'func', @test_realtime_response);
            struct('name', '長時間入力安定性テスト', 'func', @test_input_stability);
        };
    else
        fprintf('Psychtoolbox未検出 - 代替実装使用\n');
        test_functions = {
            struct('name', 'input()代替実装テスト', 'func', @test_input_alternative);
            struct('name', 'ginput()精度テスト', 'func', @test_ginput_precision);
            struct('name', 'waitforbuttonpress()テスト', 'func', @test_buttonpress);
        };
    end
    
    results = struct();
    results.ptb_available = ptb_available;
    
    % 各テスト実行
    for i = 1:length(test_functions)
        fprintf('\n--- %s ---\n', test_functions{i}.name);
        try
            results.(sprintf('test%d', i)) = test_functions{i}.func();
            results.(sprintf('test%d', i)).name = test_functions{i}.name;
            results.(sprintf('test%d', i)).status = 'SUCCESS';
        catch ME
            fprintf('エラー: %s\n', ME.message);
            results.(sprintf('test%d', i)) = struct('error', ME.message, 'status', 'ERROR');
            results.(sprintf('test%d', i)).name = test_functions{i}.name;
        end
    end
    
    % 結果評価と推奨事項生成
    recommendations = evaluate_input_systems(results);
    generate_input_report(results, recommendations);
    
    fprintf('\n=== キーボード入力システム検証完了 ===\n');
end

function available = check_psychtoolbox()
    % Psychtoolboxの利用可能性チェック
    try
        KbCheck;
        available = true;
    catch
        available = false;
    end
end

function result = test_kbcheck_basic()
    % KbCheckの基本機能テスト
    fprintf('  KbCheck基本機能をテスト中...\n');
    fprintf('  スペースキーを5回押してください（10秒以内）\n');
    
    target_presses = 5;
    timeout_sec = 10;
    
    press_times = [];
    press_count = 0;
    last_state = false;
    
    start_time = posixtime(datetime('now', 'TimeZone', 'local'));
    
    while press_count < target_presses
        current_time = posixtime(datetime('now', 'TimeZone', 'local'));
        elapsed = current_time - start_time;
        
        if elapsed > timeout_sec
            fprintf('  タイムアウト（%d/%d回検出）\n', press_count, target_presses);
            break;
        end
        
        [keyIsDown, ~, keyCode] = KbCheck;
        space_pressed = keyCode(KbName('space'));
        
        % エッジ検出（押下瞬間のみ）
        if space_pressed && ~last_state
            press_count = press_count + 1;
            press_times(end+1) = current_time;
            fprintf('    検出 %d/%d (%.3f秒)\n', press_count, target_presses, elapsed);
        end
        
        last_state = space_pressed;
        pause(0.001); % 1ms間隔でポーリング
    end
    
    % 精度分析
    if length(press_times) > 1
        intervals = diff(press_times) * 1000; % ms
        mean_interval = mean(intervals);
        std_interval = std(intervals);
        
        fprintf('  平均押下間隔: %.1f ms\n', mean_interval);
        fprintf('  標準偏差: %.1f ms\n', std_interval);
    end
    
    result = struct();
    result.target_presses = target_presses;
    result.detected_presses = press_count;
    result.press_times = press_times;
    result.timeout_sec = timeout_sec;
    result.completion_rate = press_count / target_presses;
    
    if length(press_times) > 1
        result.intervals_ms = intervals;
        result.mean_interval = mean_interval;
        result.std_interval = std_interval;
    end
end

function result = test_tapping_precision()
    % タッピングタイミング精度テスト
    fprintf('  タッピング精度テスト中...\n');
    fprintf('  メトロノームに合わせてスペースキーを10回押してください\n');
    
    % 簡易メトロノーム（600ms間隔）
    metronome_interval = 0.6; % 600ms
    num_beats = 10;
    
    % メトロノーム音生成
    fs = 8000;
    duration = 0.1;
    t = 0:1/fs:duration;
    beep_sound = sin(2*pi*1000*t);
    
    fprintf('  メトロノーム開始...\n');
    
    beat_times = [];
    tap_times = [];
    last_key_state = false;
    
    start_time = posixtime(datetime('now', 'TimeZone', 'local'));
    
    for beat = 1:num_beats
        % ビート音再生
        beat_time = posixtime(datetime('now', 'TimeZone', 'local'));
        beat_times(end+1) = beat_time;
        
        sound(beep_sound, fs);
        fprintf('    ビート %d/%d\n', beat, num_beats);
        
        % 次のビートまでの間にタッピング検出
        next_beat_time = start_time + beat * metronome_interval;
        
        while posixtime(datetime('now', 'TimeZone', 'local')) < next_beat_time
            [keyIsDown, ~, keyCode] = KbCheck;
            space_pressed = keyCode(KbName('space'));
            
            if space_pressed && ~last_key_state
                tap_time = posixtime(datetime('now', 'TimeZone', 'local'));
                tap_times(end+1) = tap_time;
            end
            
            last_key_state = space_pressed;
            pause(0.001);
        end
    end
    
    % 同期エラー解析
    sync_errors = [];
    if length(tap_times) > 0 && length(beat_times) > 0
        for i = 1:min(length(tap_times), length(beat_times))
            sync_error = (tap_times(i) - beat_times(i)) * 1000; % ms
            sync_errors(end+1) = sync_error;
        end
        
        mean_sync_error = mean(sync_errors);
        std_sync_error = std(sync_errors);
        
        fprintf('  検出タップ数: %d/%d\n', length(tap_times), num_beats);
        fprintf('  平均同期エラー: %+.1f ms\n', mean_sync_error);
        fprintf('  同期エラー標準偏差: %.1f ms\n', std_sync_error);
    end
    
    result = struct();
    result.num_beats = num_beats;
    result.beat_times = beat_times;
    result.tap_times = tap_times;
    result.num_taps = length(tap_times);
    result.tap_detection_rate = length(tap_times) / num_beats;
    
    if length(sync_errors) > 0
        result.sync_errors_ms = sync_errors;
        result.mean_sync_error = mean_sync_error;
        result.std_sync_error = std_sync_error;
    end
end

function result = test_realtime_response()
    % リアルタイム応答性テスト
    fprintf('  リアルタイム応答性テスト中...\n');
    fprintf('  ランダムな間隔で画面指示に従ってスペースキーを押してください\n');
    
    num_prompts = 5;
    response_times = [];
    success_count = 0;
    
    for i = 1:num_prompts
        % ランダム待機（1-3秒）
        wait_time = 1 + rand() * 2;
        pause(wait_time);
        
        fprintf('\n  >>> 今すぐスペースキーを押してください! <<<\n');
        prompt_time = posixtime(datetime('now', 'TimeZone', 'local'));
        
        % 応答待ち（最大2秒）
        timeout = 2.0;
        responded = false;
        last_key_state = false;
        
        while (posixtime(datetime('now', 'TimeZone', 'local')) - prompt_time) < timeout
            [keyIsDown, ~, keyCode] = KbCheck;
            space_pressed = keyCode(KbName('space'));
            
            if space_pressed && ~last_key_state
                response_time = posixtime(datetime('now', 'TimeZone', 'local'));
                reaction_time = (response_time - prompt_time) * 1000; % ms
                
                response_times(end+1) = reaction_time;
                success_count = success_count + 1;
                responded = true;
                
                fprintf('  応答時間: %.0f ms\n', reaction_time);
                break;
            end
            
            last_key_state = space_pressed;
            pause(0.001);
        end
        
        if ~responded
            fprintf('  タイムアウト\n');
        end
        
        pause(0.5); % 次のプロンプトまで待機
    end
    
    % 応答性解析
    if length(response_times) > 0
        mean_response = mean(response_times);
        std_response = std(response_times);
        min_response = min(response_times);
        max_response = max(response_times);
        
        fprintf('\n  成功率: %d/%d (%.1f%%)\n', success_count, num_prompts, (success_count/num_prompts)*100);
        fprintf('  平均応答時間: %.0f ms\n', mean_response);
        fprintf('  応答時間範囲: %.0f - %.0f ms\n', min_response, max_response);
    end
    
    result = struct();
    result.num_prompts = num_prompts;
    result.success_count = success_count;
    result.success_rate = success_count / num_prompts;
    result.response_times_ms = response_times;
    
    if length(response_times) > 0
        result.mean_response_time = mean_response;
        result.std_response_time = std_response;
        result.min_response_time = min_response;
        result.max_response_time = max_response;
    end
end

function result = test_input_stability()
    % 長時間入力安定性テスト
    fprintf('  長時間入力安定性テスト中（30秒）...\n');
    fprintf('  30秒間、好きなタイミングでスペースキーを押してください\n');
    
    test_duration = 30; % 秒
    poll_interval = 0.001; % 1ms
    
    press_times = [];
    poll_count = 0;
    missed_polls = 0;
    last_key_state = false;
    
    start_time = posixtime(datetime('now', 'TimeZone', 'local'));
    last_poll_time = start_time;
    
    while true
        current_time = posixtime(datetime('now', 'TimeZone', 'local'));
        elapsed = current_time - start_time;
        
        if elapsed >= test_duration
            break;
        end
        
        % ポーリング間隔チェック
        poll_interval_actual = current_time - last_poll_time;
        if poll_interval_actual > poll_interval * 2
            missed_polls = missed_polls + 1;
        end
        
        poll_count = poll_count + 1;
        last_poll_time = current_time;
        
        % キー検出
        [keyIsDown, ~, keyCode] = KbCheck;
        space_pressed = keyCode(KbName('space'));
        
        if space_pressed && ~last_key_state
            press_times(end+1) = current_time;
        end
        
        last_key_state = space_pressed;
        
        % 進捗表示
        if mod(poll_count, 1000) == 0
            fprintf('    経過: %.1f秒, 検出タップ: %d\n', elapsed, length(press_times));
        end
        
        pause(poll_interval);
    end
    
    % 安定性解析
    poll_rate = poll_count / test_duration;
    miss_rate = missed_polls / poll_count;
    tap_rate = length(press_times) / test_duration;
    
    fprintf('  ポーリング回数: %d (%.1f Hz)\n', poll_count, poll_rate);
    fprintf('  ポーリング失敗率: %.2f%%\n', miss_rate * 100);
    fprintf('  検出タップ数: %d (%.1f タップ/秒)\n', length(press_times), tap_rate);
    
    result = struct();
    result.test_duration_s = test_duration;
    result.poll_count = poll_count;
    result.poll_rate_hz = poll_rate;
    result.missed_polls = missed_polls;
    result.miss_rate = miss_rate;
    result.press_times = press_times;
    result.tap_count = length(press_times);
    result.tap_rate = tap_rate;
end

% Psychtoolbox未使用時の代替実装
function result = test_input_alternative()
    fprintf('  input()代替実装テスト中...\n');
    fprintf('  この実装は制限があります - ブロッキング入力のみ\n');
    
    result = struct();
    result.method = 'input()';
    result.blocking = true;
    result.realtime_capable = false;
    result.recommendation = 'Psychtoolbox推奨';
end

function result = test_ginput_precision()
    fprintf('  ginput()精度テスト中...\n');
    fprintf('  この実装は制限があります - グラフィカル入力のみ\n');
    
    result = struct();
    result.method = 'ginput()';
    result.precision_limited = true;
    result.realtime_capable = false;
    result.recommendation = 'Psychtoolbox推奨';
end

function result = test_buttonpress()
    fprintf('  waitforbuttonpress()テスト中...\n');
    fprintf('  この実装は制限があります - タイミング精度低下\n');
    
    result = struct();
    result.method = 'waitforbuttonpress()';
    result.timing_precision = 'LOW';
    result.realtime_capable = false;
    result.recommendation = 'Psychtoolbox推奨';
end

function recommendations = evaluate_input_systems(results)
    % 入力システム評価と推奨事項
    fprintf('\n=== 入力システム評価 ===\n');
    
    recommendations = struct();
    
    if results.ptb_available
        fprintf('Psychtoolbox利用可能 - 高精度リアルタイム入力対応\n');
        
        % KbCheck性能評価
        if isfield(results, 'test1') && results.test1.status == "SUCCESS"
            completion_rate = results.test1.completion_rate;
            if completion_rate >= 0.8
                fprintf('キー検出性能: 良好 (%.1f%%)\n', completion_rate * 100);
                recommendations.input_method = 'KbCheck';
                recommendations.performance = 'EXCELLENT';
            else
                fprintf('キー検出性能: 要改善 (%.1f%%)\n', completion_rate * 100);
                recommendations.input_method = 'KbCheck';
                recommendations.performance = 'NEEDS_IMPROVEMENT';
            end
        end
        
        % タッピング精度評価
        if isfield(results, 'test2') && results.test2.status == "SUCCESS"
            if isfield(results.test2, 'std_sync_error')
                sync_precision = results.test2.std_sync_error;
                if sync_precision < 50
                    fprintf('同期精度: 優秀 (σ=%.1f ms)\n', sync_precision);
                    recommendations.timing_precision = 'EXCELLENT';
                elseif sync_precision < 100
                    fprintf('同期精度: 良好 (σ=%.1f ms)\n', sync_precision);
                    recommendations.timing_precision = 'GOOD';
                else
                    fprintf('同期精度: 要改善 (σ=%.1f ms)\n', sync_precision);
                    recommendations.timing_precision = 'NEEDS_IMPROVEMENT';
                end
            end
        end
        
        recommendations.realtime_capable = true;
        recommendations.recommended_setup = 'Psychtoolbox + KbCheck';
        
    else
        fprintf('Psychtoolbox未利用可能 - 代替実装の制約あり\n');
        recommendations.input_method = 'LIMITED_ALTERNATIVES';
        recommendations.performance = 'CONSTRAINED';
        recommendations.realtime_capable = false;
        recommendations.recommended_setup = 'Psychtoolbox導入を強く推奨';
        recommendations.limitations = {'ブロッキング入力のみ', 'タイミング精度低下', 'リアルタイム性なし'};
    end
    
    recommendations.ptb_available = results.ptb_available;
end

function generate_input_report(results, recommendations)
    % 入力システム検証レポート生成
    timestamp = datestr(now, 'yyyymmdd_HHMMSS');
    report_file = fullfile('matlab_verification', 'phase1_tech_validation', ...
                          sprintf('keyboard_input_report_%s.txt', timestamp));
    
    fid = fopen(report_file, 'w');
    
    fprintf(fid, 'MATLAB キーボード入力システム検証レポート\n');
    fprintf(fid, '生成日時: %s\n', datestr(now));
    fprintf(fid, '=========================================\n\n');
    
    fprintf(fid, '【環境情報】\n');
    fprintf(fid, 'Psychtoolbox利用可能: %s\n', logical2str(results.ptb_available));
    fprintf(fid, '\n');
    
    fprintf(fid, '【推奨事項】\n');
    fprintf(fid, '推奨入力方式: %s\n', recommendations.recommended_setup);
    fprintf(fid, '性能評価: %s\n', recommendations.performance);
    fprintf(fid, 'リアルタイム対応: %s\n', logical2str(recommendations.realtime_capable));
    
    if isfield(recommendations, 'limitations')
        fprintf(fid, '制約事項:\n');
        for i = 1:length(recommendations.limitations)
            fprintf(fid, '  - %s\n', recommendations.limitations{i});
        end
    end
    
    fprintf(fid, '\n【実験適合性】\n');
    if recommendations.realtime_capable
        fprintf(fid, '協調タッピング実験: 適合\n');
        fprintf(fid, '推奨度: 高\n');
    else
        fprintf(fid, '協調タッピング実験: 制約あり\n');
        fprintf(fid, '推奨度: Psychtoolbox導入後に再評価\n');
    end
    
    fclose(fid);
    
    fprintf('\n入力システムレポートを保存しました: %s\n', report_file);
end

function str = logical2str(logical_val)
    if logical_val
        str = 'はい';
    else
        str = 'いいえ';
    end
end