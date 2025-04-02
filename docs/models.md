# Models Documentation

This document describes the different models used in the Cooperative Tapping Task project.

## Overview

The project implements three models for tapping interaction:

1. SEA (Synchronization Error Averaging) Model
2. Bayesian Inference Model
3. BIB (Bayesian-Inverse Bayesian) Inference Model

All models implement the same interface defined in the `BaseModel` class, which includes the following methods:

- `inference(se)`: Predicts the next tap timing based on synchronization error
- `reset()`: Resets the model state
- `get_state()`: Returns the current state of the model for logging/analysis

## SEA Model

### Description

The Synchronization Error Averaging (SEA) model is the simplest approach, which adjusts its timing based on the average of past synchronization errors. This model maintains a history of errors and uses their cumulative effect to modify timing.

### Parameters

- `config`: Configuration object with experiment parameters

### Example Usage

```python
from src.config import Config
from src.models import SEAModel

config = Config()
model = SEAModel(config)

# Process synchronization error
next_timing = model.inference(0.05)  # SE of 0.05 seconds

# Reset model
model.reset()
```

## Bayesian Model

### Description

The Bayesian model uses probabilistic inference to adapt to human tapping patterns. It maintains a set of hypotheses about the synchronization error and updates these hypotheses based on observed data.

### Parameters

- `config`: Configuration object
- `n_hypothesis`: Number of hypotheses (default: 20)
- `x_min`: Minimum value for hypothesis space (default: -3)
- `x_max`: Maximum value for hypothesis space (default: 3)

### Example Usage

```python
from src.config import Config
from src.models import BayesModel

config = Config()
model = BayesModel(config, n_hypothesis=30, x_min=-2, x_max=2)

# Process synchronization error
next_timing = model.inference(0.05)  # SE of 0.05 seconds

# Get current hypothesis probabilities
hypotheses = model.get_hypothesis()

# Reset model
model.reset()
```

## BIB Model

### Description

The Bayesian-Inverse Bayesian (BIB) model extends the Bayesian model by allowing the hypothesis space itself to evolve over time. This creates a more flexible and adaptive system that can better mimic human behavior in non-stationary environments.

The key innovation is the "inverse" Bayesian operation, which modifies the model's beliefs (hypotheses) based on recent observations, rather than just updating probability distributions over a fixed set of hypotheses.

### Parameters

- `config`: Configuration object
- `n_hypothesis`: Number of hypotheses (default: 20)
- `l_memory`: Memory length for inverse Bayesian learning (default: 1)
- `x_min`: Minimum value for hypothesis space (default: -3)
- `x_max`: Maximum value for hypothesis space (default: 3)

### Example Usage

```python
from src.config import Config
from src.models import BIBModel

config = Config()
model = BIBModel(config, n_hypothesis=20, l_memory=3)

# Process synchronization error
next_timing = model.inference(0.05)  # SE of 0.05 seconds

# Get current hypothesis probabilities
hypotheses = model.get_hypothesis()

# Reset model
model.reset()
```

## Implementation Details

### Synchronization Error (SE)

The synchronization error is defined as the difference between a player's tap time and the midpoint of adjacent stimulus taps:

```
SE_A(n) = Tap_B(n) - {(Tap_A(n) + Tap_A(n-1))/2}
```

Where:
- `Tap_A` are the stimulus tap times
- `Tap_B` are the player tap times

### Inter Tap-onset Interval (ITI)

The inter tap-onset interval is the time between consecutive taps:

```
ITI_A(n) = Tap_A(n) - Tap_B(n)
```

### Model Outputs

All models output a time interval to wait before the next tap. This is calculated as:

```
interval = (SPAN / 2) - prediction
```

Where:
- `SPAN` is the base interval (typically 2 seconds)
- `prediction` is the model's prediction of synchronization error