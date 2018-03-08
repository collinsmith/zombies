#include <amxmodx>
#include <amxmisc>
#include <logger>
#include <reapi>

#include "include/stocks/param_stocks.inc"

#define _zm_teams_included
#include "include/zm/zombies.inc"
#include "include/zm/zm_teams_consts.inc"

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

#define EXTENSION_NAME "Team Manager"
#define VERSION_STRING "1.0.0"

#define HIDE_MENUS_ON_STATE_CHANGE

#define PFLAG_TEAM_UNASSIGNED any:(ZM_TEAM_UNASSIGNED)
#define PFLAG_TEAM_ZOMBIE     any:(ZM_TEAM_ZOMBIE)
#define PFLAG_TEAM_HUMAN      any:(ZM_TEAM_HUMAN)
#define PFLAG_TEAM_SPECTATOR  any:(ZM_TEAM_SPECTATOR)

#define PFLAG_TEAM_MASK 0x00000003
#define PFLAG_CONNECTED 0x00000004
#define PFLAG_ALIVE     0x00000008
#define PFLAG_FIRST     0x00000010

const DEFAULT_FLAGS = PFLAG_CONNECTED;

static pFlags[MAX_PLAYERS + 1];

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
      .desc = "Manages the teams");

  RegisterHookChain(RG_CBasePlayer_Spawn, "onSpawn", 1);
  RegisterHookChain(RG_CBasePlayer_Killed, "onKilled");

  new const TeamInfo = get_user_msgid("TeamInfo");
  assert register_message(TeamInfo, "onTeamInfo");

  registerConsoleCommands();
}

stock getBuildId(buildId[], len) {
  return formatex(buildId, len, "%s [%s]", VERSION_STRING, __DATE__);
}

stock registerConsoleCommands() {
#if defined ZM_COMPILE_FOR_DEBUG
  zm_registerConCmd(
      .command = "players",
      .callback = "onPrintPlayers",
      .desc = "Lists all players with their status");

  zm_registerConCmd(
      .command = "zombies",
      .callback = "onPrintZombies",
      .desc = "Lists players who are a zombie");

  zm_registerConCmd(
      .command = "humans",
      .callback = "onPrintHumans",
      .desc = "Lists players who are a human");
#endif
}

public client_connectex(id) {
  pFlags[id] = DEFAULT_FLAGS;
}

public client_disconnected(id) {
  pFlags[id] = 0;
}

public onSpawn(const id) {
  if (!is_user_alive(id)) {
    return;
  }

  pFlags[id] |= PFLAG_ALIVE;
  zm_onSpawn(id);
  refresh(id);
}

public onKilled(const id, const killer) {
#if defined HIDE_MENUS_ON_STATE_CHANGE
  hideMenu(id);
#endif
  pFlags[id] &= ~PFLAG_ALIVE;
  zm_onKilled(id, killer);
}

public onTeamInfo(const msg, const dst, const entity) {
  if (dst != MSG_BROADCAST && dst != MSG_ALL) {
    return;
  }

  new const id = get_msg_arg_int(1);

  new team[2];
  get_msg_arg_string(2, team, charsmax(team));
  switch (team[0]) {
    case 'C': cure(id, .blockable = false);
    case 'S': return;
    case 'T': infect(id, .blockable = false);
    case 'U': return;
    default: ThrowAssertionException("Unexpected value of team[0]: %c", team[0]);
  }
}

stock hideMenu(id) {
  new menu, newMenu;
  new viewingMenu = player_menu_info(id, menu, newMenu);
  if (!viewingMenu) {
    return 0;
  } else if (menu) {
    return show_menu(id, 0, "\n", 1);
  } else if (newMenu) {
    return show_menu(id, 0, "\n", 1);
  }

  return 0;
}

/*******************************************************************************
 * Console Commands
 ******************************************************************************/

