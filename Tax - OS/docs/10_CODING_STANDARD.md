# TaxOS — Coding Standards

**Document ID:** DOC-10  
**Version:** 1.0  
**Last updated:** July 2026  
**Status:** Active  
**Audience:** All developers

---

## 1. Purpose

This document defines the coding conventions, patterns, and quality standards for all TaxOS source code. Consistency across the codebase reduces cognitive load, simplifies code review, and enables AI agents to generate code that matches team expectations.

---

## 2. General principles

| Principle | Detail |
|-----------|--------|
| **Readability over cleverness** | Code is read more than written |
| **Consistency** | Match existing patterns in the file and feature |
| **Minimal scope** | Change only what the task requires |
| **No premature abstraction** | Extract when reused, not speculatively |
| **Self-documenting names** | Names explain intent; comments explain why |
| **Fail explicitly** | Return `Either<Failure, T>` — never swallow errors |

---

## 3. Dart language conventions

### 3.1 Naming

| Element | Convention | Example |
|---------|-----------|---------|
| Files | `snake_case.dart` | `expense_repository_impl.dart` |
| Classes | `PascalCase` | `ExpenseRepositoryImpl` |
| Abstract classes | `PascalCase` | `ExpenseRepository` |
| Interfaces (abstract) | `PascalCase` (no `I` prefix) | `ExpenseRepository` |
| Methods | `camelCase` | `getExpensesByCategory()` |
| Variables | `camelCase` | `expenseList` |
| Constants | `camelCase` (class) or `SCREAMING_SNAKE` (top-level) | `AppConstants.maxFileSize` |
| Private members | `_prefixed` | `_supabaseClient` |
| Enums | `PascalCase` type, `camelCase` values | `FilingStatus.single` |
| Type parameters | Single uppercase letter | `T`, `E` |
| BLoC events | `PascalCase` (past tense or noun) | `ExpenseAdded`, `FilterChanged` |
| BLoC states | `PascalCase` (adjective) | `ExpenseLoaded`, `ExpenseLoading` |
| Use cases | Verb + Noun | `GetExpenses`, `AddExpense`, `DeleteExpense` |

### 3.2 File organization

| Rule | Detail |
|------|--------|
| One public class per file | File name matches class name |
| Import order | Dart SDK → Flutter → packages → relative |
| Export files | Use barrel files sparingly (one per feature max) |
| Line length | 80 characters (Dart formatter default) |
| Trailing commas | Always use (enables better formatting) |

### 3.3 Import ordering

```
// 1. Dart SDK
import 'dart:async';

// 2. Flutter SDK
import 'package:flutter/material.dart';

// 3. Third-party packages (alphabetical)
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// 4. Project imports (alphabetical)
import 'package:taxos/core/errors/failures.dart';
import 'package:taxos/features/expenses/domain/entities/expense.dart';
```

---

## 4. Architecture patterns

### 4.1 Entity conventions

| Rule | Detail |
|------|--------|
| Immutability | All entities are immutable (`freezed` or `equatable`) |
| Equality | Value equality via `Equatable` or `freezed` |
| No methods with side effects | Entities are data containers |
| Required fields | Use `required` keyword, not nullable with defaults |
| Optional fields | Nullable types (`String?`, `DateTime?`) |

### 4.2 Use case conventions

| Rule | Detail |
|------|--------|
| One operation per use case | `GetExpenses`, not `ManageExpenses` |
| Single public method | `call()` method |
| Return type | `Future<Either<Failure, T>>` |
| No framework imports | Pure Dart only |
| Input via constructor | Dependencies injected; params via `call()` |
| Validation | Business rule validation inside use case |

### 4.3 Repository conventions

| Rule | Detail |
|------|--------|
| Abstract in domain | Contract defines operations |
| Implementation in data | Implements domain contract |
| Return type | `Either<Failure, T>` — never throw to caller |
| Exception mapping | Catch datasource exceptions → return appropriate Failure |
| No business logic | Repositories orchestrate datasources, not validate |

### 4.4 Datasource conventions

