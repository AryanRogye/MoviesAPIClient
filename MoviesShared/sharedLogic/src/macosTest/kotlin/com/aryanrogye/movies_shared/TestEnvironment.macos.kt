package com.aryanrogye.movies_shared

import kotlinx.cinterop.ExperimentalForeignApi
import kotlinx.cinterop.toKString
import platform.posix.getenv

@OptIn(ExperimentalForeignApi::class)
internal actual fun testEnvironmentVariable(name: String): String? = getenv(name)?.toKString()
