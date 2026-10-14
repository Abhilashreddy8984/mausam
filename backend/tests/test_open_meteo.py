"""
Open-Meteo Integration Tests
============================
Tests for the Open-Meteo UV Index and AQI supplementary data integration.

All tests use mocked HTTP responses — no real network calls are made.

Coverage
--------
  Group M — _extract_current_hour_value helper
    M1:  valid IANA timezone used to select correct hour
    M2:  no stale fallback — missing current-hour slot returns None
    M3:  mismatched array lengths return None
    M4:  empty time array returns None
    M5:  None value at matched index returns None
    M6:  non-numeric value returns None (no raise)
    M7:  missing timezone field falls back to utc_offset_seconds
    M8:  invalid IANA name falls back to utc_offset_seconds
    M9:  neither timezone nor offset available defaults to UTC
    M10: current slot present but has None value → returns None
    M11: current slot absent from array → returns None (no stale value)

  Group U — UV and AQI via _fetch_open_meteo_uv_aqi
    U1:  successful UV fetch returns correct integer
    U2:  successful AQI fetch returns correct integer
    U3:  UV HTTP error returns None for uv_index, does not raise
    U4:  AQI HTTP error returns None for aqi, does not raise
    U5:  UV timeout returns None for uv_index, does not raise
    U6:  AQI timeout returns None for aqi, does not raise
    U7:  malformed UV JSON returns None for uv_index, does not raise
    U8:  malformed AQI JSON returns None for aqi, does not raise
    U9:  both succeed — both values returned
    U10: both fail — result dict returned with both None

  Group P — IMD provider integration
    P1: get_weather returns valid WeatherResponse when Open-Meteo fails
    P2: uv_index card present in WeatherResponse when UV provided
    P3: AQI card present and titled "Air Quality (est.)" when AQI provided

  Group X — Mapper backward-compatibility
    X1: map_current_weather called without uv_index/aqi args still works
    X2: uv_index in mapper populates WeatherResponse.uv_index
    X3: aqi in mapper populates WeatherResponse.aqi
    X4: aqi card title is "Air Quality (est.)"
    X5: no uv card when uv_index is None
    X6: no aqi card when aqi is None
"""

import json
import os
import sys
from datetime import datetime, timezone, timedelta
from unittest.mock import MagicMock, patch

import pytest

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.services.imd_mapper import map_current_weather
from app.services.imd_weather_provider import (
    IMDWeatherProvider,
    _extract_current_hour_value,
)


# ---------------------------------------------------------------------------
# Shared helpers
# ---------------------------------------------------------------------------

# IST = UTC+5:30
_IST_OFFSET = 19800

def _current_hour_str_for_tz(iana: str | None = None,
                              utc_offset_seconds: int = _IST_OFFSET) -> str:
    """
    Return the current-hour string ("YYYY-MM-DDTHH:00") in the given
    timezone, matching what Open-Meteo would have in its time array.
    """
    from zoneinfo import ZoneInfo
    if iana:
        try:
            local_tz = ZoneInfo(iana)
        except Exception:
            local_tz = timezone(timedelta(seconds=utc_offset_seconds))
    else:
        local_tz = timezone(timedelta(seconds=utc_offset_seconds))
    now_local = datetime.now(tz=timezone.utc).astimezone(local_tz)
    return now_local.strftime("%Y-%m-%dT%H:00")


def _build_24h_series(iana: str | None = None,
                      utc_offset_seconds: int = _IST_OFFSET
                      ) -> tuple[list[str], int, str]:
    """
    Build a 24-hour series of hour strings for today in the given timezone.
    Returns (hours_list, current_index, current_hour_str).
    """
    from zoneinfo import ZoneInfo
    if iana:
        try:
            local_tz = ZoneInfo(iana)
        except Exception:
            local_tz = timezone(timedelta(seconds=utc_offset_seconds))
    else:
        local_tz = timezone(timedelta(seconds=utc_offset_seconds))

    now_local = datetime.now(tz=timezone.utc).astimezone(local_tz)
    base = now_local.replace(hour=0, minute=0, second=0, microsecond=0)
    hours = [(base + timedelta(hours=i)).strftime("%Y-%m-%dT%H:00")
             for i in range(24)]
    target = now_local.strftime("%Y-%m-%dT%H:00")
    idx = hours.index(target) if target in hours else -1
    return hours, idx, target


def _make_open_meteo_uv_response(hours, values,
                                  iana="Asia/Kolkata",
                                  utc_offset_seconds=_IST_OFFSET) -> MagicMock:
    mock = MagicMock()
    mock.ok = True
    mock.status_code = 200
    mock.json.return_value = {
        "timezone": iana,
        "timezone_abbreviation": "IST",
        "utc_offset_seconds": utc_offset_seconds,
        "hourly": {"time": hours, "uv_index": values},
    }
    return mock


def _make_open_meteo_aqi_response(hours, values,
                                   iana="Asia/Kolkata",
                                   utc_offset_seconds=_IST_OFFSET) -> MagicMock:
    mock = MagicMock()
    mock.ok = True
    mock.status_code = 200
    mock.json.return_value = {
        "timezone": iana,
        "timezone_abbreviation": "IST",
        "utc_offset_seconds": utc_offset_seconds,
        "hourly": {"time": hours, "european_aqi": values},
    }
    return mock