| Rule | Detail |
|------|--------|
| Abstract + implementation | Interface in same folder as impl |
| Remote datasource | Supabase client calls |
| Local datasource | Hive / SharedPreferences calls |
| Throw exceptions | Datasources throw; repositories catch |
| No domain imports | Datasources work with models, not entities |

### 4.5 Model conventions

| Rule | Detail |
|------|--------|
| JSON serializable | `@JsonSerializable()` or `@freezed` with JSON |
| Mapping methods | `toEntity()` and `fromEntity()` |
| Field names | Match database column names (snake_case in JSON) |
| Null safety | Handle nullable database columns explicitly |

### 4.6 BLoC conventions

| Rule | Detail |
|------|--------|
| Events | User actions and lifecycle events |
| States | UI conditions with status enum |
| Registration | `@injectable` for DI |
| Initial event | Dispatched in constructor or via `BlocProvider` |
| Error handling | Map Failure to error state with user message |
| No direct navigation | Use `BlocListener` for side effects |

---

## 5. Widget conventions

### 5.1 Structure

| Rule | Detail |
|------|--------|
| Prefer `StatelessWidget` | State lives in BLoC |
| `const` constructors | Always when possible |
| Extract widgets | When build method exceeds ~50 lines |
| No business logic | Widgets render state, dispatch events |
| Keys | Provide `Key` for list items |

### 5.2 Naming

| Type | Convention | Example |
|------|-----------|---------|
| Page | `<Name>Page` | `ExpenseListPage` |
| Widget | `<Description>` | `ExpenseCard`, `AmountInput` |
| Shared widget | `<Description>` in `shared/widgets/` | `PrimaryButton`, `LoadingOverlay` |

### 5.3 Localization

| Rule | Detail |
|------|--------|
| No hardcoded strings | All text via `AppLocalizations.of(context)` |
| ARB key format | `<feature>_<component>_<description>` |
| Plurals | Use ARB plural syntax |
| Parameters | Use ARB placeholder syntax |

---

## 6. Error handling

### 6.1 Failure hierarchy

| Failure | When to use |
|---------|-------------|
| `ServerFailure` | Supabase 5xx, unexpected API errors |
| `NetworkFailure` | No connectivity, timeout |
| `CacheFailure` | Local storage read/write errors |
| `ValidationFailure` | Business rule violations |
| `AuthFailure` | Session expired, unauthorized |
| `NotFoundFailure` | Resource does not exist |
| `SubscriptionFailure` | Feature requires plan upgrade |

### 6.2 Rules

| Rule | Detail |
|------|--------|
| Never catch and ignore | Always return Failure or rethrow |
| Never throw from use cases | Return `Left(Failure)` |
| Never show raw errors to users | Map to user-friendly messages in BLoC |
| Log errors to Sentry | In BLoC or global error handler |
| Include context in Failures | Message, code, and optional metadata |

---

## 7. Testing standards

### 7.1 Naming

| Element | Convention | Example |
|---------|-----------|---------|
| Test file | `<source>_test.dart` | `get_expenses_test.dart` |
| Test group | `group('<ClassName>', () {` | `group('GetExpenses', () {` |
| Test case | `test('should <behavior> when <condition>', () {` | `should return expenses when repository succeeds` |

### 7.2 Structure (Arrange-Act-Assert)

| Phase | Content |
|-------|---------|
| Arrange | Set up mocks, test data, dependencies |
| Act | Call the method under test |
| Assert | Verify return value, state, or interactions |

### 7.3 Coverage requirements

| Layer | Minimum coverage |
|-------|-----------------|
| Domain (use cases) | 90% |
| Data (repositories) | 85% |
| Presentation (BLoC) | 80% |
| Shared widgets | 60% |

---

## 8. Documentation in code

### 8.1 When to comment

| Comment | Example |
|---------|---------|
| Non-obvious business logic | Tax calculation rounding rules |
| Workarounds | Supabase SDK limitation workaround |
| TODO with ticket | `// TODO(TAX-123): Add state tax support` |
| Complex algorithms | Tax bracket calculation steps |

