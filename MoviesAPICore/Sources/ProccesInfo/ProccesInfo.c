//
//  ProcessInfo.c
//  MoviesAPICore
//
//  Created by Aryan Rogye on 9/22/26.
//

#ifdef __APPLE__
#include <TargetConditionals.h>
#if TARGET_OS_OSX

#include "ProccesInfo.h"
#include <stdlib.h>
#include <signal.h>
#include <sys/types.h>

/// Function returns memory for a given pid
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

/// Function returns a threadcount and a cpu time
int getCPUInfo(pid_t pid, ProcessThreadInfo *threadInfo) {
    uint64_t thread_ids[1024];
    int bytes = proc_pidinfo(
                             pid,
                             PROC_PIDLISTTHREADS,
                             0,
                             thread_ids,
                             sizeof(thread_ids)
                             );

    if (bytes <= 0) {
        return -1;
    }

    int count = bytes / sizeof(uint64_t);

    ProcessThreadInfo info = {0};

    uint64_t total_cpu_time = 0;

    for (int i = 0; i < count; i++) {
        struct proc_threadinfo threadInfo;
        int result = proc_pidinfo(
                                  pid,
                                  PROC_PIDTHREADINFO,
                                  thread_ids[i],
                                  &threadInfo,
                                  sizeof(threadInfo)
                                  );

        if (result != sizeof(threadInfo)) {
            continue;
        }

        info.count++;
        total_cpu_time += threadInfo.pth_user_time;
        total_cpu_time += threadInfo.pth_system_time;
    }

    info.cpuTime = total_cpu_time;

    threadInfo->count = info.count;
    threadInfo->cpuTime = info.cpuTime;
    return 0;
}

int get_process_start_time(pid_t pid, struct timeval *start_tv) {
    struct proc_bsdinfo info;
    int ret = proc_pidinfo(
                           pid,
                           PROC_PIDTBSDINFO,
                           0,
                           &info,
                           sizeof(info)
                           );

    if (ret != sizeof(info)) {
        return -1; // failed, or PID doesn't exist / no permission
    }

    start_tv->tv_sec  = (time_t)info.pbi_start_tvsec;
    start_tv->tv_usec = (suseconds_t)info.pbi_start_tvusec;
    return 0;
}

int freeze_process(pid_t pid) {
    return kill(pid, SIGSTOP);
}

int resume_process(pid_t pid) {
    return kill(pid, SIGCONT);
}

/// (Unused But Kept) Function returns just the cpu time
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
