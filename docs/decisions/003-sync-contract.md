# ADR 003: Sync contract and client architecture (S16-S18)

Status: **Client engine implemented and tested against an in-memory reference server. No real
backend, auth, background scheduler or UI exists yet.** Builds on ADR 002.

## 1. What is built

| Piece | Where |
|---|---|
| Protocol: HLC, per-field merge rules, reference server (`push`, `pull`, `summary`, `server_version`) | `lib/features/sync/domain/sync_protocol.dart` |
| Per-table policies (`kSyncSpecs`), engine, transport interface, in-memory transport, backoff | `lib/features/sync/application/sync_engine.dart` |
| Schema v13: `sync_state`, `sync_dirty` (outbox), `sync_rows` (last synced values + field clocks), `sync_conflicts`, `orders.device_code` | `lib/core/db/tables.dart`, `app_database.dart` |
| Outbox capture: SQLite triggers on 19 synced tables (insert/update/delete) | `lib/core/db/sync_schema.dart` |
| Simulator + chaos transport + tests | `test/sync/` |

## 2. How it works

**Outbox in the same transaction.** Instead of decorating every repository, AFTER INSERT/UPDATE/DELETE
triggers write `(table, row_id)` into `sync_dirty` inside the mutation's own transaction (only when
sync is enabled and the engine is not applying remote rows). No write path can forget it, and it also
covers the CSV importer, backup merge and statement import.

**Push.** For each dirty row the engine diffs current synced columns against `sync_rows` (the last
state known to be on the server) and sends only changed fields, each stamped
`HLC(updated_at, counter, device)`: the row's own `updated_at` (the time the user edited), never
earlier than any stamp already seen for that row, and deterministic, so a retry after a lost ack
produces the *same* change id. The server is idempotent per `(device_id, change_id)`.

**Pull.** `pull(since_server_version)` returns merged row snapshots (values + per-field HLC), oldest
change first, with a cursor. A page is applied in one transaction; the cursor advances in the same
transaction, so an interrupted pull resumes cleanly.

**Order status is derived.** `orders.status` is not a synced field. Status changes are the
append-only `order_status_events`; after applying events the engine sets
`status = target of the latest event` (ordered by `created_at, id`; ids are UUID v7). Concurrent
status changes therefore merge instead of overwrite. `handed_over_at` / `delivered_at` are
re-derived from the same events.

**Derived money is recomputed, never replicated.** `net_receivable, outstanding, profit,
profit_state, gross_collected, cod_status` are excluded; after applying rows the engine runs
`LedgerWriter.refresh` for every touched order, so each device's ledger is a local, tested
computation over the synced events.

**Money is immutable.** `payouts` (status monotonic active -> reversed), `payout_allocations`,
`return_records`/`return_lines` (null -> value once), `order_status_events`, `order_edit_log` are
insert-once: later writers cannot change a value (earliest writer wins on every replica); the server
rejects the attempt and the client logs `rejected`. Corrections are reversals.

**Conflict log (visible).** `sync_conflicts` records: `lost_edit` (your edit was replaced by a newer
one from another device), `rejected` (server refused a change), `over_allocation` (two devices paid
the same parcel; outstanding < 0), `unique_violation` (a remote row could not be applied locally).
Nothing money-related is auto-fixed.

**Order numbers.** `orders.device_code` + unique index `(shop_id, device_code, order_number)`.
Enabling sync assigns the device a short code and stamps existing orders with it; new orders display
`ORD-<code>-0001`. Local-only users keep `ORD-0001` and an empty code.

**Migration and "replace with cloud".** `enable()` queues every existing row (initial snapshot).
`replaceWithCloud()` wipes local synced data, resets cursor/outbox and pulls; the UI must first show
`localCounts()` against `transport.summary()` (reuse the restore preview).

**Status for the UI (spec F15).** `status()` -> disabled / synced / pending / error plus counts of
pending changes and open conflicts; `syncOnce()` never throws and never blocks data entry.
`syncBackoff(failures)` gives the retry delay (5 s doubling, capped at 30 min).

