% 相対間隔に特化した音響測定システム
% 時計同期問題を回避して6n+1パターンを検証

function relative_interval_acoustic_test(manual_threshold)
    fprintf('=== 相対間隔音響測定 ===\n');
    fprintf('時計同期問題を回避し、音響間隔のみに注目\n\n');

    if nargin < 1
        manual_threshold = -1; % 自動閾値
    end

    try
        % 音声ファイル読み込み
        stim_sound_path = fullfile(pwd, 'assets', 'sounds', 'stim_beat_optimized.wav');
        player_sound_path = fullfile(pwd, 'assets', 'sounds', 'player_beat_optimized.wav');

        [sound_stim, fs_stim] = audioread(stim_sound_path);
        [sound_player, fs_player] = audioread(player_sound_path);

        fprintf('音声ファイル読み込み完了\n');

        % Stage1パターンの再現（12音で3回の6n+1パターン）
        perform_relative_measurement(sound_stim, fs_stim, sound_player, fs_player, manual_threshold);

    catch ME
        fprintf('ERROR: %s\n', ME.message);
    end
end

function perform_relative_measurement(sound_stim, fs_stim, sound_player, fs_player, manual_threshold)
    fprintf('\n--- 相対間隔測定開始 ---\n');

    % 録音設定
    fs = 44100;
    duration = 15; % 15秒録音（12音×1.0秒間隔+余裕）

    fprintf('これから%d秒間の録音・再生を開始します\n', duration);
    fprintf('12音を1.0秒間隔で再生します（main_experimentのStage1と同じ）\n');

    % 録音準備
    recorder = audiorecorder(fs, 16, 1);

    % カウントダウン
    for i = 3:-1:1
        fprintf('%d...\n', i);
        pause(1);
    end

    fprintf('録音開始！\n');
    record(recorder);

    start_time = posixtime(datetime('now'));
    num_sounds = 12;

    % main_experimentと同じStage1パターン
    for sound_index = 1:num_sounds
        % main_experimentと同じ絶対時刻スケジューリング
        % 0.5, 1.5, 2.5, 3.5, 4.5...秒（1.0秒間隔）
        target_time = (sound_index - 1) * 1.0 + 0.5;

        % main_experimentと同じ待機システム
        while (posixtime(datetime('now')) - start_time) < target_time
            pause(0.001); % 1ms間隔の安定した待機
        end

        % 音声再生
        if mod(sound_index, 2) == 1
            sound(sound_stim(:,1), fs_stim);
            sound_type = '刺激音';
        else
            sound(sound_player(:,1), fs_player);
            sound_type = 'プレイヤー音';
        end

        % 6n+1パターンのマーキング
        if mod(sound_index, 6) == 1 && mod(sound_index, 2) == 1
            pattern_marker = ' ← ★6n+1刺激音';
        else
            pattern_marker = '';
        end

        fprintf('音%d: %s%s\n', sound_index, sound_type, pattern_marker);
    end

    % 録音終了
    pause(1.0);
    stop(recorder);
    audio_data = getaudiodata(recorder);

    fprintf('録音完了！相対間隔解析を開始...\n');

    % 相対間隔解析
    analyze_relative_intervals(audio_data, fs, manual_threshold);
end

