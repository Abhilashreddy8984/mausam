# Mausam Backend

**SIH 2026 — Project SIH26076**
_Development of Personalized Homepage for 'Mausam' Mobile Application_

---

## ⚠ Important: Current Weather Data is DEMO DATA

**This backend currently serves hard-coded demo weather values.**

All demo values are defined in `app/services/weather_service.py`.

**No live IMD data is used at this stage.**

Live IMD data will be integrated only after:
- Official IMD API access has been authorized through the appropriate channels.
- API credentials have been securely obtained and stored.
- The official IMD response schema has been reviewed and mapped.

---

## ⚠ Important: Ranking is Rule-Based, Not Machine Learning

The personalization engine is a **transparent, rule-based scoring system**.

- All rules are hand-written and human-readable.
- All thresholds are named constants in `app/services/context_thresholds.py`.
- There is no trained model, no neural network, no statistical learning.
- Same input always produces the same output (deterministic).

This is an **academic SIH prototype**.
The rules are not official IMD advisories.

---

## Architecture Overview

```
Flutter App
    │
    │  GET /homepage?persona=farmer&city=Hyderabad
    ▼
┌─────────────────────────────────────────────────────────────┐
│                       API Routes                            │
│                  app/api/routes.py                          │
│  1. Calls provider_factory.get_provider()                   │
│  2. Calls provider.get_weather(LocationQuery)               │
│  3. Builds RankingContext from weather + server time        │
│  4. Calls ranking_service.rank(cards, persona, context)     │
│  5. Returns ranked WeatherResponse                          │
└────────┬──────────────────────────────────┬─────────────────┘
         │                                  │
         ▼                                  ▼
┌─────────────────┐              ┌──────────────────────────┐
│ Provider Factory│              │      Ranking Service      │
│ provider_factory│              │   ranking_service.py      │
│ .py             │              │                           │
│ Reads env var   │              │  score = persona_score    │
│ WEATHER_PROVIDER│              │        + weather_boost    │
│ Default: demo   │              │        + time_boost       │
└────────┬────────┘              └──────────────────────────┘
         │
    ┌────┴──────────────────┐
    ▼                       ▼
┌────────────┐     ┌──────────────────┐
│   Demo     │     │      IMD         │
│  Provider  │     │    Provider      │
│  (active)  │     │  (stub/future)   │
└────────────┘     └──────────────────┘
```

---

## Context-Aware Ranking System

### Design Principle

> "Personalization changes the priority, not the availability."

Every weather card is **always returned**.
The ranking engine only changes their **order**.
Cards are never filtered or removed based on persona or weather context.

---

### Scoring Formula (Additive)

```
final_score = persona_score
            + weather_context_score
            + time_context_score
```

| Component | Range | Source |
|-----------|-------|--------|
| `persona_score` | 1.0 – 10.0 | Per-card weight from persona weight table |
| `weather_context_score` | 0.0 – 5.0 | Boost when current conditions make card urgent |
| `time_context_score` | 0.0 – 2.0 | Small boost for time-of-day relevance |
| **max possible** | **≈ 17.0** | |
| **min possible** | **≈ 1.0** | |

Cards with no explicit persona weight receive `DEFAULT_WEIGHT = 1.0`
and may still receive weather/time boosts if conditions apply.

---

### 1. Persona Score

Each persona has a weight table mapping card types to base relevance scores.
Higher weight = card appears higher in the ranked list by default.

| Persona | Top priority cards |
|---------|-------------------|
| `farmer` | rain_alert (10), humidity (9), temperature (8), wind_speed (7) |
| `student` | feels_like (8), temperature (7), rain_alert (6) |
| `traveller` | visibility (10), wind_speed (9), rain_alert (9) |
| `health` | air_quality (10), pollen (9), uv_index (8) |
| `commuter` | rain_alert (10), visibility (9), wind_speed (8) |
| `outdoor_worker` | uv_index (10), temperature (9), feels_like (9) |
| `senior` | feels_like (10), temperature (9), air_quality (9) |
| `event_planner` | rain_alert (10), wind_speed (9), temperature (8) |

