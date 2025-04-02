#!/usr/bin/env python
"""
Script to analyze results from cooperative tapping experiments.
Provides command-line interface to analyze and visualize experiment data.
"""
import argparse
import sys
import os
import pandas as pd
import glob

# Add parent directory to path to import src modules
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from src.config import Config
from src.analysis.metrics import (
    calculate_iti, calculate_se, calculate_variations,
    calculate_correlation, calculate_regression
)
from src.analysis.visualizations import create_all_visualizations


def load_experiment_data(input_dir, model_type, experiment_id=None):
    """Load experiment data from CSV files.
    
    Args:
        input_dir: Directory containing data files
        model_type: Type of model (sea, bayes, bib)
        experiment_id: Specific experiment ID to analyze (or None for most recent)
        
    Returns:
        Dictionary containing data series and experiment ID
    """
    # If no specific experiment ID, find most recent one
    if experiment_id is None:
        pattern = os.path.join(input_dir, f"{model_type}_*_tap.csv")
        files = glob.glob(pattern)
        
        if not files:
            raise ValueError(f"No data files found for model {model_type} in {input_dir}")
        
        # Sort by modification time (newest first)
        files.sort(key=os.path.getmtime, reverse=True)
        
        # Extract experiment ID from filename
        filename = os.path.basename(files[0])
        experiment_id = filename.replace(f"{model_type}_", "").replace("_tap.csv", "")
    
    # Base pattern for all files
    base_pattern = os.path.join(input_dir, f"{model_type}_{experiment_id}")
    
    # Initialize data dictionary
    data = {'experiment_id': experiment_id, 'model_type': model_type}
    
    # Try to load tap data
    tap_file = f"{base_pattern}_tap.csv"
    if os.path.exists(tap_file):
        tap_df = pd.read_csv(tap_file)
        data['stim_tap'] = tap_df['Stim_tap'].tolist()
        data['player_tap'] = tap_df['Player_tap'].tolist()
    
    # Try to load SE data
    se_file = f"{base_pattern}_SE.csv"
    if os.path.exists(se_file):
        se_df = pd.read_csv(se_file)
        data['stim_se'] = se_df['Stim_SE'].tolist()
        data['player_se'] = se_df['Player_SE'].tolist()
    
    # Try to load ITI data
    iti_file = f"{base_pattern}_ITI.csv"
    if os.path.exists(iti_file):
        iti_df = pd.read_csv(iti_file)
        data['stim_iti'] = iti_df['Stim_ITI'].tolist()
        data['player_iti'] = iti_df['Player_ITI'].tolist()
    elif 'stim_tap' in data and 'player_tap' in data:
        # Calculate ITI from tap data if file doesn't exist
        data['stim_iti'] = calculate_iti(data['stim_tap'])
        data['player_iti'] = calculate_iti(data['player_tap'])
    
    # Try to load variations data
    var_file = f"{base_pattern}_variations.csv"
    if os.path.exists(var_file):
        var_df = pd.read_csv(var_file)
        if 'Stim_ITIv' in var_df.columns:
            data['stim_itiv'] = var_df['Stim_ITIv'].tolist()
        if 'Player_ITIv' in var_df.columns:
            data['player_itiv'] = var_df['Player_ITIv'].tolist()
        if 'Stim_SEv' in var_df.columns:
            data['stim_sev'] = var_df['Stim_SEv'].tolist()
        if 'Player_SEv' in var_df.columns:
            data['player_sev'] = var_df['Player_SEv'].tolist()
    else:
        # Calculate variations if file doesn't exist
        if 'stim_iti' in data:
            data['stim_itiv'] = calculate_variations(data['stim_iti'])
        if 'player_iti' in data:
            data['player_itiv'] = calculate_variations(data['player_iti'])
        if 'stim_se' in data:
            data['stim_sev'] = calculate_variations(data['stim_se'])
        if 'player_se' in data:
            data['player_sev'] = calculate_variations(data['player_se'])
    
    return data


