"""
Bayesian inference model for cooperative tapping task.
Extracted and refactored from the original bayes.py
"""
import numpy as np
from scipy.stats import norm
from .base import BaseModel

class BayesModel(BaseModel):
    """Bayesian inference model for cooperative tapping."""
    
    def __init__(self, config, n_hypothesis=20, x_min=-3, x_max=3):
        """Initialize Bayesian model.
        
        Args:
            config: Configuration object
            n_hypothesis: Number of hypotheses in the model
            x_min: Minimum value for hypothesis space
            x_max: Maximum value for hypothesis space
        """
        super().__init__(config)
        self.n_hypothesis = int(n_hypothesis)
        self.x_min = x_min
        self.x_max = x_max
        self.scale = config.SCALE
        
        # Initialize likelihood and prior probability
        self.likelihood = np.linspace(x_min, x_max, n_hypothesis)
        self.h_prov = np.ones(self.n_hypothesis) / self.n_hypothesis
    
    def inference(self, se):
        """Perform Bayesian inference using synchronization error.
        
        Args:
            se: Synchronization error
            
        Returns:
            float: Time to wait before next tap (seconds)
        """
        # Bayesian learning
        post_prov = np.array([norm(self.likelihood[i], 0.3).pdf(se) 
                             for i in range(self.n_hypothesis)]) * self.h_prov
        post_prov /= np.sum(post_prov)
        self.h_prov = post_prov
        
        # Prediction based on hypothesis
        prediction = np.random.normal(
            loc=np.random.choice(self.likelihood, p=self.h_prov), 
            scale=0.3
        )
        
        # Return time to wait
        return (self.config.SPAN / 2) - prediction
    
    def reset(self):
        """Reset model state to initial conditions."""
        self.h_prov = np.ones(self.n_hypothesis) / self.n_hypothesis
    
    def get_state(self):
        """Get current model state for logging/analysis.
        
        Returns:
            dict: Current state of the model including hypotheses
        """
        state = super().get_state()
        state.update({
            "hypotheses": self.likelihood.tolist(),
            "probabilities": self.h_prov.tolist()
        })
        return state
    
    def get_likelihood(self):
        """Get current likelihood values.
        
        Returns:
            numpy.ndarray: Likelihood values
        """
        return self.likelihood
    
    def get_hypothesis(self):
        """Get current hypothesis probabilities.
        
        Returns:
            numpy.ndarray: Hypothesis probabilities
        """
        return self.h_prov