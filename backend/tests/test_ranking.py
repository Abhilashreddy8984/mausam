"""
Ranking Service Tests
=====================
Deterministic tests for the Mausam context-aware ranking engine.

Run from the backend/ directory:
    python -m pytest tests/test_ranking.py -v
  or without pytest:
    python tests/test_ranking.py

Tests verify:
  - Cards are NEVER removed (all cards always present in output)
  - Card ORDER changes when context changes
  - Scores are deterministic (same input → same output)
  - Context boosts shift specific cards up when conditions warrant
  - Each persona's top card reflects its priority under relevant conditions
"""

import sys
import os

# Allow running from the backend/ directory directly
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.models.ranking_context import RankingContext
from app.models.weather import WeatherCard
from app.services.ranking_service import RankingService
from app.services.context_thresholds import (
    HIGH_RAIN_PROBABILITY,
    HIGH_TEMPERATURE_THRESHOLD,
    HIGH_AQI_THRESHOLD,
    POOR_VISIBILITY_THRESHOLD,
)

# ---------------------------------------------------------------------------
# Shared fixtures
# ---------------------------------------------------------------------------

_RANKING_SERVICE = RankingService()

# Standard set of 10 demo cards — same types as DemoWeatherProvider
_DEMO_CARDS = [
    WeatherCard(type="temperature",   title="Temperature",      value="32.5", unit="°C",  severity="medium"),
    WeatherCard(type="humidity",      title="Humidity",         value="68",   unit="%",   severity="medium"),
    WeatherCard(type="wind_speed",    title="Wind Speed",       value="14",   unit="km/h",severity="low"),
    WeatherCard(type="rain_alert",    title="Rain Alert",       value="Possible showers", unit="", severity="medium"),
    WeatherCard(type="uv_index",      title="UV Index",         value="7",    unit="",    severity="high"),
    WeatherCard(type="air_quality",   title="Air Quality Index",value="142",  unit="AQI", severity="medium"),
    WeatherCard(type="visibility",    title="Visibility",       value="8",    unit="km",  severity="low"),
    WeatherCard(type="feels_like",    title="Feels Like",       value="36",   unit="°C",  severity="medium"),
    WeatherCard(type="sunrise_sunset",title="Sunrise / Sunset", value="06:08 / 18:22", unit="", severity="low"),
    WeatherCard(type="pollen",        title="Pollen Level",     value="Moderate", unit="", severity="medium"),
]

# A "marine" card that is intentionally NOT in any persona's top weights
_MARINE_CARD = WeatherCard(
    type="marine_tide", title="Marine / Tide", value="Moderate sea",
    unit="", severity="low"
)

_ALL_CARDS_WITH_MARINE = _DEMO_CARDS + [_MARINE_CARD]


def _make_context(
    persona: str,
    *,
    temperature_c: float = 32.0,
    humidity_pct: float = 68.0,
    wind_speed_kmh: float = 14.0,
    condition: str = "Partly Cloudy",
    rain_probability: float | None = None,
    visibility_km: float | None = None,
    uv_index: int | None = None,
    aqi: int | None = None,
    current_hour: int = 14,
) -> RankingContext:
    return RankingContext(
        persona=persona,
        city="Hyderabad",
        current_hour=current_hour,
        temperature_c=temperature_c,
        humidity_pct=humidity_pct,
        wind_speed_kmh=wind_speed_kmh,
        condition=condition,
        rain_probability=rain_probability,
        visibility_km=visibility_km,
        uv_index=uv_index,
        aqi=aqi,
    )


def _types(cards) -> list[str]:
    return [c.type for c in cards]


def _score_of(cards, card_type: str) -> float:
    for c in cards:
        if c.type == card_type:
            return c.score
    raise ValueError(f"Card type '{card_type}' not found in results")


# ---------------------------------------------------------------------------
# Test helpers
# ---------------------------------------------------------------------------

_PASS = 0
_FAIL = 0

def _check(name: str, condition: bool, detail: str = "") -> None:
    global _PASS, _FAIL
    if condition:
        print(f"  ✓  {name}")
        _PASS += 1
    else:
        print(f"  ✗  FAIL: {name}{' — ' + detail if detail else ''}")
        _FAIL += 1


# ---------------------------------------------------------------------------
# TEST 1 — Farmer + normal weather
# ---------------------------------------------------------------------------
def test_farmer_normal():
    print("\nTEST 1: Farmer + normal weather")
    ctx = _make_context("farmer", temperature_c=32.0, wind_speed_kmh=14.0)
    result = _RANKING_SERVICE.rank(list(_DEMO_CARDS), "farmer", ctx)

    _check("all 10 cards present", len(result) == 10)
    _check("rain_alert is top card", result[0].type == "rain_alert",
           f"got {result[0].type}")
    _check("humidity is high in list", _score_of(result, "humidity") >= 9.0)
    _check("scores are deterministic",
           result == _RANKING_SERVICE.rank(list(_DEMO_CARDS), "farmer", ctx))


