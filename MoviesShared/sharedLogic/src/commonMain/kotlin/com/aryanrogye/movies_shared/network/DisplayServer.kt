package com.aryanrogye.movies_shared.network

enum class KTDisplayServer(val rawValue: String) {
    MOVIES_API("MoviesAPI"),
    VID_FAST("VidFast"),

    VID_PHANTOM("VidPhantom"),

    VID_SRC("VidSrc"),

    RIVE_STREAM("Rive Stream"),

    VID_SPARK("VidSpark"),

    VID_LINK("VidLink"),

    CINE_SRC("CineSrc"),

    OneOneOneMovies("111movies");

    private val baseURL: String
        get() {
            return when (this) {
                MOVIES_API -> "https://moviesapi.to"
                VID_FAST -> "https://vidfast.vc"
                VID_PHANTOM -> "https://vidphantom.com"
                VID_SRC -> "https://vidsrc.sh/embed"
                RIVE_STREAM -> "https://www.rivestream.app/embed/agg"
                VID_SPARK -> "https://vidspark.to"
                VID_LINK -> "https://vidlink.pro"
                CINE_SRC -> "https://cinesrc.st/embed"
                OneOneOneMovies -> "https://111movies.net"
            }
        }

    fun loadMovie(movieId: Int): String {
        return when (this) {
            RIVE_STREAM -> "$baseURL?type=movie&id=$movieId"
            else -> "$baseURL/movie/$movieId"
        }
    }

    fun loadTvShow(showId: Int, season: Int, episode: Int): String {
        return when (this) {
            CINE_SRC -> "$baseURL/tv/$showId?s=$season&e=$episode"
            RIVE_STREAM -> "$baseURL?type=tv&id=$showId&season=$season&episode=$episode"
            else -> "$baseURL/tv/$showId/$season/$episode"
        }
    }
}
