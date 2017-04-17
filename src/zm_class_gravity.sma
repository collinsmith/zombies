#include <amxmodx>
#include <amxmisc>
#include <fakemeta>
#include <logger>

#include "include/zm/zm_classes.inc"
#include "include/zm/zombies.inc"

#if defined ZM_COMPILE_FOR_DEBUG
  #define DEBUG_GRAVITY
#else
  //#define DEBUG_GRAVITY
#endif

#define EXTENSION_NAME "Class Gravity"
#define VERSION_STRING "1.0.0"

static Logger: logger = Invalid_Logger;

public zm_onInit() {
  logger = zm_getLogger();
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
      .desc = "Applies the class gravity");
}

stock getBuildId(buildId[], len) {
  return formatex(buildId, len, "%s [%s]", VERSION_STRING, __DATE__);
}

public zm_onApply(const id) {
  new const Class: class = zm_getUserClass(id);
  if (!class) {
#if defined DEBUG_GRAVITY
    LoggerLogDebug(logger, "%N doesn't have a class, ignoring", id);
#endif
    return;
  }
  
  static value[8];
  new const bool: hasProperty = zm_getClassProperty(class, ZM_CLASS_GRAVITY, value, charsmax(value));
  if (!hasProperty) {
#if defined DEBUG_GRAVITY
    new key[class_prop_key_length + 1];
    zm_getClassProperty(class, ZM_CLASS_NAME, key, charsmax(key));
    LoggerLogDebug(logger, "Ignoring gravity change for %N because \"%s\" does not contain a value for \"%s\"",
        id, key, ZM_CLASS_GRAVITY);
    return;
#endif
  }

  new const Float: gravity = str_to_float(value);
  if (gravity < 0.0) {
    new key[class_prop_key_length + 1];
    zm_getClassProperty(class, ZM_CLASS_NAME, key, charsmax(key));
    LoggerLogError(logger,"Invalid gravity value for class \"%s\". Gravity cannot be less than 0.00: %.2f", key, gravity);
    return;
  } else if (gravity == 0.0) {
#if defined DEBUG_GRAVITY
    new key[class_prop_key_length + 1];
    zm_getClassProperty(class, ZM_CLASS_NAME, key, charsmax(key));
    LoggerLogDebug(logger, "Ignoring gravity change for %N because gravity of \"%s\" is %.2f", id, key, gravity);
#endif
    return;
  }

#if defined DEBUG_GRAVITY
  LoggerLogDebug(logger, "Setting gravity of %N to %.2f", id, gravity);
#endif
  set_pev(id, pev_gravity, gravity);
}
