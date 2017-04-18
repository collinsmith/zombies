#include <amxmodx>
#include <logger>

#include "include/stocks/param_stocks.inc"
#include "include/stocks/debug_stocks.inc"

#include "include/zm/zm_classes_consts.inc"
#include "include/zm/zm_teams.inc"
#include "include/zm/zombies.inc"

#if defined ZM_COMPILE_FOR_DEBUG
  #define DEBUG_NATIVES
  //#define DEBUG_FORWARDS
  #define DEBUG_REGISTRATION
  #define DEBUG_ASSIGNMENTS
  #define DEBUG_GET_CLASSES
  #define DEBUG_CLASS_CHANGES
  //#define DEBUG_LOADERS
#else
  //#define DEBUG_NATIVES
  //#define DEBUG_FORWARDS
  //#define DEBUG_REGISTRATION
  //#define DEBUG_ASSIGNMENTS
  //#define DEBUG_GET_CLASSES
  //#define DEBUG_CLASS_CHANGES
  //#define DEBUG_LOADERS
#endif

#define EXTENSION_NAME "Class Manager"
#define VERSION_STRING "1.0.0"

#define CLASSES_DICTIONARY "zm_classes.txt"

/** Log a warning if registering a class which will overwrite an existing one */
#define WARN_ON_CLASS_OVERWRITE
/** Throw an error if operating on a class which isn't registered */
#define ENFORCE_REGISTERED_CLASSES_ONLY
/** Only forward class property change events if new value is different from current */
#define CHECK_PROPERTY_CHANGED
/** Log a warning if registering an extension for a class loader which will overwrite an existing one */
#define WARN_ON_EXTENSION_OVERWRITE

static Logger: logger = Invalid_Logger;

static fwReturn = 0;
static onBeforeClassChanged = INVALID_HANDLE;
static onClassChanged = INVALID_HANDLE;
static onAfterClassChanged = INVALID_HANDLE;
static onClassRegistered = INVALID_HANDLE;
static onBeforeClassPropertyChanged = INVALID_HANDLE;
static onClassPropertyChanged = INVALID_HANDLE;

static Trie: classes;
static Trie: classLoaders;
#if defined DEBUG_LOADERS
static Trie: classLoaderPlugins;
#endif

static key[class_prop_key_length + 1];
static value[class_prop_value_length + 1];

static Trie: pClass[MAX_PLAYERS + 1];
static Trie: pNextClass[MAX_PLAYERS + 1];

stock Trie: toTrie(value) return Trie:(value);
stock Trie: operator=(value) return toTrie(value);

stock Array: toArray(value) return Array:(value);
stock Array: operator=(value) return toArray(value);

stock bool: operator=(value) return value > 0;

public plugin_natives() {
  register_library("zm_classes");

  register_native("zm_registerClass", "native_registerClass");
  register_native("zm_findClass", "native_findClass");
  register_native("zm_setClassProperty", "native_setClassProperty");
  register_native("zm_isClassRegistered", "native_isClassRegistered");

  register_native("zm_getUserClass", "native_getUserClass");
  register_native("zm_setUserClass", "native_setUserClass");

  register_native("zm_getNumClasses", "native_getNumClasses");
  register_native("zm_getClasses", "native_getClasses");

  register_native("zm_registerClassLoader", "native_registerClassLoader");
  register_native("zm_loadClass", "native_loadClass");
  //register_native("zm_reloadClass", "native_reloadClass");
}

public zm_onInit() {
  logger = zm_getLogger();
}

public zm_onInitExtension() {
  new name[32];
  formatex(name, charsmax(name), "[%L] %s", LANG_SERVER, ZM_NAME_SHORT, EXTENSION_NAME);

  new buildId[32];
  getBuildId(buildId, charsmax(buildId));
  register_plugin(name, buildId, "Tirant");
  zm_registerExtension(
      .name = EXTENSION_NAME,
      .version = buildId,
      .desc = "Manages the classes");

  register_dictionary(CLASSES_DICTIONARY);
#if defined DEBUG_I18N
  LoggerLogDebug(logger, "Registering dictionary file \"%s\"", CLASSES_DICTIONARY);
#endif

  createForwards();
  registerConCmds();
  
  new path[256];
  zm_getConfigsDir(path, charsmax(path));
  BuildPath(path, charsmax(path), path, "classes");
  loadClasses(path, true);
}

