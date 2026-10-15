import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:parcel_khata/core/db/app_database.dart';
import 'package:parcel_khata/core/money/money.dart';
import 'package:parcel_khata/core/result/result.dart';
import 'package:parcel_khata/features/couriers/application/courier_repository.dart';
import 'package:parcel_khata/features/orders/application/order_repository.dart';
import 'package:parcel_khata/features/orders/application/order_status_service.dart';
import 'package:parcel_khata/features/orders/domain/order_enums.dart';
import 'package:parcel_khata/features/orders/presentation/status_actions.dart';
import 'package:parcel_khata/features/settings/application/settings_repository.dart';
import 'package:parcel_khata/l10n/l10n.dart';
import 'package:parcel_khata/shared/cn_scanner.dart';
import 'package:parcel_khata/shared/empty_state.dart';

/// Steps through confirmed/packed orders that have no CN: enter it, save and
/// hand over, next. Keypad-friendly (S3-17).
class CnEntryScreen extends ConsumerStatefulWidget {
  const CnEntryScreen({super.key});

  @override
  ConsumerState<CnEntryScreen> createState() => _CnEntryScreenState();
}

class _CnEntryScreenState extends ConsumerState<CnEntryScreen> {
  List<OrderListItem> _queue = [];
  int _index = 0;
  bool _loading = true;
  String? _courierId;
  final _cn = TextEditingController();
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _cn.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final repo = ref.read(orderRepositoryProvider);
    final settings = await ref.read(settingsRepositoryProvider).read();
    final rows = await repo.fetchPage(
      filter: const OrderFilter(statuses: {OrderStatus.confirmed, OrderStatus.packed}),
      limit: 200,
    );
    if (!mounted) return;
    setState(() {
      // Oldest first so the longest-waiting parcels are handled first.
      _queue = rows.where((r) => (r.order.consignmentNo ?? '').isEmpty).toList().reversed.toList();
      _courierId = settings.defaultCourierId;
      _loading = false;
    });
  }

  void _next() {
    _cn.clear();
    setState(() {
      _error = null;
      _index++;
    });
  }

  Future<void> _save(Order o) async {
    final l = context.l10n;
    if (_courierId == null) {
      setState(() => _error = l.errCourierRequired);
      return;
    }
    if (_cn.text.trim().isEmpty) {
      setState(() => _error = l.errCnRequired);
      return;
    }
    final repo = ref.read(orderRepositoryProvider);
    final a = await repo.assignCourier(o.id,
        courierId: _courierId!, consignmentNo: _cn.text, zone: o.zone ?? 'inside_dhaka');
    if (!mounted) return;
    final f = a.failureOrNull;
    if (f != null) {
      setState(() => _error = f is ConflictFailure ? l.errCnTaken : f.message);
      return;
    }
    final s = await ref
        .read(orderStatusServiceProvider)
        .changeStatus(o.id, to: OrderStatus.handedToCourier);
    if (!mounted) return;
    final sf = s.failureOrNull;
    if (sf != null) {
      setState(() => _error = sf is TransitionFailure
          ? transitionErrorText(l, sf.error)
          : sf.message);
      return;
    }
    _next();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final couriers = ref.watch(couriersProvider).value ?? const <Courier>[];
    final done = _index >= _queue.length;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.fastCnEntry),
        actions: [
          if (!_loading && !done)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(child: Text(l.remainingCount(_queue.length - _index))),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : done
              ? EmptyState(
                  icon: Icons.task_alt,
                  title: l.allHaveCn,
                  action: FilledButton(onPressed: () => context.pop(), child: Text(l.ok)),
                )
              : _body(l, couriers, _queue[_index]),
    );
  }

  Widget _body(AppLocalizations l, List<Courier> couriers, OrderListItem item) {
    final o = item.order;
    return ListView(padding: const EdgeInsets.all(16), children: [
      Card(
        child: ListTile(
          title: Text('${o.orderNo} · ${item.customerName ?? '—'}'),
          subtitle: Text(o.addressSnapshot),
          trailing: Text(Money(o.codExpected).format(),
              style: Theme.of(context).textTheme.titleMedium),
        ),
      ),
      const SizedBox(height: 16),
      DropdownButtonFormField<String>(
        initialValue: couriers.any((c) => c.id == _courierId) ? _courierId : null,
        decoration: InputDecoration(labelText: l.courier),
        items: [for (final c in couriers) DropdownMenuItem(value: c.id, child: Text(c.name))],
        onChanged: (v) => setState(() => _courierId = v),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _cn,
        autofocus: true,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _save(o),
        decoration: InputDecoration(
          labelText: l.consignmentNo,
          suffixIcon: IconButton(
            tooltip: l.scanCn,
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: () async {
              final pattern = couriers
                  .where((c) => c.id == _courierId)
                  .map((c) => c.cnRegex)
                  .firstOrNull;
              final cn = await scanCn(context, ref, courierPattern: pattern);
              if (cn != null && mounted) setState(() => _cn.text = cn);
            },
          ),
        ),
      ),
      if (_error != null)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ),
      const SizedBox(height: 16),
      Row(children: [
        Expanded(child: OutlinedButton(onPressed: _next, child: Text(l.skip))),
        const SizedBox(width: 12),
        Expanded(child: FilledButton(onPressed: () => _save(o), child: Text(l.saveNext))),
      ]),
    ]);
  }
}
