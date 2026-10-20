import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:parcel_khata/features/orders/domain/order_filter.dart';
import 'package:parcel_khata/features/search/application/saved_view_repository.dart';
import 'package:parcel_khata/l10n/l10n.dart';
import 'package:lucide_icons_flutter/lucide_icons_300.dart';

String viewDisplayName(AppLocalizations l, SavedViewItem v) {
  if (!v.isDefault) return v.name;
  return switch (v.id) {
    DefaultViews.toDispatch => l.viewToDispatch,
    DefaultViews.codPending5 => l.viewCodPending5,
    DefaultViews.returnsNotReceived => l.viewReturnsNotReceived,
    DefaultViews.lossMaking => l.viewLossMaking,
    _ => v.name,
  };
}

Future<String?> _askName(BuildContext context, String title, {String initial = ''}) async {
  final l = context.l10n;
  final c = TextEditingController(text: initial);
  final ok = await showDialog<bool>(
    context: context,
    builder: (d) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: c,
        autofocus: true,
        decoration: InputDecoration(labelText: l.viewName),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(d, false), child: Text(l.cancel)),
        FilledButton(onPressed: () => Navigator.pop(d, true), child: Text(l.save)),
      ],
    ),
  );
  final v = c.text.trim();
  c.dispose();
  return ok == true && v.isNotEmpty ? v : null;
}

/// Lists default + custom views; returns the one tapped. Custom views can be
/// renamed or deleted; the current filter can be saved as a new view.
Future<SavedViewItem?> showSavedViewsSheet(
  BuildContext context, {
  required OrderFilter current,
  required OrderSort sort,
}) {
  return showModalBottomSheet<SavedViewItem>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _SavedViewsSheet(current: current, sort: sort),
  );
}

class _SavedViewsSheet extends ConsumerWidget {
  const _SavedViewsSheet({required this.current, required this.sort});

  final OrderFilter current;
  final OrderSort sort;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final views = ref.watch(savedViewsProvider).value ?? const <SavedViewItem>[];
    final repo = ref.read(savedViewRepositoryProvider);
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
        child: ListView(shrinkWrap: true, children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(l.savedViews, style: Theme.of(context).textTheme.titleLarge),
          ),
          ListTile(
            leading: const Icon(LucideIcons300.bookmarkPlus),
            title: Text(l.saveCurrentView),
            onTap: () async {
              final name = await _askName(context, l.saveCurrentView);
              if (name != null) await repo.create(name, current, sort);
            },
          ),
          const Divider(height: 1),
          for (final v in views)
            ListTile(
              leading: Icon(v.isDefault ? LucideIcons300.pin : LucideIcons300.bookmark),
              title: Text(viewDisplayName(l, v)),
              onTap: () => Navigator.pop(context, v),
              trailing: v.isDefault
                  ? null
                  : Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(
                        tooltip: l.renameView,
                        icon: const Icon(LucideIcons300.pencil),
                        onPressed: () async {
                          final n = await _askName(context, l.renameView, initial: v.name);
                          if (n != null) await repo.rename(v.id, n);
                        },
                      ),
                      IconButton(
                        tooltip: l.deleteView,
                        icon: const Icon(LucideIcons300.trash2),
                        onPressed: () => repo.delete(v.id),
                      ),
                    ]),
            ),
        ]),
      ),
    );
  }
}
