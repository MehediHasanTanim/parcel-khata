import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:parcel_khata/features/reminders/application/attention_service.dart';
import 'package:parcel_khata/features/reminders/presentation/attention_widgets.dart';
import 'package:parcel_khata/l10n/l10n.dart';
import 'package:parcel_khata/shared/empty_state.dart';

class AttentionScreen extends ConsumerWidget {
  const AttentionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final items = ref.watch(attentionProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(l.attentionTitle),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text('${items.value?.length ?? 0}'),
            ),
          ),
        ],
      ),
      body: items.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (list) => list.isEmpty
            ? EmptyState(icon: Icons.task_alt, title: l.attentionEmpty)
            : ListView(
                padding: const EdgeInsets.all(12),
                children: [for (final i in list) AttentionTile(item: i)],
              ),
      ),
    );
  }
}
