% sound()関数の初期化遅延詳細調査

function debug_sound_initialization()
    fprintf('=== sound()関数の初期化遅延調査 ===\n');

    % テスト用音声データ
    fs = 44100;
    duration = 0.05; % 50ms短音
    t = 0:1/fs:duration;
    test_sound = sin(2*pi*440*t) * 0.1; % 小音量

    % Test 1: 連続再生での遅延パターン
    fprintf('\n--- Test 1: 連続再生遅延パターン ---\n');
    delays = [];

    for i = 1:20
        pre_time = posixtime(datetime('now'));
        sound(test_sound, fs);
        post_time = posixtime(datetime('now'));

        delay = (post_time - pre_time) * 1000;
        delays(end+1) = delay;

        fprintf('再生%d: %.3fms\n', i, delay);
        pause(0.1); % 100ms間隔
    end

    % Test 2: 長時間間隔後の再生遅延
    fprintf('\n--- Test 2: 長時間間隔後の遅延 ---\n');

    % 5秒待機
    fprintf('5秒間待機中...\n');
    pause(5.0);

    pre_time = posixtime(datetime('now'));
    sound(test_sound, fs);
    post_time = posixtime(datetime('now'));
    delay_after_pause = (post_time - pre_time) * 1000;

    fprintf('5秒待機後の再生: %.3fms\n', delay_after_pause);

    % Test 3: 音声システムの状態調査
    fprintf('\n--- Test 3: 音声システム状態 ---\n');

    try
        % オーディオデバイス情報
        [output_devices, output_names] = audiodevinfo(1, []);
        fprintf('出力デバイス数: %d\n', length(output_devices));

        % デフォルトデバイス
        default_output = audiodevinfo(1);
        fprintf('デフォルト出力デバイス: %d\n', default_output);

    catch ME
        fprintf('オーディオデバイス情報取得エラー: %s\n', ME.message);
    end

    % Test 4: MATLABオーディオシステムの内部状態
    fprintf('\n--- Test 4: MATLAB音声システム詳細 ---\n');

    % 複数回連続でsound()を呼び出し、内部状態の変化を観察
    fprintf('高速連続再生テスト:\n');
    for i = 1:10
        pre_time = posixtime(datetime('now'));
        sound(test_sound, fs);
        post_time = posixtime(datetime('now'));

        delay = (post_time - pre_time) * 1000;
        fprintf('  高速再生%d: %.3fms\n', i, delay);

        % 待機なしで連続実行
    end

    fprintf('\n=== 調査完了 ===\n');
    fprintf('初回遅延: %.3fms\n', delays(1));
    fprintf('2回目遅延: %.3fms\n', delays(2));
    fprintf('平均遅延(3回目以降): %.3fms\n', mean(delays(3:end)));
    fprintf('5秒後遅延: %.3fms\n', delay_after_pause);
end