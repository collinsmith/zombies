#include <amxmodx>
#include <amxmisc>
#include <logger>
#include <hamsandwich>

#define USE_TEAM_PROVIDERS
#if !defined USE_TEAM_PROVIDERS
  #include <cstrike>
#endif

#include "include/stocks/param_stocks.inc"

#include "include/zm/zm_teams_consts.inc"
#include "include/zm/zombies.inc"

#if defined ZM_COMPILE_FOR_DEBUG
  #define DEBUG_INFECTION
  #define DEBUG_RESPAWN
  #define DEBUG_NATIVES
  //#define DEBUG_FORWARDS
  #define DEBUG_APPLY
  #define DEBUG_PROVIDER
#else
  //#define DEBUG_INFECTION
  //#define DEBUG_RESPAWN
  //#define DEBUG_NATIVES
  //#define DEBUG_FORWARDS
  //#define DEBUG_APPLY
  //#define DEBUG_PROVIDER
#endif

#define EXTENSION_NAME "Team Manager"
#define VERSION_STRING "1.0.0"

#define ASSERT_PLAYER_IDs
//#define REFRESH_ON_INFECT_UNCHANGED
#define HIDE_MENUS_ON_STATE_CHANGE
//#define PRINT_DISCONNECTED_IDs

#define PFLAG_TEAM_MASK 0x00000003
#define PFLAG_CONNECTED 0x00000004
#define PFLAG_ALIVE     0x00000008

#define PFLAG_TEAM_UNASSIGNED any:(ZM_TEAM_UNASSIGNED)
#define PFLAG_TEAM_ZOMBIE     any:(ZM_TEAM_ZOMBIE)
#define PFLAG_TEAM_HUMAN      any:(ZM_TEAM_HUMAN)
#define PFLAG_TEAM_SPECTATOR  any:(ZM_TEAM_SPECTATOR)

const DEFAULT_FLAGS = PFLAG_CONNECTED;

static Logger: logger = Invalid_Logger;

static fwReturn = 0;
static onSpawn = INVALID_HANDLE;
static onKilled = INVALID_HANDLE;
static onBeforeInfected = INVALID_HANDLE;
static onInfected = INVALID_HANDLE;
static onAfterInfected = INVALID_HANDLE;
static onBeforeCured = INVALID_HANDLE;
static onCured = INVALID_HANDLE;
static onAfterCured = INVALID_HANDLE;
static onApply = INVALID_HANDLE;
#if defined USE_TEAM_PROVIDERS
static onProvideTeamChange = INVALID_HANDLE;
#if defined DEBUG_PROVIDER
static teamChangeProvider = INVALID_PLUGIN_ID;
#endif
#endif

static pFlags[MAX_PLAYERS + 1];

stock bool: operator=(value) return value > 0;

public plugin_natives() {
  register_library("zm_teams");

  register_native("zm_getUserTeam", "native_getUserTeam");

  register_native("zm_respawn", "native_respawn");

  register_native("zm_infect", "native_infect");
  register_native("zm_cure", "native_cure");

  register_native("zm_refresh", "native_refresh");

  register_native("zm_setTeamChangeProvider", "native_setTeamChangeProvider");
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
      .desc = "Manages the teams");

  logger = zm_getLogger();

  createForwards();
  registerConCmds();

  RegisterHamPlayer(Ham_Spawn, "ham_onSpawn", 1);
  RegisterHamPlayer(Ham_Killed, "ham_onKilled", 0);

  new TeamInfo = get_user_msgid("TeamInfo");
  new const teamInfoHandle = register_message(TeamInfo, "onTeamInfo");
  if (!teamInfoHandle) {
    LoggerLogWarning(logger, "register_message(TeamInfo, \"onTeamInfo\") returned 0");
  }
}

stock getBuildId(buildId[], len) {
  return formatex(buildId, len, "%s [%s]", VERSION_STRING, __DATE__);
}

registerConCmds() {
#if defined DEBUG_INFECTION
  zm_registerConCmd(
      .command = "players",
      .callback = "onPrintPlayers",
      .desc = "Lists all players with their statuses",
      .logger = logger);

  zm_registerConCmd(
      .command = "zombies",
      .callback = "onPrintZombies",
      .desc = "Lists players who are a zombie",
      .logger = logger);

  zm_registerConCmd(
      .command = "humans",
      .callback = "onPrintHumans",
      .desc = "Lists players who are a human",
      .logger = logger);
#endif

#if defined USE_TEAM_PROVIDERS
  zm_registerConCmd(
      .command = "team_provider",
      .callback = "onPrintTeamProvider",
      .desc = "Displays the current team provider",
      .logger = logger);
#endif
}

