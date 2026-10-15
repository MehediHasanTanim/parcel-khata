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

class VariantInput {
  const VariantInput({required this.label, this.id, this.sellPrice, this.costPrice, this.stockQty});

  final String? id;
  final String label;
  final Money? sellPrice;
  final Money? costPrice;
  final int? stockQty;
}

class ProductInput {
  const ProductInput({
    required this.name,
    required this.sellPrice,
    this.costPrice,
    this.sku,
    this.stockQty,
    this.isActive = true,
    this.variants = const [],
  });

  final String name;
  final Money sellPrice;

  /// Null = cost missing; orders using it show "cost missing" later (F3 AC2).
  final Money? costPrice;
  final String? sku;
  final int? stockQty;
  final bool isActive;
  final List<VariantInput> variants;
}

class ProductRepository {
  ProductRepository(this._db, this._ids, this._clock, this._audit, this._shopId);

  final AppDatabase _db;
  final UuidV7 _ids;
  final Clock _clock;
  final AuditWriter _audit;
  final String _shopId;

  Future<Product?> getById(String id) =>
      (_db.select(_db.products)..where((p) => p.id.equals(id))).getSingleOrNull();

  Stream<List<Product>> watchAll({String query = '', bool includeInactive = true}) {
    final q = query.trim();
    return (_db.select(_db.products)
          ..where((p) {
            Expression<bool> w = p.shopId.equals(_shopId) & p.deletedAt.isNull();
            if (!includeInactive) w = w & p.isActive.equals(true);
            if (q.isNotEmpty) w = w & (p.name.like('%$q%') | p.sku.like('%$q%'));
            return w;
          })
          ..orderBy([(p) => OrderingTerm.asc(p.name)]))
        .watch();
  }

  Future<List<ProductVariant>> variants(String productId) =>
      (_db.select(_db.productVariants)
            ..where((v) => v.productId.equals(productId) & v.deletedAt.isNull())
            ..orderBy([(v) => OrderingTerm.asc(v.createdAt)]))
          .get();

  Future<Result<Product>> create(ProductInput input) async {
    final bad = _validate(input);
    if (bad != null) return Result.err(bad);
    final now = _clock.now();
    final id = _ids.generate();
    await _db.transaction(() async {
      await _db.into(_db.products).insert(ProductsCompanion.insert(
            id: id,
            shopId: _shopId,
            createdAt: now,
            updatedAt: now,
            name: input.name.trim(),
            sku: Value(_blank(input.sku)),
            defaultSellPrice: Value(input.sellPrice.poisha),
            defaultCostPrice: Value(input.costPrice?.poisha),
            stockQty: Value(input.stockQty),
            isActive: Value(input.isActive),
          ));
      await _replaceVariants(id, input.variants, now);
      await _audit.write(entity: 'product', entityId: id, action: 'create');
    });
    return Result.ok((await getById(id))!);
  }

  Future<Result<Product>> update(String id, ProductInput input) async {
    final bad = _validate(input);
    if (bad != null) return Result.err(bad);
    final cur = await getById(id);
    if (cur == null) return const Result.err(NotFoundFailure('Product not found'));
    final now = _clock.now();
    await _db.transaction(() async {
      await (_db.update(_db.products)..where((p) => p.id.equals(id))).write(
        ProductsCompanion(
          name: Value(input.name.trim()),
          sku: Value(_blank(input.sku)),
          defaultSellPrice: Value(input.sellPrice.poisha),
          defaultCostPrice: Value(input.costPrice?.poisha),
          stockQty: Value(input.stockQty),
          isActive: Value(input.isActive),
          updatedAt: Value(now),
          rowVersion: Value(cur.rowVersion + 1),
        ),
      );
      await _replaceVariants(id, input.variants, now);
      await _audit.write(entity: 'product', entityId: id, action: 'update', payload: {
        'sell': [cur.defaultSellPrice, input.sellPrice.poisha],
        'cost': [cur.defaultCostPrice, input.costPrice?.poisha],
      });
    });
    return Result.ok((await getById(id))!);
  }

  /// Soft deactivate; old orders keep their price/cost snapshots.
  Future<void> setActive(String id, {required bool active}) async {
    await (_db.update(_db.products)..where((p) => p.id.equals(id))).write(
        ProductsCompanion(isActive: Value(active), updatedAt: Value(_clock.now())));
  }

  Future<void> _replaceVariants(String productId, List<VariantInput> vs, DateTime now) async {
    await (_db.delete(_db.productVariants)..where((v) => v.productId.equals(productId))).go();
    for (final v in vs) {
      if (v.label.trim().isEmpty) continue;
      await _db.into(_db.productVariants).insert(ProductVariantsCompanion.insert(
            id: v.id ?? _ids.generate(),
            shopId: _shopId,
            createdAt: now,
            updatedAt: now,
            productId: productId,
            label: v.label.trim(),
            sellPrice: Value(v.sellPrice?.poisha),
            costPrice: Value(v.costPrice?.poisha),
            stockQty: Value(v.stockQty),
          ));
    }
  }

  static ValidationFailure? _validate(ProductInput i) {
    if (i.name.trim().isEmpty) return const ValidationFailure('Name is required');
    if (i.sellPrice.isNegative || (i.costPrice?.isNegative ?? false)) {
      return const ValidationFailure('Prices cannot be negative');
    }
    return null;
  }

  static String? _blank(String? s) => (s == null || s.trim().isEmpty) ? null : s.trim();
}

final productRepositoryProvider = Provider<ProductRepository>((ref) =>
    ProductRepository(
      ref.watch(databaseProvider),
      ref.watch(uuidProvider),
      ref.watch(clockProvider),
      ref.watch(auditWriterProvider),
      ref.watch(shopIdProvider),
    ));

final productsProvider = StreamProvider.family<List<Product>, String>(
    (ref, q) => ref.watch(productRepositoryProvider).watchAll(query: q));
