#include <logger>

#include "include/package_manager.inc"

#include "include/zm/zombies.inc"

#define EXTENSION_NAME "Package Manager"
#define VERSION_STRING "1.0.0"

static const ZM_MANIFEST_URL[] = "https://raw.githubusercontent.com/collinsmith/zombies/master/manifest";

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
      .desc = "Manages ZM packages and automates installing, upgrading and configuring");

  logi("Checking for updates...");
  pkg_processManifest(ZM_MANIFEST_URL);
}

stock getBuildId(buildId[], len) {
  return formatex(buildId, len, "%s [%s]", VERSION_STRING, __DATE__);
}