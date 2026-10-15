# F-Commerce Order & COD Tracker: Technical Implementation Plan

**Version:** 0.1 (draft)
**Date:** 2026-10-13
**Companion to:** `fcommerce-order-cod-tracker-feature-spec.md`

---

## 1. Decisions on the Spec's Open Questions

These are proposed defaults so that development can start. Each can be revisited, but changing them after Sprint 2 is expensive.

| # | Open question | Decision | Reason |
|---|---|---|---|
| 1 | Local-only vs cloud sync at launch | **Local-first, no server in v1.** Manual file backup plus optional Google Drive backup. Schema is sync-ready (UUIDs, `updated_at`, soft deletes) | Removes backend cost and the biggest schedule risk; the target seller needs offline anyway |
| 2 | Platform | **Flutter, Android first** (iOS later from the same codebase) | One codebase, strong offline and SQLite story, good low-end Android performance |
| 3 | Stock tracking default | **Off by default**, toggle in settings | Keeps the first-run flow short |
| 4 | Courier presets | Ship **names and tracking-URL templates only**, with no pre-filled rates | Rates differ per contract and go stale; the seller enters their own |
| 5 | Bangla-only first? | **Bangla + English from day one** via ARB files | Retrofitting i18n later is far costlier than starting with it |
| 6 | Partial-delivery COD | **Per-line returned quantities**, with the COD adjustment computed and overridable | Keeps profit math exact |
| 7 | Monetization | Out of scope for v1 build; keep an `entitlements` hook in settings | Avoids blocking on a business decision |
| 8 | Multiple shops per account | **Single shop in v1**; every table carries a `shop_id` column (constant) | Cheap now, painful later |

---

## 2. Tech Stack

| Layer | Choice | Notes |
|---|---|---|
| Framework | Flutter (stable channel), Dart 3 | Android minSdk 26 (Android 8) |
| State management | **Riverpod** (with code generation) | Testable, no BuildContext dependence |
| Local DB | **Drift** (SQLite) with `sqlite3_flutter_libs` | Typed queries, migrations, reactive streams, transactions |
| DB encryption (optional) | SQLCipher via `sqlcipher_flutter_libs` | Behind a settings flag; decide after the performance test (see 11) |
| Navigation | `go_router` | Deep links for notification taps |
| Money | `int` poisha (minor units), custom `Money` value type | No floats anywhere in the domain layer |
| IDs | UUID v7 (time-ordered) | Sync-ready, index friendly |
| Notifications | `flutter_local_notifications` + `workmanager` | Daily digest and reminders, with no server |
| Barcode scan | `mobile_scanner` | v1.1 |
| PDF / share | `pdf` + `printing`, `share_plus` | Slips, statements, reports |
| CSV | `csv` package | Import and export |
| Charts | `fl_chart` | Plus table equivalents |
| i18n | `flutter_localizations` + ARB (`bn`, `en`) | Bangla numerals via a formatter |
| Local lock | `local_auth` + `flutter_secure_storage` | PIN or biometric |
| Backup | `googleapis` (Drive appDataFolder) + manual file export | Drive is optional |
| Crash reporting | Firebase Crashlytics (opt-in), no PII | Or Sentry |
| Testing | `flutter_test`, `mocktail`, `integration_test`, `patrol` (optional) | Golden tests for key screens |
| CI | GitHub Actions: analyze, test, build APK/AAB | See 12 |

**Why not a backend now:** the spec has no courier API and no multi-user features in v1, so a server adds cost and failure modes without adding value. Section 9 describes how to add one later without rewriting.

---

## 3. Architecture

### 3.1 Style
**Feature-first, layered:** `presentation -> application -> domain <- data`. The domain layer is pure Dart with no Flutter or Drift imports, so the money and profit rules can be unit tested in milliseconds.

```
lib/
  main.dart
  app/                    # app shell, router, theme, l10n wiring
  core/
    money/                # Money value type, formatters, rounding
    db/                   # Drift database, migrations, DAOs registry
    result/               # Result/Failure types
    time/                 # Clock abstraction (testable "now")
    ids/                  # UUID v7 generator
    utils/
  features/
    orders/
      domain/             # Order, OrderLine, OrderStatus, rules
      data/               # Drift tables, DAO, repository impl
      application/        # use cases / notifiers
      presentation/       # screens, widgets
    customers/
    products/
    couriers/
    cod/                  # ledger, payouts, reconciliation
    returns/
    profit/               # pure calculators
    dashboard/
    reports/
    reminders/
    settings/
    backup/
  l10n/                   # app_en.arb, app_bn.arb
test/
integration_test/
```

