import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design_system/tokens.dart';
import '../wallet/wallet_models.dart';
import '../wallet/wallet_store.dart';
import 'household.dart';

/// Household members, once there is someone to share with.
List<HouseholdMember> _sharing(WidgetRef ref) {
  final members = ref.watch(walletMembersProvider).value ?? const <HouseholdMember>[];
  return members.length > 1 ? members : const [];
}

/// Whose phone reminds: both, or one member. Hidden outside a household.
class NotifyTargetPicker extends ConsumerWidget {
  const NotifyTargetPicker({super.key, required this.value, required this.onChanged});

  /// [notifyAll] or a user id.
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = LbTokens.of(context);
    final members = _sharing(ref);
    if (members.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('Bildirim kime', style: TextStyle(color: t.muted, fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: [
        ChoiceChip(
          label: Text(members.length == 2 ? 'İkimiz' : 'Herkes'),
          selected: value == notifyAll,
          onSelected: (_) => onChanged(notifyAll),
        ),
        for (final m in members)
          ChoiceChip(
            label: Text(m.name),
            selected: value == '${m.userId}',
            onSelected: (_) => onChanged('${m.userId}'),
          ),
      ]),
    ]);
  }
}

/// A small name pill: who added the item. Hidden outside a household.
class OwnerTag extends ConsumerWidget {
  const OwnerTag(this.userId, {super.key});

  final int? userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = LbTokens.of(context);
    final owner = _sharing(ref).where((m) => m.userId == userId).firstOrNull;
    if (owner == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: t.accent.withValues(alpha: .14), borderRadius: BorderRadius.circular(99)),
      child: Text(owner.name, style: TextStyle(color: t.accent, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}