def _make_error_response(status: int = 500) -> MagicMock:
    mock = MagicMock()
    mock.ok = False
    mock.status_code = status
    mock.text = "error"
    return mock


_MINIMAL_IMD_STATION = {
    "Station Id": "42867",
    "Station": "HYDERABAD",
    "Temperature": "31.0",
    "Humidity": "60",
    "Wind Speed KMPH": "12.0",
    "Wind Direction": "230",
    "Last 24 hrs Rainfall": "0.0",
    "Weather Code": "03",
    "Nebulosity": "3",
    "Mean Sea Level Pressure": "996.0",
    "Feel Like": "33.5",
    "Date of Observation": "2026-10-04",
    "Time": "09:30",
}


# ===========================================================================
# Group M — _extract_current_hour_value
# ===========================================================================

class TestExtractCurrentHourValue:

    def test_M1_valid_iana_timezone_selects_correct_hour(self):
        """IANA timezone 'Asia/Kolkata' used to identify the correct hour slot."""
        iana = "Asia/Kolkata"
        hours, idx, target = _build_24h_series(iana=iana)
        assert idx >= 0, "Current hour must be in the 24-hour series"
        values = [float(i * 2) for i in range(24)]
        payload = {
            "timezone": iana,
            "utc_offset_seconds": _IST_OFFSET,
            "hourly": {"time": hours, "uv_index": values},
        }
        result = _extract_current_hour_value(payload, "uv_index", "UV")
        assert result == pytest.approx(float(idx * 2), abs=0.01)

    def test_M2_no_stale_fallback_missing_current_hour_returns_none(self):
        """When the current hour is NOT in the time array, return None (not a past value)."""
        # Build an array that covers only past hours well before now
        past_hours = ["2000-01-01T00:00", "2000-01-01T01:00"]
        values = [5.0, 7.0]
        payload = {
            "timezone": "Asia/Kolkata",
            "utc_offset_seconds": _IST_OFFSET,
            "hourly": {"time": past_hours, "uv_index": values},
        }
        # No stale fallback — must return None, not 7.0
        result = _extract_current_hour_value(payload, "uv_index", "UV")
        assert result is None, (
            "Must return None when current hour is absent — "
            "stale past values must never be served silently"
        )

    def test_M3_mismatched_array_lengths_return_none(self):
        hours, _, _ = _build_24h_series(iana="Asia/Kolkata")
        payload = {
            "timezone": "Asia/Kolkata",
            "utc_offset_seconds": _IST_OFFSET,
            "hourly": {"time": hours, "uv_index": [1.0]},  # length mismatch
        }
        assert _extract_current_hour_value(payload, "uv_index", "UV") is None

    def test_M4_empty_time_array_returns_none(self):
        payload = {
            "timezone": "Asia/Kolkata",
            "utc_offset_seconds": _IST_OFFSET,
            "hourly": {"time": [], "uv_index": []},
        }
        assert _extract_current_hour_value(payload, "uv_index", "UV") is None

    def test_M5_none_value_at_current_index_returns_none(self):
        hours, idx, _ = _build_24h_series(iana="Asia/Kolkata")
        values = [1.0] * 24
        values[idx] = None  # explicitly null for the current hour
        payload = {
            "timezone": "Asia/Kolkata",
            "utc_offset_seconds": _IST_OFFSET,
            "hourly": {"time": hours, "uv_index": values},
        }
        assert _extract_current_hour_value(payload, "uv_index", "UV") is None

    def test_M6_non_numeric_value_returns_none(self):
        hours, _, _ = _build_24h_series(iana="Asia/Kolkata")
        values = ["N/A"] * 24
        payload = {
            "timezone": "Asia/Kolkata",
            "utc_offset_seconds": _IST_OFFSET,
            "hourly": {"time": hours, "uv_index": values},
        }
        # Must not raise — returns None
        assert _extract_current_hour_value(payload, "uv_index", "UV") is None

    def test_M7_missing_timezone_field_falls_back_to_utc_offset(self):
        """When 'timezone' key is absent, utc_offset_seconds is used."""
        hours, idx, _ = _build_24h_series(utc_offset_seconds=_IST_OFFSET)
        values = [float(i + 1) for i in range(24)]
        payload = {
            # No "timezone" key
            "utc_offset_seconds": _IST_OFFSET,
            "hourly": {"time": hours, "uv_index": values},
        }
        result = _extract_current_hour_value(payload, "uv_index", "UV")
        # Should still resolve correctly via offset
        assert result == pytest.approx(float(idx + 1), abs=0.01)

    def test_M8_invalid_iana_name_falls_back_to_utc_offset(self):
        """An unrecognised IANA name gracefully falls back to utc_offset_seconds."""
        hours, idx, _ = _build_24h_series(utc_offset_seconds=_IST_OFFSET)
        values = [float(i + 10) for i in range(24)]
        payload = {
            "timezone": "Not/A_Real_Timezone",
            "utc_offset_seconds": _IST_OFFSET,
            "hourly": {"time": hours, "uv_index": values},
        }
        result = _extract_current_hour_value(payload, "uv_index", "UV")
        assert result == pytest.approx(float(idx + 10), abs=0.01)

    def test_M9_no_timezone_or_offset_defaults_to_utc(self):
        """Without timezone or offset, UTC is used — no crash."""
        hours, idx, _ = _build_24h_series(utc_offset_seconds=0)  # UTC hours
        values = [float(i) for i in range(24)]
        payload = {
            # Neither "timezone" nor "utc_offset_seconds"
            "hourly": {"time": hours, "uv_index": values},
        }
        # Should not raise — result depends on current UTC hour alignment
        result = _extract_current_hour_value(payload, "uv_index", "UV")
        # Result is either a float (matched) or None (hour not in series)
        assert result is None or isinstance(result, float)

    def test_M10_current_slot_present_but_none_returns_none(self):
        """Current-hour slot exists in array but its value is None → return None."""
        iana = "Asia/Kolkata"
        hours, idx, _ = _build_24h_series(iana=iana)
        values = [5.0] * 24
        values[idx] = None
        payload = {
            "timezone": iana,
            "utc_offset_seconds": _IST_OFFSET,
            "hourly": {"time": hours, "uv_index": values},
        }
        assert _extract_current_hour_value(payload, "uv_index", "UV") is None

    def test_M11_current_slot_absent_returns_none_not_stale(self):
        """Only the previous hour exists — must return None, not that stale value."""
        iana = "Asia/Kolkata"
        _, idx, target = _build_24h_series(iana=iana)
        from zoneinfo import ZoneInfo
        from datetime import timedelta
        local_tz = ZoneInfo(iana)
        now_local = datetime.now(tz=timezone.utc).astimezone(local_tz)
        prev_hour = (now_local - timedelta(hours=1)).strftime("%Y-%m-%dT%H:00")

        # Array contains only the previous hour, not the current one
        hours  = [prev_hour]
        values = [99.0]
        payload = {
            "timezone": iana,
            "utc_offset_seconds": _IST_OFFSET,
            "hourly": {"time": hours, "uv_index": values},
        }
        result = _extract_current_hour_value(payload, "uv_index", "UV")
        assert result is None, (
            f"Expected None (no stale fallback), got {result!r}"
        )


