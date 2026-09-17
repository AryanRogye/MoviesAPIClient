package com.aryanrogye.movies_shared.app

import android.content.Context
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.aryanrogye.movies_shared.BuildConfig
import com.aryanrogye.movies_shared.data.Favorite
import com.aryanrogye.movies_shared.data.FavoritesRepository
import com.aryanrogye.movies_shared.data.HistoryRepository
import com.aryanrogye.movies_shared.data.WatchHistory
import kotlinx.coroutines.CancellationException
import com.aryanrogye.movies_shared.models.KTMediaType
import com.aryanrogye.movies_shared.models.KTSearchResult
import com.aryanrogye.movies_shared.models.KTSeasonInfo
import com.aryanrogye.movies_shared.models.KTTVShow
import com.aryanrogye.movies_shared.network.KTDisplayServer
import com.aryanrogye.movies_shared.network.TMDBClient

enum class MainTab { HOME, LIBRARY, HISTORY, SETTINGS, SEARCH }
enum class LibraryFilter { ALL, TV, MOVIES }

data class DiscoveryItem(val result: KTSearchResult, val imagePath: String?, val adult: Boolean = false)
data class DiscoverySection(val title: String, val items: List<DiscoveryItem> = emptyList(), val loading: Boolean = true, val error: String? = null)

sealed interface AppDestination {
    data class Main(val tab: MainTab) : AppDestination
    data class Detail(val result: KTSearchResult, val history: WatchHistory? = null) : AppDestination
}

class MoviesAppState(context: Context) {
    private val tmdb = TMDBClient()
    private val favoritesRepository = FavoritesRepository(context)
    private val historyRepository = HistoryRepository(context)
    private val token = BuildConfig.TMDB_API_READ_ACCESS_TOKEN.trim()
    private val preferences = context.getSharedPreferences("settings", Context.MODE_PRIVATE)

    val favorites = mutableStateListOf<Favorite>().apply { addAll(favoritesRepository.load()) }
    val history = mutableStateListOf<WatchHistory>().apply { addAll(historyRepository.load()) }
    var includeAdult by mutableStateOf(preferences.getBoolean("include_adult", false))
        private set
    var searchResults by mutableStateOf<List<KTSearchResult>>(emptyList())
        private set
    var destination by mutableStateOf<AppDestination>(AppDestination.Main(MainTab.HOME))
    private var returnTab = MainTab.HOME
    var libraryFilter by mutableStateOf(LibraryFilter.ALL)
    var homeFilter by mutableStateOf(LibraryFilter.ALL)
    var searchQuery by mutableStateOf("")
    val discovery = mutableStateListOf<DiscoverySection>().apply {
        addAll(listOf("Trending", "Now Playing Movies", "Popular TV Shows", "Popular Movies", "Top Rated TV Shows", "Top Rated Movies").map { DiscoverySection(it) })
    }
    private var loadingHome = false
    var displayServer by mutableStateOf(readDisplayServer())
        private set
    var isBusy by mutableStateOf(false)
        private set
    var error by mutableStateOf<String?>(null)
        private set

    val isConfigured: Boolean get() = token.isNotEmpty()

    suspend fun loadHome() {
        if (loadingHome) return
        loadingHome = true
        try {
            discovery.indices.forEach { index ->
                val section = discovery[index]
                if (!section.loading && section.error == null) return@forEach
                discovery[index] = section.copy(loading = true, error = null)
                try {
                    val token = tokenOrThrow()
                    val items = when (index) {
                        0 -> tmdb.trending(token).results.map {
                            DiscoveryItem(KTSearchResult(it.id, it.mediaType, it.title, it.name, it.posterPath, it.overview, it.releaseDate, it.firstAirDate), it.backdropPath, it.adult)
                        }
                        1, 3, 5 -> {
                            val movies = when (index) {
                                1 -> tmdb.nowPlayingMovies(token, 1).results
                                3 -> tmdb.popularMovies(token, 1).results
                                else -> tmdb.topRatedMovies(token, 1).results
                            }
                            movies.map { DiscoveryItem(KTSearchResult(it.id, KTMediaType.MOVIE, title = it.title, posterPath = it.posterPath, overview = it.overview, releaseDate = it.releaseDate), it.backdropPath, it.adult) }
                        }
                        else -> {
                            val shows = if (index == 2) tmdb.popularTV(token, 1).results else tmdb.topRatedTV(token, 1).results
                            shows.map { DiscoveryItem(KTSearchResult(it.id, KTMediaType.TV, name = it.name, posterPath = it.posterPath, overview = it.overview, firstAirDate = it.firstAirDate), it.backdropPath) }
                        }
                    }
                    discovery[index] = section.copy(items = items, loading = false)
                } catch (cancelled: CancellationException) {
                    throw cancelled
                } catch (failure: Exception) {
                    discovery[index] = section.copy(loading = false, error = failure.message ?: "Could not load titles.")
                }
            }
        } finally {
            loadingHome = false
        }
    }

    suspend fun search(query: String) {
        val trimmed = query.trim()
        if (trimmed.isEmpty()) {
            searchResults = emptyList()
            return
        }
        runBusy { searchResults = tmdb.search(trimmed, tokenOrThrow(), includeAdult).results }
    }

    suspend fun openFavorite(favorite: Favorite) {
        returnTab = (destination as? AppDestination.Main)?.tab ?: MainTab.HOME
        runBusy {
            val result = tmdb.search(favorite.name, tokenOrThrow(), includeAdult).results.firstOrNull {
                it.id == favorite.id && it.mediaType.rawValue == favorite.mediaType
            }
            if (result == null) error = "Could not find ${favorite.name} on TMDB."
            else destination = AppDestination.Detail(result)
        }
    }

    suspend fun tvInfo(id: Int): KTTVShow? = runBusyResult { tmdb.infoOnTV(id, tokenOrThrow()) }

    suspend fun openHistory(item: WatchHistory) {
        runBusy {
            val type = if (item.season == null) KTMediaType.MOVIE else KTMediaType.TV
            val result = tmdb.search(item.name, tokenOrThrow(), includeAdult).results
                .firstOrNull { it.id == item.resultId && it.mediaType == type }
            if (result == null) error = "Could not find ${item.name} on TMDB."
            else {
                returnTab = MainTab.HISTORY
                destination = AppDestination.Detail(result, item)
            }
        }
    }

    fun recordWatch(result: KTSearchResult, season: Int? = null, episode: Int? = null) {
        val item = WatchHistory(result.id, result.name ?: result.title.orEmpty(), result.posterPath, season, episode)
        history.removeAll { it.key == item.key }
        history.add(0, item)
        historyRepository.save(history)
    }

    fun removeHistory(item: WatchHistory) {
        history.removeAll { it.key == item.key }
        historyRepository.save(history)
    }

    fun updateIncludeAdult(value: Boolean) {
        includeAdult = value
        preferences.edit().putBoolean("include_adult", value).apply()
    }

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
        } catch (cancelled: CancellationException) {
            throw cancelled
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
        } catch (cancelled: CancellationException) {
            throw cancelled
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
