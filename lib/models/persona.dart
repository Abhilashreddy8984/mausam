// ============================================================
// models/persona.dart
// Defines the Persona enum and the card-priority ranking logic.
//
// PERSONALIZATION CONCEPT:
//   "Personalization changes the priority, not the availability."
//   Every persona sees ALL weather cards. The only thing that
//   changes is the ORDER in which those cards appear.
//
//   In a future version, this ordering will be driven by an
//   ML model trained on user behaviour + weather conditions.
//   For the prototype, priority lists are curated by domain
//   experts (met dept advisories, IMD guidelines, etc.).
// ============================================================

import 'package:flutter/material.dart';

/// All supported user personas.
enum Persona {
  farmer,
  student,
  healthFitness,
  commuter,
  traveller,
  outdoorWorker,
  seniorCitizen,
  eventPlanner,
}

/// Human-readable label for each persona.
extension PersonaLabel on Persona {
  String get label {
    switch (this) {
      case Persona.farmer:
        return 'Farmer';
      case Persona.student:
        return 'Student';
      case Persona.healthFitness:
        return 'Health & Fitness';
      case Persona.commuter:
        return 'Commuter';
      case Persona.traveller:
        return 'Traveller';
      case Persona.outdoorWorker:
        return 'Outdoor Worker';
      case Persona.seniorCitizen:
        return 'Senior Citizen';
      case Persona.eventPlanner:
        return 'Event Planner';
    }
  }

  IconData get icon {
    switch (this) {
      case Persona.farmer:
        return Icons.grass;
      case Persona.student:
        return Icons.school;
      case Persona.healthFitness:
        return Icons.fitness_center;
      case Persona.commuter:
        return Icons.directions_transit;
      case Persona.traveller:
        return Icons.flight_takeoff;
      case Persona.outdoorWorker:
        return Icons.construction;
      case Persona.seniorCitizen:
        return Icons.elderly;
      case Persona.eventPlanner:
        return Icons.event;
    }
  }

  /// Short description of why this persona cares about weather.
  String get description {
    switch (this) {
      case Persona.farmer:
        return 'Rainfall, soil moisture & crop advisories';
      case Persona.student:
        return 'Commute conditions & outdoor activities';
      case Persona.healthFitness:
        return 'AQI, UV & outdoor workout conditions';
      case Persona.commuter:
        return 'Rain, visibility & travel disruptions';
      case Persona.traveller:
        return 'Destination weather & travel advisories';
      case Persona.outdoorWorker:
        return 'Heat, UV, wind & safety alerts';
      case Persona.seniorCitizen:
        return 'Temperature extremes & health advisories';
      case Persona.eventPlanner:
        return 'Precipitation, wind & hourly forecasts';
    }
  }

  /// Returns the ordered list of WeatherCardType for this persona.
  /// Cards listed first appear at the top of the homepage.
  /// All card types MUST appear in every list — only order differs.
  List<WeatherCardType> get cardPriority {
    switch (this) {
      // ── FARMER: rain-first, then crop advisory, then temperature ──
      case Persona.farmer:
        return [
          WeatherCardType.rain,
          WeatherCardType.farmAdvisory,
          WeatherCardType.temperature,
          WeatherCardType.weatherAlert,
          WeatherCardType.wind,
          WeatherCardType.humidity,
          WeatherCardType.uvIndex,
          WeatherCardType.aqi,
          WeatherCardType.visibility,
          WeatherCardType.travelAdvisory,
          WeatherCardType.marineTide,
        ];

      // ── STUDENT: commute safety, then outdoor comfort ──
      case Persona.student:
        return [
          WeatherCardType.rain,
          WeatherCardType.temperature,
          WeatherCardType.visibility,
          WeatherCardType.aqi,
          WeatherCardType.uvIndex,
          WeatherCardType.wind,
          WeatherCardType.weatherAlert,
          WeatherCardType.humidity,
          WeatherCardType.travelAdvisory,
          WeatherCardType.farmAdvisory,
          WeatherCardType.marineTide,
        ];

      // ── HEALTH & FITNESS: air quality and outdoor safety first ──
      case Persona.healthFitness:
        return [
          WeatherCardType.aqi,
          WeatherCardType.uvIndex,
          WeatherCardType.temperature,
          WeatherCardType.humidity,
          WeatherCardType.wind,
          WeatherCardType.rain,
          WeatherCardType.weatherAlert,
          WeatherCardType.visibility,
          WeatherCardType.travelAdvisory,
          WeatherCardType.farmAdvisory,
          WeatherCardType.marineTide,
        ];

      // ── COMMUTER: disruption signals first ──
      case Persona.commuter:
        return [
          WeatherCardType.rain,
          WeatherCardType.weatherAlert,
          WeatherCardType.visibility,
          WeatherCardType.wind,
          WeatherCardType.travelAdvisory,
          WeatherCardType.temperature,
          WeatherCardType.aqi,
          WeatherCardType.humidity,
          WeatherCardType.uvIndex,
          WeatherCardType.farmAdvisory,
          WeatherCardType.marineTide,
        ];

      // ── TRAVELLER: destination conditions + advisories ──
      case Persona.traveller:
        return [
          WeatherCardType.travelAdvisory,
          WeatherCardType.weatherAlert,
          WeatherCardType.temperature,
          WeatherCardType.rain,
          WeatherCardType.visibility,
          WeatherCardType.wind,
          WeatherCardType.marineTide,
          WeatherCardType.aqi,
          WeatherCardType.uvIndex,
          WeatherCardType.humidity,
          WeatherCardType.farmAdvisory,
        ];

      // ── OUTDOOR WORKER: heat, UV, safety alerts first ──
      case Persona.outdoorWorker:
        return [
          WeatherCardType.weatherAlert,
          WeatherCardType.uvIndex,
          WeatherCardType.temperature,
          WeatherCardType.wind,
          WeatherCardType.rain,
          WeatherCardType.humidity,
          WeatherCardType.aqi,
          WeatherCardType.visibility,
          WeatherCardType.travelAdvisory,
          WeatherCardType.farmAdvisory,
          WeatherCardType.marineTide,
        ];

      // ── SENIOR CITIZEN: health-impact metrics first ──
      case Persona.seniorCitizen:
        return [
          WeatherCardType.temperature,
          WeatherCardType.aqi,
          WeatherCardType.humidity,
          WeatherCardType.weatherAlert,
          WeatherCardType.rain,
          WeatherCardType.uvIndex,
          WeatherCardType.wind,
          WeatherCardType.visibility,
          WeatherCardType.travelAdvisory,
          WeatherCardType.farmAdvisory,
          WeatherCardType.marineTide,
        ];

      // ── EVENT PLANNER: precipitation & wind first ──
      case Persona.eventPlanner:
        return [
          WeatherCardType.rain,
          WeatherCardType.wind,
          WeatherCardType.weatherAlert,
          WeatherCardType.temperature,
          WeatherCardType.visibility,
          WeatherCardType.uvIndex,
          WeatherCardType.humidity,
          WeatherCardType.aqi,
          WeatherCardType.travelAdvisory,
          WeatherCardType.farmAdvisory,
          WeatherCardType.marineTide,
        ];
    }
  }
}

// ─────────────────────────────────────────────────────────────
// WeatherCardType — identifies each available weather data card.
// ─────────────────────────────────────────────────────────────
enum WeatherCardType {
  rain,
  temperature,
  aqi,
  uvIndex,
  wind,
  weatherAlert,
  farmAdvisory,
  travelAdvisory,
  visibility,
  marineTide,
  humidity,
}
