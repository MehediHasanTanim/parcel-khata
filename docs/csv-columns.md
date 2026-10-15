# CSV column contract

Exports are UTF-8 **with BOM** (Excel opens Bangla text correctly), RFC 4180 quoting, `CRLF` line ends.
Money is plain taka (`1060` or `1060.50`, no symbol, no grouping). Dates are ISO-8601 local time.
Importers also accept `DD/MM/YYYY`, grouping commas and Bangla digits.

Column names below are a stable contract; add columns only at the end and never rename.

## customers.csv
`name, phone, phone_alt, whatsapp, address, district, area, notes`

## orders.csv
`order_no, order_date, customer_phone, customer_name, address, channel, payment_type, delivery_charge, discount, advance, courier, consignment_no, status, cod_amount, notes, source_ref`

- `channel`: facebook, whatsapp, instagram, phone, walk_in, other
- `payment_type`: cod, prepaid, partial_advance
- `status`: confirmed, packed, handed_to_courier, in_transit, delivered, delivery_failed, return_in_transit, returned, cancelled.
  On import a non-confirmed status needs the courier name (matching an existing courier) **and** a CN; otherwise the order is imported as confirmed and reported as `status_ignored`.
- `cod_amount` is export-only (recomputed on import).
- Import: `order_no` is stored as the seller reference; an order with the same reference and customer is skipped (duplicate check).

## order_lines.csv
`order_no, item_name, qty, unit_price, unit_cost, line_discount`

For simple imports the first item may be given on the order row with `item_name, qty, unit_price, unit_cost` columns instead.

## products.csv (export only)
`name, sku, sell_price, cost_price, stock, active`

## payouts.csv / payout_allocations.csv / returns.csv (export only)
- payouts: `payout_id, courier, paid_at, method, reference, total_received, status`
- payout_allocations: `payout_id, order_no, amount_applied, write_off`
- returns: `order_no, type, reason, initiated_at, received_back_at, condition, loss_amount`

## Import options
- **All or nothing** (default): nothing is written if any row is invalid.
- **Skip bad rows**: valid rows are imported; problems are listed per row.
- Customers are de-duplicated by normalized phone.