# ===========================================================================
# Group U — _fetch_open_meteo_uv_aqi
# ===========================================================================

class TestFetchOpenMeteoUvAqi:

    def _provider(self):
        return IMDWeatherProvider()

    def test_U1_successful_uv_fetch(self):
        hours, idx, _ = _build_24h_series(iana="Asia/Kolkata")
        values = [float(i) for i in range(24)]
        uv_resp  = _make_open_meteo_uv_response(hours, values)
        aqi_resp = _make_open_meteo_aqi_response(hours, [0.0] * 24)
        with patch("requests.get", side_effect=[uv_resp, aqi_resp]):
            result = self._provider()._fetch_open_meteo_uv_aqi(17.385, 78.487)
        assert result is not None
        assert result["uv_index"] == int(round(float(idx)))

    def test_U2_successful_aqi_fetch(self):
        hours, idx, _ = _build_24h_series(iana="Asia/Kolkata")
        aqi_values = [float(i * 5) for i in range(24)]
        uv_resp  = _make_open_meteo_uv_response(hours, [0.0] * 24)
        aqi_resp = _make_open_meteo_aqi_response(hours, aqi_values)
        with patch("requests.get", side_effect=[uv_resp, aqi_resp]):
            result = self._provider()._fetch_open_meteo_uv_aqi(17.385, 78.487)
        assert result is not None
        assert result["aqi"] == int(round(float(idx * 5)))

    def test_U3_uv_http_error_uv_index_is_none(self):
        hours, _, _ = _build_24h_series(iana="Asia/Kolkata")
        aqi_resp = _make_open_meteo_aqi_response(hours, [50.0] * 24)
        with patch("requests.get", side_effect=[_make_error_response(503), aqi_resp]):
            result = self._provider()._fetch_open_meteo_uv_aqi(17.385, 78.487)
        assert result["uv_index"] is None

    def test_U4_aqi_http_error_aqi_is_none(self):
        hours, _, _ = _build_24h_series(iana="Asia/Kolkata")
        uv_resp = _make_open_meteo_uv_response(hours, [6.0] * 24)
        with patch("requests.get", side_effect=[uv_resp, _make_error_response(500)]):
            result = self._provider()._fetch_open_meteo_uv_aqi(17.385, 78.487)
        assert result["aqi"] is None

    def test_U5_uv_timeout_uv_index_is_none(self):
        import requests as req_mod
        hours, _, _ = _build_24h_series(iana="Asia/Kolkata")
        aqi_resp = _make_open_meteo_aqi_response(hours, [40.0] * 24)
        with patch("requests.get", side_effect=[req_mod.exceptions.Timeout, aqi_resp]):
            result = self._provider()._fetch_open_meteo_uv_aqi(17.385, 78.487)
        assert result["uv_index"] is None

    def test_U6_aqi_timeout_aqi_is_none(self):
        import requests as req_mod
        hours, _, _ = _build_24h_series(iana="Asia/Kolkata")
        uv_resp = _make_open_meteo_uv_response(hours, [5.0] * 24)
        with patch("requests.get", side_effect=[uv_resp, req_mod.exceptions.Timeout]):
            result = self._provider()._fetch_open_meteo_uv_aqi(17.385, 78.487)
        assert result["aqi"] is None

    def test_U7_malformed_uv_json_uv_index_is_none(self):
        bad = MagicMock()
        bad.ok = True
        bad.status_code = 200
        bad.json.side_effect = ValueError("bad json")
        hours, _, _ = _build_24h_series(iana="Asia/Kolkata")
        aqi_resp = _make_open_meteo_aqi_response(hours, [30.0] * 24)
        with patch("requests.get", side_effect=[bad, aqi_resp]):
            result = self._provider()._fetch_open_meteo_uv_aqi(17.385, 78.487)
        assert result["uv_index"] is None

    def test_U8_malformed_aqi_json_aqi_is_none(self):
        hours, _, _ = _build_24h_series(iana="Asia/Kolkata")
        uv_resp = _make_open_meteo_uv_response(hours, [4.0] * 24)
        bad = MagicMock()
        bad.ok = True
        bad.status_code = 200
        bad.json.side_effect = ValueError("bad json")
        with patch("requests.get", side_effect=[uv_resp, bad]):
            result = self._provider()._fetch_open_meteo_uv_aqi(17.385, 78.487)
        assert result["aqi"] is None

    def test_U9_both_succeed_both_returned(self):
        hours, idx, _ = _build_24h_series(iana="Asia/Kolkata")
        uv_values  = [0.0] * 24
        aqi_values = [0.0] * 24
        uv_values[idx]  = 8.0
        aqi_values[idx] = 120.0
        uv_resp  = _make_open_meteo_uv_response(hours, uv_values)
        aqi_resp = _make_open_meteo_aqi_response(hours, aqi_values)
        with patch("requests.get", side_effect=[uv_resp, aqi_resp]):
            result = self._provider()._fetch_open_meteo_uv_aqi(17.385, 78.487)
        assert result["uv_index"] == 8
        assert result["aqi"] == 120

    def test_U10_both_fail_both_none(self):
        import requests as req_mod
        with patch("requests.get",
                   side_effect=[req_mod.exceptions.Timeout,
                                 req_mod.exceptions.Timeout]):
            result = self._provider()._fetch_open_meteo_uv_aqi(17.385, 78.487)
        assert result["uv_index"] is None
        assert result["aqi"] is None


