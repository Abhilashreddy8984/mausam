"""
Geocoding Service
=================
Resolves city and destination names to geographic coordinates (latitude, longitude)
with high reliability and in-memory TTL caching.
"""

import logging
import time
from typing import Dict, List, Optional, Tuple

import requests
from app.config.settings import HTTP_TIMEOUT_SECONDS
from app.models.travel_advisory import LocationSearchResult

logger = logging.getLogger(__name__)

# Cache entry: (timestamp, List[LocationSearchResult])
_CACHE: Dict[str, Tuple[float, List[LocationSearchResult]]] = {}
_CACHE_TTL_SECONDS = 3600  # 1 hour

# Verified static dictionary of Indian cities, capitals, and popular travel destinations
_KNOWN_INDIAN_DESTINATIONS: Dict[str, Tuple[float, float, str, str, str]] = {
    "hyderabad": (17.3850, 78.4867, "Hyderabad", "Telangana", "India"),
    "secunderabad": (17.4399, 78.4983, "Secunderabad", "Telangana", "India"),
    "warangal": (17.9689, 79.5941, "Warangal", "Telangana", "India"),
    "nizamabad": (18.6725, 78.0941, "Nizamabad", "Telangana", "India"),
    "karimnagar": (18.4386, 79.1288, "Karimnagar", "Telangana", "India"),
    "mumbai": (19.0760, 72.8777, "Mumbai", "Maharashtra", "India"),
    "pune": (18.5204, 73.8567, "Pune", "Maharashtra", "India"),
    "nagpur": (21.1458, 79.0882, "Nagpur", "Maharashtra", "India"),
    "nashik": (19.9975, 73.7898, "Nashik", "Maharashtra", "India"),
    "delhi": (28.6139, 77.2090, "Delhi", "Delhi", "India"),
    "new delhi": (28.6139, 77.2090, "New Delhi", "Delhi", "India"),
    "noida": (28.5355, 77.3910, "Noida", "Uttar Pradesh", "India"),
    "gurugram": (28.4595, 77.0266, "Gurugram", "Haryana", "India"),
    "gurgaon": (28.4595, 77.0266, "Gurugram", "Haryana", "India"),
    "bengaluru": (12.9716, 77.5946, "Bengaluru", "Karnataka", "India"),
    "bangalore": (12.9716, 77.5946, "Bengaluru", "Karnataka", "India"),
    "mysuru": (12.2958, 76.6394, "Mysuru", "Karnataka", "India"),
    "mysore": (12.2958, 76.6394, "Mysuru", "Karnataka", "India"),
    "mangalore": (12.9141, 74.8560, "Mangalore", "Karnataka", "India"),
    "hubballi": (15.3647, 75.1240, "Hubballi", "Karnataka", "India"),
    "chennai": (13.0827, 80.2707, "Chennai", "Tamil Nadu", "India"),
    "coimbatore": (11.0168, 76.9558, "Coimbatore", "Tamil Nadu", "India"),
    "madurai": (9.9252, 78.1198, "Madurai", "Tamil Nadu", "India"),
    "ooty": (11.4102, 76.6950, "Ooty", "Tamil Nadu", "India"),
    "kolkata": (22.5726, 88.3639, "Kolkata", "West Bengal", "India"),
    "darjeeling": (27.0410, 88.2663, "Darjeeling", "West Bengal", "India"),
    "siliguri": (26.7271, 88.3953, "Siliguri", "West Bengal", "India"),
    "jaipur": (26.9124, 75.7873, "Jaipur", "Rajasthan", "India"),
    "udaipur": (24.5854, 73.7125, "Udaipur", "Rajasthan", "India"),
    "jodhpur": (26.2389, 73.0243, "Jodhpur", "Rajasthan", "India"),
    "jaisalmer": (26.9157, 70.9083, "Jaisalmer", "Rajasthan", "India"),
    "shimla": (31.1048, 77.1734, "Shimla", "Himachal Pradesh", "India"),
    "manali": (32.2396, 77.1887, "Manali", "Himachal Pradesh", "India"),
    "dharamshala": (32.2190, 76.3234, "Dharamshala", "Himachal Pradesh", "India"),
    "kullu": (31.9579, 77.1095, "Kullu", "Himachal Pradesh", "India"),
    "srinagar": (34.0837, 74.7973, "Srinagar", "Jammu and Kashmir", "India"),
    "jammu": (32.7266, 74.8570, "Jammu", "Jammu and Kashmir", "India"),
    "gulmarg": (34.0484, 74.3805, "Gulmarg", "Jammu and Kashmir", "India"),
    "leh": (34.1526, 77.5771, "Leh", "Ladakh", "India"),
    "dehradun": (30.3165, 78.0322, "Dehradun", "Uttarakhand", "India"),
    "rishikesh": (30.0869, 78.2676, "Rishikesh", "Uttarakhand", "India"),
    "haridwar": (29.9457, 78.1642, "Haridwar", "Uttarakhand", "India"),
    "nainital": (29.3919, 79.4542, "Nainital", "Uttarakhand", "India"),
    "mussoorie": (30.4598, 78.0644, "Mussoorie", "Uttarakhand", "India"),
    "goa": (15.2993, 74.1240, "Goa", "Goa", "India"),
    "panaji": (15.4909, 73.8278, "Panaji", "Goa", "India"),
    "ahmedabad": (23.0225, 72.5714, "Ahmedabad", "Gujarat", "India"),
    "surat": (21.1702, 72.8311, "Surat", "Gujarat", "India"),
    "vadodara": (22.3072, 73.1812, "Vadodara", "Gujarat", "India"),
    "lucknow": (26.8467, 80.9462, "Lucknow", "Uttar Pradesh", "India"),
    "varanasi": (25.3176, 82.9739, "Varanasi", "Uttar Pradesh", "India"),
    "agra": (27.1767, 78.0081, "Agra", "Uttar Pradesh", "India"),
    "kanpur": (26.4499, 80.3319, "Kanpur", "Uttar Pradesh", "India"),
    "prayagraj": (25.4358, 81.8463, "Prayagraj", "Uttar Pradesh", "India"),
    "patna": (25.5941, 85.1376, "Patna", "Bihar", "India"),
    "gaya": (24.7914, 85.0002, "Gaya", "Bihar", "India"),
    "bhopal": (23.2599, 77.4126, "Bhopal", "Madhya Pradesh", "India"),
    "indore": (22.7196, 75.8577, "Indore", "Madhya Pradesh", "India"),
    "gwalior": (26.2183, 78.1828, "Gwalior", "Madhya Pradesh", "India"),
    "chandigarh": (30.7333, 76.7794, "Chandigarh", "Chandigarh", "India"),
    "amritsar": (31.6340, 74.8723, "Amritsar", "Punjab", "India"),
    "ludhiana": (30.9010, 75.8573, "Ludhiana", "Punjab", "India"),
    "kochi": (9.9312, 76.2673, "Kochi", "Kerala", "India"),
    "thiruvananthapuram": (8.5241, 76.9366, "Thiruvananthapuram", "Kerala", "India"),
    "munnar": (10.0889, 77.0595, "Munnar", "Kerala", "India"),
    "kozhikode": (11.2588, 75.7804, "Kozhikode", "Kerala", "India"),
    "visakhapatnam": (17.6868, 83.2185, "Visakhapatnam", "Andhra Pradesh", "India"),
    "vizag": (17.6868, 83.2185, "Visakhapatnam", "Andhra Pradesh", "India"),
    "vijayawada": (16.5062, 80.6480, "Vijayawada", "Andhra Pradesh", "India"),
    "tirupati": (13.6288, 79.4192, "Tirupati", "Andhra Pradesh", "India"),
    "bhubaneswar": (20.2961, 85.8245, "Bhubaneswar", "Odisha", "India"),
    "puri": (19.8135, 85.8312, "Puri", "Odisha", "India"),
    "guwahati": (26.1445, 91.7362, "Guwahati", "Assam", "India"),
    "shillong": (25.5788, 91.8933, "Shillong", "Meghalaya", "India"),
    "gangtok": (27.3389, 88.6065, "Gangtok", "Sikkim", "India"),
    "ranchi": (23.3441, 85.3096, "Ranchi", "Jharkhand", "India"),
    "raipur": (21.2514, 81.6296, "Raipur", "Chhattisgarh", "India"),
}


