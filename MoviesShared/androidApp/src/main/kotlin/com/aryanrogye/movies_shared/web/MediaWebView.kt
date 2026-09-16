package com.aryanrogye.movies_shared.web

import android.app.Activity
import android.content.Context
import android.content.ContextWrapper
import android.annotation.SuppressLint
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color as AndroidColor
import android.graphics.Paint
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.util.Log
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
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
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
import org.mozilla.geckoview.AllowOrDeny
import org.mozilla.geckoview.ContentBlocking
import org.mozilla.geckoview.GeckoResult
import org.mozilla.geckoview.GeckoRuntime
import org.mozilla.geckoview.GeckoRuntimeSettings
import org.mozilla.geckoview.GeckoSession
import org.mozilla.geckoview.GeckoSessionSettings
import org.mozilla.geckoview.GeckoView
import org.mozilla.geckoview.PanZoomController
import org.mozilla.geckoview.ScreenLength
import org.mozilla.geckoview.WebRequestError

private const val TAG = "MoviesGeckoView"
private const val EXTENSION_ID = "movies-player@aryanrogye.com"
private const val EXTENSION_LOCATION = "resource://android/assets/extensions/player/"

enum class PlaybackEngine { GECKO, NATIVE_WEBVIEW }

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

/**
 * Fire TV has very little headroom for a full desktop-style browser process
 * graph. Gecko's default Fission configuration was creating tab processes for
 * each embedded frame, causing sustained major page faults and ultimately an
 * Android input-dispatch ANR. Runtime-only settings must be supplied before
 * Gecko starts, so this provider creates exactly one tuned runtime per app
 * process rather than using GeckoRuntime.getDefault().
 */
private object MoviesGeckoRuntime {
    private var runtime: GeckoRuntime? = null

    fun get(context: Context): GeckoRuntime = synchronized(this) {
        runtime ?: GeckoRuntime.create(
            context.applicationContext,
            GeckoRuntimeSettings.Builder()
                .fissionEnabled(false)
                .lowMemoryDetection(true)
                .extensionsProcessEnabled(false)
                .remoteDebuggingEnabled(false)
                .consoleOutput(false)
                .glMsaaLevel(0)
                .doubleTapZoomingEnabled(false)
                .inputAutoZoomEnabled(false)
                .forceUserScalableEnabled(false)
                .contentBlocking(
                    ContentBlocking.Settings.Builder()
                        .cookieBehavior(ContentBlocking.CookieBehavior.ACCEPT_ALL)
                        .enhancedTrackingProtectionLevel(ContentBlocking.EtpLevel.NONE)
                        .antiTracking(ContentBlocking.AntiTracking.NONE)
                        .build(),
                )
                .build(),
        ).also { runtime = it }
    }
}

