// ============================================================
// services/advisory_service.dart
//
// Advisory and Alert Engine for Mausam Personalized Weather.
//
// Core Features:
// 1. Condition-specific safety precautions:
//    - Haze/Fog: strictly visibility & respiratory precautions.
//    - Heavy Rain: waterlogging, flooding, and drainage precautions.
//    - Thunderstorms: lightning, shelter, and electrical precautions.
//    - Strong Wind: structural security, gust precautions.
//    - Heatwave: hydration, peak sun avoidance, heat-illness safety.
//    - Cold Wave: warm layering, hypothermia prevention.
// 2. Clear distinction of Official IMD Alerts vs Calculated Weather Risks.
// 3. No fabrication of validity windows or missing parameters.
// 4. Actionable recommendations tailored to all 8 user personas.
// ============================================================

import 'package:flutter/material.dart';

import '../models/homepage_response.dart';
import '../models/persona.dart';
import '../models/weather_data.dart';

class AdvisoryService {
  AdvisoryService._();

  /// Resolves the primary alert/advisory for current weather snapshot.
  ///
  /// If [officialWarnings] contains active alerts from IMD, those are used
  /// with [AlertSource.officialImd].
  /// Otherwise, an internal risk assessment is performed based on validated
  /// metrics (condition, visibility, wind, rainfall, temperature, AQI)
  /// and marked [AlertSource.calculated] or [AlertSource.normal].
  static WeatherAlert resolveAlert(
    WeatherData weather, {
    List<BackendWeatherWarning>? officialWarnings,
  }) {
    final locationName = weather.city.isNotEmpty
        ? (weather.state.isNotEmpty ? '${weather.city}, ${weather.state}' : weather.city)
        : 'Your Location';

    final windText = weather.windSpeedKmh > 0
        ? '${weather.windSpeedInt} km/h ${weather.windDirection}'.trim()
        : 'Calm winds';

    final rainText = weather.rainfallAmountMm != null
        ? (weather.rainfallAmountMm! > 0
            ? '${weather.rainfallAmountMm!.toStringAsFixed(weather.rainfallAmountMm! == weather.rainfallAmountMm!.roundToDouble() ? 0 : 1)} mm expected'
            : '0 mm expected')
        : 'Precipitation data unavailable';

    // ── 1. Check for official IMD warnings ──────────────────────
    if (officialWarnings != null && officialWarnings.isNotEmpty) {
      final activeWarning = officialWarnings.firstWhere(
        (w) => w.title != null || w.warningType != null || w.description != null,
        orElse: () => officialWarnings.first,
      );

      final wType = (activeWarning.warningType ?? '').toLowerCase();
      final wTitle = (activeWarning.title ?? '').toLowerCase();
      final wDesc = (activeWarning.description ?? '').toLowerCase();
      final combined = '$wType $wTitle $wDesc';

      final hazard = _detectHazardType(
        condition: weather.weatherCondition,
        weatherCode: weather.weatherCode,
        textToSearch: combined,
        visibilityKm: weather.visibilityKm,
        rainfallMm: weather.rainfallAmountMm,
        windSpeedKmh: weather.windSpeedKmh,
        temperatureC: weather.temperatureC,
        aqi: weather.aqi,
      );

      final severity = _parseSeverity(
        activeWarning.severity ?? activeWarning.warningType,
        defaultSeverity: AlertSeverity.medium,
      );

      final validity = _formatValidity(activeWarning.validFrom, activeWarning.validUntil);

      return WeatherAlert(
        title: activeWarning.title ?? activeWarning.warningType ?? 'IMD Weather Warning',
        headline: activeWarning.description ?? '${weather.weatherCondition} Warning',
        condition: weather.weatherCondition.isNotEmpty
            ? weather.weatherCondition
            : (activeWarning.title ?? 'Weather Event'),
        severity: severity,
        source: AlertSource.officialImd,
        hazardType: hazard,
        validPeriod: validity,
        issuedTime: activeWarning.validFrom,
        affectedLocation: activeWarning.district ?? locationName,
        windImpact: windText,
        rainImpact: rainText,
        precautions: getPrecautionsForHazard(hazard, weather),
      );
    }

    // ── 2. Calculated Weather Risk Evaluation ──────────────────
    final hazard = _detectHazardType(
      condition: weather.weatherCondition,
      weatherCode: weather.weatherCode,
      visibilityKm: weather.visibilityKm,
      rainfallMm: weather.rainfallAmountMm,
      windSpeedKmh: weather.windSpeedKmh,
      temperatureC: weather.temperatureC,
      aqi: weather.aqi,
    );

    switch (hazard) {
      case WeatherHazardType.hazeFog:
        final isSevereFog = weather.visibilityKm < 1.0;
        final isFog = weather.weatherCondition.toLowerCase().contains('fog') ||
            weather.visibilityKm <= 1.5;
        final title = isFog ? 'Fog & Low Visibility Advisory' : 'Haze & Visibility Advisory';
        final headline = isFog
            ? 'Dense fog significantly reducing road visibility'
            : 'Haze with reduced horizontal visibility';

        return WeatherAlert(
          title: title,
          headline: headline,
          condition: weather.weatherCondition.isNotEmpty ? weather.weatherCondition : 'Haze',
          severity: isSevereFog ? AlertSeverity.high : AlertSeverity.medium,
          source: AlertSource.calculated,
          hazardType: WeatherHazardType.hazeFog,
          validPeriod: null, // Do not invent fake validity hours
          affectedLocation: locationName,
          windImpact: windText,
          rainImpact: rainText,
          precautions: getPrecautionsForHazard(WeatherHazardType.hazeFog, weather),
        );

      case WeatherHazardType.thunderstorm:
        return WeatherAlert(
          title: 'Thunderstorm Advisory',
          headline: 'Thunderstorm with lightning risk in the area',
          condition: weather.weatherCondition.isNotEmpty ? weather.weatherCondition : 'Thunderstorm',
          severity: AlertSeverity.medium,
          source: AlertSource.calculated,
          hazardType: WeatherHazardType.thunderstorm,
          validPeriod: null,
          affectedLocation: locationName,
          windImpact: windText,
          rainImpact: rainText,
          precautions: getPrecautionsForHazard(WeatherHazardType.thunderstorm, weather),
        );

      case WeatherHazardType.heavyRain:
        final isVeryHeavy = (weather.rainfallAmountMm ?? 0) >= 50.0;
        return WeatherAlert(
          title: isVeryHeavy ? 'Heavy Rainfall Warning' : 'Moderate to Heavy Rain Advisory',
          headline: 'Rainfall may cause localized waterlogging and transit delays',
          condition: weather.weatherCondition.isNotEmpty ? weather.weatherCondition : 'Heavy Rain',
          severity: isVeryHeavy ? AlertSeverity.high : AlertSeverity.medium,
          source: AlertSource.calculated,
          hazardType: WeatherHazardType.heavyRain,
          validPeriod: null,
          affectedLocation: locationName,
          windImpact: windText,
          rainImpact: rainText,
          precautions: getPrecautionsForHazard(WeatherHazardType.heavyRain, weather),
        );

      case WeatherHazardType.strongWind:
        final isGale = weather.windSpeedKmh >= 60.0;
        return WeatherAlert(
          title: isGale ? 'High Wind Warning' : 'Strong Wind Advisory',
          headline: 'Gusty winds may affect light structures and two-wheeler balance',
          condition: weather.weatherCondition.isNotEmpty ? weather.weatherCondition : 'High Wind',
          severity: isGale ? AlertSeverity.high : AlertSeverity.medium,
          source: AlertSource.calculated,
          hazardType: WeatherHazardType.strongWind,
          validPeriod: null,
          affectedLocation: locationName,
          windImpact: windText,
          rainImpact: rainText,
          precautions: getPrecautionsForHazard(WeatherHazardType.strongWind, weather),
        );

      case WeatherHazardType.heatwave:
        final isExtreme = weather.temperatureC >= 43.0;
        return WeatherAlert(
          title: isExtreme ? 'Severe Heatwave Advisory' : 'High Temperature & Heat Advisory',
          headline: 'Elevated daytime temperatures require active hydration and sun safety',
          condition: weather.weatherCondition.isNotEmpty ? weather.weatherCondition : 'High Temperature',
          severity: isExtreme ? AlertSeverity.high : AlertSeverity.medium,
          source: AlertSource.calculated,
          hazardType: WeatherHazardType.heatwave,
          validPeriod: null,
          affectedLocation: locationName,
          windImpact: windText,
          rainImpact: rainText,
          precautions: getPrecautionsForHazard(WeatherHazardType.heatwave, weather),
        );

      case WeatherHazardType.coldWave:
        final isSevereCold = weather.temperatureC <= 4.0;
        return WeatherAlert(
          title: isSevereCold ? 'Severe Cold Wave Advisory' : 'Cold Weather Advisory',
          headline: 'Low temperatures require adequate thermal protection',
          condition: weather.weatherCondition.isNotEmpty ? weather.weatherCondition : 'Cold Wave',
          severity: isSevereCold ? AlertSeverity.high : AlertSeverity.medium,
          source: AlertSource.calculated,
          hazardType: WeatherHazardType.coldWave,
          validPeriod: null,
          affectedLocation: locationName,
          windImpact: windText,
          rainImpact: rainText,
          precautions: getPrecautionsForHazard(WeatherHazardType.coldWave, weather),
        );

      case WeatherHazardType.poorAqi:
        final isSevereAqi = (weather.aqi ?? 0) >= 350;
        return WeatherAlert(
          title: 'Air Quality Advisory',
          headline: 'Unfavorable air quality levels. Sensitive groups limit outdoor exposure',
          condition: 'High Pollution (AQI ${weather.aqi})',
          severity: isSevereAqi ? AlertSeverity.high : AlertSeverity.medium,
          source: AlertSource.calculated,
          hazardType: WeatherHazardType.poorAqi,
          validPeriod: null,
          affectedLocation: locationName,
          windImpact: windText,
          rainImpact: rainText,
          precautions: getPrecautionsForHazard(WeatherHazardType.poorAqi, weather),
        );

      case WeatherHazardType.normal:
        return WeatherAlert(
          title: 'Normal Weather Conditions',
          headline: 'No severe weather alerts active for your area',
          condition: weather.weatherCondition.isNotEmpty ? weather.weatherCondition : 'Fair',
          severity: AlertSeverity.low,
          source: AlertSource.normal,
          hazardType: WeatherHazardType.normal,
          validPeriod: null,
          affectedLocation: locationName,
          windImpact: windText,
          rainImpact: rainText,
          precautions: getPrecautionsForHazard(WeatherHazardType.normal, weather),
        );
    }
  }

