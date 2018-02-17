#include <amxmodx>
#include <cstrike>

#include "include/zm/zm_teams.inc"
#include "include/zm/zombies.inc"

#define EXTENSION_NAME "Team Change Provider: cstrike"
#define VERSION_STRING "1.0.0"

public zm_onInitExtension() {
  new name[32];
  formatex(name, charsmax(name), "[%L] %s", LANG_SERVER, ZM_NAME_SHORT, EXTENSION_NAME);
  register_plugin(name, VERSION_STRING, "Tirant");

  new buildId[32];
  getBuildId(buildId, charsmax(buildId));
  zm_registerExtension(
      .name = EXTENSION_NAME,
      .version = buildId,
      .desc = "Provides team changes in ");

  zm_setTeamChangeProvider("provideTeamChange");
}

stock getBuildId(buildId[], len) {
  return formatex(buildId, len, "%s [%s]", VERSION_STRING, __DATE__);
}

public provideTeamChange(const id, const ZM_Team: team) {
  cs_set_user_team(id, team, .send_teaminfo = false);
}