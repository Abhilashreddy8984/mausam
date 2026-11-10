import 'package:flutter/material.dart';

/// Structured data model representing computed farmer advisory recommendations.
/// Derived strictly from meteorological parameters (rain, wind, temp, humidity, severe alerts).
class FarmerAdvisoryData {
  final bool hasData;
  final String statusBadge;
  final String statusSubtitle;
  final Color statusColor;
  final IconData statusIcon;
  final String cropAdvisory;
  final String pestWatch;
  final String soilMoisture;
  final String expectedRain;
  final String sprayingAdvisory;
  final String summaryTitle;
  final String summaryText;
  final String harvestWindow;
  final String nextDryWindow;
  final String officialTip;
  final String? errorMessage;

  const FarmerAdvisoryData({
    required this.hasData,
    required this.statusBadge,
    required this.statusSubtitle,
    required this.statusColor,
    required this.statusIcon,
    required this.cropAdvisory,
    required this.pestWatch,
    required this.soilMoisture,
    required this.expectedRain,
    required this.sprayingAdvisory,
    required this.summaryTitle,
    required this.summaryText,
    required this.harvestWindow,
    required this.nextDryWindow,
    required this.officialTip,
    this.errorMessage,
  });

  /// Factory for empty or error state when live weather data cannot be read.
  factory FarmerAdvisoryData.empty({String? message}) {
    return FarmerAdvisoryData(
      hasData: false,
      statusBadge: 'Advisory Unavailable',
      statusSubtitle: message ?? 'Live agricultural advisory requires active weather data.',
      statusColor: const Color(0xFF64748B),
      statusIcon: Icons.cloud_off_rounded,
      cropAdvisory: 'Data unavailable',
      pestWatch: 'Data unavailable',
      soilMoisture: 'Data unavailable',
      expectedRain: 'Data unavailable',
      sprayingAdvisory: 'Data unavailable',
      summaryTitle: 'Agricultural Weather Advisory',
      summaryText: message ??
          'Current weather observations could not be retrieved. Please check your network connection and refresh.',
      harvestWindow: 'Not available',
      nextDryWindow: 'Not available',
      officialTip: 'Source: IMD Agrimet Division. Please connect to internet to receive official advisories.',
      errorMessage: message,
    );
  }
}
