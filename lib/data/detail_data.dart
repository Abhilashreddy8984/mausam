// ============================================================
// data/detail_data.dart
// Extended demo content shown on the WeatherDetailScreen.
// Each WeatherCardType maps to a WeatherDetailContent object.
//
// TODO (backend): replace static strings with parsed API fields.
// ============================================================

import 'package:flutter/material.dart';
import '../models/persona.dart';

// ─────────────────────────────────────────────────────────────
// A single detail item row (label + value) shown on detail screen
// ─────────────────────────────────────────────────────────────
class DetailRow {
  final String label;
  final String value;
  final IconData? icon;
  const DetailRow({required this.label, required this.value, this.icon});
}

// ─────────────────────────────────────────────────────────────
// WeatherDetailContent — full content for one detail screen
// ─────────────────────────────────────────────────────────────
class WeatherDetailContent {
  final WeatherCardType type;
  final String title;
  final IconData icon;
  final Color accentColor;
  final String heroValue;      // large number / status shown at top
  final String heroUnit;       // unit label beside hero value
  final String summary;        // 1–2 sentence explanation
  final List<DetailRow> rows;  // additional data rows
  final String? tip;           // optional action tip / advisory

  const WeatherDetailContent({
    required this.type,
    required this.title,
    required this.icon,
    required this.accentColor,
    required this.heroValue,
    required this.heroUnit,
    required this.summary,
    required this.rows,
    this.tip,
  });
}

