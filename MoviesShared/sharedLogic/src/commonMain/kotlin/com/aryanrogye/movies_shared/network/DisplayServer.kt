package com.aryanrogye.movies_shared.network

enum class KTDisplayServer(val rawValue: String) {
    MOVIES_API("MoviesAPI"),
    VID_FAST("VidFast"),

    VID_SPARK("VidSpark"),

    VID_LINK("VidLink"),

    CINE_SRC("CineSrc"),

    OneOneOneMovies("111movies");

    private val baseURL: String
        get() {
            return when (this) {
                MOVIES_API -> "https://moviesapi.to"
                VID_FAST -> "https://vidfast.vc"
                VID_SPARK -> "https://vidspark.to"
                VID_LINK -> "https://vidlink.pro"
                CINE_SRC -> "https://cinesrc.st/embed"
                OneOneOneMovies -> "https://111movies.net"
            }
        }

    fun loadMovie(movieId: Int): String {
        return when (this) {
            else -> "$baseURL/movie/$movieId"
        }
    }

    fun loadTvShow(showId: Int, season: Int, episode: Int): String {
        return when (this) {
            CINE_SRC -> "$baseURL/tv/$showId?s=$season&e=$episode"
            else -> "$baseURL/tv/$showId/$season/$episode"
        }
    }
}