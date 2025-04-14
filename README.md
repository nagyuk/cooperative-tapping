# Cooperative Tapping Task / 協調タッピング課題

This project implements a cooperative tapping experiment system designed to study human-computer rhythmic interaction. It provides three different models of interaction.

このプロジェクトは人間とコンピュータのリズム的相互作用を研究するための協調タッピング実験システムを実装しています。3種類の異なる相互作用モデルを提供します。

1. **SEA (Synchronization Error Averaging) Model**: Adjusts timing based on averaged synchronization errors.  
   **SEA（同期エラー平均化）モデル**：同期エラーの平均に基づいてタイミングを調整します。

2. **Bayesian Inference Model**: Uses Bayesian inference to predict and adapt to human timing patterns.  
   **ベイズ推論モデル**：ベイズ推論を使用して人間のタイミングパターンを予測し、適応します。

3. **BIB (Bayesian-Inverse Bayesian) Inference Model**: An extension of Bayesian inference that incorporates the flexible belief systems proposed by Gunji et al.  
   **BIB（ベイズ-逆ベイズ）推論モデル**：郡司らが提案した柔軟な信念システムを組み込んだベイズ推論の拡張版です。

## Project Structure / プロジェクト構造

```
cooperative-tapping/
│
├── src/                           # Main source code / メインソースコード
│   ├── models/                    # Model implementations / モデル実装
│   ├── experiment/                # Experiment framework / 実験フレームワーク
│   ├── analysis/                  # Analysis tools / 分析ツール
│   └── config.py                  # Centralized configuration / 一元化された設定
│
├── scripts/                       # Executable scripts / 実行可能なスクリプト
├── data/                          # Data directory / データディレクトリ
│   ├── raw/                       # Raw experiment data / 生の実験データ
│   └── processed/                 # Processed analysis results / 処理済み分析結果
│
├── assets/                        # Static assets / 静的アセット
│   └── sounds/                    # Sound files / 音声ファイル
│
├── tests/                         # Unit and integration tests / 単体・統合テスト
├── docs/                          # Documentation / ドキュメント
│
└── requirements.txt               # Dependencies / 依存関係
```

## Data Collection and Structure / データ収集と構造

### Experiment Phases / 実験フェーズ
The experiment consists of two phases:
実験は2つのフェーズで構成されています：

1. **Stage 1 (Metronome Phase)**: Fixed-interval taps to establish rhythm (typically 10 taps)  
   **ステージ1（メトロノームフェーズ）**：リズムを確立するための固定間隔タップ（通常10回）

2. **Stage 2 (Interaction Phase)**: Alternating taps between computer and human (typically 100 taps)  
   **ステージ2（インタラクションフェーズ）**：コンピュータと人間の交互のタップ（通常100回）

### Data Files / データファイル
Each experiment generates several CSV files with a timestamp-based ID:
各実験は、タイムスタンプベースのIDを持つ複数のCSVファイルを生成します：

- `[model]_[timestamp]_tap_full.csv`: Complete raw tap data from both Stage 1 and Stage 2  
  **完全なタップデータ**：ステージ1とステージ2の両方からの生タップデータ

- `[model]_[timestamp]_tap.csv`: Processed tap data (only Stage 2, buffer removed)  
  **処理済みタップデータ**：ステージ2のみのデータ（バッファ除去済み）

- `[model]_[timestamp]_SE.csv`: Synchronization Error data  
  **同期エラー（SE）データ**

- `[model]_[timestamp]_ITI.csv`: Inter Tap-onset Interval data  
  **タップ間隔（ITI）データ**

- `[model]_[timestamp]_variations.csv`: Variations of SE and ITI  
  **SEとITIの変動データ**

- `[model]_[timestamp]_hypo.csv`: Hypothesis data (Bayesian models only)  
  **仮説データ**（ベイズモデルのみ）

### Data Interpretation / データの解釈
- **Synchronization Error (SE)**: The difference between a player's tap and the midpoint of adjacent stimulus taps  
  **同期エラー（SE）**：プレイヤーのタップと隣接する刺激タップの中間点との差

- **Inter Tap-onset Interval (ITI)**: The time between consecutive taps  
  **タップ間隔（ITI）**：連続するタップ間の時間

- **Variations**: The differences between consecutive SE or ITI values  
  **変動**：連続するSEまたはITIの値の差

Note that analysis scripts work with processed data (Stage 2 data with buffer removed). If you need to analyze the complete raw data including Stage 1, you should use the `*_tap_full.csv` files.  
分析スクリプトは処理済みデータ（バッファを除去したステージ2のデータ）で動作します。ステージ1を含む完全な生データを分析する必要がある場合は、`*_tap_full.csv`ファイルを使用してください。

## Installation / インストール

### Setting up the development environment / 開発環境のセットアップ

