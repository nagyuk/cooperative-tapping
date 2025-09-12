function keys = get_all_recent_keys()
    % 最近のキー入力を取得
    %
    % Output:
    %   keys - 押されたキーのセル配列
    
    keys = {};
    
    % キーボード状態をチェック
    try
        if evalin('base', 'exist(''last_key_press'', ''var'')')
            last_key = evalin('base', 'last_key_press');
            if ~isempty(last_key)
                keys{end+1} = last_key;
                % キーをクリア
                assignin('base', 'last_key_press', '');
            end
        end
    catch
        % エラーが発生した場合は空を返す
    end
end

function wait_for_space_key()
    % スペースキーが押されるまで待機
    
    fprintf('準備ができたらSpaceキーを押してください\n');
    
    while true
        keys = get_all_recent_keys();
        if any(strcmp(keys, 'space'))
            break;
        elseif any(strcmp(keys, 'escape'))
            error('実験が中止されました');
        end
        pause(0.05);
    end
    
    fprintf('開始! メトロノームのリズムに交互にタップしてください\n');
end