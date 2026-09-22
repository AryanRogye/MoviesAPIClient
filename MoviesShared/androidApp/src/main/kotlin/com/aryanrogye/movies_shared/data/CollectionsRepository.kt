package com.aryanrogye.movies_shared.data

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject
import java.security.MessageDigest
import java.security.SecureRandom
import java.util.UUID

data class CollectionItem(
    val id: Int,
    val name: String,
    val mediaType: String,
    val posterPath: String?,
)

data class MovieCollection(
    val id: String = UUID.randomUUID().toString(),
    val name: String,
    val items: List<CollectionItem> = emptyList(),
    val hidesCoverImage: Boolean = false,
    val passwordSalt: String? = null,
    val passwordHash: String? = null,
) {
    val isProtected: Boolean get() = passwordSalt != null && passwordHash != null

    fun withPassword(pin: String): MovieCollection {
        require(pin.length == 4 && pin.all(Char::isDigit))
        val salt = ByteArray(16).also(SecureRandom()::nextBytes).toHex()
        return copy(passwordSalt = salt, passwordHash = pinHash(salt, pin))
    }

    fun accepts(pin: String): Boolean = passwordSalt?.let { salt ->
        passwordHash == pinHash(salt, pin)
    } ?: true

    fun withoutPassword(): MovieCollection = copy(passwordSalt = null, passwordHash = null)
}

private fun pinHash(salt: String, pin: String): String =
    MessageDigest.getInstance("SHA-256").digest("$salt:$pin".toByteArray()).toHex()

private fun ByteArray.toHex(): String = joinToString("") { "%02x".format(it.toInt() and 0xff) }

class CollectionsRepository(context: Context) {
    private val preferences = context.getSharedPreferences("collections", Context.MODE_PRIVATE)

    fun load(): List<MovieCollection> = runCatching {
        val array = JSONArray(preferences.getString("items", "[]"))
        List(array.length()) { index ->
            val value = array.getJSONObject(index)
            val items = value.optJSONArray("items") ?: JSONArray()
            MovieCollection(
                id = value.getString("id"),
                name = value.getString("name"),
                items = List(items.length()) { itemIndex ->
                    val item = items.getJSONObject(itemIndex)
                    CollectionItem(
                        id = item.getInt("id"),
                        name = item.getString("name"),
                        mediaType = item.getString("mediaType"),
                        posterPath = item.optString("posterPath").takeIf(String::isNotBlank),
                    )
                },
                hidesCoverImage = value.optBoolean("hidesCoverImage"),
                passwordSalt = value.optString("passwordSalt").takeIf(String::isNotBlank),
                passwordHash = value.optString("passwordHash").takeIf(String::isNotBlank),
            )
        }
    }.getOrDefault(emptyList())

    fun save(collections: List<MovieCollection>) {
        val array = JSONArray()
        collections.forEach { collection ->
            val items = JSONArray()
            collection.items.forEach { item ->
                items.put(JSONObject()
                    .put("id", item.id)
                    .put("name", item.name)
                    .put("mediaType", item.mediaType)
                    .put("posterPath", item.posterPath ?: ""))
            }
            array.put(JSONObject()
                .put("id", collection.id)
                .put("name", collection.name)
                .put("items", items)
                .put("hidesCoverImage", collection.hidesCoverImage)
                .put("passwordSalt", collection.passwordSalt ?: "")
                .put("passwordHash", collection.passwordHash ?: ""))
        }
        preferences.edit().putString("items", array.toString()).apply()
    }
}
