"""
簡易サウンドテストスクリプト
WAV形式のサウンドファイルのテストと動作確認を行います
"""
import os
import time
from psychopy import sound, core

def main():
    print("サウンドテストを開始します...")
    
    # ファイルパスの確認
    sound_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'assets', 'sounds')
    sound_stim = os.path.join(sound_dir, 'button02a.wav')
    sound_player = os.path.join(sound_dir, 'button03a.wav')
    
    print(f"刺激音ファイル: {sound_stim}")
    print(f"プレイヤー音ファイル: {sound_player}")
    
    # ファイル存在確認
    if not os.path.exists(sound_stim):
        print(f"エラー: 刺激音ファイルが見つかりません: {sound_stim}")
        return
    
    if not os.path.exists(sound_player):
        print(f"エラー: プレイヤー音ファイルが見つかりません: {sound_player}")
        return
    
    print("ファイルの存在を確認しました")
    
    # サウンドオブジェクトの作成
    try:
        print("刺激音オブジェクトを作成中...")
        stim_sound = sound.Sound(sound_stim)
        
        print("プレイヤー音オブジェクトを作成中...")
        player_sound = sound.Sound(sound_player)
        
        print("サウンドオブジェクトの作成に成功しました")
    except Exception as e:
        print(f"サウンドオブジェクトの作成中にエラーが発生しました: {e}")
        return
    
    # 再生テスト
    try:
        print("刺激音を再生します...")
        stim_sound.play()
        time.sleep(1)
        
        print("プレイヤー音を再生します...")
        player_sound.play()
        time.sleep(1)
        
        print("すべての音を停止します...")
        stim_sound.stop()
        player_sound.stop()
        
        print("再生テスト完了")
    except Exception as e:
        print(f"再生テスト中にエラーが発生しました: {e}")
        return
    
    # 連続再生テスト
    try:
        print("連続再生テストを開始します...")
        for i in range(5):
            print(f"刺激音を再生 {i+1}/5...")
            
            # 既に再生中なら停止してから再生
            if hasattr(stim_sound, 'status') and stim_sound.status == 1:
                stim_sound.stop()
            
            stim_sound.play()
            time.sleep(0.2)  # 短い間隔
        
        time.sleep(1)
        print("連続再生テスト完了")
    except Exception as e:
        print(f"連続再生テスト中にエラーが発生しました: {e}")
    
    print("すべてのテストが完了しました")

if __name__ == "__main__":
    main()
