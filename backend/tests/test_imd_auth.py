"""
IMD Auth Tests
==============
Unit tests for app/services/imd_auth.py

Tests:
  Group T — token fetching and caching
    T1: successful JWT generation returns access_token string
    T2: token is cached after first fetch (no second HTTP call)
    T3: cached token is reused before expiry
    T4: expired token triggers a new HTTP call
    T5: token with non-default expires_in is cached correctly

  Group F — authentication failure
    F1: HTTP 401 from OAuth endpoint raises IMDAuthError
    F2: HTTP 500 from OAuth endpoint raises IMDAuthError
    F3: connection error raises IMDAuthError
    F4: timeout raises IMDAuthError
    F5: missing access_token in response raises IMDAuthError
    F6: non-JSON response raises IMDAuthError
    F7: missing IMD_EMAIL raises ConfigurationError
    F8: missing IMD_PASSWORD raises ConfigurationError

  Group H — both headers sent to data endpoints
    H1: X-API-KEY and Authorization headers both present in data requests
    H2: Authorization header value is "Bearer <token>"
    H3: JWT is never placed in query parameters
    H4: 401 on data request invalidates token and retries once
    H5: 401 retry does NOT loop indefinitely

All tests use mocked HTTP responses. No real IMD credentials are used.
"""

import json
import os
import sys
import time
from unittest.mock import MagicMock, patch, call

import pytest

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import app.services.imd_auth as _auth_module
from app.services.imd_auth import (
    IMDAuthError,
    _TokenCache,
    get_access_token,
    invalidate_token,
    _fetch_token,
)
from app.config.settings import ConfigurationError


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _ok_token_response(token: str = "TEST.JWT.TOKEN", expires_in: int = 3600):
    """Return a mock requests.Response that looks like a successful OAuth call."""
    mock = MagicMock()
    mock.ok = True
    mock.status_code = 200
    mock.json.return_value = {
        "access_token": token,
        "token_type": "Bearer",
        "expires_in": expires_in,
    }
    mock.text = json.dumps(mock.json.return_value)
    return mock


def _error_response(status: int, body: str = "error"):
    mock = MagicMock()
    mock.ok = False
    mock.status_code = status
    mock.text = body
    mock.json.return_value = {"error": body}
    return mock


def _reset_cache():
    """Force a clean token cache state before each test."""
    _auth_module._cache.clear()


# ===========================================================================
# Group T — token fetching and caching
# ===========================================================================

class TestTokenFetching:

    def setup_method(self):
        _reset_cache()

    def test_T1_successful_token_generation(self):
        """Successful POST returns the access_token string."""
        with patch("app.config.settings.IMD_EMAIL", "user@example.com"), \
             patch("app.config.settings.IMD_PASSWORD", "secret"), \
             patch("requests.post", return_value=_ok_token_response("MY.TOKEN.VALUE")):
            token = get_access_token()

        assert token == "MY.TOKEN.VALUE"

    def test_T2_token_cached_after_first_fetch(self):
        """Second call uses the cache — no second HTTP POST."""
        with patch("app.config.settings.IMD_EMAIL", "user@example.com"), \
             patch("app.config.settings.IMD_PASSWORD", "secret"), \
             patch("requests.post", return_value=_ok_token_response()) as mock_post:
            t1 = get_access_token()
            t2 = get_access_token()

        assert t1 == t2
        assert mock_post.call_count == 1, "HTTP POST must happen only once when token is cached"

    def test_T3_cached_token_reused_before_expiry(self):
        """Token is not refreshed while still valid."""
        cache = _TokenCache()
        cache.set("CACHED.TOKEN", 7200)   # 2 hours from now
        assert cache.is_valid() is True
        assert cache.get() == "CACHED.TOKEN"

    def test_T4_expired_token_triggers_new_fetch(self):
        """Token with expires_in=0 is treated as already expired."""
        cache = _TokenCache()
        cache.set("OLD.TOKEN", 0)   # expires immediately
        assert cache.is_valid() is False

    def test_T5_token_stored_with_correct_lifetime(self):
        """Cache records the token and its expiry time correctly."""
        cache = _TokenCache()
        before = time.monotonic()
        cache.set("TKN", 1800)
        after = time.monotonic()
        # Should be valid now
        assert cache.is_valid() is True
        # expires_at should be approximately now + 1800
        remaining = cache._expires_at - time.monotonic()
        # Allow ±2 s for test execution time
        assert 1798 < remaining < 1802


# ===========================================================================
# Group F — authentication failure
# ===========================================================================

