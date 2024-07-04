#!/system/bin/sh
# YAKT v18
# Original Author: @NotZeetaa (Github)
# This script applies various performance and battery optimizations to Android devices.

# Wait for the system to stabilize before applying tweaks
sleep 30

# Function to append a message to the specified log file
log_message() {
    local log_file="$1"
    local message="$2"
    echo "[$(date "+%H:%M:%S")] $message" >> "$log_file"
}

# Function to log info messages
log_info() {
    log_message "$INFO_LOG" "$1"
}

# Function to log error messages
log_error() {
    log_message "$ERROR_LOG" "$1"
}

# Function to write a value to a specified file
write_value() {
    local file_path="$1"
    local value="$2"

    # Check if the file exists and is writable
    if [ -w "$file_path" ]; then
        echo "$value" > "$file_path" 2>/dev/null
        log_info "Successfully wrote $value to $file_path"
    else
        log_error "Error: Cannot write to $file_path."
    fi
}

# Get the directory of this script
MODDIR=${0%/*}

# Define log file paths
INFO_LOG="${MODDIR}/info.log"
ERROR_LOG="${MODDIR}/error.log"

# Prepare log files by clearing their content
:> "$INFO_LOG"
:> "$ERROR_LOG"

# Variables for paths and system information
UCLAMP_PATH="/dev/stune/top-app/uclamp.max"
CPUSET_PATH="/dev/cpuset"
MODULE_PATH="/sys/module"
KERNEL_PATH="/proc/sys/kernel"
MEMORY_PATH="/proc/sys/vm"
MGLRU_PATH="/sys/kernel/mm/lru_gen"
SCHEDUTIL_PATH="/sys/devices/system/cpu/cpu*/cpufreq/schedutil"
ANDROID_VERSION=$(getprop ro.build.version.release)
TOTAL_RAM=$(free -m | awk '/Mem/{print $2}')

# Log starting information
log_info "Starting YAKT"
log_info "Build Date: $(date "+%d/%m/%Y")"
log_info "Original Author: @NotZeetaa (Github)"
log_info "Device: $(getprop ro.product.system.model)"
log_info "Brand: $(getprop ro.product.system.brand)"
log_info "Kernel: $(uname -r)"
log_info "ROM Build Type: $(getprop ro.system.build.type)"
log_info "Android Version: $ANDROID_VERSION"
log_info "Total RAM: ${TOTAL_RAM}MB"

# Apply schedutil rate-limits tweak
log_info "Applying schedutil rate-limits tweak"
if [ -d "$SCHEDUTIL_PATH" ]; then
    for cpu in $SCHEDUTIL_PATH; do
        # Increase up_rate_limit for better battery life
        write_value "${cpu}/up_rate_limit_us" 50000
        # Increase down_rate_limit for better battery life
        write_value "${cpu}/down_rate_limit_us" 100000
    done
    log_info "Applied schedutil rate-limits tweak to all CPUs for improved battery life"
else
    log_info "Abort: Not using schedutil governor"
fi

# Disable Sched Auto Group
log_info "Disabling Sched Auto Group"
write_value "$KERNEL_PATH/sched_autogroup_enabled" 0
log_info "Sched Auto Group disabled"

# Enable CRF by default
log_info "Enabling child_runs_first"
write_value "$KERNEL_PATH/sched_child_runs_first" 1
log_info "child_runs_first enabled"

# Apply RAM tweaks
log_info "Applying RAM tweaks"
write_value "$MEMORY_PATH/vfs_cache_pressure" 50
write_value "$MEMORY_PATH/stat_interval" 60
write_value "$MEMORY_PATH/compaction_proactiveness" 1
write_value "$MEMORY_PATH/page-cluster" 0
log_info "Applied RAM tweaks"

# Adjust swappiness based on total RAM
log_info "Detecting if your device has less or more than 8GB of RAM"
if [ $TOTAL_RAM -lt 8000 ]; then
    log_info "Detected 8GB or less of RAM"
    write_value "$MEMORY_PATH/swappiness" 80
else
    log_info "Detected more than 8GB of RAM"
    write_value "$MEMORY_PATH/swappiness" 60
fi
write_value "$MEMORY_PATH/dirty_ratio" 30
write_value "$MEMORY_PATH/dirty_background_ratio" 10
log_info "Adjusted swappiness and dirty ratios for better memory management"

# MGLRU tweaks
log_info "Checking if your kernel has MGLRU support"
if [ -d "$MGLRU_PATH" ]; then
    log_info "MGLRU support found, applying tweaks"
    write_value "$MGLRU_PATH/min_ttl_ms" 10000
    log_info "MGLRU tweaks applied for improved memory management"
else
    log_info "MGLRU support not found, aborting MGLRU tweaks"
fi

# Set kernel.perf_cpu_time_max_percent to 5 for better battery life
log_info "Setting perf_cpu_time_max_percent to 5"
write_value "$KERNEL_PATH/perf_cpu_time_max_percent" 5
log_info "Applied kernel.perf_cpu_time_max_percent value for improved battery life"

# Disable certain scheduler logs/stats
log_info "Disabling some scheduler logs/stats"
write_value "$KERNEL_PATH/sched_schedstats" 0
write_value "$KERNEL_PATH/printk" "0 0 0 0"
write_value "$KERNEL_PATH/printk_devkmsg" "off"
for queue in /sys/block/*/queue; do
    write_value "$queue/iostats" 0
    write_value "$queue/nr_requests" 128
done
log_info "Scheduler logs/stats disabled for reduced overhead"

# Tweak scheduler to balance between performance and battery life
log_info "Tweaking scheduler for balanced performance and battery life"
write_value "$KERNEL_PATH/sched_migration_cost_ns" 100000
write_value "$KERNEL_PATH/sched_min_granularity_ns" 2000000
write_value "$KERNEL_PATH/sched_wakeup_granularity_ns" 3000000
log_info "Scheduler tweaked for balanced performance and battery life"

# Disable Timer migration for better battery life
log_info "Disabling Timer Migration"
write_value "$KERNEL_PATH/timer_migration" 0
log_info "Timer Migration disabled for improved battery life"

# Cgroup tweak for UCLAMP scheduler
if [ -e "$UCLAMP_PATH" ]; then
    log_info "UCLAMP scheduler detected, applying tweaks"
    write_value "${CPUSET_PATH}/top-app/uclamp.max" 80
    write_value "${CPUSET_PATH}/top-app/uclamp.min" 5
    write_value "${CPUSET_PATH}/top-app/uclamp.boosted" 1
    write_value "${CPUSET_PATH}/top-app/uclamp.latency_sensitive" 1

    write_value "${CPUSET_PATH}/foreground/uclamp.max" 60
    write_value "${CPUSET_PATH}/foreground/uclamp.min" 0
    write_value "${CPUSET_PATH}/foreground/uclamp.boosted" 0
    write_value "${CPUSET_PATH}/foreground/uclamp.latency_sensitive" 0

    write_value "${CPUSET_PATH}/background/uclamp.max" 40
    write_value "${CPUSET_PATH}/background/uclamp.min" 0
    write_value "${CPUSET_PATH}/background/uclamp.boosted" 0
    write_value "${CPUSET_PATH}/background/uclamp.latency_sensitive" 0

    write_value "${CPUSET_PATH}/system-background/uclamp.max" 40
    write_value "${CPUSET_PATH}/system-background/uclamp.min" 0
    write_value "${CPUSET_PATH}/system-background/uclamp.boosted" 0
    write_value "${CPUSET_PATH}/system-background/uclamp.latency_sensitive" 0

    sysctl -w kernel.sched_util_clamp_min_rt_default=0
    sysctl -w kernel.sched_util_clamp_min=64
    log_info "Applied UCLAMP scheduler tweaks for balanced performance and battery life"
else
    log_info "UCLAMP scheduler not detected, skipping tweaks"
fi

# Allow sched boosting on top-app tasks with a lower threshold
log_info "Configuring sched boosting on top-app tasks"
write_value "$KERNEL_PATH/sched_min_task_util_for_colocation" 25
log_info "Configured sched boosting for balanced performance"

# Disable SPI CRC if supported
log_info "Checking for SPI CRC support"
if [ -d "$MODULE_PATH/mmc_core" ]; then
    log_info "SPI CRC supported, disabling it"
    write_value "$MODULE_PATH/mmc_core/parameters/use_spi_crc" 0
    log_info "SPI CRC disabled for potential performance improvement"
else
    log_info "SPI CRC not supported, skipping"
fi

# Enable LZ4 for zRAM
log_info "Enabling LZ4 for zRAM"
for zram_dir in /sys/block/zram*; do
    write_value "$zram_dir/comp_algorithm" lz4
    write_value "$zram_dir/max_comp_streams" 2
done
log_info "Applied LZ4 compression to zRAM for efficient memory compression"

# Disable kernel panic for hung_task
log_info "Disabling kernel panic for hung_task"
write_value "$KERNEL_PATH/panic_on_oops" 0
write_value "$KERNEL_PATH/hung_task_panic" 0
write_value "$KERNEL_PATH/hung_task_timeout_secs" 0
log_info "Kernel panic disabled for hung_task to prevent unexpected reboots"

# ZSwap tweaks
log_info "Checking for zswap support"
if [ -d "$MODULE_PATH/zswap" ]; then
    log_info "zswap supported, applying tweaks"
    write_value "$MODULE_PATH/zswap/parameters/compressor" lz4
    write_value "$MODULE_PATH/zswap/parameters/zpool" z3fold
    write_value "$MODULE_PATH/zswap/parameters/max_pool_percent" 30
    log_info "Applied zswap tweaks for improved memory management"
else
    log_info "Your kernel doesn't support zswap, aborting"
fi

# Enable power efficiency
log_info "Enabling power efficiency"
write_value "$MODULE_PATH/workqueue/parameters/power_efficient" 1
log_info "Power efficiency enabled for better battery life"

# Network Tweaks
log_info "Applying network tweaks"
write_value "/proc/sys/net/ipv4/tcp_fastopen" 3
write_value "/proc/sys/net/ipv4/tcp_slow_start_after_idle" 0
write_value "/proc/sys/net/ipv4/tcp_mtu_probing" 1
write_value "/proc/sys/net/ipv4/tcp_ecn" 2
write_value "/proc/sys/net/ipv4/tcp_window_scaling" 1
write_value "/proc/sys/net/ipv4/tcp_keepalive_time" 300
write_value "/proc/sys/net/ipv4/tcp_keepalive_intvl" 60
write_value "/proc/sys/net/ipv4/tcp_keepalive_probes" 3
write_value "/proc/sys/net/ipv4/tcp_sack" 1
write_value "/proc/sys/net/core/wmem_max" 4194304
write_value "/proc/sys/net/core/rmem_max" 4194304
write_value "/proc/sys/net/ipv4/tcp_rmem" "4096 87380 4194304"
write_value "/proc/sys/net/ipv4/tcp_wmem" "4096 65536 4194304"
write_value "/proc/sys/net/ipv4/tcp_timestamps" 1
write_value "/proc/sys/net/ipv4/tcp_low_latency" 0
log_info "Network tweaks applied for balanced performance and battery life"

# GPU Tweaks
log_info "Applying GPU tweaks"
GPU_PATH="/sys/class/kgsl/kgsl-3d0"
if [ -d "$GPU_PATH" ]; then
    write_value "$GPU_PATH/devfreq/governor" "msm-adreno-tz"
    write_value "$GPU_PATH/force_bus_on" 0
    write_value "$GPU_PATH/force_rail_on" 0
    write_value "$GPU_PATH/force_clk_on" 0
    write_value "$GPU_PATH/idle_timer" 80
    log_info "Applied GPU tweaks for balanced performance and power saving"
else
    log_info "GPU path not found, skipping GPU tweaks"
fi

# I/O Scheduler Tweaks
log_info "Applying I/O scheduler tweaks"
for queue in /sys/block/*/queue; do
    write_value "$queue/scheduler" "cfq"
    write_value "$queue/add_random" 0
    write_value "$queue/nomerges" 1
    write_value "$queue/rotational" 0
    write_value "$queue/rq_affinity" 1
    write_value "$queue/read_ahead_kb" 128
done
log_info "Applied I/O scheduler tweaks for balanced performance"

# CPU Idle and Frequency Tweaks (continued)
log_info "Applying CPU idle and frequency tweaks"
CPUFREQ_PATH="/sys/devices/system/cpu/cpu0/cpufreq"
if [ -d "$CPUFREQ_PATH" ]; then
    for cpu in /sys/devices/system/cpu/cpu*/cpufreq; do
        write_value "${cpu}/scaling_governor" "schedutil"
        write_value "${cpu}/schedutil/up_rate_limit_us" 50000
        write_value "${cpu}/schedutil/down_rate_limit_us" 100000
        
        # Set scaling_min_freq to a slightly higher value for better responsiveness
        min_freq=$(cat ${cpu}/cpuinfo_min_freq)
        scaled_min_freq=$((min_freq + (min_freq / 10)))  # 10% higher than minimum
        write_value "${cpu}/scaling_min_freq" "$scaled_min_freq"
        
        # Set scaling_max_freq to 90% of max for power saving
        max_freq=$(cat ${cpu}/cpuinfo_max_freq)
        scaled_max_freq=$((max_freq - (max_freq / 10)))  # 90% of maximum
        write_value "${cpu}/scaling_max_freq" "$scaled_max_freq"
    done
    log_info "Applied CPU frequency tweaks for balanced performance and battery life"
else
    log_info "CPU frequency path not found, skipping CPU frequency tweaks"
fi

# CPU Input Boost tweaks (if available)
INPUT_BOOST_PATH="/sys/module/cpu_boost/parameters"
if [ -d "$INPUT_BOOST_PATH" ]; then
    log_info "Applying CPU Input Boost tweaks"
    write_value "$INPUT_BOOST_PATH/input_boost_freq" "0:1000000 1:1000000 2:1000000 3:1000000"
    write_value "$INPUT_BOOST_PATH/input_boost_ms" 40
    log_info "Applied CPU Input Boost tweaks for responsive user experience"
else
    log_info "CPU Input Boost not available, skipping related tweaks"
fi

# Filesystem Tweaks
log_info "Applying filesystem tweaks"
write_value "/proc/sys/fs/lease-break-time" 15
write_value "/proc/sys/fs/file-max" 1048576
write_value "/proc/sys/fs/inotify/max_user_watches" 524288
write_value "/proc/sys/fs/dir-notify-enable" 0
log_info "Applied filesystem tweaks for improved I/O performance"

# Miscellaneous Tweaks
log_info "Applying miscellaneous tweaks"
write_value "/proc/sys/kernel/random/read_wakeup_threshold" 64
write_value "/proc/sys/kernel/random/write_wakeup_threshold" 896
write_value "/proc/sys/kernel/sched_energy_aware" 1
log_info "Applied miscellaneous tweaks for better system responsiveness"

# Disable Debugging for Power Saving
log_info "Disabling various debug features for power saving"
write_value "/sys/module/kernel/parameters/initcall_debug" 0
write_value "/sys/module/printk/parameters/time" N
write_value "/sys/module/printk/parameters/console_suspend" Y
write_value "/sys/module/service_locator/parameters/enable" 0
write_value "/sys/module/subsystem_restart/parameters/enable_ramdumps" 0
write_value "/sys/module/overheat_mitigation/parameters/mitigate_threshold" 90
log_info "Disabled various debug features for improved battery life"

# Apply SELinux optimizations
log_info "Applying SELinux optimizations"
write_value "/sys/fs/selinux/avc_cache_threshold" 1024
log_info "Applied SELinux optimizations for better system performance"

# Optimize kernel task scheduler
log_info "Optimizing kernel task scheduler"
write_value "/proc/sys/kernel/sched_tunable_scaling" 0
write_value "/proc/sys/kernel/sched_latency_ns" 10000000
write_value "/proc/sys/kernel/sched_min_granularity_ns" 2500000
write_value "/proc/sys/kernel/sched_wakeup_granularity_ns" 2000000
log_info "Optimized kernel task scheduler for balanced performance"

# Tweak VM parameters for better memory management
log_info "Tweaking VM parameters"
write_value "$MEMORY_PATH/drop_caches" 3
write_value "$MEMORY_PATH/laptop_mode" 5
write_value "$MEMORY_PATH/mmap_min_addr" 4096
write_value "$MEMORY_PATH/oom_kill_allocating_task" 0
write_value "$MEMORY_PATH/overcommit_ratio" 50
write_value "$MEMORY_PATH/overcommit_memory" 1
write_value "$MEMORY_PATH/page-cluster" 0
log_info "Applied VM parameter tweaks for improved memory management"

# Apply entropy tweaks
log_info "Applying entropy tweaks"
write_value "/proc/sys/kernel/random/read_wakeup_threshold" 64
write_value "/proc/sys/kernel/random/write_wakeup_threshold" 896
log_info "Applied entropy tweaks for better system randomness"

# Finished applying all tweaks
log_info "YAKT tweaks applied successfully"
log_info "Optimizations focused on balancing performance and battery life"
log_info "Please reboot your device to ensure all changes take effect"