createForwards() {
  createOnSpawn();
  createOnKilled();
  createOnApply();
  createInfectedForwards();
  createCuredForwards();
}

createInfectedForwards() {
  createOnBeforeInfected();
  createOnInfected();
  createOnAfterInfected();
}

createCuredForwards() {
  createOnBeforeCured();
  createOnCured();
  createOnAfterCured();
}

createOnSpawn() {
#if defined DEBUG_FORWARDS
  assert onSpawn == INVALID_HANDLE;
  LoggerLogDebug(logger, "Creating forward for zm_onSpawn");
#endif
  onSpawn = CreateMultiForward("zm_onSpawn", ET_CONTINUE, FP_CELL);
#if defined DEBUG_FORWARDS
  LoggerLogDebug(logger, "onSpawn = %d", onSpawn);
#endif
}

createOnKilled() {
#if defined DEBUG_FORWARDS
  assert onKilled == INVALID_HANDLE;
  LoggerLogDebug(logger, "Creating forward for zm_onKilled");
#endif
  onKilled = CreateMultiForward("zm_onKilled", ET_CONTINUE, FP_CELL, FP_CELL);
#if defined DEBUG_FORWARDS
  LoggerLogDebug(logger, "onKilled = %d", onKilled);
#endif
}

createOnApply() {
#if defined DEBUG_FORWARDS
  assert onApply == INVALID_HANDLE;
  LoggerLogDebug(logger, "Creating forward for zm_onApply");
#endif
  onApply = CreateMultiForward("zm_onApply", ET_CONTINUE, FP_CELL);
#if defined DEBUG_FORWARDS
  LoggerLogDebug(logger, "onApply = %d", onApply);
#endif
}

createOnBeforeInfected() {
#if defined DEBUG_FORWARDS
  assert onBeforeInfected == INVALID_HANDLE;
  LoggerLogDebug(logger, "Creating forward for zm_onBeforeInfected");
#endif
  onBeforeInfected = CreateMultiForward("zm_onBeforeInfected", ET_STOP, FP_CELL, FP_CELL, FP_CELL);
#if defined DEBUG_FORWARDS
  LoggerLogDebug(logger, "onBeforeInfected = %d", onBeforeInfected);
#endif
}

createOnInfected() {
#if defined DEBUG_FORWARDS
  assert onInfected == INVALID_HANDLE;
  LoggerLogDebug(logger, "Creating forward for zm_onInfected");
#endif
  onInfected = CreateMultiForward("zm_onInfected", ET_CONTINUE, FP_CELL, FP_CELL);
#if defined DEBUG_FORWARDS
  LoggerLogDebug(logger, "onInfected = %d", onInfected);
#endif
}

createOnAfterInfected() {
#if defined DEBUG_FORWARDS
  assert onAfterInfected == INVALID_HANDLE;
  LoggerLogDebug(logger, "Creating forward for zm_onAfterInfected");
#endif
  onAfterInfected = CreateMultiForward("zm_onAfterInfected", ET_CONTINUE, FP_CELL, FP_CELL);
#if defined DEBUG_FORWARDS
  LoggerLogDebug(logger, "onAfterInfected = %d", onAfterInfected);
#endif
}

createOnBeforeCured() {
#if defined DEBUG_FORWARDS
  assert onBeforeCured == INVALID_HANDLE;
  LoggerLogDebug(logger, "Creating forward for zm_onBeforeCured");
#endif
  onBeforeCured = CreateMultiForward("zm_onBeforeCured", ET_STOP, FP_CELL, FP_CELL, FP_CELL);
#if defined DEBUG_FORWARDS
  LoggerLogDebug(logger, "onBeforeCured = %d", onBeforeCured);
#endif
}

createOnCured() {
#if defined DEBUG_FORWARDS
  assert onCured == INVALID_HANDLE;
  LoggerLogDebug(logger, "Creating forward for zm_onCured");
#endif
  onCured = CreateMultiForward("zm_onCured", ET_CONTINUE, FP_CELL, FP_CELL);
#if defined DEBUG_FORWARDS
  LoggerLogDebug(logger, "onCured = %d", onCured);
#endif
}

