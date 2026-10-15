# Post-MVP Implementation Plan (v1.1 and v2)

**Version:** 0.1 (draft)
**Date:** 2026-10-15
**Companions:** `fcommerce-order-cod-tracker-feature-spec.md` (F12, F13, F17, §13, §14), `fcommerce-order-cod-tracker-implementation-plan.md` (§9 sync-ready design), `docs/design/...sprint-plan.md`
**Starting point:** MVP v1.0 is built (Sprints 0 to 8): local-first Flutter app, Drift schema v7, 292 passing tests, release APK builds, performance budgets verified on a real device at 20k orders.

---

## 1. Reconciling the Roadmap with What Already Exists

Several roadmap items were partly delivered during MVP. This plan only schedules the remainder.

| Roadmap item | Already in v1.0 | Remaining work |
|---|---|---|
| CSV import | Customers + orders import with column mapping, preview, duplicate skip, all-or-nothing (S7-16) | Products import, payouts/opening-balance import, saved mappings, Excel (.xlsx) input, import history/undo |
| Drive backup | Manual encrypted backup file + share sheet; backup reminder | Optional automatic Drive backup (`appDataFolder`), scheduled, restore from Drive |
| Courier statement import | CN-keyed `statementRows` data and dispute PDF export | Parsing courier portal sheets, matching, auto-allocation (v2) |
| Sync-ready data model | UUID v7 ids, `row_version`, `updated_at`, soft deletes, append-only events/audit, payout reversals instead of edits | Tombstone propagation, change feed, server |
| iOS | Flutter project has an `ios/` folder; no iOS-specific work | Everything platform-specific (see §6.4) |
| Helper roles | Single-seller app; profit-privacy toggle and app lock | Accounts, roles, permission enforcement, activity log |

Items with **no** prior work: customer risk flags (F12), expenses and ad allocation (F13), exchange flow, barcode scan, paste-to-parse.

---

## 2. Guiding Decisions

1. **Ship v1.1 entirely on-device.** Nothing in v1.1 needs a server; v1.1 can ship before any backend exists.
2. **v2 starts with a backend spike, not features.** Accounts + sync is the riskiest piece; everything else in v2 either depends on it (helpers) or is independent (iOS, statement import, paste-to-parse) and can run in parallel.
3. **Local database stays the source of truth.** Sync is an add-on; the app must remain fully usable offline and for sellers who never create an account.
4. **Money events are immutable.** Payouts, allocations, write-offs and returns already sync as append-only events with reversals. Never introduce edit-in-place on financial rows.
5. **Privacy posture is a feature.** Customer data is private to the seller; risk flags use only the seller's own history; paste-to-parse defaults to on-device processing.
6. **Keep money math in the pure domain layer** with scenario tests before UI (the rule that caught the return-fee bug).

---

## 3. Release Overview

| Release | Theme | Sprints | Duration |
|---|---|---|---|
| **v1.1** | Smarter decisions and fewer taps | S9 to S12 | ~8 weeks |
| **v1.5** (optional) | Statement import + paste-to-parse (no server) | S13 to S14 | ~4 weeks |
| **v2.0** | Accounts, sync, helpers, iOS | S15 to S22 | ~16 weeks |

Estimates assume one developer with AI tooling (~25 productive h/week), two-week sprints. Add ~15% buffer.

Order rationale: statement import and paste-to-parse are high-value, server-free wins for the biggest manual-entry pains, so they are pulled forward into **v1.5** rather than waiting for v2. Sync, helpers and iOS then form v2.0.

---

## 4. v1.1: On-Device Features

### 4.1 S9: Expenses & Ad Allocation (F13)

**Goal:** true business profit, with marketing cost reflected in per-order profit.

**Data model (migration 7 -> 8)**
- `expenses(id, shop_id, date, category, amount, note, campaign_id NULL, ...)`
- `campaigns(id, shop_id, name, start, end, spend, allocation_mode, ...)`
- `order_tags` as a real table (today `tags_json`) so campaigns can target orders by tag: `order_tag_links(order_id, tag)` plus index.
- `order_charges.type` gains `ad_allocation` (source `campaign`).

