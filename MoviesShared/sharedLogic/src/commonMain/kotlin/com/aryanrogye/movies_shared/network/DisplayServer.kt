package com.aryanrogye.movies_shared.network

enum class KTDisplayServer(val rawValue: String) {
    MOVIES_API("MoviesAPI"),
    VID_FAST("VidFast"),

    VID_SPARK("VidSpark"),

    VID_LINK("VidLink"),

    CINE_SRC("CineSrc");

    private val baseURL: String
        get() {
            return when (this) {
                MOVIES_API -> "https://moviesapi.to"
                VID_FAST -> "https://vidfast.vc"
                VID_SPARK -> "https://vidspark.to"
                VID_LINK -> "https://vidlink.pro"
                CINE_SRC -> "https://cinesrc.st/embed"
            }
        }

    fun loadMovie(movieId: Int): String {
        return "$baseURL/movie/$movieId"
    }

    fun loadTvShow(showId: Int, season: Int, episode: Int): String {
        if (this == CINE_SRC) {
            return "$baseURL/tv/$showId?s=$season&e=$episode"
        }
        return "$baseURL/tv/$showId/$season/$episode"
    }
}