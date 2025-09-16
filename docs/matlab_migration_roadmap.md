# MATLAB移行ロードマップ

## 概要

このドキュメントは、協調タッピング実験システムをPsychoPy（Python）からMATLABへ移行するための詳細な技術検討とロードマップを記述しています。

## 移行の背景と目的

### 移行理由
- **統一プラットフォーム**: 研究室でのMATLAB標準化
- **分析統合**: データ収集から解析まで単一環境での実現
- **メンテナンス性向上**: 依存関係の簡素化
- **ミリ秒精度維持**: 実験要求仕様の継続

### 現在のPsychoPy実装の分析

#### 主要機能要素
1. **高精度タイミング系**
   - PTB（Psychophysics Toolbox）ベースの音声再生
   - ミリ秒精度のクロック制御（`core.Clock()`）
   - プロセス優先度の最適化
   - ガベージコレクション制御

2. **実験制御系**
   - ノンブロッキングキーボード入力（`event.getKeys()`）
   - リアルタイムイベントループ
   - 二段階実験フロー（Stage1: メトロノーム、Stage2: 適応的タッピング）

3. **データ処理系**
   - リアルタイムデータ収集
   - 同期エラー・ITI計算
   - 構造化CSVデータ保存

#### 現在のデータ構造
```
data/raw/YYYYMMDD_user_id/model_timestamp/
├── raw_taps.csv                    # 全タップデータ（Stage1+2）
├── processed_taps.csv              # Stage2のみ（バッファ処理済）
├── stim_synchronization_errors.csv
├── player_synchronization_errors.csv  
├── stim_intertap_intervals.csv
├── player_intertap_intervals.csv
├── *_iti_variations.csv
├── *_se_variations.csv
├── model_hypotheses.csv            # ベイズモデル用
├── experiment_config.csv
└── data_metadata.csv
```

## MATLAB環境でのミリ秒精度実現手法

### 技術的選択肢の比較

| 手法 | 理論精度 | 実用精度 | レイテンシー | 安定性 | 学習コスト | 外部依存 |
|-----|----------|----------|-------------|--------|------------|----------|
| **Audio System Toolbox** | 0.02ms | 0.1-1ms | 1-5ms | ★★★★★ | 低 | なし |
| **tic/toc + posixtime** | 1μs | 0.1-0.5ms | <0.1ms | ★★★★☆ | 最低 | なし |
| **PsychoPy PTB** | 0.1ms | 0.5-2ms | 5-20ms | ★★★★★ | 中 | PTB |
| **Java nanoTime** | 1ns | 0.01-0.1ms | <0.1ms | ★★★☆☆ | 高 | JVM |

### 推奨技術スタック

#### **第一推奨: Audio System Toolbox + posixtime**

**音声制御:**
```matlab
% 低レイテンシー音声環境
deviceWriter = audioDeviceWriter('SampleRate', 48000, ...
                                'BufferSize', 64, ...
                                'Driver', 'ASIO');  % 可能ならASIO
```

**タイミング計測:**
```matlab
% マイクロ秒精度タイミング
function timestamp = getHighResTime()
    timestamp = posixtime(datetime('now', 'TimeZone', 'local'));
end
```

**技術的利点:**
- **同等以上の精度**: PTBと同程度またはそれ以上（1-5ms）
- **純粋MATLAB**: 外部依存なし、メンテナンス容易
- **将来性**: MathWorks長期サポート保証
- **学習コスト低**: 既存MATLAB知識で対応可能

## 段階的移行ロードマップ

### **Phase 1: 技術検証・環境構築** (2-3週間)

#### 1.1 音声システム性能検証
- Audio System Toolboxでのレイテンシー測定実験
- 実際の遅延測定とPython版との比較
- ASIO/Core Audioドライバーとの統合テスト

#### 1.2 タイミング精度検証
```matlab
% マイクロ秒精度テスト
for i = 1:1000
    t1 = posixtime(datetime('now'));
    pause(0.001);  % 1ms待機
    t2 = posixtime(datetime('now'));
    measured(i) = (t2 - t1) * 1000;  % ms単位
end
% 精度分析: mean, std, histogram
```

#### 1.3 キーボード入力システム
- ノンブロッキング入力の実装検証
- KbCheckを使用したリアルタイム入力システム

### **Phase 2: コア実験システム開発** (3-4週間)

#### 2.1 実験制御フレームワーク
```matlab
classdef CooperativeTappingMATLAB < handle
    properties
        config
        audioWriter
        tapTimes
        stimTimes
    end
    
    methods
        function obj = CooperativeTappingMATLAB(config)
            obj.config = config;
            obj.setupAudio();
        end
        
        function setupAudio(obj)
            obj.audioWriter = audioDeviceWriter(...
                'SampleRate', 48000, ...
                'BufferSize', 64);
        end
    end
end
```

