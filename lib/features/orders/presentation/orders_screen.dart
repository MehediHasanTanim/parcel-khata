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
import 'package:parcel_khata/features/reports/application/dashboard_service.dart';
import 'package:parcel_khata/features/reports/presentation/format.dart';
import 'package:parcel_khata/features/search/presentation/order_filter_sheet.dart';
import 'package:parcel_khata/features/search/presentation/saved_views_sheet.dart';
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

/// Filters/sort of the main Orders tab survive navigating into an order and
/// back (feature spec F10 AC2).
class OrdersFilterNotifier extends Notifier<OrderFilter> {
  @override
  OrderFilter build() => const OrderFilter();

  // ignore: use_setters_to_change_properties
  void set(OrderFilter f) => state = f;
}

final ordersFilterProvider =
    NotifierProvider<OrdersFilterNotifier, OrderFilter>(OrdersFilterNotifier.new);

class OrdersSortNotifier extends Notifier<OrderSort> {
  @override
  OrderSort build() => OrderSort.newest;

  // ignore: use_setters_to_change_properties
  void set(OrderSort s) => state = s;
}

final ordersSortProvider =
    NotifierProvider<OrdersSortNotifier, OrderSort>(OrdersSortNotifier.new);

/// Order list with keyset pagination, search, filters, sort, multi-select
/// bulk actions and swipe shortcuts. [customerId] restricts to one customer;
/// [initialFilter]/[title]/[measure] make it a dashboard drill-down.
class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({
    this.customerId,
    this.initialFilter,
    this.title,
    this.measure,
    this.stuck = false,
    super.key,
  });

  final String? customerId;
  final OrderFilter? initialFilter;
  final String? title;
  final Measure? measure;
  final bool stuck;

  bool get _isMainTab =>
      customerId == null && initialFilter == null && !stuck;

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
  OrderSort _sort = OrderSort.newest;
  final _searchCtl = TextEditingController();
  Timer? _debounce;
  FilterTotals? _totals;
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
    _filter = widget.initialFilter ??
        (widget.customerId != null
            ? OrderFilter(customerId: widget.customerId)
            : ref.read(ordersFilterProvider));
    if (widget._isMainTab) _sort = ref.read(ordersSortProvider);
    _stuckOnly = widget.stuck;
    _searchCtl.text = _filter.query;
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
    _debounce?.cancel();
    _searchCtl.dispose();
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
    final page = await _repo.fetchPage(filter: _filter, limit: want, sort: _sort);
    final totals = widget.measure == null ? null : await _repo.totals(_filter);
    if (!mounted || token != _token) return;
    _totals = totals;
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
    final keyset = _sort == OrderSort.newest || _sort == OrderSort.oldest;
    final page = await _repo.fetchPage(
      filter: _filter,
      sort: _sort,
      after: keyset ? OrderCursor(last.orderDate, last.id) : null,
      offset: keyset ? 0 : _items.length,
    );
    _loading = false;
    if (!mounted || token != _token) return;
    setState(() {
      _items.addAll(page);
      _end = page.length < OrderRepository.pageSize;
    });
  }

  void _setFilter(OrderFilter f, {bool? stuck}) {
    _filter = f;
    if (widget._isMainTab) ref.read(ordersFilterProvider.notifier).set(f);
    if (stuck != null) _stuckOnly = stuck;
    _items.clear();
    _selected.clear();
    _end = false;
    _firstLoad = true;
    unawaited(_reload());
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

  String _sortLabel(AppLocalizations l, OrderSort v) => switch (v) {
        OrderSort.newest => l.sortNewest,
        OrderSort.oldest => l.sortOldest,
        OrderSort.amountHigh => l.sortAmount,
        OrderSort.profitHigh || OrderSort.profitLow => l.sortProfit,
        OrderSort.daysSinceDispatch => l.sortDispatch,
      };

  Future<void> _submitSearch(String v) async {
    final id = await _repo.exactOrderId(v);
    if (!mounted) return;
    if (id != null) {
      // A pasted/scanned CN or order number opens its order directly.
      await context.push('/orders/$id');
    } else {
      _setFilter(_filter.copyWith(query: v.trim()));
    }
  }

  Future<void> _openFilters() async {
    final f = await showOrderFilterSheet(context, _filter);
    if (f != null) _setFilter(f.copyWith(query: _filter.query));
  }

  Future<void> _openViews() async {
    final v = await showSavedViewsSheet(context, current: _filter, sort: _sort);
    if (v == null) return;
    _searchCtl.text = v.filter.query;
    setState(() => _sort = v.sort);
    _setFilter(v.filter, stuck: false);
  }

  /// One removable chip per active constraint.
  List<Widget> _activeChips(AppLocalizations l) {
    Widget chip(String label, OrderFilter cleared) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: InputChip(
            label: Text(label),
            onDeleted: () => _setFilter(cleared),
          ),
        );
    final f = _filter;
    final out = <Widget>[];
    for (final s in f.statuses) {
      if (f.statuses.length == 1 && !_stuckOnly) continue; // shown by the status row
      out.add(chip(statusLabel(l, s),
          f.copyWith(statuses: {...f.statuses}..remove(s))));
    }
    for (final c in f.codStatuses) {
      out.add(chip(codLabel(l, c), f.copyWith(codStatuses: {...f.codStatuses}..remove(c))));
    }
    if (f.channel != null) {
      out.add(chip(channelLabel(l, f.channel!), f.copyWith(clearChannel: true)));
    }
    if (f.paymentType != null) {
      out.add(chip(paymentLabel(l, f.paymentType!), f.copyWith(clearPaymentType: true)));
    }
    if (f.courierId != null) out.add(chip(l.courier, f.copyWith(clearCourier: true)));
    if (f.from != null) {
      out.add(chip('${formatDate(f.from!)} – ${formatDate(f.to!.subtract(const Duration(days: 1)))}',
          f.copyWith(clearDates: true)));
    }
    if (f.dispatchFrom != null) {
      out.add(chip(l.dispatchDates, f.copyWith(clearDispatch: true)));
    }
    if (f.deliveredFrom != null || f.deliveredOlderThanDays != null) {
      out.add(chip(l.deliveredDates, f.copyWith(clearDelivered: true)));
    }
    if (f.profitSign != null) {
      out.add(chip(f.profitSign == ProfitSign.profit ? l.profitOnly : l.lossOnly,
          f.copyWith(clearProfitSign: true)));
    }
    if (f.amountMinPoisha != null || f.amountMaxPoisha != null) {
      out.add(chip(l.amountMin, f.copyWith(clearAmount: true)));
    }
    if (f.tag != null) out.add(chip('#${f.tag}', f.copyWith(clearTag: true)));
    if (f.area != null) out.add(chip(f.area!, f.copyWith(clearArea: true)));
    if (f.hasReturn != null) out.add(chip(l.hasReturnLabel, f.copyWith(clearHasReturn: true)));
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final drafts = ref.watch(draftCountProvider).value ?? 0;
    final selected = _filter.statuses;
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
              title: Text(widget.title ?? l.ordersTitle),
              actions: [
                if (widget._isMainTab)
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
                  tooltip: l.filtersTitle,
                  onPressed: _openFilters,
                  icon: Badge(
                    isLabelVisible: _filter.activeCount > 0,
                    label: Text('${_filter.activeCount}'),
                    child: const Icon(Icons.filter_list),
                  ),
                ),
                PopupMenuButton<OrderSort>(
                  tooltip: l.sortLabel,
                  icon: const Icon(Icons.sort),
                  onSelected: (v) {
                    setState(() => _sort = v);
                    if (widget._isMainTab) ref.read(ordersSortProvider.notifier).set(v);
                    _setFilter(_filter);
                  },
                  itemBuilder: (_) => [
                    for (final v in OrderSort.values.where((v) => v != OrderSort.profitLow))
                      CheckedPopupMenuItem(
                        value: v,
                        checked: _sort == v,
                        child: Text(_sortLabel(l, v)),
                      ),
                  ],
                ),
                IconButton(
                  tooltip: l.savedViews,
                  icon: const Icon(Icons.bookmarks_outlined),
                  onPressed: _openViews,
                ),
                if (widget._isMainTab)
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
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: TextField(
            controller: _searchCtl,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: l.searchOrders,
              isDense: true,
              suffixIcon: _searchCtl.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchCtl.clear();
                        _setFilter(_filter.copyWith(query: ''));
                      },
                    ),
            ),
            onChanged: (v) {
              _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 250), () {
                if (mounted) _setFilter(_filter.copyWith(query: v.trim()));
              });
              setState(() {});
            },
            onSubmitted: _submitSearch,
          ),
        ),
        if (_totals != null && widget.measure != null)
          Container(
            width: double.infinity,
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              '${l.ordersCountHeader(_totals!.count)} · '
              '${formatMeasure(widget.measure!, measureValue(widget.measure!, _totals!))}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
        if (_activeChips(l).isNotEmpty)
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              children: _activeChips(l),
            ),
          ),
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
                  ? EmptyState(
                      icon: Icons.receipt_long_outlined,
                      title: l.noOrders,
                      message: l.emptyOrdersHint,
                      action: widget._isMainTab && _filter.activeCount == 0
                          ? FilledButton.icon(
                              onPressed: () => context.push('/orders/new'),
                              icon: const Icon(Icons.add),
                              label: Text(l.emptyOrdersCta),
                            )
                          : null,
                    )
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
          if (o.exchangeOfOrderId != null)
            StatusChip(
                label: l.exchangeChip,
                icon: Icons.swap_horiz,
                tone: StatusTone.neutral),
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
