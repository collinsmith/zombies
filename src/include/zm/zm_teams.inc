#if defined _zm_teams_included
    #endinput
#endif
#define _zm_teams_included

#pragma reqlib zm_teams

#include "include/zm/zm_teams_consts.inc"

/*******************************************************************************
 * FORWARDS
 ******************************************************************************/

/**
 * Called after a player has respawned.
 * 
 * @noreturn
 */
forward zm_onSpawn(const id);

/**
 * Called when a player dies. If {@code killer} is equal to {@code -1} then
 * {@code victim} was killed by some world event.
 * 
 * @noreturn
 */
forward zm_onKilled(const killer, const victim);

/**
 * Called when a player is about to be infected.
 * 
 * @param id        The targetted player of the infection
 * @param infector  The player causing the infection, or {@code -1} if the
 *                    infection was triggered by an extension (for example, the
 *                    player is becoming the first zombie)
 * @param blockable {@code true} if the infection event is blockable (for
 *                    example, the player has some item that might prevent
 *                    immediate infeciton), {@code false} otherwise
 * 
 * @return Typically {@code PLUGIN_CONTINUE}, however if {@code blockable} is
 *         {@code true}, then {@code PLUGIN_HANDLED} will prevent the infection.
 */
forward zm_onBeforeInfected(const id, const infector, const bool: blockable);

/**
 * Called after {@code #zm_onBeforeInfected}, once a player has been infected,
 * but before their actual state has changed. At this stage, the infection event
 * can no longer be blocked.
 * 
 * @param id       The targetted player of the infection
 * @param infector The player causing the infection, or {@code -1} if the
 *                   infection was triggered by an extension (for example, the
 *                   player is becoming the first zombie)
 * 
 * @noreturn
 */
forward zm_onInfected(const id, const infector);

/**
 * Called after {@code #zm_onInfected}, once a player has been infected and is
 * now a zombie.
 * 
 * @param id       The targetted player of the infection
 * @param infector The player causing the infection, or {@code -1} if the
 *                   infection was triggered by an extension (for example, the
 *                   player is becoming the first zombie)
 * 
 * @noreturn
 */
forward zm_onAfterInfected(const id, const infector);

/**
 * Called when a player is about to be cured.
 * 
 * @param id        The targetted player of the cure
 * @param curor     The player causing the curing, or {@code -1} if the
 *                    curing was triggered by an extension (for example, the
 *                    player has an item that cures them)
 * @param blockable {@code true} if the cure event is blockable (for
 *                    example, if the player is a prime zombie, then they might
 *                    not be curable in some cases, {@code false} otherwise
 * 
 * @return Typically {@code PLUGIN_CONTINUE}, however if {@code blockable} is
 *         {@code true}, then {@code PLUGIN_HANDLED} will prevent the infection.
 */
forward zm_onBeforeCured(const id, const curor, const bool: blockable);

/**
 * Called after {@code #zm_onBeforeCured}, once a player has been cured, but
 * before their actual state has changed. At this stage, the cure event can no
 * longer be blocked.
 * 
 * @param id    The targetted player of the cure
 * @param curor The player causing the curing, or {@code -1} if the curing was 
 *                triggered by an extension (for example, the player has an item
 *                that cures them)
 * 
 * @noreturn
 */
forward zm_onCured(const id, const curor);

/**
 * Called after {@code #zm_onCured}, once a player has been cured and is now a
 * human.
 * 
 * @param id    The targetted player of the cure
 * @param curor The player causing the curing, or {@code -1} if the curing was 
 *                triggered by an extension (for example, the player has an item
 *                that cures them)
 * 
 * @noreturn
 */
forward zm_onAfterCured(const id, const curor);

/**
 * Called when refreshing the state of a player. Extensions can override this
 * function to do things such as change the player's model, modify their
 * loadout, etc.
 * 
 * @param id       The player triggering the event
 * @param isZombie {@code true} if the player is a zombie, {@code false} otherwise
 * 
 * @noreturn
 */
forward zm_onApply(const id);

/*******************************************************************************
 * NATIVES
 ******************************************************************************/

