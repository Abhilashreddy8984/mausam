// ============================================================
// widgets/weather_card.dart
// Reusable card widget for displaying a single weather metric.
//
// Changes from v1:
//   - WeatherCard now accepts an optional onTap callback.
//   - WeatherCardGrid accepts onCardTap and threads it through.
//   - InkWell provides the tap ripple effect.
// ============================================================

import 'package:flutter/material.dart';

import '../data/demo_data.dart';

/// A single weather metric card.
/// Pass [onTap] to make it navigable (e.g. to the detail screen).
class WeatherCard extends StatelessWidget {
  final WeatherCardData data;
  final VoidCallback? onTap;

  const WeatherCard({super.key, required this.data, this.onTap});

  @override
  Widget build(BuildContext context) {
    final Color bg = data.isAlert
        ? data.accentColor.withValues(alpha: 0.08)
        : Theme.of(context).colorScheme.surface;

    final Color borderColor = data.isAlert
        ? data.accentColor.withValues(alpha: 0.5)
        : Colors.transparent;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor: data.accentColor.withValues(alpha: 0.12),
        highlightColor: data.accentColor.withValues(alpha: 0.06),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Icon + Title row ──
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: data.accentColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(data.icon, color: data.accentColor, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      data.title,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[600],
                        letterSpacing: 0.3,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Tap hint chevron when tappable
                  if (onTap != null)
                    Icon(
                      Icons.chevron_right,
                      size: 14,
                      color: Colors.grey[350],
                    ),
                ],
              ),

              const SizedBox(height: 12),

              // ── Primary value ──
              Text(
                data.value,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: data.isAlert ? data.accentColor : Colors.grey[900],
                  height: 1.1,
                ),
              ),

              // ── Subtitle / detail ──
              if (data.subtitle != null) ...[
                const SizedBox(height: 5),
                Text(
                  data.subtitle!,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// WeatherCardGrid — responsive 2-column grid of WeatherCards.
//
// [onCardTap] receives the tapped WeatherCardData so the caller
// can push the appropriate detail screen.
// An alert card in position 0 spans full width.
// ─────────────────────────────────────────────────────────────
class WeatherCardGrid extends StatelessWidget {
  final List<WeatherCardData> cards;

  /// Called when a card is tapped. Null = no tap interaction.
  final void Function(WeatherCardData)? onCardTap;

  const WeatherCardGrid({super.key, required this.cards, this.onCardTap});

  @override
  Widget build(BuildContext context) {
    final List<Widget> rows = [];
    int i = 0;

    while (i < cards.length) {
      // Full-width slot: first card if it's an alert
      if (i == 0 && cards[i].isAlert) {
        rows.add(
          WeatherCard(
            data: cards[i],
            onTap: onCardTap != null ? () => onCardTap!(cards[i]) : null,
          ),
        );
        rows.add(const SizedBox(height: 12));
        i++;
        continue;
      }

      // Standard 2-column row
      final left = cards[i];
      final right = (i + 1 < cards.length) ? cards[i + 1] : null;

      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: WeatherCard(
                  data: left,
                  onTap: onCardTap != null ? () => onCardTap!(left) : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: right != null
                    ? WeatherCard(
                        data: right,
                        onTap: onCardTap != null
                            ? () => onCardTap!(right)
                            : null,
                      )
                    : const SizedBox(),
              ),
            ],
          ),
        ),
      );
      rows.add(const SizedBox(height: 12));
      i += 2;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: rows,
    );
  }
}