createOnAfterCured() {
#if defined DEBUG_FORWARDS
  assert onAfterCured == INVALID_HANDLE;
  LoggerLogDebug(logger, "Creating forward for zm_onAfterCured");
#endif
  onAfterCured = CreateMultiForward("zm_onAfterCured", ET_CONTINUE, FP_CELL, FP_CELL);
#if defined DEBUG_FORWARDS
  LoggerLogDebug(logger, "onAfterCured = %d", onAfterCured);
#endif
}

hideMenu(id) {
  new menu, newMenu;
  new viewingMenu = player_menu_info(id, menu, newMenu);
  if (!viewingMenu) {
    return;
  }

  if (menu) {
    show_menu(id, 0, "\n", 1);
  }
}

public client_putinserver(id) {
  pFlags[id] = DEFAULT_FLAGS;
}

public client_disconnected(id) {
  pFlags[id] = 0;
}

public ham_onSpawn(id) {
  if (!is_user_alive(id)) {
    return HAM_IGNORED;
  }

  return ham_onRoundRespawn(id);
}

public ham_onRoundRespawn(id) {
  pFlags[id] |= PFLAG_ALIVE;

  refresh(id);
#if defined DEBUG_FORWARDS
  LoggerLogDebug(logger, "Forwarding zm_onSpawn(%d) for %N", id, id);
#endif
  ExecuteForward(onSpawn, fwReturn, id);
  return HAM_HANDLED;
}

public ham_onKilled(killer, victim, shouldgib) {
#if defined HIDE_MENUS_ON_STATE_CHANGE
  hideMenu(victim);
#endif
  
  pFlags[victim] &= ~PFLAG_ALIVE;
#if defined DEBUG_FORWARDS
  LoggerLogDebug(logger, "Calling zm_onKilled(killer=%d, victim=%d) for %N", killer, victim, victim);
#endif
  ExecuteForward(onKilled, fwReturn, killer, victim);
  return HAM_HANDLED;
}

public onTeamInfo(const msgId, const msgDest, const entId) {
  if (msgDest != MSG_ALL && msgDest != MSG_BROADCAST) {
    return;
  }

  new const id = get_msg_arg_int(1);
#if defined ASSERT_PLAYER_IDs
  assert isValidId(id);
#endif

  new team[2];
  get_msg_arg_string(2, team, charsmax(team));
#if defined DEBUG_INFECT
  LoggerLogDebug(logger, "onTeamInfo(%d, \"%s\") for %N", id, team, id);
#endif
  // FIXME: This implementation will cause problems in other mods
  switch (team[0]) {
    case 'C': cure(.id = id, .blockable = false);
    case 'S': return;
    case 'T': infect(.id = id, .blockable = false);
    case 'U': return;
    default: ThrowAssertionException(logger, "Unexpected value of team[0]: %c", team[0]);
  }
}

bool: respawn(id, bool: force = false) {
#if defined ASSERT_PLAYER_IDs
  assert isValidId(id);
#endif
  if ((pFlags[id] & PFLAG_ALIVE) && !force) {
#if defined DEBUG_RESPAWN
    LoggerLogDebug(logger, "Respawn blocked for %N", id);
#endif
    return false;
  }

  // TODO: This may need to conditionally call Ham_Respawn in other mods
  ExecuteHamB(Ham_CS_RoundRespawn, id);
  return true;
}

