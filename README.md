# Cooperative Tapping Task

This project implements a cooperative tapping experiment system designed to study human-computer rhythmic interaction. It provides three different models of interaction:

1. **SEA (Synchronization Error Averaging) Model**: Adjusts timing based on averaged synchronization errors.
2. **Bayesian Inference Model**: Uses Bayesian inference to predict and adapt to human timing patterns.
3. **BIB (Bayesian-Inverse Bayesian) Inference Model**: An extension of Bayesian inference that incorporates the flexible belief systems proposed by Gunji et al.

## Project Structure

```
cooperative-tapping/
│
├── src/                           # Main source code
│   ├── models/                    # Model implementations
│   ├── experiment/                # Experiment framework
│   ├── analysis/                  # Analysis tools
│   └── config.py                  # Centralized configuration
│
├── scripts/                       # Executable scripts
├── data/                          # Data directory
│   ├── raw/                       # Raw experiment data
│   └── processed/                 # Processed analysis results
│
├── assets/                        # Static assets
│   └── sounds/                    # Sound files
│
├── tests/                         # Unit and integration tests
├── docs/                          # Documentation
│
└── requirements.txt               # Dependencies
```

## Installation

### Setting up the development environment

1. Clone the repository:
```bash
git clone https://github.com/yourusername/cooperative-tapping.git
cd cooperative-tapping
```

2. Create and activate a virtual environment:
```bash
# For Python 3.11
python3.11 -m venv venv_py311
source venv_py311/bin/activate  # On Windows: venv_py311\Scripts\activate
```

3. Install dependencies:
```bash
pip install -r requirements.txt
```

4. Install the package in development mode:
```bash
pip install -e .
```

5. Make sure to place the required sound files in the assets/sounds directory:
   - button02a.mp3 (stimulus sound)
   - button03a.mp3 (player sound)

## Usage

### Running an experiment

```bash
# Using the command-line script
run-tapping --model sea

# Or directly with Python
python scripts/run_experiment.py --model sea
```

Available options:
- `--model`: Choose between 'sea', 'bayes', or 'bib' models
- `--span`: Base interval in seconds (default: 2.0)
- `--stage1`: Number of metronome taps in Stage 1 (default: 10)
- `--stage2`: Number of interaction taps in Stage 2 (default: 100)
- `--buffer`: Number of taps to exclude from analysis (default: 10)
- `--scale`: Variance scale for random timing (default: 0.1)

### Analyzing results

```bash
# Using the command-line script
analyze-tapping --model sea

# Or directly with Python
python scripts/analyze_results.py --model sea
```

Available options:
- `--model`: Model used in the experiment ('sea', 'bayes', or 'bib')
- `--experiment-id`: Specific experiment ID to analyze (default: most recent)
- `--input-dir`: Custom input directory
- `--output-dir`: Custom output directory for visualizations

## Key Concepts

### Synchronization Error (SE)
The difference between a player's tap and the midpoint of the surrounding stimulus taps.

### Inter Tap-onset Interval (ITI)
The time between consecutive taps.

### Models

#### SEA Model
The simplest model that adjusts its timing based on the average of past synchronization errors.

#### Bayesian Model
Uses Bayesian inference to learn from synchronization errors and predict optimal timing adjustments.

#### BIB (Bayesian-Inverse Bayesian) Model
Extends the Bayesian model with an "inverse" component that allows hypothesis models themselves to evolve, creating a more flexible and adaptive system that better mimics human behavior.

## Research Background

This software is an implementation of cooperative tapping experiments as described in the paper "Analysis of Cooperative Tapping Tasks Using Extended Bayesian Inference Algorithm" by Yuki Nagai and Kazuto Sasai. The research explores timing control mechanisms in human communication, with a particular focus on developing models that can represent non-stationary states.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- Based on research by Kazuto Sasai and Yukio-Pegio Gunji on Bayesian-Inverse Bayesian inference.
- Developed for the rhythmic interaction studies at Ibaraki University.