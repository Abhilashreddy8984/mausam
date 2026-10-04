"""
IMD Provider Tests
==================
Focused unit tests for:
  - request parameter construction (must use ?id=, never city=)
  - authentication header usage (key passed in header, never in URL)
  - 401 / HTTP-error handling
  - official IMD field-name parsing in imd_mapper
  - wind direction code → compass conversion
  - weather code → description conversion
  - backward-compatibility: legacy field names still work

These tests use unittest.mock to intercept outbound HTTP requests.
No real API key is required. No live IMD calls are made.
The API key is never printed or logged by these tests.

Run from backend/:
    python -m pytest tests/test_imd_provider.py -v
"""

import json
import os
import sys
import unittest
from unittest.mock import MagicMock, patch

import pytest

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.services.imd_mapper import (
    _safe_float,
    _safe_int,
    _safe_str,
    _wind_dir_to_compass,
    _weather_code_to_desc,
    map_current_weather,
)
from app.services.imd_weather_provider import (
    IMDFetchError,
    IMDParseError,
    IMDWeatherProvider,
)

# ---------------------------------------------------------------------------
# Fixture loader
# ---------------------------------------------------------------------------
_FIXTURES = os.path.join(os.path.dirname(__file__), "fixtures")


def _load(name: str) -> dict:
    with open(os.path.join(_FIXTURES, name), encoding="utf-8") as f:
        return json.load(f)


_OFFICIAL_FULL  = _load("imd_current_wx_official_fields.json")
_OFFICIAL_RAIN  = _load("imd_current_wx_official_fields_rain.json")
_LEGACY_FULL    = _load("imd_current_wx_hyderabad.json")  # existing fixture


# ===========================================================================
# Group P — Request parameter construction
# ===========================================================================
# These tests verify that the provider sends ?id=<station_id> and
# NEVER sends city= to the current_wx endpoint.
# ===========================================================================

class TestRequestParameters:
    """Verify correct IMD API parameters are constructed."""

    def _make_mock_response(self, json_data: dict, status: int = 200):
        mock = MagicMock()
        mock.ok = (status == 200)
        mock.status_code = status
        mock.json.return_value = json_data
        mock.text = json.dumps(json_data)
        return mock

    def test_P1_current_wx_uses_id_not_city(self):
        """_fetch_current must pass ?id=<station_id>, NOT city=."""
        provider = IMDWeatherProvider()
        mock_resp = self._make_mock_response(_OFFICIAL_FULL)

        with patch("requests.get", return_value=mock_resp) as mock_get:
            provider._fetch_current(
                station_id="42867",
                api_key="FAKE_KEY",
                url="https://api.imd.gov.in/api/v1/current_wx",
                auth_header="X-Api-Key",
                _jwt_token="TEST.JWT",
            )

        mock_get.assert_called_once()
        _, kwargs = mock_get.call_args
        params = kwargs.get("params", {})

        assert "id" in params, "Request must include 'id' parameter"
        assert params["id"] == "42867", "id must be the station ID"
        assert "city" not in params, (
            "Request must NOT include 'city' parameter — "
            "official current_wx uses ?id=StationId only"
        )

    def test_P2_forecast_uses_id_not_lat_lon(self):
        """_fetch_forecast must pass ?id=<station_code>, NOT lat/lon."""
        provider = IMDWeatherProvider()
        mock_resp = self._make_mock_response({"forecast": []})

        with patch("requests.get", return_value=mock_resp) as mock_get:
            provider._fetch_forecast(
                station_code="42182",
                api_key="FAKE_KEY",
                url="https://api.imd.gov.in/api/v1/cityforecastloc",
                auth_header="X-Api-Key",
                _jwt_token="TEST.JWT",
            )

        _, kwargs = mock_get.call_args
        params = kwargs.get("params", {})

        assert "id" in params
        assert params["id"] == "42182"
        assert "lat" not in params, "Forecast must NOT use lat param"
        assert "lon" not in params, "Forecast must NOT use lon param"
        assert "city" not in params

    def test_P3_warnings_uses_id_not_city(self):
        """_fetch_warnings must pass ?id=<district_id>, NOT city=."""
        provider = IMDWeatherProvider()
        mock_resp = self._make_mock_response({"warnings": []})

        with patch("requests.get", return_value=mock_resp) as mock_get:
            provider._fetch_warnings(
                district_id="573",
                api_key="FAKE_KEY",
                url="https://api.imd.gov.in/api/v1/districtwarning",
                auth_header="X-Api-Key",
                _jwt_token="TEST.JWT",
            )

        _, kwargs = mock_get.call_args
        params = kwargs.get("params", {})
        assert params.get("id") == "573"
        assert "city" not in params

    def test_P4_nowcast_uses_id_not_city(self):
        """_fetch_nowcast must pass ?id=<district_id>, NOT city=."""
        provider = IMDWeatherProvider()
        mock_resp = self._make_mock_response({"nowcast": []})

        with patch("requests.get", return_value=mock_resp) as mock_get:
            provider._fetch_nowcast(
                district_id="1",
                api_key="FAKE_KEY",
                url="https://api.imd.gov.in/api/v1/districtnowcast",
                auth_header="X-Api-Key",
                _jwt_token="TEST.JWT",
            )

        _, kwargs = mock_get.call_args
        params = kwargs.get("params", {})
        assert params.get("id") == "1"
        assert "city" not in params


