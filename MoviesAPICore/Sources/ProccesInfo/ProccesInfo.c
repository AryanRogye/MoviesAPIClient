//
//  MemoryUsage.c
//  MoviesAPICore
//
//  Created by Aryan Rogye on 9/22/26.
//

#ifdef __APPLE__
#include <TargetConditionals.h>
#if TARGET_OS_OSX

#include "ProccesInfo.h"
#include <stdlib.h>

uint64_t getMemoryForProcess(pid_t pid) {
    struct proc_taskinfo info;

    int ret = proc_pidinfo(
                           pid,
                           PROC_PIDTASKINFO, 0,
                           &info,
                           sizeof(info)
                           );

    if (ret <= 0) {
        return 0;
    }

    return info.pti_resident_size;
}

uint64_t getCPUTimeForProcess(pid_t pid) {
    uint64_t thread_ids[1024];
    int bytes = proc_pidinfo(
                             pid,
                             PROC_PIDLISTTHREADS,
                             0,
                             thread_ids,
                             sizeof(thread_ids)
                             );

    if (bytes <= 0) {
        return 0;
    }

    int count = bytes / sizeof(uint64_t);

    uint64_t total_cpu_time = 0;

    for (int i = 0; i < count; i++) {
        struct proc_threadinfo info;
        int result = proc_pidinfo(
                                  pid,
                                  PROC_PIDTHREADINFO,
                                  thread_ids[i],
                                  &info,
                                  sizeof(info)
                                  );

        if (result != sizeof(info)) {
            continue;
        }

        total_cpu_time += info.pth_user_time;
        total_cpu_time += info.pth_system_time;
    }

    return total_cpu_time;
}

#endif
#endif
