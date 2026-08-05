# TaxOS

TaxOS is a commercial SaaS platform for tax management, filing, and compliance. Built with **Flutter** (mobile-first) and **Supabase** (backend, auth, storage, and realtime).

## Architecture

- **Feature-first** — code is organized by business capability, not technical layer
- **Clean Architecture** — each feature has `data`, `domain`, and `presentation` layers
- **Monorepo-ready** — `apps/mobile` holds the Flutter shell; `lib/` holds application logic

## Repository structure

| Path | Purpose |
|------|---------|
| `apps/mobile/` | Flutter project (platform targets, pubspec, entry point) |
| `lib/` | Application source — features, core, app config |
| `assets/` | Shared static assets (fonts, icons, images) |
| `database/` | Supabase migrations, RLS policies, seeds, edge functions |
| `docs/` | Architecture, API, deployment, and onboarding documentation |
| `scripts/` | Setup, deployment, and codegen automation |
| `.github/` | CI/CD workflows and issue/PR templates |
| `.cursor/` | Cursor IDE rules and agent skills |

## Features (planned)

- Authentication & onboarding
- Dashboard & tax filing
- Documents, clients, invoicing, expenses
- Reports, subscriptions, notifications
- Settings & profile

## Prerequisites

- Flutter SDK (stable channel)
- Dart SDK (bundled with Flutter)
- Supabase CLI
- Node.js 20+ (for scripts and Supabase tooling)

## Getting started

> Detailed setup instructions live in [docs/onboarding/DEVELOPER_SETUP.md](docs/onboarding/DEVELOPER_SETUP.md).

1. Clone the repository
2. Install Flutter dependencies: `cd apps/mobile && flutter pub get`
3. Configure Supabase (see `docs/api/SUPABASE.md`)
4. Run migrations from `database/migrations/`
5. Launch the app: `flutter run`

## Documentation

- [Architecture overview](docs/architecture/OVERVIEW.md)
- [Supabase integration](docs/api/SUPABASE.md)
- [Deployment](docs/deployment/ENVIRONMENTS.md)
- [Contributing](CONTRIBUTING.md)
- [Security policy](SECURITY.md)

## License

Proprietary — see [LICENSE](LICENSE). Unauthorized use, copying, or distribution is prohibited.
