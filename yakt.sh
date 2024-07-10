#!/system/bin/sh
# YAKT v18 - Optimized for Battery Life, Performance, and Internet Speed
# Original Author: @NotZeetaa (Github)
# Modified for enhanced battery life, performance, and internet speed

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

    if [ -w "$file_path" ]; then
        echo "$value" > "$file_path" 2>/dev/null
        log_info "Successfully wrote $value to $file_path"
    else
        log_error "Error: Cannot write to $file_path."
    fi
}

MODDIR=${0%/*}
INFO_LOG="${MODDIR}/info.log"
ERROR_LOG="${MODDIR}/error.log"

# Prepare log files
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
log_info "Starting YAKT - Optimized for Battery Life, Performance, and Internet Speed"
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
        write_value "${cpu}/up_rate_limit_us" 20000
        write_value "${cpu}/down_rate_limit_us" 40000
    done
    log_info "Applied schedutil rate-limits tweak for improved responsiveness and battery life"
else
    log_info "Abort: Not using schedutil governor"
fi

# Enable CRF by default
log_info "Enabling child_runs_first"
write_value "$KERNEL_PATH/sched_child_runs_first" 1

# Apply RAM tweaks
log_info "Applying RAM tweaks"
write_value "$MEMORY_PATH/vfs_cache_pressure" 70
write_value "$MEMORY_PATH/stat_interval" 60
write_value "$MEMORY_PATH/page-cluster" 0

# Adjust swappiness based on total RAM
if [ $TOTAL_RAM -lt 8000 ]; then
    write_value "$MEMORY_PATH/swappiness" 60
else
    write_value "$MEMORY_PATH/swappiness" 40
fi
write_value "$MEMORY_PATH/dirty_ratio" 20
write_value "$MEMORY_PATH/dirty_background_ratio" 5

# MGLRU tweaks
if [ -d "$MGLRU_PATH" ]; then
    log_info "Applying MGLRU tweaks"
    write_value "$MGLRU_PATH/min_ttl_ms" 5000
else
    log_info "MGLRU support not found, skipping MGLRU tweaks"
fi

# Set kernel.perf_cpu_time_max_percent to 5 for better performance while maintaining good battery life
log_info "Setting perf_cpu_time_max_percent to 5"
write_value "$KERNEL_PATH/perf_cpu_time_max_percent" 5

# Disable certain scheduler logs/stats
log_info "Disabling some scheduler logs/stats"
write_value "$KERNEL_PATH/sched_schedstats" 0
write_value "$KERNEL_PATH/printk" "3 4 1 7"
write_value "$KERNEL_PATH/printk_devkmsg" "off"
for queue in /sys/block/*/queue; do
    write_value "$queue/iostats" 0
    write_value "$queue/nr_requests" 128
done

# Tweak scheduler for balanced performance and battery life
log_info "Tweaking scheduler for balanced performance and battery life"
write_value "$KERNEL_PATH/sched_migration_cost_ns" 250000
write_value "$KERNEL_PATH/sched_min_granularity_ns" 2000000
write_value "$KERNEL_PATH/sched_wakeup_granularity_ns" 2500000

# Disable Timer migration for better battery life
log_info "Disabling Timer Migration"
write_value "$KERNEL_PATH/timer_migration" 0

# Cgroup tweak for UCLAMP scheduler
if [ -e "$UCLAMP_PATH" ]; then
    log_info "Applying UCLAMP scheduler tweaks"
    write_value "${CPUSET_PATH}/top-app/uclamp.max" 70
    write_value "${CPUSET_PATH}/top-app/uclamp.min" 10
    write_value "${CPUSET_PATH}/top-app/uclamp.boosted" 1
    write_value "${CPUSET_PATH}/top-app/uclamp.latency_sensitive" 1

    write_value "${CPUSET_PATH}/foreground/uclamp.max" 50
    write_value "${CPUSET_PATH}/foreground/uclamp.min" 5
    write_value "${CPUSET_PATH}/foreground/uclamp.boosted" 0
    write_value "${CPUSET_PATH}/foreground/uclamp.latency_sensitive" 0

    write_value "${CPUSET_PATH}/background/uclamp.max" 30
    write_value "${CPUSET_PATH}/background/uclamp.min" 0
    write_value "${CPUSET_PATH}/background/uclamp.boosted" 0
    write_value "${CPUSET_PATH}/background/uclamp.latency_sensitive" 0

    write_value "${CPUSET_PATH}/system-background/uclamp.max" 40
    write_value "${CPUSET_PATH}/system-background/uclamp.min" 0
    write_value "${CPUSET_PATH}/system-background/uclamp.boosted" 0
    write_value "${CPUSET_PATH}/system-background/uclamp.latency_sensitive" 0

    sysctl -w kernel.sched_util_clamp_min_rt_default=0
    sysctl -w kernel.sched_util_clamp_min=64
else
    log_info "UCLAMP scheduler not detected, skipping tweaks"
fi

# Allow sched boosting on top-app tasks
log_info "Configuring sched boosting on top-app tasks"
write_value "$KERNEL_PATH/sched_min_task_util_for_colocation" 0

# Disable SPI CRC
if [ -d "$MODULE_PATH/mmc_core" ]; then
    log_info "Disabling SPI CRC"
    write_value "$MODULE_PATH/mmc_core/parameters/use_spi_crc" 0
else
    log_info "SPI CRC not supported, skipping"
fi

# Enable LZ4 for zRAM
log_info "Enabling LZ4 for zRAM"
for zram_dir in /sys/block/zram*; do
    write_value "$zram_dir/comp_algorithm" lz4
    write_value "$zram_dir/max_comp_streams" 4
done

# Disable kernel panic for hung_task
log_info "Disabling kernel panic for hung_task"
write_value "$KERNEL_PATH/panic_on_oops" 0
write_value "$KERNEL_PATH/hung_task_panic" 0
write_value "$KERNEL_PATH/hung_task_timeout_secs" 0

# Enable power efficiency
log_info "Enabling power efficiency"
write_value "$MODULE_PATH/workqueue/parameters/power_efficient" Y

# Network Tweaks
log_info "Applying network tweaks"
write_value "/proc/sys/net/ipv4/tcp_fastopen" 3
write_value "/proc/sys/net/ipv4/tcp_slow_start_after_idle" 0
write_value "/proc/sys/net/ipv4/tcp_ecn" 1
write_value "/proc/sys/net/ipv4/tcp_keepalive_time" 300
write_value "/proc/sys/net/ipv4/tcp_keepalive_intvl" 60
write_value "/proc/sys/net/ipv4/tcp_keepalive_probes" 5
write_value "/proc/sys/net/core/wmem_max" 8388608
write_value "/proc/sys/net/core/rmem_max" 8388608
write_value "/proc/sys/net/ipv4/tcp_rmem" "4096 87380 8388608"
write_value "/proc/sys/net/ipv4/tcp_wmem" "4096 65536 8388608"
write_value "/proc/sys/net/ipv4/tcp_low_latency" 1
write_value "/proc/sys/net/ipv4/tcp_mtu_probing" 1
write_value "/proc/sys/net/ipv4/tcp_congestion_control" "bbr"
write_value "/proc/sys/net/ipv4/tcp_timestamps" 1
write_value "/proc/sys/net/ipv4/tcp_sack" 1
write_value "/proc/sys/net/ipv4/tcp_fack" 1
write_value "/proc/sys/net/ipv4/tcp_window_scaling" 1
write_value "/proc/sys/net/ipv4/tcp_adv_win_scale" 2
write_value "/proc/sys/net/core/netdev_max_backlog" 5000
write_value "/proc/sys/net/core/somaxconn" 8192
write_value "/proc/sys/net/ipv4/tcp_fin_timeout" 15
write_value "/proc/sys/net/ipv4/tcp_tw_reuse" 1
write_value "/proc/sys/net/ipv4/tcp_max_syn_backlog" 2048
write_value "/proc/sys/net/ipv4/tcp_syncookies" 1
write_value "/proc/sys/net/ipv4/tcp_rfc1337" 1
write_value "/proc/sys/net/ipv4/ip_no_pmtu_disc" 0
write_value "/proc/sys/net/ipv4/tcp_frto" 2

# GPU Tweaks
GPU_PATH="/sys/class/kgsl/kgsl-3d0"
if [ -d "$GPU_PATH" ]; then
    log_info "Applying GPU tweaks"
    write_value "$GPU_PATH/devfreq/governor" "msm-adreno-tz"
    write_value "$GPU_PATH/force_bus_on" 0
    write_value "$GPU_PATH/force_rail_on" 0
    write_value "$GPU_PATH/force_clk_on" 0
    write_value "$GPU_PATH/idle_timer" 64
    write_value "$GPU_PATH/throttling" 0
else
    log_info "GPU path not found, skipping GPU tweaks"
fi

# I/O Scheduler Tweaks
log_info "Applying I/O scheduler tweaks"
for queue in /sys/block/*/queue; do
    write_value "$queue/scheduler" "cfq"
    write_value "$queue/add_random" 0
    write_value "$queue/nomerges" 0
    write_value "$queue/rotational" 0
    write_value "$queue/rq_affinity" 2
    write_value "$queue/read_ahead_kb" 128
done

# CPU Idle and Frequency Tweaks
log_info "Applying CPU idle and frequency tweaks"
CPUFREQ_PATH="/sys/devices/system/cpu/cpu0/cpufreq"
if [ -d "$CPUFREQ_PATH" ]; then
    for cpu in /sys/devices/system/cpu/cpu*/cpufreq; do
        write_value "${cpu}/scaling_governor" "schedutil"
        
        min_freq=$(cat ${cpu}/cpuinfo_min_freq)
        scaled_min_freq=$((min_freq + (min_freq / 5)))  # 20% higher than minimum
        write_value "${cpu}/scaling_min_freq" "$scaled_min_freq"
        
        max_freq=$(cat ${cpu}/cpuinfo_max_freq)
        scaled_max_freq=$((max_freq - (max_freq / 10)))  # 90% of maximum
        write_value "${cpu}/scaling_max_freq" "$scaled_max_freq"
    done
else
    log_info "CPU frequency path not found, skipping CPU frequency tweaks"
fi

# CPU Input Boost tweaks
INPUT_BOOST_PATH="/sys/module/cpu_boost/parameters"
if [ -d "$INPUT_BOOST_PATH" ]; then
    log_info "Applying CPU Input Boost tweaks"
    write_value "$INPUT_BOOST_PATH/input_boost_freq" "0:1200000 1:1200000 2:1200000 3:1200000"
    write_value "$INPUT_BOOST_PATH/input_boost_ms" 40
else
    log_info "CPU Input Boost not available, skipping related tweaks"
fi

# Filesystem Tweaks
log_info "Applying filesystem tweaks"
write_value "/proc/sys/fs/lease-break-time" 15
write_value "/proc/sys/fs/file-max" 1048576
write_value "/proc/sys/fs/inotify/max_user_watches" 524288

# Miscellaneous Tweaks
log_info "Applying miscellaneous tweaks"
write_value "/proc/sys/kernel/random/read_wakeup_threshold" 64
write_value "/proc/sys/kernel/random/write_wakeup_threshold" 896
write_value "/proc/sys/kernel/sched_energy_aware" 1

# Disable Debugging for Power Saving
log_info "Disabling various debug features for power saving"
write_value "/sys/module/kernel/parameters/initcall_debug" N
write_value "/sys/module/printk/parameters/time" N
write_value "/sys/module/printk/parameters/console_suspend" Y
write_value "/sys/module/service_locator/parameters/enable" 0
write_value "/sys/module/subsystem_restart/parameters/enable_ramdumps" 0

# Optimize kernel task scheduler
log_info "Optimizing kernel task scheduler"
write_value "/proc/sys/kernel/sched_tunable_scaling" 0
write_value "/proc/sys/kernel/sched_latency_ns" 10000000
write_value "/proc/sys/kernel/sched_min_granularity_ns" 2500000
write_value "/proc/sys/kernel/sched_wakeup_granularity_ns" 2000000

# Tweak VM parameters for better memory management
log_info "Tweaking VM parameters"
write_value "$MEMORY_PATH/drop_caches" 3
write_value "$MEMORY_PATH/laptop_mode" 5
write_value "$MEMORY_PATH/mmap_min_addr" 4096
write_value "$MEMORY_PATH/oom_kill_allocating_task" 0
write_value "$MEMORY_PATH/overcommit_ratio" 50
write_value "$MEMORY_PATH/overcommit_memory" 1
write_value "$MEMORY_PATH/page-cluster" 0

# Apply entropy tweaks
log_info "Applying entropy tweaks"
write_value "/proc/sys/kernel/random/write_wakeup_threshold" 1024

# CPU governor tweaks
log_info "Applying CPU governor tweaks"
for cpu in /sys/devices/system/cpu/cpu*/cpufreq; do
    if [ -f "${cpu}/scaling_governor" ]; then
        current_governor=$(cat ${cpu}/scaling_governor)
        case $current_governor in
            "schedutil")
                write_value "${cpu}/schedutil/up_rate_limit_us" 5000
                write_value "${cpu}/schedutil/down_rate_limit_us" 10000
                ;;
            "interactive")
                write_value "${cpu}/interactive/timer_rate" 20000
                write_value "${cpu}/interactive/timer_slack" 20000
                write_value "${cpu}/interactive/target_loads" "80 1400000:85 1800000:90"
                ;;
        esac
    fi
