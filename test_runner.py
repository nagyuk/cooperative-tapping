#!/usr/bin/env python3
"""
テスト用スクリプト - cooperative tapping実験の基本機能をテスト
"""
import sys
from src.config import Config
from src.experiment.runner import ExperimentRunner

def main():
    """実験の基本機能をテスト"""
    print("Cooperative Tapping Task テスト開始")
    
    # 設定を作成
    config = Config()
    # テスト用にバッファとステージ数を小さくする
    config.STAGE1 = 3  # ステージ1のタップ数を少なくする
    config.STAGE2 = 5  # ステージ2のタップ数を少なくする
    config.BUFFER = 1  # バッファも小さくする
    
    # 各モデルをテスト
    for model_type in ['sea', 'bayes', 'bib']:
        try:
            print(f"\n{model_type.upper()}モデルのテスト:")
            
            # 実験を初期化
            experiment = ExperimentRunner(config, model_type=model_type)
            
            # 内部状態の確認
            print(f"  データ構造初期化: stim_tap={len(experiment.stim_tap)}, player_tap={len(experiment.player_tap)}")
            print(f"  フルデータ構造: full_stim_tap={len(experiment.full_stim_tap)}, full_player_tap={len(experiment.full_player_tap)}")
            
            # 仮のタップデータを追加
            for i in range(3):
                # Stage1のタップ
                experiment.stim_tap.append(i * 2.0)  # 2秒ごと
                experiment.full_stim_tap.append(i * 2.0)
                experiment.player_tap.append(i * 2.0 + 0.1)  # 少しずれたタイミング
                experiment.full_player_tap.append(i * 2.0 + 0.1)
            
            for i in range(5):
                # Stage2のタップ
                experiment.stim_tap.append(10 + i * 2.0)
                experiment.full_stim_tap.append(10 + i * 2.0)
                experiment.player_tap.append(10 + i * 2.0 + 0.1)
                experiment.full_player_tap.append(10 + i * 2.0 + 0.1)
            
            # 安全なSE計算をテスト
            if len(experiment.player_tap) >= 2 and len(experiment.stim_tap) > 0:
                se = experiment.stim_tap[-1] - (experiment.player_tap[-1] + experiment.player_tap[-2])/2
                experiment.stim_se.append(se)
                print(f"  SE計算テスト: {se}")
            
            # 保存処理のテスト
            print("  データ保存処理テスト...")
            experiment._save_data()
            print("  保存完了")
            
            print(f"{model_type.upper()}モデルのテスト成功")
            
        except Exception as e:
            print(f"エラー発生: {e}")
            return 1
    
    print("\nすべてのテスト完了")
    return 0

if __name__ == "__main__":
    sys.exit(main())