# ===========================================================================
# Group A — Authentication header
# ===========================================================================

class TestAuthenticationHeader:
    """Verify API key is passed in header, never in URL."""

    def test_A1_api_key_in_header_not_url(self):
        """API key must appear in headers, not query params."""
        provider = IMDWeatherProvider()
        mock_resp = MagicMock()
        mock_resp.ok = True
        mock_resp.status_code = 200
        mock_resp.json.return_value = _OFFICIAL_FULL
        mock_resp.text = "{}"

        with patch("requests.get", return_value=mock_resp) as mock_get:
            provider._fetch_current(
                station_id="42867",
                api_key="FAKE_TEST_KEY",
                url="https://api.imd.gov.in/api/v1/current_wx",
                auth_header="X-Api-Key",
                _jwt_token="TEST.JWT",
            )

        _, kwargs = mock_get.call_args
        headers = kwargs.get("headers", {})
        params  = kwargs.get("params", {})

        # Key must be in headers
        assert "X-Api-Key" in headers, "API key header must be 'X-Api-Key'"
        assert headers["X-Api-Key"] == "FAKE_TEST_KEY"

        # Key must NOT appear in query params
        for v in params.values():
            assert v != "FAKE_TEST_KEY", "API key must NOT be in URL params"

    def test_A2_configurable_auth_header_name(self):
        """The api-key header name (auth_header param) must be configurable.
        The API key is always sent in that header; Authorization always carries
        the JWT Bearer token separately.
        """
        provider = IMDWeatherProvider()
        mock_resp = MagicMock()
        mock_resp.ok = True
        mock_resp.status_code = 200
        mock_resp.json.return_value = _OFFICIAL_FULL
        mock_resp.text = "{}"

        with patch("requests.get", return_value=mock_resp) as mock_get:
            # Use a non-standard header name for the API key
            provider._fetch_current(
                station_id="42867",
                api_key="FAKE_KEY",
                url="https://api.imd.gov.in/api/v1/current_wx",
                auth_header="X-Custom-Api-Key",
                _jwt_token="DUMMY.JWT",  # bypass auth module in test
            )

        _, kwargs = mock_get.call_args
        headers = kwargs.get("headers", {})

        # The configured api-key header must carry the api key
        assert "X-Custom-Api-Key" in headers, "Configured api-key header must be present"
        assert headers["X-Custom-Api-Key"] == "FAKE_KEY"

        # Authorization must carry the JWT, not the api key
        assert "Authorization" in headers, "Authorization (JWT) header must be present"
        assert headers["Authorization"] == "Bearer DUMMY.JWT"

    def test_A3_key_not_in_url_string(self):
        """The full request URL must not contain the API key."""
        provider = IMDWeatherProvider()
        captured_url = {}

        def capture_get(url, **kwargs):
            captured_url["url"] = url
            # Also capture full URL with params
            import urllib.parse
            qs = urllib.parse.urlencode(kwargs.get("params", {}))
            captured_url["full"] = f"{url}?{qs}"
            mock = MagicMock()
            mock.ok = True
            mock.status_code = 200
            mock.json.return_value = _OFFICIAL_FULL
            mock.text = "{}"
            return mock

        with patch("requests.get", side_effect=capture_get):
            provider._fetch_current(
                station_id="42867",
                api_key="SECRET_KEY_DO_NOT_LEAK",
                url="https://api.imd.gov.in/api/v1/current_wx",
                auth_header="X-Api-Key",
                _jwt_token="TEST.JWT",
            )

        assert "SECRET_KEY_DO_NOT_LEAK" not in captured_url.get("full", "")


