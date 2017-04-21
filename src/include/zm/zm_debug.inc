#if defined _zm_debug_included
  #endinput
#endif
#define _zm_debug_included

/**
 * Indicates whether or not to compile in debug mode. Compiling in debug mode
 * will enable many additional commands and features that are not required for
 * release use. Enabling this option will also add a ton of additional logging
 * which is intended for development purposes.
 */
//#define ZM_COMPILE_FOR_DEBUG

#if defined ZM_COMPILE_FOR_DEBUG
  //#define DEBUG_COMMANDS
  #define DEBUG_I18N
#else
  //#define DEBUG_COMMANDS
  //#define DEBUG_I18N
#endif

/*******************************************************************************
 * CONSTANTS
 ******************************************************************************/

stock const TRUE[] = "true";
stock const FALSE[] = "false";
stock const NULL[] = "null";
stock const ZOMBIE[] = "zombie";
stock const HUMAN[] = "human";

/*******************************************************************************
 * STOCKS
 ******************************************************************************/

/**
 * Indicates whether or not ZM was compiled in debug mode.
 */
stock bool: zm_isDebugModeEnabled() {
#if defined ZM_COMPILE_FOR_DEBUG
  return true;
#else
  return false;
#endif
}