class GeocodingService:
    """Service to geocode place names and return search results."""

    @classmethod
    def search(cls, query: str, limit: int = 5) -> List[LocationSearchResult]:
        """
        Search for places matching the query string.
        Returns a list of LocationSearchResult objects.
        """
        q = query.strip().lower()
        if not q or len(q) < 2:
            return []

        # Check cache
        cache_key = f"search:{q}:{limit}"
        if cache_key in _CACHE:
            ts, cached_results = _CACHE[cache_key]
            if time.time() - ts < _CACHE_TTL_SECONDS:
                return cached_results

        results: List[LocationSearchResult] = []

        # 1. Check known Indian destinations for prefix/substring matches
        for key, (lat, lon, city, state, country) in _KNOWN_INDIAN_DESTINATIONS.items():
            if q in key or key in q:
                disp = f"{city}, {state}, {country}"
                results.append(
                    LocationSearchResult(
                        name=city,
                        state=state,
                        country=country,
                        latitude=lat,
                        longitude=lon,
                        display_name=disp,
                    )
                )
                if len(results) >= limit:
                    break

        # 2. If static matches are fewer than limit, consult Open-Meteo Geocoding API
        if len(results) < limit:
            try:
                resp = requests.get(
                    "https://geocoding-api.open-meteo.com/v1/search",
                    params={
                        "name": query.strip(),
                        "count": str(limit),
                        "language": "en",
                        "format": "json",
                    },
                    headers={"Accept": "application/json"},
                    timeout=HTTP_TIMEOUT_SECONDS,
                )
                if resp.ok:
                    data = resp.json()
                    items = data.get("results") or []
                    for item in items:
                        name = item.get("name") or query
                        state = item.get("admin1") or ""
                        country = item.get("country") or ""
                        lat = float(item["latitude"])
                        lon = float(item["longitude"])
                        disp_parts = [name]
                        if state:
                            disp_parts.append(state)
                        if country:
                            disp_parts.append(country)
                        disp = ", ".join(disp_parts)

                        # Avoid duplicates
                        if not any(abs(r.latitude - lat) < 0.05 and abs(r.longitude - lon) < 0.05 for r in results):
                            results.append(
                                LocationSearchResult(
                                    name=name,
                                    state=state or None,
                                    country=country or None,
                                    latitude=lat,
                                    longitude=lon,
                                    display_name=disp,
                                )
                            )
                            if len(results) >= limit:
                                break
            except Exception as e:
                logger.warning("Open-Meteo geocoding search failed: %s", e)

        # Cache results
        _CACHE[cache_key] = (time.time(), results)
        return results

    @classmethod
    def geocode(cls, query: str) -> Optional[LocationSearchResult]:
        """
        Resolves a single location name to its best-match coordinates.
        Returns None if the location cannot be resolved.
        """
        q = query.strip().lower()
        if not q:
            return None

        # Check known Indian destinations first
        if q in _KNOWN_INDIAN_DESTINATIONS:
            lat, lon, city, state, country = _KNOWN_INDIAN_DESTINATIONS[q]
            return LocationSearchResult(
                name=city,
                state=state,
                country=country,
                latitude=lat,
                longitude=lon,
                display_name=f"{city}, {state}, {country}",
            )

        # Try search
        matches = cls.search(query, limit=1)
        if matches:
            return matches[0]

        return None
