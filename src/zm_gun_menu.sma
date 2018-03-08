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

#define EXTENSION_NAME "Gun Menu"
#define VERSION_STRING "1.0.0"

static menu = INVALID_HANDLE;
static callback = INVALID_HANDLE;

static blockedReason[256];

static displayedGuns[MAX_PLAYERS + 1];
static Stack: menus[MAX_PLAYERS + 1];

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
      .desc = "Manages gun menu");

  zm_registerDictionary("common.txt");
  zm_registerDictionary("zm_guns.txt");
  registerConsoleCommands();
}

stock getBuildId(buildId[], len) {
  return formatex(buildId, len, "%s [%s]", VERSION_STRING, __DATE__);
}

registerConsoleCommands() {
  cmd_registerCommand(
      .alias = "guns",
      .handle = "onGunMenu",
      .desc = "Displays the gun selection menu");

  zm_registerConCmd(
      .command = "guns",
      .callback = "onGunMenu",
      .desc = "Displays the gun selection menu");
}

/*******************************************************************************
 * Console Commands
 ******************************************************************************/

public onGunMenu(id) {
  showGunMenu(id,
      {
        CSI_ALL_PISTOLS,
        CSI_ALL_SHOTGUNS | CSI_ALL_SMGS | CSI_ALL_RIFLES | CSI_ALL_SNIPERRIFLES | CSI_ALL_MACHINEGUNS
      });
  return PLUGIN_HANDLED;
}

/*******************************************************************************
 * Mutators
 ******************************************************************************/

public onItemSelected(const id, const menu, const item) {
  if (item == MENU_EXIT) {
    return PLUGIN_HANDLED;
  }
  
  new weaponName[32], access, callback;
  menu_item_getinfo(menu, item, access, weaponName, charsmax(weaponName), .callback = callback);
  logd("%N selected \"%s\"", id, weaponName);
  rg_give_item(id, weaponName);
  showNextMenu(id);
  return PLUGIN_HANDLED;
}

public isItemEnabled(const id, const menu, const item) {
  // TODO: Check usable weapon
  new name[32], access, callback;
  menu_item_getinfo(menu, item, access, name, charsmax(name), .callback = callback);
  new const csi = get_weaponid(name);
  new const flag = 1 << csi;
#if defined ITEM_HIDDEN
  return (flag & displayedGuns[id]) == flag ? ITEM_IGNORE : ITEM_HIDDEN;
#else
  return (flag & displayedGuns[id]) == flag ? ITEM_IGNORE : ITEM_DISABLED;
#endif
}

bool: showGunMenu(const id, const weapons[], const len = sizeof weapons) {
#if defined ASSERTIONS
  assert isValidConnected(id);
  assert len > 0;
#endif
  if (menus[id] == Invalid_Stack) {
    menus[id] = CreateStack();
  }

  new const Stack: stack = menus[id];
  for (new i = len - 1; i >= 0; i--) {
#if defined ASSERTIONS
    assert weapons[i] != 0;
#endif
    PushStackCell(stack, weapons[i]);
  }

#if defined ASSERTIONS
  assert !IsStackEmpty(stack);
#endif
  PopStack(stack);

  return showMenu(id, weapons[0]);
}

bool: showNextMenu(const id) {
#if defined ASSERTIONS
  assert isValidConnected(id);
#endif
  new const Stack: stack = menus[id];
  if (!IsStackEmpty(stack)) {
    new weapons;
    PopStackCell(stack, weapons);
    return showMenu(id, weapons);
  }

  return false;
}

