# F-Commerce Order & COD Tracker: Sprint-wise Implementation Plan

**Version:** 0.1 (draft)
**Date:** 2026-10-13
**Companions:** `fcommerce-order-cod-tracker-feature-spec.md`, `fcommerce-order-cod-tracker-implementation-plan.md`

---

## 0. How to Read This Document

### 0.1 Conventions
- **Task ID:** `S{sprint}-{nn}` (e.g. `S2-07`). Dependencies are listed as `needs: S2-03`.
- **Estimate:** ideal engineering hours (h) for one developer working with AI coding tools. A day is about 5 productive hours. Estimates include writing tests.
- **Tags:** `[D]` domain (pure Dart), `[DB]` database/Drift, `[UI]` presentation, `[APP]` application/use case, `[QA]` testing, `[OPS]` tooling/CI, `[L10N]` localization.
- **Spec refs:** `F#` = feature in the feature spec; `§` = section of the implementation plan.
- **Definition of Done** for every task: section 15 of the implementation plan (tests, offline, `en`+`bn` strings, states, audit entries, perf budget, a11y).

### 0.2 Capacity and timeline

| Sprint | Theme | Length | Est. hours |
|---|---|---|---|
| S0 | Foundations | 1 week | ~28 |
| S1 | Masters (customers, products, couriers, settings) | 2 weeks | ~52 |
| S2 | Order entry | 2 weeks | ~54 |
| S3 | Status & courier flow | 2 weeks | ~52 |
| S4 | COD ledger & payouts | 2 weeks | ~56 |
| S5 | Returns & profit | 2 weeks | ~50 |
| S6 | Dashboard, search & reports | 2 weeks | ~52 |
| S7 | Reminders & data safety | 2 weeks | ~52 |
| S8 | Hardening & release | 2 weeks | ~46 |

Total is about 17 weeks and ~440 h for one developer at ~25 productive h/week. Add roughly 15% buffer for unknowns (about 2.5 weeks). Two developers can parallelize the `[UI]` and `[D]/[DB]` tracks inside each sprint.

### 0.3 Sprint ceremonies (lightweight)
- Day 1: confirm scope, pull tasks, write the sprint prompt for the AI tool.
- Mid-sprint: demo on a physical low-end Android device.
- Last day: run the exit checklist, tag a build, write a short changelog.
- Every sprint: seed the perf dataset and check budgets (implementation plan §11).

---

## Sprint 0: Foundations (1 week)

**Goal:** A running Flutter app with CI, DB, i18n, and the core primitives every later sprint depends on.

### Tasks

| ID | Task | Est | Tags | Needs |
|---|---|---|---|---|
| S0-01 | Create the repo, Flutter project (Android minSdk 26), flavors `dev`/`staging`/`prod`, `.editorconfig`, README | 2h | OPS | |
| S0-02 | Lints (`very_good_analysis`), `analysis_options.yaml`, pre-commit (format + analyze) | 1.5h | OPS | S0-01 |
| S0-03 | GitHub Actions: analyze, test with coverage, build debug APK; coverage gate on `lib/**/domain/**` | 3h | OPS | S0-02 |
| S0-04 | Add `/docs` (spec files), `CLAUDE.md` or Cursor rules (domain purity, integer money, single-transaction writes, no `DateTime.now()`, test-first bugfix) | 1.5h | OPS | S0-01 |
| S0-05 | Folder structure per §3.1; barrel files; Riverpod + codegen setup; `ProviderScope` bootstrap | 2h | APP | S0-01 |
| S0-06 | `go_router` shell with bottom navigation (Home, Orders, New, COD, More) and placeholder screens | 2h | UI | S0-05 |
| S0-07 | Theme: light/dark, color tokens (status colors with icon+text, not color alone), typography (min 16 px body), spacing, 48 dp targets | 3h | UI | S0-06 |
| S0-08 | l10n scaffolding: `app_en.arb`, `app_bn.arb`, extension `context.l10n`, a lint/test that fails on missing keys between locales | 2.5h | L10N | S0-05 |
| S0-09 | `Money` value type (poisha int), `parse`, `format` (৳, grouping option, Bangla numerals option), percent-bp rounding (round half up) + unit tests | 3h | D | S0-05 |
| S0-10 | `Clock` abstraction + `FakeClock`; provider; test helpers | 1h | D | S0-05 |
| S0-11 | UUID v7 generator + tests (monotonic ordering) | 1h | D | S0-05 |
| S0-12 | `Result<T, Failure>` type + failure hierarchy | 1h | D | S0-05 |
| S0-13 | Drift setup: `AppDatabase`, WAL, `foreign_keys=ON`, base table mixin (`id`, `shop_id`, `created_at`, `updated_at`, `deleted_at`, `row_version`), `shops` table, in-memory test DB factory | 3h | DB | S0-11 |
| S0-14 | Migration test harness (fixture-DB per version, migrate, assert) + pre-migration file copy utility | 2h | DB | S0-13 |
| S0-15 | Base UI components: `AmountField` (numeric keypad, live formatting), `StatusChip`, `EmptyState`, `ConfirmDialog`, `UndoSnackbar` | 3h | UI | S0-07, S0-09 |
| S0-16 | **Spike:** SQLCipher vs plain SQLite on a low-end device (open time, insert 20k rows, query list) and a short decision note in `/docs/decisions/001-db-encryption.md` | 3h | DB | S0-13 |
| S0-17 | Debug menu (non-prod): seed data hook placeholder, clock override, DB export | 1.5h | OPS | S0-13 |

