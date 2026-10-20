# Parcel Khata: UI/UX Specification for Claude Design

Version 1.0 · 2026-10-19 · Source of truth: the implemented app (Flutter, Material 3). Every screen,
state and string below exists in the current build; the design goal is to **replace the default
Material look with a considered, consistent, Bangla-first visual language without changing behaviour**.

---

## 0. What to produce

Please deliver, for **phone portrait (primary)**, **light and dark**, **Bangla (default) and English**:

1. A **design system**: color tokens, type scale, spacing, radius, elevation, iconography, motion, and
   a **component library** (section 4), each with all states.
2. **High-fidelity screens** for every screen in section 6 (about 55), including the listed **states**
   (empty, loading, error, offline, populated, edge cases).
3. **Key flow storyboards** (section 7) as connected frames.
4. **Responsive variants**: 320dp narrow, 360-412dp standard, 600dp+ tablet/iPad (section 8).
5. **Accessibility annotations**: 200% text scale, contrast, focus order, screen-reader labels.
6. A short **handoff note** mapping components to Flutter/Material 3 equivalents (we implement in
   Flutter; use Material 3 patterns unless a custom component is justified).

Frame size defaults: **360 x 800 dp** (also provide 412 x 915 and 320 x 640). Design in dp.

Constraints that must survive the redesign are marked **MUST**.

---

## 1. Product context

**Parcel Khata** is a local-first order and cash-on-delivery (COD) tracker for Bangladeshi Facebook /
Instagram / WhatsApp sellers. Sellers take orders in chat, ship with couriers (Pathao, Steadfast, RedX
...), and the courier collects cash and pays the seller days later, minus fees. The app answers:
*what do I owe to ship, what is stuck, who owes me money, and did I actually make profit?*

**Users:** solo sellers and small teams, often one-handed on a mid-range Android phone, intermittent
connectivity, mixed Bangla/English, many not comfortable with spreadsheets or dense fintech UI.
Secondary: a helper (order-taker or packer) with a restricted view.

**Platforms:** Android first, iOS next (Face ID, share sheet, no Android back button).
**Offline-first:** everything works with no network. Ads (small banners) appear only on three safe
screens; accounts/sync are optional and mostly not visible yet.

### Design principles
1. **Cash first.** Money owed and money stuck must be the loudest information on money screens.
2. **One-hand, thirty seconds.** A returning customer's order should take under 30 s. Primary actions
   sit in the lower half; no tiny targets.
3. **Never colour alone.** Every status = colour + icon + text (**MUST**).
4. **Calm, honest numbers.** Estimated/expected values look different from actual ones (dashed/lighter
   + label "expected" or "provisional"). Never show a figure that implies certainty it does not have.
5. **Bangla is the default language,** not a translation. Design for Bangla first (taller line height,
   conjuncts, longer words), then check English.
6. **Forgiving.** Undo for destructive actions, confirmation only for irreversible money actions,
   plain-language errors with a fix ("Fix it" buttons).
7. **Private by default.** Amounts can be masked ("••••") with tap-to-reveal; the lock screen hides
   everything; ad slots never sit near personal or money data.

---

## 2. Visual design system

### 2.1 Brand direction
Trustworthy, warm, unfussy: a **local business ledger** feel (khata = account book), not a neon fintech.
Current seed colour is **green #1B7F5C**; you may propose a refined palette and a wordmark, but keep a
green/teal primary family (association with "paid / done") and keep the **semantic status colours below
distinct from the brand colour**.

### 2.2 Color tokens (define for light and dark; names are suggestions)
| Token | Role | Current light | Current dark |
|---|---|---|---|
| `primary` / `onPrimary` | brand, primary buttons, selected nav | seed #1B7F5C (M3 tonal) | M3 tonal |
| `surface`, `surfaceContainer(Low/High)`, `outline` | backgrounds, cards, dividers | M3 defaults | M3 defaults |
| `success` | delivered, settled, final profit | #1B7F3B | #66D18A |
| `warning` | provisional, pending, attention | #B26A00 | #FFB74D |
| `danger` | returned, disputed, overdue, loss | #C62828 | #FF8A80 |
| `neutral` | draft, not applicable, expected | #5F6368 | #B0B4BA |
| `info` (add) | informational banners, new customer | propose | propose |
| `money-in` / `money-out` (add) | positive / negative amounts in lists | propose | propose |
Rules: text contrast >= 4.5:1, large text/icons >= 3:1 in both themes. Provide **tone containers**
(tinted background + on-colour) for chips and banners. Charts need a colour-blind-safe sequence of 6.

### 2.3 Typography
- Bangla: **Noto Sans Bengali** (or Hind Siliguri); Latin/digits: **Inter** or Roboto. Numerals: allow
  user choice later; default **Latin digits** for money in the UI, Bangla digits in Bangla copy where
  natural (the app accepts both).
- Scale (sp, at 100%): Display 32 (rare), Headline 24, Title Large 20, Title 16 medium, Body 16,
  Body Small 14, Label 12-14, **Money Large 28 bold tabular figures**, Money 16-18 tabular.
- **MUST**: body >= 16sp; support **200% text scale** with no clipped text and no horizontal scroll;
  Bangla line-height >= 1.5 (Latin 1.3).
- Money always uses **tabular numerals**, right-aligned in tables/lists, with the **৳** symbol, thousands
  separators (Bangladesh lakh grouping is optional; propose and mark), 0 or 2 decimals (poisha only when
  non-zero).

### 2.4 Shape, spacing, elevation
- 8dp base grid; page padding 16dp; card padding 12-16dp; list-row min height 56-72dp.
- Radius: cards 12-16, chips full, sheets 28 top, buttons full or 12, inputs 12.
- Elevation: mostly flat with tonal surfaces; sheets/dialogs/FAB elevated. Dark mode uses tonal lift.
- **Touch targets >= 48 x 48dp** (**MUST**), 8dp between adjacent targets.

### 2.5 Iconography & imagery
Material Symbols (rounded, 24dp; 18-20dp inside chips). One metaphor per concept (consistent across the
app): order = receipt, courier = local_shipping, COD = payments, return = assignment_return,
customer = person, product = inventory, payout = account_balance_wallet, dispute = flag,
expected = hourglass, scan = qr_code_scanner. Empty-state illustrations: simple, line-based, one per
major area (orders, customers, products, couriers, payouts, returns, reports, attention-clear).
Photos: only product photos/attachments (square thumbnails, 8dp radius).

### 2.6 Motion
Short (150-250ms), purposeful: sheet slide-up, chip select, list item undo, count-up on dashboard tiles
(optional). Respect "reduce motion". No decorative loops.

### 2.7 Dark mode & themes
Full parity. Status colours use the dark values above. Elevated surfaces lighter, not shadows.
Provide a "high contrast" check of the status chips.

### 2.8 Language & formatting rules (affect layout)
- Every label can be 40-60% longer in Bangla; buttons wrap to two lines rather than truncate; chips may
  grow in height.
- Dates: `15 Oct 2026` / `১৫ অক্টোবর ২০২৬`; relative: "3 days with courier".
- Phone numbers: `01712 345678` grouped, `tel:` tappable; always LTR.
- Long names/addresses: 2-line clamp in lists, full on detail.

---

## 3. Information architecture & navigation

**Bottom navigation (5):** Home · Orders · **(+) New order** (centre action, opens the form, not a tab) ·
COD · More. Selected-state label always visible. The (+) is a raised, brand-coloured action.

```
Home (dashboard) ── Attention queue
Orders ── Filters sheet / Saved views / Selection+bulk bar / Search+scan
   ├─ Order detail ── Status sheet · Courier sheet · Return (initiate/receive) · Exchange · Edit
   ├─ Order form (new/edit/draft)   ├─ Paste order   ├─ Fast CN entry
   ├─ Drafts   ├─ Recently deleted   └─ Missing costs ("Fix it")
COD ── Ageing · Disputed · Payouts history ── Payout detail
   ├─ Record payout (3 steps)  └─ Import courier statement
More ── Customers (list/detail/form/orders)  Products  Couriers  Reports (+6 reports)
   Expenses  Campaigns  Returns  Fix missing costs  Message templates
   Notifications  Security & privacy  Data (backup/restore/Drive/export/import)
   Settings  Who changed what (owner)  Privacy and ad choices  (Debug: hidden)
First run: Onboarding (5 steps).  Always: App lock (PIN/biometric).
```
Role-aware: **helpers** (order-taker / packer) do not see COD, Reports, Expenses, Campaigns, Returns,
Settings, profit/cost anywhere. Hidden entries are removed (not greyed); direct links show a calm
"Your role does not have access to this" page.

---

## 4. Component library (design each with all states)

For every component provide: default, pressed, focused, disabled, loading, error, **Bangla-long**,
**200% text**, light, dark.

1. **App bar**: title, optional leading back, up to 3 actions, optional search field variant, overflow
   menu. Home variant: shop name + attention bell with **badge = exactly the number in the queue**.
2. **Bottom navigation** with centre action (see 3). Badge slot on COD (optional future).
3. **FAB / extended FAB**: "New order", "Record payout", "New customer/product/courier/campaign".
4. **Metric tile** (dashboard & COD summary): icon + label (2 lines max) + value (Money Large) + optional
   sub-label; states: normal, **masked "••••" tap to reveal**, loading skeleton, zero, "—" no data,
   warning accent (stuck), tap ripple to drill-down.
5. **Order list row** (most important component): line 1 `ORD-0042 · Customer name` (+ optional exchange
   chip), chips row (status, COD status, profit chip, "N days with courier" warning), trailing: COD amount
   (title) + date (small). Selected state (check + tint), swipe actions (right = Delivered, left = Handed
   to courier), long-press to select. Draft variant (neutral, "Draft" chip, no money chips).
6. **Status chip**: icon + label, tones success/warning/danger/neutral/info. Full mapping in 4.A.
7. **Profit chip**: amount with sign, state suffix **Final / Provisional (dashed outline) / Incomplete
   ("cost missing", warning, tappable "Fix it")**; hidden when role/privacy setting hides profit.
8. **Risk badge chips** (customer): Reliable (success), Refused last COD (danger), High return rate
   (danger), New customer (info), Blocklisted (danger, block icon). Tap = sheet listing the orders behind
   the badge. **Warning banner** in order form (see screen), with one primary button "Take advance".
9. **Banner / inline message**: info, warning, error, success; with optional action; dismissible.
10. **Section header**: title + optional count + "View all" text button.
11. **Cards**: summary card (customer summary stats), ledger panel, profit panel (cost breakdown rows),
    return card, exchange link card, campaign preview table card.
