% サンワサプライ 400-SKB075 プログラマブルキー認識テスト

function programmable_key_test()
    fprintf('=== プログラマブルキー認識テスト ===\n');
    fprintf('400-SKB075 × 2台の独立認識確認\n\n');

    fprintf('設定確認:\n');
    fprintf('  Player 1: ''q''キー（左側プログラマブルキー）\n');
    fprintf('  Player 2: ''p''キー（右側プログラマブルキー）\n\n');

    % キー認識テスト
    test_individual_keys();

    % 同時押しテスト
    test_simultaneous_keys();

    % タイミング精度テスト
    test_timing_precision();
end

function test_individual_keys()
    fprintf('--- 個別キー認識テスト ---\n');
    fprintf('各キーを5回ずつ押してください\n\n');

    player1_count = 0;
    player2_count = 0;
    test_duration = 30; % 30秒間テスト

    fprintf('テスト開始（30秒間）...\n');
    start_time = posixtime(datetime('now'));

    while (posixtime(datetime('now')) - start_time) < test_duration
        % キー入力チェック
        [keyIsDown, ~, keyCode] = KbCheck;

        if keyIsDown
            key_name = KbName(keyCode);
            current_time = posixtime(datetime('now')) - start_time;

            if contains(key_name, 'q')
                player1_count = player1_count + 1;
                fprintf('%.3fs: Player 1 (q) #%d\n', current_time, player1_count);
            elseif contains(key_name, 'p')
                player2_count = player2_count + 1;
                fprintf('%.3fs: Player 2 (p) #%d\n', current_time, player2_count);
            end

            % キーリリース待機
            while KbCheck
                pause(0.001);
            end
            pause(0.1); % デバウンス
        end

        pause(0.01);
    end

    fprintf('\n個別キー認識結果:\n');
    fprintf('  Player 1 (q): %d回\n', player1_count);
    fprintf('  Player 2 (p): %d回\n', player2_count);

    if player1_count > 0 && player2_count > 0
        fprintf('  ✅ 両キー正常認識\n');
    else
        fprintf('  ❌ キー認識エラー\n');
    end
end

function test_simultaneous_keys()
    fprintf('\n--- 同時押し検出テスト ---\n');
    fprintf('両キーを同時に押してください（5回）\n');
    fprintf('ESCキーで終了\n\n');

    simultaneous_count = 0;
    test_active = true;

    while test_active
        [keyIsDown, ~, keyCode] = KbCheck;

        if keyIsDown
            key_names = KbName(keyCode);
            current_time = posixtime(datetime('now'));

            % ESCキーチェック
            if contains(key_names, 'ESCAPE')
                test_active = false;
                break;
            end

            % 複数キー同時押しチェック
            has_q = contains(key_names, 'q');
            has_p = contains(key_names, 'p');

            if has_q && has_p
                simultaneous_count = simultaneous_count + 1;
                fprintf('同時押し #%d 検出\n', simultaneous_count);
            elseif has_q
                fprintf('Player 1のみ (q)\n');
            elseif has_p
                fprintf('Player 2のみ (p)\n');
            end

            % キーリリース待機
            while KbCheck
                pause(0.001);
            end
            pause(0.2); % デバウンス
        end

        pause(0.01);
    end

    fprintf('\n同時押し検出結果:\n');
    fprintf('  同時押し回数: %d回\n', simultaneous_count);

    if simultaneous_count > 0
        fprintf('  ✅ 同時押し検出機能正常\n');
    else
        fprintf('  ⚠️  同時押し未検出\n');
    end
end

function test_timing_precision()
    fprintf('\n--- タイミング精度テスト ---\n');
    fprintf('メトロノームに合わせてキーを押してください\n');
    fprintf('Player 1: q, Player 2: p\n');
    fprintf('ESCキーで終了\n\n');

    % メトロノーム設定
    metro_interval = 1.0; % 1秒間隔
    metro_sound = sin(2*pi*800*(0:0.001:0.1)); % 800Hz、100ms

    player1_times = [];
    player2_times = [];
    metro_times = [];

    test_active = true;
    start_time = posixtime(datetime('now'));
    last_metro = start_time - metro_interval; % 初回メトロノーム用

    while test_active
        current_time = posixtime(datetime('now'));

        % メトロノーム再生
        if (current_time - last_metro) >= metro_interval
            sound(metro_sound, 8000);
            metro_times(end+1) = current_time - start_time;
            last_metro = current_time;
            fprintf('♪ %.3fs\n', current_time - start_time);
        end

        % キー入力チェック
        [keyIsDown, ~, keyCode] = KbCheck;

        if keyIsDown
            key_names = KbName(keyCode);
            tap_time = current_time - start_time;

            % ESCキーチェック
            if contains(key_names, 'ESCAPE')
                test_active = false;
                break;
            end

            if contains(key_names, 'q')
                player1_times(end+1) = tap_time;
                fprintf('  → Player 1: %.3fs\n', tap_time);
            elseif contains(key_names, 'p')
                player2_times(end+1) = tap_time;
                fprintf('  → Player 2: %.3fs\n', tap_time);
            end

            % キーリリース待機
            while KbCheck
                pause(0.001);
            end
            pause(0.1);
        end

        pause(0.001);
    end

    % 精度分析
    analyze_timing_precision(player1_times, player2_times, metro_times);
end

function analyze_timing_precision(p1_times, p2_times, metro_times)
    fprintf('\n--- タイミング精度分析 ---\n');

    % Player 1分析
    if length(p1_times) >= 2
        p1_intervals = diff(p1_times);
        p1_mean = mean(p1_intervals);
        p1_std = std(p1_intervals);

        fprintf('Player 1 (q):\n');
        fprintf('  タップ数: %d\n', length(p1_times));
        fprintf('  平均間隔: %.3fs\n', p1_mean);
        fprintf('  標準偏差: %.1fms\n', p1_std * 1000);

        if p1_std < 0.05 % 50ms以下
            fprintf('  ✅ 高精度タイミング\n');
        else
            fprintf('  ⚠️  タイミングばらつき大\n');
        end
    end

    % Player 2分析
    if length(p2_times) >= 2
        p2_intervals = diff(p2_times);
        p2_mean = mean(p2_intervals);
        p2_std = std(p2_intervals);

        fprintf('\nPlayer 2 (p):\n');
        fprintf('  タップ数: %d\n', length(p2_times));
        fprintf('  平均間隔: %.3fs\n', p2_mean);
        fprintf('  標準偏差: %.1fms\n', p2_std * 1000);

        if p2_std < 0.05 % 50ms以下
            fprintf('  ✅ 高精度タイミング\n');
        else
            fprintf('  ⚠️  タイミングばらつき大\n');
        end
    end

    % 総合評価
    fprintf('\n総合評価:\n');
    if length(p1_times) > 0 && length(p2_times) > 0
        fprintf('  ✅ 両プレイヤーのキー入力検出成功\n');
        fprintf('  ✅ プログラマブルキーシステム動作確認\n');
    else
        fprintf('  ❌ キー入力検出に問題あり\n');
    end
end