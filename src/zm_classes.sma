/*
// TODO: Documentation
stock parseClassResource(const Trie: class, const property[], res[], len, id = LANG_SERVER) {
  TrieGetString(class, property, res, len);
  parseResourceFast(res, len, id);
}

// TODO: Documentation
stock getClassPropertyName(const Trie: class, const property[], res[], len) {
  TrieGetString(class, property, res, len);
}

// TODO: Documentation
stock bool: getClassProperty(const Trie: class, const property[], res[], len, id = LANG_SERVER) {
  new const bool: keyExists = TrieGetString(class, property, res, len);
  parseResourceFast(res, len, id);
  return keyExists;
}
*/

#include <amxmodx>
#include <logger>

#include "include/stocks/param_stocks.inc"
#include "include/stocks/debug_stocks.inc"

#include "include/zm/zombies.inc"
#include "include/zm/zm_class_consts.inc"

#include "include/zm_internal_utils.inc"

#if defined ZM_COMPILE_FOR_DEBUG
  #define ASSERTIONS
  #define DEBUG_NATIVES
  #define DEBUG_FORWARDS
#else
  //#define ASSERTIONS
  //#define DEBUG_NATIVES
  //#define DEBUG_FORWARDS
#endif

#define EXTENSION_NAME "Class Manager"
#define VERSION_STRING "1.0.0"

#define CLASSES_DICTIONARY "zm_classes.txt"

static Trie: classes;
static key[32], value[512];

static Trie: pClass[MAX_PLAYERS + 1];
static Trie: pNextClass[MAX_PLAYERS + 1];

static blockedReason[256];

public zm_onInit() {
  LoadLogger(zm_getPluginId());
}

public zm_onInitExtension() {
  new name[32];
  formatex(name, charsmax(name), "[%L] %s", LANG_SERVER, ZM_NAME_SHORT, EXTENSION_NAME);
  register_plugin(name, VERSION_STRING, "Tirant");

  new buildId[32];
  getBuildId(buildId, charsmax(buildId));
  zm_registerExtension(
      .name = EXTENSION_NAME,
      .version = buildId,
      .desc = "Manages the classes");

  zm_registerDictionary(CLASSES_DICTIONARY);
  
  registerConsoleCommands();
}

stock getBuildId(buildId[], len) {
  return formatex(buildId, len, "%s [%s]", VERSION_STRING, __DATE__);
}

registerConsoleCommands() {
#if defined ZM_COMPILE_FOR_DEBUG
  zm_registerConCmd(
      .command = "classes",
      .callback = "onPrintClasses",
      .desc = "Lists the registered classes");
#endif
}

public client_disconnected(id) {
  pClass[id] = pNextClass[id] = Invalid_Trie;
}

public zm_onApply(const id, const bool: first) {
  new const Trie: nextClass = pNextClass[id];
  if (nextClass && nextClass != pClass[id]) {
    apply(id, nextClass);
    pNextClass[id] = Invalid_Trie;
  }
}

stock TrieGetStringOrNull(const Trie: trie, const key[], value[], const len) {
  if (trie) {
    TrieGetString(trie, key, value, len);
  } else {
    copy(value, len, NULL);
  }
}

/*******************************************************************************
 * Command Callbacks
 ******************************************************************************/

#if defined ZM_COMPILE_FOR_DEBUG
public onPrintClasses(id) {
  console_print(id, "Classes:");

  new size = 0;
  if (classes) {
    new maxName, len;
    new TrieIter: it, Trie: class;
    for (it = getClassesIter(); !TrieIterEnded(it); TrieIterNext(it)) {
      len = TrieIterGetKey(it, key, charsmax(key));
      maxName = max(maxName, len);
    }
    
    TrieIterDestroy(it);

    new headerFmt[32];
    formatex(headerFmt, charsmax(headerFmt), "%%3s %%4s %%%ds %%s", maxName);
    console_print(id, headerFmt, "#", "TRIE", "ID", "NAME");

    new fmt[32];
    formatex(fmt, charsmax(fmt), "%%2d. %%-4d %%%ds %%s", maxName);
    for (it = getClassesIter(); !TrieIterEnded(it); TrieIterNext(it), size++) {
      TrieIterGetCell(it, class);
      TrieIterGetKey(it, key, charsmax(key));
      TrieGetString(class, ZM_CLASS_NAME, value, charsmax(value));
      console_print(id, fmt, size + 1, class, key, value);
    }
    
    TrieIterDestroy(it);
  }

  console_print(id, "%d classes registered.", size);
  return PLUGIN_HANDLED;
}
#endif

