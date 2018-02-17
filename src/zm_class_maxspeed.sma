#include <amxmodx>
#include <fun>
#include <hamsandwich>
#include <logger>
#include <reapi>

#include "include/zm/zm_classes.inc"
#include "include/zm/zombies.inc"

#if defined ZM_COMPILE_FOR_DEBUG
  //#define DEBUG_MAXSPEED
#else
  //#define DEBUG_MAXSPEED
#endif

#define EXTENSION_NAME "Class Speed"
#define VERSION_STRING "1.0.0"

const Float: RAW_VALUE_THRESHOLD = 10.0;

static Float: fMaxspeed[MAX_PLAYERS + 1] = { 1.0, ... };

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

  RegisterHamPlayer(Ham_CS_Player_ResetMaxSpeed, "onResetMaxSpeed", true);
}

stock getBuildId(buildId[], len) {
  return formatex(buildId, len, "%s [%s]", VERSION_STRING, __DATE__);
}

public onResetMaxSpeed(id) {
  if (!is_user_alive(id)) {
    return;
  }
  
  static Float: maxspeed;
  maxspeed = fMaxspeed[id];
  if (maxspeed <= RAW_VALUE_THRESHOLD) {
#if defined DEBUG_MAXSPEED
  logd("maxspeed below threshold, treating as a multiplier");
#endif
    new activeItem = get_member(id, m_pActiveItem);
    if (activeItem <= 0) {
      logd("maxspeed below threshold, but active item = %d", activeItem);
      return;
    }
    
    static csw;
    csw = get_member(activeItem, m_iId);
    maxspeed *= getWeaponMaxspeed(csw);
  }
 
  set_user_maxspeed(id, maxspeed);
}

stock Float: getWeaponMaxspeed(csw) {
  switch (csw) {
    case CSW_SG550, CSW_AWP, CSW_G3SG1: return 210.0;
    case CSW_M249: return 220.0;
    case CSW_AK47: return 221.0;
    case CSW_M3, CSW_M4A1: return 230.0;
    case CSW_SG552: return 235.0;
    case CSW_XM1014, CSW_AUG, CSW_GALIL, CSW_FAMAS: return 240.0;
    case CSW_P90: return 245.0;
    case CSW_SCOUT: return 260.0;
    default: return 250.0;
  }

  return 250.0;
}

public zm_onApply(const id) {
  new const Class: class = zm_getUserClass(id);
  if (!class) {
#if defined DEBUG_MAXSPEED
    logd("%N doesn't have a class, resetting", id);
#endif
    setMaxspeed(id, 1.0);
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

  setMaxspeed(id, maxspeed);
}

stock Float: getMaxspeed(id) {
  return fMaxspeed[id];
}

stock setMaxspeed(id, Float: maxspeed) {
#if defined DEBUG_MAXSPEED
  logd("Setting maxspeed of %N to %.2f", id, maxspeed);
#endif
  fMaxspeed[id] = maxspeed;
  //ExecuteHamB(Ham_CS_Player_ResetMaxSpeed, id);
  rg_reset_maxspeed(id);
}
