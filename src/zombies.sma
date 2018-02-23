/**
 * Yet Another Zombie Mod
 */

#include <amxmodx>
#include <logger>

#include "include/stocks/debug_stocks.inc"
#include "include/stocks/exception_stocks.inc"
#include "include/stocks/param_stocks.inc"
#include "include/stocks/simple_logger_stocks.inc"

#include "include/zm/extension_consts.inc"
#include "include/zm/zm_cfg.inc"
#include "include/zm/zm_i18n.inc"
#include "include/zm/zm_misc.inc"
#include "include/zm/zm_version.inc"

#include "include/zm_internal_utils.inc"

#if defined ZM_COMPILE_FOR_DEBUG
  #define ASSERTIONS
  #define DEBUG_NATIVES
  #define DEBUG_FORWARDS
  #define DEBUG_CFG
#else
  //#define ASSERTIONS
  //#define DEBUG_NATIVES
  //#define DEBUG_FORWARDS
  //#define DEBUG_CFG
#endif

static Trie: extensions;

public plugin_precache() {
  register_plugin(ZM_MOD_NAME, ZM_VERSION_STRING, "Tirant");
  
  new buildId[32];
  zm_getBuildId(buildId, charsmax(buildId));

  new desc[256];
  formatex(desc, charsmax(desc), "The version of %s used", ZM_MOD_NAME);
  create_cvar("zm_version", buildId, FCVAR_SPONLY, desc);

  configureLog();
  
  logi("Launching %s v%s...", ZM_MOD_NAME, buildId);
  logi("Copyright (C) Collin \"Tirant\" Smith");
  
  new dictionary[32];
  zm_getDictionary(dictionary, charsmax(dictionary));
  zm_registerDictionary(dictionary);

#if defined DEBUG_CFG
  new temp[256];
  zm_getDictionary(temp, charsmax(temp));
  logd("ZOMBIES_DICTIONARY=%s", temp);
  zm_getConfigsDir(temp, charsmax(temp));
  logd("ZM_CONFIGS_DIR=%s", temp);
  zm_getConfigsFile(temp, charsmax(temp));
  logd("ZM_CFG_FILE=%s", temp);
#endif

  assert ExecuteForwardOnce("zm_onPrecache");
}

configureLog() {
#if defined ZM_COMPILE_FOR_DEBUG
  SetGlobalLoggerVerbosity(DebugLevel);
  SetLoggerVerbosity(DebugLevel);
#endif
  
  new status[16];
  get_plugin(-1, .status = status, .len5 = charsmax(status));
  if (!equal(status, "debug")) {
    SetLoggerFormat(LogMessage, "[%5v] [%t] %s");
  }
}

public plugin_init() {
  registerConsoleCmds();
  assert ExecuteForwardOnce("zm_onInit");
  assert ExecuteForwardOnce("zm_onInitExtension");
}

registerConsoleCmds() {
  zm_registerConCmd(
      .command = "version",
      .callback = "onPrintVersion",
      .desc = fmt("Prints the version info of %s", ZM_MOD_NAME),
      .access = ADMIN_ALL);

  zm_registerConCmd(
      .command = "exts,extensions",
      .callback = "onPrintExtensions",
      .desc = fmt("Lists the registered extensions of %s", ZM_MOD_NAME));
}

public plugin_cfg() {
  new cfg[PLATFORM_MAX_PATH];
  zm_getConfigsFile(cfg, charsmax(cfg));
  logd("Executing %s", cfg);
  server_cmd("exec \"%s\"", cfg);
}

/*******************************************************************************
 * Command Callbacks
 ******************************************************************************/

public onPrintVersion(id) {
  new buildId[32];
  zm_getBuildId(buildId, charsmax(buildId));
  console_print(id, "%l (%l) v%s", ZM_NAME, ZM_NAME_SHORT, buildId);
  return PLUGIN_HANDLED;
}

