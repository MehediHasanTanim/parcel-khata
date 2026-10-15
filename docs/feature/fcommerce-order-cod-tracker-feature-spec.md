# F-Commerce Order & COD Tracker: Detailed Feature Spec

**Version:** 0.1 (draft)
**Date:** 2026-10-13
**Status:** For review

---

## 1. Overview

### 1.1 Problem
Sellers on Facebook pages, Instagram and WhatsApp take orders in chat, send parcels by courier, and collect cash on delivery (COD). Their records live in chat threads, notebooks, and scattered spreadsheets. As a result they cannot answer basic questions:

- Which parcels are still out with the courier?
- How much COD cash has the courier collected but not yet paid to me?
- Which orders were returned, and what did each return cost me?
- Did I actually make money on this order after courier fees, returns, and ad spend?

### 1.2 Product
A mobile-first order and COD tracker. The seller records every order, tracks it through delivery, reconciles COD money against courier payouts, handles returns, and sees real profit per order.

### 1.3 Key constraint: manual entry only
There is **no courier API integration**. Every status change, consignment number, and payout is entered by the seller. The whole product must therefore be designed around **fast, low-friction manual entry**:

- Few taps per order. Smart defaults. Reusable customers, products and couriers.
- Bulk actions for the most repetitive jobs (mark many orders delivered, reconcile a payout).
- Never lose data: offline-capable entry, drafts, undo.
- Gentle reminders so stale statuses don't silently rot.

### 1.3.1 Non-goals (v1)
- No courier API, tracking-page scraping, or auto status sync.
- No payment gateway, online payments, or bKash/Nagad integration (payments tracked as records only).
- No storefront, catalog publishing, or customer-facing UI.
- No chat inbox integration (Facebook/WhatsApp message import). Optional paste-to-parse is a later idea (see section 14).
- No multi-user team permissions in v1 (single seller account; see section 14).

---

## 2. Target Users

| Persona | Description | Needs |
|---|---|---|
| **Solo seller** (primary) | Runs a Facebook page or WhatsApp business from a phone. 5 to 50 orders a day. | Speed, simplicity, clear cash picture |
| **Seller with a helper** (later) | Owner plus one packer or order-taker | Shared access, limited permissions |

**Context assumptions:** Android-first, mid-range phones, patchy connectivity, one-handed use, currency is BDT (Taka) by default. Bangla and English UI should both be considered (see section 12).

---

## 3. Core Concepts & Glossary

| Term | Meaning |
|---|---|
| **Order** | A sale to one customer, with one or more line items, one delivery address, one courier shipment |
| **Consignment (CN) number** | The tracking ID the courier gives for a parcel; entered manually |
| **COD amount** | Cash the courier must collect from the customer on delivery |
| **COD collected** | The courier has delivered and collected cash (customer paid the courier) |
| **COD received / settled** | The courier has paid that cash to the seller |
| **COD pending** | Cash that is expected but not yet settled to the seller |
| **Return** | Parcel not accepted or not delivered and sent back (full or partial) |
| **Payout (settlement)** | A single payment from a courier to the seller covering many orders, minus the courier's deductions |
| **Net profit** | Revenue actually earned minus all costs attributable to the order |

---

## 4. Order Lifecycle & Statuses

### 4.1 Order status (fulfilment)

```
Draft -> Confirmed -> Packed -> Handed to Courier -> In Transit -> Delivered
                 \                         \              \-> Delivery Failed -> Return in Transit -> Returned
                  \-> Cancelled             \-> Cancelled (before pickup)
```

| Status | Meaning | Typical trigger |
|---|---|---|
| Draft | Incomplete entry, saved for later | Seller starts an order and leaves |
| Confirmed | Customer agreed, details complete | Seller saves order |
| Packed | Ready for pickup (optional step; can be disabled in settings) | Seller taps Packed |
| Handed to Courier | Courier has the parcel; CN number recorded | Seller enters CN number |
| In Transit | Optional intermediate state | Manual |
| Delivered | Customer received parcel | Seller marks delivered |
| Delivery Failed | Customer refused, unreachable, wrong address | Seller marks failed (with reason) |
| Return in Transit | Parcel on its way back | Seller marks |
| Returned | Parcel received back by seller | Seller marks received |
| Cancelled | Order cancelled before dispatch | Seller cancels (with reason) |

Rules:
- Only valid forward transitions are offered in the UI by default. "Fix status" is available through an explicit **Correct status** action that is logged in the order history.
- Every status change is timestamped and stored in an immutable **order timeline**.
- Optional steps (Packed, In Transit) can be hidden in settings so simple sellers see a shorter flow: Confirmed -> Handed to Courier -> Delivered / Failed.

### 4.2 Payment (COD) status
This is tracked **separately** from order status, because "delivered" does not mean "paid to me".

| COD status | Meaning |
|---|---|
| Not Applicable | Prepaid order (no COD) |
| Pending Collection | Order not yet delivered; COD expected |
| Collected by Courier | Delivered, courier holds the cash, seller not yet paid |
| Settled | Courier paid the seller (fully) |
| Partially Settled | Courier paid part (short pay or partial delivery) |
| Not Collected | Delivery failed or returned; no cash exists |
| Disputed | Settled amount differs from expected and is under follow-up |

