classdef AudioSystem < handle
    % AudioSystem - PsychPortAudio統合管理クラス
    %
    % このクラスは全実験タイプで共通の音声システムを提供します
    % - Scarlett 4i4オーディオインターフェース管理
    % - 4チャンネル音声バッファ作成
    % - 低遅延音声再生

    properties (Access = public)
        pahandle        % PsychPortAudioハンドル
        fs              % サンプリングレート
        device_id       % デバイスID
        device_name     % デバイス名
        latency         % 予測遅延（秒）
        num_channels    % 出力チャンネル数
    end

    properties (Access = private)
        is_initialized = false
    end

    methods
        function obj = AudioSystem(varargin)
            % AudioSystem コンストラクタ
            %
            % Usage:
            %   audio = AudioSystem()              % デフォルト（4チャンネル）
            %   audio = AudioSystem('channels', 2) % 2チャンネル指定

            % デフォルト設定
            p = inputParser;
            addParameter(p, 'channels', 4, @isnumeric);
            addParameter(p, 'latency_class', 2, @isnumeric);
            parse(p, varargin{:});

            obj.num_channels = p.Results.channels;

            % PsychPortAudio初期化
            obj.initialize_psychportaudio(p.Results.latency_class);
        end

        function initialize_psychportaudio(obj, latency_class)
            % PsychPortAudio初期化

            try
                % PsychPortAudio初期化
                InitializePsychSound(1);

                % デバイス検索
                devices = PsychPortAudio('GetDevices');

                % Scarlett 4i4を優先的に検索
                obj.device_id = [];
                for i = 1:length(devices)
                    if devices(i).NrOutputChannels >= obj.num_channels
                        device_name = devices(i).DeviceName;
                        if contains(lower(device_name), 'scarlett') || contains(lower(device_name), '4i4')
                            obj.device_id = devices(i).DeviceIndex;
                            obj.device_name = device_name;
                            fprintf('✅ Scarlett 4i4検出: %s (DeviceIndex=%d, %dチャンネル)\n', ...
                                device_name, obj.device_id, devices(i).NrOutputChannels);
                            break;
                        end
                    end
                end

                % Scarlettが見つからない場合は最初の利用可能なデバイス
                if isempty(obj.device_id)
                    for i = 1:length(devices)
                        if devices(i).NrOutputChannels >= obj.num_channels
                            obj.device_id = devices(i).DeviceIndex;
                            obj.device_name = devices(i).DeviceName;
                            fprintf('⚠️  Scarlett未検出。代替デバイス使用: %s\n', obj.device_name);
                            break;
                        end
                    end
                end

                if isempty(obj.device_id)
                    error('AudioSystem:NoDevice', '%dチャンネル対応デバイスが見つかりません', obj.num_channels);
                end

                % サンプリングレート設定（22.05kHz - 低遅延用）
                obj.fs = 22050;

                % PsychPortAudioデバイスオープン
                % mode=1: 再生のみ, reqlatencyclass: 低遅延モード
                obj.pahandle = PsychPortAudio('Open', obj.device_id, 1, latency_class, obj.fs, obj.num_channels);

                % 遅延情報取得
                status = PsychPortAudio('GetStatus', obj.pahandle);
                obj.latency = status.PredictedLatency;

                fprintf('✅ PsychPortAudio初期化完了:\n');
                fprintf('   サンプリング周波数: %d Hz\n', obj.fs);
                fprintf('   出力チャンネル数: %d\n', obj.num_channels);
                fprintf('   出力遅延: %.3f ms\n', obj.latency * 1000);

                obj.is_initialized = true;

            catch ME
                error('AudioSystem:InitFailed', 'PsychPortAudio初期化エラー: %s', ME.message);
            end
        end

        function sound_data = load_sound_file(obj, filepath)
            % 音声ファイルを読み込み、モノラル化
            %
            % Usage:
            %   sound = audio.load_sound_file('path/to/sound.wav')

            if ~exist(filepath, 'file')
                error('AudioSystem:FileNotFound', '音声ファイルが見つかりません: %s', filepath);
            end

            [sound_data, fs_file] = audioread(filepath);

            % モノラル化
            if size(sound_data, 2) > 1
                sound_data = mean(sound_data, 2);
            end

            % サンプリングレート確認
            if fs_file ~= obj.fs
                warning('AudioSystem:SampleRateMismatch', ...
                    'ファイルのサンプリングレート(%d Hz)がシステム(%d Hz)と異なります。リサンプリング推奨。', ...
                    fs_file, obj.fs);
            end
        end

        function buffer = create_buffer(obj, sound_data, channel_mask)
            % 4チャンネルバッファを作成
            %
            % Parameters:
            %   sound_data - モノラル音声データ（列ベクトル）
            %   channel_mask - チャンネルマスク [Ch1, Ch2, Ch3, Ch4]
            %                  例: [1,1,0,0] = 出力1/2のみ
            %                      [0,0,1,1] = 出力3/4のみ
            %                      [1,1,1,1] = 全チャンネル
            %
            % Returns:
            %   buffer - PsychPortAudioバッファID

            if ~obj.is_initialized
                error('AudioSystem:NotInitialized', 'AudioSystemが初期化されていません');
            end

            if length(channel_mask) ~= obj.num_channels
                error('AudioSystem:InvalidMask', 'チャンネルマスク長が不正です');
            end

            % 4チャンネルデータ作成
            multi_ch = zeros(length(sound_data), obj.num_channels);
            for ch = 1:obj.num_channels
                if channel_mask(ch) == 1
                    multi_ch(:, ch) = sound_data;
                end
            end

            % 転置（PsychPortAudioは [channels x samples]）
            multi_ch = multi_ch';

            % バッファ作成
            buffer = PsychPortAudio('CreateBuffer', obj.pahandle, multi_ch);
        end

        function play_buffer(obj, buffer, wait)
            % バッファを再生
            %
            % Parameters:
            %   buffer - PsychPortAudioバッファID
            %   wait - 再生完了まで待機するか（デフォルト: false）

            if nargin < 3
                wait = 0;  % デフォルト: 待機しない
            else
                % boolean型を数値型に変換（PsychPortAudio要件）
                wait = double(wait);
            end

            PsychPortAudio('FillBuffer', obj.pahandle, buffer);
            PsychPortAudio('Start', obj.pahandle, 1, 0, wait);
        end

        function close(obj)
            % PsychPortAudioクリーンアップ

            if obj.is_initialized && ~isempty(obj.pahandle)
                try
                    PsychPortAudio('Close', obj.pahandle);
                    fprintf('✅ AudioSystemクローズ完了\n');
                catch
                    warning('AudioSystem:CloseWarning', 'AudioSystemクローズ時に警告');
                end
                obj.is_initialized = false;
            end
        end

        function delete(obj)
            % デストラクタ
            obj.close();
        end
    end
end
