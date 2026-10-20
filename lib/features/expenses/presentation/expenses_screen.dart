import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:parcel_khata/core/db/app_database.dart';
import 'package:parcel_khata/core/money/money.dart';
import 'package:parcel_khata/core/time/providers.dart';
import 'package:parcel_khata/features/expenses/application/campaign_repository.dart';
import 'package:parcel_khata/features/expenses/application/expense_repository.dart';
import 'package:parcel_khata/features/expenses/domain/business_pnl.dart';
import 'package:parcel_khata/features/orders/presentation/order_labels.dart';
import 'package:parcel_khata/l10n/l10n.dart';
import 'package:parcel_khata/shared/empty_state.dart';
import 'package:lucide_icons_flutter/lucide_icons_300.dart';

String categoryLabel(AppLocalizations l, ExpenseCategory c) => switch (c) {
      ExpenseCategory.ads => l.catAds,
      ExpenseCategory.packaging => l.catPackaging,
      ExpenseCategory.rent => l.catRent,
      ExpenseCategory.salary => l.catSalary,
      ExpenseCategory.misc => l.catMisc,
    };

IconData categoryIcon(ExpenseCategory c) => switch (c) {
      ExpenseCategory.ads => LucideIcons300.megaphone,
      ExpenseCategory.packaging => LucideIcons300.package,
      ExpenseCategory.rent => LucideIcons300.warehouse,
      ExpenseCategory.salary => LucideIcons300.idCard,
      ExpenseCategory.misc => LucideIcons300.shapes,
    };

final _monthExpensesProvider = StreamProvider.family<List<Expense>, DateTime>((ref, month) {
  return ref
      .watch(expenseRepositoryProvider)
      .watch(from: month, to: DateTime(month.year, month.month + 1));
});

class ExpensesScreen extends ConsumerStatefulWidget {
  const ExpensesScreen({super.key});

  @override
  ConsumerState<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends ConsumerState<ExpensesScreen> {
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    final now = ref.read(clockProvider).now();
    _month = DateTime(now.year, now.month);
    // Bring in this month's copies of recurring expenses.
    unawaited(ref.read(expenseRepositoryProvider).materializeRecurring().then((n) {
      if (n > 0 && mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(context.l10n.expenseRecurringAdded(n))));
      }
    }));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final rows = ref.watch(_monthExpensesProvider(_month));
    return Scaffold(
      appBar: AppBar(
        title: Text(l.expensesTitle),
        actions: [
          IconButton(
            tooltip: l.periodLastMonth,
            icon: const Icon(LucideIcons300.chevronLeft),
            onPressed: () => setState(() => _month = DateTime(_month.year, _month.month - 1)),
          ),
          Center(child: Text('${_month.month}/${_month.year}')),
          IconButton(
            icon: const Icon(LucideIcons300.chevronRight),
            onPressed: () => setState(() => _month = DateTime(_month.year, _month.month + 1)),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showExpenseSheet(context, ref),
        icon: const Icon(LucideIcons300.plus),
        label: Text(l.expenseNew),
      ),
      body: rows.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (list) {
          if (list.isEmpty) {
            return EmptyState(icon: LucideIcons300.banknote, title: l.emptyDefaultTitle);
          }
          final total = list.fold(0, (s, e) => s + e.amount);
          return ListView(children: [
            ListTile(
              title: Text(l.expenseTotal, style: Theme.of(context).textTheme.titleMedium),
              trailing: Text(Money(total).format(),
                  style: Theme.of(context).textTheme.titleMedium),
            ),
            const Divider(height: 1),
            for (final e in list)
              ListTile(
                leading: Icon(categoryIcon(ExpenseCategory.fromDb(e.category))),
                title: Text(categoryLabel(l, ExpenseCategory.fromDb(e.category))),
                subtitle: Text([
                  formatDate(e.date),
                  if (e.note != null) e.note!,
                  if (e.recurringMonthly || e.recurringSourceId != null) '↻',
                ].join(' · ')),
                trailing: Text(Money(e.amount).format()),
                onTap: () => showExpenseSheet(context, ref, existing: e),
              ),
          ]);
        },
      ),
    );
  }
}