**Total:** ~37h in the table, but S0-04, S0-12, and S0-17 are small; plan 28 to 37h and accept slight slip into week 2 if the spike takes longer.

### Tests
- `Money`: addition/subtraction, percent rounding edge cases (e.g. 1% of ৳1,234.50), parse of "1,234.5", formatting in `en` and `bn`.
- Clock/UUID: ordering and determinism.
- DB: open in-memory, insert and read a `shops` row; migration harness runs an empty migration.

### Exit checklist
- [ ] App runs on a physical Android device; navigation shell visible in `en` and `bn`
- [ ] CI green with the coverage gate active
- [ ] `Money`, `Clock`, UUID, `Result` fully unit tested
- [ ] Encryption decision note committed

---

## Sprint 1: Masters (2 weeks)

**Goal:** Customers, products, couriers and settings exist and are usable, so Sprint 2 can focus purely on orders. Spec: F2, F3, F4 (setup part), F16 (partial).

### 1A. Database

| ID | Task | Est | Tags | Needs |
|---|---|---|---|---|
| S1-01 | Tables: `customers`, `customer_addresses` (+ unique `(shop_id, phone_normalized)` partial index), DAOs, reactive queries | 3h | DB | S0-13 |
| S1-02 | Tables: `products`, `product_variants`; DAO | 2h | DB | S0-13 |
| S1-03 | Tables: `couriers`, `courier_rate_rules`; DAO | 2.5h | DB | S0-13 |
| S1-04 | Settings storage: `shops.settings_json` typed wrapper (`ShopSettings`) with defaults and versioning | 2h | DB | S0-13 |
| S1-05 | Migration step 1->2 and its migration test | 1h | DB | S1-01..S1-03 |

### 1B. Domain and application

| ID | Task | Est | Tags | Needs |
|---|---|---|---|---|
| S1-06 | `PhoneNormalizer` (BD formats: `01XXXXXXXXX`, `+8801…`, `8801…`, spaces/dashes; Bangla digits) + tests (20+ cases) | 2.5h | D | S0-05 |
| S1-07 | Customer use cases: create, update, archive, `findByPhone`, `searchCustomers(query)`; duplicate-detection result type | 3h | APP | S1-01, S1-06 |
| S1-08 | Customer merge use case (move orders/addresses to the survivor, log merge in `audit_log`); stub order references until S2 | 3h | APP | S1-07 |
| S1-09 | Product use cases: CRUD, variant handling, soft deactivate | 2.5h | APP | S1-02 |
| S1-10 | `ChargeRule` domain: courier fee rule model (zone/weight band lookup, COD fee percent-bp + flat, return fee modes) + `ChargeCalculator` v1 + tests | 4h | D | S0-09 |
| S1-11 | Courier use cases: CRUD, rate rules, tracking-URL template (`{cn}` substitution + validation), stuck/payout-cycle thresholds | 3h | APP | S1-03, S1-10 |
| S1-12 | `audit_log` table and `AuditWriter` (used inside transactions) | 2h | DB | S0-13 |

### 1C. UI

| ID | Task | Est | Tags | Needs |
|---|---|---|---|---|
| S1-13 | Customers list (search as-you-type, debounce 150 ms), empty state | 3h | UI | S1-07 |
| S1-14 | Customer form: name, phones, WhatsApp, addresses (add/edit/default), duplicate banner "Use existing customer?" | 4h | UI | S1-07 |
| S1-15 | Customer detail (shell): contact, addresses, placeholder summary card (filled in S2/S5) | 2h | UI | S1-13 |
| S1-16 | Products list + form (price, cost, variants, active toggle, optional stock field hidden unless enabled) | 4h | UI | S1-09 |
| S1-17 | Couriers list + form: details, tracking template with live preview, thresholds | 3h | UI | S1-11 |
| S1-18 | Courier rate card editor: zones, weight bands, COD fee rule, return fee rule; inline validation | 4h | UI | S1-11 |
| S1-19 | Settings screen v1: business profile, order prefix/start number, defaults (channel, delivery charge, packaging cost, courier), workflow toggles (Packed/In Transit, auto-return flow, stock tracking), language switch | 4h | UI | S1-04 |
| S1-20 | Dev seeder v1: generates 500 customers, 80 products, 4 couriers with rate cards | 2h | OPS | S1-01..S1-03 |

### Tests
- Phone normalization matrix; duplicate-detection scenarios.
- Merge: orders/addresses reassigned; audit row written (using stubs).
- `ChargeCalculator`: inside/outside Dhaka, weight bands, COD percent and flat fee combo, free-under-X rule.
- Widget: customer form shows the duplicate banner; courier tracking URL preview.
- Migration 1->2.

### Exit checklist
- [ ] Create/edit/archive customers, products, couriers offline
- [ ] Duplicate-phone prompt works; merge use case tested
- [ ] Courier tracking template substitutes the CN correctly
- [ ] Settings persist across restarts; `bn`/`en` complete for all new screens
- [ ] Search of 500 seeded customers under 300 ms

