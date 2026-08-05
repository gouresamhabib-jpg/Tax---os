# Security Policy

## Supported versions

| Version | Supported |
|---------|-----------|
| 0.1.x   | :white_check_mark: |
| < 0.1   | :x: |

## Reporting a vulnerability

**Do not open a public GitHub issue for security vulnerabilities.**

Email: **security@taxos.com**

Include:
- Description of the vulnerability
- Steps to reproduce
- Affected components (app version, Supabase project, etc.)
- Proof of concept if available

We aim to acknowledge reports within **48 hours** and provide an initial assessment within **5 business days**.

## Scope

In scope:
- TaxOS mobile application (`apps/mobile`, `lib/`)
- Supabase backend configuration (`database/`)
- CI/CD pipelines (`.github/workflows/`)

Out of scope:
- Third-party services not operated by TaxOS
- Social engineering attacks
- Denial-of-service against production infrastructure

## Safe harbor

We support good-faith security research that follows this policy. We will not pursue legal action against researchers who comply with responsible disclosure guidelines.
