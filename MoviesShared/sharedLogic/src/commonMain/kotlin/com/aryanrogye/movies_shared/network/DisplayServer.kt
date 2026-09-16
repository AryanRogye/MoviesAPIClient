package com.aryanrogye.movies_shared.network

enum class KTDisplayServer(val rawValue: String) {
    MOVIES_API("MoviesAPI"),
    VID_FAST("VidFast"),

    VID_SPARK("VidSpark"),

    VID_LINK("VidLink");

    private val baseURL: String
        get() {
            return when (this) {
                MOVIES_API -> "https://moviesapi.to"
                VID_FAST -> "https://vidfast.vc"
                VID_SPARK -> "https://vidspark.to"
                VID_LINK -> "https://vidlink.pro"
            }
        }

    fun loadMovie(movieId: Int): String {
        return "$baseURL/movie/$movieId"
    }

    fun loadTvShow(showId: Int, season: Int, episode: Int): String {
        return "$baseURL/tv/$showId/$season/$episode"
    }
}