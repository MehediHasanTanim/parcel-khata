# ADR 004: Helper roles and permissions (S19-S20, F17)

Status: **Policy, client gating, reference-server enforcement and tests implemented.** Needs the real
backend (S16) to become security: the reference server in this repo is the executable spec for it.

## 1. One table

`lib/features/sync/domain/permissions.dart` holds the only permission data:

- `kActions`: capability -> allowed roles -> **probes** (the server writes that implement it).
- `kTableAccess`: table x role -> read / write / hidden fields / write-restrictions / allowed
  status-event targets.
- `RolePolicy` (server) and `can(role, capability)` (client) both read these.

| Capability | Owner | Order taker | Packer |
|---|---|---|---|
| Create / edit / cancel orders | yes | yes | no |
| Customers, products (not cost) | yes | yes | no |
| Enter CN | yes | yes | yes |
| Mark packed / handed over | yes | no | yes |
| Record delivery / collected amount | yes | no | no |
| Cost, profit, courier deductions | yes | no | no |
| Payouts, returns, expenses, campaigns, reports | yes | no | no |
| Settings, helpers, activity log | yes | no | no |

Order taker status events: draft / confirmed / cancelled. Packer: packed / handed_to_courier /
in_transit. Order taker cannot set `cod_collected` or dispute flags; packer may write only
`courier_id, consignment_no, zone, weight_g` on **existing** orders.

## 2. Server-side enforcement (reference server)

- Writes: role, table, field allow-list, default-only fields, status-event targets, shop id.
  Rejected changes return a reason (`forbidden_role`, `forbidden_field:<f>`, `forbidden_status:<s>`,
  `wrong_shop`, `immutable_field:<f>`) and are logged on the device.
- Reads: tables a role may not see are never pulled; hidden fields are stripped from payloads
  (`products.default_cost_price`, `product_variants.cost_price`, `order_lines.unit_cost_price`;
  whole tables `order_charges`, `courier_rate_rules`, payouts, returns, expenses, campaigns).
  A rooted helper phone therefore never holds the owner's margins or courier deductions.
- Hidden fields a helper *writes* (its copy has them empty) are silently ignored, so a helper cannot
  null out the owner's cost.
- **Cost snapshot:** when a role that cannot see cost creates an order line, the server fills
  `unit_cost_price` from the catalog so the owner's margin is complete.
- Invites by phone (`invite` -> one-time code -> `accept`), instant `revoke`: the next push/pull
  throws `RevokedException`; the device runs `wipeShopCache()` (all synced rows, audit log, outbox,
  snapshots) and returns to an empty local-only state; status phase `revoked`.
- Activity log: the server stamps `actor_user_id` + role from the authenticated principal (never the
  payload), the changed fields, and a money flag (`isMoneyAffecting`); `activity(actor, moneyOnly)` is
  owner-only.

## 3. Client

- `currentRoleProvider` / `canProvider(capability)`: **owner when sync is off** (roles are inert for
  local-only use).
- Gated: route guards (`PermissionGate`) for COD, payouts, reports, expenses, campaigns, returns,
  settings, data/import, activity; More menu entries; profit chip in lists; ledger, profit, charges and
  returns panels in order detail.
- Owner screen **Who changed what** (`/settings/activity`): actor + money filters over the audit log
  (every audit row now carries `actor_user_id`). With sync on, `SyncEngine.fetchActivity` returns the
  server's authoritative log.

## 4. Tests

- `test/sync/permissions_test.dart` (51): every capability x role replayed as real server writes and
  compared with `can()`; read-side matrix (cost/charges/payouts/expenses visibility); negative tests
  (forbidden fields, packer cannot create orders, status targets, payout reversal, cross-shop, hidden
  field writes ignored, revoked cut-off, invite misuse, activity attribution).
- `test/sync/helper_e2e_test.dart` (7): two real databases + server: helper device holds no cost,
  deductions or payouts; helper order gets cost from the server and the owner's profit is complete;
  forbidden direct SQL writes on the helper device are rejected and cannot change money; revoke wipes
  the helper's data on next sync while the owner keeps everything; packer enters CN and hands over but
  cannot deliver; activity log attribution and money flags; local-only owner has every capability.

## 5. Gaps and decisions

1. **No backend yet**, so none of this is a security boundary today: it is the spec and the tests a
   real RLS/function implementation must pass (same probes, same expected outcomes).
2. **Expected courier charges** for helper-created orders are computed from rate rules the helper
   cannot read, so those orders arrive without expected charges; the owner device should (re)compute
   them on receipt (not built).
3. **Other screens** (dashboard money tiles, reports shortcuts on Home, COD tab badge, search facets
   for profit) are not all role-aware yet; the data they read is simply absent for helpers, but the
   widgets should be hidden deliberately.
4. **Helper device identity:** `accept` here returns a principal; real flow needs OTP login, token
   storage in the Keystore and server-side token revocation.
5. **"Who changed what" without sync** shows the local audit log; entity-level money flags there are
   a client heuristic, while the server's flag is authoritative.
6. Roles beyond the three (manager, accountant) are not defined; add rows to the same tables.