Derived rule: when an order moves to **Delivered** and `cod_amount > 0`, COD status auto-moves to **Collected by Courier**. When it moves to **Delivery Failed / Returned / Cancelled**, COD status auto-moves to **Not Collected** (unless partial delivery, see 8).

---

## 5. Feature List (Summary)

| ID | Feature | Phase |
|---|---|---|
| F1 | Order entry (create / edit / duplicate) | MVP |
| F2 | Customer directory & address book | MVP |
| F3 | Product / item catalog (lightweight) | MVP |
| F4 | Courier management & consignment tracking | MVP |
| F5 | Order status management & timeline | MVP |
| F6 | COD tracking & courier payout reconciliation | MVP |
| F7 | Returns management | MVP |
| F8 | Profit per order | MVP |
| F9 | Dashboard & reports | MVP |
| F10 | Search, filters & saved views | MVP |
| F11 | Reminders & follow-up queue | MVP |
| F12 | Customer risk / history flags | v1.1 |
| F13 | Expenses (ads, packaging, misc.) | v1.1 |
| F14 | Export, backup & import | MVP (basic) |
| F15 | Offline mode & sync | MVP |
| F16 | Settings & preferences | MVP |
| F17 | Helper accounts & permissions | v2 |

---

## 6. Detailed Feature Specs

### F1. Order Entry

**Goal:** Record a new order in under 30 seconds for a returning customer.

**User stories**
- As a seller, I can create an order by picking or adding a customer, adding items, and entering delivery charge and COD amount.
- As a seller, I can save an incomplete order as a draft.
- As a seller, I can duplicate a previous order for a repeat customer.
- As a seller, I can note which channel the order came from (Facebook, WhatsApp, Instagram, Phone, Other).

**Fields**

| Field | Type | Required | Notes |
|---|---|---|---|
| Order number | Auto | Yes | Sequential, human-friendly (e.g. `ORD-0001`); prefix configurable |
| Order date | Date/time | Yes | Defaults to now; editable (for back-entry) |
| Source channel | Enum | Yes | Facebook / WhatsApp / Instagram / Phone / Walk-in / Other. Remembers last used |
| Source reference | Text | No | Chat name, page post ID, or note |
| Customer | Link | Yes | See F2 |
| Delivery address | Text + structured | Yes | Defaults from customer; editable per order |
| Items | List | Yes (1+) | Product (or free text), quantity, unit sell price, unit cost |
| Item discount | Amount/% | No | Per line |
| Order discount | Amount/% | No | Whole-order |
| Delivery charge charged to customer | Amount | No | Default from settings or courier/zone rule |
| Payment type | Enum | Yes | COD / Prepaid / Partial advance |
| Advance received | Amount | No | For partial advance; record the method (bKash, Nagad, bank, cash) as text |
| **COD amount** | Amount | Auto | `= items total - discounts + delivery charge charged - advance received`; **editable override** with a visible "overridden" marker |
| Courier | Link | No at creation | Required before status "Handed to Courier" |
| Consignment number | Text | No at creation | Required before status "Handed to Courier" |
| Expected courier fee | Amount | No | Auto-filled from the courier's rate card (F4); editable |
| Notes (internal) | Text | No | Not shown to anyone else |
| Tags | Multi | No | e.g. "Eid sale", "Live sale" |
| Attachments | Images | No | Chat screenshot proving the order (stored locally and in backup) |

**Behaviour**
- COD amount recalculates live as items, discounts, delivery charge, or advance change, unless manually overridden.
- Stock is not enforced in v1 (see F3 for optional stock count). The seller can always save.
- Draft orders are excluded from all totals and reports.
- Order number is never reused, even after deletion (soft delete only; see rules below).
- Deleting an order is a **soft delete** with an undo window and a "Recently deleted" screen (30 days).

**Acceptance criteria**
- AC1: Creating an order for an existing customer needs at most: pick customer -> add items -> save (3 steps), with defaults filled.
- AC2: COD amount equals the formula above; overriding shows an indicator and a reset-to-calculated control.
- AC3: An order cannot move to "Handed to Courier" without a courier and a CN number (the UI prompts for both inline).
- AC4: Drafts auto-save on leaving the screen and appear in a "Drafts" list.
- AC5: Editing a delivered order's items or prices requires confirmation and writes an entry to the order timeline.

**Edge cases**
- Price or quantity edited after the parcel is handed over: show a warning, because COD expected from the courier may now differ from what the courier was told.
- Duplicate CN number across orders: block with a message that links to the existing order (CN numbers must be unique per courier).
- Zero COD amount (fully prepaid) is allowed; payment type switches to Prepaid.

---

### F2. Customer Directory & Address Book

**Goal:** Never retype an address; know who is a repeat or risky buyer.

**Fields:** Name, primary phone (unique key), alternate phone, WhatsApp number (if different), saved addresses (label, full text, district/area), notes, tags, created date.

**User stories**
- I can search a customer by name or phone while creating an order.
- I can keep several addresses per customer and choose one per order.
- I can open a customer to see all past orders, totals, return count, and COD outcomes.
- I can merge duplicate customers (same person, two numbers).

