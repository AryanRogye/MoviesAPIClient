package com.aryanrogye.movies_shared.models

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
enum class KTMediaType(val rawValue: String) {
    @SerialName("tv")
    TV("tv"),

    @SerialName("movie")
    MOVIE("movie"),

    @SerialName("person")
    PERSON("person")
}

@Serializable
data class KTSearchResult(
    val id: Int,
    val mediaType: KTMediaType,
    val title: String? = null,
    val name: String? = null,
    val posterPath: String? = null,
    val overview: String? = null,
    val releaseDate: String? = null,
    val firstAirDate: String? = null,
)

@Serializable
data class KTSearchResponse(
    val results: List<KTSearchResult>
)