# autoconf template for the configure script

AC_INIT
AC_CONFIG_MACRO_DIR([m4])
#AC_CANONICAL_SYSTEM


PKG_PROG_PKG_CONFIG([])

#--------------------------------------------------------------------
# Check for gnutls
#--------------------------------------------------------------------
PKG_CHECK_MODULES(GNUTLS, gnutls, HAVE_GNUTLS=1, HAVE_GNUTLS=0)
AC_SUBST(GNUTLS_CFLAGS)
AC_SUBST(GNUTLS_LIBS)
AC_SUBST(HAVE_GNUTLS)
if test "$HAVE_GNUTLS" = "0"; then
  AC_MSG_WARN("GnuTLS not available advanced cryptographic functions are disabled.")
fi

AC_CONFIG_FILES([config.make config.h])

AC_OUTPUT
