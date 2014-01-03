#!/usr/local/bin/zsh

# Author: Shawn Webb <lattera@gmail.com>
#
# Copyright (c) 2014, Shawn Webb
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
#
#   * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
#   * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

# This script helps automate updating a FreeBSD machine that's using ZFS Boot Environments (ZFS BEs).

# TODO (in no particular order):
#   1) Use pkgng
#   2) After mounting the new BE, boot it up in a jail in order to do more advanced features
#   3) Clean up some of the ugly code

function usage() {
    echo "USAGE: ${1}"
    echo "    -b    [BE name]                 (requried)"
    echo "    -e    [old BE name]             (optional)"
    echo "    -B    Build new world/kernel    (optional)"
    echo "    -k    [kernel name]             (optional, default \"SEC\")"
    echo "    -m    [mount point]             (optional, default /mnt/[BE name])"
    echo "    -s    Use sudo                  (optional, default to no)"
    echo "    -p    [ports]                   (optional, rebuild certain ports)"
    echo "    -P                              (optional, update all ports)"
    exit 1
}

function build() {
    kern=${1}

    pushd /usr/src
    
    make -sj7 buildworld buildkernel KERNCONF=${kern}
    ret=${?}

    popd
    return ${ret}
}

function installuniverse() {
    kern=${1}
    destdir=${2}
    lsudo=${3}

    pushd /usr/src
    ${lsudo} make -s installkernel KERNCONF=${kern} DESTDIR=${destdir}
    ret=${?}
    if [ ! ${ret} -eq 0 ]; then
        popd
        return ${ret}
    fi
    ${lsudo} make -s installworld DESTDIR=${destdir}
    ret=${?}

    popd
    return ${ret}
}

function portbuild() {
    lmnt=${1}
    lports=${2}
    lsudo=${3}

    ${lsudo} mount -t nullfs /usr/ports ${lmnt}/usr/ports
    ret=${?}
    if [ ! ${ret} -eq 0 ]; then
        echo "[-] Could not mount ports nullfs in chroot"
        return ${ret}
    fi

    ${lsudo} mount -t nullfs /usr/src ${lmnt}/usr/src
    ret=${?}
    if [ ! ${ret} -eq 0 ]; then
        ${lsudo} umount ${lmnt}/usr/ports

        echo "[-] Could not mount src nullfs in chroot"
        return ${ret}
    fi

    ${lsudo} mount -t devfs devfs ${lmnt}/dev
    ret=${?}
    if [ ! ${ret} -eq 0 ]; then
        ${lsudo} umount ${lmnt}/usr/ports
        ${lsudo} umount ${lmnt}/usr/src

        echo "[-] Could not mount devfs in chroot"
        return ${ret}
    fi

    ${lsudo} chroot ${lmnt} portmaster -HwD --no-confirm ${lports}
    ret=${?}
    if [ ! ${ret} -eq 0 ]; then
        echo "[-] [Re]Installing ports failed"
    fi

    ${lsudo} umount ${lmnt}/dev
    ${lsudo} umount ${lmnt}/usr/ports
    ${lsudo} umount ${lmnt}/usr/src

    return ${ret}
}

function pkgup() {
    lmnt=${1}
    lsudo=${2}

    ${lsudo} mount -t nullfs /usr/ports ${lmnt}/usr/ports
    ret=${?}
    if [ ! ${ret} -eq 0 ]; then
        echo "[-] Could not mount ports nullfs in chroot"
        return ${ret}
    fi

    ${lsudo} mount -t nullfs /usr/src ${lmnt}/usr/src
    ret=${?}
    if [ ! ${ret} -eq 0 ]; then
        ${lsudo} umount ${lmnt}/usr/ports

        echo "[-] Could not mount src nullfs in chroot"
        return ${ret}
    fi

    ${lsudo} mount -t devfs devfs ${lmnt}/dev
    ret=${?}
    if [ ! ${ret} -eq 0 ]; then
        ${lsudo} umount ${lmnt}/usr/ports
        ${lsudo} umount ${lmnt}/usr/src

        echo "[-] Could not mount devfs in chroot"
        return ${ret}
    fi

    ${lsudo} chroot ${lmnt} portmaster -awHD --no-confirm
    ret=${?}
    if [ ! ${ret} -eq 0 ]; then
        echo "[-] Rebuilding ports failed"

        ${lsudo} umount ${lmnt}/usr/ports
        ${lsudo} umount ${lmnt}/usr/src
        ${lsudo} umount ${lmnt}/dev
        return ${ret}
    fi

    ${lsudo} umount ${lmnt}/dev
    ${lsudo} umount ${lmnt}/usr/ports
    ${lsudo} umount ${lmnt}/usr/src

    return 0
}

