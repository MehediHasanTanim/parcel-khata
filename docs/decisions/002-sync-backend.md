# ADR 002: Sync backend and protocol (S15 spike)

Status: **Proposed, pending your decision gate.** Date: 2026-10-15.
Scope: the decision record for v2 accounts + sync + helper roles. No production code was written;
the spike code is `lib/features/sync/domain/sync_protocol.dart` with
`test/domain/sync_protocol_test.dart`.

## 1. Recommendation

**Supabase (managed Postgres + Auth + RLS) with our own sync protocol implemented as two Postgres
functions** (`sync_push(batch)`, `sync_pull(since, limit)`), not the vendor's offline/realtime SDK.
Django REST + Postgres is the fallback if Supabase fails the open checks in section 7; the protocol
below is backend-agnostic (it only needs Postgres, a bigserial sequence, and per-request row
authorization), so the choice is cheap to reverse before S16.

Why not Firebase: its document model and offline SDK conflict with a relational ledger whose
invariants (outstanding, payout allocations) are computed across rows. Why not the vendor SDK on
Supabase: no per-field conflict control, and money rows need insert-once / monotonic rules.

## 2. What the spike proved (and did not)

Proved, in a pure-Dart in-memory model of the protocol (3 simulated devices, one server):

| Question | Result | Test |
|---|---|---|
| `pull(since)` / `push(batch)` shape works for customers, orders, payouts (+ allocations) | yes, incremental + paginated | `basic replication` |
| Push is idempotent under a lost ack | yes (`deviceId + changeId`) | `push is idempotent` |
| Concurrent edits to different fields | both survive (per-field LWW) | `different fields…` |
| Concurrent edits to the same field | later HLC wins on all replicas and the server; exact tie broken by node id | `same field…`, `exact tie…` |
| A device with a wrong clock | still orders after what it has seen (HLC receive rule) | `slow clock…` |
| Delete vs concurrent edit | delete is a field; no silent resurrection of the row | `soft delete…` |
| Two devices record a payout for the same parcel | both rows kept; **over-allocation detected, flagged, not auto-fixed**; explicit reversal then converges | `two devices pay…` |
| Reversal vs concurrent re-activation | reversed wins (monotonic status) | `reversal wins…` |
| Rewriting a money amount after the fact | rejected (insert-once, earliest writer wins) | `an amount cannot…` |
| Derived columns (profit, outstanding, net_receivable, cod_status) | never leave the device; recomputed locally by `LedgerWriter.refresh` | `derived … never synced` |
| Role / tenant isolation | helper cannot push payouts; cross-shop write rejected, cross-shop pull empty | `authorization` |
| Convergence under random order | 150 runs x 3 devices x 40 steps, random skew, lost acks, page sizes: all replicas equal the server | `property: …` |

The property test found a real flaw during the spike (insert-once fields depended on arrival order);
the rule is now "lowest HLC wins", which is commutative.

**Not proved (needs S16 or a live backend):** real Postgres/RLS behaviour and performance, the
`sync_push` function under concurrent transactions, phone OTP end to end, background-sync battery
cost, and migration of an existing on-device database into a synced one. Nothing was run against
Supabase or any SMS provider.

## 3. Protocol (as prototyped)

- **Identity of changes:** client `changeId` (UUID v7) + `deviceId` -> idempotent push.
- **Order:** hybrid logical clock per field `(wallMs, counter, nodeId)`; clamp/reject stamps more than
  a day ahead of server time (open item, otherwise one bad clock poisons a field forever).
- **Pull:** server assigns a monotonic `server_seq` per accepted row change; `pull(since)` returns
  full merged row snapshots with per-field HLCs, oldest first, with a cursor + `hasMore`. Clients merge
  with the same function the server uses, so merge is commutative/associative/idempotent.
- **Table policies:**
  - `lww` (customers, order editable fields): per-field last-writer-wins.
  - `appendOnly` (payouts, payout_allocations, charges, status events, audit): insert-once rows; only
    declared monotonic fields (payout `status: active -> reversed`) may change afterwards.
- **Not synced:** `net_receivable, outstanding, profit, profit_state, gross_collected, cod_status`
  and other rebuildable caches; each device recomputes after merge. This keeps money invariants a
  local, tested computation instead of a replicated value.
- **Authorization:** every row has `shop_id`; role gates which tables a principal may push.

## 4. Conflicts that LWW cannot fully resolve (design obligations for S16)

1. **Over-allocation** (two payouts, one parcel): surfaced as "needs review" (the existing
   overpayment/dispute concepts), resolved by an explicit reversal. Never auto-corrected.
2. **Field groups:** per-field LWW can combine `status = delivered` from one device with
   `courier_id`/`cod_collected` from another. Proposal: treat `status + delivered_at + cod_collected +
   courier_id + consignment_no` as one atomic LWW group (stamped together, merged together).
3. **Order numbers:** `order_number` is unique per shop; two offline devices will collide. Use a
   per-device number block or assign the display number at first sync (local temporary number).
4. **Stock:** `stock_qty` is a counter, not a register: sync it as signed deltas (append-only
   stock movements), not LWW.
5. **Status machine:** the server cannot fully validate transitions; conflicting status moves are
   resolved by group LWW and logged to the timeline.

## 5. Authentication: phone OTP

