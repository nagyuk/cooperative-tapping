#!/bin/bash
# 協調タッピング実験実行スクリプト
# WAVファイルを使用する実装に対応しています

# ファイルの存在確認
if [ ! -f "assets/sounds/button02a.wav" ] || [ ! -f "assets/sounds/button03a.wav" ]; then
    echo "エラー: 必要なWAVファイルが見つかりません"
    echo "以下のファイルが必要です："
    echo "  - assets/sounds/button02a.wav"
    echo "  - assets/sounds/button03a.wav"
    exit 1
fi

# 仮想環境の存在確認と有効化
if [ ! -d "venv_py39" ]; then
    echo "警告: 仮想環境(venv_py39)が見つかりません"
    echo "システムのPythonを使用します"
    PYTHON="python3"
else
    echo "仮想環境を有効化します"
    source venv_py39/bin/activate
    PYTHON="python3"
fi

# 実験の実行（引数を渡す）
echo "実験を開始します..."
$PYTHON scripts/run_experiment.py "$@"

# 終了メッセージ
echo "実験が終了しました"