stock getBuildId(buildId[], len) {
  return formatex(buildId, len, "%s [%s]", VERSION_STRING, __DATE__);
}

stock registerConCmds() {
#if defined DEBUG_REGISTRATION
  zm_registerConCmd(
      .command = "classes",
      .callback = "onPrintClasses",
      .desc = "Lists the registered classes of ZM",
      .logger = logger);
#endif

#if defined DEBUG_LOADERS
  zm_registerConCmd(
      .command = "loaders",
      .callback = "onPrintLoaders",
      .desc = "Lists the registered class loaders of ZM",
      .logger = logger);
#endif
}

createForwards() {
  createClassChangeForwards();
}

createClassChangeForwards() {
  createOnBeforeClassChanged();
  createOnClassChanged();
  createOnAfterClassChanged();
}

createOnBeforeClassChanged() {
#if defined DEBUG_FORWARDS
  assert onBeforeClassChanged == INVALID_HANDLE;
  LoggerLogDebug(logger, "Creating forward zm_onBeforeClassChanged");
#endif
  onBeforeClassChanged = CreateMultiForward(
      "zm_onBeforeClassChanged", ET_STOP,
      FP_CELL, FP_CELL, FP_CELL, FP_CELL);
#if defined DEBUG_FORWARDS
  LoggerLogDebug(logger, "onBeforeClassChanged = %d", onBeforeClassChanged);
#endif
}

createOnClassChanged() {
#if defined DEBUG_FORWARDS
  assert onClassChanged == INVALID_HANDLE;
  LoggerLogDebug(logger, "Creating forward zm_onClassChanged");
#endif
  onClassChanged = CreateMultiForward(
      "zm_onClassChanged", ET_CONTINUE,
      FP_CELL, FP_CELL, FP_CELL);
#if defined DEBUG_FORWARDS
  LoggerLogDebug(logger, "onClassChanged = %d", onClassChanged);
#endif
}

createOnAfterClassChanged() {
#if defined DEBUG_FORWARDS
  assert onAfterClassChanged == INVALID_HANDLE;
  LoggerLogDebug(logger, "Creating forward zm_onAfterClassChanged");
#endif
  onAfterClassChanged = CreateMultiForward(
      "zm_onAfterClassChanged", ET_CONTINUE,
      FP_CELL, FP_CELL, FP_CELL);
#if defined DEBUG_FORWARDS
  LoggerLogDebug(logger, "onAfterClassChanged = %d", onAfterClassChanged);
#endif
}

zm_onClassRegistered(name[], Trie: class) {
  if (onClassRegistered == INVALID_HANDLE) {
#if defined DEBUG_FORWARDS
    LoggerLogDebug(logger, "Creating forward for zm_onClassRegistered");
#endif
    onClassRegistered = CreateMultiForward(
        "zm_onClassRegistered", ET_CONTINUE,
        FP_STRING, FP_CELL);
#if defined DEBUG_FORWARDS
    LoggerLogDebug(logger, "onClassRegistered = %d", onClassRegistered);
#endif
  }

#if defined DEBUG_FORWARDS
  LoggerLogDebug(logger, "Forwarding zm_onClassRegistered for %s", name);
#endif
  ExecuteForward(onClassRegistered, fwReturn, name, class);
}

