#!/usr/bin/env python3
"""
シンプルなインポートテスト
"""
import os
print("インポートテスト開始")

try:
    from src.config import Config
    print("Config モジュールのインポート成功")
    
    config = Config()
    print(f"Config 作成成功: SPAN={config.SPAN}")
    
    from src.experiment.runner import ExperimentRunner
    print("ExperimentRunner モジュールのインポート成功")
    
    from src.models import SEAModel, BayesModel, BIBModel
    print("モデルモジュールのインポート成功")
    
    print("すべてのインポートに成功")
    
except Exception as e:
    print(f"エラー発生: {e}")
