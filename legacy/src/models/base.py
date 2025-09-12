"""
Base model interface for cooperative tapping task.
All models must implement this interface.
"""
from abc import ABC, abstractmethod

class BaseModel(ABC):
    """Base abstract class for all tapping models."""
    
    def __init__(self, config):
        """Initialize model with configuration.
        
        Args:
            config: Configuration object with experiment parameters
        """
        self.config = config
        self.name = self.__class__.__name__
    
    @abstractmethod
    def inference(self, se):
        """Perform inference based on synchronization error.
        
        Args:
            se: Synchronization error from current tap
            
        Returns:
            float: Time to wait before next tap (seconds)
        """
        pass
    
    def reset(self):
        """Reset model state to initial conditions."""
        pass
    
    def get_state(self):
        """Get current model state for logging/analysis.
        
        Returns:
            dict: Current state of the model
        """
        return {"name": self.name}