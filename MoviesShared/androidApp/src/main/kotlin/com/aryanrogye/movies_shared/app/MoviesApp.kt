package com.aryanrogye.movies_shared.app

import androidx.activity.compose.BackHandler
import androidx.compose.animation.animateColorAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.LazyHorizontalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TextField
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.platform.LocalSoftwareKeyboardController
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil3.compose.AsyncImage
import com.aryanrogye.movies_shared.app.components.ExpandableText
import com.aryanrogye.movies_shared.data.Favorite
import com.aryanrogye.movies_shared.data.WatchHistory
import android.text.format.DateUtils
import com.aryanrogye.movies_shared.models.KTEpisode
import com.aryanrogye.movies_shared.models.KTMediaType
import com.aryanrogye.movies_shared.models.KTSearchResult
import com.aryanrogye.movies_shared.models.KTTVShow
import com.aryanrogye.movies_shared.network.KTDisplayServer
import com.aryanrogye.movies_shared.web.AndroidBlockingService
import com.aryanrogye.movies_shared.web.BlockingStatus
import com.aryanrogye.movies_shared.web.MediaWebView
import kotlinx.coroutines.launch

private val AppColors = darkColorScheme(
    primary = Color(0xFFFFD54F),
    background = Color(0xFF07090D),
    surface = Color(0xFF11141B),
    onBackground = Color.White,
    onSurface = Color.White,
)

@Composable
fun MoviesApp() {
    val context = LocalContext.current.applicationContext
    val appState = remember { MoviesAppState(context) }
    val blockingService = remember { AndroidBlockingService(context) }

    MaterialTheme(colorScheme = AppColors) {
        Surface(modifier = Modifier.fillMaxSize(), color = MaterialTheme.colorScheme.background) {
            when (val destination = appState.destination) {
                is AppDestination.Main -> MainShell(appState, blockingService, destination.tab)
                is AppDestination.Detail -> DetailScreen(appState, blockingService, destination.result, destination.history)
            }
            appState.error?.let { message ->
                AlertDialog(
                    onDismissRequest = appState::consumeError,
                    confirmButton = { TextButton(onClick = appState::consumeError) { Text("OK") } },
                    title = { Text("Error") },
                    text = { Text(message) },
                )
            }
        }
    }
}

@Composable
private fun MainShell(appState: MoviesAppState, blockingService: AndroidBlockingService, selectedTab: MainTab) {
    Row(Modifier.fillMaxSize().padding(top = 18.dp, bottom = 18.dp)) {
        Column(
            modifier = Modifier.width(178.dp).fillMaxHeight().padding(horizontal = 16.dp),
            verticalArrangement = Arrangement.Center,
        ) {
            Text("MOVIES", fontWeight = FontWeight.Black, letterSpacing = 3.sp, modifier = Modifier.padding(12.dp))
            Spacer(Modifier.height(24.dp))
            NavButton("⌂  Home", selectedTab == MainTab.HOME) { appState.selectTab(MainTab.HOME) }
            NavButton("▤  Library", selectedTab == MainTab.LIBRARY) { appState.selectTab(MainTab.LIBRARY) }
            NavButton("↺  History", selectedTab == MainTab.HISTORY) { appState.selectTab(MainTab.HISTORY) }
            NavButton("⚙  Settings", selectedTab == MainTab.SETTINGS) { appState.selectTab(MainTab.SETTINGS) }
            NavButton("⌕  Search", selectedTab == MainTab.SEARCH) { appState.selectTab(MainTab.SEARCH) }
        }
        Box(Modifier.weight(1f).fillMaxHeight().padding(end = 28.dp)) {
            when (selectedTab) {
                MainTab.HOME -> HomeScreen(appState)
                MainTab.LIBRARY -> LibraryScreen(appState)
                MainTab.HISTORY -> HistoryScreen(appState)
                MainTab.SEARCH -> SearchScreen(appState)
                MainTab.SETTINGS -> SettingsScreen(appState, blockingService)
            }
        }
    }
}

@Composable
private fun NavButton(label: String, selected: Boolean, onClick: () -> Unit) {
    FocusButton(label, selected = selected, modifier = Modifier.fillMaxWidth().padding(vertical = 5.dp), onClick = onClick)
}