/**
 * Returns the team of the specified player.
 * 
 * @return One of {@code ZM_TEAM_UNASSIGNED}, {@code ZM_TEAM_ZOMBIE},
 *         {@code ZM_TEAM_HUMAN}, or {@code ZM_TEAM_SPECTATOR}
 */
native ZM_Team: zm_getUserTeam(const id);

/**
 * Indicates whether or not the specified player is a zombie, i.e.,
 * {@code zm_getUserTeam(id) == ZM_TEAM_ZOMBIE}.
 */
stock bool: zm_isUserZombie(const id) {
  zm_getUserTeam(id) == ZM_TEAM_ZOMBIE;
}

/**
 * Indicates whether or not the specified player is a human, i.e.,
 * {@code zm_getUserTeam(id) == ZM_TEAM_HUMAN}.
 */
stock bool: zm_isUserHuman(const id) {
  zm_getUserTeam(id) == ZM_TEAM_HUMAN;
}

/**
 * Respawns the specified player.
 * 
 * @param id    The player to respawn
 * @param force {@code true} to respawn the user even if they are alive,
 *                {@code false} otherwise
 * 
 * @return {@code true} if the player respawned as a result of this call,
 *         {@code false} otherwise
 */
native bool: zm_respawn(const id, const bool: force = false);

/**
 * Infects the specified player and turns them into a zombie.
 * 
 * @param id        The player to infect
 * @param infector  The originating player of the infection, or {@code -1} if
 *                    the player is being infected an extension
 * @param blockable {@code true} if the infection event is blockable by
 *                    extensions, {@code false} otherwise. If the infection is
 *                    blockable and it is blocked, then this function will
 *                    return {@code ZM_STATE_CHANGE_BLOCKED}
 * @param respawn   {@code true} to force respawn the player, {@code false} otherwise
 * 
 * @return One of {@code ZM_STATE_CHANGE_ERROR}, {@code ZM_STATE_CHANGE_DID_NOT_CHANGE},
 *         {@code ZM_STATE_CHANGE_BLOCKED}, or {@code ZM_STATE_CHANGE_CHANGED}
 */
native ZM_State_Change: zm_infect(const id, const infector = -1, const bool: blockable = true, const bool: respawn = false);

/**
 * Cures the specified player and turns them into a human.
 * 
 * @param id        The player to cure
 * @param infector  The originating player of the cure, or {@code -1} if
 *                    the player is being cured by an extension
 * @param blockable {@code true} if the cure event is blockable by extensions,
 *                    {@code false} otherwise. If the cure is blockable and it
 *                    is blocked, then this function will return
 *                    {@code ZM_STATE_CHANGE_BLOCKED}
 * @param respawn   {@code true} to force respawn the player, {@code false} otherwise
 * 
 * @return One of {@code ZM_STATE_CHANGE_ERROR}, {@code ZM_STATE_CHANGE_DID_NOT_CHANGE},
 *         {@code ZM_STATE_CHANGE_BLOCKED}, or {@code ZM_STATE_CHANGE_CHANGED}
 */
native ZM_State_Change: zm_cure(const id, const curor = -1, const bool: blockable = true, const bool: respawn = false);

/**
 * Refreshes the state of the specified player by calling {@link #zm_onApply}.
 * 
 * @param id The player to update
 * 
 * @return {@code true} if the player's state refreshed as a result of this
 *         call, {@code false} otherwise
 */
native bool: zm_refresh(const id);

/**
 * Sets the team change provider of ZM. By default ZM only supports cstrike,
 * however with this native, other mods should be supportable by providing a
 * means of changing a user's team using a generic API. Only one team change
 * provider can be active at a time, so a warning will be given in the event
 * this function is called and a team change provider is already set.
 * 
 * @param callback The callback function which will be used to change a user's
 *                 team. The callback function's signature should look like
 *                 {@code public <callback>(const id, const ZM_Team: team)}
 * 
 * 
 * 
 * @throws IllegalStateException if a team change provider has already been set.
 */
native zm_setTeamChangeProvider(const callback[]);