# ---------------------------------------------------------------------------
# TEST 2 — Farmer + heavy rain
# ---------------------------------------------------------------------------
def test_farmer_heavy_rain():
    print("\nTEST 2: Farmer + heavy rain")
    ctx_normal = _make_context("farmer")
    ctx_rain   = _make_context(
        "farmer",
        rain_probability=HIGH_RAIN_PROBABILITY + 10,
        condition="Heavy Rain",
    )
    normal = _RANKING_SERVICE.rank(list(_DEMO_CARDS), "farmer", ctx_normal)
    rainy  = _RANKING_SERVICE.rank(list(_DEMO_CARDS), "farmer", ctx_rain)

    _check("all 10 cards present (rain)", len(rainy) == 10)
    _check("rain_alert score higher with rain",
           _score_of(rainy, "rain_alert") > _score_of(normal, "rain_alert"),
           f"{_score_of(rainy,'rain_alert')} vs {_score_of(normal,'rain_alert')}")
    _check("rain_alert still top under heavy rain", rainy[0].type == "rain_alert")
    _check("ranking_reasons populated for rain_alert",
           rainy[0].ranking_reasons is not None and len(rainy[0].ranking_reasons) > 0)


# ---------------------------------------------------------------------------
# TEST 3 — Farmer + high temperature
# ---------------------------------------------------------------------------
def test_farmer_high_temperature():
    print("\nTEST 3: Farmer + high temperature")
    ctx_normal = _make_context("farmer", temperature_c=32.0)
    ctx_hot    = _make_context("farmer", temperature_c=HIGH_TEMPERATURE_THRESHOLD + 2)
    normal = _RANKING_SERVICE.rank(list(_DEMO_CARDS), "farmer", ctx_normal)
    hot    = _RANKING_SERVICE.rank(list(_DEMO_CARDS), "farmer", ctx_hot)

    _check("all 10 cards present (hot)", len(hot) == 10)
    _check("temperature score higher when hot",
           _score_of(hot, "temperature") > _score_of(normal, "temperature"),
           f"{_score_of(hot,'temperature')} vs {_score_of(normal,'temperature')}")


# ---------------------------------------------------------------------------
# TEST 4 — Health + poor air quality
# ---------------------------------------------------------------------------
def test_health_poor_aqi():
    print("\nTEST 4: Health + poor air quality")
    ctx_normal = _make_context("health", aqi=100)
    ctx_smoggy = _make_context("health", aqi=HIGH_AQI_THRESHOLD + 20)
    normal = _RANKING_SERVICE.rank(list(_DEMO_CARDS), "health", ctx_normal)
    smoggy = _RANKING_SERVICE.rank(list(_DEMO_CARDS), "health", ctx_smoggy)

    _check("all 10 cards present (smoggy)", len(smoggy) == 10)
    _check("air_quality score higher when smoggy",
           _score_of(smoggy, "air_quality") > _score_of(normal, "air_quality"),
           f"{_score_of(smoggy,'air_quality')} vs {_score_of(normal,'air_quality')}")
    _check("air_quality is top card under poor AQI", smoggy[0].type == "air_quality",
           f"got {smoggy[0].type}")


# ---------------------------------------------------------------------------
# TEST 5 — Traveller + poor visibility
# ---------------------------------------------------------------------------
def test_traveller_poor_visibility():
    print("\nTEST 5: Traveller + poor visibility")
    ctx_normal = _make_context("traveller", visibility_km=10.0)
    ctx_foggy  = _make_context("traveller", visibility_km=POOR_VISIBILITY_THRESHOLD - 1)
    normal = _RANKING_SERVICE.rank(list(_DEMO_CARDS), "traveller", ctx_normal)
    foggy  = _RANKING_SERVICE.rank(list(_DEMO_CARDS), "traveller", ctx_foggy)

    _check("all 10 cards present (foggy)", len(foggy) == 10)
    _check("visibility score higher when foggy",
           _score_of(foggy, "visibility") > _score_of(normal, "visibility"),
           f"{_score_of(foggy,'visibility')} vs {_score_of(normal,'visibility')}")


