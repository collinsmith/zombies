#include <amxconst>
#include <amxmisc>

#include "include/stocks/string_stocks.inc"

#include "include/cs_weapon_restrictions/cs_weapon_restrictions.inc"

#include "include/zm/zm_classes.inc"
#include "include/zm/zombies.inc"

#if defined ZM_COMPILE_FOR_DEBUG
  //#define DEBUG_LOOKUP
  //#define DEBUG_RESTRICTIONS
#else
  //#define DEBUG_LOOKUP
  //#define DEBUG_RESTRICTIONS
#endif

#define EXTENSION_NAME "Class Weapon Restrictions"
#define VERSION_STRING "1.0.0"

#define FAST_WEAPONS

static Logger: logger = Invalid_Logger;
#pragma unused logger

static Trie: weapons;

public zm_onInit() {
  logger = zm_getLogger();

#if defined DEBUG_LOOKUP
  LoggerLogDebug(logger, "populating weapon lookup table");
#endif
  weapons = TrieCreate();
#if defined FAST_WEAPONS
  TrieSetCell(weapons, "p228", CSW_P228);
  TrieSetCell(weapons, "scout", CSW_SCOUT);
  TrieSetCell(weapons, "hegrenade", CSW_HEGRENADE);
  TrieSetCell(weapons, "xm1014", CSW_XM1014);
  TrieSetCell(weapons, "c4", CSW_C4);
  TrieSetCell(weapons, "mac10", CSW_MAC10);
  TrieSetCell(weapons, "aug", CSW_AUG);
  TrieSetCell(weapons, "smokegrenade", CSW_SMOKEGRENADE);
  TrieSetCell(weapons, "elite", CSW_ELITE);
  TrieSetCell(weapons, "fiveseven", CSW_FIVESEVEN);
  TrieSetCell(weapons, "ump45", CSW_UMP45);
  TrieSetCell(weapons, "sg550", CSW_SG550);
  TrieSetCell(weapons, "galil", CSW_GALIL);
  TrieSetCell(weapons, "famas", CSW_FAMAS);
  TrieSetCell(weapons, "usp", CSW_USP);
  TrieSetCell(weapons, "glock18", CSW_GLOCK18);
  TrieSetCell(weapons, "awp", CSW_AWP);
  TrieSetCell(weapons, "mp5navy", CSW_MP5NAVY);
  TrieSetCell(weapons, "m249", CSW_M249);
  TrieSetCell(weapons, "m3", CSW_M3);
  TrieSetCell(weapons, "m4a1", CSW_M4A1);
  TrieSetCell(weapons, "tmp", CSW_TMP);
  TrieSetCell(weapons, "g3sg1", CSW_G3SG1);
  TrieSetCell(weapons, "flashbang", CSW_FLASHBANG);
  TrieSetCell(weapons, "deagle", CSW_DEAGLE);
  TrieSetCell(weapons, "sg552", CSW_SG552);
  TrieSetCell(weapons, "ak47", CSW_AK47);
  TrieSetCell(weapons, "knife", CSW_KNIFE);
  TrieSetCell(weapons, "p90", CSW_P90);
#else
  for (new csw = CSW_P228, weaponname[32], len; csw <= CSW_P90; csw++) {
    len = get_weaponname(csw, weaponname, charsmax(weaponname));
    if (len == 0) {
      continue;
    }

    TrieSetCell(weapons, weaponname[7], csw);
  }
#endif
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
      .desc = "Applies weapon restrictions for classes");
}

stock getBuildId(buildId[], len) {
  return formatex(buildId, len, "%s [%s]", VERSION_STRING, __DATE__);
}

public zm_onApply(const id) {
  new const Class: class = zm_getUserClass(id);
  if (!class) {
#if defined DEBUG_RESTRICTIONS
    LoggerLogDebug(logger, "%N doesn't have a class, resetting", id);
#endif
    cs_resetWeaponRestrictions(id);
    return;
  }

  static value[class_prop_value_length + 1];
  zm_getClassProperty(class, ZM_CLASS_WEAPONS, value, charsmax(value));

  new const allowed_weapons = parseWeapons(value);
  cs_setWeaponRestrictions(id, allowed_weapons, CSW_KNIFE, true);
}

parseWeapons(const value[]) {
  new result;
  for (new weapon[32], pos, csw;;) {
    pos = argparse(value, pos, weapon, charsmax(weapon));
    if (pos == -1) {
      break;
    }
    
    TrieGetCell(weapons, weapon, csw);
    result |= (1 << csw);
  }

  return result;
}