---

## Sprint 2: Order Entry (2 weeks)

**Goal:** Create, edit, duplicate, draft, and delete orders offline with live COD calculation. Spec: F1, F10 (basic), partial F8 groundwork.

### 2A. Database

| ID | Task | Est | Tags | Needs |
|---|---|---|---|---|
| S2-01 | Tables: `orders`, `order_lines`, `order_charges`, `order_attachments`, `order_edit_log`, `order_status_events` (+ all indexes in §4.3 except FTS) | 4h | DB | S1-05 |
| S2-02 | Partial unique index for `(courier_id, consignment_no)` where not deleted | 1h | DB | S2-01 |
| S2-03 | `OrderNumberService`: transactional, never reused, prefix and start number from settings; concurrency test | 2.5h | DB | S2-01, S1-04 |
| S2-04 | Migration 2->3 + test | 1h | DB | S2-01 |
| S2-05 | `OrderDao`: keyset-paginated list, get by id with lines/charges, filter query builder (status, date range, channel, customer) | 4h | DB | S2-01 |

### 2B. Domain and application

| ID | Task | Est | Tags | Needs |
|---|---|---|---|---|
| S2-06 | Domain models: `Order`, `OrderLine`, `OrderStatus`, `PaymentType`, `Channel`, `OrderDraft` | 2.5h | D | S0-09 |
| S2-07 | `CodAmountCalculator`: `items - discounts + delivery_charge - advance`, line and order discounts (amount/%), override flag logic + tests (15+ cases incl. rounding) | 3h | D | S2-06 |
| S2-08 | `CreateOrder` use case: one transaction, creates the order, lines (price/cost snapshots), address snapshot, expected charges from courier rules if a courier is set, status event, audit | 4h | APP | S2-05, S2-07, S1-10 |
| S2-09 | `UpdateOrder` use case: field-level diff to `order_edit_log`; warning result when editing amounts after handover (consumed in S3) | 3h | APP | S2-08 |
| S2-10 | Draft handling: `saveDraft`, `promoteDraft`, autosave on leave; drafts excluded from all aggregates (query-level) | 2.5h | APP | S2-08 |
| S2-11 | `DuplicateOrder` use case (copy the lines, address, channel; new number/date; reset status/COD) | 1.5h | APP | S2-08 |
| S2-12 | Soft delete + restore + "recently deleted" (30-day purge job stub) | 2.5h | APP | S2-05 |
| S2-13 | Attachment handling: copy to the app dir, downscale (~1280px, JPEG 75), delete on purge | 2.5h | APP | S2-01 |

### 2C. UI

| ID | Task | Est | Tags | Needs |
|---|---|---|---|---|
| S2-14 | Order form: layout with sticky COD/summary bar; sections (customer, items, charges, payment, courier, notes) | 5h | UI | S2-08 |
| S2-15 | Customer picker (search by name/phone, create inline), address chooser with per-order edit | 3.5h | UI | S1-13, S2-14 |
| S2-16 | Items editor: pick from the catalog or free text, qty stepper, price/cost editing, "cost missing" badge, "save to catalog" shortcut | 4.5h | UI | S1-16, S2-14 |
| S2-17 | Charges and payment section: delivery charge default, discounts, advance (method note), COD live calc with "overridden" marker + reset control | 3.5h | UI | S2-07, S2-14 |
| S2-18 | Optional courier and CN at creation (soft validation, unique-CN error with a link to the conflicting order) | 2.5h | UI | S2-02, S2-14 |
| S2-19 | Draft list and resume; "discard draft" | 2h | UI | S2-10 |
| S2-20 | Orders list v1: card row (number, customer, amount, status chip, COD chip), keyset infinite scroll, status/date filters | 4h | UI | S2-05 |
| S2-21 | Order detail v1: summary, lines, charges, read-only timeline, overflow menu (Edit, Duplicate, Delete) | 4h | UI | S2-09 |
| S2-22 | Recently deleted screen with restore | 1.5h | UI | S2-12 |
| S2-23 | Seeder v2: 5k orders with varied statuses/amounts for perf tests | 2h | OPS | S2-08 |

### Tests
- COD calculator matrix (discounts, advance, override, rounding).
- Use-case integration tests: create -> read -> update (diff logged) -> duplicate -> delete -> restore.
- Concurrent order-number allocation yields unique, gapless numbers.
- Unique CN conflict returns a typed failure.
- Widget: COD bar updates live; "overridden" marker and reset.
- Perf: list scroll and first paint with 5k orders.

### Exit checklist
- [ ] Create an order for an existing customer in 3 steps with defaults
- [ ] COD formula verified by tests; override marker works
- [ ] Drafts autosave and are excluded from totals
- [ ] Soft delete with undo and restore works
- [ ] 5k-order list smooth on the reference device

---

## Sprint 3: Status & Courier Flow (2 weeks)

**Goal:** Move orders through the lifecycle with reasons, back-dating, bulk actions, a timeline, and stuck-parcel detection. Spec: F4 (per-order), F5.

### Tasks

