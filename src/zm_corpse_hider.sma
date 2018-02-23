#include <amxmodx>
#include <logger>

#include "include/zm/zombies.inc"

#if defined ZM_COMPILE_FOR_DEBUG
#else
#endif

#define EXTENSION_NAME "Corpse Hider"
#define VERSION_STRING "1.0.0"

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
      .desc = "Hides dead player bodies");

  new ClCorpse = get_user_msgid("ClCorpse");
  set_msg_block(ClCorpse, BLOCK_SET);
}

stock getBuildId(buildId[], len) {
  return formatex(buildId, len, "%s [%s]", VERSION_STRING, __DATE__);
}
