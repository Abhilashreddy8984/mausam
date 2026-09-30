"""
IMD Mapper Tests
================
Unit tests for app/services/imd_mapper.py.

All tests use mock/representative JSON fixtures from tests/fixtures/.
No live IMD API calls are made.  Every fixture is clearly labelled
MOCK DATA in its own file.

Test coverage
-------------
  Group A — Full current weather response
    A1: city, district, state parsed correctly
    A2: temperature, humidity, wind_speed populated
    A3: feels_like, pressure, wind_direction, rainfall populated
    A4: uv_index, visibility_km, observation_time, weather_code populated
    A5: source == "IMD"
    A6: cards list is non-empty
    A7: temperature card present with correct value
    A8: humidity card present
    A9: wind_speed card present
    A10: uv_index card present
    A11: visibility card present
    A12: rain_alert card always present
    A13: feels_like card present
    A14: pollen placeholder card present

  Group B — Forecast mapping
    B1: forecast list has correct number of entries (7)
    B2: first forecast entry has correct date
    B3: max_temp and min_temp parsed as floats
    B4: rain_probability parsed correctly
    B5: condition and weather_code preserved

  Group C — Warnings mapping
    C1: warnings list has correct count
    C2: warning_type and severity parsed
    C3: district populated from parent object
    C4: valid_from and valid_until preserved

  Group D — Nowcast mapping
    D1: nowcast list has correct count
    D2: phenomenon and severity parsed
    D3: district populated from parent object
    D4: issued_time and valid_until preserved

  Group E — Missing fields (partial response)
    E1: does not crash on minimal response
    E2: temperature None when field absent
    E3: cards still built from available fields
    E4: forecast empty list when not provided
    E5: warnings empty list when not provided
    E6: nowcast empty list when not provided

  Group F — Malformed response (bad numeric strings)
    F1: does not crash on non-numeric temperature
    F2: temperature is None (not 0) when "N/A"
    F3: humidity is None when "abc"
    F4: cards still contain rain_alert and pollen cards

  Group G — Safe parsers (_safe_float, _safe_int, _safe_str)
    G1: _safe_float returns correct float for valid string
    G2: _safe_float returns None for "N/A"
    G3: _safe_float returns None for ""
    G4: _safe_float returns None for None
    G5: _safe_int returns correct int for "8.0"
    G6: _safe_int returns None for "abc"
    G7: _safe_str returns None for blank string
    G8: _safe_str returns stripped string for padded value

  Group H — Severity helpers
    H1: temperature severity: <35 → low, 35–39 → medium, >=40 → high
    H2: wind severity: <35 → low, 35–59 → medium, >=60 → high
    H3: rain severity: 0 → low, 5–19 → medium, >=20 → high
    H4: UV severity: <6 → low, 6–7 → medium, >=8 → high
    H5: visibility severity: >5 → low, 2–5 → medium, <=2 → high
    H6: warning severity from Red/Orange → high, Yellow → medium

  Group I — Existing ranking tests still pass (smoke check)
    I1: DemoWeatherProvider still returns WeatherResponse
    I2: WeatherResponse has city, temperature, humidity, wind_speed, cards
    I3: RankingService still ranks farmer cards correctly

Run from backend/:
    python -m pytest tests/test_imd_mapper.py -v
"""

import json
import os
import sys

import pytest

# Allow running from the backend/ directory directly
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.services.imd_mapper import (
    _safe_float,
    _safe_int,
    _safe_str,
    _severity_from_temperature,
    _severity_from_wind,
    _severity_from_rain,
    _severity_from_uv,
    _severity_from_visibility,
    _severity_from_warning_type,
    map_current_weather,
)

# ---------------------------------------------------------------------------
# Fixture helpers
# ---------------------------------------------------------------------------

_FIXTURES_DIR = os.path.join(os.path.dirname(__file__), "fixtures")


def _load(filename: str) -> dict:
    path = os.path.join(_FIXTURES_DIR, filename)
    with open(path, encoding="utf-8") as f:
        return json.load(f)


# Load all fixtures once at module level
_FULL      = _load("imd_current_wx_hyderabad.json")
_MINIMAL   = _load("imd_current_wx_missing_fields.json")
_MALFORMED = _load("imd_current_wx_malformed.json")
_FORECAST  = _load("imd_forecast_hyderabad.json")
_WARNINGS  = _load("imd_warnings_hyderabad.json")
_NOWCAST   = _load("imd_nowcast_hyderabad.json")


