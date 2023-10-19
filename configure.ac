# autoconf template for the configure script

AC_INIT
AC_CONFIG_MACRO_DIR([m4])
#AC_CANONICAL_SYSTEM

if test -z "$GNUSTEP_MAKEFILES"; then
 GNUSTEP_MAKEFILES=`gnustep-config --variable=GNUSTEP_MAKEFILES 2>/dev/null`
fi

if test -z "$GNUSTEP_MAKEFILES"; then
 AC_MSG_ERROR([You must run the GNUstep initialization script first!])
fi

#--------------------------------------------------------------------
# Find the compiler
#--------------------------------------------------------------------
if test "$CC" = ""; then
 CC=`gnustep-config --variable=CC`
fi
if test "$CPP" = ""; then
 CPP=`gnustep-config --variable=CPP`
fi
if test "$CXX" = ""; then
 CXX=`gnustep-config --variable=CXX`
fi

PKG_PROG_PKG_CONFIG([])

#--------------------------------------------------------------------
# Check for nettle
#--------------------------------------------------------------------
PKG_CHECK_MODULES([NETTLE], [nettle], [HAVE_NETTLE=1], [HAVE_NETTLE=0])
if test "x$HAVE_NETTLE" = "x1"; then
  saved_CFLAGS=$CFLAGS
  saved_LIBS=$LIBS
  NETTLE_CFLAGS=`pkg-config --cflags nettle`
  NETTLE_LDFLAGS=`pkg-config --libs-only-L nettle`
  NETTLE_OTHERFLAGS=`pkg-config --libs-only-other nettle`
  NETTLE_LIBS=`pkg-config --libs-only-l nettle`
  CFLAGS="$CFLAGS $NETTLE_CFLAGS"
  LIBS="$NETTLE_OTHERFLAGS $NETTLE_LDFLAGS $NETTLE_LIBS $LIBS"
  AC_CHECK_FUNCS(nettle_sha3_512_init)
  if test "$ac_cv_func_nettle_sha3_512_init" = "no"; then
    CFLAGS=$saved_CFLAGS
    LIBS=$saved_LIBS
    AC_DEFINE([HAVE_NETTLE], [0])
  fi
fi
AC_SUBST(NETTLE_CFLAGS)
AC_SUBST(NETTLE_LDFLAGS)
AC_SUBST(NETTLE_OTHERFLAGS)
AC_SUBST(NETTLE_LIBS)
AC_SUBST(HAVE_NETTLE)
if test "x$HAVE_NETTLE" = "x0"; then
  AC_MSG_WARN("Nettle not available (or too old); advanced hash digest disabled.")
fi


#--------------------------------------------------------------------
# Check for gnutls
#--------------------------------------------------------------------
PKG_CHECK_MODULES([GNUTLS], [gnutls], [HAVE_GNUTLS=1], [HAVE_GNUTLS=0])
if test "x$HAVE_GNUTLS" = "x1"; then
  saved_CFLAGS=$CFLAGS
  saved_LIBS=$LIBS
  GNUTLS_CFLAGS=`pkg-config --cflags gnutls`
  GNUTLS_LDFLAGS=`pkg-config --libs-only-L gnutls`
  GNUTLS_LIBS=`pkg-config --libs-only-l gnutls`
  CFLAGS="$CFLAGS $GNUTLS_CFLAGS"
  LIBS="$GNUTLS_LDFLAGS $GNUTLS_LIBS $LIBS"
  AC_CHECK_FUNCS(gnutls_hash_fast)
  if test "$ac_cv_func_gnutls_hash_fast" = "no"; then
    CFLAGS=$saved_CFLAGS
    LIBS=$saved_LIBS
    HAVE_GNUTLS=0
  fi
fi
AC_SUBST(GNUTLS_CFLAGS)
AC_SUBST(GNUTLS_LDFLAGS)
AC_SUBST(GNUTLS_LIBS)
AC_SUBST(HAVE_GNUTLS)
if test "x$HAVE_GNUTLS" = "x0"; then
  AC_MSG_WARN("GnuTLS not available (or too old); advanced cryptographic functions are disabled.")
fi

AC_CONFIG_FILES([config.make config.h GWSHash.h])

AC_OUTPUT