**Behaviour**
- Phone number is normalized (country code, spaces, dashes) and used for duplicate detection. A new customer with an existing number prompts "Use existing customer?".
- Customer summary card shows: total orders, delivered %, returned %, lifetime revenue, lifetime profit, last order date.
- Address field supports free text first; optional structured fields (district, thana/area) to enable zone-based delivery charge defaults and area-wise reports.

**Acceptance criteria**
- AC1: Searching by any 4+ consecutive phone digits or name fragment returns matches within 300 ms for 10,000 customers.
- AC2: Merging two customers moves all orders and addresses to the surviving record and logs the merge.
- AC3: A customer with active (non-final) orders cannot be hard-deleted; archive only.

---

### F3. Product / Item Catalog (Lightweight)

**Goal:** Remember prices and costs so profit is accurate without re-typing.

**Fields:** Name, SKU/code (optional), default sell price, **default cost price (purchase cost)**, variants (size/color as simple labels), photo (optional), active flag, optional stock quantity.

**Behaviour**
- Adding an order line from the catalog snapshots sell price and cost **onto the order line**. Later catalog price changes never alter old orders (profit history stays accurate).
- Free-text items are allowed (no catalog entry); the cost price is then entered on the line, and a "save to catalog" shortcut is offered.
- Optional stock tracking (toggle in settings): stock decrements when an order is Handed to Courier, restores when a return is received back (see F7). Negative stock is allowed with a warning.

**Acceptance criteria**
- AC1: Changing a product's cost does not change profit on existing orders.
- AC2: Cost price missing on a line shows a visible "cost missing" badge, and the order's profit is flagged as **incomplete** rather than showing a misleading number.

---

### F4. Courier Management & Consignment Tracking

**Goal:** Record which courier has which parcel, and what that courier charges.

**Courier setup**

| Field | Notes |
|---|---|
| Name | Prebuilt suggestions (Pathao, Steadfast, RedX, eCourier, Paperfly, Sundarban, SA Paribahan, Other) plus custom |
| Contact number | Hub or pickup-person number |
| Rate card | Fee by zone (inside Dhaka / Dhaka suburb / outside Dhaka / custom) and optionally by weight band |
| COD fee rule | Percent of COD collected (e.g. 1%) and/or flat amount; "Free under X" optional |
| Return fee rule | Flat, percent of delivery fee, or none |
| Payout cycle (expected) | e.g. "within 3 days of delivery", "weekly Thursday"; drives reminders in F11 |
| Tracking link template | URL with a `{cn}` placeholder, so one tap opens the courier's own tracking page in the browser |

**Per-order courier data:** courier, consignment number, handover date/time, parcel weight (optional), expected delivery fee, expected COD fee, expected return fee (if applicable), pickup method (courier pickup / dropped at hub).

**Behaviour**
- On entering a CN number, the **Track** button opens the courier's public tracking page (via the link template) so the seller can check the status and copy it back manually. Because there is no API, the app never claims the live status; it shows "Last updated by you: 2 days ago".
- Expected fees are computed from the rate card, but the seller can override per order (the real fee often differs). Actual fee recorded at settlement (F6) overrides the expected fee for profit.
- **Stale parcel indicator:** orders in "Handed to Courier / In Transit" for more than N days (default 3, configurable per courier) show an amber flag; more than 2N shows red.
- CN number validation is soft (per-courier optional regex); a mismatch warns but does not block.
- Optional **bulk CN entry**: paste a list of `order# CN` pairs, or step through unassigned orders with a fast keypad flow.
- Optional **scan CN barcode** with the camera to fill the CN field (on-device only, no network).

**Acceptance criteria**
- AC1: The CN number is unique per courier; duplicates are blocked with a link to the conflicting order.
- AC2: The Track link opens the correct URL after template substitution.
- AC3: A courier's expected fees are applied automatically on assignment and can be edited.
- AC4: The stale-parcel threshold is configurable and drives a filter ("Stuck parcels").

---

### F5. Order Status Management & Timeline

**User stories**
- I can change an order's status with one tap from the order card or list swipe action.
- I can select multiple orders and mark them Handed to Courier / Delivered / Failed in bulk.
- I can see the full history of every change on an order.

**Behaviour**
- Each status change records: from -> to, timestamp (editable for back-dating), optional note, and (for Failed or Cancelled) a **reason** from a list: Customer refused / Not reachable / Wrong address / Customer cancelled / Out of stock / Courier issue / Other.
- Back-dating is allowed (the seller often updates later than the event). Dates cannot be in the future.
- Bulk Delivered: select orders, confirm, and COD for each moves to Collected by Courier. A summary toast shows the totals ("12 orders, ৳18,450 COD now with courier") with an Undo option.
- Order timeline view shows status changes, edits (field, old -> new), COD events, return events, and notes, in order.

**Acceptance criteria**
- AC1: Bulk status changes complete for 100 orders in under 2 seconds locally.
- AC2: Every status change appears in the timeline with the timestamp and the previous value.
- AC3: Failed or Cancelled requires a reason (the default selectable in one tap).

---

### F6. COD Tracking & Courier Payout Reconciliation

This is the core of the product. The seller must always know exactly where the cash is.

#### 6.1 Per-order COD ledger
Each COD order has these money fields:

