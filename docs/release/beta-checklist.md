# Closed beta (5-10 sellers)

Goal: every tester completes order -> deliver -> reconcile **without help** (S8 exit criteria).

## Setup per tester (15 min call)
- Install from the closed track; choose language; enter business + first courier.
- Ask them to import last week's real orders (CSV template in Settings > Data) or enter 5 live ones.
- Explain: statuses are manual; the Home "Needs attention" list is the habit.

## Tasks to observe (do not coach)
1. Create an order for a returning customer (target < 30 s).
2. Hand over with a CN, mark delivered (single and bulk).
3. Record a courier payout with a shortfall.
4. Handle one refused delivery as a return, receive it back.
5. Make a backup and restore it on a second phone.

## Feedback form (copy into Google Forms)
- Did you finish each task alone? (Y/N per task, where did you stop?)
- Which screen felt slow or confusing? (free text)
- Any wrong number (COD, profit)? Order number + what you expected.
- Bangla wording that felt unnatural? (screen + word)
- Would you use it tomorrow? (1-5)

## Triage
P0: data loss, wrong money, crash on launch. P1: blocks a core flow. P2: polish.
Budget ~8 findings; fix P0/P1 before the 10% production rollout.

## Metrics to read from testers' devices (opt-in only)
- median `order_created.ms` (target < 30 000)
- % dispatched orders with a final status within 7 days
- % delivered COD orders reconciled within 14 days
