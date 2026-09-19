# ScrollGuard Privacy Architecture

ScrollGuard is engineered around a zero-knowledge, local-first privacy standard.

---

## 1. Hard Privacy Rule
ScrollGuard NEVER reads, records, buffers, parses, or uploads:
- On-screen text, titles, subtitles, or captions
- Messages, comments, or chat transcripts
- Usernames, avatars, profile information, or account IDs
- Camera or microphone streams
- Keystrokes or text inputs

---

## 2. What Is Observed (Strict Whitelist)
Only the following structural UI metadata is examined in memory:
- **Package Name:** To filter events solely from user-selected guarded applications.
- **Resource ID:** Stable identifiers assigned by app developers (e.g., `reel_recycler`).
- **Class Name:** Android widget types (e.g., `androidx.viewpager2.widget.ViewPager2`).
- **Event Types:** High-level accessibility events (e.g., `TYPE_VIEW_SCROLLED`, `TYPE_WINDOW_STATE_CHANGED`).
- **Timestamps:** To determine duration, dwell times, and swipe frequencies.

---

## 3. Storage and Transmission Boundaries
- **On-Device Storage:** Room and Drift databases store only aggregated session records:
  - Session start/end timestamp
  - Total seconds in feed
  - Total swipe count
  - Calculated doomscroll score and penalty level reached
- **Backend Sync:** If the user creates an account and enables sync, only daily summaries and penalty records are transmitted. Individual swipe events or UI traces are never uploaded.
- **Data Deletion:** Full user-initiated data export and immediate account/data purge supported in settings.
