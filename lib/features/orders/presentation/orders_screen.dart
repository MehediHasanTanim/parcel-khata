import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:parcel_khata/core/money/money.dart';
import 'package:parcel_khata/core/time/providers.dart';
import 'package:parcel_khata/features/couriers/domain/stuck_parcel_policy.dart';
import 'package:parcel_khata/features/orders/application/order_repository.dart';
import 'package:parcel_khata/features/orders/application/order_status_service.dart';
import 'package:parcel_khata/features/orders/domain/order_enums.dart';
import 'package:parcel_khata/features/orders/presentation/order_labels.dart';
import 'package:parcel_khata/features/orders/presentation/status_actions.dart';
import 'package:parcel_khata/features/profit/presentation/profit_panel.dart';
import 'package:parcel_khata/features/settings/application/settings_repository.dart';
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

/// Order list with keyset pagination, filters, multi-select bulk actions and
/// swipe shortcuts. [customerId] restricts to one customer.
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
  final Set<String> _selected = {};
  late OrderFilter _filter;
  late final OrderRepository _repo;
  StreamSubscription<void>? _sub;
  bool _loading = false;
  bool _end = false;
  bool _firstLoad = true;
  bool _stuckOnly = false;
  int _token = 0;

  bool get _selecting => _selected.isNotEmpty;

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
    if (_stuckOnly) {
      final stuck = await ref.read(orderStatusServiceProvider).stuckOrders();
      final rows = await _repo.fetchByIds(stuck.map((s) => s.order.id).toList());
      // Keep worst-first order from the stuck query.
      final byId = {for (final r in rows) r.order.id: r};
      if (!mounted || token != _token) return;
      setState(() {
        _items
          ..clear()
          ..addAll([for (final s in stuck) if (byId[s.order.id] != null) byId[s.order.id]!]);
        _end = true;
        _firstLoad = false;
      });
      return;
    }
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
      _selected.removeWhere((id) => !_items.any((i) => i.order.id == id));
    });
  }

  Future<void> _loadMore() async {
    if (_loading || _end || _items.isEmpty || _stuckOnly) return;
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

  void _setFilter(OrderFilter f, {bool? stuck}) {
    _filter = f;
    if (stuck != null) _stuckOnly = stuck;
    _items.clear();
    _selected.clear();
    _end = false;
    _firstLoad = true;
    unawaited(_reload());
  }

  Future<void> _pickDates() async {
    final now = ref.read(clockProvider).now();
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

  // -------------------------------------------------------------- bulk

  Future<void> _bulk(OrderStatus to) async {
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final service = ref.read(orderStatusServiceProvider);
    StatusParams? params;
    if (to == OrderStatus.deliveryFailed || to == OrderStatus.cancelled) {
      params = await showStatusParamsSheet(context,
          to: to, now: ref.read(clockProvider).now());
      if (params == null) return;
    }
    final result = await service.bulkChange(
      _selected.toList(),
      to: to,
      at: params?.at,
      reason: params?.reason,
      note: params?.note,
    );
    if (!mounted) return;
    setState(_selected.clear);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(l.bulkSummary(result.changedIds.length, result.skipped.length)),
        duration: const Duration(seconds: 8),
        action: result.undoToken == null
            ? null
            : SnackBarAction(
                label: l.undo,
                onPressed: () => unawaited(service.undo(result.undoToken!)),
              ),
      ));
  }

  Future<void> _swipe(OrderListItem item, OrderStatus to) async {
    final messenger = ScaffoldMessenger.of(context);
    final l = context.l10n;
    final service = ref.read(orderStatusServiceProvider);
    final o = item.order;
    final machine = await service.machine();
    if (!mounted) return;
    if (!machine.allowedNext(OrderStatus.fromDb(o.status)).contains(to)) {
      messenger.showSnackBar(SnackBar(content: Text(l.errNotAllowed)));
      return;
    }
    await runStatusAction(context, ref, order: o, to: to);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final drafts = ref.watch(draftCountProvider).value ?? 0;
    final selected = _filter.statuses;
    final primary = Theme.of(context).colorScheme.primary;
    return Scaffold(
      appBar: _selecting
          ? AppBar(
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(_selected.clear),
              ),
              title: Text(l.selectedCount(_selected.length)),
              actions: [
                TextButton(
                  onPressed: () => setState(() =>
                      _selected.addAll(_items.map((i) => i.order.id))),
                  child: Text(l.selectAll),
                ),
              ],
            )
          : AppBar(
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
                      color: _filter.from != null ? primary : null),
                ),
                PopupMenuButton<Channel?>(
                  tooltip: l.filterChannel,
                  icon: Icon(Icons.filter_list,
                      color: _filter.channel != null ? primary : null),
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
                    if (v == 'cn') context.push('/orders/cn-entry');
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(value: 'cn', child: Text(l.fastCnEntry)),
                    PopupMenuItem(value: 'deleted', child: Text(l.recentlyDeleted)),
                  ],
                ),
              ],
            ),
      floatingActionButton: _selecting
          ? null
          : FloatingActionButton.extended(
              onPressed: () => context.push('/orders/new'),
              icon: const Icon(Icons.add),
              label: Text(l.orderNew),
            ),
      bottomNavigationBar: !_selecting
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Row(children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _bulk(OrderStatus.handedToCourier),
                      icon: const Icon(Icons.local_shipping_outlined),
                      label: Text(l.statusHanded),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _bulk(OrderStatus.delivered),
                      icon: const Icon(Icons.done_all),
                      label: Text(l.statusDelivered),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _bulk(OrderStatus.deliveryFailed),
                      icon: const Icon(Icons.error_outline),
                      label: Text(l.statusFailed),
                    ),
                  ),
                ]),
              ),
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
                  selected: selected.isEmpty && !_stuckOnly,
                  onSelected: (_) =>
                      _setFilter(_filter.copyWith(statuses: <OrderStatus>{}), stuck: false),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  avatar: const Icon(Icons.hourglass_bottom, size: 18),
                  label: Text(l.stuckParcels),
                  selected: _stuckOnly,
                  onSelected: (v) =>
                      _setFilter(_filter.copyWith(statuses: <OrderStatus>{}), stuck: v),
                ),
              ),
              for (final s in _statusFilters)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    avatar: Icon(statusIcon(s), size: 18),
                    label: Text(statusLabel(l, s)),
                    selected: selected.contains(s) && !_stuckOnly,
                    onSelected: (_) => _setFilter(_filter.copyWith(statuses: {s}), stuck: false),
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
                      itemBuilder: (_, i) {
                        final item = _items[i];
                        final id = item.order.id;
                        final tile = OrderTile(
                          item: item,
                          selected: _selected.contains(id),
                          onLongPress: () => setState(() => _selected.add(id)),
                          onTap: _selecting
                              ? () => setState(() {
                                    if (!_selected.remove(id)) _selected.add(id);
                                  })
                              : null,
                        );
                        if (_selecting) return tile;
                        // Swipe right = delivered, swipe left = hand to courier.
                        return Dismissible(
                          key: ValueKey(id),
                          background: _swipeBg(context, Alignment.centerLeft,
                              Icons.done_all, l.statusDelivered),
                          secondaryBackground: _swipeBg(context, Alignment.centerRight,
                              Icons.local_shipping_outlined, l.statusHanded),
                          confirmDismiss: (dir) async {
                            await _swipe(
                                item,
                                dir == DismissDirection.startToEnd
                                    ? OrderStatus.delivered
                                    : OrderStatus.handedToCourier);
                            return false;
                          },
                          child: tile,
                        );
                      },
                    ),
        ),
      ]),
    );
  }

  Widget _swipeBg(BuildContext c, Alignment a, IconData icon, String label) => Container(
        color: Theme.of(c).colorScheme.primaryContainer,
        alignment: a,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon), const SizedBox(width: 8), Text(label)]),
      );
}

