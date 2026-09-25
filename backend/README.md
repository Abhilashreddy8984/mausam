# Mausam Backend

**SIH 2026 — Project SIH26076**
_Development of Personalized Homepage for 'Mausam' Mobile Application_

This is the Python FastAPI backend that powers the personalized weather homepage.

---

## ⚠ Important: Current Weather Data is DEMO DATA

**This backend currently serves hard-coded demo weather values.**

The demo values are defined in `app/services/weather_service.py` and represent
static conditions for Hyderabad (temperature, humidity, wind speed, etc.).

**No live IMD data is used at this stage.**

Live IMD data will be integrated only after:
- Official IMD API access has been authorized through the appropriate channels.
- API credentials have been securely obtained and stored.
- The official IMD response schema has been reviewed and mapped.

---

## Current Architecture

```
Flutter App
    │
    │  GET /homepage?persona=farmer&city=Hyderabad
    ▼
┌─────────────────────────────────────────────────┐
│                  API Routes                     │
│            app/api/routes.py                    │
│  (knows only WeatherProvider interface —        │
│   never imports a specific provider directly)   │
└────────────────┬────────────────────────────────┘
                 │
                 │  provider_factory.get_provider()
                 ▼
┌─────────────────────────────────────────────────┐
│             Provider Factory                    │
│         app/services/provider_factory.py        │
│  Reads WEATHER_PROVIDER env var.                │
│  Returns the correct WeatherProvider instance.  │
│  Default: demo                                  │
└────────────────┬────────────────────────────────┘
                 │
       ┌─────────┴──────────┐
       ▼                    ▼
┌─────────────┐    ┌──────────────────┐
│    Demo     │    │      IMD         │
│  Provider   │    │    Provider      │
│  (active)   │    │  (stub / future) │
└──────┬──────┘    └──────────────────┘
       │
       │  WeatherResponse (with source="demo")
       ▼
┌─────────────────────────────────────────────────┐
│             Ranking Service                     │
│         app/services/ranking_service.py         │
│  Assigns relevance scores per persona.          │
│  Returns cards sorted highest-score-first.      │
│  "Personalization changes priority, not         │
│   availability."                                │
└────────────────┬────────────────────────────────┘
                 │
                 │  Ranked WeatherResponse
                 ▼
            Flutter App
         (displays ranked cards)
```

---

## Project Structure

```
backend/
├── app/
│   ├── __init__.py
│   ├── main.py                        ← FastAPI app, CORS config
│   ├── models/
│   │   ├── __init__.py
│   │   └── weather.py                 ← WeatherCard, WeatherResponse models
│   ├── services/
│   │   ├── __init__.py
│   │   ├── weather_provider.py        ← WeatherProvider ABC + LocationQuery
│   │   ├── weather_service.py         ← DemoWeatherProvider (active)
│   │   ├── imd_weather_provider.py    ← IMDWeatherProvider stub (future)
│   │   ├── provider_factory.py        ← Provider selection via env var
│   │   └── ranking_service.py         ← Rule-based persona ranking
│   └── api/
│       ├── __init__.py
│       └── routes.py                  ← HTTP endpoints
├── requirements.txt
└── README.md                          ← You are here
```

---

## Prerequisites

- Python 3.10 or newer
  Check: `python --version`
- pip (comes with Python)
  Check: `pip --version`

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

> If you see a script execution policy error, run this first:
> `Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser`

### 3. Install dependencies

```powershell
pip install -r requirements.txt
```

### 4. Start the development server

```powershell
python -m uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

The server starts at: **http://localhost:8000**

No `.env` file is required — the application works out of the box with demo data.

---

## API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/health` | Liveness check |
| GET | `/weather?city=Hyderabad` | Full weather data (unranked) |
| GET | `/homepage?persona=farmer&city=Hyderabad` | Personalized ranked homepage |

The `source` field in every response identifies the active weather provider:

| Value | Meaning |
|-------|---------|
| `"demo"` | Hard-coded demo data (current) |
| `"IMD"` | Live IMD data (future, not yet implemented) |

### Quick test (PowerShell)

```powershell
# Health check
Invoke-RestMethod http://localhost:8000/health

# Weather data (unranked)
Invoke-RestMethod "http://localhost:8000/weather?city=Hyderabad"

# Personalized homepage
Invoke-RestMethod "http://localhost:8000/homepage?persona=farmer&city=Hyderabad"
Invoke-RestMethod "http://localhost:8000/homepage?persona=student&city=Hyderabad"
Invoke-RestMethod "http://localhost:8000/homepage?persona=traveller&city=Hyderabad"
```

