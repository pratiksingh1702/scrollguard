# Quality Assurance & Testing Matrix

This document provides testing guidelines, device matrices, and verification checklists for ScrollGuard.

---

## 1. Operating System & Device Matrix

| Android Version | API Level | Target OEM Devices | Verification Focus |
|---|---|---|---|
| Android 8.0 / 8.1 | 26 / 27 | Baseline Android | Minimum SDK support, Room compatibility |
| Android 10 / 11 | 29 / 30 | Samsung Galaxy S10 / Pixel 3a | Package visibility queries, overlay rendering |
| Android 12 / 13 | 31 / 33 | Pixel 6, Samsung Galaxy S22 | Notification permission runtime request, node recycling |
| Android 14 / 15 | 34 / 35 | Pixel 8 / 9, Xiaomi 13 | Predictive back navigation, 16KB page alignment |

---

## 2. Automated Test Verification
1. **Flutter Analysis:** `flutter analyze` with `very_good_analysis` must produce zero warnings.
2. **Flutter Unit & Widget Tests:** `flutter test --coverage` covering all domain models, state providers, and router redirects.
3. **Android JVM Unit Tests:** `./gradlew testPlayDebugUnitTest` testing `SessionTracker`, `SwipeCounter`, `ScoreEngine`, and `PenaltyEngine`.
4. **Trace Replay Tests:** Deterministic event fixtures simulating scroll bursts and long-form video browsing.

---

## 3. Manual Functional Checklist
- [ ] Onboarding disclosure displayed with Agree / Decline buttons.
- [ ] Settings deep links navigate directly to Accessibility and Usage Access.
- [ ] Service activation triggers green status chip in Dashboard.
- [ ] Opening YouTube Shorts displays real-time swipe count in live state card.
- [ ] Reaching 50% budget displays non-intrusive Nudge overlay.
- [ ] Reaching 80% budget displays Friction overlay with 10s countdown.
- [ ] Reaching 100% budget blocks feed and triggers back navigation.
- [ ] Emergency unlock requires minimum 10-character reason entry.
- [ ] Disabling accessibility service triggers watchdog notification within 15 minutes.