def analyze_data(data):
    """Perform statistical analysis on experiment data.
    
    Args:
        data: Dictionary containing data series
        
    Returns:
        Dictionary with analysis results
    """
    results = {}
    
    # SE-ITI correlations
    if 'stim_se' in data and 'stim_iti' in data:
        # Need to align data for correlation
        se = data['stim_se'][:-1] if len(data['stim_se']) > len(data['stim_iti']) else data['stim_se']
        iti = data['stim_iti'][1:] if len(data['stim_iti']) > len(data['stim_se']) else data['stim_iti']
        
        if len(se) == len(iti) and len(se) > 1:
            results['stim_se_iti_corr'] = calculate_correlation(se, iti)
            slope, intercept, r2 = calculate_regression(se, iti)
            results['stim_se_iti_regression'] = {
                'slope': slope,
                'intercept': intercept,
                'r2': r2
            }
    
    # SE-ITIv correlations
    if 'stim_se' in data and 'stim_itiv' in data:
        se = data['stim_se'][:-1] if len(data['stim_se']) > len(data['stim_itiv']) else data['stim_se']
        itiv = data['stim_itiv'] if len(data['stim_itiv']) <= len(se) else data['stim_itiv'][:len(se)]
        
        if len(se) == len(itiv) and len(se) > 1:
            results['stim_se_itiv_corr'] = calculate_correlation(se, itiv)
            slope, intercept, r2 = calculate_regression(se, itiv)
            results['stim_se_itiv_regression'] = {
                'slope': slope,
                'intercept': intercept,
                'r2': r2
            }
    
    # Add more analysis as needed
    
    return results


def main():
    """Analyze cooperative tapping experiment results."""
    # Parse command-line arguments
    parser = argparse.ArgumentParser(
        description='Analyze cooperative tapping results',
        formatter_class=argparse.ArgumentDefaultsHelpFormatter
    )
    
    parser.add_argument(
        '--model', 
        choices=['sea', 'bayes', 'bib'], 
        required=True,
        help='Model type used in experiment'
    )
    
    parser.add_argument(
        '--experiment-id', 
        default=None,
        help='Specific experiment ID to analyze (default: most recent)'
    )
    
    parser.add_argument(
        '--input-dir', 
        default=None,
        help='Directory with input data (default: config RAW_DATA_DIR)'
    )
    
    parser.add_argument(
        '--output-dir', 
        default=None,
        help='Directory to save analysis results (default: config PROCESSED_DATA_DIR)'
    )
    
    args = parser.parse_args()
    
    # Create configuration
    config = Config()
    
    # Use default directories if not specified
    input_dir = args.input_dir if args.input_dir else config.RAW_DATA_DIR
    output_dir = args.output_dir if args.output_dir else config.PROCESSED_DATA_DIR
    
    print("\n" + "="*50)
    print(f"Analyzing results for {args.model.upper()} model")
    print("="*50)
    print(f"Model: {args.model}")
    print(f"Experiment ID: {args.experiment_id or 'most recent'}")
    print(f"Input directory: {input_dir}")
    print(f"Output directory: {output_dir}")
    print("="*50 + "\n")
    
    try:
        # Load experiment data
        data = load_experiment_data(input_dir, args.model, args.experiment_id)
        
        print(f"Loaded data from experiment {data['experiment_id']}")
        print(f"Number of taps - Stimulus: {len(data.get('stim_tap', []))}, Player: {len(data.get('player_tap', []))}")
        
        # Perform analysis
        results = analyze_data(data)
        
        # Print key analysis results
        print("\nAnalysis Results:")
        print("-----------------")
        if 'stim_se_iti_corr' in results:
            print(f"SE-ITI Correlation: {results['stim_se_iti_corr']:.3f}")
        if 'stim_se_itiv_corr' in results:
            print(f"SE-ITIv Correlation: {results['stim_se_itiv_corr']:.3f}")
        if 'stim_se_iti_regression' in results:
            reg = results['stim_se_iti_regression']
            print(f"SE-ITI Regression: ITI = {reg['slope']:.3f} * SE + {reg['intercept']:.3f} (R² = {reg['r2']:.3f})")
        print("-----------------\n")
        
        # Create visualizations
        print("Creating visualizations...")
        create_all_visualizations(data, args.model, data['experiment_id'], output_dir)
        
        print("\n" + "="*50)
        print("Analysis completed successfully!")
        print(f"Visualizations saved to: {output_dir}")
        print("="*50 + "\n")
        
    except Exception as e:
        print(f"Error during analysis: {e}")
        return 1
    
    return 0


if __name__ == '__main__':
    sys.exit(main())