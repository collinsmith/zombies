#include <amxmodx>
#include <amxmisc>
#include <logger>

#include "include/stocks/path_stocks.inc"

#include "include/zm/zombies.inc"

#define EXTENSION_NAME "Command Manager"
#define VERSION_STRING "1.0.0"

#define COMMANDS_DICTIONARY "zm_commands.txt"

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
      .desc = "Manages custom commands");

  register_dictionary(COMMANDS_DICTIONARY);
#if defined DEBUG_I18N
  logd("Registering dictionary file \"%s\"", COMMANDS_DICTIONARY);
#endif
}

stock getBuildId(buildId[], len) {
  return formatex(buildId, len, "%s [%s]", VERSION_STRING, __DATE__);
}
