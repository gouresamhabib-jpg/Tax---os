# Architecture Overview

> **Status:** Placeholder — to be completed before first feature implementation.

## Principles

- Feature-first folder layout under `lib/features/`
- Clean Architecture: presentation → domain ← data
- Supabase as BaaS: Postgres, Auth, Storage, Realtime, Edge Functions

## Layer rules

| Layer | Depends on | Contains |
|-------|------------|----------|
| Presentation | Domain | Pages, widgets, BLoC/Cubit |
| Domain | Nothing external | Entities, repository contracts, use cases |
| Data | Domain | Models, datasources, repository implementations |

## Dependency direction

```
presentation → domain ← data
```

## TODO

- [ ] Define state management choice (BLoC recommended)
- [ ] Define DI approach (get_it + injectable)
- [ ] Define routing (go_router)
- [ ] Document error handling strategy