| ID | Task | Est | Tags | Needs |
|---|---|---|---|---|
| S3-01 | `OrderStatusMachine`: transition table, guards (courier+CN required for Handed to Courier; reason required for Failed/Cancelled; no future dates; return received >= initiated) + exhaustive tests | 4h | D | S2-06 |
| S3-02 | `ChangeStatus` use case: transaction with the status event, `handed_over_at`/`delivered_at` stamps, COD status side effects (hook for S4), audit | 4h | APP | S3-01, S2-08 |
| S3-03 | `CorrectStatus` use case (bypass the table, mandatory note, flagged in the timeline) | 2h | APP | S3-02 |
| S3-04 | Reason catalog (failed/cancelled) in settings with defaults, localized | 1.5h | APP | S1-04 |
| S3-05 | `AssignCourier` use case: courier, CN, handover time, weight, expected fees via `ChargeCalculator`, unique-CN enforcement | 3.5h | APP | S2-02, S1-10 |
| S3-06 | `BulkChangeStatus` use case: single transaction, per-order guard results, partial-failure report (which orders were skipped and why), undo token | 4.5h | APP | S3-02 |
| S3-07 | Undo mechanism for bulk (store the inverse events; valid for 30 s or until the next mutation) | 3h | APP | S3-06 |
| S3-08 | `StuckParcelPolicy` domain: per-courier threshold N; amber at N, red at 2N; uses `Clock`; tests | 2h | D | S1-11 |
| S3-09 | Status action bar on order detail (valid next actions only; optional-step visibility from settings) | 3.5h | UI | S3-02 |
| S3-10 | Status change sheet: date/time (back-dating), reason picker (one-tap default), note | 3h | UI | S3-04, S3-09 |
| S3-11 | Courier and CN sheet: courier picker, CN field, paste/clear, soft regex warning, **Track** button (opens template URL via `url_launcher`), "Last updated by you: N days ago" | 4h | UI | S3-05 |
| S3-12 | Edit-after-handover warning dialog (amounts changed while with the courier) | 1.5h | UI | S2-09 |
| S3-13 | Order timeline widget: status events, edits (old -> new), notes, corrections; full-screen history | 3.5h | UI | S3-02 |
| S3-14 | List multi-select mode: long-press, select-all-visible, action bar (Handed / Delivered / Failed), results summary toast with Undo | 4.5h | UI | S3-06, S3-07 |
| S3-15 | Swipe actions on list rows (configurable: quick Delivered / quick Handed over) | 2h | UI | S3-02 |
| S3-16 | Stuck badges on list/detail + saved filter "Stuck parcels" | 2.5h | UI | S3-08 |
| S3-17 | Fast CN entry flow: step through unassigned orders with a keypad-friendly screen (next/skip) | 3.5h | UI | S3-05 |
| S3-18 | Seeder v3: realistic status mix with timestamps spread over 90 days | 1.5h | OPS | S3-02 |

### Tests
- State machine: every allowed and disallowed transition pair; guard failures return typed errors.
- `ChangeStatus`: timeline row written, stamps set, back-dated and future-dated cases.
- Bulk: 100 orders in under 2 s; mixed valid/invalid selection yields the correct skipped list; undo restores exact prior state.
- Stuck policy at boundaries (N, 2N) with `FakeClock`.
- Widget: only valid actions shown; Failed requires a reason.

### Exit checklist
- [ ] Full lifecycle driven by UI on a device, fully offline
- [ ] Bulk 100-order update under 2 s with working Undo
- [ ] Duplicate CN blocked with a link to the conflicting order
- [ ] Timeline shows every change with the previous value
- [ ] Track button opens the correct courier URL

---

## Sprint 4: COD Ledger & Payouts (2 weeks)

**Goal:** Always know where the cash is: per-order ledger, courier pending totals, ageing, and payout reconciliation with reversal. Spec: F6.

> This sprint is the highest-risk for correctness. Do not start the UI tasks (4C) until the domain tasks (4B) and their property tests pass.

### 4A. Database

| ID | Task | Est | Tags | Needs |
|---|---|---|---|---|
| S4-01 | Tables: `payouts`, `payout_allocations` + indexes; migration 3->4 and test | 3h | DB | S2-04 |
| S4-02 | Ledger columns on `orders` (`cod_collected`, cached `net_receivable`, `outstanding`) + the "repair derived fields" routine | 2.5h | DB | S4-01 |
| S4-03 | DAO queries: pending by courier, in-transit COD forecast, ageing buckets (0-3, 4-7, 8-14, 15+ days since delivery), disputed list | 4h | DB | S4-02 |

### 4B. Domain and application (do first)

