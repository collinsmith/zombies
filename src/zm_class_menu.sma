#include <amxmodx>
#include <logger>

#include "include/stocks/param_stocks.inc"

#include "include/commands/commands.inc"

#include "include/zm/zombies.inc"
#include "include/zm/zm_classes.inc"

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

#define EXTENSION_NAME "Class Menu"
#define VERSION_STRING "1.0.0"

static menu = INVALID_HANDLE;
static callback = INVALID_HANDLE;

static blockedReason[256];

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
      .desc = "Manages class menu");

  zm_registerDictionary("common.txt");
  registerConsoleCommands();
}

stock getBuildId(buildId[], len) {
  return formatex(buildId, len, "%s [%s]", VERSION_STRING, __DATE__);
}

registerConsoleCommands() {
  cmd_registerCommand(
      .alias = "class",
      .handle = "onClassMenu",
      .desc = "Displays the class selection menu");

  zm_registerConCmd(
      .command = "class",
      .callback = "onClassMenu",
      .desc = "Displays the class selection menu");
}

public zm_onClassRegistered(const Trie: class, const classId[]) {
  if (menu == INVALID_HANDLE) {
    menu = menu_create(NULL, "onItemSelected");
    callback = menu_makecallback("isItemEnabled");
  }

  new name[32];
  TrieGetString(class, ZM_CLASS_NAME, name, charsmax(name));
  menu_additem(menu, .name=name, .info=classId, .callback=callback);
  logd("Added %s to class menu", classId);
}

public onItemSelected(const id, const menu, const item) {
  if (item == MENU_EXIT) {
    return PLUGIN_HANDLED;
  }
  
  new classId[32], access, callback;
  menu_item_getinfo(menu, item, access, classId, charsmax(classId), .callback = callback);
  new const Trie: class = zm_findClass(classId);
  logd("%N selected \"%s\" (%d)", id, classId, class);
  zm_setUserClass(id, class);
  return PLUGIN_HANDLED;
}

public isItemEnabled(const id, const menu, const item) {
  new classId[32], access, callback;
  menu_item_getinfo(menu, item, access, classId, charsmax(classId), .callback = callback);
  new const Trie: class = zm_findClass(classId);

  // TODO: This should maybe be handled in an extension
  if (class == zm_getUserClass(id)) {
    return ITEM_DISABLED;
  }
  
  return zm_isClassEnabled(id, class) ? ITEM_IGNORE : ITEM_DISABLED;
}

/*******************************************************************************
 * Console Commands
 ******************************************************************************/

public onClassMenu(id) {
  showClassMenu(id, true);
  return PLUGIN_HANDLED;
}

/*******************************************************************************
 * Mutators
 ******************************************************************************/

bool: showClassMenu(const id, const bool: exitable) {
  new ZM_Team: team = zm_getUserTeam(id);
  if (team == ZM_TEAM_UNASSIGNED || team == ZM_TEAM_SPECTATOR) {
    ThrowIllegalStateException("%N must belong to a real team, currently: %s", id, ZM_Team_Names[team]);
    return false;
  }

  // FIXME: viewingMenu is 1 when using console command to call this function, expected 0
  new menuHandle, newMenuHandle;
  new viewingMenu = player_menu_info(id, menuHandle, newMenuHandle);
  if (viewingMenu && (menuHandle > 0 || newMenuHandle != INVALID_HANDLE)) {
    logd("%N already viewing menu: %d (menu=%d, newmenu=%d)",
        id, viewingMenu, menuHandle, newMenuHandle);
    return false;
  }

  new retVal = zm_onBeforeClassMenuDisplayed(id, exitable);
  if (exitable && retVal == PLUGIN_HANDLED) {
    parseResourceFast(blockedReason, charsmax(blockedReason), id);
    zm_onClassMenuBlocked(id, blockedReason);
    return false;
  }

  personalize(menu, id, exitable);
  menu_display(id, menu);
  logd("Displaying class menu for %N", id);
  zm_onClassMenuDisplayed(id, exitable);
  return true;
}