ZM_State_Change: infect(const id, const infector = -1, const bool: blockable = true, const bool: forceRespawn = false) {
#if defined ASSERT_PLAYER_IDs
  assert isValidId(id);
  assert infector == -1 || isValidId(infector);
#endif
  
  if ((pFlags[id] & PFLAG_TEAM_MASK) == PFLAG_TEAM_ZOMBIE) {
#if defined REFRESH_ON_INFECT_UNCHANGED
    refresh(id);
#endif
    return ZM_STATE_CHANGE_DID_NOT_CHANGE;
  }

#if defined DEBUG_FORWARDS
  LoggerLogDebug(logger, "Forwarding zm_onBeforeInfected(%d, %d, blockable=%s) for %N",
      id, infector, blockable ? TRUE : FALSE, id);
#endif
  ExecuteForward(onBeforeInfected, fwReturn, id, infector, blockable);
  if (blockable && fwReturn == PLUGIN_HANDLED) {
#if defined DEBUG_INFECTION
    LoggerLogDebug(logger, "Infection blocked for %N", id);
#endif
    return ZM_STATE_CHANGE_BLOCKED;
  }

#if defined HIDE_MENUS_ON_STATE_CHANGE
  hideMenu(id);
#endif

#if defined DEBUG_FORWARDS
  LoggerLogDebug(logger, "Forwarding zm_onInfected(%d, %d) for %N", id, infector, id);
#endif
  ExecuteForward(onInfected, fwReturn, id, infector);

  pFlags[id] = PFLAG_TEAM_ZOMBIE | (pFlags[id] & ~PFLAG_TEAM_MASK);
#if defined USE_TEAM_PROVIDERS
  if (onProvideTeamChange == INVALID_HANDLE) {
    new msg[] = "Team change called without any provider set!";
    ThrowIllegalStateException(logger, msg);
    set_fail_state(msg);
    return ZM_STATE_CHANGE_DID_NOT_CHANGE;
  } else {
#if defined DEBUG_FORWARDS
    LoggerLogDebug(logger, "Forwarding to team change provider for %N", id);
#endif
    ExecuteForward(onProvideTeamChange, fwReturn, id, ZM_TEAM_ZOMBIE);
  }
#else
  cs_set_user_team(id, ZM_TEAM_ZOMBIE, _, .send_teaminfo = false);
#endif
  if (pFlags[id] & PFLAG_ALIVE) {
    refresh(id);
    if (forceRespawn) {
      respawn(id, true);
    }
  }

  #if defined DEBUG_FORWARDS
  LoggerLogDebug(logger, "Forwarding zm_onAfterInfected(%d, %d) for %N", id, infector, id);
#endif
  ExecuteForward(onAfterInfected, fwReturn, id, infector);

#if defined DEBUG_INFECTION
  if (isValidId(infector)) {
    LoggerLogDebug(logger, "%N infected %N", infector, id);
  } else {
    LoggerLogDebug(logger, "%N has been infected", id);
  }
#endif

  return ZM_STATE_CHANGE_CHANGED;
}

ZM_State_Change: cure(const id, const curor = -1, const bool: blockable = true, const bool: forceRespawn = false) {
#if defined ASSERT_PLAYER_IDs
  assert isValidId(id);
  assert curor == -1 || isValidId(curor);
#endif

  if ((pFlags[id] & PFLAG_TEAM_MASK) == PFLAG_TEAM_HUMAN) {
#if defined REFRESH_ON_INFECT_UNCHANGED
    refresh(id);
#endif
    return ZM_STATE_CHANGE_DID_NOT_CHANGE;
  }

#if defined DEBUG_FORWARDS
  LoggerLogDebug(logger, "Forwarding zm_onBeforeCured(%d, %d, blockable=%s) for %N", id, curor, blockable ? TRUE : FALSE, id);
#endif
  ExecuteForward(onBeforeCured, fwReturn, id, curor, blockable);
  if (blockable && fwReturn == PLUGIN_HANDLED) {
#if defined DEBUG_INFECTION
    LoggerLogDebug(logger, "Curing blocked for %N", id);
#endif
    return ZM_STATE_CHANGE_BLOCKED;
  }

#if defined HIDE_MENUS_ON_STATE_CHANGE
  hideMenu(id);
#endif

#if defined DEBUG_FORWARDS
  LoggerLogDebug(logger, "Forwarding zm_onCured(%d, %d) for %N", id, curor, id);
#endif
  ExecuteForward(onCured, fwReturn, id, curor);

  pFlags[id] = PFLAG_TEAM_HUMAN | (pFlags[id] & ~PFLAG_TEAM_MASK);
#if defined USE_TEAM_PROVIDERS
  if (onProvideTeamChange == INVALID_HANDLE) {
    new msg[] = "Team change required without any provider set!";
    ThrowIllegalStateException(logger, msg);
    set_fail_state(msg);
    return ZM_STATE_CHANGE_DID_NOT_CHANGE;
  } else {
#if defined DEBUG_FORWARDS
    LoggerLogDebug(logger, "Forwarding to team change provider for %N", id);
#endif
    ExecuteForward(onProvideTeamChange, fwReturn, id, ZM_TEAM_HUMAN);
  }
#else
  cs_set_user_team(id, ZM_TEAM_HUMAN, _, .send_teaminfo = false);
#endif
  if (pFlags[id] & PFLAG_ALIVE) {
    refresh(id);
    if (forceRespawn) {
      respawn(id, true);
    }
  }

#if defined DEBUG_FORWARDS
  LoggerLogDebug(logger, "Forwarding zm_onAfterCured(%d, %d) for %N", id, curor, id);
#endif
  ExecuteForward(onAfterCured, fwReturn, id, curor);

#if defined DEBUG_INFECTION
  if (isValidId(curor)) {
    LoggerLogDebug(logger, "%N cured %N", curor, id);
  } else {
    LoggerLogDebug(logger, "%N has been cured", id);
  }
#endif
  return ZM_STATE_CHANGE_CHANGED;
}

