#include <amxmodx>
#include <logger>

#include "include/stocks/param_stocks.inc"

#include "include/commands/commands.inc"

#include "include/zm/zombies.inc"
#include "include/zm/zm_teams.inc"

#if defined ZM_COMPILE_FOR_DEBUG
#else
#endif

#define EXTENSION_NAME "zm_cmd_swap"
#define VERSION_STRING "1.0.0"

public zm_onInit() {
#if defined ZM_COMPILE_FOR_DEBUG
  SetLoggerVerbosity(DebugLevel);
#endif
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
      .desc = "");

  cmd_registerCommand(
      .alias = "respawn",
      .handle = "onRespawn",
      .desc = "Force respawns a specified player",
      .adminFlags = ADMIN_ALL);
}

stock getBuildId(buildId[], len) {
  return formatex(buildId, len, "%s [%s]", VERSION_STRING, __DATE__);
}

public onRespawn(id, player) {
  if (player == 0) {
    player = id;
  }

  if (!isValidId(player)) {
    zm_printColor(id, "Invalid player specified: %d", player);
    return PLUGIN_HANDLED;
  }

  new bool: respawned = zm_respawn(player, true);
  if (respawned) {
    zm_printColor(id, "%L", id, "ZM_RESPAWN_SUCCESS", player);
    if (id != player) {
      zm_printColor(player, "%L", player, "ZM_RESPAWN_CLIENT");
    }
    
    logi("%N has been respawned by %N", player, id);
  } else {
    // TODO: Make output prettier
    zm_printColor(id, "%L", id, "ZM_RESPAWN_FAIL", player);
  }

  return PLUGIN_HANDLED;
}
