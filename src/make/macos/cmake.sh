#!/bin/bash

# -------------------------------------------------------
# CSEIS make utility (macOS)
#
# Usage: cmake.sh [make argument list]
# The make argument list can consist of any arguments for the make utility.
#

# -------------------------------------------------------
# Set argument list for 'make'
arg_list=$@

# Check directories
${CSEISDIR_SRCROOT}/src/make/macos/check_dirs.sh
ret=$?; if [ $ret -ne 0 ]; then exit $ret; fi

#-------------------------------------------------------------------
# Build SeaSeis

# Go to source root directory before running make.
# Most Make files are relative to source root directory.
cd ${CSEISDIR_SRCROOT}

# Build module header files
if [ $NO_MAKE_BUILD -ne 1 ]; then
  make ${arg_list} -f src/make/macos/Makefile_build | grep -v "Nothing to be done for"
fi

echo "Building SeaSeis..."
make ${arg_list} -f src/make/macos/Makefile_libs | grep -v "Nothing to be done for"
make ${arg_list} -f src/make/macos/Makefile_segy | grep -v "Nothing to be done for"
make ${arg_list} -f src/make/macos/Makefile_segd | grep -v "Nothing to be done for"
make ${arg_list} -f src/make/macos/Makefile_main | grep -v "Nothing to be done for"
echo "Done."

#--------------------------------------------------
# Build modules

echo "Building SeaSeis modules..."

makefiles=
# Add make files for modules that use FFTW library:
if [ ${BUILD_FFTW} -eq 1 ]; then
    echo Making modules requiring fftw library
    makefiles="$makefiles $(find src/cs/modules -name Makefile_fftw -print)"
    echo $makefiles
fi
makefiles="$makefiles $(find src/cs/modules -name Makefile -print)"
# Add make files for Fortran modules:
if [ ${BUILD_F77} -eq 1 ]; then
    makefiles="$makefiles $(find src/cs/modules -name Makefile_f77 -print)"
fi

for makefile in $makefiles
do
  make ${arg_list} -f $makefile | grep -v "Nothing to be done for"
done

echo "Done."

#--------------------------------------------------
# Build SU module if requested
if [ ${BUILD_SU} -eq 1 ]; then
  echo "Building SU SeaSeis module & associated SU modules..."
  make ${arg_list} -f src/cs/su/Makefile_sulib | grep -v "Nothing to be done for"
  make ${arg_list} -f src/cs/su/Makefile_su | grep -v "Nothing to be done for"
  make ${arg_list} -f src/cs/su/Makefile | grep -v "Nothing to be done for"
  echo "Done."
fi

#--------------------------------------------------
# Build SeaView (skip XCSeis: not needed for the macOS .dmg)

echo "Building SeaView..."
make ${arg_list} -f src/make/macos/Makefile_seaview | grep -v "Nothing to be done for"
echo "Done."

if [ -f ${LIBDIR}/seaseis ]; then
 \cp -f ${LIBDIR}/seaseis ${BINDIR}
fi

#--------------------------------------------------
# macOS install_name fixup: rewrite each lib's install id and every consumer's
# LC_LOAD_DYLIB entry to absolute paths so the seaseis CLI and modules can
# resolve their dependencies without DYLD_LIBRARY_PATH.

if [ "${MAKE_BLEACH}" = "0" ] && [ "${MAKE_CLEAN}" = "0" ]; then
  ${CSEISDIR_SRCROOT}/src/make/macos/fix_install_names.sh "${LIBDIR}" "${BINDIR}"
fi
