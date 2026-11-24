# TaxOS — Repository and Implementation Readiness Audit

**Document ID:** DOC-18  
**Version:** 0.1  
**Status:** Source-tree audit; implementation plan  
**Date:** 24 November 2026  
**Depends on:** DOC-13 through DOC-17

## 1. Purpose

Record the actual repository implementation state before starting Flutter and Supabase feature work. This audit is based on the Git tree at branch `docs/egyptian-firm-product-reset`. It does not claim that a local developer workspace or hosted environment has been inspected.

## 2. Observed repository state

At the audited revision, the repository tree contains 77 entries.

### Present
- Flutter package manifest: `Tax - OS/apps/mobile/pubspec.yaml`.
- Supabase configuration: `Tax - OS/supabase/config.toml`.
- Existing SQL migration files in both `database/migrations/` and `supabase/migrations/`.
- Database seed files.
- Project/product/architecture/security documentation.
- Git metadata and root-level project files.

### Not present in the audited Git tree
- `Tax - OS/lib/` application source directory.
- `lib/main.dart` or another Flutter entry point.
- Flutter platform folders such as `android/`, `ios/`, `web/`, or `windows/`.
- Flutter unit/widget tests.
- Feature-first modules, repositories, domain entities, or Supabase data sources.
- Shared asset directories referenced by the package manifest (`assets/images/`, `assets/icons/`, `assets/lottie/`).
- GitHub Actions workflow files under `.github/workflows/`.
- Supabase Edge Functions.
- A committed environment example documenting safe public client configuration.

The current `pubspec.yaml` declares only the Flutter SDK and Flutter test/lint packages. It also references asset directories not present in the audited tree. The repository README describes `lib/`, assets, scripts, and platform targets as part of the structure, but those paths are not present in the Git tree.

## 3. Documentation conflicts

The repository still contains legacy requirements that conflict with the approved Egyptian accounting-firm product baseline:

- DOC-00 describes the target market as individuals/freelancers/small businesses and lists US-first individual tax workflows as v1.
- DOC-00 §8 still defines IRS/US workflows and multi-country support as out of scope.
- DOC-03 feature list still uses `tax_filing`, `tax_calculator`, personal profile, and consumer expense assumptions.
- DOC-04 describes a user-owned/solo accountant database and US tax-return tables.
- DOC-08 includes SSN/IRS/CCPA/IRS Publication 1075 assumptions that are not an Egyptian product compliance specification.
- DOC-09 roadmap and older product documents require reconciliation against DOC-13.

Until reconciled, these documents must not be used as authority for new product implementation. Security principles such as least privilege, defense in depth, RLS, auditability, and secret handling remain useful, but jurisdiction-specific claims need replacement and legal/security review.

## 4. Implementation readiness conclusion

The repository is currently a documentation and SQL-migration skeleton, not a runnable Flutter application.

Do not claim that the mobile app has been implemented, built, or tested. Do not connect screens to the current legacy schema as if it were the approved Egyptian domain.

The next safe implementation sequence is:

1. Reconcile project rules and architecture documents with DOC-13 through DOC-17.
2. Establish a valid Flutter application shell and test entry point.
3. Add localization foundations (Arabic RTL and English LTR) before feature screens.
4. Add design tokens and navigation shell with a responsive office workspace layout.
5. Implement the first UI vertical slice with mock/in-memory repository data only: client list and client detail, or dashboard backed by mock data.
6. Add unit/widget tests and CI checks.
7. After DOC-14 and DOC-17 review, build a disposable local database prototype and integration tests.
8. Connect the app to Supabase only after the new schema and RLS tests pass.

## 5. First implementation slice

Recommended first working increment:

- Flutter app boots on a clean environment.
- App supports Arabic and English locale selection.
- RTL is enabled for Arabic and LTR for English.
- Authenticated workspace shell is represented with a local demo session only (no fake security claims).
- Main navigation has clear destinations for Dashboard, Clients, Obligations, Calendar, Documents, and Office.
- Dashboard shows explicitly labeled sample/demo metrics.
- No real client/tax data, no Supabase credentials, and no database writes.
- Unit/widget tests verify app startup, localization direction, navigation shell, and demo-state labeling.

This slice proves the mobile application foundation without creating a false dependency on the legacy database.

## 6. Safe configuration and secrets

- Supabase URL and anon/publishable key may be supplied at build/runtime through documented configuration; never commit a service-role key.
- A missing Supabase configuration should leave the local demo shell runnable and display a clear unconfigured state.
- Never store real taxpayer information in mock fixtures.
- No secrets should appear in screenshots, logs, crash reports, or test output.

## 7. Required gates

- [ ] Product docs DOC-13 through DOC-17 reviewed.
- [ ] DOC-00, DOC-03, DOC-04, DOC-08, DOC-09, and README reconciled.
- [ ] Flutter SDK version and supported platform targets confirmed.
- [ ] Package manifest asset declarations match committed directories.
- [ ] Clean install/build/test verified in a Flutter-enabled environment.
- [ ] Arabic/English localization and RTL/LTR behavior verified.
- [ ] No Supabase migration or hosted connection used for the first UI shell.
- [ ] CI runs formatting, analysis, and tests on pull requests.

## 8. Scope and safety

This document records repository-tree observations and recommends an implementation order. It does not authorize hosted Supabase changes, production migrations, use of real taxpayer data, or deployment. Any Flutter source implementation must be reviewed and tested in a Flutter-enabled environment before being described as build-verified.
