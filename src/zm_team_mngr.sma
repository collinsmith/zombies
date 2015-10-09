#define VERSION_STRING "1.0.0"
#define EXTENSION_NAME "Team Manager"
#define ZM_PLAYERS_PRINT_EMPTY

#include <amxmodx>
#include <logger>
#include <hamsandwich>

#include "include\\zm\\cs_team_changer.inc"
#include "include\\zm\\zombiemod.inc"
#include "include\\zm\\zm_team_mngr_const.inc"

#include "include\\stocks\\flag_stocks.inc"
#include "include\\stocks\\param_test_stocks.inc"
#include "include\\stocks\\dynamic_param_stocks.inc"

static Logger: g_Logger = Invalid_Logger;

enum Forwards {
    fwReturn,
    onSpawn,
    onKilled,
    onBeforeInfected, onInfected, onAfterInfected,
    onBeforeCured, onCured, onAfterCured,
    onApply
}; static g_fw[Forwards] = { 0, INVALID_HANDLE, INVALID_HANDLE, INVALID_HANDLE,
        INVALID_HANDLE, INVALID_HANDLE, INVALID_HANDLE, INVALID_HANDLE,
        INVALID_HANDLE, INVALID_HANDLE };

static g_flagConnected;
static g_flagAlive;
static g_flagZombie;

public plugin_natives() {
    register_library("zm_team_mngr");

    register_native("zm_isUserConnected", "_isUserConnected", 0);
    register_native("zm_isUserAlive", "_isUserAlive", 0);
    register_native("zm_isUserZombie", "_isUserZombie", 0);

    register_native("zm_respawn", "_respawn", 0);

    register_native("zm_infect", "_infect", 0);
    register_native("zm_cure", "_cure", 0);
}

public zm_onExtensionInit() {
    new name[32];
    formatex(name, charsmax(name),
            "[%L] %s",
            LANG_SERVER, ZM_NAME_SHORT,
            EXTENSION_NAME);
    register_plugin(name, VERSION_STRING, "Tirant");
    zm_registerExtension(
            .name = EXTENSION_NAME,
            .version = VERSION_STRING,
            .description = "Manages the teams and infection events");

    g_Logger = LoggerCreate();
#if defined ZM_COMPILE_FOR_DEBUG
    LoggerSetVerbosity(g_Logger, Severity_Lowest);
    LoggerSetVerbosity(All_Loggers, Severity_Lowest);
#endif

    registerConCmds();
    createForwards();

    RegisterHam(Ham_Spawn, "player", "ham_onSpawn_Post", 1);
    RegisterHam(Ham_Killed, "player", "ham_onKilled", 0);

    new TeamInfo = get_user_msgid("TeamInfo");
    if (register_message(TeamInfo, "msg_onTeamInfo") == 0) {
        LoggerLogError(g_Logger,
                "register_message(TeamInfo, \"msg_onTeamInfo\") returned 0");
        set_fail_state(
                "register_message(TeamInfo, \"msg_onTeamInfo\") returned 0");
    }
}

registerConCmds() {
    zm_registerConCmd(
            .command = "players",
            .function = "printPlayers",
            .description = "Prints the list of players with their statuses",
            .logger = g_Logger);

    zm_registerConCmd(
            .command = "zombies",
            .function = "printZombies",
            .description = "Prints the list of players who are a zombie",
            .logger = g_Logger);

    zm_registerConCmd(
            .command = "humans",
            .function = "printHumans",
            .description = "Prints the list of players who are a human",
            .logger = g_Logger);
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
    LoggerLogDebug(g_Logger, "Creating forward zm_onSpawn");
    g_fw[onSpawn] = CreateMultiForward("zm_onSpawn",
            ET_IGNORE,
            FP_CELL, 
            FP_CELL);
    LoggerLogDebug(g_Logger,
            "g_fw[onSpawn] = %d",
            g_fw[onSpawn]);
}

createOnKilled() {
    LoggerLogDebug(g_Logger, "Creating forward zm_onKilled");
    g_fw[onKilled] = CreateMultiForward("zm_onKilled",
            ET_IGNORE,
            FP_CELL, 
            FP_CELL);
    LoggerLogDebug(g_Logger,
            "g_fw[onKilled] = %d",
            g_fw[onKilled]);
}

