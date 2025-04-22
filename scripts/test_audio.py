#!/usr/bin/env python
"""
音声エンジンのテストスクリプト

このスクリプトは、PsychoPyの音声バックエンドをテストし、
どのエンジンが動作するかを確認します。
"""

import os
import sys
import time

# 親ディレクトリをパスに追加
parent_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, parent_dir)

# PsychoPyのプリファレンスを先に設定
from psychopy import prefs

# 各種バックエンドを個別にテスト
def test_audio_backends():
    # 利用可能なバックエンド
    backends = ['pygame', 'sounddevice', 'pyo', 'ptb']
    
    print("\n===== 音声バックエンドのテスト =====")
    print("各バックエンドを個別にテストします...\n")
    
    # 設定をリセット
    if 'audioLib' in prefs.hardware:
        original_backend = prefs.hardware['audioLib']
    else:
        original_backend = []
    
    for backend in backends:
        print(f"\n--- {backend} のテスト ---")
        
        # バックエンドを設定
        prefs.hardware['audioLib'] = [backend]
        
        try:
            # この時点でsoundモジュールをインポート
            from psychopy import sound
            
            print(f"バックエンド '{backend}' を読み込みました")
            
            # 現在のバックエンドを確認
            if hasattr(sound, 'audioLib'):
                print(f"実際に使用されているバックエンド: {sound.audioLib}")
            else:
                print("警告: 音声バックエンド情報は取得できません")
            
            # WAVファイルのパスを設定
            base_dir = parent_dir
            sound_dir = os.path.join(base_dir, 'assets', 'sounds')
            wav_file = os.path.join(sound_dir, 'button02a.wav')
            
            if not os.path.exists(wav_file):
                print(f"エラー: ファイルが見つかりません: {wav_file}")
                continue
            
            print(f"テスト用ファイル: {wav_file}")
            
            # 音声オブジェクトの作成
            try:
                # 方法1: 標準の初期化
                print("方法1: 標準初期化...")
                s1 = sound.Sound(wav_file)
                print("  成功: 標準初期化")
                try:
                    s1.play()
                    print("  音声再生成功")
                    time.sleep(1)  # 音声を聞くための待機
                except Exception as e:
                    print(f"  エラー: 再生に失敗: {e}")
            except Exception as e:
                print(f"  エラー: 標準初期化に失敗: {e}")
            
            try:
                # 方法2: 値による初期化
                print("方法2: 値による初期化...")
                s2 = sound.Sound(value=wav_file)
                print("  成功: 値による初期化")
                try:
                    s2.play()
                    print("  音声再生成功")
                    time.sleep(1)  # 音声を聞くための待機
                except Exception as e:
                    print(f"  エラー: 再生に失敗: {e}")
            except Exception as e:
                print(f"  エラー: 値による初期化に失敗: {e}")
            
            try:
                # 方法3: トーン生成
                print("方法3: トーン生成...")
                s3 = sound.Sound(value='C', secs=0.5)
                print("  成功: トーン生成")
                try:
                    s3.play()
                    print("  トーン再生成功")
                    time.sleep(1)  # 音声を聞くための待機
                except Exception as e:
                    print(f"  エラー: トーン再生に失敗: {e}")
            except Exception as e:
                print(f"  エラー: トーン生成に失敗: {e}")
                
        except Exception as e:
            print(f"バックエンド '{backend}' の読み込みに失敗: {e}")
        
        # 使用済みモジュールをアンロード
        if 'sound' in sys.modules:
            del sys.modules['sound']
    
    # 元の設定に戻す
    prefs.hardware['audioLib'] = original_backend
    print("\n===== テスト完了 =====")

if __name__ == "__main__":
    test_audio_backends()
