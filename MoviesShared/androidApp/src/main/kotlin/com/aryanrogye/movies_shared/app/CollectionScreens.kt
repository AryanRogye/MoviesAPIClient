package com.aryanrogye.movies_shared.app

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TextField
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil3.compose.AsyncImage
import com.aryanrogye.movies_shared.data.MovieCollection
import com.aryanrogye.movies_shared.models.KTSearchResult
import kotlinx.coroutines.launch

@Composable
internal fun CollectionNameDialog(onDismiss: () -> Unit, onCreate: (String) -> Unit) {
    var name by remember { mutableStateOf("") }
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("New Collection") },
        text = {
            TextField(
                value = name,
                onValueChange = { name = it },
                label = { Text("Collection name") },
                singleLine = true,
            )
        },
        confirmButton = {
            TextButton(onClick = { onCreate(name) }, enabled = name.isNotBlank()) { Text("Create") }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text("Cancel") } },
    )
}

@Composable
internal fun CollectionPickerDialog(appState: MoviesAppState, result: KTSearchResult, onDismiss: () -> Unit) {
    var creating by remember { mutableStateOf(false) }
    var lockedCollection by remember { mutableStateOf<MovieCollection?>(null) }
    if (creating) {
        CollectionNameDialog(onDismiss = { creating = false }) {
            appState.createCollection(it, result)
            onDismiss()
        }
        return
    }
    lockedCollection?.let { locked ->
        PinEntryDialog(
            title = "Unlock ${locked.name}",
            onDismiss = { lockedCollection = null },
            onSubmit = { pin ->
                if (locked.accepts(pin)) {
                    appState.toggleCollectionItem(locked.id, result)
                    onDismiss()
                    true
                } else false
            },
        )
        return
    }
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Collections") },
        text = {
            LazyColumn(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                items(appState.collections, key = { it.id }) { collection ->
                    val contains = collection.items.any {
                        it.id == result.id && it.mediaType == result.mediaType.rawValue
                    }
                    FocusButton(
                        "${if (contains) "✓  " else ""}${collection.name}${if (collection.isProtected) "  🔒" else ""}",
                        selected = contains,
                        modifier = Modifier.fillMaxWidth(),
                    ) {
                        if (collection.isProtected) lockedCollection = collection
                        else appState.toggleCollectionItem(collection.id, result)
                    }
                }
            }
        },
        confirmButton = { TextButton(onClick = { creating = true }) { Text("New Collection") } },
        dismissButton = { TextButton(onClick = onDismiss) { Text("Done") } },
    )
}

@Composable
internal fun CollectionCard(collection: MovieCollection, onOpen: () -> Unit) {
    FocusSurface(modifier = Modifier.width(150.dp), onClick = onOpen) {
        Column {
            CollectionArtwork(collection, Modifier.fillMaxWidth().aspectRatio(2f / 3f))
            Text(
                collection.name,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                fontWeight = FontWeight.SemiBold,
                modifier = Modifier.padding(10.dp),
            )
            if (collection.isProtected) Text("Locked", color = Color.White.copy(alpha = .6f), modifier = Modifier.padding(start = 10.dp, bottom = 10.dp))
        }
    }
}