/// Add / edit sheet: amount, category chips, date, optional campaign.
Future<void> showExpenseSheet(BuildContext context, WidgetRef ref, {Expense? existing}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _ExpenseSheet(existing: existing),
  );
}

class _ExpenseSheet extends ConsumerStatefulWidget {
  const _ExpenseSheet({this.existing});

  final Expense? existing;

  @override
  ConsumerState<_ExpenseSheet> createState() => _ExpenseSheetState();
}

class _ExpenseSheetState extends ConsumerState<_ExpenseSheet> {
  late final TextEditingController _amount = TextEditingController(
      text: widget.existing == null
          ? ''
          : Money(widget.existing!.amount)
              .format(symbol: false, decimals: widget.existing!.amount % 100 != 0));
  late final TextEditingController _note =
      TextEditingController(text: widget.existing?.note ?? '');
  late ExpenseCategory _cat = widget.existing == null
      ? ExpenseCategory.ads
      : ExpenseCategory.fromDb(widget.existing!.category);
  late DateTime _date = widget.existing?.date ?? ref.read(clockProvider).now();
  late String? _campaignId = widget.existing?.campaignId;
  late bool _recurring = widget.existing?.recurringMonthly ?? false;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l = context.l10n;
    final amount = Money.tryParse(_amount.text);
    if (amount == null || amount.poisha <= 0) {
      setState(() => _error = l.errInvalidAmount);
      return;
    }
    final input = ExpenseInput(
      date: _date,
      category: _cat,
      amount: amount,
      note: _note.text,
      campaignId: _cat == ExpenseCategory.ads ? _campaignId : null,
      recurringMonthly: _recurring,
    );
    final repo = ref.read(expenseRepositoryProvider);
    final r = widget.existing == null
        ? await repo.create(input)
        : await repo.update(widget.existing!.id, input);
    if (!mounted) return;
    if (r.isOk) {
      Navigator.pop(context);
    } else {
      setState(() => _error = l.errInvalidAmount);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final campaigns = ref.watch(_campaignsProvider).value ?? const <Campaign>[];
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
            16, 16, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.existing == null ? l.expenseNew : l.expenseEdit,
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            TextField(
              controller: _amount,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: Theme.of(context).textTheme.titleLarge,
              decoration: InputDecoration(
                  labelText: l.expenseAmount, prefixText: '৳ ', errorText: _error),
            ),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final c in ExpenseCategory.values)
                ChoiceChip(
                  avatar: Icon(categoryIcon(c), size: 18),
                  label: Text(categoryLabel(l, c)),
                  selected: _cat == c,
                  onSelected: (_) => setState(() => _cat = c),
                ),
            ]),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(LucideIcons300.calendar),
              title: Text(l.expenseDate),
              subtitle: Text(formatDate(_date)),
              onTap: () async {
                final now = ref.read(clockProvider).now();
                final d = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(now.year - 3),
                  lastDate: now,
                );
                if (d != null) setState(() => _date = d);
              },
            ),
            if (_cat == ExpenseCategory.ads && campaigns.isNotEmpty)
              DropdownButtonFormField<String?>(
                initialValue: campaigns.any((c) => c.id == _campaignId) ? _campaignId : null,
                decoration: InputDecoration(labelText: l.expenseCampaign),
                items: [
                  DropdownMenuItem<String?>(child: Text(l.none)),
                  for (final c in campaigns)
                    DropdownMenuItem<String?>(value: c.id, child: Text(c.name)),
                ],
                onChanged: (v) => setState(() => _campaignId = v),
              ),
            const SizedBox(height: 8),
            TextField(controller: _note, decoration: InputDecoration(labelText: l.expenseNote)),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l.expenseRecurring),
              value: _recurring,
              onChanged: (v) => setState(() => _recurring = v),
            ),
            Row(children: [
              if (widget.existing != null)
                TextButton(
                  onPressed: () async {
                    await ref.read(expenseRepositoryProvider).delete(widget.existing!.id);
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: Text(l.deleteView),
                ),
              const Spacer(),
              FilledButton(onPressed: _save, child: Text(l.save)),
            ]),
          ],
        ),
      ),
    );
  }
}

final _campaignsProvider = StreamProvider<List<Campaign>>(
    (ref) => ref.watch(campaignRepositoryProvider).watchAll());
