"""
Analysis tools for cooperative tapping task.
"""
from .metrics import (
    calculate_iti, calculate_se, calculate_variations, 
    r2_score_manual, calculate_correlation, calculate_regression
)
from .visualizations import (
    plot_time_series, plot_histogram, plot_scatter_with_regression,
    create_all_visualizations
)

__all__ = [
    'calculate_iti', 'calculate_se', 'calculate_variations',
    'r2_score_manual', 'calculate_correlation', 'calculate_regression',
    'plot_time_series', 'plot_histogram', 'plot_scatter_with_regression',
    'create_all_visualizations'
]