All weight tables are defined in `app/services/ranking_service.py`.

---

### 2. Weather Context Score

Applied when current weather conditions make a specific card more urgent
for a specific persona. Rules are defined in `_weather_boosts_for_persona()`
in `ranking_service.py`.

**Condition detection uses named thresholds from `context_thresholds.py`:**

| Threshold constant | Default value | Meaning |
|-------------------|---------------|---------|
| `HIGH_RAIN_PROBABILITY` | 60% | Significant rain |
| `RAIN_CONDITION_KEYWORDS` | rain, shower, drizzle, storm, heavy | Condition string match |
| `HIGH_TEMPERATURE_THRESHOLD` | 38°C | Extreme heat |
| `LOW_TEMPERATURE_THRESHOLD` | 15°C | Cold conditions |
| `HIGH_WIND_THRESHOLD` | 40 km/h | Strong wind |
| `HIGH_UV_THRESHOLD` | 8 | High UV index |
| `HIGH_AQI_THRESHOLD` | 150 | Poor air quality |
| `POOR_VISIBILITY_THRESHOLD` | 4 km | Poor visibility |

**Example boosts applied per persona + condition:**

| Persona | Condition | Card boosted | Boost |
|---------|-----------|-------------|-------|
| farmer | significant rain | rain_alert | +5.0 |
| farmer | high temperature | temperature | +4.0 |
| farmer | strong wind | wind_speed | +4.0 |
| student | significant rain | rain_alert | +5.0 |
| traveller | poor visibility | visibility | +4.0 |
| health | poor AQI | air_quality | +5.0 |
| health | high UV | uv_index | +4.0 |
| commuter | significant rain | rain_alert | +5.0 |
| commuter | poor visibility | visibility | +4.0 |
| outdoor_worker | high temperature | temperature | +4.0 |
| outdoor_worker | high UV | uv_index | +4.0 |
| senior | high temperature | temperature | +4.0 |
| event_planner | significant rain | rain_alert | +5.0 |

All boost constants are defined in `context_thresholds.py` and are easy to adjust.

> ⚠ These are **prototype thresholds** for the SIH academic demo.
> They are **NOT official IMD advisory thresholds**.

---

### 3. Time Context Score

A small time-of-day boost applied on top of persona + weather scores.
Time boosts are intentionally smaller than weather/persona boosts so they
**never override** strong persona relevance — they only fine-tune ordering
when scores are otherwise close.

| Time window | Hours (UTC) | Cards boosted | Boost |
|-------------|-------------|---------------|-------|
| Morning | 05:00–10:00 | sunrise_sunset (+2.0), temperature (+1.0) | |
| Afternoon | 10:00–16:00 | uv_index (+2.0), temperature (+2.0), feels_like (+1.0) | |
| Evening | 16:00–21:00 | visibility (+2.0), rain_alert (+1.0) | |
| Night | 21:00–05:00 | *(no time boost)* | |

Time logic is defined in `_time_boosts()` in `ranking_service.py`.

---

### 4. Location Context

- **City** is the primary location identifier and is already supported.
- **`RankingContext`** also carries optional `latitude` and `longitude` fields,
  ready for future GPS-to-weather coordinate lookup.
- Any city string is accepted. Unknown cities fall back to Hyderabad demo data.
- No complex geospatial algorithms are used at this stage.

---

### 5. Optional Debug Information (`ranking_reasons`)

Each `WeatherCard` in the response carries an optional `ranking_reasons` field:

```json
{
  "type": "rain_alert",
  "score": 15.0,
  "ranking_reasons": [
    "high persona relevance",
    "significant rain detected"
  ]
}
```

This field is `null` for the `/weather` endpoint (unranked).
Flutter ignores this field completely — it is backward-compatible.
It is intended for development inspection and SIH demonstration only.