### 8.2 When NOT to comment

| Anti-pattern | Why |
|--------------|-----|
| Restating the code | `// increment counter` above `counter++` |
| Commented-out code | Delete it — git has history |
| Change logs in code | Use CHANGELOG.md |
| Architecture explanations | Use docs/ |

### 8.3 Doc comments

Use `///` doc comments on:
- Public API classes and methods in domain layer
- Shared widget parameters
- Complex utility functions

Do not doc-comment obvious getters, private methods, or generated code.

---

## 9. Git conventions

### 9.1 Commit messages

Format: `<type>(<scope>): <description>`

| Type | Usage |
|------|-------|
| `feat` | New feature |
| `fix` | Bug fix |
| `docs` | Documentation only |
| `style` | Formatting, no logic change |
| `refactor` | Code change without feature/fix |
| `test` | Adding or updating tests |
| `chore` | Build, CI, dependencies |

Scope = feature name: `feat(expenses): add receipt camera capture`

### 9.2 Branch naming

| Pattern | Example |
|---------|---------|
| `feature/<ticket>-<description>` | `feature/TAX-42-expense-camera` |
| `fix/<ticket>-<description>` | `fix/TAX-87-login-crash` |
| `chore/<description>` | `chore/update-dependencies` |

---

## 10. Lint rules

### 10.1 Enabled lints

Use `flutter_lints` package (latest) with these additional rules in `analysis_options.yaml`:

| Rule | Purpose |
|------|---------|
| `always_declare_return_types` | Explicit return types |
| `avoid_print` | No print statements (use logger) |
| `prefer_const_constructors` | Performance |
| `prefer_final_locals` | Immutability |
| `require_trailing_commas` | Formatting |
| `sort_constructors_first` | Readability |
| `unnecessary_lambdas` | Simplify closures |
| `use_super_parameters` | Modern constructor syntax |

### 10.2 Pre-commit checks

| Check | Command |
|-------|---------|
| Format | `dart format --set-exit-if-changed .` |
| Analyze | `flutter analyze --fatal-infos` |
| Test | `flutter test` |

---

## 11. Dependency management

| Rule | Detail |
|------|--------|
| Pin major versions | `^` for compatible updates |
| Review before adding | New packages require PR justification |
| Audit regularly | Dependabot weekly PRs |
| No git dependencies | Use published packages only |
| License check | MIT, BSD, Apache 2.0 only |

---

## 12. Performance standards

| Area | Standard |
|------|----------|
| Widget rebuilds | Use `buildWhen` in BlocBuilder |
| Lists | `ListView.builder` for > 20 items |
| Images | Always use cached loading |
| JSON parsing | Isolate for payloads > 100 KB |
| Memory | Dispose all controllers and subscriptions |
| App size | Monitor with size analysis tool |

---

## 13. Security coding rules

| Rule | Detail |
|------|--------|
| No secrets in code | Use environment config |
| No service role key in client | Anon key only |
| No PII in logs | Mask SSN, TIN, account numbers |
| Validate all input | Client and server side |
| Sanitize error messages | Never expose stack traces to users |
| Secure storage for tokens | FlutterSecureStorage only |

---

## 14. Code review checklist

Reviewers verify:

- [ ] Follows Clean Architecture layer boundaries
- [ ] No business logic in presentation layer
- [ ] No Supabase imports in domain/presentation
- [ ] Tests included for use cases and BLoC
- [ ] No hardcoded strings (localization used)
- [ ] No secrets or PII in code
- [ ] Naming follows conventions
- [ ] Error handling uses Failure types
- [ ] Documentation updated if needed
- [ ] No unnecessary dependencies added

---

**Related documents:** [03_ARCHITECTURE.md](03_ARCHITECTURE.md) · [06_FLUTTER_GUIDE.md](06_FLUTTER_GUIDE.md) · [00_PROJECT_RULES.md](00_PROJECT_RULES.md) · [11_CURSOR_RULES.md](11_CURSOR_RULES.md)
