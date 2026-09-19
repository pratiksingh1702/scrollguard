# Google Play Store Compliance & Accessibility Policy

This document outlines our compliance with the Google Play Accessibility Services Policy and User Data Policy.

---

## 1. Google Play Accessibility Service Policy Compliance

Google Play requires that apps using the `AccessibilityService` API:
1. Provide a prominent in-app disclosure **before** asking the user to enable the service.
2. Obtain affirmative, unambiguous user consent ("Agree" / "Decline").
3. Use the service exclusively for the declared user-facing feature.
4. Never collect or share sensitive personal data.

---

## 2. Prominent In-App Disclosure Text

The following disclosure screen is shown during onboarding before any system permission dialog or settings redirect:

> **How ScrollGuard uses Accessibility Services**
> 
> ScrollGuard uses the Android AccessibilityService API to detect when you are actively viewing short-form video feeds (such as YouTube Shorts and Instagram Reels) and count your scroll interactions.
> 
> **What we inspect:**
> - The active app package name (to activate only in selected apps)
> - View identifiers and scroll events (to detect vertical video feed containers)
> - Durations and swipe intervals (to compute your doomscroll score and enforce your limits)
> 
> **What we NEVER inspect or collect:**
> - We never read, store, or transmit your messages, comments, or video titles.
> - We never collect personal account information or on-screen text.
> 
> By tapping **Agree**, you give ScrollGuard permission to monitor feed containers and show intervention overlays according to your budget.

---

## 3. Permissions Declaration Form Responses

- **Core Feature:** Digital wellbeing and self-commitment enforcement to reduce compulsive short-video scrolling.
- **Why Accessibility API is required:** Platform screen-time APIs (UsageStats) only report app-level foreground durations with significant delays. Because users consume both productive long-form content and compulsive short-form feeds in apps like YouTube, feed-level detection requires immediate UI tree inspection.
- **Demo Video Script:**
  1. User configures a 1-minute YouTube Shorts budget in ScrollGuard.
  2. Disclosure screen presented; user accepts and enables service in Android Accessibility settings.
  3. User launches YouTube, watches a long-form video (no intervention).
  4. User taps the "Shorts" tab; ScrollGuard overlay appears after budget exceeded.