done

# Adjust readahead buffer size
log_info "Adjusting readahead buffer size"
for block_device in /sys/block/*/queue/read_ahead_kb; do
    write_value "$block_device" 128
done

# Optimize LMK parameters
log_info "Optimizing LMK parameters"
if [ -f "/sys/module/lowmemorykiller/parameters/minfree" ]; then
    write_value "/sys/module/lowmemorykiller/parameters/minfree" "18432,23040,27648,32256,55296,80640"
fi

# Optimize KSM (Kernel Samepage Merging)
log_info "Optimizing KSM"
if [ -f "/sys/kernel/mm/ksm/run" ]; then
    write_value "/sys/kernel/mm/ksm/run" 1
    write_value "/sys/kernel/mm/ksm/sleep_millisecs" 1500
    write_value "/sys/kernel/mm/ksm/pages_to_scan" 100
fi

# Adjust CPU input boost
log_info "Adjusting CPU input boost"
if [ -d "/sys/module/cpu_boost" ]; then
    write_value "/sys/module/cpu_boost/parameters/input_boost_freq" "0:1200000"
    write_value "/sys/module/cpu_boost/parameters/input_boost_ms" 40
fi

# Tweak thermal engine
log_info "Tweaking thermal engine"
if [ -f "/sys/module/msm_thermal/core_control/enabled" ]; then
    write_value "/sys/module/msm_thermal/core_control/enabled" 1
fi

# Adjust GPU power level
log_info "Adjusting GPU power level"
if [ -f "/sys/class/kgsl/kgsl-3d0/default_pwrlevel" ]; then
    gpu_power_levels=$(cat /sys/class/kgsl/kgsl-3d0/num_pwrlevels)
    optimal_level=$((gpu_power_levels / 2))
    write_value "/sys/class/kgsl/kgsl-3d0/default_pwrlevel" $optimal_level
fi

# Tweak CPU boost parameters
log_info "Tweaking CPU boost parameters"
if [ -d "/sys/module/cpu_boost" ]; then
    write_value "/sys/module/cpu_boost/parameters/boost_ms" 20
    write_value "/sys/module/cpu_boost/parameters/input_boost_ms" 40
fi

# Optimize interactive CPU governor if present
log_info "Checking for interactive CPU governor"
if [ -d "/sys/devices/system/cpu/cpufreq/interactive" ]; then
    write_value "/sys/devices/system/cpu/cpufreq/interactive/timer_rate" 20000
    write_value "/sys/devices/system/cpu/cpufreq/interactive/timer_slack" 20000
    write_value "/sys/devices/system/cpu/cpufreq/interactive/target_loads" "80 1400000:85 1800000:90"
    write_value "/sys/devices/system/cpu/cpufreq/interactive/min_sample_time" 40000
    write_value "/sys/devices/system/cpu/cpufreq/interactive/hispeed_freq" 1200000
    write_value "/sys/devices/system/cpu/cpufreq/interactive/go_hispeed_load" 85
    write_value "/sys/devices/system/cpu/cpufreq/interactive/above_hispeed_delay" 20000
fi

# Final optimization for I/O
log_info "Applying final I/O optimizations"
for queue in /sys/block/*/queue; do
    write_value "$queue/iostats" 0
    write_value "$queue/add_random" 0
    write_value "$queue/nomerges" 0
    write_value "$queue/rotational" 0
    write_value "$queue/rq_affinity" 2
