#include <logger>
#include <fakemeta>
#include <regex>

#include "include/commands/commands.inc"

#include "include/stocks/string_stocks.inc"

#include "include/zm/zombies.inc"

#if defined ZM_COMPILE_FOR_DEBUG
  //#define DEBUG_VERSION
#else
  //#define DEBUG_VERSION
#endif

#define EXTENSION_NAME "Version"
#define VERSION_STRING "1.0.0"

#define CHECK_VERSION

static Logger: logger = Invalid_Logger;
#pragma unused logger

static gameDescription[32];

public zm_onInitExtension() {
  new name[32];
  formatex(name, charsmax(name), "[%L] %s", LANG_SERVER, ZM_NAME_SHORT, EXTENSION_NAME);

  new buildId[32];
  getBuildId(buildId, charsmax(buildId));
  register_plugin(name, VERSION_STRING, "Tirant");
  zm_registerExtension(
      .name = EXTENSION_NAME,
      .version = buildId,
      .desc = "Sets the game description string");

  logger = zm_getLogger();
  
  configureModName();
  register_forward(FM_GetGameDescription, "onGetGameDescription");

  new desc[256];
  formatex(desc, charsmax(desc), "The version of %L used", LANG_PLAYER, ZM_NAME);
  cmd_registerCommand(
      .alias = "version",
      .handle = "onPrintVersion",
      .desc = desc);

#if defined CHECK_VERSION
  LoggerLogInfo(logger, "Checking for updates...");

  new version[32];
  new const latestVersion = zm_getLatestVersion();
  if (latestVersion > zm_getVersionId()) {
    LoggerLogInfo(logger, "A new version of ZM is available: %s", version);
  } else {
    LoggerLogInfo(logger, "You have the latest verion of ZM installed");
  }
#endif
}

stock getBuildId(buildId[], len) {
  return formatex(buildId, len, "%s [%s]", VERSION_STRING, __DATE__);
}

configureModName() {
  assert isStringEmpty(gameDescription);
#if defined DEBUG_VERSION
  LoggerLogDebug(logger, "Configuring mod name (FM_GetGameDescription)");
#endif

  new const maxLen = charsmax(gameDescription);
  new len = formatex(gameDescription, maxLen, "%L ", LANG_SERVER, ZM_NAME);

  new Regex: regex = regex_match(ZM_VERSION_STRING, "^\\d+\\.\\d+");
  regex_substr(regex, 0, gameDescription[len], maxLen - len);
  regex_free(regex);
#if defined DEBUG_VERSION
  LoggerLogDebug(logger, "Mod name set to \"%s\"", gameDescription);
#endif
}

public onGetGameDescription() {
  forward_return(FMV_STRING, gameDescription);
  return FMRES_SUPERCEDE;
}

public onPrintVersion(id) {
  new buildId[32];
  zm_getBuildId(buildId, charsmax(buildId));
  zm_printColor(id, "%L (%L) v%s", id, ZM_NAME, id, ZM_NAME_SHORT, buildId);
  return PLUGIN_HANDLED;
}
