# Architectural & Design Decisions

This document records the architectural decisions, trade-offs, and assumptions made in ScrollGuard.

---

## 1. Golden Principle: "Native Decides, Flutter Displays"
- **Decision:** All feed detection, swipe counting, session management, doomscroll scoring, and penalty enforcement (overlays, back/home navigation) execute completely inside the Android native process (`AccessibilityService`, `Room`, `DataStore`).
- **Rationale:** If the Flutter engine is killed or in the background, limits must still strictly apply. Flutter serves as the user-facing dashboard, configuration UI, sync coordinator, and payment interface.

## 2. Mandatory Guarded Apps for v1
- **YouTube Shorts:** Package `com.google.android.youtube`.
- **Instagram Reels:** Package `com.instagram.android`.
- **TikTok:** Package `com.zhiliaoapp.musically` and `com.ss.android.ugc.trill`.
- **Decision:** Prioritize high-precision detection for YouTube Shorts and Instagram Reels using view IDs, with TikTok treated as whole-app feed.

## 3. Enforcement Scope & Confidence Levels
- **Decision:** When detection confidence is high and feed containers are identified (YouTube Shorts, Instagram Reels), penalties block the feed specifically (overlay banner + `GLOBAL_ACTION_BACK`). If the user repeatedly navigates back into the feed or for whole-app feeds (TikTok), the system triggers `GLOBAL_ACTION_HOME`.

## 4. Logical Day Boundary & Reset Hour
- **Decision:** Daily budgets and stats calculate on a logical day starting at 04:00 local time by default. Late-night scrolling (e.g., 01:00) counts toward the previous day's budget to discourage doomscrolling before sleep.

## 5. Flavor Strategy
- **`play` flavor:** Designed for Google Play compliance with prominent in-app disclosure and standard policy constraints.
- **`direct` flavor:** Standalone APK build allowing sideload distribution if store policies shift.

## 6. Real-Money Penalties & Commitment Contracts
- **Decision:** Kept behind a hard feature flag (`contract_enabled = false`). Real charges are executed purely by backend Supabase Edge Functions with idempotency and daily/weekly/monthly spending caps.

## 7. Strict Mode & Friction Design (Phase 8)
- **Opt-in Delayed Disable:** Users can optionally enable "Strict Mode". When active, attempting to disable or pause ScrollGuard initiates a mandatory 10-minute cooling-off countdown timer. The user cannot immediately turn off protection during an urge.
- **Accountability Notification Stub:** Disabling the service or initiating a strict-mode cancellation dispatches a `guard_event` (tamper/pause) and queues a notification to the configured accountability partner (or push notification reminder).
- **No Device Admin in v1:** Device Admin permissions are deliberately omitted to ensure 100% compliance with Google Play Store policies. Strict Mode operates via high-friction UI timers and audit trails rather than system-level uninstallation locks.

## 8. Sync Pipeline Strategy
- **Decision:** Dual-trigger sync pipeline:
  1. Instant opportunistic sync on Flutter app launch or resume (`WidgetsBindingObserver`).
  2. Scheduled periodic background sync via Android WorkManager (`SyncWorker`) at 12-hour intervals when unmetered network is available.
- **Rationale:** Minimizes battery drain and unnecessary wakeups while ensuring daily statistics and penalty events reliably reach the Supabase backend.

