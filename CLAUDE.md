# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Python-based cooperative tapping experiment system for studying human-computer rhythmic interaction. It implements three different models (SEA, Bayesian, BIB) to simulate computer timing behavior during alternating tapping tasks.

## Conversation Guidelines

- 常に日本語で会話する

## Common Commands

### Environment Setup
```bash
# Create and activate virtual environment
python3.9 -m venv venv_py39
source venv_py39/bin/activate  # On Windows: venv_py39\Scripts\activate

# Install dependencies
pip install -r requirements.txt
pip install -e .
```

### Running Experiments

#### MATLAB (推奨)
```matlab
% メイン実験スクリプト
run_experiment

% または直接実行
final_python_experiment
```

#### Python (従来版)
```bash
# Run experiment with different models
run-tapping --model sea
run-tapping --model bayes
run-tapping --model bib

# With custom parameters
python scripts/run_experiment.py --model sea --span 2.0 --stage1 10 --stage2 100
```

### Analysis
```bash
# Analyze most recent experiment
analyze-tapping --model sea

# Analyze specific experiment ID
python scripts/analyze_results.py --model sea --experiment-id 20241208_143022
```

### Testing
```bash
pytest tests/
```

## Architecture

### Core Components
- **src/models/**: Model implementations
  - `base.py`: Abstract base model interface
  - `sea.py`: SEA (Synchronization Error Averaging) model
  - `bayes.py`: Bayesian inference model  
  - `bib.py`: BIB (Bayesian-Inverse Bayesian) model
- **src/experiment/**: Experiment framework
  - `runner.py`: Main experiment orchestration using PsychoPy
  - `data_collector.py`: Data collection and persistence
- **src/analysis/**: Analysis and visualization tools
- **src/config.py**: Centralized configuration management

### Data Structure
Experiments generate timestamped data in `data/raw/YYYYMMDD/[model]_[timestamp]/`:
- `processed_taps.csv`: Stage 2 tap timing data (main analysis data)
- `raw_taps.csv`: Complete raw tap data including Stage 1
- `*_synchronization_errors.csv`: SE data files
- `*_intertap_intervals.csv`: ITI data files  
- `model_hypotheses.csv`: Bayesian model hypothesis data

### Key Dependencies
- **PsychoPy**: Audio backend and timing-critical experiment execution
- **NumPy/SciPy**: Numerical computations and statistical analysis
- **Pandas**: Data manipulation and CSV I/O
- **Matplotlib**: Visualization generation

### Model Architecture
All models inherit from `BaseModel` and implement:
- `predict_next_interval()`: Core timing prediction logic
- `update()`: Learning from synchronization errors
- Stage 1: Fixed metronome timing for rhythm establishment
- Stage 2: Adaptive timing based on human responses

### Configuration Management
The `Config` class centralizes all parameters:
- Timing parameters (SPAN, STAGE1/STAGE2 counts, BUFFER)
- File paths for assets, data directories, sound files
- Model-specific parameters (hypothesis counts, memory length)

### Data Flow
1. Stage 1: Human taps to fixed metronome (rhythm establishment)
2. Stage 2: Alternating human-computer interaction with model adaptation
3. Real-time data collection of all tap timings
4. Post-processing: SE/ITI calculation and statistical analysis
5. Visualization generation for research output

## Development Notes

- Sound files (`stim_beat.wav`, `player_beat.wav`) must be placed in `assets/sounds/`
- The system uses millisecond-precision timing measurements via MATLAB `posixtime` function
- Analysis works with Stage 2 data by default (buffer removed)
- All models use synchronization error feedback for timing adaptation
- **メイン実験スクリプト**: `run_experiment.m` (based on `final_python_experiment.m`)
- Stage1: SPAN間隔（2.0秒）のメトロノーム、Stage2: SPAN/2間隔（1.0秒）の交互タッピング

## MATLAB Migration Status

**✅ 移行完了 + パフォーマンス最適化完了**: MATLABベースの実験システムが完成し、大幅な性能向上を達成しました。

**現在のステータス**:
- **メインスクリプト**: `run_experiment.m` → `experiments/main_experiment.m` - 本格運用レベルシステム
- **実装済み機能**: SEA/Bayes/BIBモデル、Stage1/2システム、データ記録、最適化音声再生
- **精度**: millisecond-precision timing via `posixtime` + 最適化キー入力
- **データ互換性**: 既存CSV形式と完全互換
- **音声品質**: 最適化された低遅延音声システム
- **安定性**: 適切な終了処理、タイムアウト機能、エラー耐性

**📈 パフォーマンス最適化成果 (2025-09-16)**:

### 音声システム最適化
- **音声遅延削減**: 20.7ms → 16.7ms (**19%改善**)
- **音声安定性**: 標準偏差 7.0ms → 1.2ms (**83%改善**)
- **ファイルサイズ**: 51.7KB → 12.9KB (**75%削減**)
- **最適化手法**: ステレオ→モノラル、44.1kHz→22.05kHz

### キー入力システム最適化
- **キー検出遅延**: 推定50-70%短縮
- **ループ間隔**: 0.1ms → 0.01ms (**10倍高速化**)
- **処理方式**: グローバル変数による直接アクセス
- **応答性**: より即座なキー反応を実現

### システム統合改善
- **Stage1音声同時再生問題**: 完全解決
- **プレイヤータップ音**: 削除による安定性向上
- **タイミング精度**: 総合的な遅延削減
- **CPU負荷**: 効率的な処理による軽減

**技術的改良点**:
- Stage1/Stage2間隔の正確な実装
- 音声競合問題の根本解決
- 無限ループバグの解決
- 高精度タイミングシステムの構築
- 最適化音声ファイル(`stim_beat_optimized.wav`)の採用
- キー入力遅延の大幅削減

**💡 パフォーマンス解析で特定された課題**:
- ITI遅延(1.555秒 vs 期待1.0秒)の根本原因は謎である

**🛠 残存ファイル**:
- `timing_test.m`: システム検証用
- `create_optimized_audio.m`: 音声最適化ツール
- `performance_test.m`: パフォーマンス測定ツール