Sellers identify by mobile number, so phone OTP matches. Supabase Auth supports phone OTP with
built-in providers and a custom "send SMS" hook, which lets a Bangladeshi gateway be used.

SMS cost (inputs are third-party reports found during the spike; **verify before budgeting**):

| Route | Reported price per SMS | Notes |
|---|---|---|
| Local bulk gateways (BulkSMSBD-class) | about BDT 0.5-2 (~US$0.005-0.02) | bulk/promotional routes; OTP/transactional may need a registered sender ID and differ in price/reliability |
| Twilio (list price, third-party tracker) | reported ~US$0.60 | looks like an outlier; Verify has its own fee; confirm on Twilio's page |
| Message Central OTP API | reported ~US$0.59 | unit unclear |

Regulatory note (third-party summary, verify with BTRC): bulk SMS has a minimum price floor and
transactional OTP may be sent in English.

Planning assumption: ~2 OTPs per seller per month (new device / re-login). At local rates that is
~US$0.01-0.04 per seller-month; at the Twilio figure it would be ~US$1.2, i.e. it would dominate
every other cost. **Decision input needed:** pick a local gateway or an OTP aggregator with a local
route before committing. Fallbacks that cost nothing per login: Google sign-in (already used for
Drive backup) or email magic link; WhatsApp OTP is another option to price.

## 6. Cost model (per active seller per month)

Measured: a delivered order with 2 lines costs **~3.0 KB** in the local SQLite file (300 orders ->
901 KB, including indexes, FTS, status events, audit). Planning figure on Postgres: 4 KB/order.

Assumptions: median seller 300 orders/month (heavy: 1,500), 1.5 devices/seller, 3 years of data
retained, Supabase Pro ($25/org/month, 100k MAU, 8 GB DB, 250 GB egress, then $0.125/GB DB;
figures from supabase.com/pricing and third-party guides, mid-2026), compute $10 (micro, credited)
to ~$60-200/month depending on size (**unverified**), local SMS gateway at US$0.015.

| Active sellers | Data (3 yr) | Platform + compute | Storage overage | SMS (2 OTP/mo) | Total / month | Per seller |
|---|---|---|---|---|---|---|
| 1,000 | ~43 GB | $25 + ~$15 | ~$4 | ~$30 | ~$75 | ~$0.07 |
| 10,000 | ~430 GB | $25 + ~$60 | ~$53 | ~$300 | ~$440 | ~$0.04 |
| 50,000 | ~2.2 TB | $25 + ~$200 | ~$265 | ~$1,500 | ~$2,000 | ~$0.04 |

Egress is far below the 250 GB included (a sync is a few KB; ~3 MB per device-month). Not included:
PITR/backup add-ons, error tracking, engineer time, taxes. Even at 10x the order volume the
infrastructure is well under US$0.25 per seller-month, so pricing risk is SMS routing, not hosting.

## 7. Data residency, backup, restore

- **Residency:** choose the Supabase region closest to Bangladesh (Singapore is the nearest
  commonly listed; **verify availability**). Customer phone numbers/addresses are personal data:
  disclose server storage in the privacy policy and Play data-safety form (today's answer, "nothing
  leaves the device", stops being true once sync is on). Bangladesh data-protection rules are in
  flux: get a legal read before launch.
- **Server backup:** Pro includes daily backups (7 days). Add a nightly `pg_dump` to separate object
  storage in another account, and run a **restore drill** before beta (restore into a scratch project,
  run the row-count + ledger invariants from `BackupService` counts). The local `.pkb` / Drive backup
  keeps working and remains the seller-controlled copy.
- **Offboarding:** per-shop export (existing CSV/`.pkb`) and per-shop hard delete function.

## 8. Postgres sketch (not executed)

```sql
-- every synced table: shop_id, server_seq, per-field clocks
create table orders (
  id uuid primary key, shop_id uuid not null,
  data jsonb not null,                 -- merged field values
  clocks jsonb not null,               -- field -> hlc string
  server_seq bigint generated always as identity,   -- bump on change via trigger
  deleted_at timestamptz
);
alter table orders enable row level security;
create policy shop_isolation on orders
  using (shop_id = (auth.jwt() ->> 'shop_id')::uuid);
-- helpers: no write policy on payouts / payout_allocations
-- sync_push(batch jsonb): idempotency table (device_id, change_id), per-field merge in SQL
-- sync_pull(since bigint, lim int): where server_seq > since and shop_id = jwt shop order by server_seq
```

## 9. Open checks before this becomes "Accepted"

1. Prototype `sync_push` as a real Postgres function; measure p95 for a 200-change batch.
2. Verify RLS for owner / manager / helper with real JWTs (helper cannot read profit, cost price,
   payouts if that is the product decision).
3. Price and test one local OTP route; measure delivery rate to the major operators.
4. Confirm the nearest region and data-protection obligations.
5. Spike the migration: stamp existing rows with a genesis HLC and run an initial upload on a 20k-order
   database (the performance fixture) on a mid-range phone.
6. Decide the atomic field groups (section 4.2) and the order-number scheme (4.3).

## 10. Decision

Proceed to S16 with Supabase + custom protocol **if** checks 1-3 pass; otherwise switch to Django +
Postgres using the same protocol and the same client code.

Sources used for prices (verify before budgeting): supabase.com/pricing; sent.dm Bangladesh SMS pricing;
textbee.dev Twilio SMS pricing table; messagecentral.com OTP pricing.
