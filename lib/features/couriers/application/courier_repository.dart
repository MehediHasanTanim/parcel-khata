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
import 'package:parcel_khata/features/couriers/domain/charge_calculator.dart';
import 'package:parcel_khata/features/couriers/domain/tracking_url.dart';

/// Prebuilt suggestions: names and tracking templates only; no rates (plan §1).
const kCourierPresets = <({String name, String? tracking})>[
  (name: 'Pathao', tracking: 'https://merchant.pathao.com/tracking?consignment_id={cn}'),
  (name: 'Steadfast', tracking: 'https://steadfast.com.bd/t/{cn}'),
  (name: 'RedX', tracking: 'https://redx.com.bd/track-global-parcel/?trackingId={cn}'),
  (name: 'eCourier', tracking: null),
  (name: 'Paperfly', tracking: null),
  (name: 'Sundarban', tracking: null),
  (name: 'SA Paribahan', tracking: null),
];

const kZones = ['inside_dhaka', 'dhaka_suburb', 'outside_dhaka', 'custom'];

class RateRuleInput {
  const RateRuleInput({required this.zone, required this.fee, this.weightMinG = 0, this.weightMaxG});

  final String zone;
  final Money fee;
  final int weightMinG;
  final int? weightMaxG;
}

class CourierInput {
  const CourierInput({
    required this.name,
    this.phone,
    this.trackingUrlTemplate,
    this.payoutCycleDays = 3,
    this.stuckDays = 3,
    this.cnRegex,
    this.codFeePercentBp = 0,
    this.codFeeFlat = Money.zero,
    this.codFeeFreeUnder,
    this.returnFeeMode = ReturnFeeMode.none,
    this.returnFeeValue = 0,
    this.rateRules = const [],
  });

  final String name;
  final String? phone;
  final String? trackingUrlTemplate;
  final int payoutCycleDays;
  final int stuckDays;
  final String? cnRegex;
  final int codFeePercentBp;
  final Money codFeeFlat;
  final Money? codFeeFreeUnder;
  final ReturnFeeMode returnFeeMode;
  final int returnFeeValue;
  final List<RateRuleInput> rateRules;
}

class CourierRepository {
  CourierRepository(this._db, this._ids, this._clock, this._audit, this._shopId);

  final AppDatabase _db;
  final UuidV7 _ids;
  final Clock _clock;
  final AuditWriter _audit;
  final String _shopId;

  Future<Courier?> getById(String id) =>
      (_db.select(_db.couriers)..where((c) => c.id.equals(id))).getSingleOrNull();

  Stream<List<Courier>> watchAll() => (_db.select(_db.couriers)
        ..where((c) => c.shopId.equals(_shopId) & c.deletedAt.isNull())
        ..orderBy([(c) => OrderingTerm.asc(c.name)]))
      .watch();

  Future<List<CourierRateRule>> rateRules(String courierId) =>
      (_db.select(_db.courierRateRules)
            ..where((r) => r.courierId.equals(courierId) & r.deletedAt.isNull())
            ..orderBy([
              (r) => OrderingTerm.asc(r.zone),
              (r) => OrderingTerm.asc(r.weightMinG),
            ]))
          .get();

  Future<CourierFeeRules> feeRules(String courierId) async {
    final c = await getById(courierId);
    if (c == null) return const CourierFeeRules();
    final rules = await rateRules(courierId);
    return CourierFeeRules(
      rateRules: [
        for (final r in rules)
          RateRule(
              zone: r.zone,
              fee: Money(r.fee),
              weightMinG: r.weightMinG,
              weightMaxG: r.weightMaxG),
      ],
      codFeePercentBp: c.codFeePercentBp,
      codFeeFlat: Money(c.codFeeFlat),
      codFeeFreeUnder: c.codFeeFreeUnder == null ? null : Money(c.codFeeFreeUnder!),
      returnFeeMode: ReturnFeeMode.fromDb(c.returnFeeMode),
      returnFeeValue: c.returnFeeValue,
    );
  }

  Future<Result<Courier>> create(CourierInput input) async {
    final bad = _validate(input);
    if (bad != null) return Result.err(bad);
    final now = _clock.now();
    final id = _ids.generate();
    await _db.transaction(() async {
      await _db.into(_db.couriers).insert(_companion(id, input, now));
      await _replaceRules(id, input.rateRules, now);
      await _audit.write(entity: 'courier', entityId: id, action: 'create');
    });
    return Result.ok((await getById(id))!);
  }