@Composable
private fun GeckoMediaWebView(
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
    var isFullscreen by remember { mutableStateOf(false) }
    var geckoSession by remember { mutableStateOf<GeckoSession?>(null) }
    var rootPlayerContainer by remember { mutableStateOf<FrameLayout?>(null) }
    var cursorOverlayView by remember { mutableStateOf<TvCursorOverlayView?>(null) }
    var geckoViewRef by remember { mutableStateOf<GeckoView?>(null) }
    var documentHost by remember { mutableStateOf<String?>(null) }
    var recoveryGeneration by remember { mutableStateOf(0) }
    var recoveryAttempts by remember { mutableStateOf(0) }
    var restoreFullscreenAfterRecovery by remember { mutableStateOf(false) }
    fun updateFullscreen(fullScreen: Boolean) {
        isFullscreen = fullScreen
        cursorOverlayView?.setFullscreenState(fullScreen)
        activity?.let { act ->
            val playerView = rootPlayerContainer ?: return@let
            val decorGroup = act.window.decorView as? ViewGroup ?: return@let
            val controller = WindowInsetsControllerCompat(act.window, act.window.decorView)

            if (fullScreen) {
                (playerView.parent as? ViewGroup)?.removeView(playerView)
                val params = FrameLayout.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    ViewGroup.LayoutParams.MATCH_PARENT
                )
                playerView.translationZ = 9999f
                decorGroup.addView(playerView, params)

                WindowCompat.setDecorFitsSystemWindows(act.window, false)
                controller.hide(WindowInsetsCompat.Type.systemBars())
                controller.systemBarsBehavior = WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
                // The cursor owns D-pad input and must also own focus so it is
                // drawn above Gecko's TextureView in fullscreen.
                playerView.post { cursorOverlayView?.requestFocus() }
            } else {
                (playerView.parent as? ViewGroup)?.removeView(playerView)
                playerView.translationZ = 0f
                // Let Compose re-attach playerView in update/AndroidView
                WindowCompat.setDecorFitsSystemWindows(act.window, true)
                controller.show(WindowInsetsCompat.Type.systemBars())
                controller.systemBarsBehavior = WindowInsetsControllerCompat.BEHAVIOR_DEFAULT
                playerView.post { cursorOverlayView?.requestFocus() }
            }
        }
    }

    fun recoverSession(session: GeckoSession, reason: String) {
        // A content process is allowed to die independently of the app process.
        // Reusing that session is unsupported, but Firefox's Android engine keeps
        // its runtime and creates/restores a fresh session. Limit this to one
        // automatic attempt per requested URL so a bad provider cannot loop
        // forever and make the TV UI unresponsive.
        if (session !== geckoSession) return
        if (recoveryAttempts >= MAX_AUTOMATIC_SESSION_RECOVERIES) {
            onError("GeckoView process $reason after retrying the player")
            return
        }
        recoveryAttempts += 1
        restoreFullscreenAfterRecovery = isFullscreen
        if (isFullscreen) updateFullscreen(false)
        Log.w(TAG, "GeckoView process $reason; recreating session (attempt $recoveryAttempts)")
        recoveryGeneration += 1
    }

    BackHandler(enabled = isFullscreen) {
        geckoSession?.exitFullScreen()
    }

    val runtime = remember(context) {
        MoviesGeckoRuntime.get(context)
    }

    LaunchedEffect(runtime) {
        Log.i(TAG, "Ensuring built-in WebExtension: $EXTENSION_LOCATION")
        runtime.webExtensionController
            .ensureBuiltIn(EXTENSION_LOCATION, EXTENSION_ID)
            .accept(
                { ext ->
                    Log.i(TAG, "WebExtension installed: ${ext?.id}")
                },
                { err ->
                    Log.e(TAG, "Failed to register player WebExtension", err)
                }
            )
    }

    Box(modifier = modifier.background(Color.Black)) {
        key(recoveryGeneration) {
            AndroidView<FrameLayout>(
                modifier = Modifier.fillMaxSize(),
                factory = { ctx ->
                val parentWrapper = FrameLayout(ctx)
                val playerContainer = FrameLayout(ctx).apply {
                    setBackgroundColor(AndroidColor.BLACK)
                    // The remote cursor is a child of this view. Prefer it over the
                    // container itself; otherwise FrameLayout claims focus first and
                    // the overlay never draws or receives D-pad events.
                    descendantFocusability = ViewGroup.FOCUS_AFTER_DESCENDANTS
                }
                rootPlayerContainer = playerContainer

                // TextureView keeps the compositor surface alive while fullscreen
                // reparents the player into the activity decor view on Fire OS.
                val gv = GeckoView(ctx).apply {
                    setViewBackend(GeckoView.BACKEND_TEXTURE_VIEW)
                    // Remote input is mediated by TvCursorOverlayView. Gecko tries
                    // to claim Android focus again once an iframe/player finishes
                    // loading, which otherwise makes the cursor disappear.
                    isFocusable = false
                    isFocusableInTouchMode = false
                    geckoViewRef = this

                    val settings = GeckoSessionSettings().apply {
                        configureSessionSettings(this, url)
                    }
                    val session = GeckoSession(settings).apply {
                        contentDelegate = object : GeckoSession.ContentDelegate {
                            override fun onFocusRequest(session: GeckoSession) {
                                // Keep focus (and therefore the visible cursor) on
                                // the TV overlay. Select is still forwarded to Gecko
                                // as a touch event by the overlay.
                                cursorOverlayView?.post { cursorOverlayView?.requestFocus() }
                            }

                            override fun onFullScreen(session: GeckoSession, fullScreen: Boolean) {
                                Log.i(TAG, "onFullScreen: $fullScreen")
                                updateFullscreen(fullScreen)
                            }

                            override fun onCrash(session: GeckoSession) {
                                Handler(Looper.getMainLooper()).post {
                                    recoverSession(session, "crashed")
                                }
                            }

                            override fun onKill(session: GeckoSession) {
                                Handler(Looper.getMainLooper()).post {
                                    recoverSession(session, "was killed")
                                }
                            }
                        }

                        // GeckoView deliberately has no default permission UI. Video
                        // hosts therefore receive a denial unless the embedding app
                        // handles these requests, which was the source of the black
                        // player and the "No listener for GeckoView:ContentPermission"
                        // errors in logcat. This session only permits capabilities
                        // required to start protected/audible playback; camera,
                        // microphone, location, notifications, and local-network
                        // access remain denied.
                        permissionDelegate = object : GeckoSession.PermissionDelegate {
                            override fun onContentPermissionRequest(
                                session: GeckoSession,
                                permission: GeckoSession.PermissionDelegate.ContentPermission,
                            ): GeckoResult<Int> {
                                val allow = permission.permission ==
                                    GeckoSession.PermissionDelegate.PERMISSION_AUTOPLAY_AUDIBLE ||
                                    permission.permission ==
                                    GeckoSession.PermissionDelegate.PERMISSION_AUTOPLAY_INAUDIBLE ||
                                    permission.permission ==
                                    GeckoSession.PermissionDelegate.PERMISSION_MEDIA_KEY_SYSTEM_ACCESS ||
                                    permission.permission ==
                                    GeckoSession.PermissionDelegate.PERMISSION_PERSISTENT_STORAGE
                                Log.i(
                                    TAG,
                                    "Content permission ${permission.permission} for ${permission.uri}: " +
                                        if (allow) "allowed" else "denied",
                                )
                                return GeckoResult.fromValue(
                                    if (allow) {
                                        GeckoSession.PermissionDelegate.ContentPermission.VALUE_ALLOW
                                    } else {
                                        GeckoSession.PermissionDelegate.ContentPermission.VALUE_DENY
                                    },
                                )
                            }
                        }

                        progressDelegate = object : GeckoSession.ProgressDelegate {
                            override fun onPageStart(session: GeckoSession, pageUrl: String) {
                                documentHost = runCatching { Uri.parse(pageUrl).host }.getOrNull()
                                Log.d(TAG, "onPageStart: $pageUrl")
                                isLoading = true
                                progress = 0f
                            }

                            override fun onPageStop(session: GeckoSession, success: Boolean) {
                                Log.d(TAG, "onPageStop: success=$success")
                                isLoading = false
                                cursorOverlayView?.post { cursorOverlayView?.requestFocus() }
                            }

                            override fun onProgressChange(session: GeckoSession, newProgress: Int) {
                                progress = newProgress / 100f
                                isLoading = newProgress < 100
                            }
                        }

                        navigationDelegate = object : GeckoSession.NavigationDelegate {
                            override fun onLoadRequest(
                                session: GeckoSession,
                                request: GeckoSession.NavigationDelegate.LoadRequest,
                            ): GeckoResult<AllowOrDeny> {
                                // Network filtering is intentionally disabled while
                                // diagnosing Gecko playback stability. Let Gecko and
                                // the provider handle every top-level navigation.
                                return GeckoResult.fromValue(AllowOrDeny.ALLOW)
                            }

                            override fun onSubframeLoadRequest(
                                session: GeckoSession,
                                request: GeckoSession.NavigationDelegate.LoadRequest,
                            ): GeckoResult<AllowOrDeny> {
                                // Likewise, do not filter player iframes or their
                                // network requests during this diagnostic build.
                                return GeckoResult.fromValue(AllowOrDeny.ALLOW)
                            }

                            override fun onLoadError(session: GeckoSession, uri: String?, error: WebRequestError): GeckoResult<String> {
                                Log.e(TAG, "Load error (${error.code}): $uri")
                                onError("Load error (${error.code}): $uri")
                                return GeckoResult.fromValue(null)
                            }
                        }

                        open(runtime)
                        // This is the one session the user is actively watching.
                        // Gecko maps the high hint to Android service priority,
                        // reducing the chance that Fire OS kills its content/media
                        // process while the player is visible or reparented for
                        // fullscreen.
                        setPriorityHint(GeckoSession.PRIORITY_HIGH)
                    }

                    setSession(session)
                    geckoSession = session
                    session.loadUri(url)
                }

                val overlay = TvCursorOverlayView(
                    ctx,
                    inputViewProvider = { gv },
                    onScroll = { delta ->
                        geckoSession?.panZoomController?.scrollBy(
                            ScreenLength.zero(),
                            ScreenLength.fromPixels(delta),
                            PanZoomController.SCROLL_BEHAVIOR_SMOOTH,
                        )
                    },
                    onExitFullscreen = { geckoSession?.exitFullScreen() },
                    onExitFocus = onExitFocus,
                    isFullscreenProvider = { isFullscreen },
                ).apply {
                    cursorOverlayView = this
                    translationZ = 100f
                }

                playerContainer.addView(gv, FrameLayout.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    ViewGroup.LayoutParams.MATCH_PARENT
                ))
                playerContainer.addView(overlay, FrameLayout.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    ViewGroup.LayoutParams.MATCH_PARENT
                ))
                // GeckoView is deliberately not focusable on TV: the overlay keeps
                // the visible remote cursor and translates Select into touch events.
                parentWrapper.post { overlay.requestFocus() }

                parentWrapper.addView(playerContainer, FrameLayout.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    ViewGroup.LayoutParams.MATCH_PARENT
                ))

                parentWrapper.setTag(URL_KEY_TAG, MediaRequest(url, reloadKey))
                parentWrapper.setTag(SESSION_KEY_TAG, gv.session)
                parentWrapper.setTag(GECKO_VIEW_KEY_TAG, gv)
                parentWrapper.post {
                    if (restoreFullscreenAfterRecovery) {
                        restoreFullscreenAfterRecovery = false
                        updateFullscreen(true)
                    }
                }
                parentWrapper
            },
            update = { parentWrapper ->
                // Ensure playerContainer is inside parentWrapper if not fullscreen
                val playerContainer = rootPlayerContainer
                if (!isFullscreen && playerContainer != null && playerContainer.parent != parentWrapper) {
                    (playerContainer.parent as? ViewGroup)?.removeView(playerContainer)
                    parentWrapper.addView(playerContainer, FrameLayout.LayoutParams(
                        ViewGroup.LayoutParams.MATCH_PARENT,
                        ViewGroup.LayoutParams.MATCH_PARENT
                    ))
                }

                val request = MediaRequest(url, reloadKey)
                if (parentWrapper.getTag(URL_KEY_TAG) != request) {
                    parentWrapper.setTag(URL_KEY_TAG, request)
                    recoveryAttempts = 0
                    geckoViewRef?.session?.let { session ->
                        configureSessionSettings(session.settings, url)
                        session.loadUri(url)
                    }
                }
            },
                onRelease = { parentWrapper ->
                    val releasedSession = parentWrapper.getTag(SESSION_KEY_TAG) as? GeckoSession
                    val releasedView = parentWrapper.getTag(GECKO_VIEW_KEY_TAG) as? GeckoView
                    releasedView?.releaseSession()
                    releasedSession?.close()
                    if (geckoSession === releasedSession) geckoSession = null
                    if (geckoViewRef === releasedView) geckoViewRef = null
                },
            )
        }

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
            activity?.let { act ->
                val controller = WindowInsetsControllerCompat(act.window, act.window.decorView)
                WindowCompat.setDecorFitsSystemWindows(act.window, true)
                controller.show(WindowInsetsCompat.Type.systemBars())
            }
            rootPlayerContainer?.let { container ->
                (container.parent as? ViewGroup)?.removeView(container)
            }
            geckoSession?.let { session ->
                session.exitFullScreen()
                session.stop()
                session.loadUri("about:blank")
                session.close()
            }
            geckoViewRef?.releaseSession()
            geckoViewRef = null
            cursorOverlayView = null
            rootPlayerContainer = null
            geckoSession = null
        }
    }
}

private const val URL_KEY_TAG = 0x4d415049
private const val SESSION_KEY_TAG = 0x4d41504a
private const val GECKO_VIEW_KEY_TAG = 0x4d41504b
private const val MAX_AUTOMATIC_SESSION_RECOVERIES = 1

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

private fun configureSessionSettings(settings: GeckoSessionSettings, url: String) {
    val isDesktop = !url.contains("moviesapi.to") && !url.contains("moviesapi.vip")
    settings.userAgentMode = if (isDesktop) {
        GeckoSessionSettings.USER_AGENT_MODE_DESKTOP
    } else {
        GeckoSessionSettings.USER_AGENT_MODE_MOBILE
    }
    settings.viewportMode = if (isDesktop) {
        GeckoSessionSettings.VIEWPORT_MODE_DESKTOP
    } else {
        GeckoSessionSettings.VIEWPORT_MODE_MOBILE
    }
    settings.userAgentOverride = playerUserAgent(url)
    settings.useTrackingProtection = false
    settings.suspendMediaWhenInactive = false
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
 * and synthesizes touch events directly into GeckoView.
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
            // Gecko may request focus after handling the synthetic Select touch.
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