@Composable
private fun CollectionArtwork(collection: MovieCollection, modifier: Modifier = Modifier) {
    val paths = collection.items.mapNotNull { it.posterPath }.take(4)
    Box(modifier.clip(androidx.compose.foundation.shape.RoundedCornerShape(10.dp)).background(Color(0xFF252A34))) {
        if (collection.hidesCoverImage || paths.isEmpty()) {
            Text("▤", fontSize = 48.sp, color = Color.White.copy(alpha = .55f), modifier = Modifier.align(Alignment.Center))
        } else if (paths.size == 1) {
            ArtworkImage(paths[0], Modifier.fillMaxSize())
        } else if (paths.size == 2) {
            Column(Modifier.fillMaxSize()) {
                paths.forEach { path -> ArtworkImage(path, Modifier.weight(1f).fillMaxWidth()) }
            }
        } else if (paths.size == 3) {
            Row(Modifier.fillMaxSize()) {
                ArtworkImage(paths[0], Modifier.weight(1f).fillMaxSize())
                Column(Modifier.weight(1f).fillMaxSize()) {
                    ArtworkImage(paths[1], Modifier.weight(1f).fillMaxWidth())
                    ArtworkImage(paths[2], Modifier.weight(1f).fillMaxWidth())
                }
            }
        } else {
            Column(Modifier.fillMaxSize()) {
                repeat(2) { row ->
                    Row(Modifier.weight(1f)) {
                        repeat(2) { column ->
                            ArtworkImage(paths[row * 2 + column], Modifier.weight(1f).fillMaxSize())
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun ArtworkImage(path: String?, modifier: Modifier) {
    AsyncImage(
        model = path?.let { "https://image.tmdb.org/t/p/w500$it" },
        contentDescription = null,
        contentScale = ContentScale.Crop,
        modifier = modifier.background(Color(0xFF252A34)),
    )
}

@Composable
internal fun CollectionDetailScreen(appState: MoviesAppState, id: String) {
    val collection = appState.collections.firstOrNull { it.id == id }
    var passwordAction by remember { mutableStateOf<PasswordAction?>(null) }
    val scope = rememberCoroutineScope()
    BackHandler { appState.backTo(MainTab.LIBRARY) }
    if (collection == null) {
        EmptyMessage("Collection unavailable", "Return to Library and try again.")
        return
    }
    passwordAction?.let { action ->
        PasswordActionDialog(
            collection = collection,
            action = action,
            onDismiss = { passwordAction = null },
            onUpdate = { updated ->
                appState.updateCollection(updated)
                if (updated.isProtected) appState.unlockCollection(id)
                passwordAction = null
            },
        )
    }
    if (collection.isProtected && !appState.isCollectionUnlocked(id)) {
        Column(Modifier.fillMaxSize().padding(28.dp), horizontalAlignment = Alignment.CenterHorizontally) {
            FocusButton("‹  Library", modifier = Modifier.align(Alignment.Start)) { appState.backTo(MainTab.LIBRARY) }
            Spacer(Modifier.height(36.dp))
            ScreenTitle(collection.name)
            Spacer(Modifier.height(18.dp))
            PinEntry(title = "Enter collection PIN", onSubmit = { pin ->
                val valid = collection.accepts(pin)
                if (valid) appState.unlockCollection(id)
                valid
            })
        }
        return
    }
    Column(Modifier.fillMaxSize().padding(horizontal = 28.dp, vertical = 20.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            FocusButton("‹  Library") { appState.backTo(MainTab.LIBRARY) }
            Text(collection.name, fontSize = 30.sp, fontWeight = FontWeight.Bold, modifier = Modifier.padding(start = 18.dp))
            Spacer(Modifier.weight(1f))
            FocusButton(if (collection.hidesCoverImage) "Show Cover" else "Hide Cover") {
                appState.updateCollection(collection.copy(hidesCoverImage = !collection.hidesCoverImage))
            }
            FocusButton(if (collection.isProtected) "Change PIN" else "Set PIN", modifier = Modifier.padding(start = 8.dp)) {
                passwordAction = if (collection.isProtected) PasswordAction.CHANGE else PasswordAction.SET
            }
            if (collection.isProtected) FocusButton("Remove PIN", modifier = Modifier.padding(start = 8.dp)) {
                passwordAction = PasswordAction.REMOVE
            }
        }
        Spacer(Modifier.height(22.dp))
        if (collection.items.isEmpty()) {
            EmptyMessage("No Titles Yet", "Add movies or shows from Search or a detail page.")
        } else {
            LazyVerticalGrid(
                columns = GridCells.Adaptive(150.dp),
                horizontalArrangement = Arrangement.spacedBy(18.dp),
                verticalArrangement = Arrangement.spacedBy(18.dp),
            ) {
                items(collection.items, key = { "${it.mediaType}:${it.id}" }) { item ->
                    Column {
                        FocusSurface(onClick = { scope.launch { appState.openCollectionItem(collection.id, item) } }) {
                            Column {
                                ArtworkImage(item.posterPath, Modifier.fillMaxWidth().aspectRatio(2f / 3f))
                                Text(item.name, maxLines = 1, overflow = TextOverflow.Ellipsis, modifier = Modifier.padding(8.dp))
                                Text(if (item.mediaType == "tv") "TV" else "Movie", color = Color.White.copy(alpha = .6f), modifier = Modifier.padding(start = 8.dp, bottom = 8.dp))
                            }
                        }
                        FocusButton("Remove", modifier = Modifier.padding(top = 6.dp)) {
                            appState.updateCollection(collection.copy(items = collection.items.filterNot {
                                it.id == item.id && it.mediaType == item.mediaType
                            }))
                        }
                    }
                }
            }
        }
    }
}

private enum class PasswordAction { SET, CHANGE, REMOVE }
private enum class PasswordStage { CURRENT, NEW, CONFIRM }

@Composable
private fun PasswordActionDialog(
    collection: MovieCollection,
    action: PasswordAction,
    onDismiss: () -> Unit,
    onUpdate: (MovieCollection) -> Unit,
) {
    var stage by remember(action) { mutableStateOf(if (action == PasswordAction.SET) PasswordStage.NEW else PasswordStage.CURRENT) }
    var proposedPin by remember(action) { mutableStateOf("") }
    PinEntryDialog(
        title = when (stage) {
            PasswordStage.CURRENT -> "Enter current PIN"
            PasswordStage.NEW -> "Set a four digit PIN"
            PasswordStage.CONFIRM -> "Confirm new PIN"
        },
        onDismiss = onDismiss,
        onSubmit = { pin ->
            when (stage) {
                PasswordStage.CURRENT -> {
                    if (!collection.accepts(pin)) false
                    else {
                        if (action == PasswordAction.REMOVE) onUpdate(collection.withoutPassword())
                        else stage = PasswordStage.NEW
                        true
                    }
                }
                PasswordStage.NEW -> { proposedPin = pin; stage = PasswordStage.CONFIRM; true }
                PasswordStage.CONFIRM -> {
                    if (pin != proposedPin) false
                    else { onUpdate(collection.withPassword(pin)); true }
                }
            }
        },
    )
}

@Composable
private fun PinEntryDialog(title: String, onDismiss: () -> Unit, onSubmit: (String) -> Boolean) {
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(title) },
        text = { PinEntry(title = null, onSubmit = onSubmit) },
        confirmButton = {},
        dismissButton = { TextButton(onClick = onDismiss) { Text("Cancel") } },
    )
}

@Composable
private fun PinEntry(title: String?, onSubmit: (String) -> Boolean) {
    var pin by remember(title) { mutableStateOf("") }
    var invalid by remember(title) { mutableStateOf(false) }
    Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(10.dp)) {
        title?.let { Text(it, fontSize = 20.sp, fontWeight = FontWeight.SemiBold) }
        Text("●".repeat(pin.length) + "○".repeat(4 - pin.length), fontSize = 28.sp, letterSpacing = 8.sp)
        if (invalid) Text("PIN does not match. Try again.", color = MaterialTheme.colorScheme.error)
        listOf(listOf(1, 2, 3), listOf(4, 5, 6), listOf(7, 8, 9)).forEach { row ->
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                row.forEach { digit ->
                    FocusButton(digit.toString(), modifier = Modifier.width(68.dp)) {
                        if (pin.length < 4) { pin += digit; invalid = false }
                    }
                }
            }
        }
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            FocusButton("⌫", modifier = Modifier.width(68.dp)) { pin = pin.dropLast(1); invalid = false }
            FocusButton("0", modifier = Modifier.width(68.dp)) { if (pin.length < 4) { pin += "0"; invalid = false } }
            FocusButton("Enter", modifier = Modifier.width(90.dp)) {
                if (pin.length == 4) {
                    if (onSubmit(pin)) pin = "" else { pin = ""; invalid = true }
                }
            }
        }
    }
}
