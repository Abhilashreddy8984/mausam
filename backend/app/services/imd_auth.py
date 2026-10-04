"""
IMD JWT Token Manager
=====================
Obtains and caches a JWT access token from the IMD OAuth endpoint.

IMD authentication flow
-----------------------
Every data request to api.imd.gov.in requires two headers:

    X-API-KEY: <production API key>
    Authorization: Bearer <JWT access token>

The JWT is issued by:

    POST https://api.imd.gov.in/api/oauth/token.php
    Content-Type: application/json

    {"email": "<IMD_EMAIL>", "password": "<IMD_PASSWORD>"}

Successful response:

    {
        "access_token": "<jwt>",
        "token_type": "Bearer",
        "expires_in": 3600
    }

The token is cached in memory and reused until it is close to expiry,
at which point it is automatically refreshed.

Security rules
--------------
- Credentials (email, password, JWT, API key) are NEVER logged.
- Credentials are NEVER placed in URLs or query parameters.
- Credentials are read only from environment variables via settings.py.
- The Authorization header value is NEVER included in log output.
"""

import logging
import time
from threading import Lock

import requests

from app.config.settings import (
    HTTP_TIMEOUT_SECONDS,
    IMD_TOKEN_URL,
    ConfigurationError,
)
# NOTE: IMD_EMAIL and IMD_PASSWORD are intentionally NOT imported as
# module-level names here.  They are read from the settings module at
# call time inside _fetch_token() to guarantee we always see the live
# values loaded from .env, regardless of module-import order.

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# How many seconds before the token's stated expiry time we treat it as
# already expired and proactively refresh it.  This prevents requests
# from failing mid-flight because the token expired during the call.
# ---------------------------------------------------------------------------
_EXPIRY_BUFFER_SECONDS: int = 60


class IMDAuthError(Exception):
    """
    Raised when the IMD OAuth endpoint returns an error or when
    required credentials are absent.
    """


class _TokenCache:
    """
    Thread-safe in-memory cache for the IMD JWT access token.

    Attributes
    ----------
    _token      : The current access token string, or None if never fetched.
    _expires_at : Unix timestamp (float) when the token expires.
    _lock       : Ensures only one thread refreshes the token at a time.
    """

    def __init__(self) -> None:
        self._token: str | None = None
        self._expires_at: float = 0.0
        self._lock: Lock = Lock()

    def is_valid(self) -> bool:
        """Return True if a cached token exists and is not yet close to expiry."""
        return (
            self._token is not None
            and time.monotonic() < (self._expires_at - _EXPIRY_BUFFER_SECONDS)
        )

    def set(self, token: str, expires_in: int) -> None:
        """Store a freshly-fetched token with its lifetime."""
        self._token = token
        self._expires_at = time.monotonic() + expires_in

    def get(self) -> str | None:
        return self._token

    def clear(self) -> None:
        """Force the next call to fetch a fresh token."""
        self._token = None
        self._expires_at = 0.0


# Module-level singleton — shared across all IMDWeatherProvider instances
# during the lifetime of a single server process.
_cache = _TokenCache()


def get_access_token() -> str:
    """
    Return a valid IMD JWT access token, fetching a fresh one if needed.

    Thread-safe: only one thread at a time will perform a token refresh.

    Returns
    -------
    str
        A valid Bearer token string (without the "Bearer " prefix).

    Raises
    ------
    ConfigurationError
        If IMD_EMAIL or IMD_PASSWORD are not configured.
    IMDAuthError
        If the OAuth endpoint returns an error or the response is malformed.
    """
    with _cache._lock:
        if _cache.is_valid():
            return _cache.get()  # type: ignore[return-value]

        token = _fetch_token()
        return token


def _fetch_token() -> str:
    """
    POST to the IMD OAuth endpoint and cache the returned JWT.

    Credentials are read from the settings module at call time — not from
    module-level name bindings — so that the live .env values are always
    used regardless of Python module-import order.

    Credentials are sent in the JSON body — never in the URL.
    The token value is never written to any log.

    Returns
    -------
    str
        The raw access_token value.

    Raises
    ------
    ConfigurationError
        If IMD_EMAIL or IMD_PASSWORD are absent.
    IMDAuthError
        On HTTP error, timeout, connection failure, or malformed response.
    """
    # Re-read from the settings module at call time to pick up .env values
    # that may not have been loaded when this module was first imported.
    from app.config import settings as _s
    _email    = _s.IMD_EMAIL
    _password = _s.IMD_PASSWORD
    _token_url = _s.IMD_TOKEN_URL

    # Validate credentials exist before making any network call
    if not _email:
        raise ConfigurationError(
            "IMD_EMAIL is not set. "
            "It is required to obtain a JWT from the IMD OAuth endpoint."
        )
    if not _password:
        raise ConfigurationError(
            "IMD_PASSWORD is not set. "
            "It is required to obtain a JWT from the IMD OAuth endpoint."
        )

    logger.info("IMDAuth: fetching a fresh JWT access token from %s", _token_url)

    try:
        response = requests.post(
            _token_url,
            json={"email": _email, "password": _password},
            headers={"Content-Type": "application/json"},
            timeout=HTTP_TIMEOUT_SECONDS,
        )
    except requests.exceptions.Timeout:
        raise IMDAuthError(
            f"IMD OAuth token request timed out after {HTTP_TIMEOUT_SECONDS}s."
        )
    except requests.exceptions.ConnectionError as exc:
        raise IMDAuthError(
            f"IMD OAuth connection error: {type(exc).__name__}"
        )
    except requests.exceptions.RequestException as exc:
        raise IMDAuthError(
            f"IMD OAuth request error: {type(exc).__name__}"
        )

    if not response.ok:
        # Log status only — body may contain credentials in error messages
        logger.error(
            "IMDAuth: OAuth endpoint returned HTTP %s. "
            "Check IMD_EMAIL and IMD_PASSWORD are correct and that "
            "the account is active. "
            "OAuth URL: %s",
            response.status_code,
            _token_url,
        )
        raise IMDAuthError(
            f"IMD OAuth endpoint returned HTTP {response.status_code}. "
            f"Verify IMD_EMAIL and IMD_PASSWORD are correct."
        )

    try:
        data = response.json()
    except ValueError as exc:
        raise IMDAuthError(
            f"IMD OAuth response is not valid JSON: {exc}"
        )

    token = data.get("access_token")
    expires_in = data.get("expires_in", 3600)

    if not token:
        raise IMDAuthError(
            "IMD OAuth response did not contain 'access_token'. "
            "The response structure may have changed — check the IMD API docs."
        )

    try:
        expires_in_int = int(expires_in)
    except (TypeError, ValueError):
        logger.warning(
            "IMDAuth: could not parse expires_in=%r, defaulting to 3600s",
            expires_in,
        )
        expires_in_int = 3600

    _cache.set(token, expires_in_int)
    logger.info(
        "IMDAuth: JWT obtained successfully, expires in %ds",
        expires_in_int,
    )
    # Token value is intentionally not logged
    return token


def invalidate_token() -> None:
    """
    Force the next call to get_access_token() to fetch a fresh JWT.

    Call this if a data request receives an unexpected 401 —
    the cached token may have been revoked server-side.
    """
    with _cache._lock:
        _cache.clear()
    logger.info("IMDAuth: cached JWT invalidated, will refresh on next request.")
