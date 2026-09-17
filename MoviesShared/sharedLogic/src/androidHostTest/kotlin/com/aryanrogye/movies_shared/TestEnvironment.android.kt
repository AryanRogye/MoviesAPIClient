package com.aryanrogye.movies_shared

internal actual fun testEnvironmentVariable(name: String): String? = System.getenv(name)
