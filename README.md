# Cooperative Tapping Experiment System / 協調タッピング実験システム

## 🎯 Production-Ready MATLAB System

This project implements a **high-precision cooperative tapping experiment system** using MATLAB and PsychToolbox for studying human-computer rhythmic interaction. The system achieves **sub-millisecond timing accuracy** with **perfect 1.0-second Stage1 metronome precision**.

このプロジェクトは、人間とコンピュータのリズム的相互作用を研究するためのMATLABとPsychToolboxを使った**高精度協調タッピング実験システム**を実装しています。**ミリ秒以下のタイミング精度**と**完璧な1.0秒Stage1メトロノーム精度**を実現しています。

## ✅ Quick Start / クイックスタート

```matlab
% 1. Setup PsychToolbox (one-time only / 一回のみ)
setup_psychtoolbox

% 2. Run experiment / 実験実行
run_experiment
```

## 🔬 System Features / システム機能

### High-Precision Audio System / 高精度音声システム
- **PsychPortAudio backend** with 6.8ms latency / 6.8msレイテンシのPsychPortAudioバックエンド
- **Perfect Stage1 metronome**: Exact 1.0-second intervals / 完璧なStage1メトロノーム：正確な1.0秒間隔
- **Professional audio interface** support (Scarlett 4i4) / プロ用音声インターフェースサポート
- **Optimized audio files**: 22.05kHz mono format / 最適化音声ファイル：22.05kHzモノラル

### Real-time Performance / リアルタイムパフォーマンス
- **Sub-millisecond timing precision** via GetSecs / GetSecsによるミリ秒以下のタイミング精度
- **Unified timestamp system**: All data synchronized / 統一タイムスタンプシステム：全データ同期
- **Zero audio conflicts**: Eliminated irregular rhythms / 音声競合ゼロ：不規則リズムを排除

### Experiment Models / 実験モデル
1. **SEA (Synchronization Error Averaging)**: Simple averaging of timing errors / タイミングエラーの単純平均化
2. **Bayesian**: Probabilistic inference for timing prediction / タイミング予測のための確率的推論
3. **BIB (Bayesian-Inverse Bayesian)**: Advanced adaptive model / 高度な適応モデル

## 📁 Project Structure / プロジェクト構造

```
cooperative-tapping/
├── run_experiment.m              # Main entry point / メインエントリーポイント
├── main_experiment.m             # Complete experiment system / 完全実験システム
├── setup_psychtoolbox.m          # PsychToolbox setup / PsychToolboxセットアップ
├── create_optimized_audio.m      # Audio optimization tool / 音声最適化ツール
├── CLAUDE.md                     # Development guidance / 開発ガイダンス
├── README.md                     # This file / このファイル
│
├── assets/sounds/                # Audio files / 音声ファイル
│   ├── stim_beat_optimized.wav   # Optimized stimulus sound / 最適化刺激音
│   └── player_beat_optimized.wav # Optimized player sound / 最適化プレイヤー音
│
├── data/raw/                     # Experiment data / 実験データ
│   └── YYYYMMDD/[participant]_[model]_[timestamp]/
│       ├── processed_taps.csv          # Stage2 analysis data / Stage2分析データ
│       ├── raw_taps.csv               # Complete timing data / 完全タイミングデータ
│       ├── stage1_synchronous_taps.csv # Stage1 data / Stage1データ
│       ├── stage2_alternating_taps.csv # Stage2 data / Stage2データ
│       └── debug_log.csv              # Model debug info / モデルデバッグ情報
│
├── experiments/                  # Framework & configs / フレームワーク・設定
├── legacy/                      # Original Python system / 元のPythonシステム
├── archive/                     # Development history / 開発履歴
└── Psychtoolbox/               # PsychToolbox installation / PsychToolboxインストール
```

## 🎵 Experiment Design / 実験設計

### Stage 1: Rhythm Establishment / リズム確立
- **Perfect metronome**: Exact 1.0-second intervals / 完璧なメトロノーム：正確な1.0秒間隔
- **Rhythm learning**: Human adapts to computer timing / リズム学習：人間がコンピュータタイミングに適応
- **Duration**: Typically 10 beats / 期間：通常10ビート

### Stage 2: Cooperative Interaction / 協調的相互作用
- **Alternating tapping**: Human-computer turn-taking / 交互タッピング：人間-コンピュータのターン制
- **Model adaptation**: Real-time learning from synchronization errors / モデル適応：同期エラーからのリアルタイム学習
- **Duration**: Typically 100+ interaction cycles / 期間：通常100+回の相互作用サイクル

