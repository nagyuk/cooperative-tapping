function run_unified_experiment()
    % run_unified_experiment - 統合実験システムエントリーポイント
    %
    % 協調タッピング実験システム（統合版）
    % - 人間-コンピュータ実験（SEA/Bayesian/BIB）
    % - 人間-人間協調実験
    %
    % Usage:
    %   run_unified_experiment()

    fprintf('========================================\n');
    fprintf('   協調タッピング実験システム v2.0\n');
    fprintf('========================================\n\n');

    % PsychToolboxパス追加
    if exist('Psychtoolbox', 'dir')
        addpath(genpath('Psychtoolbox'));
    end

    % コアシステムパス追加
    addpath(genpath('core'));
    addpath(genpath('experiments'));
    addpath(genpath('ui'));
    addpath(genpath('utils'));

    try
        % 実験タイプ選択
        fprintf('実験タイプを選択してください:\n');
        fprintf('  1. 人間-コンピュータ実験 (SEA/Bayesian/BIB)\n');
        fprintf('  2. 人間-人間協調実験\n');
        fprintf('  3. 終了\n\n');

        choice = input('選択 (1-3): ');

        switch choice
            case 1
                run_human_computer();
            case 2
                run_human_human();
            case 3
                fprintf('終了します\n');
                return;
            otherwise
                error('無効な選択です');
        end

    catch ME
        fprintf('\n❌ エラー: %s\n', ME.message);
        fprintf('スタックトレース:\n');
        for i = 1:length(ME.stack)
            fprintf('  %s (line %d)\n', ME.stack(i).name, ME.stack(i).line);
        end
    end
end

function run_human_computer()
    % 人間-コンピュータ実験実行

    fprintf('\n人間-コンピュータ実験はまだ実装中です\n');
    fprintf('現在のmain_experiment.mを使用してください\n');

    % TODO: HumanComputerExperimentクラス実装後に有効化
    % exp = HumanComputerExperiment();
    % exp.execute();
end

function run_human_human()
    % 人間-人間協調実験実行

    fprintf('\n=== 人間-人間協調実験 ===\n\n');

    % HumanHumanExperimentインスタンス作成
    exp = HumanHumanExperiment();

    % 実験実行
    success = exp.execute();

    if success
        fprintf('\n✅ 実験が正常に完了しました\n');
    else
        fprintf('\n⚠️  実験が中断されました\n');
    end
end
