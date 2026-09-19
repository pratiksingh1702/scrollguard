package com.yourorg.scrollguard.core.detect

import org.json.JSONArray
import org.json.JSONObject

data class RuleSet(
    val version: Int,
    val apps: List<AppRule>
) {
    fun findAppRule(packageName: String): AppRule? =
        apps.firstOrNull { it.packageName == packageName }
}

data class AppRule(
    val id: String,
    val packageName: String,
    val label: String,
    val feedSignals: List<FeedSignal>,
    val swipeSignals: SwipeSignals?,
    val wholeAppIsFeed: Boolean,
    val minAppVersion: Long? = null,
    val maxAppVersion: Long? = null
)

data class FeedSignal(
    val type: String,
    val ids: List<String>
)

data class SwipeSignals(
    val eventTypes: List<String>,
    val containerViewIds: List<String>,
    val minGapMs: Long = 500L
)

object RuleSetParser {

    /**
     * Parses a JSON string into a [RuleSet].
     * If parsing fails or JSON is malformed, falls back to [fallbackJson] if provided.
     * Throws [IllegalArgumentException] only if both fail or [fallbackJson] is null.
     */
    fun parse(jsonString: String, fallbackJson: String? = null): RuleSet {
        return try {
            parseInternal(jsonString)
        } catch (e: Exception) {
            if (fallbackJson != null) {
                try {
                    parseInternal(fallbackJson)
                } catch (fallbackEx: Exception) {
                    defaultFallbackRuleSet()
                }
            } else {
                defaultFallbackRuleSet()
            }
        }
    }

    private fun parseInternal(jsonString: String): RuleSet {
        val root = JSONObject(jsonString)
        val version = root.getInt("version")
        val appsArray = root.getJSONArray("apps")
        val apps = ArrayList<AppRule>()

        for (i in 0 until appsArray.length()) {
            val appObj = appsArray.getJSONObject(i)
            val id = appObj.getString("id")
            val pkg = appObj.getString("package")
            val label = appObj.optString("label", id)
            val wholeAppIsFeed = appObj.optBoolean("wholeAppIsFeed", false)

            val feedSignals = ArrayList<FeedSignal>()
            if (appObj.has("feedSignals")) {
                val signalsArray = appObj.getJSONArray("feedSignals")
                for (j in 0 until signalsArray.length()) {
                    val sigObj = signalsArray.getJSONObject(j)
                    val type = sigObj.getString("type")
                    val idsList = ArrayList<String>()
                    if (sigObj.has("ids")) {
                        val idsArray = sigObj.getJSONArray("ids")
                        for (k in 0 until idsArray.length()) {
                            idsList.add(idsArray.getString(k))
                        }
                    }
                    feedSignals.add(FeedSignal(type = type, ids = idsList))
                }
            }

            var swipeSignals: SwipeSignals? = null
            if (appObj.has("swipeSignals") && !appObj.isNull("swipeSignals")) {
                val swipeObj = appObj.getJSONObject("swipeSignals")
                val eventTypes = ArrayList<String>()
                if (swipeObj.has("eventTypes")) {
                    val evArray = swipeObj.getJSONArray("eventTypes")
                    for (m in 0 until evArray.length()) {
                        eventTypes.add(evArray.getString(m))
                    }
                }
                val containerViewIds = ArrayList<String>()
                if (swipeObj.has("containerViewIds")) {
                    val cArray = swipeObj.getJSONArray("containerViewIds")
                    for (m in 0 until cArray.length()) {
                        containerViewIds.add(cArray.getString(m))
                    }
                }
                val minGapMs = swipeObj.optLong("minGapMs", 500L)
                swipeSignals = SwipeSignals(
                    eventTypes = eventTypes,
                    containerViewIds = containerViewIds,
                    minGapMs = minGapMs
                )
            }

            val minVersion = if (appObj.has("minAppVersion") && !appObj.isNull("minAppVersion")) {
                appObj.getLong("minAppVersion")
            } else null

            val maxVersion = if (appObj.has("maxAppVersion") && !appObj.isNull("maxAppVersion")) {
                appObj.getLong("maxAppVersion")
            } else null

            apps.add(
                AppRule(
                    id = id,
                    packageName = pkg,
                    label = label,
                    feedSignals = feedSignals,
                    swipeSignals = swipeSignals,
                    wholeAppIsFeed = wholeAppIsFeed,
                    minAppVersion = minVersion,
                    maxAppVersion = maxVersion
                )
            )
        }

        return RuleSet(version = version, apps = apps)
    }

    fun defaultFallbackRuleSet(): RuleSet {
        return RuleSet(
            version = 1,
            apps = listOf(
                AppRule(
                    id = "youtube_shorts",
                    packageName = "com.google.android.youtube",
                    label = "YouTube Shorts",
                    feedSignals = listOf(
                        FeedSignal(
                            type = "viewIdPresent",
                            ids = listOf(
                                "com.google.android.youtube:id/reel_recycler",
                                "com.google.android.youtube:id/reel_player_page_container",
                                "com.google.android.youtube:id/shorts_container"
                            )
                        )
                    ),
                    swipeSignals = SwipeSignals(
                        eventTypes = listOf("TYPE_VIEW_SCROLLED"),
                        containerViewIds = listOf("com.google.android.youtube:id/reel_recycler"),
                        minGapMs = 500L
                    ),
                    wholeAppIsFeed = false
                ),
                AppRule(
                    id = "instagram_reels",
                    packageName = "com.instagram.android",
                    label = "Instagram Reels",
                    feedSignals = listOf(
                        FeedSignal(
                            type = "viewIdPresent",
                            ids = listOf(
                                "com.instagram.android:id/clips_viewer_view_pager",
                                "com.instagram.android:id/clips_video_container",
                                "com.instagram.android:id/reel_viewer_root"
                            )
                        )
                    ),
                    swipeSignals = SwipeSignals(
                        eventTypes = listOf("TYPE_VIEW_SCROLLED"),
                        containerViewIds = listOf("com.instagram.android:id/clips_viewer_view_pager"),
                        minGapMs = 500L
                    ),
                    wholeAppIsFeed = false
                ),
                AppRule(
                    id = "tiktok_global",
                    packageName = "com.zhiliaoapp.musically",
                    label = "TikTok",
                    feedSignals = emptyList(),
                    swipeSignals = SwipeSignals(
                        eventTypes = listOf("TYPE_VIEW_SCROLLED"),
                        containerViewIds = emptyList(),
                        minGapMs = 500L
                    ),
                    wholeAppIsFeed = true
                )
            )
        )
    }
}
