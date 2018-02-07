#include <amxmodx>
#include <amxmisc>
#include <fakemeta>
#include <logger>

#include "include/zm/zm_classes.inc"
#include "include/zm/zombies.inc"

#if defined ZM_COMPILE_FOR_DEBUG
  #define DEBUG_MAXSPEED
#else
  //#define DEBUG_MAXSPEED
#endif

#define EXTENSION_NAME "Class Speed"
#define VERSION_STRING "1.0.0"

const Float: RAW_VALUE_THRESHOLD = 10.0;

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
      .desc = "Applies the class maxspeed");
}

stock getBuildId(buildId[], len) {
  return formatex(buildId, len, "%s [%s]", VERSION_STRING, __DATE__);
}

public zm_onApply(const id) {
  new const Class: class = zm_getUserClass(id);
  if (!class) {
#if defined DEBUG_MAXSPEED
    logd("%N doesn't have a class, ignoring", id);
#endif
    return;
  }
  
  static value[8];
  new const bool: hasProperty = zm_getClassProperty(class, ZM_CLASS_MAXSPEED, value, charsmax(value));
  if (!hasProperty) {
#if defined DEBUG_MAXSPEED
    new key[class_prop_key_length + 1];
    zm_getClassProperty(class, ZM_CLASS_NAME, key, charsmax(key));
    logd("Ignoring maxspeed change for %N because \"%s\" does not contain a value for \"%s\"",
        id, key, ZM_CLASS_MAXSPEED);
    return;
#endif
  }

  new Float: maxspeed = str_to_float(value);
  if (maxspeed < 0.0) {
    new key[class_prop_key_length + 1];
    zm_getClassProperty(class, ZM_CLASS_NAME, key, charsmax(key));
    loge("Invalid maxspeed value for class \"%s\". Max speed cannot be less than 0.00: %.2f", key, maxspeed);
    return;
  } else if (maxspeed == 0.0) {
#if defined DEBUG_MAXSPEED
    new key[class_prop_key_length + 1];
    zm_getClassProperty(class, ZM_CLASS_NAME, key, charsmax(key));
    logd("Ignoring maxspeed change for %N because maxspeed of \"%s\" is %.2f", id, key, maxspeed);
#endif
    return;
  }

  if (maxspeed <= RAW_VALUE_THRESHOLD) {
    new Float: currentSpeed;
    pev(id, pev_maxspeed, currentSpeed);
    maxspeed *= currentSpeed;
#if defined DEBUG_MAXSPEED
    logd("maxspeed below threshold, treating as a multiplier");
#endif
  }

#if defined DEBUG_MAXSPEED
  logd("Setting maxspeed of %N to %.2f", id, maxspeed);
#endif
  engfunc(EngFunc_SetClientMaxspeed, id, maxspeed); 
  set_pev(id, pev_maxspeed, maxspeed);
}
