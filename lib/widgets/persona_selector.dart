// ============================================================
// widgets/persona_selector.dart
// Bottom-sheet persona picker + inline badge.
// ============================================================

import 'package:flutter/material.dart';

import '../models/persona.dart';

// ─────────────────────────────────────────────────────────────
// _PersonaTile — grid tile inside the bottom sheet
// ─────────────────────────────────────────────────────────────
class _PersonaTile extends StatelessWidget {
  final Persona persona;
  final bool isSelected;
  final VoidCallback onTap;

  const _PersonaTile({
    required this.persona,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final Color accent = isSelected ? primary : Colors.grey[300]!;
    final Color textColor = isSelected ? primary : Colors.grey[700]!;
    final Color bg = isSelected
        ? primary.withValues(alpha: 0.08)
        : Colors.grey[100]!;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: accent, width: isSelected ? 1.8 : 1.0),
        ),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(persona.icon, color: textColor, size: 26),
            const SizedBox(height: 8),
            Text(
              persona.label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// showPersonaSelectorSheet
// ─────────────────────────────────────────────────────────────
Future<Persona?> showPersonaSelectorSheet(
  BuildContext context, {
  required Persona current,
}) {
  return showModalBottomSheet<Persona>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _PersonaSelectorSheet(current: current),
  );
}

class _PersonaSelectorSheet extends StatefulWidget {
  final Persona current;
  const _PersonaSelectorSheet({required this.current});

  @override
  State<_PersonaSelectorSheet> createState() => _PersonaSelectorSheetState();
}

class _PersonaSelectorSheetState extends State<_PersonaSelectorSheet> {
  late Persona _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.current;
  }

  @override
  Widget build(BuildContext context) {
    final allPersonas = Persona.values;
    final primary = Theme.of(context).colorScheme.primary;
    // Use surface (replaces deprecated background)
    final surfaceColor = Theme.of(context).colorScheme.surface;

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          Text(
            'Choose your weather profile',
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'Your profile reorders what\'s most relevant to you. '
            'All information stays available.',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: Colors.grey[500]),
          ),
          const SizedBox(height: 20),

          // 4-column persona grid
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 4,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.9,
            children: allPersonas.map((p) {
              return _PersonaTile(
                persona: p,
                isSelected: _selected == p,
                onTap: () => setState(() => _selected = p),
              );
            }).toList(),
          ),

          const SizedBox(height: 8),

          // Description of selected persona
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Container(
              key: ValueKey(_selected),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(_selected.icon, size: 18, color: primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _selected.description,
                      style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Confirm button
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.pop(context, _selected),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Apply Profile',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// PersonaBadge — compact inline widget shown in the header
// ─────────────────────────────────────────────────────────────
class PersonaBadge extends StatelessWidget {
  final Persona persona;
  final VoidCallback onChangeTap;

  const PersonaBadge({
    super.key,
    required this.persona,
    required this.onChangeTap,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return GestureDetector(
      onTap: onChangeTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: primary.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: primary.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(persona.icon, size: 16, color: primary),
            const SizedBox(width: 6),
            Text(
              persona.label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: primary,
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.swap_horiz_rounded,
              size: 15,
              color: primary.withValues(alpha: 0.7),
            ),
          ],
        ),
      ),
    );
  }
}
