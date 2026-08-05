# TaxOS — Flutter Development Guide

**Document ID:** DOC-06  
**Version:** 1.0  
**Last updated:** July 2026  
**Status:** Active  
**Audience:** Flutter developers

---

## 1. Overview

This guide defines how Flutter development is conducted on TaxOS — project setup, package selection, patterns, testing, and build configuration. All Flutter code lives in the repository root `lib/` directory and is hosted by the Flutter project in `apps/mobile/`.

---

## 2. Environment setup

### 2.1 Prerequisites

| Tool | Version | Purpose |
|------|---------|---------|
| Flutter SDK | Stable channel (3.x) | Application framework |
| Dart SDK | 3.x (bundled) | Language |
| Xcode | 15+ (macOS only) | iOS builds |
| Android Studio | Latest | Android SDK and emulator |
| Supabase CLI | Latest | Local backend |
| Cursor / VS Code | Latest | IDE with Flutter extension |

### 2.2 Initial setup

1. Clone the repository
2. Navigate to `apps/mobile/`
3. Run dependency installation
4. Copy environment configuration template (when available)
5. Start local Supabase instance
6. Apply database migrations
7. Launch the app on a connected device or emulator

### 2.3 Environment configuration

Environment-specific values are managed through a config class in `lib/app/config/`:

| Variable | Description | Example |
|----------|-------------|---------|
| `SUPABASE_URL` | Supabase project URL | `https://xxx.supabase.co` |
| `SUPABASE_ANON_KEY` | Supabase anonymous key | `eyJ...` |
| `ENVIRONMENT` | Current environment | `local`, `staging`, `production` |
| `SENTRY_DSN` | Error monitoring DSN | `https://...@sentry.io/...` |

**Never** include the Supabase service role key in the mobile app.

---

## 3. Project structure

```
apps/mobile/                  # Flutter project shell
├── android/                  # Android platform
├── ios/                      # iOS platform
├── web/                      # Web platform (future)
├── test/                     # Tests (mirrors lib/ structure)
├── pubspec.yaml              # Dependencies and assets
└── lib/
    └── main.dart             # Entry point (bootstraps root lib/)

lib/                          # Application source (root level)
├── app/                      # App shell (config, DI, router, theme)
├── core/                     # Infrastructure (network, storage, errors)
├── features/                 # Feature modules (Clean Architecture)
└── shared/                   # Cross-feature widgets and services
```

The entry point in `apps/mobile/lib/main.dart` initializes the app and imports from the root `lib/` directory via path dependency or package reference.

---

## 4. Approved packages

### 4.1 Core dependencies

| Package | Purpose | Layer |
|---------|---------|-------|
| `flutter_bloc` | State management (BLoC pattern) | Presentation |
| `bloc` | BLoC core library | Presentation |
| `get_it` | Service locator / DI container | App |
| `injectable` | DI code generation | App |
| `go_router` | Declarative routing | App |
| `dartz` | Functional programming (`Either` type) | Domain |
| `equatable` | Value equality for entities/states | Domain |
| `freezed` | Immutable data classes | Data/Domain |
| `json_annotation` | JSON serialization annotations | Data |
| `supabase_flutter` | Supabase client SDK | Data |
| `hive_flutter` | Local storage / offline cache | Data |
| `connectivity_plus` | Network connectivity detection | Core |
| `flutter_secure_storage` | Secure token storage | Core |

### 4.2 UI dependencies

| Package | Purpose |
|---------|---------|
| `google_fonts` | Inter font loading |
| `flutter_svg` | SVG icon rendering |
| `cached_network_image` | Image caching |
| `shimmer` | Skeleton loading animations |
| `lottie` | Lottie animation playback |
| `fl_chart` | Charts for reports and dashboard |

### 4.3 Utility dependencies

| Package | Purpose |
|---------|---------|
| `intl` | Date, number, currency formatting |
| `image_picker` | Camera and gallery access |
| `file_picker` | Document file selection |
| `url_launcher` | External link opening |
| `share_plus` | Share PDF reports |
| `permission_handler` | Camera/storage permissions |

### 4.4 Dev dependencies

| Package | Purpose |
|---------|---------|
| `build_runner` | Code generation runner |
| `freezed` | Immutable class generation |
| `json_serializable` | JSON serialization generation |
| `injectable_generator` | DI registration generation |
| `bloc_test` | BLoC testing utilities |
| `mocktail` | Mock generation for tests |
| `flutter_lints` | Lint rules |
| `integration_test` | End-to-end testing |

### 4.5 Package approval process

New packages require:
1. Justification in PR description
2. Check for maintenance activity (updated within 6 months)
3. Check for compatible license (MIT, BSD, Apache 2.0)
4. No duplicate functionality with existing packages
5. Approval from tech lead