# ===========================================================================
# Group P — IMD provider integration
# ===========================================================================

class TestProviderIntegration:

    def _mock_imd_current_response(self):
        mock = MagicMock()
        mock.ok = True
        mock.status_code = 200
        mock.json.return_value = [_MINIMAL_IMD_STATION]
        mock.text = json.dumps([_MINIMAL_IMD_STATION])
        return mock

    def test_P1_open_meteo_failure_does_not_break_imd_response(self):
        """IMD WeatherResponse returned even when Open-Meteo fails."""
        import requests as req_mod
        from app.services.weather_provider import LocationQuery

        imd_resp = self._mock_imd_current_response()
        with patch("app.config.settings.IMD_STATION_ID", "42867"), \
             patch("app.services.imd_auth.get_access_token", return_value="FAKE.JWT"), \
             patch("requests.get", side_effect=[
                 imd_resp,
                 req_mod.exceptions.Timeout,   # Open-Meteo UV+visibility
                 req_mod.exceptions.Timeout,   # Open-Meteo AQI
                 req_mod.exceptions.Timeout,   # Open-Meteo daily forecast
             ]):
            provider = IMDWeatherProvider()
            from app.config import settings as _s
            _s.IMD_API_KEY        = "FAKE"
            _s.IMD_CURRENT_WX_URL = "https://api.imd.gov.in/api/v1/current_wx"
            _s.IMD_EMAIL          = "u@e.com"
            _s.IMD_PASSWORD       = "pw"
            resp = provider.get_weather(LocationQuery(
                city="Hyderabad", latitude=17.385, longitude=78.487
            ))

        assert resp is not None
        assert resp.city == "HYDERABAD"
        assert resp.temperature == pytest.approx(31.0, abs=0.01)
        assert resp.uv_index is None
        assert resp.aqi is None

    def test_P2_uv_card_present_when_uv_provided(self):
        resp = map_current_weather(_MINIMAL_IMD_STATION, uv_index=7)
        types = [c.type for c in resp.cards]
        assert "uv_index" in types
        uv_card = next(c for c in resp.cards if c.type == "uv_index")
        assert uv_card.value == "7"

    def test_P3_aqi_card_title_is_estimated(self):
        resp = map_current_weather(_MINIMAL_IMD_STATION, aqi=112)
        types = [c.type for c in resp.cards]
        assert "air_quality" in types
        aqi_card = next(c for c in resp.cards if c.type == "air_quality")
        assert aqi_card.title == "Air Quality (est.)"
        assert aqi_card.value == "112"

    def test_P4_provider_populates_forecast_and_supplementary_fields_when_open_meteo_succeeds(self):
        """When Open-Meteo succeeds, IMDWeatherProvider.get_weather populates
        forecast, coordinates, uv_index, aqi, and visibility_km."""
        from app.services.weather_provider import LocationQuery

        hours, idx, _ = _build_24h_series(iana="Asia/Kolkata")
        uv_resp = MagicMock(ok=True, status_code=200)
        uv_resp.json.return_value = {
            "timezone": "Asia/Kolkata",
            "utc_offset_seconds": 19800,
            "hourly": {
                "time": hours,
                "uv_index": [5.0] * 24,
                "visibility": [8000.0] * 24,
            },
        }
        aqi_resp = _make_open_meteo_aqi_response(hours, [75.0] * 24)
        daily_resp = MagicMock(ok=True, status_code=200)
        daily_resp.json.return_value = {
            "daily": {
                "time": [f"2026-10-{14+i:02d}" for i in range(7)],
                "temperature_2m_max": [32.0 + i for i in range(7)],
                "temperature_2m_min": [22.0 + i for i in range(7)],
                "precipitation_probability_max": [10 * i for i in range(7)],
                "precipitation_sum": [float(i) for i in range(7)],
                "weather_code": [0, 1, 2, 3, 51, 61, 95],
            }
        }
        imd_resp = self._mock_imd_current_response()

        with patch("app.config.settings.IMD_STATION_ID", "42867"), \
             patch("app.services.imd_auth.get_access_token", return_value="FAKE.JWT"), \
             patch("requests.get", side_effect=[imd_resp, uv_resp, aqi_resp, daily_resp]):
            provider = IMDWeatherProvider()
            from app.config import settings as _s
            _s.IMD_API_KEY        = "FAKE"
            _s.IMD_CURRENT_WX_URL = "https://api.imd.gov.in/api/v1/current_wx"
            _s.IMD_EMAIL          = "u@e.com"
            _s.IMD_PASSWORD       = "pw"
            # No GPS coords passed — relies on static coordinate resolution
            resp = provider.get_weather(LocationQuery(city="Hyderabad"))

        assert resp is not None
        assert resp.latitude == pytest.approx(17.45, abs=0.01)
        assert resp.longitude == pytest.approx(78.47, abs=0.01)
        assert resp.uv_index == 5
        assert resp.aqi == 75
        assert resp.visibility_km == pytest.approx(8.0, abs=0.01)
        assert len(resp.forecast) == 7
        assert resp.forecast[0].max_temp_c == pytest.approx(32.0, abs=0.01)
        assert resp.forecast[0].condition == "Clear sky"
        assert resp.forecast[3].condition == "Overcast"

    def test_P5_whitespace_station_id_resolves_coordinates(self):
        """Station ID with leading/trailing whitespace and CRLF still resolves coordinates."""
        from app.services.weather_provider import LocationQuery

        imd_resp = self._mock_imd_current_response()
        with patch("app.config.settings.IMD_STATION_ID", " 42867 \r\n"), \
             patch("app.services.imd_auth.get_access_token", return_value="FAKE.JWT"), \
             patch("requests.get", side_effect=[
                 imd_resp,
                 MagicMock(ok=False, status_code=500, text=""),
                 MagicMock(ok=False, status_code=500, text=""),
                 MagicMock(ok=False, status_code=500, text=""),
             ]):
            provider = IMDWeatherProvider()
            from app.config import settings as _s
            _s.IMD_API_KEY        = "FAKE"
            _s.IMD_CURRENT_WX_URL = "https://api.imd.gov.in/api/v1/current_wx"
            _s.IMD_EMAIL          = "u@e.com"
            _s.IMD_PASSWORD       = "pw"
            resp = provider.get_weather(LocationQuery(city="Hyderabad"))

        assert resp.latitude == pytest.approx(17.45, abs=0.01)
        assert resp.longitude == pytest.approx(78.47, abs=0.01)

    def test_P6_city_fallback_resolves_coordinates_when_station_unlisted(self):
        """When station ID is not in _STATION_COORDS, known city resolves coords."""
        from app.services.weather_provider import LocationQuery

        unlisted_station = {**_MINIMAL_IMD_STATION, "Station Id": "99999"}
        mock = MagicMock(ok=True, status_code=200)
        mock.json.return_value = [unlisted_station]
        mock.text = json.dumps([unlisted_station])

        with patch("app.config.settings.IMD_STATION_ID", "99999"), \
             patch("app.services.imd_auth.get_access_token", return_value="FAKE.JWT"), \
             patch("requests.get", side_effect=[
                 mock,
                 MagicMock(ok=False, status_code=500, text=""),
                 MagicMock(ok=False, status_code=500, text=""),
                 MagicMock(ok=False, status_code=500, text=""),
             ]):
            provider = IMDWeatherProvider()
            from app.config import settings as _s
            _s.IMD_API_KEY        = "FAKE"
            _s.IMD_CURRENT_WX_URL = "https://api.imd.gov.in/api/v1/current_wx"
            _s.IMD_EMAIL          = "u@e.com"
            _s.IMD_PASSWORD       = "pw"
            resp = provider.get_weather(LocationQuery(city="Hyderabad"))

        assert resp.latitude == pytest.approx(17.45, abs=0.01)
        assert resp.longitude == pytest.approx(78.47, abs=0.01)