personalize(const menu, const id, const bool: exitable) {  
  new text[64], mId = id;
  LookupLangKey(text, charsmax(text), "ZM_CLASS_MENU_TITLE", mId);
  menu_setprop(menu, MPROP_TITLE, text);
  LookupLangKey(text, charsmax(text), "BACK", mId);
  menu_setprop(menu, MPROP_BACKNAME, text);
  LookupLangKey(text, charsmax(text), "MORE", mId);
  menu_setprop(menu, MPROP_NEXTNAME, text);
  if (exitable) {
    LookupLangKey(text, charsmax(text), "EXIT", mId);
    menu_setprop(menu, MPROP_EXITNAME, text);
  } else {
    menu_setprop(menu, MPROP_EXIT, MEXIT_NEVER);
  }
  
  new const numItems = menu_items(menu);
  if (!exitable && numItems <= 10) {
    menu_setprop(menu, MPROP_PERPAGE, 0);
  } else if (numItems < 10) {
    menu_setprop(menu, MPROP_PERPAGE, 0);
  } else {
    menu_setprop(menu, MPROP_PERPAGE, 7);
  }
  
  new Trie: class, classId[32];
  new name[32], desc[32];
  new access, callback;
  for (new item = 0; item < numItems; item++) {
    menu_item_getinfo(menu, item, access, classId, charsmax(classId), .callback = callback);
    class = zm_findClass(classId);
    TrieGetString(class, ZM_CLASS_NAME, name, charsmax(name));
    parseResourceFast(name, charsmax(name), id);
    TrieGetString(class, ZM_CLASS_DESC, desc, charsmax(desc));
    parseResourceFast(desc, charsmax(desc), id);
    formatex(text, charsmax(text), "%L", id, "ZM_CLASS_ITEM", name, desc);
    logd("text=%s", text);
    menu_item_setname(menu, item, text);
  }
}

/*******************************************************************************
 * Forwards
 ******************************************************************************/

zm_onBeforeClassMenuDisplayed(const id, const bool: exitable) {
#if defined ASSERTIONS
  assert isValidId(id);
#endif
#if defined DEBUG_FORWARDS
  logd("Forwarding zm_onBeforeClassMenuDisplayed(%N, exitable=%s)",
      id, exitable ? TRUE : FALSE);
#endif
  static handle = INVALID_HANDLE;
  if (handle == INVALID_HANDLE) {
    handle = CreateMultiForward(
        "zm_onBeforeClassMenuDisplayed", ET_STOP,
        FP_CELL, FP_CELL);
  }

  blockedReason[0] = EOS;
  
  new retVal;
  assert ExecuteForward(handle, retVal, id, exitable);
  return retVal;
}

zm_onClassMenuBlocked(const id, const reason[]) {
#if defined ASSERTIONS
  assert isValidId(id);
#endif
#if defined DEBUG_FORWARDS
  logd("Forwarding zm_onClassMenuBlocked(%N, \"%s\")", id, reason);
#endif
  static handle = INVALID_HANDLE;
  if (handle == INVALID_HANDLE) {
    handle = CreateMultiForward(
        "zm_onClassMenuBlocked", ET_IGNORE,
        FP_CELL, FP_STRING);
  }
  
  assert ExecuteForward(handle, _, id, reason);
}

zm_onClassMenuDisplayed(const id, const bool: exitable) {
#if defined ASSERTIONS
  assert isValidId(id);
#endif
#if defined DEBUG_FORWARDS
  logd("Forwarding zm_onClassMenuDisplayed(%N, exitable=%s)",
      id, exitable ? TRUE : FALSE);
#endif
  static handle = INVALID_HANDLE;
  if (handle == INVALID_HANDLE) {
    handle = CreateMultiForward(
        "zm_onClassMenuDisplayed", ET_IGNORE,
        FP_CELL, FP_CELL);
  }

  assert ExecuteForward(handle, _, id, exitable);
}

/*******************************************************************************
 * Natives
 ******************************************************************************/

public plugin_natives() {
  register_library("zm_class_menu");
  zm_registerNative("showClassMenu");
  zm_registerNative("setClassMenuBlockedReason");
}

stock bool: operator=(value) return value > 0;

//native bool: zm_showClassMenu(const id, const bool: exitable);
public bool: native_showClassMenu(const plugin, const argc) {
#if defined DEBUG_NATIVES
  if (!numParamsEqual(2, argc)) {
    return false;
  }
#endif

  new const id = get_param(1);
  if (!isValidConnected(id)) {
    return false;
  }
  
  new const bool: exitable = get_param(2);
  return showClassMenu(id, exitable);
}

//native zm_setClassMenuBlockedReason(const reason[]);
public native_setClassMenuBlockedReason(const plugin, const argc) {
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
