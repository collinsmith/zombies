#if defined _zm_class_menu_included
  #endinput
#endif
#define _zm_class_menu_included

#pragma reqlib zm_class_menu

#include <amxconst>

#include "include/zm/zm_classes.inc"

/*******************************************************************************
 * FORWARDS
 ******************************************************************************/

/**
 * Called right before the classes menu is displayed to a user. Extensions can
 * override this function if in certain cases you would like to stop the menu
 * from being displayed.
 * 
 * @param id       The player that the menu is being displayed for
 * @param exitable {@code true} if the menu is exitable, {@code false} otherwise
 * 
 * @return Typically {@code PLUGIN_CONTINUE}, however if {@code exitable} is
 *         {@code true}, then {@code PLUGIN_HANDLED} will prevent the menu from
 *         being displayed.
 */
forward zm_onBeforeClassesMenuDisplayed(const id, const bool: exitable);

/**
 * Called when the classes menu is displayed to a user.
 * 
 * @param id       The player that the menu is being displayed for
 * @param exitable {@code true} if the menu is exitable, {@code false} otherwise
 * 
 * @noreturn
 */
forward zm_onClassesMenuDisplayed(const id, const bool: exitable);

/**
 * Called when the class menu is being constructed for a user, enabling or
 * disabling the appropriate classes.
 * 
 * @param id    The player that the menu is being constructed for
 * @param class The class represented by the menu item
 * @param name  The name of the class (without i18n)
 * 
 * @return One of {@code ITEM_IGNORE}, {@code ITEM_ENABLED}, or
 *         {@code ITEM_DISABLED}. Returning {@code ITEM_DISABLED} will override
 *         any other return values from this forward and disable the item.
 */
forward zm_isClassEnabled(const id, const Class: class, const name[]);

/*******************************************************************************
 * NATIVES
 ******************************************************************************/

/**
 * Displays the class menu to the specified player. Once a class is selected,
 * it will typically be applied the next time they respawn.
 * 
 * @param id       The player to display the menu for
 * @param exitable {@code true} if the menu is exitable, {@code false} otherwise
 * 
 * @return {@code true} if the menu displayed as a result of this call,
 *         {@code false} otherwise. This function will return {@code false} if
 *         {@code exitable} is {@code true} and another extension blocks the
 *         menu from displaying.
 */
native bool: zm_showClassesMenu(const id, const bool: exitable = true);