/*******************************************************************************
 * Mutators
 ******************************************************************************/

bool: registerClass(const Trie: class, const bool: replace = true) {
#if defined ASSERTIONS
  assert class;
  assert TrieKeyExists(class, ZM_CLASS_NAME);
#endif
  if (!classes) {
    classes = TrieCreate();
  }
  
  if (!TrieGetString(class, ZM_CLASS_ID, key, charsmax(key))) {
    TrieGetString(class, ZM_CLASS_NAME, key, charsmax(key));
    stripResourceFast(key, charsmax(key));
    TrieSetString(class, ZM_CLASS_ID, key);
  }
  
  new Trie: oldClass;
  if (TrieGetCell(classes, key, oldClass)) {
    if (!replace) {
      ThrowIllegalArgumentException("Class already exists: %s", key);
    } else {
      logw("Overwriting class %s: %d -> %d", key, oldClass, class);
    }
  }

  new parentId[sizeof key];
  if (TrieGetString(class, ZM_CLASS_PARENT, parentId, charsmax(parentId))) {
    new const Trie: parent = findClass(parentId);
    if (parent == Invalid_Trie) {
      logw("Parent could not be located: %s", parent);
    } else {
      copyInfo(class, parent);
    }
  }
  
  TrieSetCell(classes, key, class, replace);
  logd("Registered class %s", key);
  zm_onClassRegistered(class, key);
  return true;
}

copyInfo(const Trie: child, const Trie: parent) {
#if defined ASSERTIONS
  assert isValidTrie(child);
  assert isValidClass(parent);
#endif
  new classId[32];
  TrieGetString(child, ZM_CLASS_ID, classId, charsmax(classId));

  new property[32];
  new TrieIter: it;
  for (it = TrieIterCreate(parent); !TrieIterEnded(it); TrieIterNext(it)) {
    TrieIterGetKey(it, property, charsmax(property));
    if (equal(property, ZM_CLASS_ID) || equal(property, ZM_CLASS_NAME)) {
      continue;
    } else if (!TrieKeyExists(child, property)) {
      TrieGetString(parent, property, value, charsmax(value));
      assert TrieSetString(child, property, value, .replace = false);
      logd("%s %s=\"%s\"", classId, property, value);
    }
  }

  TrieIterDestroy(it);
}

TrieIter: getClassesIter() {
  return classes
      ? TrieIterCreate(classes)
      : TrieIterCreate(classes = TrieCreate());
}

getNumClasses() {
  return classes ? TrieGetSize(classes) : 0;
}

Trie: findClass(const classId[]) {
  if (!classes) {
    return Invalid_Trie;
  }

  new Trie: class;
  if (TrieGetCell(classes, classId, class)) {
    return class;
  }

  return Invalid_Trie;
}

bool: isValidClass(const Trie: class) {
  if (class <= Invalid_Trie) {
    return false;
  }

  new classId[sizeof key];
  if (!TrieGetString(class, ZM_CLASS_ID, classId, charsmax(classId))) {
    return false;
  }

  return findClass(classId) > Invalid_Trie;
}

Trie: getUserClass(const id) {
#if defined ASSERTIONS
  assert isValidId(id);
#endif
  return pClass[id];
}

Trie: setUserClass(const id, const Trie: class, const bool: immediate = true, const bool: blockable = true) {
#if defined ASSERTIONS
  assert isValidId(id);
  assert class == Invalid_Trie || isValidClass(class);
#endif
  new const Trie: oldClass = immediate ? pClass[id] : pNextClass[id];
  if (class == oldClass) {
    logd("%s unchanged for %N, ignoring", immediate ? "class" : "next class", id);
    return oldClass;
  }

  new retVal = zm_onBeforeClassChanged(id, class, immediate, blockable);
  if (blockable && retVal == PLUGIN_HANDLED) {
    parseResourceFast(blockedReason, charsmax(blockedReason), id);
    zm_onClassChangeBlocked(id, class, blockedReason);
    return oldClass;
  }
  
#define classId key
  TrieGetString(class, ZM_CLASS_ID, classId, charsmax(classId));
  zm_onClassChanged(id, class, classId, immediate);
  if (immediate) {
    apply(id, class);
  } else {
    pNextClass[id] = class;
    logd("%N next class changed to %s", id, classId);
  }

  zm_onAfterClassChanged(id, class, classId, immediate);
  return oldClass;
#undef classId
}

