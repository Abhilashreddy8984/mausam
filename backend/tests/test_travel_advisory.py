"""
Tests for Destination-Based Travel Advisory & Geocoding
=======================================================
Verifies that:
1. Destination location validation and geocoding work correctly.
2. Coordinates are not confused with user's current GPS location.
3. High/Moderate/Low travel risks are evaluated from actual weather parameters.
4. Unavailable transit/infrastructure data is explicitly marked "Data unavailable"
   and never fabricated.
5. 7-day forecast and travel precautions are structured and populated.
"""

from unittest.mock import MagicMock, patch
import pytest
from fastapi.testclient import TestClient

from app.main import app
from app.services.geocoding_service import GeocodingService
from app.services.travel_advisory_service import TravelAdvisoryService, _generate_travel_precautions


client = TestClient(app)


def test_geocoding_known_destination():
    """Known Indian destinations resolve immediately to accurate coordinates."""
    res = GeocodingService.geocode("Mumbai")
    assert res is not None
    assert res.name == "Mumbai"
    assert "Maharashtra" in res.display_name
    assert abs(res.latitude - 19.0760) < 0.1
    assert abs(res.longitude - 72.8777) < 0.1


def test_geocoding_unknown_gibberish_returns_none():
    """Unresolvable gibberish location returns None rather than inventing coordinates."""
    with patch("requests.get") as mock_get:
        mock_get.return_value = MagicMock(ok=True, json=lambda: {"results": []})
        res = GeocodingService.geocode("zyxwvutsrqp12345")
        assert res is None


def test_search_locations_returns_matches():
    """Search returns relevant matches with display names."""
    results = GeocodingService.search("Delhi", limit=3)
    assert len(results) >= 1
    assert any("Delhi" in r.name for r in results)


def test_travel_precautions_generation():
    """Precautions dynamically tailor to weather conditions."""
    # Foggy conditions
    fog_precautions = _generate_travel_precautions(
        category="fog", temp_c=18.0, rain_mm=0.0, rain_prob=10.0, vis_km=1.2, wind_kmh=8.0
    )
    assert any("fog" in p.lower() for p in fog_precautions)

    # Heavy rain conditions
    rain_precautions = _generate_travel_precautions(
        category="heavy_rain", temp_c=24.0, rain_mm=22.0, rain_prob=90.0, vis_km=4.0, wind_kmh=18.0
    )
    assert any("aquaplaning" in p.lower() or "wet road" in p.lower() for p in rain_precautions)


def test_travel_advisory_never_fabricates_transit():
    """Transit and municipal infrastructure status must be 'Data unavailable'."""
    mock_weather_json = {
        "current": {
            "temperature_2m": 29.5,
            "apparent_temperature": 32.0,
            "relative_humidity_2m": 65,
            "wind_speed_10m": 14.0,
            "wind_direction_10m": 180,
            "precipitation": 0.0,
            "weather_code": 1,
        },
        "hourly": {
            "visibility": [8500.0],
            "uv_index": [6.0],
        },
        "daily": {
            "time": ["2026-11-10", "2026-11-11"],
            "temperature_2m_max": [31.0, 30.5],
            "temperature_2m_min": [22.0, 21.5],
            "precipitation_probability_max": [15, 20],
            "precipitation_sum": [0.0, 0.5],
            "weather_code": [1, 2],
        },
    }

    with patch("requests.get") as mock_get:
        mock_get.return_value = MagicMock(ok=True, status_code=200, json=lambda: mock_weather_json)
        advisory = TravelAdvisoryService.get_advisory(
            destination="Bengaluru",
            origin="Hyderabad",
        )

        assert advisory.destination == "Bengaluru"
        assert advisory.route_summary == "Hyderabad → Bengaluru"
        assert advisory.public_transport_status == "Data unavailable"
        assert advisory.airport_status == "Data unavailable"
        assert "unavailable" in advisory.road_data_status.lower()
        assert advisory.risk_level == "low"
        assert len(advisory.forecast) == 2


def test_travel_advisory_endpoint_invalid_location_404():
    """Endpoint returns 404 with clear message when destination is invalid."""
    with patch.object(GeocodingService, "geocode", return_value=None):
        resp = client.get("/travel-advisory?destination=InvalidCity999")
        assert resp.status_code == 404
        data = resp.json()
        assert "detail" in data
        assert data["detail"]["error"] == "LocationNotFound"


def test_travel_advisory_endpoint_success():
    """Endpoint returns 200 with structured response for valid destination."""
    mock_weather_json = {
        "current": {
            "temperature_2m": 22.0,
            "apparent_temperature": 22.0,
            "relative_humidity_2m": 70,
            "wind_speed_10m": 10.0,
            "wind_direction_10m": 90,
            "precipitation": 0.0,
            "weather_code": 0,
        },
        "hourly": {
            "visibility": [10000.0],
            "uv_index": [5.0],
        },
        "daily": {
            "time": ["2026-11-10"],
            "temperature_2m_max": [25.0],
            "temperature_2m_min": [18.0],
            "precipitation_probability_max": [0],
            "precipitation_sum": [0.0],
            "weather_code": [0],
        },
    }
    with patch("requests.get") as mock_get:
        mock_get.return_value = MagicMock(ok=True, status_code=200, json=lambda: mock_weather_json)
        resp = client.get("/travel-advisory?destination=Jaipur")
        assert resp.status_code == 200
        data = resp.json()
        assert data["destination"] == "Jaipur"
        assert "Rajasthan" in data["destination_resolved"]
        assert data["temperature"] == 22.0
        assert data["public_transport_status"] == "Data unavailable"
        assert data["airport_status"] == "Data unavailable"
        assert isinstance(data["travel_precautions"], list)
