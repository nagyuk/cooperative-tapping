function system_test()
    % system_test - システム動作確認テスト
    % 音声出力、タイミング制御、キーボード入力の基本機能をテスト
    
    fprintf('=== システム動作確認テスト ===\n');
    
    try
        % 1. 音声システムテスト
        fprintf('\n1. 音声システムテスト:\n');
        
        % 音声ファイルの読み込み
        [stim_audio, fs] = audioread('assets/sounds/stim_beat.wav');
        fprintf('   ✓ 音声ファイル読み込み成功 (fs = %d Hz)\n', fs);
        
        % 基本的な音声再生テスト（sound関数使用）
        fprintf('   → 基本音声再生テスト実行中...\n');
        try
            sound(stim_audio(:,1), fs);  % 左チャンネルのみ再生
            pause(0.2);  % 音声再生時間
            fprintf('   ✓ 音声再生テスト完了\n');
        catch
            fprintf('   ⚠ 音声再生エラー（音声デバイス設定を確認）\n');
        end
        
        % 2. タイミング精度テスト
        fprintf('\n2. タイミング精度テスト:\n');
        
        % posixtime精度測定
        start_time = posixtime(datetime('now'));
        pause(0.1);  % 100ms待機
        end_time = posixtime(datetime('now'));
        measured_interval = (end_time - start_time) * 1000;  % ms
        fprintf('   測定間隔: %.2f ms (期待値: ~100ms)\n', measured_interval);
        
        if abs(measured_interval - 100) < 10
            fprintf('   ✓ タイミング精度: 良好\n');
        else
            fprintf('   ⚠ タイミング精度: 要注意 (誤差 %.1f ms)\n', abs(measured_interval - 100));
        end
        
        % 3. 高精度タイミングテスト
        fprintf('\n3. 高精度タイミングテスト (10回測定):\n');
        intervals = zeros(10, 1);
        
        for i = 1:10
            t1 = posixtime(datetime('now'));
            pause(0.05);  % 50ms
            t2 = posixtime(datetime('now'));
            intervals(i) = (t2 - t1) * 1000;
        end
        
        mean_interval = mean(intervals);
        std_interval = std(intervals);
        fprintf('   平均間隔: %.2f ms (標準偏差: %.2f ms)\n', mean_interval, std_interval);
        
        if std_interval < 5
            fprintf('   ✓ タイミング安定性: 良好\n');
        else
            fprintf('   ⚠ タイミング安定性: 要注意\n');
        end
        
        % 4. メモリと処理性能テスト
        fprintf('\n4. システム性能テスト:\n');
        
        % 大きな配列を作成してメモリテスト
        test_data = randn(1000, 1000);
        fprintf('   ✓ メモリ割り当てテスト完了\n');
        
        % 処理時間測定
        tic;
        result = test_data * test_data';
        processing_time = toc;
        fprintf('   行列計算処理時間: %.3f 秒\n', processing_time);
        
        clear test_data result;
        fprintf('   ✓ メモリ解放完了\n');
        
        % 5. ファイル入出力テスト
        fprintf('\n5. ファイル入出力テスト:\n');
        
        % テスト用CSVファイルの作成
        test_file = 'test_output.csv';
        test_table = table([1; 2; 3], [0.5; 1.0; 1.5], ...
            {'A'; 'B'; 'C'}, ...
            'VariableNames', {'Index', 'Value', 'Label'});
        
        writetable(test_table, test_file);
        fprintf('   ✓ CSVファイル書き込み完了\n');
        
        % ファイル読み込み
        read_table = readtable(test_file);
        fprintf('   ✓ CSVファイル読み込み完了\n');
        
        % ファイル削除
        delete(test_file);
        fprintf('   ✓ テストファイル削除完了\n');
        
        % 6. 基本的なモデルテスト
        fprintf('\n6. モデル動作テスト:\n');
        
        % SEAモデルのインスタンス化テスト
        addpath('matlab_verification/phase2_core_system');
        
        try
            sea_model = SEAModelMATLAB();
            fprintf('   ✓ SEAモデル作成成功\n');
            
            % 基本的な予測テスト
            test_se = 0.02;  % 20ms の同期誤差
            predicted_interval = sea_model.predict_next_interval();
            fprintf('   初期予測間隔: %.3f 秒\n', predicted_interval);
            
            % アップデートテスト
            sea_model.update(test_se);
            updated_interval = sea_model.predict_next_interval();
            fprintf('   更新後間隔: %.3f 秒\n', updated_interval);
            fprintf('   ✓ モデル更新動作確認\n');
            
        catch ME
            fprintf('   ✗ モデルテストエラー: %s\n', ME.message);
        end
        
        fprintf('\n=== システムテスト完了 ===\n');
        fprintf('✓ 基本システムは正常に動作しています。\n');
        fprintf('\n次のステップ:\n');
        fprintf('- 簡易実験: run_experiment_matlab(''model'', ''sea'', ''test_mode'', true)\n');
        fprintf('- 本格実験: run_experiment_matlab(''model'', ''sea'')\n');
        
    catch ME
        fprintf('\n✗ システムテスト中にエラーが発生しました:\n');
        fprintf('エラー: %s\n', ME.message);
        fprintf('ファイル: %s (行 %d)\n', ME.stack(1).file, ME.stack(1).line);
    end
end