---

## Project Structure

```
backend/
├── app/
│   ├── __init__.py
│   ├── main.py                        ← FastAPI app, CORS config
│   ├── models/
│   │   ├── __init__.py
│   │   ├── weather.py                 ← WeatherCard, WeatherResponse
│   │   └── ranking_context.py         ← RankingContext dataclass
│   ├── services/
│   │   ├── __init__.py
│   │   ├── weather_provider.py        ← WeatherProvider ABC + LocationQuery
│   │   ├── weather_service.py         ← DemoWeatherProvider (active)
│   │   ├── imd_weather_provider.py    ← IMDWeatherProvider stub (future)
│   │   ├── provider_factory.py        ← Provider selection via env var
│   │   ├── context_thresholds.py      ← All named threshold constants
│   │   └── ranking_service.py         ← Context-aware ranking engine
│   └── api/
│       ├── __init__.py
│       └── routes.py                  ← HTTP endpoints
├── tests/
│   ├── __init__.py
│   └── test_ranking.py                ← 46-assertion deterministic test suite
├── requirements.txt
└── README.md
```

---

## Prerequisites

- Python 3.10 or newer — check: `python --version`
- pip — check: `pip --version`

---

## Setup and Run (Windows — PowerShell)

### 1. Navigate to the backend folder

```powershell
cd c:\Users\abhil\Documents\mausam_personalized\backend
```

### 2. (Recommended) Create a virtual environment

```powershell
python -m venv venv
.\venv\Scripts\Activate.ps1
```

> If you see a script execution error:
> `Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser`

### 3. Install dependencies

```powershell
pip install -r requirements.txt
```

### 4. Start the development server

```powershell
python -m uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

Server starts at: **http://localhost:8000**

No `.env` file is required — the application works out of the box with demo data.

### 5. Run the test suite

```powershell
python tests/test_ranking.py
```

Expected output: `46/46 passed, 0 failed`

---

## API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/health` | Liveness check |
| GET | `/weather?city=Hyderabad` | Weather data, unranked |
| GET | `/homepage?persona=farmer&city=Hyderabad` | Personalized ranked homepage |

### Quick test (PowerShell)

```powershell
Invoke-RestMethod http://localhost:8000/health
Invoke-RestMethod "http://localhost:8000/weather?city=Hyderabad"
Invoke-RestMethod "http://localhost:8000/homepage?persona=farmer&city=Hyderabad"
Invoke-RestMethod "http://localhost:8000/homepage?persona=student&city=Hyderabad"
Invoke-RestMethod "http://localhost:8000/homepage?persona=traveller&city=Hyderabad"
```

Interactive docs: **http://localhost:8000/docs**

---

## Provider Selection

```
WEATHER_PROVIDER=demo    ← default, no .env file needed
WEATHER_PROVIDER=imd     ← future (not yet implemented)
```

Set for current PowerShell session:
```powershell
$env:WEATHER_PROVIDER = "demo"
python -m uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

One file controls everything: `app/services/provider_factory.py`.

---

## Future IMD Provider

To activate the IMD provider once credentials are obtained:

1. Set `IMD_API_KEY` and `IMD_API_BASE_URL` as environment variables (never in source code).
2. Implement `get_weather()` in `app/services/imd_weather_provider.py`.
3. Add a caching layer — consult IMD API docs for appropriate TTL.
4. Set `WEATHER_PROVIDER=imd`.
5. **Routes, ranking, Flutter: zero changes required.**

---

## What is NOT Included Yet

| Feature | Status |
|---------|--------|
| Live IMD API integration | Stub only — awaiting authorization |
| GPS coordinates → weather lookup | `LocationQuery` ready; provider not wired |
| Caching layer | TODO marked in `routes.py` and `provider_factory.py` |
| Database / user profiles | Not started |
| Authentication | Not started |
| Firebase notifications | Not started |
| ML-based ranking | Not started — current ranking is rule-based |
