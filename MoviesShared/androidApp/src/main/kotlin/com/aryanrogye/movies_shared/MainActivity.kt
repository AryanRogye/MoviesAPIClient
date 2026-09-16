package com.aryanrogye.movies_shared

import android.os.Bundle
import android.webkit.WebView
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import com.aryanrogye.movies_shared.app.MoviesApp

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent { MoviesApp() }
        // Prewarm Chromium while the user browses posters, so the first playback
        // WebView reuses a hot renderer/profile instead of cold-starting one.
        // This is half of why Silk feels instant and embedded views feel slow.
        window.decorView.post { runCatching { WebView(this).destroy() } }
    }
}