12. **Key-value row** (label left, value right, bold variant for totals, divider variant).
13. **Money field**: ৳ prefix, numeric keypad, clear button, inline error; supports `%` toggle for
    discounts; "expected" helper text; read-only calculated variant (COD amount) with "override" switch.
14. **Quantity stepper** (− n +), **date field** with picker, **dropdown/select**, **segmented button**
    (Payment: COD / Prepaid / Partial advance), **choice chips** (periods, methods, filters), **filter chips**,
    **switch tiles**, **radio tiles** (shortfall policy), **checkbox row** (include row).
15. **Search bar** with scan icon and clear; behaviours: type to filter, submit = exact jump to order by
    CN/order no.
16. **Bottom sheets**: standard (drag handle, title, content, sticky primary action), full-height picker
    (customer picker, product picker), confirmation sheet. **Dialogs**: confirm, passphrase, text input
    (reason), irreversible money confirm (typed summary of consequences).
17. **Snackbar with Undo** (status change, delete, archive), error snackbar with retry.
18. **Empty state**: illustration + title + one sentence + primary action. **Loading**: skeleton rows (not
    spinners) for lists; linear progress for background work. **Error state**: plain message + Retry.
19. **Timeline**: vertical list of events (icon, text, time), edits shown with "field: old → new".
20. **Table (compact)** for reports/statement review: sticky header, right-aligned numerals, zebra off,
    row = 2 lines on phone; **horizontal scroll never** (collapse columns into rows).
21. **Charts** (fl_chart): line (revenue vs profit), bar (by courier/product), donut (return reasons),
    always with a **tabular equivalent** toggle (**MUST**); palette from 2.2; tap = tooltip.
22. **PIN pad** (custom): 4-6 dots, 3x4 keys 64dp, biometric key, shake on error, lockout timer message.
23. **Ad slot**: 320 x 50 banner, labelled "Advertisement", collapses to 0 height when no ad;
    appears only on Orders list, Reports index, More (see 6.x). Never near buttons.
24. **Permission placeholder** ("Your role does not have access to this").
25. **Status / sync indicator** (future): Synced / Pending / Error pill (design it now; low priority).

### 4.A Status taxonomy (colour + icon + label; design as one table)
| Order status | Tone | Icon idea | Notes |
|---|---|---|---|
| Draft | neutral | edit_note | no money chips |
| Confirmed | info | check_circle_outline | |
| Packed | info | inventory_2 | optional step |
| Handed to courier | warning | local_shipping | adds "N days with courier"; amber at warning days, red at stuck days |
| In transit | warning | directions_bike | optional step |
| Delivered | success | done_all | |
| Delivery failed | danger | error_outline | starts return flow |
| Return in transit | warning | assignment_return | "too long" warning after N days |
| Returned | danger | assignment_return | |
| Cancelled | neutral | cancel | strike-through amount |

| COD status | Tone | Meaning |
|---|---|---|
| Not applicable (prepaid) | hidden | |
| Pending collection | neutral | before delivery |
| Collected by courier | warning | courier holds the cash |
| Partially settled | warning | some paid |
| Settled | success | fully paid out |
| Not collected | danger | |
| Disputed | danger | flagged, with note |

| Profit state | Look |
|---|---|
| Final | solid, success/danger by sign |
| Provisional | dashed outline, "expected" |
| Incomplete | warning, "cost missing" |

Courier "stuck" levels: none · amber (warning days) · red (stuck days).

---

## 5. Global behaviours (apply to every screen)

- **App lock:** if enabled, cold start and resume show the Lock screen; the app-switcher preview is
  blurred/hidden when "hide previews" is on.
- **Hide amounts:** dashboard money tiles show "••••"; tap reveals one tile; profit can be hidden in lists.
- **Undo:** destructive-but-reversible actions show a 5-6 s snackbar with Undo.
- **Offline:** no offline banners needed for core features (all local). Only Drive backup, ads, sync
  show connectivity errors, inline.
- **Dirty-form guard:** leaving a form with unsaved changes asks "Save as draft / Discard / Keep editing".
  Order form autosaves a draft.
- **Pull to refresh** on Home. **Back** returns to the previous screen; the (+) form closes to Orders.
- **Keyboard:** numeric fields use number pad; Enter moves to next field; the last field's action is
  "Save"; forms scroll the focused field above the keyboard.
- **Haptics:** light on status change, success on save, none on scroll.
- **Locale switch** is instant, no restart.
- **Roles:** gated entries are removed; gated routes show the placeholder.

---
## 6. Screens (spec per screen)

Format: **Purpose · Entry · Layout (top to bottom) · Key components · States · Interactions · Notes.**
String keys in `code` map to the appendix for exact English copy.

### 6.1 First run & security

#### S-01 Onboarding (5 steps, one screen with a stepper)
- **Purpose:** get a seller to a usable state in under 2 minutes; every step skippable.
- **Layout:** top progress dots (5) + "Skip"; large illustration per step; headline; short helper text;
  form content; sticky bottom row: Back (text) / Next (filled).
  1. **Welcome + language:** headline `obWelcome`, sub `obWelcomeSub`, segmented **বাংলা | English**
     (Bangla preselected; switching is instant).
  2. **Business:** shop name, phone (optional). Defaults: order prefix, default channel (Facebook).
  3. **Courier:** `obCourier`/`obCourierHelp`: pick preset couriers (names only, no rates) or add custom;
     optional default delivery charge.
  4. **Sample data:** switch tile `obSample` ("load a few sample orders to explore"); reversible.
  5. **Diagnostics consent:** `obTelemetryAsk` + plain-language help; default off; "Finish".
- **States:** each step valid-by-default; Finish shows brief success then lands on Home with an
  empty-state coach mark pointing at (+).
- **Notes:** no account/login anywhere. Tone: friendly, not corporate.

#### S-02 App lock (PIN / biometric)
- **Purpose:** gate the app. **Entry:** cold start/resume when lock is on.
- **Layout:** centred lock icon (48), `lockTitle`, `lockEnterPin`, PIN dots, PIN pad, "Use fingerprint/
  Face ID" key; full-screen, brand background, no app chrome.
- **States:** idle, entering, wrong PIN (shake + message + attempts left), **locked out** (countdown,
  keypad disabled), biometric prompt overlay.
- **Notes:** nothing from the app visible behind it; supports 200% text.

#### S-03 Security & privacy (settings)
- Sections: **App lock** (switch; set/change PIN flow: enter, confirm; biometric switch; auto-lock delay
  select), **Privacy** (hide previews in app switcher, hide amounts on dashboard, hide profit in lists),
  **Diagnostics** (opt-in switch + explanation + "what is sent"), **Erase all data** (danger zone card;
  typed-confirmation dialog; irreversible warning).
- States: PIN not set / set; biometric unavailable (disabled with hint).

### 6.2 Home & attention

#### S-04 Home (dashboard)
- **Purpose:** the daily glance: what needs me now, how is the period.
- **Layout:** app bar (shop name; bell with **count badge = queue length**) → **period chips** (horizontal
  scroll: Today, Yesterday, Last 7 days, This month, Last month, Custom → date-range picker) → **saved-view
  chips** (pinned views, optional) → **Needs attention** header "(n) · View all" + top 3 attention tiles →
  four **sections of metric tiles (2-column grid)**:
  1. *COD:* Pending with courier, In transit COD, Disputed, Settled.
  2. *Operations:* Orders, To dispatch, In transit, **Stuck**, Returns awaiting.
  3. *Money:* Revenue, Profit (final), Profit (provisional), Margin.
  4. *Quality:* Delivery success, Return rate, Avg profit/order.
- **Tile:** icon, label, value; tap → drill-down order list with the same filter (title + measure header).
- **States:** loading (skeleton tiles), zero data (friendly "Take your first order" card with (+)),
  masked amounts, stuck tile warning accent, error with retry. Pull to refresh.
- **Notes:** keep above-the-fold to: period chips, up to 3 attention items, first tile row. Revenue and
  profit tiles show a small "provisional" hint when not final.

#### S-05 Needs attention (queue)
- **Layout:** app bar "Needs attention (n)"; filter chips by kind; list of **attention tiles**: icon by
  kind, title (e.g. "ORD-0042 · 6 days with Pathao"), reason line, primary inline action (Call / Open
  tracking / WhatsApp / Open order / Back up now) and overflow (Snooze 1 day / Dismiss).
- **Kinds (7):** stale handed-over, overdue COD, return taking too long, old draft, dispute, to dispatch,
  backup due. (Missing costs live in their own "Fix it" screen, not this queue.)
- **States:** empty ("All clear" celebratory but quiet), snoozed/dismissed undo snackbar.
- **Notes:** the badge number on Home = list length; WhatsApp action opens a prefilled message the seller
  still sends manually.

### 6.3 Orders

#### S-06 Orders list
- **Purpose:** find and act on orders fast; 20,000+ rows must stay smooth.
- **Layout:** app bar (title, overflow: "Paste order from chat", "Fast CN entry", "Recently deleted") →
  **search field** (placeholder `searchOrders`; scan icon; clear) → optional **active-filter chips**
  (removable, horizontal) + **Filters** button + **Saved views** button + **Sort** dropdown → optional
  **summary line** (count + measure, when coming from a drill-down) → list of **order rows** → **FAB
  extended "New order"** → (ad slot anchored at bottom when ads are on and not selecting).
- **Selection mode:** long-press selects; app bar becomes "n selected" + actions; **bottom action bar**:
  Mark handed to courier / Mark delivered / Cancel / Select all; confirm sheet with count and any
  rows that will be skipped and why.
