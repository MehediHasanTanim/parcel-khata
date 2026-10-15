import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:parcel_khata/features/cod/application/cod_queries.dart';
import 'package:parcel_khata/features/couriers/application/courier_repository.dart';
import 'package:parcel_khata/l10n/l10n.dart';

String bucketLabel(AppLocalizations l, AgeBucket b) => switch (b) {
      AgeBucket.d0to3 => l.bucket0to3,
      AgeBucket.d4to7 => l.bucket4to7,
      AgeBucket.d8to14 => l.bucket8to14,
      AgeBucket.d15plus => l.bucket15plus,
    };

class AgeingScreen extends ConsumerStatefulWidget {
  const AgeingScreen({super.key});

  @override
  ConsumerState<AgeingScreen> createState() => _AgeingScreenState();
}

class _AgeingScreenState extends ConsumerState<AgeingScreen> {
  String? _courierId;
  AgeBucket? _bucket;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final q = ref.watch(codQueriesProvider);
    ref.watch(codRevisionProvider);
    final couriers = ref.watch(couriersProvider).value ?? const [];
    return Scaffold(
      appBar: AppBar(title: Text(l.ageingTitle)),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        DropdownButtonFormField<String?>(
          initialValue: _courierId,
          decoration: InputDecoration(labelText: l.courier),
          items: [
            DropdownMenuItem<String?>(child: Text(l.allCouriers)),
            for (final c in couriers)
              DropdownMenuItem<String?>(value: c.id, child: Text(c.name)),
          ],
          onChanged: (v) => setState(() {
            _courierId = v;
            _bucket = null;
          }),
        ),
        const SizedBox(height: 12),
        FutureBuilder<List<AgeingRow>>(
          future: q.ageing(courierId: _courierId),
          builder: (_, snap) {
            final rows = snap.data ?? const <AgeingRow>[];
            return Column(children: [
              for (final r in rows)
                Card(
                  color: _bucket == r.bucket
                      ? Theme.of(context).colorScheme.primaryContainer
                      : null,
                  child: ListTile(
                    title: Text(bucketLabel(l, r.bucket)),
                    subtitle: Text(l.ordersCountN(r.count)),
                    trailing: Text(r.total.format(),
                        style: Theme.of(context).textTheme.titleMedium),
                    onTap: () => setState(() => _bucket = _bucket == r.bucket ? null : r.bucket),
                  ),
                ),
            ]);
          },
        ),
        if (_bucket != null)
          FutureBuilder<List<OpenCodOrder>>(
            future: q.openOrders(courierId: _courierId, bucket: _bucket),
            builder: (_, snap) => Column(children: [
              for (final o in snap.data ?? const <OpenCodOrder>[])
                ListTile(
                  title: Text(o.order.orderNo),
                  subtitle: Text(o.courier?.name ?? ''),
                  trailing: Text(o.outstanding.format()),
                  onTap: () => context.push('/orders/${o.order.id}'),
                ),
            ]),
          ),
      ]),
    );
  }
}
