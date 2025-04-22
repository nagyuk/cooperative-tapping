#!/usr/bin/env python
"""
Script to run the cooperative tapping experiment.
Provides command-line interface to configure and start experiments.
"""
import argparse
import sys
import os
import time

# Add parent directory to path to import src modules
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from src.config import Config
from src.experiment.runner import ExperimentRunner


def main():
    """Run the cooperative tapping experiment."""
    # Parse command-line arguments
    parser = argparse.ArgumentParser(
        description='Run cooperative tapping experiment',
        formatter_class=argparse.ArgumentDefaultsHelpFormatter
    )
    
    parser.add_argument(
        '--model', 
        choices=['sea', 'bayes', 'bib'], 
        default='sea',
        help='Model type to use for experiment'
    )
    
    parser.add_argument(
        '--output-dir', 
        default=None,
        help='Directory to save output data (defaults to config RAW_DATA_DIR)'
    )
    
    parser.add_argument(
        '--span', 
        type=float, 
        default=None,
        help='Base interval in seconds'
    )
    
    parser.add_argument(
        '--stage1', 
        type=int, 
        default=None,
        help='Number of taps in Stage 1 (metronome)'
    )
    
    parser.add_argument(
        '--stage2', 
        type=int, 
        default=None,
        help='Number of taps in Stage 2 (interaction)'
    )
    
    parser.add_argument(
        '--buffer', 
        type=int, 
        default=None,
        help='Number of taps to exclude from beginning and end'
    )
    
    parser.add_argument(
        '--scale', 
        type=float, 
        default=None,
        help='Variance scale for random timing'
    )
    
    args = parser.parse_args()
    
    # Create configuration
    config = Config()
    
    # Override configuration from command-line arguments
    if args.span is not None:
        config.SPAN = args.span
    if args.stage1 is not None:
        config.STAGE1 = args.stage1
    if args.stage2 is not None:
        config.STAGE2 = args.stage2
    if args.buffer is not None:
        config.BUFFER = args.buffer
    if args.scale is not None:
        config.SCALE = args.scale
    
    # Use default output directory if not specified
    output_dir = args.output_dir if args.output_dir else config.RAW_DATA_DIR
    
    # 実際のSTAGE2値を保存
    actual_stage2 = 30
    
    # Print experiment configuration
    print("\n" + "="*50)
    print(f"Starting experiment with {args.model.upper()} model")
    print("="*50)
    print(f"Model: {args.model}")
    print(f"Output directory: {output_dir}")
    print(f"Base interval: {config.SPAN} seconds")
    print(f"Stage 1 taps: {config.STAGE1}")
    print(f"Stage 2 taps: {actual_stage2}")  # 実際の値を表示
    print(f"Buffer: {config.BUFFER}")
    print(f"Scale: {config.SCALE}")
    print("="*50 + "\n")
    
    # 実際の値をconfigに設定
    config.STAGE2 = actual_stage2
    
    # Wait for confirmation to start
    input("Press Enter to start the experiment...")
    
    # Create experiment runner
    experiment = ExperimentRunner(
        config, 
        model_type=args.model, 
        output_dir=output_dir
    )
    
    # Run experiment
    start_time = time.time()
    success = experiment.run()
    end_time = time.time()
    
    if success:
        print("\n" + "="*50)
        print("Experiment completed successfully!")
        print(f"Duration: {end_time - start_time:.2f} seconds")
        print(f"Data saved to: {output_dir}")
        print("="*50 + "\n")
    else:
        print("\n" + "="*50)
        print("Experiment was interrupted or failed.")
        print("="*50 + "\n")
    

if __name__ == '__main__':
    main()