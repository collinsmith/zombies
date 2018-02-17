#include <amxmodx>
#include <engine>
#include <logger>

#include "include/zm/zombies.inc"

#if defined ZM_COMPILE_FOR_DEBUG
#else
#endif

#define EXTENSION_NAME "Debug"
#define VERSION_STRING "1.0.0"

public zm_onPrecache() {
  precache_model("models/rpgrocket.mdl");
}

public zm_onInit() {
  LoadLogger(zm_getPluginId());
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

  zm_registerConCmd(
      .command = "cam.1",
      .callback = "onSetFirstPerson",
      .desc = "Sets camera to 1st person perspective");

  zm_registerConCmd(
      .command = "cam.3",
      .callback = "onSetThirdPerson",
      .desc = "Sets camera to 3rd person perspective");
}

stock getBuildId(buildId[], len) {
  return formatex(buildId, len, "%s [%s]", VERSION_STRING, __DATE__);
}

public onSetFirstPerson(id) {
  if (is_user_alive(id)) {
    console_print(id, "Camera set to 1st person");
    set_view(id, CAMERA_NONE);
  }

  return PLUGIN_HANDLED;
}

public onSetThirdPerson(id) {
  if (is_user_alive(id)) {
    console_print(id, "Camera set to 3rd person");
    set_view(id, CAMERA_3RDPERSON);
  }

  return PLUGIN_HANDLED;
}