zm_onBeforeClassPropertyChanged(Trie: class, key[], oldValue[], newValue[]) {
  if (onBeforeClassPropertyChanged == INVALID_HANDLE) {
#if defined DEBUG_FORWARDS
    LoggerLogDebug(logger, "Creating forward for zm_onBeforeClassPropertyChanged");
#endif
    onBeforeClassPropertyChanged = CreateMultiForward(
        "zm_onBeforeClassPropertyChanged", ET_STOP,
        FP_CELL, FP_STRING, FP_STRING, FP_STRING);
#if defined DEBUG_FORWARDS
    LoggerLogDebug(logger, "onBeforeClassPropertyChanged = %d", onBeforeClassPropertyChanged);
#endif
  }
  
#if defined DEBUG_FORWARDS
  LoggerLogDebug(logger, "Forwarding zm_onBeforeClassFieldChanged for %d: \"%s\"", class, key);
#endif
  ExecuteForward(onBeforeClassPropertyChanged, fwReturn, class, key, oldValue, newValue);
  return fwReturn;
}

zm_onClassPropertyChanged(Trie: class, key[], oldValue[], newValue[]) {
  if (onClassPropertyChanged == INVALID_HANDLE) {
#if defined DEBUG_FORWARDS
    LoggerLogDebug(logger, "Creating forward for zm_onClassPropertyChanged");
#endif
    onClassPropertyChanged = CreateMultiForward(
        "zm_onClassPropertyChanged", ET_CONTINUE,
        FP_CELL, FP_STRING, FP_STRING, FP_STRING);
#if defined DEBUG_FORWARDS
    LoggerLogDebug(logger, "onClassPropertyChanged = %d", onClassPropertyChanged);
#endif
  }
  
#if defined DEBUG_FORWARDS
  LoggerLogDebug(logger, "Forwarding zm_onClassPropertyChanged for %d: \"%s\"", class, key);
#endif
  ExecuteForward(onClassPropertyChanged, fwReturn, class, key, oldValue, newValue);
  return fwReturn;
}

zm_onBeforeClassChanged(id, Trie: class, bool: immediate, bool: blockable) {
  assert onBeforeClassChanged != INVALID_HANDLE;
#if defined DEBUG_FORWARDS
  LoggerLogDebug(logger, "Forwarding zm_onBeforeClassChanged(%d, %d, immediate=%s, blockable=%s) for %N",
      id, class, immediate ? TRUE : FALSE, blockable ? TRUE : FALSE, id);
#endif
  ExecuteForward(onBeforeClassChanged, fwReturn, id, class, immediate, blockable);
  return fwReturn;
}

zm_onClassChanged(id, Trie: class, name[], bool: immediate) {
#if defined DEBUG_FORWARDS
  LoggerLogDebug(logger, "Calling zm_onClassChanged(%d, %s, immediate=%s) for %N",
      id, name, immediate ? TRUE : FALSE, id);
#else
  #pragma unused name
#endif
  ExecuteForward(onClassChanged, fwReturn, id, class, immediate);
}

zm_onAfterClassChanged(id, Trie: class, name[], bool: immediate) {
#if defined DEBUG_FORWARDS
  LoggerLogDebug(logger, "Calling zm_onAfterClassChanged(%d, %s, immediate=%s) for %N",
      id, name, immediate ? TRUE : FALSE, id);
#else
  #pragma unused name
#endif
  ExecuteForward(onAfterClassChanged, fwReturn, id, class, immediate);
}

bool: isClassRegistered(const Trie: class) {
  if (!class || !classes) {
    return false;
  }
  
  new len;
  TrieGetString(class, ZM_CLASS_NAME, key, charsmax(key), len);
  
  new Trie: mapping;
  new bool: containsKey = TrieGetCell(classes, key, mapping);
  return containsKey && mapping == class;
}

apply(const id, const Trie: class) {
  assert isValidId(id);
#if defined DEBUG_CLASS_CHANGES
  new const Trie: oldClass = pClass[id];
  new oldClassName[32], newClassName[32];
  zm_getClassProperty(class, ZM_CLASS_NAME, newClassName, charsmax(newClassName));
  if (oldClass) {
    zm_getClassProperty(oldClass, ZM_CLASS_NAME, oldClassName, charsmax(oldClassName));
  } else {
    copy(oldClassName, charsmax(oldClassName), NULL);
  }

  LoggerLogDebug(logger, "%N changed class from %s to %s", id, oldClassName, newClassName);
#endif
  pClass[id] = class;
  zm_refresh(id);
}

