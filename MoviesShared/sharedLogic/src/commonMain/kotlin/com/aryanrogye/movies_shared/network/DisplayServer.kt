package com.aryanrogye.movies_shared.network

enum class KTDisplayServer(val rawValue: String) {
    MOVIES_API("MoviesAPI"),
    VID_FAST("VidFast");

    private val baseURL: String
        get() {
            return when (this) {
                MOVIES_API -> "https://moviesapi.to"
                VID_FAST -> "https://vidfast.vc"
            }
        }

    fun loadMovie(movieId: Int): String {
        return "$baseURL/movie/$movieId"
    }

    fun loadTvShow(showId: Int, season: Int, episode: Int): String {
        return "$baseURL/tv/$showId/$season/$episode"
    }
}