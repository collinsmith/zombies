#include <amxmodx>
#include <logger>
#include <reapi>

#include "include/stocks/param_stocks.inc"

#include "include/commands/commands.inc"

#include "include/zm/zombies.inc"

#include "include/zm_internal_utils.inc"

#if defined ZM_COMPILE_FOR_DEBUG
  #define DEBUG_ASSERTIONS
  #define DEBUG_NATIVES
  #define DEBUG_FORWARDS
#else
  //#define DEBUG_ASSERTIONS
  //#define DEBUG_NATIVES
  //#define DEBUG_FORWARDS
#endif

#define EXTENSION_NAME "Infinite BP Ammo"
#define VERSION_STRING "1.0.0"

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
      .desc = "Enables infinite backpack ammo");
  
  register_event_ex("AmmoX", "onAmmoX", RegisterEvent_Single | RegisterEvent_OnlyAlive);
}

stock getBuildId(buildId[], len) {
  return formatex(buildId, len, "%s [%s]", VERSION_STRING, __DATE__);
}

public onAmmoX(id) {
  set_member(id, m_rgAmmo, 200, read_data(1));
}