#### 2.2 Stage1/2の実装
- **Stage1**: メトロノーム実装（固定間隔タッピング）
- **Stage2**: 適応的タイミング制御（モデルベース予測）
- **リアルタイムSE計算**: Python版と同一アルゴリズム

#### 2.3 データ収集・保存システム
- **構造化CSV保存**: Python版と完全互換
- **リアルタイム検証**: データ整合性チェック
- **メタデータ管理**: 実験設定と結果の紐付け

### **Phase 3: モデル移植・統合** (2-3週間)

#### 3.1 適応モデル実装
```matlab
classdef SEAModel < handle
    methods
        function nextInterval = predictNext(obj, syncError)
            % SEA (Synchronization Error Averaging) モデルロジック
            % 同期エラーの平均化による次回間隔予測
        end
    end
end

classdef BayesModel < handle
    methods  
        function nextInterval = inference(obj, syncError)
            % ベイズ推論による適応的タイミング制御
        end
    end
end

classdef BIBModel < handle
    methods
        function nextInterval = flexibleInference(obj, syncError)
            % BIB (Bayesian-Inverse Bayesian) モデル
            % 柔軟な信念システムによる適応制御
        end
    end
end
```

#### 3.2 精度検証・調整
- **Python版との結果比較**: 数値計算結果の一致確認
- **タイミング精度の実測値確認**: 実際の実験環境での性能測定
- **必要に応じた微調整**: パラメータ最適化

### **Phase 4: 統合テスト・完成** (2-3週間)

#### 4.1 パフォーマンステスト
- **長時間実験での安定性**: メモリリーク、CPU使用率監視
- **メモリ使用量最適化**: 大量データ処理の効率化
- **精度維持確認**: 実験全体を通じたタイミング精度

#### 4.2 ユーザビリティ向上
- **エラーハンドリング**: 異常状況での適切な処理
- **進捗表示**: 実験進行状況の可視化
- **設定ファイル管理**: 実験パラメータの外部化

## データ互換性保証

### CSV読み書き対応
- **readtable/writetable**: PythonのPandasと同等機能
- **同一フォーマット維持**: 列名・データ型の完全一致
- **日時形式統一**: MATLAB datetime ↔ Python datetime

### 数値精度保証
- **double精度維持**: タイムスタンプの精度確保
- **数値フォーマット**: 小数点以下桁数の統一
- **欠損値処理**: NaN処理の一貫性

### メタデータ互換性
- **実験設定**: JSON/CSV形式での設定値保存
- **バージョン情報**: MATLAB版識別子追加
- **処理履歴**: データ処理ステップの記録

## 実験要求仕様との適合性

### 協調タッピング実験での精度要求
- **人間の反応時間**: 150-300ms
- **リズム知覚精度**: 10-50ms程度  
- **実験で求められる精度**: 1-5ms程度で十分
- **提案手法の実現精度**: 0.1-1ms（要求を上回る）

### タイミング制御の妥当性
現在のPTB使用での実測値（2-10ms）に対し、Audio System Toolboxでは1-5msの実現が期待できるため、実験精度要求を十分満たします。

## 期待される効果

### 技術的効果
- **精度向上**: より低レイテンシーでの音声制御
- **安定性向上**: MATLAB統合環境での信頼性
- **保守性向上**: 外部依存削減による長期保守の容易化

### 運用面の効果
- **学習コスト削減**: MATLAB標準機能による習得容易性
- **開発効率向上**: 統合開発環境での開発・デバッグ
- **コスト削減**: 追加ライセンス不要

### 研究面の効果  
- **分析統合**: データ収集から解析まで単一環境
- **再現性向上**: 標準化された実験環境
- **拡張性**: MATLAB豊富な数値計算・可視化機能

## 推定総期間とリソース

**総期間: 9-13週間** (従来PTB使用想定より2-3週間短縮)

**期間短縮の理由:**
1. **外部依存削減**: PTB不要による環境構築簡素化
2. **MATLAB標準機能**: 学習コスト・実装コスト削減
3. **直接的移植**: 複雑な統合作業が不要
4. **メンテナンス性向上**: 長期保守負荷軽減

## 結論

**Audio System Toolbox + posixtime**による実装が、ミリ秒精度要求を満たしながら保守性・将来性を両立する最適解です。この手法により、現在の実験精度を維持・向上させつつ、より効率的で持続可能な研究環境を構築できます。

---

*作成日: 2024年12月*  
*対象システム: MATLAB R2020b以降, Audio System Toolbox*