createOnApply() {
    LoggerLogDebug(g_Logger, "Creating forward zm_onApply");
    g_fw[onApply] = CreateMultiForward(
            "zm_onApply",
            ET_IGNORE,
            FP_CELL, 
            FP_CELL);
    LoggerLogDebug(g_Logger,
            "g_fw[onApply] = %d",
            g_fw[onApply]);
}

createOnBeforeInfected() {
    LoggerLogDebug(g_Logger, "Creating forward zm_onBeforeInfected");
    g_fw[onBeforeInfected] = CreateMultiForward(
            "zm_onBeforeInfected",
            ET_CONTINUE,
            FP_CELL,
            FP_CELL, 
            FP_CELL);
    LoggerLogDebug(g_Logger,
            "g_fw[onBeforeInfected] = %d",
            g_fw[onBeforeInfected]);
}

createOnInfected() {
    LoggerLogDebug(g_Logger, "Creating forward zm_onInfected");
    g_fw[onInfected] = CreateMultiForward(
            "zm_onInfected",
            ET_IGNORE,
            FP_CELL, 
            FP_CELL);
    LoggerLogDebug(g_Logger,
            "g_fw[onInfected] = %d",
            g_fw[onInfected]);
}

createOnAfterInfected() {
    LoggerLogDebug(g_Logger, "Creating forward zm_onAfterInfected");
    g_fw[onAfterInfected] = CreateMultiForward(
            "zm_onAfterInfected",
            ET_IGNORE,
            FP_CELL, 
            FP_CELL);
    LoggerLogDebug(g_Logger,
            "g_fw[onAfterInfected] = %d",
            g_fw[onAfterInfected]);
}

createOnBeforeCured() {
    LoggerLogDebug(g_Logger, "Creating forward zm_onBeforeCured");
    g_fw[onBeforeCured] = CreateMultiForward(
            "zm_onBeforeCured",
            ET_CONTINUE,
            FP_CELL,
            FP_CELL, 
            FP_CELL);
    LoggerLogDebug(g_Logger,
            "g_fw[onBeforeCured] = %d",
            g_fw[onBeforeCured]);
}

createOnCured() {
    LoggerLogDebug(g_Logger, "Creating forward zm_onCured");
    g_fw[onCured] = CreateMultiForward(
            "zm_onCured",
            ET_IGNORE,
            FP_CELL, 
            FP_CELL);
    LoggerLogDebug(g_Logger,
            "g_fw[onCured] = %d",
            g_fw[onCured]);
}

createOnAfterCured() {
    LoggerLogDebug(g_Logger, "Creating forward zm_onAfterCured");
    g_fw[onAfterCured] = CreateMultiForward(
            "zm_onAfterCured",
            ET_IGNORE,
            FP_CELL, 
            FP_CELL);
    LoggerLogDebug(g_Logger,
            "g_fw[onAfterCured] = %d",
            g_fw[onAfterCured]);
}

public client_putinserver(id) {
    setFlag(g_Logger, g_flagConnected, id);
}

public client_disconnect(id) { //Ignoreable: warning 233: recursive function "client_disconnect"
    unsetFlag(g_Logger, g_flagConnected, id);
    unsetFlag(g_Logger, g_flagAlive, id);
}

public ham_onSpawn_Post(id) {
    if (!is_user_alive(id)) {
        unsetFlag(g_Logger, g_flagAlive, id);
        return HAM_IGNORED;
    }
    
    setFlag(g_Logger, g_flagAlive, id);
    new bool: isZombie = isUserZombie(id);
    LoggerLogDebug(g_Logger, "Calling zm_onApply(%d, isZombie=%s) for %N", id, isZombie ? TRUE : FALSE, id);
    ExecuteForward(g_fw[onApply], g_fw[fwReturn], id, isZombie);
    LoggerLogDebug(g_Logger, "Calling zm_onSpawn(%d, isZombie=%s) for %N", id, isZombie ? TRUE : FALSE, id);
    ExecuteForward(g_fw[onSpawn], g_fw[fwReturn], id, isZombie);
    return HAM_HANDLED;
}

