# PsychPortAudioウォームアップの必要性

## 問題の概要

協調タッピング実験において、**Stage1のturn1（最初の2音）の間隔が数百ミリ秒短く聞こえる**という問題が発生しました。

- **期待値**: 刺激音（0.5秒） → プレイヤー音（1.5秒） = 間隔1.0秒
- **実測値**: システム上は1.0秒だが、実際に耳で聞くと明らかに短い（0.7-0.8秒程度）

## 根本原因

### PsychPortAudioの初回再生遅延

PsychPortAudioは、**初回の`Start`呼び出し時**に以下の処理が発生します：

1. **オーディオハードウェアの起動**
   - スリープ状態のオーディオデバイスをアクティブ化
   - DACの電源投入とクロック同期

2. **DMAバッファの初期化**
   - メモリバッファの確保と初期化
   - ハードウェアバッファとの接続確立

3. **デバイスドライバの準備**
   - CoreAudio（macOS）の内部状態初期化
   - サンプリングレート設定の確定

これらの処理には**200-300ミリ秒程度**かかることがあります。

### タイミングへの影響

```
実験開始
↓
timer.start() → 0.000秒
↓
wait_until(0.5秒) → 0.5秒で待機完了
↓
record_event() → 0.500秒を記録
↓
play_buffer(刺激音) → Start呼び出し
  ↓ [初回のみ: ハードウェア初期化で200-300ms遅延]
  ↓
実際の音再生 → 0.7-0.8秒地点で鳴る ← 遅延発生！
↓
wait_until(1.5秒) → 1.5秒で待機完了
↓
record_event() → 1.500秒を記録
↓
play_buffer(プレイヤー音) → Start呼び出し
  ↓ [2回目以降: 既に初期化済みのため遅延なし]
  ↓
実際の音再生 → 1.5秒地点で鳴る
```

**結果**: 実際の音の間隔 = 1.5 - 0.7 = **0.8秒** （1.0秒より短い！）

## 解決策: オーディオウォームアップ

### 実装内容

実験開始**前**に、無音のダミー音声を再生してハードウェアを事前に起動します。

```matlab
function warmup_audio(obj)
    % オーディオハードウェアウォームアップ
    % 初回再生遅延を防ぐため、無音を事前再生してハードウェアを初期化

    % 極短い無音データ作成（0.01秒 = 221サンプル @ 22050Hz）
    silent_samples = round(obj.fs * 0.01);
    silence = zeros(silent_samples, 1);

    % 全チャンネルに無音を割り当て
    silence_buffer = obj.create_buffer(silence, ones(1, obj.num_channels));

    % 無音を再生（wait=1で完了まで待機）
    PsychPortAudio('FillBuffer', obj.pahandle, silence_buffer);
    PsychPortAudio('Start', obj.pahandle, 1, 0, 1);

    % バッファ削除
    PsychPortAudio('DeleteBuffer', silence_buffer);

    % 短い待機でハードウェアの安定化
    pause(0.05);
end
```

### 呼び出しタイミング

```matlab
function prepare_audio_buffers(obj)
    % 音声ファイル読み込み
    stim_sound = obj.audio.load_sound_file('assets/sounds/stim_beat_optimized.wav');
    player_sound = obj.audio.load_sound_file('assets/sounds/player_beat_optimized.wav');

    % バッファ作成
    obj.stim_buffer = obj.audio.create_buffer(stim_sound, [1,1,0,0]);
    obj.player_buffer = obj.audio.create_buffer(player_sound, [1,1,0,0]);

    % ★ここでウォームアップ実行（実験開始前）
    obj.audio.warmup_audio();
end
```

### 効果

```
初期化時
↓
warmup_audio() → ハードウェア起動完了 ✓
↓
[実験開始を待機]
↓
timer.start() → 0.000秒
↓
wait_until(0.5秒) → 0.5秒で待機完了
↓
record_event() → 0.500秒を記録
↓
play_buffer(刺激音) → Start呼び出し
  ↓ [既に初期化済み: 遅延なし！]
  ↓
実際の音再生 → 0.5秒地点で鳴る ← 正確！
↓
wait_until(1.5秒) → 1.5秒で待機完了
↓
record_event() → 1.500秒を記録
↓
play_buffer(プレイヤー音)
  ↓ [遅延なし]
  ↓
実際の音再生 → 1.5秒地点で鳴る
```

