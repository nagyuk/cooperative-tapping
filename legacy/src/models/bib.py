"""
Bayesian-Inverse Bayesian (BIB) inference model for cooperative tapping task.
Based on Gunji's Bayesian-Inverse Bayesian inference theory.
"""
import numpy as np
from .bayes import BayesModel

class BIBModel(BayesModel):
    """Bayesian-Inverse Bayesian inference model."""
    
    def __init__(self, config, n_hypothesis=20, l_memory=1, x_min=-3, x_max=3):
        """Initialize BIB model.
        
        Args:
            config: Configuration object
            n_hypothesis: Number of hypotheses in the model
            l_memory: Memory length for inverse Bayesian learning (0 for regular Bayesian)
            x_min: Minimum value for hypothesis space
            x_max: Maximum value for hypothesis space
        """
        super().__init__(config, n_hypothesis, x_min, x_max)
        self.l_memory = int(l_memory)
        
        # Initialize memory for inverse Bayesian learning
        if l_memory > 0:
            self.memory = np.random.normal(loc=0.0, scale=self.scale, size=self.l_memory)
    
    def inference(self, se):
        """Perform BIB inference using synchronization error.
        
        Args:
            se: Synchronization error
            
        Returns:
            float: Time to wait before next tap (seconds)
        """
        # Inverse Bayesian learning
        if self.l_memory > 0:
            # Calculate new hypothesis based on memory
            new_hypo = np.mean(self.memory)
            
            # Invert the probability distribution
            inv_h_prov = (1 - self.h_prov) / (self.n_hypothesis - 1)
            
            # Replace a hypothesis with the new one
            self.likelihood[np.random.choice(np.arange(self.n_hypothesis), p=inv_h_prov)] = new_hypo
            
            # Update memory
            self.memory = np.roll(self.memory, -1)
            self.memory[-1] = se
        
        # Continue with regular Bayesian inference
        return super().inference(se)
    
    def reset(self):
        """Reset model state to initial conditions."""
        super().reset()
        if self.l_memory > 0:
            self.memory = np.random.normal(loc=0.0, scale=self.scale, size=self.l_memory)
    
    def get_state(self):
        """Get current model state for logging/analysis.
        
        Returns:
            dict: Current state of the model including memory
        """
        state = super().get_state()
        if self.l_memory > 0:
            state["memory"] = self.memory.tolist()
        return state