apply(const id, const Trie: class) {
#if defined ASSERTIONS
  assert isValidId(id);
  assert isValidClass(class);
#endif
#define classId key
  TrieGetString(class, ZM_CLASS_ID, classId, charsmax(classId));
  new const Trie: oldClass = pClass[id];
  new oldClassId[32];
  TrieGetStringOrNull(oldClass, ZM_CLASS_ID, oldClassId, charsmax(oldClassId));
  logi("%N class change %s -> %s", id, oldClassId, classId);
  pClass[id] = class;
  zm_refresh(id);
#undef classId
}

bool: setClassProperty(const Trie: class, const key[], const newValue[]) {
#if defined ASSERTIONS
  assert isValidClass(class);
  assert key[0] != EOS;
#endif
  
  new oldValue[sizeof value], len;
  new bool: keyExists = TrieGetString(class, key, oldValue, charsmax(oldValue), len);
  if (keyExists && len) {
    if (equal(key, ZM_CLASS_ID)) {
      loge("Class IDs are not allowed to change!");
      return false;
    } else if (equal(key, ZM_CLASS_PARENT)) {
      loge("Class parents are not allowed to change!");
      return false;
    } else if (equal(oldValue, newValue)) {
      return false;
    }
  }

  new retVal = zm_onBeforeClassPropertyChanged(class, key, oldValue, newValue);
  if (retVal == PLUGIN_HANDLED) {
    parseResourceFast(blockedReason, charsmax(blockedReason));
    zm_onClassPropertyChangeBlocked(class, key, newValue, blockedReason);
    return false;
  }

  new classId[32];
  TrieGetString(class, ZM_CLASS_ID, classId, charsmax(classId));
  logd("%s::%s \"%s\" -> \"%s\"", classId, key, oldValue, newValue);
  TrieSetString(class, key, newValue);
  /* Not allowed right now
  if (equal(key, ZM_CLASS_NAME)) {
    TrieDeleteKey(classes, oldValue);

    new strippedClassName[32];
    stripResource(newValue, strippedClassName, charsmax(strippedClassName));
    TrieSetCell(classes, strippedClassName, class);
  }*/

  zm_onClassPropertyChanged(class, key, oldValue, newValue);
  return true;
}

Array: getUserClasses(const id) {
#if defined ASSERTIONS
  assert isValidId(id);
#endif
  new const Array: array = ArrayCreate();
  new TrieIter: it, Trie: class;
  for (it = getClassesIter(); !TrieIterEnded(it); TrieIterNext(it)) {
    TrieIterGetCell(it, class);
    ArrayPushCell(array, class);
  }
  
  TrieIterDestroy(it);
  return array;
}

/*******************************************************************************
 * Forwards
 ******************************************************************************/

zm_onClassRegistered(const Trie: class, const classId[]) {
#if defined ASSERTIONS
  assert isValidTrie(class);
#endif
#if defined DEBUG_FORWARDS
  logd("Forwarding zm_onClassRegistered(%s, %d)", classId, class);
#endif
  static handle = INVALID_HANDLE;
  if (handle == INVALID_HANDLE) {
    handle = CreateMultiForward(
        "zm_onClassRegistered", ET_IGNORE,
        FP_CELL, FP_STRING);
  }
  
  assert ExecuteForward(handle, _, class, classId);
}

// TODO: This is not longer really applicable since zm_onIsClassEnabled
zm_onBeforeClassChanged(const id, const Trie: class, const bool: immediate, const bool: blockable) {
#if defined ASSERTIONS
  assert isValidId(id);
  assert class == Invalid_Trie || isValidClass(class);
#endif
#if defined DEBUG_FORWARDS
  new classId[32];
  TrieGetString(class, ZM_CLASS_ID, classId, charsmax(classId));
  logd("Forwarding zm_onBeforeClassChanged(%N, %s, immediate=%s, blockable=%s)",
      id, classId, immediate ? TRUE : FALSE, blockable ? TRUE : FALSE);
#endif
  static handle = INVALID_HANDLE;
  if (handle == INVALID_HANDLE) {
    handle = CreateMultiForward(
        "zm_onBeforeClassChanged", ET_STOP,
        FP_CELL, FP_CELL, FP_CELL, FP_CELL);
  }

  blockedReason[0] = EOS;
  
  new retVal;
  assert ExecuteForward(handle, retVal, id, class, immediate, blockable);
  return retVal;
}

