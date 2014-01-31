# autoconf template for the configure script

AC_INIT
AC_CONFIG_MACRO_DIR([m4])
#AC_CANONICAL_SYSTEM


PKG_PROG_PKG_CONFIG([])

#--------------------------------------------------------------------
# Check for gnutls
#--------------------------------------------------------------------
PKG_CHECK_MODULES([GNUTLS], gnutls, HAVE_GNUTLS=1, HAVE_GNUTLS=0)
if test "$HAVE_GNUTLS" = "1"; then
  AC_CHECK_FUNCS(gnutls_hash_fast)
  if test "$ac_cv_func_gnutls_hash_fast" = "no"; then
    GNUTLS_CFLAGS=
    GNUTLS_LIBS=
    HAVE_GNUTLS=0
  fi
fi
AC_SUBST(GNUTLS_CFLAGS)
AC_SUBST(GNUTLS_LIBS)
AC_SUBST(HAVE_GNUTLS)
if test "$HAVE_GNUTLS" = "0"; then
  AC_MSG_WARN("GnuTLS not available (or too old); advanced cryptographic functions are disabled.")
fi

AC_CONFIG_FILES([config.make config.h])

AC_OUTPUT
