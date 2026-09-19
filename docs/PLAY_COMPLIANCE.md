# Google Play Store Compliance & Policy Package

This document contains the complete Google Play Store submission package, including the Accessibility Service Declaration, Permissions Declaration Form answers, demo video script, Data Safety responses, and Content Rating guidelines.

---

## 1. Google Play Accessibility Service Policy Compliance

Google Play requires that apps utilizing the `AccessibilityService` API:
1. Provide a prominent in-app disclosure **prior** to asking the user to enable the service.
2. Obtain affirmative, explicit user consent ("Agree" / "Decline").
3. Use the service exclusively for the declared user-facing digital wellbeing features.
4. Never collect, read, or transmit sensitive personal data or on-screen content.

---

## 2. Finalized Prominent In-App Disclosure Text

The following verbatim text is displayed on the dedicated disclosure screen in `OnboardingScreen` (Step 2) before the user can trigger any system settings redirect:

> ### How ScrollGuard Uses the Accessibility Service
>
> ScrollGuard uses the Android **AccessibilityService API** to detect when short-form video feeds (such as YouTube Shorts and Instagram Reels) are open on your screen and count your scrolling interactions.
>
> **What ScrollGuard Inspects:**
> - **Package Names:** To activate monitoring only when you open selected guarded apps.
> - **View Identifiers & Container Types:** To identify vertical video feed containers (e.g. `reel_recycler` or `clips_viewer_view_pager`).
> - **Scroll Gestures & Timestamps:** To measure dwell time and calculate your doomscroll score against your daily budget.
>
> **What ScrollGuard NEVER Inspects or Collects:**
> - We **NEVER** read, store, or transmit any on-screen text, titles, or descriptions.
> - We **NEVER** inspect your private messages, usernames, search queries, or comments.
> - We **NEVER** collect personal account details, passwords, or financial information.
>
> By tapping **Agree**, you consent to allowing ScrollGuard to monitor feed containers and display intervention overlays to help you stay within your screen time limits.

---

## 3. Permissions Declaration Form Responses

### 3.1 Accessibility Services Declaration (`BIND_ACCESSIBILITY_SERVICE`)
- **Core Functionality Category:** Digital Wellbeing / Screen Time Management.
- **Why can this feature NOT be implemented using alternative Android APIs?**
  Android's standard `UsageStatsManager` only provides delayed, aggregate foreground time at the application package level (e.g., total time in YouTube). It cannot distinguish between productive long-form educational videos and compulsive short-form feeds (YouTube Shorts). The Accessibility API is the only platform mechanism that allows real-time structural detection of video feed containers and immediate user-configured interventions (nudges, friction timers, and feed exit).
- **Does the app read or collect text on screen?**
  **NO.** The service filters events to `TYPE_VIEW_SCROLLED` and `TYPE_WINDOW_STATE_CHANGED`, inspecting only view resource IDs and class names. Zero text inspection is performed.

### 3.2 Usage Access Declaration (`PACKAGE_USAGE_STATS`)
- **Declaration:** Used exclusively as a secondary cross-check to detect if the accessibility service has been disabled or killed by OEM battery savers while guarded apps are in use, and to verify daily aggregate usage statistics.

### 3.3 Notification Permission (`POST_NOTIFICATIONS`)
- **Declaration:** Used on Android 13+ to deliver critical service health alerts (e.g. "ScrollGuard protection is inactive") and optional daily summary milestones.

---

## 4. Screen-Recording Demo Video Storyboard

A 60–90 second demonstration video submitted to the Google Play Review team:

| Timestamp | Scene | Description & Voiceover / Captions |
|---|---|---|
| **0:00 – 0:15** | Onboarding & Prominent Disclosure | App opens to onboarding. Step 2 shows the full Accessibility Prominent Disclosure screen. User reads disclosure and taps "Agree". System Accessibility Settings screen opens; user enables ScrollGuard. |
| **0:15 – 0:30** | Dashboard & Budget Configuration | User returns to ScrollGuard. Dashboard shows green "ACTIVE" status chip. User sets a 1-minute daily budget for YouTube Shorts. |
| **0:30 – 0:45** | YouTube Long-form Browsing (Negative Test) | User opens YouTube. User browses the home feed and plays a standard 10-minute landscape video. ScrollGuard does NOT intervene; no overlays appear. |
| **0:45 – 1:00** | YouTube Shorts Detection & Live Card | User taps the "Shorts" tab. User returns briefly to ScrollGuard dashboard to demonstrate live swipe counter and session timer incrementing in real time. |
| **1:00 – 1:15** | Budget Limit & Intervention Overlay | User scrolls Shorts past the 1-minute budget. ScrollGuard displays the Lockout overlay ("Daily Budget Reached"). Overlay performs a safe back navigation (`GLOBAL_ACTION_BACK`) returning user to the home screen. |

---

## 5. Google Play Data Safety Form Responses

### 5.1 Data Collection & Sharing Summary
- **Data Collected:**
  - **App info and performance:** Crash logs and diagnostics (if user opts in; anonymized).
  - **Device or other IDs:** Anonymous device identifier for multi-device sync and staged rollout hashing.
- **Data Shared:**
  - **NONE.** Zero user data is shared with any third-party advertisers, data brokers, or tracking networks.
- **Financial Information:**
  - If contract features are enabled, payment card details are collected and processed **directly by Stripe** via the Stripe SDK. ScrollGuard servers never receive, process, or store raw credit card numbers.

### 5.2 Security & User Rights
- **Data encrypted in transit:** All network communication uses HTTPS with TLS 1.3.
- **Data encrypted at rest:** Server-side PostgreSQL database protected by Row-Level Security (RLS) policies.
- **Data Deletion Mechanism:** Users can request immediate account and data deletion in **Settings -> Account -> Delete Account & Data**, which cascades across all database tables.

---

## 6. Content Rating Questionnaire Guidance

- **Category:** Utilities / Productivity / Tools
- **Violence:** No
- **Sexuality / Nudity:** No
- **Language / Profanity:** No
- **Controlled Substances:** No
- **User-to-User Interaction:** No (local app; no messaging or chat features)
- **Shares Physical Location:** No
- **Target Age Group:** All ages (13+ / General Audience)
- **Resulting Rating:** Everyone / PEGI 3 / USK 0