### 3.2 Key architectural rules
1. **Domain is pure Dart.** All COD, status-transition, and profit logic lives in `domain/` and has no I/O.
2. **One write path.** Every mutation goes through an application use case that runs inside a **single DB transaction** and writes the timeline or audit event in the same transaction.
3. **Derived values are computed, not trusted.** `net_receivable`, `outstanding`, `profit` and `profit_state` come from calculators; any cached column is rebuilt by the same calculator and can be re-derived (a repair tool exists).
4. **Clock injection.** Nothing calls `DateTime.now()` directly; this makes "overdue" and "stuck parcel" logic testable.
5. **Snapshots over references** for anything that must not drift: order lines snapshot price and cost; the order snapshots the address.
6. **Soft delete only** for financial and business records; financial corrections are **reversals**, never edits-in-place of history.

### 3.3 Data flow
```
UI (Riverpod) -> UseCase -> Repository (interface)
                              |
                         Drift DAO (txn) -> SQLite
                              |
                         AuditLog / StatusEvent (same txn)
UI <- Streams from Drift (reactive queries) <- SQLite
```

---

## 4. Database Design (Drift / SQLite)

### 4.1 Conventions
- Primary keys are `TEXT` UUID v7. Every table has `shop_id`, `created_at`, `updated_at`, `deleted_at` (nullable), and `row_version` (int, incremented on update; used later for sync).
- Money columns are `INTEGER` poisha. Quantity columns are `INTEGER` (or `REAL` only if fractional quantities are needed; v1 uses integer).
- Enums are stored as `TEXT` with a Dart enum converter and a `CHECK` constraint.
- Foreign keys are enabled (`PRAGMA foreign_keys = ON`); WAL mode on.

### 4.2 Tables

```
shops(id, name, phone, currency, timezone, settings_json, ...)

customers(id, shop_id, name, phone_primary, phone_normalized UNIQUE per shop,
          phone_alt, whatsapp, notes, tags_json, ...)
customer_addresses(id, customer_id, label, full_text, district, area, is_default, ...)

products(id, shop_id, name, sku, default_sell_price, default_cost_price,
         stock_qty NULLABLE, is_active, photo_path, ...)
product_variants(id, product_id, label, sku, sell_price NULL, cost_price NULL, stock_qty NULL, ...)

couriers(id, shop_id, name, phone, tracking_url_template, payout_cycle_days,
         stuck_days, cn_regex NULL, cod_fee_percent_bp, cod_fee_flat,
         return_fee_mode, return_fee_value, is_active, ...)
courier_rate_rules(id, courier_id, zone, weight_min_g, weight_max_g, fee, ...)

orders(id, shop_id, order_no UNIQUE per shop, order_date, channel, source_ref,
       customer_id, address_snapshot, status, payment_type,
       items_total, discount_total, delivery_charge_customer, advance_received,
       cod_expected, cod_overridden BOOL, cod_status, cod_collected,
       courier_id NULL, consignment_no NULL, handed_over_at NULL, delivered_at NULL,
       notes, tags_json,
       -- cached derived (rebuildable):
       net_receivable, outstanding, profit, profit_state, ...)
  UNIQUE(courier_id, consignment_no) WHERE deleted_at IS NULL AND consignment_no IS NOT NULL
order_lines(id, order_id, product_id NULL, variant_id NULL, name_snapshot,
            qty, unit_sell_price, unit_cost_price NULL, line_discount, ...)
order_charges(id, order_id, type, expected_amount, actual_amount NULL, source, note, ...)
order_status_events(id, order_id, from_status, to_status, at, reason, note, ...)
order_edit_log(id, order_id, field, old_value, new_value, at, ...)
order_attachments(id, order_id, path, kind, ...)

return_records(id, order_id, type, reason, initiated_at, received_back_at NULL,
               condition, loss_amount, notes, ...)
return_lines(id, return_id, order_line_id, qty, condition, ...)

payouts(id, courier_id, paid_at, method, reference, total_received,
        status, reversed_reason NULL, note, ...)
payout_allocations(id, payout_id, order_id, amount_applied, deductions_applied, note, ...)

expenses(id, shop_id, date, category, amount, note, campaign_id NULL, ...)      -- v1.1
campaigns(id, shop_id, name, start, end, spend, ...)                              -- v1.1

reminders(id, shop_id, type, order_id NULL, due_at, snoozed_until NULL,
          dismissed_at NULL, dismiss_reason NULL, ...)
message_templates(id, shop_id, kind, body, ...)
audit_log(id, entity, entity_id, action, payload_json, at, ...)
```

