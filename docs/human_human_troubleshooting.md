# Human-Human実験で想定されるエラーと対処法

Human-Human協調タッピング実験で発生する可能性のあるエラーと問題点を網羅的にまとめます。

---

## 1. 技術的エラー

### 1.1 オーディオ関連エラー

#### エラー1: 4チャンネルオーディオデバイスが見つからない

**エラーメッセージ**:
```
AudioSystem:NoDevice - 4チャンネル対応デバイスが見つかりません
```

**原因**:
- Scarlett 4i4が接続されていない
- デバイスが別のアプリケーションで使用中
- ドライバが正しくインストールされていない

**対処法**:
```matlab
% 1. デバイス確認
devices = PsychPortAudio('GetDevices');
for i = 1:length(devices)
    fprintf('%d: %s (%d out channels)\n', ...
        devices(i).DeviceIndex, devices(i).DeviceName, devices(i).NrOutputChannels);
end

% 2. Scarlett 4i4を確認
% - USB接続を確認
% - Audio MIDI設定で認識されているか確認
% - 他のアプリケーション（DAW、Zoom等）を終了

% 3. 緊急対応: 2チャンネルでテスト実行
% この場合、両プレイヤーが同じ音を聞くことになる
% → Human-Humanの意味が薄れるため推奨されない
```

**予防策**:
- 実験開始前に必ずデバイス接続を確認
- チェックリストの作成（後述）

---

#### エラー2: チャンネル分離の誤り（両プレイヤーが同じ音を聞く）

**症状**:
- Stage2で両プレイヤーが両方の音を聞いてしまう
- 協調タッピングにならない

**原因**:
```matlab
% 誤った設定例
obj.player1_stage2_buffer = obj.audio.create_buffer(p2_sound, [1,1,1,1]);  % ❌ 全チャンネル
obj.player2_stage2_buffer = obj.audio.create_buffer(p1_sound, [1,1,1,1]);  % ❌ 全チャンネル

% 正しい設定
obj.player1_stage2_buffer = obj.audio.create_buffer(p2_sound, [1,1,0,0]);  % ✅ Ch1/2のみ
obj.player2_stage2_buffer = obj.audio.create_buffer(p1_sound, [0,0,1,1]);  % ✅ Ch3/4のみ
```

**検証方法**:
```matlab
% 実験開始前のテスト
% 1. Player1のヘッドフォンでPlayer2音のみ聞こえることを確認
% 2. Player2のヘッドフォンでPlayer1音のみ聞こえることを確認
```

**対処法**:
- `prepare_audio_buffers()`のチャンネルマスクを確認
- 実験前に必ず音声テストを実施

---

#### エラー3: オーディオバッファオーバーフロー/アンダーラン

**エラーメッセージ**:
```
PsychPortAudio: Buffer underrun detected
PsychPortAudio: Audio glitch detected
```

**原因**:
- システムのCPU負荷が高い
- バックグラウンドプロセスがリソースを占有
- メモリ不足

**対処法**:
```bash
# 実験前に不要なアプリケーションを終了
# - ブラウザ（特にChromeの多数タブ）
# - Slack, Discord等の通信アプリ
# - DropboxやGoogle Driveの同期

# macOSの場合
# システム環境設定 → 一般 → ログイン項目 を確認
```

**予防策**:
- 実験専用のユーザーアカウントを作成
- 実験中はネットワークを切断（可能であれば）

---

### 1.2 キーボード入力エラー

#### エラー4: キー入力が認識されない

**症状**:
- SキーまたはCキーを押してもタップが記録されない
- Stage2が進行しない

**原因**:
```matlab
% HumanHumanExperiment.m: 107-118行
switch event.Key
    case 's'  % ← 小文字の's'のみ対応
        if current_time - obj.player1_last_press_time > 0.05
            obj.player1_key_pressed = true;
            obj.player1_last_press_time = current_time;
        end
    case 'c'  % ← 小文字の'c'のみ対応
        ...
end
```

**対処法**:
- **Caps Lockがオンになっていないか確認**
- 日本語入力モードになっていないか確認
- キーボードレイアウトが正しいか確認（US/JIS）

**改善案**:
```matlab
% 大文字・小文字両対応にする
switch lower(event.Key)  % ← lower()を追加
    case 's'
        ...
    case 'c'
        ...
end
```

---

#### エラー5: キーリピートによる重複入力

**症状**:
- 1回のキー押下で複数タップが記録される
- データが異常に多くなる

**原因**:
- キーボードのリピート機能
- デバウンス時間（0.05秒）が短すぎる

**現在の対策**:
```matlab
% HumanHumanExperiment.m: 109行
if current_time - obj.player1_last_press_time > 0.05  % デバウンス
```

