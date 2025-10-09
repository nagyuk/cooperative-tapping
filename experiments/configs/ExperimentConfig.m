classdef ExperimentConfig < handle
    % ExperimentConfig - 実験パラメータ設定クラス
    %
    % 実験に関わる全パラメータを一元管理
    % デフォルト値の提供と設定の検証を行う
    %
    % Usage:
    %   config = ExperimentConfig();  % デフォルト設定
    %   config = ExperimentConfig('pilot');  % パイロット実験用
    %   config = ExperimentConfig('main');   % 本実験用
    %   config = ExperimentConfig('custom'); % 対話的に設定

    properties (Access = public)
        % === 実験設計パラメータ ===
        stage1_beats      % Stage1のビート数（デフォルト: 10）
        stage2_cycles     % Stage2のサイクル数（デフォルト: 20）
        target_interval   % 目標タップ間隔（秒、デフォルト: 1.0）

        % === モデルパラメータ（Human-Computer実験用） ===
        SPAN              % 目標サイクル期間（秒、デフォルト: 2.0）
        SCALE             % ランダム変動スケール（デフォルト: 0.02）
        BAYES_N_HYPOTHESIS  % ベイズ仮説数（デフォルト: 20）
        BIB_L_MEMORY      % BIBメモリ長（デフォルト: 1）

        % === 実験フロー設定 ===
        enable_practice   % 練習試行を実施するか（デフォルト: false）
        practice_cycles   % 練習試行のサイクル数（デフォルト: 5）

        % === デバッグ設定 ===
        DEBUG_MODEL       % モデルデバッグ出力（デフォルト: false）
        DEBUG_TIMING      % タイミングデバッグ出力（デフォルト: false）

        % === メタ情報 ===
        config_name       % 設定名（'default', 'pilot', 'main', 'custom'）
        created_date      % 設定作成日時
    end

    methods (Access = public)
        function obj = ExperimentConfig(config_type)
            % ExperimentConfig コンストラクタ
            %
            % Parameters:
            %   config_type - 設定タイプ（'default', 'pilot', 'main', 'custom'）

            if nargin < 1
                config_type = 'default';
            end

            obj.config_name = config_type;
            obj.created_date = datetime('now');

            % 設定タイプに応じて初期化
            switch lower(config_type)
                case 'default'
                    obj.load_default_config();
                case 'pilot'
                    obj.load_pilot_config();
                case 'main'
                    obj.load_main_config();
                case 'custom'
                    obj.load_custom_config();
                otherwise
                    warning('不明な設定タイプ: %s。デフォルト設定を使用します。', config_type);
                    obj.load_default_config();
            end

            % 設定の妥当性検証
            obj.validate_config();
        end

        function load_default_config(obj)
            % デフォルト設定（従来の設定値）

            fprintf('📋 デフォルト設定を読み込み中...\n');

            % 実験設計
            obj.stage1_beats = 10;
            obj.stage2_cycles = 20;
            obj.target_interval = 1.0;

            % モデルパラメータ
            obj.SPAN = 2.0;
            obj.SCALE = 0.02;
            obj.BAYES_N_HYPOTHESIS = 20;
            obj.BIB_L_MEMORY = 1;

            % 実験フロー
            obj.enable_practice = false;
            obj.practice_cycles = 5;

            % デバッグ
            obj.DEBUG_MODEL = false;
            obj.DEBUG_TIMING = false;

            fprintf('✅ デフォルト設定完了\n');
        end

        function load_pilot_config(obj)
            % パイロット実験用設定
            % - Stage2サイクル数を減らして疲労を軽減
            % - 練習試行を有効化

            fprintf('📋 パイロット実験設定を読み込み中...\n');

            % 実験設計（パイロット用に調整）
            obj.stage1_beats = 10;
            obj.stage2_cycles = 15;  % 短めに設定
            obj.target_interval = 1.0;

            % モデルパラメータ（デフォルトと同じ）
            obj.SPAN = 2.0;
            obj.SCALE = 0.02;
            obj.BAYES_N_HYPOTHESIS = 20;
            obj.BIB_L_MEMORY = 1;

            % 実験フロー（練習を有効化）
            obj.enable_practice = true;
            obj.practice_cycles = 5;

            % デバッグ（詳細ログを有効化）
            obj.DEBUG_MODEL = true;
            obj.DEBUG_TIMING = true;

            fprintf('✅ パイロット実験設定完了\n');
            fprintf('   - Stage2: %dサイクル（疲労軽減）\n', obj.stage2_cycles);
            fprintf('   - 練習試行: 有効（%dサイクル）\n', obj.practice_cycles);
        end

        function load_main_config(obj)
            % 本実験用設定
            % - 統計的検出力を確保するためのサイクル数
            % - 練習試行は無効（参加者は事前に経験済み）

            fprintf('📋 本実験設定を読み込み中...\n');

            % 実験設計（本実験用に調整）
            obj.stage1_beats = 10;
            obj.stage2_cycles = 30;  % 十分なデータ確保
            obj.target_interval = 1.0;

            % モデルパラメータ（パイロット結果を反映予定）
            % TODO: パイロット実験後に更新
            obj.SPAN = 2.0;
            obj.SCALE = 0.02;
            obj.BAYES_N_HYPOTHESIS = 20;
            obj.BIB_L_MEMORY = 1;

            % 実験フロー（練習なし）
            obj.enable_practice = false;
            obj.practice_cycles = 5;

            % デバッグ（本実験では無効）
            obj.DEBUG_MODEL = false;
            obj.DEBUG_TIMING = false;

            fprintf('✅ 本実験設定完了\n');
            fprintf('   - Stage2: %dサイクル（十分なデータ）\n', obj.stage2_cycles);
            fprintf('   - 練習試行: 無効\n');
        end

        function load_custom_config(obj)
            % カスタム設定（対話的に入力）

            fprintf('📋 カスタム設定モード\n');
            fprintf('各パラメータを入力してください（空欄でデフォルト値）\n\n');

            % デフォルト値をロード
            obj.load_default_config();

            % 実験設計パラメータ
            fprintf('=== 実験設計パラメータ ===\n');
            obj.stage1_beats = obj.input_with_default('Stage1ビート数', obj.stage1_beats);
            obj.stage2_cycles = obj.input_with_default('Stage2サイクル数', obj.stage2_cycles);
            obj.target_interval = obj.input_with_default('目標タップ間隔（秒）', obj.target_interval);

            % モデルパラメータ
            fprintf('\n=== モデルパラメータ（Human-Computer実験用） ===\n');
            obj.SPAN = obj.input_with_default('SPAN（サイクル期間）', obj.SPAN);
            obj.SCALE = obj.input_with_default('SCALE（変動スケール）', obj.SCALE);
            obj.BAYES_N_HYPOTHESIS = obj.input_with_default('BAYES_N_HYPOTHESIS', obj.BAYES_N_HYPOTHESIS);
            obj.BIB_L_MEMORY = obj.input_with_default('BIB_L_MEMORY', obj.BIB_L_MEMORY);

            % 実験フロー
            fprintf('\n=== 実験フロー ===\n');
            enable_practice_input = input(sprintf('練習試行を有効化？ (y/n) [デフォルト: %s]: ', ...
                iif(obj.enable_practice, 'y', 'n')), 's');
            if ~isempty(enable_practice_input)
                obj.enable_practice = strcmpi(enable_practice_input, 'y');
            end

            if obj.enable_practice
                obj.practice_cycles = obj.input_with_default('練習サイクル数', obj.practice_cycles);
            end

            % デバッグ
            fprintf('\n=== デバッグ設定 ===\n');
            debug_model_input = input('モデルデバッグ出力を有効化？ (y/n) [デフォルト: n]: ', 's');
            obj.DEBUG_MODEL = strcmpi(debug_model_input, 'y');

            debug_timing_input = input('タイミングデバッグ出力を有効化？ (y/n) [デフォルト: n]: ', 's');
            obj.DEBUG_TIMING = strcmpi(debug_timing_input, 'y');

            fprintf('\n✅ カスタム設定完了\n');
        end

        function value = input_with_default(~, prompt, default_value)
            % デフォルト値付き入力

            user_input = input(sprintf('%s [デフォルト: %g]: ', prompt, default_value), 's');
            if isempty(user_input)
                value = default_value;
            else
                value = str2double(user_input);
                if isnan(value)
                    warning('無効な入力。デフォルト値を使用します。');
                    value = default_value;
                end
            end
        end

        function validate_config(obj)
            % 設定の妥当性検証

            errors = {};

            % Stage1ビート数
            if obj.stage1_beats < 5 || obj.stage1_beats > 50
                errors{end+1} = sprintf('stage1_beats=%d は範囲外です（推奨: 5-50）', obj.stage1_beats);
            end

            % Stage2サイクル数
            if obj.stage2_cycles < 5 || obj.stage2_cycles > 100
                errors{end+1} = sprintf('stage2_cycles=%d は範囲外です（推奨: 5-100）', obj.stage2_cycles);
            end

            % 目標間隔
            if obj.target_interval < 0.3 || obj.target_interval > 3.0
                errors{end+1} = sprintf('target_interval=%.2f は範囲外です（推奨: 0.3-3.0秒）', obj.target_interval);
            end

            % SPAN
            if obj.SPAN < 0.5 || obj.SPAN > 5.0
                errors{end+1} = sprintf('SPAN=%.2f は範囲外です（推奨: 0.5-5.0秒）', obj.SPAN);
            end

            % SCALE
            if obj.SCALE < 0.001 || obj.SCALE > 1.0
                errors{end+1} = sprintf('SCALE=%.3f は範囲外です（推奨: 0.001-1.0）', obj.SCALE);
            end

            % エラーがあれば警告
            if ~isempty(errors)
                fprintf('\n⚠️  設定の検証で警告が見つかりました:\n');
                for i = 1:length(errors)
                    fprintf('  %d. %s\n', i, errors{i});
                end
                fprintf('\n続行しますか？ (y/n): ');
                response = input('', 's');
                if ~strcmpi(response, 'y')
                    error('ExperimentConfig:ValidationFailed', '設定検証に失敗しました');
                end
            end
        end

        function display_config(obj)
            % 現在の設定を表示

            fprintf('\n========================================\n');
            fprintf('   実験設定: %s\n', obj.config_name);
            fprintf('========================================\n');
            fprintf('作成日時: %s\n', datestr(obj.created_date));
            fprintf('\n');

            fprintf('--- 実験設計 ---\n');
            fprintf('Stage1ビート数: %d\n', obj.stage1_beats);
            fprintf('Stage2サイクル数: %d\n', obj.stage2_cycles);
            fprintf('目標タップ間隔: %.2f秒\n', obj.target_interval);
            fprintf('\n');

            fprintf('--- モデルパラメータ ---\n');
            fprintf('SPAN: %.2f秒\n', obj.SPAN);
            fprintf('SCALE: %.3f\n', obj.SCALE);
            fprintf('BAYES_N_HYPOTHESIS: %d\n', obj.BAYES_N_HYPOTHESIS);
            fprintf('BIB_L_MEMORY: %d\n', obj.BIB_L_MEMORY);
            fprintf('\n');

            fprintf('--- 実験フロー ---\n');
            fprintf('練習試行: %s', iif(obj.enable_practice, '有効', '無効'));
            if obj.enable_practice
                fprintf(' (%dサイクル)', obj.practice_cycles);
            end
            fprintf('\n');
            fprintf('\n');

            fprintf('--- デバッグ ---\n');
            fprintf('モデルデバッグ: %s\n', iif(obj.DEBUG_MODEL, '有効', '無効'));
            fprintf('タイミングデバッグ: %s\n', iif(obj.DEBUG_TIMING, '有効', '無効'));
            fprintf('========================================\n\n');
        end

        function save_config(obj, filename)
            % 設定をファイルに保存
            %
            % Parameters:
            %   filename - 保存ファイル名（デフォルト: 自動生成）

            if nargin < 2
                timestamp = datestr(obj.created_date, 'yyyymmdd_HHMMSS');
                filename = sprintf('experiments/configs/saved/%s_%s.mat', ...
                    obj.config_name, timestamp);
            end

            % ディレクトリ作成
            [filepath, ~, ~] = fileparts(filename);
            if ~exist(filepath, 'dir')
                mkdir(filepath);
            end

            % 保存
            config = obj; %#ok<NASGU>
            save(filename, 'config');
            fprintf('💾 設定を保存しました: %s\n', filename);
        end
    end

    methods (Static)
        function config = load_from_file(filename)
            % ファイルから設定を読み込み
            %
            % Parameters:
            %   filename - 読み込むファイル名
            %
            % Returns:
            %   config - ExperimentConfigインスタンス

            if ~exist(filename, 'file')
                error('ExperimentConfig:FileNotFound', 'ファイルが見つかりません: %s', filename);
            end

            loaded = load(filename);
            config = loaded.config;
            fprintf('📂 設定を読み込みました: %s\n', filename);
        end
    end
end

function result = iif(condition, true_val, false_val)
    % 三項演算子のヘルパー関数
    if condition
        result = true_val;
    else
        result = false_val;
    end
end
