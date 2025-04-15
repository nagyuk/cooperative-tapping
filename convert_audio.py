#!/usr/bin/env python3
"""
MP3からWAVへの直接コピー
MP3ファイルのままでPsychoPyの設定を変更する方針に変更
"""
import os
import shutil

def create_wav_copy(mp3_path, wav_path):
    """MP3ファイルをWAVファイルとしてコピーする。
    
    実際の変換はできないため、拡張子だけ変更したコピーを作成します。
    これは一時的な対応策であり、本来は適切な変換が必要です。

    Args:
        mp3_path: MP3ファイルのパス
        wav_path: 出力するWAVファイルのパス
    """
    print(f"Creating WAV copy of {mp3_path} as {wav_path}...")
    
    try:
        # ファイルをコピー
        shutil.copy2(mp3_path, wav_path)
        
        print(f"Copy complete: {os.path.getsize(wav_path)} bytes")
    except Exception as e:
        print(f"Error creating WAV copy of {mp3_path}: {e}")

if __name__ == "__main__":
    # プロジェクトのルートディレクトリ
    root_dir = os.path.dirname(os.path.abspath(__file__))
    
    # 音声ファイルのディレクトリ
    sounds_dir = os.path.join(root_dir, "assets", "sounds")
    
    # 変換対象のファイル
    files_to_convert = [
        ("button02a.mp3", "button02a.wav"),
        ("button03a.mp3", "button03a.wav")
    ]
    
    # ファイルをコピー
    for mp3_file, wav_file in files_to_convert:
        mp3_path = os.path.join(sounds_dir, mp3_file)
        wav_path = os.path.join(sounds_dir, wav_file)
        
        # MP3ファイルが存在するか確認
        if os.path.exists(mp3_path):
            create_wav_copy(mp3_path, wav_path)
        else:
            print(f"Error: {mp3_path} does not exist")
