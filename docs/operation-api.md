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

## Wallet (v3)

The wallet is server-authoritative and can be shared by a household. Writes are
operations (above) that name records by **client-generated ids**, so a phone can
create an account offline and add expenses to it before either reaches the
server:

| Operation | Does |
|---|---|
| `wallet.account.save` | Create or edit an account/card (owner only). Fields: name, type (cash/bank/credit_card), bank, visibility (personal/shared), opening balance, limit, statement/due day, last4, network, colour, IBAN. Type cannot change. |
| `wallet.account.archive` | Hide or restore an account. |
| `wallet.transaction.save` | Create or edit an expense/income with category and `note` ("neden"). `installments` > 1 (card expenses) splits the amount into equal parts in kuruş (remainder on the first) on successive statements, ids `<id>`, `<id>~2`, … |
| `wallet.transaction.delete` | Delete; any installment deletes the whole purchase. |
| `wallet.transfer.save` / `.delete` | Money between two accounts; into a card it is a card payment. |
| `wallet.statement.mark` | Manual "paid" for one card statement; `paid: null` returns it to automatic. |

Rules:

- **Balances.** Card balances are minus the debt (available = limit + balance).
  `balance = opening_balance + Σ effects` (income and payments raise it).
  Every change goes through one atomic `UPDATE … SET balance = balance + δ`
  per account in id order; edits and deletions lock the accounts
  (`FOR UPDATE`, id order) before undoing the old effect. Two people spending
  on the same shared card at once both land.
- **Conflicts.** Edits carry `expected_version`; an outdated one returns 409
  with `current` in the pull format.
- **Access.** An account is usable by its owner, and by household members when
  it is shared. Anything else is 403. Only the owner edits or archives it.
- **Households.** `GET /api/v3/household`, `POST /invites` (creates the
  household on first use; 6-character code, 48 h, single use), `POST /join`,
  `POST /leave`. A user is in at most one household; a leaver keeps their
  shared accounts as personal ones.
- **Pull.** `GET /api/v3/wallet/pull?since=<cursor>&scope=<scope>` returns the
  current state of every record changed since the cursor (`accounts`,
  `transactions`, `transfers`, `statement_marks`, `deleted` tombstones,
  `members`, `categories`). Changes are numbered per scope (`h:<household>` or
  `u:<user>`) by a counter locked until commit, so numbers follow commit order.
  When the client is new or its scope changed (joined/left), `reset: true` and
  a full snapshot is returned.
- **Reconciliation.** `python -m app.cli.reconcile_balances [--fix]` reports
  (or corrects) balances that differ from opening balance + history; exit 1 on
  unfixed drift.

The v1 `/accounts`, `/transactions`, `/transfers` routes (React web) use the
same ledger and change feed until they are retired.

## Database upgrade

Run `alembic -c alembic.ini upgrade head` from `backend/`. Revisions `0012`–
`0014` add the operation core, task/payment models, agenda versioning,
polymorphic reminder ownership, and optimistic entity versions. `0016` adds
households, wallet client ids, statement marks and the wallet change feed; it
converts card balances from "available credit" to "minus the debt" and derives
each account's opening balance from its history.
