% CoreAudio初期化遅延の完全解決策

function coreaudio_warmup_solution()
    fprintf('=== CoreAudio完全初期化ソリューション ===\n');

    % 解決策1: ダミー音声による完全ウォームアップ
    fprintf('解決策1: 完全ウォームアップ実行中...\n');
    complete_audio_warmup();

    % 解決策2: 初期化遅延テスト
    fprintf('\n解決策2: ウォームアップ効果検証中...\n');
    test_warmup_effectiveness();
end

function complete_audio_warmup()
    % CoreAudio完全初期化のためのウォームアップ

    % テスト用短音（実験と同じ形式）
    fs = 22050; % 実験と同じサンプリングレート
    duration = 0.01; % 10ms短音
    t = 0:1/fs:duration;

    % 刺激音相当のウォームアップ音
    warmup_stim = sin(2*pi*440*t) * 0.01; % 極小音量

    % プレイヤー音相当のウォームアップ音
    warmup_player = sin(2*pi*660*t) * 0.01; % 極小音量

    fprintf('  刺激音系統のウォームアップ...\n');

    % 刺激音のウォームアップ（初回実行）
    sound(warmup_stim, fs);
    pause(0.01);

    fprintf('  プレイヤー音系統のウォームアップ...\n');

    % プレイヤー音のウォームアップ（2回目実行で遅延発生させる）
    sound(warmup_player, fs);
    pause(0.6); % 遅延を完全に待機

    % 完全安定化確認
    fprintf('  完全安定化確認中...\n');
    sound(warmup_stim, fs);
    pause(0.01);
    sound(warmup_player, fs);
    pause(0.01);

    fprintf('  CoreAudio完全初期化完了\n');
end

function test_warmup_effectiveness()
    % ウォームアップ効果の検証

    % テスト用音声
    fs = 22050;
    duration = 0.05;
    t = 0:1/fs:duration;
    test_sound1 = sin(2*pi*440*t) * 0.1;
    test_sound2 = sin(2*pi*660*t) * 0.1;

    delays = [];

    fprintf('  連続再生遅延テスト:\n');
    for i = 1:10
        pre_time = posixtime(datetime('now'));

        if mod(i, 2) == 1
            sound(test_sound1, fs); % 刺激音相当
        else
            sound(test_sound2, fs); % プレイヤー音相当
        end

        post_time = posixtime(datetime('now'));
        delay = (post_time - pre_time) * 1000;
        delays(end+1) = delay;

        fprintf('    再生%d: %.3fms\n', i, delay);
        pause(0.1);
    end

    % 統計
    fprintf('  ウォームアップ後統計:\n');
    fprintf('    平均遅延: %.3fms\n', mean(delays));
    fprintf('    標準偏差: %.3fms\n', std(delays));
    fprintf('    最大遅延: %.3fms\n', max(delays));

    % 成功判定
    if max(delays) < 50 % 50ms未満なら成功
        fprintf('  ✅ ウォームアップ成功！遅延は制御下にあります\n');
    else
        fprintf('  ❌ ウォームアップ不十分、追加対策が必要\n');
    end
end