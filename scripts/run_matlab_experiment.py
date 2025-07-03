#!/usr/bin/env python
"""
Run cooperative tapping experiment using MATLAB for precise timing.

This script uses MATLAB for the experimental execution while leveraging
Python models for the computational aspects.
"""

import argparse
import sys
from pathlib import Path

# Add project root to Python path
sys.path.append(str(Path(__file__).parent.parent))

from src.config import Config
from src.experiment.matlab_bridge import MatlabExperimentRunner, MatlabDataLogger
from src.analysis.metrics import calculate_iti, calculate_se
from src.visualization.plotter import plot_results


def main():
    # Parse command line arguments
    parser = argparse.ArgumentParser(
        description='Run cooperative tapping experiment with MATLAB backend'
    )
    parser.add_argument(
        '--model',
        choices=['sea', 'bayes', 'bib'],
        default='sea',
        help='Model type to use for inference'
    )
    parser.add_argument(
        '--plot',
        action='store_true',
        help='Generate plots after experiment'
    )
    parser.add_argument(
        '--save',
        action='store_true',
        help='Save experiment data'
    )
    
    args = parser.parse_args()
    
    # Load configuration
    config = Config()
    
    try:
        # Initialize MATLAB experiment runner
        print(f"Initializing MATLAB experiment with {args.model} model...")
        runner = MatlabExperimentRunner(config, args.model)
        
        # Run the experiment
        print("Running experiment...")
        stim_tap, player_tap = runner.run_experiment()
        
        # Analyze results
        print("\nAnalyzing results...")
        stim_iti = calculate_iti(stim_tap)
        player_iti = calculate_iti(player_tap)
        se = calculate_se(stim_tap, player_tap)
        
        # Print summary statistics
        print(f"\nExperiment Summary:")
        print(f"- Total taps: {len(stim_tap)} stimulus, {len(player_tap)} player")
        print(f"- Mean ITI: {stim_iti.mean():.2f}ms (stimulus), {player_iti.mean():.2f}ms (player)")
        print(f"- Mean SE: {se.mean():.2f}ms")
        
        # Save data if requested
        if args.save:
            logger = MatlabDataLogger(config.LOG_DIR)
            logger.save_experiment_data(
                stim_tap=stim_tap,
                player_tap=player_tap,
                model_type=args.model,
                additional_data={
                    'stim_iti': stim_iti,
                    'player_iti': player_iti,
                    'se': se
                }
            )
        
        # Generate plots if requested
        if args.plot:
            print("\nGenerating plots...")
            plot_results(stim_tap, player_tap, stim_iti, player_iti, se)
        
        # Clean up
        runner.cleanup()
        
    except Exception as e:
        print(f"\nError during experiment: {e}")
        return 1
    
    return 0


if __name__ == '__main__':
    sys.exit(main())
