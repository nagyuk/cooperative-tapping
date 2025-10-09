# 実験準備ロードマップ

**ブランチ**: `experiment/preparation`
**目的**: パイロット実験から本実験までの準備作業を完了し、Human-Humanデータに基づくパラメータ妥当性を確立する

**作成日**: 2025-10-09
**予定期間**: 4-6週間

---

## 全体スケジュール

```
Week 1-2: Phase 1 - パイロット実験準備
Week 2-3: Phase 2 - データ収集と予備分析
Week 4:   Phase 3 - 本実験準備
Week 5:   Phase 4 - 統合とレビュー
Week 6:   Phase 5 - mainへのマージ
```

---

## Phase 1: パイロット実験準備（Week 1-2）

### 目標
- パイロット実験を実施可能な状態にする
- 実験プロトコルの検証

### タスク

#### 1.1 Stage2サイクル数の調整
```
現在の設定: BaseExperiment.m
  obj.stage2_cycles = 20;  % これは適切か？

パイロット実験用の推奨値:
  obj.stage2_cycles = 15;  % 疲労を避けつつ十分なデータ
```

**実装**:
- [ ] BaseExperiment.mでデフォルト値を確認
- [ ] 必要に応じて調整（または設定可能にする）
- [ ] テスト実行で所要時間を確認（目安: 5-10分以内）

---

#### 1.2 教示スクリプトの標準化

**作成するファイル**:
- `docs/instruction_scripts/human_human_instruction.md`

**内容**:
```markdown
# Human-Human実験 教示スクリプト

## 実験開始前の説明

「この実験では、2人で協力してリズムを維持していただきます。

### Stage 1（練習フェーズ - 約20秒）
- 2種類の音が1秒間隔で交互に鳴ります
- 音を聞いて、1秒間隔のリズムを覚えてください
- **この段階ではキーを押す必要はありません**

### Stage 2（協調タッピングフェーズ - 約30秒）
1. Player 1（あなた）がSキーを押してスタートします
2. すると、Player 2に音が聞こえます
3. Player 2はその音に合わせて、その**1秒後**にCキーを押します
4. すると、Player 1に音が聞こえます
5. このように、お互いの音に合わせて**交互**にタップしてください

### ポイント
- 相手の音の1秒後にタップする
- 急がず、ゆっくりで大丈夫です
- リズムが崩れても焦らず、再度合わせてください

何か質問はありますか？」
```

**実装**:
- [ ] 教示スクリプトファイル作成
- [ ] 実験者向けチェックリストに組み込み

---

#### 1.3 練習試行の実装（オプション）

**目的**: 参加者がタスクを理解してから本番を開始

**実装案**:
```matlab
% HumanHumanExperiment.m に追加
function run_practice_trial(obj)
    % 練習試行（3-5サイクル）

    obj.update_display('練習試行を開始します', 'color', [1.0, 0.8, 0.3]);
    pause(2);

    % Stage2のロジックを短縮版で実行
    practice_cycles = 5;

    % ... Stage2と同じロジック ...

    obj.update_display('練習完了！本番を開始します', 'color', [0.2, 1.0, 0.2]);
    pause(2);
end
```

**実装**:
- [ ] 練習試行メソッドの作成
- [ ] execute()フローに組み込み（オプション）
- [ ] テスト実行

---

#### 1.4 実験チェックリストの実地検証

**`docs/human_human_troubleshooting.md`のチェックリストを実際に使用**:

- [ ] 実験前チェックリスト（15項目）を印刷
- [ ] テスト実験で各項目を確認
- [ ] 不足項目を追加
- [ ] 実行順序を最適化

---

#### 1.5 データ品質チェックスクリプトの作成

**作成するファイル**:
- `analysis/check_data_quality.m`