public zm_onApply(const id) {
  new const Trie: nextClass = pNextClass[id];
  if (nextClass && nextClass != pClass[id]) {
    apply(id, nextClass);
    pNextClass[id] = Invalid_Trie;
#if defined DEBUG_CLASS_CHANGES
    LoggerLogDebug(logger, "pNextClass[%d] = Invalid_Trie", id);
#endif
  }
}

loadClasses(path[] = "", bool: recursive = false) {
#if defined DEBUG_LOADERS
  LoggerLogDebug(logger, "Loading classes in \"%s\"", path);
#endif

  new file[32], len;
  new dir = open_dir(path, file, charsmax(file));
  if (!dir) {
    LoggerLogError(logger, "Failed to open \"%s\" (not found or unable to open)", path);
    return;
  }

  new subPath[256];
  len = copy(subPath, charsmax(subPath), path);
  if (len <= charsmax(subPath)) {
    subPath[len++] = PATH_SEPARATOR;
  }

  new const pathLen = len;
  do {
    len = pathLen + copy(subPath[pathLen], charsmax(subPath) - pathLen, file);
    if (equal(file, ".") || equal(file, "..")) {
      continue;
    }

    if (dir_exists(subPath)) {
      if (recursive) {
        loadClasses(subPath, recursive);
      }

      continue;
    }

    loadClass(subPath, len);
  } while (next_file(dir, file, charsmax(file)));
  close_dir(dir);
}

loadClass(path[] = "", len) {
#if defined DEBUG_LOADERS
  assert classLoaders;
  LoggerLogDebug(logger, "Parsing class file \"%s\"", path);
#endif
  
  // TODO: turn this into a file util stock
  new extension[32];
  for (new i = len - 1; i >= 0; i--) {
    if (path[i] == PATH_SEPARATOR) {
      LoggerLogWarning(logger, "Failed to load \"%s\", no extension", path);
      return;
    } else if (path[i] == '.') {
      copy(extension, charsmax(extension), path[i + 1]);
      break;
    }
  }

  new onLoadClass;
  new bool: keyExists = TrieGetCell(classLoaders, extension, onLoadClass);
  if (!keyExists) {
    LoggerLogWarning(logger, "Failed to load \"%s\", no class loader registered for \"%s\"", path, extension);
    return;
  }

#if defined DEBUG_LOADERS
  LoggerLogDebug(logger, "Forwarding to class loader %d", onLoadClass);
#endif
  ExecuteForward(onLoadClass, fwReturn, path, extension);
}

/*******************************************************************************
 * Console Commands
 ******************************************************************************/

#if defined DEBUG_REGISTRATION
public onPrintClasses(id) {
  console_print(id, "Classes:");

  new count = 0;
  if (classes) {
    new Snapshot: keySet = TrieSnapshotCreate(classes);
    count = TrieSnapshotLength(keySet);

    new maxName;
    for (new i = 0, len; i < count; i++) {
      len = TrieSnapshotKeyBufferSize(keySet, i);
      maxName = max(maxName, len);
    }

    new headerFmt[32];
    formatex(headerFmt, charsmax(headerFmt), "%%3s %%4s %%%ds %%s", maxName);
    console_print(id, headerFmt, "#", "TRIE", "NAME", "DESCRIPTION");

    new fmt[32];
    formatex(fmt, charsmax(fmt), "%%2d. %%-4d %%%ds %%s", maxName);

    for (new i = 0, len; i < count; i++) {
      len = TrieSnapshotGetKey(keySet, i, key, charsmax(key));

      new Trie: class;
      TrieGetCell(classes, key, class);

      TrieGetString(class, ZM_CLASS_DESC, value, charsmax(value), len);

      console_print(id, fmt, i + 1, class, key, value);
    }

    TrieSnapshotDestroy(keySet);
  }

  console_print(id, "%d classes registered.", count);
  return PLUGIN_HANDLED;
}
#endif

