#include <amxmodx>
#include <logger>

#include "include/classloader/classloader.inc"

#include "include/stocks/param_stocks.inc"
#include "include/stocks/path_stocks.inc"
#include "include/stocks/string_utils.inc"

#include "include/zm/zombies.inc"

#if defined ZM_COMPILE_FOR_DEBUG
  #define DEBUG_NATIVES
  #define DEBUG_FORWARDS
#else
  //#define DEBUG_NATIVES
  //#define DEBUG_FORWARDS
#endif

#define EXTENSION_NAME "Class Loader"
#define VERSION_STRING "1.0.0"

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
      .desc = "Loads serialized classes from file system");

  new path[PLATFORM_MAX_PATH], len;
  len = zm_getConfigsDir(path, charsmax(path));
  resolvePath(path, charsmax(path), len, "classes");
  cl_loadClasses(path, true);
}

stock getBuildId(buildId[], len) {
  return formatex(buildId, len, "%s [%s]", VERSION_STRING, __DATE__);
}
