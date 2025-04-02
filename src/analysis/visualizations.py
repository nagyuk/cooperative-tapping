"""
Visualization tools for cooperative tapping analysis.
Provides functions to create various plots for data analysis.
"""
import matplotlib.pyplot as plt
import numpy as np
import os
from .metrics import calculate_regression

def plot_time_series(stim_data, player_data, title, ylabel, output_path, 
                    figsize=(10, 6), colors=('b', 'r')):
    """Plot time series data for stimulus and player.
    
    Args:
        stim_data: Stimulus data series
        player_data: Player data series
        title: Plot title
        ylabel: Y-axis label
        output_path: Path to save the plot
        figsize: Figure size (width, height)
        colors: Colors for stimulus and player lines
    """
    plt.figure(figsize=figsize)
    plt.title(title)
    plt.xlabel("Tap Number", fontsize=16)
    plt.ylabel(ylabel, fontsize=16)
    plt.grid(True)
    plt.tick_params(labelsize=12)
    
    x_stim = range(len(stim_data))
    x_player = range(len(player_data))
    
    plt.plot(x_stim, stim_data, color=colors[0], label='Stimulus')
    plt.plot(x_player, player_data, color=colors[1], label='Player')
    
    plt.legend(loc='upper left', fontsize=12)
    
    # Create directory if it doesn't exist
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    
    plt.savefig(output_path, bbox_inches='tight', dpi=300)
    plt.close()

def plot_histogram(stim_data, player_data, title, xlabel, output_path,
                  figsize=(10, 6), bin_range=(0, 2.0), colors=('b', 'r')):
    """Plot histograms for stimulus and player data.
    
    Args:
        stim_data: Stimulus data
        player_data: Player data
        title: Plot title
        xlabel: X-axis label
        output_path: Path to save the plot
        figsize: Figure size (width, height)
        bin_range: Range for histogram bins
        colors: Colors for stimulus and player histograms
    """
    plt.figure(figsize=figsize)
    plt.title(title)
    plt.xlabel(xlabel, fontsize=16)
    plt.ylabel("Frequency", fontsize=16)
    plt.tick_params(labelsize=12)
    
    plt.hist(stim_data, alpha=0.5, range=bin_range, color=colors[0], label='Stimulus')
    plt.hist(player_data, alpha=0.5, range=bin_range, color=colors[1], label='Player')
    
    plt.legend(loc='upper left', fontsize=12)
    
    # Create directory if it doesn't exist
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    
    plt.savefig(output_path, bbox_inches='tight', dpi=300)
    plt.close()

def plot_scatter_with_regression(x, y, title, xlabel, ylabel, output_path, figsize=(10, 6)):
    """Plot scatter with regression line.
    
    Args:
        x: X values
        y: Y values
        title: Plot title
        xlabel: X-axis label
        ylabel: Y-axis label
        output_path: Path to save the plot
        figsize: Figure size (width, height)
    """
    slope, intercept, r2 = calculate_regression(x, y)
    
    plt.figure(figsize=figsize)
    plt.title(title)
    plt.xlabel(xlabel, fontsize=16)
    plt.ylabel(ylabel, fontsize=16)
    
    # Scatter plot
    plt.scatter(x, y, alpha=0.7)
    
    # Add regression line if regression was successful
    if not np.isnan(slope):
        x_line = np.array([min(x), max(x)])
        y_line = slope * x_line + intercept
        plt.plot(x_line, y_line, 'r-', linewidth=2)
        
        # Add equation and R² to legend
        equation = f"{ylabel} = {slope:.2f} · {xlabel} + {intercept:.2f}"
        r2_text = f"R² = {r2:.3f}"
        plt.legend([equation, r2_text], loc='best', fontsize=12)
    
    # Create directory if it doesn't exist
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    
    plt.savefig(output_path, bbox_inches='tight', dpi=300)
    plt.close()

def create_all_visualizations(data_dict, model_type, experiment_id, output_dir):
    """Create all standard visualizations for experiment data.
    
    Args:
        data_dict: Dictionary containing all data series
        model_type: Type of model used (sea, bayes, bib)
        experiment_id: Experiment ID (timestamp)
        output_dir: Directory to save plots
    """
    base_path = f"{output_dir}/{model_type}_{experiment_id}"
    
    # Time series plots
    if 'stim_iti' in data_dict and 'player_iti' in data_dict:
        plot_time_series(
            data_dict['stim_iti'], 
            data_dict['player_iti'],
            "Inter Tap-onset Intervals Over Time",
            "ITI (seconds)",
            f"{base_path}_ITI.pdf"
        )
    
    if 'stim_itiv' in data_dict and 'player_itiv' in data_dict:
        plot_time_series(
            data_dict['stim_itiv'], 
            data_dict['player_itiv'],
            "ITI Variations Over Time",
            "ITIv (seconds)",
            f"{base_path}_ITIv.pdf"
        )
    
    if 'stim_se' in data_dict and 'player_se' in data_dict:
        plot_time_series(
            data_dict['stim_se'], 
            data_dict['player_se'],
            "Synchronization Errors Over Time",
            "SE (seconds)",
            f"{base_path}_SE.pdf"
        )
    
    if 'stim_sev' in data_dict and 'player_sev' in data_dict:
        plot_time_series(
            data_dict['stim_sev'], 
            data_dict['player_sev'],
            "SE Variations Over Time",
            "SEv (seconds)",
            f"{base_path}_SEv.pdf"
        )
    
    # Histogram
    if 'stim_iti' in data_dict and 'player_iti' in data_dict:
        plot_histogram(
            data_dict['stim_iti'], 
            data_dict['player_iti'],
            "Distribution of Inter Tap-onset Intervals",
            "ITI (seconds)",
            f"{base_path}_ITI_hist.pdf"
        )
    
    # Scatter plots with regression
    if 'stim_se' in data_dict and 'stim_iti' in data_dict:
        # Need to align data for regression (remove first ITI)
        se = data_dict['stim_se'][:-1] if len(data_dict['stim_se']) > len(data_dict['stim_iti']) else data_dict['stim_se']
        iti = data_dict['stim_iti'][1:] if len(data_dict['stim_iti']) > len(data_dict['stim_se']) else data_dict['stim_iti']
        
        if len(se) == len(iti) and len(se) > 1:
            plot_scatter_with_regression(
                se, iti,
                "Relationship Between SE and ITI (Stimulus)",
                "SE (seconds)",
                "ITI (seconds)",
                f"{base_path}_stim_SE_ITI.pdf"
            )
    
    if 'stim_se' in data_dict and 'stim_itiv' in data_dict:
        se = data_dict['stim_se'][:-1] if len(data_dict['stim_se']) > len(data_dict['stim_itiv']) else data_dict['stim_se']
        itiv = data_dict['stim_itiv'] if len(data_dict['stim_itiv']) <= len(se) else data_dict['stim_itiv'][:len(se)]
        
        if len(se) == len(itiv) and len(se) > 1:
            plot_scatter_with_regression(
                se, itiv,
                "Relationship Between SE and ITIv (Stimulus)",
                "SE (seconds)",
                "ITIv (seconds)",
                f"{base_path}_stim_SE_ITIv.pdf"
            )
    
    # Add more scatter plots as needed for different relationships