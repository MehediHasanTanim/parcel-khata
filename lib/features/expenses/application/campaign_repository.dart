import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:parcel_khata/core/db/app_database.dart';
import 'package:parcel_khata/core/db/audit_writer.dart';
import 'package:parcel_khata/core/db/providers.dart';
import 'package:parcel_khata/core/ids/uuid_v7.dart';
import 'package:parcel_khata/core/money/money.dart';
import 'package:parcel_khata/core/providers.dart';
import 'package:parcel_khata/core/result/result.dart';
import 'package:parcel_khata/core/time/clock.dart';
import 'package:parcel_khata/core/time/providers.dart';
import 'package:parcel_khata/features/cod/application/ledger_writer.dart';
import 'package:parcel_khata/features/expenses/domain/ad_allocator.dart';
import 'package:parcel_khata/features/orders/domain/order_enums.dart';

class CampaignInput {
  const CampaignInput({
    required this.name,
    required this.tag,
    required this.start,
    required this.end,
    required this.spend,
    this.mode = AllocationMode.byCount,
  });

  final String name;
  final String tag;
  final DateTime start;

  /// Inclusive last day.
  final DateTime end;
  final Money spend;
  final AllocationMode mode;
}

class AllocationPreview {
  const AllocationPreview({required this.shares, required this.orders, required this.spend});

  final Map<String, Money> shares;
  final List<CampaignOrder> orders;
  final Money spend;

  int get orderCount => orders.length;
}

class CampaignRepository {
  CampaignRepository(this._db, this._ids, this._clock, this._audit, this._shopId, this._ledger);

  final AppDatabase _db;
  final UuidV7 _ids;
  final Clock _clock;
  final AuditWriter _audit;
  final String _shopId;
  final LedgerWriter _ledger;

  static String normalizeTag(String t) => t.trim().toLowerCase();

  Stream<List<Campaign>> watchAll() => (_db.select(_db.campaigns)
        ..where((c) => c.shopId.equals(_shopId) & c.deletedAt.isNull())
        ..orderBy([(c) => OrderingTerm.desc(c.startDate)]))
      .watch();

  Future<Campaign?> getById(String id) =>
      (_db.select(_db.campaigns)..where((c) => c.id.equals(id))).getSingleOrNull();

  Future<Result<Campaign>> create(CampaignInput i) async {
    final bad = _validate(i);
    if (bad != null) return Result.err(bad);
    final now = _clock.now();
    final id = _ids.generate();
    await _db.transaction(() async {
      await _db.into(_db.campaigns).insert(CampaignsCompanion.insert(
            id: id,
            shopId: _shopId,
            createdAt: now,
            updatedAt: now,
            name: i.name.trim(),
            tag: normalizeTag(i.tag),
            startDate: _day(i.start),
            endDate: _day(i.end),
            spend: Value(i.spend.poisha),
            allocationMode: Value(i.mode.dbValue),
          ));
      await _audit.write(entity: 'campaign', entityId: id, action: 'create');
    });
    return Result.ok((await getById(id))!);
  }

  /// Editing an applied campaign keeps its old shares until re-applied; the
  /// UI shows it as "needs re-apply" via [needsReapply].
  Future<Result<Campaign>> update(String id, CampaignInput i) async {
    final bad = _validate(i);
    if (bad != null) return Result.err(bad);
    final cur = await getById(id);
    if (cur == null) return const Result.err(NotFoundFailure('Campaign not found'));
    final now = _clock.now();
    await _db.transaction(() async {
      await (_db.update(_db.campaigns)..where((c) => c.id.equals(id))).write(
        CampaignsCompanion(
          name: Value(i.name.trim()),
          tag: Value(normalizeTag(i.tag)),
          startDate: Value(_day(i.start)),
          endDate: Value(_day(i.end)),
          spend: Value(i.spend.poisha),
          allocationMode: Value(i.mode.dbValue),
          updatedAt: Value(now),
          rowVersion: Value(cur.rowVersion + 1),
        ),
      );
      await _audit.write(entity: 'campaign', entityId: id, action: 'update');
    });
    return Result.ok((await getById(id))!);
  }

  bool needsReapply(Campaign c) => c.allocatedAt != null && c.updatedAt.isAfter(c.allocatedAt!);

  /// Removing a campaign also removes its ad cost from every order.
  Future<void> delete(String id) async {
    await clear(id);
    final now = _clock.now();
    await (_db.update(_db.campaigns)..where((c) => c.id.equals(id)))
        .write(CampaignsCompanion(deletedAt: Value(now), updatedAt: Value(now)));
  }

  // ---------------------------------------------------------------- preview

