#!/bin/bash
set -euo pipefail

log() { echo "[zram-init] $*"; }

if swapon --show | grep -q /dev/zram0; then
    log "zram0 already active, skipping"
    swapon --show
    exit 0
fi

log "Loading zram..."
modprobe zram

set_algorithm() {
    local available
    available=$(cat /sys/block/zram0/comp_algorithm)
    log "Available algorithms: $available"

    for algo in zstd lzo-rle lz4 lzo; do
        if echo "$available" | grep -qw "$algo" && \
           echo "$algo" > /sys/block/zram0/comp_algorithm 2>/dev/null; then
            log "Algorithm: $algo"
            return 0
        fi
    done

    local current
    current=$(grep -oP '\[\K[^\]]+' /sys/block/zram0/comp_algorithm || echo "unknown")
    log "Could not set preferred algorithm; using kernel default: $current"
}

set_algorithm

echo 8G > /sys/block/zram0/disksize
log "Disk size: 8G"

mkswap --label zram0 /dev/zram0
swapon --priority 100 /dev/zram0
log "Swap on, priority 100"

sysctl -w vm.swappiness=200             # max: always prefer pushing idle app pages to zram
sysctl -w vm.watermark_boost_factor=0   # no burst reclaim; zram is fast
sysctl -w vm.watermark_scale_factor=200 # kswapd reclaims earlier, wider headroom window
sysctl -w vm.page-cluster=0             # 4KB reads; no HDD seek penalty

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