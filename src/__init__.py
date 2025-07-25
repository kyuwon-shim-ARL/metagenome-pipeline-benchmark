"""
Metagenome Pipeline Benchmarking Framework

A comprehensive framework for evaluating and comparing metagenome analysis pipelines.
"""

__version__ = "0.1.0"
__author__ = "Research Team"
__email__ = "research@example.com"

from .pipeline_interface import BasePipeline, NfCoreMagPipeline
from .evaluation import UniversalEvaluator
from .comparison import PipelineComparator

__all__ = [
    "BasePipeline",
    "NfCoreMagPipeline", 
    "UniversalEvaluator",
    "PipelineComparator",
]