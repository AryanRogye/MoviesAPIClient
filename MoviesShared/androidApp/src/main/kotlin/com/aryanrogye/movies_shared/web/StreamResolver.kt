package com.aryanrogye.movies_shared.web

import android.annotation.SuppressLint
import android.content.Context
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.ViewGroup
import android.webkit.CookieManager
import android.webkit.JavascriptInterface
import android.webkit.WebResourceRequest
import android.webkit.WebResourceResponse
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeoutOrNull
import org.json.JSONObject
import java.io.ByteArrayInputStream
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.atomic.AtomicBoolean

private const val TAG = "StreamResolver"

/**
 * Direct stream handed to ExoPlayer. Headers (Referer/Origin/UA) are required
 * by hosts like vidlink.pro or playback 403s even with a valid .m3u8.
 */
data class ResolvedStream(
    val url: String,
    val referer: String,
    val origin: String?,
    val userAgent: String,
    val isHls: Boolean,
    val cookies: String? = null,
)

object StreamResolver {
    private const val RESOLVE_TIMEOUT_MS = 30_000L

    /**
     * Load [embedUrl] in a headless WebView, sniff the underlying .m3u8/.mp4
     * (or VidLink /api/b/ JSON) and return it. The WebView is destroyed before
     * returning so only ExoPlayer holds the video surface - this is what makes
     * Fire TV sticks survive where full-page Gecko/WebView playback OOMs.
     */
    suspend fun resolve(
        context: Context,
        embedUrl: String,
        blockingService: AndroidBlockingService?,
    ): ResolvedStream? = withContext(Dispatchers.Main) {
        val deferred = CompletableDeferred<ResolvedStream?>()
        val done = AtomicBoolean(false)
        fun complete(value: ResolvedStream?) {
            if (done.compareAndSet(false, true) && !deferred.isCompleted) {
                deferred.complete(value)
            }
        }

        val appContext = context.applicationContext
        val referer = embedUrl
        val origin = runCatching {
            val uri = Uri.parse(embedUrl)
            "${uri.scheme}://${uri.host}"
        }.getOrNull()
        val userAgent = "Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 " +
            "(KHTML, like Gecko) Chrome/131.0.0.0 Mobile Safari/537.36"

        var webView: WebView? = null
        val mainHandler = Handler(Looper.getMainLooper())
        var tryParseApiJson: ((String) -> Unit)? = null

        fun candidateFound(rawUrl: String, fromApiJson: String? = null) {
            var url = rawUrl.trim()
            if (url.startsWith("blob:") || url.startsWith("data:")) return
            // Never hand the JSON API itself to ExoPlayer - it returns
            // application/json, which surfaces as "source error". Only the
            // parsed playlist/mp4 inside it is playable.
            if (url.contains("/api/b/") && fromApiJson == null) {
                tryParseApiJson?.invoke(url)
                return
            }
            // Resolve relative URLs against the embed page.
            if (url.startsWith("/")) {
                val base = Uri.parse(embedUrl)
                url = "${base.scheme}://${base.host}$url"
            }
            if (!looksLikeStream(url) && fromApiJson == null) return
            // Snapshot WebView cookies: stream CDNs often validate the same
            // session/Cloudflare cookie the embed page set.
            val cookies = runCatching {
                CookieManager.getInstance().getCookie(url)
                    ?: CookieManager.getInstance().getCookie(embedUrl)
            }.getOrNull()
            Log.i(TAG, "Stream found: $url (via ${fromApiJson ?: "network"})")
            complete(ResolvedStream(url, referer, origin, userAgent, url.lowercase().contains("m3u8"), cookies))
        }

        // VidLink's player calls an internal JSON API that lists every quality.
        // Fetch it directly (off the UI thread) instead of rendering video in JS.
        tryParseApiJson = fun(apiUrl: String) {
            Thread {
                runCatching {
                    val webCookies = runCatching {
                        CookieManager.getInstance().getCookie(apiUrl)
                            ?: CookieManager.getInstance().getCookie(embedUrl)
                    }.getOrNull()
                    val conn = (URL(apiUrl).openConnection() as HttpURLConnection).apply {
                        connectTimeout = 8000
                        readTimeout = 8000
                        setRequestProperty("Referer", referer)
                        origin?.let { setRequestProperty("Origin", it) }
                        setRequestProperty("User-Agent", userAgent)
                        setRequestProperty("Accept", "application/json,*/*")
                        if (!webCookies.isNullOrEmpty()) setRequestProperty("Cookie", webCookies)
                    }
                    val code = conn.responseCode
                    if (code != HttpURLConnection.HTTP_OK) {
                        Log.w(TAG, "api/b returned HTTP $code for $apiUrl")
                        return@runCatching
                    }
                    val body = conn.inputStream.bufferedReader().use { it.readText() }
                    Log.d(TAG, "api/b body ${body.length} chars: ${body.take(300)}")
                    val best = extractBestStreamFromJson(body)
                    if (best != null) {
                        mainHandler.post { candidateFound(best, fromApiJson = apiUrl) }
                    } else {
                        Log.w(TAG, "api/b had no playable stream: ${body.take(500)}")
                    }
                }.onFailure { Log.w(TAG, "api/b fetch failed: $apiUrl", it) }
            }.start()
        }

        val hook = object {
            @JavascriptInterface
            fun onStreamFound(url: String) {
                mainHandler.post { candidateFound(url) }
            }
        }

        @SuppressLint("SetJavaScriptEnabled", "AddJavascriptInterface")
        fun create(): WebView = WebView(appContext).apply webApply@{
            // Offscreen but full-size: a 2x2 viewport hides play-button overlays
            // behind mobile breakpoints on provider embeds. Not attached to any
            // window so nothing is composited - just laid out for JS to click.
            layoutParams = ViewGroup.LayoutParams(1280, 720)
            settings.apply {
                javaScriptEnabled = true
                domStorageEnabled = true
                databaseEnabled = true
                // Resolver never shows pixels - skip images to save Fire TV RAM.
                loadsImagesAutomatically = false
                blockNetworkImage = true
                mediaPlaybackRequiresUserGesture = false
                cacheMode = WebSettings.LOAD_DEFAULT
                mixedContentMode = WebSettings.MIXED_CONTENT_ALWAYS_ALLOW
                javaScriptCanOpenWindowsAutomatically = false
                setSupportMultipleWindows(false)
                useWideViewPort = true
                loadWithOverviewMode = false
                this.userAgentString = userAgent
            }
            CookieManager.getInstance().apply {
                setAcceptCookie(true)
                setAcceptThirdPartyCookies(this@webApply, true)
            }
            addJavascriptInterface(hook, "AndroidStreamHook")
            webChromeClient = object : android.webkit.WebChromeClient() {
                override fun onConsoleMessage(message: android.webkit.ConsoleMessage): Boolean {
                    // Provider pages log player states here; useful when a host
                    // changes its embed and resolve starts failing.
                    Log.d(TAG, "console[${message.messageLevel()}]: ${message.message()}")
                    return true
                }
            }
            webViewClient = object : WebViewClient() {
                override fun shouldInterceptRequest(
                    view: WebView,
                    request: WebResourceRequest,
                ): WebResourceResponse? {
                    val url = request.url.toString()
                    val host = request.url.host?.lowercase()
                    // VidLink JSON API first - it is NOT playable itself, only
                    // the playlist/mp4 inside it is. candidateFound re-routes
                    // here too as a safety net.
                    if (url.contains("/api/b/")) {
                        tryParseApiJson(url)
                        return null
                    }
                    // Let the stream + its playlist segments through untouched.
                    if (looksLikeStream(url)) {
                        candidateFound(url)
                        return null
                    }
                    // Block ads/trackers/popups during resolve; keep provider +
                    // CDN + challenge hosts. Reuses the canonical iOS rule set.
                    val documentHost = runCatching { Uri.parse(embedUrl).host }.getOrNull()
                    if (blockingService?.shouldBlock(url, documentHost) == true) {
                        return emptyResponse()
                    }
                    // Extra cheap wins: skip fonts/images that only cost RAM.
                    if (request.method == "GET" && host != null) {
                        val path = request.url.path?.lowercase().orEmpty()
                        if (path.endsWith(".woff2") || path.endsWith(".woff") ||
                            path.endsWith(".ttf") || path.endsWith(".png") ||
                            path.endsWith(".jpg") || path.endsWith(".jpeg") ||
                            path.endsWith(".webp") || path.endsWith(".gif") ||
                            path.endsWith(".svg") || path.endsWith(".ico")
                        ) {
                            return emptyResponse()
                        }
                    }
                    return null
                }

                override fun shouldOverrideUrlLoading(view: WebView, request: WebResourceRequest): Boolean {
                    // Only block non-web schemes (intent://, market://, etc).
                    // Returning true for http(s) would cancel the provider's own
                    // player iframes and no stream would ever be requested.
                    val scheme = request.url.scheme?.lowercase()
                    val isMainFrame = request.isForMainFrame
                    if (scheme != "http" && scheme != "https") {
                        Log.i(TAG, "Blocking non-web navigation: ${request.url}")
                        return true
                    }
                    // Allow the embed + its player iframes to navigate. Popups
                    // that try to take over the main frame with an ad host are
                    // still contained because we never show this WebView.
                    if (isMainFrame) {
                        val embedHost = runCatching { Uri.parse(embedUrl).host?.lowercase() }.getOrNull()
                        val targetHost = request.url.host?.lowercase()
                        if (embedHost != null && targetHost != null &&
                            targetHost != embedHost && !targetHost.endsWith(".$embedHost")
                        ) {
                            Log.i(TAG, "Blocking main-frame hop to ad host: ${request.url}")
                            return true
                        }
                    }
                    return false
                }

                override fun onPageFinished(view: WebView, url: String) {
                    Log.d(TAG, "page finished: $url")
                    view.evaluateJavascript(STREAM_HOOK_JS, null)
                    view.evaluateJavascript(AUTO_CLICK_JS, null)
                }
            }
        }

        try {
            webView = create().also { it.loadUrl(embedUrl) }
            // Re-inject periodically: embed players build their <video> late,
            // after 2-3 chained iframes/APIs resolve, and most hosts only
            // request the stream AFTER a play-button click.
            val reinject = object : Runnable {
                var ticks = 0
                override fun run() {
                    if (done.get() || ticks++ > 13) return
                    webView?.evaluateJavascript(STREAM_HOOK_JS, null)
                    webView?.evaluateJavascript(AUTO_CLICK_JS, null)
                    mainHandler.postDelayed(this, 2000)
                }
            }
            mainHandler.postDelayed(reinject, 2000)

            val found = withTimeoutOrNull(RESOLVE_TIMEOUT_MS) { deferred.await() }
            // Copy out before destroy so finally can return without getCompleted().
            found
        } catch (t: Throwable) {
            Log.w(TAG, "resolve failed for $embedUrl", t)
            null
        } finally {
            mainHandler.removeCallbacksAndMessages(null)
            runCatching {
                webView?.apply {
                    stopLoading()
                    loadUrl("about:blank")
                    webViewClient = WebViewClient()
                    removeJavascriptInterface("AndroidStreamHook")
                    destroy()
                }
            }
            webView = null
            // Always settle so late callbacks don't leak; caller already has result.
            complete(null)
        }
    }

