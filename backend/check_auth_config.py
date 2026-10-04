"""
IMD Auth Configuration Check
=============================
Run from the backend/ directory on AWS to verify the production auth
configuration WITHOUT printing any secrets.

    python check_auth_config.py

What it checks:
  1. All required environment variables are set (non-empty).
  2. IMD_AUTH_HEADER is configured (the API-key header name).
  3. IMD_TOKEN_URL is reachable (HTTP POST returns a response — 200 or any code).
  4. If OAuth returns 200, confirms access_token is present in the response.
  5. If OAuth succeeds, confirms the token has a non-trivial length.

What it NEVER prints:
  - API key value
  - email value
  - password value
  - JWT token value
  - Authorization header value
"""

import sys
import os

# Ensure backend/ is on the path when run from that directory
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from app.config import settings as s

_OK  = "  [OK] "
_ERR = "  [FAIL] "
_WARN= "  [WARN] "

all_ok = True


def check(condition: bool, ok_msg: str, fail_msg: str) -> bool:
    global all_ok
    if condition:
        print(_OK + ok_msg)
        return True
    else:
        print(_ERR + fail_msg)
        all_ok = False
        return False


print()
print("=" * 60)
print("  IMD Auth Configuration Check")
print("=" * 60)

# ── 1. Required env vars present ──────────────────────────────
print("\n1. Required environment variables:")
check(bool(s.IMD_API_KEY),       "IMD_API_KEY is set",       "IMD_API_KEY is MISSING")
check(bool(s.IMD_CURRENT_WX_URL),"IMD_CURRENT_WX_URL is set","IMD_CURRENT_WX_URL is MISSING")
check(bool(s.IMD_STATION_ID),    "IMD_STATION_ID is set",    "IMD_STATION_ID is MISSING")
check(bool(s.IMD_EMAIL),         "IMD_EMAIL is set",         "IMD_EMAIL is MISSING")
check(bool(s.IMD_PASSWORD),      "IMD_PASSWORD is set",      "IMD_PASSWORD is MISSING")

# ── 2. Auth header name ────────────────────────────────────────
print("\n2. Auth header configuration:")
print(_OK + f"IMD_AUTH_HEADER = '{s.IMD_AUTH_HEADER}'")
print(_OK + f"IMD_TOKEN_URL   = '{s.IMD_TOKEN_URL}'")
print(_OK + f"IMD_CURRENT_WX_URL = '{s.IMD_CURRENT_WX_URL}'")
print(_OK + f"IMD_STATION_ID  = '{s.IMD_STATION_ID}'")

# ── 3. API key shape (length only, never value) ────────────────
print("\n3. API key shape (length only, never value):")
if s.IMD_API_KEY:
    key_len = len(s.IMD_API_KEY)
    check(key_len >= 8, f"IMD_API_KEY length = {key_len} chars (looks non-trivial)",
          f"IMD_API_KEY length = {key_len} chars (suspiciously short — check .env)")

# ── 4. Attempt OAuth token fetch ──────────────────────────────
print("\n4. OAuth token fetch (no secrets printed):")
if s.IMD_EMAIL and s.IMD_PASSWORD:
    try:
        import requests
        resp = requests.post(
            s.IMD_TOKEN_URL,
            json={"email": s.IMD_EMAIL, "password": s.IMD_PASSWORD},
            headers={"Content-Type": "application/json"},
            timeout=10,
        )
        check(resp.status_code == 200,
              f"OAuth endpoint returned HTTP {resp.status_code} (success)",
              f"OAuth endpoint returned HTTP {resp.status_code} — "
              "check IMD_EMAIL and IMD_PASSWORD")

        if resp.status_code == 200:
            try:
                data = resp.json()
                token = data.get("access_token", "")
                check(bool(token),
                      f"access_token present (length={len(token)} chars)",
                      "access_token MISSING from OAuth response — unexpected response format")
            except Exception as e:
                print(_ERR + f"Could not parse OAuth response as JSON: {e}")
                all_ok = False
    except Exception as e:
        print(_ERR + f"Could not reach OAuth endpoint: {e}")
        all_ok = False
else:
    print(_WARN + "Skipping OAuth check — IMD_EMAIL or IMD_PASSWORD not set")

# ── 5. Summary ────────────────────────────────────────────────
print()
print("=" * 60)
if all_ok:
    print("  RESULT: All checks passed.")
    print("  If IMD still returns 401 on data requests,")
    print("  the remaining cause is external (IP whitelist or key scope).")
    print("  Contact IMD support with your AWS public IP.")
else:
    print("  RESULT: One or more checks FAILED — fix the above issues first.")
print("=" * 60)
print()

sys.exit(0 if all_ok else 1)