public ham_onKilled(killer, victim, shouldgib) {
    if (is_user_alive(victim)) {
        return HAM_IGNORED;
    }
    
    //hideMenus(victim);
    unsetFlag(g_Logger, g_flagAlive, victim);
    LoggerLogDebug(g_Logger, "Calling zm_onKilled(killer=%d, victim=%d) for %N", killer, victim, victim);
    ExecuteForward(g_fw[onKilled], g_fw[fwReturn], killer, victim);
    return HAM_HANDLED;
}

public msg_onTeamInfo(const msgId, const msgDest, const entId) {
    if (msgDest != MSG_ALL && msgDest != MSG_BROADCAST) {
        return;
    }

    new id = get_msg_arg_int(1);
    assert isValidId(id);

    new team[2];
    get_msg_arg_string(2, team, charsmax(team));
    LoggerLogDebug(g_Logger, "msg_onTeamInfo(%d, %s)", id, team);
    switch (team[0]) {
        case 'C': cure(.id = id, .blockable = false);
        case 'S': return;
        case 'T': infect(.id = id, .blockable = false);
        case 'U': return;
        default: assert false;
    }
}

bool: isUserConnected(const id) {
    assert isValidId(id);
    return isFlagSet(g_Logger, g_flagConnected, id);
}

bool: isUserAlive(const id) {
    assert isValidId(id);
    return isFlagSet(g_Logger, g_flagAlive, id);
}

bool: isUserZombie(const id) {
    assert isValidId(id);
    return isFlagSet(g_Logger, g_flagZombie, id);
}

bool: isUserHuman(const id) {
    assert isValidId(id);
    return !isUserZombie(id);
}

bool: respawn(const id, const bool: force = false) {
    assert isValidId(id);
    if (isUserAlive(id) && !force) {
        LoggerLogDebug(g_Logger, "Respawn blocked for %N", id);
        return false;
    }

    ExecuteHamB(Ham_CS_RoundRespawn, id);
    return true;
}

ZM_State_Change: infect(const id, const infector = -1, const bool: blockable = true) {
    assert isValidId(id);
    assert infector == -1 || isValidId(infector);
    if (isUserZombie(id)) {
        LoggerLogDebug(g_Logger, "Calling zm_onApply(%d, isZombie=%s) for %N", id, TRUE, id);
        ExecuteForward(g_fw[onApply], g_fw[fwReturn], id, true);
        return ZM_STATE_CHANGE_DID_NOT_CHANGE;
    }

    LoggerLogDebug(g_Logger, "Calling zm_onBeforeInfected(%d, %d, blockable=%s) for %N", id, infector, blockable ? TRUE : FALSE, id);
    ExecuteForward(g_fw[onBeforeInfected], g_fw[fwReturn], id, infector, blockable);
    if (blockable && g_fw[fwReturn] == PLUGIN_HANDLED) {
        LoggerLogDebug(g_Logger, "Infection blocked for %N", id);
        return ZM_STATE_CHANGE_BLOCKED;
    }

    //hideMenus(id);
    LoggerLogDebug(g_Logger, "Calling zm_onInfected(%d, %d) for %N", id, infector, id);
    ExecuteForward(g_fw[onInfected], g_fw[fwReturn], id, infector);

    setFlag(g_Logger, g_flagZombie, id);
    cs_set_team_id(id, ZM_TEAM_ZOMBIE);
    LoggerLogDebug(g_Logger, "Calling zm_onApply(%d, isZombie=%s) for %N", id, TRUE, id);
    ExecuteForward(g_fw[onApply], g_fw[fwReturn], id, true);
    
    LoggerLogDebug(g_Logger, "Calling zm_onAfterInfected(%d, %d) for %N", id, infector, id);
    ExecuteForward(g_fw[onAfterInfected], g_fw[fwReturn], id, infector);

#if defined ZM_COMPILE_FOR_DEBUG
    new name[32];
    get_user_name(id, name, 31);
    if (isValidId(infector)) {
        new other[32];
        get_user_name(infector, other, 31);
        LoggerLogDebug(g_Logger, "%s infected %s", other, name);
    } else {
        LoggerLogDebug(g_Logger, "%s has been infected", name);
    }
#endif
    return ZM_STATE_CHANGE_CHANGED;
}