zm_onClassChangeBlocked(const id, const Trie: class, const reason[]) {
#if defined ASSERTIONS
  assert isValidId(id);
  assert class == Invalid_Trie || isValidClass(class);
#endif
#if defined DEBUG_FORWARDS
  new classId[32];
  TrieGetString(class, ZM_CLASS_ID, classId, charsmax(classId));
  logd("Forwarding zm_onClassChangeBlocked(%N, %s, \"%s\")", id, classId, reason);
#endif
  static handle = INVALID_HANDLE;
  if (handle == INVALID_HANDLE) {
    handle = CreateMultiForward(
        "zm_onClassChangeBlocked", ET_IGNORE,
        FP_CELL, FP_CELL, FP_STRING);
  }
  
  assert ExecuteForward(handle, _, id, class, reason);
}

zm_onClassChanged(const id, const Trie: class, const classId[], const bool: immediate) {
#if defined ASSERTIONS
  assert isValidId(id);
  assert class == Invalid_Trie || isValidClass(class);
#endif
#if defined DEBUG_FORWARDS
  logd("Forwarding zm_onClassChanged(%N, %s, immediate=%s)",
      id, classId, immediate ? TRUE : FALSE);
#endif
  static handle = INVALID_HANDLE;
  if (handle == INVALID_HANDLE) {
    handle = CreateMultiForward(
        "zm_onClassChanged", ET_IGNORE,
        FP_CELL, FP_CELL, FP_STRING, FP_CELL);
  }

  assert ExecuteForward(handle, _, id, class, classId, immediate);
}

zm_onAfterClassChanged(const id, const Trie: class, const classId[], const bool: immediate) {
#if defined ASSERTIONS
  assert isValidId(id);
  assert class == Invalid_Trie || isValidClass(class);
#endif
#if defined DEBUG_FORWARDS
  logd("Forwarding zm_onAfterClassChanged(%N, %s, immediate=%s)",
      id, classId, immediate ? TRUE : FALSE);
#endif
  static handle = INVALID_HANDLE;
  if (handle == INVALID_HANDLE) {
    handle = CreateMultiForward(
        "zm_onAfterClassChanged", ET_IGNORE,
        FP_CELL, FP_CELL, FP_STRING, FP_CELL);
  }

  assert ExecuteForward(handle, _, id, class, classId, immediate);
}

zm_onBeforeClassPropertyChanged(const Trie: class, const property[],
                                const oldValue[], const newValue[]) {
#if defined ASSERTIONS
  assert isValidClass(class);
  assert property[0] != EOS;
#endif
#if defined DEBUG_FORWARDS
  new classId[32];
  TrieGetString(class, ZM_CLASS_ID, classId, charsmax(classId));
  logd("Forwarding zm_onBeforeClassPropertyChanged(%s, %s, oldValue=\"%s\", newValue=\"%s\")",
      classId, property, oldValue, newValue);
#endif
  static handle = INVALID_HANDLE;
  if (handle == INVALID_HANDLE) {
    handle = CreateMultiForward(
        "zm_onBeforeClassPropertyChanged", ET_STOP,
        FP_CELL, FP_STRING, FP_STRING, FP_STRING);
  }

  blockedReason[0] = EOS;
  
  new retVal;
  assert ExecuteForward(handle, retVal, class, property, oldValue, newValue);
  return retVal;
}

zm_onClassPropertyChangeBlocked(const Trie: class, const property[],
                                const newValue[], const reason[]) {
#if defined ASSERTIONS
  assert isValidClass(class);
#endif
#if defined DEBUG_FORWARDS
  new classId[32];
  TrieGetString(class, ZM_CLASS_ID, classId, charsmax(classId));
  logd("Forwarding zm_onClassPropertyChangeBlocked(%s, %s, newValue=\"%s\", reason=\"%s\")",
      classId, property, newValue, reason);
#endif
  static handle = INVALID_HANDLE;
  if (handle == INVALID_HANDLE) {
    handle = CreateMultiForward(
        "zm_onClassPropertyChangeBlocked", ET_IGNORE,
        FP_CELL, FP_STRING, FP_STRING, FP_STRING);
  }
  
  assert ExecuteForward(handle, _, class, property, newValue, reason);
}

