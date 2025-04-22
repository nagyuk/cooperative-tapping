import os
import soundfile as sf
import librosa

# 変換する音声ファイル
files = ['button02a.mp3', 'button03a.mp3']

for file in files:
    # ファイルパス
    input_path = os.path.join('assets/sounds', file)
    output_path = os.path.join('assets/sounds', file.replace('.mp3', '_new.wav'))
    
    try:
        # MP3ファイルを読み込む
        print(f"Loading {input_path}...")
        y, sr = librosa.load(input_path, sr=44100)
        
        # WAVファイルとして保存
        print(f"Saving as {output_path}...")
        sf.write(output_path, y, sr, format='WAV')
        
        print(f"Successfully converted {file} to WAV format.")
    except Exception as e:
        print(f"Error converting {file}: {e}")

print("Conversion completed.")
