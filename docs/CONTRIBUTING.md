# Contributing to Cooperative Tapping Task

Thank you for considering contributing to the Cooperative Tapping Task project. This document provides guidelines for contributing to make the process smooth for everyone.

## Getting Started

### Setting up the development environment

1. Fork the repository on GitHub.
2. Clone your fork locally:
```bash
git clone https://github.com/your-username/cooperative-tapping.git
cd cooperative-tapping
```

3. Create and activate a virtual environment:
```bash
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
```

4. Install development dependencies:
```bash
pip install -r requirements.txt
pip install -e .
```

5. Create a branch for your feature or bug fix:
```bash
git checkout -b feature-or-bugfix-name
```

## Development Workflow

### Code Style

- Follow PEP 8 style guidelines for Python code.
- Use docstrings for all functions, classes, and modules.
- Maximum line length is 100 characters.
- Use 4 spaces for indentation (not tabs).

### Testing

- Write tests for all new code using pytest.
- Run tests before submitting a pull request:
```bash
pytest
```

### Committing Changes

- Commit messages should be clear and concise.
- Include references to issues or bug reports when applicable.
- Keep commits focused on a single change.

### Submitting a Pull Request

1. Push your changes to your fork:
```bash
git push origin feature-or-bugfix-name
```

2. Go to the GitHub page of your fork and create a new pull request.
3. Provide a clear description of the changes and their purpose.
4. Link to any relevant issues.

## Project Structure

Please maintain the existing project structure:

- `src/models/`: Model implementations
- `src/experiment/`: Experiment runner and UI
- `src/analysis/`: Data analysis and visualization tools
- `scripts/`: Command-line utilities
- `tests/`: Test cases

## Adding a New Model

1. Create a new file in `src/models/` that extends `BaseModel`.
2. Implement the required methods: `inference()`, `reset()`, and `get_state()`.
3. Register the model in `src/models/__init__.py`.
4. Add appropriate test cases in `tests/`.
5. Update documentation.

## Modifying Experiment Parameters

Any changes to default experiment parameters should be made in `src/config.py` and should be configurable through command-line arguments.

## Code of Conduct

- Be respectful and considerate in all communications.
- Constructive criticism is welcome, but should be focused on the code, not the person.
- Harassment, offensive comments, or any form of discrimination will not be tolerated.

## Questions

If you have any questions about the project or the contribution process, please open an issue on GitHub or contact the project maintainers.

Thank you for contributing!