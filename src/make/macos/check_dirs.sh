#!/bin/bash

#----------------------------------------------------------------------
# Check if output directories exist or not. If not create them
#
if [ ! -d $LIBDIR ]; then
  mkdir $LIBDIR
fi
if [ ! -d $OBJDIR ]; then
  mkdir $OBJDIR
fi
if [ ! -d $BINDIR ]; then
  mkdir $BINDIR
fi
if [ ! -d $DOCDIR ]; then
  mkdir $DOCDIR
fi
if [ ! -d $LIBDIR ]; then
  echo "$LIBDIR is not a directory" ; exit 1
fi
if [ ! -d $BINDIR ]; then
  echo "$BINDIR is not a directory" ; exit 1
fi
if [ ! -d $OBJDIR ]; then
  echo "$OBJDIR is not a directory" ; exit 1
fi
if [ ! -d $DOCDIR ]; then
  echo "$DOCDIR is not a directory" ; exit 1
fi

