package com.aryanrogye.movies_shared.web

import android.app.Activity
import android.content.Context
import android.content.ContextWrapper
import android.annotation.SuppressLint
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color as AndroidColor
import android.graphics.Paint
import android.os.SystemClock
import android.view.KeyEvent
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.ViewGroup
import android.webkit.WebChromeClient
import android.webkit.CookieManager
import android.webkit.WebResourceRequest
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.FrameLayout
import androidx.activity.compose.BackHandler
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat


@Composable
fun MediaWebView(
    url: String,
    reloadKey: Int,
    blockingService: AndroidBlockingService,
    modifier: Modifier = Modifier,
    onExitFocus: () -> Unit,
    onError: (String) -> Unit,
) {
    NativeMediaWebView(
        url = url,
        reloadKey = reloadKey,
        modifier = modifier,
        onExitFocus = onExitFocus,
        onError = onError,
    )
}

private const val URL_KEY_TAG = 0x4d415049

/** A user-selected native WebView path for provider compatibility testing. */
@SuppressLint("SetJavaScriptEnabled")
@Composable
private fun NativeMediaWebView(
    url: String,
    reloadKey: Int,
    modifier: Modifier,
    onExitFocus: () -> Unit,
    onError: (String) -> Unit,
) {
    val context = LocalContext.current
    val activity = remember(context) { context.findActivity() }
    var progress by remember { mutableFloatStateOf(0f) }
    var isLoading by remember { mutableStateOf(false) }
    var webView by remember { mutableStateOf<TvCursorWebView?>(null) }
    var inlineHost by remember { mutableStateOf<FrameLayout?>(null) }
    var customView by remember { mutableStateOf<View?>(null) }
    var fullscreenCursor by remember { mutableStateOf<TvCursorOverlayView?>(null) }
    var customViewCallback by remember { mutableStateOf<WebChromeClient.CustomViewCallback?>(null) }

    fun closeFullscreen() {
        val view = customView ?: return
        (view.parent as? ViewGroup)?.removeView(view)
        fullscreenCursor?.let { cursor ->
            (cursor.parent as? ViewGroup)?.removeView(cursor)
        }
        fullscreenCursor = null
        activity?.let { act ->
            WindowCompat.setDecorFitsSystemWindows(act.window, true)
            WindowInsetsControllerCompat(act.window, act.window.decorView).apply {
                show(WindowInsetsCompat.Type.systemBars())
                systemBarsBehavior = WindowInsetsControllerCompat.BEHAVIOR_DEFAULT
            }
        }
        val callback = customViewCallback
        customViewCallback = null
        customView = null
        // Restore the same WebView without reloading the playing document.
        webView?.let { browser ->
            inlineHost?.let { host ->
                if (browser.parent !== host) {
                    (browser.parent as? ViewGroup)?.removeView(browser)
                    host.addView(browser, FrameLayout.LayoutParams(
                        ViewGroup.LayoutParams.MATCH_PARENT,
                        ViewGroup.LayoutParams.MATCH_PARENT,
                    ))
                }
            }
        }
        callback?.onCustomViewHidden()
        webView?.requestFocus()
    }

    BackHandler(enabled = customView != null) { closeFullscreen() }

    Box(modifier = modifier.background(Color.Black)) {
        AndroidView<FrameLayout>(
            modifier = Modifier.fillMaxSize(),
            factory = { ctx ->
                val host = FrameLayout(ctx)
                inlineHost = host
                val browser = TvCursorWebView(ctx, onExitFocus).apply {
                    webView = this
                    setTag(URL_KEY_TAG, MediaRequest(url, reloadKey))
                    setBackgroundColor(AndroidColor.BLACK)
                    // Keep the normal hardware-accelerated window rendering.
                    // A forced offscreen layer cannot contain the separate
                    // SurfaceView used by Amazon WebView for video overlays.
                    // LAYER_TYPE_NONE does not disable hardware acceleration.
                    setLayerType(View.LAYER_TYPE_NONE, null)
                    settings.apply {
                        javaScriptEnabled = true
                        domStorageEnabled = true
                        databaseEnabled = true
                        useWideViewPort = false
                        loadWithOverviewMode = false
                        allowFileAccess = true
                        allowContentAccess = true
                        cacheMode = WebSettings.LOAD_DEFAULT
                        mediaPlaybackRequiresUserGesture = false
                        // Do not block provider redirects or popup windows in this
                        // comparison engine; the website controls those requests.
                        javaScriptCanOpenWindowsAutomatically = true
                        setSupportMultipleWindows(true)
                        mixedContentMode = WebSettings.MIXED_CONTENT_ALWAYS_ALLOW
                        userAgentString = playerUserAgent(url)
                    }
                    CookieManager.getInstance().setAcceptCookie(true)
                    CookieManager.getInstance().setAcceptThirdPartyCookies(this, true)
                    webViewClient = object : WebViewClient() {
                        override fun shouldOverrideUrlLoading(view: WebView, request: WebResourceRequest) = false

                        override fun onPageStarted(view: WebView, pageUrl: String, favicon: Bitmap?) {
                            isLoading = true
                        }

                        override fun onPageFinished(view: WebView, pageUrl: String) {
                            isLoading = false
                            view.evaluateJavascript(NATIVE_WEBVIEW_COMPATIBILITY_SCRIPT, null)
                        }

                        override fun onReceivedError(
                            view: WebView,
                            request: WebResourceRequest,
                            error: android.webkit.WebResourceError,
                        ) {
                            if (request.isForMainFrame && error.errorCode != ERROR_HOST_LOOKUP) {
                                onError(error.description.toString())
                            }
                        }
                    }
                    webChromeClient = object : WebChromeClient() {
                        override fun onProgressChanged(view: WebView, newProgress: Int) {
                            // Progress fires ~100x per load; each write recomposes.
                            // Coarsen to 2% steps so the meter doesn't jank video init.
                            val p = newProgress / 100f
                            if (newProgress >= 100 || kotlin.math.abs(p - progress) >= 0.02f) {
                                progress = p
                                isLoading = newProgress < 100
                            }
                        }

                        override fun onShowCustomView(view: View, callback: CustomViewCallback) {
                            if (customView != null) closeFullscreen()
                            customView = view
                            customViewCallback = callback
                            activity?.let { act ->
                                val decor = act.window.decorView as? ViewGroup ?: return@let
                                // AWV can keep its hardware video SurfaceView under
                                // the original WebView even when controls move into
                                // the fullscreen custom view. Expand both to the
                                // same origin and bounds to avoid inline clipping.
                                webView?.let { browser ->
                                    (browser.parent as? ViewGroup)?.removeView(browser)
                                    decor.addView(browser, FrameLayout.LayoutParams(
                                        ViewGroup.LayoutParams.MATCH_PARENT,
                                        ViewGroup.LayoutParams.MATCH_PARENT,
                                        Gravity.TOP or Gravity.START,
                                    ))
                                }
                                // Preserve WebView's custom-view background and
                                // surface composition; do not paint over its video
                                // surface with an application-owned opaque layer.
                                view.translationZ = 999f
                                (view.parent as? ViewGroup)?.removeView(view)
                                decor.addView(view, FrameLayout.LayoutParams(
                                    ViewGroup.LayoutParams.MATCH_PARENT,
                                    ViewGroup.LayoutParams.MATCH_PARENT,
                                    Gravity.TOP or Gravity.START,
                                ))
                                val cursor = TvCursorOverlayView(
                                    act,
                                    inputViewProvider = { customView },
                                    onScroll = {},
                                    onExitFullscreen = { closeFullscreen() },
                                    onExitFocus = { closeFullscreen() },
                                    isFullscreenProvider = { true },
                                ).apply {
                                    setFullscreenState(true)
                                    translationZ = 1000f
                                }
                                fullscreenCursor = cursor
                                decor.addView(cursor, FrameLayout.LayoutParams(
                                    ViewGroup.LayoutParams.MATCH_PARENT,
                                    ViewGroup.LayoutParams.MATCH_PARENT,
                                    Gravity.TOP or Gravity.START,
                                ))
                                WindowCompat.setDecorFitsSystemWindows(act.window, false)
                                WindowInsetsControllerCompat(act.window, act.window.decorView).apply {
                                    hide(WindowInsetsCompat.Type.systemBars())
                                    systemBarsBehavior = WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
                                }
                                decor.requestLayout()
                                view.requestLayout()
                                cursor.requestFocus()
                            }
                        }

                        override fun onHideCustomView() = closeFullscreen()
                    }
                    loadUrl(url)
                }
                host.addView(browser, FrameLayout.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    ViewGroup.LayoutParams.MATCH_PARENT,
                ))
                host
            },
            update = update@{
                val view = webView ?: return@update
                val request = MediaRequest(url, reloadKey)
                val previous = view.getTag(URL_KEY_TAG) as? MediaRequest
                if (previous != request) {
                    view.setTag(URL_KEY_TAG, request)
                    view.settings.userAgentString = playerUserAgent(url)
                    if (previous?.url == url) {
                        // Same embed, user hit Reload: view.reload() keeps the warm
                        // renderer, cache, cookies and connections alive. This is
                        // exactly what Silk's refresh button does, and why it
                        // unsticks VidFast's first-load hang instantly.
                        // loadUrl would work but tears down more page state.
                        view.reload()
                    } else {
                        view.loadUrl(url)
                    }
                }
            },
        )
        if (isLoading) {
            LinearProgressIndicator(
                progress = { progress },
                modifier = Modifier.fillMaxWidth().height(3.dp),
                color = Color.Yellow,
                trackColor = Color.Transparent,
            )
        }
    }

    DisposableEffect(Unit) {
        onDispose {
            closeFullscreen()
            webView?.apply {
                stopLoading()
                loadUrl("about:blank")
                webChromeClient = null
                webViewClient = WebViewClient()
                destroy()
            }
            webView = null
        }
    }
}