function analyze_relative_intervals(audio_data, fs, manual_threshold)
    fprintf('\n--- 相対間隔解析 ---\n');

    % エネルギー解析
    window_size = round(0.02 * fs);
    hop_size = round(0.005 * fs);

    energy = [];
    time_axis = [];

    for i = 1:hop_size:(length(audio_data) - window_size)
        window = audio_data(i:i+window_size-1);
        energy(end+1) = sum(window.^2);
        time_axis(end+1) = i / fs;
    end

    % 最適化された音響イベント検出
    max_energy = max(energy);
    background_level = median(energy);

    fprintf('エネルギー解析:\n');
    fprintf('  最大エネルギー: %.6f\n', max_energy);
    fprintf('  バックグラウンド: %.6f\n', background_level);
    fprintf('  動的レンジ: %.1fdB\n', 10*log10(max_energy/background_level));

    % 閾値設定（手動 or 自動）
    if manual_threshold > 0
        threshold = max_energy * manual_threshold;
        fprintf('  手動閾値: %.6f (最大の%.0f%%)\n', threshold, manual_threshold*100);
    else
        % 適応的閾値設定（バックグラウンドレベルベース）
        dynamic_range = max_energy / background_level;
        if dynamic_range > 100  % 高動的レンジ（40dB以上）
            threshold_factor = 0.15;  % 15%
        elseif dynamic_range > 10   % 中動的レンジ（10dB以上）
            threshold_factor = 0.25;  % 25%
        else                        % 低動的レンジ
            threshold_factor = 0.4;   % 40%
        end

        threshold = max_energy * threshold_factor;
        fprintf('  自動閾値: %.6f (最大の%.0f%%)\n', threshold, threshold_factor*100);
    end

    % より柔軟な間隔設定
    min_interval = 0.6;  % 0.8秒から0.6秒に緩和

    detected_events = [];
    last_detection = -min_interval;

    % 改良されたピーク検出
    for i = 5:(length(energy)-5)  % 端点制限を緩和
        if energy(i) > threshold
            % 局所最大値チェック（より小さい窓）
            local_max = true;
            for j = (i-3):(i+3)  % 10点から6点に縮小
                if j ~= i && energy(j) >= energy(i)
                    local_max = false;
                    break;
                end
            end

            if local_max && (time_axis(i) - last_detection) >= min_interval
                detected_events(end+1) = time_axis(i);
                last_detection = time_axis(i);
                fprintf('検出: %.3fs地点, エネルギー=%.6f\n', time_axis(i), energy(i));
            end
        end
    end

    fprintf('検出された音響イベント: %d個\n', length(detected_events));

    % 検出診断
    if length(detected_events) < 10
        fprintf('警告: 検出数不足 (%d/12個)\n', length(detected_events));
        fprintf('閾値を下げて再試行することを推奨\n');
    elseif length(detected_events) > 12
        fprintf('警告: 検出過多 (%d個) - ノイズ混入の可能性\n', length(detected_events));
    else
        fprintf('良好: 適切な検出数 (%d個)\n', length(detected_events));
    end

    % 相対間隔の計算
    if length(detected_events) >= 2
        intervals = [];
        for i = 2:length(detected_events)
            interval = detected_events(i) - detected_events(i-1);
            intervals(end+1) = interval;
            fprintf('間隔%d: %.3fs\n', i-1, interval);
        end

        % 6n+1パターンの分析（間隔ベース）
        analyze_6n1_pattern_from_intervals(intervals);

        % 統計
        fprintf('\n間隔統計:\n');
        fprintf('平均間隔: %.3fs\n', mean(intervals));
        fprintf('標準偏差: %.3fs (%.1fms)\n', std(intervals), std(intervals)*1000);
        fprintf('最小間隔: %.3fs\n', min(intervals));
        fprintf('最大間隔: %.3fs\n', max(intervals));

        % 不規則性の検出
        irregular_indices = find(abs(intervals - mean(intervals)) > 2*std(intervals));
        if ~isempty(irregular_indices)
            fprintf('\n不規則な間隔（2σ超え）:\n');
            for idx = irregular_indices
                fprintf('  間隔%d: %.3fs (平均から%.1fms逸脱)\n', ...
                    idx, intervals(idx), (intervals(idx) - mean(intervals))*1000);
            end
        end

    else
        fprintf('検出されたイベントが不足（%d個）\n', length(detected_events));
    end

    % データ保存
    save('relative_interval_data.mat', 'audio_data', 'fs', 'detected_events', 'intervals');
    fprintf('\n測定データを relative_interval_data.mat に保存\n');
end

function analyze_6n1_pattern_from_intervals(intervals)
    fprintf('\n=== 6n+1パターン解析（相対間隔ベース）===\n');

    if length(intervals) < 6
        fprintf('間隔データ不足（%d個）\n', length(intervals));
        return;
    end

    % 音のインデックスから間隔のパターンを特定
    % 音1→音2, 音2→音3, ..., 音6→音7, 音7→音8, ...
    % 6n+1刺激音は音1, 音7, 音13...
    % 6n+1前の間隔は間隔6, 間隔12... (音6→音7, 音12→音13)

    pattern_6n1_intervals = [];
    other_intervals = [];

    for i = 1:length(intervals)
        % 間隔iは音i→音(i+1)
        % 音(i+1)が6n+1刺激音かチェック
        sound_index = i + 1; % 間隔iの終点の音番号

        if mod(sound_index, 6) == 1 && mod(sound_index, 2) == 1
            % 6n+1刺激音への間隔
            pattern_6n1_intervals(end+1) = intervals(i);
            fprintf('間隔%d→音%d: %.3fs ← ★6n+1前間隔\n', i, sound_index, intervals(i));
        else
            other_intervals(end+1) = intervals(i);
            fprintf('間隔%d→音%d: %.3fs\n', i, sound_index, intervals(i));
        end
    end

    % 比較分析
    if ~isempty(pattern_6n1_intervals) && ~isempty(other_intervals)
        fprintf('\n★相対間隔分析結果★\n');
        fprintf('6n+1前間隔: %.3f±%.3fs (%d個)\n', ...
            mean(pattern_6n1_intervals), std(pattern_6n1_intervals), length(pattern_6n1_intervals));
        fprintf('その他間隔: %.3f±%.3fs (%d個)\n', ...
            mean(other_intervals), std(other_intervals), length(other_intervals));

        difference = mean(pattern_6n1_intervals) - mean(other_intervals);
        fprintf('★差分: %+.1fms (6n+1の方が%s)\n', ...
            difference*1000, iif(difference > 0, '長い', '短い'));

        % 有意性判定
        if abs(difference) > 0.05 % 50ms以上
            fprintf('→ 明確な6n+1遅延パターン！\n');
        elseif abs(difference) > 0.02 % 20ms以上
            fprintf('→ 軽微な6n+1パターン\n');
        else
            fprintf('→ 6n+1パターンなし\n');
        end

    elseif isempty(pattern_6n1_intervals)
        fprintf('6n+1前間隔データなし\n');
    else
        fprintf('比較対象間隔データなし\n');
    end
end

function result = iif(condition, true_val, false_val)
    if condition
        result = true_val;
    else
        result = false_val;
    end
end