#if defined ZM_COMPILE_FOR_DEBUG
public onPrintPlayers(id) {
  console_print(id, "Players:");

  new maxName;
  new name[64];

  new players[MAX_PLAYERS], num;
  get_players_ex(players, num);
  for (new i = 0, len; i < num; i++) {
    len = formatex(name, charsmax(name), "%N", players[i]);
    maxName = max(len, maxName);
  }
    
  new headerFmt[128];
  formatex(headerFmt, charsmax(headerFmt), "%%3s %%%ds %%10s %%5s", maxName);
  console_print(id, headerFmt, "ID", "NAME", "STATE", "ALIVE");

  new fmt[128];
  formatex(fmt, charsmax(fmt), "%%2d. %%%dN %%10s %%5s", maxName);
  
  new playersConnected = 0;
  for (new i = 1, flags; i <= MaxClients; i++) {
    flags = pFlags[i];
    if ((flags & PFLAG_CONNECTED) == PFLAG_CONNECTED) {
      playersConnected++;
      console_print(id, fmt, i, i,
          ZM_Team_Names[ZM_Team:(flags & PFLAG_TEAM_MASK)][8], // removes ZM_TEAM_
          (flags & PFLAG_ALIVE) == PFLAG_ALIVE ? TRUE : NULL_STRING);
    }
  }

  console_print(id, "%d players connected.", playersConnected);
  return PLUGIN_HANDLED;
}

public onPrintZombies(id) {
  console_print(id, "Zombies:");

  new maxName;
  new name[64];

  new players[MAX_PLAYERS], num;
  get_players_ex(players, num);
  for (new i = 0, len; i < num; i++) {
    len = formatex(name, charsmax(name), "%N", players[i]);
    maxName = max(len, maxName);
  }
    
  new headerFmt[128];
  formatex(headerFmt, charsmax(headerFmt), "%%3s %%%ds %%5s", maxName);
  console_print(id, headerFmt, "ID", "NAME", "ALIVE");

  new fmt[128];
  formatex(fmt, charsmax(fmt), "%%2d. %%%dN %%5s", maxName);
  
  new playersConnected = 0;
  const CONNECTED_ZOMBIE_MASK = PFLAG_TEAM_ZOMBIE | PFLAG_CONNECTED;
  for (new i = 1, flags; i <= MaxClients; i++) {
    flags = pFlags[i];
    if ((flags & CONNECTED_ZOMBIE_MASK) == CONNECTED_ZOMBIE_MASK) {
      playersConnected++;
      console_print(id, fmt, i, i,
          (flags & PFLAG_ALIVE) == PFLAG_ALIVE ? TRUE : NULL_STRING);
    }
  }

  console_print(id, "%d zombies found.", playersConnected);
  return PLUGIN_HANDLED;
}

public onPrintHumans(id) {
  console_print(id, "Humans:");

  new maxName;
  new name[64];

  new players[MAX_PLAYERS], num;
  get_players_ex(players, num);
  for (new i = 0, len; i < num; i++) {
    len = formatex(name, charsmax(name), "%N", players[i]);
    maxName = max(len, maxName);
  }
    
  new headerFmt[128];
  formatex(headerFmt, charsmax(headerFmt), "%%3s %%%ds %%5s", maxName);
  console_print(id, headerFmt, "ID", "NAME", "ALIVE");

  new fmt[128];
  formatex(fmt, charsmax(fmt), "%%2d. %%%dN %%5s", maxName);
  
  new playersConnected = 0;
  const CONNECTED_HUMAN_MASK = PFLAG_TEAM_HUMAN | PFLAG_CONNECTED;
  for (new i = 1, flags; i <= MaxClients; i++) {
    flags = pFlags[i];
    if ((flags & CONNECTED_HUMAN_MASK) == CONNECTED_HUMAN_MASK) {
      playersConnected++;
      console_print(id, fmt, i, i,
          (flags & PFLAG_ALIVE) == PFLAG_ALIVE ? TRUE : NULL_STRING);
    }
  }

  console_print(id, "%d humans found.", playersConnected);
  return PLUGIN_HANDLED;
}
#endif

