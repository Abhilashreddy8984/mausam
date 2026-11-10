import 'package:flutter/material.dart';
import '../theme/mausam_theme.dart';

/// Screen 9: Loading State
class MausamLoadingView extends StatelessWidget {
  final String title;
  final String subtitle;

  const MausamLoadingView({
    super.key,
    this.title = 'Fetching your weather data...',
    this.subtitle = 'This may take a few seconds.',
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Soft circular illustration container
            Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFE0F2FE).withValues(alpha: 0.6),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Icon(
                    Icons.wb_sunny_rounded,
                    size: 48,
                    color: Color(0xFFFBBF24),
                  ),
                  Positioned(
                    bottom: 24,
                    right: 24,
                    child: Icon(
                      Icons.cloud_rounded,
                      size: 48,
                      color: Colors.lightBlue[300],
                    ),
                  ),
                  const SizedBox(
                    width: 110,
                    height: 110,
                    child: CircularProgressIndicator(
                      strokeWidth: 3.5,
                      valueColor: AlwaysStoppedAnimation<Color>(MausamTheme.primaryBlue),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: MausamTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: MausamTheme.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Screen 10: Error State
class MausamErrorView extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback? onRetry;
  final VoidCallback? onBack;

  const MausamErrorView({
    super.key,
    this.title = 'Oops! Something went wrong',
    this.subtitle = "We couldn't fetch the weather data.\nPlease try again.",
    this.onRetry,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFF1F5F9),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    Icons.cloud_rounded,
                    size: 64,
                    color: Colors.blueGrey[200],
                  ),
                  Positioned(
                    bottom: 26,
                    right: 28,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.error,
                        size: 26,
                        color: Color(0xFFEF4444),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 26),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                color: MausamTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: MausamTheme.textMuted,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 28),
            if (onRetry != null)
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onRetry,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF1E3A8A),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Retry', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ),
            if (onBack != null) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: onBack,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: MausamTheme.textSecondary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: MausamTheme.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Go Back', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Screen 11: No Network State
class MausamNoNetworkView extends StatelessWidget {
  final VoidCallback? onRetry;
  final VoidCallback? onSettings;

  const MausamNoNetworkView({
    super.key,
    this.onRetry,
    this.onSettings,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFE0F2FE).withValues(alpha: 0.5),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Icon(
                    Icons.wifi,
                    size: 56,
                    color: Color(0xFF60A5FA),
                  ),
                  Positioned(
                    bottom: 24,
                    right: 28,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        size: 22,
                        color: Color(0xFFEF4444),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 26),
            const Text(
              'No Internet Connection',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                color: MausamTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Check your network and try again.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: MausamTheme.textMuted,
              ),
            ),
            const SizedBox(height: 28),
            if (onRetry != null)
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onRetry,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF1E3A8A),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Retry', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ),
            if (onSettings != null) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: onSettings,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: MausamTheme.textSecondary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: MausamTheme.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Go to Settings', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Screen 12 (Left): No Alerts Available
class MausamNoAlertsView extends StatelessWidget {
  final VoidCallback? onBackHome;

  const MausamNoAlertsView({super.key, this.onBackHome});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFF1F5F9),
              ),
              child: const Icon(
                Icons.notifications_none_rounded,
                size: 58,
                color: Color(0xFF3B82F6),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No Alerts Available',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                color: MausamTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'There are currently no weather alerts\nfrom the connected source.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: MausamTheme.textMuted,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 28),
            if (onBackHome != null)
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onBackHome,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF1E3A8A),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Back to Home', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Screen 12 (Right): No Data Available
class MausamNoDataView extends StatelessWidget {
  final VoidCallback? onRetry;

  const MausamNoDataView({super.key, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFF1F5F9),
              ),
              child: const Icon(
                Icons.find_in_page_outlined,
                size: 56,
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No Data Available',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                color: MausamTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "We couldn't find specific data for this\nlocation right now.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: MausamTheme.textMuted,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 28),
            if (onRetry != null)
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onRetry,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF1E3A8A),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Try Again', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