### 4.3 Indexes (performance-critical)
- `orders(shop_id, status, order_date DESC)`
- `orders(shop_id, cod_status, delivered_at)`
- `orders(courier_id, consignment_no)` (unique, partial)
- `orders(customer_id, order_date DESC)`
- `customers(shop_id, phone_normalized)` (unique)
- `payout_allocations(order_id)`, `payout_allocations(payout_id)`
- `order_status_events(order_id, at)`
- FTS5 virtual table `search_index(order_no, customer_name, phone, cn, product_names, notes)` maintained by triggers or the repository

### 4.4 Migrations
- Drift `schemaVersion` with step-by-step migrations, and a migration test per version (open an old fixture DB, migrate, assert).
- Never edit a shipped migration; always add a new step.
- Pre-migration automatic file copy of the DB (kept for the last 2 versions).

---

## 5. Domain Logic Design

### 5.1 `Money`
```dart
@immutable
class Money implements Comparable<Money> {
  final int poisha;
  const Money(this.poisha);
  Money operator +(Money o) => Money(poisha + o.poisha);
  Money operator -(Money o) => Money(poisha - o.poisha);
  Money percentBp(int basisPoints) => Money((poisha * basisPoints / 10000).round()); // banker's rounding decision documented
  // format(), parse(), compareTo...
}
```
Rounding rule is defined once (round half up), applied only at the point a percentage fee is computed, and covered by tests.

### 5.2 Status state machine
A pure `OrderStatusMachine` with an allowed-transition table plus guard functions:

| Transition | Guard |
|---|---|
| any -> `handedToCourier` | courier set and CN non-empty |
| `handedToCourier`/`inTransit` -> `delivered` | none (back-dating allowed, not future) |
| -> `deliveryFailed`, `cancelled` | reason required |
| `deliveryFailed` -> `returnInTransit` | auto (setting) |
| `returnInTransit` -> `returned` | received-back date >= initiated date |

A separate `correctStatus()` use case bypasses the table but always logs a correction event.

### 5.3 COD state derivation
`CodStatusResolver.resolve(order, allocations, returns)` returns one of `notApplicable | pendingCollection | collectedByCourier | partiallySettled | settled | notCollected | disputed`, using the rules in spec section 4.2 and F6. Disputed is an explicit flag, never inferred.

### 5.4 Charges
`ChargeCalculator` produces expected `delivery_fee`, `cod_fee`, `return_fee` from the courier's rules; actuals are written at settlement. Profit always prefers `actual` over `expected`.

### 5.5 Profit
`ProfitCalculator.compute(order) -> ProfitResult { revenue, costs[], net, marginBp, state }` implementing spec F8 section 8.1 and 8.2, with:
- `state = incomplete` if any line has a null cost
- `state = final` if the order is settled (or prepaid and delivered with no unsettled expected charges)
- otherwise `provisional`

The calculator is pure and takes immutable inputs, so the same function backs the order detail breakdown, the list chip, and the reports (which prevents drift between screens).

### 5.6 Reconciliation
`PayoutReconciler`:
- `autoAllocate(courier, totalReceived)` allocates oldest-delivered-first against each order's `outstanding`
- `difference(selectedOrders, totalReceived)` returns the shortfall or overage
- `settle(allocations, shortfallPolicy)` where policy is `allocate | dispute | writeOff`
- `reverse(payout)` restores outstanding balances

All run inside a single transaction, and each emits audit rows.

### 5.6.1 Invariants (assert in code and tests)
- For every order: `sum(allocation.amount_applied) <= net_receivable` unless an explicit overpayment adjustment exists
- For every courier: `sum(outstanding) == dashboard "pending with courier" for that courier`
- For every filter: `sum(order.profit) == report profit`

---

## 6. Feature to Module Mapping

