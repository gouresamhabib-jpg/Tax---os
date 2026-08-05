# TaxOS — Supabase Integration Guide

**Document ID:** DOC-07  
**Version:** 1.0  
**Last updated:** July 2026  
**Status:** Active  
**Audience:** Backend and full-stack developers

---

## 1. Overview

TaxOS uses **Supabase** as its backend-as-a-service platform, providing PostgreSQL database, authentication, file storage, realtime subscriptions, and edge functions. This guide covers integration patterns, configuration, and operational practices.

---

## 2. Supabase services used

| Service | TaxOS usage | Priority |
|---------|-------------|----------|
| **Auth** | Email/password, Google OAuth, Apple OAuth | P0 |
| **Database** | All structured data (PostgreSQL) | P0 |
| **Storage** | Documents, receipts, generated PDFs | P0 |
| **Realtime** | Notification delivery, sync indicators | P1 |
| **Edge Functions** | PDF generation, webhooks, tax calculations | P1 |
| **Database Functions (RPC)** | Complex queries, subscription limit checks | P1 |

---

## 3. Project configuration

### 3.1 Environments

| Environment | Project name | Purpose |
|-------------|-------------|---------|
| Local | `supabase start` (Docker) | Development |
| Staging | `taxos-staging` | QA and pre-release testing |
| Production | `taxos-prod` | Live customer data |

### 3.2 Keys and secrets

| Key | Where used | Exposure |
|-----|-----------|----------|
| **Anon key** | Flutter mobile app | Public (safe with RLS) |
| **Service role key** | Edge Functions, CI/CD, admin scripts | Secret — never in client |
| **JWT secret** | Token verification in Edge Functions | Secret — Supabase managed |
| **Database URL** | Direct connections (migrations, admin) | Secret — CI/CD only |

### 3.3 Local development

1. Install Supabase CLI
2. Run `supabase start` from project root
3. Local services available at:
   - API: `http://localhost:54321`
   - Studio: `http://localhost:54323`
   - Database: `postgresql://postgres:postgres@localhost:54322/postgres`
4. Apply migrations: `supabase db push`
5. Seed data: `supabase db seed`

---

## 4. Authentication

### 4.1 Supported providers

| Provider | Priority | Configuration |
|----------|----------|---------------|
| Email/password | P0 | Enabled by default |
| Google OAuth | P1 | Google Cloud Console credentials |
| Apple Sign In | P1 | Apple Developer credentials (required for iOS App Store) |

### 4.2 Auth flow

```mermaid
sequenceDiagram
    participant App as Flutter App
    participant Auth as Supabase Auth
    participant DB as PostgreSQL

    App->>Auth: signUp(email, password)
    Auth->>DB: INSERT auth.users
    DB->>DB: Trigger: handle_new_user()
    DB->>DB: INSERT profiles, subscriptions
    Auth->>App: Session (JWT + refresh token)

    App->>Auth: signIn(email, password)
    Auth->>App: Session (JWT + refresh token)

    App->>Auth: Auto refresh token
    Auth->>App: New JWT

    App->>Auth: signOut()
    Auth->>App: Session cleared
```

### 4.3 Session management

| Aspect | Configuration |
|--------|---------------|
| JWT expiry | 3600 seconds (1 hour) |
| Refresh token | Automatic via `supabase_flutter` SDK |
| Session persistence | Secure storage on device |
| Inactivity timeout | 30 days (app-level enforcement) |
| Multi-device | Supported — independent sessions |

### 4.4 Auth integration in Flutter

| Layer | Responsibility |
|-------|---------------|
| Data datasource | Calls `supabase.auth.signUp/signIn/signOut` |
| Data repository | Maps auth exceptions to domain Failures |
| Domain use case | `SignIn`, `SignUp`, `SignOut`, `RefreshSession` |
| Presentation BLoC | Emits authenticated/unauthenticated states |
| Router guard | Redirects based on auth state |

**Rule:** Auth SDK calls exist only in the auth feature's remote datasource.

---

## 5. Database integration

### 5.1 Query patterns

| Operation | Supabase method | Layer |
|-----------|----------------|-------|
| Select rows | `.from('table').select()` | Remote datasource |
| Insert row | `.from('table').insert()` | Remote datasource |
| Update row | `.from('table').update().eq('id', id)` | Remote datasource |
| Soft delete | `.from('table').update({'deleted_at': now}).eq('id', id)` | Remote datasource |
| Filter | `.eq()`, `.gte()`, `.lte()`, `.inFilter()` | Remote datasource |
| Pagination | `.range(from, to)` | Remote datasource |
| RPC | `.rpc('function_name', params: {})` | Remote datasource |
| Join | `.select('*, category:expense_categories(name)')` | Remote datasource |