  /// Categorizes hazard according to verified conditions and metrics.
  static WeatherHazardType _detectHazardType({
    required String condition,
    String? weatherCode,
    String textToSearch = '',
    required double visibilityKm,
    double? rainfallMm,
    required double windSpeedKmh,
    required double temperatureC,
    int? aqi,
  }) {
    final c = condition.toLowerCase();
    final combined = '$c $textToSearch';

    // 1. Thunderstorm / Lightning
    if (combined.contains('thunder') ||
        combined.contains('lightning') ||
        combined.contains('squall') ||
        weatherCode == '4' ||
        weatherCode == '17' ||
        weatherCode == '29' ||
        weatherCode == '95' ||
        weatherCode == '99') {
      return WeatherHazardType.thunderstorm;
    }

    // 2. Heavy Rain
    if (combined.contains('heavy rain') ||
        combined.contains('downpour') ||
        combined.contains('torrential') ||
        (rainfallMm != null && rainfallMm >= 15.0) ||
        weatherCode == '9' ||
        weatherCode == '64' ||
        weatherCode == '65' ||
        weatherCode == '81' ||
        weatherCode == '82') {
      return WeatherHazardType.heavyRain;
    }

    // 3. Haze / Fog / Mist / Low Visibility
    // Checked BEFORE general rain if visibility is restricted and no thunderstorm
    if (combined.contains('haze') ||
        combined.contains('fog') ||
        combined.contains('mist') ||
        combined.contains('smoke') ||
        visibilityKm <= 3.0 ||
        weatherCode == '5' ||
        weatherCode == '6' ||
        weatherCode == '28' ||
        weatherCode == '41' ||
        weatherCode == '45') {
      return WeatherHazardType.hazeFog;
    }

    // 4. Strong Wind
    if (combined.contains('gale') ||
        combined.contains('high wind') ||
        combined.contains('wind warning') ||
        windSpeedKmh >= 40.0) {
      return WeatherHazardType.strongWind;
    }

    // 5. Extreme Heat
    if (combined.contains('heat') ||
        combined.contains('hot') ||
        temperatureC >= 40.0) {
      return WeatherHazardType.heatwave;
    }

    // 6. Cold Wave
    if (combined.contains('cold') ||
        combined.contains('freeze') ||
        temperatureC <= 8.0) {
      return WeatherHazardType.coldWave;
    }

    // 7. Poor AQI
    if (aqi != null && aqi >= 250) {
      return WeatherHazardType.poorAqi;
    }

    return WeatherHazardType.normal;
  }

