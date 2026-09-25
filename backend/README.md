# Mausam Backend

**SIH 2026 — Project SIH26076**
_Development of Personalized Homepage for 'Mausam' Mobile Application_

This is the Python FastAPI backend that powers the personalized weather homepage.

---

## Project structure

```
backend/
├── app/
│   ├── __init__.py
│   ├── main.py               ← FastAPI app, CORS config
│   ├── models/
│   │   ├── __init__.py
│   │   └── weather.py        ← WeatherCard & WeatherResponse models
│   ├── services/
│   │   ├── __init__.py
│   │   ├── weather_service.py  ← DemoWeatherService (swap for IMD later)
│   │   └── ranking_service.py  ← Rule-based persona ranking
│   └── api/
│       ├── __init__.py
│       └── routes.py         ← All HTTP endpoints
├── requirements.txt
└── README.md                 ← You are here
```

---

## Prerequisites

- Python 3.10 or newer
  Check: `python --version`
- pip (comes with Python)
  Check: `pip --version`

---

## Setup and run (Windows — PowerShell)

### 1. Open a terminal and navigate to the backend folder

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
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

The server starts at: **http://localhost:8000**

---

## API endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/health` | Liveness check |
| GET | `/weather?city=Hyderabad` | Full weather data (unranked) |
| GET | `/homepage?persona=farmer&city=Hyderabad` | Personalized ranked homepage |

### Quick test (PowerShell)

```powershell
# Health check
Invoke-RestMethod http://localhost:8000/health

# Weather data
Invoke-RestMethod "http://localhost:8000/weather?city=Hyderabad"

# Personalized homepage
Invoke-RestMethod "http://localhost:8000/homepage?persona=farmer&city=Hyderabad"
```

### Interactive docs (Swagger UI)

Open in browser: **http://localhost:8000/docs**

---

## Supported personas

| Persona | Primary focus |
|---------|---------------|
| `farmer` | Rain, humidity, sunrise/sunset |
| `student` | Feels-like temperature, rain alerts |
| `traveller` | Visibility, wind, rain |
| `health` | Air quality, pollen, UV index |
| `commuter` | Rain, visibility, wind |
| `outdoor_worker` | UV index, heat, humidity |
| `senior` | Feels-like, air quality, pollen |
| `event_planner` | Rain, wind, visibility |

---

## Design principles

- **"Personalization changes the priority, not the availability."**
  All weather cards are always returned. The ranking service only changes their order.
- **Weather data is isolated in `weather_service.py`.**
  Demo values live in exactly one place. To add a real IMD API, create a new class
  implementing the same `get_weather(city)` interface and swap the import in `routes.py`.
- **Ranking logic is isolated in `ranking_service.py`.**
  Weights are transparent and hand-crafted (no machine learning in this MVP).

---

## What is NOT included yet (planned for future steps)

- IMD / real weather API integration
- Database / user profile storage
- Authentication / user accounts
- Firebase push notifications
- Machine learning–based ranking
