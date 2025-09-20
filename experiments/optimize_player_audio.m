function optimize_player_audio()
    % プレイヤー音の最適化版を作成（刺激音と同様の最適化）

    fprintf('=== プレイヤー音最適化処理開始 ===\n');

    % 元ファイルパス
    input_file = '../assets/sounds/player_beat.wav';
    output_file = '../assets/sounds/player_beat_optimized.wav';

    if ~exist(input_file, 'file')
        error('元ファイルが見つかりません: %s', input_file);
    end

    % 音声読み込み
    [y, fs] = audioread(input_file);
    fprintf('元ファイル読み込み完了: %s\n', input_file);
    fprintf('  - サンプルレート: %d Hz\n', fs);
    fprintf('  - チャンネル数: %d\n', size(y, 2));
    fprintf('  - 長さ: %.3f秒\n', length(y) / fs);
    fprintf('  - ファイルサイズ: %.1f KB\n', dir(input_file).bytes / 1024);

    % 最適化処理（刺激音と同じ処理）

    % 1. モノラル変換（ステレオの場合）
    if size(y, 2) > 1
        y_mono = mean(y, 2);
        fprintf('ステレオ→モノラル変換完了\n');
    else
        y_mono = y;
        fprintf('既にモノラルです\n');
    end

    % 2. ダウンサンプリング（44.1kHz → 22.05kHz）
    if fs > 22050
        target_fs = 22050;
        y_resampled = resample(y_mono, target_fs, fs);
        fs_optimized = target_fs;
        fprintf('ダウンサンプリング: %d Hz → %d Hz\n', fs, fs_optimized);
    else
        y_resampled = y_mono;
        fs_optimized = fs;
        fprintf('サンプルレートはそのまま: %d Hz\n', fs_optimized);
    end

    % 3. 音量正規化
    y_normalized = y_resampled / max(abs(y_resampled));
    fprintf('音量正規化完了\n');

    % 4. 最適化ファイル保存
    audiowrite(output_file, y_normalized, fs_optimized);

    % 結果検証
    output_info = dir(output_file);
    [y_verify, fs_verify] = audioread(output_file);

    fprintf('\n=== 最適化結果 ===\n');
    fprintf('出力ファイル: %s\n', output_file);
    fprintf('  - サンプルレート: %d Hz\n', fs_verify);
    fprintf('  - チャンネル数: %d\n', size(y_verify, 2));
    fprintf('  - 長さ: %.3f秒\n', length(y_verify) / fs_verify);
    fprintf('  - ファイルサイズ: %.1f KB\n', output_info.bytes / 1024);

    % 最適化効果
    original_size = dir(input_file).bytes / 1024;
    optimized_size = output_info.bytes / 1024;
    size_reduction = (1 - optimized_size/original_size) * 100;

    fprintf('\n=== 最適化効果 ===\n');
    fprintf('ファイルサイズ削減: %.1f%% (%.1fKB → %.1fKB)\n', ...
        size_reduction, original_size, optimized_size);

    if fs > fs_verify
        fprintf('サンプルレート削減: %.1f%% (%dHz → %dHz)\n', ...
            (1 - fs_verify/fs) * 100, fs, fs_verify);
    end

    fprintf('\nプレイヤー音最適化完了！\n');
    fprintf('実験スクリプトで %s を使用してください\n', output_file);
end