// Derived from fix/android-webview-playback-stability. This only fixes Fire TV
// viewport/fullscreen presentation; it has no popup or network filtering.
private val NATIVE_WEBVIEW_COMPATIBILITY_SCRIPT = """
    (() => {
        if (document.getElementById('movies-tv-compat')) return;
        const style = document.createElement('style');
        style.id = 'movies-tv-compat';
        style.textContent = 'video, iframe { transform: none !important; max-width: 100% !important; border: none !important; }';
        (document.head || document.documentElement).appendChild(style);
        if (!HTMLVideoElement.prototype.webkitEnterFullScreen) {
            HTMLVideoElement.prototype.webkitEnterFullScreen = function() {
                if (this.requestFullscreen) this.requestFullscreen().catch(() => {});
                else if (this.webkitRequestFullScreen) this.webkitRequestFullScreen();
            };
            HTMLVideoElement.prototype.webkitEnterFullscreen = HTMLVideoElement.prototype.webkitEnterFullScreen;
        }
        const updateViewport = () => {
            document.documentElement.style.setProperty('--movies-vh', (window.innerHeight / 100) + 'px');
            if (document.body) {
                document.body.style.setProperty('position', 'relative', 'important');
                document.body.style.setProperty('height', window.innerHeight + 'px', 'important');
                document.body.style.setProperty('min-height', window.innerHeight + 'px', 'important');
            }
        };
        updateViewport();
        window.addEventListener('resize', updateViewport);
    })();
""".trimIndent()

