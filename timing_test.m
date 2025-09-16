function timing_test()
    % 音声タイミングテストスクリプト
    
    fprintf('=== 音声タイミング検証テスト ===\n');
    
    % 現在の設定値を確認
    cd('experiments');
    addpath('configs');
    config = experiment_config();
    
    fprintf('現在の設定:\n');
    fprintf('  SPAN = %.1f秒\n', config.SPAN);
    fprintf('  Stage1間隔 = SPAN = %.1f秒\n', config.SPAN);
    fprintf('  Stage2間隔 = SPAN / 2 = %.1f秒\n', config.SPAN / 2);
    fprintf('\n');
    
    % 理論値との比較
    fprintf('期待される値 (CLAUDE.md基準):\n');
    fprintf('  Stage1間隔 = 2.0秒\n');
    fprintf('  Stage2間隔 = 1.0秒\n');
    fprintf('\n');
    
    % 差異の確認
    stage1_actual = config.SPAN;
    stage2_actual = config.SPAN / 2;

    if stage1_actual == 2.0
        fprintf('✅ Stage1間隔: 正常 (%.1f秒)\n', stage1_actual);
    else
        fprintf('❌ Stage1間隔: 異常 (%.1f秒 ≠ 2.0秒)\n', stage1_actual);
    end
    
    if stage2_actual == 1.0
        fprintf('✅ Stage2間隔: 正常 (%.1f秒)\n', stage2_actual);
    else
        fprintf('❌ Stage2間隔: 異常 (%.1f秒 ≠ 1.0秒)\n', stage2_actual);
    end
    
    % 実際の音声再生タイミングテスト
    fprintf('\n=== 実際の音声再生テスト ===\n');
    fprintf('Stage1タイミング (%.1f秒間隔) を3回テスト:\n', stage1_actual);
    
    [sound_data, fs] = audioread(config.SOUND_STIM);
    player = audioplayer(sound_data(:,1), fs);
    
    start_time = posixtime(datetime('now'));
    play_times = [];
    
    for i = 1:3
        play(player);
        current_time = posixtime(datetime('now'));
        elapsed = current_time - start_time;
        play_times(end+1) = elapsed;
        if i == 1
            interval_text = 0;
        else
            interval_text = elapsed - play_times(end-1);
        end
        fprintf('  %d回目: %.3f秒 (間隔: %.3f秒)\n', i, elapsed, interval_text);
        
        if i < 3
            pause(stage1_actual);  % 次の再生まで待機
        end
    end
    
    % 間隔精度の評価
    if length(play_times) > 1
        intervals = diff(play_times);
        mean_interval = mean(intervals);
        std_interval = std(intervals);
        
        fprintf('\n間隔統計:\n');
        fprintf('  平均間隔: %.3f秒 (目標: %.1f秒)\n', mean_interval, stage1_actual);
        fprintf('  標準偏差: %.3f秒\n', std_interval);
        fprintf('  誤差: %.3f秒 (%.1f%%)\n', ...
            abs(mean_interval - stage1_actual), ...
            abs(mean_interval - stage1_actual) / stage1_actual * 100);
    end
    
    delete(player);
    cd('..');
    
    fprintf('\n=== テスト完了 ===\n');
end