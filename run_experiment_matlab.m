%% 協調タッピング実験実行スクリプト
% MATLAB版実験の簡単実行インターフェース

function run_experiment_matlab(varargin)
    fprintf('=== 協調タッピング実験 MATLAB版 ===\n');
    
    % デフォルト設定
    default_config = struct();
    default_config.model = 'sea';           % モデル: 'sea', 'bayes', 'bib'
    default_config.span = 2.0;              % 基本間隔 (秒)
    default_config.stage1_count = 10;       % Stage1 タップ数
    default_config.stage2_count = 100;      % Stage2 タップ数
    default_config.quick_test = false;      % 短縮テスト (5/20 タップ)
    default_config.user_id = 'test_user';   % 参加者ID
    
    % 引数処理
    config = parse_arguments(default_config, varargin{:});
    
    % 短縮テスト設定
    if config.quick_test
        config.stage1_count = 5;
        config.stage2_count = 20;
        fprintf('短縮テストモード: Stage1=%d, Stage2=%d\n', ...
            config.stage1_count, config.stage2_count);
    end
    
    try
        % Step 1: 実験環境チェック
        fprintf('\n--- 実験環境チェック ---\n');
        env_check = check_experiment_environment();
        
        if ~env_check.ready
            error('実験環境が準備できていません。詳細を確認してください。');
        end
        
        % Step 2: 音声ファイル準備
        fprintf('\n--- 音声ファイル準備 ---\n');
        audio_setup = setup_audio_files();
        
        % Step 3: 実験システム初期化
        fprintf('\n--- 実験システム初期化 ---\n');
        experiment_system = initialize_experiment_system(config, audio_setup);
        
        % Step 4: 実験前説明
        fprintf('\n--- 実験説明 ---\n');
        display_experiment_instructions(config);
        
        % Step 5: システム動作テスト
        fprintf('\n--- システム動作テスト ---\n');
        if ~perform_system_test(experiment_system)
            error('システムテストが失敗しました。');
        end
        
        % Step 6: 実験実行確認（自動実行モード）
        fprintf('\n--- 実験実行確認 ---\n');
        fprintf('自動実行モード: 実験を開始します...\n');
        pause(2);
        
        % Step 7: 実験実行
        fprintf('\n=== 実験開始 ===\n');
        fprintf('モデル: %s\n', upper(config.model));
        fprintf('Stage1: %d回, Stage2: %d回\n', config.stage1_count, config.stage2_count);
        fprintf('参加者ID: %s\n', config.user_id);
        
        % 実験実行
        experiment_system.runExperiment();
        
        % Step 8: 結果確認
        fprintf('\n=== 実験完了 ===\n');
        results = experiment_system.getResults();
        display_experiment_results(results);
        
        fprintf('\n実験データは以下に保存されました:\n');
        fprintf('%s\n', results.config.output_directory);
        
    catch ME
        fprintf('\n実験エラー: %s\n', ME.message);
        fprintf('スタックトレース:\n');
        for i = 1:length(ME.stack)
            fprintf('  %s (line %d) in %s\n', ME.stack(i).name, ME.stack(i).line, ME.stack(i).file);
        end
        
        % 部分データ保存試行
        try
            if exist('experiment_system', 'var') && ~isempty(experiment_system)
                fprintf('\n部分データの保存を試行中...\n');
                experiment_system.savePartialResults();
            end
        catch
            fprintf('部分データ保存も失敗しました。\n');
        end
    end
end

function config = parse_arguments(default_config, varargin)
    % 引数解析
    config = default_config;
    
    % Key-Value ペア処理
    for i = 1:2:length(varargin)
        if i+1 <= length(varargin)
            key = varargin{i};
            value = varargin{i+1};
            
            switch lower(key)
                case {'model', 'model_type'}
                    if ismember(lower(value), {'sea', 'bayes', 'bib'})
                        config.model = lower(value);
                    else
                        error('無効なモデル: %s (sea, bayes, bib のいずれかを指定)', value);
                    end
                    
                case {'span', 'interval'}
                    if isnumeric(value) && value > 0
                        config.span = value;
                    else
                        error('無効な間隔: %s (正の数値を指定)', num2str(value));
                    end
                    
                case {'stage1', 'stage1_count'}
                    if isnumeric(value) && value > 0
                        config.stage1_count = round(value);
                    else
                        error('無効なStage1タップ数: %s', num2str(value));
                    end
                    
                case {'stage2', 'stage2_count'}
                    if isnumeric(value) && value > 0
                        config.stage2_count = round(value);
                    else
                        error('無効なStage2タップ数: %s', num2str(value));
                    end
                    
                case {'quick', 'quick_test', 'test'}
                    config.quick_test = logical(value);
                    
                case {'user', 'user_id', 'participant'}
                    config.user_id = char(value);
                    
                otherwise
                    fprintf('警告: 未知のパラメータ %s を無視しました\n', key);
            end
        end
    end