zm_onClassPropertyChanged(const Trie: class, const property[],
                          const oldValue[], const newValue[]) {
#if defined ASSERTIONS
  assert isValidClass(class);
#endif
#if defined DEBUG_FORWARDS
  new classId[32];
  TrieGetString(class, ZM_CLASS_ID, classId, charsmax(classId));
  logd("Forwarding zm_onClassPropertyChanged(%s, %s, oldValue=\"%s\", newValue=\"%s\")",
      classId, property, oldValue, newValue);
#endif
  static handle = INVALID_HANDLE;
  if (handle == INVALID_HANDLE) {
    handle = CreateMultiForward(
        "zm_onClassPropertyChanged", ET_IGNORE,
        FP_CELL, FP_STRING, FP_STRING, FP_STRING);
  }

  assert ExecuteForward(handle, _, class, property, oldValue, newValue);
}

zm_onIsClassEnabled(const id, const Trie: class, const classId[]) {
#if defined ASSERTIONS
  assert isValidId(id);
  assert isValidClass(class);
#endif
#if defined DEBUG_FORWARDS
  logd("Forwarding zm_onIsClassEnabled(%N, %s)", id, classId);
#endif
  static handle = INVALID_HANDLE;
  if (handle == INVALID_HANDLE) {
    handle = CreateMultiForward(
        "zm_onIsClassEnabled", ET_STOP2,
        FP_CELL, FP_CELL, FP_STRING);
  }

  blockedReason[0] = EOS;
  
  new retVal;
  assert ExecuteForward(handle, retVal, id, class, classId);
  return retVal;
}

/*******************************************************************************
 * Natives
 ******************************************************************************/

public plugin_natives() {
  register_library("zm_classes");
  zm_registerNative("registerClass");
  zm_registerNative("getClassesIter");
  zm_registerNative("getNumClasses");
  zm_registerNative("findClass");
  zm_registerNative("isValidClass");
  zm_registerNative("setClassProperty");
  zm_registerNative("getUserClass");
  zm_registerNative("setUserClass");
  zm_registerNative("setClassBlockedReason");
  zm_registerNative("setClassPropertyBlockedReason");
  zm_registerNative("isClassEnabled");
  zm_registerNative("getUserClasses");
}

stock bool: operator=(const value) { return value > 0; }
stock Trie: operator=(const value) { return Trie:(value); }

//native bool: zm_registerClass(const Trie: class, const bool: replace = true);
public bool: native_registerClass(const plugin, const argc) {
#if defined DEBUG_NATIVES
  if (!numParamsEqual(2, argc)) {
    return false;
  }
#endif

  new const Trie: class = get_param(1);
  if (!isValidTrie(class)) {
    return false;
  }

  new bool: keyExists, len;
  keyExists = TrieGetString(class, ZM_CLASS_NAME, key, charsmax(key), len);
  if (!keyExists) {
    ThrowIllegalArgumentException("celltrie %d must contain a value for \"%s\"", class, ZM_CLASS_NAME);
    return false;
  } else if (len == 0) {
    ThrowIllegalArgumentException("celltrie %d cannot have an empty value for \"%s\"", class, ZM_CLASS_NAME);
    return false;
  }

  new const bool: replace = get_param(2);
  return registerClass(class, replace);
}

//native TrieIter: zm_getClassesIter(); 
public TrieIter: native_getClassesIter(const plugin, const argc) {
#if defined DEBUG_NATIVES
  if (!numParamsEqual(0, argc)) {}
#endif
  return getClassesIter();
}

//native zm_getNumClasses();
public native_getNumClasses(const plugin, const argc) {
#if defined DEBUG_NATIVES
  if (!numParamsEqual(0, argc)) {}
#endif
  return getNumClasses();
}

//native Trie: zm_findClass(const name[]);
public Trie: native_findClass(const plugin, const argc) {
#if defined DEBUG_NATIVES
  if (!numParamsEqual(1, argc)) {
    return Invalid_Trie;
  }
#endif

  new len = get_string(1, value, charsmax(value));
  if (!len) {
    return Invalid_Trie;
  }

  return findClass(value);
}

