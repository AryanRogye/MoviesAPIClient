//
//  MemoryUsage.h
//  MoviesAPICore
//
//  Created by Aryan Rogye on 9/22/26.
//

#ifndef MEMORY_USAGE_H
#define MEMORY_USAGE_H
#ifdef __APPLE__
#include <TargetConditionals.h>
#if TARGET_OS_OSX

#include "libproc.h"
#include <unistd.h>

uint64_t getMemoryForProcess(pid_t pid);

#endif
#endif
#endif
