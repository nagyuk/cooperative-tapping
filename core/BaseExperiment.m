classdef (Abstract) BaseExperiment < handle
    % BaseExperiment - 実験システム抽象基底クラス
    %
    % 全実験タイプの共通インターフェースと機能を定義
    % - HumanComputerExperiment
    % - HumanHumanExperiment
    % などがこのクラスを継承

    properties (Access = protected)
        audio          % AudioSystemインスタンス
        timer          % TimingControllerインスタンス
        recorder       % DataRecorderインスタンス
        config         % ExperimentConfigインスタンス

        % 実験パラメータ（configから取得、下位互換性のため残す）
        stage1_beats
        stage2_cycles
        target_interval

        % UI要素
        input_fig      % 入力ウィンドウFigure
        window_axes    % ウィンドウ描画用axes

        % グローバルフラグ
        is_running = true
        space_pressed = false
        escape_pressed = false
    end

    properties (Abstract, Access = protected)
        experiment_type  % 'human_computer' or 'human_human'
    end

    methods (Abstract, Access = protected)
        % 各実験タイプで実装が必要な抽象メソッド
        run_stage1(obj)
        run_stage2(obj)
    end

    methods (Access = public)
        function obj = BaseExperiment(varargin)
            % BaseExperiment コンストラクタ
            % 共通システムを初期化
            %
            % Parameters (optional):
            %   config - ExperimentConfigインスタンス または 設定タイプ文字列

            % PsychToolboxパス追加
            if exist('Psychtoolbox', 'dir')
                addpath(genpath('Psychtoolbox'));
            end

            fprintf('=== 協調タッピング実験システム ===\n');

            % 設定の初期化
            if nargin >= 1 && isa(varargin{1}, 'ExperimentConfig')
                % ExperimentConfigインスタンスが渡された場合
                obj.config = varargin{1};
            elseif nargin >= 1 && ischar(varargin{1})
                % 設定タイプ文字列が渡された場合
                obj.config = ExperimentConfig(varargin{1});
            else
                % デフォルト設定
                obj.config = ExperimentConfig('default');
            end

            % configから実験パラメータをコピー（下位互換性）
            obj.stage1_beats = obj.config.stage1_beats;
            obj.stage2_cycles = obj.config.stage2_cycles;
            obj.target_interval = obj.config.target_interval;
        end

        function success = execute(obj)
            % 実験実行メインフロー
            %
            % Returns:
            %   success - 実験成功フラグ

            success = false;

            try
                % 1. 初期化
                obj.initialize_systems();

                % 2. 実験説明
                obj.display_instructions();

                % 3. Stage 1実行
                fprintf('\n=== Stage 1 ===\n');
                obj.run_stage1();
                if ~obj.is_running
                    return;
                end

                % 4. Stage 2実行
                fprintf('\n=== Stage 2 ===\n');
                obj.run_stage2();
                if ~obj.is_running
                    return;
                end

                % 5. データ保存
                obj.save_data();

                % 6. 結果表示
                obj.display_results();

                success = true;
                fprintf('\n✅ 実験が正常に完了しました\n');

            catch ME
                fprintf('\n❌ 実験エラー: %s\n', ME.message);
                fprintf('スタックトレース:\n');
                for i = 1:length(ME.stack)
                    fprintf('  %s (line %d)\n', ME.stack(i).name, ME.stack(i).line);
                end
                success = false;
            end

            % クリーンアップ
            obj.cleanup();
        end

        function initialize_systems(obj)
            % システム初期化（共通処理）

            fprintf('INFO: システムを初期化中...\n');

            % タイミングコントローラー初期化
            obj.timer = TimingController();

            % オーディオシステム初期化
            obj.audio = AudioSystem('channels', 4);

            % 入力ウィンドウ作成
            obj.create_input_window();

            fprintf('✅ システム初期化完了\n');
        end

        function create_input_window(obj)
            % 入力ウィンドウ作成

            obj.input_fig = figure('Name', 'Cooperative Tapping Experiment', ...
                'NumberTitle', 'off', ...
                'MenuBar', 'none', 'ToolBar', 'none', ...
                'Position', [100, 100, 800, 600], ...
                'KeyPressFcn', @(src, event) obj.key_press_handler(src, event), ...
                'KeyReleaseFcn', @(src, event) obj.key_release_handler(src, event), ...
                'CloseRequestFcn', @(src, event) obj.window_close_handler(src, event), ...
                'Color', [0.2, 0.2, 0.2]);

            obj.window_axes = axes('Position', [0, 0, 1, 1], 'Visible', 'off');
        end

        function key_press_handler(obj, ~, event)
            % キー押下ハンドラ（サブクラスでオーバーライド可能）

            switch event.Key
                case 'space'
                    obj.space_pressed = true;
                case 'escape'
                    obj.escape_pressed = true;
                    obj.is_running = false;
            end
        end

        function key_release_handler(obj, ~, event)
            % キーリリースハンドラ（サブクラスでオーバーライド可能）
            % サブクラスで実装
        end

        function window_close_handler(obj, ~, ~)
            % ウィンドウクローズハンドラ
            obj.is_running = false;
            delete(obj.input_fig);
        end

        function wait_for_space(obj)
            % スペースキー待機

            obj.space_pressed = false;
            while ~obj.space_pressed && obj.is_running
                pause(0.01);
                drawnow;
            end
            obj.space_pressed = false;
        end

        function update_display(obj, message, varargin)
            % ウィンドウ表示更新
            %
            % Parameters:
            %   message - 表示メッセージ
            %   varargin - 追加パラメータ（'color', [r,g,b]など）

            cla(obj.window_axes);
            axis(obj.window_axes, [0 1 0 1]);

            % デフォルト色
            color = [1, 1, 1];
            for i = 1:2:length(varargin)
                if strcmp(varargin{i}, 'color')
                    color = varargin{i+1};
                end
            end

            text(0.5, 0.5, message, ...
                'HorizontalAlignment', 'center', ...
                'FontSize', 24, ...
                'Color', color, ...
                'Parent', obj.window_axes);

            drawnow;
        end

        function display_instructions(obj)
            % 実験説明（サブクラスでオーバーライド可能）
            obj.update_display('実験説明', 'color', [0.2, 1.0, 0.2]);
            pause(2);
        end

        function save_data(obj)
            % データ保存
            obj.recorder.save_data();
        end

        function display_results(obj)
            % 結果表示（サブクラスでオーバーライド）
            fprintf('\n=== 実験結果 ===\n');
            fprintf('Stage1イベント数: %d\n', length(obj.recorder.data.stage1_data));
            fprintf('Stage2タップ数: %d\n', length(obj.recorder.data.stage2_data));
        end

        function cleanup(obj)
            % クリーンアップ

            fprintf('INFO: クリーンアップ中...\n');

            % オーディオシステムクローズ
            if ~isempty(obj.audio)
                obj.audio.close();
            end

            % ウィンドウクローズ
            if ~isempty(obj.input_fig) && isvalid(obj.input_fig)
                delete(obj.input_fig);
            end

            fprintf('✅ クリーンアップ完了\n');
        end
    end
end
