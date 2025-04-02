"""
Configuration for cooperative tapping experiment.
Centralized configuration parameters for the entire project.
"""
import os

class Config:
    """Configuration for cooperative tapping experiment."""
    
    def __init__(self):
        """Initialize configuration with default values."""
        # Basic timing parameters
        self.SPAN = 2.0          # Base interval in seconds
        self.STAGE1 = 10         # Number of taps in Stage 1 (metronome)
        self.STAGE2 = 100        # Number of taps in Stage 2 (interaction)
        self.BUFFER = 10         # Number of taps to exclude from analysis
        self.SCALE = 0.1         # Variance scale for random timings
        
        # Paths for assets and data
        self.BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        self.ASSETS_DIR = os.path.join(self.BASE_DIR, 'assets')
        self.SOUND_DIR = os.path.join(self.ASSETS_DIR, 'sounds')
        self.DATA_DIR = os.path.join(self.BASE_DIR, 'data')
        self.RAW_DATA_DIR = os.path.join(self.DATA_DIR, 'raw')
        self.PROCESSED_DATA_DIR = os.path.join(self.DATA_DIR, 'processed')
        
        # Sound file paths
        self.SOUND_STIM = os.path.join(self.SOUND_DIR, 'button02a.mp3')
        self.SOUND_PLAYER = os.path.join(self.SOUND_DIR, 'button03a.mp3')
        
        # Model parameters
        self.BAYES_N_HYPOTHESIS = 20  # Number of hypotheses for Bayesian models
        self.BIB_L_MEMORY = 1         # Memory length for BIB model
        
        # Create directories if they don't exist
        self._create_directories()
        
    def _create_directories(self):
        """Create necessary directories if they don't exist."""
        directories = [
            self.ASSETS_DIR,
            self.SOUND_DIR,
            self.DATA_DIR,
            self.RAW_DATA_DIR,
            self.PROCESSED_DATA_DIR
        ]
        
        for directory in directories:
            os.makedirs(directory, exist_ok=True)
            
    def __str__(self):
        """String representation of configuration."""
        return (
            f"Cooperative Tapping Configuration\n"
            f"-------------------------------\n"
            f"SPAN: {self.SPAN} seconds\n"
            f"STAGE1: {self.STAGE1} taps\n"
            f"STAGE2: {self.STAGE2} taps\n"
            f"BUFFER: {self.BUFFER} taps\n"
            f"SCALE: {self.SCALE}\n"
            f"-------------------------------\n"
            f"DATA_DIR: {self.DATA_DIR}\n"
            f"SOUND_STIM: {self.SOUND_STIM}\n"
            f"SOUND_PLAYER: {self.SOUND_PLAYER}\n"
        )