**推奨デバウンス時間**:
- 現在: 0.05秒（50ms）
- 推奨: 0.1秒（100ms）← より安全

**改善案**:
```matlab
% デバウンス時間を設定可能に
properties (Access = protected)
    debounce_time = 0.1  % 100ms
end

if current_time - obj.player1_last_press_time > obj.debounce_time
    ...
end
```

---

#### エラー6: キー押下とリリースのタイミング問題

**症状**:
- キーを長押しすると複数タップになる
- キーを離すタイミングでエラー

**原因**:
```matlab
% key_release_handler (121-130行)
function key_release_handler(obj, ~, event)
    switch event.Key
        case 's'
            obj.player1_key_pressed = false;
        case 'c'
            obj.player2_key_pressed = false;
    end
end
```

**潜在的問題**:
- リリースイベントが取得できない場合、フラグが永続的にtrueになる可能性

**改善案**:
```matlab
% Stage2のメインループにタイムアウトを追加
timeout_duration = 60;  % 60秒無操作でタイムアウト
last_tap_time = obj.timer.get_current_time();

while cycle_count < obj.stage2_cycles && obj.is_running
    current_time = obj.timer.get_current_time();

    % タイムアウトチェック
    if current_time - last_tap_time > timeout_duration
        warning('60秒間タップがありませんでした。実験を中断します。');
        break;
    end

    % 通常の処理
    ...
end
```

---

### 1.3 タイミング関連エラー

#### エラー7: Stage1の音声間隔が不正確

**症状**:
- 最初の2音の間隔が1.0秒より明らかに短い
- リズムが不規則に聞こえる

**原因**:
- オーディオウォームアップが実行されていない
- タイマー開始タイミングが不適切

**確認方法**:
```matlab
% データを確認
data = readtable('data/raw/human_human/.../stage1_metronome.csv');
timestamps = data.timestamp;
intervals = diff(timestamps);

fprintf('Stage1音声間隔:\n');
for i = 1:length(intervals)
    fprintf('  間隔%d: %.3f秒\n', i, intervals(i));
end

% 期待値: すべて1.0秒（±0.01秒）
```

**対処法**:
- `prepare_audio_buffers()`でウォームアップが実行されているか確認
- `docs/audio_warmup_necessity.md`を参照

---

#### エラー8: データのタイムスタンプ不整合

**症状**:
- Stage1とStage2のタイムスタンプが大きくずれる
- 負のInter-Tap Intervalが記録される

**原因**:
- タイマーが途中でリセットされる
- `timer.start()`が複数回呼ばれる

**検証方法**:
```matlab
% データ整合性チェック
data = readtable('data/raw/human_human/.../stage2_cooperative_taps.csv');
timestamps = data.timestamp;

% 単調増加をチェック
if any(diff(timestamps) < 0)
    error('タイムスタンプが単調増加していません！');
end

% 異常に大きな間隔をチェック
intervals = diff(timestamps);
if any(intervals > 5.0)
    warning('異常に長い間隔が検出されました（>5秒）');
end
```

---

## 2. 実験手続き上のエラー

### 2.1 参加者関連

#### エラー9: 参加者の理解不足

**症状**:
- Stage2で交互タッピングができない
- 両プレイヤーが同時にタップしてしまう
- タップのタイミングが全く合わない

**原因**:
- 教示が不十分
- Stage1でリズムを学習できていない
- 実験の目的を理解していない

**対処法**:
```
【実験前の教示スクリプト（推奨）】

"この実験では、2人で協力してリズムを維持していただきます。

Stage 1（練習フェーズ）:
- 2種類の音が1秒間隔で交互に鳴ります
- 音を聞いて、1秒間隔のリズムを覚えてください
- この段階ではキーを押す必要はありません

Stage 2（協調タッピングフェーズ）:
- Player 1がSキーを押してスタートします
- すると、Player 2に音が聞こえます
- Player 2はその音に合わせて、その1秒後にCキーを押します
- すると、Player 1に音が聞こえます
- このように、お互いの音に合わせて交互にタップしてください

ポイント:
- 相手の音の1秒後にタップする
- 急がず、ゆっくりで大丈夫です
- リズムが崩れても焦らず、再度合わせてください

何か質問はありますか？"
```

**予防策**:
- 実験前に必ず練習試行を実施（3-5サイクル）
- 教示スクリプトを標準化
- 理解度確認クイズの実施

---

#### エラー10: 参加者の疲労・集中力低下

**症状**:
- Stage2後半でタップ間隔が不規則になる
- 反応時間が遅くなる

**原因**:
- Stage2のサイクル数が多すぎる（現在: stage2_cycles設定次第）
- 休憩なしで長時間実施