| ID | Task | Est | Tags | Needs |
|---|---|---|---|---|
| S4-04 | `CodStatusResolver` (all 7 states; Disputed is an explicit flag) + tests | 3.5h | D | S2-06 |
| S4-05 | `ChargeCalculator` v2: actual charges override expected; deductions aggregated per order | 2h | D | S1-10 |
| S4-06 | `LedgerCalculator`: `net_receivable = collected - deductions`, `outstanding = net_receivable - settled` | 2h | D | S4-05 |
| S4-07 | `PayoutReconciler`: `autoAllocate` (oldest-delivered-first), `difference`, `settle(policy)` for allocate / dispute / writeOff, overpayment adjustment rule | 6h | D | S4-06 |
| S4-08 | **Property-based tests** for the invariants (implementation plan §5.6.1): allocations never exceed net receivable; the sum of outstanding per courier equals the pending total; the same total after a reverse round trip | 4h | QA | S4-07 |
| S4-09 | Hook `ChangeStatus` to COD side effects: Delivered + COD > 0 -> Collected by Courier; Failed/Returned/Cancelled -> Not Collected; partial-delivery hook for S5 | 2.5h | APP | S4-04, S3-02 |
| S4-10 | `RecordCollectedAmount` use case (short-collection edit with a reason) | 2h | APP | S4-06 |
| S4-11 | `RecordPayout` use case: one transaction creating the payout, allocations, order COD status/outstanding updates, write-off adjustment charges, audit | 5h | APP | S4-07, S4-01 |
| S4-12 | `ReversePayout` use case: restore outstanding balances and COD states; mandatory reason; audit | 3h | APP | S4-11 |
| S4-13 | `MarkDisputed` / `ResolveDispute` use cases with notes | 2h | APP | S4-04 |

### 4C. UI

| ID | Task | Est | Tags | Needs |
|---|---|---|---|---|
| S4-14 | Order detail: COD ledger panel (expected, collected, deductions itemized, net receivable, settled, outstanding) + actual-fee editor | 4.5h | UI | S4-06 |
| S4-15 | COD hub screen: tiles (Pending with courier, In transit, Disputed, Settled this month), grouped by courier with age and overdue flag vs the courier payout cycle | 5h | UI | S4-03 |
| S4-16 | COD ageing view (buckets, drill-down to the order list) | 3h | UI | S4-03 |
| S4-17 | Record payout flow step 1: choose the courier, enter the total, method, reference, date | 2.5h | UI | S4-11 |
| S4-18 | Record payout step 2: order selection list (oldest first, prefilled), live "expected vs received, difference" bar, auto-allocate button | 5h | UI | S4-07, S4-17 |
| S4-19 | Record payout step 3: difference handling sheet (allocate per order / dispute / write off); manual per-order amounts | 4h | UI | S4-18 |
| S4-20 | Payout detail screen (allocations, reference, reverse action with reason) + payouts list per courier | 3.5h | UI | S4-12 |
| S4-21 | Disputed list and resolve flow | 2h | UI | S4-13 |
| S4-22 | Seeder v4: realistic payouts, shortfalls, disputes for 90 days | 1.5h | OPS | S4-11 |

### Tests
- `CodStatusResolver` truth table; ledger math with itemized deductions.
- Reconciler scenarios: zero difference; shortfall -> allocate / dispute / write off; overpayment; partial settlement across two payouts; lump-sum auto-allocation across 15 orders.
- Property tests (random orders and payouts; fixed seeds) for all invariants.
- Reversal round trip restores the exact prior state.
- Perf: payout of 100 orders saves under 1 s.
- Widget: difference bar math; cannot save with an unresolved shortfall.

### Exit checklist
- [ ] Spec F6 AC1 to AC5 pass as automated tests
- [ ] Property tests green on 1,000+ random cases
- [ ] Dashboard-style pending total equals the sum of order outstanding per courier
- [ ] Reversal restores state precisely
- [ ] Manual walkthrough with a real courier statement succeeds

---

## Sprint 5: Returns & Profit (2 weeks)

**Goal:** Full and partial returns with losses and stock effects; true profit per order with Provisional/Final/Incomplete labels. Spec: F7, F8.

### Tasks

| ID | Task | Est | Tags | Needs |
|---|---|---|---|---|
| S5-01 | Tables: `return_records`, `return_lines`; migration 4->5 and test | 2.5h | DB | S4-01 |
| S5-02 | `ReturnLossCalculator`: `non-resellable cost + non-recoverable fees`; full vs partial; tests | 3h | D | S4-05 |
| S5-03 | `ProfitCalculator` per spec F8 (§8.1, §8.2): revenue, COGS, delivery fee, COD fee, packaging, other costs, return/write-off adjustments; outcome table (delivered, partial return, full return, cancelled) | 6h | D | S4-06, S5-02 |
| S5-04 | Profit state resolver: `incomplete` (null cost) / `provisional` (unsettled or expected fees) / `final` | 2h | D | S5-03 |
| S5-05 | **Profit scenario suite**: the 15 spec scenarios (section 16) as named tests, plus edge cases (discounts, advance, rounding) | 5h | QA | S5-03 |
| S5-06 | `InitiateReturn` use case (full/partial, reason, lines, auto-start on Delivery Failed per setting) | 3.5h | APP | S5-01, S3-02 |
| S5-07 | `ReceiveReturn` use case: received-back date guard, condition per line, loss amount, stock restore (resellable) or loss record, COD adjustment for partial returns (reduces collected, recomputes the ledger) | 5h | APP | S5-06, S4-10 |
| S5-08 | Stock service (when enabled): decrement on Handed to Courier, restore on resellable return, allow negative with a warning; tests | 3.5h | APP | S1-09, S3-02 |
| S5-09 | Profit refresh pipeline: recompute and cache `profit`/`profit_state` in the same transaction as any money/status change; "repair derived fields" extended to profit | 3h | APP | S5-04, S4-02 |
| S5-10 | Return flow UI: initiate sheet (type, reason, lines, qty), full-return shortcut from Delivery Failed | 4.5h | UI | S5-06 |
| S5-11 | Receive-back UI: date, per-line condition, loss preview, stock-restore preview | 4h | UI | S5-07 |
| S5-12 | Returns list: In transit / Received / Not received (aging flag past the threshold) | 3.5h | UI | S5-06 |
| S5-13 | Order detail: **Profit breakdown panel** (each line itemized, expected-vs-actual highlight, state label with explanation tooltip) | 4.5h | UI | S5-03 |
| S5-14 | Profit chip in the order list (green/red/grey for incomplete) + privacy toggle ("Hide profit in lists") | 2.5h | UI | S5-09 |
| S5-15 | Customer detail summary card: orders, delivered %, returned %, lifetime revenue and profit | 2.5h | UI | S5-09, S1-15 |
| S5-16 | Product "cost missing" fix-it flow: list of orders with incomplete profit and a quick cost entry | 2.5h | UI | S5-04 |
| S5-17 | Seeder v5: returns (full/partial, damaged/resellable) over the 90-day dataset | 1.5h | OPS | S5-07 |

