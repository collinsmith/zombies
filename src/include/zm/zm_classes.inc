#if defined _zm_classes_included
  #endinput
#endif
#define _zm_classes_included

#pragma reqlib zm_classes

#include <celltrie>

#include "include/zm/zm_classes_consts.inc"
#include "include/zm/zombies.inc"

/*******************************************************************************
 * FORWARDS
 ******************************************************************************/

/**
 * Called when a player is about to have their class changed.
 *
 * @param id        The player whose class is about to change
 * @param class     The trie containing the class' data. Properties should be
 *                    documented by the classes
 * @param blockable {@code true} if the class change event is blockable by other
 *                    extensions, {@code false} otherwise
 * 
 * @return Typically {@code PLUGIN_CONTINUE}, however if {@code blockable} is
 *         {@code true}, then {@code PLUGIN_HANDLED} will prevent the change.
 */
forward zm_onBeforeClassChanged(const id, const Class: class, const bool: immediate, const bool: blockable);

/**
 * Called after {@code #zm_onBeforeClassChanged}, once a player has changed
 * classes, but before their actual state has changed. At this stage, the class
 * change event can no longer be blocked.
 *
 * @param id    The player whose class is about to change
 * @param class The trie containing the class' data. Properties should be
 *                documented by the classes
 * 
 * @noreturn
 */
forward zm_onClassChanged(const id, const Class: class, const bool: immediate);

/**
 * Called after {@code #zm_onClassChanged}, once a player has changed classes.
 *
 * @param id    The player whose class is about to change
 * @param class The trie containing the class' data. Properties should be
 *                documented by the classes
 * 
 * @noreturn
 */
forward zm_onAfterClassChanged(const id, const Class: class, const bool: immediate);

/**
 * Called after a class has been registered. The class' properties are stored
 * within the passed trie, whose keys should be documented by the class or
 * class type similar to {@link zm_classes_const.inc}.
 * 
 * @param name  The name of the class, independent of i18n
 * @param class The trie storing the class' data
 * 
 * @noreturn
 */
forward zm_onClassRegistered(const name[], const Class: class);

/**
 * Called when a class' property is about to change. Extensions can override
 * this function to validate property values and return {@code PLUGIN_HANDLED}
 * to invalidate the new value.
 * 
 * @param class    The trie containing the class' data. Properties should be
 *                   documented by the classes
 * @param property The field that changed
 * @param oldValue The previous value of the field
 * @param newValue The current value of the field
 * 
 * @return Typically {@code PLUGIN_CONTINUE}, however if the overriding function
 *         invalidates {@code newValue}, then {@code PLUGIN_HANDLED} will
 *         block the property change.
 */
forward zm_onBeforeClassPropertyChanged(const Class: class, const property[],
                                        const oldValue[], const newValue[]);

/**
 * Called after {@link #zm_onBeforeClassPropertyChanged}, when a class' property
 * has been changed. This propagates the string representation for the updated
 * value, it is the responsibility of the overriding functions to parse the
 * values if necessary and cache them.
 * 
 * @param class    The trie containing the class' data. Properties should be
 *                   documented by the classes
 * @param property The field that changed
 * @param oldValue The previous value of the field
 * @param newValue The current value of the field
 * 
 * @noreturn
 */
forward zm_onClassPropertyChanged(const Class: class, const property[],
                                  const oldValue[], const newValue[]);

/*******************************************************************************
 * NATIVES
 ******************************************************************************/

/**
 * Registers a class with the ZM classes module. Registered classes will send
 * registration forwards to extensions, allowing them to be cached into
 * sub-extensions such as the classes menu, making the class selectable by
 * a user.
 * 
 * The trie should contain at least the {@code ZM_CLASS_NAME} key, referencing
 * the name of the class. All values should be represented within the trie as
 * strings, which can be parsed appropriately by extensions.
 * 
 * {@link #zm_setClassProperty} can be called to update the value for a specific
 * property and send the suggested forward, however if many modifications are
 * made then {@link #zm_reloadClass} should be used instead, which calls
 * {@link #zm_onClassPropertyChanged} for each property with an empty previous
 * value ({@code ""}).
 * 
 * @param class   The handle to the trie representing the class
 * @param replace {@code true} to replace existing classes with the same
 *                {@code ZM_CLASS_NAME} (if any), {@code false} otherwise
 * 
 * @return {@code true} if the class was registered as a result of this call,
 *         {@code false} otherwise
 * 
 * @throws ThrowIllegalArgumentException if {@code class} is {@code Invalid_Trie},
 *         the {@code class} does not contain a {@code ZM_CLASS_NAME} key, or
 *         {@code replace} is {@code false} and a class is already registered
 *         with the same name as {@code class}.
 */
native bool: zm_registerClass(const Trie: class, const bool: replace = false);

