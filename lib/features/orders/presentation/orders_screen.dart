import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:parcel_khata/core/money/money.dart';
import 'package:parcel_khata/features/orders/application/order_repository.dart';
import 'package:parcel_khata/features/orders/domain/order_enums.dart';
import 'package:parcel_khata/features/orders/presentation/order_labels.dart';
import 'package:parcel_khata/l10n/l10n.dart';
import 'package:parcel_khata/shared/empty_state.dart';
import 'package:parcel_khata/shared/status_chip.dart';

final draftCountProvider = StreamProvider<int>((ref) async* {
  final repo = ref.watch(orderRepositoryProvider);
  yield await repo.draftCount();
  await for (final _ in repo.changes) {
    yield await repo.draftCount();
  }
});

/// Order list with keyset pagination, status/date/channel filters.
/// [customerId] restricts to one customer and shows a back button.
class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({this.customerId, super.key});

  final String? customerId;

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> {
  static const _statusFilters = [
    OrderStatus.confirmed,
    OrderStatus.packed,
    OrderStatus.handedToCourier,
    OrderStatus.inTransit,
    OrderStatus.delivered,
    OrderStatus.deliveryFailed,
    OrderStatus.returnInTransit,
    OrderStatus.returned,
    OrderStatus.cancelled,
  ];

  final _scroll = ScrollController();
  final List<OrderListItem> _items = [];
  late OrderFilter _filter;
  late final OrderRepository _repo;
  StreamSubscription<void>? _sub;
  bool _loading = false;
  bool _end = false;
  bool _firstLoad = true;
  int _token = 0;

  @override
  void initState() {
    super.initState();
    _repo = ref.read(orderRepositoryProvider);
    _filter = OrderFilter(customerId: widget.customerId);
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 400) {
        unawaited(_loadMore());
      }
    });
    _sub = _repo.changes.listen((_) => unawaited(_reload()));
    unawaited(_reload());
  }

  @override
  void dispose() {
    _sub?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    final token = ++_token;
    final want = _items.length < OrderRepository.pageSize
        ? OrderRepository.pageSize
        : _items.length;
    final page = await _repo.fetchPage(filter: _filter, limit: want);
    if (!mounted || token != _token) return;
    setState(() {
      _items
        ..clear()
        ..addAll(page);
      _end = page.length < want;
      _firstLoad = false;
    });
  }

  Future<void> _loadMore() async {
    if (_loading || _end || _items.isEmpty) return;
    _loading = true;
    final last = _items.last.order;
    final token = _token;
    final page = await _repo.fetchPage(
        filter: _filter, after: OrderCursor(last.orderDate, last.id));
    _loading = false;
    if (!mounted || token != _token) return;
    setState(() {
      _items.addAll(page);
      _end = page.length < OrderRepository.pageSize;
    });
  }

  void _setFilter(OrderFilter f) {
    _filter = f;
    _items.clear();
    _end = false;
    _firstLoad = true;
    unawaited(_reload());
  }

  Future<void> _pickDates() async {
    final now = DateTime.now();
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year + 1),
      initialDateRange: _filter.from == null
          ? null
          : DateTimeRange(
              start: _filter.from!,
              end: _filter.to!.subtract(const Duration(days: 1))),
    );
    if (r == null) return;
    _setFilter(_filter.copyWith(
        from: DateTime(r.start.year, r.start.month, r.start.day),
        to: DateTime(r.end.year, r.end.month, r.end.day).add(const Duration(days: 1))));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final drafts = ref.watch(draftCountProvider).value ?? 0;
    final selected = _filter.statuses;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.ordersTitle),
        actions: [
          if (widget.customerId == null)
            IconButton(
              tooltip: l.drafts,
              onPressed: () => context.push('/orders/drafts'),
              icon: Badge(
                isLabelVisible: drafts > 0,
                label: Text('$drafts'),
                child: const Icon(Icons.edit_note),
              ),
            ),
          IconButton(
            tooltip: l.filterDates,
            onPressed: _pickDates,
            icon: Icon(Icons.date_range,
                color: _filter.from != null ? Theme.of(context).colorScheme.primary : null),
          ),
          PopupMenuButton<Channel?>(
            tooltip: l.filterChannel,
            icon: Icon(Icons.filter_list,
                color: _filter.channel != null ? Theme.of(context).colorScheme.primary : null),
            onSelected: (c) => _setFilter(c == null
                ? _filter.copyWith(clearChannel: true)
                : _filter.copyWith(channel: c)),
            itemBuilder: (_) => [
              PopupMenuItem<Channel?>(child: Text(l.statusAll)),
              for (final c in Channel.values)
                PopupMenuItem<Channel?>(value: c, child: Text(channelLabel(l, c))),
            ],
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'deleted') context.push('/orders/deleted');
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'deleted', child: Text(l.recentlyDeleted)),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/orders/new'),
        icon: const Icon(Icons.add),
        label: Text(l.orderNew),
      ),
      body: Column(children: [
        SizedBox(
          height: 56,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(l.statusAll),
                  selected: selected.isEmpty,
                  onSelected: (_) => _setFilter(_filter.copyWith(statuses: <OrderStatus>{})),
                ),
              ),
              for (final s in _statusFilters)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    avatar: Icon(statusIcon(s), size: 18),
                    label: Text(statusLabel(l, s)),
                    selected: selected.contains(s),
                    onSelected: (_) => _setFilter(_filter.copyWith(statuses: {s})),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: _firstLoad && _items.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : _items.isEmpty
                  ? EmptyState(icon: Icons.receipt_long_outlined, title: l.noOrders)
                  : ListView.separated(
                      controller: _scroll,
                      itemCount: _items.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) => OrderTile(item: _items[i]),
                    ),
        ),
      ]),
    );
  }
}

class OrderTile extends StatelessWidget {
  const OrderTile({required this.item, this.trailing, this.onTap, super.key});

  final OrderListItem item;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final o = item.order;
    final status = OrderStatus.fromDb(o.status);
    final cod = CodStatus.fromDb(o.codStatus);
    return ListTile(
      onTap: onTap ?? () => context.push('/orders/${o.id}'),
      title: Text('${o.orderNo} · ${item.customerName ?? '—'}'),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Wrap(spacing: 6, runSpacing: 4, children: [
          StatusChip(
              label: statusLabel(l, status),
              icon: statusIcon(status),
              tone: statusTone(status)),
          if (cod != CodStatus.notApplicable && status != OrderStatus.draft)
            StatusChip(
                label: codLabel(l, cod), icon: Icons.payments_outlined, tone: codTone(cod)),
        ]),
      ),
      trailing: trailing ??
          Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(Money(o.codExpected).format(),
                style: Theme.of(context).textTheme.titleMedium),
            Text(formatDate(o.orderDate), style: Theme.of(context).textTheme.bodySmall),
          ]),
    );
  }
}
