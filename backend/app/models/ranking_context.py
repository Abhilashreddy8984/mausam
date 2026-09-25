"""
Ranking Context Model
=====================
Carries all inputs that the RankingService uses to compute scores.

The context is built by the route layer from:
  - persona        (from the API query parameter)
  - weather data   (from the active WeatherProvider)
  - current time   (from the server clock at request time)
  - location       (city from the query parameter; lat/lon when available)

Design principles
-----------------
- All weather fields are Optional.  If a field is absent in the provider
  response (e.g. an API that does not return rain_probability), the
  ranking service simply skips that context adjustment — it never crashes.
- Fields match real weather measurements; no values are invented.
- The context is a pure data object — no business logic lives here.
- Adding a new field requires only: add it here, then optionally handle
  it in ranking_service.py.  Nothing else needs to change.
"""

from dataclasses import dataclass, field
from typing import Optional


@dataclass
class RankingContext:
    """
    Complete context snapshot for a single ranking request.

    Persona fields
    --------------
    persona         : Active user persona key, e.g. "farmer", "student".

    Location fields
    ---------------
    city            : City name used for the weather lookup.
    latitude        : Optional decimal latitude (future GPS integration).
    longitude       : Optional decimal longitude (future GPS integration).

    Time fields
    -----------
    current_hour    : Server-side hour (0–23) at request time.
                      Used for small time-of-day relevance adjustments.

    Weather fields  (all optional — skip adjustment if None)
    ---------------
    temperature_c   : Current temperature in °C.
    feels_like_c    : Perceived temperature in °C.
    humidity_pct    : Relative humidity 0–100.
    wind_speed_kmh  : Wind speed in km/h.
    rain_probability: Rain probability 0–100 (percentage).
    condition       : Short weather condition string, e.g. "Heavy Rain".
    visibility_km   : Visibility in km.
    uv_index        : UV index integer (0–11+).
    aqi             : Air Quality Index integer.
    """

    # ── Persona ───────────────────────────────────────────────
    persona: str

    # ── Location ──────────────────────────────────────────────
    city: str
    latitude: Optional[float] = None
    longitude: Optional[float] = None

    # ── Time ──────────────────────────────────────────────────
    current_hour: int = 12          # default midday if not provided

    # ── Weather ───────────────────────────────────────────────
    temperature_c: Optional[float] = None
    feels_like_c: Optional[float] = None
    humidity_pct: Optional[float] = None
    wind_speed_kmh: Optional[float] = None
    rain_probability: Optional[float] = None
    condition: Optional[str] = None
    visibility_km: Optional[float] = None
    uv_index: Optional[int] = None
    aqi: Optional[int] = None
