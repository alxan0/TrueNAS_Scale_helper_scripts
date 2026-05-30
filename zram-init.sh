#!/bin/bash
set -euo pipefail

log() { echo "[zram-init] $*"; }

# Check if it's not already running
if swapon --show | grep -q /dev/zram0; then
    log "zram0 already active, skipping"
    swapon --show
    exit 0
fi

log "Loading zram..."
modprobe zram

# Falls back to lzo if somehow not available on this kernel build.
if cat /sys/block/zram0/comp_algorithm | grep -q "lzo-rle"; then
    echo lzo-rle > /sys/block/zram0/comp_algorithm
    log "Algorithm: lzo-rle"
else
    echo lzo > /sys/block/zram0/comp_algorithm
    log "lzo-rle not available, falling back to lzo"
fi

echo 8G > /sys/block/zram0/disksize
log "Disk size: 8G"

mkswap --label zram0 /dev/zram0
swapon --priority 100 /dev/zram0
log "Swap on, priority 100"

# Kernel VM tuning
# These are the Pop!_OS / Fedora-validated settings for in-memory swap,
# recommended by the Arch Wiki and kernel docs for ZRAM specifically.

sysctl -w vm.swappiness=180

# 0   - disables fragmentation-triggered reclaim bursts from kswapd.
#        With fast RAM-backed swap there's no reason for the extra work.
sysctl -w vm.watermark_boost_factor=0

# 125 - kswapd wakes up earlier (~290MB buffer on 23G host) to reclaim
#        smoothly under pressure instead of scrambling at the last second.
sysctl -w vm.watermark_scale_factor=125

# 0   - read 1 page (4KB) at a time instead of the default 8.
#        The default is tuned for HDD seek latency - irrelevant for ZRAM.
sysctl -w vm.page-cluster=0

# Done
echo ""
echo "zram device:"
zramctl --output NAME,ALGORITHM,DISKSIZE,DATA,COMPR,TOTAL,STREAMS,MOUNTPOINT

echo ""
echo "swap:"
swapon --show

echo ""
echo "vm params:"
sysctl vm.swappiness vm.watermark_boost_factor vm.watermark_scale_factor vm.page-cluster

echo ""
log "Done"