### 5.2 Query rules

| Rule | Detail |
|------|--------|
| RLS handles authorization | Never filter by `user_id` manually — RLS enforces it |
| Select specific columns | Avoid `.select('*')` in production queries |
| Use indexes | All filtered/sorted columns must have indexes |
| Pagination required | Lists > 50 items must use `.range()` |
| Transactions | Use RPC functions for multi-table writes |
| Error handling | Catch `PostgrestException` → map to Failure |

### 5.3 Realtime subscriptions

| Use case | Channel | Event |
|----------|---------|-------|
| New notification | `notifications:user_id=eq.{uid}` | INSERT |
| Return status change | `tax_returns:id=eq.{rid}` | UPDATE |
| Sync indicator | Connection status listener | — |

**Rule:** Unsubscribe from channels in datasource `dispose()` or BLoC `close()`.

---

## 6. Storage integration

### 6.1 Bucket configuration

| Bucket | Access | Max file size | Allowed MIME types |
|--------|--------|---------------|-------------------|
| `documents` | Private | 25 MB | PDF, JPG, PNG, HEIC |
| `receipts` | Private | 10 MB | JPG, PNG, HEIC |
| `exports` | Private | 50 MB | PDF, CSV |
| `avatars` | Private | 5 MB | JPG, PNG |

### 6.2 Storage path convention

```
{bucket}/{user_id}/{resource_id}/{filename}
```

Example: `documents/a1b2c3d4-.../e5f6g7h8-.../w2_2025.pdf`

### 6.3 Upload flow

```mermaid
sequenceDiagram
    participant App as Flutter App
    participant Storage as Supabase Storage
    participant DB as PostgreSQL

    App->>App: Pick file (camera/gallery)
    App->>App: Validate size and MIME type
    App->>Storage: upload(path, fileBytes)
    Storage->>App: Upload success
    App->>DB: INSERT documents(record)
    DB->>App: Document record created
```

### 6.4 Download flow

| Method | Usage |
|--------|-------|
| Signed URL | `.createSignedUrl(path, expirySeconds)` for preview/download |
| Public URL | Never used — all buckets are private |
| URL expiry | 3600 seconds (1 hour) for preview; regenerate on demand |

### 6.5 Storage policies

Every bucket mirrors table RLS:

| Operation | Policy |
|-----------|--------|
| SELECT (download) | User can access files in their own `{user_id}/` folder |
| INSERT (upload) | User can upload to their own `{user_id}/` folder |
| DELETE | User can delete files in their own `{user_id}/` folder |

---

## 7. Edge Functions

### 7.1 Function inventory

| Function | Trigger | Purpose |
|----------|---------|---------|
| `generate-return-pdf` | HTTP (authenticated) | Generate tax return PDF |
| `generate-invoice-pdf` | HTTP (authenticated) | Generate invoice PDF |
| `calculate-tax` | HTTP (authenticated) | Server-side tax calculation |
| `subscription-webhook` | HTTP (RevenueCat/Stripe) | Process subscription events |
| `send-notification` | Database trigger | Create and push notification |
| `cleanup-deleted` | Cron (daily) | Purge soft-deleted records > 90 days |

### 7.2 Edge Function conventions

| Rule | Detail |
|------|--------|
| Location | `database/functions/<function-name>/index.ts` |
| Auth | Verify JWT from Authorization header |
| Service role | Used for admin operations (bypass RLS) |
| Error response | Standard JSON: `{ error: string, code: string }` |
| CORS | Configured for mobile app origins only |
| Logging | Structured JSON logs for debugging |

### 7.3 Deployment

Edge Functions are deployed via Supabase CLI:

```
supabase functions deploy <function-name> --project-ref <ref>
```

Production deployments require CI/CD pipeline approval.

---

## 8. Migration management

### 8.1 Workflow

```mermaid
flowchart LR
    A[Write SQL migration] --> B[Test locally]
    B --> C[PR with migration file]
    C --> D[CI validates SQL]
    D --> E[Review and merge]
    E --> F[Deploy to staging]
    F --> G[Verify staging]
    G --> H[Deploy to production]
```

### 8.2 Migration file structure

Each migration in `database/migrations/` contains:

