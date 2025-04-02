"""
Metrics calculation for cooperative tapping analysis.
Provides functions to calculate ITI, SE, and their variations.
"""
import numpy as np

def calculate_iti(taps):
    """Calculate Inter Tap-onset Intervals.
    
    Args:
        taps: List of tap times
        
    Returns:
        List of ITIs
    """
    if len(taps) < 2:
        return []
    return [taps[i+1] - taps[i] for i in range(len(taps) - 1)]

def calculate_se(stim_taps, player_taps):
    """Calculate Synchronization Errors.
    
    Args:
        stim_taps: List of stimulus tap times
        player_taps: List of player tap times
        
    Returns:
        List of SEs
    """
    se_list = []
    for i in range(1, min(len(stim_taps), len(player_taps))):
        if i < len(player_taps) and i < len(stim_taps):
            # SE_A(n) = Tap_B(n) - {(Tap_A(n) + Tap_A(n-1))/2}
            se = player_taps[i] - (stim_taps[i-1] + stim_taps[i])/2
            se_list.append(se)
    return se_list

def calculate_variations(values):
    """Calculate variations between consecutive values.
    
    Args:
        values: List of values
        
    Returns:
        List of variations
    """
    if len(values) < 2:
        return []
    return [values[i+1] - values[i] for i in range(len(values) - 1)]

def r2_score_manual(y_true, y_pred):
    """Calculate R2 score manually.
    
    Args:
        y_true: True values
        y_pred: Predicted values
        
    Returns:
        R2 score
    """
    if len(y_true) != len(y_pred) or len(y_true) == 0:
        return np.nan
        
    y_mean = np.mean(y_true)
    ss_total = np.sum((y_true - y_mean) ** 2)
    
    # Avoid division by zero
    if ss_total == 0:
        return np.nan
        
    ss_residual = np.sum((y_true - y_pred) ** 2)
    r2 = 1 - (ss_residual / ss_total)
    return r2

def calculate_correlation(x, y):
    """Calculate Pearson correlation coefficient.
    
    Args:
        x: First variable
        y: Second variable
        
    Returns:
        Correlation coefficient
    """
    if len(x) != len(y) or len(x) < 2:
        return np.nan
    
    return np.corrcoef(x, y)[0, 1]

def calculate_regression(x, y):
    """Calculate linear regression coefficients.
    
    Args:
        x: Independent variable
        y: Dependent variable
        
    Returns:
        Tuple of (slope, intercept, r2_score)
    """
    if len(x) != len(y) or len(x) < 2:
        return (np.nan, np.nan, np.nan)
    
    # Calculate regression line
    slope, intercept = np.polyfit(x, y, 1)
    
    # Calculate predicted values
    y_pred = slope * np.array(x) + intercept
    
    # Calculate R2 score
    r2 = r2_score_manual(y, y_pred)
    
    return (slope, intercept, r2)