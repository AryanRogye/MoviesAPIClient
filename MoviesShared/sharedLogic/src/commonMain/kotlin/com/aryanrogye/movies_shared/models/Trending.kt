package com.aryanrogye.movies_shared.models
import kotlinx.serialization.Serializable


@Serializable
data class KTTrendingResult(
    val adult: Boolean = false,
    val backdropPath: String? = null,
    val id: Int,
    val title: String? = null,
    val originalTitle: String? = null,
    val releaseDate: String? = null,
    val video: Boolean? = null,
    val name: String? = null,
    val originalName: String? = null,
    val firstAirDate: String? = null,
    val originCountry: List<String>? = null,
    val originalLanguage: String,
    val overview: String? = null,
    val posterPath: String? = null,
    val mediaType: KTMediaType,
    val genreIds: List<Int> = emptyList(),
    val popularity: Double,
    val voteAverage: Double,
    val voteCount: Int,
)

@Serializable
data class KTTrendingResponse(
    val page: Int,
    val results: List<KTTrendingResult>,
    val totalPages: Int,
    val totalResults: Int,
)
