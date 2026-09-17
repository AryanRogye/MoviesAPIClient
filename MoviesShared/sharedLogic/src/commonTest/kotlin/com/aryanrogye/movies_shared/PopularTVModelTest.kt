package com.aryanrogye.movies_shared

import com.aryanrogye.movies_shared.models.KTTVListResponse
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull
import kotlinx.serialization.ExperimentalSerializationApi
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonNamingStrategy

class PopularTVModelTest {

    @OptIn(ExperimentalSerializationApi::class)
    @Test
    fun decodesSnakeCaseResponseAndNullablePaths() {
        val json = Json {
            ignoreUnknownKeys = true
            namingStrategy = JsonNamingStrategy.SnakeCase
        }

        val response = json.decodeFromString<KTTVListResponse>(SAMPLE_RESPONSE)

        assertEquals(1, response.page)
        assertEquals(7416, response.totalPages)
        assertEquals(148302, response.totalResults)
        assertEquals(1, response.results.size)

        val show = response.results.single()
        assertEquals(36361, show.id)
        assertEquals("Ulice", show.name)
        assertEquals("2005-09-05", show.firstAirDate)
        assertEquals(listOf(18, 35), show.genreIds)
        assertEquals(listOf("CZ"), show.originCountry)
        assertNull(show.backdropPath)
    }

    private companion object {
        const val SAMPLE_RESPONSE = """
            {
              "page": 1,
              "results": [
                {
                  "backdrop_path": null,
                  "first_air_date": "2005-09-05",
                  "genre_ids": [18, 35],
                  "id": 36361,
                  "name": "Ulice",
                  "origin_country": ["CZ"],
                  "original_language": "cs",
                  "original_name": "Ulice",
                  "overview": "A Czech soap opera.",
                  "popularity": 2539.81,
                  "poster_path": "/3ayWL13P1HeRnyVL9lU9flOdZjq.jpg",
                  "vote_average": 2.2,
                  "vote_count": 10
                }
              ],
              "total_pages": 7416,
              "total_results": 148302
            }
        """
    }
}