**推奨設定**:
```matlab
% BaseExperiment.m: デフォルト設定
obj.stage1_beats = 10;     % 適切
obj.stage2_cycles = 20;    % これは適切か？

% 推奨:
% - パイロット実験: 10-15サイクル
% - 本実験: 20-30サイクル
% - 疲労度に応じて調整
```

**対処法**:
- セッション間に休憩を入れる
- 参加者の状態を観察
- 必要に応じて実験を中断

---

#### エラー11: 参加者ID入力ミス

**症状**:
- データファイル名が不正
- 同じ参加者IDが複数セッションで使われる

**現在の実装**:
```matlab
% HumanHumanExperiment.m: 53-69行
obj.participant1_id = input('参加者1 ID (例: P001): ', 's');
if isempty(obj.participant1_id)
    obj.participant1_id = 'P1_anonymous';
end

obj.participant2_id = input('参加者2 ID (例: P002): ', 's');
if isempty(obj.participant2_id)
    obj.participant2_id = 'P2_anonymous';
end
```

**問題点**:
- タイポのチェックがない
- 重複IDのチェックがない
- ID形式の検証がない

**改善案**:
```matlab
function get_participant_info(obj)
    fprintf('\n=== 参加者情報入力 ===\n');

    % ID形式の検証関数
    validate_id = @(id) ~isempty(regexp(id, '^P\d{3}$', 'once'));

    % 参加者1 ID入力
    while true
        obj.participant1_id = input('参加者1 ID (例: P001): ', 's');
        if isempty(obj.participant1_id)
            obj.participant1_id = 'P1_anonymous';
            break;
        elseif validate_id(obj.participant1_id)
            break;
        else
            fprintf('❌ ID形式が不正です。P + 3桁の数字で入力してください（例: P001）\n');
        end
    end

    % 参加者2 ID入力（同様）
    while true
        obj.participant2_id = input('参加者2 ID (例: P002): ', 's');
        if isempty(obj.participant2_id)
            obj.participant2_id = 'P2_anonymous';
            break;
        elseif validate_id(obj.participant2_id)
            % 重複チェック
            if strcmp(obj.participant2_id, obj.participant1_id)
                fprintf('❌ 参加者1と同じIDです。異なるIDを入力してください。\n');
                continue;
            end
            break;
        else
            fprintf('❌ ID形式が不正です。P + 3桁の数字で入力してください（例: P002）\n');
        end
    end

    % 確認
    fprintf('\n確認:\n');
    fprintf('  参加者1: %s (出力1/2, Sキー)\n', obj.participant1_id);
    fprintf('  参加者2: %s (出力3/4, Cキー)\n', obj.participant2_id);
    confirm = input('この内容でよろしいですか？ (y/n): ', 's');
    if ~strcmp(lower(confirm), 'y')
        fprintf('やり直します...\n');
        obj.get_participant_info();  % 再帰呼び出し
    end
end
```

---

### 2.2 環境関連

#### エラー12: 実験環境の騒音

**症状**:
- 参加者が音が聞こえにくいと訴える
- タップのタイミングがばらつく

**原因**:
- ヘッドフォンの音量が小さい
- 環境騒音が大きい
- ヘッドフォンの遮音性が低い

**対処法**:
- 実験前に音量テストを実施
- 密閉型ヘッドフォンを使用
- 静かな環境で実験を実施

---

#### エラー13: 参加者間の物理的配置

**症状**:
- 参加者同士が視覚的に同期してしまう
- 相手の手の動きが見える

**問題**:
- Human-Human実験は「聴覚的同期」を測定したい
- 視覚情報があると純粋な聴覚同期ではなくなる

**推奨配置**:
```
推奨: 背中合わせまたは仕切りで視覚遮断
避けるべき: 向かい合わせ、横並び
```

---

## 3. データ関連エラー

### 3.1 データ保存エラー

#### エラー14: データ保存先ディレクトリがない

**エラーメッセージ**:
```
Error using writetable
Unable to open file...
```

**原因**:
```matlab
% DataRecorder.m: 183行
save_dir = fullfile(base_dir, obj.experiment_type, date_str, dir_name);

% ディレクトリが存在しない場合
if ~exist(save_dir, 'dir')
    mkdir(save_dir);  % ← これが失敗する可能性
end
```

**対処法**:
```matlab
% 親ディレクトリから順に作成
try
    if ~exist(save_dir, 'dir')
        mkdir(save_dir);
    end
catch ME
    error('DataRecorder:DirCreationFailed', ...
        'ディレクトリ作成失敗: %s\nエラー: %s', save_dir, ME.message);
end
```

---

#### エラー15: ディスク容量不足

**症状**:
- データ保存時にエラー
- MATファイルが破損

