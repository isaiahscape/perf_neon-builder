#!/bin/bash 

# Export KernelSU variables
export KSU_SETUP_URI="https://raw.githubusercontent.com/backslashxx/KernelSU/refs/heads/master/kernel/setup.sh"
export KSU_SETUP_BRANCH="master"
export KSU_SELINUX_HIDE_LINEAGE="https://raw.githubusercontent.com/null07089/Lineage_Hide/refs/heads/main/scripts/selinux_hide_patch.sh"
export KSU_CUSTOMROM_HIDE_LINEAGE="https://raw.githubusercontent.com/null07089/Lineage_Hide/refs/heads/main/scripts/patch-kernel.sh"

# Run setup script
ksu_run_setup() {
    echo "-- KernelSU: Running setup script..."
    curl -LSs --fail --retry 3 -H "Authorization: Bearer $GITHUB_TOKEN" "$KSU_SETUP_URI" | bash -s "$KSU_SETUP_BRANCH" &> /dev/null || { echo "-- Fatal: KSU setup script failed to download/run!"; exit 1; }
}

# Configure basic KernelSU configs
ksu_common_configs() {
    echo "-- KernelSU: Enabling configs..."
    # KSU depends on SECURITY_SELINUX and selects SECCOMP
    echo "CONFIG_SECURITY_SELINUX=y" >> $FINAL_DEFCONFIG
    echo "CONFIG_KSU=y" >> $FINAL_DEFCONFIG
    echo "CONFIG_KSU_LSM_SECURITY_HOOKS=y" >> $FINAL_DEFCONFIG
    # Hook methods are mutually exclusive (see KernelSU/kernel/Kconfig)
    # - syscall table tampering: recommended for 3.0 ~ 4.14
    # - ARM64 branch-link inline hooking: recommended for 4.19+, requires KALLSYMS
    if [[ "$KERNEL_VERSION" == "4.14" ]]; then
        echo "CONFIG_KSU_TAMPER_SYSCALL_TABLE=y" >> $FINAL_DEFCONFIG
        echo "# CONFIG_KSU_HACK_ARM64_BRANCH_LINK is not set" >> $FINAL_DEFCONFIG
    else
        echo "# CONFIG_KSU_TAMPER_SYSCALL_TABLE is not set" >> $FINAL_DEFCONFIG
        echo "CONFIG_KSU_HACK_ARM64_BRANCH_LINK=y" >> $FINAL_DEFCONFIG
    fi
    # KALLSYMS is required by branch-link hooks and the symbol resolver.
    # Note: Do NOT enable CONFIG_KALLSYMS_ALL here; in-tree KSU does not require it,
    # and enabling it causes llvm-nm to fail with Broken pipe in scripts/kallsyms.
    echo "CONFIG_KALLSYMS=y" >> $FINAL_DEFCONFIG
    echo "# CONFIG_KALLSYMS_ALL is not set" >> $FINAL_DEFCONFIG
}

# Verify KernelSU configs survived olddefconfig (run from kernel dir after config generation)
ksu_verify_config() {
    local config="${1:-out/.config}"
    echo "-- KernelSU: Verifying final config..."
    for opt in CONFIG_KSU CONFIG_KSU_LSM_SECURITY_HOOKS CONFIG_KALLSYMS; do
        grep -q "^${opt}=y" "$config" || { echo "-- Fatal: ${opt} is not enabled in ${config}!"; exit 1; }
    done
    if grep -q "^CONFIG_KSU_TAMPER_SYSCALL_TABLE=y" "$config"; then
        echo "-- KernelSU: Hook method: syscall table"
    elif grep -q "^CONFIG_KSU_HACK_ARM64_BRANCH_LINK=y" "$config"; then
        echo "-- KernelSU: Hook method: ARM64 branch-link"
    else
        echo "-- Fatal: No KernelSU hook method enabled!"; exit 1
    fi
}

# Export selinux symbols
ksu_export_selinux_symbols() {
    echo "-- KernelSU: Checking and exporting static SELinux symbols..."
    unstatic() {
        local file="$1" regex="$2"
        if [ -f "$file" ] && grep -q "static $regex" "$file" 2>/dev/null; then
            sed -i "s/static $regex/$regex/" "$file"
            echo "   -> Exported: $regex"
        fi
    }
    unstatic "security/selinux/selinuxfs.c" "ssize_t (\*write_op\[\])"
    unstatic "security/selinux/selinuxfs.c" "ssize_t (\*const write_op\[\])"
    unstatic "security/selinux/selinuxfs.c" "const struct file_operations sel_handle_status_ops"
    unstatic "security/selinux/selinuxfs.c" "DEFINE_MUTEX(sel_mutex);"
    unstatic "security/selinux/ss/status.c" "struct page \*selinux_status_page;"
    unstatic "security/selinux/ss/status.c" "DEFINE_MUTEX(selinux_status_lock);"
    unstatic "security/selinux/ss/services.c" "DEFINE_RWLOCK(policy_rwlock);"
    unstatic "security/selinux/hooks.c" "struct security_operations selinux_ops"
    unstatic "security/selinux/ss/services.c" "void security_dump_masked_av"
    unstatic "security/selinux/ss/services.c" "void context_struct_compute_av"
}

# Fix exposed SELinux on LineageOS and their forks
ksu_fix_exposed_selinux_linag() {
    echo "-- KernelSU: Fixing exposed adbd SELinux..."
    curl -LSs --fail --retry 3 -H "Authorization: Bearer $GITHUB_TOKEN" "$KSU_SELINUX_HIDE_LINEAGE" | bash -s KernelSU/ &> /dev/null || { echo "-- Fatal: SELinux Hide fixup script failed to download/run!"; exit 1; }
}

# Hide custom rom details
ksu_hide_customrom() {
    echo "-- KernelSU: Hiding Custom ROM details..."
    curl -LSs --fail --retry 3 -H "Authorization: Bearer $GITHUB_TOKEN" "$KSU_CUSTOMROM_HIDE_LINEAGE" | bash -s ./ &> /dev/null || { echo "-- Fatal: Hide Custom ROM script failed to download/run!"; exit 1; }
}
