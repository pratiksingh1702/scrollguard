# Closed Beta Testing Program Plan

This document defines the structure, cohort recruitment, KPI tracking, and operational guidelines for the ScrollGuard Closed Beta Program (Phase 10, Task P10-T5).

---

## 1. Program Objectives & Scope

The closed beta aims to validate real-world reliability, battery consumption, OEM survival, and detection precision across diverse Android devices before the public Google Play launch.

- **Cohort Size:** 20–50 active testers.
- **Duration:** 2–4 weeks.
- **Distribution Track:** Google Play Console Closed Testing track.
- **Hardware Coverage:** At least 3 devices each from Google Pixel, Samsung (One UI), Xiaomi (MIUI/HyperOS), OnePlus/Oppo (ColorOS), and Vivo (FuntouchOS).

---

## 2. Beta Key Performance Indicators (KPIs)

| Metric | Target SLA | Tracking Mechanism |
|---|---|---|
| **False-Positive Penalty Rate** | < 1.0% of total penalties | In-app dispute button + `rules_stale` telemetry |
| **OEM Background Kill Rate** | < 5.0% of total running hours | Watchdog `service_killed` alerts + server heartbeat gaps |
| **Crash-Free Sessions** | ≥ 99.5% | Sentry crash reporting + Play Console vitals |
| **Daily Battery Consumption** | < 1.0% avg per 24h | Android Battery Historian logs submitted by testers |
| **Detection Precision** | ≥ 95.0% across YouTube Shorts & IG Reels | Beta user survey verification & session logs |

---

## 3. Tester Onboarding & Feedback Protocol

### 3.1 Onboarding Steps
1. Tester accepts Google Play Closed Testing invitation link.
2. App is downloaded from Google Play (`play` flavor).
3. Tester completes onboarding, reviews the prominent disclosure, and follows the OEM setup guide for their device.
4. Tester configures their standard daily budgets (e.g., 30 mins YouTube Shorts, 20 mins Instagram Reels).

### 3.2 Feedback Channels
- **In-App Dispute / Report:** Users can tap "Report Wrong Penalty" directly from the Penalty History detail view.
- **Diagnostics Export:** Settings -> "Export Diagnostics" generates a sanitized JSON log (no content, only timestamps and event types).
- **Private Beta Community:** Dedicated Discord/Slack channel and weekly feedback survey form.

---

## 4. Post-Beta Tuning & Adjustments

Based on beta data:
1. **Swipe Debounce Window:** Adjust `minGapMs` in `assets/detector_rules.json` if testers report rapid swipes being overcounted or missed.
2. **OEM Guide Refinements:** Update `assets/oem_guides.json` with any updated OS settings paths discovered on new OEM versions (e.g. HyperOS 2.0).
3. **Budget Default Settings:** Tune default ladder thresholds (L0 at 50%, L1 at 80%, L2 at 100%) to maximize habit formation without excessive friction.
