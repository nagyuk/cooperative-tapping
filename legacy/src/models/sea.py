"""
Synchronization Error Averaging (SEA) model for cooperative tapping task.
Extracted and refactored from the original modify.py
"""
import numpy as np
from .base import BaseModel

class SEAModel(BaseModel):
    """Synchronization Error Averaging model.
    
    This model adjusts timing based on the average of past synchronization errors.
    It's a simpler approach compared to Bayesian models.
    """
    
    def __init__(self, config):
        """Initialize SEA model.
        
        Args:
            config: Configuration object
        """
        super().__init__(config)
        self.se_history = []
        self.modify = 0  # Cumulative modification value
    
    def inference(self, se):
        """Adjust timing based on average synchronization error.
        
        Args:
            se: Synchronization error
            
        Returns:
            float: Time to wait before next tap (seconds)
        """
        # Store SE for averaging
        self.se_history.append(se)
        
        # Update cumulative modification
        self.modify += se
        
        # Calculate average modification
        avg_modify = self.modify / len(self.se_history)
        
        # Generate random interval with normal distribution
        random_interval = np.random.normal(
            (self.config.SPAN / 2) - avg_modify, 
            self.config.SCALE
        )
        
        return random_interval
    
    def reset(self):
        """Reset model state to initial conditions."""
        self.se_history = []
        self.modify = 0
    
    def get_state(self):
        """Get current model state for logging/analysis.
        
        Returns:
            dict: Current state of the model
        """
        state = super().get_state()
        state.update({
            "se_history_length": len(self.se_history),
            "cumulative_modify": self.modify,
            "average_modify": self.modify / len(self.se_history) if self.se_history else 0
        })
        return state