//native bool: zm_isValidClass(const any: class);
public bool: native_isValidClass(const plugin, const argc) {
#if defined DEBUG_NATIVES
  if (!numParamsEqual(1, argc)) {
    return false;
  }
#endif

  new const Trie: class = get_param(1);
  return isValidClass(class);
}

//native bool: zm_setClassProperty(const Trie: class, const key[], const value[]);
public bool: native_setClassProperty(const plugin, const argc) {
#if defined DEBUG_NATIVES
  if (!numParamsEqual(3, argc)) {
    return false;
  }
#endif
  
  new const Trie: class = get_param(1);
  if (!isValidClass(class)) {
    ThrowIllegalArgumentException("Invalid class specified: %d", class);
    return false;
  }

  get_string(2, key, charsmax(key));
  get_string(3, value, charsmax(value));
  return setClassProperty(class, key, value);
}

//native Trie: zm_getUserClass(const id);
public Trie: native_getUserClass(const plugin, const argc) {
#if defined DEBUG_NATIVES
  if (!numParamsEqual(1, argc)) {
    return Invalid_Trie;
  }
#endif

  new const id = get_param(1);
  if (!isValidConnected(id)) {
    return Invalid_Trie;
  }

  return getUserClass(id);
}

//native Class: zm_setUserClass(const id, const Trie: class,
//                              const bool: immediate = true,
//                              const bool: blockable = true);
public Trie: native_setUserClass(const plugin, const argc) {
#if defined DEBUG_NATIVES
  if (!numParamsEqual(4, argc)) {
    return Invalid_Trie;
  }
#endif

  new const id = get_param(1);
  if (!isValidConnected(id)) {
    return Invalid_Trie;
  }

  new const Trie: class = get_param(2);
  if (class != Invalid_Trie && !isValidClass(class)) {
    ThrowIllegalArgumentException("Invalid class specified: %d", class);
    return Invalid_Trie;
  }

  new const bool: immediate = get_param(3);
  new const bool: blockable = get_param(4);
  return setUserClass(id, class, immediate, blockable);
}

//native zm_setClassBlockedReason(const reason[]);
public native_setClassBlockedReason(const plugin, const argc) {
#if defined DEBUG_NATIVES
  if (!numParamsEqual(1, argc)) {
    return -1;
  }
#endif
  
  new const len = get_string(1, blockedReason, charsmax(blockedReason));
  blockedReason[len] = EOS;
  return len;
}

//native zm_setClassPropertyBlockedReason(const reason[]);
public native_setClassPropertyBlockedReason(const plugin, const argc) {
  return native_setClassBlockedReason(plugin, argc);
}

//native bool: zm_isClassEnabled(const id, const Trie: class);
public bool: native_isClassEnabled(const plugin, const argc) {
#if defined DEBUG_NATIVES
  if (!numParamsEqual(2, argc)) {
    return false;
  }
#endif

  new const id = get_param(1);
  if (!isValidConnected(id)) {
    return false;
  }

  new const Trie: class = get_param(2);
  if (!isValidClass(class)) {
    ThrowIllegalArgumentException("Invalid class specified: %d", class);
    return false;
  }
  
  new classId[sizeof key];
  TrieGetString(class, ZM_CLASS_ID, classId, charsmax(classId));
  return zm_onIsClassEnabled(id, class, classId) <= ITEM_ENABLED;
}

//native Array: zm_getUserClasses(const id);
public Array: native_getUserClasses(const plugin, const argc) {
#if defined DEBUG_NATIVES
  if (!numParamsEqual(1, argc)) {
    return Invalid_Array;
  }
#endif

  new const id = get_param(1);
  if (!isValidConnected(id)) {
    return Invalid_Array;
  }

  return getUserClasses(id);
}

stock bool: isValidTrie(const any: trie) {
  if (trie <= Invalid_Trie) {
    ThrowIllegalArgumentException("Invalid trie specified: %d", trie);
    return false;
  }

  return true;
}

stock bool: isValidConnected(const id) {
  if (!isValidId(id)) {
    ThrowIllegalArgumentException("Invalid player id specified: %d", id);
    return false;
  } else if (!is_user_connected(id)) {
    ThrowIllegalArgumentException("Player with id is not connected: %d", id);
    return false;
  }

  return true;
}
