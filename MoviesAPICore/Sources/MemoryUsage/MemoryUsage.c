//
//  MemoryUsage.c
//  MoviesAPICore
//
//  Created by Aryan Rogye on 9/22/26.
//

#ifdef __APPLE__
#include <TargetConditionals.h>
#if TARGET_OS_OSX

#include "MemoryUsage.h"

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

#endif
#endif
