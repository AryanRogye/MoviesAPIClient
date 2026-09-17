package com.aryanrogye.movies_shared

import com.aryanrogye.movies_shared.models.KTNowPlayingMovieResponse
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlinx.serialization.ExperimentalSerializationApi
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonNamingStrategy

class NowPlayingMovieModelTest {

    @OptIn(ExperimentalSerializationApi::class)
    @Test
    fun decodesDatesAndMovieResults() {
        val json = Json {
            ignoreUnknownKeys = true
            namingStrategy = JsonNamingStrategy.SnakeCase
        }

        val response = json.decodeFromString<KTNowPlayingMovieResponse>(SAMPLE_RESPONSE)

        assertEquals("2023-03-16", response.dates.minimum)
        assertEquals("2023-05-03", response.dates.maximum)
        assertEquals(1, response.page)
        assertEquals(87, response.totalPages)
        assertEquals(1734, response.totalResults)

        val movie = response.results.single()
        assertEquals(502356, movie.id)
        assertEquals("The Super Mario Bros. Movie", movie.title)
        assertEquals("2023-04-05", movie.releaseDate)
        assertEquals(listOf(16, 12, 10751, 14, 35), movie.genreIds)
    }

    private companion object {
        const val SAMPLE_RESPONSE = """
            {
              "dates": {
                "maximum": "2023-05-03",
                "minimum": "2023-03-16"
              },
              "page": 1,
              "results": [
                {
                  "adult": false,
                  "backdrop_path": "/iJQIbOPm81fPEGKt5BPuZmfnA54.jpg",
                  "genre_ids": [16, 12, 10751, 14, 35],
                  "id": 502356,
                  "original_language": "en",
                  "original_title": "The Super Mario Bros. Movie",
                  "overview": "Mario embarks on an epic quest to find Luigi.",
                  "popularity": 6572.614,
                  "poster_path": "/qNBAXBIQlnOThrVvA6mA2B5ggV6.jpg",
                  "release_date": "2023-04-05",
                  "title": "The Super Mario Bros. Movie",
                  "video": false,
                  "vote_average": 7.5,
                  "vote_count": 1456
                }
              ],
              "total_pages": 87,
              "total_results": 1734
            }
        """
    }
}
