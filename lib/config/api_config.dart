// ============================================================
// config/api_config.dart
//
// Single source of truth for the backend API base URL.
//
// ┌─────────────────────────────────────────────────────────┐
// │  HOW TO CONFIGURE FOR YOUR RUN TARGET                   │
// │                                                         │
// │  Android Emulator (default):                            │
// │    Use http://10.0.2.2:8000                             │
// │    The emulator maps 10.0.2.2 → your PC's localhost.    │
// │                                                         │
// │  Android Physical Device:                               │
// │    Your PC and phone must be on the same Wi-Fi network. │
// │    Find your PC's local IPv4 address:                   │
// │      Windows PowerShell: (Get-NetIPAddress -AddressFamily IPv4 │
// │        -InterfaceAlias Wi-Fi).IPAddress                 │
// │    Then set:                                            │
// │      const _kBaseUrl = 'http://192.168.X.X:8000';       │
// │    Replace 192.168.X.X with your actual PC IP.          │
// │                                                         │
// │  Chrome / Flutter Web:                                  │
// │    const _kBaseUrl = 'http://localhost:8000';           │
// │                                                         │
// │  ⚠  Change ONLY the _kBaseUrl constant below.          │
// │     Nothing else in the codebase needs to change.       │
// └─────────────────────────────────────────────────────────┘
// ============================================================

// ── CHANGE THIS LINE to match your run target ───────────────
const String _kBaseUrl = 'http://10.29.142.190:8000';
// ────────────────────────────────────────────────────────────

/// The FastAPI backend base URL.
///
/// Consumed exclusively by [ApiService].
/// Do not import or use this constant anywhere else.
const String kApiBaseUrl = _kBaseUrl;

/// How long to wait for a backend response before giving up.
/// Keep this short so the UI falls back to demo data quickly
/// rather than making the user wait on a stalled request.
const Duration kApiTimeout = Duration(seconds: 8);