### Tests
- Profit scenarios (all 15) plus: cost missing -> incomplete; settled with a different actual fee -> final value changes; partial return recalculates revenue and COGS for the kept lines only.
- Stock: restore only for resellable; negative stock warning.
- Return guards: received-back before initiated is rejected.
- Consistency: `sum(order.profit)` equals the aggregate query (feeds S6).
- Widget: breakdown panel lines match the calculator output.

### Exit checklist
- [ ] All spec F7 and F8 acceptance criteria automated and passing
- [ ] Full return shows negative profit equal to the non-recoverable costs
- [ ] Incomplete/Provisional/Final labels correct on seeded data
- [ ] Profit privacy toggle hides figures in lists

---

## Sprint 6: Dashboard, Search & Reports (2 weeks)

**Goal:** Fast, traceable insight: dashboard with drill-down, full-text search, saved views, and the first five reports. Spec: F9, F10.

### Tasks

| ID | Task | Est | Tags | Needs |
|---|---|---|---|---|
| S6-01 | FTS5 virtual table `search_index` + sync triggers (order no, customer name, phone, CN, product names, notes); migration 5->6 and test | 4h | DB | S2-01 |
| S6-02 | Search service: tokenization, prefix queries, CN/phone exact-jump rule | 3h | APP | S6-01 |
| S6-03 | Filter model (`OrderFilter`): status, COD status, courier, date ranges (order/dispatch/delivery), channel, payment type, tag, area, profit sign, amount range, has-return; to-SQL builder with tests | 5h | APP | S2-05 |
| S6-04 | Saved views storage (`saved_views`) + default views shipped ("To dispatch today", "Delivered, COD pending > 5 days", "Returns not received", "Loss-making orders") | 3h | APP | S6-03 |
| S6-05 | Aggregate queries (period, by courier/product/channel/customer/area): revenue, final vs provisional profit, margin, delivery success, return rate, average profit | 6h | DB | S5-09 |
| S6-06 | Perf check at 20k orders; add indexes or a `daily_aggregates` table maintained in the write transaction if the dashboard exceeds 1.5 s | 4h | DB | S6-05 |
| S6-07 | Consistency tests: report totals equal the sum of per-order values for the same filter (spec F8 AC4); dashboard tiles equal drill-down list totals (F9 AC1) | 3h | QA | S6-05 |
| S6-08 | Home dashboard: cash tiles, ops tiles, performance tiles, period switcher; every tile tappable | 6h | UI | S6-05 |
| S6-09 | Drill-down screens: tile -> filtered order list with a matching total header | 3h | UI | S6-08, S6-03 |
| S6-10 | Orders list: search bar, filter sheet, active-filter chips, sort options, filter persistence across back navigation | 5h | UI | S6-02, S6-03 |
| S6-11 | Saved views UI (pinned on home, create from the current filter, rename, delete) | 3h | UI | S6-04 |
| S6-12 | Reports framework: report picker, date presets, shared header, table + chart pair (`fl_chart`) | 4h | UI | S6-05 |
| S6-13 | Reports: Daily summary, COD ageing, Courier performance (avg delivery days, payout lag, return %, fees, shortfalls) | 6h | UI | S6-12 |
| S6-14 | Reports: Profit report (by period/product/channel/courier/customer; best and worst orders), Returns report (by reason/product/courier) | 5h | UI | S6-12 |
| S6-15 | Seeder v6: scale option to 20k orders for the perf run | 1.5h | OPS | S6-05 |

### Tests
- FTS: partial name, phone suffix, CN exact, Bangla text search.
- Filter builder: combinatorial tests on generated data vs an in-memory reference implementation.
- Aggregates vs brute-force Dart computation on the same dataset.
- Perf at 20k: dashboard < 1.5 s, search < 300 ms, report generation < 2 s.
- Widget: filter chips; drill-down totals match tiles.

### Exit checklist
- [ ] Every dashboard figure drills to a list whose total matches
- [ ] Scanning/pasting a CN into search jumps to the order
- [ ] 20k-order perf budgets met on the reference device
- [ ] Five reports available with table and chart views