bool: refresh(const id) {
#if defined ASSERT_PLAYER_IDs
  assert isValidId(id);
  assert pFlags[id] & PFLAG_ALIVE;
#endif

#if defined DEBUG_FORWARDS || defined DEBUG_APPLY
  LoggerLogDebug(logger, "Forwarding zm_onApply(%d) for %N", id, id);
#endif
  ExecuteForward(onApply, fwReturn, id);
  return true;
}

/*******************************************************************************
 * Console Commands
 ******************************************************************************/

#if defined DEBUG_INFECTION
public onPrintPlayers(id) {
  console_print(id, "Players:");
  console_print(id, "%3s %32s %10s %5s %s", "ID", "NAME", "STATE", "ALIVE", "CONNECTED");

  new playersConnected = 0;
  for (new i = 1, flags; i <= MaxClients; i++) {
    flags = pFlags[i];
    if (flags & PFLAG_CONNECTED) {
      playersConnected++;
      console_print(id, "%2d. %32.32N %10s %5s %s", i, i,
          ZM_Team_Names[ZM_Team:(flags & PFLAG_TEAM_MASK)][8],
          (flags & PFLAG_ALIVE) ? TRUE : NULL_STRING,
          TRUE);
#if defined PRINT_DISCONNECTED_IDs
    } else {
      console_print(id, "%2d.", i);
#endif
    }
  }

  console_print(id, "%d players connected.", playersConnected);
  return PLUGIN_HANDLED;
}

public onPrintZombies(id) {
  console_print(id, "Zombies:");
  console_print(id, "%3s %32s %5s", "ID", "NAME", "ALIVE");

  new numZombies = 0;
  const CONNECTED_ZOMBIE_MASK = PFLAG_TEAM_ZOMBIE | PFLAG_CONNECTED;
  for (new i = 1, flags; i <= MaxClients; i++) {
    flags = pFlags[i];
    if ((flags & CONNECTED_ZOMBIE_MASK) == CONNECTED_ZOMBIE_MASK) {
      numZombies++;
      console_print(id, "%2d. %32.32N %5s", i, i,
          (flags & PFLAG_ALIVE) ? TRUE : NULL_STRING);
    }
  }

  console_print(id, "%d zombies found.", numZombies);
  return PLUGIN_HANDLED;
}

public onPrintHumans(id) {
  console_print(id, "Humans:");
  console_print(id, "%3s %32s %5s", "ID", "NAME", "ALIVE");

  new numHumans = 0;
  const CONNECTED_HUMAN_MASK = PFLAG_TEAM_HUMAN | PFLAG_CONNECTED;
  for (new i = 1, flags; i <= MaxClients; i++) {
    flags = pFlags[i];
    if ((flags & CONNECTED_HUMAN_MASK) == CONNECTED_HUMAN_MASK) {
      numHumans++;
      console_print(id, "%2d. %32.32N %5s", i, i,
          (flags & PFLAG_ALIVE) ? TRUE : NULL_STRING);
    }
  }

  console_print(id, "%d humans found.", numHumans);
  return PLUGIN_HANDLED;
}
#endif


#if defined USE_TEAM_PROVIDERS
public onPrintTeamProvider(id) {
  new plugin[32];
  get_plugin(teamChangeProvider, .filename = plugin, .len1 = charsmax(plugin));
  console_print(id, plugin);
  return PLUGIN_HANDLED;
}
#endif

/*******************************************************************************
 * Natives
 ******************************************************************************/

//native ZM_Team: zm_getUserTeam(const id);
public ZM_Team: native_getUserTeam(plugin, numParams) {
#if defined DEBUG_NATIVES
  if (!numParamsEqual(1, numParams, logger)) {
    return ZM_TEAM_UNASSIGNED;
  }
#endif

  new const id = get_param(1);
  if (!isValidId(id)) {
    ThrowIllegalArgumentException(logger, "Invalid player id specified: %d", id);
    return ZM_TEAM_UNASSIGNED;
  }

  return ZM_Team:(pFlags[id] & PFLAG_TEAM_MASK);
}