# ===========================================================================
# Group E — HTTP error and 401 handling
# ===========================================================================

class TestHttpErrorHandling:
    """Verify correct behaviour on HTTP errors, especially 401."""

    def _make_error_response(self, status: int, body: str = "Unauthorized"):
        mock = MagicMock()
        mock.ok = False
        mock.status_code = status
        mock.text = body
        return mock

    # _jwt_token="TEST.JWT" is passed to all _fetch_* calls so the tests
    # can exercise HTTP error paths without real IMD credentials or a live
    # OAuth call.  Production paths always use _jwt_token=None (default).

    def test_E1_401_raises_imd_fetch_error(self):
        """HTTP 401 must raise IMDFetchError (not crash silently)."""
        provider = IMDWeatherProvider()
        mock_resp = self._make_error_response(401, "401 Unauthorized")

        with patch("requests.get", return_value=mock_resp):
            with pytest.raises(IMDFetchError) as exc_info:
                provider._fetch_current(
                    station_id="42867",
                    api_key="FAKE_KEY",
                    url="https://api.imd.gov.in/api/v1/current_wx",
                    auth_header="X-Api-Key",
                    _jwt_token="TEST.JWT",
                )

        assert "401" in str(exc_info.value)

    def test_E2_403_raises_imd_fetch_error(self):
        """HTTP 403 must raise IMDFetchError."""
        provider = IMDWeatherProvider()
        mock_resp = self._make_error_response(403, "Forbidden")

        with patch("requests.get", return_value=mock_resp):
            with pytest.raises(IMDFetchError) as exc_info:
                provider._fetch_current(
                    station_id="42867",
                    api_key="FAKE_KEY",
                    url="https://api.imd.gov.in/api/v1/current_wx",
                    auth_header="X-Api-Key",
                    _jwt_token="TEST.JWT",
                )

        assert "403" in str(exc_info.value)

    def test_E3_500_raises_imd_fetch_error(self):
        """HTTP 500 must raise IMDFetchError."""
        provider = IMDWeatherProvider()
        mock_resp = self._make_error_response(500, "Internal Server Error")

        with patch("requests.get", return_value=mock_resp):
            with pytest.raises(IMDFetchError):
                provider._fetch_current(
                    station_id="42867",
                    api_key="FAKE_KEY",
                    url="https://api.imd.gov.in/api/v1/current_wx",
                    auth_header="X-Api-Key",
                    _jwt_token="TEST.JWT",
                )

    def test_E4_error_message_does_not_contain_api_key(self):
        """The exception message must not contain the API key."""
        provider = IMDWeatherProvider()
        mock_resp = self._make_error_response(403, "Invalid API key provided")

        with patch("requests.get", return_value=mock_resp):
            with pytest.raises(IMDFetchError) as exc_info:
                provider._fetch_current(
                    station_id="42867",
                    api_key="MY_SECRET_KEY_XYZ",
                    url="https://api.imd.gov.in/api/v1/current_wx",
                    auth_header="X-Api-Key",
                    _jwt_token="TEST.JWT",
                )

        assert "MY_SECRET_KEY_XYZ" not in str(exc_info.value), (
            "API key must not appear in the exception message"
        )

    def test_E5_optional_endpoints_swallow_errors(self):
        """Non-required endpoints (forecast/warnings/nowcast) return None on error."""
        provider = IMDWeatherProvider()
        mock_resp = self._make_error_response(401, "Unauthorized")

        with patch("requests.get", return_value=mock_resp):
            result = provider._fetch_forecast(
                station_code="42182",
                api_key="FAKE_KEY",
                url="https://api.imd.gov.in/api/v1/cityforecastloc",
                auth_header="X-Api-Key",
                _jwt_token="TEST.JWT",
            )

        assert result is None, "Forecast failure must return None (non-fatal)"

    def test_E6_warnings_swallow_errors(self):
        provider = IMDWeatherProvider()
        mock_resp = self._make_error_response(404, "Not Found")

        with patch("requests.get", return_value=mock_resp):
            result = provider._fetch_warnings(
                district_id="573",
                api_key="FAKE_KEY",
                url="https://api.imd.gov.in/api/v1/districtwarning",
                auth_header="X-Api-Key",
                _jwt_token="TEST.JWT",
            )
        assert result is None

    def test_E7_timeout_raises_imd_fetch_error(self):
        """Timeout must raise IMDFetchError."""
        import requests as req_mod
        provider = IMDWeatherProvider()

        with patch("requests.get", side_effect=req_mod.exceptions.Timeout):
            with pytest.raises(IMDFetchError) as exc_info:
                provider._fetch_current(
                    station_id="42867",
                    api_key="FAKE_KEY",
                    url="https://api.imd.gov.in/api/v1/current_wx",
                    auth_header="X-Api-Key",
                    _jwt_token="TEST.JWT",
                )

        assert "timed out" in str(exc_info.value).lower()

    def test_E8_invalid_json_raises_imd_parse_error(self):
        """Non-JSON response must raise IMDParseError."""
        provider = IMDWeatherProvider()
        mock_resp = MagicMock()
        mock_resp.ok = True
        mock_resp.status_code = 200
        mock_resp.text = "<html>Gateway Error</html>"
        mock_resp.json.side_effect = ValueError("No JSON")

        with patch("requests.get", return_value=mock_resp):
            with pytest.raises(IMDParseError):
                provider._fetch_current(
                    station_id="42867",
                    api_key="FAKE_KEY",
                    url="https://api.imd.gov.in/api/v1/current_wx",
                    auth_header="X-Api-Key",
                    _jwt_token="TEST.JWT",
                )


