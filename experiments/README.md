# MATLAB Implementation for Cooperative Tapping

## Overview

This directory contains the MATLAB implementation of the cooperative tapping experiment, utilizing Psychtoolbox (PTB) for high-precision timing and audio control.

## Directory Structure

```
matlab/
├── src/              # Core MATLAB source files
├── experiments/      # Experiment scripts and classes
├── utils/            # Utility functions
├── config/           # Configuration files
└── tests/            # Unit tests
```

## Requirements

- MATLAB R2021b or later
- Psychtoolbox-3
- Signal Processing Toolbox (optional)
- Statistics and Machine Learning Toolbox (optional)

## Installation

1. Install Psychtoolbox:
   ```matlab
   >> DownloadPsychtoolbox
   ```

2. Add this directory to MATLAB path:
   ```matlab
   >> addpath(genpath('/Users/sasailab/cooperative-tapping/matlab'))
   ```

## Features

- High-precision timing control (sub-millisecond accuracy)
- Low-latency audio playback using PsychPortAudio
- Real-time data acquisition and processing
- Integration with Python models via MATLAB Engine API

## Usage

See `experiments/` directory for example experiment scripts.
