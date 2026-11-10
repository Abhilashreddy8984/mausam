import 'package:flutter/material.dart';

import '../models/weather_data.dart';
import '../theme/mausam_theme.dart';

class ForecastScreen extends StatelessWidget {
  final WeatherData weather;

  const ForecastScreen({super.key, required this.weather});

  @override
  Widget build(BuildContext context) {
    // Generate dates based on current or demo time
    final now = weather.timestamp ?? DateTime.now();
    final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

    final baseTemp = weather.temperatureC.toInt();
    final items = [
      {
        'day': 'Today',
        'date': '${now.day} ${monthNames[now.month - 1]}',
        'icon': Icons.wb_sunny_rounded,
        'iconColor': const Color(0xFFF59E0B),
        'high': '$baseTemp°',
        'low': '${baseTemp - 10}°',
        'pop': weather.rainfallProbability != null
            ? '${weather.rainfallProbability!.toInt()}%'
            : '--',
      },
      {
        'day': dayNames[(now.weekday) % 7],
        'date': '${now.add(const Duration(days: 1)).day} ${monthNames[now.add(const Duration(days: 1)).month - 1]}',
        'icon': Icons.wb_cloudy_rounded,
        'iconColor': const Color(0xFF60A5FA),
        'high': '${baseTemp - 1}°',
        'low': '${baseTemp - 11}°',
        'pop': '20%',
      },
      {
        'day': dayNames[(now.weekday + 1) % 7],
        'date': '${now.add(const Duration(days: 2)).day} ${monthNames[now.add(const Duration(days: 2)).month - 1]}',
        'icon': Icons.grain_rounded,
        'iconColor': const Color(0xFF3B82F6),
        'high': '${baseTemp - 3}°',
        'low': '${baseTemp - 12}°',
        'pop': '60%',
      },
      {
        'day': dayNames[(now.weekday + 2) % 7],
        'date': '${now.add(const Duration(days: 3)).day} ${monthNames[now.add(const Duration(days: 3)).month - 1]}',
        'icon': Icons.cloud_rounded,
        'iconColor': const Color(0xFF94A3B8),
        'high': '${baseTemp - 4}°',
        'low': '${baseTemp - 13}°',
        'pop': '40%',
      },
      {
        'day': dayNames[(now.weekday + 3) % 7],
        'date': '${now.add(const Duration(days: 4)).day} ${monthNames[now.add(const Duration(days: 4)).month - 1]}',
        'icon': Icons.wb_sunny_rounded,
        'iconColor': const Color(0xFFF59E0B),
        'high': '${baseTemp - 2}°',
        'low': '${baseTemp - 12}°',
        'pop': '10%',
      },
      {
        'day': dayNames[(now.weekday + 4) % 7],
        'date': '${now.add(const Duration(days: 5)).day} ${monthNames[now.add(const Duration(days: 5)).month - 1]}',
        'icon': Icons.wb_cloudy_rounded,
        'iconColor': const Color(0xFF60A5FA),
        'high': '${baseTemp - 1}°',
        'low': '${baseTemp - 11}°',
        'pop': '20%',
      },
      {
        'day': dayNames[(now.weekday + 5) % 7],
        'date': '${now.add(const Duration(days: 6)).day} ${monthNames[now.add(const Duration(days: 6)).month - 1]}',
        'icon': Icons.grain_rounded,
        'iconColor': const Color(0xFF3B82F6),
        'high': '${baseTemp - 4}°',
        'low': '${baseTemp - 13}°',
        'pop': '70%',
      },
    ];

    return Scaffold(
      backgroundColor: MausamTheme.background,
      appBar: AppBar(
        title: const Text('7-Day Forecast'),
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                onPressed: () => Navigator.pop(context),
              )
            : null,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          children: [
            Container(
              decoration: MausamTheme.cardDecoration(),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: items.length,
                separatorBuilder: (_, _) => Divider(height: 1, color: Colors.grey[200]),
                itemBuilder: (context, idx) {
                  final it = items[idx];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 80,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                it['day'] as String,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: MausamTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                it['date'] as String,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: MausamTheme.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        Icon(
                          it['icon'] as IconData,
                          color: it['iconColor'] as Color,
                          size: 26,
                        ),
                        const Spacer(),
                        SizedBox(
                          width: 65,
                          child: Text(
                            '${it['high']}/${it['low']}',
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: MausamTheme.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 20),
                        SizedBox(
                          width: 38,
                          child: Text(
                            it['pop'] as String,
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: MausamTheme.primaryBlue,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              '% = Probability of precipitation',
              style: TextStyle(
                fontSize: 12,
                color: MausamTheme.textMuted,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