---

## Sprint 7: Reminders & Data Safety (2 weeks)

**Goal:** Keep manual data fresh with the follow-up queue and notifications, and keep it safe with export, backup and restore. Spec: F11, F14.

### 7A. Reminders

| ID | Task | Est | Tags | Needs |
|---|---|---|---|---|
| S7-01 | `reminders` table + migration 6->7 and test | 1.5h | DB | S6-01 |
| S7-02 | `NeedsAttentionBuilder` domain: six sources (stale handed-over orders, overdue COD, returns in transit too long, old drafts, disputes, to-dispatch today), priority order, dedupe, snooze/dismiss state; tests with `FakeClock` | 5h | D | S3-08, S4-04 |
| S7-03 | Use cases: snooze (1/3 days), dismiss with reason, resolve-through-action | 2.5h | APP | S7-02 |
| S7-04 | Home "Needs attention" list and the badge count (equal to the queue length, spec F11 AC1) | 4h | UI | S7-02 |
| S7-05 | Quick actions: one-tap Delivered/Failed/Still in transit; call (dialer intent), WhatsApp chat (`wa.me` link, prefilled template), open the tracking link | 4h | UI | S7-04 |
| S7-06 | Message templates: model, defaults in `bn`/`en` (confirmation, dispatch with CN, delivery follow-up), editor, placeholders (`{name}`, `{cn}`, `{amount}`) | 4h | APP | S1-04 |
| S7-07 | Local notifications: daily digest (time, quiet hours, per-type toggles), `workmanager` scheduling, deep link into the queue | 5h | APP | S7-02 |
| S7-08 | Battery-optimization guide (one-time prompt, an OEM-specific link) | 1.5h | UI | S7-07 |

### 7B. Export, backup, import

| ID | Task | Est | Tags | Needs |
|---|---|---|---|---|
| S7-09 | CSV exporters (orders, lines, customers, products, payouts, returns); UTF-8 with BOM; stable column contract documented in `/docs` | 4h | APP | S6-03 |
| S7-10 | PDF: order slip, daily summary, COD ageing, **courier dispute statement** (CN, expected vs received, difference) | 6h | APP | S4-11 |
| S7-11 | Share intents for CSV/PDF (`share_plus`) | 1.5h | UI | S7-09 |
| S7-12 | Backup file format: zip with a DB snapshot (`VACUUM INTO`), attachments, manifest (schema version, counts, checksum); optional passphrase (AES-GCM) | 5h | APP | S0-14 |
| S7-13 | Restore: manifest validation, preview (counts), merge vs replace choice, schema-version handling (migrate on restore), failure-safe (restore into a temp DB, then swap) | 6h | APP | S7-12 |
| S7-14 | Backup reminder (default 7 days) feeding the Needs-attention queue | 1.5h | APP | S7-12, S7-02 |
| S7-15 | Backup/Restore/Export UI in Settings > Data; progress and error states | 3.5h | UI | S7-12, S7-13 |
| S7-16 | CSV import v0 (orders and customers): template download, column mapping, validation preview, duplicate check, all-or-nothing or skip-bad-rows | 6h | APP | S7-09 |

### Tests
- Needs-attention: each source triggers at the threshold and not before; snooze reappearance; badge equals the list count.
- Round trip: export CSV -> import -> identical counts and totals (spec F14 AC1).
- Backup -> wipe -> restore is lossless; restore of a corrupted or old-version file is handled safely.
- Notification scheduling logic (unit-level with a fake scheduler).
- PDF generation smoke tests with `bn` text.

### Exit checklist
- [ ] Daily digest fires on a physical device; the in-app queue works even with notifications disabled
- [ ] Backup and restore round trip verified on two devices
- [ ] Courier dispute statement PDF renders Bangla correctly
- [ ] CSV round trip lossless

---

## Sprint 8: Hardening & Release (2 weeks)

**Goal:** Security, quality, accessibility, onboarding, beta feedback, and the Play Store release.

### Tasks

| ID | Task | Est | Tags | Needs |
|---|---|---|---|---|
| S8-01 | App lock: PIN (salted hash, Argon2id/PBKDF2) + biometric; lock on background timeout; failed-attempt backoff | 5h | APP | S0-05 |
| S8-02 | Privacy toggles: hide amounts on the dashboard until tapped; hide profit everywhere | 2.5h | UI | S5-14 |
| S8-03 | DB encryption per the S0-16 decision (default or opt-in); key in Keystore; migration path from plain to encrypted | 5h | DB | S0-16 |
| S8-04 | "Erase all data": wipe the DB, attachments, secure storage, notifications; confirmation | 2h | APP | S8-03 |
| S8-05 | `allowBackup=false` and data-extraction rules; review the permissions list (minimum set) | 1.5h | OPS | |
| S8-06 | Bangla review with a native speaker: strings, numerals, truncation, mixed-script addresses; fix the findings | 6h | L10N | |
| S8-07 | Accessibility pass: font scale to 200%, TalkBack labels, contrast, touch targets; fix the findings | 5h | UI | |
| S8-08 | Performance profiling on the low-end device (profile mode): scroll jank, startup, dashboard; fix the top 5 issues | 6h | QA | S6-06 |
| S8-09 | Onboarding: language, business profile, first courier, optional sample data; empty-state guidance | 4h | UI | S1-19 |
| S8-10 | Crash reporting (opt-in) and analytics events for the spec §11 metrics, no PII; consent screen | 3.5h | OPS | |
| S8-11 | Integration test suite: create -> dispatch -> deliver -> payout -> report; return flow; backup/restore (all offline) | 5h | QA | |
| S8-12 | Closed beta (5 to 10 sellers): distribute via the Play internal/closed track; feedback form; triage the top issues | 6h | QA | S8-11 |
| S8-13 | Beta fixes and regression pass (budget for ~8 findings) | 8h | UI | S8-12 |
| S8-14 | Store assets: listing text (`bn`/`en`), screenshots, privacy policy, data-safety form | 4h | OPS | |
| S8-15 | Release: signing, versioning, staged rollout (10% -> 50% -> 100%), rollback plan, monitoring checklist | 3h | OPS | S8-13 |