private const val DESKTOP_USER_AGENT =
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 " +
        "(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"

private const val IOS_COMPATIBILITY_USER_AGENT =
    "Mozilla/5.0 (iPad; CPU OS 18_6 like Mac OS X) AppleWebKit/605.1.15 " +
        "(KHTML, like Gecko) Version/18.6 Mobile/15E148 Safari/604.1"

private fun playerUserAgent(url: String): String {
    return if (url.contains("moviesapi.to") || url.contains("moviesapi.vip")) {
        IOS_COMPATIBILITY_USER_AGENT
    } else {
        DESKTOP_USER_AGENT
    }
}

private fun Context.findActivity(): Activity? {
    var ctx = this
    while (ctx is ContextWrapper) {
        if (ctx is Activity) return ctx
        ctx = ctx.baseContext
    }
    return null
}

private data class MediaRequest(val url: String, val reloadKey: Int)

/**
 * Overlay View rendered directly above SurfaceView (translationZ = 100f).
 * Intercepts D-pad keys, coordinates cursor drawing, handles edge scrolling,
 * and synthesizes touch events into the fullscreen player.
 */
private class TvCursorOverlayView(
    context: Context,
    private val inputViewProvider: () -> View?,
    private val onScroll: (Double) -> Unit,
    private val onExitFullscreen: () -> Unit,
    private val onExitFocus: () -> Unit,
    private val isFullscreenProvider: () -> Boolean,
) : View(context) {
    private val density = resources.displayMetrics.density
    private val cursorRadius = 10f * density
    private val cursorOutline = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = AndroidColor.BLACK
        style = Paint.Style.FILL
    }
    private val cursorFill = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = AndroidColor.WHITE
        style = Paint.Style.FILL
    }
    private val focusOutline = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = AndroidColor.rgb(255, 213, 79)
        style = Paint.Style.STROKE
        strokeWidth = 3f * density
    }
    private var cursorX = 0f
    private var cursorY = 0f
    private var pointerDownTime = 0L
    private var isFullscreen = false
    private var releasingFocusToApp = false

    init {
        setWillNotDraw(false)
        isFocusable = true
        isFocusableInTouchMode = true
    }

    fun setFullscreenState(fullscreen: Boolean) {
        isFullscreen = fullscreen
        invalidate()
    }

    override fun onSizeChanged(width: Int, height: Int, oldWidth: Int, oldHeight: Int) {
        super.onSizeChanged(width, height, oldWidth, oldHeight)
        if (cursorX == 0f && cursorY == 0f) {
            cursorX = width / 2f
            cursorY = height / 2f
        } else if (oldWidth > 0 && oldHeight > 0) {
            cursorX = (cursorX / oldWidth * width).coerceIn(cursorRadius, width - cursorRadius)
            cursorY = (cursorY / oldHeight * height).coerceIn(cursorRadius, height - cursorRadius)
        }
    }

    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        when (event.keyCode) {
            KeyEvent.KEYCODE_BACK -> {
                if (event.action == KeyEvent.ACTION_DOWN) {
                    if (isFullscreenProvider()) {
                        onExitFullscreen()
                        return true
                    }
                    releasingFocusToApp = true
                    clearFocus()
                    onExitFocus()
                }
                return true
            }
            KeyEvent.KEYCODE_DPAD_UP -> {
                if (event.action == KeyEvent.ACTION_DOWN) {
                    if (cursorY <= cursorRadius + 15f * density && !isFullscreenProvider()) {
                        releasingFocusToApp = true
                        clearFocus()
                        onExitFocus()
                        return true
                    }
                    moveCursor(event.keyCode)
                }
                return true
            }
            KeyEvent.KEYCODE_DPAD_LEFT,
            KeyEvent.KEYCODE_DPAD_RIGHT,
            KeyEvent.KEYCODE_DPAD_DOWN -> {
                if (event.action == KeyEvent.ACTION_DOWN) moveCursor(event.keyCode)
                return true
            }
            KeyEvent.KEYCODE_DPAD_CENTER,
            KeyEvent.KEYCODE_ENTER,
            KeyEvent.KEYCODE_NUMPAD_ENTER -> {
                sendPointerEvent(event.action)
                return true
            }
        }
        return super.dispatchKeyEvent(event)
    }

    override fun onFocusChanged(focused: Boolean, direction: Int, previouslyFocusedRect: android.graphics.Rect?) {
        super.onFocusChanged(focused, direction, previouslyFocusedRect)
        if (focused) {
            releasingFocusToApp = false
        } else if (!releasingFocusToApp && isAttachedToWindow) {
            // The player may request focus after handling the synthetic Select touch.
            // Keep remote input and the visible cursor on this overlay unless the
            // user explicitly navigated back to the native controls.
            post { requestFocus() }
        }
        invalidate()
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        if (!hasFocus()) return
        if (!isFullscreen) {
            val inset = focusOutline.strokeWidth / 2f
            canvas.drawRect(inset, inset, width - inset, height - inset, focusOutline)
        }
        canvas.drawCircle(cursorX, cursorY, cursorRadius + 3f * density, cursorOutline)
        canvas.drawCircle(cursorX, cursorY, cursorRadius, cursorFill)
    }

    private fun moveCursor(keyCode: Int) {
        val step = 18f * density
        when (keyCode) {
            KeyEvent.KEYCODE_DPAD_LEFT -> cursorX -= step
            KeyEvent.KEYCODE_DPAD_RIGHT -> cursorX += step
            KeyEvent.KEYCODE_DPAD_UP -> {
                cursorY -= step
                if (cursorY <= cursorRadius + 20f * density) {
                    onScroll(-step.toDouble())
                }
            }
            KeyEvent.KEYCODE_DPAD_DOWN -> {
                cursorY += step
                if (cursorY >= height - cursorRadius - 20f * density) {
                    onScroll(step.toDouble())
                }
            }
        }
        cursorX = cursorX.coerceIn(cursorRadius, width - cursorRadius)
        cursorY = cursorY.coerceIn(cursorRadius, height - cursorRadius)
        invalidate()
    }

    private fun sendPointerEvent(action: Int) {
        if (action != KeyEvent.ACTION_DOWN && action != KeyEvent.ACTION_UP) return
        val inputView = inputViewProvider() ?: return
        val now = SystemClock.uptimeMillis()
        if (action == KeyEvent.ACTION_DOWN) pointerDownTime = now
        val motionAction = if (action == KeyEvent.ACTION_DOWN) MotionEvent.ACTION_DOWN else MotionEvent.ACTION_UP
        val motion = MotionEvent.obtain(pointerDownTime, now, motionAction, cursorX, cursorY, 0)
        inputView.dispatchTouchEvent(motion)
        motion.recycle()
    }
}