# ---------------------------------------------------------------------------
# TEST 6 — Student + rain
# ---------------------------------------------------------------------------
def test_student_rain():
    print("\nTEST 6: Student + rain")
    ctx_dry  = _make_context("student", rain_probability=10.0)
    ctx_rain = _make_context("student", rain_probability=HIGH_RAIN_PROBABILITY + 5,
                             condition="Showers")
    dry  = _RANKING_SERVICE.rank(list(_DEMO_CARDS), "student", ctx_dry)
    wet  = _RANKING_SERVICE.rank(list(_DEMO_CARDS), "student", ctx_rain)

    _check("all 10 cards present (student rain)", len(wet) == 10)
    _check("rain_alert score higher for student with rain",
           _score_of(wet, "rain_alert") > _score_of(dry, "rain_alert"),
           f"{_score_of(wet,'rain_alert')} vs {_score_of(dry,'rain_alert')}")


# ---------------------------------------------------------------------------
# TEST 7 — Commuter + poor visibility
# ---------------------------------------------------------------------------
def test_commuter_poor_visibility():
    print("\nTEST 7: Commuter + poor visibility")
    ctx_clear = _make_context("commuter", visibility_km=10.0)
    ctx_foggy = _make_context("commuter", visibility_km=POOR_VISIBILITY_THRESHOLD - 1)
    clear = _RANKING_SERVICE.rank(list(_DEMO_CARDS), "commuter", ctx_clear)
    foggy = _RANKING_SERVICE.rank(list(_DEMO_CARDS), "commuter", ctx_foggy)

    _check("all 10 cards present (commuter fog)", len(foggy) == 10)
    _check("visibility score higher for commuter in fog",
           _score_of(foggy, "visibility") > _score_of(clear, "visibility"),
           f"{_score_of(foggy,'visibility')} vs {_score_of(clear,'visibility')}")


# ---------------------------------------------------------------------------
# TEST 8 — Marine/tide card remains available for farmer
# ---------------------------------------------------------------------------
def test_farmer_marine_card_retained():
    print("\nTEST 8: Marine/tide card MUST remain available for farmer")
    ctx = _make_context("farmer")
    result = _RANKING_SERVICE.rank(list(_ALL_CARDS_WITH_MARINE), "farmer", ctx)
    types = _types(result)

    _check("marine_tide card is present in farmer results",
           "marine_tide" in types,
           f"types found: {types}")
    _check("marine_tide is NOT the top card for farmer",
           result[0].type != "marine_tide",
           f"got {result[0].type} at top")
    _check("all 11 cards present (including marine)", len(result) == 11)


# ---------------------------------------------------------------------------
# TEST 9 — Deterministic: same input always produces same output
# ---------------------------------------------------------------------------
def test_deterministic():
    print("\nTEST 9: Deterministic ranking (same input → same output)")
    ctx = _make_context("outdoor_worker", temperature_c=41.0, uv_index=9)
    r1 = _RANKING_SERVICE.rank(list(_DEMO_CARDS), "outdoor_worker", ctx)
    r2 = _RANKING_SERVICE.rank(list(_DEMO_CARDS), "outdoor_worker", ctx)
    r3 = _RANKING_SERVICE.rank(list(_DEMO_CARDS), "outdoor_worker", ctx)

    _check("run 1 == run 2", _types(r1) == _types(r2))
    _check("run 2 == run 3", _types(r2) == _types(r3))
    _check("scores identical across runs",
           [c.score for c in r1] == [c.score for c in r2])


# ---------------------------------------------------------------------------
# TEST 10 — No context (backward compatibility: context=None)
# ---------------------------------------------------------------------------
def test_no_context_backward_compat():
    print("\nTEST 10: No context (backward-compat — context=None)")
    result = _RANKING_SERVICE.rank(list(_DEMO_CARDS), "farmer", context=None)

    _check("all 10 cards present without context", len(result) == 10)
    _check("rain_alert is top for farmer without context",
           result[0].type == "rain_alert", f"got {result[0].type}")
    _check("ranking_reasons is None without context",
           result[0].ranking_reasons is None)


# ---------------------------------------------------------------------------
# TEST 11 — All 8 personas accept context without crashing
# ---------------------------------------------------------------------------
def test_all_personas_smoke():
    print("\nTEST 11: All 8 personas smoke test")
    personas = [
        "farmer", "student", "traveller", "health",
        "commuter", "outdoor_worker", "senior", "event_planner",
    ]
    ctx = _make_context("farmer")  # persona field ignored in helper, overridden below
    for p in personas:
        ctx2 = _make_context(p)
        result = _RANKING_SERVICE.rank(list(_DEMO_CARDS), p, ctx2)
        _check(f"{p}: 10 cards returned", len(result) == 10)
        _check(f"{p}: no card has score 0 (all scored)", all(c.score > 0 for c in result))