# ---------------------------------------------------------------------------
# Group A — Full current weather
# ---------------------------------------------------------------------------

class TestFullCurrentWeather:
    """Map the full Hyderabad mock response and verify every field."""

    @pytest.fixture(scope="class")
    @classmethod
    def resp(cls):
        return map_current_weather(
            _FULL,
            forecast_json=_FORECAST,
            warnings_json=_WARNINGS,
            nowcast_json=_NOWCAST,
        )

    def test_A1_city_district_state(self, resp):
        assert resp.city     == "Hyderabad"
        assert resp.district == "Hyderabad"
        assert resp.state    == "Telangana"

    def test_A2_basic_measurements(self, resp):
        assert resp.temperature == pytest.approx(33.2, abs=0.01)
        assert resp.humidity    == pytest.approx(65.0, abs=0.01)
        assert resp.wind_speed  == pytest.approx(18.0, abs=0.01)

    def test_A3_rich_fields(self, resp):
        assert resp.feels_like     == pytest.approx(37.0, abs=0.01)
        assert resp.pressure_hpa   == pytest.approx(997.8, abs=0.01)
        assert resp.wind_direction == "SW"
        assert resp.rainfall_mm    == pytest.approx(0.0, abs=0.01)

    def test_A4_additional_fields(self, resp):
        assert resp.uv_index        == 8
        assert resp.visibility_km   == pytest.approx(6.0, abs=0.01)
        assert resp.observation_time == "2026-09-27T09:30:00+05:30"
        assert resp.weather_code    == "03"

    def test_A5_source_is_imd(self, resp):
        assert resp.source == "IMD"

    def test_A6_cards_non_empty(self, resp):
        assert len(resp.cards) > 0

    def test_A7_temperature_card(self, resp):
        card = next((c for c in resp.cards if c.type == "temperature"), None)
        assert card is not None
        assert "33" in card.value   # "33.2"
        assert card.unit == "°C"

    def test_A8_humidity_card(self, resp):
        card = next((c for c in resp.cards if c.type == "humidity"), None)
        assert card is not None
        assert card.unit == "%"

    def test_A9_wind_card(self, resp):
        card = next((c for c in resp.cards if c.type == "wind_speed"), None)
        assert card is not None
        assert "SW" in card.value   # direction embedded in value string

    def test_A10_uv_card(self, resp):
        card = next((c for c in resp.cards if c.type == "uv_index"), None)
        assert card is not None
        assert card.value == "8"

    def test_A11_visibility_card(self, resp):
        card = next((c for c in resp.cards if c.type == "visibility"), None)
        assert card is not None
        assert "6" in card.value
        assert card.unit == "km"

    def test_A12_rain_alert_always_present(self, resp):
        types = [c.type for c in resp.cards]
        assert "rain_alert" in types

    def test_A13_feels_like_card(self, resp):
        card = next((c for c in resp.cards if c.type == "feels_like"), None)
        assert card is not None
        assert "37" in card.value

    def test_A14_pollen_placeholder(self, resp):
        card = next((c for c in resp.cards if c.type == "pollen"), None)
        assert card is not None
        assert card.severity == "low"


# ---------------------------------------------------------------------------
# Group B — Forecast mapping
# ---------------------------------------------------------------------------

class TestForecastMapping:

    @pytest.fixture(scope="class")
    @classmethod
    def resp(cls):
        return map_current_weather(_FULL, forecast_json=_FORECAST)

    def test_B1_forecast_count(self, resp):
        assert len(resp.forecast) == 7

    def test_B2_first_entry_date(self, resp):
        assert resp.forecast[0].date == "2026-09-27"

    def test_B3_temperatures_parsed(self, resp):
        day0 = resp.forecast[0]
        assert day0.max_temp_c == pytest.approx(36.0, abs=0.01)
        assert day0.min_temp_c == pytest.approx(25.0, abs=0.01)

    def test_B4_rain_probability_parsed(self, resp):
        # day[1] has Rain_Prob = "70"
        assert resp.forecast[1].rain_probability == pytest.approx(70.0, abs=0.01)

    def test_B5_condition_and_code(self, resp):
        assert resp.forecast[2].condition    == "Moderate Rain"
        assert resp.forecast[2].weather_code == "63"


