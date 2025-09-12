# 協調タッピング実験の実行方法

## 🎯 基本実行

MATLABで以下のコマンドを実行：

```matlab
run_experiment
```

## 📋 実験手順

1. **モデル選択**: 1=SEA, 2=Bayes, 3=BIB
2. **参加者ID入力**: 任意の識別子
3. **Stage1**: メトロノーム（2秒間隔）に合わせて10回タップ
4. **Stage2**: 交互タッピング（1秒間隔）で100回のインタラクション

## 🎵 必要ファイル

- `assets/sounds/stim_beat.wav` - システム音
- `assets/sounds/player_beat.wav` - プレイヤー音

## 📊 データ出力

実験データは `data/raw/YYYYMMDD/` に保存：
- `processed_taps.csv` - Stage2メインデータ 
- `raw_taps.csv` - 全データ（Stage1含む）

## ⌨️ キー操作

- **Space**: タップ
- **Escape**: 実験終了

## 🔧 設定

- **SPAN**: 2.0秒（config内で変更可能）
- **Stage1**: 10回のメトロノーム
- **Stage2**: 100回の交互タッピング