    private fun looksLikeStream(url: String): Boolean {
        val lower = url.lowercase()
        if (lower.startsWith("blob:") || lower.startsWith("data:")) return false
        // NOTE: /api/b/ is deliberately excluded - it returns JSON, not video.
        // It is handled via tryParseApiJson instead.
        return lower.contains(".m3u8") || lower.contains(".mpd") ||
            (lower.contains(".mp4") && !lower.contains("thumbnail"))
    }

    /**
     * VidLink /api/b/ shape: {"stream":{"qualities":{"1080":"https://...mp4",...},
     * "playlist":"https://...m3u8"}}. Prefer the HLS playlist, else highest mp4.
     * Falls back to a recursive scan so minor API shape changes don't break us.
     */
    internal fun extractBestStreamFromJson(body: String): String? {
        return runCatching {
            val root = JSONObject(body)
            // Walk: root -> stream -> playlist, or stream -> qualities{1080: url}
            val stream = root.optJSONObject("stream")
            stream?.optString("playlist")?.takeIf { it.contains("http") }?.let { return it }
            val qualities = stream?.optJSONObject("qualities")
            if (qualities != null) {
                val best = qualities.keys().asSequence()
                    .mapNotNull { key -> key.toIntOrNull()?.let { it to qualities.optString(key) } }
                    .filter { it.second.contains("http") }
                    .maxByOrNull { it.first }
                    ?.second
                if (best != null) return best
            }
            // Recursive fallback for unexpected shapes.
            findFirstStreamString(root)?.let { return it }
            // Top-level playlist field variant.
            root.optString("playlist").takeIf { it.contains("http") }
        }.getOrNull()?.takeIf { it.contains("http") }
    }

