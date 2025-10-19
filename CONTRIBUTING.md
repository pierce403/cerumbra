# Contributing to Cerumbra

Thank you for your interest in contributing to Cerumbra! This document provides guidelines for contributing to the project.

## 🎯 Areas of Contribution

We welcome contributions in the following areas:

### 1. Core Protocol
- Production TEE integration (NVIDIA Blackwell)
- Enhanced attestation mechanisms
- Additional cryptographic protocols
- Performance optimizations

### 2. Security
- Security audits and reviews
- Threat model refinement
- Cryptographic protocol analysis
- Vulnerability reporting

### 3. Documentation
- Tutorial improvements
- API documentation
- Architecture diagrams
- Use case examples

### 4. Testing
- Unit tests
- Integration tests
- Security testing
- Performance benchmarks

### 5. Tooling
- Developer tools
- Debugging utilities
- Monitoring and logging
- CI/CD improvements

## 🚀 Getting Started

1. Fork the repository
2. Clone your fork: `git clone https://github.com/your-username/cerumbra.git`
3. Create a feature branch: `git checkout -b feature/your-feature-name`
4. Install dependencies: `pip install -r requirements.txt`
5. Make your changes
6. Test your changes
7. Commit with clear messages: `git commit -m "Add feature: description"`
8. Push to your fork: `git push origin feature/your-feature-name`
9. Open a Pull Request

## 📝 Code Style

### Python
- Follow PEP 8 style guidelines
- Use type hints where appropriate
- Document functions with docstrings
- Keep functions focused and modular

### JavaScript
- Use modern ES6+ features
- Prefer `const` and `let` over `var`
- Use async/await for asynchronous code
- Document complex logic with comments

### HTML/CSS
- Use semantic HTML5 elements
- Follow BEM naming convention for CSS classes
- Ensure accessibility (ARIA labels, semantic structure)
- Test responsive design

## 🔒 Security Guidelines

### Reporting Security Issues
- **Do not** open public issues for security vulnerabilities
- Email security concerns to: [maintainer email]
- Provide detailed description and reproduction steps
- Allow time for fix before public disclosure

### Security Best Practices
- Never commit secrets or private keys
- Use cryptographically secure random number generators
- Validate all inputs
- Follow principle of least privilege
- Keep dependencies updated

## ✅ Pull Request Process

1. **Before submitting:**
   - Ensure all tests pass
   - Update documentation if needed
   - Add tests for new features
   - Follow code style guidelines
   - Rebase on latest main branch

2. **PR Description:**
   - Clear title describing the change
   - Detailed description of what and why
   - Reference related issues
   - Include screenshots for UI changes
   - List breaking changes if any

3. **Review Process:**
   - Address reviewer feedback
   - Keep PR focused and atomic
   - Be responsive to comments
   - Update PR based on feedback

4. **After Approval:**
   - Squash commits if requested
   - Ensure CI passes
   - Wait for maintainer merge

## 🧪 Testing

### Running Tests
```bash
# Python tests (when available)
python -m pytest

# Run example to verify crypto operations
python3 example.py

# Test server startup
python3 server.py
```

### Writing Tests
- Write tests for new features
- Ensure edge cases are covered
- Use descriptive test names
- Mock external dependencies

## 📚 Documentation

### Code Documentation
- Document all public APIs
- Explain complex algorithms
- Include usage examples
- Keep documentation up-to-date

### README Updates
- Update README for new features
- Keep setup instructions current
- Add new examples as needed
- Update roadmap when appropriate

## 🎨 Design Guidelines

### User Interface
- Maintain consistent design language
- Ensure accessibility (WCAG 2.1 AA)
- Test on multiple browsers
- Optimize for performance

### API Design
- Keep APIs simple and intuitive
- Follow REST principles for HTTP APIs
- Use clear, descriptive names
- Version APIs appropriately

## 📄 License

By contributing to Cerumbra, you agree that your contributions will be licensed under the Apache License 2.0.

## 🤝 Code of Conduct

### Our Pledge
We are committed to providing a welcoming and inclusive environment for all contributors.

### Expected Behavior
- Be respectful and considerate
- Welcome diverse perspectives
- Provide constructive feedback
- Focus on what's best for the project

### Unacceptable Behavior
- Harassment or discrimination
- Trolling or insulting comments
- Personal or political attacks
- Publishing others' private information

## 💬 Communication

### Channels
- GitHub Issues: Bug reports and feature requests
- GitHub Discussions: General questions and ideas
- Pull Requests: Code contributions

### Response Times
- Issues: We aim to respond within 48 hours
- Pull Requests: Initial review within 1 week
- Security Issues: Response within 24 hours

## 🎓 Learning Resources

### Cryptography
- [Web Crypto API](https://developer.mozilla.org/en-US/docs/Web/API/Web_Crypto_API)
- [Cryptography Documentation](https://cryptography.io/)
- [ECDH Key Exchange](https://en.wikipedia.org/wiki/Elliptic-curve_Diffie%E2%80%93Hellman)

### TEE/Confidential Computing
- [NVIDIA Confidential Computing](https://www.nvidia.com/en-us/data-center/solutions/confidential-computing/)
- [TEE Basics](https://en.wikipedia.org/wiki/Trusted_execution_environment)
- [Remote Attestation](https://en.wikipedia.org/wiki/Trusted_Computing#Remote_attestation)

### WebSocket
- [WebSocket Protocol](https://developer.mozilla.org/en-US/docs/Web/API/WebSocket)
- [Python websockets Library](https://websockets.readthedocs.io/)

## 🙏 Thank You!

Thank you for contributing to Cerumbra and helping build the future of private AI inference!