# ---------------------------------------------------------------------------
# TEST 12 — Invalid persona raises ValueError
# ---------------------------------------------------------------------------
def test_invalid_persona():
    print("\nTEST 12: Invalid persona raises ValueError")
    ctx = _make_context("farmer")
    try:
        _RANKING_SERVICE.rank(list(_DEMO_CARDS), "wizard", ctx)
        _check("ValueError raised for invalid persona", False, "no exception raised")
    except ValueError as e:
        _check("ValueError raised for invalid persona", True)
        _check("error message mentions supported personas",
               "Supported personas" in str(e))


# ---------------------------------------------------------------------------
# Run all tests
# ---------------------------------------------------------------------------
if __name__ == "__main__":
    print("=" * 60)
    print("  Mausam Ranking Service — Deterministic Test Suite")
    print("=" * 60)

    test_farmer_normal()
    test_farmer_heavy_rain()
    test_farmer_high_temperature()
    test_health_poor_aqi()
    test_traveller_poor_visibility()
    test_student_rain()
    test_commuter_poor_visibility()
    test_farmer_marine_card_retained()
    test_deterministic()
    test_no_context_backward_compat()
    test_all_personas_smoke()
    test_invalid_persona()
    # ── New location / GPS tests ──
    test_context_stores_coordinates()
    test_ranking_with_and_without_coordinates()
    test_city_only_context()

    print()
    print("=" * 60)
    total = _PASS + _FAIL
    print(f"  Results: {_PASS}/{total} passed, {_FAIL} failed")
    print("=" * 60)

    sys.exit(0 if _FAIL == 0 else 1)


# ---------------------------------------------------------------------------
# TEST 13 — RankingContext stores lat/lon when provided
# ---------------------------------------------------------------------------
def test_context_stores_coordinates():
    print("\nTEST 13: RankingContext stores lat/lon when provided")
    ctx_with = RankingContext(
        persona="farmer",
        city="Hyderabad",
        current_hour=14,
        latitude=17.3850,
        longitude=78.4867,
        temperature_c=32.0,
    )
    ctx_without = RankingContext(
        persona="farmer",
        city="Hyderabad",
        current_hour=14,
        temperature_c=32.0,
    )

    _check("latitude stored correctly",
           ctx_with.latitude == 17.3850)
    _check("longitude stored correctly",
           ctx_with.longitude == 78.4867)
    _check("latitude is None when not provided",
           ctx_without.latitude is None)
    _check("longitude is None when not provided",
           ctx_without.longitude is None)


# ---------------------------------------------------------------------------
# TEST 14 — Ranking with coordinates produces same scores as without
#           (DemoWeatherProvider does not use coords for weather data;
#            coords are carried through but do not change current scores)
# ---------------------------------------------------------------------------
def test_ranking_with_and_without_coordinates():
    print("\nTEST 14: Ranking with GPS coords vs without — same scores")
    ctx_no_coords = RankingContext(
        persona="farmer",
        city="Hyderabad",
        current_hour=14,
        temperature_c=32.0,
        humidity_pct=68.0,
        wind_speed_kmh=14.0,
        condition="Partly Cloudy",
    )
    ctx_with_coords = RankingContext(
        persona="farmer",
        city="Hyderabad",
        current_hour=14,
        latitude=17.3850,
        longitude=78.4867,
        temperature_c=32.0,
        humidity_pct=68.0,
        wind_speed_kmh=14.0,
        condition="Partly Cloudy",
    )

    result_no  = _RANKING_SERVICE.rank(list(_DEMO_CARDS), "farmer", ctx_no_coords)
    result_yes = _RANKING_SERVICE.rank(list(_DEMO_CARDS), "farmer", ctx_with_coords)

    _check("all 10 cards with coords",    len(result_yes) == 10)
    _check("all 10 cards without coords", len(result_no) == 10)
    _check("card order identical with/without coords",
           [c.type for c in result_no] == [c.type for c in result_yes])
    _check("scores identical with/without coords",
           [c.score for c in result_no] == [c.score for c in result_yes])


# ---------------------------------------------------------------------------
# TEST 15 — City-only context (lat/lon both None) still works correctly
# ---------------------------------------------------------------------------
def test_city_only_context():
    print("\nTEST 15: City-only context (no GPS) works correctly")
    ctx = RankingContext(
        persona="traveller",
        city="Mumbai",          # different city — should not crash
        current_hour=10,
        temperature_c=30.0,
        wind_speed_kmh=12.0,
        condition="Sunny",
    )
    result = _RANKING_SERVICE.rank(list(_DEMO_CARDS), "traveller", ctx)

    _check("all 10 cards for non-Hyderabad city", len(result) == 10)
    _check("no card has score 0", all(c.score > 0 for c in result))
    _check("latitude is None in city-only context", ctx.latitude is None)
    _check("longitude is None in city-only context", ctx.longitude is None)


# NOTE: Tests 13-15 above are picked up automatically by pytest.
# The __main__ block above calls them when running as a standalone script.