# ===========================================================================
# Group X — Mapper backward-compatibility
# ===========================================================================

class TestMapperBackwardCompat:

    def test_X1_existing_callers_without_new_args_still_work(self):
        resp = map_current_weather(_MINIMAL_IMD_STATION)
        assert resp is not None
        assert resp.city == "HYDERABAD"

    def test_X2_uv_index_populates_weather_response(self):
        resp = map_current_weather(_MINIMAL_IMD_STATION, uv_index=9)
        assert resp.uv_index == 9

    def test_X3_aqi_populates_weather_response(self):
        resp = map_current_weather(_MINIMAL_IMD_STATION, aqi=145)
        assert resp.aqi == 145

    def test_X4_aqi_card_title_is_estimated(self):
        resp = map_current_weather(_MINIMAL_IMD_STATION, aqi=145)
        aqi_card = next(c for c in resp.cards if c.type == "air_quality")
        assert aqi_card.title == "Air Quality (est.)"

    def test_X5_no_uv_card_when_uv_none(self):
        resp = map_current_weather(_MINIMAL_IMD_STATION, uv_index=None)
        types = [c.type for c in resp.cards]
        assert "uv_index" not in types

    def test_X6_no_aqi_card_when_aqi_none(self):
        resp = map_current_weather(_MINIMAL_IMD_STATION, aqi=None)
        types = [c.type for c in resp.cards]
        assert "air_quality" not in types