bool: showMenu(const id, weapons) {
#if defined ASSERTIONS
  assert isValidConnected(id);
#endif
  // FIXME: viewingMenu is 1 when using console command to call this function, expected 0
  new menuHandle, newMenuHandle;
  new viewingMenu = player_menu_info(id, menuHandle, newMenuHandle);
  if (viewingMenu && (menuHandle > 0 || newMenuHandle != INVALID_HANDLE)) {
    logd("%N already viewing menu: %d (menu=%d, newmenu=%d)",
        id, viewingMenu, menuHandle, newMenuHandle);
    return false;
  }

  new retVal = zm_onBeforeGunMenuDisplayed(id, weapons);
  if (retVal == PLUGIN_HANDLED) {
    parseResourceFast(blockedReason, charsmax(blockedReason), id);
    zm_onGunMenuBlocked(id, blockedReason);
    return showNextMenu(id);
  }
  
  // FIXME: Create ITEM_HIDDEN constant for hiding items from menu
#if !defined ITEM_HIDDEN
  new menu = INVALID_HANDLE;
#endif
  if (menu == INVALID_HANDLE) {
    menu = menu_create(NULL, "onItemSelected");
    callback = menu_makecallback("isItemEnabled");
    new const name[][] = {
        "", "weapon_p228", "", "weapon_scout", "weapon_hegrenade",
        "weapon_xm1014", "weapon_c4", "weapon_mac10", "weapon_aug",
        "weapon_smokegrenade", "weapon_elite", "weapon_fiveseven",
        "weapon_ump45", "weapon_sg550", "weapon_galil", "weapon_famas",
        "weapon_usp", "weapon_glock18", "weapon_awp", "weapon_mp5navy",
        "weapon_m249", "weapon_m3", "weapon_m4a1", "weapon_tmp", "weapon_g3sg1",
        "weapon_flashbang", "weapon_deagle", "weapon_sg552", "weapon_ak47",
        "weapon_knife", "weapon_p90"
    };
    
#if defined ITEM_HIDDEN
    for (new i = CSI_P228; i <= CSI_LAST_WEAPON; i++) {
      if (name[i][0] != EOS) {
        menu_additem(menu, .name=name[i], .info=name[i], .callback=callback);
        logd("Added %s to gun menu", name[i]);
      }
    }
#else
    for (new i = CSI_P228; i <= CSI_LAST_WEAPON; i++) {
      new const csi = 1 << i;
      if ((weapons & csi) == csi && name[i][0] != EOS) {        
        menu_additem(menu, .name=name[i], .info=name[i], .callback=callback);
        logd("Added %s to gun menu", name[i]);
      }
    }
#endif
  }
  
  personalize(menu, id);
  displayedGuns[id] = weapons;
  menu_display(id, menu);
  logd("Displaying gun menu for %N : %x", id, weapons);
  zm_onGunMenuDisplayed(id, weapons);
  return true;
}

personalize(const menu, const id) {
  new text[64], mId = id;
  LookupLangKey(text, charsmax(text), "ZM_GUN_MENU_TITLE", mId);
  menu_setprop(menu, MPROP_TITLE, text);
  LookupLangKey(text, charsmax(text), "BACK", mId);
  menu_setprop(menu, MPROP_BACKNAME, text);
  LookupLangKey(text, charsmax(text), "MORE", mId);
  menu_setprop(menu, MPROP_NEXTNAME, text);
  menu_setprop(menu, MPROP_EXIT, MEXIT_NEVER);
  
  new const numItems = menu_items(menu);
  if (numItems <= 10) {
    menu_setprop(menu, MPROP_PERPAGE, 0);
  } else {
    menu_setprop(menu, MPROP_PERPAGE, 7);
  }
  
  new weaponName[32];
  new weaponNameTrans[32];
  new access, callback;
  for (new item = 0; item < numItems; item++) {
    menu_item_getinfo(menu, item, access, weaponName, charsmax(weaponName), .callback = callback);
    formatex(weaponNameTrans, charsmax(weaponNameTrans), "%L", id, weaponName);
    formatex(text, charsmax(text), "%L", id, "ZM_GUN_ITEM", weaponNameTrans);
    logd("text=%s", text);
    menu_item_setname(menu, item, text);
  }
}

/*******************************************************************************
 * Forwards
 ******************************************************************************/

