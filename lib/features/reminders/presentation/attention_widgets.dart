import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:parcel_khata/app/theme.dart';
import 'package:parcel_khata/core/money/money.dart';
import 'package:parcel_khata/core/time/providers.dart';
import 'package:parcel_khata/features/couriers/domain/tracking_url.dart';
import 'package:parcel_khata/features/orders/application/order_status_service.dart';
import 'package:parcel_khata/features/orders/domain/order_enums.dart';
import 'package:parcel_khata/features/orders/presentation/status_actions.dart';
import 'package:parcel_khata/features/reminders/application/reminder_repository.dart';
import 'package:parcel_khata/features/reminders/domain/needs_attention.dart';
import 'package:parcel_khata/features/templates/application/template_repository.dart';
import 'package:parcel_khata/features/templates/domain/message_templates.dart';
import 'package:parcel_khata/l10n/l10n.dart';
import 'package:parcel_khata/shared/status_chip.dart';
import 'package:url_launcher/url_launcher.dart';

String attentionText(AppLocalizations l, AttentionItem i) => switch (i.kind) {
      AttentionKind.staleHandedOver => l.attStale(i.days),
      AttentionKind.overdueCod => l.attOverdueCod(i.days),
      AttentionKind.returnTooLong => l.attReturn(i.days),
      AttentionKind.oldDraft => l.attDraft,
      AttentionKind.dispute => l.attDispute,
      AttentionKind.toDispatch => l.attDispatch,
      AttentionKind.backupDue => l.attBackup(i.days),
    };

IconData attentionIcon(AttentionKind k) => switch (k) {
      AttentionKind.staleHandedOver => Icons.local_shipping_outlined,
      AttentionKind.overdueCod => Icons.payments_outlined,
      AttentionKind.returnTooLong => Icons.assignment_return_outlined,
      AttentionKind.oldDraft => Icons.edit_note,
      AttentionKind.dispute => Icons.flag_outlined,
      AttentionKind.toDispatch => Icons.outbox_outlined,
      AttentionKind.backupDue => Icons.backup_outlined,
    };

StatusTone attentionTone(AttentionKind k) => switch (k) {
      AttentionKind.staleHandedOver ||
      AttentionKind.returnTooLong ||
      AttentionKind.dispute =>
        StatusTone.danger,
      AttentionKind.overdueCod || AttentionKind.backupDue => StatusTone.warning,
      _ => StatusTone.neutral,
    };

Color _toneColor(BuildContext context, StatusTone tone) {
  final c = Theme.of(context).extension<StatusColors>()!;
  return switch (tone) {
    StatusTone.success => c.success,
    StatusTone.warning => c.warning,
    StatusTone.danger => c.danger,
    StatusTone.neutral => c.neutral,
    StatusTone.info => c.info,
  };
}

/// One queue entry with one-tap actions (feature spec F11).
class AttentionTile extends ConsumerWidget {
  const AttentionTile({required this.item, super.key});