#if defined DEBUG_LOADERS
public onPrintLoaders(id) {
  console_print(id, "Class Loaders:");
  
  new count, uniqueLoaders = 0;
  if (classLoaders) {
    new tmp[2];
    new Trie: valueSet = TrieCreate();
    new Snapshot: keySet = TrieSnapshotCreate(classLoaderPlugins);
    count = TrieSnapshotLength(keySet);
    for (new i = 0, len; i < count; i++) {
      len = TrieSnapshotGetKey(keySet, i, key, charsmax(key));
      key[len] = 0;

      new plugin;
      TrieGetCell(classLoaderPlugins, key, plugin);

      tmp[0] = plugin;
      TrieSetCell(valueSet, tmp, 1);
      
      new filename[32];
      get_plugin(plugin, .filename = filename, .len1 = charsmax(filename));
      console_print(id, "%4s [%s]", key, filename);
    }
    
    TrieSnapshotDestroy(keySet);

    uniqueLoaders = TrieGetSize(valueSet);
    TrieDestroy(valueSet);
  }

  console_print(id, "%d class loaders registered for %d extensions.", uniqueLoaders, count);
  return PLUGIN_HANDLED;
}
#endif

/*******************************************************************************
 * Natives
 ******************************************************************************/

//native bool: zm_registerClass(const Trie: class, const bool: replace = true);
public bool: native_registerClass(plugin, numParams) {
#if defined DEBUG_NATIVES
  if (!numParamsEqual(2, numParams, logger)) {
    return false;
  }
#endif

  new const Trie: class = get_param(1);
  if (!class) {
    ThrowIllegalArgumentException(logger, "Invalid class specified: %d", class);
    return false;
  }

  new bool: keyExists, len;
  keyExists = TrieGetString(class, ZM_CLASS_NAME, key, charsmax(key), len);
  if (!keyExists) {
    ThrowIllegalArgumentException(logger, "celltrie %d must contain a value for \"%s\"", class, ZM_CLASS_NAME);
    return false;
  } else if (len == 0) {
    ThrowIllegalArgumentException(logger, "celltrie %d cannot have an empty value for \"%s\"", class, ZM_CLASS_NAME);
    return false;
  }

  if (!classes) {
    classes = TrieCreate();
#if defined DEBUG_EXTENSIONS
    assert classes;
    LoggerLogDebug(logger, "Initialized classes container as celltrie %d", classes);
#endif
  }

  new Trie: oldClass;
  keyExists = TrieGetCell(classes, key, oldClass);
  zm_parseResource(key, value, charsmax(value));

  new const bool: replace = get_param(2);
  if (keyExists) {
    if (!replace) {
      ThrowIllegalArgumentException(logger, "Class named [%s] \"%s\" already exists!", key, value);
      return false;
#if defined WARN_ON_CLASS_OVERWRITE
    } else {
      LoggerLogWarning(logger, "Overwriting class [%s] \"%s\" (%d -> %d)", key, value, oldClass, class);
#endif
    }
  }
  
  TrieSetCell(classes, key, class, replace);
  
#if defined DEBUG_REGISTRATION
  new dst[2048];
  TrieToString(class, dst, charsmax(dst));
  LoggerLogDebug(logger, "Class: %s", dst);
  LoggerLogDebug(logger, "Registered class [%s] \"%s\" as Trie: %d", key, value, class);
#endif

  zm_onClassRegistered(key, class);
  return true;
}

