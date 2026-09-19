# ScrollGuard — Full Build Plan (Flutter + Native Android)

> Working name: **ScrollGuard** (rename freely).
> Audience: an AI coding agent that will implement this end to end. Follow the phases in order. Every task has an ID, details, and acceptance criteria. Do not skip acceptance criteria.

---

## 0. How to use this document (rules for the AI agent)

1. Work **one task at a time**, in ID order unless a task says otherwise. Mark the checkbox when done.
2. After every task: the project must **build, lint clean (`flutter analyze`, `./gradlew lint`), and all tests pass**.
3. Never invent Android view IDs. Every detector rule must be **verified on a real device** (see Phase 1) and stored in a JSON rules file.
4. **Privacy rule (hard):** never read, log, store, or upload on-screen text, messages, usernames, or video titles. Only use view IDs, class names, package names, event types, and timestamps.
5. **Golden principle: "Native decides, Flutter displays."** Detection, limits, and blocking must work even when the Flutter engine is not running. Flutter is UI, configuration, sync, and payments.
6. Small commits, conventional commit messages (`feat:`, `fix:`, `chore:`, `test:`).
7. If a task is ambiguous, write the assumption in `docs/DECISIONS.md` and continue.
8. Keep secrets (Stripe keys, Supabase service key) out of the repo. Use `--dart-define` and environment variables.

---

## 1. Product overview

### 1.1 Problem
People lose hours to short-form vertical video (YouTube Shorts, Instagram Reels, TikTok, Facebook Reels, Snapchat Spotlight). Screen-time limits at app level are too blunt (YouTube is also used for long videos). We need **feed-level detection** and **real consequences**.

### 1.2 What the app does
1. Detects in real time, in the background, when the user is inside a short-video feed and how they are behaving (time, swipe rate, dwell per video).
2. Computes a **doomscroll score**.
3. Applies an escalating **penalty ladder**: nudge → friction → lock → strike → (optional) money penalty.
4. Shows stats, streaks, and history in a Flutter app.
5. Optionally lets the user opt into a **commitment contract** (deposit / charity donation / fee) enforced by a backend.

