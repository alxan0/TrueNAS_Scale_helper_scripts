#!/bin/bash

# SATA ALPM
#for d in /sys/class/scsi_host/host*/link_power_management_policy; do
#    echo min_power > "$d"
#done

# USB autosuspend
for dev in /sys/bus/usb/devices/*/power/control; do
    echo auto > "$dev"
done

for d in /sys/bus/pci/devices/*; do
  ctrl="$d/power/control"; [ -e "$ctrl" ] || continue
  class=$(cat "$d/class")
  case "$class" in
    0x01*|0x0200*|0x0c03*) echo on   | sudo tee "$ctrl" > /dev/null ;; # storage, ethernet, USB
    *)                      echo auto | sudo tee "$ctrl" > /dev/null ;;
  esac
done

for dev in /sys/class/nvme/nvme*/device; do
    pci=$(basename "$(readlink -f "$dev")")
    echo "Setting $pci to auto"
    echo auto | sudo tee "/sys/bus/pci/devices/$pci/power/control" >/dev/null
done

echo auto | sudo tee /sys/bus/pci/devices/0000:00:14.0/power/control

# NMI watchdog off
sysctl -w kernel.nmi_watchdog=0

# VM writeback timeout
sysctl -w vm.dirty_writeback_centisecs=1500

# Run once
# midclt call system.advanced.update '{"kernel_extra_options": "i915.enable_dc=2 i915.enable_fbc=1 i915.enable_psr=1 i915.enable_rc6=7"}'
