# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a **MATLAB-based cooperative tapping experiment system** for studying human-computer rhythmic interaction. It implements three different models (SEA, Bayesian, BIB) to simulate computer timing behavior during alternating tapping tasks. The system uses **PsychToolbox** for high-precision audio and timing control.

## Conversation Guidelines

- 常に日本語で会話する

## Quick Start

### Prerequisites
- MATLAB R2025a or later
- PsychToolbox (included in project)
- Scarlett 4i4 audio interface (recommended for high-precision timing)

### Setup
```matlab
% 1. PsychToolbox setup (one-time only)
setup_psychtoolbox

% 2. Run unified experiment system (OOP version)
clear classes; rehash toolboxcache
run_unified_experiment

% Choose experiment type:
%   1. Human-Computer (SEA/Bayesian/BIB models)
%   2. Human-Human (cooperative tapping)
```

## System Architecture

### ✅ Current Production System (October 2025)

**Unified OOP Architecture (2025-10-09):**

The system uses object-oriented design with inheritance for code reusability and maintainability.

**Main Components:**
- `run_unified_experiment.m` - Unified entry point for all experiment types
- `experiments/base/BaseExperiment.m` - Base class with common functionality
- `experiments/human_computer/HumanComputerExperiment.m` - Human-computer experiments
- `experiments/human_human/HumanHumanExperiment.m` - Human-human cooperative experiments
- `core/audio/AudioSystem.m` - PsychPortAudio integration
- `core/timing/TimingController.m` - High-precision timing control
- `core/data/DataRecorder.m` - Unified data recording and CSV export
- `setup_psychtoolbox.m` - PsychToolbox configuration
- `create_optimized_audio.m` - Audio optimization utility

**Legacy Components (archived):**
- `main_experiment.m` - Original monolithic experiment script (pre-OOP)
- `run_experiment.m` - Original entry point (pre-OOP)

### Core Features

**🎯 High-Precision Audio System:**
- **PsychPortAudio** backend with sub-millisecond precision
- **Scarlett 4i4** integration (6.8ms output latency)
- **Optimized audio files**: 22.05kHz mono for minimal latency
- **完全な1秒間隔精度**: Stage1メトロノームで完璧な規則性

**⚡ Real-time Performance:**
- **Global timing reference**: All recordings use unified `experiment_clock_start`
- **High-precision key input**: Optimized keyboard detection system
- **Unified data recording**: stim_tap and player_tap synchronized timestamps

**🔬 Experiment Design:**
- **Stage 1**: Perfect 1.0-second interval metronome for rhythm establishment
- **Stage 2**: Cooperative alternating tapping with model adaptation
- **Models**: SEA, Bayesian, BIB for computer timing prediction

**🏗️ OOP Architecture:**
- **BaseExperiment**: Abstract base class with common experiment flow
  - Audio system initialization with warmup
  - Timing controller with unified clock
  - Data recorder with CSV export
  - Keyboard input handling
  - Display management
- **HumanComputerExperiment**: Extends BaseExperiment
  - Model selection (SEA/Bayesian/BIB)
  - Stage1: Automatic metronome playback
  - Stage2: Human-computer alternating tapping with SE calculation