if [ ${#@} -lt 2 ]; then
    usage ${0}
fi

bename=""
oldbename=""
buildme="false"
pkgups="false"
kernel="SEC"
mntpoint=""
sudo=""
ports=""

while getopts 'b:e:k:m:p:BPsh' o; do
    case "${o}" in
        b)
            bename=${OPTARG}
            ;;
        e)
            oldbename="-e ${OPTARG}"
            ;;
        B)
            buildme="true"
            ;;
        k)
            kernel=${OPTARG}
            ;;
        m)
            mntpoint=${OPTARG}
            ;;
        p)
            ports="${OPTARG}"
            ;;
        P)
            pkgups="true"
            ;;
        s)
            sudo=$(which sudo)
            if [ ${#sudo} -eq 0 ]; then
                echo "[-] Sudo not installed. Please install the security/sudo port"
                exit 1
            fi
            ;;
        h)
            usage ${0}
            ;;
        *)
            usage ${0}
            ;;
    esac
done

if [ ${#bename} -eq 0 ]; then
    usage ${0}
fi

if [ ${#mntpoint} -eq 0 ]; then
    mntpoint="/mnt/${bename}"
fi

beadm=$(which beadm)
if [ ${#beadm} -eq 0 ]; then
    echo "[-] No beadm installed. Please install the sysutils/beadm port"
    exit 1
fi

if [ "${buildme}" = "true" ]; then
    # Don't use sudo. Force an unprivileged build.

    build ${kernel}
    if [ ! ${?} -eq 0 ]; then
        echo "    [-] Build failed"
        exit 1
    fi
fi

echo "[+] Creating new BE ${bename}"

${sudo} ${beadm} create ${oldbename} ${bename}
if [ ! ${?} -eq 0 ]; then
    echo "    [-] Creation of new BE failed"
    exit 1
fi

echo "[+] Mounting new BE"
${sudo} ${beadm} mount ${bename} ${mntpoint}
if [ ! ${?} -eq 0 ]; then
    echo "    [-] Mounting the new BE failed"
    ${sudo} ${beadm} destroy -F ${bename}
    exit 1
fi

echo "[+] Installing new world/kernel"
installuniverse ${kernel} ${mntpoint} ${sudo}
if [ ! ${?} -eq 0 ]; then
    echo "    [-] Installing new world/kernel failed"
    ${sudo} ${beadm} umount ${bename}
    ${sudo} ${beadm} destroy -F ${bename}
    exit 1
fi

if [ "${pkgups}" = "true" ]; then
    echo "[+] Updating ports"
    pkgup ${mntpoint} ${sudo}
    if [ ! ${?} -eq 0 ]; then
        echo "    [-] Rebuilding ports failed"
        ${sudo} ${beadm} umount ${bename}
        ${sudo} ${beadm} destroy -F ${bename}
        exit 1
    fi
fi

if [ ${#ports} -gt 0 ]; then
    echo "[+] Rebuilding ports."
    portbuild ${mntpoint} ${ports} ${sudo}
    if [ ! ${?} -eq 0 ]; then
        echo "    [-] Rebuilding ports failed"
        ${sudo} ${beadm} umount ${bename}
        ${sudo} ${beadm} destroy -F ${bename}
        exit 1
    fi
fi

${sudo} ${beadm} umount ${bename}
${sudo} ${beadm} activate ${bename}

echo "[+] New BE created. Reboot to activate BE"
