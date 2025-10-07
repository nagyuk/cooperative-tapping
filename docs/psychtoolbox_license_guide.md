# PsychToolbox ライセンス問題と対処法

## 🚨 現在の状況

**PsychToolbox 3.0.22.1の状況**:
- ✅ **ダウンロード・インストール完了**: 94.4MB
- ❌ **ライセンス未設定**: "not licensed for use on this machine"
- 🔄 **GStreamer 1.26.5インストール中**: Homebrew経由

## 📋 ライセンス情報

### **価格体系**
- **14日間無料トライアル**: 初回のみ
- **商用ライセンス**: 有料（価格は公式サイト参照）
- **Linux版**: 引き続き無料

### **ライセンス管理方式**
- インターネット接続必須（初回認証）
- オフライン使用：数日間限定
- 定期的な認証確認：数時間ごと

## 🛠 対処方法

### **Method 1: 14日間無料トライアル開始**

```matlab
% MATLABを開いて対話的に実行
PsychLicenseHandling('Setup')

% 手順:
% 1. ライセンス管理への同意
% 2. "Start Free Trial"を選択
% 3. 14日間無料トライアル開始
```

### **Method 2: コマンドライン準備**

現在の問題: **インタラクティブ入力が必要**
- `PsychLicenseHandling('Setup')`は対話式
- コマンドライン実行では入力不可

**解決方法**:
1. **MATLAB GUIで直接実行**
2. **事前設定ファイル作成**（高度）

### **Method 3: 古いバージョン使用**

**代替案**: PsychToolbox 3.0.19以前
- ライセンス制限なし
- MATLAB R2025a対応性要確認
- 機能制限の可能性

## 🎯 推奨アプローチ

### **即座実行可能な方法**

1. **MATLAB GUI起動**
```bash
/Applications/MATLAB_R2025a.app/bin/matlab
```

2. **対話的ライセンス設定**
```matlab
% MATLAB Command Windowで実行
PsychLicenseHandling('Setup')
```

3. **14日間トライアル開始**
   - ライセンス管理同意
   - 無料トライアル選択
   - インターネット認証完了

### **認証完了後の確認**

```matlab
% ライセンス状態確認
active = PsychLicenseHandling('IsLicensed')

% PsychPortAudio動作確認
InitializePsychSound(1);
devices = PsychPortAudio('GetDevices');
fprintf('音声デバイス数: %d\n', length(devices));
```

## 📊 コスト vs ベネフィット分析

### **14日間無料トライアル**
- ✅ **即座利用可能**
- ✅ **全機能アクセス**
- ✅ **555ms遅延問題解決**
- ⚠️ **14日間制限**

### **商用ライセンス購入**
- ✅ **永続利用**
- ✅ **研究品質システム**
- ✅ **論文発表可能品質**
- 💰 **投資必要**

### **代替手段（無料）**
- **Pure MATLAB**: 遅延問題残存
- **Python + PyAudio**: 実装工数大
- **C++ + ASIO**: 専門知識必要

## 🚀 次のステップ

### **即座実行推奨**:
1. **GStreamerインストール完了確認**
2. **MATLAB GUI起動**
3. **PsychLicenseHandling('Setup')実行**
4. **14日間トライアル開始**
5. **Scarlett 4i4動作確認**

**この14日間で**:
- 高精度音声システム実装
- Stage1遅延問題根本解決
- 人間同士協調実験完成
- 商用ライセンス購入検討

---

**💡 重要**: 14日間という制限はありますが、この期間でシステムの真価を確認し、投資判断を行うには十分です。研究用途であれば、ライセンス投資の価値は非常に高いです。