    private fun findFirstStreamString(obj: Any?): String? {
        when (obj) {
            is JSONObject -> {
                // Prefer keys that sound like streams first.
                val keys = obj.keys().asSequence().toList()
                val ordered = keys.sortedBy {
                    when {
                        it.contains("playlist", true) -> 0
                        it.contains("m3u8", true) -> 1
                        it.contains("master", true) -> 2
                        it.contains("source", true) -> 3
                        it.contains("file", true) -> 4
                        it.contains("url", true) -> 5
                        else -> 9
                    }
                }
                for (key in ordered) {
                    val v = obj.opt(key)
                    if (v is String && v.contains("http") &&
                        (v.contains("m3u8") || v.contains(".mp4") || v.contains(".mpd"))
                    ) return v
                }
                for (key in ordered) {
                    findFirstStreamString(obj.opt(key))?.let { return it }
                }
            }
            is org.json.JSONArray -> {
                for (i in 0 until obj.length()) {
                    findFirstStreamString(obj.opt(i))?.let { return it }
                }
            }
            is String -> {
                if (obj.contains("http") &&
                    (obj.contains("m3u8") || obj.contains(".mp4") || obj.contains(".mpd"))
                ) return obj
            }
        }
        return null
    }

    private fun emptyResponse(): WebResourceResponse =
        WebResourceResponse("text/plain", "utf-8", 204, "No Content", emptyMap(), ByteArrayInputStream(ByteArray(0)))