// ─────────────────────────────────────────────────────────────
// The catalogue — keyed by WeatherCardType
// ─────────────────────────────────────────────────────────────
const Map<WeatherCardType, WeatherDetailContent> kDetailContent = {
  WeatherCardType.rain: WeatherDetailContent(
    type: WeatherCardType.rain,
    title: 'Rainfall',
    icon: Icons.water_drop,
    accentColor: Color(0xFF1976D2),
    heroValue: '55',
    heroUnit: '% chance',
    summary:
        'Moderate probability of rain between 4 PM and 7 PM today. '
        'An estimated 8 mm of rainfall is expected during this window.',
    rows: [
      DetailRow(label: 'Expected rainfall', value: '~8 mm', icon: Icons.water_drop),
      DetailRow(label: 'Rain window', value: '4 PM – 7 PM', icon: Icons.access_time),
      DetailRow(label: 'Last 24 h', value: '2.4 mm recorded', icon: Icons.history),
      DetailRow(label: 'Monthly average', value: '85 mm (Sep)', icon: Icons.calendar_month),
      DetailRow(label: 'Forecast (3-day)', value: 'Rain likely Thu & Fri', icon: Icons.date_range),
    ],
    tip: 'Carry an umbrella if going out between 3–8 PM. '
        'Farmers: hold off irrigation — natural rain expected tonight.',
  ),

  WeatherCardType.temperature: WeatherDetailContent(
    type: WeatherCardType.temperature,
    title: 'Temperature',
    icon: Icons.thermostat,
    accentColor: Color(0xFFE64A19),
    heroValue: '32',
    heroUnit: '°C',
    summary:
        'Current temperature is 32 °C with a feels-like of 35 °C due to '
        'high humidity. Expect a high of 34 °C and overnight low of 26 °C.',
    rows: [
      DetailRow(label: 'Feels like', value: '35 °C', icon: Icons.thermostat_outlined),
      DetailRow(label: "Today's high", value: '34 °C', icon: Icons.arrow_upward),
      DetailRow(label: "Today's low", value: '26 °C', icon: Icons.arrow_downward),
      DetailRow(label: 'Humidity', value: '68%', icon: Icons.water_drop_outlined),
      DetailRow(label: 'Dew point', value: '24 °C', icon: Icons.opacity),
      DetailRow(label: '3-day forecast', value: '33 / 34 / 31 °C', icon: Icons.date_range),
    ],
    tip: 'Heat index is elevated. Stay hydrated and avoid prolonged sun exposure '
        'between 11 AM and 3 PM.',
  ),

  WeatherCardType.aqi: WeatherDetailContent(
    type: WeatherCardType.aqi,
    title: 'Air Quality Index',
    icon: Icons.air,
    accentColor: Color(0xFFF9A825),
    heroValue: '112',
    heroUnit: 'AQI',
    summary:
        'AQI is 112, classified as Moderate. Fine particulate matter (PM2.5) '
        'is the dominant pollutant. Sensitive groups should limit outdoor exposure.',
    rows: [
      DetailRow(label: 'Category', value: 'Moderate', icon: Icons.info_outline),
      DetailRow(label: 'PM2.5', value: '42 µg/m³', icon: Icons.grain),
      DetailRow(label: 'PM10', value: '68 µg/m³', icon: Icons.grain),
      DetailRow(label: 'NO₂', value: '28 µg/m³', icon: Icons.science_outlined),
      DetailRow(label: 'O₃ (Ozone)', value: '72 µg/m³', icon: Icons.wb_sunny_outlined),
      DetailRow(label: 'CO', value: '0.8 mg/m³', icon: Icons.local_fire_department_outlined),
    ],
    tip: 'People with respiratory conditions should avoid vigorous outdoor activity. '
        'Running indoors with windows closed is recommended.',
  ),

  WeatherCardType.uvIndex: WeatherDetailContent(
    type: WeatherCardType.uvIndex,
    title: 'UV Index',
    icon: Icons.wb_sunny,
    accentColor: Color(0xFFFF6F00),
    heroValue: '7',
    heroUnit: 'UV Index',
    summary:
        'UV Index of 7 is classified as High. Unprotected skin can burn '
        'in as little as 25 minutes during peak hours.',
    rows: [
      DetailRow(label: 'Category', value: 'High (6–7)', icon: Icons.info_outline),
      DetailRow(label: 'Peak hours', value: '11 AM – 2 PM', icon: Icons.access_time),
      DetailRow(label: 'Burn time (fair skin)', value: '~25 min', icon: Icons.timer_outlined),
      DetailRow(label: 'Recommended SPF', value: 'SPF 30 or higher', icon: Icons.health_and_safety),
      DetailRow(label: 'Tomorrow forecast', value: 'UV 8 · Very High', icon: Icons.date_range),
    ],
    tip: 'Wear sunscreen (SPF 30+), UV-blocking sunglasses, and protective clothing. '
        'Seek shade between 11 AM and 2 PM.',
  ),

  WeatherCardType.wind: WeatherDetailContent(
    type: WeatherCardType.wind,
    title: 'Wind',
    icon: Icons.wind_power,
    accentColor: Color(0xFF00838F),
    heroValue: '14',
    heroUnit: 'km/h',
    summary:
        'Winds are currently blowing from the south-west at 14 km/h. '
        'Evening gusts are forecast to reach 28 km/h ahead of the storm.',
    rows: [
      DetailRow(label: 'Direction', value: 'South-West (SW)', icon: Icons.explore_outlined),
      DetailRow(label: 'Current speed', value: '14 km/h', icon: Icons.speed),
      DetailRow(label: 'Expected gusts', value: 'Up to 28 km/h (eve)', icon: Icons.air),
      DetailRow(label: 'Beaufort scale', value: '3 – Gentle breeze', icon: Icons.info_outline),
      DetailRow(label: 'Wind chill effect', value: 'Negligible at 32 °C', icon: Icons.thermostat_outlined),
    ],
    tip: 'Secure loose outdoor objects before 4 PM. Gusts during the '
        'thunderstorm window may be stronger.',
  ),

  WeatherCardType.weatherAlert: WeatherDetailContent(
    type: WeatherCardType.weatherAlert,
    title: 'Weather Alert',
    icon: Icons.warning_amber_rounded,
    accentColor: Color(0xFFF57F17),
    heroValue: '⚠',
    heroUnit: 'Yellow Alert',
    summary:
        'IMD has issued a Yellow Alert for Hyderabad district. '
        'Thunderstorm with lightning and gusty winds (30–40 km/h) '
        'is expected between 3 PM and 8 PM.',
    rows: [
      DetailRow(label: 'Issued by', value: 'IMD Hyderabad', icon: Icons.account_balance_outlined),
      DetailRow(label: 'Severity', value: 'Yellow (Watch)', icon: Icons.warning_outlined),
      DetailRow(label: 'Valid period', value: '3:00 PM – 8:00 PM today', icon: Icons.access_time),
      DetailRow(label: 'Affected districts', value: 'Hyderabad, Rangareddy, Medchal', icon: Icons.location_on_outlined),
      DetailRow(label: 'Hazards', value: 'Lightning, gusty winds, heavy rain', icon: Icons.bolt),
    ],
    tip: 'Avoid open areas, tall trees, and metal structures between 3–8 PM. '
        'Keep emergency contacts handy.',
  ),

  WeatherCardType.farmAdvisory: WeatherDetailContent(
    type: WeatherCardType.farmAdvisory,
    title: 'Farm Advisory',
    icon: Icons.grass,
    accentColor: Color(0xFF388E3C),
    heroValue: 'Hold',
    heroUnit: 'irrigation',
    summary:
        '8–10 mm of rain is expected tonight. Irrigation scheduled for today '
        'should be postponed. Standing crops vulnerable to lodging should be '
        'harvested or tied before evening.',
    rows: [
      DetailRow(label: 'Crop advisory', value: 'Delay irrigation 24 h', icon: Icons.grass),
      DetailRow(label: 'Pest watch', value: 'High humidity — watch for blight', icon: Icons.bug_report_outlined),
      DetailRow(label: 'Soil moisture', value: 'Adequate (pre-rain)', icon: Icons.water_drop_outlined),
      DetailRow(label: 'Harvest window', value: 'Before 3 PM today', icon: Icons.agriculture),
      DetailRow(label: 'Next dry window', value: 'Sat–Sun forecast dry', icon: Icons.wb_sunny_outlined),
    ],
    tip: 'Source: IMD Agrimet Division. Advisory is indicative — '
        'verify with local Krishi Vigyan Kendra before major decisions.',
  ),

  WeatherCardType.travelAdvisory: WeatherDetailContent(
    type: WeatherCardType.travelAdvisory,
    title: 'Travel Advisory',
    icon: Icons.directions_car,
    accentColor: Color(0xFF5E35B1),
    heroValue: 'Moderate',
    heroUnit: 'disruption',
    summary:
        'Fog patches on NH-44 near Jadcherla are reducing visibility. '
        'Waterlogging at Mehdipatnam underpass may affect TSRTC buses '
        'on routes 5C, 10K, and 216.',
    rows: [
      DetailRow(label: 'Road condition', value: 'Caution — fog on NH-44', icon: Icons.visibility_off_outlined),
      DetailRow(label: 'Affected routes', value: 'TSRTC 5C, 10K, 216', icon: Icons.directions_bus_outlined),
      DetailRow(label: 'Waterlogging', value: 'Mehdipatnam underpass', icon: Icons.water),
      DetailRow(label: 'Metro status', value: 'Normal operations', icon: Icons.train_outlined),
      DetailRow(label: 'Airport', value: 'No delays reported', icon: Icons.flight_outlined),
    ],
    tip: 'Allow extra 15–20 min travel time. Prefer metro for city routes '
        'during evening storm window.',
  ),

  WeatherCardType.visibility: WeatherDetailContent(
    type: WeatherCardType.visibility,
    title: 'Visibility',
    icon: Icons.visibility,
    accentColor: Color(0xFF0288D1),
    heroValue: '8.5',
    heroUnit: 'km',
    summary:
        'Visibility is currently good at 8.5 km. It is expected to drop '
        'to 3–4 km after 4 PM due to incoming rain and possible fog pockets.',
    rows: [
      DetailRow(label: 'Current', value: '8.5 km (Good)', icon: Icons.visibility),
      DetailRow(label: 'Forecast (4–8 PM)', value: '3–4 km (Moderate)', icon: Icons.visibility_outlined),
      DetailRow(label: 'Overnight', value: '< 1 km possible (fog)', icon: Icons.nights_stay_outlined),
      DetailRow(label: 'Airport CAVOK', value: 'Yes (till 3 PM)', icon: Icons.flight_outlined),
      DetailRow(label: 'Relative humidity', value: '68% rising to 85%', icon: Icons.water_drop_outlined),
    ],
    tip: 'Drivers: switch on headlights and maintain safe following distance '
        'after 4 PM. Aviators: check METAR before departure.',
  ),

  WeatherCardType.marineTide: WeatherDetailContent(
    type: WeatherCardType.marineTide,
    title: 'Marine / Tide',
    icon: Icons.waves,
    accentColor: Color(0xFF00695C),
    heroValue: '1.2',
    heroUnit: 'm waves',
    summary:
        'Sea state is moderate with wave heights of 1.2 m. A fishing '
        'advisory is in effect for the Bay of Bengal coastal belt. '
        'Fishermen are advised not to venture into the deep sea.',
    rows: [
      DetailRow(label: 'Wave height', value: '1.2 m (Moderate)', icon: Icons.waves),
      DetailRow(label: 'Low tide', value: '06:14 IST', icon: Icons.arrow_downward),
      DetailRow(label: 'High tide', value: '12:38 IST', icon: Icons.arrow_upward),
      DetailRow(label: 'Next low tide', value: '18:52 IST', icon: Icons.arrow_downward),
      DetailRow(label: 'Sea surface temp', value: '28.5 °C', icon: Icons.thermostat_outlined),
      DetailRow(label: 'Fishing advisory', value: 'Active — avoid deep sea', icon: Icons.warning_outlined),
    ],
    tip: 'Fishermen: do not venture into deep sea until advisory is lifted. '
        'Coastal residents: monitor tide levels during evening high water.',
  ),

  WeatherCardType.humidity: WeatherDetailContent(
    type: WeatherCardType.humidity,
    title: 'Humidity',
    icon: Icons.water_drop_outlined,
    accentColor: Color(0xFF1565C0),
    heroValue: '68',
    heroUnit: '%',
    summary:
        'Relative humidity is 68%, making the effective temperature feel '
        'significantly higher than the thermometer reading of 32 °C.',
    rows: [
      DetailRow(label: 'Relative humidity', value: '68%', icon: Icons.water_drop_outlined),
      DetailRow(label: 'Dew point', value: '24 °C', icon: Icons.opacity),
      DetailRow(label: 'Feels like (heat index)', value: '35 °C', icon: Icons.thermostat_outlined),
      DetailRow(label: 'Forecast peak', value: '~85% after rain', icon: Icons.trending_up),
      DetailRow(label: 'Comfort level', value: 'Humid — uncomfortable outdoors', icon: Icons.sentiment_dissatisfied_outlined),
    ],
    tip: 'Drink water frequently. High humidity reduces the body\'s ability '
        'to cool through sweating — limit strenuous outdoor activity.',
  ),
};