public onPrintExtensions(id) {
  console_print(id, "Extensions registered:");
  
  new size = 0;
  if (extensions) {
    new len;
    new plugin;
    new filename[ZM_EXT_FILENAME_length];
    new name[ZM_EXT_NAME_length];
    new version[ZM_EXT_VERSION_length];
    new status[16];

    new Trie: extension;
    new maxFilename, maxName, maxVersion;

    new TrieIter: it;
    for (it = getExtensionsIter(); !TrieIterEnded(it); TrieIterNext(it)) {
      TrieIterGetCell(it, extension);

      TrieGetString(extension, ZM_EXT_NAME, name, charsmax(name), len);
      maxName = max(maxName, len);
      
      TrieGetString(extension, ZM_EXT_VERSION, version, charsmax(version), len);
      maxVersion = max(maxVersion, len);

      TrieGetString(extension, ZM_EXT_FILENAME, filename, charsmax(filename), len);
      maxFilename = max(maxFilename, len);
    }
    
    TrieIterDestroy(it);
    
    new headerFmt[32];
    formatex(headerFmt, charsmax(headerFmt), "%%3s %%%ds %%%ds %%%ds %%s", maxName, maxVersion, maxFilename);
    console_print(id, headerFmt, "#", "NAME", "VERSION", "FILE", "STATUS");

    new fmt[32];
    formatex(fmt, charsmax(fmt), "%%2d. %%%ds %%%ds %%%ds %%s", maxName, maxVersion, maxFilename);
    for (it = getExtensionsIter(); !TrieIterEnded(it); TrieIterNext(it), size++) {
      TrieIterGetCell(it, extension);
      TrieGetCell(extension, ZM_EXT_PLUGIN, plugin);
      TrieGetString(extension, ZM_EXT_NAME, name, charsmax(name), len);
      TrieGetString(extension, ZM_EXT_VERSION, version, charsmax(version), len);
      TrieGetString(extension, ZM_EXT_FILENAME, filename, charsmax(filename), len);
      get_plugin(plugin, .status = status, .len5 = charsmax(status));
      console_print(id, fmt, size + 1, name, version, filename, status);
    }
    
    TrieIterDestroy(it);
  }

  console_print(id, "%d extensions registered.", size);
  return PLUGIN_HANDLED;
}

/*******************************************************************************
 * Mutators
 ******************************************************************************/

registerExtension(const Trie: extension) {
#if defined ASSERTIONS
  assert extension;
#endif
  if (!extensions) {
    extensions = TrieCreate();
  }

  new filename[32];
  TrieGetString(extension, ZM_EXT_FILENAME, filename, charsmax(filename));
  if (!TrieSetCell(extensions, filename, extension, false)) {
    ThrowIllegalArgumentException("Extension already registered: %s", filename);
    return;
  }
  
#if defined DEBUG_NATIVES
  new name[32];
  TrieGetString(extension, ZM_EXT_NAME, name, charsmax(name));
  logd("Registered extension \"%s\"", name);
#endif
  zm_onExtensionRegistered(extension, filename);
}

TrieIter: getExtensionsIter() {
  return extensions
      ? TrieIterCreate(extensions)
      : TrieIterCreate(extensions = TrieCreate());
}

getNumExtensions() {
  return extensions ? TrieGetSize(extensions) : 0;
}

Trie: findExtension(const filename[]) {
  if (!extensions) {
    return Invalid_Trie;
  }

  new Trie: extension;
  if (TrieGetCell(extensions, filename, extension)) {
    return extension;
  }
  
  return Invalid_Trie;
}

Trie: findExtensionById(const plugin) {
  new filename[ZM_EXT_FILENAME_length];
  get_plugin(plugin, .filename = filename, .len1 = charsmax(filename));
  return findExtension(filename);
}

bool: isValidExtension(const Trie: extension) {
  if (extension <= Invalid_Trie) {
    return false;
  }
  
  new filename[ZM_EXT_FILENAME_length];
  if (!TrieGetString(extension, ZM_EXT_FILENAME, filename, charsmax(filename))) {
    return false;
  }
  
  return findExtension(filename) > Invalid_Trie;
}

/*******************************************************************************
 * Forwards
 ******************************************************************************/

zm_onExtensionRegistered(const Trie: extension, const filename[]) {
#if defined ASSERTIONS
  assert extension;
  assert filename[0] != EOS;
#endif
#if defined DEBUG_FORWARDS
  logd("Forwarding zm_onExtensionRegistered");
#endif
  static handle = INVALID_HANDLE;
  if (handle == INVALID_HANDLE) {
    CreateMultiForward(
        "zm_onExtensionRegistered", ET_IGNORE,
        FP_CELL, FP_STRING);
  }
  
  ExecuteForward(handle, _, extension, filename);
}

