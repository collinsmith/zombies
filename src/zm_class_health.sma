#include <amxmodx>
#include <amxmisc>
#include <fakemeta>
#include <logger>

#include "include/zm/zm_classes.inc"
#include "include/zm/zombies.inc"

#if defined ZM_COMPILE_FOR_DEBUG
  #define DEBUG_HEALTH
#else
  //#define DEBUG_HEALTH
#endif

#define EXTENSION_NAME "Class Health"
#define VERSION_STRING "1.0.0"

public zm_onInit() {
  new Logger: oldLogger = LoggerSetThis(zm_getLogger());
  LoggerDestroy(oldLogger);
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
      .desc = "Applies the class health");
}

stock getBuildId(buildId[], len) {
  return formatex(buildId, len, "%s [%s]", VERSION_STRING, __DATE__);
}

public zm_onApply(const id) {
  new const Class: class = zm_getUserClass(id);
  if (!class) {
#if defined DEBUG_HEALTH
    LoggerLogDebug("%N doesn't have a class, ignoring", id);
#endif
    return;
  }
  
  static value[8];
  new const bool: hasProperty = zm_getClassProperty(class, ZM_CLASS_HEALTH, value, charsmax(value));
  if (!hasProperty) {
#if defined DEBUG_HEALTH
    new key[class_prop_key_length + 1];
    zm_getClassProperty(class, ZM_CLASS_NAME, key, charsmax(key));
    LoggerLogDebug("Ignoring health change for %N because \"%s\" does not contain a value for \"%s\"",
        id, key, ZM_CLASS_HEALTH);
    return;
#endif
  }

  new const Float: health = str_to_float(value);
  if (health < 0.0) {
    new key[class_prop_key_length + 1];
    zm_getClassProperty(class, ZM_CLASS_NAME, key, charsmax(key));
    LoggerLogError("Invalid health value for class \"%s\". Health cannot be less than 0.0: %.0f", key, health);
    return;
  } else if (health == 0.0) {
#if defined DEBUG_HEALTH
    new key[class_prop_key_length + 1];
    zm_getClassProperty(class, ZM_CLASS_NAME, key, charsmax(key));
    LoggerLogDebug("Ignoring health change for %N because health of \"%s\" is %.0f", id, key, health);
#endif
    return;
  }

#if defined DEBUG_HEALTH
  LoggerLogDebug("Setting health of %N to %.0f", id, health);
#endif
  set_pev(id, pev_health, health);
}
