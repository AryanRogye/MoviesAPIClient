package com.aryanrogye.movies_shared.models

import kotlinx.serialization.Serializable

@Serializable
data class KTMovieListResult(
    val adult: Boolean = false,
    val backdropPath: String? = null,
    val genreIds: List<Int> = emptyList(),
    val id: Int,
    val originalLanguage: String,
    val originalTitle: String,
    val overview: String = "",
    val popularity: Double,
    val posterPath: String? = null,
    val releaseDate: String? = null,
    val title: String,
    val video: Boolean = false,
    val voteAverage: Double,
    val voteCount: Int,
)

@Serializable
data class KTMovieListResponse(
    val page: Int,
    val results: List<KTMovieListResult>,
    val totalPages: Int,
    val totalResults: Int,
)

@Serializable
data class KTMovieDateRange(
    val maximum: String,
    val minimum: String,
)

@Serializable
data class KTNowPlayingMovieResponse(
    val dates: KTMovieDateRange,
    val page: Int,
    val results: List<KTMovieListResult>,
    val totalPages: Int,
    val totalResults: Int,
)
