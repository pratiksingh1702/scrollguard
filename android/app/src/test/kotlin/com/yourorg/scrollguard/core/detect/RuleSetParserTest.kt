package com.yourorg.scrollguard.core.detect

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test

class RuleSetParserTest {

    @Test
    fun testParseValidJson() {
        val validJson = """
            {
              "version": 42,
              "apps": [
                {
                  "id": "test_app",
                  "package": "com.test.app",
                  "label": "Test App",
                  "feedSignals": [
                    { "type": "viewIdPresent", "ids": ["com.test.app:id/container"] }
                  ],
                  "swipeSignals": {
                    "eventTypes": ["TYPE_VIEW_SCROLLED"],
                    "containerViewIds": ["com.test.app:id/container"],
                    "minGapMs": 400
                  },
                  "wholeAppIsFeed": false
                }
              ]
            }
        """.trimIndent()

        val ruleSet = RuleSetParser.parse(validJson)
        assertEquals(42, ruleSet.version)
        assertEquals(1, ruleSet.apps.size)

        val app = ruleSet.apps[0]
        assertEquals("test_app", app.id)
        assertEquals("com.test.app", app.packageName)
        assertFalse(app.wholeAppIsFeed)
        assertEquals(1, app.feedSignals.size)
        assertEquals("viewIdPresent", app.feedSignals[0].type)
        assertEquals("com.test.app:id/container", app.feedSignals[0].ids[0])
        assertNotNull(app.swipeSignals)
        assertEquals(400L, app.swipeSignals?.minGapMs)
    }

    @Test
    fun testMalformedJsonFallsBackToBundled() {
        val malformedJson = "{ broken json: true "
        val fallbackJson = """
            {
              "version": 10,
              "apps": [
                {
                  "id": "fallback_app",
                  "package": "com.fallback.app",
                  "wholeAppIsFeed": true
                }
              ]
            }
        """.trimIndent()

        val ruleSet = RuleSetParser.parse(malformedJson, fallbackJson)
        assertEquals(10, ruleSet.version)
        assertEquals("com.fallback.app", ruleSet.apps[0].packageName)
        assertTrue(ruleSet.apps[0].wholeAppIsFeed)
    }

    @Test
    fun testCompletelyInvalidJsonNeverCrashes() {
        val junk = "not even json at all"
        val ruleSet = RuleSetParser.parse(junk, "also not json")
        assertNotNull(ruleSet)
        assertTrue(ruleSet.apps.isNotEmpty())
        assertNotNull(ruleSet.findAppRule("com.google.android.youtube"))
    }
}