# ===========================================================================
# Group O — Official field name parsing in mapper
# ===========================================================================

class TestOfficialFieldNames:
    """Verify mapper reads official IMD current_wx field names correctly."""

    def test_O1_station_field_parsed(self):
        """'Station' (official) must be read as city name."""
        resp = map_current_weather(_OFFICIAL_FULL)
        assert resp.city == "HYDERABAD"

    def test_O2_temperature_field_parsed(self):
        """'Temperature' (official) must be parsed as float."""
        resp = map_current_weather(_OFFICIAL_FULL)
        assert resp.temperature == pytest.approx(33.2, abs=0.01)

    def test_O3_humidity_field_parsed(self):
        """'Humidity' (official) must be parsed."""
        resp = map_current_weather(_OFFICIAL_FULL)
        assert resp.humidity == pytest.approx(65.0, abs=0.01)

    def test_O4_wind_speed_field_parsed(self):
        """'Wind Speed' (official, with space) must be parsed."""
        resp = map_current_weather(_OFFICIAL_FULL)
        assert resp.wind_speed == pytest.approx(18.0, abs=0.01)

    def test_O5_wind_direction_code_converted(self):
        """'Wind Direction' numeric code 230 must map to 'SW'."""
        resp = map_current_weather(_OFFICIAL_FULL)
        assert resp.wind_direction == "SW"

    def test_O6_rainfall_field_parsed(self):
        """'Last 24 hrs Rainfall' (official) must be parsed."""
        resp = map_current_weather(_OFFICIAL_FULL)
        assert resp.rainfall_mm == pytest.approx(0.0, abs=0.01)

    def test_O7_pressure_field_parsed(self):
        """'M.S.L.P' (official) must be parsed as pressure_hpa."""
        resp = map_current_weather(_OFFICIAL_FULL)
        assert resp.pressure_hpa == pytest.approx(997.8, abs=0.01)

    def test_O8_nebulosity_converted_to_percentage(self):
        """Nebulosity 4 (on 0-8 scale) must convert to 50% cloud cover."""
        resp = map_current_weather(_OFFICIAL_FULL)
        assert resp.cloud_cover_pct == pytest.approx(50.0, abs=1.0)

    def test_O9_obs_time_built_from_date_and_time(self):
        """'Date of Observation' + 'Time of Observation' must form obs timestamp."""
        resp = map_current_weather(_OFFICIAL_FULL)
        assert resp.observation_time == "2026-09-27T04:00Z"

    def test_O10_weather_code_03_produces_condition(self):
        """Weather code '03' must produce a human-readable condition."""
        resp = map_current_weather(_OFFICIAL_FULL)
        assert resp.condition is not None
        assert len(resp.condition) > 0
        assert resp.condition != "Unknown"

    def test_O11_source_is_imd(self):
        resp = map_current_weather(_OFFICIAL_FULL)
        assert resp.source == "IMD"

    def test_O12_cards_non_empty(self):
        resp = map_current_weather(_OFFICIAL_FULL)
        assert len(resp.cards) > 0

    def test_O13_rain_card_present(self):
        types = [c.type for c in map_current_weather(_OFFICIAL_FULL).cards]
        assert "rain_alert" in types

    def test_O14_rain_scenario_correct_cloud_cover(self):
        """Nebulosity=8 (full cloud) should map to 100% cover."""
        resp = map_current_weather(_OFFICIAL_RAIN)
        assert resp.cloud_cover_pct == pytest.approx(100.0, abs=1.0)

    def test_O15_rain_scenario_condition_is_rain_description(self):
        """Weather Code 63 = 'Rain, not freezing, continuous moderate'."""
        resp = map_current_weather(_OFFICIAL_RAIN)
        assert "moderate" in resp.condition.lower() or "rain" in resp.condition.lower()


