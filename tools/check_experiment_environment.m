function check_experiment_environment()
    % check_experiment_environment - MATLABでの実験環境をチェック
    % 必要なツールボックス、ディレクトリ、音声ファイルの確認を行う
    
    fprintf('=== 実験環境チェック ===\n');
    
    all_good = true;
    
    % MATLABのバージョンチェック
    fprintf('\n1. MATLABバージョンチェック:\n');
    matlab_version = version;
    fprintf('   MATLAB Version: %s\n', matlab_version);
    
    % 必要なツールボックスのチェック
    fprintf('\n2. 必要なツールボックスのチェック:\n');
    
    % Audio System Toolbox
    if license('test', 'Audio_System_Toolbox')
        fprintf('   ✓ Audio System Toolbox: 利用可能\n');
    else
        fprintf('   ✗ Audio System Toolbox: 利用不可\n');
        all_good = false;
    end
    
    % Signal Processing Toolbox
    if license('test', 'Signal_Toolbox')
        fprintf('   ✓ Signal Processing Toolbox: 利用可能\n');
    else
        fprintf('   ✓ Signal Processing Toolbox: 利用不可（基本機能のみで動作可能）\n');
    end
    
    % Statistics and Machine Learning Toolbox (Bayesモデル用)
    if license('test', 'Statistics_Toolbox')
        fprintf('   ✓ Statistics and Machine Learning Toolbox: 利用可能\n');
    else
        fprintf('   ⚠ Statistics and Machine Learning Toolbox: 利用不可（Bayesモデルで一部制限）\n');
    end
    
    % 3. 重要なMATLAB関数のチェック
    fprintf('\n3. 重要な関数のチェック:\n');
    
    % posixtime関数
    try
        test_time = posixtime(datetime('now'));
        fprintf('   ✓ posixtime関数: 利用可能\n');
    catch
        fprintf('   ✗ posixtime関数: 利用不可（MATLAB R2019b以降が必要）\n');
        all_good = false;
    end
    
    % audioPlayerRecorder関数
    try
        temp_player = audioPlayerRecorder('SampleRate', 44100);
        release(temp_player);
        fprintf('   ✓ audioPlayerRecorder: 利用可能\n');
    catch
        fprintf('   ✗ audioPlayerRecorder: 利用不可\n');
        all_good = false;
    end
    
    % 4. ディレクトリ構造のチェック
    fprintf('\n4. ディレクトリ構造のチェック:\n');
    
    dirs_to_check = {
        'assets', 'assets/sounds', 'data', 'data/raw', 'data/processed', ...
        'matlab_verification', 'matlab_verification/phase2_core_system'
    };
    
    for i = 1:length(dirs_to_check)
        dir_path = dirs_to_check{i};
        if exist(dir_path, 'dir')
            fprintf('   ✓ %s: 存在\n', dir_path);
        else
            fprintf('   ✗ %s: 作成が必要\n', dir_path);
            try
                mkdir(dir_path);
                fprintf('     → %s を作成しました\n', dir_path);
            catch
                fprintf('     → %s の作成に失敗\n', dir_path);
                all_good = false;
            end
        end
    end
    
    % 5. MATLABファイルの確認
    fprintf('\n5. 必要なMATLABファイルの確認:\n');
    
    matlab_files = {
        'matlab_verification/phase2_core_system/CooperativeTappingMATLAB.m', ...
        'matlab_verification/phase2_core_system/BaseModelMATLAB.m', ...
        'matlab_verification/phase2_core_system/SEAModelMATLAB.m', ...
        'matlab_verification/phase2_core_system/BayesModelMATLAB.m', ...
        'matlab_verification/phase2_core_system/BIBModelMATLAB.m', ...
        'matlab_verification/phase2_core_system/DataCollectorMATLAB.m', ...
        'matlab_verification/phase2_core_system/TimingControllerMATLAB.m', ...
        'matlab_verification/phase2_core_system/InputHandlerMATLAB.m'
    };
    
    for i = 1:length(matlab_files)
        file_path = matlab_files{i};
        if exist(file_path, 'file')
            fprintf('   ✓ %s: 存在\n', file_path);
        else
            fprintf('   ✗ %s: 存在しない\n', file_path);
            all_good = false;
        end
    end
    
    % 6. 音声ファイルの確認
    fprintf('\n6. 音声ファイルの確認:\n');
    
    sound_files = {'assets/sounds/stim_beat.wav', 'assets/sounds/player_beat.wav'};
    for i = 1:length(sound_files)
        file_path = sound_files{i};
        if exist(file_path, 'file')
            fprintf('   ✓ %s: 存在\n', file_path);
        else
            fprintf('   ✗ %s: 存在しない（後で生成します）\n', file_path);
        end
    end
    
    % 7. システム推奨事項
    fprintf('\n7. システム推奨事項:\n');
    
    % オーディオデバイスの確認
    try
        devices = getAudioDevices;
        fprintf('   利用可能なオーディオデバイス数: %d\n', height(devices));
        if height(devices) > 0
            fprintf('   デフォルトデバイス: %s\n', devices.Name{1});
        end
    catch
        fprintf('   オーディオデバイス情報の取得に失敗\n');
    end
    
    % メモリ使用量チェック
    try
        mem_info = memory;
        total_mem_gb = mem_info.MemAvailableAllArrays / 1024^3;
        fprintf('   利用可能メモリ: %.1f GB\n', total_mem_gb);
        if total_mem_gb < 2
            fprintf('   ⚠ メモリが少ない可能性があります（推奨: 2GB以上）\n');
        end
    catch
        fprintf('   メモリ情報の取得に失敗\n');
    end
    
    % 結果サマリー
    fprintf('\n=== チェック結果 ===\n');
    if all_good
        fprintf('✓ 実験環境は正常に設定されています。\n');
        fprintf('次のステップ: 音声ファイルの生成と実験実行\n');
    else
        fprintf('✗ いくつかの問題があります。上記の指示に従って修正してください。\n');
    end
    
    fprintf('\n実験を開始するには run_experiment_matlab.m を実行してください。\n');
end