- **States:** loading skeleton; empty ("No orders yet" + "Take your first order"); empty-filtered ("No
  results" + "Clear filters"); error; drafts excluded unless filter says otherwise.
- **Interactions:** swipe row (see component 5); exact search by CN/order no opens the order directly;
  pagination/infinite scroll with a stable scroll position.

#### S-07 Filters sheet (full-height bottom sheet)
Groups: **Status** (multi chips), **COD status**, **Profit state**, **Courier**, **Channel**, **Payment
type**, **Date ranges** (order date, dispatch, delivered; "delivered more than N days ago"), **Area** text,
**Tag**, **Amount min/max**, **Profit sign** (profit / loss), **Has return**, **Include drafts**. Sticky
footer: "Clear" + "Show N orders" (live count). "Save as view" action (name + pin to Home).

#### S-08 Saved views sheet
List of views (pin icon for Home-pinned default), rename, delete, set default, apply. Empty state explains
how to create one from Filters.

#### S-09 Order form (new / edit / resume draft)
- **Purpose:** create an order in < 30 s. **Entry:** (+) nav, FAB, "Edit" on detail, drafts, paste flow.
- **Layout (single scroll, sticky bottom bar with total + "Save order"):**
  1. *Duplicate/CN conflict banner* when relevant ("View conflicting order").
  2. **Customer** card: name + phone, chevron → customer picker sheet (search, recent, "New customer");
     **risk banner** under it when the customer is risky: icon, `riskBannerTitle`, risk chips (tap =
     explain), caution note, button **Take advance** (switches payment to *Advance + COD* and focuses the
     advance field). Non-blocking.
  3. **Delivery address** (multi-line, "choose saved address" icon).
  4. **Items:** line cards (name, qty stepper, unit price, optional cost, optional discount, remove);
     buttons "Add from catalog" (product picker, variant picker, snapshots price/cost) / "Add free text".
  5. **Payment type** segmented: COD · Prepaid · Partial advance (shows advance amount + method).
  6. **Charges:** delivery charge, order discount (৳ or %), COD amount (**calculated, read-only** with
     breakdown chip; "Override" switch → editable, marked "overridden").
  7. **Shipping (optional):** courier, zone (inside Dhaka / outside / ...), weight, CN (with scan, paste,
     clear).
  8. **Details:** channel, source reference, order date, notes, **tags** (comma-separated, chips preview).
- **Sticky bar:** grand total, COD to collect, profit hint ("expected profit ৳…" or "cost missing"),
  primary "Save order", secondary "Save draft".
- **States:** pristine, dirty (guard on exit), validation errors inline (customer required, items
  required, address required, invalid amount), saving, saved (returns to detail with success snackbar),
  editing a **delivered** order (amber banner + confirm dialog before saving amount changes).
- **Notes:** autosaves a draft; keep line cards compact; keypad-friendly order of fields.

#### S-10 Paste order (from chat)
- **Layout:** large multi-line paste box (hint `pasteHint`), buttons **Paste** / **Read message**,
  progress, then a **review form**: phone (confidence-coloured border + icon: green check = sure, amber
  question = check), existing-customer card ("Existing customer found: name; details are not changed") or
  "New customer" hint with name field, address, **product line cards** (mention, catalog match dropdown,
  qty stepper, price, delete; amber for ambiguous), hints (message total, delivery, advance as switches),
  other numbers/notes list, primary **Create order** (opens the normal form pre-filled).
- **States:** empty paste, nothing recognised (`pasteNothing`), loading, results.
- **Notes:** "Never saves from here" must be visible as helper text (`pasteReview`).

#### S-11 Order detail
- **Purpose:** the single page to understand and act on one order.
- **Layout:** app bar (order no; overflow: Edit, Change status, Assign courier, Correct status (audited), Duplicate order, Share order slip (PDF), Delete) → **header card**
  (customer name + tap-to-call + WhatsApp, address, status chip big, COD status chip, tags, "overridden"
  mark, stuck warning) → **primary action row** (context-sensitive: Assign courier / Mark handed over /
  Mark delivered / Track parcel / Start return) → **Items** list → **Totals** key-values → **Ledger
  panel** (collected, deductions, settled, outstanding; expected vs actual styling) → **Profit panel**
  (revenue, cost lines, fees, **Final / Provisional / Incomplete**, "Fix missing cost") → **Return card**
  (initiate full/partial, receive; Exchange button on delivered) → **Exchange link card** (partner order +
  combined profit) → **Charges** list (expected vs actual) → **Timeline** (status events + edits, with
  reason/notes).
- **Status change:** bottom sheet listing only allowed next statuses; required fields (reason for
  cancel/failed, courier + CN for handover) shown inline; "date/time" chip for backdating.
- **States:** draft (limited panels), cancelled (dimmed), returned, disputed (flag banner with note),
  role-restricted (hides ledger/profit/charges/returns).
- **Notes:** order is a long page: use sticky primary action and anchor chips (Items · Money · Timeline).

#### S-12 Courier sheet (assign courier / hand over)
Bottom sheet: courier select, zone select, weight, **CN field with paste / scan / clear**, "Mark as handed
over" switch (when allowed); errors: CN already used (link "view order"), courier required, CN required;
soft warning when CN does not match the courier's pattern (never blocks).

#### S-13 Scan barcode sheet
Camera preview 280dp tall in a rounded frame, torch button, hint `scanHint`, "type instead" link; on
permission denied/unavailable switches to a manual field (`scanPermissionDenied`) + "Use". Success
auto-closes with haptic.

#### S-14 Initiate return / Receive return (bottom sheets)
- *Initiate:* full vs partial, reason chips (customer refused, not reachable, wrong address, wrong/damaged
  item, size/colour, changed mind, fake order, other), line + qty steppers (partial), notes, date.
- *Receive:* per-line condition chips (Resellable / Damaged / Lost), summary of **loss** (goods + fees),
  stock restored hint, "Confirm received".

#### S-15 Exchange
Steps in one scroll: **Items coming back** (qty steppers per line) → **Replacement items** (cards: name,
qty, price, cost; "Same items, new size" shortcut) → **Who pays the courier** segmented (I pay / Customer
pays) + delivery charge + return shipping → **live preview card** (value coming back, replacement value,
**Collect on delivery**, **Refund due**, shipping you absorb) → **Create exchange**. Success opens the new
order.

#### S-16 Fast CN entry
One order at a time: header "n remaining", order summary card (no., customer, address, COD), courier
select (defaults), **big CN field (autofocus, scan icon)**, error line, buttons Skip / **Save & next**.
Done state: "All orders have a CN" with OK.

#### S-17 Drafts, S-18 Recently deleted
Lists of order rows (draft style / deleted style). Drafts: tap resumes form; swipe delete with undo.
Deleted: "Restore" per row (fails with message if CN reused), shows days left before purge; empty states.

#### S-19 Missing costs ("Fix it")
List grouped by order: line name, qty, price, **inline cost field** + Save; progress "n of m fixed";
success state "All profits are complete".

### 6.4 Customers, products, couriers

#### S-20 Customers list
Search (name or 4+ phone digits), rows: avatar, name, phone, **risk badges inline**, archived tag; FAB "New
customer"; empty states.

#### S-21 Customer detail
Header (name, phone, alt phone, WhatsApp, notes) → **Risk section** card (badges with tap-to-explain;
caution note; buttons "Caution note" and "Blocklist"/"Remove from blocklist"; privacy line `riskPrivateNote`)
→ **Addresses** list (default star) → **Summary** card (orders, delivered %, returned %, lifetime revenue,
lifetime profit, last order) → "Orders" row → Archive/Unarchive. App bar: Edit.

#### S-22 Customer form
Name, phone (validated Bangladeshi mobile; **duplicate banner** "Phone already used by X · Use existing"),
alt phone, WhatsApp, notes, **address list** (add/remove, label, text, district, area, default radio).

#### S-23 Customer picker / Product picker (sheets)
Search + results + "New …" row; keyboard-first; recents on top.

#### S-24 Products list / S-25 Product form
List: name, SKU, price, cost (hidden for helpers), stock chip (low-stock warning), active/inactive tag.
Form: name, SKU, sell price, cost price (optional, "cost missing" hint), stock qty (only when stock
tracking is on), active, **variants** (label, SKU, price/cost overrides, add/remove). No product photos yet.

#### S-26 Couriers list / S-27 Courier form
List: name, default marker, payout cycle, tracking link indicator; FAB "New courier". Form: **Quick add**
chips for common couriers (names only; no rates), name, phone, **tracking URL template** (`{cn}` placeholder
explained), **payout cycle days**, **stuck-after days**, **CN pattern (regex, optional; mismatch only warns)**,
**COD fee %**, **return fee** (None / Flat / % of delivery + value), **rate card** (rules: zone, weight min/max
g, delivery fee; add/remove rule rows).
Helper text: "Rates are only used to estimate; actual fees come from the courier's statement".


### 6.5 COD, payouts, returns

#### S-28 COD tab
- **Purpose:** "who owes me cash". **Layout:** app bar "COD" (+ statement PDF action) → **2 x 2 summary
  tiles**: Pending with courier, In transit COD, Disputed, Settled this month (each drills down) →
  **courier cards**: name, "n orders · oldest d days", **overdue chip** (danger) if any, trailing **total owed**
  (largest typography on the page); tap opens Record payout for that courier → **FAB "Record payout"**.
- **States:** empty ("Nothing is owed by couriers" friendly), loading, error. Money is **never masked here
  unless "hide amounts" is on** (then tap to reveal).

#### S-29 COD ageing
Buckets (0-3, 4-7, 8-14, 15+ days) as horizontal segmented summary + list of orders per bucket (order row
variant: courier, days owed, amount owed); filter by courier; overdue ones flagged.

#### S-30 Disputed
List of orders with dispute flag: note, amount outstanding, days, actions "Resolve" (sheet with note) and
"Open".

#### S-31 Payouts history / S-32 Payout detail
History: rows (amount, date · method · reference, "Reversed" chip). App bar actions: **Import statement**
(upload icon), **Dispute statement PDF**. Detail: header (courier, total received, date, method,
reference, policy used), allocated orders table (order, applied, deductions, write-off, disputed flag),
**Reverse payout** (danger, requires reason; explains it restores balances exactly).

#### S-33 Record payout (3-step flow)
1. **Courier + total received** (money field large), method chips (Bank, bKash, Nagad, Cash, Other),
   reference, paid-on date. 2. **Pick orders & amounts:** list with checkbox, order no., delivered date,
   outstanding, editable applied amount; **live bar** "Expected ৳X · Received ৳Y · Difference" (shortfall
   danger / surplus info); button "Auto-allocate (oldest first)". 3. **Shortfall handling** (only if
   needed): radios *Leave balance outstanding / Mark unpaid orders as disputed / Write off (accept the
   loss)*, "Allow overpayment" switch, **Save payout** with a consequence summary.
- **Errors:** allocations must equal received; an amount exceeds balance; choose a shortfall option.

#### S-34 Import courier statement
Steps in one scroll: **Courier** select → **Column profile** select (saved profiles + presets) with
"Edit columns" (dialog: header-name fields per data item, tolerance) → **Choose file** (CSV/Excel) →
**review**: filter chips with counts (All, Matched, Unknown CN, Duplicate in file, Amount differs, Already
settled) → rows (checkbox, CN · outcome, recorded vs statement amounts, payable) with, for "Amount
differs", a switch "Use the statement's collected amount" + shared reason field → totals ("Payout to
record", "Actual fees to save") → shortfall options → reference → **Apply statement**. Banner when the
same file was already applied. App bar: **Dispute PDF** when mismatches exist.

#### S-35 Returns (list)
Segmented control: In transit · Not received · Received. Row: order no., customer, reason, days in transit
("taking too long" warning), loss amount when received; tap opens the order; button "Mark received".

### 6.6 Reports

#### S-36 Reports index
List with icon, title, chevron: Daily summary, COD ageing, Courier performance, Profit, Returns, Business
P&L. **Ad slot at the bottom (ads on).**

#### S-37 Report shell (all reports)
App bar (title, Share/Export), **period chips** (as Home), body per report. Every chart has a **Table/Chart
toggle**; every number is tappable to the underlying orders when possible. Empty period = friendly
message. Loading skeleton.

- **Daily:** summary cards (orders, delivered, revenue, profit, payouts received) + **bar chart by day**
  (orders or revenue) + day list.
- **Ageing:** bucket cards + courier breakdown.
- **Courier:** table per courier: orders, delivered %, returned %, average days to deliver, fees,
  outstanding (sortable).
- **Profit:** group-by selector (Day / Courier / Channel / Customer / Product / Area), list of groups with
  revenue, cost, profit, margin; **banner "N orders excluded: cost missing"** with "Fix it"; best/worst
  orders lists.
- **Returns:** segmented by Reason / Product / Courier; donut + list; **total loss** header.
- **Business P&L:** statement-style card: Revenue → Product cost → Courier fees → Returns and write-offs →
  Packaging → Ads (campaign allocations) → **Order profit** → Expenses by category → **Business profit**;
  note about incomplete orders; link "Expenses".

### 6.7 Money outside orders

#### S-38 Expenses
Month switcher (‹ October 2026 ›) + **total**; list grouped by date (category icon, note, amount, recurring
tag, campaign link); FAB "Add expense"; **add/edit sheet:** amount, category chips (Ads, Packaging, Rent,
Salary, Misc), date, note, optional campaign, "repeat monthly" switch. Empty state.

#### S-39 Campaigns / S-40 Campaign
List: name, tag, date range, spend, status chip (Not applied / Applied / **Apply again** warning). Detail
form: name, **tag** (matches order tags), start/end, spend, allocation mode (By order count / By
revenue); **preview table** (orders matched, share per order); buttons **Apply to orders** and **Remove**;
explains idempotent re-apply and cancelled-order caveat.

### 6.8 Messaging & reminders

#### S-41 Message templates
List of 4 templates (Order confirmed, Dispatched with CN, Delivery follow-up, Courier will call you) in
the app language, with preview; edit screen: body with **variable chips** ({name}, {order}, {amount},
{courier}, {cn}, {shop}) inserted at cursor, reset to default; live preview; "Send via WhatsApp" is done elsewhere (seller still taps
Send).

#### S-42 Notifications (daily digest)
Switch, time picker, quiet hours (start/end), **kinds checklist** (what the digest includes), permission
status/CTA, "Test"/preview text, battery guide (Android only).

### 6.9 Settings, data, admin

#### S-43 Settings
Sections: **Business** (name, phone, order prefix, start number, default channel), **Defaults**
(delivery charge, packaging cost, add packaging to new orders switch, default courier), **Workflow**
(packed step on/off, in-transit step on/off, auto-start return flow, stock tracking, return-in-transit
warning days, hide profit in lists), **Customer risk** (return-rate %, minimum orders, refusal window days),
**Language** (বাংলা/English). Autosaves with a subtle "Saved" indicator.

#### S-44 Data
Rows: **Create backup** (optional passphrase dialog, then share sheet), **Restore** (file picker → preview
dialog "This backup contains …" with counts, Merge vs Replace buttons, passphrase prompt), **Last backup**
caption; **Google Drive backup** block (switch, schedule text, last success, error line, "Back up now",
"Restore from Drive" sheet listing backups); **Export CSV** list (Orders, Items, Customers, Products,
Payouts, Returns); **Import from CSV**; **Share CSV template**.

#### S-45 Import (CSV/Excel)
Type chips (Customers, Orders, Products, Opening balance); pick file; "using your saved mapping" note;
**column mapping** list (dropdown per field, "not mapped"); preview counts (valid, errors, duplicates);
all-or-nothing switch; **Import**; result summary (imported, skipped, row issues list); **Import history**
list with **Undo import** (confirm; result "n removed, m kept").

#### S-46 Who changed what (owner)
Filter chips (Everyone, You, helper ids) + "Money-affecting only"; list rows: icon, "entity · action",
actor · time, **Money chip**; empty state.

#### S-47 More (menu)
Grouped list with icons and chevrons: People & catalog (Customers, Products, Couriers) · Money (Reports,
Expenses, Campaigns, Returns, Fix missing costs) · Communication (Message templates, Notifications) ·
System (Security & privacy, Data, Settings, Who changed what) · Privacy and ad choices (only when
required). **Ad slot at the bottom (ads on).** Role-aware.

#### S-48 Access denied (role) / S-49 Sync status (future)
Centered lock icon + "Your role does not have access to this." and a Back button. Sync status screen
(future): state pill, last sync, pending count, **conflict list** (lost edits, rejected, over-allocation,
unique violations) with "Mark resolved", choose-data-source dialog ("This is my existing data" vs "Replace
with cloud", with count previews).

### 6.10 Cross-cutting sheets & dialogs (design as a set)
Status change sheet · Courier sheet · Return sheets · Customer/Product pickers · Filters · Saved views
(name dialog) · Date-range picker · Passphrase dialog · Restore preview dialog · Confirm irreversible
money action · Reason prompt (cancel/failed/reversal/dispute/adjust collected) · Snackbar variants ·
Risk-badge explanation sheet (orders behind a badge) · Blocklist reason dialog · Caution-note dialog.

---

## 7. Key flows (design as connected frames)

1. **First run → first order (target < 2 min):** Onboarding (5) → Home empty state → (+) → Order form
   (customer picker → new customer → items → Save) → Order detail with success snackbar.
2. **Repeat customer order in < 30 s:** (+) → pick customer (recents) → risk banner appears for a risky one
   → Take advance → items from catalog → Save.
3. **From chat:** WhatsApp message → Paste order → review (amber/green) → Create order → form pre-filled →
   Save.
4. **Dispatch day:** Orders (filter To dispatch) → select several → Mark handed → Fast CN entry (scan,
   Save & next) → Home "To dispatch" = 0.
5. **Getting paid:** COD tab → courier card → Record payout (total, auto-allocate, shortfall → dispute) →
   payout detail; or Import statement → review → Apply.
6. **Return & exchange:** Order detail (delivery failed) → Start return → Receive (conditions, loss) ;
   Delivered order → Exchange → preview money → Create.
7. **Month end:** Home period "Last month" → Reports → Business P&L → Expenses (add rent) → Campaign apply.
8. **Safety:** Data → Create backup (passphrase) → share; Restore → preview → Merge.
9. **Helper role (future):** invite → limited Home (no money) → create order → cannot see profit/COD.

---

## 8. Responsive & platform adaptation

- **Phones:** 320 (narrow: single-column tiles at 200% text, buttons wrap), 360-412 (primary), 430+ (more
  breathing room; keep max content width 600dp centred on larger screens).
- **Tablets / iPad (>= 600dp):** Orders = **two-pane** (list left, detail right); Home tiles 3-4 columns;
  forms centred max 640dp; bottom nav becomes **navigation rail**. Share sheets anchored (iPad popover).
- **Landscape:** supported but secondary; forms keep sticky bar; avoid fixed heights.
- **Android:** system back, edge-to-edge, predictive back, Material You *not* used (brand palette).
- **iOS:** swipe-back, Face ID wording, safe areas, no battery-guide; Cupertino-style adaptive dialogs are
  acceptable but keep one visual language.
- **Dark mode** everywhere; **text scale 100-200%** everywhere.

---

## 9. Accessibility checklist (annotate on frames)

- Contrast 4.5:1 text / 3:1 icons-large text; status never by colour alone.
- Targets >= 48dp; focus order = visual order; visible focus ring for keyboard/switch access.
- Screen-reader labels for icon buttons, chips ("Status: Delivered"), metric tiles ("Pending with courier,
  4,200 taka"), the ad slot ("Advertisement"), charts (summary sentence + table alternative).
- Dynamic type up to 200% with reflow; no truncation of money values (wrap label, never the amount).
- Reduced motion; haptics optional; works one-handed (primary actions in the lower 60%).
- Bangla: correct shaping of conjuncts, no letter-spacing, avoid italic/all-caps.

---

## 10. Content rules

- Plain words, short sentences; Bangla written naturally (not word-for-word English).
- Buttons are verbs ("Save order", "Mark delivered"), not "OK" unless acknowledging.
- Errors say what to do next ("Enter a valid mobile number"). Never blame the user.
- Money: ৳ prefix; negative amounts with a minus and danger tone; "expected" vs "actual" always labelled.
- Dates: absolute in lists, relative in warnings ("6 days with Pathao").
- Empty states are encouraging and give exactly one next step.
- Privacy copy is literal and calm ("Stays on your phone").

---

## 11. Prompt to paste into Claude Design (with this document attached)

> Design the complete mobile UI for **Parcel Khata**, an offline-first COD/order tracker for Bangladeshi
> social-commerce sellers. Use the attached specification as the source of truth. Produce: (1) a design
> system (tokens, type, components with states) in light and dark, Bangla-first with English variants;
> (2) high-fidelity phone screens (360x800) for every screen S-01 to S-49 with the listed states;
> (3) connected flow frames for the 9 flows in section 7; (4) narrow (320) and tablet/iPad (two-pane
> Orders, navigation rail) variants for the 8 most important screens (Home, Orders list, Order form, Order
> detail, COD, Record payout, Customer detail, Reports/P&L); (5) accessibility annotations and 200% text
> scale checks. Keep Material 3 behaviour so it can be built in Flutter. Prioritise: Order list row, Order
> form, Order detail, Home dashboard, COD tab, Payout flow. Do not invent features; mark any proposed
> addition as "proposal". Follow all **MUST** constraints.

# Appendix: copy inventory per screen (generated from the app; English strings)

Every string below is a real localisation key currently used by that screen. Bangla equivalents exist for all keys.


## lib/app/shell_scaffold.dart
- `navHome`: Home
- `navOrders`: Orders
- `navNewOrder`: New order
- `navCod`: COD
- `navMore`: More


## lib/features/backup/presentation/data_screen.dart
- `errBackupNotBackup`: This is not a Parcel Khata backup
- `errBackupCorrupted`: The backup file is damaged
- `errBackupChecksum`: The backup failed its integrity check
- `errBackupNewer`: This backup is from a newer app version
- `errBackupPass`: Wrong passphrase
- `errBackupNeedPass`: This backup is encrypted: enter its passphrase
- `backupPassphrase`: Passphrase (optional)
- `cancel`: Cancel
- `confirm`: Confirm
- `backupNow`: Create backup
- `backupCreated`: Backup created
- `restoreBackup`: Restore from backup
- `restorePreview`: This backup contains
- `restoreMerge`: Merge: add what is missing
- `restoreReplace`: Replace everything on this phone
- `restoreDone`: Restore complete
- `driveErrNotSignedIn`: Not signed in to Google. Open this screen and turn Drive backup on again.
- `driveErrPassphrase`: Encryption passphrase is missing.
- `driveErrNetwork`: No connection. Try again on Wi-Fi.
- `driveErrOther`: Drive backup failed.
- `driveTitle`: Google Drive backup
- `driveUploaded`: Backed up to Drive
- `driveNoBackups`: No backups found in Drive.
- `driveSchedule`: Weekly, on Wi-Fi while charging
- `driveSubtitle`: Encrypted copy in a private app folder. Only this app can see it.
- `driveLastSuccess`: Last Drive backup
- `driveBackupNow`: Back up to Drive now
- `driveRestore`: Restore from Drive
- `neverBackedUp`: Never
- `dataSection`: Data
- `lastBackup`: Last backup
- `exportData`: Export data (CSV)
- `exportOrders`: Orders
- `items`: Items
- `exportCustomers`: Customers
- `exportProducts`: Products
- `exportPayouts`: Payouts
- `exportReturns`: Returns
- `importCsv`: Import from CSV
- `downloadTemplate`: Share CSV template
- `importCustomers`: Import customers
- `importOrders`: Import orders


## lib/features/backup/presentation/import_screen.dart
- `importCsv`: Import from CSV
- `importCustomers`: Import customers
- `importOrders`: Import orders
- `importProducts`: Products
- `importOpeningBalance`: Opening balance
- `importOpeningHint`: Columns: courier, amount, consignment_no, delivered_date. Each row becomes a delivered, unpaid parcel so payouts can be matched.
- `pickFile`: Choose file
- `mapColumns`: Match columns
- `importSavedMapping`: Using the column mapping you saved for this file layout.
- `notMapped`: — not used —
- `importPreview`: Preview
- `importValid`: {n} rows ready
- `importErrors`: {n} rows have problems
- `importDuplicates`: {n} already exist and will be skipped
- `importSkipBad`: Skip bad rows and import the rest
- `importAllOrNothing`: Import only if every row is valid
- `importRun`: Import
- `importDone`: {n} imported
- `importHistory`: Import history
- `importNone`: No imports yet.
- `importBatchCount`: {n} rows
- `importUndone`: Undone
- `importUndoConfirm`: Remove everything this import created?
- `cancel`: Cancel
- `importUndo`: Undo import
- `importUndoResult`: {removed} removed, {kept} kept (already used)


## lib/features/cod/presentation/ageing_screen.dart
- `bucket0to3`: 0–3 days
- `bucket4to7`: 4–7 days
- `bucket8to14`: 8–14 days
- `bucket15plus`: 15+ days
- `ageingTitle`: COD ageing
- `courier`: Courier
- `allCouriers`: All couriers
- `ordersCountN`: {n} orders


## lib/features/cod/presentation/cod_screen.dart
- `codTitle`: COD
- `ageingTitle`: COD ageing
- `payoutsHistory`: Payouts
- `recordPayout`: Record payout
- `pendingWithCourier`: Pending with couriers
- `inTransitCod`: COD in transit
- `codDisputed`: Disputed
- `settledThisMonth`: Received this month
- `noPayableOrders`: Nothing is owed by this courier
- `ordersCountN`: {n} orders
- `oldestDays`: Oldest: {n} days
- `overdueLabel`: Overdue


## lib/features/cod/presentation/ledger_panel.dart
- `ledgerTitle`: COD ledger
- `expectedCod`: Expected COD
- `codPending`: COD pending
- `collectedAmount`: Collected by courier
- `recordCollected`: Record collected amount
- `expected`: expected
- `enterActual`: Enter actual fee
- `netReceivable`: Net receivable
- `settledAmount`: Received
- `writtenOffAmount`: Written off
- `outstandingLabel`: Outstanding
- `resolveDispute`: Resolve dispute
- `markDispute`: Mark as disputed
- `cancel`: Cancel
- `confirm`: Confirm
- `collectedReason`: Reason for the difference
- `disputeNote`: Note


## lib/features/cod/presentation/payout_flow_screen.dart
- `errCourierRequired`: Select a courier first
- `errTotalPositive`: Enter the total received
- `errNoOrdersSelected`: Select at least one order
- `errAllocationMismatch`: Allocated amounts must equal the cash received
- `errExceedsOutstanding`: An amount is more than the balance owed on an order
- `errShortfallPolicy`: Choose how to handle the shortfall
- `payoutSaved`: Payout saved
- `payoutNewTitle`: Record payout
- `courier`: Courier
- `totalReceived`: Total received
- `referenceNo`: Reference no.
- `paidOn`: Paid on
- `fieldNotes`: Notes
- `nextStep`: Next
- `methodBank`: Bank
- `methodBkash`: bKash
- `methodNagad`: Nagad
- `methodCash`: Cash
- `methodOther`: Other
- `noPayableOrders`: Nothing is owed by this courier
- `expectedLabel`: Expected
- `receivedLabel`: Received
- `differenceLabel`: Difference
- `shortfallLabel`: Shortfall
- `surplusLabel`: Surplus
- `autoAllocate`: Auto-allocate (oldest first)
- `allowOverpayment`: Allow overpayment
- `selectOrdersTitle`: Orders covered by this payout
- `outstandingLabel`: Outstanding
- `amountApplied`: Amount applied
- `shortfallHandling`: How to handle the shortfall?
- `handleAllocate`: Leave the balance outstanding
- `handleDispute`: Mark unpaid orders as disputed
- `handleWriteOff`: Write off (accept the loss)
- `confirmPayout`: Save payout


## lib/features/cod/presentation/payouts_screen.dart
- `payoutsHistory`: Payouts
- `stmtImport`: Import statement
- `shareStatement`: Courier statement (PDF)
- `noPayouts`: No payouts yet
- `payoutStatusReversed`: Reversed
- `payoutReversed`: Payout reversed
- `paidOn`: Paid on
- `payMethod`: Method
- `referenceNo`: Reference no.
- `allocationsTitle`: Allocations
- `writtenOffAmount`: Written off
- `codDisputed`: Disputed
- `allowOverpayment`: Allow overpayment
- `reversePayout`: Reverse payout
- `reverseReason`: Reason for reversal
- `cancel`: Cancel
- `confirm`: Confirm
- `disputedOrders`: Disputed orders
- `emptyDefaultTitle`: Nothing here yet
- `appName`: Parcel Khata


## lib/features/cod/presentation/statement_import_screen.dart
- `stmtApplied`: Statement applied
- `stmtErrReason`: Enter a reason for adjusting collected amounts
- `stmtErrIneligible`: Only matched or amount-differs rows can be applied
- `stmtErrNothing`: Select at least one row
- `errShortfallPolicy`: Choose how to handle the shortfall
- `errExceedsOutstanding`: An amount is more than the balance owed on an order
- `errAllocationMismatch`: Allocated amounts must equal the cash received
- `stmtAlreadyApplied`: This exact file was already applied. Nothing more to do.
- `stmtNoMismatch`: No differences to report.
- `appName`: Parcel Khata
- `stmtEditMapping`: Edit columns
- `stmtProfileName`: Profile name
- `stmtTolerance`: Amount tolerance (৳)
- `stmtColumnHint`: Header names in the file; use | between alternatives
- `cancel`: Cancel
- `stmtSaveProfile`: Save profile
- `stmtOutMatched`: Matched
- `stmtOutUnknown`: Unknown CN
- `stmtOutDuplicate`: Duplicate in file
- `stmtOutMismatch`: Amount differs
- `stmtOutSettled`: Already settled
- `stmtTitle`: Courier statement
- `stmtDisputePdf`: Dispute PDF
- `courier`: Courier
- `stmtProfile`: Column profile
- `stmtPickFile`: Choose statement file (CSV or Excel)
- `stmtNoCn`: Could not find the consignment column. Edit the columns and try again.
- `stmtAll`: All
- `stmtAdjustReason`: Reason for adjusting collected amounts
- `stmtPayoutTotal`: Payout to record
- `stmtFeesUpdated`: Actual fees to save
- `stmtNothingToPay`: Nothing to pay on the included rows; fees and adjustments will still be saved.
- `shortfallHandling`: How to handle the shortfall?
- `handleAllocate`: Leave the balance outstanding
- `handleDispute`: Mark unpaid orders as disputed
- `handleWriteOff`: Write off (accept the loss)
- `allowOverpayment`: Allow overpayment
- `referenceNo`: Reference no.
- `stmtIssues`: Rows that could not be read
- `stmtApply`: Apply statement
- `stmtRecorded`: Recorded
- `stmtStatementSays`: Statement
- `stmtAdjust`: Use the statement''s collected amount


## lib/features/couriers/presentation/courier_form_screen.dart
- `zoneInsideDhaka`: Inside Dhaka
- `zoneDhakaSuburb`: Dhaka suburb
- `zoneOutsideDhaka`: Outside Dhaka
- `zoneCustom`: Custom
- `courierNew`: New courier
- `courierEdit`: Edit courier
- `save`: Save
- `quickAdd`: Quick add
- `fieldName`: Name
- `errNameRequired`: Name is required
- `fieldPhone`: Mobile number
- `trackingTemplate`: Tracking link ('{cn}' = consignment no.)
- `errTrackingTemplate`: Must be an http(s) link containing '{cn}'
- `trackingPreview`: Preview
- `payoutCycleDays`: Payout cycle (days)
- `stuckDays`: Stuck parcel after (days)
- `cnPattern`: CN pattern (optional regex)
- `codFeePercent`: COD fee (%)
- `codFeeFlat`: COD flat fee
- `codFeeFreeUnder`: No COD fee under
- `returnFee`: Return fee
- `returnNone`: None
- `returnFlat`: Flat
- `returnPercent`: % of delivery fee
- `returnValue`: Return fee value
- `rateCard`: Rate card
- `addRule`: Add rate
- `zone`: Zone
- `remove`: Remove
- `weightMinG`: From (g)
- `weightMaxG`: Under (g)
- `fee`: Fee


## lib/features/couriers/presentation/couriers_screen.dart
- `couriers`: Couriers
- `courierNew`: New courier
- `emptyDefaultTitle`: Nothing here yet
- `archivedBadge`: Archived


## lib/features/customers/presentation/customer_detail_screen.dart
- `customers`: Customers
- `edit`: Edit
- `fieldPhone`: Mobile number
- `fieldPhoneAlt`: Alternate number
- `fieldWhatsapp`: WhatsApp number
- `addresses`: Addresses
- `ordersTitle`: Orders
- `unarchive`: Restore
- `archive`: Archive
- `customerSummary`: Summary
- `ordersTotal`: Orders
- `deliveredPct`: Delivered
- `returnedPct`: Returned
- `lifetimeRevenue`: Lifetime revenue
- `lifetimeProfit`: Lifetime profit
- `lastOrderOn`: Last order


## lib/features/customers/presentation/customer_form_screen.dart
- `customerEdit`: Edit customer
- `customerNew`: New customer
- `save`: Save
- `duplicatePhone`: A customer with this number already exists
- `useExisting`: Use existing customer
- `fieldName`: Name
- `errNameRequired`: Name is required
- `fieldPhone`: Mobile number
- `errInvalidPhone`: Enter a valid mobile number
- `fieldPhoneAlt`: Alternate number
- `fieldWhatsapp`: WhatsApp number
- `fieldNotes`: Notes
- `addresses`: Addresses
- `addAddress`: Add address
- `addressLabel`: Label (Home, Office)
- `remove`: Remove
- `addressText`: Full address
- `district`: District
- `area`: Area / Thana
- `defaultAddress`: Default


## lib/features/customers/presentation/customers_screen.dart
- `customers`: Customers
- `customerNew`: New customer
- `searchCustomers`: Search by name or phone
- `emptyDefaultTitle`: Nothing here yet
- `noResults`: No results
- `archivedBadge`: Archived


## lib/features/customers/presentation/risk_widgets.dart
- `riskReliable`: Reliable
- `riskRefusedLastCod`: Refused last COD
- `riskHighReturnRate`: High return rate
- `riskNewCustomer`: New customer
- `riskBlocklisted`: Blocklisted
- `riskWhyTitle`: Orders behind this badge
- `riskNoOrders`: No orders — set manually or no history yet.
- `riskBannerTitle`: Risky customer — consider taking an advance.
- `riskTakeAdvance`: Take advance
- `riskSection`: Risk flags
- `riskPrivateNote`: Seller-private. Based only on your own orders.
- `riskCaution`: Caution note
- `riskCautionHint`: Private note about this customer
- `riskUnblock`: Remove from blocklist
- `riskBlocklist`: Blocklist
- `riskBlockReason`: Reason
- `cancel`: Cancel
- `riskSave`: Save


## lib/features/expenses/presentation/campaigns_screen.dart
- `campaignsTitle`: Ad campaigns
- `campaignNew`: New campaign
- `emptyDefaultTitle`: Nothing here yet
- `allocNeedsReapply`: Changed since applied: apply again
- `allocApply`: Apply to orders
- `errNameRequired`: Name is required
- `campaignEdit`: Edit campaign
- `save`: Save
- `deleteView`: Delete
- `campaignName`: Campaign name
- `campaignTag`: Order tag
- `campaignTagHelp`: Orders with this tag share the spend
- `campaignSpend`: Ad spend
- `campaignStart`: From
- `campaignEnd`: To
- `allocByCount`: Equal share per order
- `allocByRevenue`: In proportion to sales
- `allocPreview`: Preview
- `allocNoOrders`: No orders carry this tag in these dates
- `taggedOrdersN`: {n} orders
- `allocApplied`: Applied to {n} orders
- `allocClear`: Remove from orders


## lib/features/expenses/presentation/expenses_screen.dart
- `catAds`: Ads
- `catPackaging`: Packaging
- `catRent`: Rent
- `catSalary`: Salary
- `catMisc`: Misc
- `expensesTitle`: Expenses
- `periodLastMonth`: Last month
- `expenseNew`: Add expense
- `emptyDefaultTitle`: Nothing here yet
- `expenseTotal`: Total
- `errInvalidAmount`: Enter a valid amount
- `expenseEdit`: Edit expense
- `expenseAmount`: Amount
- `expenseDate`: Date
- `expenseCampaign`: Campaign
- `none`: None
- `expenseNote`: Note
- `expenseRecurring`: Repeats every month
- `deleteView`: Delete
- `save`: Save


## lib/features/home/presentation/home_screen.dart
- `periodToday`: Today
- `periodYesterday`: Yesterday
- `period7d`: 7 days
- `periodThisMonth`: This month
- `periodLastMonth`: Last month
- `periodCustom`: Custom
- `homeTitle`: Home
- `attentionTitle`: Needs attention
- `viewAll`: View all
- `sectionCash`: Cash
- `pendingWithCourier`: Pending with couriers
- `inTransitCod`: COD in transit
- `settledThisMonth`: Received this month
- `codDisputed`: Disputed
- `sectionOps`: Operations
- `tileOrders`: Orders
- `tileToDispatch`: To dispatch
- `tileInTransitOps`: In transit
- `tileStuck`: Stuck parcels
- `tileReturnsAwaiting`: Returns awaiting
- `sectionPerformance`: Performance
- `tileRevenue`: Revenue
- `tileProfitFinal`: Final profit
- `tileProfitProvisional`: Provisional profit
- `tileMargin`: Margin
- `tileDeliverySuccess`: Delivery success
- `tileReturnRate`: Return rate
- `tileAvgProfit`: Avg profit / order


## lib/features/more/presentation/more_screen.dart
- `moreTitle`: More
- `customers`: Customers
- `products`: Products
- `couriers`: Couriers
- `reportsTitle`: Reports
- `expensesTitle`: Expenses
- `campaignsTitle`: Ad campaigns
- `returnsTitle`: Returns
- `fixMissingCosts`: Fix missing costs
- `messageTemplates`: Message templates
- `digestSettings`: Daily digest
- `secTitle`: Security & privacy
- `dataSection`: Data
- `settings`: Settings
- `activityTitle`: Who changed what
- `debugMenu`: Debug menu
- `adsPrivacyChoices`: Privacy and ad choices


## lib/features/onboarding/presentation/onboarding_gate.dart
- `sampleCustomerA`: Sample customer A
- `sampleCustomerB`: Sample customer B
- `sampleProduct1`: Sample T-shirt
- `sampleProduct2`: Sample bag
- `sampleProduct3`: Sample mug
- `obWelcome`: Welcome to Parcel Khata
- `obWelcomeSub`: Track orders, courier cash and real profit in one place.
- `obLanguage`: Choose your language
- `languageBangla`: বাংলা
- `languageEnglish`: English
- `obBusiness`: Your business
- `businessName`: Business name
- `businessPhone`: Business phone
- `obCourier`: Which courier do you use most?
- `obCourierHelp`: You can add rates and more couriers later.
- `obSample`: Add a few sample records
- `obSampleHelp`: Two customers and three products so you can try an order right away.
- `obTelemetryAsk`: Help improve the app with anonymous usage reports
- `secTelemetryHelp`: Never includes customers, phones, addresses or amounts.
- `obSkip`: Skip
- `backStep`: Back
- `obFinish`: Start using the app
- `obNext`: Next


## lib/features/orders/presentation/cn_entry_screen.dart
- `errCourierRequired`: Select a courier first
- `errCnRequired`: Enter the consignment number first
- `errCnTaken`: This CN is already used by another order
- `fastCnEntry`: Fast CN entry
- `remainingCount`: {n} left
- `allHaveCn`: All orders have a CN
- `ok`: OK
- `courier`: Courier
- `consignmentNo`: Consignment no. (CN)
- `scanCn`: Scan barcode
- `skip`: Skip
- `saveNext`: Save & next


## lib/features/orders/presentation/deleted_orders_screen.dart
- `recentlyDeleted`: Recently deleted
- `emptyDefaultTitle`: Nothing here yet
- `restored`: Order restored
- `errCnTaken`: This CN is already used by another order
- `restore`: Restore


## lib/features/orders/presentation/drafts_screen.dart
- `drafts`: Drafts
- `emptyDefaultTitle`: Nothing here yet
- `remove`: Remove


## lib/features/orders/presentation/order_detail_screen.dart
- `appName`: Parcel Khata
- `orderDeleted`: Order deleted
- `undo`: Undo
- `edit`: Edit
- `changeStatusTitle`: Change status
- `assignCourier`: Courier & CN
- `correctStatus`: Correct status
- `duplicateOrder`: Duplicate
- `shareOrderSlip`: Share order slip (PDF)
- `deleteOrder`: Delete order
- `customer`: Customer
- `items`: Items
- `costMissing`: Cost missing
- `codAmount`: COD amount
- `itemsTotal`: Items total
- `discountLabel`: Discount
- `deliveryCharge`: Delivery charge
- `advanceLabel`: Advance
- `codOverriddenMark`: Overridden
- `charges`: Courier & other charges
- `expected`: expected
- `timeline`: Timeline
- `correctionNote`: Why is this being corrected?
- `cancel`: Cancel
- `confirm`: Confirm
- `courier`: Courier
- `noCourier`: Not assigned
- `consignmentNo`: Consignment no. (CN)
- `lastUpdatedByYou`: Last updated by you
- `daysAgo`: {n, plural, =0{today} =1{1 day ago} other{{n} days ago}}
- `trackUnavailable`: Add a tracking link to this courier first
- `trackParcel`: Track parcel
- `returnCard`: Return
- `fullReturn`: Full return
- `partialReturn`: Partial return
- `receivedBackOn`: Received on
- `lossAmountLabel`: Loss
- `startReturn`: Start return
- `exchangeAction`: Exchange
- `actionReturned`: Received back


## lib/features/orders/presentation/order_form_screen.dart
- `lineDiscount`: Discount
- `confirmEditDelivered`: This order is delivered. Change its amounts anyway?
- `cancel`: Cancel
- `confirm`: Confirm
- `warnDialogTitle`: Check with the courier
- `warnEditAfterHandover`: Amounts changed while the courier has this parcel. The COD the courier collects may differ.
- `ok`: OK
- `draftSaved`: Draft saved
- `orderCreated`: Order created
- `orderUpdated`: Order updated
- `errCnTaken`: This CN is already used by another order
- `errCustomerRequired`: Select a customer
- `errItemsRequired`: Add at least one item
- `errAddressRequired`: Enter a delivery address
- `orderNew`: New order
- `orderEdit`: Edit order
- `codAmount`: COD amount
- `codOverriddenMark`: Overridden
- `saveDraft`: Save draft
- `saveOrder`: Save order
- `viewConflictingOrder`: View order
- `customer`: Customer
- `selectCustomer`: Select customer
- `deliveryAddress`: Delivery address
- `chooseSavedAddress`: Choose saved address
- `items`: Items
- `addFromCatalog`: From catalog
- `addFreeText`: Free item
- `paymentType`: Payment
- `payCod`: COD
- `payPrepaid`: Prepaid
- `payPartial`: Advance + COD
- `advanceReceived`: Advance received
- `advanceMethod`: Method (bKash, Nagad...)
- `deliveryCharge`: Delivery charge
- `orderDiscount`: Order discount
- `discountPercent`: Percent
- `courier`: Courier
- `noCourier`: Not assigned
- `zone`: Zone
- `weightGrams`: Weight (g)
- `consignmentNo`: Consignment no. (CN)
- `channel`: Channel
- `sourceRef`: Chat name / reference
- `orderTags`: Tags (comma separated)
- `internalNotes`: Internal notes
- `itemsTotal`: Items total
- `discountLabel`: Discount
- `total`: Total
- `advanceLabel`: Advance
- `overrideCod`: Override COD
- `resetToCalculated`: Reset to calculated
- `itemName`: Item name
- `remove`: Remove
- `unitPrice`: Unit price
- `unitCost`: Unit cost
- `costMissing`: Cost missing
- `saveToCatalog`: Save to catalog
- `expectedDeliveryFee`: Expected delivery fee
- `expectedCodFee`: Expected COD fee
- `searchCustomers`: Search by name or phone
- `addNewCustomer`: Add new customer
- `searchProducts`: Search products


## lib/features/orders/presentation/order_labels.dart
- `statusDraft`: Draft
- `statusConfirmed`: Confirmed
- `statusPacked`: Packed
- `statusHanded`: With courier
- `statusInTransit`: In transit
- `statusDelivered`: Delivered
- `statusFailed`: Failed
- `statusReturnInTransit`: Return in transit
- `statusReturned`: Returned
- `statusCancelled`: Cancelled
- `codNotApplicable`: Prepaid
- `codPending`: COD pending
- `codCollected`: With courier
- `codSettled`: Settled
- `codPartial`: Partly settled
- `codNotCollected`: Not collected
- `codDisputed`: Disputed
- `channelFacebook`: Facebook
- `channelWhatsapp`: WhatsApp
- `channelInstagram`: Instagram
- `channelPhone`: Phone
- `channelWalkIn`: Walk-in
- `channelOther`: Other
- `payCod`: COD
- `payPrepaid`: Prepaid
- `payPartial`: Advance + COD
- `chargeDeliveryFee`: Delivery fee
- `chargeCodFee`: COD fee
- `chargeReturnFee`: Return fee
- `chargePackaging`: Packaging
- `writtenOffAmount`: Written off
- `costAdAllocation`: Ad cost
- `chargeOther`: Other
- `zoneInsideDhaka`: Inside Dhaka
- `zoneDhakaSuburb`: Dhaka suburb
- `zoneOutsideDhaka`: Outside Dhaka
- `zoneCustom`: Custom


## lib/features/orders/presentation/orders_screen.dart
- `bulkSummary`: {changed} updated, {skipped} skipped
- `undo`: Undo
- `errNotAllowed`: This change is not allowed
- `sortNewest`: Newest
- `sortOldest`: Oldest
- `sortAmount`: Amount
- `sortProfit`: Profit
- `sortDispatch`: Longest with courier
- `courier`: Courier
- `dispatchDates`: Dispatched between
- `deliveredDates`: Delivered between
- `profitOnly`: Profit
- `lossOnly`: Loss
- `amountMin`: Min amount
- `hasReturnLabel`: Has return
- `selectedCount`: {n} selected
- `selectAll`: Select all
- `ordersTitle`: Orders
- `drafts`: Drafts
- `filtersTitle`: Filters
- `sortLabel`: Sort
- `savedViews`: Saved views
- `pasteMenu`: Paste order from chat
- `fastCnEntry`: Fast CN entry
- `recentlyDeleted`: Recently deleted
- `orderNew`: New order
- `statusHanded`: With courier
- `statusDelivered`: Delivered
- `statusFailed`: Failed
- `searchOrders`: Search order, name, phone, CN, product
- `scanCn`: Scan barcode
- `ordersCountHeader`: {n} orders
- `statusAll`: All
- `stuckParcels`: Stuck parcels
- `noOrders`: No orders yet
- `emptyOrdersHint`: Orders you take on Facebook, WhatsApp or by phone appear here.
- `emptyOrdersCta`: Create your first order
- `exchangeChip`: Exchange
- `withCourierDays`: With courier {n} days


## lib/features/orders/presentation/paste_order_screen.dart
- `pasteTitle`: Paste order
- `pasteHint`: Paste the customer''s message here
- `pasteFromClipboard`: Paste
- `pasteParse`: Read message
- `pasteNothing`: Nothing recognised. Fill the order manually.
- `pasteReview`: Check the highlighted fields before creating the order. Nothing is saved yet.
- `fieldPhone`: Mobile number
- `pasteExisting`: Existing customer found
- `pasteExistingNote`: This customer is used as saved. Their details are not changed.
- `pasteNameDiffers`: The message says a different name
- `pasteNewCustomer`: New customer: you can review the details first
- `fieldName`: Name
- `deliveryAddress`: Delivery address
- `pasteLines`: Products
- `pasteTotalHint`: Message mentions a total of
- `pasteUseDelivery`: Use delivery charge from message
- `pasteUseAdvance`: Use advance from message
- `pasteMoreNumbers`: Other numbers
- `pasteCreate`: Create order
- `pasteAmbiguous`: Several products match
- `pasteMatch`: Catalog product
- `pasteNoMatch`: Not in catalog (free text)
- `pasteQty`: Qty
- `exchangeSell`: Price
- `remove`: Remove


## lib/features/orders/presentation/status_actions.dart
- `errNotAllowed`: This change is not allowed
- `errCourierRequired`: Select a courier first
- `errCnRequired`: Enter the consignment number first
- `errReasonRequired`: Select a reason
- `errFutureDate`: Date cannot be in the future
- `errBeforeInitiated`: Received date is before the return started
- `actionPacked`: Mark packed
- `actionHanded`: Hand to courier
- `actionInTransit`: Mark in transit
- `actionDelivered`: Mark delivered
- `actionFailed`: Delivery failed
- `actionReturnTransit`: Return in transit
- `actionReturned`: Received back
- `actionCancel`: Cancel order
- `reasonCustomerRefused`: Customer refused
- `reasonNotReachable`: Not reachable
- `reasonWrongAddress`: Wrong address
- `reasonCustomerCancelled`: Customer cancelled
- `reasonOutOfStock`: Out of stock
- `reasonCourierIssue`: Courier issue
- `conditionDamaged`: Damaged
- `variantLabel`: Size / color
- `reasonOther`: Other
- `reasonCorrection`: Correction
- `whenLabel`: When
- `change`: Change
- `reasonLabel`: Reason
- `noteOptional`: Note (optional)
- `confirm`: Confirm
- `errCnTaken`: This CN is already used by another order
- `cnPatternWarn`: CN does not match the usual pattern
- `assignCourier`: Courier & CN
- `courier`: Courier
- `consignmentNo`: Consignment no. (CN)
- `scanCn`: Scan barcode
- `paste`: Paste
- `remove`: Remove
- `zone`: Zone
- `weightGrams`: Weight (g)
- `markHandedOver`: Mark as handed over
- `viewConflictingOrder`: View order
- `save`: Save


## lib/features/products/presentation/product_form_screen.dart
- `productNew`: New product
- `productEdit`: Edit product
- `save`: Save
- `fieldName`: Name
- `errNameRequired`: Name is required
- `sku`: SKU / code
- `sellPrice`: Selling price
- `costPrice`: Cost price
- `stockQty`: Stock quantity
- `activeLabel`: Active
- `variants`: Variants
- `variantLabel`: Size / color
- `remove`: Remove
- `addVariant`: Add variant


## lib/features/products/presentation/products_screen.dart
- `products`: Products
- `productNew`: New product
- `searchProducts`: Search products
- `emptyDefaultTitle`: Nothing here yet
- `noResults`: No results
- `costMissing`: Cost missing
- `archivedBadge`: Archived


## lib/features/profit/presentation/missing_costs_screen.dart
- `unitCost`: Unit cost
- `cancel`: Cancel
- `save`: Save
- `fixMissingCosts`: Fix missing costs
- `noMissingCosts`: No orders with missing costs
- `alsoUpdateCatalog`: Also set this as the catalog cost


## lib/features/profit/presentation/profit_panel.dart
- `stateProvisional`: Provisional
- `stateFinal`: Final
- `stateIncomplete`: Incomplete
- `costCogs`: Product cost
- `costGoodsLoss`: Damaged/lost goods
- `chargeDeliveryFee`: Delivery fee
- `chargeCodFee`: COD fee
- `chargeReturnFee`: Return fee
- `chargePackaging`: Packaging
- `writtenOffAmount`: Written off
- `costAdAllocation`: Ad cost
- `chargeOther`: Other
- `expected`: expected
- `helpProvisional`: Based on expected fees or the order is not settled yet.
- `helpFinal`: All amounts are known.
- `helpIncomplete`: A product cost is missing, so profit cannot be trusted.
- `missingCostFor`: Cost missing for
- `profitTitle`: Profit
- `profitRevenue`: Product revenue
- `profitDelivery`: Delivery charge
- `profitGross`: Collected value
- `profitNet`: Net profit
- `marginLabel`: Margin
- `expectedFeesNote`: includes expected fees


## lib/features/reminders/presentation/attention_screen.dart
- `attentionTitle`: Needs attention
- `attentionEmpty`: All caught up


## lib/features/reminders/presentation/attention_widgets.dart
- `attStale`: No update for {n} days. Delivered?
- `attOverdueCod`: COD overdue by {n} days
- `attReturn`: Return in transit {n} days
- `attDraft`: Draft older than a day
- `attDispute`: Disputed settlement
- `attDispatch`: Waiting to be dispatched
- `attBackup`: No backup for {n} days
- `backupNow`: Create backup
- `statusDelivered`: Delivered
- `statusFailed`: Failed
- `stillInTransit`: Still in transit
- `recordPayout`: Record payout
- `actionReturned`: Received back
- `callCustomer`: Call
- `whatsappCustomer`: WhatsApp
- `openTracking`: Track
- `snooze1d`: Snooze 1 day
- `snooze3d`: Snooze 3 days
- `dismissItem`: Dismiss
- `dismissReasonLabel`: Why dismiss?
- `dismissDone`: Already handled
- `dismissNotNeeded`: Not needed
- `appName`: Parcel Khata


## lib/features/reminders/presentation/notification_settings_screen.dart
- `attStale`: No update for {n} days. Delivered?
- `codTitle`: COD
- `returnsTitle`: Returns
- `drafts`: Drafts
- `codDisputed`: Disputed
- `tileToDispatch`: To dispatch
- `backupNow`: Create backup
- `digestSettings`: Daily digest
- `digestEnable`: Send a daily reminder
- `digestTime`: Time
- `quietHours`: Quiet hours
- `quietFrom`: From
- `quietTo`: To
- `batteryGuideTitle`: Keep reminders working
- `batteryGuideBody`: Some phones stop apps in the background. Allow Parcel Khata to run without battery restrictions so reminders arrive. The in-app list always works.
- `batteryGuideOpen`: How to allow
- `gotIt`: Got it


## lib/features/reports/presentation/reports_screens.dart
- `reportsTitle`: Reports
- `reportDaily`: Daily summary
- `ageingTitle`: COD ageing
- `reportCourier`: Courier performance
- `reportProfit`: Profit report
- `reportReturns`: Returns report
- `reportPnl`: Business profit (P&L)
- `periodToday`: Today
- `periodYesterday`: Yesterday
- `period7d`: 7 days
- `periodThisMonth`: This month
- `periodLastMonth`: Last month
- `periodCustom`: Custom
- `noData`: No data for this period
- `payoutsReceivedLabel`: Payouts received
- `colCreated`: Created
- `colDispatched`: Dispatched
- `colDelivered`: Delivered
- `colFailed`: Failed
- `colCollected`: COD collected
- `bucket0to3`: 0–3 days
- `bucket4to7`: 4–7 days
- `bucket8to14`: 8–14 days
- `bucket15plus`: 15+ days
- `colOrders`: Orders
- `outstandingLabel`: Outstanding
- `courier`: Courier
- `colReturned`: Returned
- `colAvgDays`: Avg days
- `colPayoutLag`: Payout lag
- `colFees`: Fees
- `colShortfall`: Shortfall
- `groupDay`: By day
- `groupCourier`: By courier
- `groupChannel`: By channel
- `groupCustomer`: By customer
- `groupProduct`: By product
- `groupArea`: By area
- `incompleteExcluded`: {n} incomplete orders are excluded from margins
- `colName`: Name
- `colUnits`: Units
- `colRevenue`: Revenue
- `colProfit`: Profit
- `colMargin`: Margin
- `bestOrders`: Best orders
- `worstOrders`: Worst orders
- `byReason`: By reason
- `lossTotal`: Total loss
- `lossAmountLabel`: Loss
- `pnlRevenue`: Revenue
- `pnlCogs`: Product cost
- `pnlCourierFees`: Courier fees
- `pnlReturnLoss`: Returns & write-offs
- `pnlPackaging`: Packaging
- `pnlAds`: Ads (on orders)
- `pnlOtherCosts`: Other order costs
- `pnlOrderProfit`: Order profit
- `pnlExpenses`: Business expenses
- `expenseTotal`: Total
- `pnlBusinessProfit`: Business profit
- `openExpenses`: Expenses


## lib/features/returns/presentation/exchange_screen.dart
- `exchangeCreated`: Exchange created
- `exchangeNotDelivered`: Only delivered orders can be exchanged.
- `exchangeExists`: This order already has a return or exchange.
- `exchangeNeedItems`: Pick items to return and add a replacement.
- `exchangeTitle`: Exchange order
- `exchangeReturnedItems`: Items coming back
- `exchangeReplacementItems`: Replacement items
- `exchangeAddItem`: Add item
- `exchangeSameItems`: Same items, new size
- `exchangeWhoPays`: Who pays the courier
- `exchangePayerSeller`: I pay
- `exchangePayerCustomer`: Customer pays
- `exchangeDeliveryCharge`: Replacement delivery charge
- `exchangeReturnShipping`: Return shipping fee
- `exchangeValueReturned`: Value coming back
- `exchangeValueReplacement`: Replacement value
- `exchangeCollect`: Collect on delivery
- `exchangeRefundDue`: Refund due to customer
- `exchangeShippingLoss`: Shipping you absorb
- `exchangeCreate`: Create exchange
- `exchangeItemName`: Item name
- `exchangeQty`: Qty
- `exchangeSell`: Price
- `exchangeCost`: Cost
- `exchangeLinked`: Linked exchange
- `exchangeReplacementOrder`: Replacement order
- `exchangeOriginalOrder`: Original order
- `exchangeGroupProfit`: Profit of both orders


## lib/features/returns/presentation/return_sheets.dart
- `conditionResellable`: Resellable
- `conditionDamaged`: Damaged
- `conditionLost`: Lost
- `errReturnStatus`: A return is not possible in this status
- `errReturnNoLines`: Select at least one item
- `errReturnBadQty`: Quantity is more than ordered
- `errReturnUseFull`: All items returned: use a full return
- `errFutureDate`: Date cannot be in the future
- `errBeforeInitiated`: Received date is before the return started
- `errReturnExists`: A return already exists for this order
- `fullReturn`: Full return
- `partialReturn`: Partial return
- `returnReason`: Return reason
- `quantity`: Qty
- `save`: Save
- `actionReturned`: Received back
- `receivedBackOn`: Received on
- `change`: Change
- `lossAmountLabel`: Loss
- `stockWillRestore`: Resellable items go back to stock
- `confirm`: Confirm


## lib/features/returns/presentation/returns_screen.dart
- `returnsTitle`: Returns
- `tabInTransit`: In transit
- `tabNotReceived`: Not received
- `tabReceived`: Received
- `emptyDefaultTitle`: Nothing here yet
- `lossAmountLabel`: Loss
- `receivedBackOn`: Received on
- `daysInTransitN`: {n} days in transit


## lib/features/search/presentation/order_filter_sheet.dart
- `filtersTitle`: Filters
- `resetFilters`: Reset
- `ordersTitle`: Orders
- `filterCodStatus`: COD status
- `courier`: Courier
- `allCouriers`: All couriers
- `channel`: Channel
- `statusAll`: All
- `paymentType`: Payment
- `orderDates`: Ordered between
- `dispatchDates`: Dispatched between
- `deliveredDates`: Delivered between
- `filterProfit`: Profit
- `profitOnly`: Profit
- `lossOnly`: Loss
- `amountMin`: Min amount
- `amountMax`: Max amount
- `tagLabel`: Tag
- `areaLabel`: Area
- `hasReturnLabel`: Has return
- `applyFilters`: Apply


## lib/features/search/presentation/saved_views_sheet.dart
- `viewToDispatch`: To dispatch today
- `viewCodPending5`: Delivered, COD pending > 5 days
- `viewReturnsNotReceived`: Returns not received
- `viewLossMaking`: Loss-making orders
- `viewName`: View name
- `cancel`: Cancel
- `save`: Save
- `savedViews`: Saved views
- `saveCurrentView`: Save current filters as view
- `renameView`: Rename
- `deleteView`: Delete


## lib/features/security/presentation/lock_gate.dart
- `lockTitle`: Parcel Khata is locked
- `lockEnterPin`: Enter your PIN
- `lockTryAgain`: Try again in {s} seconds
- `lockWrongPin`: Wrong PIN
- `lockUseBiometric`: Use fingerprint / face
- `remove`: Remove
- `confirm`: Confirm


## lib/features/security/presentation/security_screen.dart
- `cancel`: Cancel
- `confirm`: Confirm
- `lockSetPin`: Choose a PIN (4–8 digits)
- `lockPinInvalid`: Use 4 to 8 digits
- `lockConfirmPin`: Confirm PIN
- `lockPinMismatch`: PINs do not match
- `secTitle`: Security & privacy
- `secEnableLock`: Lock the app with a PIN
- `lockEnterPin`: Enter your PIN
- `lockWrongPin`: Wrong PIN
- `secChangePin`: Change PIN
- `secBiometric`: Unlock with fingerprint / face
- `secTimeout`: Lock after leaving the app
- `secTimeoutNow`: Immediately
- `secTimeout1m`: After 1 minute
- `secTimeout5m`: After 5 minutes
- `secHideAmounts`: Hide dashboard amounts until tapped
- `secHideProfit`: Hide profit everywhere
- `secTelemetry`: Share anonymous usage and crash reports
- `secTelemetryHelp`: Never includes customers, phones, addresses or amounts.
- `secErase`: Erase all data
- `secEraseWarn`: This deletes every order, customer, product, payout, attachment and setting on this phone. It cannot be undone. Make a backup first.
- `secEraseType`: Type ERASE to confirm
- `secEraseWord`: ERASE
- `secErased`: All data erased


## lib/features/settings/presentation/settings_screen.dart
- `channelFacebook`: Facebook
- `channelWhatsapp`: WhatsApp
- `channelInstagram`: Instagram
- `channelPhone`: Phone
- `channelWalkIn`: Walk-in
- `channelOther`: Other
- `settings`: Settings
- `businessProfile`: Business profile
- `businessName`: Business name
- `businessPhone`: Business phone
- `orderPrefix`: Order number prefix
- `orderStart`: Starting number
- `defaults`: Defaults
- `defaultChannel`: Default channel
- `defaultDeliveryCharge`: Default delivery charge
- `defaultPackaging`: Default packaging cost
- `settingApplyPackaging`: Add default packaging cost to new orders
- `defaultCourier`: Default courier
- `none`: None
- `workflow`: Workflow
- `packedStep`: Use Packed step
- `inTransitStep`: Use In Transit step
- `autoReturnFlow`: Start return flow on failed delivery
- `stockTracking`: Track stock
- `hideProfit`: Hide profit in lists
- `returnTransitDays`: Flag returns in transit after (days)
- `riskSettings`: Customer risk flags
- `riskPrivateNote`: Seller-private. Based only on your own orders.
- `riskReturnRateLabel`: High return rate from (%)
- `riskMinOrdersLabel`: Minimum finished orders
- `riskRecencyLabel`: Refusal counts for (days)
- `language`: Language
- `languageEnglish`: English
- `languageBangla`: বাংলা


## lib/features/sync/presentation/activity_screen.dart
- `activityTitle`: Who changed what
- `activityAllActors`: Everyone
- `activityYou`: You (owner)
- `activityMoneyOnly`: Money-affecting only
- `activityNone`: No activity yet.
- `activityMoney`: Money


## lib/features/templates/presentation/templates_screen.dart
- `tplConfirmation`: Order confirmation
- `tplDispatch`: Dispatch notice
- `tplFollowUp`: Delivery follow-up
- `tplBeAvailable`: Please be available
- `messageTemplates`: Message templates
- `languageBangla`: বাংলা
- `languageEnglish`: English
- `tplPlaceholders`: Placeholders: '{name}' '{cn}' '{amount}' '{order}' '{courier}' '{shop}'
- `tplUnknown`: Unknown placeholder
- `tplReset`: Reset to default


## lib/shared/cn_scanner.dart
- `scanTitle`: Scan consignment barcode
- `scanHint`: Point the camera at the parcel barcode or QR code.
- `scanManualField`: Consignment number
- `scanPermissionDenied`: Camera not available. Type the number instead.
- `scanUse`: Use


## lib/shared/confirm_dialog.dart
- `cancel`: Cancel
- `confirm`: Confirm
