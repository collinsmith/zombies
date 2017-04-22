/**
 * Yet Another Zombie Mod
 */

#include <amxmodx>
#include <logger>

#include "include/stocks/exception_stocks.inc"
#include "include/stocks/param_stocks.inc"

#include "include/zm/extension_t.inc"
#include "include/zm/zm_cfg.inc"
#include "include/zm/zm_debug.inc"
#include "include/zm/zm_i18n.inc"
#include "include/zm/zm_misc.inc"
#include "include/zm/zm_version.inc"

#if defined ZM_COMPILE_FOR_DEBUG
  //#define DEBUG_CFG
  //#define DEBUG_FORWARDS
  //#define DEBUG_NATIVES
  //#define DEBUG_EXTENSIONS
#else
  //#define DEBUG_CFG
  //#define DEBUG_FORWARDS
  //#define DEBUG_NATIVES
  //#define DEBUG_EXTENSIONS
#endif

/** Throws an error if trying to register extensions before onInitExtension */
#define ENFORCE_REGISTRATION_AFTER_INIT
/** The initial number of extensions to allocate */
#define INITIAL_EXTENSIONS_SIZE 16

static fwReturn = 0;
static onPrecache = INVALID_HANDLE;
static onInit = INVALID_HANDLE;
static onInitExtension = INVALID_HANDLE;
static onExtensionRegistered = INVALID_HANDLE;

static Array: extensions, numExtensions;

stock ZM_Extension: indexToExtension(value) return ZM_Extension:(value + 1);
stock extensionToIndex(ZM_Extension: extension) return any:(extension) - 1;
stock ZM_Extension: operator=(value) return ZM_Extension:(value);
stock bool: operator==(ZM_Extension: extension, other) return any:(extension) == other;
stock bool: operator!=(ZM_Extension: extension, other) return any:(extension) != other;
stock bool: operator< (ZM_Extension: extension, other) return any:(extension) <  other;
stock bool: operator<=(ZM_Extension: extension, other) return any:(extension) <= other;
stock bool: operator> (ZM_Extension: extension, other) return any:(extension) >  other;
stock bool: operator>=(ZM_Extension: extension, other) return any:(extension) >= other;

public plugin_natives() {
  register_library("zombies");

  register_native("zm_registerExtension", "native_registerExtension");
  register_native("zm_getNumExtensions", "native_getNumExtensions");
  register_native("zm_getExtension", "native_getExtension");
  register_native("zm_findExtension", "native_findExtension");
  register_native("zm_getLogger", "native_getLogger");
}

public plugin_precache() {
  register_plugin(ZM_MOD_NAME, ZM_VERSION_STRING, "Tirant");

  new buildId[32];
  zm_getBuildId(buildId, charsmax(buildId));

  new desc[256];
  formatex(desc, charsmax(desc), "The version of %s used", ZM_MOD_NAME);
  create_cvar("zm_version", buildId, FCVAR_SPONLY, desc);

#if defined ZM_COMPILE_FOR_DEBUG
  LoggerSetVerbosity(This_Logger, Severity_Lowest);
#endif

  LoggerLogInfo("Launching %s v%s...", ZM_MOD_NAME, buildId);
  LoggerLogInfo("Copyright (C) Collin \"Tirant\" Smith");

  new dictionary[32];
  zm_getDictionary(dictionary, charsmax(dictionary));
  register_dictionary(dictionary);
#if defined DEBUG_I18N
  LoggerLogDebug("Registered dictionary \"%s\"", dictionary);
#endif

#if defined DEBUG_CFG
  new temp[256];
  zm_getDictionary(temp, charsmax(temp));
  LoggerLogDebug("ZOMBIES_DICTIONARY=%s", temp);
  zm_getConfigsDir(temp, charsmax(temp));
  LoggerLogDebug("ZM_CONFIGS_DIR=%s", temp);
  zm_getConfigsFile(temp, charsmax(temp));
  LoggerLogDebug("ZM_CFG_FILE=%s", temp);
#endif

#if defined DEBUG_COMMANDS
  LoggerLogDebug("Registering console commands...");
#endif
  registerConCmds();

  zm_onPrecache();
}

public plugin_init() {
  zm_onInit();
  zm_onInitExtension();
}

