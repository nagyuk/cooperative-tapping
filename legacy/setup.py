"""
Setup script for cooperative-tapping package.
"""
from setuptools import setup, find_packages

setup(
    name="cooperative-tapping",
    version="0.1.0",
    description="Cooperative tapping task with various interaction models",
    author="Kazuto Sasai Lab",
    author_email="example@example.com",
    url="https://github.com/yourusername/cooperative-tapping",
    packages=find_packages(),
    classifiers=[
        "Development Status :: 3 - Alpha",
        "Intended Audience :: Science/Research",
        "License :: OSI Approved :: MIT License",
        "Programming Language :: Python :: 3",
        "Programming Language :: Python :: 3.9",
        "Programming Language :: Python :: 3.10",
        "Programming Language :: Python :: 3.11",
    ],
    python_requires=">=3.9",
    install_requires=[
        "numpy>=1.20.0",
        "scipy>=1.7.0",
        "matplotlib>=3.4.0",
        "pandas>=1.3.0",
        "psychopy>=2023.1.0",
    ],
    entry_points={
        "console_scripts": [
            "run-tapping=scripts.run_experiment:main",
            "analyze-tapping=scripts.analyze_results:main",
        ],
    },
)