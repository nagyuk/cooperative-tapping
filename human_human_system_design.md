# 人間同士協調タッピングシステム 技術仕様書

## 🔧 **ハードウェア構成**

### **入力デバイス**
- **サンワサプライ 400-SKB075 プログラマブルキー** × 2台
  - Player 1用、Player 2用として独立認識
  - 高精度タイミング検出
  - USB接続による安定した入力

### **音声出力システム**
- **Focusrite Scarlett 4i4 (4th Gen) オーディオインターフェース**
  - Output 1/2: Player 1用ヘッドフォン
  - Output 3/4: Player 2用ヘッドフォン
  - 低遅延モニタリング対応
  - 48kHz/24bit高音質

### **音声配信構成**
```
Scarlett 4i4 Outputs:
├── Output 1/2 (Player 1 ヘッドフォン)
│   ├── メトロノーム音
│   └── Player 2のタップ → 刺激音
└── Output 3/4 (Player 2 ヘッドフォン)
    ├── メトロノーム音
    └── Player 1のタップ → 刺激音
```

---

## 🎯 **実験設計**

### **Stage 1: メトロノームフェーズ（実験安定化）**
```
目的: 両プレイヤーが独立して1.0秒間隔を学習
音声:
  - 両ヘッドフォンに同じメトロノーム音
  - プレイヤーのタップ音なし
期間: 20タップ（40秒）
評価: 個別のタイミング精度測定
```

### **Stage 2: 相互協調タッピング**
```
目的: 交互タッピングによる協調リズム形成
音声:
  - Player 1タップ → Player 2ヘッドフォンに刺激音
  - Player 2タップ → Player 1ヘッドフォンに刺激音
  - 自分のタップ音は聞こえない（相手の音のみ）
期間: 100交互タップ（200タップ総計）
評価: 相互適応、同期精度、安定性
```

---

## 🔧 **技術実装アーキテクチャ**

### **1. キー入力システム**
```matlab
% プログラマブルキー識別
% 400-SKB075を異なるキーコードに設定
% Player 1: 'q' キー
% Player 2: 'p' キー

function detect_programmable_keys()
    % デバイス固有識別
    % キー設定確認
    % 同時押し検出
end
```

### **2. Scarlett 4i4対応音声システム**
```matlab
% 4チャンネル独立出力
% ASIO/CoreAudio低遅延ドライバー対応

function setup_scarlett_4i4()
    % Output 1/2: Player 1 (Left/Right)
    % Output 3/4: Player 2 (Left/Right)

    player1_device = audioplayer(audio_data, 48000, 24, 1); % Ch 1/2
    player2_device = audioplayer(audio_data, 48000, 24, 3); % Ch 3/4
end
```

### **3. 相互刺激音フィードバック**
```matlab
% リアルタイム音声ルーティング
function handle_cross_feedback(player_id, tap_time)
    if player_id == 1
        % Player 1のタップ → Player 2のヘッドフォンに刺激音
        play_to_output(stim_sound, [3, 4]); % Ch 3/4
    else
        % Player 2のタップ → Player 1のヘッドフォンに刺激音
        play_to_output(stim_sound, [1, 2]); % Ch 1/2
    end
end
```

---

## 📊 **データ収集設計**

### **記録項目**
```matlab
データ構造:
- tap_times: [player_id, absolute_time, stage, tap_number]
- intervals: [from_player, to_player, interval_duration]
- sync_errors: [player_id, expected_time, actual_time, error]
- cooperation_metrics: [mutual_adaptation, sync_stability]
```

### **評価メトリクス**
1. **個別精度**: 各プレイヤーのタイミング精度
2. **相互適応**: 相手に合わせる能力
3. **同期安定性**: 長期間の協調維持
4. **予測精度**: 相手のタイミング予測能力

---

## 🎵 **音声設計仕様**

### **音声ファイル**
```
メトロノーム音: metro_beat.wav (300ms, クリック音)
刺激音: stim_beat.wav (200ms, 高音ビープ)
確認音: confirm_beat.wav (150ms, 中音チャイム)
```

### **音量設定**
```
メトロノーム: -12dB (背景音レベル)
刺激音: -6dB (明確な合図レベル)
確認音: -9dB (フィードバックレベル)
```

### **遅延対策**
```
Scarlett 4i4設定:
- Buffer Size: 64 samples (1.3ms@48kHz)
- Sample Rate: 48kHz
- ASIO/CoreAudio直接制御
```

---

## 🔄 **実験フロー**

### **準備フェーズ**
1. **ハードウェア接続確認**
   - プログラマブルキー認識テスト
   - Scarlett 4i4出力チャンネル確認
   - ヘッドフォン左右チェック

2. **キーマッピング設定**
   - Player 1: 'q'キー設定
   - Player 2: 'p'キー設定
   - 同時押し検出テスト

3. **音声システム確認**
   - 4チャンネル独立出力テスト
   - 遅延測定（<5ms目標）
   - クロスフィードバック確認

### **実験実行フェーズ**
```
Stage 1 (60秒):
├── 20メトロノーム音 (3秒間隔)
├── 両プレイヤー独立タップ
└── 個別精度測定

Stage 2 (200秒):
├── Player 1スタート
├── 交互タッピング (100サイクル)
├── リアルタイム相互フィードバック
└── 協調メトリクス測定
```

### **データ保存**
```
実験データ: human_human_YYYYMMDD_HHMMSS.mat
├── raw_taps: 全タップデータ
├── intervals: 間隔データ
├── cooperation: 協調指標
└── hardware_info: 機器情報
```

---

## 🚀 **実装優先順位**

### **Phase 1: 基本システム (1週間)**
1. ✅ **プログラマブルキー認識システム**
2. ⏳ **Scarlett 4i4 4チャンネル出力**
3. ⏳ **基本的な交互タッピング**

### **Phase 2: 高度化 (2週間)**
1. **遅延最適化**
2. **リアルタイム分析**
3. **実験プロトコル完成**

### **Phase 3: 研究機能 (1ヶ月)**
1. **多様な実験条件**
2. **高度な協調分析**
3. **論文レベルデータ収集**

---

## 📋 **検証項目**

### **ハードウェア検証**
- [ ] プログラマブルキー2台の独立認識
- [ ] Scarlett 4i4の4ch出力確認
- [ ] 遅延測定（<5ms）
- [ ] クロスフィードバック動作

### **ソフトウェア検証**
- [ ] リアルタイム音声ルーティング
- [ ] 高精度タイミング測定
- [ ] データ収集完整性
- [ ] 長時間安定動作

---

この仕様に基づいて、まず**プログラマブルキー認識システム**から実装を開始します。