**対処法**:
```matlab
% 実験前にディスク容量チェック
function check_disk_space()
    if ismac
        [~, result] = system('df -h . | tail -1');
        fprintf('ディスク容量:\n%s\n', result);
    elseif ispc
        [~, result] = system('wmic logicaldisk get size,freespace,caption');
        fprintf('%s\n', result);
    end

    % 最低1GB空き容量を推奨
    fprintf('警告: 最低1GBの空き容量を確保してください\n');
end
```

---

### 3.2 データ品質エラー

#### エラー16: Stage2データが空

**症状**:
- `stage2_cooperative_taps.csv`にデータがない
- または数行しかない

**原因**:
- 参加者がタップしなかった
- 実験が早期終了した
- エラーで中断した

**対処法**:
```matlab
% BaseExperiment.m: cleanupメソッド
function cleanup(obj)
    try
        % データ保存前に最低限のデータがあるか確認
        if isempty(obj.recorder.data.stage2_data)
            warning('Stage2データが空です！実験が正常に完了していない可能性があります。');
            response = input('それでも保存しますか？ (y/n): ', 's');
            if ~strcmp(lower(response), 'y')
                fprintf('データを保存せずに終了します。\n');
                return;
            end
        end

        obj.recorder.save_data();
    catch ME
        warning('データ保存エラー: %s', ME.message);
    end

    % 以降のクリーンアップ処理
    ...
end
```

---

## 4. 実験デザイン上の問題

### 4.1 統計的検出力不足

**問題**:
- サンプルサイズが小さい（N < 10ペア）
- Stage2サイクル数が少ない（< 20サイクル）

**推奨設定**:
```
パイロット実験:
- N = 3-5ペア
- Stage2 = 10-15サイクル

本実験:
- N = 10-20ペア
- Stage2 = 20-30サイクル
```

---

### 4.2 個人差の問題

**問題**:
- 音楽経験者と非経験者で大きく異なる
- 年齢・性別による違い

**対処法**:
- 事前アンケートで統制変数を記録
- 混合効果モデルで個人差を考慮

---

## 5. 実験チェックリスト

### 実験前（30分前）

```
□ ハードウェア確認
  □ Scarlett 4i4接続確認
  □ ヘッドフォン2セット接続確認
  □ ケーブル接続確認（Ch1/2 → Player1, Ch3/4 → Player2）

□ ソフトウェア確認
  □ MATLAB起動
  □ PsychToolbox動作確認
  □ オーディオデバイス認識確認

□ 音声テスト
  □ Player1ヘッドフォンでStage2音声確認（Player2音のみ聞こえるか）
  □ Player2ヘッドフォンでStage2音声確認（Player1音のみ聞こえるか）
  □ 音量調整（快適な音量か確認）

□ 環境準備
  □ 静かな環境か確認
  □ 参加者配置（背中合わせまたは仕切り）
  □ 椅子の高さ調整

□ データ保存確認
  □ ディスク容量確認（>1GB）
  □ 保存先ディレクトリ確認
```

### 実験開始直前

```
□ 参加者への教示
  □ 実験の目的説明
  □ Stage1/Stage2の説明
  □ キー割り当て確認（Player1=S, Player2=C）
  □ 質疑応答

□ 練習試行
  □ 3-5サイクルの練習
  □ 理解度確認

□ システム最終確認
  □ clear classes; rehash toolboxcache
  □ 不要なアプリケーション終了
  □ Caps Lock オフ確認
  □ 日本語入力モード オフ確認
```

### 実験中

```
□ 観察
  □ 参加者の集中度
  □ タップのタイミング（目視確認）
  □ エラーメッセージの有無

□ メモ
  □ 気づいた点をメモ
  □ 参加者のコメントを記録
```

### 実験終了後

```
□ データ確認
  □ CSVファイルが生成されているか
  □ データの行数が妥当か
  □ タイムスタンプが単調増加しているか

□ 簡易分析
  □ ITI平均値の確認
  □ 異常値の有無

□ デブリーフィング
  □ 参加者の感想聴取
  □ 困難だった点の確認
```

---

## 6. エラー発生時の対処フロー

```
エラー発生
    ↓
メッセージを記録（スクリーンショット推奨）
    ↓
実験を中断すべきか判断
    ├─ Yes → データ保存を試みる → 参加者に謝罪 → 再実験調整
    └─ No  → その場で対処 → 実験続行
```

---

## まとめ

### 最も重要な予防策

1. **実験前チェックリストの厳守**
2. **音声テストの徹底**（特にチャンネル分離）
3. **参加者への丁寧な教示**
4. **データのリアルタイム確認**

### 緊急時連絡先

```
技術的問題: [実験責任者の連絡先]
倫理的問題: [倫理委員会の連絡先]
```

---

**作成日**: 2025-10-09
**次回更新**: パイロット実験完了後、実際のエラー事例を追加