### 1.3 Non-goals (v1)
- iOS (Apple does not allow reading other apps' screens; only Screen Time API at app level. Planned as a separate later phase, see Section 20).
- Reading or analyzing video content.
- Parental-control / monitoring other people. This is a **self-commitment** tool. The user is always the one who opts in.

### 1.4 Core user stories
- As a user I install, grant permissions, choose which apps to guard, and set a daily short-video budget (e.g. 30 min).
- As a user I get a gentle nudge at 50% of budget, a friction screen at 80%, and a lock at 100%.
- As a user I can see how much time I spent in Reels/Shorts today, this week, and my streak.
- As a user I can opt into a money penalty that I set, with caps, and I can see exactly why I was charged.
- As a user I am told if the guard is turned off (service disabled, battery-killed).

---

## 2. Technology stack

### 2.1 Flutter (UI + orchestration)
| Concern | Choice | Why |
|---|---|---|
| State management | **flutter_riverpod + riverpod_annotation + riverpod_generator** (code-gen providers, `AsyncNotifier`, `StreamProvider`) | Compile-safe, testable, works great with streams from native |
| Immutable models | **freezed + json_serializable** | Union types and copyWith |
| Routing | **go_router** with Riverpod-driven redirects (onboarding/permissions guard) | Declarative + deep links |
| Local DB (Flutter side) | **drift** (SQLite) | Cache of daily stats, penalties, offline queue |
| Platform bridge | **pigeon** (typed MethodChannel API) + **EventChannel** for live streams | Type safety, no string typos |
| Networking | **dio** + interceptors | Retry, auth header |
| Backend SDK | **supabase_flutter** | Auth, Postgres, Realtime, Edge Functions |
| Payments | **flutter_stripe** | SetupIntent / PaymentSheet |
| Charts | **fl_chart** | Stats screens |
| Notifications | **flutter_local_notifications** (+ FCM later) | Reminders and summaries |
| Secure storage | **flutter_secure_storage** | Tokens |
| Crash/monitoring | **sentry_flutter** (or Firebase Crashlytics) | Production visibility |
| Lints | **very_good_analysis** | Strict lints |
| Testing | `flutter_test`, `mocktail`, `riverpod` `ProviderContainer` overrides, `integration_test`, `golden_toolkit`/`alchemist` | |
| Localization | `flutter_localizations` + `intl` (ARB files) | |

### 2.2 Native Android (detection + enforcement core)
| Concern | Choice |
|---|---|
| Language | **Kotlin**, coroutines + Flow |
| minSdk / targetSdk | minSdk **26** (Android 8), targetSdk = **latest required by Google Play** |
| Detection | `AccessibilityService` |
| Usage stats | `UsageStatsManager` (cross-check + fallback) |
| Blocking UI | `TYPE_ACCESSIBILITY_OVERLAY` window (no extra SYSTEM_ALERT_WINDOW permission needed) + `performGlobalAction(GLOBAL_ACTION_HOME)` |
| Keep alive | Foreground service is **not** required for an enabled AccessibilityService (the system binds it), but use **WorkManager** for watchdog/heartbeat + a `BOOT_COMPLETED` receiver |
| Native storage | **Room** (events/sessions/penalties) + **DataStore** (config) |
| Serialization | kotlinx.serialization |
| DI | Manual DI (a small `ServiceLocator`) — keep it dependency-light |
| Testing | JUnit5, MockK, Robolectric, `kotlinx-coroutines-test`, UI Automator for on-device tests |

### 2.3 Backend
- **Supabase**: Auth (email + Google), Postgres with **Row Level Security**, Edge Functions (Deno/TypeScript), Storage not needed.
- **Stripe**: SetupIntent (save card), off-session PaymentIntents, webhooks, Connect not needed for v1 (charity donation handled via a fixed pooled payout, or simply "fee").
- **Remote rules**: a `detector_rules` table + versioned JSON so detection can be fixed **without an app release** when YouTube/Instagram change their UI.

---

## 3. High-level architecture

```
┌──────────────────────────── Flutter (Dart) ─────────────────────────────┐
│ Presentation (screens/widgets)                                          │
│   ↕ Riverpod providers (Notifiers / StreamProviders)                    │
│ Domain (entities, use cases, repository interfaces)                     │
│ Data (repositories impl)                                                │
│   ├─ NativeBridge (Pigeon + EventChannel)  ──────────┐                  │
│   ├─ Drift local DB                                  │                  │
│   └─ Supabase / Stripe clients                       │                  │
└──────────────────────────────────────────────────────┼──────────────────┘
                                                       │ platform channels
┌──────────────────────────── Kotlin (Android) ────────┼──────────────────┐
│ FlutterPlugin: ScrollGuardPlugin (bridge entrypoint) ◄┘                 │
│                                                                         │
│ ┌─────────────────────  Enforcement Core (pure Kotlin) ──────────────┐  │
│ │ DetectorRegistry ─► SignalCollector ─► SessionTracker ─► ScoreEngine│  │
│ │                                                        │            │  │
│ │                                          PenaltyEngine ◄┘            │  │
│ │ ConfigStore (limits, ladder, rules)   Room (sessions, penalties)     │  │
│ └────────────────────────────────────────────────────────────────────┘  │
│                                                                         │
│ ScrollGuardAccessibilityService  (events in, overlay/global action out) │
│ OverlayController (native block/friction/nudge views)                   │
│ UsageStatsReader   WatchdogWorker   BootReceiver   HeartbeatWorker      │
└─────────────────────────────────────────────────────────────────────────┘
                                   │ HTTPS (aggregates only)
┌────────────────────────── Supabase + Stripe ────────────────────────────┐
│ Auth · Postgres (RLS) · Edge Functions · Stripe webhooks · detector_rules│
└─────────────────────────────────────────────────────────────────────────┘
```

**Data flow (real time):**
1. User scrolls Reels → Android sends `AccessibilityEvent`s to our service.
2. `DetectorRegistry` picks the detector for that package and decides "is this a short-video feed screen right now?" and "did the user swipe to the next video?".
3. `SessionTracker` builds a session (start, end, swipes, dwell times).
4. `ScoreEngine` computes the doomscroll score and budget usage.
5. `PenaltyEngine` decides the next action (nudge / friction / lock / strike).
6. `OverlayController` shows the native UI. Every event is also emitted to Flutter (if the engine is alive) via EventChannel for the live UI.
7. Aggregates sync to Supabase when online. Money penalties are executed **only by the backend**.

---

## 4. Repository layout

```
scrollguard/
├─ plan.md
├─ docs/
│  ├─ DECISIONS.md
│  ├─ DETECTOR_RULES.md          # how rules were verified, per app/version
│  ├─ PRIVACY.md
│  └─ PLAY_COMPLIANCE.md
├─ lib/
│  ├─ main.dart
│  ├─ app/                       # App widget, router, theme, l10n
│  ├─ core/                      # errors, result type, logger, constants, utils
│  ├─ bridge/                    # pigeon-generated + NativeBridge wrapper
│  └─ features/
│     ├─ onboarding/
│     ├─ permissions/
│     ├─ guard/                  # live status, enable/disable guard
│     ├─ dashboard/
│     ├─ stats/
│     ├─ rules/                  # budgets, guarded apps, ladder config
│     ├─ penalties/
│     ├─ contract/               # money commitment + Stripe
│     ├─ auth/
│     └─ settings/
│        (each feature: data/ domain/ presentation/ providers/)
├─ pigeons/
│  └─ native_api.dart            # pigeon definition
├─ android/app/src/main/
│  ├─ AndroidManifest.xml
│  ├─ res/xml/accessibility_service_config.xml
│  └─ kotlin/com/yourorg/scrollguard/
│     ├─ MainActivity.kt
│     ├─ plugin/ScrollGuardPlugin.kt
│     ├─ service/ScrollGuardAccessibilityService.kt
│     ├─ core/
│     │  ├─ detect/  (Detector, DetectorRegistry, RuleSet, per-app detectors)
│     │  ├─ session/ (SessionTracker, SwipeCounter)
│     │  ├─ score/   (ScoreEngine)
│     │  ├─ penalty/ (PenaltyEngine, PenaltyLadder)
│     │  └─ model/
│     ├─ overlay/    (OverlayController, views)
│     ├─ data/       (Room DB, DAOs, ConfigStore)
│     ├─ usage/      (UsageStatsReader)
│     └─ work/       (WatchdogWorker, HeartbeatWorker, BootReceiver)
├─ android/app/src/test/ ...     # JVM unit tests for core/
├─ android/app/src/androidTest/  # on-device tests
├─ test/                         # Flutter unit + widget tests
├─ integration_test/
└─ supabase/
   ├─ migrations/
   ├─ functions/ (create-setup-intent, charge-penalty, stripe-webhook, sync-day, get-rules)
   └─ seed.sql
```

---

## 5. Native Android design (the heart of the app)

### 5.1 AccessibilityService configuration
`res/xml/accessibility_service_config.xml`:

```xml
<accessibility-service xmlns:android="http://schemas.android.com/apk/res/android"
    android:accessibilityEventTypes="typeWindowStateChanged|typeWindowContentChanged|typeViewScrolled"
    android:accessibilityFeedbackType="feedbackGeneric"
    android:accessibilityFlags="flagReportViewIds|flagRetrieveInteractiveWindows"
    android:canRetrieveWindowContent="true"
    android:notificationTimeout="100"
    android:packageNames="com.google.android.youtube,com.instagram.android,com.zhiliaoapp.musically,com.ss.android.ugc.trill,com.facebook.katana,com.snapchat.android"
    android:description="@string/a11y_service_description"
    android:settingsActivity="com.yourorg.scrollguard.MainActivity" />
```

Notes:
- `packageNames` filter means we **only ever receive events from guarded apps** (better privacy + battery). Make the package list generated from the rules file.
- `canRetrieveWindowContent=true` is required for `findAccessibilityNodeInfosByViewId`. We use it **only** to check for the presence of specific view IDs, never to read text.
- The package list is static in XML, but we can additionally call `serviceInfo.packageNames = ...` at runtime to narrow it based on the user's "guarded apps" choice.

### 5.2 How we detect "short-video feed" (per app)
Detection uses **three layered signals**; a detector may use any of them, with the strongest first.

| Layer | Signal | Reliability | Cost |
|---|---|---|---|
| A | **View ID presence** of the feed container (e.g. reel pager) | High, but breaks on app updates | Medium |
| B | **Class name / window title / content description** heuristics (e.g. "Shorts", "Reels" content-desc on the selected tab) | Medium | Low |
| C | **Behavioral heuristic**: in a guarded app + vertical page-swipes with short dwell times | Lower precision but update-proof | Low |

**Starting hypotheses (MUST be verified on a real device in Task P1-T2; IDs change between versions):**

| App | Package | Likely feed container hints to verify |
|---|---|---|
| YouTube Shorts | `com.google.android.youtube` | `reel_recycler`, `reel_player_page_container`, `shorts_*` ids |
| Instagram Reels | `com.instagram.android` | `clips_viewer_view_pager`, `clips_viewer_container`, `clips_*` ids |
| TikTok | `com.zhiliaoapp.musically` (global), `com.ss.android.ugc.trill` (some regions) | Whole app is a short-video feed: treat foreground time + swipes as feed time |
| Facebook Reels | `com.facebook.katana` | reels viewer pager ids to verify |
| Snapchat Spotlight | `com.snapchat.android` | spotlight ids to verify |

**Do not trust this table.** The agent must inspect with Android Studio *Layout Inspector*, `adb shell uiautomator dump`, and the Accessibility Node Inspector, then record findings in `docs/DETECTOR_RULES.md` (app version, date, screenshot, IDs) and in `rules/detector_rules.json`.

### 5.3 Rules file format (`detector_rules.json`, also served remotely)
```json
{
  "version": 12,
  "apps": [
    {
      "id": "youtube_shorts",
      "package": "com.google.android.youtube",
      "label": "YouTube Shorts",
      "feedSignals": [
        { "type": "viewIdPresent", "ids": ["com.google.android.youtube:id/reel_recycler"] },
        { "type": "viewIdPresent", "ids": ["com.google.android.youtube:id/reel_player_page_container"] }
      ],
      "swipeSignals": {
        "eventTypes": ["TYPE_VIEW_SCROLLED"],
        "containerViewIds": ["com.google.android.youtube:id/reel_recycler"],
        "minGapMs": 500
      },
      "wholeAppIsFeed": false,
      "minAppVersion": null,
      "maxAppVersion": null
    }
  ]
}
```
The Kotlin `RuleSet` parses this. Rules ship bundled in `assets/` and are overridden by a newer remote version when available (Phase 9). If remote parsing fails, fall back to the bundled version.

### 5.4 Detector interface
```kotlin
interface FeedDetector {
    val appId: String
    /** Called with each accessibility event from this app. */
    fun onEvent(event: AccessibilityEvent, root: AccessibilityNodeInfo?): DetectorResult
}

data class DetectorResult(
    val inFeed: Boolean,          // is the user currently on a short-video feed screen
    val swiped: Boolean,          // did we detect a next/previous video swipe
    val confidence: Float,        // 0..1
    val signal: SignalSource      // VIEW_ID, HEURISTIC_TEXT, BEHAVIORAL
)
```
Implement one **generic `RuleBasedDetector`** driven by the JSON rules (no per-app Kotlin classes unless an app truly needs special logic). Add a **`BehavioralFallbackDetector`** that activates when the rule-based detector has had 0 matches in a guarded app for > N minutes of foreground time but scroll events keep arriving (signals the rules may be outdated → also raise a "rules_may_be_stale" telemetry flag).

### 5.5 Performance and battery rules for the service
- Throttle heavy calls (`rootInActiveWindow`, `findAccessibilityNodeInfosByViewId`) to at most **once per 400 ms** per package.
- Prefer event data (`event.className`, `event.source?.viewIdResourceName`) before tree walking.
- Always recycle nodes on API < 33 (`recycle()`), wrap in try/catch, and never hold node references across coroutines.
- No disk write per event. Buffer in memory and flush every 5 s or on session end.
- Run processing on a single-threaded coroutine dispatcher so events are processed in order.

### 5.6 Swipe counting (`SwipeCounter`)
- A "swipe" = a new video was shown. Best signals: `TYPE_VIEW_SCROLLED` on the pager container, or a `TYPE_WINDOW_CONTENT_CHANGED` burst after a scroll.
- Debounce: ignore additional swipe events within `minGapMs` (default 500 ms) since a single swipe animation emits many events.
- **Dwell time** = time between consecutive swipes. Store a rolling window of the last 20 dwell times.

### 5.7 Session tracking (`SessionTracker`)
State machine:

```
IDLE ──feed detected──► ACTIVE ──no feed signal for 8s / app left──► ENDING ──►  IDLE (session saved)
                          │
                          └── screen off / phone locked ──► ENDING
```
- Session fields: `id, appId, startTs, endTs, feedSeconds, swipeCount, avgDwellMs, minDwellMs, peakSwipesPerMinute, scoreMax, penaltyLevelReached`.
- Pauses: if the user leaves for < 20 s and returns, **merge** into the same session (prevents gaming by flicking away).
- Use `SystemClock.elapsedRealtime()` for durations (immune to clock changes) and store wall-clock timestamps separately.
- Listen for `ACTION_SCREEN_OFF` and `ACTION_USER_PRESENT` to end/resume sessions.

### 5.8 Doomscroll score (`ScoreEngine`)
Two independent measures, both configurable:

1. **Budget usage** = `feedSecondsToday / dailyBudgetSeconds` (primary, simple, easy to explain to users).
2. **Doomscroll intensity (0–100)**, from a rolling 5-minute window:
   ```
   intensity = clamp( 0.4 * norm(swipesPerMinute, 0..12)
                    + 0.3 * norm(1 - avgDwell/30s)          // shorter dwell = worse
                    + 0.2 * norm(continuousMinutes, 0..20)  // no break
                    + 0.1 * timeOfDayFactor(23:00–05:00),   // late-night bonus
                    0, 100 )
   ```
   Show "intensity" as flavor in UI; **penalties are driven by budget usage and continuous-minutes rules**, so behavior is predictable and explainable.

### 5.9 Penalty ladder (`PenaltyEngine`)
Fully user-configurable with sane defaults. Evaluated on every score update.

| Level | Trigger (default) | Action | Native implementation |
|---|---|---|---|
| L0 Nudge | 50% of daily budget OR 10 min continuous | Small non-blocking banner: "You've been scrolling 10 min" | Accessibility overlay banner, auto-dismiss 4 s |
| L1 Friction | 80% of budget OR 20 min continuous | Full-screen "Are you sure?" with 10 s forced wait + breathing animation, option "Leave" | Full overlay; "Continue" enabled after countdown |
| L2 Lock | 100% of budget | Feed is blocked for the cool-down (default 30 min). Overlay covers guarded app + `GLOBAL_ACTION_HOME` | Overlay + home action every time guarded app is foreground |
| L3 Strike | User bypasses L2 (e.g. clears app data, disables service to escape, or taps emergency unlock) OR exceeds budget by 150% | Record a **strike** locally + notify backend | Room `penalty_events` row + sync queue |
| L4 Money | Strike count ≥ threshold **and** user has an active contract | Backend charges the saved card (Phase 7) | Backend only |

Rules:
- **Emergency unlock**: limited (e.g. 1 per day), costs a strike or coin, and requires typing a reason of ≥ 10 chars (kept locally).
- **Cool-down** and **daily reset time** are configurable (default reset 04:00 local, so late-night scrolling counts toward "yesterday").
- Only the guarded **feed** is blocked (e.g. Shorts), not the whole YouTube app if we can detect the feed reliably: on lock, when feed is detected → overlay + `GLOBAL_ACTION_BACK`, then home if user persists. If detection is only behavioral (TikTok), block the whole app.
- Penalty engine is a **pure Kotlin class with no Android imports** so it is fully JVM unit testable.

### 5.10 Overlay controller
- Use `WindowManager.addView` with `WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY` from inside the service (needs no overlay permission).
- Build overlays with **native Android views** (ViewBinding/Compose-in-service is fragile). Keep them small, themed to match Flutter (colors from a shared token file exported at build time).
- Must handle: rotation, dark mode, back button (consume and go home), multi-window, and being removed if the guarded app leaves foreground.
- Keep a single overlay instance; guard against double `addView`.

### 5.11 UsageStatsManager cross-check
- Permission `PACKAGE_USAGE_STATS` (special access, user grants in Settings).
- Used for: (a) total per-app foreground time as a sanity check against accessibility-derived feed time, (b) recovering data for times the service was disabled (to detect tampering gaps), (c) daily totals shown in UI.
- Not used for real-time detection (data is delayed).

### 5.12 Reliability and OEM issues
Many OEMs (Xiaomi, Oppo, Vivo, Huawei, Samsung with "sleeping apps") kill background components.
- Onboarding step: deep-link the user to battery-optimization settings (`ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` where policy allows, else `ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS`) and show OEM-specific instructions (from a small `oem_guides.json`, sourced from dontkillmyapp.com knowledge).
- `WatchdogWorker` (periodic 15 min) checks: is the accessibility service enabled (`Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES`)? If not → local notification "Guard is off" + record a `guard_off` event + sync.
- `BootReceiver` reschedules workers after reboot.
- Persist `lastEventTs` so the watchdog can detect "service enabled but silent while guarded apps used" (via UsageStats).

### 5.13 Manifest essentials
```xml
<uses-permission android:name="android.permission.PACKAGE_USAGE_STATS" tools:ignore="ProtectedPermissions"/>
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
<uses-permission android:name="android.permission.INTERNET"/>
<!-- Optional, only if used: REQUEST_IGNORE_BATTERY_OPTIMIZATIONS (check Play policy first) -->

<queries> <!-- package visibility on Android 11+ for guarded apps -->
    <package android:name="com.google.android.youtube"/>
    <package android:name="com.instagram.android"/>
    <package android:name="com.zhiliaoapp.musically"/>
    ...
</queries>

<service android:name=".service.ScrollGuardAccessibilityService"
    android:permission="android.permission.BIND_ACCESSIBILITY_SERVICE"
    android:exported="true">
    <intent-filter><action android:name="android.accessibilityservice.AccessibilityService"/></intent-filter>
    <meta-data android:name="android.accessibilityservice"
               android:resource="@xml/accessibility_service_config"/>
</service>
```

---

## 6. Platform bridge (Flutter ⇄ Kotlin)

Use **Pigeon** for request/response and a plain **EventChannel** for live streams. Define everything in `pigeons/native_api.dart`.

### 6.1 Pigeon API (Flutter → native)
```dart
@HostApi()
abstract class GuardHostApi {
  // Status & permissions
  GuardStatus getStatus();                       // service enabled, usage access, notifications, battery opt
  void openAccessibilitySettings();
  void openUsageAccessSettings();
  void openBatterySettings();
  bool isAccessibilityServiceEnabled();

  // Configuration (Flutter is source of truth for user intent; native persists a copy)
  void applyConfig(GuardConfig config);          // budgets, ladder, guarded apps, reset hour
  void applyDetectorRules(String rulesJson);     // remote rules

  // Data
  List<SessionDto> getSessions(int fromEpochMs, int toEpochMs);
  DailyStatsDto getDailyStats(String dateIso);   // date in the app's "logical day"
  List<PenaltyEventDto> getPenaltyEvents(int fromEpochMs, int toEpochMs);
  void markSynced(List<String> ids);
  List<PendingSyncItemDto> getPendingSync();

  // Actions
  bool requestEmergencyUnlock(String reason);
  void setGuardPaused(int untilEpochMs);         // limited "pause" (audited)
}

@FlutterApi()
abstract class GuardFlutterApi {
  void onPenaltyApplied(PenaltyEventDto event); // optional push when engine is alive
}
```
`GuardStatus`, `GuardConfig`, `SessionDto`, etc. are Pigeon data classes (plain fields; no nulls where avoidable).

### 6.2 EventChannel streams (native → Flutter)
- `scrollguard/live` → emits `LiveState` every 1 s while a session is active, and immediately on state changes:
  `{ appId, inFeed, sessionSeconds, swipeCount, swipesPerMinute, budgetUsedFraction, intensity, penaltyLevel, lockedUntil? }`
- `scrollguard/guardStatus` → emits when service enabled/disabled or permissions change.

### 6.3 Threading contract
- Native emits on the main thread (Flutter requirement) but processing stays off-main.
- Streams are lazy: the native side only publishes when a Flutter listener is attached; otherwise it just stores.

---

## 7. Flutter app design (Riverpod)

### 7.1 Architecture per feature
`presentation` (widgets) → `providers` (Riverpod notifiers) → `domain` (entities, use-cases) → `data` (repositories, data sources). Providers are the **only** place widgets get state from. Widgets never call the bridge or Supabase directly.

### 7.2 Riverpod conventions
- Use **code-gen** (`@riverpod`) everywhere. One `*_providers.dart` per feature.
- Services (`NativeBridge`, `SupabaseClient`, `AppDatabase`, `Dio`) are **plain `Provider`s** that tests override.
- Screen state = `AsyncNotifier<State>` with `freezed` state classes.
- Streams from native = `StreamProvider` built from `EventChannel.receiveBroadcastStream()`.
- Use `ref.keepAlive()` only for long-lived things (live state, auth).
- Errors: a sealed `AppFailure` type, mapped to user-friendly messages in one place.

### 7.3 Key providers (minimum set)
| Provider | Type | Purpose |
|---|---|---|
| `nativeBridgeProvider` | Provider | Wraps Pigeon + EventChannels |
| `guardStatusProvider` | StreamProvider | Permission/service state, drives router redirects |
| `liveStateProvider` | StreamProvider | Real-time session data for dashboard |
| `guardConfigProvider` | AsyncNotifier | Read/edit budgets, ladder, guarded apps; calls `applyConfig` |
| `todayStatsProvider` | StreamProvider/AsyncNotifier | Daily totals (native + Drift) |
| `weeklyStatsProvider` | FutureProvider.family | Chart data |
| `sessionsProvider` | FutureProvider.family (date) | Session list |
| `penaltiesProvider` | AsyncNotifier | Penalty history |
| `authControllerProvider` | AsyncNotifier | Supabase auth state |
| `contractControllerProvider` | AsyncNotifier | Money contract lifecycle |
| `syncControllerProvider` | AsyncNotifier | Pushes pending items to backend |
| `rulesUpdaterProvider` | AsyncNotifier | Fetch + apply remote detector rules |
| `routerProvider` | Provider<GoRouter> | Redirect logic from onboarding/permissions/auth |

### 7.4 Screens
1. **Splash / Gate** – decides route from onboarding + permission + auth state.
2. **Onboarding (5 steps)** – value pitch → choose apps to guard → set daily budget → **prominent disclosure** for Accessibility (mandatory Play requirement, see §12) → grant permissions.
3. **Permissions checklist** – Accessibility, Usage Access, Notifications, Battery optimization; live tick marks driven by `guardStatusProvider`.
4. **Dashboard** – today's ring (budget used), live intensity gauge when scrolling, streak, next-penalty preview, guard status chip.
5. **Stats** – week/month charts (fl_chart), per-app breakdown, best/worst day, average dwell.
6. **Sessions** – list with details (start/end, swipes, dwell).
7. **Rules** – budgets per app, ladder thresholds, cool-down, reset hour, emergency-unlock allowance.
8. **Penalties** – history with the exact reason for each entry (transparency).
9. **Contract** – enable money penalty, set amounts and caps, add card (Stripe), terms, cooling-off.
10. **Settings** – account, data export/delete, privacy, about, diagnostics (shows detector rules version and last-match times).
11. **Blocked-screen preview** (debug) to visually test overlays.

### 7.5 Design
Material 3, single seed color, dark mode first-class. Calm, non-shaming tone in copy. Accessibility: 48dp targets, semantic labels, text scaling to 200%.

---

## 8. Data models

### 8.1 Native Room schema
```
sessions(id PK, appId, startTs, endTs, feedSeconds, swipeCount, avgDwellMs, minDwellMs,
         peakSpm, scoreMax, levelReached, synced BOOL)
daily_stats(dateIso PK, feedSeconds, swipeCount, lockCount, strikeCount, synced BOOL)
penalty_events(id PK, ts, appId, level, reason, budgetFraction, meta JSON, synced BOOL)
guard_events(id PK, ts, type[guard_on|guard_off|rules_stale|boot|paused|emergency_unlock], meta JSON, synced BOOL)
```
Index on `(startTs)`, `(dateIso)`, `(synced)`.

### 8.2 Flutter Drift schema
Mirror aggregates (`daily_stats`, `penalty_events`) for offline-first UI and history that survives native DB clears, plus `sync_queue`. Native remains authoritative for anything real-time.

### 8.3 Supabase Postgres schema (RLS on every table: `user_id = auth.uid()`)
```sql
profiles(id uuid pk references auth.users, created_at, timezone text, day_reset_hour int default 4)
devices(id uuid pk, user_id, platform, app_version, last_seen_at, guard_enabled bool)
rules_config(user_id pk, budget_seconds int, ladder jsonb, guarded_apps text[], updated_at)
daily_stats(user_id, date, feed_seconds int, swipe_count int, lock_count int, strike_count int, primary key(user_id,date))
penalty_events(id uuid pk, user_id, ts timestamptz, level int, reason text, meta jsonb)
guard_events(id uuid pk, user_id, ts, type text, meta jsonb)
contracts(id uuid pk, user_id, status[draft|active|paused|cancelled], stripe_customer_id, stripe_pm_id,
          per_penalty_cents int, daily_cap_cents int, weekly_cap_cents int, strike_threshold int,
          destination[charity|fee], terms_version text, accepted_at, cooling_off_until, created_at)
charges(id uuid pk, contract_id, penalty_event_id, amount_cents int, stripe_payment_intent_id,
        status, failure_reason, created_at)
detector_rules(version int pk, rules jsonb, min_app_build int, created_at, is_active bool)
```
Only **aggregates and events** are uploaded. Never raw scroll events or screen content.

---

## 9. Money penalties (design and safety)

> ⚠️ Real-money penalties are the highest-risk part legally and for store policy. Build it **last**, behind a feature flag, and get legal review (consumer protection, payments, Google Play payments policy, refund/chargeback handling) before launch. Start with the *commitment-deposit / charity* framing, never "surprise fines".

### 9.1 Principles
1. **Explicit opt-in contract** with clear terms: exact amounts, when they trigger, caps, how to cancel.
2. **Caps**: per-penalty, daily, weekly, and lifetime-per-month maximums, enforced server-side.
3. **Cooling-off / change delay**: reducing or cancelling the contract takes effect after a delay (e.g. 24–72 h) — that delay *is* the commitment device — but must comply with local consumer law (always allow cancellation of future penalties with notice; get legal input).
4. **Full transparency**: each charge links to the penalty event and reason; receipts by email.
5. **Backend-only execution**: the app never decides to charge; it reports events. The Edge Function validates (contract active, caps, idempotency, event not already charged) and charges.
6. **Dispute-friendly**: an "I disagree" button flags the event for review; auto-refund policy for detected false positives (e.g. `rules_stale` flagged).

### 9.2 Stripe flow
1. Flutter → Edge Function `create-setup-intent` → returns client secret.
2. `flutter_stripe` presents PaymentSheet in **setup mode** to save a card. Store `customer_id` + `payment_method_id` on `contracts`.
3. On strike threshold: `charge-penalty` function creates an **off-session PaymentIntent** (`confirm: true`, `off_session: true`, idempotency key = `penalty_event_id`).
4. `stripe-webhook` function updates `charges.status` (succeeded / failed / requires_action). On failure: notify user, retry policy (max 2), then pause the contract.
5. Alternatives to consider: pre-paid wallet balance (deduct without card fees per penalty), or a deposit held via authorization (short-lived, so a wallet is better).

### 9.3 Anti-gaming
- Detect tamper events (service disabled during guarded-app usage per UsageStats, uninstall/reinstall patterns, clock changes) → server-side "unverified day" logic: days with unexplained gaps count as a strike **only if the contract terms clearly say so**.
- Server is the source of truth for "day count" using device heartbeat timestamps (server time, not device time).

---

## 10. Backend Edge Functions (TypeScript)

| Function | Purpose |
|---|---|
| `sync-day` | Upsert daily stats, penalty events, guard events (idempotent by IDs) |
| `get-rules` | Return latest active `detector_rules` for app build |
| `create-setup-intent` | Stripe customer + SetupIntent |
| `activate-contract` | Validate terms, cooling-off, store contract |
| `charge-penalty` | Idempotent charge with caps |
| `stripe-webhook` | Verify signature, update charge state |
| `heartbeat` | Device alive ping → detects "guard silent" |
| `export-data` / `delete-account` | GDPR-style user data controls |

All functions: auth required, input validated (zod), structured logs, no PII in logs.

---

## 11. Testing strategy

| Layer | What | Tools |
|---|---|---|
| Kotlin core (`SessionTracker`, `SwipeCounter`, `ScoreEngine`, `PenaltyEngine`, `RuleSet`) | Pure JVM tests with fake clocks and event scripts | JUnit5, MockK, coroutines-test |
| Detector replay | Record anonymized **event traces** (types + ids + timestamps only) from real devices as JSON fixtures; replay through detectors and assert sessions | Custom `TraceReplayer` |
| Accessibility on device | Launch YouTube/Instagram, scroll, assert service state and overlays | UI Automator on a real device (manual checklist for store apps you can't automate) |
| Flutter unit | Notifiers with mocked bridge | `ProviderContainer`, mocktail |
| Flutter widget/golden | Dashboard, onboarding, rules, contract | `flutter_test`, goldens |
| Integration | Onboarding → permissions → dashboard using a **FakeNativeBridge** | `integration_test` |
| Backend | Edge function tests, RLS tests, Stripe test-mode e2e | Deno test, Stripe CLI |
| Manual QA matrix | Android 8–15, Samsung/Xiaomi/Pixel/Oppo, dark/light, tablets | Checklist in `docs/QA.md` |

**Fake native bridge:** provide `FakeNativeBridge` in Dart that emits scripted `LiveState` streams so the whole Flutter app can be developed and tested without a device.

---

## 12. Compliance, privacy, and store policy

- **Google Play AccessibilityService policy**: apps not primarily accessibility tools must (a) show a **prominent in-app disclosure** *before* sending the user to Accessibility settings, describing exactly what is observed and why, with explicit "Agree" / "Decline"; (b) not use it for anything other than the declared core feature; (c) complete the **Permissions Declaration Form** with a screen-recording demo; (d) never collect or share screen content. Write `docs/PLAY_COMPLIANCE.md` with the exact disclosure text and video script. Do **not** mark the service as `isAccessibilityTool` unless it truly qualifies.
- **Usage Access** and **Notifications**: explain each in the permissions screen.
- **Privacy policy** + **Data Safety form**: declare account data, purchase data, app activity aggregates; state no screen content is collected; on-device processing.
- **Payments**: confirm Play payments policy applicability to penalties before shipping money features (consider charity-only in Play build and direct-Stripe in a web/APK build if needed).
- **Age**: 18+ only for money features. Do not target children.
- **Data controls**: in-app export and delete; delete cascades in Supabase.
- **Fallback distribution plan**: keep a sideload/direct APK build flavor (`direct`) in case Play rejects the accessibility justification. Use Gradle flavors (`play`, `direct`).

---

## 13. Security and anti-tamper

- Certificate pinning is optional; do enforce HTTPS and Supabase RLS.
- Obfuscate release builds (`--obfuscate --split-debug-info`, R8 on Android).
- Detect: service disabled, app data cleared (guard_event on next start via server heartbeat gap), device clock changes (compare `elapsedRealtime` vs wall clock), rooted/emulator flags (informational only).
- The user can always uninstall — that is acceptable. The design goal is **making the escape costly and visible**, not impossible. Uninstall protection via Device Admin is intrusive and increases Play risk; leave it out of v1 and reconsider as an opt-in "strict mode".
- Optional **accountability partner**: v2 feature; partner gets notified on guard-off events.

---

## 14. Analytics and observability

- Crash reporting (Sentry) with breadcrumbs for bridge calls (no user content).
- Product analytics (PostHog/Firebase) — events: onboarding_step, permission_granted, session_summary (aggregate), penalty_level_reached, contract_enabled. **No per-scroll events.**
- Detector health metrics: per app + app version: `feed_match_rate`, `rules_stale_flag`, `last_feed_match_ts`. This tells you when YouTube/Instagram updates broke detection.

---

# TASK BREAKDOWN

Legend: **[ ]** todo · Each task: *Details* → *Acceptance*.

---

## PHASE 0 — Foundation

- [x] **P0-T1 Create project and flavors**
  *Details:* `flutter create --org com.yourorg --platforms=android scrollguard`. Add Gradle flavors `play` and `direct` with different `applicationIdSuffix` and a `BuildConfig.FLAVOR`. Set Kotlin, AGP, Gradle to current stable. Set minSdk 26.
  *Acceptance:* `flutter run --flavor play` launches on a device; `flutter analyze` clean.

- [x] **P0-T2 Tooling and lints**
  *Details:* Add `very_good_analysis`, `build_runner`, pre-commit script (`dart format`, `analyze`, `test`), GitHub Actions workflow running Flutter analyze/test and Gradle unit tests.
  *Acceptance:* CI green on an empty project.

- [x] **P0-T3 Dependency setup**
  *Details:* Add all packages from §2.1. Configure `build.yaml` for freezed/riverpod/drift/json codegen.
  *Acceptance:* `dart run build_runner build` succeeds.

- [x] **P0-T4 Folder structure and core utilities**
  *Details:* Create the layout in §4. Add `Result<T>`/`AppFailure`, `Logger` wrapper (no sensitive data), `Clock` abstraction (injectable for tests), env config via `--dart-define`.
  *Acceptance:* Structure exists; unit test for `Clock` and `AppFailure` mapping.

- [x] **P0-T5 Theme, l10n, router skeleton**
  *Details:* Material 3 theme (light/dark), ARB localization (en), go_router with placeholder routes and `routerProvider`.
  *Acceptance:* App shows a placeholder home; theme switch works; widget test passes.

- [x] **P0-T6 Docs stubs**
  *Details:* Create `docs/DECISIONS.md`, `DETECTOR_RULES.md`, `PRIVACY.md`, `PLAY_COMPLIANCE.md`, `QA.md`.
  *Acceptance:* Files exist with headings from this plan.

---

## PHASE 1 — Native detection spike (do this BEFORE building UI)

> Goal: prove that detection works on real devices with real apps. If this fails, the product idea needs rethinking, so validate first.

- [x] **P1-T1 Minimal AccessibilityService**
  *Details:* Add the service, XML config (§5.1), manifest entry, `strings.xml` description. Log (debug only, no text content) event type, package, className, and viewId of the source for guarded packages.
  *Acceptance:* After enabling the service in Settings, opening YouTube produces log lines with event types; nothing is logged for non-guarded apps.

- [x] **P1-T2 Discovery: find feed signals per app**
  *Details:* On a physical device, for each app in the §5.2 table: open the short-video feed, use Layout Inspector / `uiautomator dump` / a debug-only "node tree dumper" in the service (IDs + class names only) to identify stable view IDs for (a) feed container present, (b) pager that changes on swipe. Record app version, date, and IDs in `docs/DETECTOR_RULES.md`. Verify the signals are **absent** when the user is on the normal home feed or watching a long video.
  *Acceptance:* `DETECTOR_RULES.md` has, per app: version, IDs, how verified, negative test results. At least YouTube Shorts and Instagram Reels done.

- [x] **P1-T3 Rules file and parser**
  *Details:* Implement `detector_rules.json` schema (§5.3) in `assets/`, Kotlin `RuleSet` + parser (kotlinx.serialization), validation with helpful errors, unit tests including malformed input.
  *Acceptance:* JVM tests pass; bad JSON falls back to the bundled rules without crashing.

- [x] **P1-T4 RuleBasedDetector**
  *Details:* Implement `FeedDetector` (§5.4) driven by rules: `viewIdPresent`, `contentDescContains` (matches only against a whitelist of strings from rules, never stores them), `wholeAppIsFeed`. Throttle tree queries (§5.5).
  *Acceptance:* On device, entering Shorts sets `inFeed=true` within 1 s and leaving sets it to false within 2 s; unit tests using fake node trees.

- [x] **P1-T5 SwipeCounter and dwell**
  *Details:* Implement per §5.6 with configurable `minGapMs`. Unit tests with scripted event timelines (burst of events per swipe → 1 swipe).
  *Acceptance:* Manually scrolling 20 Reels yields 20 ±2 swipes on device; unit tests pass.

- [x] **P1-T6 BehavioralFallbackDetector**
  *Details:* Implement heuristic C (§5.2): guarded app foreground + ≥ N scroll-like events per minute with short intervals. Emits `rules_stale` guard event when it fires while rule-based detector is silent.
  *Acceptance:* With rules deliberately corrupted, scrolling still gets detected as feed-time with lower confidence; stale flag is recorded.

- [x] **P1-T7 SessionTracker**
  *Details:* State machine per §5.7 incl. merge window, screen-off handling, `elapsedRealtime`. In-memory first, then persisted (P1-T8).
  *Acceptance:* Replay-based unit tests: leave for 10 s and return → 1 session; leave for 60 s → 2 sessions; screen off ends session.

- [x] **P1-T8 Room persistence**
  *Details:* Room DB per §8.1, DAOs, buffered writes (flush 5 s / on session end), migrations setup, `ConfigStore` with DataStore.
  *Acceptance:* Sessions survive process death; instrumentation test inserts + reads; no per-event disk writes (verify with a counter test).

- [x] **P1-T9 ScoreEngine + daily budget**
  *Details:* Implement §5.8 with logical-day boundary (reset hour). Pure Kotlin.
  *Acceptance:* Unit tests: budget fraction across a 04:00 boundary; intensity monotonic with swipe rate.

- [x] **P1-T10 Trace recorder + replayer**
  *Details:* Debug-only tool to record anonymized event traces (no text) to JSON, and `TraceReplayer` test utility. Record at least 3 traces per app (normal browsing, doomscroll, long video).
  *Acceptance:* Replay tests assert correct session counts per fixture.

**Phase 1 exit gate:** a demo APK where a debug notification shows live "In Shorts / Reels — N swipes — MM:SS" on at least 2 apps. Write findings into `DECISIONS.md`. **Stop and report if detection reliability is < 90%.**

---

## PHASE 2 — Enforcement (penalties and overlay)

- [x] **P2-T1 PenaltyEngine (pure Kotlin)**
  *Details:* Implement ladder §5.9 as a deterministic function `(state, event, config, now) → actions`. Include cool-down, emergency unlock allowance, strike counting.
  *Acceptance:* Table-driven unit tests for every transition and edge (budget hit exactly, reset hour, unlock used up).

- [x] **P2-T2 OverlayController**
  *Details:* Native overlays via `TYPE_ACCESSIBILITY_OVERLAY`: Nudge banner, Friction screen (10 s countdown, "Leave" button), Lock screen (shows time remaining, emergency-unlock button with reason input). Handle rotation/dark mode/back button; single instance.
  *Acceptance:* On device, each overlay appears and dismisses correctly, doesn't leak (LeakCanary clean), and is removed when the app leaves foreground.

- [x] **P2-T3 Wire engine → service**
  *Details:* Service feeds detector results into SessionTracker → ScoreEngine → PenaltyEngine → OverlayController; L2 lock triggers `GLOBAL_ACTION_BACK`/`HOME` as designed; persist penalty events.
  *Acceptance:* With a 1-minute test budget: nudge at 30 s, friction at 48 s, lock at 60 s; re-opening Shorts during cool-down is blocked.

- [x] **P2-T4 Emergency unlock and pause**
  *Details:* Limited unlock (count/day), reason ≥ 10 chars stored locally, records a `guard_event`. Limited "pause guard" (max duration, max per day) for legit needs.
  *Acceptance:* Unit + device test; counts reset at logical day change.

- [x] **P2-T5 Watchdog + Boot + Heartbeat**
  *Details:* `WatchdogWorker` (15 min) checks accessibility enabled (§5.12) → local notification + `guard_off` event; `BootReceiver`; `HeartbeatWorker` stores timestamps for later sync.
  *Acceptance:* Disabling the service produces the notification within 15 min (test with a shortened interval in debug); reboot reschedules workers.

- [x] **P2-T6 UsageStats cross-check**
  *Details:* `UsageStatsReader` for per-app daily foreground time; compare with accessibility-derived time; log divergence > 30% as `rules_stale`/gap event.
  *Acceptance:* Unit test on comparator; device check with usage access granted.

**Phase 2 exit gate:** Full enforcement works with **no Flutter UI running** (kill the app; guard still blocks).

---

## PHASE 3 — Bridge (Pigeon + EventChannel)

- [x] **P3-T1 Pigeon definition and codegen**
  *Details:* Write `pigeons/native_api.dart` per §6.1; configure Dart + Kotlin output; add script `tool/gen_pigeon.sh`.
  *Acceptance:* Generated files compile on both sides.

- [x] **P3-T2 ScrollGuardPlugin (Kotlin)**
  *Details:* Implement `GuardHostApi`, register as FlutterPlugin. Service ↔ plugin communication via a process-wide `GuardStateHolder` (StateFlow) since the service and the Flutter engine live in the same process but different lifecycles.
  *Acceptance:* `getStatus()` returns real permission/service state from Dart.

- [x] **P3-T3 EventChannels**
  *Details:* `scrollguard/live` and `scrollguard/guardStatus` per §6.2, lazy publishing, throttled to 1 Hz.
  *Acceptance:* Dart test app prints live updates while scrolling Shorts; no updates (and no CPU use) when no listener.

- [x] **P3-T4 Dart NativeBridge wrapper + fake**
  *Details:* `NativeBridge` interface, `AndroidNativeBridge` (real) and `FakeNativeBridge` (scripted). Map DTOs → domain entities. Expose through `nativeBridgeProvider`.
  *Acceptance:* Unit tests using the fake; swapping via `ProviderScope.overrides` works.

- [x] **P3-T5 Config push**
  *Details:* `applyConfig` persists config natively and takes effect immediately without restarting the service.
  *Acceptance:* Changing budget from Dart changes the next penalty threshold on the device within 1 s.

---

## PHASE 4 — Flutter shell, onboarding, permissions

- [ ] **P4-T1 Domain models and repositories**
  *Details:* freezed entities: `GuardConfig`, `LiveState`, `Session`, `DailyStats`, `PenaltyEvent`, `GuardStatus`. Repository interfaces + implementations backed by the bridge and Drift.
  *Acceptance:* Model serialization tests; repositories tested with fakes.

- [ ] **P4-T2 Providers baseline**
  *Details:* Implement providers listed in §7.3 (except contract/sync/rules). `guardStatusProvider` and `liveStateProvider` from EventChannels.
  *Acceptance:* Provider tests with `ProviderContainer` + `FakeNativeBridge`.

- [ ] **P4-T3 Router gating**
  *Details:* `routerProvider` redirects: not onboarded → onboarding; missing critical permission → permissions; else dashboard. Re-check on app resume (`WidgetsBindingObserver`), since the user returns from Settings.
  *Acceptance:* Widget tests for each redirect case.

- [ ] **P4-T4 Onboarding flow**
  *Details:* 5 steps (§7.4). The **Accessibility prominent disclosure** screen: exact wording from `PLAY_COMPLIANCE.md`, explicit Agree/Decline; Decline leads to an explanation and a safe exit (no permission request).
  *Acceptance:* Golden tests for each step; manual check that Settings deep link only opens after Agree.

- [ ] **P4-T5 Permissions screen**
  *Details:* Live checklist for Accessibility, Usage Access, Notifications (runtime request on Android 13+), Battery optimization, with OEM-specific help sheet from `oem_guides.json`.
  *Acceptance:* Ticks update automatically upon returning from settings; works on at least Pixel + one OEM device.

---

## PHASE 5 — Core screens

- [ ] **P5-T1 Dashboard**
  *Details:* Budget ring, live card (appears when `liveState.inFeed`), streak, next-penalty preview, guard status chip, quick pause/emergency actions.
  *Acceptance:* Widget tests with scripted live states; visually matches design; 60 fps during live updates.

- [ ] **P5-T2 Stats**
  *Details:* Weekly/monthly bar charts, per-app breakdown, average dwell, best/worst day.
  *Acceptance:* Correct aggregates vs seeded data; golden tests.

- [ ] **P5-T3 Sessions list + detail**
  *Details:* Paginated list grouped by day; detail shows timeline of dwell times.
  *Acceptance:* Handles 10k sessions smoothly (pagination/lazy queries).

- [ ] **P5-T4 Rules screen**
  *Details:* Edit guarded apps (only apps installed, using package visibility), daily budget (global + per app), ladder thresholds with validation (L0 < L1 < L2), cool-down, reset hour, emergency allowance. Apply via `applyConfig`.
  *Acceptance:* Validation tests; changes persist and take effect natively.

- [ ] **P5-T5 Penalties history**
  *Details:* List of penalty events with human-readable reason ("Budget reached: 30/30 min in Instagram Reels").
  *Acceptance:* Matches native Room data.

- [ ] **P5-T6 Settings + diagnostics**
  *Details:* Diagnostics page: service status, rules version, last feed match per app, stale flags, export logs (no content). Data export/delete hooks (wired in Phase 6).
  *Acceptance:* Diagnostics reflect real state.

- [ ] **P5-T7 Local notifications**
  *Details:* Daily summary, "guard is off" alert (from native), streak milestones.
  *Acceptance:* Notifications fire on schedule; tapping deep-links to the right screen.

---

## PHASE 6 — Backend, auth, sync

- [ ] **P6-T1 Supabase project + migrations**
  *Details:* Create schema §8.3 as SQL migrations; enable RLS with policies; seed a bundled rules version.
  *Acceptance:* RLS tests prove user A cannot read user B's rows.

- [ ] **P6-T2 Auth**
  *Details:* Email + Google sign-in via `supabase_flutter`; `authControllerProvider`; guest mode allowed until money features are enabled (guest data links to account on sign-up).
  *Acceptance:* Sign up / in / out flows tested; router respects auth where required.

- [ ] **P6-T3 Sync pipeline**
  *Details:* `syncControllerProvider`: gathers `getPendingSync()`, posts to `sync-day` (idempotent by ID), calls `markSynced`. Triggers: app open, day rollover, connectivity regained, WorkManager periodic (native worker with a lightweight HTTP call if Flutter is not running, or defer until app open — decision in `DECISIONS.md`).
  *Acceptance:* Offline for a day → all data appears server-side after reconnect exactly once.

- [ ] **P6-T4 Heartbeat + guard-silent detection (server)**
  *Details:* `heartbeat` function stores last seen; a scheduled function marks gaps and creates `guard_events`.
  *Acceptance:* Simulated gap produces a server event.

- [ ] **P6-T5 Data export and account deletion**
  *Details:* `export-data` (JSON zip), `delete-account` (cascade + Stripe customer deletion). UI in Settings.
  *Acceptance:* Deleting an account removes all rows (verified by test).

---

## PHASE 7 — Money penalties (feature-flagged: `contract_enabled`)

- [ ] **P7-T1 Contract domain + terms**
  *Details:* `contracts`, `charges` tables; terms document versioning; `contractControllerProvider` with states draft → active → paused → cancelled; cooling-off logic.
  *Acceptance:* State machine unit tests.

- [ ] **P7-T2 Stripe setup flow**
  *Details:* `create-setup-intent` function; PaymentSheet in setup mode; store PM; 3DS handling; test with Stripe test cards.
  *Acceptance:* Card saved in test mode; contract can be activated only after explicit acceptance (checkbox + typed confirmation of the max monthly amount).

- [ ] **P7-T3 Charge engine**
  *Details:* `charge-penalty` with idempotency, caps (per-penalty/daily/weekly/monthly), contract state checks; `stripe-webhook` for async results; failure retries and contract pause.
  *Acceptance:* Tests: duplicate event → one charge; cap exceeded → no charge; failed card → retry then pause.

- [ ] **P7-T4 Money UI**
  *Details:* Contract screen, charge history with linked penalty reasons, receipts by email, "I disagree" dispute button, change-contract flow honoring the delay.
  *Acceptance:* Golden + integration tests with a mocked backend.

- [ ] **P7-T5 False-positive protection**
  *Details:* Server refuses/auto-refunds charges tied to events with `rules_stale`, usage-stats divergence, or unusual detection anomalies in the same window.
  *Acceptance:* Scenario tests.

- [ ] **P7-T6 Legal/compliance checklist**
  *Details:* Produce `docs/LEGAL_CHECKLIST.md` (terms, refunds, chargebacks, age gate, jurisdictions, store policy review). **Do not enable the flag in production until a human signs off.**
  *Acceptance:* Document reviewed by the owner.

---

## PHASE 8 — Anti-tamper and reliability hardening

- [ ] **P8-T1 Tamper signals** — clock-change detection, service-disabled-while-used detection (UsageStats vs events), data-cleared detection via server heartbeat; all recorded as `guard_events`.
  *Acceptance:* Each scenario reproduced on a device and shown in diagnostics.

- [ ] **P8-T2 OEM survival guide** — `oem_guides.json` for Xiaomi, Oppo/Realme, Vivo, Huawei, Samsung, OnePlus; in-app step-by-step screens; test on at least two OEMs.
  *Acceptance:* Guard still active after 24 h idle on tested OEM devices.

- [ ] **P8-T3 Strict mode (optional opt-in)** — friction to disable the guard: delayed disable (e.g. 10 min wait), accountability notification stub. No Device Admin in v1.
  *Acceptance:* Behavior documented in `DECISIONS.md`; tested.

- [ ] **P8-T4 Performance audit** — profile the service (Android Studio Profiler): CPU < 1–2% avg during scrolling, no memory growth over a 1 h scroll test, battery impact measured against a baseline.
  *Acceptance:* Report saved in `docs/PERF.md`.

---

## PHASE 9 — Remote detector rules (keeps the product alive)

- [ ] **P9-T1 Rules service** — `get-rules` function + `detector_rules` table + admin script to publish a new version (validated JSON schema, staged rollout percentage).
  *Acceptance:* Publishing v13 makes clients pick it up within 24 h.

- [ ] **P9-T2 Client updater** — `rulesUpdaterProvider` fetches on app open + daily background job; validates; sends to native via `applyDetectorRules`; native keeps last-known-good and auto-rolls back if the new rules produce zero matches for 24 h of guarded usage.
  *Acceptance:* Bad rules never brick detection (test with a malformed payload).

- [ ] **P9-T3 Detection health dashboard** — Supabase view/SQL of `rules_stale` rate per app version to notice breakage quickly.
  *Acceptance:* Query documented in `DETECTOR_RULES.md`.

- [ ] **P9-T4 Maintenance playbook** — write `docs/RULES_MAINTENANCE.md`: how to re-discover IDs after an app update, test with the trace replayer, publish.
  *Acceptance:* A new person can fix a broken rule by following it.

---

## PHASE 10 — Quality, release, and launch

- [ ] **P10-T1 Full test pass** — all suites in §11 green; coverage targets: Kotlin core ≥ 85%, Flutter domain/providers ≥ 80%.
- [ ] **P10-T2 Device QA matrix** — run `docs/QA.md` on Android 8, 10, 12, 13, 14, 15 and ≥ 4 OEMs; fix issues.
- [ ] **P10-T3 Play Store compliance package** — prominent disclosure text finalized, Permissions Declaration Form answers, screen-recording demo video, privacy policy URL, Data Safety form answers, content rating.
- [ ] **P10-T4 Release pipeline** — signed AAB via CI, R8 + Dart obfuscation, symbol upload to Sentry, internal testing track → closed beta → production staged rollout (5% → 20% → 100%).
- [ ] **P10-T5 Beta program** — 20–50 testers for 2–4 weeks; track false-positive rate and OEM kill rate; adjust thresholds and defaults.
- [ ] **P10-T6 Launch checklist** — crash-free rate ≥ 99.5%, detection precision ≥ 95% on top apps, support email/FAQ, in-app "report a wrong penalty" flow.

---

## 15. Suggested timeline (solo dev + AI agent)

| Phase | Effort |
|---|---|
| 0 Foundation | 1–2 days |
| 1 Detection spike | 1–2 weeks (device-heavy; the riskiest part) |
| 2 Enforcement | 1 week |
| 3 Bridge | 3–5 days |
| 4–5 Flutter app | 2–3 weeks |
| 6 Backend/sync | 1 week |
| 7 Money | 1–2 weeks + legal review |
| 8–9 Hardening + remote rules | 1–2 weeks |
| 10 QA + release | 2–3 weeks incl. beta |

MVP cut (no backend, no money): Phases 0–5 → shippable as a free, local-only app.

---

## 16. Key risks and mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| Instagram/YouTube UI update breaks view IDs | Detection fails | Remote rules, behavioral fallback, health metrics, trace replay tests |
| Google Play rejects Accessibility use | Can't distribute on Play | Strong disclosure, tight scope, `direct` flavor for sideload, contact policy support early |
| OEM battery killers | Guard silently stops | Onboarding guides, watchdog, server heartbeat |
| False-positive penalties (esp. money) | User anger, chargebacks, legal | Conservative defaults, transparent reasons, dispute flow, auto-refund on stale flags |
| Battery drain from service | Bad reviews | Package filter, throttling, profiling gate in Phase 8 |
| Users bypass by disabling service | Product ineffective | Visible tamper events, optional strict mode, accountability partner (v2) |
| Legal issues with real-money fines | Blocking | Commitment-contract framing, caps, opt-in, legal sign-off before launch |

---

## 17. Definition of Done (global)

A task is done only when:
1. Code compiles, lints clean, tests written and passing.
2. Acceptance criteria verified (on a real device where relevant).
3. No sensitive content logged or stored.
4. Docs updated (`DECISIONS.md` for any assumption or trade-off).
5. Changes committed with a clear message.

---

## 18. Future roadmap (post v1)

- **Accountability partner** (friend gets notified / must approve unlock).
- **Widgets and Quick Settings tile** (pause, status).
- **Rewards**: earn "focus coins" for streaks, spend on emergency unlocks.
- **Smart interventions**: replace scrolling with breathing/reading prompts, time-of-day rules, location rules.
- **Insights**: weekly report emails, mood tagging.
- **Wear OS** glance.
- **Web dashboard** for contracts.

## 19. Open questions for the owner (record answers in DECISIONS.md)

1. Which apps are mandatory for v1 (recommend YouTube Shorts + Instagram Reels + TikTok)?
2. Money model: charity donation, platform fee, or wallet deposit?
3. Play Store only, or also direct APK distribution?
4. Countries at launch (affects payments and consumer law)?
5. Should a lock block only the feed or the whole app when detection confidence is low?

## 20. iOS (separate future track, not part of this plan's tasks)

Apple forbids reading other apps' UI. The only route is **Screen Time API** (FamilyControls, DeviceActivity, ManagedSettings) with an Apple-approved entitlement: app-level (not feed-level) limits, shielding apps after a threshold, implemented in Swift extensions and controlled from Flutter via platform channels. Expect a much coarser product ("Instagram limit reached") than Android. Plan it only after the Android product proves demand.