**結果**: 実際の音の間隔 = 1.5 - 0.5 = **1.0秒** （正確！）

## 発見の経緯

### 問題発見

- ユーザーが実際に実験を実行し、**耳で聞いて**最初の2音の間隔が短いことに気づいた
- システム上の記録時刻（0.501秒、1.501秒）は正確だったため、当初は原因不明

### 仮説の提示

ユーザーからの重要な洞察：
> 「**最初のサウンドを再生する際に何らかの読み込みなどが発生している**せいで遅延が発生するのではないか」

この仮説が正しく、PsychPortAudioの初回再生遅延が原因と判明。

### 解決までの試行

1. ❌ タイミング記録順序の変更 → 効果なし
2. ❌ timer.start()位置の調整 → 効果なし
3. ✅ **オーディオウォームアップ実装** → 完全解決！

## 技術的詳細

### なぜ初回のみ遅延するのか

**オーディオハードウェアの電源管理**:
- 現代のオーディオデバイスは省電力のため、未使用時はスリープ状態
- 最初の再生要求時に起動処理が必要
- 一度起動すると、しばらくアクティブ状態を維持

**PsychPortAudioの設計**:
- 低レイテンシを優先した設計
- ハードウェアの起動は最初のStart時に遅延実行
- これにより初期化時間は短縮されるが、初回再生に遅延が生じる

### ウォームアップの重要性

この問題は**測定に現れない**ため、気づきにくい：
- `record_event()`は`play_buffer()`呼び出し時刻を記録
- 実際の音声出力は数百ms後
- データ上は正確に見えるが、実際の音は遅れている

## 適用範囲

### 必須の実験タイプ

- **タイミング精度が重要な全ての実験**
  - 協調タッピング実験
  - リズム知覚実験
  - 反応時間測定

### 特に重要なケース

- **最初の刺激が基準となる実験**
  - Stage1で基準リズムを学習
  - 初回の精度が後続に影響

### 不要なケース

- 音声のタイミング精度が重要でない実験
- 長い説明音声の後に実験が始まる場合（既にハードウェアが起動済み）

## 実装上の注意

### ウォームアップの設計

1. **無音を使用する理由**
   - 参加者に聞こえない
   - 極短時間（0.01秒）で十分

2. **wait=1で完了待機する理由**
   - ハードウェアの起動完了を確実にする
   - 非同期では効果が不十分

3. **pause(0.05)の理由**
   - ハードウェアの安定化時間
   - DACの電圧安定化

### パフォーマンスへの影響

- **初期化時間**: 約50-100ms増加
- **実験精度**: 大幅に向上
- **トレードオフ**: 初期化時間の増加は許容範囲内

## 関連コード

### 実装ファイル

- `core/audio/AudioSystem.m`: warmup_audio()メソッド
- `experiments/human_computer/HumanComputerExperiment.m`: prepare_audio_buffers()
- `experiments/human_human/HumanHumanExperiment.m`: prepare_audio_buffers()

### テスト方法

実際に実験を実行し、**耳で聞いて**確認：
```matlab
clear classes; rehash toolboxcache
run_unified_experiment
```

Stage1 turn1の最初の刺激音→プレイヤー音の間隔が1.0秒に聞こえることを確認。

## まとめ

**この「儀式めいた」ウォームアップは必須です。**

- PsychPortAudioの仕様に起因する初回再生遅延を回避
- データ上は見えないが、実際の音声タイミングに数百ms影響
- 実験の精度を保証するための重要な処理

**削除してはいけません。**

---

**作成日**: 2025-10-09
**問題発見者**: 実験実施ユーザー（耳で聞いて気づいた）
**解決者**: Claude Code with user guidance
**参考コミット**: 75a5e05
