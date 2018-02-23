#include <amxmodx>
#include <logger>

#include "include/stocks/param_stocks.inc"

#include "include/commands/commands.inc"

#include "include/zm/zombies.inc"
#include "include/zm/zm_teams.inc"

#if defined ZM_COMPILE_FOR_DEBUG
#else
#endif

#define EXTENSION_NAME "Swap Command"
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
      .alias = "swap",
      .handle = "onSwap",
      .desc = "Swaps a specified player's team",
      .adminFlags = ADMIN_ALL);
}

stock getBuildId(buildId[], len) {
  return formatex(buildId, len, "%s [%s]", VERSION_STRING, __DATE__);
}

public onSwap(id, player) {
  if (player == 0) {
    player = id;
  }

  if (!isValidId(player)) {
    zm_printColor(id, "Invalid player specified: %d", player);
    return PLUGIN_HANDLED;
  }

  
  new const ZM_Team: team = zm_getUserTeam(player);
  new ZM_State_Change: result;
  if (team == ZM_TEAM_ZOMBIE) {
    result = zm_cure(player, .blockable = false, .respawn = true);
  } else if (team == ZM_TEAM_HUMAN) {
    result = zm_infect(player, .blockable = false, .respawn = true);
  } else {
    // TODO: Make output prettier
    zm_printColor(id, "%l", "ZM_SWAP_FAIL", player);
    return PLUGIN_HANDLED;
  }

  if (result == ZM_STATE_CHANGE_CHANGED) {
    // TODO: Make output prettier
    zm_printColor(id, "%l", "ZM_SWAP_SUCCESS", player);
    if (id != player) {
      zm_printColor(player, "%l", "ZM_SWAP_CLIENT");
    }
    
    logi("%N has been swapped by %N", player, id);
  } else {
    // TODO: Make output prettier
    zm_printColor(id, "%l", "ZM_SWAP_FAIL", player);
  }

  return PLUGIN_HANDLED;
}