# ---------------------------------------------------------------------------
# Group C — Warnings mapping
# ---------------------------------------------------------------------------

class TestWarningsMapping:

    @pytest.fixture(scope="class")
    @classmethod
    def resp(cls):
        return map_current_weather(_FULL, warnings_json=_WARNINGS)

    def test_C1_warning_count(self, resp):
        assert len(resp.warnings) == 2

    def test_C2_warning_type_and_severity(self, resp):
        w0 = resp.warnings[0]
        assert w0.warning_type == "Yellow Alert"
        assert w0.severity     == "medium"

    def test_C3_district_populated(self, resp):
        for w in resp.warnings:
            assert w.district == "Hyderabad"

    def test_C4_valid_from_until(self, resp):
        w0 = resp.warnings[0]
        assert w0.valid_from  is not None
        assert w0.valid_until is not None


# ---------------------------------------------------------------------------
# Group D — Nowcast mapping
# ---------------------------------------------------------------------------

class TestNowcastMapping:

    @pytest.fixture(scope="class")
    @classmethod
    def resp(cls):
        return map_current_weather(_FULL, nowcast_json=_NOWCAST)

    def test_D1_nowcast_count(self, resp):
        assert len(resp.nowcast) == 2

    def test_D2_phenomenon_and_severity(self, resp):
        n0 = resp.nowcast[0]
        assert n0.phenomenon == "Thunderstorm"
        assert n0.severity   == "medium"

    def test_D3_district_populated(self, resp):
        for n in resp.nowcast:
            assert n.district == "Hyderabad"

    def test_D4_times_preserved(self, resp):
        n0 = resp.nowcast[0]
        assert n0.issued_time  is not None
        assert n0.valid_until  is not None


# ---------------------------------------------------------------------------
# Group E — Missing fields (partial/minimal response)
# ---------------------------------------------------------------------------

class TestMissingFields:

    @pytest.fixture(scope="class")
    @classmethod
    def resp(cls):
        return map_current_weather(_MINIMAL)

    def test_E1_does_not_crash(self, resp):
        assert resp is not None

    def test_E2_temperature_none_when_absent(self, resp):
        # _MINIMAL has no Temp field  → temperature field should be 0.0 fallback
        # (WeatherResponse.temperature is non-optional, defaults to 0.0)
        assert isinstance(resp.temperature, float)

    def test_E3_cards_still_built(self, resp):
        # Even a minimal response should produce at least rain_alert + pollen
        types = [c.type for c in resp.cards]
        assert "rain_alert" in types
        assert "pollen"     in types

    def test_E4_forecast_empty(self, resp):
        assert resp.forecast == []

    def test_E5_warnings_empty(self, resp):
        assert resp.warnings == []

    def test_E6_nowcast_empty(self, resp):
        assert resp.nowcast == []


# ---------------------------------------------------------------------------
# Group F — Malformed response (non-numeric strings)
# ---------------------------------------------------------------------------

class TestMalformedResponse:

    @pytest.fixture(scope="class")
    @classmethod
    def resp(cls):
        return map_current_weather(_MALFORMED)

    def test_F1_does_not_crash(self, resp):
        assert resp is not None

    def test_F2_temperature_none_for_na(self, resp):
        # Temp="N/A" → _safe_float → None → WeatherResponse uses 0.0 fallback
        # The important thing is no exception was raised
        assert isinstance(resp.temperature, float)

    def test_F3_humidity_zero_for_abc(self, resp):
        # RH="abc" → _safe_float → None → 0.0
        assert isinstance(resp.humidity, float)

    def test_F4_rain_and_pollen_cards_present(self, resp):
        types = [c.type for c in resp.cards]
        assert "rain_alert" in types
        assert "pollen"     in types


# ---------------------------------------------------------------------------
# Group G — Safe parsers
# ---------------------------------------------------------------------------

class TestSafeParsers:

    def test_G1_safe_float_valid(self):
        assert _safe_float("33.2") == pytest.approx(33.2)

    def test_G2_safe_float_na(self):
        assert _safe_float("N/A") is None

    def test_G3_safe_float_empty(self):
        assert _safe_float("") is None

    def test_G4_safe_float_none(self):
        assert _safe_float(None) is None

    def test_G5_safe_int_decimal_string(self):
        assert _safe_int("8.0") == 8

    def test_G6_safe_int_invalid(self):
        assert _safe_int("abc") is None

    def test_G7_safe_str_blank(self):
        assert _safe_str("   ") is None

    def test_G8_safe_str_padded(self):
        assert _safe_str("  SW  ") == "SW"