### Tests
- Lock: wrong-PIN backoff, background timeout, biometric fallback.
- Encryption migration: plain -> encrypted retains all data.
- Full integration suite on an emulator and one physical device.
- Accessibility checks at 200% font scale on the 10 key screens.
- Final regression against all spec acceptance criteria (traceability sheet in section 3).

### Exit checklist
- [ ] Beta sellers complete a full cycle (order -> deliver -> reconcile) without help
- [ ] No P0/P1 open bugs; crash-free sessions above 99%
- [ ] All performance budgets met (implementation plan §11)
- [ ] Production build live at 10% rollout with monitoring

---

## 3. Acceptance-Criteria Traceability (Where Each Spec Item Is Verified)

| Spec feature | Sprint(s) | Primary verifying tests |
|---|---|---|
| F1 Order entry | S2 | COD calculator matrix; create/duplicate/delete integration |
| F2 Customers | S1, S5 | Phone normalization; merge; summary card |
| F3 Products | S1, S2, S5 | Snapshot-on-add; cost-missing badge; stock |
| F4 Couriers / CN | S1, S3 | Unique CN; Track URL; stuck policy |
| F5 Status | S3 | State machine; bulk + undo |
| F6 COD & payouts | S4 | Reconciler scenarios; property tests |
| F7 Returns | S5 | Return guards; stock restore; loss calc |
| F8 Profit | S5, S6 | 15-scenario suite; report consistency |
| F9 Dashboard / reports | S6 | Drill-down totals; perf at 20k |
| F10 Search / filters | S2, S6 | FTS; filter builder |
| F11 Reminders | S7 | Queue builder; badge equals the list |
| F14 Export / backup | S7 | CSV round trip; backup/restore |
| F15 Offline | all | Offline integration suite (S8) |
| F16 Settings | S1, S7, S8 | Persistence; lock; erase |

---

## 4. Cross-Sprint Risk Controls

| Risk | Control in the plan |
|---|---|
| Reconciliation or profit bugs | S4-08 property tests and the S5-05 scenario suite are **blocking gates**: later sprints do not start until they pass |
| Slipping into backend/sync work | Locked scope; sync-ready columns only (implementation plan §9) |
| Perf regressions | Seeder scales each sprint; budgets checked at the end of S2, S3, S4, S6 and S8 |
| Schema churn | One migration per sprint with a migration test; never edit a shipped migration |
| Late Bangla issues | `en`/`bn` keys required per task; the native review is in S8, with spot checks in S1 and S4 |
| Manual-entry fatigue | Bulk actions (S3), fast CN entry (S3-17), Needs-attention queue (S7) are scheduled before release; measure update discipline in beta |
| Single-developer bottleneck | Tasks tagged by track so a second developer can take `[UI]` while the first handles `[D]/[DB]` |

---

## 5. Per-Sprint AI Prompt Template

Use at the start of each sprint with Claude Code or Cursor, filling in the bracketed parts.

```
Context: Flutter app "F-Commerce Order & COD Tracker". Read /docs/*.md and the rules file first.
Sprint: [S#: name]. Goal: [one sentence].
Do these tasks in order: [paste the task IDs and descriptions for the sprint].
Constraints:
- Domain layer is pure Dart (no Flutter/Drift imports); money is integer poisha via `Money`.
- Every mutation runs in ONE DB transaction via a use case and writes audit/timeline rows.
- No DateTime.now(); use the injected Clock.
- All user-facing strings in app_en.arb and app_bn.arb.
- For each task: write the failing tests first, then the implementation; keep PRs small (one use case or screen).
- If a bug is found, add a reproducing test before fixing.
Deliver: code + tests, a short summary of what changed, and any decisions needing my input.
Stop after each task group (DB, domain/app, UI) and wait for review.
```

---

## 6. Tracking Template (copy to your tracker)

```
Epic: S# [Sprint name]
  Task: S#-## [title]   Est: __h   Tag: [D|DB|APP|UI|QA|OPS|L10N]   Needs: S#-##
    Acceptance: [from the spec AC or this plan]
    Tests: [list]
    Status: Todo | In progress | In review | Done
    Actual: __h   Notes: __
```

---
*End of document.*
