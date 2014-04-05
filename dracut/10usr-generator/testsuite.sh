#!/bin/bash

moddir=$(dirname "$0")
failed=0

run_test() {
    local cmdline="$1"
    local checkfunc="$2"
    local unitdir=$(mktemp -d)
    trap "rm -rf '${unitdir}'" EXIT

    echo "Starting test ${checkfunc}"
    export USR_GENERATOR_CMDLINE="${cmdline}"
    if ! "${moddir}/usr-generator" "${unitdir}"; then
        echo "FAILED ${checkfunc}"
        failed=$((failed + 1))
    elif ! "${checkfunc}" "${unitdir}"; then
        echo "FAILED ${checkfunc}"
        failed=$((failed + 1))
    else
        echo "PASSED ${checkfunc}"
    fi

    rm -rf "${unitdir}"
    trap - EXIT
}

test_noop() {
    if [[ -e "$1"/* ]]; then
        echo "$1 not empty"
        return 1
    fi
}
run_test nothing test_noop


test_simple() {
    [[ $(readlink "$1/initrd-root-fs.target.requires/sysroot-usr.mount") \
        == "../sysroot-usr.mount" ]] || return 1
    diff -u "$1/sysroot-usr.mount" - <<EOF
# Automatically generated by usr-generator

[Unit]
SourcePath=/proc/cmdline
Before=initrd-root-fs.target
Wants=remount-sysroot.service
After=remount-sysroot.service

[Mount]
What=/foo
Where=/sysroot/usr
Type=auto
Options=ro
EOF
    return $?
}
run_test usr=/foo test_simple

test_multiple() {
    diff -u "$1/sysroot-usr.mount" - <<EOF
# Automatically generated by usr-generator

[Unit]
SourcePath=/proc/cmdline
Before=initrd-root-fs.target
Wants=remount-sysroot.service
After=remount-sysroot.service

[Mount]
What=/two
Where=/sysroot/usr
Type=auto
Options=ro
EOF
    return $?
}
run_test "usr=/one usr=/two" test_multiple

test_opts() {
    diff -u "$1/sysroot-usr.mount" - <<EOF
# Automatically generated by usr-generator

[Unit]
SourcePath=/proc/cmdline
Before=initrd-root-fs.target
Wants=remount-sysroot.service
After=remount-sysroot.service

[Mount]
What=/foo
Where=/sysroot/usr
Type=ext4
Options=rw
EOF
    return $?
}
run_test "usr=/foo usrfstype=ext4 usrflags=rw" test_opts

if [[ "${failed}" -ne 0 ]]; then
    echo "${failed} test(s) failed!"
    exit 1
fi
