#!/usr/bin/env python3
"""
オーディオファイルとバックエンドのテストスクリプト
音声ファイルのパスとバックエンドの設定をチェックします
"""
import os
import sys

# PsychoPyのオーディオ設定を先に行う
from psychopy import prefs
# サウンドバックエンドの優先順位を設定（pygameを最優先）
prefs.hardware['audioLib'] = ['pygame', 'sounddevice', 'pyo', 'ptb']

# その他のpsychopyモジュールをインポート
from psychopy import sound

def check_audio_files():
    """オーディオファイルの存在とパスをチェックする"""
    # 実行ディレクトリを基準にします
    base_dir = os.path.dirname(os.path.abspath(__file__))
    
    # 設定されているファイルパス
    sound_dir = os.path.join(base_dir, 'assets', 'sounds')
    wav_files = [
        os.path.join(sound_dir, 'button02a.wav'),
        os.path.join(sound_dir, 'button03a.wav')
    ]
    mp3_files = [
        os.path.join(sound_dir, 'button02a.mp3'),
        os.path.join(sound_dir, 'button03a.mp3')
    ]
    
    print("===== オーディオファイルチェック =====")
    
    # ディレクトリ存在チェック
    print(f"サウンドディレクトリ: {sound_dir}")
    if os.path.exists(sound_dir):
        print("✓ サウンドディレクトリは存在します")
    else:
        print("✗ サウンドディレクトリが見つかりません")
        return False
    
    # ファイル存在チェック
    print("\nWAVファイルチェック:")
    for wav_file in wav_files:
        if os.path.exists(wav_file):
            print(f"✓ ファイルが存在します: {wav_file}")
        else:
            print(f"✗ ファイルが見つかりません: {wav_file}")
    
    print("\nMP3ファイルチェック:")
    for mp3_file in mp3_files:
        if os.path.exists(mp3_file):
            print(f"⚠ MP3ファイルが存在します: {mp3_file}")
        else:
            print(f"- MP3ファイルがありません: {mp3_file}")
    
    # 容量チェック
    print("\nファイル容量チェック:")
    for file_path in wav_files + mp3_files:
        if os.path.exists(file_path):
            size_kb = os.path.getsize(file_path) / 1024
            print(f"{os.path.basename(file_path)}: {size_kb:.1f} KB")
    
    return True

def check_audio_backend():
    """PsychoPyの音声バックエンドをチェックする"""
    print("\n===== 音声バックエンド情報 =====")
    
    # 設定された優先順位
    print(f"設定されたバックエンド優先順位: {prefs.hardware['audioLib']}")
    
    # 実際に使用されているバックエンド
    if hasattr(sound, 'audioLib'):
        print(f"使用中の音声バックエンド: {sound.audioLib}")
    else:
        print("音声バックエンド情報が取得できません")
    
    # バックエンドのテスト
    print("\n音声バックエンドのテスト:")
    try:
        # 簡単なテスト音を作成
        test_sound = sound.Sound(440, secs=0.1)
        print("✓ サウンドオブジェクト作成成功")
        
        # バックエンド情報の表示
        if hasattr(test_sound, '_snd'):
            print(f"音声オブジェクトの種類: {type(test_sound._snd).__name__}")
        
        return True
    except Exception as e:
        print(f"✗ サウンドオブジェクト作成に失敗: {e}")
        return False

def test_sound_files():
    """WAVファイルの読み込みをテストする"""
    # 実行ディレクトリを基準にします
    base_dir = os.path.dirname(os.path.abspath(__file__))
    sound_dir = os.path.join(base_dir, 'assets', 'sounds')
    
    wav_files = [
        os.path.join(sound_dir, 'button02a.wav'),
        os.path.join(sound_dir, 'button03a.wav')
    ]
    
    print("\n===== WAVファイル読み込みテスト =====")
    
    for wav_file in wav_files:
        if not os.path.exists(wav_file):
            print(f"✗ ファイルが見つかりません: {wav_file}")
            continue
        
        try:
            print(f"ファイル読み込み中: {os.path.basename(wav_file)}")
            wav_sound = sound.Sound(wav_file)
            print(f"✓ 読み込み成功: {os.path.basename(wav_file)}")
        except Exception as e:
            print(f"✗ 読み込み失敗: {e}")
            return False
    
    return True

if __name__ == "__main__":
    print("音声システムテスト開始")
    
    # ファイルチェック
    if not check_audio_files():
        print("\n✗ オーディオファイルチェックに失敗しました")
        sys.exit(1)
    
    # バックエンドチェック
    if not check_audio_backend():
        print("\n✗ 音声バックエンドチェックに失敗しました")
        sys.exit(1)
    
    # WAVファイル読み込みテスト
    if not test_sound_files():
        print("\n✗ WAVファイル読み込みテストに失敗しました")
        sys.exit(1)
    
    print("\n✓ すべてのテストに成功しました！")
    sys.exit(0)