    // Most provider embeds (moviesapi/vidfast/vidspark/vidlink) render a
    // backdrop + big play button and only fetch the .m3u8 AFTER it is clicked.
    // A headless resolver that never clicks will always time out with
    // "direct stream not found". This aggressively clicks the most likely
    // play control every 2s until the stream appears.
    private val AUTO_CLICK_JS = """
        (() => {
          try {
            // 1. Direct <video> tap-to-play: muted autoplay unlocks segments.
            document.querySelectorAll('video').forEach(v => {
              try {
                v.muted = true;
                const r = v.getBoundingClientRect();
                if (r.width > 50 && r.height > 50) {
                  v.click();
                  v.play && v.play().catch(() => {});
                }
              } catch (e) {}
            });
            // 2. Score visible clickables: big + centered + play-ish wins.
            const cands = [];
            document.querySelectorAll('button, div, a, span, [role="button"], iframe').forEach(el => {
              try {
                if (el.tagName === 'IFRAME') {
                  // Tapping the player iframe itself often starts it.
                  const r = el.getBoundingClientRect();
                  if (r.width > 200 && r.height > 120) cands.push({el, score: 40});
                  return;
                }
                const r = el.getBoundingClientRect();
                if (r.width < 30 || r.height < 30 || r.width > innerWidth * 0.9 && r.height > innerHeight * 0.9) return;
                const style = getComputedStyle(el);
                if (style.display === 'none' || style.visibility === 'hidden' || style.opacity === '0') return;
                const text = ((el.innerText || '') + ' ' + (el.getAttribute('aria-label') || '') + ' ' + (el.className || '')).toLowerCase();
                let score = 0;
                if (text.includes('play')) score += 50;
                if (text.includes('watch') || text.includes('player')) score += 20;
                if (/▶|►|❚❚/.test(el.innerHTML || '')) score += 40;
                // Center of viewport = almost always the big play overlay.
                const cx = Math.abs((r.left + r.width / 2) - innerWidth / 2) / innerWidth;
                const cy = Math.abs((r.top + r.height / 2) - innerHeight / 2) / innerHeight;
                score += Math.max(0, 30 - (cx + cy) * 40);
                score += Math.min(20, (r.width * r.height) / 20000);
                if (score > 25) cands.push({el, score});
              } catch (e) {}
            });
            cands.sort((a, b) => b.score - a.score);
            if (cands.length > 0) {
              const top = cands[0];
              console.log('[movies-resolver] clicking play candidate score=' + Math.round(top.score));
              try { top.el.click(); } catch (e) {}
              try {
                const r = top.el.getBoundingClientRect();
                ['mousedown', 'mouseup', 'touchstart', 'touchend'].forEach(t =>
                  top.el.dispatchEvent(new Event(t, {bubbles: true})));
              } catch (e) {}
            } else {
              // 3. Last resort: tap viewport center - many overlays listen there.
              const el = document.elementFromPoint(innerWidth / 2, innerHeight / 2);
              if (el) { try { el.click(); } catch (e) {} }
            }
          } catch (e) { console.log('[movies-resolver] autoclick err ' + e); }
        })();
    """.trimIndent()

