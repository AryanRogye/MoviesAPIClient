package com.aryanrogye.movies_shared.data

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

data class WatchHistory(
    val resultId: Int,
    val name: String,
    val posterPath: String?,
    val season: Int? = null,
    val episode: Int? = null,
    val watchedAt: Long = System.currentTimeMillis(),
) {
    val key: String get() = "$resultId:${season ?: "movie"}:${episode ?: ""}"
}

class HistoryRepository(context: Context) {
    private val preferences = context.getSharedPreferences("watch_history", Context.MODE_PRIVATE)

    fun load(): List<WatchHistory> = runCatching {
        val array = JSONArray(preferences.getString("items", "[]"))
        List(array.length()) { index ->
            val item = array.getJSONObject(index)
            WatchHistory(
                resultId = item.getInt("resultId"),
                name = item.getString("name"),
                posterPath = item.optString("posterPath").takeIf { it.isNotBlank() },
                season = if (item.has("season")) item.getInt("season") else null,
                episode = if (item.has("episode")) item.getInt("episode") else null,
                watchedAt = item.getLong("watchedAt"),
            )
        }.sortedByDescending { it.watchedAt }
    }.getOrDefault(emptyList())

    fun save(items: List<WatchHistory>) {
        val array = JSONArray()
        items.forEach { item ->
            array.put(JSONObject()
                .put("resultId", item.resultId)
                .put("name", item.name)
                .put("posterPath", item.posterPath ?: "")
                .put("season", item.season)
                .put("episode", item.episode)
                .put("watchedAt", item.watchedAt))
        }
        preferences.edit().putString("items", array.toString()).apply()
    }
}