public plugin_cfg() {
  new cfg[256];
  zm_getConfigsFile(cfg, charsmax(cfg));
  LoggerLogDebug("Executing %s", cfg);
  server_cmd("exec %s", cfg);
}

registerConCmds() {
  zm_registerConCmd(
      .command = "version",
      .callback = "onPrintVersion",
      .desc = "Prints the version info of ZM",
      .access = ADMIN_ALL);

  zm_registerConCmd(
      .command = "exts,extensions",
      .callback = "onPrintExtensions",
      .desc = "Lists the registered extensions of ZM");
}

zm_onPrecache() {
#if defined DEBUG_FORWARDS
  assert onPrecache == INVALID_HANDLE;
  LoggerLogDebug("Creating forward for zm_onPrecache");
#endif
  onPrecache = CreateMultiForward("zm_onPrecache", ET_CONTINUE);
#if defined DEBUG_FORWARDS
  LoggerLogDebug("onPrecache = %d", onPrecache);
  LoggerLogDebug("Forwarding zm_onPrecache");
#endif
  ExecuteForward(onPrecache, fwReturn);
  DestroyForward(onPrecache);
}

zm_onInit() {
#if defined DEBUG_FORWARDS
  assert onInit == INVALID_HANDLE;
  LoggerLogDebug("Creating forward for zm_onInit");
#endif
  onInit = CreateMultiForward("zm_onInit", ET_CONTINUE);
#if defined DEBUG_FORWARDS
  LoggerLogDebug("onInit = %d", onInit);
  LoggerLogDebug("Forwarding zm_onInit");
#endif
  ExecuteForward(onInit, fwReturn);
  DestroyForward(onInit);
}

zm_onInitExtension() {
#if defined DEBUG_FORWARDS
  assert onInitExtension == INVALID_HANDLE;
  LoggerLogDebug("Creating forward for zm_onInitExtension");
#endif
  onInitExtension = CreateMultiForward("zm_onInitExtension", ET_CONTINUE);
#if defined DEBUG_FORWARDS
  LoggerLogDebug("onInitExtension = %d", onInitExtension);
  LoggerLogDebug("Forwarding zm_onInitExtension");
#endif
  ExecuteForward(onInitExtension, fwReturn);
  DestroyForward(onInitExtension);
}

zm_onExtensionRegistered(ZM_Extension: extension, data[extension_t]) {
  if (onExtensionRegistered == INVALID_HANDLE) {
#if defined DEBUG_FORWARDS
    LoggerLogDebug("Creating forward for zm_onExtensionRegistered");
#endif
    onExtensionRegistered = CreateMultiForward(
        "zm_onExtensionRegistered", ET_CONTINUE,
        FP_CELL, FP_STRING, FP_STRING, FP_STRING);
#if defined DEBUG_FORWARDS
    LoggerLogDebug("onExtensionRegistered = %d", onExtensionRegistered);
#endif
  }

#if defined DEBUG_FORWARDS
  LoggerLogDebug("Forwarding zm_onExtensionRegistered for %s", data[ext_Name]);
#endif
  ExecuteForward(onExtensionRegistered, fwReturn,
      extension, data[ext_Name], data[ext_Version], data[ext_Desc]);
}

ZM_Extension: registerExtension(data[extension_t]) {
#if defined DEBUG_EXTENSIONS
  assert extensions;
#endif
  new const ZM_Extension: extension = indexToExtension(ArrayPushArray(extensions, data));
  numExtensions++;
#if defined DEBUG_EXTENSIONS
  assert extension == numExtensions;
  LoggerLogDebug("Registered extension \"%s\" as index %d", data[ext_Name], extension);
#endif
  return extension;
}

/*******************************************************************************
 * Console Commands
 ******************************************************************************/

public onPrintVersion(id) {
  new buildId[32];
  zm_getBuildId(buildId, charsmax(buildId));
  console_print(id, "%L (%L) v%s", id, ZM_NAME, id, ZM_NAME_SHORT, buildId);
  return PLUGIN_HANDLED;
}

