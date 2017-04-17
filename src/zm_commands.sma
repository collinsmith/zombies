#include <amxmodx>
#include <amxmisc>
#include <logger>

#include "include/stocks/path_stocks.inc"

#include "include/zm/zombies.inc"

#define EXTENSION_NAME "Command Manager"
#define VERSION_STRING "1.0.0"

#define COMMANDS_DICTIONARY "zm_commands.txt"

public zm_onInitExtension() {
  new name[32];
  formatex(name, charsmax(name), "[%L] %s", LANG_SERVER, ZM_NAME_SHORT, EXTENSION_NAME);

  new buildId[32];
  getBuildId(buildId, charsmax(buildId));
  register_plugin(name, buildId, "Tirant");
  zm_registerExtension(
      .name = EXTENSION_NAME,
      .version = buildId,
      .desc = "Manages custom commands");

  register_dictionary(COMMANDS_DICTIONARY);
#if defined DEBUG_I18N
  new const Logger: logger = zm_getLogger();
  LoggerLogDebug(logger, "Registering dictionary file \"%s\"", COMMANDS_DICTIONARY);
#endif
}

stock getBuildId(buildId[], len) {
  return formatex(buildId, len, "%s [%s]", VERSION_STRING, __DATE__);
}
