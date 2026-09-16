package com.aryanrogye.movies_shared.web

import android.view.KeyEvent
import androidx.activity.compose.BackHandler
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.viewinterop.AndroidView
import androidx.media3.common.MediaItem
import androidx.media3.common.Player
import androidx.media3.common.util.UnstableApi
import androidx.media3.datasource.DefaultHttpDataSource
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.hls.HlsMediaSource
import androidx.media3.exoplayer.source.DefaultMediaSourceFactory
import androidx.media3.ui.PlayerView

/**
 * Native hardware-decoded playback. This replaces rendering video inside
 * Gecko/WebView (software HLS.js, full page JS, 100MB+ engine) with a direct
 * HLS/mp4 URL resolved headlessly. ExoPlayer handles adaptive bitrate,
 * buffering and subtitles with the TV hardware decoders Fire sticks rely on.
 */
@androidx.annotation.OptIn(UnstableApi::class)
@Composable
fun NativePlayer(
    stream: ResolvedStream,
    modifier: Modifier = Modifier,
    onError: (String) -> Unit = {},
) {
    val context = LocalContext.current
    var playerError by remember { mutableStateOf<String?>(null) }

    val exoPlayer = remember(stream.url) {
        val httpFactory = DefaultHttpDataSource.Factory().apply {
            setUserAgent(stream.userAgent)
            setDefaultRequestProperties(
                buildMap {
                    put("Referer", stream.referer)
                    // VidLink CDN pins to the UA in its api/b headers
                    // (e.g. com.community.oneroom) - generic Chrome 403s.
                    stream.streamHeaders.forEach { (k, v) ->
                        if (k.equals("User-Agent", true)) return@forEach
                        if (k.equals("Referer", true) || k.equals("Cookie", true)) return@forEach
                        put(k, v)
                    }
                    put("Accept", stream.streamHeaders["Accept"] ?: "*/*")
                    stream.origin?.let { put("Origin", it) }
                    if (!stream.cookies.isNullOrEmpty()) put("Cookie", stream.cookies)
                },
            )
            setConnectTimeoutMs(15_000)
            setReadTimeoutMs(15_000)
            setAllowCrossProtocolRedirects(true)
        }
        ExoPlayer.Builder(context).apply {
            setMediaSourceFactory(DefaultMediaSourceFactory(context).setDataSourceFactory(httpFactory))
            setSeekBackIncrementMs(10_000)
            setSeekForwardIncrementMs(10_000)
        }.build().apply {
            val item = MediaItem.fromUri(stream.url)
            // HlsMediaSource handles multi-quality playlists adaptively;
            // progressive mp4 falls back to the default source automatically.
            if (stream.isHls) {
                setMediaSource(HlsMediaSource.Factory(httpFactory).createMediaSource(item))
            } else {
                setMediaItem(item)
            }
            addListener(object : Player.Listener {
                override fun onPlayerError(error: androidx.media3.common.PlaybackException) {
                    android.util.Log.e(
                        "NativePlayer",
                        "source error url=${stream.url} code=${error.errorCode} " +
                            "name=${error.errorCodeName} cause=${error.cause?.message}",
                        error,
                    )
                    playerError = "Source error (${error.errorCodeName}, ${error.errorCode}): ${stream.url.take(120)}"
                    onError(playerError!!)
                }
            })
            prepare()
            playWhenReady = true
        }
    }

    DisposableEffect(stream.url) {
        onDispose { exoPlayer.release() }
    }

    LaunchedEffect(playerError) {
        // Error is surfaced via onError so the caller can offer WebView fallback.
    }

    Box(modifier = modifier.background(Color.Black)) {
        AndroidView(
            modifier = Modifier.fillMaxSize(),
            factory = { ctx ->
                PlayerView(ctx).apply {
                    player = exoPlayer
                    useController = true
                    controllerShowTimeoutMs = 4000
                    setShowBuffering(PlayerView.SHOW_BUFFERING_WHEN_PLAYING)
                    // Leanback: controller must grab D-pad focus first.
                    isFocusable = true
                    isFocusableInTouchMode = true
                    requestFocus()
                }
            },
            update = { view ->
                if (view.player !== exoPlayer) view.player = exoPlayer
            },
            onRelease = { view -> view.player = null },
        )
    }

    BackHandler {
        exoPlayer.pause()
        exoPlayer.release()
    }
}

/**
 * D-pad helper for screens hosting NativePlayer: left/right seek, center
 * toggles play. PlayerView's controller already handles most keys when
 * focused; this is only needed if you build custom controls later.
 */
fun handlePlayerKey(player: ExoPlayer, keyCode: Int, action: Int): Boolean {
    if (action != KeyEvent.ACTION_DOWN) return false
    return when (keyCode) {
        KeyEvent.KEYCODE_DPAD_LEFT -> { player.seekBack(); true }
        KeyEvent.KEYCODE_DPAD_RIGHT -> { player.seekForward(); true }
        KeyEvent.KEYCODE_DPAD_CENTER, KeyEvent.KEYCODE_ENTER -> {
            if (player.isPlaying) player.pause() else player.play()
            true
        }
        else -> false
    }
}