/** Stable remote cursor for the native WebView comparison path. */
private class TvCursorWebView(
    context: Context,
    private val onExitFocus: () -> Unit,
) : WebView(context) {
    private val density = resources.displayMetrics.density
    private val cursorRadius = 10f * density
    private val outline = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = AndroidColor.BLACK }
    private val fill = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = AndroidColor.WHITE }
    private val focusOutline = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = AndroidColor.rgb(255, 213, 79)
        style = Paint.Style.STROKE
        strokeWidth = 3f * density
    }
    private var cursorX = 0f
    private var cursorY = 0f
    private var pointerDownTime = 0L

    init {
        setWillNotDraw(false)
        isFocusable = true
        isFocusableInTouchMode = true
    }

    override fun onSizeChanged(width: Int, height: Int, oldWidth: Int, oldHeight: Int) {
        super.onSizeChanged(width, height, oldWidth, oldHeight)
        if (cursorX == 0f && cursorY == 0f) {
            cursorX = width / 2f
            cursorY = height / 2f
        } else if (oldWidth > 0 && oldHeight > 0) {
            cursorX = (cursorX / oldWidth * width).coerceIn(cursorRadius, width - cursorRadius)
            cursorY = (cursorY / oldHeight * height).coerceIn(cursorRadius, height - cursorRadius)
        }
    }

    override fun dispatchKeyEvent(event: KeyEvent): Boolean = when (event.keyCode) {
        KeyEvent.KEYCODE_BACK -> {
            if (event.action == KeyEvent.ACTION_DOWN) {
                clearFocus()
                onExitFocus()
            }
            true
        }
        KeyEvent.KEYCODE_DPAD_UP,
        KeyEvent.KEYCODE_DPAD_LEFT,
        KeyEvent.KEYCODE_DPAD_RIGHT,
        KeyEvent.KEYCODE_DPAD_DOWN -> {
            if (event.action == KeyEvent.ACTION_DOWN) {
                if (event.keyCode == KeyEvent.KEYCODE_DPAD_UP && cursorY <= cursorRadius + 15f * density && scrollY == 0) {
                    clearFocus()
                    onExitFocus()
                } else {
                    moveCursor(event.keyCode)
                }
            }
            true
        }
        KeyEvent.KEYCODE_DPAD_CENTER,
        KeyEvent.KEYCODE_ENTER,
        KeyEvent.KEYCODE_NUMPAD_ENTER -> {
            sendPointerEvent(event.action)
            true
        }
        else -> super.dispatchKeyEvent(event)
    }

    override fun onFocusChanged(focused: Boolean, direction: Int, previouslyFocusedRect: android.graphics.Rect?) {
        super.onFocusChanged(focused, direction, previouslyFocusedRect)
        invalidate()
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        if (!hasFocus()) return
        val inset = focusOutline.strokeWidth / 2f
        canvas.drawRect(inset, inset, width - inset, height - inset, focusOutline)
        canvas.drawCircle(cursorX, cursorY, cursorRadius + 3f * density, outline)
        canvas.drawCircle(cursorX, cursorY, cursorRadius, fill)
    }

    private fun moveCursor(keyCode: Int) {
        val step = 18f * density
        when (keyCode) {
            KeyEvent.KEYCODE_DPAD_LEFT -> cursorX -= step
            KeyEvent.KEYCODE_DPAD_RIGHT -> cursorX += step
            KeyEvent.KEYCODE_DPAD_UP -> {
                cursorY -= step
                if (cursorY <= cursorRadius + 20f * density && scrollY > 0) scrollBy(0, -step.toInt())
            }
            KeyEvent.KEYCODE_DPAD_DOWN -> {
                cursorY += step
                if (cursorY >= height - cursorRadius - 20f * density) scrollBy(0, step.toInt())
            }
        }
        cursorX = cursorX.coerceIn(cursorRadius, width - cursorRadius)
        cursorY = cursorY.coerceIn(cursorRadius, height - cursorRadius)
        invalidate()
    }

    private fun sendPointerEvent(action: Int) {
        if (action != KeyEvent.ACTION_DOWN && action != KeyEvent.ACTION_UP) return
        val now = SystemClock.uptimeMillis()
        if (action == KeyEvent.ACTION_DOWN) pointerDownTime = now
        val motionAction = if (action == KeyEvent.ACTION_DOWN) MotionEvent.ACTION_DOWN else MotionEvent.ACTION_UP
        val motion = MotionEvent.obtain(pointerDownTime, now, motionAction, cursorX, cursorY, 0)
        super.dispatchTouchEvent(motion)
        motion.recycle()
    }
}
