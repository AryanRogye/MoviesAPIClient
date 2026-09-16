package com.aryanrogye.movies_shared.web

import android.content.Context
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.util.JsonReader
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import org.json.JSONObject
import java.io.InputStreamReader
import java.util.concurrent.Executors
import java.util.regex.Pattern

enum class BlockingStatus { PREPARING, READY, FAILED }

/** Android implementation of the behavior expressed by the iOS WebKit rule sources. */
class AndroidBlockingService(private val context: Context) {
    @Volatile private var matcher: NetworkMatcher = NetworkMatcher.EMPTY
    var status by mutableStateOf(BlockingStatus.PREPARING)
        private set
    var error by mutableStateOf<String?>(null)
        private set

    val popupScript: String by lazy { buildPopupScript() }

    init {
        Executors.newSingleThreadExecutor().execute {
            runCatching { NetworkMatcher.compile(context) }
                .onSuccess { compiled ->
                    matcher = compiled
                    Handler(Looper.getMainLooper()).post { status = BlockingStatus.READY }
                }
                .onFailure { throwable ->
                    Handler(Looper.getMainLooper()).post {
                        error = throwable.message
                        status = BlockingStatus.FAILED
                    }
                }
        }
    }

    fun shouldBlock(url: String, documentHost: String?): Boolean = matcher.matches(url, documentHost)

    private fun buildPopupScript(): String {
        val root = JSONObject(context.assets.open("PopupFilters.json").bufferedReader().use { it.readText() })
        val signatures = root.getJSONArray("signatures")
        val clauses = buildList {
            repeat(signatures.length()) { index ->
                val group = signatures.getJSONArray(index)
                val terms = buildList {
                    repeat(group.length()) { term -> add("source.includes(${JSONObject.quote(group.getString(term))})") }
                }
                add("(${terms.joinToString(" && ")})")
            }
        }
        return """
            (() => {
              const isSuspicious = frame => {
                if (!(frame instanceof HTMLIFrameElement) || !frame.srcdoc) return false;
                const source = frame.srcdoc;
                return ${clauses.joinToString(" || ")};
              };
              const inspect = node => {
                if (!(node instanceof Element)) return;
                if (isSuspicious(node)) node.remove();
                node.querySelectorAll?.('iframe').forEach(frame => { if (isSuspicious(frame)) frame.remove(); });
              };
              new MutationObserver(records => records.forEach(record => {
                record.addedNodes.forEach(inspect);
                if (record.type === 'attributes' && isSuspicious(record.target)) record.target.remove();
              })).observe(document.documentElement, {
                childList: true, subtree: true, attributes: true, attributeFilter: ['srcdoc']
              });
              document.querySelectorAll('iframe').forEach(frame => { if (isSuspicious(frame)) frame.remove(); });
            })();
        """.trimIndent()
    }
}

private data class HostRule(
    val host: String,
    val ifDomains: List<String>,
    val unlessDomains: List<String>,
) {
    fun applies(documentHost: String?): Boolean {
        val source = documentHost?.lowercase().orEmpty()
        if (unlessDomains.any { domainMatches(source, it) }) return false
        return ifDomains.isEmpty() || ifDomains.any { domainMatches(source, it) }
    }
}

private data class ScopedRegex(
    val pattern: Pattern,
    val ifDomains: List<String>,
    val unlessDomains: List<String>,
) {
    fun matches(url: String, documentHost: String?): Boolean {
        val source = documentHost?.lowercase().orEmpty()
        if (unlessDomains.any { domainMatches(source, it) }) return false
        if (ifDomains.isNotEmpty() && ifDomains.none { domainMatches(source, it) }) return false
        return pattern.matcher(url).find()
    }
}

