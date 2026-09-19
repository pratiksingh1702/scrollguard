# Detector Rules & Verification Protocol

This document details verified feed signals, view IDs, class names, and test results across target applications.

---

## 1. Hard Privacy Boundary
Detectors MUST NOT read, evaluate, store, or transmit node text content, video descriptions, titles, comments, or user handles. Signals are restricted exclusively to:
- Package names
- Resource view IDs (`viewIdResourceName`)
- Class names (`className`)
- Event types (`eventType`)
- Content description matching against strict static whitelists (e.g. tab names "Reels", "Shorts")

---

## 2. Target Application Signal Catalog

### YouTube (`com.google.android.youtube`)
- **App ID:** `youtube_shorts`
- **Verified Versions:** 19.10.x – 19.36.x (Android 10+)
- **Inspection Method:** `uiautomator dump` + Accessibility Node Inspector trace recording
- **Feed Container Hints:**
  - `com.google.android.youtube:id/reel_recycler`
  - `com.google.android.youtube:id/reel_player_page_container`
  - `com.google.android.youtube:id/shorts_container`
- **Swipe Events:**
  - `TYPE_VIEW_SCROLLED` originating from `reel_recycler`
  - Debounce window: 500 ms (`minGapMs`)
- **Negative Verification:**
  - Normal home feed (`browse_recycler`, `results_recycler`) does NOT trigger `inFeed = true`.
  - Long-form video watch page (`watch_while_layout`, `player_view`) does NOT trigger `inFeed = true`.

### Instagram (`com.instagram.android`)
- **App ID:** `instagram_reels`
- **Verified Versions:** 320.x – 350.x (Android 10+)
- **Inspection Method:** Layout Inspector + node dump hierarchy
- **Feed Container Hints:**
  - `com.instagram.android:id/clips_viewer_view_pager`
  - `com.instagram.android:id/clips_video_container`
  - `com.instagram.android:id/reel_viewer_root`
- **Swipe Events:**
  - `TYPE_VIEW_SCROLLED` on `clips_viewer_view_pager`
  - Debounce window: 500 ms
- **Negative Verification:**
  - Main photo feed (`feed_recycler`, `main_feed`) does NOT trigger `inFeed = true`.
  - Direct messages, profile grid, and search do NOT trigger `inFeed = true`.

### TikTok (`com.zhiliaoapp.musically`, `com.ss.android.ugc.trill`)
- **App ID:** `tiktok`
- **Verified Versions:** 33.x – 36.x
- **Inspection Method:** Process foreground observer + vertical swipe detection
- **Rule:** `wholeAppIsFeed = true`.
- **Logic:** Foreground active time combined with vertical swipe gestures constitutes feed consumption.

### Facebook Reels (`com.facebook.katana`)
- **App ID:** `facebook_reels`
- **Feed Container Hints:**
  - `com.facebook.katana:id/reels_viewer_container`
  - `com.facebook.katana:id/short_form_video_pager`
- **Negative Verification:**
  - Standard Facebook news feed does NOT trigger `inFeed = true`.

### Snapchat Spotlight (`com.snapchat.android`)
- **App ID:** `snapchat_spotlight`
- **Feed Container Hints:**
  - `com.snapchat.android:id/spotlight_pager`
  - `com.snapchat.android:id/spotlight_fullscreen_player`
- **Negative Verification:**
  - Chat screen and camera viewfinder do NOT trigger `inFeed = true`.

---

## 3. Remote Rules Schema & Fallback
The application bundles `assets/detector_rules.json` as the baseline. Remote updates from the backend override bundled rules only when validated against the local schema. If remote rules produce zero matches over an extended usage window, the system automatically falls back to bundled rules.

---

## 4. Detection Health Dashboard & Monitoring Query

To detect UI breakages in guarded applications (e.g. YouTube or Instagram changing container IDs in an update), the backend aggregates `rules_stale` and `usage_divergence` signals from client telemetry.

### 4.1 Real-Time Health Query (SQL View `detection_health`)
```sql
SELECT
    app_id,
    target_app_version,
    total_guard_events,
    stale_events_count,
    divergence_events_count,
    stale_rate_pct,
    status,
    last_stale_event_at
FROM public.detection_health
ORDER BY stale_rate_pct DESC, total_guard_events DESC;
```

### 4.2 Automated Alert Thresholds
- **HEALTHY:** `stale_rate_pct == 0%` (detection functioning normally).
- **WARNING:** `0% < stale_rate_pct <= 10%` (minor variance or user edge cases).
- **CRITICAL:** `stale_rate_pct > 10%` (indicates a breaking app UI change in `target_app_version`). Triggers an alert to update detector rules immediately following the Maintenance Playbook (`docs/RULES_MAINTENANCE.md`).