ZM_State_Change: cure(const id, const curor = -1, const bool: blockable = true) {
    assert isValidId(id);
    assert curor == -1 || isValidId(curor);
    if (isUserHuman(id)) {
        LoggerLogDebug(g_Logger, "Calling zm_onApply(%d, isZombie=%s) for %N", id, FALSE, id);
        ExecuteForward(g_fw[onApply], g_fw[fwReturn], id, false);
        return ZM_STATE_CHANGE_DID_NOT_CHANGE;
    }

    LoggerLogDebug(g_Logger, "Calling zm_onBeforeCured(%d, %d, blockable=%s) for %N", id, curor, blockable ? TRUE : FALSE, id);
    ExecuteForward(g_fw[onBeforeCured], g_fw[fwReturn], id, curor, blockable);
    if (blockable && g_fw[fwReturn] == PLUGIN_HANDLED) {
        LoggerLogDebug(g_Logger, "Curing blocked for %N", id);
        return ZM_STATE_CHANGE_BLOCKED;
    }

    //hideMenus(id);
    LoggerLogDebug(g_Logger, "Calling zm_onCured(%d, %d) for %N", id, curor, id);
    ExecuteForward(g_fw[onCured], g_fw[fwReturn], id, curor);

    setFlag(g_Logger, g_flagZombie, id);
    cs_set_team_id(id, ZM_TEAM_HUMAN);
    LoggerLogDebug(g_Logger, "Calling zm_onApply(%d, isZombie=%s) for %N", id, FALSE, id);
    ExecuteForward(g_fw[onApply], g_fw[fwReturn], id, false);
    
    LoggerLogDebug(g_Logger, "Calling zm_onAfterCured(%d, %d) for %N", id, curor, id);
    ExecuteForward(g_fw[onAfterCured], g_fw[fwReturn], id, curor);

#if defined ZM_COMPILE_FOR_DEBUG
    new name[32];
    get_user_name(id, name, 31);
    if (isValidId(curor)) {
        new other[32];
        get_user_name(curor, other, 31);
        LoggerLogDebug(g_Logger, "%s cured %s", other, name);
    } else {
        LoggerLogDebug(g_Logger, "%s has been cured", name);
    }
#endif
    return ZM_STATE_CHANGE_CHANGED;
}

/*******************************************************************************
 * Console Commands
 ******************************************************************************/

public printPlayers(id) {
    console_print(id, "Players:");

    console_print(id,
            "%3s %8s %5s %5s %s",
            "ID",
            "NAME",
            "STATE",
            "ALIVE",
            "CONNECTED");

    new name[32];
    new playersConnected = 0;
    for (new i = 1; i <= MaxClients; i++) {
        if (isUserConnected(i)) {
            playersConnected++;
            get_user_name(i, name, charsmax(name));
            console_print(id,
                    "%2d. %8.8s %5c %5s %s",
                    i,
                    name,
                    isUserZombie(i) ? ZOMBIE[0] : HUMAN[0],
                    isUserAlive(i) ? TRUE : NULL_STRING,
                    TRUE);
        } else {
            name[0] = EOS;
#if defined ZM_PLAYERS_PRINT_EMPTY
            console_print(id, "%2d.", i);
#endif
        }

        
    }
    
    console_print(id, "%d players connected.", playersConnected);
}

public printZombies(id) {
    console_print(id, "Zombies:");

    console_print(id,
            "%3s %8s %5s",
            "ID",
            "NAME",
            "ALIVE");

    new name[32];
    new numZombies = 0;
    for (new i = 1; i <= MaxClients; i++) {
        if (!isUserZombie(i) || !isUserConnected(i)) {
            continue;
        }

        numZombies++;
        get_user_name(i, name, charsmax(name));
        console_print(id,
                "%2d. %8.8s %5s",
                i,
                name,
                isUserAlive(i) ? TRUE : NULL_STRING);
    }
    
    console_print(id, "%d zombies found.", numZombies);
}