zm_onBeforeGunMenuDisplayed(const id, &weapons) {
#if defined ASSERTIONS
  assert isValidId(id);
  assert weapons != 0;
#endif
#if defined DEBUG_FORWARDS
  logd("Forwarding zm_onBeforeGunMenuDisplayed(%N, weapons=%x)", id, weapons);
#endif
  static handle = INVALID_HANDLE;
  if (handle == INVALID_HANDLE) {
    handle = CreateMultiForward(
        "zm_onBeforeGunMenuDisplayed", ET_STOP,
        FP_CELL, FP_CELL);
  }

  blockedReason[0] = EOS;
  
  new retVal;
  // TODO: Copy back modifications? Allow changes
  assert ExecuteForward(handle, retVal, id, weapons);
  return retVal;
}

zm_onGunMenuBlocked(const id, const reason[]) {
#if defined ASSERTIONS
  assert isValidId(id);
#endif
#if defined DEBUG_FORWARDS
  logd("Forwarding zm_onGunMenuBlocked(%N, \"%s\")", id, reason);
#endif
  static handle = INVALID_HANDLE;
  if (handle == INVALID_HANDLE) {
    handle = CreateMultiForward(
        "zm_onGunMenuBlocked", ET_IGNORE,
        FP_CELL, FP_STRING);
  }
  
  assert ExecuteForward(handle, _, id, reason);
}

zm_onGunMenuDisplayed(const id, const weapons) {
#if defined ASSERTIONS
  assert isValidId(id);
  assert len > 0;
#endif
#if defined DEBUG_FORWARDS
  logd("Forwarding zm_onGunMenuDisplayed(%N, weapons=%x)", id, weapons);
#endif
  static handle = INVALID_HANDLE;
  if (handle == INVALID_HANDLE) {
    handle = CreateMultiForward(
        "zm_onGunMenuDisplayed", ET_IGNORE,
        FP_CELL, FP_CELL);
  }

  assert ExecuteForward(handle, _, id, weapons);
}

/*******************************************************************************
 * Natives
 ******************************************************************************/

public plugin_natives() {
  register_library("zm_gun_menu");
  zm_registerNative("showGunMenu");
  zm_registerNative("setGunMenuBlockedReason");
}

stock bool: operator=(value) return value > 0;

//native bool: zm_showGunMenu(const id, const weapons, ...);
public bool: native_showGunMenu(const plugin, const argc) {
#if defined DEBUG_NATIVES
  if (!numParamsGreaterEqual(2, argc)) {
    return false;
  }
#endif

  new const id = get_param(1);
  if (!isValidConnected(id)) {
    return false;
  }

  new weapons[32];
  weapons[0] = get_param(2);
  for (new i = 3; i <= argc; i++) {
    weapons[i - 2] = get_param_byref(i);
  }

#if defined DEBUG_NATIVES
  new str[256], len;
  for (new i = 0; i < argc - 1; i++) {
    len += formatex(str[len], charsmax(str) - len, "%x, ", weapons[i]);
  }

  str[len - 2] = EOS;
  logd("zm_showGunMenu(%N, { %s })", id, str);
#endif

  return showGunMenu(id, weapons, argc - 1);
}

//native zm_setGunMenuBlockedReason(const reason[]);
public native_setGunMenuBlockedReason(const plugin, const argc) {
#if defined DEBUG_NATIVES
  if (!numParamsEqual(1, argc)) {
    return -1;
  }
#endif
  
  new const len = get_string(1, blockedReason, charsmax(blockedReason));
  blockedReason[len] = EOS;
  return len;
}

stock bool: isValidConnected(const id) {
  if (!isValidId(id)) {
    ThrowIllegalArgumentException("Invalid player id specified: %d", id);
    return false;
  } else if (!is_user_connected(id)) {
    ThrowIllegalArgumentException("Player with id is not connected: %d", id);
    return false;
  }

  return true;
}

