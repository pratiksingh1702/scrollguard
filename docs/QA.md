# Quality Assurance & Testing Matrix

This document defines the comprehensive QA test matrix, device profiles, and step-by-step verification procedures for ScrollGuard across Android OS versions (8.0 to 15) and major OEM skins.

---

## 1. Operating System & Device Matrix

| OS Version | API Level | Reference Device | OEM Skin / Customization | Verification Scope |
|---|---|---|---|---|
| **Android 8.0 / 8.1** | 26 / 27 | Nexus 5X / Moto G5 | Stock Android / AOSP | Min SDK verification, Room SQLite migrations, baseline accessibility bindings. |
| **Android 10** | 29 | Samsung Galaxy S10 | Samsung One UI 2.5 | Scoped storage baseline, legacy package visibility. |
| **Android 11** | 30 | Pixel 4a / OnePlus 8 | OxygenOS 11 | `<queries>` package visibility verification for guarded apps. |
| **Android 12** | 31 / 32 | Samsung Galaxy S21 | Samsung One UI 4.1 | Splash screen API, dynamic color / Material You rendering. |
| **Android 13** | 33 | Xiaomi 12 / Poco F4 | MIUI 14 / HyperOS | `POST_NOTIFICATIONS` runtime permission request; battery saver autostart permissions. |
| **Android 14** | 34 | Pixel 7 / Samsung S23 | One UI 6.0 | Predictive back navigation callbacks; foreground service restrictions; 1 Hz throttled streams. |
| **Android 15** | 35 | Pixel 9 Pro | Stock Android 15 | 16 KB memory page size alignment; edge-to-edge system bar enforcement; Private Space compatibility. |
| **OEM: Oppo/Realme** | 33 / 34 | Realme GT 2 | ColorOS 13 / 14 | Deep sleeping apps exemption; autostart toggle; floating overlay permissions. |
| **OEM: Vivo/iQOO** | 33 / 34 | Vivo V27 | FuntouchOS 13 / 14 | Background high power consumption whitelist; Speed Up exclusion. |
| **OEM: Huawei** | 30 / 31 | Huawei P40 | EMUI 12 / HarmonyOS | MicroG / GMS fallback; manual startup management. |

---

## 2. Test Execution Suites & Coverage Targets

| Test Suite | Execution Command | Target Coverage | Current Status |
|---|---|---|---|
| **Flutter Unit Tests** | `flutter test test/core/` | ≥ 90% | **PASS (100%)** |
| **Flutter Widget Tests** | `flutter test test/features/` | ≥ 80% | **PASS (100%)** |
| **Kotlin Unit Tests** | `./gradlew testPlayDebugUnitTest` | ≥ 85% | **PASS (100%)** |
| **Flutter Code Analysis** | `flutter analyze` | 0 issues | **PASS (0 issues)** |
| **Pigeon IPC Integrity** | `tool/gen_pigeon.sh` | Clean build | **PASS** |

---

## 3. Manual Device QA Test Protocols

### TC-01: Onboarding & Prominent Disclosure
- **Step 1:** Fresh install app; launch without permissions.
- **Expected:** Welcome screen appears. Stepping to Step 2 displays the exact Accessibility prominent disclosure.
- **Step 2:** Tap "Decline".
- **Expected:** Informational dialog explains why accessibility is needed; no system settings opened.
- **Step 3:** Tap "Agree".
- **Expected:** Opens Accessibility settings directly to ScrollGuard toggle.

### TC-02: Live Permission Checklist Synchronization
- **Step 1:** Navigate to `/permissions` screen.
- **Step 2:** Toggle Accessibility ON in Android Settings, then return to ScrollGuard.
- **Expected:** Accessibility item instantly turns green with a checkmark without needing an app restart.
- **Step 3:** Tap OEM Guide button.
- **Expected:** Modal bottom sheet shows device-specific autostart and battery optimization steps.

### TC-03: Feed Detection & Negative Testing
- **Step 1:** Open YouTube app -> Home feed -> Tap a standard 10-minute landscape video.
- **Expected:** Live state remains `inFeed = false`. No interventions triggered.
- **Step 2:** Tap the "Shorts" tab.
- **Expected:** Live state immediately transitions to `inFeed = true`, displaying active swipe count and session timer in Dashboard.
- **Step 3:** Open Instagram -> Direct Messages -> Profile Grid.
- **Expected:** `inFeed = false`.
- **Step 4:** Open Instagram Reels tab.
- **Expected:** `inFeed = true`.

### TC-04: Enforcement Ladder & Overlay Flow
- **Step 1:** Configure a 1-minute budget for YouTube Shorts.
- **Step 2:** Scroll in Shorts for 30 seconds (50% budget).
- **Expected:** Non-blocking L0 Nudge banner appears for 3 seconds and dismisses.
- **Step 3:** Scroll past 48 seconds (80% budget).
- **Expected:** L1 Friction overlay appears with a mandatory 10-second countdown before dismissal.
- **Step 4:** Scroll past 60 seconds (100% budget).
- **Expected:** L2 Lockout overlay displays "Daily Budget Reached". Tapping back or waiting triggers `GLOBAL_ACTION_BACK`.

### TC-05: Emergency Unlock & Daily Limits
- **Step 1:** When locked out, tap "Emergency Unlock".
- **Step 2:** Enter reason `< 10` characters.
- **Expected:** Form validation blocks unlock.
- **Step 3:** Enter valid reason (≥ 10 characters) and submit.
- **Expected:** Lockout lifts for 5 minutes; unlock count increments by 1; penalty event logged.
- **Step 4:** Exhaust maximum unlocks (e.g. 2/2). Subsequent requests are disabled.

### TC-06: Anti-Tamper & Watchdog Verification
- **Step 1:** With ScrollGuard active, navigate to System Settings -> Apps -> Accessibility -> Toggle ScrollGuard OFF.
- **Step 2:** Wait up to 15 minutes (or trigger `WatchdogWorker` via adb).
- **Expected:** High-priority notification alerts: *"Protection is inactive. Tap to restore protection."*
- **Step 3:** Change device system clock backward by 2 hours.
- **Expected:** Watchdog records `guard_event` with `event_type = 'clock_tampered'` and notifies server during next sync.

### TC-07: 24-Hour Idle Survival & Battery Benchmark
- **Step 1:** Leave device on battery overnight (24 hours) with guarded apps installed.
- **Step 2:** Inspect Android Battery Historian / Battery Settings.
- **Expected:** ScrollGuard accounts for `< 1.0%` of daily battery consumption. Watchdog worker executes reliably without crashing.