1. Clone the repository / リポジトリのクローン:
```bash
git clone https://github.com/yourusername/cooperative-tapping.git
cd cooperative-tapping
```

2. Create and activate a virtual environment / 仮想環境の作成と有効化:
```bash
# For Python 3.9 or later / Python 3.9以降の場合
python3.9 -m venv venv_py39
source venv_py39/bin/activate  # On Windows: venv_py39\Scripts\activate
```

3. Install dependencies / 依存関係のインストール:
```bash
pip install -r requirements.txt
```

4. Install the package in development mode / 開発モードでパッケージをインストール:
```bash
pip install -e .
```

5. Make sure to place the required sound files in the assets/sounds directory / 必要な音声ファイルをassets/soundsディレクトリに配置してください:
   - button02a.mp3 (stimulus sound / 刺激音)
   - button03a.mp3 (player sound / プレイヤー音)

## Usage / 使用方法

### Running an experiment / 実験の実行

```bash
# Using the command-line script / コマンドラインスクリプトを使用
run-tapping --model sea

# Or directly with Python / または直接Pythonで
python scripts/run_experiment.py --model sea
```

Available options / 利用可能なオプション:
- `--model`: Choose between 'sea', 'bayes', or 'bib' models / 'sea'、'bayes'、または'bib'モデルから選択
- `--span`: Base interval in seconds (default: 2.0) / 基本間隔（秒）（デフォルト：2.0）
- `--stage1`: Number of metronome taps in Stage 1 (default: 10) / ステージ1のメトロノームタップ数（デフォルト：10）
- `--stage2`: Number of interaction taps in Stage 2 (default: 100) / ステージ2のインタラクションタップ数（デフォルト：100）
- `--buffer`: Number of taps to exclude from analysis (default: 10) / 分析から除外するタップ数（デフォルト：10）
- `--scale`: Variance scale for random timing (default: 0.1) / ランダムタイミングの分散スケール（デフォルト：0.1）

### Analyzing results / 結果の分析

```bash
# Using the command-line script / コマンドラインスクリプトを使用
analyze-tapping --model sea

# Or directly with Python / または直接Pythonで
python scripts/analyze_results.py --model sea
```

Available options / 利用可能なオプション:
- `--model`: Model used in the experiment ('sea', 'bayes', or 'bib') / 実験で使用したモデル（'sea'、'bayes'、または'bib'）
- `--experiment-id`: Specific experiment ID to analyze (default: most recent) / 分析する特定の実験ID（デフォルト：最新のもの）
- `--input-dir`: Custom input directory / カスタム入力ディレクトリ
- `--output-dir`: Custom output directory for visualizations / 可視化用のカスタム出力ディレクトリ

## Key Concepts / 重要な概念

### Models / モデル

#### SEA Model / SEAモデル
The simplest model that adjusts its timing based on the average of past synchronization errors.  
過去の同期エラーの平均に基づいてタイミングを調整する最もシンプルなモデル。

#### Bayesian Model / ベイズモデル
Uses Bayesian inference to learn from synchronization errors and predict optimal timing adjustments.  
ベイズ推論を使用して同期エラーから学習し、最適なタイミング調整を予測します。

#### BIB (Bayesian-Inverse Bayesian) Model / BIB（ベイズ-逆ベイズ）モデル
Extends the Bayesian model with an "inverse" component that allows hypothesis models themselves to evolve, creating a more flexible and adaptive system that better mimics human behavior.  
ベイズモデルを「逆」コンポーネントで拡張し、仮説モデル自体が進化できるようにすることで、より柔軟で適応性のあるシステムを作り出し、人間の行動をより良く模倣します。

## Research Background / 研究背景

This software is an implementation of cooperative tapping experiments as described in the paper "Analysis of Cooperative Tapping Tasks Using Extended Bayesian Inference Algorithm" by Yuki Nagai and Kazuto Sasai. The research explores timing control mechanisms in human communication, with a particular focus on developing models that can represent non-stationary states.  
このソフトウェアは、永井友貴と笹井一人による論文「拡張ベイズ推論アルゴリズムを用いた協調タッピング課題の分析」に記述されている協調タッピング実験の実装です。この研究は、人間のコミュニケーションにおけるタイミング制御メカニズムを探求し、特に非定常状態を表現できるモデルの開発に焦点を当てています。

## License / ライセンス

This project is licensed under the MIT License - see the LICENSE file for details.  
このプロジェクトはMITライセンスの下でライセンスされています - 詳細はLICENSEファイルを参照してください。

## Acknowledgments / 謝辞

- Based on research by Kazuto Sasai and Yukio-Pegio Gunji on Bayesian-Inverse Bayesian inference.  
  笹井一人と郡司幸夫によるベイズ-逆ベイズ推論に関する研究に基づいています。
- Developed for the rhythmic interaction studies at Ibaraki University.  
  茨城大学でのリズム的相互作用研究のために開発されました。