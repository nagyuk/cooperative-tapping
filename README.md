# Cooperative Tapping Task

このプロジェクトは、人間と機械間の協調交互タッピング課題を実装したソフトウェアです。
3種類の異なるモデルを実装しています：

- SEA (Synchronization Error Averaging) モデル
- ベイズ推論モデル
- BIB (ベイズ-逆ベイズ) 推論モデル

## 環境設定

```bash
# 仮想環境の作成と有効化
python -m venv venv
source venv/bin/activate  # Linuxの場合
# または
venv\Scripts\activate  # Windowsの場合

# 依存パッケージのインストール
pip install -r requirements.txt
```

## 実験の実行

```bash
# 実験の実行
python scripts/run_experiment.py
```

## 結果の分析

```bash
# 結果の分析
python scripts/analyze_results.py
```