public onPrintExtensions(id) {
  console_print(id, "Extensions registered:");
  if (extensions) {
    new extension[extension_t];
    new maxName, maxVersion;
    for (new i = 0; i < numExtensions; i++) {
      ArrayGetArray(extensions, i, extension);
      maxName = max(maxName, strlen(extension[ext_Name]));
      maxVersion = max(maxVersion, strlen(extension[ext_Version]));
    }
    
    new fmt[32];
    formatex(fmt, charsmax(fmt), "%%2d. %%%ds %%%ds %%s", maxName, maxVersion);

    for (new i = 0; i < numExtensions; i++) {
      ArrayGetArray(extensions, i, extension);
      new status[16];
      get_plugin(
          .index = extension[ext_PluginId],
          .status = status,
          .len5 = charsmax(status));
      console_print(id, fmt, i + 1, extension[ext_Name], extension[ext_Version], status);
    }
  }

  console_print(id, "%d extensions registered.", numExtensions);
  return PLUGIN_HANDLED;
}

/*******************************************************************************
 * Natives
 ******************************************************************************/

//native Logger: zm_getLogger();
public Logger: native_getLogger(plugin, numParams) {
#if defined DEBUG_NATIVES
  if (!numParamsEqual(0, numParams)) {
    return Invalid_Logger;
  }
#endif

  return LoggerGetThis();
}

//native ZM_Extension: zm_registerExtension(const name[] = "",
//                                          const version[] = "",
//                                          const desc[] = "");
public ZM_Extension: native_registerExtension(plugin, numParams) {
#if defined DEBUG_NATIVES
  if (!numParamsEqual(3, numParams)) {
    return Invalid_Extension;
  }
#endif

#if defined ENFORCE_REGISTRATION_AFTER_INIT
  if (!onInitExtension) {
    ThrowIllegalStateException(This_Logger, "Cannot register extensions outside of zm_onInitExtension");
    return Invalid_Extension;
  }
#endif

  if (!extensions) {
    extensions = ArrayCreate(extension_t, INITIAL_EXTENSIONS_SIZE);
    numExtensions = 0;
#if defined DEBUG_EXTENSIONS
    assert extensions;
    LoggerLogDebug("Initialized extensions container as cellarray %d", extensions);
#endif
  }

  new data[extension_t];
  data[ext_PluginId] = plugin;
  get_string(1, data[ext_Name], ext_Name_length);
  if (isStringEmpty(data[ext_Name])) {
    get_plugin(.index = plugin, .filename = data[ext_Name], .len1 = ext_Name_length);
    data[ext_Name][strlen(data[ext_Name])-5] = EOS;
#if defined DEBUG_EXTENSIONS
    LoggerLogDebug("Empty extension name specified, using \"%s\" instead", data[ext_Name]);
#endif
  }

  get_string(2, data[ext_Version], ext_Version_length);
  get_string(3, data[ext_Desc], ext_Desc_length);

  new const ZM_Extension: extension = registerExtension(data);
  zm_onExtensionRegistered(extension, data);
  return extension;
}

//native bool: zm_getExtension(ZM_Extension: extension, data[extension_t]);
public bool: native_getExtension(plugin, numParams) {
#if defined DEBUG_NATIVES
  if (!numParamsEqual(2, numParams)) {
    return false;
  }
#endif

  new const ZM_Extension: extension = get_param(1);
  if (extension == Invalid_Extension) {
    LoggerLogError("Invalid extension specified: Invalid_Extension");
    return false;
  } else if (extension > numExtensions) {
    LoggerLogError("Invalid extension specified: %d", extension);
    return false;
  }

#if defined DEBUG_EXTENSIONS
  assert extensions;
#endif
  new data[extension_t];
  ArrayGetArray(extensions, extensionToIndex(extension), data);
  return true;
}

//native zm_getNumExtensions();
public native_getNumExtensions(plugin, numParams) {
#if defined DEBUG_NATIVES
  if (!numParamsEqual(0, numParams)) {
    return 0;
  }
#endif

  return numExtensions;
}

//native ZM_Extension: zm_findExtension(const name[]);
public ZM_Extension: native_findExtension(plugin, numParams) {
#if defined DEBUG_NATIVES
  if (!numParamsEqual(1, numParams)) {
    return Invalid_Extension;
  }
#endif

  if (!extensions) {
    return Invalid_Extension;
  }
  
  new name[ext_Name_length + 1];
  get_string(1, name, ext_Name_length);

  new data[extension_t];
  for (new i = 0; i < numExtensions; i++) {
    ArrayGetArray(extensions, i, data);
    if (equali(name, data[ext_Name])) {
      return indexToExtension(i);
    }
  }

  return Invalid_Extension;
}
