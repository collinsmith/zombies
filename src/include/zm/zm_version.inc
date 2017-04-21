#if defined _zm_version_included
  #endinput
#endif
#define _zm_version_included

#include "include/stocks/exception_stocks.inc"

#include "include/zm/zm_version_codes.inc"
#include "include/zm/zm_debug.inc"

/** The version code of ZM. */
#define ZM_VERSION 1
/** The string representation for this version of ZM. */
#define ZM_VERSION_STRING "1.0.0"

/**
 * Returns the version code of ZM.
 */
stock zm_getVersionId() {
  return ZM_VERSION;
}

/**
 * Returns the string representation for the version of ZM.
 */
stock zm_getVersion(version[], len) {
  return copy(version, len, ZM_VERSION_STRING);
}

/**
 * Returns the build identifier string for the version of ZM.
 */
stock zm_getBuildId(buildId[], len) {
#if defined ZM_COMPILE_FOR_DEBUG
  return formatex(buildId, len, "%s [%s] [DEBUG]", ZM_VERSION_STRING, __DATE__);
#else
  return formatex(buildId, len, "%s [%s]", ZM_VERSION_STRING, __DATE__);
#endif
}