/*******************************************************************************
 * Mutators
 ******************************************************************************/

ZM_Team: getUserTeam(const id) {
#if defined ASSERTIONS
  assert isValidId(id);
  assert (pFlags[id] & PFLAG_CONNECTED) == PFLAG_CONNECTED;
#endif
  return ZM_Team:(pFlags[id] & PFLAG_TEAM_MASK);
}

ZM_State_Change: infect(const id,
                        const infector = -1,
                        const bool: blockable = true,
                        const bool: forceRespawn = false) {
#if defined ASSERTIONS
  assert isValidId(id);
  assert (pFlags[id] & PFLAG_CONNECTED) == PFLAG_CONNECTED;
  assert infector == -1 || isValidId(infector);
#endif
  if ((pFlags[id] & PFLAG_TEAM_MASK) == PFLAG_TEAM_ZOMBIE) {
    return ZM_STATE_CHANGE_DID_NOT_CHANGE;
  }

  new retVal = zm_onBeforeInfected(id, infector, blockable);
  if (blockable && retVal == PLUGIN_HANDLED) {
    parseResourceFast(blockedReason, charsmax(blockedReason), id);
    zm_onInfectionBlocked(id, infector, blockedReason);
    return ZM_STATE_CHANGE_BLOCKED;
  }

#if defined HIDE_MENUS_ON_STATE_CHANGE
  hideMenu(id);
#endif

  zm_onInfected(id, infector);
  pFlags[id] = PFLAG_TEAM_ZOMBIE | (pFlags[id] & ~PFLAG_TEAM_MASK);
  pFlags[id] |= PFLAG_FIRST;
  rg_set_user_team(id, ZM_TEAM_ZOMBIE, .send_teaminfo = false);
  if ((pFlags[id] & PFLAG_ALIVE) == PFLAG_ALIVE) {
    refresh(id);
    if (forceRespawn) {
      respawn(id, true);
    }
  }
  
  zm_onAfterInfected(id, infector);
  if (isValidId(infector)) {
    logi("%N infected %N", infector, id);
  } else {
    logi("%N has been infected", id);
  }

  return ZM_STATE_CHANGE_CHANGED;
}

ZM_State_Change: cure(const id,
                      const curor = -1,
                      const bool: blockable = true,
                      const bool: forceRespawn = false) {
#if defined ASSERTIONS
  assert isValidId(id);
  assert (pFlags[id] & PFLAG_CONNECTED) == PFLAG_CONNECTED;
  assert curor == -1 || isValidId(curor);
#endif
  if ((pFlags[id] & PFLAG_TEAM_MASK) == PFLAG_TEAM_HUMAN) {
    return ZM_STATE_CHANGE_DID_NOT_CHANGE;
  }

  new retVal = zm_onBeforeCured(id, curor, blockable);
  if (blockable && retVal == PLUGIN_HANDLED) {
    parseResourceFast(blockedReason, charsmax(blockedReason), id);
    zm_onCureBlocked(id, curor, blockedReason);
    return ZM_STATE_CHANGE_BLOCKED;
  }

#if defined HIDE_MENUS_ON_STATE_CHANGE
  hideMenu(id);
#endif

  zm_onCured(id, curor);
  pFlags[id] = PFLAG_TEAM_HUMAN | (pFlags[id] & ~PFLAG_TEAM_MASK);
  pFlags[id] |= PFLAG_FIRST;
  rg_set_user_team(id, ZM_TEAM_HUMAN, .send_teaminfo = false);
  if ((pFlags[id] & PFLAG_ALIVE) == PFLAG_ALIVE) {
    refresh(id);
    if (forceRespawn) {
      respawn(id, true);
    }
  }
  
  zm_onAfterCured(id, curor);
  if (isValidId(curor)) {
    logi("%N cured %N", curor, id);
  } else {
    logi("%N has been cured", id);
  }

  return ZM_STATE_CHANGE_CHANGED;
}

