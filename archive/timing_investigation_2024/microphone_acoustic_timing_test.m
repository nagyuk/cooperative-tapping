% マイクを使った実音響タイミング測定システム
% 真の6n+1遅延問題の検証

function microphone_acoustic_timing_test()
    fprintf('=== マイク実音響タイミング測定 ===\n');

    try
        % Step1: 音声出力・入力システムのセットアップ
        setup_audio_system();

        % Step2: 実音響測定の実行
        perform_acoustic_measurement();

    catch ME
        fprintf('ERROR: %s\n', ME.message);
        fprintf('マイクアクセス権限を確認してください\n');
    end
end

function setup_audio_system()
    fprintf('\n--- Step1: 音声システムセットアップ ---\n');

    % 音声デバイス情報取得
    try
        input_devices = audiodevinfo(0);  % 入力デバイス
        output_devices = audiodevinfo(1); % 出力デバイス

        fprintf('入力デバイス: %d個\n', length(input_devices));
        fprintf('出力デバイス: %d個\n', length(output_devices));

        % デフォルトデバイス確認
        default_input = audiodevinfo(0);
        default_output = audiodevinfo(1);

        fprintf('デフォルト入力: ID %d\n', default_input);
        fprintf('デフォルト出力: ID %d\n', default_output);

    catch ME
        fprintf('デバイス情報取得エラー: %s\n', ME.message);
    end
end

function perform_acoustic_measurement()
    fprintf('\n--- Step2: 実音響測定 ---\n');

    % 録音パラメータ
    fs = 44100;  % サンプリング周波数
    duration = 15; % 録音時間（15秒）

    % 実験用音声ファイル読み込み
    stim_sound_path = fullfile(pwd, 'assets', 'sounds', 'stim_beat_optimized.wav');
    player_sound_path = fullfile(pwd, 'assets', 'sounds', 'player_beat_optimized.wav');

    [sound_stim, fs_stim] = audioread(stim_sound_path);
    [sound_player, fs_player] = audioread(player_sound_path);

    fprintf('実験用音声読み込み完了\n');
    fprintf('これから%d秒間の同時録音・再生を開始します\n', duration);
    fprintf('録音中は静かにしてください...\n');

    % 録音開始の準備
    recorder = audiorecorder(fs, 16, 1); % 44.1kHz, 16bit, モノラル

    % カウントダウン
    for i = 3:-1:1
        fprintf('%d...\n', i);
        pause(1);
    end

    fprintf('録音開始！\n');

    % 録音開始
    record(recorder);

    % 記録用配列
    sound_times = [];
    sound_types = {};

    start_time = posixtime(datetime('now'));

    % Stage1パターンの再現（15秒間で10音）
    num_sounds = 10;

    for sound_index = 1:num_sounds
        % 目標時刻（0.5秒オフセット）
        target_time = (sound_index - 1) * 1.4 + 0.5; % 1.4秒間隔で見やすく

        % 目標時刻まで待機
        while (posixtime(datetime('now')) - start_time) < target_time
            pause(0.001);
        end

        % 音声再生タイミング記録
        actual_time = posixtime(datetime('now')) - start_time;
        sound_times(end+1) = actual_time;

        % 音声再生
        if mod(sound_index, 2) == 1
            % 刺激音
            sound(sound_stim(:,1), fs_stim);
            sound_types{end+1} = '刺激音';

            % 6n+1パターンの特別マーキング
            if mod(sound_index, 6) == 1
                marker = ' ← 6n+1パターン！';
            else
                marker = '';
            end

        else
            % プレイヤー音
            sound(sound_player(:,1), fs_player);
            sound_types{end+1} = 'プレイヤー音';
            marker = '';
        end

        fprintf('音%d: %s (%.3fs地点)%s\n', sound_index, sound_types{end}, actual_time, marker);
    end

    % 録音終了待機
    pause(1.0);

    % 録音停止
    stop(recorder);

    % 録音データ取得
    audio_data = getaudiodata(recorder);

    fprintf('録音完了！音響解析を開始します...\n');

    % 音響解析実行
    analyze_acoustic_data(audio_data, fs, sound_times, sound_types);
end