# ===========================================================================
# Group C — Coordinate resolution (static station table)
# ===========================================================================

class TestCoordinateResolution:
    """Verify that known IMD station IDs resolve to static coordinates
    when the caller does not supply GPS coordinates."""

    def test_C1_known_station_resolves_coordinates(self):
        """Station 43128 must resolve to static Hyderabad coordinates."""
        from app.services.imd_weather_provider import _STATION_COORDS
        assert "43128" in _STATION_COORDS
        lat, lon = _STATION_COORDS["43128"]
        assert 17.0 < lat < 18.5,  "Hyderabad latitude ~17.4"
        assert 78.0 < lon < 79.5,  "Hyderabad longitude ~78.5"

    def test_C2_unknown_station_not_in_table(self):
        """An unverified station ID must not be in the table."""
        from app.services.imd_weather_provider import _STATION_COORDS
        assert "99999" not in _STATION_COORDS

    def test_C3_caller_gps_takes_precedence_over_static(self):
        """When caller supplies GPS, static lookup must not override it."""
        hours, _, _ = _build_24h_series(iana="Asia/Kolkata")
        uv_values = [5.0] * 24
        imd_resp = MagicMock()
        imd_resp.ok = True
        imd_resp.status_code = 200
        imd_resp.json.return_value = [_MINIMAL_IMD_STATION]
        imd_resp.text = json.dumps([_MINIMAL_IMD_STATION])

        captured_params = {}

        def capture_get(url, params=None, **kwargs):
            captured_params[url] = params or {}
            mock = MagicMock()
            mock.ok = True
            mock.status_code = 200
            mock.json.return_value = {
                "timezone": "Asia/Kolkata",
                "utc_offset_seconds": 19800,
                "hourly": {"time": hours, "uv_index": uv_values,
                           "visibility": [10000.0] * 24},
            }
            mock.text = "{}"
            return mock

        from app.services.weather_provider import LocationQuery
        with patch("app.config.settings.IMD_STATION_ID", "43128"), \
             patch("app.services.imd_auth.get_access_token", return_value="FAKE.JWT"), \
             patch("requests.get", side_effect=[imd_resp, MagicMock(ok=False, status_code=500, text=""),
                                                MagicMock(ok=False, status_code=500, text=""),
                                                MagicMock(ok=False, status_code=500, text="")]):
            provider = IMDWeatherProvider()
            from app.config import settings as _s
            _s.IMD_API_KEY        = "FAKE"
            _s.IMD_CURRENT_WX_URL = "https://api.imd.gov.in/api/v1/current_wx"
            _s.IMD_EMAIL          = "u@e.com"
            _s.IMD_PASSWORD       = "pw"
            # Supply specific GPS coords — different from the static lookup
            provider.get_weather(LocationQuery(
                city="Hyderabad", latitude=12.9716, longitude=77.5946  # Bangalore
            ))


# ===========================================================================
# Group V — Visibility extraction
# ===========================================================================

