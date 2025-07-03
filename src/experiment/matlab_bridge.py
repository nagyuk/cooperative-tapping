"""
MATLAB Bridge for Cooperative Tapping Experiment

This module provides integration between Python models and MATLAB experiment implementation.
"""

import matlab.engine
import numpy as np
from typing import Tuple, Optional, Union
import os
import json
from pathlib import Path

from ..models import SEAModel, BayesModel, BIBModel
from ..config import Config


class MatlabExperimentRunner:
    """Bridge class for running experiments in MATLAB while using Python models."""
    
    def __init__(self, config: Config, model_type: str = 'sea'):
        """
        Initialize the MATLAB-Python bridge.
        
        Args:
            config: Experiment configuration object
            model_type: Type of model to use ('sea', 'bayes', or 'bib')
        """
        self.config = config
        self.model_type = model_type
        self.model = self._create_model(model_type)
        
        # Start MATLAB engine
        print("Starting MATLAB engine...")
        self.eng = matlab.engine.start_matlab()
        
        # Add MATLAB paths
        matlab_path = Path(__file__).parent.parent.parent / 'matlab'
        self.eng.addpath(str(matlab_path / 'src'))
        self.eng.addpath(str(matlab_path / 'utils'))
        self.eng.addpath(str(matlab_path / 'experiments'))
        
        # Create MATLAB config struct
        self._setup_matlab_config()
        
    def _create_model(self, model_type: str):
        """Create the appropriate model instance."""
        if model_type == 'sea':
            return SEAModel(self.config)
        elif model_type == 'bayes':
            return BayesModel(self.config)
        elif model_type == 'bib':
            return BIBModel(self.config)
        else:
            raise ValueError(f"Unknown model type: {model_type}")
    
    def _setup_matlab_config(self):
        """Convert Python config to MATLAB struct."""
        # Create config struct in MATLAB
        self.eng.eval("""
            config = struct();
            config.SPAN = {};
            config.STAGE1 = {};
            config.STAGE2 = {};
            config.SHOW_TAP = {};
            config.WRITE_OUTPUT = {};
            config.LOG_DIR = '{}';
        """.format(
            self.config.SPAN,
            self.config.STAGE1,
            self.config.STAGE2,
            int(self.config.SHOW_TAP),
            int(self.config.WRITE_OUTPUT),
            self.config.LOG_DIR
        ), nargout=0)
    
    def run_experiment(self) -> Tuple[np.ndarray, np.ndarray]:
        """
        Run the full experiment in MATLAB.
        
        Returns:
            Tuple of (stimulus_tap_times, player_tap_times)
        """
        print(f"Running experiment with {self.model_type} model...")
        
        # Create and run experiment in MATLAB
        self.eng.eval(f"""
            % Create experiment instance
            exp = CooperativeTappingExperiment(config, '{self.model_type}');
            
            % Run the experiment
            exp.runExperiment();
            
            % Extract timing data
            stim_tap = exp.stim_tap;
            player_tap = exp.player_tap;
        """, nargout=0)
        
        # Retrieve data from MATLAB
        stim_tap = self._matlab_to_numpy(self.eng.workspace['stim_tap'])
        player_tap = self._matlab_to_numpy(self.eng.workspace['player_tap'])
        
        return stim_tap, player_tap
    
    def inference_callback(self, se: float) -> float:
        """
        Callback function for MATLAB to request model inference.
        
        Args:
            se: Synchronization error in milliseconds
            
        Returns:
            Predicted next ITI
        """
        return self.model.inference(se)
    
    def _matlab_to_numpy(self, matlab_array) -> np.ndarray:
        """Convert MATLAB array to numpy array."""
        if matlab_array is None:
            return np.array([])
        return np.array(matlab_array).flatten()
    
    def cleanup(self):
        """Clean up MATLAB engine."""
        if hasattr(self, 'eng'):
            self.eng.quit()
    
    def __del__(self):
        """Destructor to ensure MATLAB engine is closed."""
        self.cleanup()


class MatlabDataLogger:
    """Logger for saving experiment data in MATLAB-compatible format."""
    
    def __init__(self, log_dir: str):
        self.log_dir = Path(log_dir)
        self.log_dir.mkdir(parents=True, exist_ok=True)
    
    def save_experiment_data(self, 
                           stim_tap: np.ndarray,
                           player_tap: np.ndarray,
                           model_type: str,
                           additional_data: Optional[dict] = None):
        """
        Save experiment data in both .mat and .json formats.
        
        Args:
            stim_tap: Stimulus tap times
            player_tap: Player tap times  
            model_type: Model type used
            additional_data: Any additional data to save
        """
        import scipy.io as sio
        from datetime import datetime
        
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        base_filename = f"experiment_{model_type}_{timestamp}"
        
        # Prepare data dictionary
        data = {
            'stim_tap': stim_tap,
            'player_tap': player_tap,
            'model_type': model_type,
            'timestamp': timestamp
        }
        
        if additional_data:
            data.update(additional_data)
        
        # Save as .mat file for MATLAB
        mat_path = self.log_dir / f"{base_filename}.mat"
        sio.savemat(mat_path, data)
        
        # Save as .json for Python (convert arrays to lists)
        json_data = {k: v.tolist() if isinstance(v, np.ndarray) else v 
                    for k, v in data.items()}
        json_path = self.log_dir / f"{base_filename}.json"
        with open(json_path, 'w') as f:
            json.dump(json_data, f, indent=2)
        
        print(f"Data saved to {mat_path} and {json_path}")
