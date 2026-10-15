import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:parcel_khata/core/db/app_database.dart';
import 'package:parcel_khata/core/db/providers.dart';
import 'package:parcel_khata/core/providers.dart';
import 'package:parcel_khata/core/time/clock.dart';
import 'package:parcel_khata/core/time/providers.dart';
import 'package:parcel_khata/features/cod/application/cod_queries.dart';
import 'package:parcel_khata/features/orders/domain/order_enums.dart';
import 'package:parcel_khata/features/reminders/application/reminder_repository.dart';
import 'package:parcel_khata/features/reminders/domain/needs_attention.dart';
import 'package:parcel_khata/features/settings/application/settings_repository.dart';

/// Loads queue facts from the database and runs the pure builder.
class AttentionService {
  AttentionService(this._db, this._clock, this._shopId, this._reminders, this._settings);

  final AppDatabase _db;
  final Clock _clock;
  final String _shopId;
  final ReminderRepository _reminders;
  final SettingsRepository _settings;

  DateTime _t(int s) => DateTime.fromMillisecondsSinceEpoch(s * 1000);

  Future<List<OrderAttentionFacts>> _facts() async {
    final rows = await _db.customSelect(
      '''
SELECT o.id, o.order_no, o.status, o.cod_status, o.created_at, o.handed_over_at,
  o.delivered_at, o.consignment_no, o.courier_id, o.outstanding, o.cod_expected,
  c.stuck_days, c.payout_cycle_days, c.name AS courier_name, c.tracking_url_template,
  cu.name AS customer_name, cu.phone_primary,
  (SELECT MAX(e.at) FROM order_status_events e WHERE e.order_id = o.id) AS last_event,
  (SELECT MIN(e.at) FROM order_status_events e
     WHERE e.order_id = o.id AND e.to_status IN ('delivery_failed','return_in_transit')) AS return_started
FROM orders o
LEFT JOIN couriers c ON c.id = o.courier_id
LEFT JOIN customers cu ON cu.id = o.customer_id
WHERE o.shop_id = ?1 AND o.deleted_at IS NULL
  AND o.status IN ('draft','confirmed','packed','handed_to_courier','in_transit',
                   'delivered','delivery_failed','return_in_transit')
''',
      variables: [Variable<String>(_shopId)],
      readsFrom: {_db.orders, _db.orderStatusEvents, _db.couriers, _db.customers},
    ).get();
    DateTime? ts(QueryRow r, String c) {
      final v = r.read<int?>(c);
      return v == null ? null : _t(v);
    }

    return [
      for (final r in rows)
        OrderAttentionFacts(
          orderId: r.read<String>('id'),
          orderNo: r.read<String>('order_no'),
          status: OrderStatus.fromDb(r.read<String>('status')),
          codStatus: CodStatus.fromDb(r.read<String>('cod_status')),
          createdAt: _t(r.read<int>('created_at')),
          handedOverAt: ts(r, 'handed_over_at'),
          deliveredAt: ts(r, 'delivered_at'),
          lastEventAt: ts(r, 'last_event'),
          returnStartedAt: ts(r, 'return_started'),
          stuckDays: r.read<int?>('stuck_days'),
          payoutCycleDays: r.read<int?>('payout_cycle_days'),
          hasCourier: r.read<String?>('courier_id') != null,
          hasCn: (r.read<String?>('consignment_no') ?? '').isNotEmpty,
          customerName: r.read<String?>('customer_name'),
          customerPhone: r.read<String?>('phone_primary'),
          courierName: r.read<String?>('courier_name'),
          outstandingPoisha: r.read<int?>('outstanding') ?? 0,
          amountPoisha: r.read<int?>('cod_expected') ?? 0,
          consignmentNo: r.read<String?>('consignment_no'),
          trackingTemplate: r.read<String?>('tracking_url_template'),
        ),
    ];
  }

  Future<List<AttentionItem>> load() async {
    final settings = await _settings.read();
    final shop = await (_db.select(_db.shops)..where((s) => s.id.equals(_shopId)))
        .getSingleOrNull();
    return NeedsAttentionBuilder.build(
      orders: await _facts(),
      states: await _reminders.states(),
      now: _clock.now(),
      thresholds: AttentionThresholds(
        returnInTransitDays: settings.returnInTransitDays,
        backupReminderDays: settings.backupReminderDays,
      ),
      lastBackupAt: settings.lastBackupAtMs == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(settings.lastBackupAtMs!),
      firstUseAt: shop?.createdAt,
    );
  }
}

final attentionServiceProvider = Provider<AttentionService>((ref) => AttentionService(
      ref.watch(databaseProvider),
      ref.watch(clockProvider),
      ref.watch(shopIdProvider),
      ref.watch(reminderRepositoryProvider),
      ref.watch(settingsRepositoryProvider),
    ));

/// The queue; refreshes on any order/payout change and on snooze/dismiss.
final attentionProvider = FutureProvider<List<AttentionItem>>((ref) async {
  ref.watch(codRevisionProvider);
  ref.watch(_reminderStatesProvider);
  ref.watch(shopSettingsProvider);
  return ref.watch(attentionServiceProvider).load();
});

final _reminderStatesProvider = StreamProvider<Map<String, ReminderState>>(
    (ref) => ref.watch(reminderRepositoryProvider).watchStates());
