#!/usr/bin/env python3
"""
シンプルなモデルテスト
"""
import os
import sys
print("モデルテスト開始")

try:
    from src.config import Config
    from src.models import SEAModel, BayesModel, BIBModel
    
    config = Config()
    
    # SEAモデルのテスト
    print("SEAモデルのテスト...")
    sea_model = SEAModel(config)
    
    # テスト用のSE値
    test_se = 0.1
    
    # 推論実行
    result = sea_model.inference(test_se)
    print(f"SEAモデル推論結果: {result}")
    
    # Bayesモデルのテスト
    print("\nBayesモデルのテスト...")
    bayes_model = BayesModel(config)
    
    # 推論実行
    result = bayes_model.inference(test_se)
    print(f"Bayesモデル推論結果: {result}")
    
    # BIBモデルのテスト
    print("\nBIBモデルのテスト...")
    bib_model = BIBModel(config, l_memory=1)
    
    # 推論実行
    result = bib_model.inference(test_se)
    print(f"BIBモデル推論結果: {result}")
    
    print("\nすべてのモデルテスト成功")
except Exception as e:
    print(f"エラー発生: {e}")
    import traceback
    traceback.print_exc()
    sys.exit(1)
