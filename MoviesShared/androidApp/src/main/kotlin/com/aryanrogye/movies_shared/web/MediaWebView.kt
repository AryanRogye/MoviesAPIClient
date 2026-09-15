package com.aryanrogye.movies_shared.web

import android.annotation.SuppressLint
import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color as AndroidColor
import android.graphics.Paint
import android.os.SystemClock
import android.view.KeyEvent
import android.view.MotionEvent
import android.view.View
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
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import java.io.ByteArrayInputStream

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
    var progress by remember { mutableFloatStateOf(0f) }
    var isLoading by remember { mutableStateOf(false) }
    var webView by remember { mutableStateOf<WebView?>(null) }
    var customView by remember { mutableStateOf<View?>(null) }
    var customViewCallback by remember { mutableStateOf<WebChromeClient.CustomViewCallback?>(null) }
    var documentHost by remember { mutableStateOf<String?>(null) }

    fun closeFullscreen() {
        customViewCallback?.onCustomViewHidden()
        customViewCallback = null
        customView = null
    }

    BackHandler(enabled = customView != null) {
        closeFullscreen()
    }

    Box(modifier = modifier.background(Color.Black)) {
        AndroidView(
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
                    CookieManager.getInstance().setAcceptCookie(true)
                    CookieManager.getInstance().setAcceptThirdPartyCookies(this, true)
                    settings.mediaPlaybackRequiresUserGesture = false
                    settings.javaScriptCanOpenWindowsAutomatically = false
                    settings.setSupportMultipleWindows(true)
                    settings.mixedContentMode = WebSettings.MIXED_CONTENT_NEVER_ALLOW
                    // VidFast rejects Amazon WebView through a Chrome-specific
                    // timing gate before it ever requests the stream. The iPad
                    // Safari identity follows the same non-Chrome path as the
                    // working iOS client while leaving rendering native to AWV.
                    settings.userAgentString = playerUserAgent(url)

                    webViewClient = object : WebViewClient() {
                        override fun shouldOverrideUrlLoading(view: WebView, request: WebResourceRequest): Boolean {
                            val scheme = request.url.scheme?.lowercase()
                            if (!request.isForMainFrame && request.url.toString() in setOf("about:blank", "about:srcdoc")) return false
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
                            view.requestFocus()
                        }

                        override fun onReceivedError(view: WebView, request: WebResourceRequest, error: android.webkit.WebResourceError) {
                            if (request.isForMainFrame && error.errorCode != ERROR_HOST_LOOKUP) {
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
                            customViewCallback?.onCustomViewHidden()
                            customView = view
                            customViewCallback = callback
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

        customView?.let { fullscreen ->
            Dialog(
                onDismissRequest = { closeFullscreen() },
                properties = DialogProperties(
                    usePlatformDefaultWidth = false,
                    decorFitsSystemWindows = false,
                    dismissOnClickOutside = false,
                ),
            ) {
                AndroidView(factory = { fullscreen }, modifier = Modifier.fillMaxSize().background(Color.Black))
            }
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

private const val URL_KEY_TAG = 0x4d415049
// Keep a consistent, genuine browser identity for MoviesAPI's embedded
// verification flow. Only VidFast needs the Safari compatibility workaround.
private fun playerUserAgent(url: String): String? =
    if (android.net.Uri.parse(url).host == "vidfast.vc") IOS_COMPATIBILITY_USER_AGENT else null
// The Safari identity selects the provider's iOS fullscreen branch. Bridge
// that entry point to Chromium's fullscreen API and correct percentage-height
// layouts whose root otherwise collapses inside Amazon WebView.
private val PLAYER_COMPATIBILITY_SCRIPT = """
    (() => {
        if (!document.getElementById('movies-tv-viewport')) {
            const style = document.createElement('style');
            style.id = 'movies-tv-viewport';
            style.textContent = 'html,body{width:100%!important;height:100%!important;min-height:100vh!important;margin:0!important}';
            document.head.appendChild(style);
        }
        if (!HTMLVideoElement.prototype.webkitEnterFullScreen) {
            HTMLVideoElement.prototype.webkitEnterFullScreen = function() {
                this.requestFullscreen().catch(() => {});
            };
            HTMLVideoElement.prototype.webkitEnterFullscreen = HTMLVideoElement.prototype.webkitEnterFullScreen;
        }
    })();
""".trimIndent()
private const val IOS_COMPATIBILITY_USER_AGENT =
    "Mozilla/5.0 (iPad; CPU OS 18_6 like Mac OS X) AppleWebKit/605.1.15 " +
        "(KHTML, like Gecko) Version/18.6 Mobile/15E148 Safari/604.1"
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
            KeyEvent.KEYCODE_DPAD_LEFT,
            KeyEvent.KEYCODE_DPAD_RIGHT,
            KeyEvent.KEYCODE_DPAD_UP,
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
            KeyEvent.KEYCODE_DPAD_UP -> cursorY -= step
            KeyEvent.KEYCODE_DPAD_DOWN -> cursorY += step
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