class TestAuthFailures:

    def setup_method(self):
        _reset_cache()

    def test_F1_401_raises_imd_auth_error(self):
        with patch("app.config.settings.IMD_EMAIL", "u@e.com"), \
             patch("app.config.settings.IMD_PASSWORD", "pw"), \
             patch("requests.post", return_value=_error_response(401)):
            with pytest.raises(IMDAuthError) as exc_info:
                get_access_token()
        assert "401" in str(exc_info.value)

    def test_F2_500_raises_imd_auth_error(self):
        with patch("app.config.settings.IMD_EMAIL", "u@e.com"), \
             patch("app.config.settings.IMD_PASSWORD", "pw"), \
             patch("requests.post", return_value=_error_response(500)):
            with pytest.raises(IMDAuthError):
                get_access_token()

    def test_F3_connection_error_raises_imd_auth_error(self):
        import requests as req_mod
        with patch("app.config.settings.IMD_EMAIL", "u@e.com"), \
             patch("app.config.settings.IMD_PASSWORD", "pw"), \
             patch("requests.post",
                   side_effect=req_mod.exceptions.ConnectionError("refused")):
            with pytest.raises(IMDAuthError) as exc_info:
                get_access_token()
        assert "connection" in str(exc_info.value).lower()

    def test_F4_timeout_raises_imd_auth_error(self):
        import requests as req_mod
        with patch("app.config.settings.IMD_EMAIL", "u@e.com"), \
             patch("app.config.settings.IMD_PASSWORD", "pw"), \
             patch("requests.post",
                   side_effect=req_mod.exceptions.Timeout):
            with pytest.raises(IMDAuthError) as exc_info:
                get_access_token()
        assert "timed out" in str(exc_info.value).lower()

    def test_F5_missing_access_token_in_response_raises(self):
        mock = MagicMock()
        mock.ok = True
        mock.status_code = 200
        mock.json.return_value = {"token_type": "Bearer"}   # no access_token key
        mock.text = "{}"
        with patch("app.config.settings.IMD_EMAIL", "u@e.com"), \
             patch("app.config.settings.IMD_PASSWORD", "pw"), \
             patch("requests.post", return_value=mock):
            with pytest.raises(IMDAuthError) as exc_info:
                get_access_token()
        assert "access_token" in str(exc_info.value)

    def test_F6_non_json_response_raises_imd_auth_error(self):
        mock = MagicMock()
        mock.ok = True
        mock.status_code = 200
        mock.text = "<html>Not JSON</html>"
        mock.json.side_effect = ValueError("no json")
        with patch("app.config.settings.IMD_EMAIL", "u@e.com"), \
             patch("app.config.settings.IMD_PASSWORD", "pw"), \
             patch("requests.post", return_value=mock):
            with pytest.raises(IMDAuthError):
                get_access_token()

    def test_F7_missing_email_raises_configuration_error(self):
        with patch("app.config.settings.IMD_EMAIL", None), \
             patch("app.config.settings.IMD_PASSWORD", "pw"):
            with pytest.raises(ConfigurationError) as exc_info:
                get_access_token()
        assert "IMD_EMAIL" in str(exc_info.value)

    def test_F8_missing_password_raises_configuration_error(self):
        with patch("app.config.settings.IMD_EMAIL", "u@e.com"), \
             patch("app.config.settings.IMD_PASSWORD", None):
            with pytest.raises(ConfigurationError) as exc_info:
                get_access_token()
        assert "IMD_PASSWORD" in str(exc_info.value)


# ===========================================================================
# Group H — both headers sent to data endpoints
# ===========================================================================

