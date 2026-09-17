package com.aryanrogye.movies_shared

import com.aryanrogye.movies_shared.network.TMDBClient
import com.aryanrogye.movies_shared.models.KTMediaType
import com.aryanrogye.movies_shared.models.KTSearchResult
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNotNull
import kotlin.test.assertTrue
import kotlinx.coroutines.test.runTest

class TMDBClientTest {

    private val client = TMDBClient()

    @Test
    fun searchReturnsLabRats() = runTest {
        val result = client.search(
            "Lab Rats",
            requireToken(),
            includeAdult = false,
        )

        val labRats = result.results.firstOrNull {
            it.mediaType == KTMediaType.TV && it.name == "Lab Rats"
        }

        assertNotNull(labRats, "Expected the Lab Rats TV series in the search results.")
        assertTrue(labRats.id > 0)
        assertFalse(labRats.overview.isNullOrBlank())
    }

    @Test
    fun popularTVReturnsRequestedPage() = runTest {
        val result = client.popularTV(requireToken(), page = 1)

        assertEquals(1, result.page)
        assertTrue(result.totalPages > 0)
        assertTrue(result.totalResults > 0)
        assertTrue(result.results.isNotEmpty())
        assertTrue(result.results.all { it.id > 0 && it.name.isNotBlank() })
    }

    @Test
    fun popularMoviesReturnsRequestedPage() = runTest {
        val result = client.popularMovies(requireToken(), page = 1)

        assertEquals(1, result.page)
        assertTrue(result.totalPages > 0)
        assertTrue(result.totalResults > 0)
        assertTrue(result.results.isNotEmpty())
        assertTrue(result.results.all { it.id > 0 && it.title.isNotBlank() })
    }

    @Test
    fun topRatedMoviesReturnsRequestedPage() = runTest {
        val result = client.topRatedMovies(requireToken(), page = 1)

        assertEquals(1, result.page)
        assertTrue(result.totalPages > 0)
        assertTrue(result.totalResults > 0)
        assertTrue(result.results.isNotEmpty())
        assertTrue(result.results.all { it.id > 0 && it.title.isNotBlank() })
        assertTrue(result.results.all { it.voteAverage >= 0.0 })
    }

    @Test
    fun topRatedTVReturnsRequestedPage() = runTest {
        val result = client.topRatedTV(requireToken(), page = 1)

        assertEquals(1, result.page)
        assertTrue(result.totalPages > 0)
        assertTrue(result.totalResults > 0)
        assertTrue(result.results.isNotEmpty())
        assertTrue(result.results.all { it.id > 0 && it.name.isNotBlank() })
        assertTrue(result.results.all { it.voteAverage >= 0.0 })
    }

    @Test
    fun nowPlayingMoviesReturnsDatesAndRequestedPage() = runTest {
        val result = client.nowPlayingMovies(requireToken(), page = 1)

        assertEquals(1, result.page)
        assertTrue(result.dates.minimum.isNotBlank())
        assertTrue(result.dates.maximum.isNotBlank())
        assertTrue(result.dates.minimum <= result.dates.maximum)
        assertTrue(result.totalPages > 0)
        assertTrue(result.totalResults > 0)
        assertTrue(result.results.isNotEmpty())
        assertTrue(result.results.all { it.id > 0 && it.title.isNotBlank() })
    }

    @Test
    fun trendingReturnsTypedMedia() = runTest {
        val result = client.trending(requireToken())

        assertTrue(result.page > 0)
        assertTrue(result.results.isNotEmpty())
        assertTrue(result.results.all { item ->
            item.id > 0 && (item.title?.isNotBlank() == true || item.name?.isNotBlank() == true)
        })
    }

    @Test
    fun tvInfoReturnsLabRatsDetails() = runTest {
        val token = requireToken()
        val labRats = findLabRats(token)
        val result = client.infoOnTV(labRats.id, token)

        assertEquals(labRats.id, result.id)
        assertEquals("Lab Rats", result.name)
        assertTrue(result.numberOfSeasons > 0)
        assertTrue(result.numberOfEpisodes > 0)
        assertTrue(result.seasons.isNotEmpty())
    }

    @Test
    fun seasonInfoReturnsEpisodes() = runTest {
        val token = requireToken()
        val labRats = findLabRats(token)
        val result = client.seasonInfo(
            id = labRats.id,
            seasonNumber = 1,
            token = token,
        )

        assertEquals(1, result.seasonNumber)
        assertTrue(result.episodes.isNotEmpty())
        assertTrue(result.episodes.all { it.seasonNumber == 1 && it.episodeNumber > 0 })
    }

    private fun requireToken(): String {
        val token = testEnvironmentVariable("TMDB_API_READ_ACCESS_TOKEN")
        assertFalse(
            token.isNullOrBlank(),
            "Set TMDB_API_READ_ACCESS_TOKEN in local.properties, Gradle properties, or the environment.",
        )
        return requireNotNull(token).trim()
    }

    private suspend fun findLabRats(token: String): KTSearchResult {
        val result = client.search("Lab Rats", token, includeAdult = false)
        return assertNotNull(
            result.results.firstOrNull {
                it.mediaType == KTMediaType.TV && it.name == "Lab Rats"
            },
            "Expected the Lab Rats TV series in the search results.",
        )
    }
}

internal expect fun testEnvironmentVariable(name: String): String?