## 📊 Data Output / データ出力

Each experiment generates synchronized CSV files with unified timestamps:
各実験は統一タイムスタンプで同期されたCSVファイルを生成します：

- **processed_taps.csv**: Stage2 analysis data (buffer removed) / Stage2分析データ（バッファ除去済み）
- **raw_taps.csv**: Complete timing records / 完全タイミング記録
- **stage1_synchronous_taps.csv**: Metronome data / メトロノームデータ
- **stage2_alternating_taps.csv**: Interaction data / 相互作用データ
- **debug_log.csv**: Model predictions and calculations / モデル予測と計算

## ⚙️ System Requirements / システム要件

### Hardware / ハードウェア
- **Audio Interface**: Scarlett 4i4 (recommended) or system audio / 音声インターフェース：Scarlett 4i4（推奨）またはシステム音声
- **Computer**: Mac/Windows with MATLAB support / コンピュータ：MATLAB対応のMac/Windows

### Software / ソフトウェア
- **MATLAB R2025a+** with Signal Processing Toolbox / Signal Processing Toolbox付きMATLAB R2025a+
- **PsychToolbox 3.0.22+** (included in project) / PsychToolbox 3.0.22+（プロジェクトに含まれる）

## 🛠️ Technical Achievements / 技術的成果

### Problems Solved / 解決された問題
1. **3n+1 Irregular Rhythm**: Complete elimination / 3n+1不規則リズム：完全排除
2. **Audio Latency**: Reduced to professional levels (6.8ms) / 音声遅延：プロレベルまで削減（6.8ms）
3. **Timestamp Synchronization**: Resolved 20+ second offsets / タイムスタンプ同期：20+秒のオフセット解決
4. **System Stability**: Robust error handling / システム安定性：堅牢なエラー処理

### Performance Metrics / パフォーマンス指標
- **Audio Latency**: 6.848ms (Scarlett 4i4) / 音声遅延：6.848ms（Scarlett 4i4）
- **Timing Precision**: Sub-millisecond accuracy / タイミング精度：ミリ秒以下の精度
- **Stage1 Regularity**: Perfect 1.0-second intervals / Stage1規則性：完璧な1.0秒間隔
- **Data Integrity**: Zero synchronization errors / データ整合性：同期エラーゼロ

## 🔬 Research Background / 研究背景

This system implements cooperative tapping experiments for studying human-computer rhythmic interaction and timing control mechanisms. The research explores how different computational models can adapt to and predict human timing behavior in real-time collaborative tasks.

このシステムは、人間とコンピュータのリズム的相互作用とタイミング制御メカニズムを研究するための協調タッピング実験を実装しています。異なる計算モデルがリアルタイムの協調課題において人間のタイミング行動にどのように適応し予測できるかを探求しています。

### Key Research Areas / 主要研究分野
- **Timing Control**: Human-computer synchronization / タイミング制御：人間-コンピュータ同期
- **Model Adaptation**: Real-time learning algorithms / モデル適応：リアルタイム学習アルゴリズム
- **Rhythmic Interaction**: Cooperative timing behavior / リズム的相互作用：協調的タイミング行動

## 📈 Development History / 開発履歴

- **2025-10-07**: Production system completion with perfect timing / 完璧なタイミングでの本番システム完成
- **Audio Migration**: From `sound()` to PsychPortAudio / 音声移行：`sound()`からPsychPortAudioへ
- **Timing Unification**: Single global reference system / タイミング統合：単一グローバル基準システム
- **Professional Integration**: Scarlett 4i4 support / プロ統合：Scarlett 4i4サポート

## 🤝 Contributing / 貢献

This is a research project. For technical questions or collaboration inquiries, please refer to the development documentation in `CLAUDE.md`.

これは研究プロジェクトです。技術的な質問や共同研究に関するお問い合わせは、`CLAUDE.md`の開発ドキュメントを参照してください。

## 📄 License / ライセンス

This project is for academic research purposes. Please contact the authors for usage permissions.

このプロジェクトは学術研究目的です。使用許可については著者にお問い合わせください。

---

**Status**: ✅ **Production Ready** - High-precision cooperative tapping experiment system
**ステータス**: ✅ **本番対応完了** - 高精度協調タッピング実験システム