public printHumans(id) {
    console_print(id, "Humans:");

    console_print(id,
            "%3s %8s %5s",
            "ID",
            "NAME",
            "ALIVE");

    new name[32];
    new numHumans = 0;
    for (new i = 1; i <= MaxClients; i++) {
        if (!isUserHuman(i) || !isUserConnected(i)) {
            continue;
        }

        numHumans++;
        get_user_name(i, name, charsmax(name));
        console_print(id,
                "%2d. %8.8s %5s",
                i,
                name,
                isUserAlive(i) ? TRUE : NULL_STRING);
    }
    
    console_print(id, "%d humans found.", numHumans);
}

/*******************************************************************************
 * Natives
 ******************************************************************************/

// native bool: zm_isUserConnected(const id);
public bool: _isUserConnected(pluginId, numParams) {
    if (!numParamsEqual(g_Logger, 1, numParams)) {
        return false;
    }

    new id = get_param(1);
    if (!isValidId(id)) {
        LoggerLogWarn(g_Logger, "Invalid player id specified: %d", id);
        return false;
    }

    return isUserConnected(id);
}

// native bool: zm_isUserAlive(const id);
public bool: _isUserAlive(pluginId, numParams) {
    if (!numParamsEqual(g_Logger, 1, numParams)) {
        return false;
    }

    new id = get_param(1);
    if (!isValidId(id)) {
        LoggerLogWarn(g_Logger, "Invalid player id specified: %d", id);
        return false;
    }

    return isUserAlive(id);
}

// native bool: zm_isUserZombie(const id);
public bool: _isUserZombie(pluginId, numParams) {
    if (!numParamsEqual(g_Logger, 1, numParams)) {
        return false;
    }

    new id = get_param(1);
    if (!isValidId(id)) {
        LoggerLogWarn(g_Logger, "Invalid player id specified: %d", id);
        return false;
    }

    return isUserZombie(id);
}

// native bool: zm_respawn(const id, const bool: force = false);
public bool: _respawn(pluginId, numParams) {
    if (!numParamsEqual(g_Logger, 2, numParams)) {
        return false;
    }

    new id = get_param(1);
    if (!isValidId(id)) {
        LoggerLogWarn(g_Logger, "Invalid player id specified: %d", id);
        return false;
    }

    if (!isUserConnected(id)) {
        LoggerLogError(g_Logger,
                "Player with id specified is not connected: %d", id);
        return false;
    }

    return respawn(id, bool:(get_param(2)));
}

// native ZM_State_Change: zm_infect(
//         const id,
//         const infector = -1,
//         const bool: blockable = true);
public ZM_State_Change: _infect(pluginId, numParams) {
    if (!numParamsEqual(g_Logger, 3, numParams)) {
        return ZM_STATE_CHANGE_ERROR;
    }

    new id = get_param(1);
    if (!isValidId(id)) {
        LoggerLogError(g_Logger, "Invalid player id specified: %d", id);
        return ZM_STATE_CHANGE_ERROR;
    }

    if (!isUserConnected(id)) {
        LoggerLogError(g_Logger,
                "Player with id specified is not connected: %d", id);
        return ZM_STATE_CHANGE_ERROR;
    }

    return infect(id, get_param(2), bool:(get_param(3)));
}

// native ZM_State_Change: zm_cure(
//         const id,
//         const curor = -1,
//         const bool: blockable = true);
public ZM_State_Change: _cure(pluginId, numParams) {
    if (!numParamsEqual(g_Logger, 3, numParams)) {
        return ZM_STATE_CHANGE_ERROR;
    }

    new id = get_param(1);
    if (!isValidId(id)) {
        LoggerLogError(g_Logger, "Invalid player id specified: %d", id);
        return ZM_STATE_CHANGE_ERROR;
    }

    if (!isUserConnected(id)) {
        LoggerLogError(g_Logger,
                "Player with id specified is not connected: %d", id);
        return ZM_STATE_CHANGE_ERROR;
    }

    return cure(id, get_param(2), bool:(get_param(3)));
}