bool: refresh(const id) {
#if defined ASSERTIONS
  assert isValidId(id);
#endif
  if ((pFlags[id] & PFLAG_ALIVE) != PFLAG_ALIVE) {
    return false;
  }
  
  new const bool: first = (pFlags[id] & PFLAG_FIRST) == PFLAG_FIRST;
  pFlags[id] &= ~PFLAG_FIRST;
  zm_onApply(id, first);
  zm_onAfterApply(id, first);
  return true;
}

bool: respawn(const id, const bool: force = false) {
#if defined ASSERTIONS
  assert isValidId(id);
  assert (pFlags[id] & PFLAG_CONNECTED) == PFLAG_CONNECTED;
#endif
  if ((pFlags[id] & PFLAG_ALIVE) == PFLAG_ALIVE && !force) {
    return false;
  }

  rg_round_respawn(id);
  return true;
}

/*******************************************************************************
 * Forwards
 ******************************************************************************/

zm_onSpawn(const id) {
#if defined ASSERTIONS
  assert isValidId(id);
#endif
#if defined DEBUG_FORWARDS
  logd("Forwarding zm_onSpawn(%N)", id);
#endif
  static handle = INVALID_HANDLE;
  if (handle == INVALID_HANDLE) {
    handle = CreateMultiForward(
        "zm_onSpawn", ET_IGNORE,
        FP_CELL);
  }
  
  assert ExecuteForward(handle, _, id);
}

zm_onKilled(const id, const killer) {
#if defined ASSERTIONS
  assert isValidId(id);
#endif
#if defined DEBUG_FORWARDS
  logd("Forwarding zm_onKilled(%N, %N)", id, killer);
#endif
  static handle = INVALID_HANDLE;
  if (handle == INVALID_HANDLE) {
    handle = CreateMultiForward(
        "zm_onKilled", ET_IGNORE,
        FP_CELL, FP_CELL);
  }
  
  assert ExecuteForward(handle, _, id, killer);
}

zm_onApply(const id, const bool: first) {
#if defined ASSERTIONS
  assert isValidId(id);
#endif
#if defined DEBUG_FORWARDS
  logd("Forwarding zm_onApply(%N, first=%s)", id, first ? TRUE : FALSE);
#endif
  static handle = INVALID_HANDLE;
  if (handle == INVALID_HANDLE) {
    handle = CreateMultiForward(
        "zm_onApply", ET_IGNORE,
        FP_CELL, FP_CELL);
  }
  
  assert ExecuteForward(handle, _, id, first);
}

zm_onAfterApply(const id, const bool: first) {
#if defined ASSERTIONS
  assert isValidId(id);
#endif
#if defined DEBUG_FORWARDS
  logd("Forwarding zm_onAfterApply(%N, first=%s)", id, first ? TRUE : FALSE);
#endif
  static handle = INVALID_HANDLE;
  if (handle == INVALID_HANDLE) {
    handle = CreateMultiForward(
        "zm_onAfterApply", ET_IGNORE,
        FP_CELL, FP_CELL);
  }
  
  assert ExecuteForward(handle, _, id, first);
}

zm_onBeforeInfected(const id, const infector, const bool: blockable) {
#if defined ASSERTIONS
  assert isValidId(id);
#endif
#if defined DEBUG_FORWARDS
  logd("Forwarding zm_onBeforeInfected(%N, %d, blockable=%s)",
      id, infector, blockable ? TRUE : FALSE);
#endif
  static handle = INVALID_HANDLE;
  if (handle == INVALID_HANDLE) {
    handle = CreateMultiForward(
        "zm_onBeforeInfected", ET_STOP,
        FP_CELL, FP_CELL, FP_CELL);
  }

  blockedReason[0] = EOS;
  
  new retVal;
  assert ExecuteForward(handle, retVal, id, infector, blockable);
  return retVal;
}

