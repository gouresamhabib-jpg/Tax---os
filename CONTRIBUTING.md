# Contributing to TaxOS

Thank you for contributing to TaxOS. This document outlines how we work on this codebase.

## Before you start

1. Read [docs/architecture/OVERVIEW.md](docs/architecture/OVERVIEW.md)
2. Read [docs/onboarding/DEVELOPER_SETUP.md](docs/onboarding/DEVELOPER_SETUP.md)
3. Never commit secrets (`.env`, API keys, service account files)

## Branch naming

- `feature/<ticket-id>-short-description`
- `fix/<ticket-id>-short-description`
- `chore/<short-description>`

## Commit messages

Use [Conventional Commits](https://www.conventionalcommits.org/):

```
feat(auth): add biometric login
fix(tax-filing): correct deadline calculation
docs(readme): update setup instructions
```

## Pull request process

1. Create a branch from `main`
2. Keep PRs focused — one feature or fix per PR
3. Fill out the PR template completely
4. Ensure CI passes (lint, test, build)
5. Request review from a code owner
6. Squash merge after approval

## Code standards

### Architecture

- Place new code inside the appropriate **feature** under `lib/features/`
- Follow the three layers: `data` → `domain` → `presentation`
- Domain layer must not depend on Flutter or Supabase SDKs
- Shared UI goes in `lib/shared/widgets/` only if used by 2+ features

### Naming

- Files: `snake_case.dart`
- Classes: `PascalCase`
- Features: `snake_case` folder names (e.g. `tax_filing/`)

### Testing

- Unit tests for domain use cases and repositories
- Widget tests for critical UI flows
- Place tests mirroring source under `apps/mobile/test/`

## Reporting issues

Use GitHub issue templates for bugs and feature requests.

## Questions

Open a discussion or contact the maintainers listed in README.