  /// Parses warning severity strings safely.
  static AlertSeverity _parseSeverity(String? raw, {AlertSeverity defaultSeverity = AlertSeverity.medium}) {
    if (raw == null) return defaultSeverity;
    final r = raw.toLowerCase();
    if (r.contains('red') || r.contains('extreme') || r.contains('severe')) {
      return AlertSeverity.extreme;
    }
    if (r.contains('orange') || r.contains('high')) {
      return AlertSeverity.high;
    }
    if (r.contains('yellow') || r.contains('moderate') || r.contains('watch') || r.contains('medium')) {
      return AlertSeverity.medium;
    }
    if (r.contains('green') || r.contains('low') || r.contains('advisory')) {
      return AlertSeverity.low;
    }
    return defaultSeverity;
  }

  /// Formats official valid_from and valid_until strings. Does not fabricate if missing.
  static String? _formatValidity(String? from, String? until) {
    if (from == null && until == null) return null;
    if (from != null && until != null) {
      return 'Valid: $from – $until';
    }
    if (until != null) {
      return 'Valid until $until';
    }
    return 'Effective from $from';
  }

  /// Provides strictly condition-specific actionable safety recommendations.
  /// Never combines unrelated precautions (e.g. thunderstorm precautions with haze).
  static List<String> getPrecautionsForHazard(WeatherHazardType hazard, WeatherData weather) {
    switch (hazard) {
      case WeatherHazardType.hazeFog:
        return [
          'Turn on low-beam headlights or fog lights while driving; avoid high-beam glare.',
          'Maintain increased following distance behind vehicles due to reduced braking visibility.',
          'Pedestrians and cyclists: wear bright or reflective clothing near traffic.',
          'Sensitive groups with respiratory issues should wear a protective mask outdoors.',
        ];

      case WeatherHazardType.thunderstorm:
        return [
          'Stay indoors and keep windows shut — ensure all windows and doors firmly shut until the storm passes.',
          'Avoid open areas, tall trees, and metal structures; keep away from open fields and tall isolated trees during lightning.',
          'Unplug sensitive electrical appliances to prevent surge damage.',
          'Motorists: slow down and beware of localized waterlogging and slippery roads.',
        ];

      case WeatherHazardType.heavyRain:
        return [
          'Avoid driving through waterlogged underpasses and flooded road stretches.',
          'Ensure rooftop and property storm drains are clear of debris to prevent pooling.',
          'Drive at reduced speeds and check tire traction on wet pavement.',
          'Stay away from open stormwater drains, electric junction boxes, and fallen wires.',
        ];

      case WeatherHazardType.strongWind:
        return [
          'Secure loose outdoor objects, balcony furniture, and temporary tin sheds.',
          'Stay clear of large trees, billboard hoardings, and construction sites.',
          'Drivers of two-wheelers and high-profile vehicles should exercise extra caution against crosswinds.',
          'Avoid parking vehicles underneath weak tree limbs or overhead utility lines.',
        ];

      case WeatherHazardType.heatwave:
        return [
          'Drink water frequently throughout the day, even if not actively feeling thirsty.',
          'Avoid direct sun exposure and strenuous outdoor tasks between 11 AM and 3 PM.',
          'Wear loose, lightweight cotton clothing and a wide-brimmed hat or umbrella outdoors.',
          'Check on elderly family members and never leave children or pets inside parked vehicles.',
        ];

      case WeatherHazardType.coldWave:
        return [
          'Dress in warm, multiple clothing layers and cover your head, hands, and feet.',
          'Ensure infants and senior citizens are sheltered from cold drafts and hypothermia.',
          'Operate room heaters with adequate ventilation to prevent carbon monoxide buildup.',
          'Keep warm beverages and nourishing warm meals handy during peak cold hours.',
        ];

      case WeatherHazardType.poorAqi:
        return [
          'Wear a well-fitted N95 or anti-pollution mask when stepping outside.',
          'Avoid vigorous outdoor physical workouts during early morning and late evening hours.',
          'Keep indoor windows closed during peak traffic hours and run air filtration if available.',
          'Individuals with asthma or chronic bronchitis should keep prescribed inhalers accessible.',
        ];

      case WeatherHazardType.normal:
        return [
          'No severe weather alerts active for your area.',
          'Current weather conditions are favorable for routine daily and outdoor activities.',
          'Stay adequately hydrated and follow seasonal comfort recommendations.',
        ];
    }
  }