zm_onInfectionBlocked(const id, const infector, const reason[]) {
#if defined ASSERTIONS
  assert isValidId(id);
#endif
#if defined DEBUG_FORWARDS
  logd("Forwarding zm_onInfectionBlocked(%N, %d, \"%s\")", id, infector, reason);
#endif
  static handle = INVALID_HANDLE;
  if (handle == INVALID_HANDLE) {
    handle = CreateMultiForward(
        "zm_onInfectionBlocked", ET_IGNORE,
        FP_CELL, FP_CELL, FP_STRING);
  }
  
  assert ExecuteForward(handle, _, id, infector, reason);
}

zm_onInfected(const id, const infector) {
#if defined ASSERTIONS
  assert isValidId(id);
#endif
#if defined DEBUG_FORWARDS
  logd("Forwarding zm_onInfected(%N, %d)", id, infector);
#endif
  static handle = INVALID_HANDLE;
  if (handle == INVALID_HANDLE) {
    handle = CreateMultiForward(
        "zm_onInfected", ET_IGNORE,
        FP_CELL, FP_CELL);
  }
  
  assert ExecuteForward(handle, _, id, infector);
}

zm_onAfterInfected(const id, const infector) {
#if defined ASSERTIONS
  assert isValidId(id);
#endif
#if defined DEBUG_FORWARDS
  logd("Forwarding zm_onAfterInfected(%N, %d)", id, infector);
#endif
  static handle = INVALID_HANDLE;
  if (handle == INVALID_HANDLE) {
    handle = CreateMultiForward(
        "zm_onAfterInfected", ET_IGNORE,
        FP_CELL, FP_CELL);
  }
  
  assert ExecuteForward(handle, _, id, infector);
}

zm_onBeforeCured(const id, const curor, const bool: blockable) {
#if defined ASSERTIONS
  assert isValidId(id);
#endif
#if defined DEBUG_FORWARDS
  logd("Forwarding zm_onBeforeCured(%N, %d, blockable=%s)",
      id, curor, blockable ? TRUE : FALSE);
#endif
  static handle = INVALID_HANDLE;
  if (handle == INVALID_HANDLE) {
    handle = CreateMultiForward(
        "zm_onBeforeCured", ET_STOP,
        FP_CELL, FP_CELL, FP_CELL);
  }

  blockedReason[0] = EOS;
  
  new retVal;
  assert ExecuteForward(handle, retVal, id, curor, blockable);
  return retVal;
}

zm_onCureBlocked(const id, const curor, const reason[]) {
#if defined ASSERTIONS
  assert isValidId(id);
#endif
#if defined DEBUG_FORWARDS
  logd("Forwarding zm_onCureBlocked(%N, %d, \"%s\")", id, curor, reason);
#endif
  static handle = INVALID_HANDLE;
  if (handle == INVALID_HANDLE) {
    handle = CreateMultiForward(
        "zm_onCureBlocked", ET_IGNORE,
        FP_CELL, FP_CELL, FP_STRING);
  }
  
  assert ExecuteForward(handle, _, id, curor, reason);
}

zm_onCured(const id, const curor) {
#if defined ASSERTIONS
  assert isValidId(id);
#endif
#if defined DEBUG_FORWARDS
  logd("Forwarding zm_onCured(%N, %d)", id, curor);
#endif
  static handle = INVALID_HANDLE;
  if (handle == INVALID_HANDLE) {
    handle = CreateMultiForward(
        "zm_onCured", ET_IGNORE,
        FP_CELL, FP_CELL);
  }
  
  assert ExecuteForward(handle, _, id, curor);
}

zm_onAfterCured(const id, const curor) {
#if defined ASSERTIONS
  assert isValidId(id);
#endif
#if defined DEBUG_FORWARDS
  logd("Forwarding zm_onAfterCured(%N, %d)", id, curor);
#endif
  static handle = INVALID_HANDLE;
  if (handle == INVALID_HANDLE) {
    handle = CreateMultiForward(
        "zm_onAfterCured", ET_IGNORE,
        FP_CELL, FP_CELL);
  }
  
  assert ExecuteForward(handle, _, id, curor);
}