---

## 5. State management (BLoC)

### 5.1 BLoC conventions

| Rule | Detail |
|------|--------|
| One BLoC per feature or major screen | Not one BLoC for the entire app |
| Events are nouns/verbs describing user actions | `ExpenseAdded`, `ExpenseDeleted`, `FilterChanged` |
| States are adjectives describing UI condition | `ExpenseLoading`, `ExpenseLoaded`, `ExpenseError` |
| BLoC calls use cases only | Never repositories or datasources |
| Side effects in BLoC | Navigation and snackbars via `BlocListener`, not in builder |

### 5.2 BLoC lifecycle

| Event | Action |
|-------|--------|
| Screen opens | `BlocProvider` creates BLoC, dispatches initial load event |
| User action | Widget dispatches event to BLoC |
| BLoC processes | Calls use case, emits new state |
| Screen closes | BLoC disposed automatically by `BlocProvider` |
| App background | No special handling (state preserved in BLoC) |

### 5.3 State class structure

Every state class includes:
- Status enum: `initial`, `loading`, `loaded`, `error`
- Data payload (nullable until loaded)
- Error message (nullable)
- Optional metadata (pagination, filters)

---

## 6. Dependency injection

### 6.1 Registration

All dependencies are registered in `lib/app/di/injection.dart` using `get_it` and `injectable`:

| Registration type | Lifetime | Example |
|-------------------|----------|---------|
| Singleton | App lifetime | Supabase client, router, theme |
| Lazy singleton | First access | Repositories, datasources |
| Factory | New instance each time | BLoCs, use cases |

### 6.2 Module organization

| Module | Contents |
|--------|----------|
| `CoreModule` | Network client, storage, connectivity |
| `AuthModule` | Auth repository, datasources, use cases, BLoC |
| `ExpenseModule` | Expense repository, datasources, use cases, BLoC |
| (one per feature) | Same pattern |

---

## 7. Routing

### 7.1 GoRouter configuration

Routes are defined in `lib/app/router/app_router.dart`:

| Pattern | Detail |
|---------|--------|
| Route naming | `kebab-case` paths: `/tax-filing`, `/expenses/add` |
| Route parameters | Path params for IDs: `/filing/:returnId` |
| Query parameters | Filters: `/expenses?category=travel` |
| Redirects | Auth guard, onboarding guard |
| Deep links | Supported for notifications |

### 7.2 Navigation rules

| Action | Method |
|--------|--------|
| Forward navigation | `context.push('/path')` |
| Replace current | `context.replace('/path')` |
| Go back | `context.pop()` |
| Navigate to root tab | `context.go('/dashboard')` |
| Pass data | Via path/query params or BLoC state — never via constructor args across routes |

---

## 8. Localization

### 8.1 Setup

| Aspect | Detail |
|--------|--------|
| Format | ARB files in `apps/mobile/lib/l10n/` |
| v1 language | English (US) only |
| Key naming | `feature_component_description`: `expense_add_button_label` |
| Pluralization | Use ARB plural syntax |
| Parameters | Use ARB placeholder syntax |

### 8.2 Rules

- **No hardcoded strings** in widgets — all text via `AppLocalizations`
- Currency formatted via `intl` NumberFormat with locale
- Dates formatted via `intl` DateFormat with locale
- Tax-specific terms include a `* `_tooltip` suffix key for helper text

---

## 9. Theming

Theme configuration lives in `lib/app/theme/`:

| File | Purpose |
|------|---------|
| `app_theme.dart` | Material 3 ThemeData for light and dark |
| `app_colors.dart` | Color tokens from UI Guidelines |
| `app_typography.dart` | TextTheme with Inter font |
| `app_spacing.dart` | Spacing constants |

See [05_UI_GUIDELINES.md](05_UI_GUIDELINES.md) for color values and typography scale.

---

## 10. Error handling in Flutter

### 10.1 Presentation layer pattern

| BLoC state | UI response |
|------------|-------------|
| Loading | Skeleton loader or button spinner |
| Loaded | Display data |
| Error (network) | Snackbar with retry action |
| Error (auth) | Redirect to login |
| Error (validation) | Inline field errors |
| Error (subscription) | Upsell bottom sheet |
| Empty | Empty state illustration + CTA |

### 10.2 Global error handling

| Mechanism | Purpose |
|-----------|---------|
| `FlutterError.onError` | Catch framework errors → Sentry |
| `runZonedGuarded` | Catch async errors → Sentry |
| `BlocObserver` | Log all BLoC transitions in debug mode |
| Error boundary widget | Catch widget tree errors with fallback UI |

---

## 11. Offline support

### 11.1 Strategy

| Feature | Offline capability |
|---------|-------------------|
| Expense entry | Full CRUD offline; sync queue on reconnect |
| Document upload | Queue locally; upload on reconnect |
| Tax filing | Read-only offline; edits require connection |
| Dashboard | Show cached data with "last updated" timestamp |
| Calculator | Full offline (local computation) |

### 11.2 Sync pattern

1. User action → save to local cache immediately (optimistic UI)
2. Queue write operation in local sync queue
3. On connectivity restored → process queue in order
4. On sync conflict → server wins; notify user if data changed
5. Sync status indicator in app bar when queue is pending

---

## 12. Testing

### 12.1 Test structure

Tests mirror the source structure under `apps/mobile/test/`:

```
test/
├── features/
│   ├── auth/
│   │   ├── domain/usecases/
│   │   ├── data/repositories/
│   │   └── presentation/bloc/
│   └── expenses/
│       └── ...
├── core/
│   └── utils/
└── shared/
    └── widgets/
