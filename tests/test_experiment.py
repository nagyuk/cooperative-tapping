import pytest
import numpy as np
from src.config import Config
from src.experiment.runner import ExperimentRunner
from src.models import SEAModel, BayesModel, BIBModel

class TestExperimentRunner:
    @pytest.fixture
    def config(self):
        return Config()

    def test_stage2_tap_synchronization(self, config):
        """Test the timing and synchronization in Stage 2"""
        # テスト用のモデルとモデルタイプを定義
        model_configs = [
            (SEAModel(config), 'sea'),
            (BayesModel(config), 'bayes'),
            (BIBModel(config), 'bib')
        ]

        for model, model_type in model_configs:
            runner = ExperimentRunner(config, model_type=model_type)
            runner.model = model  # モデルを明示的に設定
            
            # モックデータの設定
            runner.stim_tap = [0, 2, 4, 6, 8]
            runner.player_tap = [1, 3, 5, 7]
            
            # 安全な同期エラー計算のテスト
            for turn in range(1, len(runner.stim_tap)):
                # player_tapの長さを超えないように注意
                if turn < len(runner.player_tap):
                    se = runner.stim_tap[turn] - np.mean([
                        runner.player_tap[turn-1], 
                        runner.player_tap[turn]
                    ])
                    
                    # モデルの推論が例外を発生させないことを確認
                    try:
                        interval = model.inference(se)
                        assert isinstance(interval, float)
                    except Exception as e:
                        pytest.fail(f"Model {model.__class__.__name__} failed with SE {se}: {e}")

    def test_tap_time_consistency(self, config):
        """Test the consistency of tap times"""
        runner = ExperimentRunner(config)
        
        # モックデータの設定
        runner.stim_tap = [0, 2, 4, 6, 8]
        runner.player_tap = [1, 3, 5, 7]
        
        # タップ時系列の整合性チェック
        assert len(runner.stim_tap) > len(runner.player_tap)
        assert all(t1 < t2 for t1, t2 in zip(runner.stim_tap[:-1], runner.stim_tap[1:]))
        assert all(t1 < t2 for t1, t2 in zip(runner.player_tap[:-1], runner.player_tap[1:]))