/*******************************************************************************
 * Natives
 ******************************************************************************/

public plugin_natives() {
  register_library("zm_teams");
  zm_registerNative("getUserTeam");
  zm_registerNative("respawn");
  zm_registerNative("refresh");
  zm_registerNative("infect");
  zm_registerNative("cure");
  zm_registerNative("setInfectionBlockedReason");
  zm_registerNative("setCureBlockedReason");
}

stock bool: operator=(value) return value > 0;

//native ZM_Team: zm_getUserTeam(const id);
public ZM_Team: native_getUserTeam(const plugin, const argc) {
#if defined DEBUG_NATIVES
  if (!numParamsEqual(1, argc)) {
    return ZM_TEAM_UNASSIGNED;
  }
#endif

  new const id = get_param(1);
  if (!isValidConnected(id)) {
    return ZM_TEAM_UNASSIGNED;
  }

  return getUserTeam(id);
}

//native bool: zm_respawn(const id, const bool: force = false);
public bool: native_respawn(plugin, argc) {
#if defined DEBUG_NATIVES
  if (!numParamsEqual(2, argc)) {
    return false;
  }
#endif

  new const id = get_param(1);
  if (!isValidConnected(id)) {
    return false;
  }

  new const bool: force = get_param(2);
  return respawn(id, force);
}

//native bool: zm_refresh(const id);
public bool: native_refresh(plugin, argc) {
#if defined DEBUG_NATIVES
  if (!numParamsEqual(1, argc)) {
    return false;
  }
#endif

  new const id = get_param(1);
  if (!isValidConnected(id)) {
    return false;
  }

  return refresh(id);
}

//native ZM_State_Change: zm_infect(const id, const infector = -1,
//                                  const bool: blockable = true,
//                                  const bool: respawn = false);
public ZM_State_Change: native_infect(const plugin, const argc) {
#if defined DEBUG_NATIVES
  if (!numParamsEqual(4, argc)) {
    return ZM_STATE_CHANGE_ERROR;
  }
#endif
  
  new const id = get_param(1);
  if (!isValidConnected(id)) {
    return ZM_STATE_CHANGE_ERROR;
  }

  new const infector = max(get_param(2), -1);
  new const bool: blockable = get_param(3);
  new const bool: respawn = get_param(4);
  return infect(id, infector, blockable, respawn);
}

//native ZM_State_Change: zm_cure(const id, const curor = -1,
//                                const bool: blockable = true,
//                                const bool: respawn = false);
public ZM_State_Change: native_cure(const plugin, const argc) {
#if defined DEBUG_NATIVES
  if (!numParamsEqual(4, argc)) {
    return ZM_STATE_CHANGE_ERROR;
  }
#endif
  
  new const id = get_param(1);
  if (!isValidConnected(id)) {
    return ZM_STATE_CHANGE_ERROR;
  }

  new const curor = max(get_param(2), -1);
  new const bool: blockable = get_param(3);
  new const bool: respawn = get_param(4);
  return cure(id, curor, blockable, respawn);
}

//native zm_setInfectionBlockedReason(const reason[]);
public native_setInfectionBlockedReason(const plugin, const argc) {
#if defined DEBUG_NATIVES
  if (!numParamsEqual(1, argc)) {
    return -1;
  }
#endif

  new const len = get_string(1, blockedReason, charsmax(blockedReason));
  blockedReason[len] = EOS;
  return len;
}

//native zm_setCureBlockedReason(const reason[]);
public native_setCureBlockedReason(const plugin, const argc) {
  return native_setInfectionBlockedReason(plugin, argc);
}

stock bool: isValidConnected(const id) {
  if (!isValidId(id)) {
    ThrowIllegalArgumentException("Invalid player id specified: %d", id);
    return false;
  } else if ((pFlags[id] & PFLAG_CONNECTED) != PFLAG_CONNECTED) {
    ThrowIllegalArgumentException("Player with id is not connected: %d", id);
    return false;
  }

  return true;
}
