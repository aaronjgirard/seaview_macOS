#!/bin/bash

## macOS port of make_seaseis.sh.
## Usage: make_seaseis_macos.sh [option]
## Options: clean, bleach, verbose, debug

#*****************************************************
# Compiler settings
#
export BUILD_FFTW=0
export BUILD_F77=1
export BUILD_SU=0
export BUILD_MPI=0

export CPP=clang++
export F77=${F77:-gfortran}
export LD=$CPP

#*****************************************************
# Make file settings, command line arguments
#
export MAKE_BLEACH=0
export MAKE_CLEAN=0
export MAKE_DEBUG=0
export VERBOSE=0
export NO_MAKE_BUILD=0

export platform="apple"
export SONAME=install_name

make_argument=""

## Apple Clang flags. -fexpensive-optimizations and -Wformat-overflow are GCC-only.
## -Wl,-undefined,dynamic_lookup -Wl,-headerpad_max_install_names mimics GNU ld's permissive cross-lib symbol resolution
## so the existing build order (cseis_system before segy) still links on macOS.
export GLOBAL_FLAGS="-O3 -Wno-long-long -Wall -pedantic -Wno-unknown-warning-option -Wno-deprecated-declarations -Wno-deprecated-register -Wno-unused-command-line-argument -Wl,-undefined,dynamic_lookup -Wl,-headerpad_max_install_names"
export F77_FLAGS="-ffixed-line-length-132"
export RM="rm -f"

for arg in $@
do
    if [ $arg == "verbose" ]; then
        export VERBOSE=1
        make_argument=""
    fi
    if [ $arg == "debug" ]; then
        export MAKE_DEBUG=1
        make_argument=""
        GLOBAL_FLAGS="-g -DOS_DEBUG=1 -Wno-long-long -Wall -pedantic -Wno-unknown-warning-option -Wno-unused-command-line-argument -Wl,-undefined,dynamic_lookup -Wl,-headerpad_max_install_names"
        F77_FLAGS+=" -g"
    fi
    if [ $arg == "clean" ]; then
        export MAKE_CLEAN=1
        make_argument="clean"
    fi
    if [ $arg == "bleach" ]; then
        export MAKE_BLEACH=1
        make_argument="bleach"
    fi
done

numMakeOptions=$(echo "${MAKE_BLEACH} + ${MAKE_CLEAN} + ${MAKE_DEBUG}" | bc -l)
if [ ${numMakeOptions} -gt 1 ]; then
    echo "ERROR: Too many make options. Specify one option only: debug, clean or bleach"
    exit 1
fi

#********************************************************************************
# Setup environment variables for Seaseis directories
#
source src/make/macos/set_environment.sh

## locate JDK headers
if [ -z "${JAVA_HOME}" ]; then
    if [ -x /usr/libexec/java_home ]; then
        export JAVA_HOME=$(/usr/libexec/java_home 2>/dev/null)
    fi
fi
if [ -n "${JAVA_HOME}" ]; then
    export JNI_INC="-I${JAVA_HOME}/include -I${JAVA_HOME}/include/darwin"
else
    export JNI_INC=""
fi

#********************************************************************************
# Make Seaseis
#
export COMMON_FLAGS="${GLOBAL_FLAGS} -D_FILE_OFFSET_BITS=64 -D_LARGEFILE_SOURCE ${JNI_INC}"
export LD_FLAGS=${GLOBAL_FLAGS}
## libdl is rolled into libSystem on macOS; libc is implicit. Drop both.
export LIB_FLAGS=""

echo "SeaSeis ${VERSION} source root directory:  '${CSEISDIR_SRCROOT}'"
echo "SeaSeis ${VERSION} obj/lib/bin root dir:   '${CSEISDIR}'"
echo "SeaSeis ${VERSION} library directory:      '${LIBDIR}'"
echo "JAVA_HOME:                                 '${JAVA_HOME}'"

${CSEISDIR_SRCROOT}/src/make/macos/cmake.sh ${make_argument}

if [ ${MAKE_BLEACH} -eq 0 -a ${MAKE_CLEAN} -eq 0 ]; then
    if [ -x "${BINDIR}/seaseis" ]; then
        echo "Auto-generate HTML self-documentation:  ${BINDIR}/seaseis -html > ${DOCDIR}/SeaSeis_help.html"
        ${BINDIR}/seaseis -html > ${DOCDIR}/SeaSeis_help.html
    fi
    if [ -x "${THISDIR}/set_links" ]; then
        ${THISDIR}/set_links ${VERSION}
    fi
fi

echo "Done."