### Interactive docs (Swagger UI)

Open in browser: **http://localhost:8000/docs**

---

## Provider Selection

The active weather provider is controlled by a single environment variable:

```
WEATHER_PROVIDER=demo    ← default (works with no .env file)
WEATHER_PROVIDER=imd     ← future IMD integration (not yet implemented)
```

**The application always defaults to `demo` when the variable is not set.**
No `.env` file is required to run locally.

### How to set the provider (PowerShell)

```powershell
# Set for current session only
$env:WEATHER_PROVIDER = "demo"

# Then start the server
python -m uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

### Where provider selection lives

`app/services/provider_factory.py` — one file, one place.
Adding a new provider requires only:
1. Create a new class implementing `WeatherProvider`.
2. Add it to the `_REGISTRY` dict in `provider_factory.py`.
3. Set `WEATHER_PROVIDER=<new_key>` in the environment.

Routes, ranking, and Flutter require zero changes.

---

## Demo Provider

**File:** `app/services/weather_service.py`
**Class:** `DemoWeatherProvider`

- Returns static demo weather data for Hyderabad.
- All demo values are defined in `_DEMO_DATA` — only in this file.
- Falls back to Hyderabad data for any unknown city.
- Sets `source = "demo"` on every response.

---

## Future IMD Provider

**File:** `app/services/imd_weather_provider.py`
**Class:** `IMDWeatherProvider`

Currently raises `NotImplementedError` on every call.

### Steps required to activate it

1. **Obtain official IMD API access** through the authorized channel
   (contact IMD / Ministry of Earth Sciences).

2. **Store credentials as environment variables — never in source code:**
   ```
   IMD_API_KEY=<your_key>
   IMD_API_BASE_URL=<official_endpoint>
   ```

3. **Review the official IMD API response schema** before writing any
   mapping code. Do not assume the schema — verify it from official docs.

4. **Implement `get_weather()`** in `imd_weather_provider.py` by:
   - Making an authenticated HTTP request to the IMD endpoint.
   - Mapping the IMD response fields to `WeatherCard` and `WeatherResponse`.
   - Setting `source = "IMD"` on the response.

5. **Add caching** between the route and the IMD call.
   Consult the official IMD API documentation for the recommended
   refresh interval / rate limits before choosing a cache TTL.

6. **Switch the provider:**
   ```
   WEATHER_PROVIDER=imd
   ```

7. **No other files need to change** — routes, ranking, and Flutter
   are fully isolated from the provider implementation.

---

## Supported Personas

| Persona key | Description |
|-------------|-------------|
| `farmer` | Rain, humidity, sunrise/sunset prioritized |
| `student` | Feels-like temperature, rain alerts |
| `traveller` | Visibility, wind, rain |
| `health` | Air quality, pollen, UV index |
| `commuter` | Rain, visibility, wind disruptions |
| `outdoor_worker` | UV index, heat, humidity |
| `senior` | Feels-like, air quality, pollen |
| `event_planner` | Rain, wind, visibility |

---

## Design Principles

- **"Personalization changes the priority, not the availability."**
  All weather cards are always returned. The ranking service only changes their order.

- **Weather data is isolated in the provider layer.**
  Demo values live in exactly one place (`weather_service.py`).
  Routes never know which provider is active.

- **Ranking is always separate from weather fetching.**
  `RankingService` receives cards from whichever provider is active and
  scores them — it is never modified when providers change.

- **Location is extensible.**
  `LocationQuery` accepts an optional `latitude` and `longitude` alongside
  the city name. Providers can use coordinates once GPS-to-weather wiring
  is complete in the Flutter app — no interface change required.

---

## What is NOT Included Yet (Planned for Future Steps)

| Feature | Status |
|---------|--------|
| Live IMD API integration | Stub only — awaiting authorization |
| GPS coordinates → weather lookup | LocationQuery ready; provider not yet wired |
| Caching layer | TODO marked in routes.py and provider_factory.py |
| Database / user profile storage | Not started |
| Authentication / user accounts | Not started |
| Firebase push notifications | Not started |
| Machine learning–based ranking | Not started |
