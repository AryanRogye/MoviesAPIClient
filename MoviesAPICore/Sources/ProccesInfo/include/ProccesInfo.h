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

typedef struct {
    int count;
    uint64_t cpuTime;
} ProcessThreadInfo;

uint64_t getMemoryForProcess(pid_t pid);
uint64_t getCPUTimeForProcess(pid_t pid);

int getCPUInfo(pid_t pid, ProcessThreadInfo *threadInfo);
int get_process_start_time(pid_t pid, struct timeval *start_tv);

int freeze_process(pid_t pid);
int resume_process(pid_t pid);


#endif
#endif
#endif
