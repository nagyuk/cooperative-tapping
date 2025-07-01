# Experiment Documentation

This document describes the **windowless** cooperative tapping experiment implemented in this project.

## Experiment Overview

The cooperative tapping experiment is designed to study the rhythmic interaction between a human participant and a computer model. This implementation operates entirely through console interface with PTB audio backend for millisecond-precision timing. Participants perform the experiment with closed eyes (瞑目) as required by the experimental protocol. The experiment consists of two stages:

1. **Stage 1 (Metronome Stage)**: A fixed-interval metronome plays a series of beats to establish the rhythm.
2. **Stage 2 (Interactive Stage)**: The participant and computer take turns tapping in an alternating pattern.

## Experimental Setup

### Physical Setup

- Computer with PsychoPy installed (using PTB audio backend)
- High-quality headphones for clear audio feedback
- Quiet environment to minimize distractions
- High-precision keyboard (Realforce R3S recommended for low-latency input)

### Participant Instructions

Participants are instructed to:
1. **Close their eyes (瞑目) throughout the experiment** - this is critical for the experimental protocol
2. Listen to the metronome beats in Stage 1
3. Press the space bar in alternating turns with the computer in Stage 2
4. Try to maintain a consistent rhythm throughout
5. Use only the right index finger for tapping

## Experiment Flow

All interactions are through console output and keyboard input (no visual display):

1. **Initialization**: The experiment begins with console instructions
2. **Stage 1**: 
   - The system plays a series of metronome beats at a fixed interval (typically 2 seconds)
   - The participant is instructed to listen to establish the rhythm
   - Duration: 10 beats (configurable)
   - Console displays progress information

3. **Stage 2**:
   - The computer plays the first beat
   - The participant responds by pressing the space bar (with eyes closed)
   - The computer calculates the synchronization error
   - The computer uses this error to predict when to play the next beat
   - This alternating pattern continues
   - Duration: 100 alternating taps (configurable)
   - Progress is reported via console every 10 taps

4. **Completion**: The experiment ends with a console message

## Data Collection

During the experiment, the system records:

1. **Tap Times**: The exact time (in seconds) of each tap from both the computer and participant
2. **Synchronization Errors (SE)**: The difference between the participant's tap and the midpoint of surrounding computer taps
3. **Inter Tap-onset Intervals (ITI)**: The time between consecutive taps
4. **Model State**: For Bayesian models, the system also records the hypothesis probabilities

## Running the Experiment

### Command Line

```bash
python scripts/run_experiment.py --model sea
```

Options:
- `--model`: The model to use ('sea', 'bayes', or 'bib')
- `--span`: Base interval in seconds (default: 2.0)
- `--stage1`: Number of metronome beats in Stage 1 (default: 10)
- `--stage2`: Number of interactive taps in Stage 2 (default: 100)
- `--buffer`: Data buffer size for analysis (default: 10)
- `--scale`: Variance scale for random timing (default: 0.1)

### Programmatically

```python
from src.config import Config
from src.experiment.runner import ExperimentRunner

# Create configuration
config = Config()
config.SPAN = 2.0  # Base interval in seconds
config.STAGE1 = 10  # Metronome beats
config.STAGE2 = 100  # Interactive taps

# Create and run experiment
experiment = ExperimentRunner(config, model_type='bib')
experiment.run()
```

## Data Analysis

After the experiment, you can analyze the data using the provided scripts:

```bash
python scripts/analyze_results.py --model sea
```

This will:
1. Load the experimental data
2. Calculate metrics and statistics
3. Generate visualizations
4. Save the results to the `data/processed` directory

## Experiment Parameters

The experiment is configured using parameters in the `Config` class:

- **SPAN**: Base interval in seconds (default: 2.0)
- **STAGE1**: Number of metronome beats in Stage 1 (default: 10)
- **STAGE2**: Number of interactive taps in Stage 2 (default: 100)
- **BUFFER**: Number of taps to exclude from beginning and end of analysis (default: 10)
- **SCALE**: Variance scale for random timing (default: 0.1)

## Notes on Participant Recruitment

When recruiting participants for the experiment:

1. Ensure diverse age groups and musical backgrounds
2. Provide clear instructions on the task
3. Allow practice trials before the actual experiment
4. Obtain appropriate consent for data collection
5. Debrief participants after the experiment

## Ethical Considerations

- Obtain informed consent from all participants
- Ensure data privacy and anonymity
- Follow institutional research ethics guidelines
- Provide breaks to prevent fatigue