| Section | Content |
|---------|---------|
| Header comment | Description, author, date |
| Up migration | CREATE TABLE, ALTER, INSERT seed data |
| Down migration (commented) | Reverse operations for rollback reference |
| RLS policies | Enable RLS + CREATE POLICY statements |
| Indexes | CREATE INDEX statements |
| Triggers | CREATE TRIGGER statements |

### 8.3 Rules

| Rule | Detail |
|------|--------|
| One concern per migration | Don't mix unrelated changes |
| Never edit merged migrations | Create a new migration to fix |
| Always include RLS | No table goes live without policies |
| Test locally first | `supabase db reset` then `supabase db push` |
| Destructive changes | Require explicit team approval |

---

## 9. Row Level Security (RLS)

### 9.1 Policy template

Every user-owned table:

| Policy name | Operation | Expression |
|-------------|-----------|------------|
| `{table}_select_own` | SELECT | `user_id = auth.uid()` |
| `{table}_insert_own` | INSERT | `user_id = auth.uid()` |
| `{table}_update_own` | UPDATE | `user_id = auth.uid()` |
| `{table}_delete_own` | DELETE | `user_id = auth.uid()` |

### 9.2 Special policies

| Table | Special rule |
|-------|-------------|
| `subscriptions` | UPDATE via service role only (webhook) |
| `notifications` | INSERT via service role only (Edge Function) |
| `expense_categories` | SELECT only for authenticated users |
| `document_categories` | SELECT only for authenticated users |

### 9.3 RLS testing

Before any table goes to production:

1. Test as authenticated user — can access own data
2. Test as authenticated user — cannot access other user's data
3. Test as unauthenticated — cannot access any data
4. Test as service role — can access all data (Edge Functions only)

---

## 10. Monitoring and observability

| Tool | Purpose | Integration |
|------|---------|-------------|
| Supabase Dashboard | Database metrics, auth stats, storage usage | Built-in |
| Supabase Logs | API, auth, storage, Edge Function logs | Built-in |
| Sentry | Application error tracking | Flutter SDK |
| PostHog | Product analytics | Flutter SDK |
| Uptime monitoring | API availability | External service (future) |

### 10.1 Key metrics to monitor

| Metric | Alert threshold |
|--------|----------------|
| API error rate (5xx) | > 1% over 5 minutes |
| Auth failure rate | > 10% over 15 minutes |
| Database connection pool | > 80% utilization |
| Storage usage | > 80% of plan limit |
| Edge Function errors | > 5% over 5 minutes |
| Response time (p95) | > 1000 ms |

---

## 11. Security best practices

| Practice | Detail |
|----------|--------|
| Anon key only in client | Service role key never in Flutter app |
| RLS on every table | No exceptions |
| Input validation | Validate in Edge Functions and use cases |
| SQL injection | Use parameterized queries (Supabase client handles this) |
| File upload validation | Check MIME type and size server-side in Edge Functions |
| Rate limiting | Configure Supabase rate limits; add app-level throttling |
| Audit logging | Log auth events and sensitive operations |
| Key rotation | Rotate service role key quarterly |

See [08_SECURITY.md](08_SECURITY.md) for the complete security policy.

---

## 12. Disaster recovery

| Scenario | Response |
|----------|----------|
| Supabase outage | App shows cached data; queue writes; monitor status page |
| Data corruption | Restore from daily backup (point-in-time recovery) |
| Accidental migration | Run down migration; restore from backup if needed |
| Key compromise | Rotate keys immediately; audit access logs |
| Storage bucket deletion | Restore from Supabase backup; prevent via dashboard locks |

---

## 13. Cost management

| Service | Free tier limit | Pro plan | Optimization |
|---------|----------------|----------|-------------|
| Database | 500 MB | 8 GB | Archive old returns; soft delete cleanup |
| Storage | 1 GB | 100 GB | Compress images; PDF size limits |
| Auth | 50,000 MAU | 100,000 MAU | Monitor active users |
| Edge Functions | 500K invocations | 2M invocations | Cache calculations |
| Realtime | 200 concurrent | 500 concurrent | Unsubscribe when not needed |
| Bandwidth | 5 GB | 250 GB | Signed URL caching |

---

**Related documents:** [04_DATABASE.md](04_DATABASE.md) · [03_ARCHITECTURE.md](03_ARCHITECTURE.md) · [08_SECURITY.md](08_SECURITY.md) · [06_FLUTTER_GUIDE.md](06_FLUTTER_GUIDE.md)
