package com.aryanrogye.movies_shared

import com.aryanrogye.movies_shared.models.KTMovieListResponse
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlinx.serialization.ExperimentalSerializationApi
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonNamingStrategy

class PopularMovieModelTest {

    @OptIn(ExperimentalSerializationApi::class)
    @Test
    fun decodesPopularMovieResponse() {
        val json = Json {
            ignoreUnknownKeys = true
            namingStrategy = JsonNamingStrategy.SnakeCase
        }

        val response = json.decodeFromString<KTMovieListResponse>(SAMPLE_RESPONSE)

        assertEquals(1, response.page)
        assertEquals(38029, response.totalPages)
        assertEquals(760569, response.totalResults)
        assertEquals(1, response.results.size)

        val movie = response.results.single()
        assertEquals(640146, movie.id)
        assertEquals("Ant-Man and the Wasp: Quantumania", movie.title)
        assertEquals("Ant-Man and the Wasp: Quantumania", movie.originalTitle)
        assertEquals("2023-02-15", movie.releaseDate)
        assertEquals(listOf(28, 12, 878), movie.genreIds)
        assertFalse(movie.adult)
        assertFalse(movie.video)
    }

    private companion object {
        const val SAMPLE_RESPONSE = """
            {
              "page": 1,
              "results": [
                {
                  "adult": false,
                  "backdrop_path": "/gMJngTNfaqCSCqGD4y8lVMZXKDn.jpg",
                  "genre_ids": [28, 12, 878],
                  "id": 640146,
                  "original_language": "en",
                  "original_title": "Ant-Man and the Wasp: Quantumania",
                  "overview": "Scott Lang and Hope van Dyne explore the Quantum Realm.",
                  "popularity": 8567.865,
                  "poster_path": "/ngl2FKBlU4fhbdsrtdom9LVLBXw.jpg",
                  "release_date": "2023-02-15",
                  "title": "Ant-Man and the Wasp: Quantumania",
                  "video": false,
                  "vote_average": 6.5,
                  "vote_count": 1886
                }
              ],
              "total_pages": 38029,
              "total_results": 760569
            }
        """
    }
}