class OrderTile extends ConsumerWidget {
  const OrderTile({
    required this.item,
    this.trailing,
    this.onTap,
    this.onLongPress,
    this.selected = false,
    super.key,
  });

  final OrderListItem item;
  final Widget? trailing;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final o = item.order;
    final status = OrderStatus.fromDb(o.status);
    final cod = CodStatus.fromDb(o.codStatus);
    final now = ref.watch(clockProvider).now();
    final hideProfit = ref.watch(shopSettingsProvider).value?.hideProfitInLists ?? false;
    final stuck = StuckParcelPolicy.level(
      status: status,
      handedOverAt: o.handedOverAt,
      now: now,
      stuckDays: item.courierStuckDays ?? 0,
    );
    return ListTile(
      selected: selected,
      selectedTileColor: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.4),
      onTap: onTap ?? () => context.push('/orders/${o.id}'),
      onLongPress: onLongPress,
      leading: selected ? const Icon(Icons.check_circle) : null,
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
          if (!hideProfit && status != OrderStatus.draft)
            ProfitChip(profit: o.profit, stateDb: o.profitState),
          if (stuck != StuckLevel.none)
            StatusChip(
              label: l.withCourierDays(
                  StuckParcelPolicy.daysWithCourier(o.handedOverAt!, now)),
              icon: Icons.hourglass_bottom,
              tone: stuck == StuckLevel.red ? StatusTone.danger : StatusTone.warning,
            ),
        ]),
      ),
      trailing: trailing ??
          Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(Money(o.codExpected).format(),
                    style: Theme.of(context).textTheme.titleMedium),
                Text(formatDate(o.orderDate), style: Theme.of(context).textTheme.bodySmall),
              ]),
    );
  }
}
