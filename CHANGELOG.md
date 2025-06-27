# Changelog

All notable changes to the Cooperative Tapping Task project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased] - 2025-01-01

### Changed
- Implemented minimal window approach (1x1 pixel) instead of complete windowless operation
  - PsychoPy's `event.getKeys()` requires a window context for keyboard event detection
  - The minimal window ensures reliable millisecond-precision timing while maintaining console-based interface
  - Window is automatically minimized where possible to remain invisible during experiments
- Updated documentation to reflect the minimal window implementation
- Modified experiment configuration to record window mode as "MinimalWindow"

### Technical Details
- Window size: 1x1 pixel
- Position: Center of primary display (0, 0)
- Window type: pyglet (for compatibility)
- VSynx disabled (`waitBlanking=False`) for improved timing precision
- Audio backend: PTB (as required for millisecond precision)

### Notes
- Participants still perform the experiment with closed eyes (瞑目) as per protocol
- All interaction remains primarily through console interface
- The minimal window does not interfere with the experimental protocol

## [0.2.0] - 2024-12-15

### Added
- Windowless experiment implementation attempt
- Console-based interaction for participants with closed eyes (瞑目)
- PTB audio backend optimization for millisecond-precision timing

### Changed
- Removed visual window dependencies from experiment runner
- Migrated all feedback to console output

## [0.1.0] - 2024-11-01

### Added
- Initial implementation of cooperative tapping task
- Three models: SEA, Bayesian, and BIB
- Basic experiment runner with visual window
- Data analysis and visualization tools
