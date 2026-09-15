package com.aryanrogye.movies_shared.network

import com.aryanrogye.movies_shared.models.KTSearchResponse
import com.aryanrogye.movies_shared.models.KTSeasonInfo
import com.aryanrogye.movies_shared.models.KTTVShow
import io.ktor.client.HttpClient
import io.ktor.client.call.body
import io.ktor.client.plugins.contentnegotiation.ContentNegotiation
import io.ktor.client.request.get
import io.ktor.client.request.header
import io.ktor.client.request.parameter
import io.ktor.serialization.kotlinx.json.json
import kotlinx.serialization.ExperimentalSerializationApi
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonNamingStrategy

class TMDBClient {

    @OptIn(ExperimentalSerializationApi::class)
    private val client = HttpClient {
        install(ContentNegotiation) {
            json(
                Json {
                    ignoreUnknownKeys = true
                    namingStrategy = JsonNamingStrategy.SnakeCase
                }
            )
        }
    }

    suspend fun search(query: String, token: String): KTSearchResponse {
        val response = client.get("https://api.themoviedb.org/3/search/multi") {
            parameter("query", query)
            parameter("include_adult", true)
            parameter("language", "en-US")
            parameter("page", 1)

            header("accept", "application/json")
            header("Authorization", "Bearer $token")
        }

        return response.body()
    }

    suspend fun infoOnTV(id: Int, token: String): KTTVShow {
        val response = client.get("https://api.themoviedb.org/3/tv/$id") {
            parameter("language", "en-US")

            header("accept", "application/json")
            header("Authorization", "Bearer $token")
        }

        return response.body()
    }

    suspend fun seasonInfo(id: Int, seasonNumber: Int, token: String): KTSeasonInfo {
        val response = client.get("https://api.themoviedb.org/3/tv/$id/season/$seasonNumber") {
            parameter("language", "en-US")

            header("accept", "application/json")
            header("Authorization", "Bearer $token")
        }

        return response.body()
    }
}