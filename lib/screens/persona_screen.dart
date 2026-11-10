import 'package:flutter/material.dart';

import '../models/persona.dart';
import '../state/app_state.dart';
import '../theme/mausam_theme.dart';

class PersonaScreen extends StatefulWidget {
  final AppPersonaNotifier personaNotifier;

  const PersonaScreen({super.key, required this.personaNotifier});

  @override
  State<PersonaScreen> createState() => _PersonaScreenState();
}

class _PersonaScreenState extends State<PersonaScreen> {
  late Persona _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.personaNotifier.value;
  }

  void _apply() {
    widget.personaNotifier.value = _selected;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final personas = [
      Persona.farmer,
      Persona.traveller,
      Persona.student,
      Persona.outdoorWorker,
      Persona.healthFitness,
      Persona.commuter,
      Persona.seniorCitizen,
      Persona.eventPlanner,
    ];

    return Scaffold(
      backgroundColor: MausamTheme.background,
      appBar: AppBar(
        title: const Text('Choose Your Persona'),
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                onPressed: () => Navigator.pop(context),
              )
            : null,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Get personalized weather insights\nfor your needs.',
                      style: TextStyle(
                        fontSize: 14,
                        color: MausamTheme.textSecondary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 18),
                    ...personas.map((p) => _buildPersonaTile(p)),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),

            // Bottom "Continue" Button matching Screen 8
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Colors.grey[200]!)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _apply,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF1E3A8A),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Continue',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPersonaTile(Persona persona) {
    final isSelected = _selected == persona;

    Color iconBg;
    Color iconColor;

    switch (persona) {
      case Persona.farmer:
        iconBg = const Color(0xFFF3E8FF);
        iconColor = const Color(0xFF9333EA);
        break;
      case Persona.traveller:
        iconBg = const Color(0xFFEFF6FF);
        iconColor = const Color(0xFF2563EB);
        break;
      case Persona.student:
        iconBg = const Color(0xFFFFF7ED);
        iconColor = const Color(0xFFEA580C);
        break;
      case Persona.outdoorWorker:
        iconBg = const Color(0xFFCCFBF1);
        iconColor = const Color(0xFF0D9488);
        break;
      case Persona.healthFitness:
        iconBg = const Color(0xFFF3E8FF);
        iconColor = const Color(0xFF7E22CE);
        break;
      case Persona.commuter:
        iconBg = const Color(0xFFE0F2FE);
        iconColor = const Color(0xFF0284C7);
        break;
      case Persona.seniorCitizen:
        iconBg = const Color(0xFFFEF3C7);
        iconColor = const Color(0xFFD97706);
        break;
      case Persona.eventPlanner:
        iconBg = const Color(0xFFFCE7F3);
        iconColor = const Color(0xFFDB2777);
        break;
    }

    String description;
    switch (persona) {
      case Persona.farmer:
        description = 'Better crop decisions, field advisory & more';
        break;
      case Persona.traveller:
        description = 'Plan safer journeys with weather insights';
        break;
      case Persona.student:
        description = 'Stay prepared for classes & outdoor activities';
        break;
      case Persona.outdoorWorker:
        description = 'Work safely with weather updates';
        break;
      case Persona.healthFitness:
        description = 'Daily weather & lifestyle recommendations';
        break;
      default:
        description = persona.description;
        break;
    }

    final title = persona == Persona.healthFitness ? 'General User' : persona.label;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(MausamTheme.radiusCard),
        border: Border.all(
          color: isSelected ? const Color(0xFF7C3AED) : MausamTheme.border,
          width: isSelected ? 1.6 : 1.0,
        ),
        boxShadow: isSelected ? MausamTheme.elevatedShadow : MausamTheme.cardShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(MausamTheme.radiusCard),
          onTap: () => setState(() => _selected = persona),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: iconBg,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(persona.icon, color: iconColor, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: MausamTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        description,
                        style: const TextStyle(
                          fontSize: 12,
                          color: MausamTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? const Color(0xFF7C3AED) : Colors.grey[400]!,
                      width: 2,
                    ),
                    color: isSelected ? const Color(0xFF7C3AED) : Colors.transparent,
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, size: 14, color: Colors.white)
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
