# Contributing to SWIP

Thank you for your interest in contributing to the Synheart Wellness Impact Protocol (SWIP)! This document provides guidelines and information for contributors.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [How to Contribute](#how-to-contribute)
- [Development Process](#development-process)
- [Pull Request Process](#pull-request-process)
- [Issue Guidelines](#issue-guidelines)
- [Documentation](#documentation)
- [Testing](#testing)
- [Release Process](#release-process)

## Code of Conduct

This project and everyone participating in it is governed by our [Code of Conduct](CODE_OF_CONDUCT.md). By participating, you are expected to uphold this code. Please report unacceptable behavior to conduct@synheart.ai.

## Getting Started

1. **Fork the repository** on GitHub
2. **Clone your fork** locally:
   ```bash
   git clone https://github.com/YOUR_USERNAME/swip.git
   cd swip
   ```
3. **Add the upstream remote**:
   ```bash
   git remote add upstream https://github.com/synheart/swip.git
   ```
4. **Create a branch** for your feature:
   ```bash
   git checkout -b feature/your-feature-name
   ```

## How to Contribute

### Types of Contributions

We welcome several types of contributions:

- **Bug fixes** - Fix issues in existing code
- **New features** - Add new functionality
- **Documentation** - Improve or add documentation
- **SDK implementations** - Contribute to platform-specific SDKs
- **Tools** - Develop validation tools, CLI utilities, or simulators
- **Specification improvements** - Enhance the SWIP specification
- **Testing** - Add or improve tests

### Areas Needing Contribution

- **SDK Development**: iOS, Android, Flutter, React Native implementations
- **Validation Tools**: HRV data validation and testing frameworks
- **Documentation**: API references, tutorials, and guides
- **Testing**: Unit tests, integration tests, and validation suites
- **Security**: Security audits and vulnerability assessments

## Development Process

### Branch Naming

Use descriptive branch names:
- `feature/add-ios-sdk` - New features
- `fix/android-crash` - Bug fixes
- `docs/api-reference` - Documentation updates
- `test/integration-tests` - Testing improvements

### Commit Messages

Follow conventional commit format:
```
type(scope): description

[optional body]

[optional footer]
```

Examples:
- `feat(ios): add HRV measurement capability`
- `fix(android): resolve sensor permission issue`
- `docs(api): update authentication examples`
- `test(validator): add edge case validation`

### Code Style

- Follow platform-specific style guides
- Use meaningful variable and function names
- Add comments for complex logic
- Ensure all code is properly formatted

## Pull Request Process

1. **Ensure your branch is up to date**:
   ```bash
   git fetch upstream
   git rebase upstream/main
   ```

2. **Run tests** to ensure nothing is broken:
   ```bash
   # Platform-specific test commands
   npm test          # Node.js projects
   ./gradlew test    # Android
   xcodebuild test   # iOS
   flutter test      # Flutter
   ```

3. **Update documentation** if your changes affect APIs or behavior

4. **Create a pull request** with:
   - Clear title and description
   - Reference to related issues
   - Screenshots for UI changes
   - Test results

5. **Respond to feedback** and make requested changes

### Pull Request Template

```markdown
## Description
Brief description of changes

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation update

## Testing
- [ ] Unit tests pass
- [ ] Integration tests pass
- [ ] Manual testing completed

## Checklist
- [ ] Code follows style guidelines
- [ ] Self-review completed
- [ ] Documentation updated
- [ ] No breaking changes (or documented)
```

## Issue Guidelines

### Before Creating an Issue

1. **Search existing issues** to avoid duplicates
2. **Check documentation** for solutions
3. **Verify the issue** with the latest version

### Issue Types

- **Bug Report**: Something isn't working
- **Feature Request**: New functionality
- **Documentation**: Missing or unclear docs
- **Question**: Need help or clarification

### Bug Report Template

```markdown
**Describe the bug**
A clear description of what the bug is.

**To Reproduce**
Steps to reproduce the behavior.

**Expected behavior**
What you expected to happen.

**Environment**
- OS: [e.g. iOS 15, Android 12]
- SDK Version: [e.g. 1.0.0]
- Device: [e.g. iPhone 13, Samsung Galaxy S21]

**Additional context**
Any other relevant information.
```

## Documentation

### Documentation Standards

- Use clear, concise language
- Include code examples
- Keep documentation up to date
- Follow the existing documentation structure

### Documentation Types

- **API Reference**: Complete API documentation
- **Getting Started**: Quick start guides
- **Developer Guide**: Comprehensive development docs
- **Tutorials**: Step-by-step guides
- **Specifications**: Technical specifications

## Testing

### Test Requirements

- **Unit Tests**: Test individual functions and methods
- **Integration Tests**: Test component interactions
- **End-to-End Tests**: Test complete workflows
- **Performance Tests**: Validate performance requirements

### Test Coverage

- Aim for >80% code coverage
- Test edge cases and error conditions
- Include both positive and negative test cases

## Release Process

### Version Numbering

We follow [Semantic Versioning](https://semver.org/):
- **MAJOR**: Incompatible API changes
- **MINOR**: New functionality (backward compatible)
- **PATCH**: Bug fixes (backward compatible)

### Release Checklist

- [ ] All tests pass
- [ ] Documentation updated
- [ ] Changelog updated
- [ ] Version numbers updated
- [ ] Release notes prepared
- [ ] Security review completed

## Getting Help

- **Documentation**: Check the [docs](docs/) directory
- **Issues**: Search existing [GitHub Issues](https://github.com/synheart/swip/issues)
- **Discussions**: Use [GitHub Discussions](https://github.com/synheart/swip/discussions)
- **Email**: Contact us at dev@synheart.ai

## Recognition

Contributors will be recognized in:
- Release notes
- Contributors list
- Project documentation

Thank you for contributing to SWIP and helping make digital wellness measurable!

---

**Author**: Israel Goytom  
**Organization**: Synheart Open Council (SOC)