# ===========================================================================
# Group L — Legacy field names backward-compatibility
# ===========================================================================

class TestLegacyFieldNames:
    """Existing test fixtures with old field names must still parse correctly."""

    def test_L1_legacy_station_name_field(self):
        """'Station_Name' (legacy) should still be read as city."""
        resp = map_current_weather(_LEGACY_FULL)
        assert resp.city == "Hyderabad"

    def test_L2_legacy_temp_field(self):
        """'Temp' (legacy) should still be parsed."""
        resp = map_current_weather(_LEGACY_FULL)
        assert resp.temperature == pytest.approx(33.2, abs=0.01)

    def test_L3_legacy_rh_field(self):
        """'RH' (legacy) should still be parsed as humidity."""
        resp = map_current_weather(_LEGACY_FULL)
        assert resp.humidity == pytest.approx(65.0, abs=0.01)

    def test_L4_legacy_wind_dir_string(self):
        """'Wind_Dir' string (legacy) should still be preserved."""
        resp = map_current_weather(_LEGACY_FULL)
        assert resp.wind_direction == "SW"

    def test_L5_legacy_obs_time_field(self):
        """'Obs_Time' (legacy) should be used when date/time fields absent."""
        resp = map_current_weather(_LEGACY_FULL)
        assert resp.observation_time == "2026-09-27T09:30:00+05:30"


# ===========================================================================
# Group W — Wind direction code conversion
# ===========================================================================