| Field | Meaning |
|---|---|
| Expected COD | Amount the courier should collect |
| Collected amount | What the courier actually collected (defaults to expected; editable for short-collection or partial acceptance) |
| Courier deductions | Delivery fee + COD fee + return fee + other deductions, as itemized lines |
| Net receivable | `Collected - deductions` |
| Settled amount | Cash actually received from the courier for this order |
| Outstanding | `Net receivable - Settled amount` |

#### 6.2 Payout (settlement) recording
A **payout** represents one payment from a courier (a bank, bKash, or cash-in-hand transfer) covering many orders.

**Fields:** Courier, payout date, payment method, reference number, **total amount received**, notes, and a list of linked orders with the amount allocated to each.

**Reconciliation flow**
1. The seller taps **Record payout** and picks the courier.
2. The app lists that courier's orders with an outstanding balance (oldest first), pre-selected if Delivered.
3. The seller enters the total received and ticks the orders included. The app shows `sum of expected net receivables` vs `received` and the **difference**.
4. If the difference is zero, confirm. Each included order becomes **Settled**.
5. If there is a difference, the seller either:
   - **Allocates per order** (edits individual settled amounts to match the courier's statement), or
   - **Marks a shortfall** as Disputed (kept as outstanding with a note), or
   - **Writes off** (accepts the loss; recorded as an adjustment cost on the affected orders).
6. Confirm to save. A payout can be edited or reversed with a logged reason.

**Rules**
- A payout cannot allocate more than an order's outstanding balance without an explicit "overpayment" adjustment.
- A payout may cover orders for only one courier.
- Every settled amount ties to exactly one payout (full audit trail: order -> payout -> date and reference).
- Partial settlements are supported (an order may appear in multiple payouts until its outstanding is zero).

#### 6.3 COD views
- **COD Pending (with courier):** Delivered orders not yet settled, grouped by courier, with age in days since delivery and an overdue flag against the courier's expected payout cycle.
- **COD to be collected:** Orders in transit whose COD is not yet collected (forecast).
- **Disputed:** Orders with a shortfall or mismatch under follow-up.
- Totals shown at the top: `Pending with courier`, `In transit COD`, `Disputed`, `Settled this month`.

**Acceptance criteria**
- AC1: The sum of all order outstanding balances for a courier equals the courier's "pending" total on the dashboard, always.
- AC2: Recording a payout with a zero difference settles all selected orders in one confirmation.
- AC3: A payout with a shortfall requires choosing how to handle the difference (allocate / dispute / write off) before it can be saved.
- AC4: Reversing a payout restores the affected orders' outstanding balances and logs the reversal.
- AC5: Overdue flag appears when `today - delivery date > courier payout cycle`.

**Edge cases**
- The courier sends a payout in a lump sum with no breakdown: the seller uses the auto-allocate (oldest first) or manual allocation.
- The courier delivers and collects but later reverses (customer disputes): the order can be moved from Collected back to a return flow with the COD collected amount adjusted (see F7).
- Prepaid orders never appear in COD views but still appear in revenue and profit.

---

### F7. Returns Management

**Goal:** Capture what returned, why, what it cost, and whether stock came back.

**Return types**
- **Full return:** the whole parcel returned (refused, unreachable, wrong address).
- **Partial return:** the customer kept some items and returned others; the COD collected is reduced accordingly.
- **Exchange** (optional v1.1): the original is returned and a linked replacement order is created.

**Return record fields**

| Field | Notes |
|---|---|
| Order | Link |
| Return type | Full / Partial |
| Reason | Customer refused / Not reachable / Wrong address / Wrong or damaged item / Size or color issue / Changed mind / Fake order / Other |
| Items returned | Lines and quantities (full return selects all) |
| Return initiated date | When the failure or return began |
| Received-back date | When the parcel physically reached the seller |
| Return fee (courier) | Charged to the seller (itemized in deductions) |
| Return fee (delivery fee lost) | Original delivery fee still charged by the courier |
| Condition of goods | Resellable / Damaged / Lost |
| Loss amount | Auto from costs, editable: `non-resellable cost + non-recoverable fees` |
| Notes / photo | Optional |

**Behaviour**
- Marking an order Delivery Failed starts a **Return in Transit** workflow automatically (can be turned off). The seller later marks **Received back** and records condition.
- **Resellable** returns restore stock (if stock tracking is on). **Damaged** or **Lost** items are recorded as a loss and do not restore stock.
- **Partial return:** COD collected is reduced by the returned items' value (defaults computed, editable), and the order's revenue and cost are re-computed for profit (see F8).
- The order's profit reflects the return cost: the delivery fee and return fee are real expenses even though no sale happened.
- A returns list shows aging: "Return in transit for 9 days" with a flag after a configurable threshold, and a "Not received back" queue to chase the courier.
- Return reason analytics feed the dashboard (F9).

**Acceptance criteria**
- AC1: A full return sets revenue to 0 for the order and profit to `-(non-recoverable costs)`, with a breakdown.
- AC2: A partial return reduces revenue, COD, and cost for returned lines only.
- AC3: Marking goods Resellable restores stock when stock tracking is enabled; Damaged does not.
- AC4: A return cannot be marked Received-back before it is initiated.
- AC5: A returned parcel awaiting receipt longer than the threshold appears in the **Follow-up queue** (F11).

---

### F8. Profit Per Order

**Goal:** Show true profit on each order, not just sale price minus product cost.

#### 8.1 Formula (delivered order)

```
Revenue (product)        = sum(line qty x sell price) - discounts
+ Delivery charge charged to customer
= Gross collected value  (what the customer pays in total)

Costs:
  - Product cost (COGS)            = sum(line qty x unit cost)
  - Courier delivery fee           (actual if settled, else expected)
  - Courier COD fee                (actual if settled, else expected)
  - Packaging cost                 (default per order from settings, editable)
  - Ad cost allocation             (optional; see F13)
  - Other order costs              (manual line items)
  - Return / write-off adjustments (if any)

Net profit = Gross collected value - all costs
Margin %   = Net profit / Gross collected value
```

#### 8.2 Formula by outcome

| Outcome | Revenue | Costs counted | Profit |
|---|---|---|---|
| Delivered, COD settled | Full | COGS + fees + packaging + ad share | Positive or negative; **final** |
| Delivered, COD not yet settled | Full | Same, using expected fees | **Provisional** (labelled) |
| Partially returned | Reduced | COGS of kept items + all fees + loss on returned items | Final when settled |
| Full return | 0 | Delivery fee + return fee + packaging + non-resellable goods | Negative |
| Cancelled before dispatch | 0 | Packaging only if already used (manual) | ~0 |

#### 8.3 Status labels
- **Provisional:** based on expected fees, or the order is not yet settled.
- **Final:** the order is settled, so all actual amounts are known.
- **Incomplete:** a required cost (e.g. the product cost) is missing; a number is not shown as final.

**Behaviour**
- The order detail screen has a **Profit breakdown** panel listing each line above, with a mismatch highlight where actual differs from expected.
- The order list can show a profit chip (green / red) with an option to hide profit in lists (privacy toggle for when the phone is handed to a helper).
- Profit rolls up by day, week, month, courier, product, source channel, and customer.
- Money uses integer minor units (poisha) or fixed-point decimals internally to avoid rounding errors; display in whole Taka by default with an option for 2 decimals.

**Acceptance criteria**
- AC1: Profit for a delivered, settled COD order = collected value - COGS - actual fees - packaging - other costs; verified with unit tests across at least 15 scenarios (including discounts, partial return, full return, advance payment, write-off).
- AC2: Changing the actual courier deductions at settlement updates profit and flips the label to Final.
- AC3: Orders missing costs show **Incomplete** and are excluded from "final profit" totals by default (with a toggle to include).
- AC4: Sum of per-order profits equals the profit shown in reports for the same filter (no drift).

---

### F9. Dashboard & Reports

#### 9.1 Home dashboard (default: current month; switchable)

**Cash tiles**
- COD pending with couriers (by courier)
- COD in transit (forecast)
- Settled this period
- Disputed / overdue amount

**Operations tiles**
- Orders today / this period
- To dispatch (Confirmed but not handed over)
- In transit
- Stuck parcels (over threshold)
- Returns awaiting receipt

**Performance tiles**
- Revenue, Net profit (final) and Provisional profit, Margin %
- Delivery success rate, Return rate
- Average profit per order

#### 9.2 Reports

| Report | Contents |
|---|---|
| **Daily summary** | Orders created, dispatched, delivered, failed; COD collected; payouts received |
| **Courier performance** | Per courier: parcels, delivered %, return %, average delivery days, average payout lag, total fees, shortfalls |
| **COD ageing** | Outstanding COD in buckets: 0-3, 4-7, 8-14, 15+ days since delivery, by courier |
| **Profit report** | By period, product, channel, courier, customer; best and worst orders |
| **Returns report** | Count and cost by reason, product, courier, area; the loss total |
| **Product performance** | Units, revenue, profit, return rate per product |
| **Channel performance** | Facebook vs WhatsApp vs Instagram: orders, delivery rate, profit |
| **Area report** | Orders and return rate by district or area (if address is structured) |
| **Payout statement** | All payouts for a courier in a period, with allocations |

**Behaviour**
- Date range presets (Today, Yesterday, 7d, This month, Last month, Custom).
- Every figure is **tappable** and drills down to the underlying order list (traceability).
- Charts: line (revenue and profit trend), bar (by courier/product), donut (return reasons). Charts must always have tabular equivalents.
- Reports export to CSV and PDF (F14).

**Acceptance criteria**
- AC1: Every dashboard number drills into a list whose total matches the tile.
- AC2: Dashboard loads in under 1.5 s with 20,000 orders on a mid-range device (using indexed queries or cached aggregates).
- AC3: Provisional and final profit are always shown separately or clearly labelled.

---

### F10. Search, Filters & Saved Views

**Search:** by order number, customer name, phone, CN number, product name, note text.

**Filters (combinable):** order status, COD status, courier, date range (order / dispatch / delivery), channel, payment type, tag, area, profit sign (profit/loss), amount range, has-return.

**Saved views (pinned on home):** e.g. *"To dispatch today"*, *"Delivered, COD pending > 5 days"*, *"Returns not received"*, *"Loss-making orders"*. Defaults ship with the app; users can create their own.

**Sort:** newest, oldest, amount, profit, days since dispatch.

**Acceptance criteria**
- AC1: Scanning or pasting a CN into search jumps straight to the matching order.
- AC2: Filters persist while navigating back from an order detail.
- AC3: Search results appear as the user types, within 300 ms locally.

---

### F11. Reminders & Follow-Up Queue

**Goal:** Because status updates are manual, the app actively prompts the seller so that nothing is forgotten.

**Daily queue ("Needs attention")** is a single prioritized list containing:
1. Orders handed to a courier N days ago with no status update ("Did this get delivered?"), with one-tap **Delivered / Failed / Still in transit**.
2. Delivered orders whose COD is overdue against the courier's payout cycle.
3. Returns in transit longer than the threshold.
4. Draft orders older than 24 hours.
5. Disputed settlements awaiting follow-up.
6. Orders to dispatch today (Confirmed, no CN).

**Notifications**
- Optional daily digest at a user-set time (e.g. 9:00 PM): "7 parcels need a status update, ৳23,100 COD overdue".
- Per-type toggles; quiet hours.
- Local notifications only (no server needed in v1).

**Quick actions in queue:** call customer (opens dialer), open WhatsApp chat to the customer's number (prefilled optional message template), open courier tracking link, snooze for 1 / 3 days, dismiss with reason.

**Message templates (optional):** editable text snippets for order confirmation, dispatch notice with the CN number, delivery follow-up, "please be available" call prompts, etc. Opened in WhatsApp or SMS via a share intent (the seller still taps Send; the app never sends messages itself).

**Acceptance criteria**
- AC1: A single "Needs attention" count badge on home equals the number of items in the queue.
- AC2: Snoozed items reappear on the chosen date.
- AC3: Resolving an item from the queue (e.g. marking Delivered) updates the order and removes the item immediately.

---

### F12. Customer Risk / History Flags *(v1.1)*

- Automatic **badges** on the customer card based on the seller's own history: "2 previous returns", "Refused last COD order", "Reliable (5/5 delivered)".
- At order creation, a non-blocking **warning banner** for customers with a high return rate (configurable threshold) and a suggestion to take an advance payment.
- Manual flag: **Blocklist / Caution** with a note. The seller's data is private, with no sharing between sellers.
- Rules are transparent: tap a badge to see the orders that caused it.

---

### F13. Expenses *(v1.1)*

- Record non-order business expenses: ad spend (by campaign or date), packaging purchases, rent, salaries, misc.
- **Ad cost allocation** (optional): spread a campaign's spend across orders tagged with it (by count or by revenue) so per-order profit includes marketing cost. Unallocated spend appears in the monthly P&L.
- Monthly profit and loss summary: `Net order profit - unallocated expenses = business profit`.
- Packaging default cost per order configurable in settings (applies automatically to F8).

---

### F14. Export, Backup & Import

**Export**
- Orders, customers, products, payouts, and returns as CSV (UTF-8 with BOM for Excel).
- Reports as PDF (daily summary, COD ageing, profit, courier statement). A shareable **courier dispute statement** lists the orders, CN numbers, expected and received COD, and the difference, so the seller can send it to the courier.
- Shareable order slip (PDF or image) with the order summary, address, CN number and COD amount; the seller can send it to a helper or courier (no customer branding required in v1).

**Backup & restore**
- Manual backup to a file (shareable to Google Drive, WhatsApp, etc.) and optional automatic cloud backup if accounts are enabled.
- Restore from backup with a preview (counts of orders, customers) and a merge or replace choice.
- Data lives locally first; losing a phone must not mean losing the business (backup reminder if no backup in 7 days).

**Import**
- CSV import of past orders and customers with column mapping, a validation preview, and a duplicate check (by phone and order reference).
- Downloadable CSV template.

**Acceptance criteria**
- AC1: An exported CSV re-imports without loss (round trip test).
- AC2: Import shows row-level errors and never partially applies silently (all or nothing, or an explicit "skip bad rows" choice).
- AC3: The backup reminder triggers after 7 days without a backup (configurable).

---

### F15. Offline Mode & Sync

- All core features (order entry, status updates, payouts, reports) work **fully offline**; the local database is the source of truth.
- If accounts and cloud sync are enabled: background sync with last-write-wins per field, conflict log for same-field edits, and a visible sync state (Synced / Pending / Error).
- Sync must never block entry; failed syncs retry with backoff.
- If sync is not in v1, the app is local-only with F14 backup. The data model must still use stable IDs (UUIDs) so sync can be added later.

---

### F16. Settings & Preferences

| Area | Options |
|---|---|
| Business profile | Business name, phone, logo (for slips), currency (BDT default), timezone |
| Order numbering | Prefix, starting number |
| Workflow | Enable/disable Packed and In Transit steps; auto-start return flow on failed delivery |
| Defaults | Default channel, default delivery charge, default packaging cost, default courier |
| Couriers | Manage couriers, rate cards, fee rules, payout cycles, tracking templates |
| Thresholds | Stuck parcel days, overdue payout days, return-in-transit days |
| Notifications | Daily digest time, toggles per type, quiet hours |
| Stock | Enable stock tracking on or off |
| Privacy | App PIN / biometric lock, hide profit in lists, hide amounts on the dashboard until tapped |
| Language | Bangla / English (see section 12) |
| Data | Backup, restore, export, recently deleted, erase all data |

---

### F17. Helper Accounts & Permissions *(v2)*

- Owner invites a helper (order-taker / packer) by phone.
- Roles: **Owner** (all), **Order-taker** (create/edit orders, no profit or payout visibility), **Packer** (view dispatch queue, enter CN numbers, mark packed and handed over).
- Activity log shows who changed what.
- Requires accounts and sync (F15).

---

## 7. Data Model (Logical)

```
Seller (1) ──< Customer
Seller (1) ──< Product ──< ProductVariant
Seller (1) ──< Courier ──< CourierRateRule
Seller (1) ──< Order
Order (1) ──< OrderLine            (snapshot: name, qty, sell_price, cost_price)
Order (1) ──< OrderStatusEvent     (from, to, at, reason, note)
Order (1) ──< OrderCharge          (type: delivery_fee | cod_fee | return_fee | packaging | other, expected, actual)
Order (1) ──< OrderEditLog
Order (0..1) ──< ReturnRecord ──< ReturnLine
Courier (1) ──< Payout ──< PayoutAllocation >── Order
Seller (1) ──< Expense
Seller (1) ──< Campaign (optional)
```

**Key tables / fields**

**Order**
`id (uuid), order_no, customer_id, address_snapshot, source_channel, source_ref, order_date, status, payment_type, items_total, discount_total, delivery_charge_customer, advance_received, cod_expected, cod_overridden (bool), courier_id, consignment_no, handed_over_at, delivered_at, cod_status, cod_collected, notes, tags, is_deleted, created_at, updated_at`

**OrderCharge**
`id, order_id, type, expected_amount, actual_amount (nullable until settled), source (rate_card | manual | statement)`

**Payout**
`id, courier_id, paid_at, method, reference, total_received, note, status (active | reversed), reversed_reason`

**PayoutAllocation**
`id, payout_id, order_id, amount_applied, deductions_applied, note`

**ReturnRecord**
`id, order_id, type (full | partial), reason, initiated_at, received_back_at, condition, loss_amount, notes`

**Derived (not stored, or cached)**
`order.net_receivable`, `order.outstanding`, `order.profit`, `order.profit_state (provisional | final | incomplete)`

**Integrity rules**
- Money stored as integers (poisha) or decimals; never floats.
- `consignment_no` unique per `(courier_id)` among non-deleted orders.
- `sum(PayoutAllocation.amount_applied) for an order <= net_receivable` unless an overpayment adjustment is recorded.
- Soft deletes everywhere; financial rows are never hard-deleted, only reversed.

---

## 8. Key Business Rules (Consolidated)

1. **COD amount** = items total - discounts + delivery charge charged - advance received (overridable, with a visible marker).
2. **Delivered + COD > 0** -> COD status = Collected by Courier. **Failed / Returned / Cancelled** -> Not Collected (partial delivery excepted).
3. **Settled** requires a payout allocation covering the net receivable; partial coverage -> Partially Settled.
4. **Net receivable** = collected COD - courier deductions (delivery fee, COD fee, return fee, other).
5. **Profit is Final** only when the order is settled (or a prepaid delivered order with confirmed fees) and no cost is missing; otherwise Provisional or Incomplete.
6. **Returns:** fees stay as costs even when there is no sale; resellable goods restore stock; damaged or lost goods are losses.
7. **Catalog price changes never rewrite history**; order lines snapshot price and cost.
8. **CN uniqueness** per courier; a courier and CN are required before Handed to Courier.
9. **Status is manual**; the app prompts and reminds but never assumes a courier state.
10. **Every money-affecting change is logged** (who, when, old -> new).

---

## 9. Screens & Navigation (Mobile)

**Bottom navigation:** Home - Orders - **(+) New order** - COD - More

| Screen | Purpose |
|---|---|
| Home / Dashboard | Cash and ops tiles, Needs attention, saved views |
| Orders list | Search, filters, bulk select, swipe actions |
| Order detail | Summary, status buttons, courier and CN with Track button, COD ledger, profit breakdown, timeline, return section |
| New / Edit order | Customer, items, charges, COD, courier |
| Customers list / detail | History, addresses, flags |
| Products list / detail | Prices, costs, stock |
| COD hub | Pending by courier, ageing, disputed; **Record payout** |
| Payout detail | Allocations, difference handling, reversal |
| Returns | In transit, received, losses |
| Reports | Report picker, filters, export |
| Couriers | Rate cards, rules, payout cycle |
| Settings | See F16 |
| Recently deleted | Restore soft-deleted records |

**Design principles:** thumb-reachable primary actions; large numeric keypad for amounts; sticky COD and profit summary bar on the order form; color plus text and icon (not color alone) for statuses; works at 360 px width.

---

## 10. Non-Functional Requirements

| Category | Requirement |
|---|---|
| **Performance** | Order save under 200 ms locally; lists scroll smoothly with 20k+ orders; dashboard under 1.5 s |
| **Reliability** | No data loss on crash or force-close (transactional writes); drafts autosave |
| **Offline** | 100% of core flows usable offline |
| **Accuracy** | Money math in integers/fixed-point; automated tests for all profit and COD formulas |
| **Security & privacy** | Local DB encrypted at rest where the platform allows; optional PIN/biometric lock; customer data (phones, addresses) is never shared or sold; clear erase-all |
| **Accessibility** | Minimum 16 px body text, 48 dp touch targets, sufficient contrast, screen-reader labels |
| **Localization** | Bangla and English; Bangla numerals optional; BDT formatting (e.g. ৳12,450) |
| **Compatibility** | Android 8+ (primary); iOS and web as later phases |
| **Observability** | Opt-in crash and usage analytics, no customer PII in logs |
| **Data portability** | Full CSV export always available, with no lock-in |

---

## 11. Analytics (Product Metrics)

- Time to create an order (median) - target under 30 s for a returning customer
- Orders created per active day per seller
- % of dispatched orders with a final status within 7 days (manual-update discipline)
- % of delivered COD orders reconciled via a payout within 14 days
- Reminder to action conversion rate
- Weekly active sellers, 30-day retention

---

## 12. Localization & Cultural Notes

- Default UI language selectable at onboarding; **Bangla-first** copy should be considered for the primary audience.
- Address entry should tolerate mixed Bangla/English text; search should be diacritic- and script-tolerant.
- Phone formats: `01XXXXXXXXX` and `+8801XXXXXXXXX` normalize to one canonical form.
- Currency symbol ৳ and Indian-style digit grouping (e.g. 1,25,000) as an option.
- Date format `DD/MM/YYYY`; week starts on a configurable day.

---

## 13. MVP Scope & Phasing

**MVP (v1.0):** F1, F2, F3, F4, F5, F6, F7, F8, F9 (core tiles and 5 key reports), F10, F11, F14 (CSV export and manual backup), F15 (local-first), F16.

**v1.1:** F12 (risk flags), F13 (expenses and ad allocation), exchange flow, courier dispute statement PDF polish, CSV import polish, barcode scan for CN.

**v2:** F17 (helpers and permissions), cloud sync and multi-device, iOS/web, paste-to-parse order import, courier statement import (CSV/Excel from courier portals) to speed up reconciliation.

---

## 14. Future Ideas (Out of Scope Now)

- **Paste-to-parse:** paste a customer's chat message (name, phone, address, items) and auto-fill the order form (on-device or LLM-assisted).
- **Courier statement import:** upload the courier's payout sheet (CSV/Excel) and auto-match by CN number to reconcile in seconds, without needing a courier API.
- Courier API integration where couriers offer it, as an optional enhancement alongside manual entry.
- Inventory purchase orders and supplier tracking.
- Customer-facing order status link or WhatsApp notifications (via the WhatsApp Business API).
- Smart insights ("Courier X has delayed payouts by 6 days on average", "Product Y has a 28% return rate").

---

## 15. Risks & Open Questions

**Risks**
| Risk | Mitigation |
|---|---|
| Sellers stop updating statuses (manual fatigue) | Follow-up queue, one-tap actions, bulk updates, daily digest, minimal required fields |
| Wrong profit numbers erode trust | Provisional / Final / Incomplete labels, visible breakdown, unit-tested formulas |
| Courier fee rules differ by contract and change often | Editable per-order fees; actual fee at settlement always overrides expected |
| Data loss on device loss | Backup reminders, easy export, optional cloud backup |
| Reconciliation is tedious without statements | Fast allocation UI, auto-allocate oldest first, courier statement import later |

**Open questions**
1. Is **local-only** acceptable for v1, or are accounts and cloud sync needed at launch?
2. Which platform first: Android native, Flutter cross-platform, or PWA?
3. Should stock tracking be on by default, or hidden for simplicity?
4. Which couriers' rate-card presets should ship pre-filled (and who maintains them)?
5. Is a **Bangla-only** first release acceptable for the target segment?
6. How should partial-delivery COD adjustments be captured: per line, or a single adjusted amount?
7. Is a monetization model (free tier limits, subscription) defined? It affects the account and sync decisions.
8. Do sellers need **multiple pages/shops** under one account (separate books per brand)?

---

## 16. Glossary of Acceptance Test Scenarios (Starter Set)

1. Prepaid order, delivered: no COD; profit = revenue - COGS - fees - packaging.
2. COD order, delivered, fully settled at the expected amount -> Settled; profit Final.
3. COD order, delivered, courier pays ৳40 less than the statement -> shortfall prompt -> dispute / write-off / allocate.
4. COD order, customer refuses -> Delivery Failed -> Return in Transit -> Received back (resellable) -> stock restored; profit negative by fees.
5. COD order, partial return (2 of 3 items) -> COD collected reduced; revenue and COGS recomputed.
6. One payout covering 15 orders with a lump-sum total -> auto-allocate oldest first -> all Settled.
7. Duplicate CN number on a second order -> blocked with a link to the first.
8. Edit item price after handover -> warning plus timeline entry.
9. Reverse a payout -> orders return to Collected by Courier with the outstanding restored.
10. Catalog cost changes -> old orders' profit unchanged.
11. Missing cost on a line -> profit shows Incomplete and is excluded from final totals.
12. Bulk mark 40 orders Delivered -> COD tiles update; Undo restores all.
13. Overdue payout: delivered 8 days ago with a 5-day cycle -> appears in the Needs attention queue.
14. Offline: create, dispatch, and deliver orders with no network; the data persists after an app restart.
15. Export then re-import CSV -> identical order counts and totals.

---
*End of document.*