  Future<Result<Courier>> update(String id, CourierInput input) async {
    final bad = _validate(input);
    if (bad != null) return Result.err(bad);
    final cur = await getById(id);
    if (cur == null) return const Result.err(NotFoundFailure('Courier not found'));
    final now = _clock.now();
    await _db.transaction(() async {
      await (_db.update(_db.couriers)..where((c) => c.id.equals(id))).write(
        CouriersCompanion(
          name: Value(input.name.trim()),
          phone: Value(_blank(input.phone)),
          trackingUrlTemplate: Value(_blank(input.trackingUrlTemplate)),
          payoutCycleDays: Value(input.payoutCycleDays),
          stuckDays: Value(input.stuckDays),
          cnRegex: Value(_blank(input.cnRegex)),
          codFeePercentBp: Value(input.codFeePercentBp),
          codFeeFlat: Value(input.codFeeFlat.poisha),
          codFeeFreeUnder: Value(input.codFeeFreeUnder?.poisha),
          returnFeeMode: Value(input.returnFeeMode.dbValue),
          returnFeeValue: Value(input.returnFeeValue),
          updatedAt: Value(now),
          rowVersion: Value(cur.rowVersion + 1),
        ),
      );
      await _replaceRules(id, input.rateRules, now);
      await _audit.write(entity: 'courier', entityId: id, action: 'update');
    });
    return Result.ok((await getById(id))!);
  }

  Future<void> setActive(String id, {required bool active}) async {
    await (_db.update(_db.couriers)..where((c) => c.id.equals(id))).write(
        CouriersCompanion(isActive: Value(active), updatedAt: Value(_clock.now())));
  }

  CouriersCompanion _companion(String id, CourierInput i, DateTime now) =>
      CouriersCompanion.insert(
        id: id,
        shopId: _shopId,
        createdAt: now,
        updatedAt: now,
        name: i.name.trim(),
        phone: Value(_blank(i.phone)),
        trackingUrlTemplate: Value(_blank(i.trackingUrlTemplate)),
        payoutCycleDays: Value(i.payoutCycleDays),
        stuckDays: Value(i.stuckDays),
        cnRegex: Value(_blank(i.cnRegex)),
        codFeePercentBp: Value(i.codFeePercentBp),
        codFeeFlat: Value(i.codFeeFlat.poisha),
        codFeeFreeUnder: Value(i.codFeeFreeUnder?.poisha),
        returnFeeMode: Value(i.returnFeeMode.dbValue),
        returnFeeValue: Value(i.returnFeeValue),
      );

  Future<void> _replaceRules(String courierId, List<RateRuleInput> rules, DateTime now) async {
    await (_db.delete(_db.courierRateRules)..where((r) => r.courierId.equals(courierId))).go();
    for (final r in rules) {
      await _db.into(_db.courierRateRules).insert(CourierRateRulesCompanion.insert(
            id: _ids.generate(),
            shopId: _shopId,
            createdAt: now,
            updatedAt: now,
            courierId: courierId,
            zone: r.zone,
            fee: r.fee.poisha,
            weightMinG: Value(r.weightMinG),
            weightMaxG: Value(r.weightMaxG),
          ));
    }
  }

  static ValidationFailure? _validate(CourierInput i) {
    if (i.name.trim().isEmpty) return const ValidationFailure('Name is required');
    final t = i.trackingUrlTemplate?.trim() ?? '';
    if (t.isNotEmpty && !TrackingUrl.isValidTemplate(t)) {
      return const ValidationFailure('Tracking link must be an http(s) URL containing {cn}');
    }
    final re = i.cnRegex?.trim() ?? '';
    if (re.isNotEmpty) {
      try {
        RegExp(re);
      } on FormatException {
        return const ValidationFailure('Invalid CN pattern');
      }
    }
    if (i.payoutCycleDays < 0 || i.stuckDays < 1) {
      return const ValidationFailure('Thresholds must be positive');
    }
    for (final r in i.rateRules) {
      if (r.fee.isNegative) return const ValidationFailure('Fee cannot be negative');
      if (r.weightMaxG != null && r.weightMaxG! <= r.weightMinG) {
        return const ValidationFailure('Max weight must exceed min weight');
      }
    }
    return null;
  }

  static String? _blank(String? s) => (s == null || s.trim().isEmpty) ? null : s.trim();
}

final courierRepositoryProvider = Provider<CourierRepository>((ref) =>
    CourierRepository(
      ref.watch(databaseProvider),
      ref.watch(uuidProvider),
      ref.watch(clockProvider),
      ref.watch(auditWriterProvider),
      ref.watch(shopIdProvider),
    ));

final couriersProvider = StreamProvider<List<Courier>>(
    (ref) => ref.watch(courierRepositoryProvider).watchAll());