- **HumanHumanExperiment**: Extends BaseExperiment
  - Two-player setup (S/C keys, 4-channel audio)
  - Stage1: Two-tone metronome (both players hear both sounds)
  - Stage2: Player-initiated alternating tapping (each hears opponent's sound)

### Directory Structure

```
cooperative-tapping/
├── run_unified_experiment.m      # Unified entry point (OOP system)
├── setup_psychtoolbox.m          # PsychToolbox setup
├── create_optimized_audio.m      # Audio optimization tool
├── CLAUDE.md                     # This file
├── experiments/                  # OOP experiment framework
│   ├── base/
│   │   └── BaseExperiment.m      # Abstract base class
│   ├── human_computer/
│   │   ├── HumanComputerExperiment.m
│   │   └── run_human_computer.m  # Entry script
│   └── human_human/
│       ├── HumanHumanExperiment.m
│       └── run_human_human.m     # Entry script
├── core/                         # Core system components
│   ├── audio/
│   │   └── AudioSystem.m         # PsychPortAudio wrapper
│   ├── timing/
│   │   └── TimingController.m    # High-precision timing
│   └── data/
│       └── DataRecorder.m        # Data recording & CSV export
├── models/                       # Timing prediction models
│   ├── SEAModel.m                # Synchronization Error Averaging
│   ├── BayesianModel.m           # Bayesian inference
│   └── BIBModel.m                # Bayesian-Inverse Bayesian
├── assets/
│   └── sounds/
│       ├── stim_beat_optimized.wav    # Stimulus sound (22.05kHz)
│       └── player_beat_optimized.wav  # Player sound (22.05kHz)
├── data/
│   └── raw/
│       ├── human_computer/YYYYMMDD/[participant]_[model]_[timestamp]/
│       │   ├── experiment_data.mat
│       │   ├── stage1_synchronous_taps.csv
│       │   └── stage2_alternating_taps.csv
│       └── human_human/YYYYMMDD/[p1]_[p2]_human_human_[timestamp]/
│           ├── experiment_data.mat
│           ├── stage1_metronome.csv
│           └── stage2_cooperative_taps.csv
├── docs/                         # Documentation
│   ├── audio_warmup_necessity.md # Critical audio warmup explanation
│   └── ...
├── legacy/                       # Original Python system (deprecated)
├── archive/                      # Development history
│   └── pre-oop-system/          # Original main_experiment.m (archived)
└── Psychtoolbox/                # PsychToolbox installation
```

### Data Output Format

Each experiment generates timestamped data in both MAT and CSV formats:

**Human-Computer Experiments:**
- `experiment_data.mat` - Full MATLAB data structure
- `stage1_synchronous_taps.csv` - Stage1 metronome events
- `stage2_alternating_taps.csv` - Stage2 tapping data with SE and predicted intervals

**Human-Human Experiments:**
- `experiment_data.mat` - Full MATLAB data structure
- `stage1_metronome.csv` - Stage1 two-tone metronome events
- `stage2_cooperative_taps.csv` - Stage2 alternating tapping data

**Common features:**
- **Unified timing**: All timestamps relative to `timer.start()`
- **Structured metadata**: Participant IDs, model type, experiment settings
- **CSV compatibility**: Ready for R/Python statistical analysis

## Model System

### Model Types
1. **SEA (Synchronization Error Averaging)**: Simple averaging of timing errors
2. **Bayesian**: Probabilistic inference for timing prediction
3. **BIB (Bayesian-Inverse Bayesian)**: Advanced dual-model approach

### Model Interface
All models inherit from a common interface and implement:
- `predict_next_interval(se)` - Predict next interval from synchronization error
- `get_model_info()` - Return model configuration string
- Real-time adaptation during Stage2 interaction

Models are instantiated with experiment configuration:
```matlab
model = SEAModel(experiment_config);
interval = model.predict_next_interval(se);
```

## Audio System Details

### PsychPortAudio Integration
- **Latency Class 2**: Maximum precision mode
- **Pre-buffered audio**: Eliminates loading delays
- **Automatic device selection**: Prefers Scarlett 4i4 when available
- **Error handling**: Graceful fallbacks for audio failures

### Timing Achievements
- **Perfect Stage1 metronome**: Exact 1.0-second intervals
- **Sub-millisecond precision**: PsychPortAudio + GetSecs timing
- **Synchronized recording**: Unified timestamp reference via TimingController
- **Audio warmup**: Critical 200-300ms first-playback delay eliminated (see `docs/audio_warmup_necessity.md`)
- **Precise event recording**: `record_event()` called immediately before `play_buffer()` for minimal timestamp-to-sound delay

## Development History

### 🏗️ OOP Refactoring (2025-10-09)
1. **Object-oriented architecture**: Migrated from monolithic `main_experiment.m` to modular OOP system
2. **BaseExperiment abstraction**: Common functionality (audio, timing, data recording) extracted to base class
3. **Experiment-specific implementations**: HumanComputerExperiment and HumanHumanExperiment extend BaseExperiment
4. **Core system components**: AudioSystem, TimingController, DataRecorder as reusable modules
5. **Critical fixes applied**:
   - Method access permissions (public/protected consistency)
   - Resource initialization order (audio system before buffer preparation)
   - Audio warmup integration (eliminates first-sound delay)
   - Timer start timing (immediately after user input)
   - Event recording timing (immediately before audio playback)

### 🎉 Major Achievements (2025-10-07)
1. **Complete PsychPortAudio migration**: From unreliable `sound()` to professional audio
2. **Perfect timing precision**: Eliminated all irregular rhythm problems
3. **Unified timestamp system**: Resolved 20+ second timing offsets between data streams
4. **Production-ready system**: Professional audio interface integration

### 🔧 Technical Solutions Applied
- **Audio Backend Replacement**: `sound()` → `PsychPortAudio`
- **OOP Architecture**: Monolithic script → BaseExperiment + specialized subclasses
- **Timing Reference Unification**: Single clock via TimingController
- **Data Synchronization**: Proper array length management via DataRecorder
- **Resource Management**: Automatic cleanup and error handling in destructors

### 📊 Performance Metrics
- **Audio Latency**: 6.848ms (with Scarlett 4i4)
- **Timing Precision**: Sub-millisecond accuracy
- **Stage1 Regularity**: Perfect 1.0-second intervals
- **Data Integrity**: Zero timestamp synchronization errors

## Troubleshooting

### Common Issues
```matlab
% PsychToolbox not recognized
setup_psychtoolbox

% Class definition changes not recognized
clear classes
rehash toolboxcache

% Audio device issues
InitializePsychSound(1)  % Force reinitialize

% Timing precision check
GetSecs  % Should return current time

% Method access permission errors
% Solution: Ensure overridden methods match or broaden parent class access level
% Example: BaseExperiment defines display_results as public → subclass must be public
```

### System Requirements
- **MATLAB**: R2025a+ with Signal Processing Toolbox
- **Audio Hardware**: Professional audio interface recommended
- **PsychToolbox**: Version 3.0.22+ (included)

## Legacy Systems

- **Python version**: Available in `legacy/` directory (deprecated)
- **Pre-OOP MATLAB system**: `main_experiment.m` archived in `archive/pre-oop-system/` (functional but monolithic)
- **Early MATLAB attempts**: Other historical experiments in `archive/` directory
- **Development files**: Historical optimization efforts preserved

---

## Key Implementation Notes

### Audio Warmup (CRITICAL - DO NOT REMOVE)
The `AudioSystem.warmup_audio()` call is **essential** and must not be removed:
- PsychPortAudio has 200-300ms hardware initialization delay on first `Start()` call
- Without warmup, Stage1's first two sounds have incorrect timing (audibly shorter interval)
- Warmup plays silent audio before experiment to pre-initialize hardware
- See `docs/audio_warmup_necessity.md` for detailed explanation

### Timing Precision Pattern
```matlab
% CORRECT: Minimal delay between timestamp and sound
actual_time = obj.timer.record_event();  % Record timestamp
obj.audio.play_buffer(buffer, 0);        % Play immediately

% WRONG: Processing delays introduce timing errors
actual_time = obj.timer.record_event();
fprintf('Playing sound...\n');  % Delay!
obj.audio.play_buffer(buffer, 0);
```

### Resource Initialization Order
```matlab
% In BaseExperiment.execute():
1. Constructor (participant info, create recorder)
2. initialize_systems() (create audio, timer, window)
3. Subclass prepare_audio_buffers() (after audio exists)
4. display_instructions() (timer.start() after user input)
5. run_stage1() / run_stage2()
```

---

**Project Status**: ✅ **Production Ready** - High-precision cooperative tapping experiment system with professional OOP architecture, PsychPortAudio backend, and perfect timing accuracy.