/*******************************************************************************
 * Natives
 ******************************************************************************/

public plugin_natives() {
  register_library("zombies");
  zm_registerNative("getPluginId");
  zm_registerNative("registerExtension");
  zm_registerNative("getExtensionsIter");
  zm_registerNative("getNumExtensions");
  zm_registerNative("findExtension");
  zm_registerNative("isValidExtension");
  zm_registerNative("findExtensionById");
}

stock Trie: operator=(const value) { return Trie:(value); }

//native zm_getPluginId();
public native_getPluginId(const plugin, const argc) {
#if defined DEBUG_NATIVES
  if (!numParamsEqual(0, argc)) {}
#endif

  static pluginId = INVALID_PLUGIN_ID;
  if (pluginId == INVALID_PLUGIN_ID) {
    pluginId = get_plugin(-1);
  }
  
  return pluginId;
}

//native Trie: zm_registerExtension(const name[] = "", const version[] = "", const desc[] = "");
public Trie: native_registerExtension(const plugin, const argc) {
#if defined DEBUG_NATIVES
  if (!numParamsEqual(3, argc)) {
    return Invalid_Trie;
  }
#endif
  
  new len;
  
  new filename[ZM_EXT_FILENAME_length];
  get_plugin(plugin, .filename = filename, .len1 = charsmax(filename));
  
  new name[ZM_EXT_NAME_length];
  len = get_string(1, name, charsmax(name));
  if (!len) {
    len = copy(name, charsmax(name), filename);
    name[len - 5] = EOS; // removes .amxx extension
#if defined DEBUG_NATIVES
    logd("Extension name empty, using \"%s\" instead", name);
#endif
  }

  new version[ZM_EXT_VERSION_length];
  get_string(2, version, charsmax(version));

  new desc[ZM_EXT_DESC_length];
  get_string(3, desc, charsmax(desc));

  new const Trie: extension = TrieCreate(); {
    TrieSetCell(extension, ZM_EXT_PLUGIN, plugin);
    TrieSetString(extension, ZM_EXT_FILENAME, filename);
    TrieSetString(extension, ZM_EXT_NAME, name);
    TrieSetString(extension, ZM_EXT_VERSION, version);
    TrieSetString(extension, ZM_EXT_DESC, desc);
#if defined DEBUG_NATIVES
    new toString[256];
    TrieToString(extension, toString, charsmax(toString));
    logd(toString);
#endif
  }

  registerExtension(extension);  
  return extension;
}

//native TrieIter: zm_getExtensionsIter();
public TrieIter: native_getExtensionsIter(const plugin, const argc) {
#if defined DEBUG_NATIVES
  if (!numParamsEqual(0, argc)) {}
#endif
  return getExtensionsIter();
}

//native zm_getNumExtensions();
public native_getNumExtensions(const plugin, const argc) {
#if defined DEBUG_NATIVES
  if (!numParamsEqual(0, argc)) {}
#endif
  return getNumExtensions();
}

//native Trie: zm_findExtension(const filename[]);
public Trie: native_findExtension(const plugin, const argc) {
#if defined DEBUG_NATIVES
  if (!numParamsEqual(1, argc)) {
    return Invalid_Trie;
  }
#endif

  new filename[ZM_EXT_FILENAME_length], len;
  len = get_string(1, filename, charsmax(filename));
  if (!len) {
    return Invalid_Trie;
  }
  
  return findExtension(filename);
}

//native bool: zm_isValidExtension(const any: extension);
public bool: native_isValidExtension(const plugin, const argc) {
#if defined DEBUG_NATIVES
  if (!numParamsEqual(1, argc)) {
    return false;
  }
#endif

  new const Trie: extension = get_param(1);
  return isValidExtension(extension);
}

//native Trie: zm_findExtensionById(const plugin);
public Trie: native_findExtensionById(const plugin, const argc) {
#if defined DEBUG_NATIVES
  if (!numParamsEqual(1, argc)) {
    return Invalid_Trie;
  }
#endif

  new pluginId = get_param(1);
  if (pluginId <= INVALID_PLUGIN_ID) {
    pluginId = plugin;
  }
  
  return findExtensionById(pluginId);
}
