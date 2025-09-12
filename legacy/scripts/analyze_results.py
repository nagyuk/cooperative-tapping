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
import numpy as np

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
    # Find date-based directories
    try:
        date_dirs = [d for d in os.listdir(input_dir) if os.path.isdir(os.path.join(input_dir, d)) and d.startswith('20')]
        
        if not date_dirs:
            raise ValueError(f"No date-based directories found in {input_dir}")
        
        # Sort date directories (newest first)
        date_dirs.sort(reverse=True)
        
        # If no specific experiment ID, find most recent one for the specified model
        if experiment_id is None:
            for date_dir in date_dirs:
                date_path = os.path.join(input_dir, date_dir)
                model_dirs = [d for d in os.listdir(date_path) 
                             if os.path.isdir(os.path.join(date_path, d)) and d.startswith(f"{model_type}_")]
                
                if model_dirs:
                    # Sort model directories (newest first by timestamp)
                    model_dirs.sort(reverse=True)
                    experiment_id = model_dirs[0].replace(f"{model_type}_", "")
                    selected_date_dir = date_dir
                    break
            else:
                raise ValueError(f"No data found for model {model_type} in any date directory")
        else:
            # If experiment_id is specified, find the corresponding date directory
            selected_date_dir = None
            for date_dir in date_dirs:
                date_path = os.path.join(input_dir, date_dir)
                if os.path.exists(os.path.join(date_path, f"{model_type}_{experiment_id}")):
                    selected_date_dir = date_dir
                    break
            
            if selected_date_dir is None:
                raise ValueError(f"No data found for experiment ID {experiment_id} with model {model_type}")
        
        # Base directory for experiment data
        experiment_path = os.path.join(input_dir, selected_date_dir, f"{model_type}_{experiment_id}")
        
        if not os.path.exists(experiment_path):
            raise ValueError(f"Experiment directory not found: {experiment_path}")
        
        print(f"Loading data from: {experiment_path}")
        
        # Initialize data dictionary
        data = {'experiment_id': experiment_id, 'model_type': model_type}
        
        # Try to load tap data
        # First try processed_taps.csv, then raw_taps.csv
        processed_tap_file = os.path.join(experiment_path, "processed_taps.csv")
        raw_tap_file = os.path.join(experiment_path, "raw_taps.csv")
        
        if os.path.exists(processed_tap_file):
            tap_df = pd.read_csv(processed_tap_file)
            data['stim_tap'] = tap_df['Stim_tap'].tolist()
            data['player_tap'] = tap_df['Player_tap'].tolist()
            tap_source = "processed"
        elif os.path.exists(raw_tap_file):
            tap_df = pd.read_csv(raw_tap_file)
            data['stim_tap'] = tap_df['Stim_tap'].tolist()
            data['player_tap'] = tap_df['Player_tap'].tolist()
            tap_source = "raw"
        else:
            raise ValueError(f"No tap data found in {experiment_path}")
        
        print(f"Loaded {tap_source} tap data - Stimulus: {len(data['stim_tap'])} taps, Player: {len(data['player_tap'])} taps")
        
        # Try to load SE data
        stim_se_file = os.path.join(experiment_path, "stim_synchronization_errors.csv")
        player_se_file = os.path.join(experiment_path, "player_synchronization_errors.csv")
        
        if os.path.exists(stim_se_file):
            stim_se_df = pd.read_csv(stim_se_file)
            data['stim_se'] = stim_se_df['Stim_SE'].tolist()
            print(f"Loaded stim SE data: {len(data['stim_se'])} entries")
        
        if os.path.exists(player_se_file):
            player_se_df = pd.read_csv(player_se_file)
            data['player_se'] = player_se_df['Player_SE'].tolist()
            print(f"Loaded player SE data: {len(data['player_se'])} entries")
        
        # If SE data is not available, calculate it
        if 'stim_se' not in data and 'player_se' not in data and 'stim_tap' in data and 'player_tap' in data:
            print("Calculating SE data from tap times...")
            data['stim_se'] = calculate_se(data['player_tap'], data['stim_tap'])  # Swap order for stim_se
            data['player_se'] = calculate_se(data['stim_tap'], data['player_tap'])
        
        # Try to load ITI data
        stim_iti_file = os.path.join(experiment_path, "stim_intertap_intervals.csv")
        player_iti_file = os.path.join(experiment_path, "player_intertap_intervals.csv")
        
        if os.path.exists(stim_iti_file):
            stim_iti_df = pd.read_csv(stim_iti_file)
            data['stim_iti'] = stim_iti_df['Stim_ITI'].tolist()
            print(f"Loaded stim ITI data: {len(data['stim_iti'])} entries")
        
        if os.path.exists(player_iti_file):
            player_iti_df = pd.read_csv(player_iti_file)
            data['player_iti'] = player_iti_df['Player_ITI'].tolist()
            print(f"Loaded player ITI data: {len(data['player_iti'])} entries")
        
        # If ITI data is not available, calculate it
        if 'stim_iti' not in data and 'stim_tap' in data:
            print("Calculating stim ITI data from tap times...")
            data['stim_iti'] = calculate_iti(data['stim_tap'])
        
        if 'player_iti' not in data and 'player_tap' in data:
            print("Calculating player ITI data from tap times...")
            data['player_iti'] = calculate_iti(data['player_tap'])
        
        # Try to load ITI variations data
        stim_itiv_file = os.path.join(experiment_path, "stim_iti_variations.csv")
        player_itiv_file = os.path.join(experiment_path, "player_iti_variations.csv")
        
        if os.path.exists(stim_itiv_file):
            stim_itiv_df = pd.read_csv(stim_itiv_file)
            data['stim_itiv'] = stim_itiv_df['Stim_ITIv'].tolist()
            print(f"Loaded stim ITIv data: {len(data['stim_itiv'])} entries")
        
        if os.path.exists(player_itiv_file):
            player_itiv_df = pd.read_csv(player_itiv_file)
            data['player_itiv'] = player_itiv_df['Player_ITIv'].tolist()
            print(f"Loaded player ITIv data: {len(data['player_itiv'])} entries")
        
        # If ITIv data is not available, calculate it
        if 'stim_itiv' not in data and 'stim_iti' in data:
            print("Calculating stim ITIv data...")
            data['stim_itiv'] = calculate_variations(data['stim_iti'])
        
        if 'player_itiv' not in data and 'player_iti' in data:
            print("Calculating player ITIv data...")
            data['player_itiv'] = calculate_variations(data['player_iti'])
        
        # Try to load SE variations data
        stim_sev_file = os.path.join(experiment_path, "stim_se_variations.csv")
        player_sev_file = os.path.join(experiment_path, "player_se_variations.csv")
        
        if os.path.exists(stim_sev_file):
            stim_sev_df = pd.read_csv(stim_sev_file)
            data['stim_sev'] = stim_sev_df['Stim_SEv'].tolist()
            print(f"Loaded stim SEv data: {len(data['stim_sev'])} entries")
        
        if os.path.exists(player_sev_file):
            player_sev_df = pd.read_csv(player_sev_file)
            data['player_sev'] = player_sev_df['Player_SEv'].tolist()
            print(f"Loaded player SEv data: {len(data['player_sev'])} entries")
        
        # If SEv data is not available, calculate it
        if 'stim_sev' not in data and 'stim_se' in data:
            print("Calculating stim SEv data...")
            data['stim_sev'] = calculate_variations(data['stim_se'])
        
        if 'player_sev' not in data and 'player_se' in data:
            print("Calculating player SEv data...")
            data['player_sev'] = calculate_variations(data['player_se'])
        
        # Try to load model hypotheses data
        hypo_file = os.path.join(experiment_path, "model_hypotheses.csv")
        
        if os.path.exists(hypo_file):
            hypo_df = pd.read_csv(hypo_file)
            # Convert string representations of hypotheses to numpy arrays
            if 'Hypothesis' in hypo_df.columns:
                try:
                    data['hypo'] = [np.fromstring(h.strip('[]'), sep=',') 
                                   for h in hypo_df['Hypothesis']]
                    print(f"Loaded hypothesis data: {len(data['hypo'])} entries")
                except Exception as e:
                    print(f"Error parsing hypothesis data: {e}")
        
        return data
    
    except Exception as e:
        print(f"Error in load_experiment_data: {e}")
        import traceback
        traceback.print_exc()
        raise

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
        import traceback
        traceback.print_exc()
        return 1
    
    return 0

if __name__ == '__main__':
    sys.exit(main())