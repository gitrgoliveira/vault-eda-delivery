# This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0.
# If a copy of the MPL was not distributed with this file, You can obtain one at https://mozilla.org/MPL/2.0/.
# Release Guide

This document describes how to release new versions of the Vault EDA collection using the enhanced automated GitHub Actions workflow.

## Overview

The collection uses a comprehensive, multi-stage GitHub Actions workflow for building, testing, and publishing releases to Ansible Galaxy. The workflow includes matrix testing across multiple Python and Ansible versions, enhanced security measures, and comprehensive validation.

## Prerequisites

### 1. Ansible Galaxy API Key

1. Go to [Ansible Galaxy My Preferences](https://galaxy.ansible.com/me/preferences)
2. Generate or copy your API key
3. Add it as a GitHub repository secret:
   - Go to repository Settings → Secrets and variables → Actions
   - Click "New repository secret"
   - Name: `GALAXY_API_KEY`
   - Value: Your API key

### 2. Repository Settings

1. **Environment Protection**: Create a `release` environment in repository settings for additional protection
2. **Required Permissions**: 
   - Write access to the repository
   - Ability to create releases
   - Ability to push tags
3. **Branch Protection**: Ensure main branch has required reviews and status checks

### 3. Local Development Setup

```bash
# Install development dependencies
pip install ansible-core>=2.14 websockets>=10.0 PyYAML

# Verify collection builds locally
cd collections/ansible_collections/gitrgoliveira/vault
ansible-galaxy collection build --verbose
```

## Enhanced Release Workflow Features

### Multi-Matrix Validation
- **Python versions**: 3.9, 3.10, 3.11, 3.12
- **Ansible Core versions**: 2.14, 2.15, 2.16, 2.17
- **Compatibility checks**: Automatic exclusion of incompatible combinations
- **Dependency caching**: Faster workflow execution with pip caching

### Enhanced Security
- **Explicit permissions**: Minimal required permissions (contents: write, id-token: write, checks: read)
- **Environment protection**: Uses `release` environment for publishing
- **Secret validation**: Comprehensive checks for required secrets

### Comprehensive Testing
- **Structure validation**: Collection structure and galaxy.yml format validation
- **Import testing**: Plugin import verification across all matrix combinations
- **Dependency verification**: WebSocket and other dependency availability checks
- **Tarball validation**: Size limits and content verification

## Release Methods

### Method 1: Manual Workflow Dispatch (Recommended)

This method provides the most control and visibility into the release process.

1. **Update version in galaxy.yml**:
   ```yaml
   # In collections/ansible_collections/gitrgoliveira/vault/galaxy.yml
   version: 1.0.1  # Update to new version following semantic versioning
   ```

2. **Update CHANGELOG.md**:
   ```markdown
   # Changelog
   
   ## [1.0.1] - 2025-01-15
   
   ### Added
   - New feature descriptions
   
   ### Changed
   - Modified behavior descriptions
   
   ### Fixed
   - Bug fix descriptions
   
   ### Security
   - Security improvement descriptions
   ```

3. **Commit and push changes**:
   ```bash
   git add collections/ansible_collections/gitrgoliveira/vault/galaxy.yml
   git add collections/ansible_collections/gitrgoliveira/vault/CHANGELOG.md
   git commit -m "Release v1.0.1: Brief description of changes"
   git push origin main
   ```

4. **Trigger release workflow**:
   - Go to **Actions** → **"Release Ansible Collection"**
   - Click **"Run workflow"**
   - Select branch: `main`
   - Enter version number: `1.0.1` (must match galaxy.yml)
   - Click **"Run workflow"**

5. **Monitor the workflow**:
   - **Validation stage**: Monitor matrix testing across Python/Ansible versions
   - **Build stage**: Check collection building and comprehensive validation
   - **Publishing stage**: Verify Galaxy publication and GitHub release creation
   - **Logs**: Review detailed logs for any issues or warnings

### Method 2: Automated Release on GitHub Release

This method automatically triggers when you create a GitHub release.

1. **Prepare release** (same as Method 1, steps 1-3)

2. **Create GitHub Release**:
   - Go to repository **Releases** page
   - Click **"Create a new release"**
   - Tag: `v1.0.1` (will be created automatically)
   - Title: `Release v1.0.1`
   - Description: Copy from CHANGELOG.md
   - Click **"Publish release"**

3. **Workflow triggers automatically** and follows the same validation→build→publish process

### Method 3: Local Development/Testing Release

For testing the release process or when GitHub Actions are unavailable:

1. **Set up environment**:
   ```bash
   export GALAXY_API_KEY="your_api_key_here"
   cd collections/ansible_collections/gitrgoliveira/vault
   ```

2. **Build and validate**:
   ```bash
   # Build collection
   ansible-galaxy collection build --verbose
   
   # Test locally
   ansible-galaxy collection install gitrgoliveira-vault-*.tar.gz --force
   
   # Verify import works
   python -c "from ansible_collections.gitrgoliveira.vault.plugins.event_source.vault_events import main; print('✓ Import successful')"
   ```

3. **Publish manually** (optional):
   ```bash
   ansible-galaxy collection publish gitrgoliveira-vault-*.tar.gz --api-key "$GALAXY_API_KEY"
   ```

## Enhanced Release Workflow Details

The GitHub Actions workflow consists of two main jobs:

### 1. Validation Job (`validate`)

**Purpose**: Ensure collection works across supported environments before release

**Matrix Testing**:
- Tests **4 Python versions** × **4 Ansible Core versions** = **16 combinations**
- Excludes incompatible combinations (Python 3.12 with older Ansible versions)
- Uses dependency caching for faster execution

**Validation Steps**:
1. **Environment Setup**: Python + Ansible Core installation
2. **Structure Validation**: Collection directory structure and file integrity  
3. **Build Testing**: `ansible-galaxy collection build` across all combinations
4. **Installation Testing**: Local installation and import verification
5. **Plugin Testing**: Verify main plugin can be imported successfully

### 2. Build and Publish Job (`build-and-publish`)

**Purpose**: Build final collection and publish to Galaxy + GitHub

**Requirements**:
- Runs only after successful validation
- Uses `release` environment for additional security
- Requires manual approval if environment protection is enabled

**Enhanced Validation**:
1. **galaxy.yml Structure**: YAML parsing and required field validation
2. **Semantic Versioning**: Version format validation (x.y.z)
3. **Version Consistency**: Input version vs galaxy.yml version matching
4. **Dependency Verification**: WebSocket and other required dependencies
5. **Tarball Validation**: Size limits (2MB Galaxy limit) and content verification

**Publishing Process**:
1. **Collection Build**: Clean build with detailed output
2. **Galaxy Publication**: Uses `--wait` flag for immediate feedback
3. **Artifact Upload**: Collection tarball with 90-day retention
4. **GitHub Release**: Rich release notes with installation instructions and links

### Workflow Security Features

- **Minimal Permissions**: Only required permissions granted
- **Secret Protection**: Validates API key presence before use
- **Environment Protection**: Uses protected `release` environment
- **Dependency Integrity**: Verifies all dependencies before publication

## Supported Environments

### Python Versions
- **3.9**: Minimum supported version
- **3.10**: Current stable
- **3.11**: Current stable  
- **3.12**: Latest stable

### Ansible Core Versions
- **2.14**: LTS, minimum supported
- **2.15**: Stable
- **2.16**: Current stable
- **2.17**: Latest stable

### Excluded Combinations
- Python 3.12 with Ansible Core 2.14/2.15 (compatibility issues)

## Release Artifacts

Each successful release creates:

1. **Ansible Galaxy Package**: `gitrgoliveira.vault:x.y.z`
2. **GitHub Release**: With changelog and installation instructions  
3. **Collection Artifact**: Downloadable `.tar.gz` file (90-day retention)
4. **Git Tag**: `vx.y.z` for version tracking

## Version Management

### Semantic Versioning

Follow [semantic versioning](https://semver.org/):

- **MAJOR** (1.0.0 → 2.0.0): Breaking changes
- **MINOR** (1.0.0 → 1.1.0): New features, backward compatible
- **PATCH** (1.0.0 → 1.0.1): Bug fixes, backward compatible

### Pre-release Versions

For testing:
- Alpha: `1.1.0-alpha.1`
- Beta: `1.1.0-beta.1`
- Release Candidate: `1.1.0-rc.1`

## Troubleshooting

### Common Issues and Solutions

#### 1. API Key Issues
```
Error: GALAXY_API_KEY secret not set
```
**Solutions**:
- Verify the secret is set in repository Settings → Secrets and variables → Actions
- Check API key hasn't expired on [Ansible Galaxy](https://galaxy.ansible.com/me/preferences)
- Ensure the API key has correct permissions for the namespace

#### 2. Version Conflicts
```
Error: Version already exists on Galaxy
```
**Solutions**:
- Increment version number in `galaxy.yml`
- Ensure version follows semantic versioning (x.y.z format)
- Check Galaxy page to see what versions already exist

#### 3. Matrix Job Failures
```
Error: Collection plugin import failed
```
**Solutions**:
- Check specific Python/Ansible combination that failed
- Review plugin dependencies and compatibility
- Test locally with same Python/Ansible versions:
  ```bash
  python3.11 -m pip install ansible-core==2.16.*
  ansible-galaxy collection build
  ansible-galaxy collection install gitrgoliveira-vault-*.tar.gz --force
  ```

#### 4. Collection Build Failures
```
Error: Collection build failed
```
**Solutions**:
- Check for missing required files in collection structure
- Validate `galaxy.yml` syntax:
  ```bash
  python -c "import yaml; yaml.safe_load(open('galaxy.yml'))"
  ```
- Ensure all dependencies are properly specified
- Check file permissions and accessibility

#### 5. Publishing Failures
```
Error: HTTP 403 Forbidden
```
**Solutions**:
- Check API key permissions on Ansible Galaxy
- Verify namespace ownership (`custom` namespace access)
- Ensure API key isn't expired or revoked

#### 6. Tarball Size Issues
```
Error: Collection tarball exceeds 2MB limit
```
**Solutions**:
- Review included files and use `build_ignore` in `galaxy.yml`:
  ```yaml
  build_ignore:
    - '*.log'
    - 'tests/output'
    - '.pytest_cache'
    - '__pycache__'
  ```
- Remove large unnecessary files
- Optimize documentation and examples

#### 7. Environment Protection Issues
```
Error: Required reviewers not met
```
**Solutions**:
- If `release` environment protection is enabled, required reviewers must approve
- Check repository Settings → Environments → release
- Disable environment protection for automated releases if appropriate

### Advanced Troubleshooting

#### Local Debugging
```bash
# Test collection build locally
cd collections/ansible_collections/gitrgoliveira/vault
ansible-galaxy collection build --verbose

# Test specific Python/Ansible combination
python3.11 -m venv test-env
source test-env/bin/activate
pip install ansible-core==2.16.*
ansible-galaxy collection install gitrgoliveira-vault-*.tar.gz --force

# Test plugin import
python -c "from ansible_collections.gitrgoliveira.vault.plugins.event_source.vault_events import main; print('Success')"
```

#### Workflow Debugging
- Check workflow logs in GitHub Actions for detailed error messages
- Review specific matrix job that failed
- Look for patterns across multiple matrix combinations
- Check GitHub Actions status page for service issues

#### Manual Recovery
If automated release fails completely:
```bash
# Manual build and publish
export GALAXY_API_KEY="your_key"
cd collections/ansible_collections/gitrgoliveira/vault
ansible-galaxy collection build
ansible-galaxy collection publish gitrgoliveira-vault-*.tar.gz --api-key "$GALAXY_API_KEY"
```

### Manual Verification After Release

After each successful release, verify the following:

#### 1. Installation Testing
```bash
# Install from Galaxy
ansible-galaxy collection install gitrgoliveira.vault:1.0.1

# Verify installation location
ansible-galaxy collection list | grep gitrgoliveira.vault

# Test plugin import
python -c "from ansible_collections.gitrgoliveira.vault.plugins.event_source.vault_events import main; print('✓ Import successful')"
```

#### 2. Galaxy Verification
- Visit: https://galaxy.ansible.com/ui/repo/published/gitrgoliveira/vault/
- Verify new version appears in version list
- Check download count and version details
- Confirm metadata is correct

#### 3. GitHub Release Verification
- Check repository **Releases** page
- Verify release notes are properly formatted
- Confirm artifacts are attached and downloadable
- Check release links and installation instructions

#### 4. Integration Testing
```bash
# Test in clean environment
python -m venv release-test
source release-test/bin/activate
pip install ansible-core>=2.14 ansible-rulebook
ansible-galaxy collection install gitrgoliveira.vault:1.0.1

# Test basic functionality (requires Vault Enterprise)
# ansible-rulebook --rulebook examples/basic-monitoring.yml --env-vars VAULT_ADDR,VAULT_TOKEN
```

## Rollback and Recovery

### Rollback Process

If a release has critical issues:

1. **Immediate Action**:
   - **Do NOT delete** from Galaxy (not supported)
   - Mark version as deprecated if severe issues exist
   - Document known issues in GitHub release notes

2. **Hotfix Release**:
   ```bash
   # Create hotfix branch
   git checkout -b hotfix/1.0.2
   
   # Apply critical fixes
   git commit -m "fix: critical issue description"
   
   # Update version in galaxy.yml
   # Update CHANGELOG.md with hotfix details
   
   # Merge and release
   git checkout main
   git merge hotfix/1.0.2
   # Follow normal release process with new version
   ```

3. **Communication**:
   - Update documentation with known issues
   - Create GitHub issue tracking the problem
   - Add deprecation notice if necessary

### Recovery from Failed Releases

#### Partial Release (Galaxy published, GitHub release failed)
```bash
# Manually create GitHub release
gh release create v1.0.1 \
  --title "Release v1.0.1" \
  --notes-file CHANGELOG.md \
  --files collections/ansible_collections/gitrgoliveira/vault/gitrgoliveira-vault-*.tar.gz
```

#### Failed Galaxy Publish (GitHub release exists)
```bash
# Manual Galaxy publish
cd collections/ansible_collections/gitrgoliveira/vault
ansible-galaxy collection publish gitrgoliveira-vault-*.tar.gz --api-key "$GALAXY_API_KEY"
```

## Best Practices and Guidelines

### Pre-Release Checklist
- [ ] Version incremented in `galaxy.yml`
- [ ] CHANGELOG.md updated with changes
- [ ] All tests pass locally
- [ ] Documentation updated for new features
- [ ] Examples tested and working
- [ ] Breaking changes clearly documented
- [ ] API key has sufficient permissions

### Release Quality Standards
1. **Semantic Versioning**: Follow strict semver guidelines
2. **Backwards Compatibility**: Minimize breaking changes
3. **Documentation**: Keep all documentation current
4. **Testing**: Comprehensive testing across matrix environments
5. **Security**: Regular security reviews and updates

### Automation Best Practices
1. **Monitor Workflows**: Always review workflow execution logs
2. **Environment Protection**: Use release environment for critical releases
3. **Matrix Testing**: Leverage comprehensive environment testing
4. **Caching**: Maintain dependency caching for faster builds
5. **Security**: Regular rotation of API keys and secrets

### Communication Guidelines
1. **Clear Release Notes**: Write user-focused changelog entries
2. **Version Tagging**: Use consistent git tagging strategy
3. **Issue Tracking**: Link releases to resolved issues
4. **Community Updates**: Announce major releases appropriately

## Maintenance and Monitoring

### Ongoing Tasks
- **Monthly**: Review and update supported Python/Ansible versions
- **Quarterly**: Rotate Galaxy API keys
- **Per Release**: Monitor Galaxy download statistics
- **Annually**: Review and update release automation

### Performance Monitoring
- Monitor workflow execution times
- Track success/failure rates
- Review matrix job performance
- Optimize caching strategies as needed

## Support and Resources

### Internal Resources
- **Workflow Logs**: GitHub Actions → Release Ansible Collection
- **Local Testing**: Use `make` targets for local validation
- **Collection Structure**: Follow Ansible collection best practices

### External Resources
- **Ansible Galaxy**: https://galaxy.ansible.com/ui/repo/published/gitrgoliveira/vault/
- **Ansible Documentation**: https://docs.ansible.com/ansible/latest/dev_guide/developing_collections.html
- **GitHub Actions**: https://docs.github.com/en/actions
- **Semantic Versioning**: https://semver.org/

### Getting Help
1. **Check workflow logs** for detailed error information
2. **Review Ansible Galaxy** collection page for publication status
3. **Test locally** with `ansible-galaxy collection build`
4. **Check dependencies** and environment compatibility
5. **Review this documentation** for common solutions