# Detector Rules Maintenance Playbook

This guide provides step-by-step instructions for engineering and QA teams to diagnose, re-discover, test, and safely publish detector rule updates when third-party apps (YouTube, Instagram, TikTok, etc.) change their UI layout or container IDs.

---

## 1. Hard Privacy Boundary
> [!IMPORTANT]
> **Strict Mandate:** Never read, evaluate, log, or transmit node text content, video descriptions, titles, comments, or user handles.
> All rules must exclusively rely on:
> - Package names (`packageName`)
> - Resource view IDs (`viewIdResourceName`)
> - Class names (`className`)
> - Event types (`eventType`)

---

## 2. Step 1: Detect Anomaly in Telemetry

When an app update breaks detection, the `UsageStatsReader` cross-check logs `rules_stale` events because the user spends time in the app without feed signals firing.

Run the detection health query in the Supabase SQL Editor:
```sql
SELECT * FROM public.detection_health
WHERE status IN ('WARNING', 'CRITICAL')
ORDER BY stale_rate_pct DESC;
```
Identify the `app_id` and `target_app_version` with elevated `stale_rate_pct`.

---

## 3. Step 2: Device Inspection & ID Re-discovery

1. **Connect Test Device:**
   Ensure `adb` is connected to a physical device running the affected app version:
   ```bash
   adb devices
   ```

2. **Open Feed & Dump Hierarchy:**
   - Launch the target app (e.g. YouTube Shorts or Instagram Reels).
   - Once inside the short-form video feed, dump the UI hierarchy:
     ```bash
     adb shell uiautomator dump /sdcard/feed_dump.xml
     adb pull /sdcard/feed_dump.xml ./dump_feed.xml
     ```

3. **Locate Feed Container & Pager IDs:**
   - Open `dump_feed.xml` in an XML editor or use Android Studio Layout Inspector.
   - Look for the root container wrapping the full-screen video page.
   - Look for the scrollable container (e.g., `RecyclerView`, `ViewPager2`, `Pager`).
   - Record the `resource-id` (e.g., `com.google.android.youtube:id/new_shorts_container`).

4. **Negative Verification (Essential!):**
   - Navigate away to the app's regular home feed, search tab, and profile.
   - Dump hierarchy again:
     ```bash
     adb shell uiautomator dump /sdcard/home_dump.xml
     adb pull /sdcard/home_dump.xml ./dump_home.xml
     ```
   - **Confirm:** The discovered container ID is **absent** from `dump_home.xml`.

---

## 4. Step 3: Update Rules & Test Locally

1. **Update `assets/detector_rules.json`:**
   Add the new container ID to `feedSignals` and `containerViewIds` for the app:
   ```json
   {
     "type": "viewIdPresent",
     "ids": [
       "com.google.android.youtube:id/reel_recycler",
       "com.google.android.youtube:id/new_shorts_container"
     ]
   }
   ```

2. **Run Unit & Trace Replayer Tests:**
   Run the Kotlin detection test suite:
   ```bash
   cd android
   ./gradlew testPlayDebugUnitTest --tests "com.yourorg.scrollguard.core.detect.*"
   ```
   Ensure `RuleSetParserTest` and `TraceReplayTest` pass with 100% success.

---

## 5. Step 4: Staged Rollout & Publishing

1. **Validate Schema in Dry-Run Mode:**
   ```bash
   dart run tool/publish_rules.dart --file=assets/detector_rules.json --dry-run
   ```

2. **Stage 1 (10% Canary Rollout):**
   Publish the new version (e.g. v2) with a 10% rollout to test devices:
   ```bash
   dart run tool/publish_rules.dart \
     --file=assets/detector_rules.json \
     --version=2 \
     --rollout=10 \
     --min-app-build=1
   ```

3. **Monitor Telemetry:**
   - Query `detection_health` for the canary cohort.
   - Confirm that canary devices on the new app version report `HEALTHY` with 0 `rules_stale` events.

4. **Stage 2 (Full Release - 100% Rollout):**
   ```bash
   dart run tool/publish_rules.dart \
     --file=assets/detector_rules.json \
     --version=2 \
     --rollout=100 \
     --min-app-build=1
   ```

---

## 6. Step 5: Rollback Protocol

If a newly published ruleset inadvertently misidentifies non-feed screens or fails to detect:
1. **Client Auto-Rollback:** The Android service automatically detects if remote rules produce 0 matches across 24 hours of guarded usage and rolls back to `last_known_good_rules.json`.
2. **Immediate Server Rollback:** Set `is_active = false` on the faulty rule version in Supabase:
   ```sql
   UPDATE public.detector_rules
   SET is_active = false
   WHERE version = 2;
   ```
   Clients will immediately revert to the previous active version upon their next refresh.
