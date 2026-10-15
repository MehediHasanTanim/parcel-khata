import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:parcel_khata/core/db/audit_writer.dart';
import 'package:parcel_khata/core/db/providers.dart';
import 'package:parcel_khata/core/ids/uuid_v7.dart';
import 'package:parcel_khata/core/time/providers.dart';

/// v1 is single-shop; every table still carries a constant `shop_id`.
const kDefaultShopId = 'shop-default';

final shopIdProvider = Provider<String>((ref) => kDefaultShopId);

final uuidProvider =
    Provider<UuidV7>((ref) => UuidV7(clock: ref.watch(clockProvider)));

final auditWriterProvider = Provider<AuditWriter>((ref) => AuditWriter(
      ref.watch(databaseProvider),
      ref.watch(uuidProvider),
      ref.watch(clockProvider),
      ref.watch(shopIdProvider),
    ));