@Composable
private fun HomeScreen(appState: MoviesAppState) {
    val scope = rememberCoroutineScope()
    LaunchedEffect(appState) { appState.loadHome() }
    Column(Modifier.fillMaxSize()) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            ScreenTitle("Home")
            Spacer(Modifier.weight(1f))
            FilterButtons(appState.homeFilter) { appState.homeFilter = it }
        }
        LazyColumn(verticalArrangement = Arrangement.spacedBy(12.dp)) {
            items(appState.discovery.filter { it.matches(appState.homeFilter) }, key = { it.title }) { section ->
                Column {
                    Text(section.title, fontSize = 22.sp, fontWeight = FontWeight.Bold, modifier = Modifier.padding(top = 16.dp, bottom = 12.dp))
                    val visible = section.items.filter { item ->
                        (appState.includeAdult || !item.adult) &&
                            (section.title != "Trending" || when (appState.homeFilter) {
                                LibraryFilter.ALL -> true
                                LibraryFilter.TV -> item.result.mediaType == KTMediaType.TV
                                LibraryFilter.MOVIES -> item.result.mediaType == KTMediaType.MOVIE
                            })
                    }
                    when {
                        section.loading -> Box(Modifier.fillMaxWidth().height(100.dp), contentAlignment = Alignment.Center) { CircularProgressIndicator() }
                        section.error != null -> Column {
                            Text(section.error, color = Color.White.copy(alpha = .65f))
                            FocusButton("Retry", modifier = Modifier.padding(top = 8.dp)) { scope.launch { appState.loadHome() } }
                        }
                        visible.isEmpty() -> Text("No titles available", color = Color.White.copy(alpha = .65f))
                        else -> LazyHorizontalGrid(
                            rows = GridCells.Fixed(2),
                            modifier = Modifier.fillMaxWidth().height(404.dp),
                            horizontalArrangement = Arrangement.spacedBy(12.dp),
                            verticalArrangement = Arrangement.spacedBy(12.dp),
                        ) {
                            items(visible, key = { "${it.result.mediaType.rawValue}:${it.result.id}" }) { item ->
                                FocusSurface(modifier = Modifier.width(110.dp), onClick = { appState.openDetail(item.result) }) {
                                    Column {
                                        Box {
                                            Poster(item.imagePath, item.result.displayName(), Modifier.width(110.dp).height(165.dp))
                                            Text(item.result.mediaType.rawValue, fontSize = 10.sp, fontWeight = FontWeight.Bold,
                                                modifier = Modifier.align(Alignment.TopEnd).padding(5.dp).background(Color.Black.copy(alpha = .6f), CircleShape).padding(horizontal = 5.dp, vertical = 3.dp))
                                        }
                                        Text(item.result.displayName(), fontSize = 14.sp, fontWeight = FontWeight.Medium, maxLines = 1, overflow = TextOverflow.Ellipsis, modifier = Modifier.padding(top = 6.dp))
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun FilterButtons(selected: LibraryFilter, onSelect: (LibraryFilter) -> Unit) {
    LibraryFilter.entries.forEach { filter ->
        FocusButton(when (filter) { LibraryFilter.ALL -> "All"; LibraryFilter.TV -> "TV"; LibraryFilter.MOVIES -> "Movies" },
            selected = selected == filter, modifier = Modifier.padding(start = 8.dp)) { onSelect(filter) }
    }
}

@Composable
private fun LibraryScreen(appState: MoviesAppState) {
    val scope = rememberCoroutineScope()
    val favorites = appState.favorites.filter {
        when (appState.libraryFilter) {
            LibraryFilter.ALL -> true
            LibraryFilter.TV -> it.mediaType == "tv"
            LibraryFilter.MOVIES -> it.mediaType == "movie"
        }
    }
    Column(Modifier.fillMaxSize()) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            ScreenTitle("Library")
            Spacer(Modifier.weight(1f))
            FilterButtons(appState.libraryFilter) { appState.libraryFilter = it }
        }
        Spacer(Modifier.height(18.dp))
        if (appState.favorites.isEmpty()) {
            EmptyMessage("No Favorites Yet", "Movies and shows you favorite will show up here.")
        } else if (favorites.isEmpty()) {
            EmptyMessage("Nothing in this filter", "Try All or another media type.")
        } else {
            Text("Favorites", fontSize = 22.sp, fontWeight = FontWeight.Bold, modifier = Modifier.padding(bottom = 12.dp))
            LazyVerticalGrid(
                columns = GridCells.Adaptive(150.dp),
                horizontalArrangement = Arrangement.spacedBy(18.dp),
                verticalArrangement = Arrangement.spacedBy(18.dp),
            ) {
                items(favorites, key = { it.id }) { favorite ->
                    FavoriteCard(
                        favorite = favorite,
                        onOpen = { scope.launch { appState.openFavorite(favorite) } },
                        onRemove = { appState.removeFavorite(favorite) },
                    )
                }
            }
        }
    }
}

@Composable
private fun SearchScreen(appState: MoviesAppState) {
    var query by appState::searchQuery
    var editing by remember { mutableStateOf(false) }
    val editorFocus = remember { FocusRequester() }
    val searchFieldFocus = remember { FocusRequester() }
    val keyboard = LocalSoftwareKeyboardController.current
    val scope = rememberCoroutineScope()
    fun finishEditing(search: Boolean) {
        keyboard?.hide()
        editing = false
        searchFieldFocus.requestFocus()
        if (search) scope.launch { appState.search(query) }
    }
    if (editing) {
        AlertDialog(
            onDismissRequest = { finishEditing(false) },
            title = { Text("Search") },
            text = {
                TextField(
                    value = query,
                    onValueChange = { query = it },
                    singleLine = true,
                    placeholder = { Text("Search movies, TV, and people") },
                    modifier = Modifier.fillMaxWidth().focusRequester(editorFocus),
                    keyboardOptions = KeyboardOptions(imeAction = ImeAction.Search),
                    keyboardActions = KeyboardActions(onSearch = { finishEditing(true) }),
                )
                LaunchedEffect(Unit) {
                    editorFocus.requestFocus()
                    keyboard?.show()
                }
            },
            confirmButton = { TextButton(onClick = { finishEditing(true) }) { Text("Search") } },
            dismissButton = { TextButton(onClick = { finishEditing(false) }) { Text("Done") } },
        )
    }
    Column(Modifier.fillMaxSize()) {
        ScreenTitle("Search")
        Row(Modifier.padding(vertical = 16.dp), verticalAlignment = Alignment.CenterVertically) {
            FocusSurface(
                modifier = Modifier.weight(1f).focusRequester(searchFieldFocus),
                onClick = { editing = true },
            ) {
                Text(query.ifBlank { "Search movies, TV, and people" },
                    modifier = Modifier.padding(16.dp), maxLines = 1, overflow = TextOverflow.Ellipsis)
            }
            FocusButton("Search", modifier = Modifier.padding(start = 12.dp)) {
                scope.launch { appState.search(query) }
            }
        }
        if (appState.searchResults.isEmpty()) {
            EmptyMessage("Search", "Find movies, TV shows, and people.")
        } else {
            LazyColumn(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                items(appState.searchResults, key = { it.id }) { result ->
                    SearchResultRow(
                        result,
                        favorite = appState.isFavorite(result.id),
                        onOpen = { appState.openDetail(result) },
                        onFavorite = { appState.toggleFavorite(result) },
                    )
                }
            }
        }
    }
}

@Composable
private fun HistoryScreen(appState: MoviesAppState) {
    val scope = rememberCoroutineScope()
    var resolving by remember { mutableStateOf<String?>(null) }
    Column(Modifier.fillMaxSize()) {
        ScreenTitle("History")
        Spacer(Modifier.height(16.dp))
        if (appState.history.isEmpty()) {
            EmptyMessage("No Watch History", "Movies and episodes you watch will show up here.")
        } else {
            LazyColumn(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                items(appState.history, key = { it.key }) { item ->
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        FocusSurface(modifier = Modifier.weight(1f), onClick = {
                            if (resolving == null) scope.launch {
                                resolving = item.key
                                try { appState.openHistory(item) } finally { resolving = null }
                            }
                        }) {
                            Row(Modifier.fillMaxWidth().padding(12.dp), verticalAlignment = Alignment.CenterVertically) {
                                Poster(item.posterPath, item.name, Modifier.width(48.dp).height(64.dp))
                                Column(Modifier.weight(1f).padding(horizontal = 14.dp)) {
                                    Text(item.name, fontWeight = FontWeight.Bold, maxLines = 1, overflow = TextOverflow.Ellipsis)
                                    val media = if (item.season != null) "S${item.season} E${item.episode}" else "Movie"
                                    Text("$media · ${DateUtils.getRelativeTimeSpanString(item.watchedAt)}", color = Color.White.copy(alpha = .6f))
                                }
                                Text(if (resolving == item.key) "Loading…" else "›")
                            }
                        }
                        FocusButton("Remove", modifier = Modifier.padding(start = 10.dp)) { appState.removeHistory(item) }
                    }
                }
            }
        }
    }
}

@Composable
private fun SettingsScreen(appState: MoviesAppState, blockingService: AndroidBlockingService) {
    Column(Modifier.fillMaxSize()) {
        ScreenTitle("Settings")
        Spacer(Modifier.height(20.dp))
        Text("Search Settings", fontSize = 20.sp, fontWeight = FontWeight.SemiBold)
        FocusButton(
            "Include Adult Content: ${if (appState.includeAdult) "On" else "Off"}",
            selected = appState.includeAdult,
            modifier = Modifier.padding(top = 12.dp),
        ) { appState.updateIncludeAdult(!appState.includeAdult) }
        Spacer(Modifier.height(28.dp))
        Text(
            when (blockingService.status) {
                BlockingStatus.PREPARING -> "◌  Preparing Blocking"
                BlockingStatus.READY -> "✓  Blocking Ready"
                BlockingStatus.FAILED -> "!  Blocking unavailable"
            },
            fontSize = 22.sp,
            fontWeight = FontWeight.SemiBold,
            color = if (blockingService.status == BlockingStatus.FAILED) Color(0xFFFF8A80) else Color.White,
        )
        blockingService.error?.let { Text(it, color = Color.White.copy(alpha = .62f), modifier = Modifier.padding(top = 8.dp)) }
        Text(
            "Playback uses the system WebView and preserves the warm renderer when Reload is pressed.",
            color = Color.White.copy(alpha = .62f),
            modifier = Modifier.padding(top = 32.dp),
        )
        if (!appState.isConfigured) {
            Text(
                "TMDB_API_READ_ACCESS_TOKEN is not configured. Set it as a Gradle property or environment variable and rebuild.",
                color = Color(0xFFFFCC80),
                modifier = Modifier.padding(top = 28.dp),
            )
        }
    }
}

@Composable
private fun FavoriteCard(favorite: Favorite, onOpen: () -> Unit, onRemove: () -> Unit) {
    FocusSurface(onClick = onOpen) {
        Column {
            Poster(favorite.posterPath, favorite.name, Modifier.fillMaxWidth().aspectRatio(2f / 3f))
            Row(Modifier.padding(10.dp), verticalAlignment = Alignment.CenterVertically) {
                Column(Modifier.weight(1f)) {
                    Text(favorite.name, fontWeight = FontWeight.Medium, maxLines = 2, overflow = TextOverflow.Ellipsis)
                    Text(if (favorite.mediaType == "tv") "TV" else "Movie", fontSize = 12.sp, color = Color.White.copy(alpha = .55f))
                }
                SmallAction("★", onRemove, "Remove from favorites")
            }
        }
    }
}

@Composable
private fun SearchResultRow(result: KTSearchResult, favorite: Boolean, onOpen: () -> Unit, onFavorite: () -> Unit) {
    Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
      FocusSurface(onClick = onOpen, modifier = Modifier.weight(1f)) {
        Row(Modifier.height(142.dp).padding(8.dp)) {
            Poster(result.posterPath, result.displayName(), Modifier.width(84.dp).fillMaxHeight())
            Column(Modifier.weight(1f).padding(horizontal = 16.dp)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(result.displayName(), fontSize = 20.sp, fontWeight = FontWeight.Bold, modifier = Modifier.weight(1f), maxLines = 1, overflow = TextOverflow.Ellipsis)
                    val year = when (result.mediaType) {
                        KTMediaType.MOVIE -> result.releaseDate
                        KTMediaType.TV -> result.firstAirDate
                        else -> null
                    }?.take(4).orEmpty()
                    Text(year, modifier = Modifier.padding(start = 12.dp), color = Color.White.copy(alpha = .6f))
                }
                Text(result.mediaLabel(), color = Color.White.copy(alpha = .56f), fontSize = 13.sp)
                Text(result.overview.orEmpty(), maxLines = 3, overflow = TextOverflow.Ellipsis, color = Color.White.copy(alpha = .7f), modifier = Modifier.padding(top = 8.dp))
            }
        }
      }
      Spacer(Modifier.width(12.dp))
      SmallAction(if (favorite) "★" else "☆", onFavorite,
          if (favorite) "Remove from favorites" else "Add to favorites")
    }
}

@Composable
private fun DetailScreen(appState: MoviesAppState, blocker: AndroidBlockingService, result: KTSearchResult, history: WatchHistory?) {
    BackHandler { appState.backTo() }
    Column(Modifier.fillMaxSize().padding(horizontal = 28.dp, vertical = 20.dp)) {
        DetailToolbar(appState, onBack = { appState.backTo() })
        Spacer(Modifier.height(14.dp))
        when (result.mediaType) {
            KTMediaType.MOVIE -> MovieDetail(appState, blocker, result)
            KTMediaType.TV -> TvDetail(appState, blocker, result, history)
            KTMediaType.PERSON -> EmptyMessage("Not Yet Supported", "People pages are not available yet.")
        }
    }
}

@Composable
private fun DetailToolbar(appState: MoviesAppState, onBack: () -> Unit) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        FocusButton("‹  Back", onClick = onBack)
        Spacer(Modifier.weight(1f))
        Text("Server", color = Color.White.copy(alpha = .55f), modifier = Modifier.padding(end = 8.dp))
        KTDisplayServer.entries.forEach { server ->
            FocusButton(
                server.rawValue,
                selected = appState.displayServer == server,
                modifier = Modifier.padding(start = 8.dp),
            ) { appState.updateDisplayServer(server) }
        }
    }
}

@Composable
private fun MovieDetail(appState: MoviesAppState, blocker: AndroidBlockingService, result: KTSearchResult) {
    var loaded by remember(result.id) { mutableStateOf(false) }
    var reloadKey by remember { mutableIntStateOf(0) }
    val reloadFocus = remember { FocusRequester() }
    val url = appState.displayServer.loadMovie(result.id)
    if (loaded) {
        LaunchedEffect(result.id, url) { appState.recordWatch(result) }
        BackHandler { loaded = false }
        Column(Modifier.fillMaxSize()) {
            Row(
                Modifier.padding(bottom = 10.dp),
                horizontalArrangement = Arrangement.spacedBy(10.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                FocusButton("‹  Details") { loaded = false }
                FocusButton("↻  Reload", modifier = Modifier.focusRequester(reloadFocus)) { reloadKey++ }
                Text(
                    result.displayName(),
                    fontSize = 20.sp,
                    fontWeight = FontWeight.Bold,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.weight(1f),
                )
                Text("↑ controls", color = Color.White.copy(alpha = .5f))
            }
            MediaWebView(
                url = url,
                reloadKey = reloadKey,
                blockingService = blocker,
                modifier = Modifier.fillMaxSize(),
                onExitFocus = { reloadFocus.requestFocus() },
                onError = appState::reportError,
            )
        }
    } else {
        Hero(result, playLabel = "▶  Play Movie") { loaded = true }
    }
}

@Composable
private fun TvDetail(appState: MoviesAppState, blocker: AndroidBlockingService, result: KTSearchResult, history: WatchHistory?) {
    var show by remember { mutableStateOf<KTTVShow?>(null) }
    var selectedSeason by remember { mutableStateOf<Int?>(null) }
    var episodes by remember { mutableStateOf<List<KTEpisode>>(emptyList()) }
    var selectedEpisode by remember { mutableStateOf<KTEpisode?>(null) }
    var pendingHistory by remember(result.id, history?.key) { mutableStateOf(history) }
    var reloadKey by remember { mutableIntStateOf(0) }
    val reloadFocus = remember { FocusRequester() }

    LaunchedEffect(result.id) {
        val tvShow = appState.tvInfo(result.id)
        show = tvShow
        if (selectedSeason == null && tvShow != null && tvShow.seasons.isNotEmpty()) {
            selectedSeason = history?.season ?: tvShow.seasons.firstOrNull { it.seasonNumber > 0 }?.seasonNumber
                ?: tvShow.seasons.first().seasonNumber
        }
    }

    LaunchedEffect(selectedSeason) {
        selectedSeason?.let { season ->
            selectedEpisode = null
            episodes = emptyList()
            episodes = appState.seasonInfo(result.id, season)?.episodes.orEmpty()
            pendingHistory?.let { saved ->
                if (saved.season == season) {
                    selectedEpisode = episodes.firstOrNull { it.episodeNumber == saved.episode }
                    if (selectedEpisode == null) appState.reportError("This episode is no longer available on TMDB.")
                    pendingHistory = null
                }
            }
        }
    }

    val episode = selectedEpisode
    if (episode != null && selectedSeason != null) {
        BackHandler { selectedEpisode = null }
        val tvUrl = appState.displayServer.loadTvShow(result.id, selectedSeason!!, episode.episodeNumber)
        LaunchedEffect(tvUrl) { appState.recordWatch(result, selectedSeason, episode.episodeNumber) }
        Column(Modifier.fillMaxSize()) {
            Row(
                Modifier.padding(bottom = 10.dp),
                horizontalArrangement = Arrangement.spacedBy(10.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                FocusButton("‹  Episodes") { selectedEpisode = null }
                FocusButton("↻  Reload", modifier = Modifier.focusRequester(reloadFocus)) { reloadKey++ }
                Text(
                    text = "${result.displayName()} · S$selectedSeason E${episode.episodeNumber}${if (!episode.name.isNullOrBlank()) ": ${episode.name}" else ""}",
                    fontSize = 20.sp,
                    fontWeight = FontWeight.Bold,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.weight(1f),
                )
                Text("↑ controls", color = Color.White.copy(alpha = .5f))
            }
            EpisodeInfo(episode)
            MediaWebView(
                url = tvUrl,
                reloadKey = reloadKey,
                blockingService = blocker,
                modifier = Modifier.fillMaxSize(),
                onExitFocus = { reloadFocus.requestFocus() },
                onError = appState::reportError,
            )
        }
    } else {
        LazyColumn(Modifier.fillMaxSize()) {
            item { Hero(result, backdropPath = show?.backdropPath, playLabel = null, onPlay = {}) }
            item {
                TvSelectors(
                    show = show,
                    selectedSeason = selectedSeason,
                    episodes = episodes,
                    selectedEpisode = episode,
                    onSeason = { selectedSeason = it },
                    onEpisode = { selectedEpisode = it },
                )
            }
        }
    }
}

@Composable
private fun EpisodeInfo(episode: KTEpisode) {
    val overview = episode.overview.trim()

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(bottom = 12.dp),
    ) {
        Text(
            episode.name.ifBlank { "Episode ${episode.episodeNumber}" },
            fontSize = 20.sp,
            fontWeight = FontWeight.SemiBold,
        )
        if (overview.isNotEmpty()) {
            ExpandableText(
                text = overview,
                modifier = Modifier.padding(top = 4.dp),
            )
        }
    }
}

@Composable
private fun TvSelectors(
    show: KTTVShow?,
    selectedSeason: Int?,
    episodes: List<KTEpisode>,
    selectedEpisode: KTEpisode?,
    onSeason: (Int) -> Unit,
    onEpisode: (KTEpisode) -> Unit,
) {
    show ?: return
    Column(Modifier.padding(vertical = 18.dp)) {
        Text("Seasons", fontSize = 22.sp, fontWeight = FontWeight.Bold)
        LazyRow(horizontalArrangement = Arrangement.spacedBy(10.dp), modifier = Modifier.padding(top = 10.dp)) {
            items(show.seasons, key = { it.id }) { season ->
                FocusButton("Season ${season.seasonNumber}", selected = selectedSeason == season.seasonNumber) { onSeason(season.seasonNumber) }
            }
        }
        if (episodes.isNotEmpty()) {
            Text("Episodes", fontSize = 22.sp, fontWeight = FontWeight.Bold, modifier = Modifier.padding(top = 20.dp))
            LazyRow(horizontalArrangement = Arrangement.spacedBy(10.dp), modifier = Modifier.padding(top = 10.dp)) {
                items(episodes, key = { it.id }) { episode ->
                    FocusButton("Episode ${episode.episodeNumber}", selected = selectedEpisode?.id == episode.id) { onEpisode(episode) }
                }
            }
        }
    }
}

@Composable
private fun Hero(result: KTSearchResult, backdropPath: String? = null, playLabel: String?, onPlay: () -> Unit) {
    Box(Modifier.fillMaxWidth().height(430.dp).clip(RoundedCornerShape(16.dp)).background(Color(0xFF161A22))) {
        AsyncImage(
            model = imageUrl(backdropPath ?: result.posterPath),
            contentDescription = result.displayName(),
            contentScale = ContentScale.Crop,
            modifier = Modifier.fillMaxSize(),
        )
        Box(Modifier.fillMaxSize().background(Brush.verticalGradient(listOf(Color.Transparent, Color.Black.copy(alpha = .2f), Color.Black))))
        Column(Modifier.align(Alignment.BottomStart).fillMaxWidth(.72f).padding(30.dp)) {
            Text(result.displayName(), fontSize = 42.sp, lineHeight = 48.sp, fontFamily = FontFamily.Serif, fontWeight = FontWeight.SemiBold, maxLines = 2, overflow = TextOverflow.Ellipsis)
            Text(result.overview.orEmpty(), maxLines = 3, overflow = TextOverflow.Ellipsis, color = Color.White.copy(alpha = .78f), lineHeight = 22.sp, modifier = Modifier.padding(vertical = 12.dp))
            playLabel?.let { FocusButton(it, onClick = onPlay) }
        }
    }
}

@Composable
private fun Poster(path: String?, description: String, modifier: Modifier) {
    AsyncImage(
        model = imageUrl(path),
        contentDescription = description,
        contentScale = ContentScale.Crop,
        modifier = modifier.clip(RoundedCornerShape(10.dp)).background(Color(0xFF252A34)),
    )
}

@Composable
private fun FocusSurface(modifier: Modifier = Modifier, onClick: () -> Unit, content: @Composable () -> Unit) {
    var focused by remember { mutableStateOf(false) }
    val borderColor by animateColorAsState(if (focused) MaterialTheme.colorScheme.primary else Color.Transparent, label = "focus border")
    Surface(
        modifier = modifier.onFocusChanged { focused = it.isFocused }.border(2.dp, borderColor, RoundedCornerShape(14.dp)).clip(RoundedCornerShape(14.dp)).clickable(onClick = onClick),
        color = MaterialTheme.colorScheme.surface,
        shape = RoundedCornerShape(14.dp),
        content = content,
    )
}

@Composable
private fun FocusButton(label: String, modifier: Modifier = Modifier, selected: Boolean = false, onClick: () -> Unit) {
    var focused by remember { mutableStateOf(false) }
    val background by animateColorAsState(
        when { focused -> Color.White; selected -> Color.White.copy(alpha = .2f); else -> Color.White.copy(alpha = .07f) },
        label = "button background",
    )
    val foreground = if (focused) Color.Black else Color.White
    Surface(
        modifier = modifier.onFocusChanged { focused = it.isFocused }.clip(RoundedCornerShape(50)).clickable(onClick = onClick),
        color = background,
        contentColor = foreground,
        shape = RoundedCornerShape(50),
    ) { Text(label, fontWeight = FontWeight.SemiBold, modifier = Modifier.padding(horizontal = 18.dp, vertical = 11.dp)) }
}

@Composable
private fun SmallAction(symbol: String, onClick: () -> Unit, label: String = symbol) {
    var focused by remember { mutableStateOf(false) }
    Surface(
        modifier = Modifier.size(44.dp).semantics { contentDescription = label }.onFocusChanged { focused = it.isFocused }.clip(CircleShape).clickable(onClick = onClick),
        color = if (focused) Color.White else Color.White.copy(alpha = .08f),
        contentColor = if (focused) Color.Black else Color.White,
        shape = CircleShape,
    ) { Box(contentAlignment = Alignment.Center) { Text(symbol, fontSize = 23.sp) } }
}

@Composable
private fun ScreenTitle(text: String) = Text(text, fontSize = 34.sp, fontWeight = FontWeight.Bold)

@Composable
private fun EmptyMessage(title: String, detail: String) {
    Column(Modifier.fillMaxSize(), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.Center) {
        Text(title, fontSize = 26.sp, fontWeight = FontWeight.Bold)
        Text(detail, color = Color.White.copy(alpha = .58f), modifier = Modifier.padding(top = 8.dp))
    }
}

private fun KTSearchResult.displayName(): String = name ?: title ?: "Unknown"
private fun KTSearchResult.mediaLabel(): String = when (mediaType) {
    KTMediaType.TV -> "TV Show"
    KTMediaType.MOVIE -> "Movie"
    KTMediaType.PERSON -> "Person"
}
private fun imageUrl(path: String?): String? = path?.let { "https://image.tmdb.org/t/p/w500$it" }