function analyze_acoustic_data(audio_data, fs, planned_times, sound_types)
    fprintf('\n--- Step3: 音響解析 ---\n');

    % 音響信号の解析
    % 1. 音量レベルの計算（より細かい解析）
    window_size = round(0.02 * fs); % 20ms窓（短縮）
    hop_size = round(0.005 * fs);   % 5ms間隔（高密度）

    energy = [];
    time_axis = [];

    for i = 1:hop_size:(length(audio_data) - window_size)
        window = audio_data(i:i+window_size-1);
        energy(end+1) = sum(window.^2);
        time_axis(end+1) = i / fs;
    end

    % エネルギー分布の分析
    energy_sorted = sort(energy, 'descend');
    background_level = median(energy); % バックグラウンドレベル
    max_energy = max(energy);

    fprintf('エネルギー分析:\n');
    fprintf('  最大エネルギー: %.6f\n', max_energy);
    fprintf('  バックグラウンド: %.6f\n', background_level);
    fprintf('  動的レンジ: %.1fdB\n', 10*log10(max_energy/background_level));

    % 2. 改善された音響イベント検出
    % より厳格な閾値設定（最大の50%以上）
    threshold = max_energy * 0.5;

    % 最小間隔設定（1秒以上の間隔でイベント検出）
    min_interval = 0.8; % 最小0.8秒間隔

    detected_events = [];
    last_detection = -min_interval; % 初回検出用

    % 改善されたピーク検出アルゴリズム
    for i = 10:(length(energy)-10) % 端点を避ける
        if energy(i) > threshold
            % 周囲10点での最大値チェック
            local_max = true;
            for j = (i-5):(i+5)
                if j ~= i && energy(j) >= energy(i)
                    local_max = false;
                    break;
                end
            end

            % 最小間隔チェック
            if local_max && (time_axis(i) - last_detection) >= min_interval
                detected_events(end+1) = time_axis(i);
                last_detection = time_axis(i);
                fprintf('音響イベント検出: %.3fs地点, エネルギー=%.6f\n', time_axis(i), energy(i));
            end
        end
    end

    fprintf('検出された音響イベント: %d個\n', length(detected_events));
    fprintf('計画された音再生: %d個\n', length(planned_times));

    % 3. 計画vs実測の比較（改善版）
    fprintf('\n=== 計画時刻 vs 実音響検出 ===\n');

    if length(detected_events) ~= length(planned_times)
        fprintf('警告: 検出数不一致 (検出%d個 vs 計画%d個)\n', ...
            length(detected_events), length(planned_times));

        % 部分的マッチング：最初の共通部分のみ分析
        common_count = min(length(detected_events), length(planned_times));
        fprintf('最初の%d個で分析を実行\n', common_count);
    else
        common_count = length(planned_times);
        fprintf('完全一致: %d個のイベントで分析\n', common_count);
    end

    detected_intervals = [];
    planned_intervals = [];

    for i = 1:common_count
        delay = detected_events(i) - planned_times(i);

        % 6n+1パターンのマーキング
        if mod(i, 6) == 1 && mod(i, 2) == 1
            pattern_marker = ' ← ★6n+1刺激音';
        else
            pattern_marker = '';
        end

        fprintf('音%d: 計画%.3fs vs 検出%.3fs, 遅延%+.1fms (%s)%s\n', ...
            i, planned_times(i), detected_events(i), delay*1000, sound_types{i}, pattern_marker);

        % 間隔計算
        if i > 1
            detected_interval = detected_events(i) - detected_events(i-1);
            planned_interval = planned_times(i) - planned_times(i-1);

            detected_intervals(end+1) = detected_interval;
            planned_intervals(end+1) = planned_interval;

            interval_error = detected_interval - planned_interval;

            % 6n+1前間隔の特別マーキング
            if mod(i, 6) == 1 && mod(i, 2) == 1
                interval_marker = ' ← ★6n+1前間隔';
            else
                interval_marker = '';
            end

            fprintf('   間隔%d: 計画%.3fs vs 実測%.3fs, 誤差%+.1fms%s\n', ...
                i-1, planned_interval, detected_interval, interval_error*1000, interval_marker);
        end
    end

    % 4. 統計分析
    if ~isempty(detected_intervals)
        fprintf('\n音響測定統計:\n');
        fprintf('平均間隔: %.3fs (計画%.3fs)\n', mean(detected_intervals), mean(planned_intervals));
        fprintf('標準偏差: %.3fs\n', std(detected_intervals));
        fprintf('最大誤差: %.1fms\n', max(abs(detected_intervals - planned_intervals)) * 1000);

        % 6n+1パターンの特別分析（改善版）
        pattern_6n1_indices = [];
        for i = 1:common_count
            if mod(i, 6) == 1 && mod(i, 2) == 1 % 6n+1刺激音
                if i > 1 && (i-1) <= length(detected_intervals)
                    pattern_6n1_indices(end+1) = i-1; % 間隔のインデックス
                end
            end
        end

        fprintf('\n=== 6n+1パターン解析 ===\n');
        fprintf('6n+1刺激音の位置: ');
        for i = 1:common_count
            if mod(i, 6) == 1 && mod(i, 2) == 1
                fprintf('音%d ', i);
            end
        end
        fprintf('\n');

        if ~isempty(pattern_6n1_indices) && max(pattern_6n1_indices) <= length(detected_intervals)
            pattern_intervals = detected_intervals(pattern_6n1_indices);
            other_intervals = detected_intervals;
            other_intervals(pattern_6n1_indices) = [];

            fprintf('6n+1前間隔（注目！）: %.3f±%.3fs (%d個)\n', ...
                mean(pattern_intervals), std(pattern_intervals), length(pattern_intervals));

            if ~isempty(other_intervals)
                fprintf('その他の間隔: %.3f±%.3fs (%d個)\n', ...
                    mean(other_intervals), std(other_intervals), length(other_intervals));

                difference = mean(pattern_intervals) - mean(other_intervals);
                fprintf('★重要★ 差分: %+.1fms (6n+1の方が%s)\n', ...
                    difference*1000, iif(difference > 0, '長い', '短い'));

                % 統計的有意性の簡易チェック
                if abs(difference) > 0.05 % 50ms以上の差
                    fprintf('→ 50ms以上の差: 明確な6n+1遅延パターン検出！\n');
                elseif abs(difference) > 0.02 % 20ms以上の差
                    fprintf('→ 20ms以上の差: 軽微な6n+1パターン\n');
                else
                    fprintf('→ 差分小: 6n+1パターンなし\n');
                end
            else
                fprintf('比較対象なし（6n+1間隔のみ）\n');
            end
        else
            fprintf('6n+1パターンデータ不足\n');
        end
    end

    % 5. 保存
    save('acoustic_measurement_data.mat', 'audio_data', 'fs', 'planned_times', ...
         'detected_events', 'sound_types', 'energy', 'time_axis');

    fprintf('\n測定データを acoustic_measurement_data.mat に保存しました\n');
    fprintf('=== 音響測定完了 ===\n');
end

function result = iif(condition, true_val, false_val)
    if condition
        result = true_val;
    else
        result = false_val;
    end
end