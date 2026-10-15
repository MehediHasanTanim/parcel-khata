import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:parcel_khata/features/templates/application/template_repository.dart';
import 'package:parcel_khata/features/templates/domain/message_templates.dart';
import 'package:parcel_khata/l10n/l10n.dart';

String templateTitle(AppLocalizations l, TemplateKind k) => switch (k) {
      TemplateKind.confirmation => l.tplConfirmation,
      TemplateKind.dispatch => l.tplDispatch,
      TemplateKind.deliveryFollowUp => l.tplFollowUp,
      TemplateKind.beAvailable => l.tplBeAvailable,
    };

class TemplatesScreen extends ConsumerStatefulWidget {
  const TemplatesScreen({super.key});

  @override
  ConsumerState<TemplatesScreen> createState() => _TemplatesScreenState();
}

class _TemplatesScreenState extends ConsumerState<TemplatesScreen> {
  final Map<TemplateKind, TextEditingController> _ctl = {};
  String _lang = 'bn';
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loaded) {
      _loaded = true;
      _lang = Localizations.localeOf(context).languageCode == 'en' ? 'en' : 'bn';
      _load();
    }
  }

  Future<void> _load() async {
    final repo = ref.read(templateRepositoryProvider);
    for (final k in TemplateKind.values) {
      final text = await repo.body(k, _lang);
      (_ctl[k] ??= TextEditingController()).text = text;
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    for (final c in _ctl.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.messageTemplates)),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        SegmentedButton<String>(
          segments: [
            ButtonSegment(value: 'bn', label: Text(l.languageBangla)),
            ButtonSegment(value: 'en', label: Text(l.languageEnglish)),
          ],
          selected: {_lang},
          onSelectionChanged: (s) {
            setState(() => _lang = s.first);
            _load();
          },
        ),
        const SizedBox(height: 8),
        Text(l.tplPlaceholders, style: Theme.of(context).textTheme.bodySmall),
        for (final k in TemplateKind.values) ...[
          const SizedBox(height: 16),
          Text(templateTitle(l, k), style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 6),
          TextField(
            controller: _ctl[k],
            maxLines: 4,
            decoration: InputDecoration(
              errorText: MessageTemplates.unknownPlaceholders(_ctl[k]?.text ?? '').isEmpty
                  ? null
                  : '${l.tplUnknown}: ${MessageTemplates.unknownPlaceholders(_ctl[k]!.text).join(', ')}',
            ),
            onChanged: (v) async {
              await ref.read(templateRepositoryProvider).save(k, _lang, v);
              if (mounted) setState(() {});
            },
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () async {
                await ref.read(templateRepositoryProvider).reset(k, _lang);
                await _load();
              },
              child: Text(l.tplReset),
            ),
          ),
        ],
      ]),
    );
  }
}