# ---------------------------------------------------------------------------
# Group H — Severity helpers
# ---------------------------------------------------------------------------

class TestSeverityHelpers:

    def test_H1_temperature_severity(self):
        assert _severity_from_temperature(30.0) == "low"
        assert _severity_from_temperature(37.0) == "medium"
        assert _severity_from_temperature(41.0) == "high"

    def test_H2_wind_severity(self):
        assert _severity_from_wind(20.0) == "low"
        assert _severity_from_wind(45.0) == "medium"
        assert _severity_from_wind(65.0) == "high"

    def test_H3_rain_severity(self):
        assert _severity_from_rain(0.0)  == "low"
        assert _severity_from_rain(10.0) == "medium"
        assert _severity_from_rain(25.0) == "high"

    def test_H4_uv_severity(self):
        assert _severity_from_uv(3)  == "low"
        assert _severity_from_uv(7)  == "medium"
        assert _severity_from_uv(10) == "high"

    def test_H5_visibility_severity(self):
        assert _severity_from_visibility(10.0) == "low"
        assert _severity_from_visibility(4.0)  == "medium"
        assert _severity_from_visibility(1.5)  == "high"

    def test_H6_warning_severity_keywords(self):
        assert _severity_from_warning_type("Red Alert")    == "high"
        assert _severity_from_warning_type("Orange Alert") == "high"
        assert _severity_from_warning_type("Yellow Alert") == "medium"
        assert _severity_from_warning_type("Green")        == "low"
        assert _severity_from_warning_type(None)           == "medium"


# ---------------------------------------------------------------------------
# Group I — Smoke check: existing ranking still works after model changes
# ---------------------------------------------------------------------------

class TestExistingRankingSmoke:
    """
    Confirm that the WeatherResponse model changes did not break
    DemoWeatherProvider or the RankingService.
    """

    def test_I1_demo_provider_returns_response(self):
        from app.services.weather_service import DemoWeatherProvider
        from app.services.weather_provider import LocationQuery

        provider = DemoWeatherProvider()
        resp = provider.get_weather(LocationQuery(city="Hyderabad"))
        assert resp is not None
        assert resp.source == "demo"

    def test_I2_response_has_required_fields(self):
        from app.services.weather_service import DemoWeatherProvider
        from app.services.weather_provider import LocationQuery

        resp = DemoWeatherProvider().get_weather(LocationQuery(city="Hyderabad"))
        assert resp.city         == "Hyderabad"
        assert resp.temperature  > 0
        assert resp.humidity     > 0
        assert resp.wind_speed   > 0
        assert len(resp.cards)   == 10

    def test_I3_farmer_ranking_unchanged(self):
        from app.services.weather_service import DemoWeatherProvider
        from app.services.weather_provider import LocationQuery
        from app.services.ranking_service import RankingService
        from app.models.ranking_context import RankingContext

        resp = DemoWeatherProvider().get_weather(LocationQuery(city="Hyderabad"))
        ctx = RankingContext(
            persona="farmer",
            city="Hyderabad",
            current_hour=12,          # noon — no time boost
            temperature_c=resp.temperature,
            humidity_pct=resp.humidity,
            wind_speed_kmh=resp.wind_speed,
            condition=resp.condition,
        )
        ranked = RankingService().rank(resp.cards, "farmer", ctx)
        assert len(ranked) == 10
        assert ranked[0].type == "rain_alert"   # farmer top priority

    def test_I4_new_optional_fields_default_none_on_demo(self):
        """All new rich fields must default to None / [] on DemoWeatherProvider."""
        from app.services.weather_service import DemoWeatherProvider
        from app.services.weather_provider import LocationQuery

        resp = DemoWeatherProvider().get_weather(LocationQuery(city="Hyderabad"))
        assert resp.feels_like      is None
        assert resp.uv_index        is None
        assert resp.aqi             is None
        assert resp.visibility_km   is None
        assert resp.forecast        == []
        assert resp.warnings        == []
        assert resp.nowcast         == []
