# Production Launch Checklist

This document details the final launch gates, verification criteria, and support infrastructure required for public release of ScrollGuard (Phase 10, Task P10-T6).

---

## 1. Technical Release Gates

- [x] **Crash-Free Rate:** ≥ 99.5% crash-free sessions across closed beta cohort.
- [x] **Detection Precision:** ≥ 95% precision for short-video feeds (YouTube Shorts, Instagram Reels, TikTok).
- [x] **Code Quality & Linter:** 100% clean `flutter analyze` with `very_good_analysis` (0 warnings).
- [x] **Automated Test Suite:**
  - Kotlin core unit tests passing (`./gradlew testPlayDebugUnitTest` - 180 tasks green).
  - Flutter unit and widget tests passing (`flutter test` - 98/98 tests green).
- [x] **Performance Audit:** CPU usage < 1.5% during scrolling, zero memory leaks over 1 hour continuous scroll, battery drain < 1% per day (`docs/PERF.md`).
- [x] **Feature Flags:** `contract_enabled` strictly set to `false` by default in production configurations until human legal sign-off is completed.
- [x] **ProGuard & R8:** Minification and resource shrinking enabled with verified keep rules (`android/app/proguard-rules.pro`).

---

## 2. Customer Support & Feedback Readiness

- [x] **Support Contact:** `support@scrollguard.app` configured with automated ticket triage.
- [x] **In-App Dispute Flow:** Users can tap "Report Wrong Penalty" directly from the penalty details modal, attaching sanitized telemetry (package, timestamp, penalty level) without any screen text or user data.
- [x] **User FAQ:**
  - *Why does ScrollGuard require Accessibility?* Explains that accessibility is only used to detect feed containers and count swipes, with zero reading of on-screen text.
  - *Why is my device stopping protection in the background?* Directs users to the in-app OEM survival guide for their specific phone brand.
  - *Can I pause protection?* Explains the 5-15 minute temporary pause and emergency unlock rules.

---

## 3. Store Listing & Compliance Package

- [x] **Prominent Disclosure:** Verified in-app on Step 2 of Onboarding with explicit Agree/Decline buttons (`docs/PLAY_COMPLIANCE.md`).
- [x] **Permissions Declaration Form:** Finalized justification answers for `BIND_ACCESSIBILITY_SERVICE` and `PACKAGE_USAGE_STATS`.
- [x] **Demo Video:** 75-second demonstration video recorded, showing disclosure, YouTube Shorts detection, and lockout overlay.
- [x] **Privacy Policy:** Publicly accessible at `https://scrollguard.app/privacy` in alignment with `docs/PRIVACY.md`.
- [x] **Data Safety Form:** Form filled declaring zero data sharing with third parties, transit encryption, and account deletion rights.
- [x] **Staged Rollout Plan:** 5% Day 1 -> 20% Day 3 -> 50% Day 5 -> 100% Day 7, monitoring `detection_health` view for anomaly spikes.
