import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:parcel_khata/core/db/app_database.dart';
import 'package:parcel_khata/core/money/money.dart';
import 'package:parcel_khata/core/time/providers.dart';
import 'package:parcel_khata/features/expenses/application/campaign_repository.dart';
import 'package:parcel_khata/features/expenses/domain/ad_allocator.dart';
import 'package:parcel_khata/features/orders/presentation/order_labels.dart';
import 'package:parcel_khata/l10n/l10n.dart';
import 'package:parcel_khata/shared/empty_state.dart';
import 'package:parcel_khata/shared/status_chip.dart';

final _campaignsProvider = StreamProvider<List<Campaign>>(
    (ref) => ref.watch(campaignRepositoryProvider).watchAll());

class CampaignsScreen extends ConsumerWidget {
  const CampaignsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final rows = ref.watch(_campaignsProvider);
    final repo = ref.read(campaignRepositoryProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l.campaignsTitle)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/campaigns/new'),
        icon: const Icon(Icons.add),
        label: Text(l.campaignNew),
      ),
      body: rows.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (list) => list.isEmpty
            ? EmptyState(icon: Icons.campaign_outlined, title: l.emptyDefaultTitle)
            : ListView.separated(
                itemCount: list.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final c = list[i];
                  return ListTile(
                    leading: const Icon(Icons.campaign_outlined),
                    title: Text(c.name),
                    subtitle: Text('#${c.tag} · ${formatDate(c.startDate)} – ${formatDate(c.endDate)}'),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(Money(c.spend).format()),
                        if (c.allocatedAt != null)
                          StatusChip(
                            label: repo.needsReapply(c) ? l.allocNeedsReapply : l.allocApply,
                            icon: repo.needsReapply(c) ? Icons.refresh : Icons.check,
                            tone: repo.needsReapply(c) ? StatusTone.warning : StatusTone.success,
                          ),
                      ],
                    ),
                    onTap: () => context.push('/campaigns/${c.id}'),
                  );
                },
              ),
      ),
    );
  }
}

/// Create/edit a campaign; when editing, also shows the allocation preview
/// table with Apply / Remove.
class CampaignScreen extends ConsumerStatefulWidget {
  const CampaignScreen({this.campaignId, super.key});

  final String? campaignId;

  @override
  ConsumerState<CampaignScreen> createState() => _CampaignScreenState();
}

class _CampaignScreenState extends ConsumerState<CampaignScreen> {
  final _name = TextEditingController();
  final _tag = TextEditingController();
  final _spend = TextEditingController();
  late DateTime _start;
  late DateTime _end;
  AllocationMode _mode = AllocationMode.byCount;
  bool _loaded = false;
  String? _error;
  String? _id;
  Campaign? _campaign;
  AllocationPreview? _preview;

  @override
  void initState() {
    super.initState();
    final now = ref.read(clockProvider).now();
    _start = DateTime(now.year, now.month);
    _end = DateTime(now.year, now.month, now.day);
    _id = widget.campaignId;
    if (_id == null) {
      _loaded = true;
    } else {
      _load();
    }
  }

  Future<void> _load() async {
    final repo = ref.read(campaignRepositoryProvider);
    final c = await repo.getById(_id!);
    if (c == null || !mounted) return;
    final p = await repo.preview(_id!);
    setState(() {
      _campaign = c;
      _name.text = c.name;
      _tag.text = c.tag;
      _spend.text = Money(c.spend).format(symbol: false, decimals: c.spend % 100 != 0);
      _start = c.startDate;
      _end = c.endDate;
      _mode = AllocationMode.fromDb(c.allocationMode);
      _preview = p;
      _loaded = true;
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _tag.dispose();
    _spend.dispose();
    super.dispose();
  }

  CampaignInput _input() => CampaignInput(
        name: _name.text,
        tag: _tag.text,
        start: _start,
        end: _end,
        spend: Money.tryParse(_spend.text) ?? Money.zero,
        mode: _mode,
      );

  Future<void> _save() async {
    final l = context.l10n;
    final repo = ref.read(campaignRepositoryProvider);
    final r = _id == null ? await repo.create(_input()) : await repo.update(_id!, _input());
    if (!mounted) return;
    final c = r.valueOrNull;
    if (c == null) {
      setState(() => _error = l.errNameRequired);
      return;
    }
    if (_id == null) {
      context.pushReplacement('/campaigns/${c.id}');
    } else {
      await _load();
    }
  }

  Future<void> _pick(bool start) async {
    final d = await showDatePicker(
      context: context,
      initialDate: start ? _start : _end,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (d != null) setState(() => start ? _start = d : _end = d);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final repo = ref.read(campaignRepositoryProvider);
    final p = _preview;
    return Scaffold(
      appBar: AppBar(
        title: Text(_id == null ? l.campaignNew : l.campaignEdit),
        actions: [
          TextButton(onPressed: _loaded ? _save : null, child: Text(l.save)),
          if (_id != null)
            IconButton(
              tooltip: l.deleteView,
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                await repo.delete(_id!);
                if (context.mounted) context.pop();
              },
            ),
        ],
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.all(16), children: [
              TextField(
                controller: _name,
                decoration: InputDecoration(labelText: l.campaignName, errorText: _error),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _tag,
                decoration: InputDecoration(
                  labelText: l.campaignTag,
                  helperText: l.campaignTagHelp,
                  prefixText: '#',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _spend,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: l.campaignSpend, prefixText: '৳ '),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pick(true),
                    icon: const Icon(Icons.event),
                    label: Text('${l.campaignStart}: ${formatDate(_start)}'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pick(false),
                    icon: const Icon(Icons.event),
                    label: Text('${l.campaignEnd}: ${formatDate(_end)}'),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              SegmentedButton<AllocationMode>(
                segments: [
                  ButtonSegment(value: AllocationMode.byCount, label: Text(l.allocByCount)),
                  ButtonSegment(value: AllocationMode.byRevenue, label: Text(l.allocByRevenue)),
                ],
                selected: {_mode},
                onSelectionChanged: (s) => setState(() => _mode = s.first),
              ),
              if (_id != null && p != null) ...[
                const SizedBox(height: 20),
                Text(l.allocPreview, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                if (p.orderCount == 0)
                  Text(l.allocNoOrders)
                else ...[
                  Text(l.taggedOrdersN(p.orderCount)),
                  const SizedBox(height: 8),
                  for (final o in p.orders.take(30))
                    ListTile(
                      dense: true,
                      title: Text(o.id.substring(o.id.length - 8)),
                      subtitle: Text(formatDate(o.orderDate)),
                      trailing: Text((p.shares[o.id] ?? Money.zero).format(decimals: true)),
                    ),
                  if (p.orderCount > 30) Text('+ ${p.orderCount - 30}'),
                ],
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: p.orderCount == 0
                          ? null
                          : () async {
                              final r = await repo.allocate(_id!);
                              if (!context.mounted) return;
                              final n = r.valueOrNull?.orderCount ?? 0;
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(SnackBar(content: Text(l.allocApplied(n))));
                              await _load();
                            },
                      child: Text(l.allocApply),
                    ),
                  ),
                  if (_campaign?.allocatedAt != null) ...[
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: () async {
                        await repo.clear(_id!);
                        await _load();
                      },
                      child: Text(l.allocClear),
                    ),
                  ],
                ]),
                if (_campaign != null && repo.needsReapply(_campaign!))
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(l.allocNeedsReapply,
                        style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ),
              ],
            ]),
    );
  }
}