```matlab
function quality = check_data_quality(data_filepath)
    % データ品質チェック
    %
    % Usage:
    %   quality = check_data_quality('data/raw/human_human/.../stage2_cooperative_taps.csv')

    data = readtable(data_filepath);

    quality = struct();

    % 1. データ数チェック
    quality.num_taps = height(data);
    quality.sufficient_data = quality.num_taps >= 20;  % 最低20タップ

    % 2. タイムスタンプ単調性
    timestamps = data.timestamp;
    quality.monotonic = all(diff(timestamps) > 0);

    % 3. 異常値検出
    intervals = diff(timestamps);
    quality.mean_iti = mean(intervals);
    quality.std_iti = std(intervals);
    quality.outliers = sum(abs(intervals - quality.mean_iti) > 3 * quality.std_iti);

    % 4. プレイヤー交互性
    if isfield(data, 'player_id')
        player_sequence = data.player_id;
        expected_alternation = true;
        for i = 2:length(player_sequence)
            if player_sequence(i) == player_sequence(i-1)
                expected_alternation = false;
                break;
            end
        end
        quality.proper_alternation = expected_alternation;
    end

    % 5. 総合判定
    quality.overall = quality.sufficient_data && quality.monotonic && ...
                      (quality.outliers < 3) && quality.proper_alternation;

    % レポート
    fprintf('=== データ品質チェック ===\n');
    fprintf('ファイル: %s\n', data_filepath);
    fprintf('タップ数: %d (%s)\n', quality.num_taps, ...
        iif(quality.sufficient_data, '✅', '❌ 不足'));
    fprintf('タイムスタンプ: %s\n', iif(quality.monotonic, '✅ 単調増加', '❌ 不整合'));
    fprintf('ITI平均: %.3f秒 (SD=%.3f)\n', quality.mean_iti, quality.std_iti);
    fprintf('外れ値: %d個 (%s)\n', quality.outliers, ...
        iif(quality.outliers < 3, '✅', '⚠️  多い'));
    fprintf('交互性: %s\n', iif(quality.proper_alternation, '✅', '❌'));
    fprintf('総合判定: %s\n', iif(quality.overall, '✅ PASS', '❌ FAIL'));
end

function result = iif(condition, true_val, false_val)
    if condition
        result = true_val;
    else
        result = false_val;
    end
end
```

**実装**:
- [ ] スクリプト作成
- [ ] 既存データでテスト
- [ ] 実験フローに組み込み（実験終了直後に自動実行）

---

## Phase 2: データ収集と予備分析（Week 2-3）

### 目標
- パイロット実験実施（N=3-5ペア）
- データ分析スクリプトのテスト
- パラメータの予備的推定

### タスク

#### 2.1 パイロット実験実施

**参加者募集**:
- [ ] N=3-5ペアを募集
- [ ] 実験日時調整
- [ ] 同意書準備（必要に応じて）

**実験実施**:
- [ ] 各ペアで実験を実施
- [ ] チェックリストに従って進行
- [ ] 参加者フィードバックを記録

**データ確認**:
- [ ] 各セッション後にcheck_data_quality.m実行
- [ ] 問題があれば即座に対処

---

#### 2.2 データ分析スクリプトのテスト

**`analysis/estimate_parameters_from_human_data.m`の改良**:

- [ ] パイロットデータで実行
- [ ] 可視化の改善
- [ ] 信頼区間計算の精度向上
- [ ] セッション間変動の分析追加

**追加スクリプト作成**:
- [ ] `analysis/visualize_human_human_data.m` - データ可視化専用
- [ ] `analysis/compare_sessions.m` - セッション間比較

---

#### 2.3 予備的パラメータ推定

**実行**:
```matlab
% パイロットデータから推定
params_pilot = estimate_parameters_from_human_data('data/raw/human_human/');

% 結果を記録
save('analysis/pilot_parameters.mat', 'params_pilot');
```

**分析**:
- [ ] 現在の設定値との比較
- [ ] 個人差・セッション間変動の評価
- [ ] 本実験でのサンプルサイズ決定

---

## Phase 3: 本実験準備（Week 4）

### 目標
- パイロット結果を反映
- 本実験プロトコルの確定

### タスク

#### 3.1 パイロット結果の反映

**パラメータ調整**:
- [ ] パイロット推定値に基づいてデフォルト値を更新
- [ ] `experiments/configs/experiment_config.m` の更新

**プロトコル改善**:
- [ ] 参加者フィードバックを反映
- [ ] 教示スクリプトの改良
- [ ] チェックリストの更新

---

#### 3.2 サンプルサイズ設計

**統計的検出力分析**:
```matlab
% パイロットデータから効果量を推定
effect_size = calculate_effect_size(params_pilot);

% 必要サンプルサイズを計算（α=0.05, power=0.8）
required_n = power_analysis(effect_size, 0.05, 0.8);

fprintf('本実験の推奨サンプルサイズ: N=%d ペア\n', required_n);
```

- [ ] 効果量推定
- [ ] 検出力分析
- [ ] 本実験のN決定（推奨: 10-20ペア）

