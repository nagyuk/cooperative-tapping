function run_human_human()
    % 人間同士協調タッピング実験エントリーポイント
    %
    % 使用法:
    %   run_human_human    % 対話式で実験実行

    fprintf('=== 人間同士協調タッピング実験システム ===\n');
    fprintf('PsychPortAudio高精度音響システム使用\n\n');

    try
        % PsychToolboxパス設定
        if exist('Psychtoolbox', 'dir')
            addpath(genpath('Psychtoolbox'));
            fprintf('PsychToolboxパス設定完了\n');
        else
            warning('Psychtoolboxディレクトリが見つかりません');
        end

        % 実験実行
        human_human_experiment;

    catch ME
        fprintf('エラー: %s\n', ME.message);
        fprintf('スタックトレース:\n');
        for i = 1:length(ME.stack)
            fprintf('  %s (line %d)\n', ME.stack(i).file, ME.stack(i).line);
        end
    end

    fprintf('\n実験終了\n');
end