//native Trie: zm_findClass(const name[]);
public Trie: native_findClass(plugin, numParams) {
#if defined DEBUG_NATIVES
  if (!numParamsEqual(1, numParams, logger)) {
    return Invalid_Trie;
  }
#endif

  if (!classes) {
    LoggerLogWarning(logger, "Calling zm_findClass before any classes have been registered");
    return Invalid_Trie;
  }

  new len = get_string(1, key, charsmax(key));
  key[len] = 0;

  new Trie: class;
  new bool: keyExists = TrieGetCell(classes, key, class);
  if (!keyExists) {
    return Invalid_Trie;
  }

  return class;
}

//native bool: zm_setClassProperty(const Trie: class, const key[], const value[]);
public bool: native_setClassProperty(plugin, numParams) {
#if defined DEBUG_NATIVES
  if (!numParamsEqual(3, numParams, logger)) {
    return false;
  }
#endif

  new const Trie: class = get_param(1);
  if (!class) {
    ThrowIllegalArgumentException(logger, "Invalid class specified: %d", class);
    return false;
  }

#if defined ENFORCE_REGISTERED_CLASSES_ONLY
  if (!isClassRegistered(class)) {
    ThrowIllegalArgumentException(logger, "Cannot perform operations on an unregistered class: %d", class);
    return false;
  }
#else
  if (!classes) {
    LoggerLogWarning(logger, "Calling zm_setClassProperty before any classes have been registered");
    return false;
  }
#endif

  new len;
  len = get_string(2, key, charsmax(key));
  len = get_string(3, value, charsmax(value));

  new oldValue[class_prop_value_length + 1];
  TrieGetString(class, key, oldValue, charsmax(oldValue), len);
#if defined CHECK_PROPERTY_CHANGED
  if (equal(value, oldValue)) {
    LoggerLogDebug(logger, "Value of %s unchanged in %d: \"%s\"", key, class, value);
    return false;
  }
#endif

  fwReturn = zm_onBeforeClassPropertyChanged(class, key, oldValue, value);
  if (fwReturn == PLUGIN_HANDLED) {
#if defined DEBUG_ASSIGNMENTS
    LoggerLogDebug(logger, "%d [%s] \"%s\" -> \"%s\" was rejected", class, key, oldValue, value);
#endif
    return false;
  }

#if defined DEBUG_ASSIGNMENTS
  LoggerLogDebug(logger, "Setting %d [%s] \"%s\" -> \"%s\"", class, key, oldValue, value);
#endif
  TrieSetString(class, key, value);
  if (equal(key, ZM_CLASS_NAME)) {
#if defined DEBUG_REGISTRATION
    LoggerLogDebug(logger, "Updating class table reference \"%s\" -> \"%s\"", oldValue, value);
#endif
#if defined ENFORCE_REGISTERED_CLASSES_ONLY
    TrieDeleteKey(classes, oldValue);
    TrieSetCell(classes, value, class);
#else
    if (classes) {
      TrieDeleteKey(classes, oldValue);
      TrieSetCell(classes, value, class);
    }
#endif
  }

  zm_onClassPropertyChanged(class, key, oldValue, value);
  return true;
}

//native zm_reloadClass(const Trie: class);
public native_reloadClass(plugin, numParams) {
#if defined DEBUG_NATIVES
  if (!numParamsEqual(1, numParams, logger)) {
    return;
  }
#endif

  new const Trie: class = get_param(1);
#if defined ENFORCE_REGISTERED_CLASSES_ONLY
  if (!isClassRegistered(class)) {
    ThrowIllegalArgumentException(logger, "Cannot perform operations on an unregistered class: %d", class);
    return;
  }
#endif

  new Snapshot: keySet = TrieSnapshotCreate(class);
  new const count = TrieSnapshotLength(keySet);
  for (new i = 0, len; i < count; i++) {
    len = TrieSnapshotGetKey(keySet, i, key, charsmax(key));
    TrieGetString(class, key, value, charsmax(value), len);

#if defined DEBUG_ASSIGNMENTS
    LoggerLogDebug(logger, "Loading %d [%s] = \"%s\"", class, key, value);
#endif
    zm_onClassPropertyChanged(class, key, "", value);
  }

  TrieSnapshotDestroy(keySet);
}