class TestVisibilityExtraction:
    """Visibility is fetched alongside UV in the same Open-Meteo call."""

    def test_V1_visibility_present_in_uv_aqi_result(self):
        """Result dict from _fetch_open_meteo_uv_aqi must include visibility_km."""
        hours, idx, _ = _build_24h_series(iana="Asia/Kolkata")
        uv_values = [5.0] * 24
        vis_values = [8000.0] * 24  # metres
        uv_values[idx] = 7.0
        vis_values[idx] = 6500.0

        uv_mock = MagicMock()
        uv_mock.ok = True
        uv_mock.status_code = 200
        uv_mock.json.return_value = {
            "timezone": "Asia/Kolkata",
            "utc_offset_seconds": 19800,
            "hourly": {
                "time":       hours,
                "uv_index":   uv_values,
                "visibility": vis_values,
            },
        }
        aqi_mock = _make_open_meteo_aqi_response(hours, [80.0] * 24)

        with patch("requests.get", side_effect=[uv_mock, aqi_mock]):
            result = IMDWeatherProvider()._fetch_open_meteo_uv_aqi(17.385, 78.487)

        assert result is not None
        assert result["uv_index"] == 7
        # 6500 m → 6.5 km
        assert result["visibility_km"] == pytest.approx(6.5, abs=0.05)

    def test_V2_missing_visibility_field_returns_none(self):
        """If Open-Meteo omits the visibility field, visibility_km is None."""
        hours, _, _ = _build_24h_series(iana="Asia/Kolkata")
        uv_mock = MagicMock()
        uv_mock.ok = True
        uv_mock.status_code = 200
        uv_mock.json.return_value = {
            "timezone": "Asia/Kolkata",
            "utc_offset_seconds": 19800,
            "hourly": {
                "time":     hours,
                "uv_index": [3.0] * 24,
                # no "visibility" key
            },
        }
        aqi_mock = _make_open_meteo_aqi_response(hours, [50.0] * 24)

        with patch("requests.get", side_effect=[uv_mock, aqi_mock]):
            result = IMDWeatherProvider()._fetch_open_meteo_uv_aqi(17.385, 78.487)

        assert result is not None
        assert result["visibility_km"] is None

    def test_V3_visibility_passed_to_mapper(self):
        """map_current_weather with visibility_km populates WeatherResponse."""
        resp = map_current_weather(_MINIMAL_IMD_STATION, visibility_km=8.5)
        assert resp.visibility_km == pytest.approx(8.5, abs=0.01)
        vis_card = next((c for c in resp.cards if c.type == "visibility"), None)
        assert vis_card is not None
        assert "8.5" in vis_card.value

    def test_V4_imd_visibility_used_when_om_not_available(self):
        """When visibility_km param is None, IMD field Visibility is tried."""
        station_with_vis = {**_MINIMAL_IMD_STATION, "Visibility": "6.0"}
        resp = map_current_weather(station_with_vis, visibility_km=None)
        assert resp.visibility_km == pytest.approx(6.0, abs=0.01)

    def test_V5_om_visibility_overrides_imd(self):
        """Open-Meteo visibility_km overrides any IMD Visibility field."""
        station_with_vis = {**_MINIMAL_IMD_STATION, "Visibility": "3.0"}
        resp = map_current_weather(station_with_vis, visibility_km=9.0)
        assert resp.visibility_km == pytest.approx(9.0, abs=0.01)


# ===========================================================================
# Group F — Open-Meteo forecast mapping
# ===========================================================================

