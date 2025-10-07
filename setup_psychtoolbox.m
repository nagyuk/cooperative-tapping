% PsychToolbox 3.0.22.1 セットアップスクリプト

function setup_psychtoolbox()
    fprintf('=== PsychToolbox 3.0.22.1 セットアップ ===\n');

    try
        % 現在のディレクトリを確認
        current_dir = pwd;
        fprintf('作業ディレクトリ: %s\n', current_dir);

        % PsychToolboxディレクトリの存在確認
        ptb_dir = fullfile(current_dir, 'Psychtoolbox');
        if ~exist(ptb_dir, 'dir')
            error('Psychtoolboxディレクトリが見つかりません: %s', ptb_dir);
        end

        fprintf('PsychToolboxディレクトリ確認: ✅\n');

        % MATLABパスに追加
        fprintf('MATLABパスに追加中...\n');
        addpath(genpath(ptb_dir));

        % パスを保存
        try
            savepath;
            fprintf('パス保存: ✅\n');
        catch ME
            fprintf('⚠️ パス保存に失敗（権限の問題？）: %s\n', ME.message);
            fprintf('手動でsavepathを実行してください\n');
        end

        % 基本設定実行
        fprintf('\n--- 基本設定実行 ---\n');

        % PsychDefaultSetup (レベル2 = 基本設定)
        fprintf('PsychDefaultSetup実行中...\n');
        PsychDefaultSetup(2);
        fprintf('PsychDefaultSetup: ✅\n');

        % 初回テスト用にSyncTestsをスキップ
        fprintf('SyncTests無効化（初回テスト用）...\n');
        Screen('Preference', 'SkipSyncTests', 1);
        fprintf('SyncTests設定: ✅\n');

        % 基本動作確認
        fprintf('\n--- 基本動作確認 ---\n');

        % スクリーン情報取得
        screens = Screen('Screens');
        fprintf('利用可能なスクリーン数: %d\n', length(screens));

        % PsychPortAudio初期化
        fprintf('PsychPortAudio初期化中...\n');
        InitializePsychSound(1);
        fprintf('PsychPortAudio初期化: ✅\n');

        % オーディオデバイス一覧取得
        devices = PsychPortAudio('GetDevices');
        fprintf('認識された音声デバイス数: %d\n', length(devices));

        % Scarlett 4i4検索
        scarlett_found = false;
        scarlett_device = [];

        for i = 1:length(devices)
            device_name = devices(i).DeviceName;
            fprintf('  デバイス %d: %s\n', devices(i).DeviceIndex, device_name);

            if contains(lower(device_name), 'scarlett') || contains(lower(device_name), '4i4')
                scarlett_found = true;
                scarlett_device = devices(i);
                fprintf('    → ✅ Scarlett 4i4検出！\n');
                fprintf('      DeviceIndex: %d\n', scarlett_device.DeviceIndex);
                fprintf('      MaxChannels: %d (入力), %d (出力)\n', ...
                    scarlett_device.NrInputChannels, scarlett_device.NrOutputChannels);
            end
        end

        if ~scarlett_found
            fprintf('⚠️ Scarlett 4i4が見つかりません\n');
            fprintf('デバイスが接続されているか確認してください\n');
        end

        % GetSecs精度テスト
        fprintf('\n--- GetSecs精度テスト ---\n');
        test_getsecs_precision();

        fprintf('\n=== PsychToolboxセットアップ完了 ===\n');
        fprintf('次のステップ:\n');
        fprintf('1. GStreamerインストール完了確認\n');
        fprintf('2. Scarlett 4i4接続確認\n');
        fprintf('3. 高精度音声システム実装開始\n');

    catch ME
        fprintf('❌ セットアップエラー: %s\n', ME.message);
        fprintf('スタック:\n');
        for i = 1:length(ME.stack)
            fprintf('  %s (line %d)\n', ME.stack(i).file, ME.stack(i).line);
        end
    end
end

function test_getsecs_precision()
    fprintf('GetSecs精度測定...\n');

    % 10回測定
    times = zeros(1, 10);
    for i = 1:10
        times(i) = GetSecs;
        pause(0.001); % 1ms待機
    end

    % 間隔計算
    intervals = diff(times);
    mean_interval = mean(intervals);
    std_interval = std(intervals);

    fprintf('  平均間隔: %.6fs (%.3fms)\n', mean_interval, mean_interval * 1000);
    fprintf('  標準偏差: %.6fs (%.3fms)\n', std_interval, std_interval * 1000);

    if std_interval < 0.0001 % 0.1ms以下
        fprintf('  ✅ 高精度タイミング確認\n');
    else
        fprintf('  ⚠️ タイミング精度要確認\n');
    end
end

function test_basic_audio()
    fprintf('\n--- 基本音声テスト ---\n');

    try
        % 短いテスト音生成
        fs = 48000;
        duration = 0.2;
        t = 0:1/fs:duration-1/fs;
        test_sound = 0.3 * sin(2*pi*440*t); % 440Hz、200ms

        % デフォルトデバイスでテスト
        fprintf('基本音声再生テスト...\n');
        pahandle = PsychPortAudio('Open', [], [], 0, fs, 1);
        PsychPortAudio('FillBuffer', pahandle, test_sound);
        PsychPortAudio('Start', pahandle, 1, 0, 1);
        WaitSecs(duration + 0.1);
        PsychPortAudio('Close', pahandle);

        fprintf('  ✅ 基本音声再生成功\n');

    catch ME
        fprintf('  ❌ 音声テストエラー: %s\n', ME.message);
    end
end