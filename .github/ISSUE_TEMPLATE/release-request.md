---
name: Release Request
about: Request a new release of the Vault EDA collection
title: 'Release v[VERSION]'
labels: ['release']
assignees: ''

---

## Release Information

**Version**: v[VERSION] (e.g., v1.0.1)
**Type**: [Major/Minor/Patch]

## Checklist

### Pre-Release
- [ ] Version updated in `collections/ansible_collections/gitrgoliveira/vault/galaxy.yml`
- [ ] CHANGELOG.md updated with release notes
- [ ] All tests passing
- [ ] Documentation updated
- [ ] Breaking changes documented (if any)

### Release Process
- [ ] GALAXY_API_KEY secret configured
- [ ] GitHub Actions workflow completed successfully
- [ ] Collection published to Ansible Galaxy
- [ ] GitHub release created
- [ ] Release artifacts uploaded

### Post-Release
- [ ] Installation tested: `ansible-galaxy collection install gitrgoliveira.vault:[VERSION]`
- [ ] Collection visible on [Ansible Galaxy](https://galaxy.ansible.com/gitrgoliveira/vault)
- [ ] Documentation updated with new version

## Changes in This Release

### Added
- 

### Changed
- 

### Fixed
- 

### Removed
- 

## Migration Notes

<!-- Any special instructions for users upgrading from previous versions -->

## Testing

<!-- Describe how this release was tested -->

## Additional Notes

<!-- Any additional information about this release -->