/**
 * Locates the handle of the trie representing the class with the specified
 * {@code name} and returns it. If the class cannot be found, then
 * {@code Invalid_Trie} is returned instead.
 */
native Trie: zm_findClass(const name[]);

/**
 * Changes the specified class property.
 * 
 * @param class    The class whose property to change
 * @param property The name of the property
 * @param value    The value to assign the property
 * 
 * @return {@code true} if the value of the {@code property} changed as a
 *         result of this call, {@code false} otherwise. This function will
 *         return {@code false} if {@code value} is the same as the current
 *         value, or {@code value} was invalidated by an extension and the
 *         change was rejected
 * 
 * @throws IllegalArgumentException if {@code class} is {@code Invalid_Trie}.
 */
native zm_setClassProperty(const Class: class, const property[], const value[]);

/**
 * Indicates whether or not the specified class has been registered with ZM.
 * This is analogous with calling {@link #zm_findClass} with the name of the
 * specified class, however this will also distinguish whether or not the class
 * returned by {@link #zm_findClass} is actually equivalent to {@code class}.
 */
native bool: zm_isClassRegistered(const any: class);

/**
 * Returns the class assigned to the specified player, or {@code Invalid_Trie}
 * if the player has no class assigned to him.
 */
native Trie: zm_getUserClass(const id);

/**
 * Assigns a class to a player.
 * 
 * @param id        The player to assign {@code class} to
 * @param class     The class to assign
 * @param immediate {@code true} to immediately assign the class, regardless of
 *                    whether or not they already have a class, or {@code false}
 *                    to assign the class at the next appripriate time (such as
 *                    when a respawn or infection event occurs)
 * @param blockable {@code true} if the class change event is blockable by
 *                    extensions, {@code false} otherwise
 * 
 * @return The previous class assigned to the player if {@code immediate} is
 *         {@code true}, otherwise the previous value of their next class (i.e.,
 *         the class they would have changed to if a graceful class change had
 *         occurred).
 */
native Trie: zm_setUserClass(const id, const Class: class, const bool: immediate = false, const bool: blockable = true);

/**
 * Returns the number of classes registered.
 */
native zm_getNumClasses();

/**
 * Populates the passed array with handles to the tries representing the classes
 * that have been registered with ZM (in no particular order).
 * 
 * The caller is responsible for destroying the returned array once they are
 * finished using it.
 * 
 * @param dst The destination cellarray to copy the classes to, if
 *              {@code dst} is {@code Invalid_Array}, then a new cellarray will
 *              be allocated.
 * 
 * @return An array containing the registered classes
 */
native Array: zm_getClasses(const Array: dst = Invalid_Array);

/**
 * Registers this plugin as a loader of class files.
 * 
 * Example: {@code zm_registerClassLoader("onLoadClass", "txt", "cfg", "ini");
 * 
 * @param callback  The function to be called when a file is being parsed for
 *                    classes with one of the extensions registered. The
 *                    signature of the callback function should be:
 *                    {@code Trie: <callback>(const path[], const extension[]);}
 *                    and should return the handle of the trie containing the
 *                    loaded class, or {@code Invalid_Trie} if an error occurred
 * @param extension The file extensions this class loader recognizes
 */
native zm_registerClassLoader(const callback[], const extension[], ...);

/**
 * Loads the classes contained within the specified file (or folder) and
 * registers them with ZM. If {@code path} refers to a directory and
 * {@code recursive} is {@code true}, then classes in that folder and any
 * subfolders (recursively) are parsed and loaded. All paths should be given
 * relative to the ZM configs directory (see below). Typically, classes should
 * be given as one class per file, however this is dependent on the class file
 * format.
 * 
 * Examples:
 * {@code
 * zm_loadClass("classes/classic.smc");
 * zm_loadClass("classes", true);
 * }
 * 
 * @param path      The path of the file (or folder) containing the class(es)
 *                    to load
 * @param class     The specific class to load, or {@code ""} to load all classes
 * @param recursive {@code true} to load classes recursively from the file
 *                    system, otherwise load only the immediate files. This is
 *                    only applicable to when {@code file} refers to a folder
 * 
 * @see #zm_registerClass
 * @see zm_cfg.inc::zm_getConfigsDirPath
 */
native zm_loadClass(const path[], const bool: recursive = false);

/**
 * Reloads the specified class as if it were being registered for the first
 * time, with the exception that instead of calling {@link #zm_onClassRegistered},
 * {@link #zm_onClassPropertyChanged} is called for each field in the class with
 * the previous value set to {@code ""}.
 * 
 * This native is provided in the case that it is easier to modify a class using
 * its trie handle directly, and then push those updates all at once. This
 * function will not attempt to validate the values, as
 * {@link #zm_onClassPropertyChanged} will not be called.
 * 
 * @param class The handle of the trie repreesnting the class
 */
//native zm_reloadClass(const Trie: class);
