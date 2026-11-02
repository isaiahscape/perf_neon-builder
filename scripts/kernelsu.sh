#!/bin/bash

echo "-- KernelSU: loading functions..."
chmod +x scripts/functions/kernelsu.sh
source scripts/functions/kernelsu.sh

case "$KERNELSU_SELECTOR" in
    ksu)
        # Run KernelSU setup script
        ksu_run_setup

        # Enable the necessary KernelSU configs
        ksu_common_configs

        # Export SELinux Symbols
        ksu_export_selinux_symbols

        # Hide custom rom
        # ksu_hide_customrom

        # Fix exposed SELinux
        # ksu_fix_exposed_selinux_linag
        ;;
    none|"")
        echo "-- KernelSU is not selected."
        ;;
    *)
        echo "- Invalid KERNELSU_SELECTOR: $KERNELSU_SELECTOR. Valid options: ksu, none."
        exit 1
        ;;
esac