//native bool: zm_isClassRegistered(const Trie: class);
public bool: native_isClassRegistered(plugin, numParams) {
#if defined DEBUG_NATIVES
  if (!numParamsEqual(1, numParams, logger)) {
    return false;
  }
#endif

  new const Trie: class = get_param(1);
  return isClassRegistered(class);
}

//native zm_getNumClasses();
public native_getNumClasses(plugin, numParams) {
#if defined DEBUG_NATIVES
  if (!numParamsEqual(0, numParams, logger)) {
    return 0;
  }
#endif

  if (!classes) {
    return 0;
  }

  return TrieGetSize(classes);
}

//native Array: zm_getClasses(const Array: dst = Invalid_Array);
public Array: native_getClasses(plugin, numParams) {
#if defined DEBUG_NATIVES
  if (!numParamsEqual(1, numParams, logger)) {
    return Invalid_Array;
  }
#endif

  new Array: dst = get_param(1);
  if (dst) {
#if defined DEBUG_GET_CLASSES
    LoggerLogDebug(logger, "clearing input cellarray %d", dst);
#endif
    ArrayClear(dst);
  } else {
    dst = ArrayCreate();
#if defined DEBUG_GET_CLASSES
    LoggerLogDebug(logger, "dst cellarray initialized as cellarray %d", dst);
#endif
  }
  
  if (!classes) {
    return dst;
  }

  new Snapshot: keySet = TrieSnapshotCreate(classes);
  new const count = TrieSnapshotLength(keySet);
  for (new i = 0, Trie: class; i < count; i++) {
    TrieSnapshotGetKey(keySet, i, key, charsmax(key));
    TrieGetCell(classes, key, class);
    ArrayPushCell(dst, class);
#if defined DEBUG_GET_CLASSES
    LoggerLogDebug(logger, "dst[%d]=%d:[%s]", i, class, key);
#endif
  }

  TrieSnapshotDestroy(keySet);
  return dst;
}

//native Trie: zm_getUserClass(const id);
public Trie: native_getUserClass(plugin, numParams) {
#if defined DEBUG_NATIVES
  if (!numParamsEqual(1, numParams, logger)) {
    return Invalid_Trie;
  }
#endif

  new const id = get_param(1);
  if (!isValidId(id)) {
    ThrowIllegalArgumentException(logger, "Invalid player id specified: %d", id);
    return Invalid_Trie;
  }

  return pClass[id];
}

//native Trie: zm_setUserClass(const id, const Trie: class);
public Trie: native_setUserClass(plugin, numParams) {
#if defined DEBUG_NATIVES
  if (!numParamsEqual(4, numParams, logger)) {
    return Invalid_Trie;
  }
#endif

  new const id = get_param(1);
  if (!isValidId(id)) {
    ThrowIllegalArgumentException(logger, "Invalid player id specified: %d", id);
    return Invalid_Trie;
  }

  new const Trie: class = get_param(2);
  if (!class) {
    ThrowIllegalArgumentException(logger, "Invalid class specified: %d", class);
    return Invalid_Trie;
  }

#if defined ENFORCE_REGISTERED_CLASSES_ONLY
  if (!isClassRegistered(class)) {
    ThrowIllegalArgumentException(logger, "Cannot assign player to an unregistered class: %d", class);
    return Invalid_Trie;
  }
#endif

  new const bool: immediate = bool:(get_param(3));
  new const Trie: oldClass = immediate ? pClass[id] : pNextClass[id];
  if (class == oldClass) {
#if defined DEBUG_CLASS_CHANGES
    LoggerLogDebug(logger, "%s unchanged for %N, ignoring", immediate ? "class" : "next class", id);
#endif
    return oldClass;
  }

#define newClassName key
  zm_getClassProperty(class, ZM_CLASS_NAME, newClassName, charsmax(newClassName));
  
#if defined DEBUG_FORWARDS || defined DEBUG_CLASS_CHANGES
  new oldClassName[32];
  if (oldClass) {
    zm_getClassProperty(oldClass, ZM_CLASS_NAME, oldClassName, charsmax(oldClassName));
  } else {
    copy(oldClassName, charsmax(oldClassName), NULL);
  }
#endif

  new const bool: blockable = bool:(get_param(4));
  fwReturn = zm_onBeforeClassChanged(id, class, immediate, blockable);
  if (fwReturn == PLUGIN_HANDLED && blockable) {
#if defined DEBUG_CLASS_CHANGES
    LoggerLogDebug(logger, "%s change on %N from \"%s\" -> \"%s\" was rejected",
        immediate ? "class" : "next class", oldClassName, newClassName);
#endif
    return oldClass;
  }

  zm_onClassChanged(id, class, newClassName, immediate);
  if (immediate) {
    apply(id, class);
  } else {
    pNextClass[id] = class;
  }

#if defined DEBUG_CLASS_CHANGES
  LoggerLogDebug(logger, "%N changed %s from %s to %s",
      id, immediate ? "class" : "next class", oldClassName, newClassName);
#endif
  zm_onAfterClassChanged(id, class, newClassName, immediate);
#undef newClassName
  return oldClass;
}