**Domain (pure, test first)**
- `AdAllocator.allocate(campaign, orders, mode)`: modes `byCount` (equal share per order) and `byRevenue` (proportional to kept revenue). Remainder poisha assigned deterministically (largest-remainder) so shares always sum exactly to spend.
- `BusinessPnl.compute(orderProfits, expenses, period)`: `net order profit - unallocated expenses = business profit`.
- Profit calculator already has an `other` cost bucket: add `CostKind.adAllocation` so it shows separately and is excluded from courier deductions.

**Application**
- Expense CRUD, categories (Ads, Packaging purchase, Rent, Salary, Misc), recurring monthly expense (optional).
- Campaign CRUD; "Allocate" is idempotent: re-running replaces the campaign's prior `ad_allocation` charges inside one transaction and refreshes profit via `LedgerWriter.refresh` for each touched order.
- Settings: default packaging cost already exists; expose "apply to new orders".

**UI**
- Expenses list + add (amount keypad, category chips, date, optional campaign).
- Campaign screen: spend, tagged orders count, allocation preview (table), Apply.
- Monthly P&L report (new): revenue, COGS, courier fees, returns loss, ads, other expenses, business profit.
- Order profit panel: new "Ad cost" line.

**Tests / exit**
- Property test: allocated shares always sum to campaign spend; re-allocation is idempotent; removing a tag/campaign restores profit exactly.
- Monthly P&L total equals sum of order profits minus expenses for the same period (extends the existing no-drift invariant).

### 4.2 S10: Customer Risk Flags (F12)

**Goal:** warn before taking a risky COD order, using only the seller's own history.

**Domain**
- `CustomerRiskScorer`: inputs = per-customer counts (orders, delivered, returned/refused, fake-order reasons, last outcome, days since last order). Output = list of explainable `RiskBadge` (`reliable`, `refusedLastCod`, `highReturnRate`, `newCustomer`, `blocklisted`) with the order ids that caused each. No opaque score.
- Threshold config (return rate %, min orders) in settings.

**Data**
- `customers.risk_note`, `customers.is_blocklisted`, `customers.blocklist_reason` (migration).
- Badges are derived, not stored (recomputed from orders; cached only if profiling demands).

**UI**
- Badges on customer card/list; tap a badge to see the orders behind it (transparency rule from F12).
- Order form: non-blocking banner when the selected customer is risky, with one-tap "take advance" (switches payment to Advance + COD and focuses the advance field).
- Manual caution/blocklist with note.

**Privacy:** seller-private; never shared. If v2 sync is added, flags sync only within the same shop.

**Tests:** scorer truth table (boundaries: min-orders, rate threshold, refusal recency); banner appears/disappears; blocklist survives customer merge (merge must union flags).

### 4.3 S11: Exchange Flow

**Goal:** record "wrong size, send replacement" as one linked flow with correct money.

**Model**
- `return_records.exchange_order_id NULL` plus `orders.exchange_of_order_id NULL` (migration).
- A replacement is a normal order with `payment_type=prepaid` or COD of the *difference*; the original is returned (partial or full) as today.

**Domain (pure, scenario tests first)**
- `ExchangeCalculator`: given returned lines value, replacement lines value, delivery charges, and who pays the courier: outputs the replacement order's COD (difference, floor 0), refund/credit if replacement is cheaper, and the cost attribution (return fee + new delivery fee as business loss unless customer pays).
- Profit rule: the pair is reported together (`ExchangeGroupProfit`) and individually; sum of both = group profit.

**Application / UI**
- From a delivered order: "Exchange" -> pick returned lines -> pick replacement items -> preview money -> creates return record (initiated) + linked confirmed order in one transaction.
- Timeline on both orders cross-links; list shows an exchange chip.
- Stock: returned resellable restores, replacement decrements on handover (existing hooks).

**Tests:** 8+ scenarios (same price, higher/lower price, customer pays courier, damaged return, replacement cancelled); group profit invariant.

### 4.4 S12: Barcode Scan, CSV Import v2, Drive Backup, Polish