  final AttentionItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final o = item.order;
    final t = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          InkWell(
            onTap: () {
              if (o != null) {
                context.push('/orders/${o.orderId}');
              } else {
                context.push('/settings/data');
              }
            },
            child: Row(children: [
              Icon(attentionIcon(item.kind),
                  size: 20, color: _toneColor(context, attentionTone(item.kind))),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    o == null ? l.backupNow : '${o.orderNo} · ${o.customerName ?? '—'}',
                    style: t.textTheme.titleSmall,
                  ),
                  Text(attentionText(l, item), style: t.textTheme.bodySmall),
                ]),
              ),
              if (o != null && o.amountPoisha > 0) Text(Money(o.amountPoisha).format()),
            ]),
          ),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 4, children: _actions(context, ref, l)),
        ]),
      ),
    );
  }

  List<Widget> _actions(BuildContext context, WidgetRef ref, AppLocalizations l) {
    final o = item.order;
    final status = ref.read(orderStatusServiceProvider);
    final acts = <_Act>[];
    final out = _ActList(acts);
    _Act chip(String label, IconData icon, VoidCallback onTap) => _Act(label, icon, onTap);

    if (o != null && item.kind == AttentionKind.staleHandedOver) {
      out
        ..add(chip(l.statusDelivered, Icons.done_all, () async {
          await status.changeStatus(o.orderId, to: OrderStatus.delivered);
        }))
        ..add(chip(l.statusFailed, Icons.error_outline, () async {
          final p = await showStatusParamsSheet(
            context,
            to: OrderStatus.deliveryFailed,
            now: ref.read(clockProvider).now(),
          );
          if (p == null) return;
          await status.changeStatus(o.orderId,
              to: OrderStatus.deliveryFailed, at: p.at, reason: p.reason, note: p.note);
        }))
        ..add(chip(l.stillInTransit, Icons.hourglass_bottom, () async {
          await status.acknowledge(o.orderId);
          ref.invalidate(_noop);
        }));
    }
    if (o != null && item.kind == AttentionKind.overdueCod) {
      out.add(chip(l.recordPayout, Icons.add_card, () {
        context.push('/cod/payout/new');
      }));
    }
    if (o != null && item.kind == AttentionKind.returnTooLong) {
      out.add(chip(l.actionReturned, Icons.inventory_2_outlined,
          () => context.push('/orders/${o.orderId}')));
    }
    if (o != null && (o.customerPhone ?? '').isNotEmpty) {
      out
        ..add(chip(l.callCustomer, Icons.call, () {
          unawaited(launchUrl(Uri(scheme: 'tel', path: o.customerPhone)));
        }))
        ..add(chip(l.whatsappCustomer, Icons.chat, () => _whatsApp(context, ref, o)));
    }
    if (o != null &&
        (o.trackingTemplate ?? '').isNotEmpty &&
        (o.consignmentNo ?? '').isNotEmpty) {
      final url = TrackingUrl.build(o.trackingTemplate!, o.consignmentNo!);
      if (url != null) {
        out.add(chip(l.openTracking, Icons.open_in_new, () {
          unawaited(launchUrl(url, mode: LaunchMode.externalApplication));
        }));
      }
    }
    final reminders = ref.read(reminderRepositoryProvider);
    out
      ..add(chip(l.snooze1d, Icons.snooze, () => reminders.snooze(item, 1)))
      ..add(chip(l.snooze3d, Icons.snooze, () => reminders.snooze(item, 3)))
      ..add(chip(l.dismissItem, Icons.close, () => _dismiss(context, reminders, l)));
    return _render(acts);
  }

  /// Two primary actions as chips, the rest behind an overflow menu.
  List<Widget> _render(List<_Act> acts) {
    const visible = 2;
    return [
      for (final a in acts.take(visible))
        ActionChip(
          avatar: Icon(a.icon, size: 16),
          label: Text(a.label),
          onPressed: a.onTap,
        ),
      if (acts.length > visible)
        PopupMenuButton<_Act>(
          padding: EdgeInsets.zero,
          child: const Chip(label: Icon(Icons.more_horiz, size: 18)),
          onSelected: (a) => a.onTap(),
          itemBuilder: (_) => [
            for (final a in acts.skip(visible))
              PopupMenuItem(value: a, child: Row(children: [
                Icon(a.icon, size: 18),
                const SizedBox(width: 8),
                Flexible(child: Text(a.label)),
              ])),
          ],
        ),
    ];
  }

  Future<void> _dismiss(
      BuildContext context, ReminderRepository repo, AppLocalizations l) async {
    final reason = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(title: Text(l.dismissReasonLabel)),
          ListTile(
              title: Text(l.dismissDone), onTap: () => Navigator.pop(context, 'handled')),
          ListTile(
              title: Text(l.dismissNotNeeded),
              onTap: () => Navigator.pop(context, 'not_needed')),
        ]),
      ),
    );
    if (reason != null) await repo.dismiss(item, reason);
  }

  Future<void> _whatsApp(
      BuildContext context, WidgetRef ref, OrderAttentionFacts o) async {
    final l = context.l10n;
    final lang = Localizations.localeOf(context).languageCode;
    final kind = switch (item.kind) {
      AttentionKind.toDispatch => TemplateKind.dispatch,
      AttentionKind.staleHandedOver => TemplateKind.deliveryFollowUp,
      _ => TemplateKind.confirmation,
    };
    final body = await ref.read(templateRepositoryProvider).body(kind, lang);
    final text = MessageTemplates.render(body, {
      'name': o.customerName ?? '',
      'cn': o.consignmentNo ?? '',
      'amount': Money(o.amountPoisha).format(),
      'order': o.orderNo,
      'courier': o.courierName ?? '',
      'shop': l.appName,
    });
    // The seller still taps Send; the app never sends messages itself.
    await launchUrl(
      MessageTemplates.whatsAppLink(o.customerPhone!, text),
      mode: LaunchMode.externalApplication,
    );
  }
}

final _noop = Provider<int>((ref) => 0);

class _Act {
  const _Act(this.label, this.icon, this.onTap);

  final String label;
  final IconData icon;
  final VoidCallback onTap;
}

/// Lets the existing `out..add(chip(...))` chains append to [_acts].
class _ActList {
  _ActList(this._acts);

  final List<_Act> _acts;

  void add(_Act a) => _acts.add(a);
}
