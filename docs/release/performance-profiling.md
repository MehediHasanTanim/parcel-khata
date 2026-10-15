# Performance profiling (low-end device)

Budgets (implementation plan §11): order save < 200 ms, list first paint < 500 ms, search < 300 ms,
dashboard < 1.5 s at 20k orders, cold start < 2.5 s.

1. Debug menu > "Seed 20,000 orders (fast bulk)".
2. Debug menu > "Measure dashboard load" (repeat 5x, take the median).
3. `flutter run --profile` on the reference device; DevTools > Performance:
   scroll Orders (jank frames), open Home, open Reports > Profit (group by day).
4. Record results below and fix the top 5 issues.

| Check | Budget | Measured | Pass |
|---|---|---|---|
| Cold start | 2.5 s | | |
| Orders first paint | 500 ms | | |
| Search "345678" | 300 ms | | |
| Dashboard (20k) | 1.5 s | | |
| Order save | 200 ms | | |

The dashboard uses one aggregate query per tile group over indexed columns (`orders(shop_id,status,order_date)`,
`orders(shop_id,cod_status,delivered_at)`). If it exceeds budget, add a `daily_aggregates` table maintained in
`LedgerWriter.refresh` (same transaction) before changing queries.

## Measured on device (20,000 orders)

Device: motorola edge 50 fusion (Android 16). Run with
`flutter test integration_test/perf_test.dart -d <device>` (debug build, so these are
upper bounds; release is faster). Median of 3 runs, in-memory SQLite.

| Check | Budget | Measured | Pass |
|---|---|---|---|
| Dashboard load (all tiles) | 1.5 s | 932 ms | yes |
| Orders first page (30 rows) | 500 ms | 13 ms | yes |
| Search by CN (trigram FTS) | 300 ms | 7 ms | yes |
| Search "Rah" (LIKE fallback) | 300 ms | 60 ms | yes |
| Filtered + sorted page | n/a | 52 ms | |
| Profit report grouped by courier | 2 s | 191 ms | yes |
| Bulk seed 20k rows | n/a | 11.5 s | |

Still to measure by hand on the device: cold start, list scroll jank (DevTools, `--profile`),
and order save latency. Release APK builds and installs (80 MB fat APK; the AAB splits per ABI).
