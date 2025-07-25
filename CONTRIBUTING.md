# Contributing to Metagenome Pipeline Benchmarking Framework

We welcome contributions from the community! This document provides guidelines for contributing to the project.

## Getting Started

1. **Fork the repository** on GitHub
2. **Clone your fork** locally:
   ```bash
   git clone https://github.com/YOUR_USERNAME/metagenome-pipeline-benchmark.git
   cd metagenome-pipeline-benchmark
   ```
3. **Set up the development environment**:
   ```bash
   ./bin/setup_environment.sh
   conda activate metagenome-benchmark
   INSTALL_DEV=true ./bin/setup_environment.sh
   ```

## Development Workflow

### Setting Up Development Environment

```bash
# Install development dependencies
uv pip install -e ".[dev,viz,workflow]"

# Set up pre-commit hooks
pre-commit install
```

### Making Changes

1. **Create a new branch** for your feature:
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Make your changes** following our coding standards

3. **Run tests**:
   ```bash
   pytest tests/
   ```

4. **Check code quality**:
   ```bash
   # Format code
   black src/ tests/
   
   # Lint code
   ruff src/ tests/
   
   # Type checking
   mypy src/
   ```

5. **Commit your changes**:
   ```bash
   git add .
   git commit -m "Add feature: your feature description"
   ```

6. **Push to your fork**:
   ```bash
   git push origin feature/your-feature-name
   ```

7. **Create a Pull Request** on GitHub

## Types of Contributions

### 🐛 Bug Reports

Please use the GitHub issue template and include:
- Clear description of the bug
- Steps to reproduce
- Expected vs actual behavior
- Environment details (OS, Python version, etc.)

### 🚀 Feature Requests

Before submitting a feature request:
- Check if it already exists in issues
- Explain the use case and benefit
- Consider if it fits the project scope

### 📖 Documentation

Documentation improvements are always welcome:
- Fix typos or unclear explanations
- Add examples or tutorials
- Improve API documentation

### 🔧 Code Contributions

#### Adding New Pipelines

To add support for a new pipeline:

1. **Create pipeline wrapper**:
   ```
   pipelines/external/your_pipeline/
   ├── wrapper.py          # Pipeline interface implementation
   ├── config.template     # Configuration template
   └── README.md          # Pipeline-specific documentation
   ```

2. **Register in pipeline registry**:
   ```yaml
   # configs/pipeline_registry.yml
   your_pipeline:
     type: "external"
     wrapper: "pipelines/external/your_pipeline/"
     variants:
       standard:
         description: "Standard configuration"
   ```

3. **Add tests**:
   ```python
   # tests/test_your_pipeline.py
   def test_your_pipeline_execution():
       # Test pipeline execution
       pass
   ```

#### Adding Evaluation Metrics

To add new evaluation metrics:

1. **Implement metric class**:
   ```python
   # src/evaluation/your_metric.py
   from .base_metric import BaseMetric
   
   class YourMetric(BaseMetric):
       def calculate(self, pipeline_results, ground_truth=None):
           # Implementation
           pass
   ```

2. **Register metric**:
   ```python
   # src/evaluation/__init__.py
   from .your_metric import YourMetric
   ```

3. **Add configuration**:
   ```yaml
   # configs/pipeline_registry.yml
   evaluation_metrics:
     your_metric:
       - enabled: true
       - parameters: {}
   ```

## Coding Standards

### Python Style

- Follow **PEP 8** style guide
- Use **Black** for code formatting
- Use **Ruff** for linting
- Use **type hints** for all functions
- Maximum line length: **88 characters**

### Documentation

- Use **Google-style docstrings**
- Include examples in docstrings
- Update relevant documentation files

### Testing

- Write tests for all new functionality
- Aim for >80% test coverage
- Use meaningful test names
- Include both unit and integration tests

### Commit Messages

Follow conventional commit format:
```
type(scope): description

[optional body]

[optional footer]
```

Types:
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes
- `refactor`: Code refactoring
- `test`: Test additions/modifications
- `chore`: Maintenance tasks

Examples:
```
feat(pipeline): add MetaWRAP pipeline support
fix(evaluation): correct BUSCO score calculation
docs(readme): update installation instructions
```

## Review Process

1. **Automated checks** must pass (CI/CD)
2. **Code review** by maintainers
3. **Testing** on different environments
4. **Documentation** review if applicable

## Getting Help

- **GitHub Discussions**: General questions and ideas
- **GitHub Issues**: Bug reports and feature requests
- **Email**: [research@example.com] for sensitive issues

## Recognition

Contributors will be acknowledged in:
- README.md contributor section
- Release notes
- Academic publications (for significant contributions)

Thank you for contributing to the project! 🙏