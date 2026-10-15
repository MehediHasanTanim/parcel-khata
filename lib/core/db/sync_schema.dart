/// Tables that take part in sync, parents before children, and the SQLite
/// triggers that mark a row dirty in the same transaction as its mutation
/// (the "outbox written by the single write path" rule, enforced by the
/// database so no repository can forget it).
const kSyncedTables = <String>[
  'customers',
  'customer_addresses',
  'products',
  'product_variants',
  'couriers',
  'courier_rate_rules',
  'orders',
  'order_lines',
  'order_charges',
  'order_tag_links',
  'order_attachments',
  'order_status_events',
  'order_edit_log',
  'payouts',
  'payout_allocations',
  'return_records',
  'return_lines',
  'campaigns',
  'expenses',
];

/// Rows are only captured while sync is enabled and while the engine is not
/// itself applying remote rows.
List<String> syncTriggerSql() => [
      for (final t in kSyncedTables) ...[
        'CREATE TRIGGER IF NOT EXISTS sync_${t}_ins AFTER INSERT ON $t '
            'WHEN (SELECT enabled = 1 AND applying = 0 FROM sync_state WHERE id = 1) '
            "BEGIN INSERT OR IGNORE INTO sync_dirty(tbl, row_id) VALUES('$t', NEW.id); END",
        'CREATE TRIGGER IF NOT EXISTS sync_${t}_upd AFTER UPDATE ON $t '
            'WHEN (SELECT enabled = 1 AND applying = 0 FROM sync_state WHERE id = 1) '
            "BEGIN INSERT OR IGNORE INTO sync_dirty(tbl, row_id) VALUES('$t', NEW.id); END",
        // Hard deletes (e.g. rebuilding an address list) become tombstones.
        'CREATE TRIGGER IF NOT EXISTS sync_${t}_del AFTER DELETE ON $t '
            'WHEN (SELECT enabled = 1 AND applying = 0 FROM sync_state WHERE id = 1) '
            "BEGIN INSERT OR IGNORE INTO sync_dirty(tbl, row_id) VALUES('$t', OLD.id); END",
      ],
    ];
