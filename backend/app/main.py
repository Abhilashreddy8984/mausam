"""
Mausam Backend — FastAPI Application Entry Point
=================================================
Starts the FastAPI application, configures CORS so the Flutter app
can communicate during development, and registers all API routes.
"""

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.api.routes import router

# --------------------------------------------------------------------------- #
# Application instance                                                         #
# --------------------------------------------------------------------------- #
app = FastAPI(
    title="Mausam Personalized Backend",
    description=(
        "Backend API for the SIH 2026 project SIH26076 — "
        "'Development of Personalized Homepage for Mausam Mobile Application'. "
        "Provides rule-based personalized weather card ranking for multiple user personas."
    ),
    version="0.1.0",
    contact={
        "name": "SIH 2026 Team",
    },
)

# --------------------------------------------------------------------------- #
# CORS — allow the Flutter app (and Swagger UI) to call the API               #
# during local development.                                                    #
#                                                                              #
# origins="*" is intentionally broad for the MVP / development phase.         #
# Restrict to specific origins before any production deployment.              #
# --------------------------------------------------------------------------- #
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],          # Flutter web + emulator + Swagger UI
    allow_credentials=False,      # must be False when allow_origins=["*"]
    allow_methods=["GET"],        # read-only API for now
    allow_headers=["*"],
)

# --------------------------------------------------------------------------- #
# Register routes                                                              #
# --------------------------------------------------------------------------- #
app.include_router(router)


# --------------------------------------------------------------------------- #
# Root redirect — convenience for browser visits to http://localhost:8000/    #
# --------------------------------------------------------------------------- #
@app.get("/", include_in_schema=False)
def root():
    return {
        "message": "Mausam Backend is running.",
        "docs": "http://localhost:8000/docs",
        "health": "http://localhost:8000/health",
    }
