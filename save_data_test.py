#!/usr/bin/env python3
"""
データ保存テスト
"""
import os
import sys
import numpy as np

print("データ保存テスト開始")

try:
    from src.config import Config
    from src.experiment.runner import ExperimentRunner
    
    # 設定の作成
    config = Config()
    
    # ExperimentRunnerの初期化
    model_type = 'sea'  # シンプルな例としてSEAモデルを使用
    experiment = ExperimentRunner(config, model_type=model_type)
    
    print("ExperimentRunner初期化成功")
    
    # サンプルデータの作成
    # Stage1のデータ (3タップ)
    for i in range(3):
        experiment.full_stim_tap.append(i * 2.0)
        experiment.full_player_tap.append(i * 2.0 + 0.1)
    
    # Stage2のデータ (5タップ)
    for i in range(5):
        tap_time = 10 + i * 2.0
        experiment.stim_tap.append(tap_time)
        experiment.full_stim_tap.append(tap_time)
        
        player_time = tap_time + 0.1
        experiment.player_tap.append(player_time)
        experiment.full_player_tap.append(player_time)
    
    # SEとITIのサンプルデータ
    for i in range(5):
        experiment.stim_se.append(0.1 + i * 0.01)
        experiment.player_se.append(0.05 + i * 0.01)
        experiment.stim_iti.append(1.9 + i * 0.02)
        experiment.player_iti.append(2.0 + i * 0.02)
    
    # 変動量のサンプルデータ
    for i in range(4):
        experiment.stim_itiv.append(0.02)
        experiment.player_itiv.append(0.02)
        experiment.stim_sev.append(0.01)
        experiment.player_sev.append(0.01)
    
    # データ保存関数のテスト
    print("データ保存の実行...")
    experiment._save_data()
    
    # 保存されたファイルの確認
    base_filename = f"{model_type}_{experiment.serial_num}"
    expected_files = [
        f"{experiment.output_dir}/{base_filename}_tap_full.csv",
        f"{experiment.output_dir}/{base_filename}_tap.csv",
        f"{experiment.output_dir}/{base_filename}_SE.csv",
        f"{experiment.output_dir}/{base_filename}_ITI.csv",
        f"{experiment.output_dir}/{base_filename}_variations.csv"
    ]
    
    for file_path in expected_files:
        if os.path.exists(file_path):
            print(f"ファイル確認: {file_path} - 存在します")
        else:
            print(f"ファイル確認: {file_path} - 存在しません!")
    
    print("\nデータ保存テスト成功")
    
except Exception as e:
    print(f"エラー発生: {e}")
    import traceback
    traceback.print_exc()
    sys.exit(1)