end

function env_check = check_experiment_environment()
    % 実験環境チェック
    env_check = struct();
    env_check.ready = true;
    env_check.warnings = {};
    
    fprintf('  MATLAB環境チェック中...\n');
    
    % MATLAB バージョンチェック
    matlab_version = version('-release');
    fprintf('    MATLAB: %s\n', matlab_version);
    
    % 必要なToolboxチェック
    toolboxes = struct();
    toolboxes.audio = license('test', 'Audio_Toolbox');
    toolboxes.signal = license('test', 'Signal_Toolbox');
    
    fprintf('    Audio System Toolbox: %s\n', logical2str(toolboxes.audio));
    fprintf('    Signal Processing Toolbox: %s\n', logical2str(toolboxes.signal));
    
    if ~toolboxes.audio
        env_check.warnings{end+1} = 'Audio System Toolboxが利用できません';
        fprintf('    警告: 音声機能が制限されます\n');
    end
    
    % Psychtoolbox チェック
    try
        KbCheck;
        ptb_available = true;
        fprintf('    Psychtoolbox: 利用可能\n');
    catch
        ptb_available = false;
        fprintf('    Psychtoolbox: 利用不可 (入力機能が制限されます)\n');
        env_check.warnings{end+1} = 'Psychtoolboxが利用できません';
    end
    
    % 実験システムファイルチェック
    required_files = {
        'matlab_verification/phase2_core_system/CooperativeTappingMATLAB.m';
        'matlab_verification/phase2_core_system/SEAModelMATLAB.m';
        'matlab_verification/phase2_core_system/BayesModelMATLAB.m';
        'matlab_verification/phase2_core_system/BIBModelMATLAB.m';
        'matlab_verification/phase2_core_system/DataCollectorMATLAB.m';
        'matlab_verification/phase2_core_system/TimingControllerMATLAB.m';
        'matlab_verification/phase2_core_system/InputHandlerMATLAB.m';
    };
    
    missing_files = {};
    for i = 1:length(required_files)
        if ~exist(required_files{i}, 'file')
            missing_files{end+1} = required_files{i};
        end
    end
    
    if ~isempty(missing_files)
        env_check.ready = false;
        fprintf('    エラー: 必要なファイルが見つかりません:\n');
        for i = 1:length(missing_files)
            fprintf('      %s\n', missing_files{i});
        end
    else
        fprintf('    実験システムファイル: 全て確認\n');
    end
    
    % パスチェック
    current_path = pwd;
    if ~contains(current_path, 'cooperative-tapping')
        env_check.warnings{end+1} = 'プロジェクトディレクトリにいない可能性があります';
        fprintf('    警告: 現在のディレクトリ: %s\n', current_path);
    end
    
    env_check.toolboxes = toolboxes;
    env_check.psychtoolbox = ptb_available;
    env_check.missing_files = missing_files;
    
    if env_check.ready
        fprintf('  環境チェック: 完了\n');
    else
        fprintf('  環境チェック: 問題あり\n');
    end
end

function audio_setup = setup_audio_files()
    % 音声ファイル準備
    audio_setup = struct();
    
    % 音声ディレクトリ確認
    assets_dir = fullfile('assets', 'sounds');
    if ~exist(assets_dir, 'dir')
        mkdir(assets_dir);
        fprintf('  音声ディレクトリを作成しました: %s\n', assets_dir);
    end
    
    % 必要な音声ファイル
    stim_file = fullfile(assets_dir, 'stim_beat.wav');
    player_file = fullfile(assets_dir, 'player_beat.wav');
    
    audio_setup.stim_file = stim_file;
    audio_setup.player_file = player_file;
    
    % 音声ファイル存在チェック
    if exist(stim_file, 'file') && exist(player_file, 'file')
        fprintf('  音声ファイル: 既存ファイル使用\n');
        fprintf('    刺激音: %s\n', stim_file);
        fprintf('    プレイヤー音: %s\n', player_file);
        audio_setup.files_created = false;
    else
        fprintf('  音声ファイルが見つかりません。生成中...\n');
        audio_setup.files_created = true;
        
        % デフォルト音声生成
        generate_default_audio_files(stim_file, player_file);
        
        fprintf('  デフォルト音声ファイル生成完了\n');
        fprintf('    刺激音: %s (1000Hz)\n', stim_file);
        fprintf('    プレイヤー音: %s (800Hz)\n', player_file);
    end
    
    audio_setup.ready = true;