//native bool: zm_respawn(const id, const bool: force = false);
public bool: native_respawn(plugin, numParams) {
#if defined DEBUG_NATIVES
  if (!numParamsEqual(1, numParams, logger)) {
    return false;
  }
#endif

  new const id = get_param(1);
  if (!isValidId(id)) {
    ThrowIllegalArgumentException(logger, "Invalid player id specified: %d", id);
    return false;
  } else if (!(pFlags[id] & PFLAG_CONNECTED)) {
    ThrowIllegalArgumentException(logger, "Player with id is not connected: %d", id);
  }

  new const bool: force = get_param(2);
  return respawn(id, force);
}

//native ZM_State_Change: zm_infect(const id, const infector = -1, const bool: blockable = true,
//                                  const bool: respawn = false);
public ZM_State_Change: native_infect(plugin, numParams) {
#if defined DEBUG_NATIVES
  if (!numParamsEqual(3, numParams, logger)) {
    return ZM_STATE_CHANGE_ERROR;
  }
#endif

  new const id = get_param(1);
  if (!isValidId(id)) {
    ThrowIllegalArgumentException(logger, "Invalid player id specified: %d", id);
    return ZM_STATE_CHANGE_ERROR;
  } else if (!(pFlags[id] & PFLAG_CONNECTED)) {
    ThrowIllegalArgumentException(logger, "Player with id is not connected: %d", id);
    return ZM_STATE_CHANGE_ERROR;
  }

  new const infector = get_param(2);
  new const bool: blockable = get_param(3);
  new const bool: respawn = get_param(4);
  return infect(id, infector, blockable, respawn);
}

//native ZM_State_Change: zm_cure(const id, const curor = -1, const bool: blockable = true,
//                                const bool: respawn = false);
public ZM_State_Change: native_cure(plugin, numParams) {
#if defined DEBUG_NATIVES
  if (!numParamsEqual(3, numParams, logger)) {
    return ZM_STATE_CHANGE_ERROR;
  }
#endif

  new const id = get_param(1);
  if (!isValidId(id)) {
    ThrowIllegalArgumentException(logger, "Invalid player id specified: %d", id);
    return ZM_STATE_CHANGE_ERROR;
  } else if (!(pFlags[id] & PFLAG_CONNECTED)) {
    ThrowIllegalArgumentException(logger, "Player with id is not connected: %d", id);
    return ZM_STATE_CHANGE_ERROR;
  }

  new const curor = get_param(2);
  new const bool: blockable = get_param(3);
  new const bool: respawn = get_param(4);
  return cure(id, curor, blockable, respawn);
}

//native bool: zm_refresh(const id);
public bool: native_refresh(plugin, numParams) {
  if (!numParamsEqual(1, numParams, logger)) {
    return false;
  }

  new id = get_param(1);
  if (!isValidId(id)) {
    ThrowIllegalArgumentException(logger, "Invalid player id specified: %d", id);
    return false;
  } else if (!(pFlags[id] & PFLAG_ALIVE)) {
    ThrowIllegalArgumentException(logger, "Player with id is not alive: %d", id);
    return false;
  }

  return refresh(id);
}

//native zm_setTeamChangeProvider(const callback[]);
public native_setTeamChangeProvider(plugin, numParams) {
#if defined DEBUG_NATIVES
  if (!numParamsEqual(1, numParams, logger)) {
    return;
  }
#endif

  if (onProvideTeamChange != INVALID_HANDLE) {
    LoggerLogWarning(logger, "Overriding assigned team changer %d", onProvideTeamChange);
    DestroyForward(onProvideTeamChange);
  }

  new callback[32];
  get_string(1, callback, charsmax(callback));
  onProvideTeamChange = CreateOneForward(plugin, callback, FP_CELL, FP_CELL);
#if defined DEBUG_PROVIDER
  teamChangeProvider = plugin;
  
  new name[32];
  get_plugin(plugin, .filename = name, .len1 = charsmax(name));
  name[strlen(name) - 5] = EOS;
  LoggerLogDebug(logger, "Setting team change provider to %s::%s", name, callback);
#endif
}
