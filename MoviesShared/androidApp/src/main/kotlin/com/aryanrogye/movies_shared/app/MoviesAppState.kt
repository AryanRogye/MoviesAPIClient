package com.aryanrogye.movies_shared.app

import android.content.Context
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.aryanrogye.movies_shared.BuildConfig
import com.aryanrogye.movies_shared.data.Favorite
import com.aryanrogye.movies_shared.data.FavoritesRepository
import com.aryanrogye.movies_shared.models.KTMediaType
import com.aryanrogye.movies_shared.models.KTSearchResult
import com.aryanrogye.movies_shared.models.KTSeasonInfo
import com.aryanrogye.movies_shared.models.KTTVShow
import com.aryanrogye.movies_shared.network.KTDisplayServer
import com.aryanrogye.movies_shared.network.TMDBClient

enum class MainTab { HOME, SEARCH, SETTINGS }
enum class LibraryFilter { ALL, TV, MOVIES }

sealed interface AppDestination {
    data class Main(val tab: MainTab) : AppDestination
    data class Detail(val result: KTSearchResult) : AppDestination
}

class MoviesAppState(context: Context) {
    private val tmdb = TMDBClient()
    private val favoritesRepository = FavoritesRepository(context)
    private val token = BuildConfig.TMDB_API_READ_ACCESS_TOKEN.trim()
    private val preferences = context.getSharedPreferences("settings", Context.MODE_PRIVATE)

    val favorites = mutableStateListOf<Favorite>().apply { addAll(favoritesRepository.load()) }
    var searchResults by mutableStateOf<List<KTSearchResult>>(emptyList())
        private set
    var destination by mutableStateOf<AppDestination>(AppDestination.Main(MainTab.HOME))
    private var returnTab = MainTab.HOME
    var libraryFilter by mutableStateOf(LibraryFilter.ALL)
    var displayServer by mutableStateOf(readDisplayServer())
        private set
    var isBusy by mutableStateOf(false)
        private set
    var error by mutableStateOf<String?>(null)
        private set

    val isConfigured: Boolean get() = token.isNotEmpty()

    suspend fun search(query: String) {
        val trimmed = query.trim()
        if (trimmed.isEmpty()) {
            searchResults = emptyList()
            return
        }
        runBusy { searchResults = tmdb.search(trimmed, tokenOrThrow()).results }
    }

    suspend fun openFavorite(favorite: Favorite) {
        returnTab = (destination as? AppDestination.Main)?.tab ?: MainTab.HOME
        runBusy {
            val result = tmdb.search(favorite.name, tokenOrThrow()).results.firstOrNull { it.id == favorite.id }
            if (result == null) error = "Could not find ${favorite.name} on TMDB."
            else destination = AppDestination.Detail(result)
        }
    }

    suspend fun tvInfo(id: Int): KTTVShow? = runBusyResult { tmdb.infoOnTV(id, tokenOrThrow()) }

    suspend fun seasonInfo(id: Int, season: Int): KTSeasonInfo? =
        runBusyResult { tmdb.seasonInfo(id, season, tokenOrThrow()) }

    fun selectTab(tab: MainTab) {
        destination = AppDestination.Main(tab)
    }

    fun openDetail(result: KTSearchResult) {
        returnTab = (destination as? AppDestination.Main)?.tab ?: MainTab.SEARCH
        destination = AppDestination.Detail(result)
    }

    fun backTo(tab: MainTab = returnTab) {
        destination = AppDestination.Main(tab)
    }

    fun toggleFavorite(result: KTSearchResult) {
        val existing = favorites.indexOfFirst { it.id == result.id }
        if (existing >= 0) favorites.removeAt(existing)
        else favorites.add(
            Favorite(
                id = result.id,
                name = result.name ?: result.title.orEmpty(),
                mediaType = result.mediaType.rawValue,
                posterPath = result.posterPath,
            )
        )
        favoritesRepository.save(favorites)
    }

    fun removeFavorite(favorite: Favorite) {
        favorites.remove(favorite)
        favoritesRepository.save(favorites)
    }

    fun isFavorite(id: Int): Boolean = favorites.any { it.id == id }

    fun updateDisplayServer(server: KTDisplayServer) {
        displayServer = server
        preferences.edit().putString(DISPLAY_SERVER, server.name).apply()
    }

    fun consumeError() {
        error = null
    }

    fun reportError(message: String) {
        error = message
    }

    private fun tokenOrThrow(): String = token.ifEmpty {
        throw IllegalStateException("Set TMDB_API_READ_ACCESS_TOKEN in ~/.gradle/gradle.properties or the environment.")
    }

    private suspend fun runBusy(block: suspend () -> Unit) {
        if (isBusy) return
        isBusy = true
        try {
            block()
        } catch (throwable: Throwable) {
            error = throwable.message ?: "Unknown error"
        } finally {
            isBusy = false
        }
    }

    private suspend fun <T> runBusyResult(block: suspend () -> T): T? {
        if (isBusy) return null
        isBusy = true
        return try {
            block()
        } catch (throwable: Throwable) {
            error = throwable.message ?: "Unknown error"
            null
        } finally {
            isBusy = false
        }
    }

    private fun readDisplayServer(): KTDisplayServer {
        val saved = preferences.getString(DISPLAY_SERVER, null)
        return KTDisplayServer.entries.firstOrNull { it.name == saved } ?: KTDisplayServer.MOVIES_API
    }

    private companion object {
        const val DISPLAY_SERVER = "display_server"
    }
}