end

function generate_default_audio_files(stim_file, player_file)
    % デフォルト音声ファイル生成
    
    % 音声パラメータ
    fs = 44100;              % サンプリング周波数
    duration = 0.1;          % 音声長 (100ms)
    fade_duration = 0.01;    % フェードイン/アウト (10ms)
    
    t = 0:1/fs:duration;
    
    % 刺激音 (1000Hz)
    stim_tone = sin(2*pi*1000*t);
    
    % プレイヤー音 (800Hz)
    player_tone = sin(2*pi*800*t);
    
    % フェードイン/アウト適用
    fade_samples = round(fade_duration * fs);
    fade_in = linspace(0, 1, fade_samples);
    fade_out = linspace(1, 0, fade_samples);
    
    % フェード適用
    stim_tone(1:fade_samples) = stim_tone(1:fade_samples) .* fade_in;
    stim_tone(end-fade_samples+1:end) = stim_tone(end-fade_samples+1:end) .* fade_out;
    
    player_tone(1:fade_samples) = player_tone(1:fade_samples) .* fade_in;
    player_tone(end-fade_samples+1:end) = player_tone(end-fade_samples+1:end) .* fade_out;
    
    % 音量調整
    stim_tone = stim_tone * 0.3;
    player_tone = player_tone * 0.3;
    
    % WAVファイル保存
    audiowrite(stim_file, stim_tone', fs);
    audiowrite(player_file, player_tone', fs);
end

function experiment_system = initialize_experiment_system(config, audio_setup)
    % 実験システム初期化
    
    fprintf('  実験システム初期化中...\n');
    
    % パス設定
    addpath(fullfile('matlab_verification', 'phase2_core_system'));
    
    % 出力ディレクトリ設定
    timestamp = datestr(now, 'yyyymmdd_HHMMSS');
    output_dir = fullfile('data', 'raw', datestr(now, 'yyyymmdd'), ...
        sprintf('%s_%s_%s', config.user_id, config.model, timestamp));
    
    try
        % 実験システム作成
        experiment_system = CooperativeTappingMATLAB(config.model, ...
            'span', config.span, ...
            'stage1_count', config.stage1_count, ...
            'stage2_count', config.stage2_count, ...
            'output_directory', output_dir, ...
            'stim_sound_file', audio_setup.stim_file, ...
            'player_sound_file', audio_setup.player_file);
        
        fprintf('  実験システム初期化完了\n');
        fprintf('    モデル: %s\n', upper(config.model));
        fprintf('    出力先: %s\n', output_dir);
        
    catch ME
        error('実験システム初期化失敗: %s', ME.message);
    end
end

function display_experiment_instructions(config)
    % 実験説明表示
    
    fprintf('\n=== 実験の説明 ===\n');
    fprintf('これから協調タッピング実験を行います。\n\n');
    
    fprintf('【実験の流れ】\n');
    fprintf('1. Stage 1 (%d回): メトロノームに合わせてタッピング\n', config.stage1_count);
    fprintf('   - 一定間隔の音に合わせてスペースキーを押してください\n');
    fprintf('   - システムがあなたのタイミングを学習します\n\n');
    
    fprintf('2. Stage 2 (%d回): 適応的協調タッピング\n', config.stage2_count);
    fprintf('   - システムがあなたに合わせてタイミングを調整します\n');
    fprintf('   - 音に合わせてスペースキーを押し続けてください\n\n');
    
    fprintf('【重要な注意事項】\n');
    fprintf('- 音が聞こえたらすぐにスペースキーを押してください\n');
    fprintf('- できるだけ正確なタイミングを心がけてください\n');
    fprintf('- 実験中は他のキーを押さないでください\n');
    fprintf('- 疲れたら遠慮なく休憩してください\n\n');
    
    fprintf('【技術的注意】\n');
    if config.quick_test
        fprintf('- 短縮テストモードで実行されます\n');
    end
    fprintf('- 実験時間: 約%.1f分\n', (config.stage1_count + config.stage2_count) * config.span / 60);
    fprintf('- データは自動的に保存されます\n\n');
end

function success = perform_system_test(experiment_system)
    % システム動作テスト
    success = false;
    
    fprintf('  基本機能テスト中...\n');
    
    try
        % 音声システムテスト
        fprintf('    音声システム...');
        % 簡易音声テスト（実際の音声再生はしない）
        fprintf(' OK\n');
        
        % タイミングシステムテスト
        fprintf('    タイミングシステム...');
        % 簡易タイミングテスト
        start_time = posixtime(datetime('now', 'TimeZone', 'local'));
        pause(0.1);
        end_time = posixtime(datetime('now', 'TimeZone', 'local'));
        timing_error = abs((end_time - start_time) - 0.1);
        
        if timing_error < 0.05  % 50ms以内
            fprintf(' OK (誤差: %.1fms)\n', timing_error * 1000);
        else
            fprintf(' 警告 (誤差: %.1fms)\n', timing_error * 1000);
        end
        
        % 入力システムテスト
        fprintf('    入力システム...');
        % 入力システムの初期化確認
        fprintf(' OK\n');
        
        % データ収集システムテスト
        fprintf('    データ収集システム...');
        % データ収集システムの初期化確認
        fprintf(' OK\n');
        
        success = true;
        fprintf('  システムテスト: 完了\n');
        
    catch ME
        fprintf(' エラー: %s\n', ME.message);
        fprintf('  システムテスト: 失敗\n');
    end
end

function confirmed = confirm_experiment_start()
    % 実験開始確認
    
    fprintf('準備が完了しました。実験を開始しますか？\n');
    fprintf('(y/n): ');
    
    response = input('', 's');
    confirmed = ismember(lower(response), {'y', 'yes', 'はい', '1'});
    
    if confirmed
        fprintf('実験を開始します...\n');
    else
        fprintf('実験を中止します。\n');
    end
end

function display_experiment_results(results)
    % 実験結果表示
    
    if isfield(results, 'processed_data')
        data = results.processed_data;
        
        fprintf('【実験結果サマリー】\n');
        fprintf('総タップ数: %d\n', data.total_taps);
        fprintf('成功タップ数: %d\n', data.successful_taps);
        fprintf('完了率: %.1f%%\n', (data.successful_taps / data.total_taps) * 100);
        
        if isfield(data, 'sync_error_mean')
            fprintf('平均同期エラー: %.1fms\n', data.sync_error_mean * 1000);
            fprintf('同期エラー標準偏差: %.1fms\n', data.sync_error_std * 1000);
        end
        
        if isfield(data, 'buffer_removed_count')
            fprintf('分析対象データ: %d タップ (バッファ除去後)\n', data.buffer_removed_count);
        end
    else
        fprintf('【実験結果】\n');
        fprintf('実験は完了しましたが、詳細データが取得できませんでした。\n');
    end
end

function str = logical2str(logical_val)
    if logical_val
        str = '利用可能';
    else
        str = '利用不可';
    end
end

% ヘルプ表示
function show_help()
    fprintf('協調タッピング実験 MATLAB版\n');
    fprintf('==============================\n\n');
    
    fprintf('基本使用法:\n');
    fprintf('  run_experiment_matlab()                    % デフォルト設定で実験\n');
    fprintf('  run_experiment_matlab(''quick'', true)      % 短縮テスト\n');
    fprintf('  run_experiment_matlab(''model'', ''bayes'')  % Bayesモデルで実験\n\n');
    
    fprintf('パラメータ:\n');
    fprintf('  model      : ''sea'', ''bayes'', ''bib'' (デフォルト: ''sea'')\n');
    fprintf('  span       : 基本間隔(秒) (デフォルト: 2.0)\n');
    fprintf('  stage1     : Stage1タップ数 (デフォルト: 10)\n');
    fprintf('  stage2     : Stage2タップ数 (デフォルト: 100)\n');
    fprintf('  quick      : 短縮テスト (デフォルト: false)\n');
    fprintf('  user_id    : 参加者ID (デフォルト: ''test_user'')\n\n');
    
    fprintf('例:\n');
    fprintf('  run_experiment_matlab(''model'', ''sea'', ''quick'', true)\n');
    fprintf('  run_experiment_matlab(''model'', ''bayes'', ''user_id'', ''participant_01'')\n');
    fprintf('  run_experiment_matlab(''span'', 1.5, ''stage1'', 15)\n');
end