private class NetworkMatcher(
    private val hostRules: Map<String, List<HostRule>>,
    private val combinedPatterns: List<Pattern>,
    private val scopedPatterns: List<ScopedRegex>,
) {
    fun matches(url: String, documentHost: String?): Boolean {
        val host = runCatching { Uri.parse(url).host?.lowercase() }.getOrNull()
        if (host != null) {
            if (ALLOWED_STREAMING_DOMAINS.any { host == it || host.endsWith(".$it") }) {
                return false
            }
            var candidate: String = host
            while (true) {
                if (hostRules[candidate]?.any { it.applies(documentHost) } == true) return true
                val dot = candidate.indexOf('.')
                if (dot < 0) break
                candidate = candidate.substring(dot + 1)
            }
        }
        if (combinedPatterns.any { it.matcher(url).find() }) return true
        return scopedPatterns.any { it.matches(url, documentHost) }
    }

    companion object {
        val EMPTY = NetworkMatcher(emptyMap(), emptyList(), emptyList())
        private const val HOST_PREFIX = "^[a-z][a-z0-9+.-]*://(?:[^/?#]*\\.)?"
        private const val HOST_SUFFIX = "(?::[0-9]+)?(?:[/?#].*)?$"

        private val ALLOWED_STREAMING_DOMAINS = setOf(
            "moviesapi.to",
            "vidfast.vc",
            "themoviedb.org",
            "tmdb.org",
            "netrocdn.site",
            "cloudflare.com",
            "challenges.cloudflare.com",
            "vidspark.to",
            "openwebtorrent.com",
            "btorrent.xyz",
            "moviesapi.vip",
            "nextgencloudfabric.com",
        )

        fun compile(context: Context): NetworkMatcher {
            val hostRules = mutableMapOf<String, MutableList<HostRule>>()
            val unscoped = mutableListOf<String>()
            val scoped = mutableListOf<ScopedRegex>()
            JsonReader(InputStreamReader(context.assets.open("NetworkBlockingRules.json"))).use { reader ->
                reader.beginArray()
                while (reader.hasNext()) {
                    var filter: String? = null
                    var ifDomains = emptyList<String>()
                    var unlessDomains = emptyList<String>()
                    reader.beginObject()
                    while (reader.hasNext()) {
                        when (reader.nextName()) {
                            "trigger" -> {
                                reader.beginObject()
                                while (reader.hasNext()) {
                                    when (reader.nextName()) {
                                        "url-filter" -> filter = reader.nextString()
                                        "if-domain" -> ifDomains = reader.readStrings()
                                        "unless-domain" -> unlessDomains = reader.readStrings()
                                        else -> reader.skipValue()
                                    }
                                }
                                reader.endObject()
                            }
                            else -> reader.skipValue()
                        }
                    }
                    reader.endObject()

                    val expression = filter ?: continue
                    val canonicalHost = expression.takeIf {
                        it.startsWith(HOST_PREFIX) && it.endsWith(HOST_SUFFIX)
                    }?.removePrefix(HOST_PREFIX)?.removeSuffix(HOST_SUFFIX)?.replace("\\.", ".")

                    if (canonicalHost != null && canonicalHost.matches(Regex("[a-zA-Z0-9.-]+"))) {
                        val rule = HostRule(canonicalHost.lowercase(), ifDomains, unlessDomains)
                        hostRules.getOrPut(rule.host) { mutableListOf() }.add(rule)
                    } else if (ifDomains.isEmpty() && unlessDomains.isEmpty()) {
                        unscoped.add(expression)
                    } else {
                        runCatching { Pattern.compile(expression, Pattern.CASE_INSENSITIVE) }
                            .onSuccess { scoped.add(ScopedRegex(it, ifDomains, unlessDomains)) }
                    }
                }
                reader.endArray()
            }

            val combined = unscoped.chunked(160).flatMap { chunk ->
                runCatching {
                    listOf(Pattern.compile(chunk.joinToString(prefix = "(?:", postfix = ")", separator = ")|(?:"), Pattern.CASE_INSENSITIVE))
                }.getOrElse {
                    // A small number of WebKit expressions can use syntax Java
                    // does not accept. Keep every compatible neighbor instead
                    // of dropping the entire optimized batch.
                    chunk.mapNotNull { expression ->
                        runCatching { Pattern.compile(expression, Pattern.CASE_INSENSITIVE) }.getOrNull()
                    }
                }
            }
            return NetworkMatcher(hostRules, combined, scoped)
        }
    }
}

private fun JsonReader.readStrings(): List<String> = buildList {
    beginArray()
    while (hasNext()) add(nextString().lowercase())
    endArray()
}

private fun domainMatches(host: String, rule: String): Boolean {
    val normalized = rule.removePrefix("*").removePrefix(".")
    return host == normalized || host.endsWith(".$normalized")
}