| Spec feature | Module(s) | Key deliverables |
|---|---|---|
| F1 Order entry | `orders` | Form with live COD calc, drafts, duplicate, soft delete and undo |
| F2 Customers | `customers` | Phone normalization, duplicate detection, merge |
| F3 Products | `products` | Snapshot-on-add, cost-missing badge, optional stock |
| F4 Couriers | `couriers` | Rate cards, fee rules, tracking-URL launcher, stuck threshold |
| F5 Status | `orders` | State machine, bulk update, timeline |
| F6 COD | `cod` | Ledger, payout recorder, reconciliation, ageing views |
| F7 Returns | `returns` | Full/partial flows, stock restore, loss calculation |
| F8 Profit | `profit` | Calculators, breakdown panel, state labels |
| F9 Dashboard / reports | `dashboard`, `reports` | Aggregate queries, drill-down, CSV/PDF |
| F10 Search | `orders` + search index | FTS5, filters, saved views |
| F11 Reminders | `reminders` | Queue builder, local notifications, snooze |
| F14 Export/backup | `backup` | CSV, PDF, backup file, restore, import |
| F15 Offline | `core/db` | Local-first by design |
| F16 Settings | `settings` | Preferences, thresholds, lock |

---

## 7. Implementation Phases & Sprints

Two-week sprints for a solo developer or a pair, assisted by AI coding tools. Adjust the durations to team size.

### Phase 0: Foundations (Sprint 0, about 1 week)
- [ ] Repo, Flutter project, lints (`very_good_analysis` or similar), CI skeleton
- [ ] Riverpod, go_router, theme (light/dark), l10n scaffolding (`en`, `bn`)
- [ ] Drift setup, WAL, foreign keys, base table mixin, migration test harness
- [ ] `Money`, `Clock`, UUID v7, `Result` types, and their unit tests
- [ ] Design tokens and base components (amount field with numeric keypad, status chip, empty states)
- [ ] Decision spike: DB encryption cost on a low-end device (see 11)

**Exit criteria:** the app launches, the DB opens, one dummy entity round-trips, CI is green.

### Phase 1: Core Orders (Sprints 1 to 2)
**Sprint 1: Masters**
- [ ] Customers: CRUD, phone normalization, duplicate prompt, address book
- [ ] Products: CRUD, variants, cost price
- [ ] Couriers: CRUD, rate rules, fee rules, tracking template
- [ ] Settings v1: business profile, order prefix, defaults
- [ ] Seed data and fixtures for dev

**Sprint 2: Order entry**
- [ ] Order form: customer picker with search, items, charges, live COD calculation, override marker
- [ ] Draft autosave, duplicate order, soft delete and recently deleted
- [ ] Orders list: pagination via keyset, basic filters
- [ ] Order detail: summary and timeline (read-only)
- [ ] Order numbering service (transactional, gapless per shop but never reused)

**Exit criteria:** create, edit, and duplicate orders offline; COD formula tests pass; list stays smooth with 5k seeded orders.

### Phase 2: Fulfilment & COD (Sprints 3 to 4)
**Sprint 3: Status and courier flow**
- [ ] `OrderStatusMachine`, status buttons, reasons, back-dating
- [ ] Courier and CN assignment, uniqueness enforcement, Track launcher
- [ ] Bulk select and bulk status change with undo
- [ ] Stuck-parcel flags and the "Stuck parcels" filter
- [ ] Order timeline and edit log (audit)

**Sprint 4: COD ledger and payouts**
- [ ] Order charges (expected/actual), `ChargeCalculator`
- [ ] `CodStatusResolver`, per-order COD ledger panel
- [ ] COD hub: pending by courier, in-transit forecast, ageing buckets
- [ ] Record payout flow: select orders, difference display, auto-allocate, allocate / dispute / write-off
- [ ] Payout reversal; payout detail screen

**Exit criteria:** all reconciliation invariants (5.6.1) hold under property-based tests; payout of 100 orders saves in under 1 s.

### Phase 3: Returns & Profit (Sprint 5)
- [ ] Return record flows (full and partial), reasons, condition, received-back
- [ ] Stock restore and decrement (when the setting is on)
- [ ] `ProfitCalculator` plus breakdown panel; provisional / final / incomplete labels
- [ ] Profit chip in lists with the privacy toggle
- [ ] 15+ profit scenario tests (spec section 16)

**Exit criteria:** every profit scenario in spec section 16 is an automated test and passes.

