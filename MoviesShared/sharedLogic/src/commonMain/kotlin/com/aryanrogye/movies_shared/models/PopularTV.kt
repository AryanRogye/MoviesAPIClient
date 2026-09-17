package com.aryanrogye.movies_shared.models

import kotlinx.serialization.Serializable

@Serializable
data class KTTVListResult(
    val backdropPath: String? = null,
    val firstAirDate: String? = null,
    val genreIds: List<Int> = emptyList(),
    val id: Int,
    val name: String,
    val originCountry: List<String> = emptyList(),
    val originalLanguage: String,
    val originalName: String,
    val overview: String = "",
    val popularity: Double,
    val posterPath: String? = null,
    val voteAverage: Double,
    val voteCount: Int,
)

@Serializable
data class KTTVListResponse(
    val page: Int,
    val results: List<KTTVListResult>,
    val totalPages: Int,
    val totalResults: Int,
)