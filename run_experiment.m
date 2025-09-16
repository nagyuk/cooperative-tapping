function run_experiment()
    % 協調タッピング実験メインエントリーポイント
    %
    % 使用法:
    %   run_experiment    % 対話式で実験実行
    
    fprintf('=== 協調タッピング実験システム ===\n');
    fprintf('実験ディレクトリに移動します...\n');
    
    % experimentsディレクトリに移動
    if ~exist('experiments', 'dir')
        error('experimentsディレクトリが見つかりません');
    end
    
    original_dir = pwd;
    cd('experiments');
    
    try
        % 実験実行
        main_experiment;  % スクリプトとして実行
    catch ME
        fprintf('エラー: %s\n', ME.message);
    end
    
    % 元のディレクトリに戻る
    cd(original_dir);
    
    fprintf('実験完了\n');
end