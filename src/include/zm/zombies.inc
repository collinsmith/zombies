#if defined _zombies_included
  #endinput
#endif
#define _zombies_included

#pragma reqlib zombies

#tryinclude <logger>

#include "include/zm/extension_t.inc"
#include "include/zm/zm_cfg.inc"
#include "include/zm/zm_debug.inc"
#include "include/zm/zm_i18n.inc"
#include "include/zm/zm_misc.inc"
#include "include/zm/zm_version.inc"

/*******************************************************************************
 * FORWARDS
 ******************************************************************************/

/**
 * Called after ZM has initialized its resources. Extensions should override
 * this function to precache their own dependencies.
 * 
 * @noreturn
 */
forward zm_onPrecache();

/**
 * Called after {@link #zm_onPrecache} when ZM has initialized. Extensions
 * should override this function to initialize any data structures or variables
 * that they rely upon, so that any extensions which in turn depend upon them
 * can access the extension's state within {@link #zm_onInitExtension}.
 * 
 * @noreturn
 */
forward zm_onInit();

/**
 * Called after {@link #zm_onInit}. Extensions should override this function to
 * {@link #zm_registerExtension register themselves} with ZM and initialize.
 * 
 * @noreturn
 */
forward zm_onInitExtension();

/**
 * Called after an extension has been registered.
 * 
 * @param extension The unique identifier associated with the extension
 * @param name      The name of the extension
 * @param desc      A brief description of the extension
 * @param version   The version of the extension
 * 
 * @noreturn
 */
forward zm_onExtensionRegistered(const ZM_Extension: extension, const name[],
                                 const desc[], const version[]);

/*******************************************************************************
 * NATIVES
 ******************************************************************************/

/**
 * Registers an extension of zombies. Extensions should be registered in an
 * effort to maintain good house-keeping of a server and to keep track of
 * plugins which rely on zombies. Extensions should be registered during
 * {@link #zm_onInitExtension}.
 * 
 * @param name    The name of the extension, or {@code ""} to use the file name
 *                  as the extension name (without {@code .amxx})
 * @param desc    A brief description of what the extension does
 * @param version The version of the extension
 * 
 * @return The index assigned to the extension as a result of registering it
 *         with ZM, or {@code Invalid_Extension} if an error occured while
 *         registering it.
 */
native ZM_Extension: zm_registerExtension(const name[] = "",
                                          const version[] = "",
                                          const desc[] = "");

/**
 * Returns the number of extensions registered with ZM.
 */
native zm_getNumExtensions();

/**
 * Populates the passed array with the metadata of the specified extension.
 * 
 * @noreturn
 * 
 * @throws IllegalArgumentException if {@code extension} is invalid.
 */
native zm_getExtension(const ZM_Extension: extension, data[extension_t]);

/**
 * Returns the extension with the given name (case-insensitive), or
 * {@code Invalid_Extension} if no extension with the specified name was found.
 */
native ZM_Extension: zm_findExtension(const name[]);

/**
 * Returns the logger handle used by ZM, or {@code Invalid_Logger} if an error
 * occurred. This logger is used by all core extensions. Extensions which log
 * a lot of information should use their own loggers instead.
 * 
 * @throws IllegalStateException if this function is called before the logger
 *         has been initialized.
 */
native Logger: zm_getLogger();
