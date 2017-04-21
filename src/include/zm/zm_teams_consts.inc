#if defined _zm_teams_consts_included
  #endinput
#endif
#define _zm_teams_consts_included

enum ZM_Team {
  ZM_TEAM_UNASSIGNED = 0,
  ZM_TEAM_ZOMBIE = 1,
  ZM_TEAM_HUMAN = 2,
  ZM_TEAM_SPECTATOR = 3,
};

stock const ZM_Team_Names[ZM_Team][] = {
  "ZM_TEAM_UNASSIGNED",
  "ZM_TEAM_ZOMBIE",
  "ZM_TEAM_HUMAN",
  "ZM_TEAM_SPECTATOR",
};

/**
 * Enumeration of possible results from changing the state of a player from one
 * team to another.
 */
enum ZM_State_Change {
  /** An error occurred, see log for details */
  ZM_STATE_CHANGE_ERROR = -1,
  /** The player was already on the specified team */
  ZM_STATE_CHANGE_DID_NOT_CHANGE = 0,
  /** The state change was blocked by an extension */
  ZM_STATE_CHANGE_BLOCKED,
  /** The player's state changed as a result of the calling function */
  ZM_STATE_CHANGE_CHANGED
};
