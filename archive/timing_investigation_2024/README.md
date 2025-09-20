# タイミング調査アーカイブ (2024年9月)

## 概要
Stage1音声タイミング問題の根本原因調査と解決策検討で作成されたテストスクリプト群

## 調査内容

### 🔍 **問題の特定**
- **6n+1パターン**: 特定音響で32ms短縮間隔を発見
- **音1-2結合問題**: 実音響測定で音響分離失敗を確認
- **内部時計 vs 実音響**: ソフトウェア測定と実際の音響出力の乖離

### 🛠 **実装された解決策**
- **遅延補正システム**: -4ms補正で最適化達成
- **audioplayerオブジェクト事前初期化**: 6n+1問題の解決
- **音声ファイル短縮**: 音響分離の改善

## ファイル一覧

### **診断・分析系**
- `timing_precision_test.m` - 各手法の遅延特性分析
- `debug_actual_timing_measurement.m` - Stage1実際タイミング測定
- `debug_3n1_timing_analysis.m` - 6n+1問題の詳細分析
- `debug_sound_initialization.m` - CoreAudio初期化遅延調査

### **音響測定系**
- `microphone_acoustic_timing_test.m` - 実音響タイミング測定
- `relative_interval_acoustic_test.m` - 相対間隔特化測定
- `acoustic_separation_test.m` - 音響分離テスト
- `simple_acoustic_verification.m` - 簡易音響検証

### **解決策実装系**
- `delay_compensation_test.m` - 遅延補正システム
- `audioplayer_solution_test.m` - audioplayerによる解決
- `timing_solution_tests.m` - 複数解決手法の比較テスト
- `audio_length_analysis.m` - 音声ファイル長さ最適化

### **その他**
- `timing_test.m` - 基本タイミングテスト

## 🎯 **主要な発見**

### **遅延特性**
```
待機システム: 0.6ms誤差 (完璧)
音声再生: 7ms平均遅延 (問題の根源)
最適補正値: -4ms
```

### **6n+1問題**
- 実音響測定で32ms短縮間隔を客観的に確認
- audioplayerオブジェクト事前初期化で解決

### **実装推奨**
- main_experimentに-4ms遅延補正を適用
- 複数audioplayerオブジェクトの活用
- posixtime()高精度待機システム

## 📚 **関連ドキュメント**
- `docs/experiment_design_improvement.md` - 実験設計改善
- `docs/audio_timing_issue_analysis.md` - 詳細分析レポート

---
*このアーカイブは2024年9月のタイミング問題調査の完全な記録です*