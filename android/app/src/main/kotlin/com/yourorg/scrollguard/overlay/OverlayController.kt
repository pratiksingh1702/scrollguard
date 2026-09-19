package com.yourorg.scrollguard.overlay

import android.annotation.SuppressLint
import android.content.Context
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.CountDownTimer
import android.os.Handler
import android.os.Looper
import android.text.Editable
import android.text.TextWatcher
import android.util.Log
import android.util.TypedValue
import android.view.Gravity
import android.view.KeyEvent
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import android.widget.Button
import android.widget.EditText
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.TextView
import android.view.ContextThemeWrapper

enum class OverlayType {
    NONE,
    NUDGE,
    FRICTION,
    LOCK
}

/**
 * Native overlay controller rendering UI using [WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY].
 *
 * Ensures only a single overlay is active at any time, handles back key consumption,
 * rotation re-layout, and safe view removal.
 */
class OverlayController(
    private val context: Context,
    private val windowManager: WindowManager = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
) {

    companion object {
        private const val TAG = "OverlayController"
        private const val NUDGE_AUTO_DISMISS_MS = 4000L
    }

    private val mainHandler = Handler(Looper.getMainLooper())
    private val themedContext = ContextThemeWrapper(context, android.R.style.Theme_DeviceDefault)

    private var currentView: View? = null
    var currentType: OverlayType = OverlayType.NONE
        private set

    private var nudgeDismissRunnable: Runnable? = null
    private var frictionTimer: CountDownTimer? = null
    private var lockTimer: CountDownTimer? = null

    /**
     * Show L0 Nudge overlay banner. Non-blocking, auto-dismisses after 4 seconds.
     */
    fun showNudge(message: String) {
        mainHandler.post {
            dismissCurrent()

            val rootView = createNudgeView(message)
            val params = WindowManager.LayoutParams(
                WindowManager.LayoutParams.MATCH_PARENT,
                WindowManager.LayoutParams.WRAP_CONTENT,
                WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                        WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                        WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
                PixelFormat.TRANSLUCENT
            ).apply {
                gravity = Gravity.TOP or Gravity.CENTER_HORIZONTAL
                y = dpToPx(36)
            }

            addViewSafely(rootView, params, OverlayType.NUDGE)

            val runnable = Runnable {
                if (currentType == OverlayType.NUDGE) {
                    dismissCurrent()
                }
            }
            nudgeDismissRunnable = runnable
            mainHandler.postDelayed(runnable, NUDGE_AUTO_DISMISS_MS)
        }
    }

    /**
     * Show L1 Friction overlay with countdown and "Leave" option.
     */
    fun showFriction(
        countdownSeconds: Int = 10,
        onLeave: () -> Unit,
        onContinue: () -> Unit
    ) {
        mainHandler.post {
            dismissCurrent()

            val rootView = createFrictionView(
                countdownSeconds = countdownSeconds,
                onLeave = {
                    dismissCurrent()
                    onLeave()
                },
                onContinue = {
                    dismissCurrent()
                    onContinue()
                }
            )

            val params = WindowManager.LayoutParams(
                WindowManager.LayoutParams.MATCH_PARENT,
                WindowManager.LayoutParams.MATCH_PARENT,
                WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
                WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                        WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
                PixelFormat.TRANSLUCENT
            ).apply {
                gravity = Gravity.CENTER
            }

            addViewSafely(rootView, params, OverlayType.FRICTION)
        }
    }

    /**
     * Show L2 Lock overlay with countdown, leave action, and emergency unlock.
     */
    fun showLock(
        remainingSeconds: Long,
        onLeave: () -> Unit,
        onEmergencyUnlock: (reason: String) -> Unit
    ) {
        mainHandler.post {
            // If already showing lock, just update or leave active
            if (currentType == OverlayType.LOCK) {
                return@post
            }
            dismissCurrent()

            val rootView = createLockView(
                remainingSeconds = remainingSeconds,
                onLeave = {
                    dismissCurrent()
                    onLeave()
                },
                onEmergencyUnlock = { reason ->
                    onEmergencyUnlock(reason)
                }
            )

            val params = WindowManager.LayoutParams(
                WindowManager.LayoutParams.MATCH_PARENT,
                WindowManager.LayoutParams.MATCH_PARENT,
                WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
                PixelFormat.TRANSLUCENT
            ).apply {
                gravity = Gravity.CENTER
            }

            addViewSafely(rootView, params, OverlayType.LOCK)
        }
    }

    /**
     * Dismiss whatever overlay is currently shown.
     */
    fun dismiss() {
        mainHandler.post {
            dismissCurrent()
        }
    }

    @Synchronized
    private fun dismissCurrent() {
        nudgeDismissRunnable?.let {
            mainHandler.removeCallbacks(it)
            nudgeDismissRunnable = null
        }
        frictionTimer?.cancel()
        frictionTimer = null
        lockTimer?.cancel()
        lockTimer = null

        currentView?.let { view ->
            try {
                if (view.isAttachedToWindow) {
                    windowManager.removeViewImmediate(view)
                }
            } catch (e: Exception) {
                Log.w(TAG, "Error removing overlay view: ${e.message}")
            }
            currentView = null
        }
        currentType = OverlayType.NONE
    }

    private fun addViewSafely(
        view: View,
        params: WindowManager.LayoutParams,
        type: OverlayType
    ) {
        try {
            windowManager.addView(view, params)
            currentView = view
            currentType = type
        } catch (e: Exception) {
            Log.e(TAG, "Failed to add overlay view ($type): ${e.message}", e)
            currentView = null
            currentType = OverlayType.NONE
        }
    }

    // --- UI View Builders ---

    private fun createNudgeView(message: String): View {
        val root = FrameLayout(themedContext).apply {
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            )
            setPadding(dpToPx(16), 0, dpToPx(16), 0)
        }

        val card = LinearLayout(themedContext).apply {
            orientation = LinearLayout.VERTICAL
            background = GradientDrawable().apply {
                setColor(Color.parseColor("#E620222A"))
                cornerRadius = dpToPx(16).toFloat()
                setStroke(dpToPx(1), Color.parseColor("#40FFA726"))
            }
            setPadding(dpToPx(16), dpToPx(12), dpToPx(16), dpToPx(12))
            layoutParams = FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            ).apply {
                gravity = Gravity.CENTER_HORIZONTAL
            }
        }

        val title = TextView(themedContext).apply {
            text = "ScrollGuard Alert"
            setTextColor(Color.parseColor("#FFA726"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 13f)
            typeface = Typeface.DEFAULT_BOLD
        }

        val msg = TextView(themedContext).apply {
            text = message
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 14f)
            setPadding(0, dpToPx(2), 0, 0)
        }

        card.addView(title)
        card.addView(msg)
        root.addView(card)
        return root
    }

    private fun createFrictionView(
        countdownSeconds: Int,
        onLeave: () -> Unit,
        onContinue: () -> Unit
    ): View {
        val root = InterceptBackFrameLayout(themedContext) {
            onLeave()
            true
        }.apply {
            setBackgroundColor(Color.parseColor("#F5111318"))
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            )
        }

        val centerLayout = LinearLayout(themedContext).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(dpToPx(32), dpToPx(32), dpToPx(32), dpToPx(32))
            layoutParams = FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            ).apply {
                gravity = Gravity.CENTER
            }
        }

        val iconText = TextView(themedContext).apply {
            text = "🛡️"
            textSize = 48f
            gravity = Gravity.CENTER
        }

        val titleText = TextView(themedContext).apply {
            text = "Take a breath"
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 24f)
            typeface = Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
            setPadding(0, dpToPx(12), 0, dpToPx(8))
        }

        val descText = TextView(themedContext).apply {
            text = "You've reached your friction threshold. Is this how you want to spend your time right now?"
            setTextColor(Color.parseColor("#CCCCCC"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 15f)
            gravity = Gravity.CENTER
            setPadding(0, 0, 0, dpToPx(24))
        }

        val countdownText = TextView(themedContext).apply {
            text = "Pause for $countdownSeconds seconds..."
            setTextColor(Color.parseColor("#FFA726"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 16f)
            typeface = Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
            setPadding(0, 0, 0, dpToPx(24))
        }

        val leaveButton = Button(themedContext).apply {
            text = "Leave Feed"
            setTextColor(Color.WHITE)
            background = GradientDrawable().apply {
                setColor(Color.parseColor("#4CAF50"))
                cornerRadius = dpToPx(12).toFloat()
            }
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                dpToPx(50)
            )
            setOnClickListener { onLeave() }
        }

        val continueButton = Button(themedContext).apply {
            text = "Continue scrolling"
            setTextColor(Color.parseColor("#888888"))
            isEnabled = false
            alpha = 0.5f
            background = GradientDrawable().apply {
                setColor(Color.parseColor("#22FFFFFF"))
                cornerRadius = dpToPx(12).toFloat()
            }
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                dpToPx(50)
            ).apply {
                topMargin = dpToPx(12)
            }
            setOnClickListener { onContinue() }
        }

        frictionTimer = object : CountDownTimer(countdownSeconds * 1000L, 1000L) {
            override fun onTick(millisUntilFinished: Long) {
                val sec = (millisUntilFinished / 1000L) + 1
                countdownText.text = "Pause for $sec seconds..."
            }

            override fun onFinish() {
                countdownText.text = "You may choose to continue now"
                countdownText.setTextColor(Color.parseColor("#81C784"))
                continueButton.isEnabled = true
                continueButton.alpha = 1.0f
                continueButton.setTextColor(Color.WHITE)
            }
        }.start()

        centerLayout.addView(iconText)
        centerLayout.addView(titleText)
        centerLayout.addView(descText)
        centerLayout.addView(countdownText)
        centerLayout.addView(leaveButton)
        centerLayout.addView(continueButton)

        root.addView(centerLayout)
        return root
    }

    private fun createLockView(
        remainingSeconds: Long,
        onLeave: () -> Unit,
        onEmergencyUnlock: (reason: String) -> Unit
    ): View {
        val root = InterceptBackFrameLayout(themedContext) {
            onLeave()
            true
        }.apply {
            setBackgroundColor(Color.parseColor("#F70E1015"))
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            )
        }

        val container = LinearLayout(themedContext).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(dpToPx(28), dpToPx(32), dpToPx(28), dpToPx(32))
            layoutParams = FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            ).apply {
                gravity = Gravity.CENTER
            }
        }

        val icon = TextView(themedContext).apply {
            text = "🔒"
            textSize = 48f
            gravity = Gravity.CENTER
        }

        val title = TextView(themedContext).apply {
            text = "Feed Locked"
            setTextColor(Color.parseColor("#FF5252"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 26f)
            typeface = Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
            setPadding(0, dpToPx(12), 0, dpToPx(8))
        }

        val message = TextView(themedContext).apply {
            text = "You have used your daily short-video budget. Time to step away!"
            setTextColor(Color.parseColor("#DDDDDD"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 15f)
            gravity = Gravity.CENTER
            setPadding(0, 0, 0, dpToPx(20))
        }

        val timerText = TextView(themedContext).apply {
            val m = remainingSeconds / 60
            val s = remainingSeconds % 60
            text = String.format("Locked for %02d:%02d", m, s)
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 20f)
            typeface = Typeface.MONOSPACE
            gravity = Gravity.CENTER
            setPadding(0, 0, 0, dpToPx(24))
        }

        val leaveButton = Button(themedContext).apply {
            text = "Leave App"
            setTextColor(Color.WHITE)
            background = GradientDrawable().apply {
                setColor(Color.parseColor("#E53935"))
                cornerRadius = dpToPx(12).toFloat()
            }
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                dpToPx(50)
            )
            setOnClickListener { onLeave() }
        }

        // Emergency unlock expandable area
        val emergencyContainer = LinearLayout(themedContext).apply {
            orientation = LinearLayout.VERTICAL
            visibility = View.GONE
            setPadding(0, dpToPx(16), 0, 0)
        }

        val reasonInput = EditText(themedContext).apply {
            hint = "Reason for emergency access (min 10 chars)..."
            setHintTextColor(Color.parseColor("#777777"))
            setTextColor(Color.WHITE)
            setBackgroundColor(Color.parseColor("#20FFFFFF"))
            setPadding(dpToPx(12), dpToPx(12), dpToPx(12), dpToPx(12))
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            )
        }

        val submitUnlockButton = Button(themedContext).apply {
            text = "Confirm Emergency Unlock"
            isEnabled = false
            alpha = 0.5f
            setTextColor(Color.WHITE)
            background = GradientDrawable().apply {
                setColor(Color.parseColor("#FFA000"))
                cornerRadius = dpToPx(10).toFloat()
            }
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                dpToPx(46)
            ).apply {
                topMargin = dpToPx(8)
            }
            setOnClickListener {
                val reason = reasonInput.text.toString().trim()
                if (reason.length >= 10) {
                    onEmergencyUnlock(reason)
                }
            }
        }

        reasonInput.addTextChangedListener(object : TextWatcher {
            override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) {}
            override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) {
                val valid = (s?.trim()?.length ?: 0) >= 10
                submitUnlockButton.isEnabled = valid
                submitUnlockButton.alpha = if (valid) 1.0f else 0.5f
            }
            override fun afterTextChanged(s: Editable?) {}
        })

        emergencyContainer.addView(reasonInput)
        emergencyContainer.addView(submitUnlockButton)

        val toggleEmergencyBtn = Button(themedContext).apply {
            text = "Emergency Unlock"
            setTextColor(Color.parseColor("#AAAAAA"))
            background = null
            setOnClickListener {
                if (emergencyContainer.visibility == View.VISIBLE) {
                    emergencyContainer.visibility = View.GONE
                } else {
                    emergencyContainer.visibility = View.VISIBLE
                }
            }
        }

        // Live ticker for lock
        lockTimer = object : CountDownTimer(remainingSeconds * 1000L, 1000L) {
            override fun onTick(millisUntilFinished: Long) {
                val sec = millisUntilFinished / 1000L
                val m = sec / 60
                val s = sec % 60
                timerText.text = String.format("Locked for %02d:%02d", m, s)
            }

            override fun onFinish() {
                timerText.text = "Lock period ended"
                dismissCurrent()
            }
        }.start()

        container.addView(icon)
        container.addView(title)
        container.addView(message)
        container.addView(timerText)
        container.addView(leaveButton)
        container.addView(toggleEmergencyBtn)
        container.addView(emergencyContainer)

        root.addView(container)
        return root
    }

    private fun dpToPx(dp: Int): Int {
        return (dp * context.resources.displayMetrics.density).toInt()
    }

    /**
     * Custom FrameLayout that intercepts hardware BACK key events.
     */
    private class InterceptBackFrameLayout(
        context: Context,
        private val onBackPressed: () -> Boolean
    ) : FrameLayout(context) {

        override fun dispatchKeyEvent(event: KeyEvent?): Boolean {
            if (event?.keyCode == KeyEvent.KEYCODE_BACK && event.action == KeyEvent.ACTION_UP) {
                if (onBackPressed()) {
                    return true
                }
            }
            return super.dispatchKeyEvent(event)
        }
    }
}