---

#### 3.3 本実験用ドキュメント整備

**作成するドキュメント**:
- [ ] `docs/main_experiment_protocol.md` - 本実験プロトコル
- [ ] `docs/participant_consent_form.md` - 同意書テンプレート（必要に応じて）
- [ ] `docs/experimenter_manual.md` - 実験者マニュアル

---

## Phase 4: 統合とレビュー（Week 5）

### 目標
- 全変更のテスト
- ドキュメント更新
- レビュー

### タスク

#### 4.1 統合テスト

**テストケース**:
- [ ] Human-Computer実験（各モデル）
- [ ] Human-Human実験（練習試行あり/なし）
- [ ] データ分析パイプライン全体

**エッジケース**:
- [ ] 参加者ID入力エラー処理
- [ ] 実験途中終了
- [ ] データ保存エラー

---

#### 4.2 ドキュメント更新

- [ ] CLAUDE.mdの更新（新機能の追加）
- [ ] README更新（本実験の説明）
- [ ] 変更履歴のまとめ

---

#### 4.3 コードレビュー

**レビュー項目**:
- [ ] コードの可読性
- [ ] エラーハンドリングの網羅性
- [ ] パフォーマンス
- [ ] ドキュメントとの整合性

---

## Phase 5: mainへのマージ（Week 6）

### 目標
- experiment/preparationブランチをmainにマージ
- 本実験実施可能な状態を確立

### タスク

#### 5.1 最終確認

- [ ] 全機能が動作することを確認
- [ ] ドキュメントが最新であることを確認
- [ ] データ分析パイプラインが完成していることを確認

---

#### 5.2 マージ準備

```bash
# 最新のmainを取り込む
git checkout experiment/preparation
git fetch origin
git merge origin/main

# 競合があれば解決
# テストを再実行

# コミット履歴を整理（必要に応じて）
git log --oneline
```

- [ ] mainブランチの最新状態を取り込み
- [ ] 競合解決
- [ ] 最終テスト

---

#### 5.3 Pull Requestとマージ

```bash
# GitHub上でPull Request作成
# レビュー後、mainにマージ

# または直接マージ
git checkout main
git merge experiment/preparation
git push origin main
```

- [ ] Pull Request作成
- [ ] レビュー（self-review可）
- [ ] mainにマージ
- [ ] タグ付け（v2.0.0-experiment-ready など）

---

## 成功指標

このブランチが完了時に達成すべき状態：

### 技術的指標
- ✅ パイロット実験データ（N=3-5ペア）収集完了
- ✅ パラメータ推定スクリプトが動作
- ✅ データ品質チェックが自動化
- ✅ 全エラーケースに対処

### ドキュメント指標
- ✅ 実験プロトコルが標準化
- ✅ 教示スクリプトが完成
- ✅ チェックリストが検証済み
- ✅ 分析パイプラインがドキュメント化

### 科学的指標
- ✅ パラメータの予備的推定値を取得
- ✅ 本実験のサンプルサイズ決定
- ✅ 個人差・セッション間変動を定量化

---

## リスク管理

### リスク1: パイロット参加者が集まらない
**対策**:
- 早めに募集開始
- インセンティブ提供
- オンライン実施の検討

### リスク2: データ品質が低い
**対策**:
- チェックリストの厳守
- 実験者トレーニング
- 技術的問題の事前確認

### リスク3: スケジュール遅延
**対策**:
- 各Phaseの期限を明確化
- 優先順位付け（必須 vs オプション）
- 必要に応じて範囲を縮小

---

## 進捗管理

### 週次レビュー
- 毎週金曜日に進捗確認
- 次週のタスク明確化
- リスクの再評価

### マイルストーン
- Week 2 終了時: パイロット実験準備完了
- Week 3 終了時: パイロットデータ収集完了
- Week 4 終了時: 本実験プロトコル確定
- Week 5 終了時: 統合テスト完了
- Week 6 終了時: mainへのマージ

---

## 次のステップ

**今すぐ始めるべきこと**:
1. [ ] このロードマップをレビュー
2. [ ] Phase 1のタスク1.1（Stage2サイクル数）から着手
3. [ ] 週次レビューの日時を決定

**準備が整ったら**:
- パイロット実験の参加者募集を開始
- 実験室・機材の予約

---

**作成日**: 2025-10-09
**ブランチ**: experiment/preparation
**次回更新**: Phase 1完了時
