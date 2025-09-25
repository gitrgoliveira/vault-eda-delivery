---
name: 'Release Request'
about: 'Request a new release of the Vault EDA collection.'
title: 'Release v[VERSION]'
labels: ['release']
assignees: ''

---

## Release Information

**Version**: v[VERSION] (e.g., v0.1.1)
**Type**: [Major | Minor | Patch]

## Checklist

### Pre-Release
- [ ] Version is updated in `collections/ansible_collections/gitrgoliveira/vault_eda/galaxy.yml`.
- [ ] `CHANGELOG.md` is updated with release notes.
- [ ] All automated tests are passing.
- [ ] Documentation is updated to reflect changes.
- [ ] Breaking changes are documented (if any).

### Release Process
- [ ] `GALAXY_API_KEY` secret is configured and valid.
- [ ] GitHub Actions workflow completed successfully.
- [ ] Collection is published to Ansible Galaxy.
- [ ] GitHub release is created.
- [ ] Release artifacts are uploaded.

### Post-Release
- [ ] Installation is tested: `ansible-galaxy collection install gitrgoliveira.vault_eda:[VERSION]`.
- [ ] Collection is visible on [Ansible Galaxy](https://galaxy.ansible.com/gitrgoliveira/vault).
- [ ] Documentation is updated with the new version number.

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

<!-- Provide instructions for users upgrading from previous versions. -->

## Testing

<!-- Describe the testing performed for this release. -->

## Additional Notes

<!-- Include any other relevant information about this release. -->