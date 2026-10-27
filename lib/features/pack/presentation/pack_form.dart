import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/byte_format.dart';
import '../../../core/ui/formatting.dart';
import '../domain/pack_plan.dart';
import 'pack_controller.dart';

enum _PackType { daily, monthly }

/// Edits the pack: per day or per month, its size, renewal day and alerts.
class PackForm extends ConsumerStatefulWidget {
  const PackForm({required this.initial, super.key});

  final PackSettings initial;

  @override
  ConsumerState<PackForm> createState() => _PackFormState();
}

class _PackFormState extends ConsumerState<PackForm> {
  late final TextEditingController _amount;
  late _PackType _type;
  late ByteUnit _unit;
  late int _resetDay;
  late bool _alerts;
  PackLimitError? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final plan = widget.initial.plan;
    final (text, unit) = plan == null
        ? ('', ByteUnit.gb)
        : editableAmount(plan.limitBytes);
    _amount = TextEditingController(text: text);
    _unit = unit;
    _type = plan is MonthlyPack ? _PackType.monthly : _PackType.daily;
    _resetDay = plan is MonthlyPack ? plan.resetDay : 1;
    _alerts = widget.initial.alertsEnabled;
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final bytes = parsePackAmount(_amount.text, _unit.bytes);
    final error = validatePackLimit(bytes);
    setState(() => _error = error);
    if (error != null || bytes == null) return;

    final plan = switch (_type) {
      _PackType.daily => DailyPack(limitBytes: bytes),
      _PackType.monthly => MonthlyPack(limitBytes: bytes, resetDay: _resetDay),
    };
    setState(() => _saving = true);
    try {
      await ref
          .read(packControllerProvider.notifier)
          .save(PackSettings(plan: plan, alertsEnabled: _alerts));
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.packSaved)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<_PackType>(
          segments: [
            ButtonSegment(
              value: _PackType.daily,
              label: Text(l10n.packTypeDaily),
            ),
            ButtonSegment(
              value: _PackType.monthly,
              label: Text(l10n.packTypeMonthly),
            ),
          ],
          selected: {_type},
          onSelectionChanged: (s) => setState(() => _type = s.first),
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                key: const Key('pack-amount'),
                controller: _amount,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                decoration: InputDecoration(
                  labelText: l10n.packAmount,
                  hintText: l10n.packAmountHint,
                  errorText: switch (_error) {
                    PackLimitError.notANumber => l10n.errorNotANumber,
                    PackLimitError.tooSmall => l10n.errorTooSmall,
                    PackLimitError.tooLarge => l10n.errorTooLarge,
                    null => null,
                  },
                  border: const OutlineInputBorder(),
                ),
                onSubmitted: (_) => _save(),
              ),
            ),
            const SizedBox(width: 12),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: SegmentedButton<ByteUnit>(
                segments: [
                  ButtonSegment(value: ByteUnit.mb, label: Text(l10n.unitMb)),
                  ButtonSegment(value: ByteUnit.gb, label: Text(l10n.unitGb)),
                ],
                selected: {_unit},
                showSelectedIcon: false,
                onSelectionChanged: (s) => setState(() => _unit = s.first),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_type == _PackType.monthly) ...[
          DropdownButtonFormField<int>(
            initialValue: _resetDay,
            decoration: InputDecoration(
              labelText: l10n.resetDay,
              helperText: l10n.resetDayHelp,
              border: const OutlineInputBorder(),
            ),
            items: [
              for (var day = 1; day <= 31; day++)
                DropdownMenuItem(value: day, child: Text('$day')),
            ],
            onChanged: (day) => setState(() => _resetDay = day ?? 1),
          ),
        ] else
          Text(l10n.dailyResetHelp, style: theme.textTheme.bodySmall),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.alertsSwitch),
          value: _alerts,
          onChanged: (on) => setState(() => _alerts = on),
        ),
        const SizedBox(height: 4),
        FilledButton(
          key: const Key('save-pack'),
          onPressed: _saving ? null : _save,
          child: Text(l10n.savePack),
        ),
      ],
    );
  }
}
