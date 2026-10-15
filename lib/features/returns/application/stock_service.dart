import 'package:drift/drift.dart';
import 'package:parcel_khata/core/db/app_database.dart';
import 'package:parcel_khata/core/time/clock.dart';

class StockChange {
  const StockChange({required this.productId, required this.variantId, required this.newQty});
  final String productId;
  final String? variantId;
  final int newQty;
  bool get negative => newQty < 0;
}

/// Optional stock counts (feature spec F3). Negative stock is allowed; callers
/// surface a warning. Always run inside the caller's transaction.
class StockService {
  StockService(this._db, this._clock);

  final AppDatabase _db;
  final Clock _clock;

  /// Applies [delta] to a variant's stock, or the product's when no variant.
  Future<StockChange?> adjust({
    required String? productId,
    required String? variantId,
    required int delta,
  }) async {
    if (productId == null || delta == 0) return null;
    final now = _clock.now();
    if (variantId != null) {
      final v = await (_db.select(_db.productVariants)..where((x) => x.id.equals(variantId)))
          .getSingleOrNull();
      if (v != null) {
        final next = (v.stockQty ?? 0) + delta;
        await (_db.update(_db.productVariants)..where((x) => x.id.equals(variantId)))
            .write(ProductVariantsCompanion(stockQty: Value(next), updatedAt: Value(now)));
        return StockChange(productId: productId, variantId: variantId, newQty: next);
      }
    }
    final p = await (_db.select(_db.products)..where((x) => x.id.equals(productId)))
        .getSingleOrNull();
    if (p == null) return null;
    final next = (p.stockQty ?? 0) + delta;
    await (_db.update(_db.products)..where((x) => x.id.equals(productId)))
        .write(ProductsCompanion(stockQty: Value(next), updatedAt: Value(now)));
    return StockChange(productId: productId, variantId: null, newQty: next);
  }

  /// Stock leaves (out) or returns for every catalog line of an order.
  Future<List<StockChange>> applyForOrder(String orderId, {required bool out}) async {
    final lines = await (_db.select(_db.orderLines)
          ..where((l) => l.orderId.equals(orderId) & l.deletedAt.isNull()))
        .get();
    final changes = <StockChange>[];
    for (final l in lines) {
      final c = await adjust(
        productId: l.productId,
        variantId: l.variantId,
        delta: out ? -l.qty : l.qty,
      );
      if (c != null) changes.add(c);
    }
    return changes;
  }
}