    // Hooks fetch/XHR + scans <video>/<source> + performance entries, because
    // shouldInterceptRequest misses XHR-driven HLS.js requests on some hosts.
    private val STREAM_HOOK_JS = """
        (() => {
          if (window.__moviesStreamHook) { window.__moviesStreamHookScan && window.__moviesStreamHookScan(); return; }
          window.__moviesStreamHook = true;
          const report = (u) => {
            if (typeof u !== 'string' || !u.startsWith('http')) return;
            const l = u.toLowerCase();
            if (l.includes('.m3u8') || l.includes('.mpd') || l.includes('/api/b/') ||
                (l.includes('.mp4') && !l.includes('thumbnail'))) {
              try { AndroidStreamHook.onStreamFound(u); } catch (e) {}
            }
          };
          window.__moviesStreamHookScan = () => {
            document.querySelectorAll('video, source').forEach(el => {
              if (el.src) report(el.src);
              const s = el.getAttribute && el.getAttribute('src');
              if (s) report(s);
            });
            try {
              performance.getEntriesByType('resource').forEach(r => report(r.name));
            } catch (e) {}
          };
          const origFetch = window.fetch;
          if (origFetch) {
            window.fetch = function(input, init) {
              try { report(typeof input === 'string' ? input : input && input.url); } catch (e) {}
              return origFetch.apply(this, arguments).then(resp => {
                try {
                  const u = (resp && resp.url) || (typeof input === 'string' ? input : input && input.url);
                  if (u) report(u);
                } catch (e) {}
                return resp;
              });
            };
          }
          const origOpen = XMLHttpRequest.prototype.open;
          XMLHttpRequest.prototype.open = function(method, url) {
            try { report(url); } catch (e) {}
            return origOpen.apply(this, arguments);
          };
          // Autoplay muted so providers start loading segments without a tap.
          // ExoPlayer takes over actual rendering once we hand off the URL.
          document.querySelectorAll('video').forEach(v => {
            try { v.muted = true; v.play && v.play().catch(() => {}); } catch (e) {}
          });
          window.__moviesStreamHookScan();
        })();
    """.trimIndent()
}
