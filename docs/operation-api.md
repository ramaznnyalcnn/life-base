# Structured Operation API

The `/api/v2` API is the backend contract for the Android-first client. It uses
selected values and typed numeric/date inputs.

## Request flow

1. `GET /api/v2/operations/catalog` returns the supported operation classes and
   the fields each screen must render.
2. `GET /api/v2/operations/context` returns the current selectable values such
   as accounts, categories, activity templates, pending tasks, payments, and
   medication doses.
3. `POST /api/v2/operations/execute` accepts an operation envelope, then the
   selected operation class validates its own typed input.
   Every request requires a UUID `request_id`. Retrying identical content is
   safe; reusing the UUID with changed content returns HTTP 409.
4. `GET /api/v2/agenda/today` and `GET /api/v2/agenda/range` return the unified
   read model used by the app, widget, reminders, and calendar synchronization.
   Agenda responses include reminder times and an `ETag`; clients may send
   `If-None-Match` and receive HTTP 304.

Schedule changes, task/payment completion actions, edits, toggles, and deletes
on existing versioned entities carry `expected_version`. If the entity changed
after the client cached it, the API returns HTTP 409 with the current entity
snapshot.
This lets the mobile queue ask the user which version to keep without silently
overwriting another device.

## Daily read surfaces

- `/api/v2/auth/login`, `/api/v2/auth/me`
- `/api/v2/finance/overview`, `/accounts`, `/categories`, `/entries`, `/payments`
- `/api/v2/planning/tasks`, `/events`, `/routines`
- `/api/v2/health/dashboard`, `/medications`, `/medications/{id}`

## Layers

- `app/api/routes`: authentication, HTTP validation, and error mapping.
- `app/operations`: one class per use case, an explicit registry, and the
  transactional executor.
- `app/services`: reusable read models and selection-context builders.
- `app/models`: persistence, ownership, idempotency journal, and agenda version.

Operation classes never commit. `OperationExecutor` commits the domain change,
agenda revision, and idempotency record together.

## Activity templates

Planning operations require an activity template selection. System defaults are
created idempotently. User templates can be managed through:

- `GET /api/v2/activity-templates`
- `POST /api/v2/activity-templates`
- `PATCH /api/v2/activity-templates/{id}`
- `DELETE /api/v2/activity-templates/{id}`

Deleting a user template deactivates it so existing tasks and events retain the
selected template reference and their saved title snapshot.

## Database upgrade

Run `alembic -c alembic.ini upgrade head` from `backend/`. Revisions `0012`–
`0014` add the operation core, task/payment models, agenda versioning,
polymorphic reminder ownership, and optimistic entity versions.
