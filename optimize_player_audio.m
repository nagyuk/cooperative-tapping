% プレイヤータップ音の最適化版作成
% stim_beat_optimized.wavと同じ最適化を適用

function optimize_player_audio()
    fprintf('=== プレイヤータップ音最適化 ===\n');

    % 元のプレイヤー音ファイル
    original_path = fullfile(pwd, 'assets', 'sounds', 'player_beat.wav');
    optimized_path = fullfile(pwd, 'assets', 'sounds', 'player_beat_optimized.wav');

    if ~exist(original_path, 'file')
        fprintf('❌ 元ファイルが見つかりません: %s\n', original_path);
        fprintf('デフォルト音を生成します...\n');

        % デフォルトプレイヤー音生成
        fs = 22050; % 最適化サンプリング周波数
        duration = 0.2; % 200ms
        t = 0:1/fs:duration-1/fs;

        % エンベロープ付き音
        envelope = exp(-t*10); % 緩やかな減衰
        player_sound = 0.4 * envelope' .* sin(2*pi*900*t)'; % 900Hz

        % 最適化音声保存
        audiowrite(optimized_path, player_sound, fs, 'BitsPerSample', 16);

        fprintf('✅ デフォルトプレイヤー音を最適化版として保存\n');
        fprintf('   周波数: 900Hz\n');
        fprintf('   長さ: %.1fms\n', duration * 1000);
        fprintf('   サンプリング: %dHz\n', fs);

    else
        % 既存ファイルを最適化
        [original_audio, fs_orig] = audioread(original_path);

        fprintf('元ファイル情報:\n');
        fprintf('  サイズ: %.1fKB\n', file_size_kb(original_path));
        fprintf('  長さ: %.3fs\n', length(original_audio)/fs_orig);
        fprintf('  チャンネル: %d\n', size(original_audio, 2));
        fprintf('  サンプリング: %dHz\n', fs_orig);

        % 最適化処理
        optimized_audio = original_audio;
        fs_opt = fs_orig;

        % ステレオ→モノラル変換
        if size(optimized_audio, 2) > 1
            optimized_audio = mean(optimized_audio, 2);
            fprintf('✅ ステレオ→モノラル変換\n');
        end

        % ダウンサンプリング（44.1kHz → 22.05kHz）
        if fs_opt > 22050
            optimized_audio = resample(optimized_audio, 22050, fs_opt);
            fs_opt = 22050;
            fprintf('✅ %dHz → %dHz ダウンサンプリング\n', fs_orig, fs_opt);
        end

        % 正規化
        max_val = max(abs(optimized_audio));
        if max_val > 0
            optimized_audio = optimized_audio / max_val * 0.4; % 40%音量
            fprintf('✅ 音量正規化 (40%%)\n');
        end

        % 最適化版保存
        audiowrite(optimized_path, optimized_audio, fs_opt, 'BitsPerSample', 16);

        fprintf('\n最適化完了:\n');
        fprintf('  元サイズ: %.1fKB → 最適化後: %.1fKB\n', ...
            file_size_kb(original_path), file_size_kb(optimized_path));
        fprintf('  削減率: %.1f%%\n', ...
            (1 - file_size_kb(optimized_path)/file_size_kb(original_path)) * 100);
    end

    % 最適化版テスト
    test_optimized_audio(optimized_path);
end

function size_kb = file_size_kb(filepath)
    info = dir(filepath);
    size_kb = info.bytes / 1024;
end

function test_optimized_audio(filepath)
    fprintf('\n--- 最適化版音声テスト ---\n');

    try
        [audio_data, fs] = audioread(filepath);

        fprintf('最適化版情報:\n');
        fprintf('  ファイル: %s\n', filepath);
        fprintf('  サイズ: %.1fKB\n', file_size_kb(filepath));
        fprintf('  長さ: %.3fs\n', length(audio_data)/fs);
        fprintf('  サンプリング: %dHz\n', fs);
        fprintf('  チャンネル: %d\n', size(audio_data, 2));

        % 再生テスト
        fprintf('\n再生テスト中...\n');
        player = audioplayer(audio_data, fs);
        play(player);
        pause(length(audio_data)/fs + 0.1);

        fprintf('✅ 最適化版音声テスト完了\n');

    catch ME
        fprintf('❌ テストエラー: %s\n', ME.message);
    end
end