class TestBothHeadersSentToDataEndpoints:

    def setup_method(self):
        _reset_cache()

    def _make_data_response(self, json_data: dict):
        mock = MagicMock()
        mock.ok = True
        mock.status_code = 200
        mock.json.return_value = json_data
        mock.text = json.dumps(json_data)
        return mock

    def test_H1_both_headers_present_in_data_request(self):
        """Every IMD data request must carry X-API-KEY and Authorization."""
        from app.services.imd_weather_provider import IMDWeatherProvider

        _auth_module._cache.set("FAKE.JWT", 3600)
        data_resp = self._make_data_response({"Station": "HYD", "Temperature": "30"})

        with patch("requests.get", return_value=data_resp) as mock_get:
            provider = IMDWeatherProvider()
            provider._fetch_current(
                station_id="42867",
                api_key="MY_API_KEY",
                url="https://api.imd.gov.in/api/v1/current_wx",
                auth_header="X-API-KEY",
            )

        _, kwargs = mock_get.call_args
        headers = kwargs.get("headers", {})

        assert "X-API-KEY" in headers, "X-API-KEY header must be present"
        assert "Authorization" in headers, "Authorization header must be present"

    def test_H2_authorization_header_is_bearer_jwt(self):
        """Authorization header value must be 'Bearer <token>'."""
        from app.services.imd_weather_provider import IMDWeatherProvider

        _auth_module._cache.set("SPECIFIC.TOKEN.VALUE", 3600)
        data_resp = self._make_data_response({"Station": "HYD", "Temperature": "30"})

        with patch("requests.get", return_value=data_resp) as mock_get:
            provider = IMDWeatherProvider()
            provider._fetch_current(
                station_id="42867",
                api_key="MY_API_KEY",
                url="https://api.imd.gov.in/api/v1/current_wx",
                auth_header="X-API-KEY",
            )

        _, kwargs = mock_get.call_args
        auth_value = kwargs["headers"]["Authorization"]
        assert auth_value == "Bearer SPECIFIC.TOKEN.VALUE"

    def test_H3_jwt_not_in_query_params(self):
        """The JWT token must never appear in URL query parameters."""
        from app.services.imd_weather_provider import IMDWeatherProvider

        _auth_module._cache.set("SECRET.JWT.TOKEN", 3600)
        data_resp = self._make_data_response({"Station": "HYD", "Temperature": "30"})

        with patch("requests.get", return_value=data_resp) as mock_get:
            provider = IMDWeatherProvider()
            provider._fetch_current(
                station_id="42867",
                api_key="MY_API_KEY",
                url="https://api.imd.gov.in/api/v1/current_wx",
                auth_header="X-API-KEY",
            )

        _, kwargs = mock_get.call_args
        params = kwargs.get("params", {})
        for v in params.values():
            assert "SECRET.JWT.TOKEN" not in str(v), (
                "JWT token must not appear in query parameters"
            )

    def test_H4_401_on_data_request_invalidates_token_and_retries(self):
        """401 on a data call must invalidate the JWT cache and retry once."""
        from app.services.imd_weather_provider import IMDWeatherProvider

        _auth_module._cache.set("OLD.TOKEN", 3600)

        # First call returns 401; second (after token refresh) returns 200
        response_401 = MagicMock()
        response_401.ok = False
        response_401.status_code = 401
        response_401.text = "Unauthorized"

        response_200 = self._make_data_response({"Station": "HYD", "Temperature": "30"})

        call_responses = [response_401, response_200]

        with patch("requests.get", side_effect=call_responses) as mock_get, \
             patch("app.config.settings.IMD_EMAIL", "u@e.com"), \
             patch("app.config.settings.IMD_PASSWORD", "pw"), \
             patch("requests.post", return_value=_ok_token_response("NEW.TOKEN")):
            provider = IMDWeatherProvider()
            result = provider._fetch_current(
                station_id="42867",
                api_key="MY_API_KEY",
                url="https://api.imd.gov.in/api/v1/current_wx",
                auth_header="X-API-KEY",
            )

        # Two GET calls: original + one retry
        assert mock_get.call_count == 2
        assert result == {"Station": "HYD", "Temperature": "30"}

    def test_H5_401_retry_does_not_loop(self):
        """After one retry the 401 must propagate as IMDFetchError, not loop."""
        from app.services.imd_weather_provider import IMDWeatherProvider, IMDFetchError

        _auth_module._cache.set("OLD.TOKEN", 3600)

        # Both calls return 401
        response_401 = MagicMock()
        response_401.ok = False
        response_401.status_code = 401
        response_401.text = "Unauthorized"

        with patch("requests.get", return_value=response_401) as mock_get, \
             patch("app.config.settings.IMD_EMAIL", "u@e.com"), \
             patch("app.config.settings.IMD_PASSWORD", "pw"), \
             patch("requests.post", return_value=_ok_token_response("NEW.TOKEN")):
            provider = IMDWeatherProvider()
            with pytest.raises(IMDFetchError) as exc_info:
                provider._fetch_current(
                    station_id="42867",
                    api_key="MY_API_KEY",
                    url="https://api.imd.gov.in/api/v1/current_wx",
                    auth_header="X-API-KEY",
                )

        # Exactly 2 GET calls (original + 1 retry), not infinite
        assert mock_get.call_count == 2
        assert "401" in str(exc_info.value)