## 3. Server contract (what a backend must implement)

```
POST sync/push   {device_id, changes:[{change_id, table, row_id, shop_id,
                   fields:{col:{value, hlc}}}]}
  -> {accepted:[id], duplicates:[id], rejected:{id:reason}, lost:{id:[field]}}
GET  sync/pull?since=<server_version>&limit=<n>
  -> {rows:[{table, id, shop_id, fields:{col:{value, hlc}}}], cursor, has_more}
GET  sync/summary -> {table: count}          # restore-style preview
```
Rules: authenticate; take `shop_id` from the token, never the payload; reject other shops; reject
tables the role may not write (`forbidden_role`); merge with `mergeFields` semantics (LWW per field;
insert-once and monotonic for money tables); bump `server_version` only when a row actually changed;
idempotency on `(device_id, change_id)`; reject HLC wall time more than a day ahead.
Also needed: account export and delete-account endpoints (Play requirement).

## 4. Test evidence

- `test/sync/sync_engine_test.dart` (16): initial upload then second-device download with derived
  status/ledger equal; master field merge + visible lost-edit log; concurrent status changes merge;
  device-scoped order numbers; payout on A settles on B; double payout keeps both events and flags
  over-allocation, fixed by reversal; rewriting a money row rejected; lost ack + duplicate push exactly
  once; offline entry never blocked; pull failure resumes from cursor; shuffled pages; slow clock;
  replace-with-cloud; local-only mode untouched.
- `test/sync/sync_convergence_test.dart` (13): 12 seeds x 3 real databases x 45 random operations
  (customers, edits, orders, handovers, deliveries, payouts, reversals) with offline periods, lost
  acks, duplicate pushes, shuffled/paginated pulls, failed pulls and clock skew. After delivery every
  device holds identical synced data, nothing is pending, every payout exists everywhere, cached
  outstanding equals a fresh ledger computation, status equals the latest event, no order-number
  collisions. Aggregate over the seeds: 80 orders, 19 payouts, 163 status events, 6 over-allocations,
  50 lost edits.

## 5. Where this deviates from the plan (decisions needed)

1. **`order_charges` (actual courier fees) and `orders.cod_collected` are field-LWW, not immutable
   events.** The app edits them in place with an edit-log entry. Making them events means changing the
   local model (charge adjustments and collected-amount corrections as reversal rows). Until then a
   concurrent fee edit on two devices resolves by LWW, logged in `order_edit_log`.
2. **`shops` (business settings) is not synced.** Its JSON mixes shop-wide and per-device values
   (last backup time, digest schedule, PIN-related flags). Split into `shop_settings` (synced, LWW) and
   device settings first.
3. **Attachments:** metadata rows sync; content-addressed blob upload is not implemented.
4. **Unique constraints** (customer phone, courier + CN): a remote row that violates one is skipped
   and logged. A "merge these two customers" resolution UX is needed (the merge feature exists locally).
5. **Foreign keys are not enforced while a page is applied** (children can precede parents). A
   dangling child is possible if a parent never arrives.
6. **Display order numbers** of legacy orders can repeat across devices (`ORD-0001` on both); the
   unique key is `(device_code, order_number)`.
7. **No transport, auth, background scheduler (`workmanager`), UI (account, status chip, conflict
   list, "existing data vs replace with cloud" screen)** and no server. `SyncTransport` is the seam.
8. **Cost:** `sync_rows` stores a second copy of every synced row (JSON) plus field clocks, roughly
   doubling database size on a synced device. Trigger overhead and the 20k-order performance budgets
   were not re-measured.
9. Status derivation uses `created_at` ordering of events; `correctStatus` with a backdated `at` still
   orders by when it was written.

## 6. Next steps

S16 backend (functions + RLS + auth) -> `HttpSyncTransport` -> S17 UI (status, conflicts, enable /
choose data source) and workmanager runner -> S18 helper roles (per-table read/write matrix, hide
profit/cost fields for helpers) -> resolve items 1, 2, 4 above; then re-run the performance profile at
20k orders with sync enabled.
