# TrueNAS Scale Helper Scripts

This repository contains automation scripts to help manage and optimize a TrueNAS Scale system. The scripts are designed to streamline service management and system power tuning for improved efficiency and reliability.

## Scripts

### powertune.sh
Automates power management settings for various hardware components:
- Enables USB autosuspend
- Sets some PCI device power control
- Tunes NVMe device power settings
- Disables NMI watchdog
- Adjusts VM writeback timeout
- (Optional) SATA ALPM and kernel options for Intel graphics

**Usage:**
```bash
sudo bash powertune.sh
```

### start_services.sh
Automates starting Docker Compose stacks in a specified order.

- Edit the `ORDER` array to specify which stacks to start and in what order.
- Supports dry-run mode and custom Compose binary location.

**Usage:**
```bash
bash start_services.sh
```

## Customization
- Adjust stack names and paths in `start_services.sh` as needed for your environment.
- Review and modify hardware-specific settings in `powertune.sh` for your system.

## License
MIT
