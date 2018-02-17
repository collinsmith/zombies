#include <amxmodx>
#include <engine>
#include <logger>

#include "include/zm/zm_classes.inc"
#include "include/zm/zombies.inc"

#if defined ZM_COMPILE_FOR_DEBUG
  //#define DEBUG_GRAVITY
#else
  //#define DEBUG_GRAVITY
#endif

#define EXTENSION_NAME "Class Gravity"
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
      .desc = "Applies the class gravity");
}

stock getBuildId(buildId[], len) {
  return formatex(buildId, len, "%s [%s]", VERSION_STRING, __DATE__);
}

public zm_onApply(const id) {
  new const Class: class = zm_getUserClass(id);
  if (!class) {
#if defined DEBUG_GRAVITY
    logd("%N doesn't have a class, resetting", id);
#endif
    setGravity(id, 1.0);
    return;
  }
  
  static value[8];
  new const bool: hasProperty = zm_getClassProperty(class, ZM_CLASS_GRAVITY, value, charsmax(value));
  if (!hasProperty) {
#if defined DEBUG_GRAVITY
    new key[class_prop_key_length + 1];
    zm_getClassProperty(class, ZM_CLASS_NAME, key, charsmax(key));
    logd("Ignoring gravity change for %N because \"%s\" does not contain a value for \"%s\"",
        id, key, ZM_CLASS_GRAVITY);
    return;
#endif
  }

  new const Float: gravity = str_to_float(value);
  if (gravity < 0.0) {
    new key[class_prop_key_length + 1];
    zm_getClassProperty(class, ZM_CLASS_NAME, key, charsmax(key));
    loge("Invalid gravity value for class \"%s\". Gravity cannot be less than 0.00: %.2f", key, gravity);
    return;
  } else if (gravity == 0.0) {
#if defined DEBUG_GRAVITY
    new key[class_prop_key_length + 1];
    zm_getClassProperty(class, ZM_CLASS_NAME, key, charsmax(key));
    logd("Ignoring gravity change for %N because gravity of \"%s\" is %.2f", id, key, gravity);
#endif
    return;
  }

  setGravity(id, gravity);
}

setGravity(id, Float: gravity) {
#if defined DEBUG_GRAVITY
  logd("Setting gravity of %N to %.2f", id, gravity);
#endif
  entity_set_float(id, EV_FL_gravity, gravity);
}
