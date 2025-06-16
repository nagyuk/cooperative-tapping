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
from .network import (
    create_recurrence_network, calculate_network_metrics, fit_degree_distribution,
    analyze_sliding_window, plot_recurrence_network, plot_recurrence_matrix,
    plot_degree_distribution, plot_sliding_window_metrics, interpret_network_results
)

__all__ = [
    'calculate_iti', 'calculate_se', 'calculate_variations',
    'r2_score_manual', 'calculate_correlation', 'calculate_regression',
    'plot_time_series', 'plot_histogram', 'plot_scatter_with_regression',
    'create_all_visualizations',
    'create_recurrence_network', 'calculate_network_metrics', 'fit_degree_distribution',
    'analyze_sliding_window', 'plot_recurrence_network', 'plot_recurrence_matrix',
    'plot_degree_distribution', 'plot_sliding_window_metrics', 'interpret_network_results'
]