```

### 12.2 Test types and targets

| Type | Target | Coverage goal |
|------|--------|---------------|
| Unit tests | Domain use cases | 90% |
| Unit tests | Repository implementations | 85% |
| BLoC tests | State transitions | 80% |
| Widget tests | Shared widgets, critical screens | 60% |
| Integration tests | Auth flow, expense CRUD, filing wizard | Key paths |

### 12.3 Testing conventions

| Rule | Detail |
|------|--------|
| File naming | `<source_file>_test.dart` |
| Test naming | `should <expected behavior> when <condition>` |
| Mocking | `mocktail` for all external dependencies |
| BLoC testing | `blocTest` from `bloc_test` package |
| No real network calls | Mock all datasources in tests |
| Golden tests | Consider for shared widgets (future) |

---

## 13. Build and release

### 13.1 Build flavors

| Flavor | Environment | App ID suffix | App name |
|--------|-------------|---------------|----------|
| `dev` | Local/staging Supabase | `.dev` | TaxOS Dev |
| `staging` | Staging Supabase | `.staging` | TaxOS Staging |
| `production` | Production Supabase | (none) | TaxOS |

### 13.2 Build commands

| Platform | Command | Output |
|----------|---------|--------|
| Android (debug) | `flutter run --flavor dev` | Debug APK |
| Android (release) | `flutter build appbundle --flavor production` | AAB for Play Store |
| iOS (debug) | `flutter run --flavor dev` | Debug on simulator |
| iOS (release) | `flutter build ipa --flavor production` | IPA for App Store |

### 13.3 Pre-release checklist

- [ ] All tests pass
- [ ] No lint warnings
- [ ] Version bumped in pubspec.yaml
- [ ] CHANGELOG updated
- [ ] Environment config points to production Supabase
- [ ] Sentry DSN configured
- [ ] App icons and splash screen verified
- [ ] ProGuard/R8 rules configured (Android)

---

## 14. Performance guidelines

| Area | Guideline |
|------|-----------|
| Widget rebuilds | Use `const` constructors; `BlocBuilder` with `buildWhen` |
| List rendering | `ListView.builder` for lists > 20 items |
| Image loading | `cached_network_image` with placeholder and error widget |
| JSON parsing | Parse on isolate for payloads > 100 KB |
| App size | Target < 30 MB download; audit with `flutter build apk --analyze-size` |
| Memory | Dispose controllers, streams, and listeners in `dispose()` |
| Startup | Defer non-critical initialization; lazy-load features |

---

## 15. Code generation

Run code generation after modifying annotated classes:

| Generator | Input | Output |
|-----------|-------|--------|
| `freezed` | `@freezed` classes | `.freezed.dart` |
| `json_serializable` | `@JsonSerializable()` models | `.g.dart` |
| `injectable` | `@injectable` classes | `injection.config.dart` |

Generated files are excluded from lint and review — never edit manually.

---

## 16. Common pitfalls

| Pitfall | Prevention |
|---------|-------------|
| Business logic in widgets | Extract to use cases |
| Direct Supabase calls in BLoC | Go through repository |
| Hardcoded strings | Use ARB localization |
| Missing dispose | Always dispose controllers and subscriptions |
| Giant widget trees | Extract into smaller widgets |
| setState in BLoC app | Use BLoC for all feature state |
| Ignoring lint warnings | Fix all warnings before PR |
| Skipping tests for use cases | Use cases are the highest-priority test target |

---

**Related documents:** [03_ARCHITECTURE.md](03_ARCHITECTURE.md) · [05_UI_GUIDELINES.md](05_UI_GUIDELINES.md) · [07_SUPABASE_GUIDE.md](07_SUPABASE_GUIDE.md) · [10_CODING_STANDARD.md](10_CODING_STANDARD.md)