### Phase 4: Insight & Habit (Sprints 6 to 7)
**Sprint 6: Dashboard, search and reports**
- [ ] Aggregate queries and (if needed) a cached `daily_aggregates` table
- [ ] Dashboard tiles with drill-down
- [ ] FTS5 search, saved views, full filter set
- [ ] Reports: daily summary, COD ageing, courier performance, profit, returns

**Sprint 7: Reminders and data safety**
- [ ] Follow-up queue builder (six sources) and Needs-attention badge
- [ ] Local notifications: daily digest, quiet hours, per-type toggles
- [ ] Snooze and dismiss; quick actions (call, WhatsApp, track)
- [ ] CSV export (all entities), PDF reports and order slip
- [ ] Manual backup file and restore with preview; backup reminder
- [ ] Message templates and share intents

**Exit criteria:** dashboard under 1.5 s with 20k orders on the reference device; the backup then restore round trip is lossless.

### Phase 5: Hardening & Release (Sprint 8)
- [ ] App lock (PIN / biometric), hide-amount toggles
- [ ] Bangla translation review by a native speaker; numerals and layout checks
- [ ] Accessibility pass (font scaling to 200%, touch targets, TalkBack labels)
- [ ] Performance profiling on a low-end device; fix jank
- [ ] Onboarding flow and sample-data mode
- [ ] Crash reporting (opt-in), privacy policy, store listing
- [ ] Closed beta with 5 to 10 real sellers; fix the top issues
- [ ] Play Store release (internal -> closed -> production)

### Post-MVP
- **v1.1:** customer risk flags, expenses and ad allocation, exchange flow, CSV import, barcode scan, Drive backup
- **v2:** accounts and sync, helper roles, iOS, courier statement import, paste-to-parse

---

## 8. Testing Strategy

| Level | What | Tooling |
|---|---|---|
| **Unit (domain)** | Money, state machine, COD resolver, charges, profit, reconciler | `flutter_test`; target **95%+ coverage on `domain/`** |
| **Property-based** | Invariants in 5.6.1 using randomly generated order and payout sets | `glados` or hand-rolled generators with fixed seeds |
| **DB / repository** | Queries, uniqueness constraints, migrations, FTS | In-memory Drift, plus fixture DBs for each old schema version |
| **Widget** | Order form (live COD), payout flow, filters | `flutter_test` + golden images for key screens in `en` and `bn` |
| **Integration** | Create -> dispatch -> deliver -> payout -> report, fully offline | `integration_test` on an emulator |
| **Performance** | 20k-order dataset: list scroll, search, dashboard, payout save | Seeder script + profile-mode runs on a low-end device |
| **Manual / beta** | Real seller workflows, Bangla copy | Checklist per release |

**Golden rule:** no profit or COD bug is fixed without first adding a failing test that reproduces it.

---

## 9. Sync-Ready Design (for later)

The plan avoids a backend now but keeps the door open:
- **UUID v7 IDs and `row_version` / `updated_at`** on every row.
- **Soft deletes** (tombstones) so deletions can propagate.
- **Append-only audit and status-event tables**, which merge naturally.
- **Repository interfaces** (`OrderRepository` etc.) so a `SyncingOrderRepository` decorator can be added without touching use cases.
- **Candidate backend when needed:** Django REST (or Supabase) with per-entity `pull(since)` and `push(batch)` endpoints, last-write-wins per field, and a conflict log.
- Money-affecting entities (payouts, allocations) sync as **immutable events**, with reversals instead of edits, to avoid reconciliation conflicts.

---

## 10. Security & Privacy Implementation

