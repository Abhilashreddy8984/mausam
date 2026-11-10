import 'package:flutter/material.dart';

import '../data/demo_data.dart';
import '../models/persona.dart';
import '../theme/mausam_theme.dart';

/// A single weather metric card redesigned with clean light styling.
class WeatherCard extends StatelessWidget {
  final WeatherCardData data;
  final VoidCallback? onTap;

  const WeatherCard({super.key, required this.data, this.onTap});

  @override
  Widget build(BuildContext context) {
    final Color bg = data.isAlert
        ? data.accentColor.withValues(alpha: 0.08)
        : Colors.white;

    final Color borderColor = data.isAlert
        ? data.accentColor.withValues(alpha: 0.4)
        : MausamTheme.border;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(MausamTheme.radiusCard),
        splashColor: data.accentColor.withValues(alpha: 0.12),
        highlightColor: data.accentColor.withValues(alpha: 0.05),
        child: Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(MausamTheme.radiusCard),
            border: Border.all(
              color: borderColor,
              width: data.isAlert ? 1.4 : 1.0,
            ),
            boxShadow: MausamTheme.cardShadow,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon + Title Row
              Row(
                children: [
                  _buildCardThumbnail(data),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      data.title,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: MausamTheme.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (onTap != null)
                    const Icon(
                      Icons.chevron_right,
                      size: 14,
                      color: MausamTheme.textMuted,
                    ),
                ],
              ),
              const SizedBox(height: 6),

              // Value
              Text(
                data.value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: MausamTheme.textPrimary,
                  letterSpacing: -0.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),

              // Subtitle
              if (data.subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  data.subtitle!,
                  style: const TextStyle(
                    fontSize: 11,
                    color: MausamTheme.textSecondary,
                    height: 1.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardThumbnail(WeatherCardData data) {
    final String? assetPath = data.type == WeatherCardType.farmAdvisory
        ? 'assets/images/farm_advisory.png'
        : (data.type == WeatherCardType.travelAdvisory
            ? 'assets/images/travel_advisory.png'
            : null);

    if (assetPath != null) {
      return Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Image.asset(
            assetPath,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: data.accentColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(data.icon, color: data.accentColor, size: 16),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: data.accentColor.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: Icon(data.icon, color: data.accentColor, size: 16),
    );
  }
}

/// A 2-column grid displaying multiple [WeatherCard]s.
class WeatherCardGrid extends StatelessWidget {
  final List<WeatherCardData> cards;
  final ValueChanged<WeatherCardData>? onCardTap;

  const WeatherCardGrid({
    super.key,
    required this.cards,
    this.onCardTap,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.5,
      ),
      itemCount: cards.length,
      itemBuilder: (context, idx) {
        final card = cards[idx];
        return WeatherCard(
          data: card,
          onTap: onCardTap != null ? () => onCardTap!(card) : null,
        );
      },
    );
  }
}
