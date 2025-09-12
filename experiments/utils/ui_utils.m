function fig = create_experiment_input_window()
    % 実験用入力ウィンドウ作成
    %
    % Output:
    %   fig - 作成されたfigureハンドル
    
    fig = figure('Name', 'Cooperative Tapping', 'NumberTitle', 'off', ...
        'MenuBar', 'none', 'ToolBar', 'none', ...
        'Position', [100, 100, 500, 300], ...
        'KeyPressFcn', @experiment_key_press_handler, ...
        'CloseRequestFcn', @experiment_window_close_handler, ...
        'Color', [0.2, 0.2, 0.2]);
    
    % 表示テキスト
    axes('Position', [0, 0, 1, 1], 'Visible', 'off');
    text(0.5, 0.7, '協調タッピング実験', 'HorizontalAlignment', 'center', ...
        'FontSize', 16, 'Color', 'white', 'FontWeight', 'bold');
    text(0.5, 0.5, 'スペースキー: タップ', 'HorizontalAlignment', 'center', ...
        'FontSize', 12, 'Color', 'white');
    text(0.5, 0.3, 'Escapeキー: 実験中止', 'HorizontalAlignment', 'center', ...
        'FontSize', 12, 'Color', 'white');
    
    figure(fig);
end

function experiment_key_press_handler(~, event)
    % キープレス処理
    assignin('base', 'last_key_press', event.Key);
    assignin('base', 'last_key_time', posixtime(datetime('now')));
end

function experiment_window_close_handler(~, ~)
    % ウィンドウクローズ処理
    assignin('base', 'experiment_running', false);
end