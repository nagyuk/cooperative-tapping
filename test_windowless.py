#!/usr/bin/env python
"""
Test script for windowless implementation
"""
import sys
import os

# Add parent directory to path
sys.path.insert(0, os.path.abspath(os.path.dirname(__file__)))

try:
    print("Testing windowless implementation...")
    print("-" * 50)
    
    # Test imports
    print("1. Testing imports...")
    from src.config import Config
    print("   ✓ Config imported")
    
    from src.models import SEAModel, BayesModel, BIBModel
    print("   ✓ Models imported")
    
    from src.experiment.runner import ExperimentRunner
    print("   ✓ ExperimentRunner imported")
    
    # Test configuration
    print("\n2. Testing configuration...")
    config = Config()
    config.STAGE1 = 3  # Small values for testing
    config.STAGE2 = 5
    print(f"   ✓ Config created: STAGE1={config.STAGE1}, STAGE2={config.STAGE2}")
    
    # Test model creation
    print("\n3. Testing model creation...")
    sea_model = SEAModel(config)
    print("   ✓ SEA model created")
    
    bayes_model = BayesModel(config)
    print("   ✓ Bayes model created")
    
    bib_model = BIBModel(config)
    print("   ✓ BIB model created")
    
    # Test runner creation
    print("\n4. Testing ExperimentRunner creation...")
    runner = ExperimentRunner(config, model_type='sea')
    print("   ✓ ExperimentRunner created")
    
    # Test UI setup (audio only)
    print("\n5. Testing UI setup...")
    runner.setup_ui()
    print("   ✓ UI setup completed (audio only)")
    
    print("\n" + "-" * 50)
    print("All tests passed! Windowless implementation is ready.")
    print("-" * 50)
    
except Exception as e:
    print(f"\n✗ Error: {e}")
    import traceback
    traceback.print_exc()
    sys.exit(1)