class TestWindDirectionConversion:

    def test_W1_code_230_is_sw(self):
        assert _wind_dir_to_compass(230) == "SW"

    def test_W2_code_90_is_e(self):
        assert _wind_dir_to_compass(90) == "E"

    def test_W3_code_270_is_w(self):
        assert _wind_dir_to_compass(270) == "W"

    def test_W4_code_0_is_calm(self):
        assert _wind_dir_to_compass(0) == "Calm"

    def test_W5_code_360_is_n(self):
        assert _wind_dir_to_compass(360) == "N"

    def test_W6_none_returns_none(self):
        assert _wind_dir_to_compass(None) is None

    def test_W7_string_numeric_code(self):
        """Numeric code supplied as string should still convert."""
        assert _wind_dir_to_compass("180") == "S"

    def test_W8_nearest_match(self):
        """Code 235 should match nearest table entry (230=SW)."""
        assert _wind_dir_to_compass(235) == "SW"


# ===========================================================================
# Group C — Weather code to description
# ===========================================================================

class TestWeatherCodeToDesc:

    def test_C1_code_03_clouds_forming(self):
        desc = _weather_code_to_desc("03")
        assert desc is not None
        assert "cloud" in desc.lower() or "forming" in desc.lower()

    def test_C2_code_63_rain(self):
        desc = _weather_code_to_desc("63")
        assert desc is not None
        assert "rain" in desc.lower() or "moderate" in desc.lower()

    def test_C3_code_95_thunderstorm(self):
        desc = _weather_code_to_desc("95")
        assert desc is not None
        assert "thunder" in desc.lower()

    def test_C4_unknown_code_returns_none(self):
        assert _weather_code_to_desc("00") is None

    def test_C5_none_returns_none(self):
        assert _weather_code_to_desc(None) is None

    def test_C6_leading_zero_handled(self):
        """Code "3" should match "03"."""
        assert _weather_code_to_desc("3") is not None


# ===========================================================================
# Group S — settings.py configuration validation
# ===========================================================================

class TestSettingsValidation:
    """Verify require_imd_config raises when station ID is absent."""

    def test_S1_missing_station_id_raises(self):
        """ConfigurationError must be raised when IMD_STATION_ID is missing."""
        from app.config.settings import ConfigurationError

        with patch("app.config.settings.IMD_API_KEY", "FAKE_KEY"), \
             patch("app.config.settings.IMD_CURRENT_WX_URL",
                   "https://api.imd.gov.in/api/v1/current_wx"), \
             patch("app.config.settings.IMD_STATION_ID", None):
            from app.config import settings as s
            s.IMD_STATION_ID = None
            s.IMD_API_KEY = "FAKE_KEY"
            s.IMD_CURRENT_WX_URL = "https://api.imd.gov.in/api/v1/current_wx"
            with pytest.raises(ConfigurationError) as exc_info:
                s.require_imd_config()
            assert "IMD_STATION_ID" in str(exc_info.value)

    def test_S2_all_required_vars_present_does_not_raise(self):
        """No exception when all required vars are present."""
        from app.config import settings as s
        original_key      = s.IMD_API_KEY
        original_url      = s.IMD_CURRENT_WX_URL
        original_id       = s.IMD_STATION_ID
        original_email    = s.IMD_EMAIL
        original_password = s.IMD_PASSWORD
        try:
            s.IMD_API_KEY        = "FAKE_KEY"
            s.IMD_CURRENT_WX_URL = "https://api.imd.gov.in/api/v1/current_wx"
            s.IMD_STATION_ID     = "42867"
            s.IMD_EMAIL          = "test@example.com"
            s.IMD_PASSWORD       = "testpassword"
            s.require_imd_config()  # must not raise
        finally:
            s.IMD_API_KEY        = original_key
            s.IMD_CURRENT_WX_URL = original_url
            s.IMD_STATION_ID     = original_id
            s.IMD_EMAIL          = original_email
            s.IMD_PASSWORD       = original_password