- DB file in app-private storage; excluded from Android auto-backup unless the user opts in (set `allowBackup=false` and use the app's own backup).
- Optional SQLCipher; the key is stored in Android Keystore via `flutter_secure_storage`.
- PIN stored as a salted hash (e.g. Argon2id or PBKDF2); biometric via `local_auth`.
- Backup files are optionally passphrase-encrypted (AES-GCM with a key derived from the passphrase).
- No customer PII in logs or crash reports; analytics are opt-in and event-level only.
- "Erase all data" wipes the DB, attachments, secure-storage keys, and scheduled notifications.
- Customer phone numbers are only passed to dialer and WhatsApp intents on explicit user action.

---

## 11. Performance Plan

| Concern | Approach |
|---|---|
| Large lists | Keyset pagination, `ListView.builder`, lightweight row widgets, no per-row async work |
| Dashboard | SQL aggregates with proper indexes; add `daily_aggregates` maintained in the same write transaction if tiles exceed the budget |
| Search | FTS5 with prefix queries; debounce 150 ms |
| Bulk updates | Single transaction with batched statements |
| Startup | Lazy-open heavy features; avoid blocking migrations (progress UI if one runs long) |
| Encryption cost | Spike in Sprint 0 on a low-end device; ship encrypted-by-default only if the overhead is acceptable, else opt-in |
| Images | Downscale and compress attachments on save (max ~1280 px, JPEG quality ~75) |

**Budgets:** order save < 200 ms; list first paint < 500 ms; search results < 300 ms; dashboard < 1.5 s at 20k orders; cold start < 2.5 s on the reference device.

---

## 12. DevOps & Release

- **Branching:** trunk-based with short-lived feature branches; PRs require a green CI.
- **CI (GitHub Actions):** `flutter analyze` -> `flutter test --coverage` -> coverage gate on `domain/` -> build APK/AAB on `main`.
- **Environments:** `dev` (sample data, debug menu), `staging` (internal testing track), `prod`.
- **Versioning:** semantic version plus build number from CI; changelog from conventional commits.
- **Signing:** keystore in CI secrets; Play App Signing enabled.
- **Release channels:** Play internal -> closed beta -> production with staged rollout (10% -> 50% -> 100%).
- **Debug tooling (non-prod):** seed 20k orders, DB inspector export, time-travel clock override, and a "repair derived fields" action.

---

## 13. Risk Register (Technical)

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Profit or COD math bugs | Med | High | Pure domain layer, property tests, scenario suite, derived-value repair tool |
| Data loss (device lost or corrupted DB) | Med | High | Transactional writes, backup reminders, pre-migration copies, easy export |
| Migration failure on upgrade | Low | High | Migration tests against fixture DBs; automatic pre-migration backup |
| Jank on low-end Android | Med | Med | Early profiling on a reference device, perf budgets in CI where feasible |
| Background reminders killed by OEM battery savers | High | Med | In-app "Needs attention" queue is the source of truth; notifications are a bonus; show a one-time battery-optimization guide |
| Bangla text rendering / layout bugs | Med | Med | Native-speaker review; `bn` goldens; test with large font scales |
| Scope creep into sync, accounts, API | Med | High | Treat Section 1 decisions as locked for v1; log requests in the post-MVP list |
| Manual-entry fatigue reduces usage | High | High | Measure update discipline (spec section 11); invest in bulk actions and the queue early |

---

## 14. Suggested Working Method with AI Coding Tools

1. **Spec-in-repo:** commit both markdown files under `/docs`; reference them in the `CLAUDE.md` or Cursor rules so every session shares context.
2. **Rules file highlights:** domain stays pure; money is integer poisha; all writes via use cases in one transaction; no `DateTime.now()`; every bug gets a failing test first.
3. **Sprint prompts:** one prompt per sprint listing the tasks, the files to touch, and the exit criteria from section 7; ask for tests alongside the code.
4. **Review gates:** after Phase 2 and Phase 3, run a focused review of the reconciliation and profit code against the invariants in 5.6.1 before building on top.
5. **Keep PRs small:** one use case or screen per PR, so regressions are easy to bisect.

---

## 15. Definition of Done (per feature)

- [ ] Domain logic covered by unit tests; invariants hold
- [ ] Works fully offline; no network assumption
- [ ] `en` and `bn` strings present; no hard-coded text
- [ ] Empty, loading, and error states designed
- [ ] Audit or timeline entries written for money- or status-affecting actions
- [ ] Meets performance budgets on the reference device
- [ ] Accessibility checks (font scale, touch targets, labels)
- [ ] Documented in the changelog; spec acceptance criteria ticked

---

## 16. Immediate Next Steps (First Week)

1. Confirm the Section 1 decisions (especially local-first and Flutter).
2. Create the repo, CI, and `/docs`; add the rules file.
3. Build `Money`, `Clock`, and the Drift base, with tests.
4. Run the encryption and performance spike on a low-end phone.
5. Draft the Bangla and English string inventory for the order form.
6. Recruit 5 to 10 beta sellers early, since their real orders will validate the reconciliation flow better than any test data.

---
*End of document.*
