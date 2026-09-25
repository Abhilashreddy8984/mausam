// ============================================================
// screens/persona_screen.dart
//
// Receives AppPersonaNotifier directly (no InheritedWidget lookup).
// When "Apply Profile" is tapped:
//   1. personaNotifier.value = _selected  (instant update)
//   2. Navigator.pop()                    (return to Home)
// HomeScreen's ValueListenableBuilder sees the change immediately.
// ============================================================

import 'package:flutter/material.dart';

import '../models/persona.dart';
import '../state/app_state.dart';

class PersonaScreen extends StatefulWidget {
  final AppPersonaNotifier personaNotifier;

  const PersonaScreen({super.key, required this.personaNotifier});

  @override
  State<PersonaScreen> createState() => _PersonaScreenState();
}

class _PersonaScreenState extends State<PersonaScreen> {
  // Local selection state — tracks what the user has highlighted
  // in this screen before committing with "Apply".
  late Persona _selected;

  @override
  void initState() {
    super.initState();
    // Seed from the current live value — no InheritedWidget needed.
    _selected = widget.personaNotifier.value;
  }

  void _apply() {
    // Write the new persona into the shared notifier.
    // ValueListenableBuilder in HomeScreen reacts immediately.
    widget.personaNotifier.value = _selected;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
          tooltip: 'Back',
        ),
        title: const Text(
          'Weather Profile',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: Colors.grey[200]),
        ),
      ),
      body: Column(
        children: [
          _buildBanner(context),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              children: [
                _sectionLabel('Select your profile'),
                const SizedBox(height: 12),

                // ── 2-column persona grid ──────────────────
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.55,
                  children: Persona.values.map((p) {
                    return _PersonaCard(
                      persona: p,
                      isSelected: _selected == p,
                      onTap: () => setState(() => _selected = p),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 20),
                _sectionLabel('What this means'),
                const SizedBox(height: 10),

                // Animates when _selected changes
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: _SelectedPersonaDetail(
                    key: ValueKey(_selected),
                    persona: _selected,
                  ),
                ),

                const SizedBox(height: 16),

                // Personalization principle note
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: primary.withValues(alpha: 0.15)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 16,
                        color: primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '"Personalization changes the priority, not the '
                          'availability." All weather data is always accessible '
                          'on the Explore tab — your profile just surfaces the '
                          'most relevant cards first.',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: Colors.grey[600],
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),

      // ── Sticky Apply button ──────────────────────────────────
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton(
            onPressed: _apply,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(_selected.icon, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Apply ${_selected.label} Profile',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBanner(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Choose your weather profile',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Your profile reorders the weather cards so the most relevant '
            'information appears first. All data stays available.',
            style: TextStyle(fontSize: 12.5, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(
    text.toUpperCase(),
    style: TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      color: Colors.grey[400],
      letterSpacing: 1.1,
    ),
  );
}

// ─────────────────────────────────────────────────────────────
// _PersonaCard — selectable tile
// ─────────────────────────────────────────────────────────────
class _PersonaCard extends StatelessWidget {
  final Persona persona;
  final bool isSelected;
  final VoidCallback onTap;

  const _PersonaCard({
    required this.persona,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final bg = isSelected ? primary.withValues(alpha: 0.07) : Colors.white;
    final border = isSelected ? primary : Colors.grey[300]!;
    final labelColor = isSelected ? primary : Colors.grey[800]!;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border, width: isSelected ? 1.8 : 1.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected
                    ? primary.withValues(alpha: 0.12)
                    : Colors.grey[100]!,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                persona.icon,
                size: 22,
                color: isSelected ? primary : Colors.grey[600],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    persona.label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: labelColor,
                    ),
                  ),
                  if (isSelected) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Selected',
                      style: TextStyle(
                        fontSize: 10,
                        color: primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle_rounded, size: 18, color: primary),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _SelectedPersonaDetail — description + top priority chips
// ─────────────────────────────────────────────────────────────
class _SelectedPersonaDetail extends StatelessWidget {
  final Persona persona;
  const _SelectedPersonaDetail({super.key, required this.persona});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final topTypes = persona.cardPriority.take(4).toList();
    const typeLabels = <WeatherCardType, String>{
      WeatherCardType.rain: 'Rainfall',
      WeatherCardType.temperature: 'Temperature',
      WeatherCardType.aqi: 'Air Quality',
      WeatherCardType.uvIndex: 'UV Index',
      WeatherCardType.wind: 'Wind',
      WeatherCardType.weatherAlert: 'Weather Alert',
      WeatherCardType.farmAdvisory: 'Farm Advisory',
      WeatherCardType.travelAdvisory: 'Travel Advisory',
      WeatherCardType.visibility: 'Visibility',
      WeatherCardType.marineTide: 'Marine / Tide',
      WeatherCardType.humidity: 'Humidity',
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(persona.icon, color: primary, size: 20),
              const SizedBox(width: 8),
              Text(
                persona.label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            persona.description,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'TOP PRIORITY CARDS',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Colors.grey[400],
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: topTypes.asMap().entries.map((e) {
              final idx = e.key + 1;
              final label = typeLabels[e.value] ?? e.value.name;
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 16,
                      height: 16,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: primary,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$idx',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: primary,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
