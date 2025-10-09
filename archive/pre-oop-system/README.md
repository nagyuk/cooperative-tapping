# Pre-OOP System Archive

このディレクトリには、OOPリファクタリング以前のモノリシックな実験システムが保存されています。

## アーカイブ日

2025-10-09

## 含まれるファイル

- `main_experiment.m` - モノリシックな実験システム（2025-10-07最終版）
- `run_experiment.m` - エントリポイントスクリプト

## システムの特徴

### 🎯 機能
- 人間-コンピュータ協調タッピング実験
- PsychPortAudio統合
- SEA/Bayesian/BIBモデル対応
- 高精度タイミング制御

### ✅ 達成事項（2025-10-07）
1. **PsychPortAudio完全移行**: `sound()`から高精度オーディオシステムへ
2. **完璧なタイミング精度**: 不規則リズム問題の解消
3. **統一タイムスタンプ**: 20秒以上のタイミングオフセット問題の解決
4. **プロダクション品質**: Scarlett 4i4統合で6.8ms遅延達成

### ⚠️ 制限事項
- **モノリシック構造**: 単一の大きなスクリプトファイル（800行以上）
- **コードの重複**: 人間-人間実験は別実装が必要
- **保守性の低さ**: 機能追加が困難
- **再利用性の欠如**: 共通機能の抽出が不可能

## なぜアーカイブされたか

### OOPリファクタリングの動機（2025-10-09）

1. **保守性の向上**
   - BaseExperimentによる共通機能の抽出
   - 実験タイプ別のクラス分離

2. **コードの再利用性**
   - AudioSystem, TimingController, DataRecorderの分離
   - 複数の実験タイプで共通コンポーネントを共有

3. **拡張性の確保**
   - 新しい実験タイプの追加が容易
   - 新しいモデルの追加が容易

4. **テスタビリティ**
   - コンポーネント単位でのテストが可能
   - モックオブジェクトの利用が可能

## 移行先システム

### 新しいOOPアーキテクチャ

```
run_unified_experiment.m
├── BaseExperiment (abstract)
│   ├── AudioSystem
│   ├── TimingController
│   └── DataRecorder
├── HumanComputerExperiment
│   └── Models (SEA/Bayesian/BIB)
└── HumanHumanExperiment
```

詳細は `/CLAUDE.md` を参照してください。

## このシステムを使用する場合

**注意**: このシステムは機能的には動作しますが、メンテナンスされていません。

### 使用方法
```matlab
% レガシーシステムを実行（推奨されません）
run('archive/pre-oop-system/run_experiment.m')
```

### 推奨
代わりに統合OOPシステムを使用してください：
```matlab
clear classes; rehash toolboxcache
run_unified_experiment
```

## 技術的詳細

### データ互換性
- **CSV形式**: 新システムと互換性あり
- **MAT形式**: データ構造が若干異なる

### 主な違い

| 項目 | Pre-OOP | OOP System |
|------|---------|------------|
| エントリポイント | `run_experiment.m` | `run_unified_experiment.m` |
| 実験タイプ | Human-Computerのみ | Human-Computer + Human-Human |
| アーキテクチャ | モノリシック | OOP（継承・カプセル化） |
| コード行数 | ~800行（1ファイル） | ~200行/クラス（モジュール化） |
| テスト | なし | テストスイートあり |
| ドキュメント | コメントのみ | CLAUDE.md + docs/ |

## 参考資料

- **OOPリファクタリングコミット**: `016297c`
- **最終動作確認日**: 2025-10-07
- **アーカイブ理由**: OOP移行完了、保守性向上のため

---

**このシステムは歴史的参考資料として保存されています。**
**新規開発には統合OOPシステムを使用してください。**