  /// Generates tailored, actionable persona recommendations based on validated conditions.
  static PersonaAdvisory getPersonaAdvisory(
    Persona persona,
    WeatherData weather,
    WeatherAlert alert,
  ) {
    final rain = weather.rainfallAmountMm ?? 0.0;
    final wind = weather.windSpeedKmh;
    final temp = weather.temperatureC;
    final vis = weather.visibilityKm;
    final aqi = weather.aqi ?? 50;

    switch (persona) {
      // ── 1. FARMER ──────────────────────────────────────────────
      case Persona.farmer:
        if (alert.hazardType == WeatherHazardType.thunderstorm) {
          return const PersonaAdvisory(
            persona: Persona.farmer,
            headline: 'Thunderstorm Risk — Halt Field Work',
            recommendation: 'Suspend outdoor field operations immediately. Seek shelter indoors away from metal implements.',
            actionableTip: 'Secure livestock under sturdy shelter. Check field bunds after the storm to avoid soil erosion.',
            fieldSuitability: 'Unfavorable for Field Work',
            icon: Icons.bolt_rounded,
            accentColor: Color(0xFFDC2626),
          );
        } else if (rain >= 5.0 || (weather.rainfallProbability != null && weather.rainfallProbability! >= 40.0) || alert.hazardType == WeatherHazardType.heavyRain) {
          return PersonaAdvisory(
            persona: Persona.farmer,
            headline: 'Hold Irrigation — Rainfall Expected',
            recommendation: 'Postpone scheduled irrigation as natural precipitation (${rain.toInt()} mm) is expected.',
            actionableTip: 'Ensure proper drainage in standing crop plots to prevent root waterlogging.',
            fieldSuitability: 'Caution in Fields',
            icon: Icons.water_drop_rounded,
            accentColor: const Color(0xFF2563EB),
          );
        } else if (temp >= 38.0 || alert.hazardType == WeatherHazardType.heatwave) {
          return const PersonaAdvisory(
            persona: Persona.farmer,
            headline: 'High Evaporation — Irrigate During Cool Hours',
            recommendation: 'Irrigate crops during early morning or late evening to minimize moisture loss from heat.',
            actionableTip: 'Provide shaded resting areas and ample drinking water for working livestock.',
            fieldSuitability: 'Work During Early Hours',
            icon: Icons.wb_sunny_rounded,
            accentColor: Color(0xFFD97706),
          );
        } else if (wind >= 35.0 || alert.hazardType == WeatherHazardType.strongWind) {
          return const PersonaAdvisory(
            persona: Persona.farmer,
            headline: 'High Winds — Postpone Spraying',
            recommendation: 'Do not spray pesticides or foliar fertilizers due to spray drift in strong winds.',
            actionableTip: 'Provide mechanical propping or staking for tall standing crops like banana or sugarcane.',
            fieldSuitability: 'Moderate Caution',
            icon: Icons.air_rounded,
            accentColor: Color(0xFF0D9488),
          );
        } else {
          return const PersonaAdvisory(
            persona: Persona.farmer,
            headline: 'Favorable Conditions for Farming',
            recommendation: 'Weather conditions are generally favorable for standard intercultural operations and harvesting.',
            actionableTip: 'Check soil moisture levels before routine irrigation; monitor crops for seasonal pest activity.',
            fieldSuitability: 'Good for Field Work',
            icon: Icons.grass_rounded,
            accentColor: Color(0xFF16A34A),
          );
        }

      // ── 2. STUDENT ─────────────────────────────────────────────
      case Persona.student:
        if (alert.hazardType == WeatherHazardType.heavyRain || rain >= 8.0) {
          return const PersonaAdvisory(
            persona: Persona.student,
            headline: 'Rainy Commute — Carry Waterproof Gear',
            recommendation: 'Carry an umbrella or raincoat and protect school bags/laptops with waterproof covers.',
            actionableTip: 'Leave 15 minutes early to account for public transit delays near campus gates.',
            fieldSuitability: 'Transit Delays Likely',
            icon: Icons.umbrella_rounded,
            accentColor: Color(0xFF2563EB),
          );
        } else if (alert.hazardType == WeatherHazardType.hazeFog || vis <= 3.0) {
          return const PersonaAdvisory(
            persona: Persona.student,
            headline: 'Reduced Visibility on Morning Commute',
            recommendation: 'Ride bicycles or scooters carefully with headlights on due to hazy conditions.',
            actionableTip: 'Wear bright outerwear and avoid using headphones while crossing campus roads.',
            fieldSuitability: 'Caution on Roads',
            icon: Icons.visibility_outlined,
            accentColor: Color(0xFFD97706),
          );
        } else if (temp >= 38.0) {
          return const PersonaAdvisory(
            persona: Persona.student,
            headline: 'High Heat — Carry Water Bottle',
            recommendation: 'Stay hydrated during campus walks and avoid direct midday sun exposure.',
            actionableTip: 'Refill your water bottle between lectures and prefer shaded pathways.',
            fieldSuitability: 'Stay Hydrated',
            icon: Icons.local_drink_rounded,
            accentColor: Color(0xFFEA580C),
          );
        } else {
          return const PersonaAdvisory(
            persona: Persona.student,
            headline: 'Pleasant Campus Weather',
            recommendation: 'Comfortable weather conditions for classroom commute and outdoor campus activities.',
            actionableTip: 'Great time for outdoor sports and campus study sessions.',
            fieldSuitability: 'Ideal for Activities',
            icon: Icons.school_rounded,
            accentColor: Color(0xFF16A34A),
          );
        }

      // ── 3. TRAVELLER ───────────────────────────────────────────
      case Persona.traveller:
        if (alert.hazardType == WeatherHazardType.hazeFog || vis <= 3.0) {
          return PersonaAdvisory(
            persona: Persona.traveller,
            headline: 'Highway Visibility Advisory',
            recommendation: 'Visibility reduced to ${weather.visibilityStr} km. Drive with low beams and maintain safe headway.',
            actionableTip: 'Check highway travel alerts and flight schedules before leaving for the airport.',
            fieldSuitability: 'Low Visibility Caution',
            icon: Icons.directions_car_rounded,
            accentColor: const Color(0xFFD97706),
          );
        } else if (alert.hazardType == WeatherHazardType.heavyRain || rain >= 12.0) {
          return const PersonaAdvisory(
            persona: Persona.traveller,
            headline: 'Wet Roads & Hydroplaning Risk',
            recommendation: 'Water accumulation reported on key travel corridors. Reduce highway cruising speeds.',
            actionableTip: 'Avoid mountain or ghat roads vulnerable to mudslides during persistent rain.',
            fieldSuitability: 'Travel Caution',
            icon: Icons.navigation_rounded,
            accentColor: Color(0xFF2563EB),
          );
        } else {
          return PersonaAdvisory(
            persona: Persona.traveller,
            headline: 'Smooth Travel Conditions',
            recommendation: 'Clear road conditions and good visibility (${weather.visibilityStr} km) for travel.',
            actionableTip: 'Optimal time for regional sightseeing and intercity road journeys.',
            fieldSuitability: 'Ideal for Travel',
            icon: Icons.flight_takeoff_rounded,
            accentColor: const Color(0xFF16A34A),
          );
        }

      // ── 4. COMMUTER ────────────────────────────────────────────
      case Persona.commuter:
        if (alert.hazardType == WeatherHazardType.heavyRain || rain >= 10.0) {
          return const PersonaAdvisory(
            persona: Persona.commuter,
            headline: 'Waterlogging Alert on Transit Routes',
            recommendation: 'Allow extra transit time. Low-lying underpasses may experience traffic bottlenecks.',
            actionableTip: 'Consider metro or rail alternatives to bypass flooded road junctions.',
            fieldSuitability: 'Traffic Delays Expected',
            icon: Icons.directions_bus_rounded,
            accentColor: Color(0xFF2563EB),
          );
        } else if (alert.hazardType == WeatherHazardType.hazeFog || vis <= 3.0) {
          return const PersonaAdvisory(
            persona: Persona.commuter,
            headline: 'Hazy Morning Commute — Drive Carefully',
            recommendation: 'Drive with dipped headlights; avoid rapid lane changes in reduced visibility.',
            actionableTip: 'Keep front and rear defoggers active in vehicles.',
            fieldSuitability: 'Moderate Commute Risk',
            icon: Icons.commute_rounded,
            accentColor: Color(0xFFD97706),
          );
        } else {
          return const PersonaAdvisory(
            persona: Persona.commuter,
            headline: 'Normal Commute Conditions',
            recommendation: 'Clear weather across transit corridors. Public transportation operating smoothly.',
            actionableTip: 'Routine travel times expected on major arterial routes.',
            fieldSuitability: 'Good Commute',
            icon: Icons.directions_subway_rounded,
            accentColor: Color(0xFF16A34A),
          );
        }

      // ── 5. HEALTH & FITNESS ────────────────────────────────────
      case Persona.healthFitness:
        if (aqi >= 200 || alert.hazardType == WeatherHazardType.poorAqi) {
          return PersonaAdvisory(
            persona: Persona.healthFitness,
            headline: 'Poor Air Quality (AQI $aqi) — Move Indoors',
            recommendation: 'High particulate matter levels. Shift aerobic running and workouts indoors to gym facilities.',
            actionableTip: 'Wear an N95 mask if walking outdoors; keep windows shut during peak pollution.',
            fieldSuitability: 'Avoid Outdoor Workouts',
            icon: Icons.masks_rounded,
            accentColor: const Color(0xFFDC2626),
          );
        } else if (temp >= 37.0 || alert.hazardType == WeatherHazardType.heatwave) {
          return const PersonaAdvisory(
            persona: Persona.healthFitness,
            headline: 'Heat Stress Warning — Workout Early',
            recommendation: 'Schedule outdoor runs before 7:30 AM or after sunset to avoid heat cramps.',
            actionableTip: 'Electrolyte replenishment is essential; monitor heart rate in elevated temperatures.',
            fieldSuitability: 'Early Morning Only',
            icon: Icons.fitness_center_rounded,
            accentColor: Color(0xFFD97706),
          );
        } else {
          return const PersonaAdvisory(
            persona: Persona.healthFitness,
            headline: 'Great Conditions for Outdoor Fitness',
            recommendation: 'Air quality and temperature are supportive for outdoor jogs, cycling, and sports.',
            actionableTip: 'Stay hydrated and apply sunscreen for prolonged mid-morning sessions.',
            fieldSuitability: 'Optimal for Workouts',
            icon: Icons.directions_run_rounded,
            accentColor: Color(0xFF16A34A),
          );
        }

      // ── 6. OUTDOOR WORKER ──────────────────────────────────────
      case Persona.outdoorWorker:
        if (alert.hazardType == WeatherHazardType.thunderstorm) {
          return const PersonaAdvisory(
            persona: Persona.outdoorWorker,
            headline: 'Lightning Hazard — Stop Work at Heights',
            recommendation: 'Cease work on scaffolds, cranes, and metal structures immediately.',
            actionableTip: 'Seek solid enclosed shelter; do not stand under trees or ungrounded tin sheds.',
            fieldSuitability: 'Mandatory Work Halt',
            icon: Icons.warning_rounded,
            accentColor: Color(0xFFDC2626),
          );
        } else if (temp >= 38.0 || alert.hazardType == WeatherHazardType.heatwave) {
          return const PersonaAdvisory(
            persona: Persona.outdoorWorker,
            headline: 'Heat Stress Safety — Take Shaded Breaks',
            recommendation: 'Follow the 15-minute shaded rest cycle per hour of heavy outdoor physical exertion.',
            actionableTip: 'Drink cool ORS/water at regular intervals; report dizziness or nausea immediately.',
            fieldSuitability: 'High Heat Strain',
            icon: Icons.construction_rounded,
            accentColor: Color(0xFFEA580C),
          );
        } else if (wind >= 35.0 || alert.hazardType == WeatherHazardType.strongWind) {
          return const PersonaAdvisory(
            persona: Persona.outdoorWorker,
            headline: 'High Wind — Secure Materials',
            recommendation: 'Secure roofing sheets, cladding, and tarpaulins. Exercise extreme caution at elevation.',
            actionableTip: 'Wear chin-strapped safety helmets and eye protection against airborne dust.',
            fieldSuitability: 'Wind Caution',
            icon: Icons.safety_check_rounded,
            accentColor: Color(0xFFD97706),
          );
        } else {
          return const PersonaAdvisory(
            persona: Persona.outdoorWorker,
            headline: 'Standard Outdoor Work Safety',
            recommendation: 'Weather conditions are stable for construction, delivery, and maintenance work.',
            actionableTip: 'Follow standard PPE protocols and stay hydrated throughout your shift.',
            fieldSuitability: 'Safe for Work',
            icon: Icons.verified_user_rounded,
            accentColor: Color(0xFF16A34A),
          );
        }

      // ── 7. SENIOR CITIZEN ──────────────────────────────────────
      case Persona.seniorCitizen:
        if (temp >= 37.0 || alert.hazardType == WeatherHazardType.heatwave) {
          return const PersonaAdvisory(
            persona: Persona.seniorCitizen,
            headline: 'High Temperature — Stay in Cool Indoors',
            recommendation: 'Stay indoors in well-ventilated or air-cooled rooms during afternoon hours.',
            actionableTip: 'Sip water, buttermilk, or lemon water frequently to prevent dehydration.',
            fieldSuitability: 'Rest Indoors',
            icon: Icons.elderly_rounded,
            accentColor: Color(0xFFEA580C),
          );
        } else if (temp <= 10.0 || alert.hazardType == WeatherHazardType.coldWave) {
          return const PersonaAdvisory(
            persona: Persona.seniorCitizen,
            headline: 'Cold Weather — Keep Warm and Sheltered',
            recommendation: 'Wear warm woolens and keep joints protected from cold drafts.',
            actionableTip: 'Avoid early dawn walks when temperatures are lowest; prefer sunny midday hours.',
            fieldSuitability: 'Cold Protection Required',
            icon: Icons.ac_unit_rounded,
            accentColor: Color(0xFF0284C7),
          );
        } else if (alert.hazardType == WeatherHazardType.heavyRain || rain >= 10.0) {
          return const PersonaAdvisory(
            persona: Persona.seniorCitizen,
            headline: 'Slippery Surfaces — Avoid Stepping Out',
            recommendation: 'Wet walkways and steps carry slip risks. Postpone non-essential outdoor errands.',
            actionableTip: 'Wear footwear with non-skid rubber soles if walking on wet surfaces.',
            fieldSuitability: 'Slip Risk Outdoors',
            icon: Icons.warning_amber_rounded,
            accentColor: Color(0xFFD97706),
          );
        } else {
          return const PersonaAdvisory(
            persona: Persona.seniorCitizen,
            headline: 'Pleasant & Comfortable Weather',
            recommendation: 'Gentle weather conditions suited for light garden strolls and social time.',
            actionableTip: 'Enjoy morning sunshine for natural vitamin D while temperatures are mild.',
            fieldSuitability: 'Comfortable',
            icon: Icons.sentiment_satisfied_alt_rounded,
            accentColor: Color(0xFF16A34A),
          );
        }

      // ── 8. EVENT PLANNER ───────────────────────────────────────
      case Persona.eventPlanner:
        if (alert.hazardType == WeatherHazardType.thunderstorm ||
            alert.hazardType == WeatherHazardType.heavyRain ||
            rain >= 10.0) {
          return const PersonaAdvisory(
            persona: Persona.eventPlanner,
            headline: 'Rain/Storm Risk — Prepare Indoor Backup',
            recommendation: 'Precipitation expected. Activate waterproofing tarpaulins and prepare covered venues.',
            actionableTip: 'Ensure all outdoor sound and lighting power distribution boards are elevated and watertight.',
            fieldSuitability: 'Indoor Backup Critical',
            icon: Icons.event_busy_rounded,
            accentColor: Color(0xFFDC2626),
          );
        } else if (wind >= 30.0 || alert.hazardType == WeatherHazardType.strongWind) {
          return const PersonaAdvisory(
            persona: Persona.eventPlanner,
            headline: 'Wind Warning — Reinforce Canopies & Tents',
            recommendation: 'Secure tent anchor pegs and ballast canopies against gusting winds.',
            actionableTip: 'Lower or secure stage backdrop banners and freestanding branding arches.',
            fieldSuitability: 'Reinforce Outdoor Setup',
            icon: Icons.wind_power_rounded,
            accentColor: Color(0xFFD97706),
          );
        } else {
          return const PersonaAdvisory(
            persona: Persona.eventPlanner,
            headline: 'Favorable Outdoor Event Conditions',
            recommendation: 'Weather parameters are favorable for open-air gatherings and outdoor staging.',
            actionableTip: 'Maintain standard hydration stations and guest shade arrangements.',
            fieldSuitability: 'Excellent for Events',
            icon: Icons.event_available_rounded,
            accentColor: Color(0xFF16A34A),
          );
        }
    }
  }
}
