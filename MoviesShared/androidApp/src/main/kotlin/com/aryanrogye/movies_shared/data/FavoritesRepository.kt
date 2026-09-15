package com.aryanrogye.movies_shared.data

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

data class Favorite(
    val id: Int,
    val name: String,
    val mediaType: String,
    val posterPath: String?,
)

class FavoritesRepository(context: Context) {
    private val preferences = context.getSharedPreferences("favorites", Context.MODE_PRIVATE)

    fun load(): List<Favorite> {
        val raw = preferences.getString(KEY, null) ?: return emptyList()
        return runCatching {
            val array = JSONArray(raw)
            buildList {
                repeat(array.length()) { index ->
                    val item = array.getJSONObject(index)
                    add(
                        Favorite(
                            id = item.getInt("id"),
                            name = item.getString("name"),
                            mediaType = item.getString("mediaType"),
                            posterPath = item.optString("posterPath").takeIf { it.isNotEmpty() },
                        )
                    )
                }
            }
        }.getOrDefault(emptyList())
    }

    fun save(favorites: List<Favorite>) {
        val array = JSONArray()
        favorites.forEach { favorite ->
            array.put(
                JSONObject()
                    .put("id", favorite.id)
                    .put("name", favorite.name)
                    .put("mediaType", favorite.mediaType)
                    .put("posterPath", favorite.posterPath ?: "")
            )
        }
        preferences.edit().putString(KEY, array.toString()).apply()
    }

    private companion object {
        const val KEY = "items"
    }
}
