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
- **Feed Container Hints:**
  - `com.google.android.youtube:id/reel_recycler`
  - `com.google.android.youtube:id/reel_player_page_container`
  - `com.google.android.youtube:id/shorts_container`
- **Swipe Events:**
  - `TYPE_VIEW_SCROLLED` originating from `reel_recycler`
  - Debounce window: 500 ms (`minGapMs`)
- **Negative Verification:**
  - Normal home feed (`browse_recycler`) does NOT trigger `inFeed = true`.
  - Long video watch page (`watch_while_layout`, `player_view`) does NOT trigger `inFeed = true`.

### Instagram (`com.instagram.android`)
- **App ID:** `instagram_reels`
- **Feed Container Hints:**
  - `com.instagram.android:id/clips_viewer_view_pager`
  - `com.instagram.android:id/clips_video_container`
  - `com.instagram.android:id/reel_viewer_root`
- **Swipe Events:**
  - `TYPE_VIEW_SCROLLED` on `clips_viewer_view_pager`
  - Debounce window: 500 ms
- **Negative Verification:**
  - Main chronological/algorithmic photo feed does NOT trigger `inFeed = true`.
  - Direct messages, profile grid, and search do NOT trigger `inFeed = true`.

### TikTok (`com.zhiliaoapp.musically`, `com.ss.android.ugc.trill`)
- **App ID:** `tiktok`
- **Rule:** `wholeAppIsFeed = true`.
- **Logic:** Foreground usage with vertical scrolling is measured directly as feed consumption.

---

## 3. Remote Rules Schema & Fallback
The application bundles `assets/detector_rules.json` as the baseline. Remote updates from the backend override bundled rules only when validated against the local schema. If remote rules produce zero matches over an extended usage window, the system automatically falls back to bundled rules.
