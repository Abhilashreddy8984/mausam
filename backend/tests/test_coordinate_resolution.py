# -*- coding: utf-8 -*-
"""Tests for IMDWeatherProvider coordinate resolution.

These tests verify that:
1. Static station coordinates are used when no GPS and a known IMD_STATION_ID is set.
2. Provided GPS coordinates are preserved.
3. The hard‑coded Hyderabad fallback is applied when neither GPS nor a known station ID is available.
"""

import pytest
from app.config import settings
from app.services.imd_weather_provider import IMDWeatherProvider
from app.services.weather_provider import LocationQuery

# Helper: a minimal WeatherResponse stub that only checks latitude/longitude fields.
# The provider ultimately returns a WeatherResponse object; we can inspect its attributes.

@pytest.fixture(autouse=True)
def reset_settings(monkeypatch):
    """Reset settings to a clean state before each test."""
    # Ensure default values are cleared.
    monkeypatch.setattr(settings, "IMD_STATION_ID", "", raising=False)
    monkeypatch.setattr(settings, "IMD_API_KEY", "test-key", raising=False)
    monkeypatch.setattr(settings, "IMD_CURRENT_WX_URL", "http://example.com/current", raising=False)
    # Mock any required URLs to avoid accidental network calls.
    yield

def make_provider(monkeypatch):
    """Create an IMDWeatherProvider with network calls mocked out.

    The provider's internal HTTP helpers are replaced with no‑op lambdas that
    return empty dictionaries, allowing the coordinate logic to be exercised
    without external dependencies.
    """
    provider = IMDWeatherProvider()
    # Mock the fetch methods that would otherwise perform HTTP requests.
    monkeypatch.setattr(provider, "_fetch_current", lambda *a, **k: {})
    monkeypatch.setattr(provider, "_fetch_forecast", lambda *a, **k: None)
    monkeypatch.setattr(provider, "_fetch_warnings", lambda *a, **k: None)
    monkeypatch.setattr(provider, "_fetch_nowcast", lambda *a, **k: None)
    monkeypatch.setattr(provider, "_fetch_open_meteo_uv_aqi", lambda *a, **k: None)
    monkeypatch.setattr(provider, "_fetch_open_meteo_forecast", lambda *a, **k: None)
    return provider

def test_static_station_coords_used(monkeypatch):
    """When a known IMD_STATION_ID is configured, the provider falls back to the static table."""
    # Use a known station ID that exists in _STATION_COORDS.
    monkeypatch.setattr(settings, "IMD_STATION_ID", "42867", raising=False)
    provider = make_provider(monkeypatch)
    location = LocationQuery(city="", latitude=None, longitude=None)
    resp = provider.get_weather(location)
    # The WeatherResponse includes latitude and longitude attributes.
    assert resp.latitude == 17.45
    assert resp.longitude == 78.47

def test_gps_coordinates_preserved(monkeypatch):
    """Supplied GPS coordinates should be passed through unchanged."""
    monkeypatch.setattr(settings, "IMD_STATION_ID", "42867", raising=False)
    provider = make_provider(monkeypatch)
    location = LocationQuery(city="", latitude=10.0, longitude=20.0)
    resp = provider.get_weather(location)
    assert resp.latitude == 10.0
    assert resp.longitude == 20.0

def test_hyderabad_fallback_when_unknown_station(monkeypatch):
    """If the station ID is unknown and no city is given, the hard‑coded Hyderabad fallback applies."""
    monkeypatch.setattr(settings, "IMD_STATION_ID", "99999", raising=False)
    provider = make_provider(monkeypatch)
    location = LocationQuery(city="", latitude=None, longitude=None)
    resp = provider.get_weather(location)
    # Expect Hyderabad coordinates from the hard‑coded fallback.
    assert resp.latitude == 17.45
    assert resp.longitude == 78.47
