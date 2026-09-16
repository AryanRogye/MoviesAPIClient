package com.aryanrogye.movies_shared.web

import android.annotation.SuppressLint
import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color as AndroidColor
import android.graphics.Paint
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.view.KeyEvent
import android.view.MotionEvent
import android.view.View
import android.webkit.JavascriptInterface
import android.webkit.WebChromeClient
import android.webkit.CookieManager
import android.webkit.WebResourceRequest
import android.webkit.WebResourceResponse
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
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
import java.io.ByteArrayInputStream
import android.app.Activity
import android.content.ContextWrapper
import android.view.ViewGroup
import android.widget.FrameLayout
import androidx.compose.runtime.mutableIntStateOf
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat

@SuppressLint("SetJavaScriptEnabled")
@Composable
fun MediaWebView(
    url: String,
    reloadKey: Int,
    blockingService: AndroidBlockingService,
    modifier: Modifier = Modifier,
    onExitFocus: () -> Unit,
    onError: (String) -> Unit,
) {
    val context = LocalContext.current
    val activity = remember(context) { context.findActivity() }
    var progress by remember { mutableFloatStateOf(0f) }
    var isLoading by remember { mutableStateOf(false) }
    var webView by remember { mutableStateOf<WebView?>(null) }
    var customView by remember { mutableStateOf<View?>(null) }
    var customViewCallback by remember { mutableStateOf<WebChromeClient.CustomViewCallback?>(null) }
    var documentHost by remember { mutableStateOf<String?>(null) }
    val stallHandler = remember { Handler(Looper.getMainLooper()) }
    var stallWatchdog by remember { mutableStateOf<Runnable?>(null) }

    fun cancelStallWatchdog() {
        stallWatchdog?.let { stallHandler.removeCallbacks(it) }
        stallWatchdog = null
    }

    fun scheduleStallWatchdog() {
        cancelStallWatchdog()
        val runnable = Runnable {
            onError(
                "This source didn't start playing within ${STALL_TIMEOUT_MS / 1000}s. " +
                    "It may be unavailable right now — try Reload or switch server."
            )
        }
        stallWatchdog = runnable
        stallHandler.postDelayed(runnable, STALL_TIMEOUT_MS)
    }

    fun closeFullscreen() {
        val cv = customView ?: return
        (cv.parent as? ViewGroup)?.removeView(cv)
        activity?.let { act ->
            WindowCompat.setDecorFitsSystemWindows(act.window, true)
            val controller = WindowInsetsControllerCompat(act.window, act.window.decorView)
            controller.show(WindowInsetsCompat.Type.systemBars())
            controller.systemBarsBehavior = WindowInsetsControllerCompat.BEHAVIOR_DEFAULT
        }
        customViewCallback?.onCustomViewHidden()
        customViewCallback = null
        customView = null
        webView?.requestFocus()
    }

    BackHandler(enabled = customView != null) {
        closeFullscreen()
    }

    Box(modifier = modifier.background(Color.Black)) {
        AndroidView<TvCursorWebView>(
            modifier = Modifier.fillMaxSize(),
            factory = {
                TvCursorWebView(context, onExitFocus).apply {
                    webView = this
                    setTag(URL_KEY_TAG, MediaRequest(url, reloadKey))
                    setBackgroundColor(android.graphics.Color.BLACK)
                    isFocusable = true
                    isFocusableInTouchMode = true
                    settings.javaScriptEnabled = true
                    settings.domStorageEnabled = true
                    settings.databaseEnabled = true
                    settings.useWideViewPort = false
                    settings.loadWithOverviewMode = false
                    settings.allowFileAccess = true
                    settings.allowContentAccess = true
                    settings.cacheMode = WebSettings.LOAD_DEFAULT
                    CookieManager.getInstance().setAcceptCookie(true)
                    CookieManager.getInstance().setAcceptThirdPartyCookies(this, true)
                    settings.mediaPlaybackRequiresUserGesture = false
                    settings.javaScriptCanOpenWindowsAutomatically = false
                    settings.setSupportMultipleWindows(true)
                    settings.mixedContentMode = WebSettings.MIXED_CONTENT_ALWAYS_ALLOW
                    // Use a desktop user agent so streaming sites serve a landscape-
                    // friendly layout that fits Fire TV. The iOS iPad UA caused sites
                    // to serve mobile/portrait layouts that were clipped or rotated.
                    settings.userAgentString = playerUserAgent(url)
                    addJavascriptInterface(
                        PlaybackWatchdogBridge { cancelStallWatchdog() },
                        PLAYBACK_WATCHDOG_BRIDGE_NAME,
                    )

                    webViewClient = object : WebViewClient() {
                        override fun shouldOverrideUrlLoading(view: WebView, request: WebResourceRequest): Boolean {
                            val requestUrl = request.url.toString()
                            val scheme = request.url.scheme?.lowercase()
                            // Allow about:blank and about:srcdoc for sub-frames (player iframes).
                            if (requestUrl == "about:blank" || requestUrl == "about:srcdoc") return false
                            // Block non-HTTP(S) schemes.
                            return scheme != "http" && scheme != "https"
                        }

                        override fun shouldInterceptRequest(view: WebView, request: WebResourceRequest): WebResourceResponse? {
                            return if (blockingService.shouldBlock(request.url.toString(), documentHost)) {
                                WebResourceResponse("text/plain", "utf-8", 204, "Blocked", emptyMap(), ByteArrayInputStream(ByteArray(0)))
                            } else null
                        }

                        override fun onPageStarted(view: WebView, pageUrl: String, favicon: Bitmap?) {
                            documentHost = runCatching { android.net.Uri.parse(pageUrl).host }.getOrNull()
                            isLoading = true
                        }

                        override fun onPageFinished(view: WebView, pageUrl: String) {
                            isLoading = false
                            view.evaluateJavascript(blockingService.popupScript, null)
                            view.evaluateJavascript(PLAYER_COMPATIBILITY_SCRIPT, null)
                            view.evaluateJavascript(VIEWPORT_UNIT_POLYFILL_SCRIPT, null)
                            view.evaluateJavascript(PLAYBACK_WATCHDOG_SCRIPT, null)
                            view.requestFocus()
                            scheduleStallWatchdog()
                        }

                        override fun onReceivedError(view: WebView, request: WebResourceRequest, error: android.webkit.WebResourceError) {
                            if (request.isForMainFrame && error.errorCode != ERROR_HOST_LOOKUP) {
                                cancelStallWatchdog()
                                onError(error.description.toString())
                            }
                        }
                    }

                    webChromeClient = object : WebChromeClient() {
                        override fun onProgressChanged(view: WebView, newProgress: Int) {
                            progress = newProgress / 100f
                            isLoading = newProgress < 100
                        }

                        override fun onCreateWindow(view: WebView?, isDialog: Boolean, isUserGesture: Boolean, resultMsg: android.os.Message?): Boolean {
                            // Match the iOS policy: a real anchor activated by the user
                            // may replace the current tab; scripted popup windows never do.
                            val hit = view?.hitTestResult
                            val isLink = hit?.type == WebView.HitTestResult.SRC_ANCHOR_TYPE ||
                                hit?.type == WebView.HitTestResult.SRC_IMAGE_ANCHOR_TYPE
                            val target = hit?.extra
                            if (isUserGesture && isLink && target != null &&
                                (target.startsWith("https://") || target.startsWith("http://"))) {
                                view.loadUrl(target)
                            }
                            return false
                        }

                        override fun onShowCustomView(view: View, callback: CustomViewCallback) {
                            cancelStallWatchdog()
                            if (customView != null) {
                                closeFullscreen()
                            }
                            customView = view
                            customViewCallback = callback

                            activity?.let { act ->
                                val decorGroup = act.window.decorView as? ViewGroup ?: return@let

                                val params = FrameLayout.LayoutParams(
                                    ViewGroup.LayoutParams.MATCH_PARENT,
                                    ViewGroup.LayoutParams.MATCH_PARENT
                                )
                                view.setBackgroundColor(android.graphics.Color.BLACK)
                                // Ensure the fullscreen view renders above the Compose layer.
                                view.translationZ = 999f
                                decorGroup.addView(view, params)

                                // Use modern immersive mode via WindowInsetsControllerCompat.
                                WindowCompat.setDecorFitsSystemWindows(act.window, false)
                                val controller = WindowInsetsControllerCompat(act.window, act.window.decorView)
                                controller.hide(WindowInsetsCompat.Type.systemBars())
                                controller.systemBarsBehavior = WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE

                                view.isFocusable = true
                                view.isFocusableInTouchMode = true
                                view.requestFocus()
                                view.setOnKeyListener { _, keyCode, keyEvent ->
                                    if (keyCode == KeyEvent.KEYCODE_BACK && keyEvent.action == KeyEvent.ACTION_UP) {
                                        closeFullscreen()
                                        true
                                    } else false
                                }
                            }
                        }

                        override fun onHideCustomView() = closeFullscreen()
                    }
                    loadUrl(url)
                }
            },
            update = { view ->
                val request = MediaRequest(url, reloadKey)
                if (view.getTag(URL_KEY_TAG) != request) {
                    view.setTag(URL_KEY_TAG, request)
                    view.settings.userAgentString = playerUserAgent(url)
                    view.loadUrl(url)
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
            cancelStallWatchdog()
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

private const val URL_KEY_TAG = 0x4d415049

// How long to wait after a page finishes loading for a <video> to actually start
// playing (or for native fullscreen to engage) before surfacing a clear error
// instead of leaving the user staring at an infinite spinner.
private const val STALL_TIMEOUT_MS = 25_000L
private const val PLAYBACK_WATCHDOG_BRIDGE_NAME = "MoviesPlaybackWatchdog"

// Exposed to the page as window.MoviesPlaybackWatchdog.reportPlaying(). Called
// from PLAYBACK_WATCHDOG_SCRIPT once a <video> element actually starts playing,
// so the stall watchdog can stand down instead of firing a false-positive error.
private class PlaybackWatchdogBridge(private val onPlaying: () -> Unit) {
    private val mainHandler = Handler(Looper.getMainLooper())

    @JavascriptInterface
    fun reportPlaying() {
        mainHandler.post(onPlaying)
    }
}

// Desktop Chrome user agent for landscape-friendly layouts on Fire TV.
private const val DESKTOP_USER_AGENT =
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 " +
        "(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"

// iPad Safari user agent as a fallback for providers that require a mobile identity
// (e.g. Cloudflare Turnstile, certain bot-detection on moviesapi.to).
private const val IOS_COMPATIBILITY_USER_AGENT =
    "Mozilla/5.0 (iPad; CPU OS 18_6 like Mac OS X) AppleWebKit/605.1.15 " +
        "(KHTML, like Gecko) Version/18.6 Mobile/15E148 Safari/604.1"

private fun playerUserAgent(url: String): String {
    // MoviesAPI's bot detection requires a mobile/iPad identity.
    // VidFast and other providers work best with a desktop UA on Fire TV
    // so they serve a landscape-friendly layout.
    return if (url.contains("moviesapi.to") || url.contains("moviesapi.vip")) {
        IOS_COMPATIBILITY_USER_AGENT
    } else {
        DESKTOP_USER_AGENT
    }
}

private val PLAYER_COMPATIBILITY_SCRIPT = """
    (() => {
        if (!document.getElementById('movies-tv-compat')) {
            const style = document.createElement('style');
            style.id = 'movies-tv-compat';
            style.textContent = `
                video, iframe {
                    transform: none !important;
                    max-width: 100% !important;
                    border: none !important;
                }
            `;
            (document.head || document.documentElement).appendChild(style);
        }
        /* Polyfill Safari-specific fullscreen API for sites that call it */
        if (!HTMLVideoElement.prototype.webkitEnterFullScreen) {
            HTMLVideoElement.prototype.webkitEnterFullScreen = function() {
                if (this.requestFullscreen) {
                    this.requestFullscreen().catch(() => {});
                } else if (this.webkitRequestFullScreen) {
                    this.webkitRequestFullScreen();
                }
            };
            HTMLVideoElement.prototype.webkitEnterFullscreen = HTMLVideoElement.prototype.webkitEnterFullScreen;
        }
        /* Scroll the player into view once it appears */
        const scrollToPlayer = () => {
            const el = document.querySelector('video, iframe[src*="player"], iframe[src*="embed"], iframe[allowfullscreen]');
            if (el) { el.scrollIntoView({ block: 'start', behavior: 'smooth' }); return true; }
            return false;
        };
        if (!scrollToPlayer()) {
            let attempts = 0;
            const poll = setInterval(() => {
                if (scrollToPlayer() || ++attempts > 30) clearInterval(poll);
            }, 500);
        }
    })();
""".trimIndent()

// This Fire TV WebView build's internal viewport height (the "initial containing
// block" Blink uses for both the `vh` family of CSS units and for resolving
// percentage heights on elements with no positioned ancestor) is stuck at 0,
// even though `window.innerHeight` reports the real, correct value. Verified
// directly: a bare `<div style="height:100vh">` on a blank page measures 0px,
// and so does a `position:absolute` div using `inset:0; height:100%` with no
// positioned ancestor — both rely on that same broken internal value. Sites
// that size full-screen overlays this way end up with collapsed, zero-height
// containers whose centered children render half off the top of the screen.
// Two independent fixes, since the two symptoms don't share a resolution path:
// 1. Rewrite raw `vh`/`svh`/`lvh`/`dvh` tokens in every stylesheet rule to a
//    `--movies-vh` custom property derived from `window.innerHeight`.
// 2. Give `<body>` a real pixel height and `position: relative` so it becomes
//    the containing block for absolutely-positioned descendants instead of the
//    broken initial containing block — fixes `height:100%`/`inset:0` overlays.
private val VIEWPORT_UNIT_POLYFILL_SCRIPT = """
    (() => {
        if (window.__moviesViewportUnitPolyfill) return;
        window.__moviesViewportUnitPolyfill = true;

        const unitRe = /(-?[0-9]*\.?[0-9]+)(dvh|svh|lvh|vh)\b/gi;

        const patchValue = (value) => {
            if (!value || value.indexOf('vh') === -1) return value;
            return value.replace(unitRe, (match, num) => 'calc(' + num + ' * var(--movies-vh, 1vh))');
        };

        const patchStyleDeclaration = (style) => {
            for (let i = style.length - 1; i >= 0; i--) {
                const prop = style[i];
                const val = style.getPropertyValue(prop);
                if (val && val.indexOf('vh') !== -1) {
                    const priority = style.getPropertyPriority(prop);
                    style.setProperty(prop, patchValue(val), priority);
                }
            }
        };

        const patchRules = (rules) => {
            if (!rules) return;
            for (let i = 0; i < rules.length; i++) {
                const rule = rules[i];
                if (rule.style) patchStyleDeclaration(rule.style);
                if (rule.cssRules) patchRules(rule.cssRules);
            }
        };

        const patchAllSheets = () => {
            for (let i = 0; i < document.styleSheets.length; i++) {
                try {
                    patchRules(document.styleSheets[i].cssRules);
                } catch (e) {
                    /* cross-origin stylesheet; nothing we can do */
                }
            }
            document.querySelectorAll('[style*="vh"]').forEach((el) => patchStyleDeclaration(el.style));
        };

        const updateVhVariable = () => {
            document.documentElement.style.setProperty('--movies-vh', (window.innerHeight / 100) + 'px');
        };

        const fixContainingBlock = () => {
            const body = document.body;
            if (!body) return;
            if (getComputedStyle(body).position === 'static') {
                body.style.setProperty('position', 'relative', 'important');
            }
            body.style.setProperty('height', window.innerHeight + 'px', 'important');
            body.style.setProperty('min-height', window.innerHeight + 'px', 'important');
        };

        updateVhVariable();
        fixContainingBlock();
        patchAllSheets();

        window.addEventListener('resize', () => {
            updateVhVariable();
            fixContainingBlock();
            patchAllSheets();
        });

        new MutationObserver((records) => {
            const addedStyleNode = records.some((record) =>
                Array.from(record.addedNodes).some(
                    (node) => node.nodeType === 1 && (node.tagName === 'STYLE' || node.tagName === 'LINK')
                )
            );
            if (addedStyleNode) patchAllSheets();
        }).observe(document.documentElement, { childList: true, subtree: true });

        // Catch rules (and a body element that didn't exist yet) inserted by hydration
        // shortly after our own injection.
        [300, 1000, 3000].forEach((delay) => {
            setTimeout(() => {
                fixContainingBlock();
                patchAllSheets();
            }, delay);
        });
    })();
""".trimIndent()

// Reports the first real sign of video playback (or the lack of one) to the
// native side so MediaWebView's stall watchdog knows whether to fire. Covers
// both a same-origin <video> that's already playing and ones added later by
// client-side JS (both MoviesAPI and VidFast build their player UI after an
// async fetch resolves).
private val PLAYBACK_WATCHDOG_SCRIPT = """
    (() => {
        if (window.__moviesPlaybackWatchdog) return;
        window.__moviesPlaybackWatchdog = true;

        const reportPlaying = () => {
            if (window.$PLAYBACK_WATCHDOG_BRIDGE_NAME) {
                window.$PLAYBACK_WATCHDOG_BRIDGE_NAME.reportPlaying();
            }
        };

        const watch = (video) => {
            if (video.__moviesWatched) return;
            video.__moviesWatched = true;
            if (video.readyState >= 2 || !video.paused) {
                reportPlaying();
                return;
            }
            const onPlaying = () => reportPlaying();
            video.addEventListener('playing', onPlaying, { once: true });
            video.addEventListener('loadeddata', onPlaying, { once: true });
            video.addEventListener('timeupdate', onPlaying, { once: true });
        };

        document.querySelectorAll('video').forEach(watch);

        new MutationObserver((records) => {
            records.forEach((record) => {
                record.addedNodes.forEach((node) => {
                    if (!(node instanceof Element)) return;
                    if (node.tagName === 'VIDEO') watch(node);
                    node.querySelectorAll && node.querySelectorAll('video').forEach(watch);
                });
            });
        }).observe(document.documentElement, { childList: true, subtree: true });
    })();
""".trimIndent()

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
 * Fire TV's WebView has no useful mouse pointer. This adapter gives the
 * remote a stable cursor: arrows move, Select taps, and Back returns focus
 * to the native controls without changing web history.
 */
private class TvCursorWebView(
    context: Context,
    private val leaveCursorMode: () -> Unit,
) : WebView(context) {
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

    init {
        setWillNotDraw(false)
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
                    clearFocus()
                    leaveCursorMode()
                }
                return true
            }
            KeyEvent.KEYCODE_DPAD_UP -> {
                if (event.action == KeyEvent.ACTION_DOWN) {
                    if (cursorY <= cursorRadius + 15f * density && scrollY == 0) {
                        clearFocus()
                        leaveCursorMode()
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
        invalidate()
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        if (!hasFocus()) return
        val inset = focusOutline.strokeWidth / 2f
        canvas.drawRect(inset, inset, width - inset, height - inset, focusOutline)
        canvas.drawCircle(cursorX, cursorY, cursorRadius + 3f * density, cursorOutline)
        canvas.drawCircle(cursorX, cursorY, cursorRadius, cursorFill)
    }

    private fun moveCursor(keyCode: Int) {
        val step = 34f * density
        when (keyCode) {
            KeyEvent.KEYCODE_DPAD_LEFT -> cursorX -= step
            KeyEvent.KEYCODE_DPAD_RIGHT -> cursorX += step
            KeyEvent.KEYCODE_DPAD_UP -> {
                cursorY -= step
                if (cursorY <= cursorRadius + 20f * density && scrollY > 0) {
                    scrollBy(0, -step.toInt())
                }
            }
            KeyEvent.KEYCODE_DPAD_DOWN -> {
                cursorY += step
                if (cursorY >= height - cursorRadius - 20f * density) {
                    scrollBy(0, step.toInt())
                }
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
        dispatchTouchEvent(motion)
        motion.recycle()
    }
}