**Barcode/QR scan for CN**
- `mobile_scanner` (on-device only). Entry points: CN field in courier sheet and fast-CN screen, plus search bar (scan -> existing exact-jump).
- Camera permission requested on first use only; no network. Handle torch, permission-denied fallback to manual entry.
- Optional per-courier CN regex (already stored) validates the scan; mismatch warns, never blocks.
- Tests: pure `CnNormalizer` (trim, strip prefixes/spaces/check chars), widget test with a fake scanner stream.

**CSV import v2**
- Products import (name, sku, prices, stock); payouts opening-balance import so existing COD owed can be loaded.
- `.xlsx` input via `excel` package (read-only), converted to the same row model.
- Saved column mappings per file signature (header hash); import history list with "undo import" using a batch id column (`import_batch_id` on created rows, soft-delete by batch).

**Drive backup (optional)**
- `googleapis` + Google Sign-In scoped to `drive.appdata` only (no access to the user's other files). Upload the existing encrypted `.pkb`; list/restore through the same `BackupService` preview/merge/replace path.
- Schedule via `workmanager` (weekly, Wi-Fi + charging); failure surfaces in Needs-attention (reuses backup reminder).
- Privacy review: file is already passphrase-encrypted; recommend encryption on by default when Drive is enabled.

**Polish / release**
- Migration tests 7 -> 8 -> 9 with fixture DBs; update Play data-safety (Drive scope, camera).
- Beta with the same 5 to 10 sellers; measure risk-banner usage and expense entry.

### 4.5 v1.1 Exit Checklist
- [ ] Business P&L reconciles to order profits and expenses in tests
- [ ] Risk flags are explainable and never block saving an order
- [ ] Exchange pair profit invariant holds across 8+ scenarios
- [ ] Barcode scan works offline; denied-permission path usable
- [ ] Import v2 round trip lossless; undo import restores prior counts
- [ ] Drive backup restores on a second device via the existing restore flow
- [ ] All new strings in `bn` + `en`, parity tests green, performance budgets re-run at 20k orders

---

## 5. v1.5: Server-Free Wins (Statement Import & Paste-to-Parse)

### 5.1 S13: Courier Statement Import

**Goal:** reconcile a payout in seconds from the courier's portal export, with no courier API.

**Pipeline**
1. **Parse:** CSV/XLSX -> rows (reuse CSV + `excel` readers). Per-courier **parser profiles** (column names for CN, COD amount, delivery fee, COD fee, return fee, status/date, net payable) stored as data, user-editable, with presets for common couriers that ship as *templates only* (names/columns, no rates), consistent with the earlier courier-preset decision.
2. **Match:** by CN (normalized) within the courier. Outcomes per row: `matched`, `unknownCn`, `duplicateInFile`, `amountMismatch` (collected differs from expected COD), `alreadySettled`.
3. **Review:** table with filters per outcome; the seller fixes or excludes rows.
4. **Apply:** writes actual charges (`setActualCharge`), optional collected-amount adjustment (reason required), and builds a `RecordPayoutInput` through the existing `PayoutReconciler` plan (so shortfall policy, overpayment and audit rules are unchanged).

**Domain (pure, test first)**
- `StatementMatcher`: deterministic matching and mismatch classification with tolerance (poisha).
- `StatementPlanBuilder`: turns matched rows into `ReconcileOrder` + allocations + actual-fee updates; property tests assert it can never allocate more than outstanding without the explicit overpayment flag.
- Guard rails: nothing is written until the final confirm; whole import runs in one transaction; re-importing the same file is detected by a content hash and offered as "already applied".

**UI:** Record payout -> "Import statement" -> pick file -> profile (or create) -> review -> confirm. Dispute PDF can be generated straight from mismatches.

**Risks:** inconsistent portal formats (mitigated by editable profiles + sample fixtures), CN formatting (leading zeros, prefixes), partial deliveries (surfaced as `amountMismatch`).

### 5.2 S14: Paste-to-Parse Order Entry

**Goal:** paste a customer's chat message and get a pre-filled order form.

**Approach (progressive, privacy-first)**
1. **Rule-based on-device parser** (ships first): extracts phone (existing `PhoneNormalizer`, Bangla digits), name candidates, address block, product mentions matched against the seller's catalog (fuzzy, Bangla/English), quantities, price hints. Output = `ParsedOrderDraft` with a per-field confidence.
2. **Optional LLM assist (opt-in, v1.5 stretch):** a user-visible toggle; sends only the pasted text, never the customer database; scrub nothing the user didn't paste; show exactly what will be sent; allow bring-your-own key or an app proxy. Off by default; clearly disclosed in the privacy policy and data-safety form.

**UX**
- Paste box (also via Android share-target from WhatsApp text) -> editable draft -> matches highlighted (green high confidence, amber needs check) -> **Create order** goes through the normal form so every validation (customer duplicate, cost missing) still applies.
- Never auto-saves; seller always confirms.

**Domain (pure, test first):** parser against a fixture corpus of 100+ real-looking Bangla/English/mixed messages with expected fields; precision/recall targets recorded; regression suite grows with every reported mis-parse.

**Exit:** median time to create order from paste measured vs manual (target 40% faster); parser never overwrites an existing customer without confirmation.

---

## 6. v2: Accounts, Sync, Helpers, iOS

### 6.1 S15: Backend Spike & Architecture Decision (1 sprint, decision gate)

Decide and prove before building features. Candidates:

| Option | Pros | Cons |
|---|---|---|
| **Supabase** (Postgres + Auth + RLS + Realtime) | Fast to build, row-level security maps to roles, managed | Vendor lock-in, per-field LWW needs custom logic |
| **Django REST + Postgres** (the earlier candidate) | Full control, familiar | You operate it; slower to first value |
| **Firebase** | Offline SDK | Data model mismatch with relational ledger |

**Recommendation to validate:** Supabase (or Django) with a **custom sync protocol on top of Postgres**, not the vendor's offline SDK. Our model is relational with money invariants; we already have UUID v7, `row_version`, soft deletes and append-only events.

Spike deliverables (written decision record `docs/decisions/002-sync-backend.md`):
- Auth via **phone OTP** (matches how sellers identify; needs SMS provider cost estimate for Bangladesh).
- Prototype `pull(since)` / `push(batch)` for 3 tables incl. one money event, with a simulated two-device conflict.
- Cost model per active seller per month; data residency note; backup/restore of server data.

### 6.2 S16 to S18: Accounts & Sync

**Protocol**
- Every synced table gets: `server_version` (monotonic, assigned by server), `device_id`, existing `row_version/updated_at/deleted_at`.
- **Change feed:** `pull(since_server_version)` returns changed rows and tombstones; `push(batch)` is idempotent via client-generated op ids.
- **Conflict policy (documented, tested):**
  - Masters (customers, products, couriers, settings): last-write-wins **per field** using hybrid logical clocks; conflicts written to a visible conflict log.
  - Orders: LWW per field except status; status changes are **events** (append-only), and the order's status is derived from the event log so concurrent updates merge instead of overwrite.
  - **Money entities (payouts, allocations, write-offs, returns, collected-amount edits): immutable events only.** Corrections are reversals. Server rejects any update to an existing money row.
- **Order numbers:** device-scoped ranges (e.g. server leases blocks of 100) or `{device_code}-{n}` so offline devices never collide; existing `order_number` unique index becomes `(shop_id, device_code, order_number)`.
- **Attachments:** content-addressed blobs uploaded lazily; metadata syncs first.

**Client architecture**
- `SyncingRepository` decorators over existing repository interfaces (as planned in §9 of the base plan); an outbox table (`sync_outbox`: op id, entity, payload, state) written in the **same transaction** as the mutation (reuses the single write-path rule).
- Sync engine: foreground + background (`workmanager`), exponential backoff, visible state **Synced / Pending / Error** (spec F15), never blocks entry.
- Migration of existing users: first sign-in uploads the local database as an initial snapshot (single device = trivial); a second device downloads. Provide "this is my existing data" vs "replace with cloud" choice with a preview (reuse backup preview UI).

**Security**
- TLS only; per-shop row-level security; tokens in Keystore; server-side encryption at rest; data export and delete-account endpoints (Play requirement).
- Update privacy policy + data-safety from "data never leaves device" to describe the opt-in account; keep local-only mode fully supported.

**Testing**
- Deterministic multi-device simulator in Dart (N virtual devices, scripted offline/online, shuffled delivery) with property tests: convergence, no lost money events, ledger invariants hold on every device after sync.
- Chaos tests: duplicate pushes, out-of-order pulls, clock skew (HLC), partial failure mid-batch.

### 6.3 S19 to S20: Helper Roles & Permissions (F17)

- **Roles:** Owner (all), Order-taker (create/edit orders, customers, products; no profit, payouts or settings), Packer (dispatch queue, enter CN, mark packed/handed over).
- **Invites:** owner invites by phone; helper joins the shop, gets a role; owner can revoke instantly (server revokes tokens; device wipes the shop cache on next sync).
- **Enforcement is server-side** (RLS/policies per role). The client also hides what a role cannot use, but hiding is UX, never security.
- **Field-level masking:** helpers' payloads omit cost, profit and courier deductions (server-computed projection), so a rooted helper phone never holds the owner's margins.
- **Activity log:** every synced mutation records `actor_user_id`; Owner screen "Who changed what" with filters; money-affecting actions flagged.
- **Local-only owners** can still use the app with no helpers; roles are inert without an account.
- Tests: permission matrix (role x action) generated from one table and asserted on both client gating and server policies; negative tests that attempt forbidden writes directly.

### 6.4 S21: iOS

Run in parallel with S15 to S20 (independent track, one developer-week of platform hardening per sprint).

- **Build & plugins:** verify every plugin on iOS (`sqlite3`, `flutter_secure_storage`, `local_auth` FaceID usage string, `flutter_local_notifications` permissions, `share_plus`, `file_picker`, `mobile_scanner` camera string, `url_launcher` with `LSApplicationQueriesSchemes` for `whatsapp`, `tel`). Add `Info.plist` strings and entitlements.
- **Platform differences:**
  - Local notifications: exact scheduling and permission prompt model differ; daily digest uses iOS calendar triggers; no battery-guide dialog on iOS.
  - Backup path: no `allowBackup` equivalent; set `NSURLIsExcludedFromBackupKey` on the DB and attachments (opt-in iCloud backup via the encrypted `.pkb` only).
  - PDF fonts/share sheet and Files integration.
  - Secure storage uses Keychain; define accessibility class so the lock survives reboot correctly.
- **Distribution:** Apple Developer account, App Store privacy nutrition label (mirror the Play data-safety doc), TestFlight beta.
- **CI:** macOS runner job for `flutter build ipa --no-codesign`; golden tests run on both platforms.
- Exit: full integration test suite and perf test pass on a real iPhone; no `dart:io` Android-path assumptions remain (path provider abstraction already isolates this).

### 6.5 S22: v2 Hardening & Release

- Migration of existing v1.x installs (with and without accounts), staged rollout 10% -> 50% -> 100%.
- Load test of sync endpoints with 1,000 simulated shops x 20k orders; payload size budgets for initial sync (stream in pages, resume on failure).
- Disaster recovery drill: restore server from backup; verify devices re-converge.
- Final security review (RLS policies, token handling, helper revocation), privacy docs, support runbook.

---

## 7. Cross-Cutting Work

| Area | Plan |
|---|---|
| **Migrations** | One migration per sprint with fixture-DB migration tests; never edit shipped steps. v1.1 expects schema 8 to 9; v2 adds sync columns and outbox in a dedicated migration released *before* the sync client so the schema can bake. |
| **Localization** | Every sprint adds `bn`/`en` strings; parity test remains a CI gate; Bangla review per release (checklist in `docs/release/bangla-review.md`). |
| **Docs/policy** | Update `privacy-policy.md` and `data-safety.md` whenever data leaves the device (Drive S12, LLM S14, accounts S16). |
| **Telemetry** | Extend the allow-list for new events (e.g. `statement_imported`, `paste_parsed`, `sync_completed`) keeping the no-PII rule and consent gate. |
| **Performance** | Re-run `integration_test/perf_test.dart` at the end of each sprint; new aggregates must meet the same budgets; add `daily_aggregates` only if a budget is missed. |
| **Accessibility** | 200% font and 48 dp checks on every new screen (existing widget test pattern). |

---

## 8. Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Sync corrupts or duplicates financial data | Med | **Critical** | Immutable money events, server rejects edits, multi-device simulator with ledger invariants in CI, staged rollout, local snapshot before first sync |
| Backend cost/operations burden for a small team | Med | High | Managed backend first, spike with cost model, keep local-only mode free |
| OTP SMS cost/deliverability in Bangladesh | Med | Med | Cost estimate in spike; alternative email/Google sign-in; rate limits |
| Courier statement formats vary and change | High | Med | Editable parser profiles as data, fixture library, mismatches never auto-applied |
| Paste-to-parse mis-parses and erodes trust | Med | Med | Confidence UI, always editable, never auto-save, regression corpus |
| LLM assist raises privacy concerns | Med | High | Off by default, explicit disclosure, only pasted text sent, on-device path always available |
| Role leakage (helper sees margins) | Low | High | Server-side projections and RLS, permission matrix tests |
| iOS plugin/permission surprises | Med | Med | Early iOS build in S15 to S16, TestFlight beta |
| Scope creep from sellers' requests | High | Med | Keep this roadmap locked per release; log requests in §10 |

---

## 9. Dependencies and Sequencing

```
S9 Expenses ─┐
S10 Risk     ├─> v1.1 (no server) ──> S13 Statement ─┐
S11 Exchange │                         S14 Paste     ├─> v1.5
S12 Scan/Import/Drive ─┘                              │
                                                      v
S15 Backend spike ─> S16-18 Accounts+Sync ─> S19-20 Helpers ─> S22 v2.0
S21 iOS (parallel from S15) ───────────────────────────────────┘
```

- S10 (risk flags) must precede helper roles so flag visibility can be part of the permission matrix.
- S13 depends on S12's import framework (xlsx reader, mapping store).
- Helpers (S19) require sync (S18); iOS (S21) does not.

---

## 10. Open Questions

1. **Backend choice** (Supabase vs Django vs other) and hosting region/data residency requirement.
2. **Identity:** phone OTP only, or also Google sign-in? Who pays for SMS?
3. **Monetization:** are accounts/sync/helpers a paid tier? This decides what must work without an account and the entitlement model (`entitlements` hook reserved in settings).
4. **Multiple shops/brands per account:** `shop_id` already exists everywhere; do we expose multi-shop in v2 or keep single shop?
5. **LLM assist:** is any cloud LLM acceptable for the target users, or on-device parsing only?
6. **Statement import scope:** which couriers' exports must be supported first (drives the preset templates)?
7. **Exchange accounting:** who bears the return and re-delivery fee by default; is it configurable per courier/order?
8. **Retention:** server-side retention and deletion policy for helpers' removed shops and for deleted accounts.

---

## 11. Definition of Done (per feature)

- Domain logic pure, covered by scenario/property tests written first; money invariants hold
- Works offline; sync-enabled features degrade gracefully with no account
- `en` + `bn` strings; empty/loading/error states; a11y checks at 200% font
- Audit/timeline entries for money- or status-affecting actions; reversals, not edits
- Migration + migration test; privacy/data-safety docs updated if data flow changed
- Performance budgets re-verified on the reference device at 20k orders
- Acceptance criteria and changelog entry recorded

---

## 12. Immediate Next Steps

1. Confirm release split (v1.1, v1.5, v2) and open questions #1 to #3.
2. Cut a `v1.0` tag; start S9 with the `AdAllocator` and `BusinessPnl` domain tests.
3. In parallel, start the S15 backend spike branch (cost model + OTP provider quote) since it needs lead time.
4. Recruit 3 to 5 sellers who run ads for S9/S10 validation and 2 who work with a helper for S19 requirements.

*End of document.*
