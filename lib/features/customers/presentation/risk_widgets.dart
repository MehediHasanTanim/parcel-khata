import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:parcel_khata/core/db/app_database.dart';
import 'package:parcel_khata/core/db/providers.dart';
import 'package:parcel_khata/features/customers/application/customer_repository.dart';
import 'package:parcel_khata/features/customers/application/customer_risk_queries.dart';
import 'package:parcel_khata/features/customers/domain/customer_risk.dart';
import 'package:parcel_khata/l10n/l10n.dart';

String riskBadgeLabel(AppLocalizations l, RiskBadgeKind k) => switch (k) {
      RiskBadgeKind.reliable => l.riskReliable,
      RiskBadgeKind.refusedLastCod => l.riskRefusedLastCod,
      RiskBadgeKind.highReturnRate => l.riskHighReturnRate,
      RiskBadgeKind.newCustomer => l.riskNewCustomer,
      RiskBadgeKind.blocklisted => l.riskBlocklisted,
    };

IconData _icon(RiskBadgeKind k) => switch (k) {
      RiskBadgeKind.reliable => Icons.verified_outlined,
      RiskBadgeKind.refusedLastCod => Icons.assignment_return_outlined,
      RiskBadgeKind.highReturnRate => Icons.trending_up,
      RiskBadgeKind.newCustomer => Icons.fiber_new_outlined,
      RiskBadgeKind.blocklisted => Icons.block,
    };

Color _color(BuildContext c, RiskBadgeKind k) {
  final s = Theme.of(c).colorScheme;
  return switch (k) {
    RiskBadgeKind.reliable => Colors.green.shade700,
    RiskBadgeKind.newCustomer => s.primary,
    _ => s.error,
  };
}

/// Chips for a customer's badges; tapping one lists the orders behind it.
class RiskBadgeWrap extends StatelessWidget {
  const RiskBadgeWrap({required this.badges, this.onTap, super.key});

  final List<RiskBadge> badges;
  final void Function(RiskBadge badge)? onTap;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Wrap(spacing: 6, runSpacing: 4, children: [
      for (final b in badges)
        ActionChip(
          visualDensity: VisualDensity.compact,
          avatar: Icon(_icon(b.kind), size: 16, color: _color(context, b.kind)),
          label: Text(riskBadgeLabel(l, b.kind)),
          onPressed: onTap == null ? null : () => onTap!(b),
        ),
    ]);
  }
}

/// Transparency rule: every badge can show the orders that caused it.
Future<void> showRiskBadgeOrders(
    BuildContext context, WidgetRef ref, RiskBadge badge) async {
  final db = ref.read(databaseProvider);
  final rows = badge.orderIds.isEmpty
      ? <Order>[]
      : await (db.select(db.orders)
            ..where((o) => o.id.isIn(badge.orderIds))
            ..orderBy([(o) => OrderingTerm.desc(o.orderDate)]))
          .get();
  if (!context.mounted) return;
  final l = context.l10n;
  await showModalBottomSheet<void>(
    context: context,
    builder: (ctx) => SafeArea(
      child: ListView(shrinkWrap: true, children: [
        ListTile(
          title: Text(riskBadgeLabel(l, badge.kind),
              style: Theme.of(ctx).textTheme.titleMedium),
          subtitle: Text(l.riskWhyTitle),
        ),
        if (rows.isEmpty)
          ListTile(title: Text(l.riskNoOrders))
        else
          for (final o in rows)
            ListTile(
              leading: const Icon(Icons.receipt_long_outlined),
              title: Text(o.orderNo),
              subtitle: Text(o.status),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pop(ctx);
                context.push('/orders/${o.id}');
              },
            ),
      ]),
    ),
  );
}

/// Inline badges for list rows; loads lazily and stays silent while loading.
class RiskBadgesInline extends ConsumerWidget {
  const RiskBadgesInline({required this.customerId, super.key});

  final String customerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final risk = ref.watch(customerRiskProvider(customerId)).value;
    if (risk == null || risk.badges.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: RiskBadgeWrap(
        badges: risk.badges,
        onTap: (b) => showRiskBadgeOrders(context, ref, b),
      ),
    );
  }
}

/// Non-blocking warning for the order form with one-tap "take advance".
class RiskBanner extends ConsumerWidget {
  const RiskBanner({required this.customerId, required this.onTakeAdvance, super.key});

  final String customerId;
  final VoidCallback onTakeAdvance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final risk = ref.watch(customerRiskProvider(customerId)).value;
    if (risk == null || !risk.hasWarning) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.errorContainer,
      margin: const EdgeInsets.only(top: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.warning_amber_rounded, color: scheme.onErrorContainer),
            const SizedBox(width: 8),
            Expanded(
              child: Text(l.riskBannerTitle,
                  style: TextStyle(color: scheme.onErrorContainer)),
            ),
          ]),
          const SizedBox(height: 8),
          RiskBadgeWrap(
            badges: [for (final b in risk.badges) if (b.isWarning) b],
            onTap: (b) => showRiskBadgeOrders(context, ref, b),
          ),
          if (risk.riskNote != null && risk.riskNote!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(risk.riskNote!,
                  style: TextStyle(color: scheme.onErrorContainer)),
            ),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.tonal(
              onPressed: onTakeAdvance,
              child: Text(l.riskTakeAdvance),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Customer detail: badges plus manual caution note and blocklist.
class RiskSection extends ConsumerWidget {
  const RiskSection({required this.customer, required this.onChanged, super.key});

  final Customer customer;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final risk = ref.watch(customerRiskProvider(customer.id)).value;
    final repo = ref.read(customerRepositoryProvider);
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l.riskSection, style: Theme.of(context).textTheme.titleMedium),
          Text(l.riskPrivateNote, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          if (risk != null)
            RiskBadgeWrap(
              badges: risk.badges,
              onTap: (b) => showRiskBadgeOrders(context, ref, b),
            ),
          if (customer.isBlocklisted && customer.blocklistReason != null)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.block),
              title: Text(customer.blocklistReason!),
            ),
          if (customer.riskNote != null)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.sticky_note_2_outlined),
              title: Text(customer.riskNote!),
            ),
          Wrap(spacing: 8, children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.edit_note),
              label: Text(l.riskCaution),
              onPressed: () async {
                final t = await _ask(context, l.riskCaution, l.riskCautionHint,
                    customer.riskNote ?? '');
                if (t == null) return;
                await repo.setRiskNote(customer.id, t);
                ref.invalidate(customerRiskProvider(customer.id));
                onChanged();
              },
            ),
            OutlinedButton.icon(
              icon: Icon(customer.isBlocklisted ? Icons.lock_open : Icons.block),
              label: Text(customer.isBlocklisted ? l.riskUnblock : l.riskBlocklist),
              onPressed: () async {
                if (customer.isBlocklisted) {
                  await repo.setBlocklisted(customer.id, blocked: false);
                } else {
                  final t = await _ask(context, l.riskBlocklist, l.riskBlockReason, '');
                  if (t == null) return;
                  await repo.setBlocklisted(customer.id, blocked: true, reason: t);
                }
                ref.invalidate(customerRiskProvider(customer.id));
                onChanged();
              },
            ),
          ]),
        ]),
      ),
    );
  }

  static Future<String?> _ask(
      BuildContext context, String title, String hint, String initial) {
    final c = TextEditingController(text: initial);
    final l = context.l10n;
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: c,
          autofocus: true,
          maxLines: 3,
          decoration: InputDecoration(hintText: hint),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.cancel)),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, c.text), child: Text(l.riskSave)),
        ],
      ),
    );
  }
}