//native zm_registerClassLoader(const callback[], const extensions[], ...);
public native_registerClassLoader(plugin, numParams) {
#if defined DEBUG_NATIVES
  if (!numParamsGreaterEqual(2, numParams, logger)) {
    return;
  }
#endif

  new callback[32];
  get_string(1, callback, charsmax(callback));
  new const onLoadClass = CreateOneForward(plugin, callback, FP_STRING, FP_STRING);
  if (!onLoadClass) {
    ThrowIllegalArgumentException(logger, "Cannot register class loader without \"%s\" function", callback);
    return;
  }

  if (!classLoaders) {
    classLoaders = TrieCreate();
#if defined DEBUG_LOADERS
    assert classLoaders;
    LoggerLogDebug(logger, "Initialized classLoaders container as celltrie %d", classLoaders);
#endif
  }

#if defined DEBUG_LOADERS
  if (!classLoaderPlugins) {
    classLoaderPlugins = TrieCreate();
  }
#endif

  new extension[32];
  for (new param = 2; param <= numParams; param++) {
    get_string(param, extension, charsmax(extension));
    if (isStringEmpty(extension)) {
      LoggerLogWarning(logger, "Cannot associate empty extension with a class loader");
      continue;
    }

#if defined WARN_ON_EXTENSION_OVERWRITE
    new bool: keyExists = TrieKeyExists(classLoaders, extension);
    if (keyExists) {
      LoggerLogWarning(logger, "Overwriting existing class loader for extension \"%s\"", extension);
    }
#endif
#if defined DEBUG_LOADERS
    new name[32];
    get_plugin(plugin, .filename = name, .len1 = charsmax(name));
    name[strlen(name) - 5] = EOS;
    LoggerLogDebug(logger, "Associating extension \"%s\" with %s::%s", extension, name, callback);
#endif
    TrieSetCell(classLoaders, extension, onLoadClass);
#if defined DEBUG_LOADERS
    TrieSetCell(classLoaderPlugins, extension, plugin);
#endif
  }
}

//native zm_loadClass(const path[], const bool: recursive = false);
public native_loadClass(plugin, numParams) {
#if defined DEBUG_NATIVES
  if (!numParamsEqual(2, numParams, logger)) {
    return;
  }
#endif

  if (!classLoaders) {
    LoggerLogWarning(logger, "Cannot load classes, no class loaders have been registered!");
    return;
  }

  new relativePath[256];
  get_string(1, relativePath, charsmax(relativePath));

  new path[256];
  zm_getConfigsDir(path, charsmax(path));
  new len = BuildPath(path, charsmax(path), path, relativePath);

  if (file_exists(path)) {
    loadClass(path, len);
  } else {
    new bool: recursive = get_param(2);  
    loadClasses(path, recursive);
  }
}
