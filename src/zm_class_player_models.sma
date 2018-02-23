#include <amxmodx>
#include <logger>

#include "../lib/set_player_model/playermodel.inc"

#include "include/stocks/path_stocks.inc"
#include "include/stocks/precache_stocks.inc"

#include "include/zm/zombies.inc"
#include "include/zm/zm_classes.inc"

#if defined ZM_COMPILE_FOR_DEBUG
  #define DEBUG_PRECACHING
  #define DEBUG_APPLICATION
#else
  //#define DEBUG_PRECACHING
  //#define DEBUG_APPLICATION
#endif

#define EXTENSION_NAME "Class Player Models"
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
      .desc = "Applies player models for classes");
}

stock getBuildId(buildId[], len) {
  return formatex(buildId, len, "%s [%s]", VERSION_STRING, __DATE__);
}

public zm_onClassRegistered(const Trie: class, const classId[]) {
  new model[32];
  TrieGetString(class, ZM_CLASS_MODEL, model, charsmax(model));

  new path[256];
  BuildPlayerModelPath(path, charsmax(path), model);
  precacheModel(path);
}

public zm_onApply(const id) {
  new const Trie: class = zm_getUserClass(id);
  if (!class) {
#if defined DEBUG_APPLICATION
    logd("%N doesn't have a class, resetting", id);
#endif
    fm_reset_user_model(id);
    return;
  }

  static value[32];
  TrieGetString(class, ZM_CLASS_MODEL, value, charsmax(value));

#if defined DEBUG_APPLICATION
  logd("Changing player model of %N to \"%s\"", id, value);
#endif
  
  // TODO: Support custom player model indexes
  fm_set_user_model(id, value, false);
}
