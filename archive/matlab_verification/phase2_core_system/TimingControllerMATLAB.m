%% 高精度タイミング制御システム
% posixtime()を使用したマイクロ秒精度タイミング制御
% PsychoPy core.Clock()相当の機能を提供

classdef TimingControllerMATLAB < handle
    properties (Access = private)
        config              % 実験設定
        reference_time      % 基準時刻
        drift_correction    % ドリフト補正値
        timing_history      % タイミング履歴
        precision_mode      % 精度モード
        
        % パフォーマンス監視
        timing_errors       % タイミング誤差履歴
        performance_stats   % パフォーマンス統計
    end
    
    methods (Access = public)
        function obj = TimingControllerMATLAB(config)
            % タイミング制御システム初期化
            obj.config = config;
            obj.reference_time = posixtime(datetime('now', 'TimeZone', 'local'));
            obj.drift_correction = 0;
            obj.timing_history = [];
            obj.timing_errors = [];
            
            % 精度モード設定
            if isfield(config, 'high_precision_timing')
                obj.precision_mode = config.high_precision_timing;
            else
                obj.precision_mode = true; % デフォルト高精度
            end
            
            % パフォーマンス統計初期化
            obj.performance_stats = struct();
            obj.performance_stats.total_waits = 0;
            obj.performance_stats.mean_error = 0;
            obj.performance_stats.max_error = 0;
            obj.performance_stats.timing_stability = 0;
            
            fprintf('TimingController初期化完了 (高精度モード: %s)\n', ...
                logical2str(obj.precision_mode));
        end
        
        function current_time = getCurrentTime(obj)
            % 現在時刻取得 (秒)
            current_time = posixtime(datetime('now', 'TimeZone', 'local'));
            
            % ドリフト補正適用
            if obj.precision_mode
                current_time = current_time + obj.drift_correction;
            end
        end
        
        function elapsed = getElapsedTime(obj)
            % 基準時刻からの経過時間取得
            current_time = obj.getCurrentTime();
            elapsed = current_time - obj.reference_time;
        end
        
        function resetClock(obj)
            % 基準時刻リセット
            obj.reference_time = obj.getCurrentTime();
            obj.timing_history = [];
            fprintf('タイミングクロックリセット\n');
        end
        
        function actual_wait_time = waitUntil(obj, target_time)
            % 指定時刻まで高精度待機
            % target_time: 目標時刻 (絶対時刻)
            % 戻り値: 実際の待機時間
            
            start_wait = obj.getCurrentTime();
            target_wait_duration = target_time - start_wait;
            
            if target_wait_duration <= 0
                % 既に目標時刻を過ぎている
                actual_wait_time = 0;
                obj.recordTimingError(target_wait_duration);
                return;
            end
            
            % 高精度待機実行
            if obj.precision_mode
                actual_wait_time = obj.precisionWait(target_wait_duration);
            else
                pause(target_wait_duration);
                actual_wait_time = target_wait_duration;
            end
            
            % タイミング誤差記録
            actual_time = obj.getCurrentTime();
            timing_error = actual_time - target_time;
            obj.recordTimingError(timing_error);
            
            % 履歴記録
            obj.timing_history(end+1) = actual_time;
            obj.performance_stats.total_waits = obj.performance_stats.total_waits + 1;
        end
        
        function actual_wait_time = waitFor(obj, duration)
            % 指定時間だけ高精度待機
            % duration: 待機時間 (秒)
            % 戻り値: 実際の待機時間
            
            target_time = obj.getCurrentTime() + duration;
            actual_wait_time = obj.waitUntil(target_time);
        end
        
        function is_ready = checkTimeout(obj, start_time, timeout_duration)
            % タイムアウトチェック
            % start_time: 開始時刻
            % timeout_duration: タイムアウト時間 (秒)
            % 戻り値: タイムアウトしたかどうか
            
            current_time = obj.getCurrentTime();
            elapsed = current_time - start_time;
            is_ready = elapsed >= timeout_duration;
        end
        
        function [precision, stability] = measureTimingPrecision(obj, num_tests)
            % タイミング精度測定
            % num_tests: テスト回数
            % 戻り値: [精度(ms), 安定性(標準偏差)]
            
            if nargin < 2
                num_tests = 100;
            end
            
            fprintf('タイミング精度測定中 (%d回)...\n', num_tests);
            
            target_interval = 0.010; % 10ms間隔
            measured_intervals = zeros(num_tests, 1);
            
            for i = 1:num_tests
                start_time = obj.getCurrentTime();
                obj.waitFor(target_interval);
                end_time = obj.getCurrentTime();
                
                measured_intervals(i) = (end_time - start_time) * 1000; % ms変換
                
                if mod(i, 20) == 0
                    fprintf('  進捗: %d/%d\n', i, num_tests);
                end
            end
            
            % 精度分析
            mean_interval = mean(measured_intervals);
            std_interval = std(measured_intervals);
            target_interval_ms = target_interval * 1000;
            
            precision = abs(mean_interval - target_interval_ms);
            stability = std_interval;
            
            fprintf('精度測定結果:\n');
            fprintf('  目標間隔: %.3f ms\n', target_interval_ms);
            fprintf('  測定平均: %.3f ms\n', mean_interval);
            fprintf('  精度誤差: %.3f ms\n', precision);
            fprintf('  安定性(σ): %.3f ms\n', stability);
            
            % 統計更新
            obj.performance_stats.timing_stability = stability;
        end
        
        function calibrateDrift(obj, calibration_duration)
            % ドリフト補正キャリブレーション
            % calibration_duration: キャリブレーション時間 (秒)
            
            if nargin < 2
                calibration_duration = 60; % デフォルト1分
            end
            
            fprintf('ドリフト補正キャリブレーション中 (%d秒)...\n', calibration_duration);
            
            start_time = obj.getCurrentTime();
            target_end_time = start_time + calibration_duration;
            
            % 定期的な時刻測定
            measurement_interval = 1.0; % 1秒間隔
            num_measurements = floor(calibration_duration / measurement_interval);
            drift_measurements = zeros(num_measurements, 1);
            
            for i = 1:num_measurements
                measurement_time = start_time + i * measurement_interval;
                obj.waitUntil(measurement_time);
                
                actual_time = posixtime(datetime('now', 'TimeZone', 'local'));
                expected_time = measurement_time;
                drift_measurements(i) = actual_time - expected_time;
                
                if mod(i, 10) == 0
                    fprintf('  キャリブレーション進捗: %d/%d\n', i, num_measurements);
                end
            end
            
            % ドリフト計算
            if length(drift_measurements) > 1
                drift_trend = polyfit((1:length(drift_measurements))', drift_measurements, 1);
                obj.drift_correction = -drift_trend(1) * calibration_duration;
                
                fprintf('ドリフト補正値: %.6f秒/分\n', obj.drift_correction * 60);
            end
        end
        
        function stats = getPerformanceStats(obj)
            % パフォーマンス統計取得
            if length(obj.timing_errors) > 0
                obj.performance_stats.mean_error = mean(abs(obj.timing_errors)) * 1000; % ms
                obj.performance_stats.max_error = max(abs(obj.timing_errors)) * 1000; % ms
                obj.performance_stats.error_std = std(obj.timing_errors) * 1000; % ms
            end
            
            stats = obj.performance_stats;
            stats.total_timing_records = length(obj.timing_errors);
            stats.drift_correction = obj.drift_correction;
        end
        
        function printStats(obj)
            % 統計情報表示
            stats = obj.getPerformanceStats();
            
            fprintf('\n=== タイミング制御統計 ===\n');
            fprintf('総待機回数: %d\n', stats.total_waits);
            fprintf('平均誤差: %.3f ms\n', stats.mean_error);
            fprintf('最大誤差: %.3f ms\n', stats.max_error);
            fprintf('誤差標準偏差: %.3f ms\n', stats.error_std);
            fprintf('タイミング安定性: %.3f ms\n', stats.timing_stability);
            fprintf('ドリフト補正: %.6f s\n', stats.drift_correction);
            fprintf('========================\n');
        end
    end
    
    methods (Access = private)
        function actual_wait = precisionWait(obj, target_duration)
            % 高精度待機実装
            
            if target_duration <= 0
                actual_wait = 0;
                return;
            end
            
            start_time = obj.getCurrentTime();
            target_end_time = start_time + target_duration;
            
            % ハイブリッド待機戦略
            if target_duration > 0.001 % 1ms以上の場合
                % 粗い待機 (90%まで)
                coarse_duration = target_duration * 0.9;
                if coarse_duration > 0.001
                    pause(coarse_duration);
                end
                
                % 精密待機 (残り10%)
                while obj.getCurrentTime() < target_end_time
                    % ビジーウェイト (CPU使用率とのトレードオフ)
                    pause(0.0001); % 100μs間隔
                end
            else
                % 短時間の場合はビジーウェイトのみ
                while obj.getCurrentTime() < target_end_time
                    % ビジーウェイト
                end
            end
            
            actual_end_time = obj.getCurrentTime();
            actual_wait = actual_end_time - start_time;
        end
        
        function recordTimingError(obj, error)
            % タイミング誤差記録
            obj.timing_errors(end+1) = error;
            
            % 履歴サイズ制限
            if length(obj.timing_errors) > 1000
                obj.timing_errors = obj.timing_errors(end-500:end);
            end
        end
    end
    
    methods (Access = public, Static)
        function demo()
            % TimingControllerデモンストレーション
            fprintf('=== TimingController デモンストレーション ===\n');
            
            % テスト設定
            config = struct();
            config.high_precision_timing = true;
            
            % タイミング制御システム作成
            timing_ctrl = TimingControllerMATLAB(config);
            
            % 基本機能テスト
            fprintf('\n1. 基本タイミング機能テスト\n');
            start_time = timing_ctrl.getCurrentTime();
            timing_ctrl.waitFor(0.5); % 500ms待機
            elapsed = timing_ctrl.getCurrentTime() - start_time;
            fprintf('目標: 0.500s, 実際: %.3fs, 誤差: %+.3fms\n', ...
                elapsed, (elapsed - 0.5) * 1000);
            
            % 精度測定
            fprintf('\n2. タイミング精度測定\n');
            [precision, stability] = timing_ctrl.measureTimingPrecision(50);
            
            % 連続タイミングテスト
            fprintf('\n3. 連続タイミングテスト\n');
            intervals = [0.1, 0.2, 0.05, 0.3, 0.15]; % 様々な間隔
            
            for i = 1:length(intervals)
                target_interval = intervals(i);
                start_time = timing_ctrl.getCurrentTime();
                timing_ctrl.waitFor(target_interval);
                actual_interval = timing_ctrl.getCurrentTime() - start_time;
                error_ms = (actual_interval - target_interval) * 1000;
                
                fprintf('  間隔 %d: 目標=%.3fs, 実際=%.3fs, 誤差=%+.3fms\n', ...
                    i, target_interval, actual_interval, error_ms);
            end
            
            % 統計表示
            fprintf('\n4. 統計情報\n');
            timing_ctrl.printStats();
            
            fprintf('=== TimingController デモ完了 ===\n');
        end
        
        function performanceBenchmark()
            % パフォーマンスベンチマーク
            fprintf('=== TimingController パフォーマンスベンチマーク ===\n');
            
            config = struct();
            config.high_precision_timing = true;
            timing_ctrl = TimingControllerMATLAB(config);
            
            % 様々な間隔でのテスト
            test_intervals = [0.001, 0.005, 0.01, 0.05, 0.1]; % 1ms～100ms
            num_tests_per_interval = 20;
            
            fprintf('\n間隔別精度測定:\n');
            fprintf('%-10s %-12s %-12s %-12s\n', '目標(ms)', '平均(ms)', '誤差(ms)', 'σ(ms)');
            fprintf('%s\n', repmat('-', 1, 50));
            
            for target_ms = test_intervals * 1000
                target_interval = target_ms / 1000;
                measured_intervals = zeros(num_tests_per_interval, 1);
                
                for i = 1:num_tests_per_interval
                    start_time = timing_ctrl.getCurrentTime();
                    timing_ctrl.waitFor(target_interval);
                    end_time = timing_ctrl.getCurrentTime();
                    measured_intervals(i) = (end_time - start_time) * 1000;
                end
                
                mean_measured = mean(measured_intervals);
                error_ms = mean_measured - target_ms;
                std_measured = std(measured_intervals);
                
                fprintf('%-10.1f %-12.3f %-12.3f %-12.3f\n', ...
                    target_ms, mean_measured, error_ms, std_measured);
            end
            
            fprintf('\n=== ベンチマーク完了 ===\n');
        end
    end
end

function str = logical2str(logical_val)
    if logical_val
        str = '有効';
    else
        str = '無効';
    end
end