  Future<List<CampaignOrder>> _candidateOrders(Campaign c) async {
    final tagOrders = await (_db.select(_db.orderTagLinks)
          ..where((l) => l.tag.equals(c.tag) & l.deletedAt.isNull()))
        .get();
    if (tagOrders.isEmpty) return [];
    final ids = tagOrders.map((l) => l.orderId).toSet().toList();
    final out = <CampaignOrder>[];
    for (var i = 0; i < ids.length; i += 500) {
      final chunk = ids.sublist(i, i + 500 > ids.length ? ids.length : i + 500);
      final rows = await (_db.select(_db.orders)
            ..where((o) => o.id.isIn(chunk) & o.deletedAt.isNull() & o.shopId.equals(_shopId)))
          .get();
      for (final o in rows) {
        // Weight = kept revenue (gross collected minus delivery charge).
        final kept = (o.grossCollected ?? (o.itemsTotal - o.discountTotal)) -
            o.deliveryChargeCustomer;
        out.add(CampaignOrder(
          id: o.id,
          orderDate: o.orderDate,
          status: OrderStatus.fromDb(o.status),
          tags: [c.tag],
          weight: kept < 0 ? 0 : kept,
        ));
      }
    }
    return out;
  }

  CampaignWindow _window(Campaign c) => CampaignWindow(
        tag: c.tag,
        start: c.startDate,
        endExclusive: c.endDate.add(const Duration(days: 1)),
        spend: Money(c.spend),
        mode: AllocationMode.fromDb(c.allocationMode),
      );

  Future<AllocationPreview> preview(String campaignId) async {
    final c = await getById(campaignId);
    if (c == null) return AllocationPreview(shares: {}, orders: [], spend: Money.zero);
    final w = _window(c);
    final eligible = AdAllocator.eligible(w, await _candidateOrders(c));
    return AllocationPreview(
      shares: AdAllocator.allocate(w.spend, eligible, w.mode),
      orders: eligible,
      spend: w.spend,
    );
  }

  /// Number of orders carrying the tag in the window (for the list).
  Future<int> taggedOrderCount(Campaign c) async =>
      AdAllocator.eligible(_window(c), await _candidateOrders(c)).length;

  // --------------------------------------------------------------- allocate

  /// Idempotent: replaces this campaign's previous `ad_allocation` charges
  /// and refreshes profit for every order touched, in one transaction.
  Future<Result<AllocationPreview>> allocate(String campaignId) async {
    final c = await getById(campaignId);
    if (c == null || c.deletedAt != null) {
      return const Result.err(NotFoundFailure('Campaign not found'));
    }
    final p = await preview(campaignId);
    final now = _clock.now();
    await _db.transaction(() async {
      final touched = <String>{...await _removeCharges(campaignId, now)};
      for (final e in p.shares.entries) {
        await _db.into(_db.orderCharges).insert(OrderChargesCompanion.insert(
              id: _ids.generate(),
              shopId: _shopId,
              createdAt: now,
              updatedAt: now,
              orderId: e.key,
              type: 'ad_allocation',
              // Actual = expected so it also counts on orders whose other
              // charges are only estimates.
              expectedAmount: Value(e.value.poisha),
              actualAmount: Value(e.value.poisha),
              source: const Value('campaign'),
              note: Value(campaignId),
            ));
        touched.add(e.key);
      }
      for (final id in touched) {
        await _ledger.refresh(id);
      }
      await (_db.update(_db.campaigns)..where((x) => x.id.equals(campaignId))).write(
        CampaignsCompanion(allocatedAt: Value(now), updatedAt: Value(now)),
      );
      await _audit.write(
        entity: 'campaign',
        entityId: campaignId,
        action: 'allocate',
        payload: {'orders': p.orderCount, 'spend': c.spend},
      );
    });
    return Result.ok(p);
  }

  /// Takes the campaign's cost back off every order (profit returns to what
  /// it was before the allocation).
  Future<void> clear(String campaignId) async {
    final now = _clock.now();
    await _db.transaction(() async {
      final touched = await _removeCharges(campaignId, now);
      for (final id in touched) {
        await _ledger.refresh(id);
      }
      await (_db.update(_db.campaigns)..where((x) => x.id.equals(campaignId))).write(
        CampaignsCompanion(allocatedAt: const Value(null), updatedAt: Value(now)),
      );
      await _audit.write(entity: 'campaign', entityId: campaignId, action: 'clear');
    });
  }

  Future<Set<String>> _removeCharges(String campaignId, DateTime now) async {
    final rows = await (_db.select(_db.orderCharges)
          ..where((c) =>
              c.type.equals('ad_allocation') &
              c.note.equals(campaignId) &
              c.deletedAt.isNull()))
        .get();
    if (rows.isEmpty) return {};
    await (_db.update(_db.orderCharges)
          ..where((c) => c.id.isIn(rows.map((r) => r.id))))
        .write(OrderChargesCompanion(deletedAt: Value(now), updatedAt: Value(now)));
    return rows.map((r) => r.orderId).toSet();
  }

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  static ValidationFailure? _validate(CampaignInput i) {
    if (i.name.trim().isEmpty) return const ValidationFailure('name_required');
    if (normalizeTag(i.tag).isEmpty) return const ValidationFailure('tag_required');
    if (i.spend.isNegative) return const ValidationFailure('amount_required');
    if (_day(i.end).isBefore(_day(i.start))) return const ValidationFailure('bad_range');
    return null;
  }
}

final campaignRepositoryProvider = Provider<CampaignRepository>((ref) => CampaignRepository(
      ref.watch(databaseProvider),
      ref.watch(uuidProvider),
      ref.watch(clockProvider),
      ref.watch(auditWriterProvider),
      ref.watch(shopIdProvider),
      LedgerWriter(ref.watch(databaseProvider)),
    ));
