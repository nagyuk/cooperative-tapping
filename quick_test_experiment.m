function quick_test_experiment()
    % quick_test_experiment - 簡易テスト実験（自動実行）
    % キーボード入力なしで基本動作をテスト
    
    fprintf('=== 簡易テスト実験 ===\n');
    
    try
        % 基本設定
        addpath('matlab_verification/phase2_core_system');
        
        fprintf('1. システム初期化中...\n');
        
        % 基本設定の作成
        config = struct();
        config.model = 'sea';
        config.scale = 0.1;
        config.span = 2.0;
        config.output_directory = 'data/raw';
        config.stage1_count = 5;
        config.stage2_count = 10;
        config.model_type = 'sea';
        
        % SEAモデルの初期化
        model = SEAModelMATLAB(config);
        fprintf('   ✓ SEAモデル初期化完了\n');
        
        % データコレクター用設定の追加
        config.user_id = 'quicktest';
        config.experiment_id = sprintf('quicktest_%s', datestr(now, 'yyyymmdd_HHMMSS'));
        
        % データコレクター初期化
        data_collector = DataCollectorMATLAB(config);
        fprintf('   ✓ データコレクター初期化完了\n');
        
        % タイミングコントローラー初期化
        timing_controller = TimingControllerMATLAB();
        fprintf('   ✓ タイミングコントローラー初期化完了\n');
        
        fprintf('2. 模擬実験データ生成中...\n');
        
        % Stage 1 の模擬（固定メトロノーム）
        stage1_data = [];
        base_interval = 0.6;  % 600ms
        
        fprintf('   Stage 1: 固定メトロノーム（5回）\n');
        for i = 1:5
            % 人間のタップ時刻を模擬（少し誤差を含む）
            human_tap_time = i * base_interval + randn() * 0.02;  % ±20ms程度の誤差
            computer_tap_time = i * base_interval;
            
            stage1_data = [stage1_data; human_tap_time, computer_tap_time, base_interval];
            
            % データ記録
            data_collector.recordTap(human_tap_time, computer_tap_time, base_interval, i, 1);
            
            fprintf('     タップ %d: 人間=%.3fs, コンピュータ=%.3fs\n', ...
                i, human_tap_time, computer_tap_time);
        end
        
        % Stage 2 の模擬（適応的）
        stage2_data = [];
        
        fprintf('   Stage 2: 適応的協調（10回）\n');
        for i = 1:10
            % 同期誤差の計算（前回のタップから）
            if i > 1
                se = (stage2_data(end, 1) - stage2_data(end, 2));  % 人間 - コンピュータ
                model.update(se);
                fprintf('     同期誤差: %.3fs -> ', se);
            end
            
            % 次の間隔を予測
            predicted_interval = model.predict_next_interval();
            fprintf('予測間隔: %.3fs\n', predicted_interval);
            
            % 人間のタップを模擬
            if i == 1
                human_tap_time = base_interval;
            else
                human_tap_time = stage2_data(end, 1) + predicted_interval + randn() * 0.015;
            end
            
            % コンピュータのタップ時刻
            if i == 1
                computer_tap_time = 0;
            else
                computer_tap_time = stage2_data(end, 2) + predicted_interval;
            end
            
            stage2_data = [stage2_data; human_tap_time, computer_tap_time, predicted_interval];
            
            % データ記録
            data_collector.recordTap(human_tap_time, computer_tap_time, predicted_interval, i, 2);
        end
        
        fprintf('3. データ保存中...\n');
        
        % データ保存
        success = data_collector.saveData();
        if success
            fprintf('   ✓ データ保存完了: %s\n', data_collector.experiment_id);
        else
            fprintf('   ✗ データ保存エラー\n');
        end
        
        fprintf('4. 結果サマリー:\n');
        
        % Stage1の精度
        stage1_errors = stage1_data(:, 1) - stage1_data(:, 2);  % 同期誤差
        fprintf('   Stage1 同期誤差: 平均=%.3fs, 標準偏差=%.3fs\n', ...
            mean(stage1_errors), std(stage1_errors));
        
        % Stage2の適応
        stage2_errors = stage2_data(:, 1) - stage2_data(:, 2);
        stage2_intervals = stage2_data(:, 3);
        fprintf('   Stage2 同期誤差: 平均=%.3fs, 標準偏差=%.3fs\n', ...
            mean(stage2_errors), std(stage2_errors));
        fprintf('   Stage2 間隔変化: %.3fs -> %.3fs\n', ...
            stage2_intervals(1), stage2_intervals(end));
        
        % SEAモデルの状態
        fprintf('   SEAモデル最終状態: 累積修正=%.3fs\n', model.cumulative_modification);
        
        fprintf('\n=== 簡易テスト実験完了 ===\n');
        fprintf('✓ 基本的な実験システムが正常に動作しています。\n');
        fprintf('出力ディレクトリ: data/raw/%s/\n', datestr(now, 'yyyymmdd'));
        
    catch ME
        fprintf('\n✗ テスト実験中にエラーが発生しました:\n');
        fprintf('エラー: %s\n', ME.message);
        if ~isempty(ME.stack)
            fprintf('場所: %s (行 %d)\n', ME.stack(1).name, ME.stack(1).line);
        end
    end
end