done

# Optimize CPU frequencies for balanced performance and battery life
log_info "Optimizing CPU frequencies"
for cpu in /sys/devices/system/cpu/cpu*/cpufreq; do
    if [ -f "${cpu}/scaling_min_freq" ] && [ -f "${cpu}/scaling_max_freq" ]; then
        min_freq=$(cat ${cpu}/cpuinfo_min_freq)
        max_freq=$(cat ${cpu}/cpuinfo_max_freq)
        new_min_freq=$((min_freq + (max_freq - min_freq) / 5))  # 20% above minimum
        new_max_freq=$((max_freq - (max_freq - min_freq) / 10))  # 10% below maximum
        write_value "${cpu}/scaling_min_freq" $new_min_freq
        write_value "${cpu}/scaling_max_freq" $new_max_freq
    fi
done

# Apply thermal throttling optimizations
log_info "Applying thermal throttling optimizations"
if [ -f "/sys/module/msm_thermal/parameters/temp_threshold" ]; then
    write_value "/sys/module/msm_thermal/parameters/temp_threshold" 60
fi

# Finished applying all tweaks
log_info "YAKT tweaks applied successfully"
log_info "Optimizations focused on balancing battery life, performance, and internet speed"
log_info "Please reboot your device to ensure all changes take effect"