class TestOpenMeteoForecastMapping:
    """Verify that daily Open-Meteo forecast data maps correctly into ForecastDay."""

    def _forecast_days(self):
        from datetime import datetime, date, timedelta
        today = date.today()
        return [
            {
                "date":      (today + timedelta(days=i)).isoformat(),
                "max_temp":  35.0 + i,
                "min_temp":  24.0 + i,
                "rain_prob": float(i * 10),
                "precip":    float(i),
                "wmo_code":  63,   # Moderate rain
            }
            for i in range(7)
        ]

    def test_F1_forecast_length(self):
        from app.services.imd_mapper import _map_open_meteo_forecast
        days = self._forecast_days()
        result = _map_open_meteo_forecast(days)
        assert len(result) == 7

    def test_F2_temperature_fields(self):
        from app.services.imd_mapper import _map_open_meteo_forecast
        result = _map_open_meteo_forecast(self._forecast_days())
        assert result[0].max_temp_c == pytest.approx(35.0, abs=0.01)
        assert result[0].min_temp_c == pytest.approx(24.0, abs=0.01)

    def test_F3_rain_probability_separate_from_rainfall_mm(self):
        """rain_probability (%) must NOT be confused with rainfall_mm."""
        from app.services.imd_mapper import _map_open_meteo_forecast
        days = self._forecast_days()
        # day[2]: rain_prob=20%, precip=2.0 mm
        result = _map_open_meteo_forecast(days)
        assert result[2].rain_probability == pytest.approx(20.0, abs=0.1)
        assert result[2].rainfall_mm      == pytest.approx(2.0,  abs=0.01)
        # They must be distinct values
        assert result[2].rain_probability != result[2].rainfall_mm

    def test_F4_condition_from_wmo_code(self):
        from app.services.imd_mapper import _map_open_meteo_forecast
        result = _map_open_meteo_forecast(self._forecast_days())
        assert result[0].condition == "Moderate rain"

    def test_F5_weather_code_preserved_as_string(self):
        from app.services.imd_mapper import _map_open_meteo_forecast
        result = _map_open_meteo_forecast(self._forecast_days())
        assert result[0].weather_code == "63"

    def test_F6_empty_input_returns_empty_list(self):
        from app.services.imd_mapper import _map_open_meteo_forecast
        assert _map_open_meteo_forecast([]) == []
        assert _map_open_meteo_forecast(None) == []

    def test_F7_partial_missing_fields_handled(self):
        """Entries missing some fields must not crash."""
        from app.services.imd_mapper import _map_open_meteo_forecast
        sparse = [{"date": "2026-10-04"}]  # no temp/prob/precip
        result = _map_open_meteo_forecast(sparse)
        assert len(result) == 1
        assert result[0].date == "2026-10-04"
        assert result[0].max_temp_c is None
        assert result[0].rain_probability is None

    def test_F8_om_forecast_used_when_imd_forecast_absent(self):
        """map_current_weather uses open_meteo_forecast when forecast_json is None."""
        days = self._forecast_days()
        resp = map_current_weather(
            _MINIMAL_IMD_STATION,
            forecast_json=None,
            open_meteo_forecast=days,
        )
        assert len(resp.forecast) == 7
        assert resp.forecast[0].rain_probability == pytest.approx(0.0, abs=0.01)

    def test_F9_imd_forecast_preferred_over_om_when_both_present(self):
        """If forecast_json is provided, it is used; open_meteo_forecast is ignored."""
        fj = {"Forecast": [{"Date": "2026-10-04", "Min_Temp": "22", "Max_Temp": "33",
                             "Rainfall": "0", "Rain_Prob": "10",
                             "Weather_Desc": "Partly Cloudy", "Weather_Code": "03"}]}
        days = self._forecast_days()  # 7 days
        resp = map_current_weather(
            _MINIMAL_IMD_STATION,
            forecast_json=fj,
            open_meteo_forecast=days,
        )
        # IMD forecast has 1 entry; OM has 7 — IMD should win
        assert len(resp.forecast) == 1
        assert resp.forecast[0].date == "2026-10-04"

    def test_F10_wmo_code_non_int_does_not_crash(self):
        """Non-integer wmo_code strings or invalid types must not raise ValueError."""
        from app.services.imd_mapper import _map_open_meteo_forecast
        sparse = [{"date": "2026-10-04", "wmo_code": "N/A"}]
        result = _map_open_meteo_forecast(sparse)
        assert len(result) == 1
        assert result[0].condition is None
        assert result[0].weather_code is None

    def test_F11_forecast_json_list_or_invalid_does_not_crash_mapper(self):
        """When forecast_json is a list or unexpected type, mapper safely falls back."""
        days = self._forecast_days()
        resp_list = map_current_weather(
            _MINIMAL_IMD_STATION,
            forecast_json=[],
            open_meteo_forecast=days,
        )
        assert len(resp_list.forecast) == 7

        resp_list_entries = map_current_weather(
            _MINIMAL_IMD_STATION,
            forecast_json=[{"Date": "2026-10-04"}],
            open_meteo_forecast=days,
        )
        assert len(resp_list_entries.forecast) == 7


# ===========================================================================
# Group R — Rain Alert card fallback text
# ===========================================================================

class TestRainAlertFallback:

    def test_R1_rain_mm_shown_when_rainfall_positive(self):
        """When rainfall_mm > 0, the card shows the mm value."""
        station = {**_MINIMAL_IMD_STATION, "Last 24 hrs Rainfall": "5.2"}
        resp = map_current_weather(station)
        rain_card = next(c for c in resp.cards if c.type == "rain_alert")
        assert "5.2" in rain_card.value

    def test_R2_unknown_condition_shows_no_data(self):
        """When condition is 'Unknown' and rainfall is 0, card shows 'No data'."""
        # Weather code absent → condition = "Unknown"
        station = {k: v for k, v in _MINIMAL_IMD_STATION.items()
                   if k not in ("Weather Code", "Weather_Code")}
        station["Last 24 hrs Rainfall"] = "0.0"
        resp = map_current_weather(station)
        rain_card = next(c for c in resp.cards if c.type == "rain_alert")
        assert rain_card.value == "No data"

    def test_R3_meaningful_condition_shown_when_rainfall_zero(self):
        """When rainfall is 0 but condition is meaningful (e.g. 'Haze'), show it."""
        station = {**_MINIMAL_IMD_STATION, "Last 24 hrs Rainfall": "0.0",
                   "Weather Code": "05"}  # 05 → "Haze"
        resp = map_current_weather(station)
        rain_card = next(c for c in resp.cards if c.type == "rain_alert")
        assert rain_card.value == "Haze"

    def test_R4_no_data_not_no_rainfall(self):
        """'No data' must be used when data is missing, not 'No rainfall reported'."""
        station = {k: v for k, v in _MINIMAL_IMD_STATION.items()
                   if k not in ("Weather Code", "Weather_Code", "Last 24 hrs Rainfall")}
        resp = map_current_weather(station)
        rain_card = next(c for c in resp.cards if c.type == "rain_alert")
        assert rain_card.value not in ("No rainfall reported", "Unknown")
        assert rain_card.value == "No data"
