function config = experiment_config()
    % 実験設定を返す
    %
    % Output:
    %   config - 実験設定構造体
    
    config = struct();
    
    % 基本タイミングパラメータ
    config.SPAN = 2.0;          % 基本間隔（秒）
    config.STAGE1 = 10;         % Stage1のタップ数
    config.STAGE2 = 20;         % Stage2のタップ数  
    config.BUFFER = 2;          % 解析から除外するタップ数
    config.SCALE = 0.1;         % ランダム変動のスケール
    
    % 音声ファイルパス（experimentsディレクトリからの相対パス）
    config.SOUND_STIM = '../assets/sounds/stim_beat.wav';
    config.SOUND_PLAYER = '../assets/sounds/player_beat.wav';
    
    % データ保存パス
    config.DATA_DIR = '../data/raw';
    
    % モデルパラメータ
    config.BAYES_N_HYPOTHESIS = 20;  % Bayesianモデルの仮説数
    config.BIB_L_MEMORY = 1;         % BIBモデルのメモリ長
end