"""
Tests for model implementations.
"""
import pytest
import numpy as np
from src.models import SEAModel, BayesModel, BIBModel
from src.config import Config

class TestModels:
    """Test suite for tapping models."""
    
    @pytest.fixture
    def config(self):
        """Create a test configuration."""
        return Config()
    
    def test_sea_model_initialization(self, config):
        """Test SEA model initialization."""
        model = SEAModel(config)
        assert model.name == "SEAModel"
        assert model.se_history == []
        assert model.modify == 0
    
    def test_sea_model_inference(self, config):
        """Test SEA model inference."""
        model = SEAModel(config)
        # Set random seed for reproducibility
        np.random.seed(42)
        
        # First inference with SE=0.1
        result1 = model.inference(0.1)
        assert isinstance(result1, float)
        assert model.se_history == [0.1]
        assert model.modify == 0.1
        
        # Second inference with SE=-0.05
        result2 = model.inference(-0.05)
        assert isinstance(result2, float)
        assert model.se_history == [0.1, -0.05]
        assert model.modify == 0.05
        
        # Verify reset works
        model.reset()
        assert model.se_history == []
        assert model.modify == 0
    
    def test_bayes_model_initialization(self, config):
        """Test Bayesian model initialization."""
        model = BayesModel(config)
        assert model.name == "BayesModel"
        assert model.n_hypothesis == 20
        assert len(model.likelihood) == 20
        assert len(model.h_prov) == 20
        assert np.isclose(sum(model.h_prov), 1.0)
    
    def test_bayes_model_inference(self, config):
        """Test Bayesian model inference."""
        model = BayesModel(config)
        # Set random seed for reproducibility
        np.random.seed(42)
        
        # First inference with SE=0.1
        result1 = model.inference(0.1)
        assert isinstance(result1, float)
        
        # Second inference with SE=-0.05
        result2 = model.inference(-0.05)
        assert isinstance(result2, float)
        
        # Verify hypothesis distribution still sums to 1
        assert np.isclose(sum(model.h_prov), 1.0)
        
        # Verify reset works
        original_h_prov = model.h_prov.copy()
        model.reset()
        assert np.array_equal(model.h_prov, np.ones(20) / 20)
        assert not np.array_equal(model.h_prov, original_h_prov)
    
    def test_bib_model_initialization(self, config):
        """Test BIB model initialization."""
        model = BIBModel(config)
        assert model.name == "BIBModel"
        assert model.l_memory == 1
        assert len(model.memory) == 1
        
        # Test with different memory length
        model2 = BIBModel(config, l_memory=3)
        assert model2.l_memory == 3
        assert len(model2.memory) == 3
    
    def test_bib_model_inference(self, config):
        """Test BIB model inference."""
        model = BIBModel(config, l_memory=2)
        # Set random seed for reproducibility
        np.random.seed(42)
        
        # Save initial likelihood
        initial_likelihood = model.likelihood.copy()
        
        # First inference with SE=0.1
        result1 = model.inference(0.1)
        assert isinstance(result1, float)
        
        # Second inference with SE=-0.05
        result2 = model.inference(-0.05)
        assert isinstance(result2, float)
        
        # Verify hypothesis distribution still sums to 1
        assert np.isclose(sum(model.h_prov), 1.0)
        
        # Verify memory contains the SEs
        assert model.memory[0] == 0.1
        assert model.memory[1] == -0.05
        
        # Verify likelihood has changed (inverse Bayesian effect)
        assert not np.array_equal(model.likelihood, initial_likelihood)
        
        # Verify reset works
        model.reset()
        assert not np.array_equal(model.memory, np.array([0.1, -0.05]))
        assert np.array_equal(model.h_prov, np.ones(20) / 20)